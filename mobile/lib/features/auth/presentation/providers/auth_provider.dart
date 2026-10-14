import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';
import '../../domain/entities/user.dart';

final authStateProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthRepository _repo;

  AuthNotifier(this._repo, {User? initialUser}) : super(AsyncValue.data(initialUser));

  User? get user => state.valueOrNull;

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

  /// Replaces the signed in user after a profile change.
  void updateUser(User user) {
    state = AsyncValue.data(user);
    _repo.cacheUser(user).ignore();
  }

  Future<void> tryRestoreSession() async {
    final user = await _repo.restoreSession();
    if (user != null && mounted) state = AsyncValue.data(user);
  }

  /// Re-reads the signed in user (e.g. reading totals) from the server.
  Future<void> refreshUser() async {
    if (user == null) return;
    try {
      final fresh = await _repo.fetchMe();
      if (mounted) state = AsyncValue.data(fresh);
    } catch (_) {}
  }
}
