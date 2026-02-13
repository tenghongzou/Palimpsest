import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../domain/entities/user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(apiClientProvider));
});

class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository(this._apiClient);

  Future<AuthResult> login(String login, String password) async {
    final response = await _apiClient.dio.post('/auth/login', data: {
      'login': login,
      'password': password,
    });
    final data = response.data['data'];
    final user = _parseUser(data['user']);
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String;

    _apiClient.setAccessToken(accessToken);
    await _saveTokens(accessToken, refreshToken);

    return AuthResult(user: user, accessToken: accessToken, refreshToken: refreshToken);
  }

  Future<AuthResult> register(String username, String email, String password, String nickname) async {
    final response = await _apiClient.dio.post('/auth/register', data: {
      'username': username,
      'email': email,
      'password': password,
      'nickname': nickname,
    });
    final data = response.data['data'];
    final user = _parseUser(data['user']);
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String;

    _apiClient.setAccessToken(accessToken);
    await _saveTokens(accessToken, refreshToken);

    return AuthResult(user: user, accessToken: accessToken, refreshToken: refreshToken);
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
      final data = response.data['data'];
      final user = _parseUser(data['user']);
      final accessToken = data['access_token'] as String;
      final refreshToken = data['refresh_token'] as String;

      _apiClient.setAccessToken(accessToken);
      await _saveTokens(accessToken, refreshToken);

      return AuthResult(user: user, accessToken: accessToken, refreshToken: refreshToken);
    } catch (_) {
      await _clearTokens();
      return null;
    }
  }

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    if (accessToken != null) {
      _apiClient.setAccessToken(accessToken);
    }
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
  }

  User _parseUser(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      nickname: json['nickname'] as String,
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String? ?? 'reader',
      languagePref: json['language_pref'] as String? ?? 'zh-TW',
    );
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
