import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/sync/sync_service.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/reader/presentation/providers/reader_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
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
