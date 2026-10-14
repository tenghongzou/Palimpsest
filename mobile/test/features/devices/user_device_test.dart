import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/features/devices/data/device_registration.dart';
import 'package:palimpsest/features/devices/domain/entities/user_device.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('UserDevice', () {
    test('parses the API device', () {
      final d = UserDevice.fromJson({
        'id': 'rec',
        'device_id': 'install',
        'device_type': 'android',
        'device_name': 'Android 裝置',
        'last_active_at': '2026-10-14T08:00:00Z',
        'created_at': '2026-10-01T08:00:00Z',
      });
      expect(d.id, 'rec');
      expect(d.deviceId, 'install');
      expect(d.label, 'Android 裝置');
      expect(d.lastActiveAt, DateTime.utc(2026, 10, 14, 8));
    });

    test('falls back to the platform label without a name', () {
      final d = UserDevice.fromJson({'id': 'r', 'device_id': 'i', 'device_type': 'macos', 'device_name': ''});
      expect(d.deviceName, isNull);
      expect(d.label, 'Mac');
    });
  });

  group('DeviceRegistrationInput', () {
    test('omits the push token until there is one', () {
      const input = DeviceRegistrationInput(deviceId: 'i', deviceType: 'android', deviceName: 'Android 裝置');
      expect(input.toJson(), {'device_id': 'i', 'device_type': 'android', 'device_name': 'Android 裝置'});
      const withToken = DeviceRegistrationInput(deviceId: 'i', deviceType: 'ios', pushToken: 'tok');
      expect(withToken.toJson(), {'device_id': 'i', 'device_type': 'ios', 'push_token': 'tok'});
    });

    test('caps the name at the API limit of 100 characters', () {
      final input = DeviceRegistrationInput(deviceId: 'i', deviceType: 'linux', deviceName: 'x' * 150);
      expect((input.toJson()['device_name'] as String).length, 100);
    });
  });

  group('device naming', () {
    test('maps platforms onto API device types', () {
      for (final os in ['android', 'ios', 'windows', 'macos', 'linux']) {
        expect(platformDeviceType(os), os);
      }
      expect(platformDeviceType('fuchsia'), 'linux');
      expect(deviceTypes, containsAll(['android', 'ios', 'windows', 'macos', 'linux', 'web']));
    });

    test('describes devices readably', () {
      expect(describeDevice('android', 'Linux 5.10.43 #1 SMP PREEMPT', 'localhost'), 'Android 裝置');
      expect(describeDevice('ios', 'Version 17.4 (Build 21E213)', 'iPhone'), 'iPhone / iPad（iOS 17.4）');
      expect(describeDevice('macos', 'Version 14.5 (Build 23F79)', 'mbp'), 'Mac（macOS 14.5）');
      expect(describeDevice('windows', '"Windows 11 Pro" 10.0 (Build 26200)', 'DESKTOP-01'), 'Windows 電腦（DESKTOP-01）');
      expect(describeDevice('linux', 'Linux 6.8', ''), 'Linux 電腦');
    });
  });

  group('DeviceIdentity', () {
    test('generates the install id once and keeps it', () async {
      SharedPreferences.setMockInitialValues({});
      final first = await DeviceIdentity().deviceId();
      expect(first, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      // A new instance (next launch) reads the same id.
      expect(await DeviceIdentity().deviceId(), first);
      expect(deviceTypes, contains(DeviceIdentity().deviceType));
    });
  });
}
