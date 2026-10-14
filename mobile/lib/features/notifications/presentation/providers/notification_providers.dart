import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/pagination/paged_notifier.dart';
import '../../data/notification_repository.dart';
import '../../domain/entities/app_notification.dart';

/// Unread notification count shown on the bell. Refreshed on sign in, on app
/// start and resume, and every [UnreadCountNotifier.pollInterval] while the
/// app is in the foreground (see PalimpsestApp).
final unreadCountProvider = StateNotifierProvider<UnreadCountNotifier, int>((ref) {
  final api = ref.read(apiClientProvider);
  return UnreadCountNotifier(ref.read(notificationRepositoryProvider), isSignedIn: () => api.hasAccessToken);
});

class UnreadCountNotifier extends StateNotifier<int> {
  static const pollInterval = Duration(seconds: 60);

  final NotificationRepository _repo;
  final bool Function() _isSignedIn;
  Timer? _timer;

  UnreadCountNotifier(this._repo, {required bool Function() isSignedIn})
      : _isSignedIn = isSignedIn,
        super(0);

  bool get isPolling => _timer != null;

  /// Asks the server; failures (e.g. offline) keep the last known count.
  Future<void> refresh() async {
    if (!_isSignedIn()) {
      if (mounted) state = 0;
      return;
    }
    try {
      final count = await _repo.unreadCount();
      if (mounted) state = count < 0 ? 0 : count;
    } catch (_) {}
  }

  void startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (_) => refresh());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  void set(int count) => state = count < 0 ? 0 : count;

  void decrement() => set(state - 1);

  /// Signed out: forget the count and stop asking.
  void reset() {
    stopPolling();
    state = 0;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}

/// The notifications list, newest first.
final notificationsProvider =
    StateNotifierProvider.autoDispose<PagedNotifier<AppNotification>, PagedState<AppNotification>>((ref) {
  final repo = ref.read(notificationRepositoryProvider);
  return PagedNotifier((page) => repo.list(page: page));
});
