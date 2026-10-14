import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: AppConfig.apiBaseUrl);
});

class ApiClient {
  final Dio _dio;
  Future<bool>? _refreshing;

  /// [adapter] replaces the HTTP transport; tests use it to fake the server.
  ApiClient({required String baseUrl, HttpClientAdapter? adapter})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Content-Type': 'application/json',
          },
        )) {
    if (adapter != null) _dio.httpClientAdapter = adapter;
    _dio.interceptors.add(_AuthInterceptor(this));
    // Request logging in debug builds, but not under `flutter test`.
    if (kDebugMode && !Platform.environment.containsKey('FLUTTER_TEST')) {
      _dio.interceptors.add(LogInterceptor(responseBody: false));
    }
  }

  Dio get dio => _dio;

  void setAccessToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  bool get hasAccessToken => _dio.options.headers['Authorization'] != null;

  void clearAccessToken() {
    _dio.options.headers.remove('Authorization');
  }

  /// Refreshes the session. Concurrent callers share the same in-flight refresh.
  Future<bool> tryRefreshToken() {
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _refresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      if (refreshToken == null) return false;

      final refreshDio = Dio(BaseOptions(baseUrl: _dio.options.baseUrl))
        ..httpClientAdapter = _dio.httpClientAdapter;
      final response = await refreshDio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = response.data['data'];
      final newAccessToken = data['access_token'] as String;
      final newRefreshToken = data['refresh_token'] as String;

      setAccessToken(newAccessToken);
      await prefs.setString('access_token', newAccessToken);
      await prefs.setString('refresh_token', newRefreshToken);
      return true;
    } catch (_) {
      clearAccessToken();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      return false;
    }
  }
}

class _AuthInterceptor extends Interceptor {
  final ApiClient _client;

  _AuthInterceptor(this._client);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Retry once only, so a request that keeps failing with 401 cannot loop.
    if (err.response?.statusCode == 401 && err.requestOptions.extra['retried'] != true) {
      final success = await _client.tryRefreshToken();
      if (success) {
        try {
          final opts = err.requestOptions;
          opts.extra['retried'] = true;
          opts.headers['Authorization'] = _client._dio.options.headers['Authorization'];
          final response = await _client._dio.fetch(opts);
          return handler.resolve(response);
        } catch (e) {
          return handler.next(err);
        }
      }
    }
    handler.next(err);
  }
}
