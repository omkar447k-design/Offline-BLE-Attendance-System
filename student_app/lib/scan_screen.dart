import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'ble_scanner.dart';
import 'student_advertiser.dart';
import 'attendance_record.dart';
import 'device_service.dart';

class ScanScreen extends StatefulWidget {
  final String name;
  final String prn;

  const ScanScreen({super.key, required this.name, required this.prn});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  final BLEScanner _scanner = BLEScanner();
  final StudentAdvertiser _advertiser = StudentAdvertiser();
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isScanning = false;
  String _statusMessage = 'Ready to scan';
  List<AttendanceRecord> _records = [];
  StreamSubscription? _scanSubscription;
  String? _deviceId;
  bool _canCheckBiometrics = false;
  bool _isAuthenticating = false;
  Map<String, dynamic>? _pendingAttendance; // Store pending attendance data

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDevice();
    _checkBiometrics();
    _loadRecords();
    _startScanning();
  }

  Future<void> _checkBiometrics() async {
    try {
      _canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      _canCheckBiometrics = _canCheckBiometrics && isDeviceSupported;
    } catch (e) {
      debugPrint('Error checking biometrics: $e');
      _canCheckBiometrics = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-load records when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _loadRecords();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanSubscription?.cancel();
    _scanner.stopScanning();
    _advertiser.stopAdvertising();
    super.dispose();
  }

  Future<void> _initDevice() async {
    try {
      _deviceId = await DeviceService.getDeviceId();
    } catch (e) {
      debugPrint('Error getting device ID: $e');
    }
  }

  Future<bool> _authenticateWithBiometrics() async {
    if (_isAuthenticating) return false;

    try {
      _isAuthenticating = true;

      // Check if device supports biometrics
      if (!_canCheckBiometrics) {
        // If biometrics not available, show dialog and block
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '⚠️ This device does not support fingerprint/biometric authentication. Cannot mark attendance.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return false;
      }

      // Get available biometric types
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '⚠️ No biometrics enrolled. Please set up fingerprint in device settings.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return false;
      }

      // Authenticate using biometrics
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Verify your identity to mark attendance',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true, // Only allow fingerprint/face, no PIN
        ),
      );

      return authenticated;
    } on PlatformException catch (e) {
      debugPrint('Biometric authentication error: $e');
      if (mounted) {
        String message = 'Authentication error';
        if (e.code == 'NotEnrolled') {
          message =
              'No fingerprint enrolled. Please set up in device settings.';
        } else if (e.code == 'LockedOut') {
          message = 'Too many attempts. Try again later.';
        } else if (e.code == 'PermanentlyLockedOut') {
          message = 'Biometric disabled. Use device unlock first.';
        } else if (e.code == 'NotAvailable') {
          message = 'Biometric not available on this device.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ $message'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return false;
    } catch (e) {
      debugPrint('Biometric error: $e');
      return false;
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> _loadRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordsJson = prefs.getStringList('attendance_records') ?? [];
      if (mounted) {
        setState(() {
          _records = recordsJson
              .map((json) {
                try {
                  return AttendanceRecord.fromJson(json);
                } catch (e) {
                  return null;
                }
              })
              .whereType<AttendanceRecord>()
              .toList()
            ..sort((a, b) =>
                b.timestamp.compareTo(a.timestamp)); // Sort newest first
        });
      }
    } catch (e) {
      debugPrint('Error loading records: $e');
    }
  }

  Future<void> _saveRecord(AttendanceRecord record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordsJson = prefs.getStringList('attendance_records') ?? [];
      recordsJson.add(record.toJson());
      await prefs.setStringList('attendance_records', recordsJson);
      await _loadRecords();
    } catch (e) {
      debugPrint('Error saving record: $e');
    }
  }

  void _startScanning() async {
    if (mounted) {
      setState(() {
        _isScanning = true;
        _statusMessage = 'Scanning for attendance...';
      });
    }

    _scanSubscription = _scanner.startScanning().listen(
      (attendanceData) {
        _onAttendanceDetected(attendanceData);
      },
      onError: (e) {
        debugPrint('Scan error: $e');
      },
    );
  }

  Future<void> _onAttendanceDetected(Map<String, dynamic> data) async {
    try {
      final sessionToken = data['token'] as String;

      // Check if already marked for this session using device-level protection
      // This survives app data clearing because it uses Android device ID
      final alreadyMarked = await DeviceService.hasMarkedSession(sessionToken);
      if (alreadyMarked) {
        return; // Already marked for this session on this device
      }

      // Check if within active time window (e.g., within 2 hours of start time)
      final startTime = data['startTime'] as int;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final elapsedMinutes = (currentTime - startTime) / 1000 / 60;

      if (elapsedMinutes > 120) {
        // Session expired
        return;
      }

      // Store pending attendance and request biometric authentication
      _pendingAttendance = data;

      // Request biometric authentication before marking attendance
      final authenticated = await _authenticateWithBiometrics();
      if (!authenticated) {
        _pendingAttendance = null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '⚠️ Fingerprint authentication required to mark attendance'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      _pendingAttendance = null;

      // Mark attendance with device-level protection
      await DeviceService.markSession(sessionToken);

      final record = AttendanceRecord(
        subject: data['subject'] as String,
        classroom: data['classroom'] as String,
        timestamp: DateTime.now(),
        prn: widget.prn,
        sessionToken: sessionToken,
      );

      await _saveRecord(record);

      // Start advertising our PRN to the teacher for 30 seconds
      await _advertiser.startAdvertising(
        prn: widget.prn,
        name: widget.name,
        sessionToken: sessionToken,
      );

      // Stop advertising after 30 seconds
      Future.delayed(const Duration(seconds: 30), () {
        _advertiser.stopAdvertising();
      });

      if (mounted) {
        setState(() {
          _statusMessage = 'Attendance marked for ${data['subject']}';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Attendance marked for ${data['subject']}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Reset status after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _statusMessage = 'Scanning for attendance...';
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error marking attendance: $e');
    }
  }

  // Group records by date for better display
  Map<String, List<AttendanceRecord>> _groupRecordsByDate() {
    final grouped = <String, List<AttendanceRecord>>{};
    for (final record in _records) {
      final dateKey = record.formattedShortDate;
      grouped.putIfAbsent(dateKey, () => []).add(record);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedRecords = _groupRecordsByDate();

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.name}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecords,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            color: _isScanning ? Colors.green.shade50 : Colors.grey.shade100,
            child: Column(
              children: [
                Icon(
                  _isScanning
                      ? Icons.bluetooth_searching
                      : Icons.bluetooth_disabled,
                  size: 64,
                  color: _isScanning ? Colors.green : Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  _statusMessage,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'PRN: ${widget.prn}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _canCheckBiometrics
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _canCheckBiometrics
                          ? Colors.green.shade300
                          : Colors.red.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fingerprint,
                        size: 18,
                        color: _canCheckBiometrics
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _canCheckBiometrics
                            ? 'Fingerprint Required'
                            : 'No Biometric Available',
                        style: TextStyle(
                          fontSize: 12,
                          color: _canCheckBiometrics
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Attendance History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_records.length} records',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _records.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No attendance records yet',
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Records will appear here when you mark attendance',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: groupedRecords.length,
                    itemBuilder: (context, index) {
                      final dateKey = groupedRecords.keys.elementAt(index);
                      final dateRecords = groupedRecords[dateKey]!;
                      final firstRecord = dateRecords.first;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date header
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            color: Colors.grey.shade200,
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 16, color: Colors.grey.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  '${firstRecord.dayName}, $dateKey',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  firstRecord.relativeDate,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Records for this date
                          ...dateRecords.map((record) => Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                elevation: 1,
                                child: ListTile(
                                  leading: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.check_circle,
                                        color: Colors.green.shade700, size: 28),
                                  ),
                                  title: Text(
                                    record.subject,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.room,
                                              size: 14,
                                              color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Text(record.classroom),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.access_time,
                                              size: 14,
                                              color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Text(record.formattedTime),
                                        ],
                                      ),
                                    ],
                                  ),
                                  isThreeLine: true,
                                ),
                              )),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
