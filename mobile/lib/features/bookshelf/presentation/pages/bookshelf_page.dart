import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/bookshelf_repository.dart';
import '../../domain/entities/bookshelf_item.dart';
import '../providers/bookshelf_provider.dart';

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
        title: Text(_selecting ? '已選擇 ${_selected.length} 本' : '我的書架'),
        leading: _selecting
            ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(_exitSelection))
            : null,
        actions: user == null
            ? null
            : _selecting
                ? [
                    IconButton(
                      tooltip: '移出書架',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _selected.isEmpty ? null : _removeSelected,
                    ),
                  ]
                : [
                    PopupMenuButton<String>(
                      tooltip: '排序',
                      icon: const Icon(Icons.sort),
                      initialValue: notifier.sortBy,
                      onSelected: (v) => notifier.load(sortBy: v),
                      itemBuilder: (_) => bookshelfSortOptions.entries
                          .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
                          .toList(),
                    ),
                    IconButton(
                      tooltip: '管理',
                      icon: const Icon(Icons.checklist),
                      onPressed: () => setState(() => _selecting = true),
                    ),
                  ],
      ),
      body: user == null
          ? EmptyState(
              icon: Icons.book_outlined,
              message: '登入後即可使用書架',
              actionLabel: '登入',
              onAction: () => context.push('/login'),
            )
          : bookshelf.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('載入失敗：${describeError(e)}')),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.book_outlined,
                    message: '書架還是空的',
                    actionLabel: '去逛逛',
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
                                label: Text(g == null ? '全部' : _groupLabel(g)),
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
        ? '讀到 第${progress.chapterNumber}章 ${progress.chapterTitle} · ${progress.percentage.toStringAsFixed(0)}%'
        : '尚未開始閱讀';
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
              child: const Text('更新', style: TextStyle(color: Colors.white, fontSize: 10)),
            ),
        ],
      ),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      trailing: _selecting || progress?.chapterId == null
          ? null
          : TextButton(
              onPressed: () => context.push('/read/${progress!.chapterId}'),
              child: const Text('繼續'),
            ),
      onTap: () => _selecting ? _toggle(item.novelId) : context.push('/novel/${item.novelId}'),
      onLongPress: _selecting ? null : () => _showItemActions(item),
    );
  }

  String _groupLabel(String group) => group == 'default' ? '預設' : group;

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
      showSnack(context, '已移出 ${ids.length} 本');
    } catch (e) {
      if (mounted) showSnack(context, describeError(e));
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
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('移動到分組'),
              onTap: () => Navigator.pop(context, 'group'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('移出書架'),
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
        if (mounted) showSnack(context, '已移出書架');
      } else if (action == 'group') {
        final group = await _askGroup(item.groupName);
        if (group != null && group.isNotEmpty) await notifier.setGroup(item.novelId, group);
      }
    } catch (e) {
      if (mounted) showSnack(context, describeError(e));
    }
  }

  Future<String?> _askGroup(String current) {
    final controller = TextEditingController(text: current == 'default' ? '' : current);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移動到分組'),
        content: TextField(
          controller: controller,
          maxLength: 50,
          decoration: const InputDecoration(hintText: '分組名稱（留空為預設）'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              Navigator.pop(context, name.isEmpty ? 'default' : name);
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }
}
