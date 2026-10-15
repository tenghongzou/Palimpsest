import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/database/database_helper.dart';
import 'core/sync/sync_service.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/profile/presentation/providers/app_language_provider.dart';
import 'features/reader/presentation/providers/reader_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // SQLite through FFI on Windows and Linux, before anything opens the DB.
  DatabaseHelper.ensureFactory();
  // Read before the first frame so the app opens in the chosen language.
  final language = await AppLanguage.load();
  final container = ProviderContainer(overrides: [
    initialAppLanguageProvider.overrideWithValue(language),
  ]);
  // Upload changes recorded offline whenever connectivity returns.
  container.read(syncServiceProvider).listenForConnectivity();
  container.read(readerSettingsProvider.notifier).loadFromLocal().ignore();
  // Restoring the session signs the user in, which triggers the first sync
  // (see PalimpsestApp).
  container.read(authStateProvider.notifier).tryRestoreSession().ignore();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PalimpsestApp(),
    ),
  );
}
