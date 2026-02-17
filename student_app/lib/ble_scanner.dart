import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BLEScanner {
  StreamSubscription? _scanSubscription;
  final Set<String> _processedTokens = {};

  Stream<Map<String, dynamic>> startScanning() async* {
    final controller = StreamController<Map<String, dynamic>>();

    try {
      // Turn on Bluetooth if off
      if (await FlutterBluePlus.isSupported) {
        await FlutterBluePlus.turnOn();
      }

      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: const Duration(days: 1),
        continuousUpdates: true,
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (var result in results) {
          final manufacturerData = result.advertisementData.manufacturerData;

          if (manufacturerData.isNotEmpty) {
            // Check for our manufacturer ID (0xFFFF = 65535)
            final data =
                manufacturerData[65535] ?? manufacturerData.values.first;

            try {
              final jsonString = utf8.decode(data);
              final rawData = json.decode(jsonString) as Map<String, dynamic>;

              // Check if this looks like our attendance data
              if (rawData.containsKey('s') && rawData.containsKey('k')) {
                // Convert shortened keys to full keys
                final attendanceData = {
                  'subject': rawData['s'] as String,
                  'classroom': rawData['c'] as String,
                  'startTime': rawData['t'] as int,
                  'token': rawData['k'] as String,
                };

                final token = attendanceData['token'] as String;

                // Only emit if we haven't processed this token in this scan session
                if (!_processedTokens.contains(token)) {
                  _processedTokens.add(token);
                  if (!controller.isClosed) {
                    controller.add(attendanceData);
                  }
                }
              }
            } catch (e) {
              // Not our data, ignore
            }
          }
        }
      });

      yield* controller.stream;
    } catch (e) {
      print('BLE Scan Error: $e');
      controller.close();
    }
  }

  Future<void> stopScanning() async {
    await _scanSubscription?.cancel();
    await FlutterBluePlus.stopScan();
    _processedTokens.clear();
  }
}
