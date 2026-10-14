import '../../../../core/utils/formatters.dart';

/// `DeviceType` values of the API.
const deviceTypes = ['android', 'ios', 'windows', 'macos', 'linux', 'web'];

/// A signed-in installation of the user (`Device` in the API).
class UserDevice {
  /// The server's record id, used to remove it.
  final String id;

  /// The client-generated per-installation id.
  final String deviceId;
  final String deviceType;
  final String? deviceName;
  final DateTime? lastActiveAt;
  final DateTime? createdAt;

  const UserDevice({
    required this.id,
    required this.deviceId,
    required this.deviceType,
    this.deviceName,
    this.lastActiveAt,
    this.createdAt,
  });

  factory UserDevice.fromJson(Map<String, dynamic> json) {
    final name = json['device_name'] as String?;
    return UserDevice(
      id: json['id'] as String,
      deviceId: json['device_id'] as String? ?? '',
      deviceType: json['device_type'] as String? ?? '',
      deviceName: name == null || name.isEmpty ? null : name,
      lastActiveAt: parseDateTime(json['last_active_at']),
      createdAt: parseDateTime(json['created_at']),
    );
  }

  /// The name to show: the device's own name, else its platform.
  String get label => deviceName ?? deviceTypeLabel(deviceType);
}

String deviceTypeLabel(String type) {
  switch (type) {
    case 'android':
      return 'Android 裝置';
    case 'ios':
      return 'iPhone / iPad';
    case 'windows':
      return 'Windows 電腦';
    case 'macos':
      return 'Mac';
    case 'linux':
      return 'Linux 電腦';
    case 'web':
      return '網頁版';
  }
  return '未知裝置';
}

/// What POST /users/me/devices registers.
class DeviceRegistrationInput {
  final String deviceId;
  final String deviceType;
  final String? deviceName;

  /// FCM/APNs token. Always null until push notifications are set up.
  final String? pushToken;

  const DeviceRegistrationInput({
    required this.deviceId,
    required this.deviceType,
    this.deviceName,
    this.pushToken,
  });

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'device_type': deviceType,
        if (deviceName != null && deviceName!.isNotEmpty)
          'device_name': deviceName!.length > 100 ? deviceName!.substring(0, 100) : deviceName,
        if (pushToken != null && pushToken!.isNotEmpty) 'push_token': pushToken,
      };
}
