import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../community/domain/entities/community.dart';
import '../../../community/presentation/widgets/comments_sheet.dart';
import '../../data/bookmark_repository.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/chapter_translation.dart';
import '../providers/chapter_provider.dart';
import '../providers/reader_provider.dart';
import '../widgets/bookmark_list.dart';
import '../widgets/reading_settings_panel.dart';
import '../widgets/toc_sheet.dart';
import '../widgets/translate_sheet.dart';

class ReaderPage extends ConsumerStatefulWidget {
  final String chapterId;

  /// Paragraph to open at (e.g. from a bookmark or saved progress).
  final int? initialParagraph;

  /// A comment to show on open, in the chapter's comments (e.g. from a reply
  /// notification).
  final String? focusCommentId;

  const ReaderPage({super.key, required this.chapterId, this.initialParagraph, this.focusCommentId});

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> with WidgetsBindingObserver {
  /// Progress is reported on scroll idle at most this often.
  static const _reportInterval = Duration(seconds: 15);

  /// Longer gaps between reports are not counted as reading time.
  static const _maxCountedGap = Duration(minutes: 10);

  final _scroll = ScrollController();
  bool _showToolbar = false;
  bool _showSettings = false;
  Chapter? _chapter;
  List<GlobalKey> _paragraphKeys = const [];
  ChapterTranslation? _translation;
  late final SyncService _sync;
  late final bool Function() _signedIn;
  DateTime? _readingSince;
  DateTime _lastReport = DateTime.now();
  int _lastParagraph = 0;
  double _lastFraction = 0;

  /// Set when this page is replaced by another chapter; its final report was
  /// already sent so it cannot overwrite the next chapter's position.
  bool _leaving = false;
  Timer? _idleTimer;

  /// Whether [ReaderPage.focusCommentId] was already shown.
  bool _focusShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync = ref.read(syncServiceProvider);
    final api = ref.read(apiClientProvider);
    _signedIn = () => api.hasAccessToken;
    ref.listenManual<AsyncValue<Chapter>>(chapterProvider(widget.chapterId), (_, next) {
      final chapter = next.valueOrNull;
      if (chapter != null && _chapter?.id != chapter.id) _onChapterLoaded(chapter);
    }, fireImmediately: true);
    ref.listenManual<bool>(readerSettingsProvider.select((s) => s.keepScreenOn), (_, keep) {
      _setWakelock(keep);
    }, fireImmediately: true);
  }

