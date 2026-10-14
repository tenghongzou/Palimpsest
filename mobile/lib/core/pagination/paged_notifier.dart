import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_error.dart';
import '../network/paginated.dart';

class PagedState<T> {
  final List<T> items;
  final int page;
  final bool hasMore;
  final bool isLoading;
  final Object? error;

  const PagedState({
    this.items = const [],
    this.page = 0,
    this.hasMore = true,
    this.isLoading = false,
    this.error,
  });

  bool get isInitialLoading => isLoading && items.isEmpty;

  PagedState<T> copyWith({List<T>? items, int? page, bool? hasMore, bool? isLoading, Object? error}) =>
      PagedState(
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

/// Loads a paginated endpoint page by page.
class PagedNotifier<T> extends StateNotifier<PagedState<T>> {
  final Future<Paginated<T>> Function(int page) fetch;

  PagedNotifier(this.fetch, {bool autoLoad = true}) : super(const PagedState()) {
    if (autoLoad) loadMore();
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);
    try {
      final result = await fetch(state.page + 1);
      if (!mounted) return;
      state = PagedState(
        items: [...state.items, ...result.items],
        page: result.page,
        hasMore: result.hasMore && result.items.isNotEmpty,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> refresh() async {
    state = const PagedState();
    await loadMore();
  }

  /// Replaces items in place (e.g. after liking one).
  void updateItems(List<T> Function(List<T> items) update) {
    state = state.copyWith(items: update(state.items));
  }
}

/// A list over a [PagedState] that loads the next page when its end is shown.
class PagedListView<T> extends StatelessWidget {
  final PagedState<T> state;
  final VoidCallback onLoadMore;
  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget? empty;
  final EdgeInsetsGeometry? padding;
  final Widget? header;

  const PagedListView({
    super.key,
    required this.state,
    required this.onLoadMore,
    required this.onRefresh,
    required this.itemBuilder,
    this.empty,
    this.padding,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isInitialLoading) return const Center(child: CircularProgressIndicator());
    if (state.items.isEmpty && state.error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('載入失敗：${describeError(state.error!)}'),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRefresh, child: const Text('重試')),
        ]),
      );
    }
    final offset = header == null ? 0 : 1;
    final showEmpty = state.items.isEmpty && !state.hasMore;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: padding,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: offset + (showEmpty ? 1 : state.items.length + 1),
        itemBuilder: (context, index) {
          if (header != null && index == 0) return header!;
          final i = index - offset;
          if (showEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(child: empty ?? const Text('目前沒有內容')),
            );
          }
          if (i < state.items.length) return itemBuilder(context, state.items[i], i);
          return _Footer(state: state, onLoadMore: onLoadMore);
        },
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final PagedState state;
  final VoidCallback onLoadMore;

  const _Footer({required this.state, required this.onLoadMore});

  @override
  Widget build(BuildContext context) {
    if (state.error != null) {
      return Center(child: TextButton(onPressed: onLoadMore, child: const Text('載入失敗，點此重試')));
    }
    if (!state.hasMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('沒有更多了', style: TextStyle(color: Colors.grey))),
      );
    }
    if (!state.isLoading) WidgetsBinding.instance.addPostFrameCallback((_) => onLoadMore());
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
    );
  }
}
