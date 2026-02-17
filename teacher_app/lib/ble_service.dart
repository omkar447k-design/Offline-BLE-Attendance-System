import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

class BLEService {
  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();

  Future<bool> startAdvertising({
    required String subject,
    required String classroom,
    required int startTime,
    required String sessionToken,
  }) async {
    try {
      // Check if advertising is supported
      final isSupported = await _blePeripheral.isSupported;
      if (!isSupported) {
        print('BLE Peripheral not supported');
        return false;
      }

      // Create attendance data (use short keys to fit in BLE payload)
      final data = {
        's': subject.length > 15 ? subject.substring(0, 15) : subject,
        'c': classroom.length > 10 ? classroom.substring(0, 10) : classroom,
        't': startTime,
        'k': sessionToken,
      };

      final jsonData = json.encode(data);
      final bytes = utf8.encode(jsonData);

      // Create advertise data
      final advertiseData = AdvertiseData(
        includeDeviceName: false,
        manufacturerId: 0xFFFF,
        manufacturerData: Uint8List.fromList(bytes),
      );

      final advertiseSettings = AdvertiseSettings(
        advertiseMode: AdvertiseMode.advertiseModeBalanced,
        txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
        connectable: false,
        timeout: 7200000,
      );

      await _blePeripheral.start(
        advertiseData: advertiseData,
        advertiseSettings: advertiseSettings,
      );

      return true;
    } catch (e) {
      print('BLE Advertising Error: $e');
      return false;
    }
  }

  Future<void> stopAdvertising() async {
    try {
      await _blePeripheral.stop();
    } catch (e) {
      print('Stop Advertising Error: $e');
    }
  }
}
