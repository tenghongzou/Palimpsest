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
import '../../domain/entities/reading_settings.dart';
import '../providers/chapter_provider.dart';
import '../providers/reader_provider.dart';
import '../widgets/bookmark_list.dart';
import '../widgets/page_turn_view.dart';
import '../widgets/reader_pagination.dart';
import '../widgets/reading_settings_panel.dart';
import '../widgets/toc_sheet.dart';
import '../widgets/translate_sheet.dart';
import '../../../../core/l10n/l10n.dart';

/// Route `extra` for a chapter change made by turning past a chapter's edge
/// in page mode: the turn animation already showed the new chapter, so the
/// route swaps without a transition of its own.
const seamlessChapterTurn = 'reader-seamless-chapter-turn';

class ReaderPage extends ConsumerStatefulWidget {
  final String chapterId;

  /// Paragraph to open at (e.g. from a bookmark or saved progress).
  final int? initialParagraph;

  /// A comment to show on open, in the chapter's comments (e.g. from a reply
  /// notification).
  final String? focusCommentId;

  /// Open at the chapter's last page in page mode (turning back from the
  /// next chapter).
  final bool startAtEnd;

  const ReaderPage({
    super.key,
    required this.chapterId,
    this.initialParagraph,
    this.focusCommentId,
    this.startAtEnd = false,
  });

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

  // Page mode.
  final _turns = PageTurnController();

  /// Whether the last build showed page mode.
  bool _pageModeActive = false;
  Pagination? _pagination;
  Object? _paginationKey;
  int _page = 0;

