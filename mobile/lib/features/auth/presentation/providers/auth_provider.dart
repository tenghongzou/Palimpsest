import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user.dart';

final authStateProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  AuthNotifier() : super(const AsyncValue.data(null));

  Future<void> login(String login, String password) async {
    state = const AsyncValue.loading();
    // TODO: call auth API
  }

  Future<void> register(String username, String email, String password, String nickname) async {
    state = const AsyncValue.loading();
    // TODO: call register API
  }

  Future<void> logout() async {
    // TODO: call logout API, clear tokens
    state = const AsyncValue.data(null);
  }
}
