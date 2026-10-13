import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/sync/sync_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  // Upload progress recorded offline, now and whenever connectivity returns.
  final sync = container.read(syncServiceProvider)..listenForConnectivity();
  sync.pushPending().ignore();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PalimpsestApp(),
    ),
  );
}