  /// Keeps the screen on while the reader is open, if the user wants that.
  void _setWakelock(bool on) {
    (on ? WakelockPlus.enable() : WakelockPlus.disable()).catchError((_) {
      // Not supported on this platform (e.g. tests); reading still works.
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    if (!_leaving) _report(disposing: true);
    _setWakelock(false);
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _readingSince = DateTime.now();
    } else if (state == AppLifecycleState.paused) {
      _report();
      _readingSince = null;
    }
  }

  void _onChapterLoaded(Chapter chapter) {
    _chapter = chapter;
    _translation = null;
    _paragraphKeys = List.generate(chapter.paragraphs.length, (_) => GlobalKey());
    _readingSince = DateTime.now();
    _lastReport = DateTime.now();
    _lastParagraph = widget.initialParagraph ?? 0;
    _lastFraction = 0;
    // Opening a chapter is reported right away (it adds a history entry).
    _sync
        .recordProgress(
          novelId: chapter.novelId,
          chapterId: chapter.id,
          scrollOffset: 0,
          paragraphIndex: widget.initialParagraph ?? 0,
          upload: _signedIn(),
        )
        .catchError((_) {});
    final target = widget.initialParagraph;
    if (target != null && target > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToParagraph(target));
    }
    final focus = widget.focusCommentId;
    if (focus != null && !_focusShown) {
      _focusShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showFocusedThread(chapter, focus);
      });
    }
  }

  /// Opens the comments holding [commentId] with its thread pinned: the
  /// paragraph's comments when it is a paragraph comment, else the chapter's.
  /// When the thread is gone or unreachable, the chapter's comments open and
  /// say so.
  Future<void> _showFocusedThread(Chapter chapter, String commentId) async {
    final provider = commentThreadProvider(commentId);
    // Keeps the fetched thread for the sheet, which shows it pinned.
    final keepAlive = ref.listenManual(provider, (_, __) {});
    try {
      Comment? thread;
      try {
        thread = await ref.read(provider.future);
      } catch (_) {}
      if (!mounted) return;
      final paragraphs = chapter.paragraphs;
      final index = thread?.paragraphIndex;
      if (thread != null && thread.chapterId == chapter.id && index != null && index < paragraphs.length) {
        await showCommentsSheet(context, chapter.id,
            paragraphIndex: index, paragraphText: paragraphs[index], focusCommentId: commentId, dark: _darkTheme);
      } else {
        await _showComments(chapter, focusCommentId: commentId);
      }
    } finally {
      keepAlive.close();
    }
  }

  bool get _darkTheme {
    final settings = ref.read(readerSettingsProvider);
    return (AppTheme.readerThemes[settings.theme] ?? AppTheme.readerThemes['white']!).isDark;
  }

  Future<void> _showComments(Chapter chapter, {String? focusCommentId}) =>
      showCommentsSheet(context, chapter.id, focusCommentId: focusCommentId, dark: _darkTheme);

  /// Comments on one paragraph (long-press on it, or its count bubble).
  Future<void> _showParagraphComments(Chapter chapter, int index, String text) {
    HapticFeedback.selectionClick().ignore();
    return showCommentsSheet(context, chapter.id, paragraphIndex: index, paragraphText: text, dark: _darkTheme);
  }

  // ------------------------------------------------------- taps, page mode

  void _toggleToolbar() => setState(() {
        _showToolbar = !_showToolbar;
        if (!_showToolbar) _showSettings = false;
      });

  /// In page mode the left and right thirds of the screen turn pages and the
  /// middle shows the toolbar; in scroll mode any tap shows the toolbar.
  void _onContentTap(Chapter chapter, TapUpDetails details, bool pageMode, bool autoChapter) {
    if (_showToolbar || !pageMode) {
      _toggleToolbar();
      return;
    }
    final x = details.globalPosition.dx / MediaQuery.of(context).size.width;
    if (x < 1 / 3) {
      _pageBy(chapter, -1, autoChapter);
    } else if (x > 2 / 3) {
      _pageBy(chapter, 1, autoChapter);
    } else {
      _toggleToolbar();
    }
  }

  /// Scrolls one screen, keeping a little overlap; at either end of the
  /// chapter it moves to the neighbouring chapter when auto-chapter is on.
  void _pageBy(Chapter chapter, int direction, bool autoChapter) {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (direction > 0 && position.pixels >= position.maxScrollExtent - 4) {
      final next = chapter.nextChapter;
      if (autoChapter && next != null) _openChapter(next.id);
      return;
    }
    if (direction < 0 && position.pixels <= position.minScrollExtent + 4) {
      final prev = chapter.prevChapter;
      if (autoChapter && prev != null) _openChapter(prev.id);
      return;
    }
    final target = (position.pixels + direction * (position.viewportDimension - 80))
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  // --------------------------------------------------------------- position

  /// Index of the first paragraph visible at the top of the screen.
  int _currentParagraph() {
    final topInset = MediaQuery.of(context).padding.top + 56;
    for (var i = 0; i < _paragraphKeys.length; i++) {
      final box = _paragraphKeys[i].currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final bottom = box.localToGlobal(Offset.zero).dy + box.size.height;
      if (bottom > topInset) return i;
    }
    return math.max(0, _paragraphKeys.length - 1);
  }

  double _scrollFraction() {
    if (!_scroll.hasClients) return 0;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return 1;
    return (_scroll.offset / max).clamp(0.0, 1.0);
  }

  void _jumpToParagraph(int index) {
    if (index < 0 || index >= _paragraphKeys.length) return;
    final ctx = _paragraphKeys[index].currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.05);
  }

  /// Reports the position and the time read since the previous report.
  /// While [disposing], the last known paragraph is used because the widget
  /// tree can no longer be inspected.
  void _report({bool disposing = false}) {
    final chapter = _chapter;
    if (chapter == null) return;
    final now = DateTime.now();
    var seconds = 0;
    final since = _readingSince;
    if (since != null) {
      final gap = now.difference(since);
      seconds = (gap > _maxCountedGap ? _maxCountedGap : gap).inSeconds;
    }
    _readingSince = _readingSince == null ? null : now;
    _lastReport = now;
    if (!disposing) {
      _lastParagraph = _currentParagraph();
      _lastFraction = _scrollFraction();
    }
    _sync
        .recordProgress(
          novelId: chapter.novelId,
          chapterId: chapter.id,
          scrollOffset: _lastFraction,
          paragraphIndex: _lastParagraph,
          duration: seconds,
          upload: _signedIn(),
        )
        .catchError((_) {});
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollEndNotification) {
      _lastParagraph = _currentParagraph();
      _lastFraction = _scrollFraction();
      _idleTimer?.cancel();
      _idleTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && DateTime.now().difference(_lastReport) >= _reportInterval) _report();
      });
    }
    return false;
  }

  // ---------------------------------------------------------------- actions

  void _openChapter(String chapterId, {int? paragraph}) {
    _report();
    _leaving = true;
    final location = paragraph != null && paragraph > 0 ? '/read/$chapterId?p=$paragraph' : '/read/$chapterId';
    context.pushReplacement(location);
  }

  void _close(Chapter? chapter) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(chapter == null ? '/' : '/novel/${chapter.novelId}');
    }
  }

  Future<void> _addBookmark(Chapter chapter) async {
    final paragraph = _currentParagraph();
    try {
      await ref.read(bookmarkRepositoryProvider).add(
            novelId: chapter.novelId,
            chapterId: chapter.id,
            chapterTitle: chapter.title,
            paragraphIndex: paragraph,
          );
      ref.invalidate(bookmarksProvider(chapter.novelId));
      ref.invalidate(bookmarksProvider(null));
      if (mounted) showSnack(context, '已加入書籤（第 ${paragraph + 1} 段）');
    } catch (e) {
      if (mounted) showSnack(context, '加入書籤失敗');
    }
  }

  Future<void> _showBookmarks(Chapter chapter) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(children: [
                Text('書籤', style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(sheetContext)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: BookmarkList(
                novelId: chapter.novelId,
                onOpen: (b) {
                  Navigator.pop(sheetContext);
                  if (b.chapterId == chapter.id) {
                    _jumpToParagraph(b.paragraphIndex);
                  } else {
                    _openChapter(b.chapterId, paragraph: b.paragraphIndex);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showToc(Chapter chapter) async {
    final id = await showTocSheet(context, novelId: chapter.novelId, currentChapterId: chapter.id);
    if (id != null && id != chapter.id && mounted) _openChapter(id);
  }

  Future<void> _showTranslate(Chapter chapter) async {
    final translation = await showTranslateSheet(context, chapter);
    if (translation != null && mounted) setState(() => _translation = translation);
  }

  // ------------------------------------------------------------------- view

  @override
  Widget build(BuildContext context) {
    final chapterAsync = ref.watch(chapterProvider(widget.chapterId));
    final settings = ref.watch(readerSettingsProvider);
    final theme = AppTheme.readerThemes[settings.theme] ?? AppTheme.readerThemes['white']!;
    final dim = (100 - settings.brightness.clamp(10, 100)) / 100 * 0.7;

    return Scaffold(
      backgroundColor: theme.background,
      body: chapterAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildError(e),
        // Fill the screen even for short chapters, so the bottom toolbar sits
        // at the bottom and taps below the text still toggle the toolbars.
        data: (chapter) => Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _onContentTap(chapter, details, settings.readingMode == 'page', settings.autoChapter),
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: _buildContent(chapter, settings.fontSize.toDouble(), settings.lineHeight,
                    settings.letterSpacing, settings.margin.toDouble(), theme),
              ),
            ),
            if (dim > 0)
              IgnorePointer(child: Container(color: Colors.black.withValues(alpha: dim))),
            if (_showToolbar) ..._buildToolbars(chapter),
          ],
        ),
      ),
    );
  }

  Widget _buildError(Object e) {
    final offline = isNetworkError(e);
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => _close(null)),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(offline ? '目前離線，且此章節尚未下載' : '載入失敗：${describeError(e)}', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(chapterProvider(widget.chapterId)),
                      child: const Text('重試'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Chapter chapter, double fontSize, double lineHeight, double letterSpacing, double margin,
      ReaderTheme theme) {
    final translation = _translation;
    final paragraphs = translation == null
        ? chapter.paragraphs
        : translation.content.split('\n').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    final title = translation?.title ?? chapter.title;
    final subtle = TextStyle(fontSize: 12, color: theme.text.withValues(alpha: 0.6));
    final textStyle = TextStyle(fontSize: fontSize, height: lineHeight, letterSpacing: letterSpacing, color: theme.text);
    // Paragraph comments use the original's paragraph indexes; a translation
    // with a different paragraph count cannot be matched up, and a chapter
    // served from the offline cache means the server is unreachable.
    final paragraphComments =
        !chapter.fromCache && (translation == null || paragraphs.length == chapter.paragraphs.length);
    final counts = paragraphComments
        ? ref.watch(paragraphCountsProvider(chapter.id)).valueOrNull ?? const <int, int>{}
        : const <int, int>{};

    return SingleChildScrollView(
      controller: _scroll,
      padding: EdgeInsets.symmetric(horizontal: margin + 16, vertical: 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chapter.fromCache)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('離線模式：顯示的是本機快取的章節', style: subtle),
              ),
            ),
          if (translation != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('正在顯示譯文（${translationLanguages[translation.targetLang] ?? translation.targetLang}）', style: subtle),
                  TextButton(onPressed: () => setState(() => _translation = null), child: const Text('顯示原文')),
                ]),
              ),
            ),
          Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: fontSize + 4, fontWeight: FontWeight.bold, color: theme.text),
            ),
          ),
          const SizedBox(height: 32),
          for (var i = 0; i < paragraphs.length; i++)
            Padding(
              key: i < _paragraphKeys.length ? _paragraphKeys[i] : null,
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildParagraph(chapter, i, paragraphs[i], textStyle, theme,
                  count: counts[i] ?? 0, commentable: paragraphComments),
            ),
          const SizedBox(height: 40),
          _buildChapterNav(chapter, theme.text),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () => _showComments(chapter),
              icon: Icon(Icons.chat_bubble_outline, color: theme.text, size: 18),
              label: Text('本章留言', style: TextStyle(color: theme.text)),
            ),
          ),
        ],
      ),
    );
  }

  /// A paragraph; long-press opens its comments. Commented paragraphs end
  /// with a small count bubble that opens them too. Plain taps fall through
  /// to the page's tap handling (toolbar, page turns).
  Widget _buildParagraph(Chapter chapter, int index, String text, TextStyle style, ReaderTheme theme,
      {required int count, required bool commentable}) {
    final content = Text.rich(
      TextSpan(children: [
        TextSpan(text: '　　$text'),
        if (count > 0)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _ParagraphCommentBubble(
              key: ValueKey('paragraph-comments-$index'),
              count: count,
              color: theme.text,
              onTap: () => _showParagraphComments(chapter, index, text),
            ),
          ),
      ]),
      style: style,
    );
    if (!commentable) return content;
    return GestureDetector(
      onLongPress: () => _showParagraphComments(chapter, index, text),
      child: content,
    );
  }

  Widget _buildChapterNav(Chapter chapter, Color color) {
    final prev = chapter.prevChapter;
    final next = chapter.nextChapter;
    final disabled = color.withValues(alpha: 0.35);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton(
          onPressed: prev == null ? null : () => _openChapter(prev.id),
          child: Text(prev == null ? '已是第一章' : '上一章', style: TextStyle(color: prev == null ? disabled : color)),
        ),
        TextButton(
          onPressed: next == null ? null : () => _openChapter(next.id),
          child: Text(next == null ? '已是最新章' : '下一章', style: TextStyle(color: next == null ? disabled : color)),
        ),
      ],
    );
  }

  List<Widget> _buildToolbars(Chapter chapter) {
    final surface = Theme.of(context).colorScheme.surface;
    return [
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Material(
          color: surface,
          elevation: 2,
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(tooltip: '返回', icon: const Icon(Icons.arrow_back), onPressed: () => _close(chapter)),
                Expanded(child: Text(chapter.title, overflow: TextOverflow.ellipsis)),
                IconButton(
                  tooltip: '加入書籤',
                  icon: const Icon(Icons.bookmark_add_outlined),
                  onPressed: () => _addBookmark(chapter),
                ),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Material(
          color: surface,
          elevation: 8,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    TextButton(
                      onPressed: chapter.prevChapter == null ? null : () => _openChapter(chapter.prevChapter!.id),
                      child: const Text('上一章'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: chapter.nextChapter == null ? null : () => _openChapter(chapter.nextChapter!.id),
                      child: const Text('下一章'),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(tooltip: '目錄', icon: const Icon(Icons.list), onPressed: () => _showToc(chapter)),
                    IconButton(tooltip: '書籤', icon: const Icon(Icons.bookmarks_outlined), onPressed: () => _showBookmarks(chapter)),
                    IconButton(
                      tooltip: '留言',
                      icon: const Icon(Icons.chat_bubble_outline),
                      onPressed: () => _showComments(chapter),
                    ),
                    IconButton(tooltip: '翻譯', icon: const Icon(Icons.translate), onPressed: () => _showTranslate(chapter)),
                    IconButton(
                      tooltip: '閱讀設定',
                      icon: const Icon(Icons.settings),
                      onPressed: () => setState(() => _showSettings = !_showSettings),
                    ),
                  ],
                ),
                if (_showSettings)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: ReadingSettingsPanel(compact: true),
                  ),
              ],
            ),
          ),
        ),
      ),
    ];
  }
}

/// The comment count shown at the end of a commented paragraph.
class _ParagraphCommentBubble extends StatelessWidget {
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _ParagraphCommentBubble({super.key, required this.count, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tint = color.withValues(alpha: 0.5);
    return Semantics(
      button: true,
      label: '本段有 $count 則留言',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          // A slightly larger target than the bubble itself.
          padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              border: Border.all(color: color.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline, size: 11, color: tint),
                const SizedBox(width: 2),
                Text(
                  count > 99 ? '99+' : '$count',
                  style: TextStyle(fontSize: 11, height: 1.2, letterSpacing: 0, color: tint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
