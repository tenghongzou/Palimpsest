import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/database/offline_store.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/reading_settings.dart';

final readerSettingsProvider = StateNotifierProvider<ReaderSettingsNotifier, ReadingSettings>((ref) {
  final api = ref.read(apiClientProvider);
  return ReaderSettingsNotifier(
    store: ref.read(offlineStoreProvider),
    remote: ReadingSettingsRemote(api),
    isSignedIn: () => api.hasAccessToken,
  );
});

/// GET/PUT /users/me/reading-settings.
class ReadingSettingsRemote {
  final ApiClient _api;

  ReadingSettingsRemote(this._api);

  /// The saved settings and when they were saved (null if never saved).
  Future<(ReadingSettings, DateTime?)> fetch() async {
    final response = await _api.dio.get('/users/me/reading-settings');
    final data = response.data['data'] as Map<String, dynamic>;
    final updatedAt = DateTime.tryParse(data['updated_at'] as String? ?? '');
    // The server reports the zero time when the user never saved settings.
    final saved = updatedAt != null && updatedAt.year > 1;
    return (ReadingSettings.fromJson(data), saved ? updatedAt : null);
  }

  Future<void> save(ReadingSettings settings) async {
    await _api.dio.put('/users/me/reading-settings', data: settings.toApiJson());
  }
}

/// Reader preferences, persisted in local_reading_settings and, for signed in
/// users, synced with the server (the newer side wins).
class ReaderSettingsNotifier extends StateNotifier<ReadingSettings> {
  static const pushDelay = Duration(milliseconds: 800);

  final Future<OfflineStore> Function()? _store;
  final ReadingSettingsRemote? _remote;
  final bool Function() _isSignedIn;
  DateTime? _localUpdatedAt;
  Timer? _pushTimer;

  ReaderSettingsNotifier({
    Future<OfflineStore> Function()? store,
    ReadingSettingsRemote? remote,
    bool Function()? isSignedIn,
  })  : _store = store,
        _remote = remote,
        _isSignedIn = isSignedIn ?? _never,
        super(const ReadingSettings());

  static bool _never() => false;

  /// Load persisted settings from local SQLite on app startup.
  Future<void> loadFromLocal() async {
    try {
      final loaded = await (await _store!()).loadReadingSettings();
      if (loaded != null && mounted) {
        state = loaded.$1;
        _localUpdatedAt = loaded.$2;
      }
    } catch (_) {
      // If DB read fails, keep defaults
    }
  }

  /// Applies the server's settings when they are newer than the local ones,
  /// otherwise uploads the local ones.
  Future<void> syncWithServer() async {
    final remote = _remote;
    if (remote == null || !_isSignedIn()) return;
    try {
      final (settings, remoteUpdatedAt) = await remote.fetch();
      final local = _localUpdatedAt;
      if (remoteUpdatedAt != null && (local == null || remoteUpdatedAt.isAfter(local))) {
        if (!mounted) return;
        state = settings;
        _localUpdatedAt = remoteUpdatedAt;
        await _saveLocal(remoteUpdatedAt);
      } else if (local != null) {
        await remote.save(state);
      }
    } catch (_) {
      // Offline or signed out: local settings stay in effect.
    }
  }

  /// Replaces every setting at once (e.g. from the settings page).
  void replace(ReadingSettings settings) {
    state = settings;
    _persist();
  }

  void updateFontSize(int size) {
    state = state.copyWith(fontSize: size.clamp(12, 36));
    _persist();
  }

  void updateTheme(String theme) {
    state = state.copyWith(theme: theme);
    _persist();
  }

  void updateLineHeight(double height) {
    state = state.copyWith(lineHeight: height.clamp(1.2, 3.0));
    _persist();
  }

  void updateReadingMode(String mode) {
    state = state.copyWith(readingMode: mode);
    _persist();
  }

  void updatePageAnimation(String animation) {
    state = state.copyWith(pageAnimation: animation);
    _persist();
  }

  void updateLetterSpacing(double spacing) {
    state = state.copyWith(letterSpacing: spacing.clamp(0.0, 5.0));
    _persist();
  }

  void updateMargin(int margin) {
    state = state.copyWith(margin: margin.clamp(0, 64));
    _persist();
  }

  void updateFontFamily(String family) {
    state = state.copyWith(fontFamily: family);
    _persist();
  }

  void updateBrightness(int brightness) {
    state = state.copyWith(brightness: brightness.clamp(10, 100));
    _persist();
  }

  void updateKeepScreenOn(bool keep) {
    state = state.copyWith(keepScreenOn: keep);
    _persist();
  }

  void updateAutoChapter(bool auto) {
    state = state.copyWith(autoChapter: auto);
    _persist();
  }

  void resetToDefaults() {
    state = const ReadingSettings();
    _persist();
  }

  Future<void> _persist() async {
    final now = DateTime.now().toUtc();
    _localUpdatedAt = now;
    await _saveLocal(now);
    final remote = _remote;
    if (remote != null && _isSignedIn()) {
      // Debounced: a slider drag produces many changes but one upload.
      _pushTimer?.cancel();
      _pushTimer = Timer(pushDelay, () => remote.save(state).catchError((_) {}));
    }
  }

  Future<void> _saveLocal(DateTime updatedAt) async {
    final store = _store;
    if (store == null) return;
    try {
      await (await store()).saveReadingSettings(state, updatedAt: updatedAt);
    } catch (_) {
      // Non-critical: settings will be re-persisted on next change
    }
  }

  @override
  void dispose() {
    _pushTimer?.cancel();
    super.dispose();
  }
}
