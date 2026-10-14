import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../data/device_registration.dart';
import '../../data/device_repository.dart';
import '../../domain/entities/user_device.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('登入裝置')),
      body: devices.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: isNetworkError(e) ? Icons.wifi_off : Icons.error_outline,
          message: isNetworkError(e) ? '目前離線，連線後即可查看登入裝置' : '載入失敗：${describeError(e)}',
          actionLabel: '重試',
          onAction: () => ref.invalidate(devicesProvider),
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () => ref.refresh(devicesProvider.future),
          child: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('以下裝置目前登入你的帳號。移除後，該裝置不會再收到通知推播，直到它再次開啟 App。',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
              ),
              if (list.isEmpty)
                const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('沒有登入裝置'))),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除裝置'),
        content: Text('確定要移除「${device.label}」嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('移除')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(deviceRepositoryProvider).remove(device.id);
      ref.invalidate(devicesProvider);
      if (context.mounted) showSnack(context, '已移除裝置');
    } catch (e) {
      if (context.mounted) showSnack(context, describeError(e));
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
    return ListTile(
      leading: Icon(_icon),
      title: Row(
        children: [
          Flexible(child: Text(device.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (isCurrent)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('此裝置', style: TextStyle(fontSize: 11)),
            ),
        ],
      ),
      subtitle: Text(lastActive == null ? '' : '最後活動：${formatRelative(lastActive)}'),
      trailing: isCurrent
          ? null
          : IconButton(tooltip: '移除裝置', icon: const Icon(Icons.delete_outline), onPressed: onRemove),
    );
  }
}
