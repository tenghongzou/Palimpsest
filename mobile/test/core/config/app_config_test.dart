import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('appName is Palimpsest', () {
      expect(AppConfig.appName, 'Palimpsest');
    });

    test('apiBaseUrl has correct default', () {
      expect(AppConfig.apiBaseUrl, contains('api/v1'));
    });

    test('maxCacheSizeBytes is 500MB', () {
      expect(AppConfig.maxCacheSizeBytes, 524288000);
    });

    test('syncIntervalMinutes is 5', () {
      expect(AppConfig.syncIntervalMinutes, 5);
    });
  });
}
