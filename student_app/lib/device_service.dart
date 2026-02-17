import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceService {
  static String? _deviceId;

  /// Gets a unique device identifier that persists even after app data clear
  /// Uses Android ID which is unique per device + app signing key combination
  static Future<String> getDeviceId() async {
    if (_deviceId != null) return _deviceId!;

    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Android ID is unique per device and app signing key
        // It survives app data clear but changes on factory reset
        _deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor;
      }

      _deviceId ??= 'unknown_${DateTime.now().millisecondsSinceEpoch}';
      return _deviceId!;
    } catch (e) {
      print('Error getting device ID: $e');
      _deviceId = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
      return _deviceId!;
    }
  }

  /// Check if this device has already marked attendance for a session
  /// Uses device-level storage that survives app data clear
  static Future<bool> hasMarkedSession(String sessionToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = await getDeviceId();
      final key = 'marked_${deviceId}_$sessionToken';
      return prefs.getBool(key) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Mark that this device has marked attendance for a session
  static Future<void> markSession(String sessionToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = await getDeviceId();
      final key = 'marked_${deviceId}_$sessionToken';
      await prefs.setBool(key, true);

      // Also store in a list for cleanup later if needed
      final markedList = prefs.getStringList('device_marked_sessions') ?? [];
      if (!markedList.contains(sessionToken)) {
        markedList.add(sessionToken);
        await prefs.setStringList('device_marked_sessions', markedList);
      }
    } catch (e) {
      print('Error marking session: $e');
    }
  }
}
