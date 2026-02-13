import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';
import '../../domain/entities/user.dart';

final authStateProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AsyncValue.data(null));

  Future<void> login(String login, String password) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.login(login, password);
      state = AsyncValue.data(result.user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> register(String username, String email, String password, String nickname) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.register(username, email, password, nickname);
      state = AsyncValue.data(result.user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncValue.data(null);
  }

  Future<void> tryRestoreSession() async {
    await _repo.restoreSession();
    final result = await _repo.refreshToken();
    if (result != null) {
      state = AsyncValue.data(result.user);
    }
  }
}
