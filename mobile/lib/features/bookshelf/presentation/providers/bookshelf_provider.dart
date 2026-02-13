import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/bookshelf_repository.dart';
import '../../domain/entities/bookshelf_item.dart';

final bookshelfProvider = StateNotifierProvider<BookshelfNotifier, AsyncValue<List<BookshelfItem>>>((ref) {
  return BookshelfNotifier(ref.read(bookshelfRepositoryProvider));
});

class BookshelfNotifier extends StateNotifier<AsyncValue<List<BookshelfItem>>> {
  final BookshelfRepository _repo;

  BookshelfNotifier(this._repo) : super(const AsyncValue.loading());

  Future<void> load({String sort = 'recent'}) async {
    state = const AsyncValue.loading();
    try {
      final items = await _repo.getBookshelf(sort: sort);
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(String novelId) async {
    await _repo.addToBookshelf(novelId);
    await load();
  }

  Future<void> remove(String novelId) async {
    await _repo.removeFromBookshelf(novelId);
    state.whenData((items) {
      state = AsyncValue.data(items.where((i) => i.novelId != novelId).toList());
    });
  }
}
