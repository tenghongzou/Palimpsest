import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/uuid.dart';
import '../domain/entities/user_device.dart';
import 'device_repository.dart';

final deviceIdentityProvider = Provider<DeviceIdentity>((ref) => DeviceIdentity());

final deviceRegistrationProvider = Provider<DeviceRegistration>((ref) {
  return DeviceRegistration(ref.read(deviceRepositoryProvider), ref.read(deviceIdentityProvider));
});

/// This installation's stable id, platform and readable name.
class DeviceIdentity {
  /// Kept across sign-outs: it identifies the installation, not the user.
  static const prefsKey = 'device_install_id';

  Future<String>? _id;

  /// Generated once per installation and persisted in shared preferences.
  Future<String> deviceId() => _id ??= _loadId();

  Future<String> _loadId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(prefsKey);
    if (saved != null && saved.isNotEmpty) return saved;
    final id = generateUuidV4();
    await prefs.setString(prefsKey, id);
    return id;
  }

  String get deviceType => kIsWeb ? 'web' : platformDeviceType(Platform.operatingSystem);

  String get deviceName {
    if (kIsWeb) return deviceTypeLabel('web');
    String host = '';
    try {
      host = Platform.localHostname;
    } catch (_) {}
    return describeDevice(Platform.operatingSystem, Platform.operatingSystemVersion, host);
  }
}

/// Maps `Platform.operatingSystem` onto the API's device types.
String platformDeviceType(String os) {
  switch (os) {
    case 'android':
    case 'ios':
    case 'windows':
    case 'macos':
    case 'linux':
      return os;
  }
  // fuchsia and others: closest supported type.
  return 'linux';
}

/// A readable name without a device-info plugin. On Android the OS version
/// string is the kernel's, so only the platform is used; on iOS and macOS the
/// version is "Version 17.0 (Build ...)"; desktops add their host name.
String describeDevice(String os, String osVersion, String hostname) {
  final version = RegExp(r'Version ([\d.]+)').firstMatch(osVersion)?.group(1);
  final host = hostname.trim();
  switch (os) {
    case 'android':
      return 'Android 裝置';
    case 'ios':
      return version == null ? 'iPhone / iPad' : 'iPhone / iPad（iOS $version）';
    case 'macos':
      return version == null ? 'Mac' : 'Mac（macOS $version）';
    case 'windows':
    case 'linux':
      final label = deviceTypeLabel(os);
      return host.isEmpty || host == 'localhost' ? label : '$label（$host）';
  }
  return deviceTypeLabel(platformDeviceType(os));
}

/// Registers this installation with the server once per launch and signed-in
/// user, and removes it again on sign-out.
class DeviceRegistration {
  final DeviceRepository _repo;
  final DeviceIdentity _identity;

  /// Supplies the FCM/APNs token once push notifications are set up (no
  /// Firebase project yet, so it is null). On a token refresh, call
  /// [ensureRegistered] with `force: true` to upload the new token.
  final Future<String?> Function()? pushToken;

  String? _registeredFor;
  String? _recordId;
  Future<void>? _inFlight;

  DeviceRegistration(this._repo, this._identity, {this.pushToken});

  /// The server's record id of this device, once registered.
  String? get recordId => _recordId;

  /// Registers unless already done for [userId] during this launch. Failures
  /// (e.g. offline) are swallowed; the next call (app resume) retries.
  Future<void> ensureRegistered(String userId, {bool force = false}) {
    if (!force && _registeredFor == userId) return Future.value();
    return _inFlight ??= _register(userId).whenComplete(() => _inFlight = null);
  }

  Future<void> _register(String userId) async {
    try {
      final device = await _repo.register(DeviceRegistrationInput(
        deviceId: await _identity.deviceId(),
        deviceType: _identity.deviceType,
        deviceName: _identity.deviceName,
        pushToken: await pushToken?.call(),
      ));
      _recordId = device.id;
      _registeredFor = userId;
    } catch (_) {}
  }

  /// Removes this device's record while still signed in. Best effort: when
  /// it was not registered this launch, the record is looked up by device id.
  Future<void> unregister() async {
    final inFlight = _inFlight;
    if (inFlight != null) await inFlight;
    try {
      var id = _recordId;
      if (id == null) {
        final mine = await _identity.deviceId();
        for (final d in await _repo.list()) {
          if (d.deviceId == mine) id = d.id;
        }
      }
      if (id != null) await _repo.remove(id);
    } catch (_) {
    } finally {
      forget();
    }
  }

  /// Forgets the registration (signed out), so the next sign-in registers.
  void forget() {
    _registeredFor = null;
    _recordId = null;
  }
}
