class AppConfig {
  static const String appName = 'Palimpsest';
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080/api/v1', // Android emulator -> host
  );
  static const int maxCacheSizeBytes = 524288000; // 500MB
  static const int syncIntervalMinutes = 5;
}
