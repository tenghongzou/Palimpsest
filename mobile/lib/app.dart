import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/sync/sync_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/reader/presentation/providers/reader_provider.dart';

class PalimpsestApp extends ConsumerWidget {
  const PalimpsestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    // Once signed in, upload what was recorded offline and pull bookmarks and
    // reading settings changed on other devices.
    ref.listen(authStateProvider, (prev, next) {
      final before = prev?.valueOrNull;
      final user = next.valueOrNull;
      if (user == null || before?.id == user.id) return;
      final sync = ref.read(syncServiceProvider);
      sync.requestBookmarkSync().catchError((_) {});
      sync.pushPending().ignore();
      ref.read(readerSettingsProvider.notifier).syncWithServer();
    });

    return MaterialApp.router(
      title: 'Palimpsest',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'TW'),
      supportedLocales: const [Locale('zh', 'TW'), Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
