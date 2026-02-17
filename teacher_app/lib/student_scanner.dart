import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'session_record.dart';

// Class to track cheating attempts
class CheatAttempt {
  final String deviceId;
  final String originalPrn;
  final String originalName;
  final String attemptedPrn;
  final String attemptedName;
  final DateTime attemptTime;

  CheatAttempt({
    required this.deviceId,
    required this.originalPrn,
    required this.originalName,
    required this.attemptedPrn,
    required this.attemptedName,
    required this.attemptTime,
  });
}

class StudentScanner {
  StreamSubscription? _scanSubscription;
  // Track by DEVICE ID to prevent same phone marking twice with different PRN
  final Set<String> _detectedDeviceIds = {};
  // Map device ID to original student info for cheat detection
  final Map<String, StudentAttendance> _deviceToStudent = {};
  final List<StudentAttendance> _students = [];
  final List<CheatAttempt> _cheatAttempts = [];
  StreamController<StudentAttendance>? _studentController;
  StreamController<CheatAttempt>? _cheatController;
  bool _isScanning = false;

  Stream<StudentAttendance> get studentStream {
    _studentController ??= StreamController<StudentAttendance>.broadcast();
    return _studentController!.stream;
  }

  Stream<CheatAttempt> get cheatStream {
    _cheatController ??= StreamController<CheatAttempt>.broadcast();
    return _cheatController!.stream;
  }

  List<StudentAttendance> get students => List.unmodifiable(_students);
  List<CheatAttempt> get cheatAttempts => List.unmodifiable(_cheatAttempts);
  int get studentCount => _students.length;
  int get cheatAttemptCount => _cheatAttempts.length;

  Future<void> startScanning(String sessionToken) async {
    if (_isScanning) return;

    _detectedDeviceIds.clear();
    _deviceToStudent.clear();
    _students.clear();
    _cheatAttempts.clear();
    _isScanning = true;

    // Create fresh controllers
    _studentController?.close();
    _studentController = StreamController<StudentAttendance>.broadcast();
    _cheatController?.close();
    _cheatController = StreamController<CheatAttempt>.broadcast();

    try {
      // Check if Bluetooth is supported and turn on
      if (await FlutterBluePlus.isSupported) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (e) {
          print('Could not turn on Bluetooth: $e');
        }
      }

      // Stop any existing scan first
      try {
        await FlutterBluePlus.stopScan();
      } catch (e) {
        // Ignore
      }

      // Start scanning for student responses
      await FlutterBluePlus.startScan(
        timeout: const Duration(hours: 2),
        continuousUpdates: true,
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (!_isScanning) return;

        for (var result in results) {
          try {
            final manufacturerData = result.advertisementData.manufacturerData;

            if (manufacturerData.isNotEmpty) {
              // Check for our manufacturer ID (0xFFFE = 65534 for students)
              final data = manufacturerData[65534] ?? manufacturerData[65535];
              if (data == null) continue;

              try {
                final jsonString = utf8.decode(data);
                final rawData = json.decode(jsonString) as Map<String, dynamic>;

                // Check if this is a student attendance response
                // Now requires: d (device ID), p (PRN), n (name), k (token)
                if (rawData.containsKey('p') &&
                    rawData.containsKey('n') &&
                    rawData.containsKey('k')) {
                  final token = rawData['k'] as String;

                  // Only process if it matches our session token
                  if (token == sessionToken) {
                    // Get device ID - use it to prevent same device marking twice
                    // If no device ID (old app version), fall back to PRN
                    final deviceId =
                        rawData['d'] as String? ?? rawData['p'] as String;
                    final prn = rawData['p'] as String;
                    final name = rawData['n'] as String;

                    // Check by DEVICE ID - prevents same phone with different PRN
                    if (!_detectedDeviceIds.contains(deviceId)) {
                      _detectedDeviceIds.add(deviceId);

                      // Store PRN and name for the attendance record
                      final student = StudentAttendance(
                        prn: prn,
                        name: name,
                        markedAt: DateTime.now(),
                        deviceId: deviceId, // Store device ID for reference
                      );

                      _students.add(student);
                      _deviceToStudent[deviceId] = student;

                      if (_studentController != null &&
                          !_studentController!.isClosed) {
                        _studentController!.add(student);
                      }
                    } else {
                      // CHEAT DETECTED! Same device trying with different PRN
                      final originalStudent = _deviceToStudent[deviceId];
                      if (originalStudent != null &&
                          (originalStudent.prn != prn ||
                              originalStudent.name != name)) {
                        // Check if we already recorded this exact cheat attempt
                        final alreadyRecorded = _cheatAttempts.any((c) =>
                            c.deviceId == deviceId && c.attemptedPrn == prn);

                        if (!alreadyRecorded) {
                          final cheat = CheatAttempt(
                            deviceId: deviceId,
                            originalPrn: originalStudent.prn,
                            originalName: originalStudent.name,
                            attemptedPrn: prn,
                            attemptedName: name,
                            attemptTime: DateTime.now(),
                          );

                          _cheatAttempts.add(cheat);

                          if (_cheatController != null &&
                              !_cheatController!.isClosed) {
                            _cheatController!.add(cheat);
                          }
                        }
                      }
                    }
                  }
                }
              } catch (e) {
                // Not valid JSON, ignore
              }
            }
          } catch (e) {
            // Error processing result, continue
          }
        }
      }, onError: (e) {
        print('Scan results error: $e');
      });
    } catch (e) {
      print('Student Scan Error: $e');
      _isScanning = false;
    }
  }

  Future<void> stopScanning() async {
    _isScanning = false;

    try {
      await _scanSubscription?.cancel();
      _scanSubscription = null;
    } catch (e) {
      print('Error canceling scan subscription: $e');
    }

    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      print('Error stopping scan: $e');
    }
  }

  void dispose() {
    _isScanning = false;
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _studentController?.close();
    _studentController = null;
    _cheatController?.close();
    _cheatController = null;
  }
}
