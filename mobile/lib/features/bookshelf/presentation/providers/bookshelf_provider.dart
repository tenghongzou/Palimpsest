import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_error.dart';
import '../../data/bookshelf_repository.dart';
import '../../domain/entities/bookshelf_item.dart';

final bookshelfProvider = StateNotifierProvider<BookshelfNotifier, AsyncValue<List<BookshelfItem>>>((ref) {
  return BookshelfNotifier(ref.read(bookshelfRepositoryProvider));
});

class BookshelfNotifier extends StateNotifier<AsyncValue<List<BookshelfItem>>> {
  final BookshelfRepository _repo;
  String _sortBy = 'recent';

  BookshelfNotifier(this._repo) : super(const AsyncValue.loading());

  String get sortBy => _sortBy;

  bool contains(String novelId) => state.valueOrNull?.any((i) => i.novelId == novelId) ?? false;

  Future<void> load({String? sortBy}) async {
    if (sortBy != null) _sortBy = sortBy;
    if (!state.hasValue) state = const AsyncValue.loading();
    try {
      final items = await _repo.getBookshelf(sortBy: _sortBy);
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Adds a novel; throws when the server rejects it. A 409 (already on the
  /// shelf) counts as success.
  Future<void> add(String novelId) async {
    try {
      await _repo.addToBookshelf(novelId);
    } catch (e) {
      if (httpStatus(e) != 409) rethrow;
    }
    await load();
  }

  Future<void> remove(String novelId) async {
    await _repo.removeFromBookshelf(novelId);
    _drop({novelId});
  }

  Future<void> removeMany(Set<String> novelIds) async {
    if (novelIds.isEmpty) return;
    await _repo.batchRemove(novelIds.toList());
    _drop(novelIds);
  }

  Future<void> setGroup(String novelId, String groupName) async {
    await _repo.setGroup(novelId, groupName);
    await load();
  }

  void reset() => state = const AsyncValue.data([]);

  void _drop(Set<String> novelIds) {
    state.whenData((items) {
      state = AsyncValue.data(items.where((i) => !novelIds.contains(i.novelId)).toList());
    });
  }
}
