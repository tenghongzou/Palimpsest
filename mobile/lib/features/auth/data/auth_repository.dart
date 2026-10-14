import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../domain/entities/user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(apiClientProvider));
});

class AuthRepository {
  static const _userKey = 'current_user';

  final ApiClient _apiClient;

  AuthRepository(this._apiClient);

  Future<AuthResult> login(String login, String password) async {
    final response = await _apiClient.dio.post('/auth/login', data: {
      'login': login,
      'password': password,
    });
    return _handleAuth(response.data['data'] as Map<String, dynamic>);
  }

  Future<AuthResult> register(String username, String email, String password, String nickname) async {
    final response = await _apiClient.dio.post('/auth/register', data: {
      'username': username,
      'email': email,
      'password': password,
      'nickname': nickname,
    });
    return _handleAuth(response.data['data'] as Map<String, dynamic>);
  }

  /// Always succeeds (the server does not reveal whether the email exists).
  Future<void> forgotPassword(String email) async {
    await _apiClient.dio.post('/auth/forgot-password', data: {'email': email});
  }

  Future<void> resetPassword(String token, String newPassword) async {
    await _apiClient.dio.post('/auth/reset-password', data: {'token': token, 'new_password': newPassword});
  }

  Future<void> logout() async {
    try {
      await _apiClient.dio.post('/auth/logout');
    } catch (_) {}
    _apiClient.clearAccessToken();
    await _clearTokens();
  }

  Future<AuthResult?> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('refresh_token');
    if (token == null) return null;

    try {
      final response = await _apiClient.dio.post('/auth/refresh', data: {
        'refresh_token': token,
      });
      return await _handleAuth(response.data['data'] as Map<String, dynamic>);
    } catch (_) {
      await _clearTokens();
      return null;
    }
  }

  /// Restores the saved session. Returns the signed in user: fetched from
  /// the server when reachable, otherwise the copy cached at the last sign in.
  Future<User?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    if (accessToken == null) return null;
    _apiClient.setAccessToken(accessToken);
    try {
      // An expired access token is refreshed by the client's interceptor.
      return await fetchMe();
    } on DioException catch (e) {
      if (e.response == null) return cachedUser();
      if (e.response?.statusCode == 401) {
        _apiClient.clearAccessToken();
        await _clearTokens();
      }
      return null;
    }
  }

  Future<User> fetchMe() async {
    final response = await _apiClient.dio.get('/users/me');
    final user = User.fromJson(response.data['data'] as Map<String, dynamic>);
    await cacheUser(user);
    return user;
  }

  Future<User?> cachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<AuthResult> _handleAuth(Map<String, dynamic> data) async {
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String;
    _apiClient.setAccessToken(accessToken);
    await _saveTokens(accessToken, refreshToken);
    await cacheUser(user);
    return AuthResult(user: user, accessToken: accessToken, refreshToken: refreshToken);
  }

  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }

  Future<void> _clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove(_userKey);
  }
}

class AuthResult {
  final User user;
  final String accessToken;
  final String refreshToken;

  const AuthResult({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });
}
