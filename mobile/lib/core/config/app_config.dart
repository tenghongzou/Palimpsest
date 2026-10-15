import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'Palimpsest';

  /// `--dart-define=API_BASE_URL=...`; empty when not given.
  static const String _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// The API to talk to. Without a `--dart-define`, a backend on the
  /// development machine: 10.0.2.2 from the Android emulator, localhost
  /// from desktop builds and the iOS simulator.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return android ? 'http://10.0.2.2:8080/api/v1' : 'http://localhost:8080/api/v1';
  }

  static const int maxCacheSizeBytes = 524288000; // 500MB
  static const int syncIntervalMinutes = 5;
}
