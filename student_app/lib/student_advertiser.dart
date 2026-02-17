import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'device_service.dart';

class StudentAdvertiser {
  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();
  bool _isAdvertising = false;

  Future<bool> startAdvertising({
    required String prn,
    required String name,
    required String sessionToken,
  }) async {
    if (_isAdvertising) {
      await stopAdvertising();
    }

    try {
      // Check if advertising is supported
      final isSupported = await _blePeripheral.isSupported;
      if (!isSupported) {
        print('BLE Peripheral not supported');
        return false;
      }

      // Get device ID for anti-cheat (prevents same device marking with different PRN)
      final deviceId = await DeviceService.getDeviceId();
      // Use last 8 chars of device ID to save space in BLE payload
      final shortDeviceId = deviceId.length > 8
          ? deviceId.substring(deviceId.length - 8)
          : deviceId;

      // Create student data (use short keys to fit in BLE payload)
      // d = device ID (for anti-cheat)
      // p = PRN (for records)
      // n = name
      // k = session token
      final data = {
        'd': shortDeviceId,
        'p': prn.length > 12 ? prn.substring(0, 12) : prn,
        'n': name.length > 8 ? name.substring(0, 8) : name,
        'k': sessionToken,
      };

      final jsonData = json.encode(data);
      final bytes = utf8.encode(jsonData);

      // Create advertise data with different manufacturer ID (0xFFFE for students)
      final advertiseData = AdvertiseData(
        includeDeviceName: false,
        manufacturerId: 0xFFFE,
        manufacturerData: Uint8List.fromList(bytes),
      );

      final advertiseSettings = AdvertiseSettings(
        advertiseMode: AdvertiseMode.advertiseModeBalanced,
        txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
        connectable: false,
        timeout: 30000, // 30 seconds
      );

      await _blePeripheral.start(
        advertiseData: advertiseData,
        advertiseSettings: advertiseSettings,
      );

      _isAdvertising = true;
      return true;
    } catch (e) {
      print('Student BLE Advertising Error: $e');
      return false;
    }
  }

  Future<void> stopAdvertising() async {
    try {
      await _blePeripheral.stop();
      _isAdvertising = false;
    } catch (e) {
      print('Stop Advertising Error: $e');
    }
  }
}
