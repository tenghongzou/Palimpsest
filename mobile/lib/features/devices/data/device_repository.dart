import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/entities/user_device.dart';

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceRepository(ref.read(apiClientProvider));
});

/// /users/me/devices.
class DeviceRepository {
  final ApiClient _api;

  DeviceRepository(this._api);

  /// Most recently active first.
  Future<List<UserDevice>> list() async {
    final response = await _api.dio.get('/users/me/devices');
    return (response.data['data'] as List? ?? const [])
        .map((e) => UserDevice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Registers this installation, or refreshes it when already registered.
  Future<UserDevice> register(DeviceRegistrationInput input) async {
    final response = await _api.dio.post('/users/me/devices', data: input.toJson());
    return UserDevice.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// [id] is the record's `id`, not its `device_id`.
  Future<void> remove(String id) => _api.dio.delete('/users/me/devices/$id');
}
