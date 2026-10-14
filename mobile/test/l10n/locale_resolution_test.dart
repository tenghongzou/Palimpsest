import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/core/l10n/l10n.dart';

void main() {
  const zhTW = Locale('zh', 'TW');
  const zhCN = Locale('zh', 'CN');
  const en = Locale('en');

  group('resolveAppLocale', () {
    test('Traditional Chinese by script or region', () {
      expect(resolveAppLocale([const Locale('zh', 'TW')]), zhTW);
      expect(resolveAppLocale([const Locale('zh', 'HK')]), zhTW);
      expect(resolveAppLocale([const Locale('zh', 'MO')]), zhTW);
      expect(resolveAppLocale([const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')]), zhTW);
      // The script wins over the region.
      expect(resolveAppLocale([const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'CN')]),
          zhTW);
    });

    test('Simplified Chinese by script or region', () {
      expect(resolveAppLocale([const Locale('zh', 'CN')]), zhCN);
      expect(resolveAppLocale([const Locale('zh', 'SG')]), zhCN);
      expect(resolveAppLocale([const Locale('zh', 'MY')]), zhCN);
      expect(resolveAppLocale([const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans')]), zhCN);
      expect(resolveAppLocale([const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans', countryCode: 'HK')]),
          zhCN);
    });

    test('plain zh is Traditional, the default', () {
      expect(resolveAppLocale([const Locale('zh')]), zhTW);
    });

    test('English in any region', () {
      expect(resolveAppLocale([const Locale('en', 'US')]), en);
      expect(resolveAppLocale([const Locale('en', 'GB')]), en);
    });

    test('the first supported preference wins; unsupported ones are skipped', () {
      expect(resolveAppLocale([const Locale('ja', 'JP'), const Locale('zh', 'CN'), const Locale('en')]), zhCN);
      expect(resolveAppLocale([const Locale('fr'), const Locale('en', 'CA')]), en);
    });

    test('falls back to zh-TW', () {
      expect(resolveAppLocale([const Locale('ja', 'JP'), const Locale('ko')]), zhTW);
      expect(resolveAppLocale(const []), zhTW);
      expect(resolveAppLocale(null), zhTW);
    });
  });

  test('language_pref codes map onto locales and back to localizations', () {
    expect(localeForLanguage('zh-TW'), zhTW);
    expect(localeForLanguage('zh-CN'), zhCN);
    expect(localeForLanguage('en'), en);
    expect(localeForLanguage('fr'), zhTW);
    expect(lookupAppLocalizations(zhTW).settings, '設定');
    expect(lookupAppLocalizations(zhCN).settings, '设置');
    expect(lookupAppLocalizations(en).settings, 'Settings');
    expect(intlLocaleOf(lookupAppLocalizations(zhTW)), 'zh_TW');
    expect(intlLocaleOf(lookupAppLocalizations(zhCN)), 'zh_CN');
  });
}
