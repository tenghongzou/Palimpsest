import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../devices/data/device_registration.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../data/auth_repository.dart';
import '../../domain/entities/user.dart';

final authStateProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider), beforeLogout: () => cleanUpBeforeLogout(ref));
});

/// Runs while still signed in: uploads changes made offline, removes this
/// device's registration, then deletes the user's local data. Logging out
/// must not hang on a slow network, so each request gives up after a few
/// seconds.
Future<void> cleanUpBeforeLogout(Ref ref) async {
  final sync = ref.read(syncServiceProvider);
  final devices = ref.read(deviceRegistrationProvider);
  await Future.wait([
    sync.pushPending().timeout(const Duration(seconds: 5)).catchError((_) => 0),
    devices.unregister().timeout(const Duration(seconds: 5)).catchError((_) => devices.forget()),
  ]);
  ref.read(unreadCountProvider.notifier).reset();
  await (await sync.store()).clearUserData();
}

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthRepository _repo;

  /// Runs while still signed in, to flush and then remove the user's local data.
  final Future<void> Function()? beforeLogout;

  AuthNotifier(this._repo, {User? initialUser, this.beforeLogout}) : super(AsyncValue.data(initialUser));

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
    if (beforeLogout != null) {
      try {
        await beforeLogout!();
      } catch (_) {
        // Clearing local data is best effort; signing out must still work.
      }
    }
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
