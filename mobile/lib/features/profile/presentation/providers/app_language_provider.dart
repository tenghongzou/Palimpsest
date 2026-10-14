import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/user_repository.dart';

/// The "follow the system" UI language setting.
const followSystemLanguage = 'system';

/// The UI language setting: [followSystemLanguage] or a `language_pref` code.
///
/// Rules:
/// * Following the system is local to this device: the UI uses the device's
///   locale and the account's `language_pref` is neither read nor written.
/// * A specific language picked while signed in is applied at once and saved
///   to the account (`PATCH /users/me`). If the server rejects it, the
///   previous setting comes back; if the device is offline, it is kept and
///   uploaded with the next session sync.
/// * A specific language picked while signed out is kept locally and
///   uploaded at the next sign-in.
/// * Otherwise, whenever a session starts (sign-in, or app start with a saved
///   session) the account's `language_pref` is applied, so a language picked
///   on another device follows the user.
@immutable
class AppLanguage {
  final String setting;

  /// A specific language picked here that the account does not have yet.
  final bool pendingUpload;

  const AppLanguage(this.setting, {this.pendingUpload = false});

  bool get followsSystem => !appLanguages.contains(setting);

  /// The forced UI locale, or null to follow the system.
  Locale? get locale => followsSystem ? null : localeForLanguage(setting);

  static const _settingKey = 'ui_language';
  static const _pendingKey = 'ui_language_pending';

  /// The setting saved on this device.
  static Future<AppLanguage> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final setting = prefs.getString(_settingKey);
      if (setting == null || !appLanguages.contains(setting)) return const AppLanguage(followSystemLanguage);
      return AppLanguage(setting, pendingUpload: prefs.getBool(_pendingKey) ?? false);
    } catch (_) {
      return const AppLanguage(followSystemLanguage);
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingKey, setting);
      await prefs.setBool(_pendingKey, pendingUpload);
    } catch (_) {
      // Not saved: the choice still applies until the app restarts.
    }
  }

  @override
  bool operator ==(Object other) =>
      other is AppLanguage && other.setting == setting && other.pendingUpload == pendingUpload;

  @override
  int get hashCode => Object.hash(setting, pendingUpload);
}

/// The setting loaded at startup (main overrides it with the saved one, so
/// the first frame is already in the right language).
final initialAppLanguageProvider = Provider<AppLanguage>((ref) => const AppLanguage(followSystemLanguage));

final appLanguageProvider = StateNotifierProvider<AppLanguageNotifier, AppLanguage>((ref) {
  return AppLanguageNotifier(
    initial: ref.read(initialAppLanguageProvider),
    saveToAccount: (code) => ref.read(userRepositoryProvider).updateProfile(languagePref: code),
    isSignedIn: () => ref.read(authStateProvider).valueOrNull != null,
    onUserUpdated: (user) => ref.read(authStateProvider.notifier).updateUser(user),
  );
});

/// What a language change ended in.
enum LanguageChange { applied, savedLater, reverted }

class AppLanguageNotifier extends StateNotifier<AppLanguage> {
  final Future<User> Function(String code) _saveToAccount;
  final bool Function() _isSignedIn;
  final void Function(User user) _onUserUpdated;

  AppLanguageNotifier({
    required AppLanguage initial,
    required Future<User> Function(String code) saveToAccount,
    required bool Function() isSignedIn,
    required void Function(User user) onUserUpdated,
  })  : _saveToAccount = saveToAccount,
        _isSignedIn = isSignedIn,
        _onUserUpdated = onUserUpdated,
        super(initial);

  void _set(AppLanguage value) {
    if (!mounted) return;
    state = value;
    value.save().ignore();
  }

  /// Applies [setting] right away; a specific language is also saved to the
  /// signed in account (see [AppLanguage] for what happens on failure).
  Future<LanguageChange> select(String setting) async {
    final previous = state;
    if (setting == previous.setting) return LanguageChange.applied;
    final specific = appLanguages.contains(setting);
    if (!specific || !_isSignedIn()) {
      _set(AppLanguage(specific ? setting : followSystemLanguage, pendingUpload: specific));
      return specific ? LanguageChange.savedLater : LanguageChange.applied;
    }
    _set(AppLanguage(setting));
    try {
      final user = await _saveToAccount(setting);
      _onUserUpdated(user);
      return LanguageChange.applied;
    } catch (e) {
      // Superseded by a later choice: leave that one alone.
      if (state.setting != setting) return LanguageChange.applied;
      if (e is DioException && e.response == null) {
        _set(AppLanguage(setting, pendingUpload: true));
        return LanguageChange.savedLater;
      }
      _set(previous);
      return LanguageChange.reverted;
    }
  }

  /// Called when a session starts with [user]: uploads a language picked
  /// while signed out (or offline), otherwise applies the account's.
  Future<void> syncWithAccount(User user) async {
    final current = state;
    if (current.followsSystem) return;
    if (current.pendingUpload) {
      try {
        final updated = await _saveToAccount(current.setting);
        _onUserUpdated(updated);
        if (state == current) _set(AppLanguage(current.setting));
      } catch (_) {
        // Still pending; tried again at the next session start.
      }
      return;
    }
    final pref = user.languagePref;
    if (appLanguages.contains(pref) && pref != current.setting) _set(AppLanguage(pref));
  }
}
