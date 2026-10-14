import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/sync/sync_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/domain/entities/user.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/devices/data/device_registration.dart';
import 'features/notifications/presentation/providers/notification_providers.dart';
import 'features/reader/presentation/providers/reader_provider.dart';

class PalimpsestApp extends ConsumerStatefulWidget {
  const PalimpsestApp({super.key});

  @override
  ConsumerState<PalimpsestApp> createState() => _PalimpsestAppState();
}

class _PalimpsestAppState extends ConsumerState<PalimpsestApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Already signed in when the app starts (e.g. a restored session that
    // completed before the first frame).
    final user = ref.read(authStateProvider).valueOrNull;
    if (user != null) Future.microtask(() => _onSignedIn(user));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final unread = ref.read(unreadCountProvider.notifier);
    final user = ref.read(authStateProvider).valueOrNull;
    if (state == AppLifecycleState.resumed) {
      if (user != null) _onSignedIn(user);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // No polling in the background.
      unread.stopPolling();
    }
  }

  /// Per launch, sign-in and resume: register this device (once per launch)
  /// and refresh and poll the unread notification count.
  void _onSignedIn(User user) {
    if (!mounted) return;
    ref.read(deviceRegistrationProvider).ensureRegistered(user.id).ignore();
    final unread = ref.read(unreadCountProvider.notifier);
    unread.refresh().ignore();
    unread.startPolling();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    ref.listen(authStateProvider, (prev, next) {
      final before = prev?.valueOrNull;
      final user = next.valueOrNull;
      if (user == null) {
        // Signed out (logout clears the count while still signed in; this
        // also covers a session that ended another way).
        if (before != null && !next.isLoading) {
          ref.read(unreadCountProvider.notifier).reset();
          ref.read(deviceRegistrationProvider).forget();
        }
        return;
      }
      if (before?.id == user.id) return;
      // Once signed in, upload what was recorded offline and pull bookmarks
      // and reading settings changed on other devices.
      final sync = ref.read(syncServiceProvider);
      sync.requestBookmarkSync().catchError((_) {});
      sync.pushPending().ignore();
      ref.read(readerSettingsProvider.notifier).syncWithServer();
      _onSignedIn(user);
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
