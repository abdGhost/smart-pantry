import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _key = 'device_user_id';

/// Returns a stable per-device user ID (generated once, stored in SharedPreferences).
/// Each installation gets its own ID so pantry data is isolated per user/device.
Future<String> getOrCreateDeviceUserId() async {
  final prefs = await SharedPreferences.getInstance();
  String? id = prefs.getString(_key);
  if (id == null || id.isEmpty) {
    id = const Uuid().v4();
    await prefs.setString(_key, id);
  }
  return id;
}