  /// Where the current page starts; kept when pages are recomputed (font
  /// size, translation, rotation) so the reader stays at the same text.
  PageAnchor _anchor = (0, 0);
  late bool _openAtEnd = widget.startAtEnd;
  final _neighbourPaginations = <String, (Object, Pagination)>{};
  final _prefetched = <String>{};

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
    ref.listenManual<bool>(readerSettingsProvider.select((s) => s.readingMode == 'page'), _onModeChanged);
    _anchor = (widget.initialParagraph ?? 0, 0);
  }

  /// Keeps the reading position when switching between scroll and page mode.
  void _onModeChanged(bool? before, bool pageMode) {
    if (before == pageMode || _chapter == null) return;
    // Still showing the previous mode here.
    final paragraph = _currentParagraph();
    _pagination = null;
    _paginationKey = null;
    if (pageMode) {
      _anchor = (paragraph, 0);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _jumpToParagraph(paragraph);
      });
    }
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
  void _onContentTap(TapUpDetails details, bool pageMode) {
    if (_showToolbar || !pageMode) {
      _toggleToolbar();
      return;
    }
    final x = details.globalPosition.dx / MediaQuery.of(context).size.width;
    if (x < 1 / 3) {
      _turns.turn(-1);
    } else if (x > 2 / 3) {
      _turns.turn(1);
    } else {
      _toggleToolbar();
    }
  }

  /// A page turn within the chapter finished.
  void _onPageChanged(Chapter chapter, int page) {
    final pagination = _pagination;
    if (pagination == null || page >= pagination.length) return;
    setState(() {
      _page = page;
      _anchor = pagination.pages[page].anchor;
    });
    _lastParagraph = _currentParagraph();
    _lastFraction = _scrollFraction();
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && DateTime.now().difference(_lastReport) >= _reportInterval) _report();
    });
    _prefetchNeighbours(chapter);
  }

  /// Loads the neighbouring chapter when nearing either end, so turning
  /// past the edge can show its first (or last) page right away.
  void _prefetchNeighbours(Chapter chapter) {
    final pagination = _pagination;
    if (pagination == null || !ref.read(readerSettingsProvider).autoChapter) return;
    final targets = [
      if (_page >= pagination.length - 2) chapter.nextChapter?.id,
      if (_page <= 1) chapter.prevChapter?.id,
    ];
    for (final id in targets.whereType<String>()) {
      if (!_prefetched.add(id)) continue;
      ref.listenManual<AsyncValue<Chapter>>(chapterProvider(id), (before, next) {
        // Rebuild the neighbour's page once it loads.
        if (mounted && before?.isLoading == true && !next.isLoading) setState(() {});
      });
    }
  }

  /// Turned past the chapter's edge onto the neighbouring chapter's page.
  void _leaveChapter(Chapter chapter, int direction) {
    final target = direction > 0 ? chapter.nextChapter : chapter.prevChapter;
    if (target != null) _openChapter(target.id, seamless: true, atEnd: direction < 0);
  }

  // --------------------------------------------------------------- position

  /// Index of the first paragraph visible at the top of the screen.
  int _currentParagraph() {
    final pagination = _pagination;
    if (_pageModeActive && pagination != null) {
      final page = _page.clamp(0, pagination.length - 1);
      return pagination.pages[page].firstParagraph.clamp(0, math.max(0, _paragraphKeys.length - 1));
    }
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
    final pagination = _pagination;
    if (_pageModeActive && pagination != null) {
      return pagination.length <= 1 ? 1 : (_page / (pagination.length - 1)).clamp(0.0, 1.0);
    }
    if (!_scroll.hasClients) return 0;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return 1;
    return (_scroll.offset / max).clamp(0.0, 1.0);
  }

  void _jumpToParagraph(int index) {
    if (index < 0 || index >= _paragraphKeys.length) return;
    if (_pageModeActive) {
      final pagination = _pagination;
      setState(() {
        _anchor = (index, 0);
        if (pagination != null) _page = pagination.pageFor(_anchor);
      });
      return;
    }
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

  /// Replaces this page with [chapterId]. A [seamless] change follows a
  /// page-turn animation that already showed the chapter, so the route swaps
  /// without a transition; [atEnd] opens at its last page.
  void _openChapter(String chapterId, {int? paragraph, bool seamless = false, bool atEnd = false}) {
    _report();
    _leaving = true;
    // A failed prefetch (e.g. offline) must not stick: load it afresh.
    if (ref.read(chapterProvider(chapterId)).hasError) ref.invalidate(chapterProvider(chapterId));
    final query = [
      if (paragraph != null && paragraph > 0) 'p=$paragraph',
      if (atEnd) 'at=end',
    ];
    final location = query.isEmpty ? '/read/$chapterId' : '/read/$chapterId?${query.join('&')}';
    context.pushReplacement(location, extra: seamless ? seamlessChapterTurn : null);
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
      if (mounted) showSnack(context, context.l10n.readerBookmarkAdded(paragraph + 1));
    } catch (e) {
      if (mounted) showSnack(context, context.l10n.readerBookmarkFailed);
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
                Text(context.l10n.bookmarks, style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
    final pageMode = settings.readingMode == 'page';
    _pageModeActive = pageMode && chapterAsync.hasValue;

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
              onTapUp: (details) => _onContentTap(details, pageMode),
              child: pageMode
                  ? _buildPaged(chapter, settings, theme)
                  : NotificationListener<ScrollNotification>(
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
                    Text(
                      offline
                          ? context.l10n.readerOfflineNotDownloaded
                          : context.l10n.commonLoadFailed(describeError(e, context.l10n)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(chapterProvider(widget.chapterId)),
                      child: Text(context.l10n.commonRetry),
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
                child: Text(context.l10n.readerOfflineCopy, style: subtle),
              ),
            ),
          if (translation != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    context.l10n.readerShowingTranslation(
                        translationLanguages[translation.targetLang] ?? translation.targetLang),
                    style: subtle,
                  ),
                  TextButton(onPressed: () => setState(() => _translation = null), child: Text(context.l10n.readerShowOriginal)),
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
              label: Text(context.l10n.chapterComments, style: TextStyle(color: theme.text)),
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
          child: Text(prev == null ? context.l10n.readerFirstChapter : context.l10n.readerPrevChapter, style: TextStyle(color: prev == null ? disabled : color)),
        ),
        TextButton(
          onPressed: next == null ? null : () => _openChapter(next.id),
          child: Text(next == null ? context.l10n.readerLatestChapter : context.l10n.readerNextChapter, style: TextStyle(color: next == null ? disabled : color)),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- page mode

  /// Measures and styles shared by every page of the current layout.
  _PageLayout _pageLayout(BuildContext context, BoxConstraints constraints, ReadingSettings settings, ReaderTheme theme) {
    final mq = MediaQuery.of(context);
    final side = settings.margin.toDouble() + 16;
    final padding = EdgeInsets.fromLTRB(side, mq.padding.top + 36, side, mq.padding.bottom + 36);
    final fontSize = settings.fontSize.toDouble();
    var base = DefaultTextStyle.of(context).style;
    if (mq.boldText) base = base.merge(const TextStyle(fontWeight: FontWeight.bold));
    final text = TextStyle(fontSize: fontSize, height: settings.lineHeight, letterSpacing: settings.letterSpacing, color: theme.text);
    final title = TextStyle(fontSize: fontSize + 4, fontWeight: FontWeight.bold, color: theme.text);
    final subtle = TextStyle(fontSize: 12, color: theme.text.withValues(alpha: 0.6));
    return _PageLayout(
      padding: padding,
      size: Size(
        math.max(1, constraints.maxWidth - padding.horizontal),
        math.max(1, constraints.maxHeight - padding.vertical),
      ),
      textStyle: text,
      titleStyle: title,
      subtle: subtle,
      measureText: base.merge(text),
      measureTitle: base.merge(title),
      measureSubtle: base.merge(subtle),
      textScaler: mq.textScaler,
      locale: Localizations.maybeLocaleOf(context),
      textDirection: Directionality.of(context),
      textHeightBehavior: DefaultTextHeightBehavior.maybeOf(context) ?? DefaultTextStyle.of(context).textHeightBehavior,
      theme: theme,
      settings: settings,
    );
  }

  /// Pages for [chapter] (or its [translation]) in [layout], recomputed only
  /// when something that moves page breaks changed.
  Pagination _paginate(_PageLayout layout, Chapter chapter, ChapterTranslation? translation, Map<int, int> counts,
      {required (Object, Pagination)? cached, required void Function(Object, Pagination) store}) {
    final paragraphs = _paragraphsOf(chapter, translation);
    final key = (
      chapter,
      translation,
      layout.size,
      layout.measureText,
      layout.measureTitle,
      layout.textScaler,
      layout.locale,
      layout.textDirection,
      counts,
    );
    if (cached != null && cached.$1 == key) return cached.$2;
    final pagination = PaginationSpec(
      paragraphs: paragraphs,
      title: translation?.title ?? chapter.title,
      textStyle: layout.measureText,
      titleStyle: layout.measureTitle,
      noticeStyle: layout.measureSubtle,
      size: layout.size,
      textScaler: layout.textScaler,
      locale: layout.locale,
      textDirection: layout.textDirection,
      textHeightBehavior: layout.textHeightBehavior,
      offlineNotice: chapter.fromCache,
      translationNotice: translation != null,
      commentCounts: counts,
    ).paginate();
    store(key, pagination);
    return pagination;
  }

  List<String> _paragraphsOf(Chapter chapter, ChapterTranslation? translation) => translation == null
      ? chapter.paragraphs
      : translation.content.split('\n').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();

  /// Whether paragraph comments can be shown for [chapter] as displayed.
  bool _commentable(Chapter chapter, ChapterTranslation? translation) =>
      !chapter.fromCache &&
      (translation == null || _paragraphsOf(chapter, translation).length == chapter.paragraphs.length);

  Widget _buildPaged(Chapter chapter, ReadingSettings settings, ReaderTheme theme) {
    final translation = _translation;
    final commentable = _commentable(chapter, translation);
    final counts = commentable
        ? ref.watch(paragraphCountsProvider(chapter.id)).valueOrNull ?? const <int, int>{}
        : const <int, int>{};
    return LayoutBuilder(builder: (context, constraints) {
      final layout = _pageLayout(context, constraints, settings, theme);
      final cached = _paginationKey == null || _pagination == null ? null : (_paginationKey!, _pagination!);
      final pagination = _paginate(layout, chapter, translation, counts,
          cached: cached, store: (key, _) => _paginationKey = key);
      if (!identical(pagination, _pagination)) {
        _pagination = pagination;
        if (_openAtEnd) {
          _openAtEnd = false;
          _page = pagination.length - 1;
          _anchor = pagination.pages[_page].anchor;
        } else {
          _page = pagination.pageFor(_anchor);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _prefetchNeighbours(chapter);
        });
      }
      return PageTurnView(
        controller: _turns,
        page: _page,
        pageCount: pagination.length,
        contentKey: pagination,
        effect: PageTurnEffect.parse(settings.effectivePageAnimation),
        background: theme.background,
        canLeave: (direction) =>
            settings.autoChapter && (direction > 0 ? chapter.nextChapter : chapter.prevChapter) != null,
        onPageChanged: (page) => _onPageChanged(chapter, page),
        onLeave: (direction) => _leaveChapter(chapter, direction),
        pageBuilder: (context, index) {
          if (index >= 0 && index < pagination.length) {
            return _buildPage(layout, chapter, translation, pagination, index, counts, commentable);
          }
          return _buildNeighbourPage(layout, chapter, index < 0 ? -1 : 1);
        },
      );
    });
  }

  /// The first page of the next chapter or the last of the previous one,
  /// shown while turning past this chapter's edge; a loading page until it
  /// has loaded.
  Widget _buildNeighbourPage(_PageLayout layout, Chapter chapter, int direction) {
    final target = direction > 0 ? chapter.nextChapter : chapter.prevChapter;
    if (target == null) return const SizedBox.shrink();
    final neighbour = ref.read(chapterProvider(target.id)).valueOrNull;
    if (neighbour == null) {
      return Padding(
        padding: layout.padding,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(target.title, textAlign: TextAlign.center, style: layout.titleStyle),
              const SizedBox(height: 24),
              SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: layout.theme.text.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      );
    }
    final pagination = _paginate(layout, neighbour, null, const {},
        cached: _neighbourPaginations[neighbour.id],
        store: (key, value) => _neighbourPaginations[neighbour.id] = (key, value));
    final index = direction > 0 ? 0 : pagination.length - 1;
    return _buildPage(layout, neighbour, null, pagination, index, const {}, false);
  }

  Widget _buildPage(_PageLayout layout, Chapter chapter, ChapterTranslation? translation, Pagination pagination,
      int index, Map<int, int> counts, bool commentable) {
    final page = pagination.pages[index];
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: layout.padding,
          // Measured to fit; clipped rather than overflowing if a font
          // renders a hair taller than measured.
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: 0,
              maxHeight: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final block in page.blocks)
                    _buildBlock(layout, block, chapter, translation, counts, commentable),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: layout.padding.right,
          bottom: bottomInset + 10,
          child: Text(context.l10n.readerPageOf(index + 1, pagination.length), style: layout.subtle),
        ),
      ],
    );
  }

  Widget _buildBlock(_PageLayout layout, PageBlock block, Chapter chapter, ChapterTranslation? translation,
      Map<int, int> counts, bool commentable) {
    final theme = layout.theme;
    switch (block) {
      case NoticeBlock(kind: NoticeKind.offline):
        return SizedBox(
          height: block.height,
          child: Align(
            alignment: Alignment.topCenter,
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(context.l10n.readerOfflineCopy, style: layout.subtle)),
          ),
        );
      case NoticeBlock(kind: NoticeKind.translation):
        final t = translation;
        return SizedBox(
          height: block.height,
          child: Align(
            alignment: Alignment.topCenter,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  t == null
                      ? ''
                      : context.l10n.readerShowingTranslation(translationLanguages[t.targetLang] ?? t.targetLang),
                  style: layout.subtle,
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => setState(() => _translation = null),
                  child: Text(context.l10n.readerShowOriginal),
                ),
              ]),
            ),
          ),
        );
      case TitleBlock():
        return SizedBox(
          height: block.height,
          child: Align(
            alignment: Alignment.topCenter,
            child: Text(translation?.title ?? chapter.title, textAlign: TextAlign.center, style: layout.titleStyle),
          ),
        );
      case ParagraphBlock():
        final paragraphs = _paragraphsOf(chapter, translation);
        final original = block.index < paragraphs.length ? paragraphs[block.index] : '';
        final count = block.last ? counts[block.index] ?? 0 : 0;
        final scaler = layout.textScaler;
        final content = Text.rich(
          TextSpan(children: [
            TextSpan(text: block.text),
            if (count > 0)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: SizedBox.fromSize(
                  size: commentBubbleSize(count, scaler),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _ParagraphCommentBubble(
                      key: ValueKey('paragraph-comments-${block.index}'),
                      count: count,
                      color: theme.text,
                      onTap: () => _showParagraphComments(chapter, block.index, original),
                    ),
                  ),
                ),
              ),
          ]),
          style: layout.textStyle,
        );
        return Padding(
          padding: EdgeInsets.only(bottom: block.spacing),
          child: SizedBox(
            height: block.height,
            child: commentable
                ? GestureDetector(
                    onLongPress: () => _showParagraphComments(chapter, block.index, original),
                    child: content,
                  )
                : content,
          ),
        );
      case FooterBlock():
        final rowHeight = (block.height - FooterBlock.gap) / 2;
        return SizedBox(
          height: block.height,
          child: Column(
            children: [
              const SizedBox(height: FooterBlock.gap),
              SizedBox(height: rowHeight, child: _buildChapterNav(chapter, theme.text)),
              SizedBox(
                height: rowHeight,
                child: Center(
                  child: TextButton.icon(
                    onPressed: () => _showComments(chapter),
                    icon: Icon(Icons.chat_bubble_outline, color: theme.text, size: 18),
                    label: Text(context.l10n.chapterComments, style: TextStyle(color: theme.text)),
                  ),
                ),
              ),
            ],
          ),
        );
    }
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
                IconButton(tooltip: context.l10n.commonBack, icon: const Icon(Icons.arrow_back), onPressed: () => _close(chapter)),
                Expanded(child: Text(chapter.title, overflow: TextOverflow.ellipsis)),
                IconButton(
                  tooltip: context.l10n.readerAddBookmark,
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
                      child: Text(context.l10n.readerPrevChapter),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: chapter.nextChapter == null ? null : () => _openChapter(chapter.nextChapter!.id),
                      child: Text(context.l10n.readerNextChapter),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(tooltip: context.l10n.readerToc, icon: const Icon(Icons.list), onPressed: () => _showToc(chapter)),
                    IconButton(tooltip: context.l10n.bookmarks, icon: const Icon(Icons.bookmarks_outlined), onPressed: () => _showBookmarks(chapter)),
                    IconButton(
                      tooltip: context.l10n.readerComments,
                      icon: const Icon(Icons.chat_bubble_outline),
                      onPressed: () => _showComments(chapter),
                    ),
                    IconButton(tooltip: context.l10n.readerTranslate, icon: const Icon(Icons.translate), onPressed: () => _showTranslate(chapter)),
                    IconButton(
                      tooltip: context.l10n.readingSettings,
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

/// Styles and measures for laying out pages in page mode.
class _PageLayout {
  final EdgeInsets padding;

  /// The text area of a page.
  final Size size;
  final TextStyle textStyle;
  final TextStyle titleStyle;
  final TextStyle subtle;

  /// The styles above merged with the ambient default style, as rendered.
  final TextStyle measureText;
  final TextStyle measureTitle;
  final TextStyle measureSubtle;
  final TextScaler textScaler;
  final Locale? locale;
  final TextDirection textDirection;
  final TextHeightBehavior? textHeightBehavior;
  final ReaderTheme theme;
  final ReadingSettings settings;

  const _PageLayout({
    required this.padding,
    required this.size,
    required this.textStyle,
    required this.titleStyle,
    required this.subtle,
    required this.measureText,
    required this.measureTitle,
    required this.measureSubtle,
    required this.textScaler,
    required this.locale,
    required this.textDirection,
    required this.textHeightBehavior,
    required this.theme,
    required this.settings,
  });
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
      label: context.l10n.readerParagraphCommentCount(count),
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
