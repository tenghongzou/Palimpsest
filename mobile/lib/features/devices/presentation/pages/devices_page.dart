import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../data/device_registration.dart';
import '../../data/device_repository.dart';
import '../../domain/entities/user_device.dart';
import '../../../../core/l10n/l10n.dart';

final devicesProvider = FutureProvider.autoDispose<List<UserDevice>>((ref) {
  return ref.read(deviceRepositoryProvider).list();
});

/// This installation's device id, to mark it in the list.
final currentDeviceIdProvider = FutureProvider<String>((ref) => ref.read(deviceIdentityProvider).deviceId());

/// "登入裝置": where the account is signed in. Other devices can be removed;
/// this one is removed by signing out.
class DevicesPage extends ConsumerWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesProvider);
    final currentId = ref.watch(currentDeviceIdProvider).valueOrNull;

    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.devicesTitle)),
      body: devices.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: isNetworkError(e) ? Icons.wifi_off : Icons.error_outline,
          message: isNetworkError(e) ? l.devicesOffline : l.commonLoadFailed(describeError(e, l)),
          actionLabel: l.commonRetry,
          onAction: () => ref.invalidate(devicesProvider),
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () => ref.refresh(devicesProvider.future),
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(l.devicesIntro, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ),
              if (list.isEmpty)
                Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(l.devicesEmpty))),
              ...list.map((d) => _DeviceTile(
                    device: d,
                    isCurrent: d.deviceId == currentId,
                    onRemove: () => _remove(context, ref, d),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, UserDevice device) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.devicesRemoveTitle),
        content: Text(l.devicesRemoveConfirm(device.label(l))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.commonRemove)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(deviceRepositoryProvider).remove(device.id);
      ref.invalidate(devicesProvider);
      if (context.mounted) showSnack(context, l.devicesRemoved);
    } catch (e) {
      if (context.mounted) showSnack(context, describeError(e, l));
    }
  }
}

class _DeviceTile extends StatelessWidget {
  final UserDevice device;
  final bool isCurrent;
  final VoidCallback onRemove;

  const _DeviceTile({required this.device, required this.isCurrent, required this.onRemove});

  IconData get _icon {
    switch (device.deviceType) {
      case 'android':
        return Icons.phone_android;
      case 'ios':
        return Icons.phone_iphone;
      case 'windows':
        return Icons.desktop_windows_outlined;
      case 'macos':
        return Icons.laptop_mac;
      case 'web':
        return Icons.language;
    }
    return Icons.computer;
  }

  @override
  Widget build(BuildContext context) {
    final lastActive = device.lastActiveAt;
    final l = context.l10n;
    return ListTile(
      leading: Icon(_icon),
      title: Row(
        children: [
          Flexible(child: Text(device.label(l), maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (isCurrent)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(l.devicesThisDevice, style: const TextStyle(fontSize: 11)),
            ),
        ],
      ),
      subtitle: Text(lastActive == null ? '' : l.devicesLastActive(formatRelative(lastActive, l))),
      trailing: isCurrent
          ? null
          : IconButton(tooltip: l.devicesRemoveTitle, icon: const Icon(Icons.delete_outline), onPressed: onRemove),
    );
  }
}
