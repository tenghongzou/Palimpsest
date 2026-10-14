import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

export '../../l10n/app_localizations.dart';

/// UI languages, as the API's `language_pref` codes.
const appLanguages = ['zh-TW', 'zh-CN', 'en'];

const _zhTW = Locale('zh', 'TW');
const _zhCN = Locale('zh', 'CN');
const _en = Locale('en');

/// Locales the app is translated into; zh-TW first (the default).
const appSupportedLocales = [_zhTW, _zhCN, _en];

/// The app locale for a `language_pref` code (zh-TW for unknown codes).
Locale localeForLanguage(String code) => switch (code) {
      'zh-CN' => _zhCN,
      'en' => _en,
      _ => _zhTW,
    };

/// Maps one locale onto a supported one, or null when it is not Chinese or
/// English. Chinese uses the script when given (Hant/Hans), else the region:
/// TW, HK and MO are Traditional, CN, SG and MY Simplified; plain `zh` is
/// Traditional, the app's default.
Locale? matchAppLocale(Locale locale) {
  switch (locale.languageCode.toLowerCase()) {
    case 'en':
      return _en;
    case 'zh':
      final script = locale.scriptCode?.toLowerCase();
      if (script == 'hans') return _zhCN;
      if (script == 'hant') return _zhTW;
      final region = locale.countryCode?.toUpperCase();
      if (region == 'CN' || region == 'SG' || region == 'MY') return _zhCN;
      return _zhTW;
  }
  return null;
}

/// The UI locale for the user's preferred locales (most preferred first):
/// the first one the app supports, else zh-TW.
Locale resolveAppLocale(List<Locale>? preferred) {
  for (final locale in preferred ?? const <Locale>[]) {
    final match = matchAppLocale(locale);
    if (match != null) return match;
  }
  return _zhTW;
}

/// The `intl` locale name for dates and numbers. Generated localizations use
/// `zh` for Traditional Chinese, which `intl` would treat as Simplified.
String intlLocaleOf(AppLocalizations l) => switch (l.localeName) {
      'zh' => 'zh_TW',
      final name => name,
    };

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
