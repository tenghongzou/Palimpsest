import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/bookshelf_repository.dart';
import '../../domain/entities/bookshelf_item.dart';
import '../providers/bookshelf_provider.dart';
import '../../../../core/l10n/l10n.dart';

class BookshelfPage extends ConsumerStatefulWidget {
  const BookshelfPage({super.key});

  @override
  ConsumerState<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends ConsumerState<BookshelfPage> {
  final Set<String> _selected = {};
  bool _selecting = false;
  String? _group;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (ref.read(authStateProvider).valueOrNull != null) ref.read(bookshelfProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final bookshelf = ref.watch(bookshelfProvider);
    final notifier = ref.read(bookshelfProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(_selecting ? context.l10n.shelfSelected(_selected.length) : context.l10n.shelfTitle),
        leading: _selecting
            ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(_exitSelection))
            : null,
        actions: user == null
            ? null
            : _selecting
                ? [
                    IconButton(
                      tooltip: context.l10n.shelfRemove,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _selected.isEmpty ? null : _removeSelected,
                    ),
                  ]
                : [
                    PopupMenuButton<String>(
                      tooltip: context.l10n.shelfSort,
                      icon: const Icon(Icons.sort),
                      initialValue: notifier.sortBy,
                      onSelected: (v) => notifier.load(sortBy: v),
                      itemBuilder: (_) => bookshelfSortOptions
                          .map((e) => PopupMenuItem(value: e, child: Text(bookshelfSortLabel(e, context.l10n))))
                          .toList(),
                    ),
                    IconButton(
                      tooltip: context.l10n.shelfManage,
                      icon: const Icon(Icons.checklist),
                      onPressed: () => setState(() => _selecting = true),
                    ),
                  ],
      ),
      body: user == null
          ? EmptyState(
              icon: Icons.book_outlined,
              message: context.l10n.shelfSignInPrompt,
              actionLabel: context.l10n.authLogin,
              onAction: () => context.push('/login'),
            )
          : bookshelf.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(context.l10n.commonLoadFailed(describeError(e, context.l10n)))),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.book_outlined,
                    message: context.l10n.shelfEmpty,
                    actionLabel: context.l10n.shelfBrowse,
                    onAction: () => context.go('/'),
                  );
                }
                final groups = items.map((i) => i.groupName).toSet().toList()..sort();
                final shown = _group == null ? items : items.where((i) => i.groupName == _group).toList();
                return RefreshIndicator(
                  onRefresh: () => notifier.load(),
                  child: ListView(
                    children: [
                      if (groups.length > 1)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [null, ...groups].map((g) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(g == null ? context.l10n.statusAll : _groupLabel(g)),
                                selected: _group == g,
                                onSelected: (_) => setState(() => _group = g),
                              ),
                            )).toList(),
                          ),
                        ),
                      ...shown.map(_buildItem),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: const AppBottomNav(selectedIndex: 1),
    );
  }

  Widget _buildItem(BookshelfItem item) {
    final progress = item.progress;
    final subtitle = progress != null
        ? context.l10n.shelfReadingAt(chapterLabel(progress.chapterNumber, progress.chapterTitle, context.l10n),
            progress.percentage.toStringAsFixed(0))
        : context.l10n.shelfNotStarted;
    return ListTile(
      leading: _selecting
          ? Checkbox(
              value: _selected.contains(item.novelId),
              onChanged: (_) => _toggle(item.novelId),
            )
          : NovelCover(url: item.coverUrl, width: 40, height: 56),
      title: Row(
        children: [
          Flexible(child: Text(item.novelTitle, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (item.hasUpdate)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
              child: Text(context.l10n.shelfUpdated, style: const TextStyle(color: Colors.white, fontSize: 10)),
            ),
          if (!item.isNotified)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.notifications_off_outlined, size: 14, color: Colors.grey.shade500, semanticLabel: context.l10n.shelfNotificationsOffLabel),
            ),
        ],
      ),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      trailing: _selecting || progress?.chapterId == null
          ? null
          : TextButton(
              onPressed: () => context.push('/read/${progress!.chapterId}'),
              child: Text(context.l10n.shelfContinue),
            ),
      onTap: () => _selecting ? _toggle(item.novelId) : context.push('/novel/${item.novelId}'),
      onLongPress: _selecting ? null : () => _showItemActions(item),
    );
  }

  String _groupLabel(String group) => group == 'default' ? context.l10n.shelfDefaultGroup : group;

  void _toggle(String novelId) {
    setState(() => _selected.contains(novelId) ? _selected.remove(novelId) : _selected.add(novelId));
  }

  void _exitSelection() {
    _selecting = false;
    _selected.clear();
  }

  Future<void> _removeSelected() async {
    final ids = Set<String>.from(_selected);
    try {
      await ref.read(bookshelfProvider.notifier).removeMany(ids);
      if (!mounted) return;
      setState(_exitSelection);
      showSnack(context, context.l10n.shelfRemovedCount(ids.length));
    } catch (e) {
      if (mounted) showSnack(context, describeError(e, context.l10n));
    }
  }

  Future<void> _showItemActions(BookshelfItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(item.novelTitle, style: const TextStyle(fontWeight: FontWeight.bold))),
            SwitchListTile(
              secondary: Icon(item.isNotified ? Icons.notifications_active_outlined : Icons.notifications_off_outlined),
              title: Text(context.l10n.shelfNotifications),
              subtitle: Text(context.l10n.shelfNotificationsSubtitle),
              value: item.isNotified,
              onChanged: (_) => Navigator.pop(context, 'notify'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(context.l10n.shelfMoveToGroup),
              onTap: () => Navigator.pop(context, 'group'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(context.l10n.shelfRemove),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    final notifier = ref.read(bookshelfProvider.notifier);
    try {
      if (action == 'remove') {
        await notifier.remove(item.novelId);
        if (mounted) showSnack(context, context.l10n.shelfRemoved);
      } else if (action == 'notify') {
        final on = !item.isNotified;
        await notifier.setNotified(item.novelId, on);
        if (mounted) showSnack(context, on ? context.l10n.shelfNotificationsOn : context.l10n.shelfNotificationsTurnedOff);
      } else if (action == 'group') {
        final group = await _askGroup(item.groupName);
        if (group != null && group.isNotEmpty) await notifier.setGroup(item.novelId, group);
      }
    } catch (e) {
      if (mounted) showSnack(context, describeError(e, context.l10n));
    }
  }

  Future<String?> _askGroup(String current) {
    final controller = TextEditingController(text: current == 'default' ? '' : current);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.shelfMoveToGroup),
        content: TextField(
          controller: controller,
          maxLength: 50,
          decoration: InputDecoration(hintText: context.l10n.shelfGroupHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.commonCancel)),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              Navigator.pop(context, name.isEmpty ? 'default' : name);
            },
            child: Text(context.l10n.commonConfirm),
          ),
        ],
      ),
    );
  }
}

String bookshelfSortLabel(String key, AppLocalizations l) => switch (key) {
      'recent' => l.shelfSortRecent,
      'added' => l.shelfSortAdded,
      'title' => l.shelfSortTitle,
      _ => key,
    };
