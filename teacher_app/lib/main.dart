import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'teacher_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TeacherApp());
}

class TeacherApp extends StatelessWidget {
  const TeacherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Teacher Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const PermissionScreen(),
    );
  }
}

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  String _status = 'Initializing...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      setState(() => _status = 'Requesting permissions...');

      // Request permissions based on platform
      if (Platform.isAndroid) {
        await [
          Permission.bluetooth,
          Permission.bluetoothScan,
          Permission.bluetoothAdvertise,
          Permission.bluetoothConnect,
          Permission.location,
        ].request();
      } else if (Platform.isIOS) {
        await [
          Permission.bluetooth,
        ].request();
      }

      setState(() => _status = 'Checking Bluetooth...');

      // Wait a moment for permissions to take effect
      await Future.delayed(const Duration(milliseconds: 500));

      // Check if Bluetooth is available and try to turn it on
      try {
        if (await FlutterBluePlus.isSupported) {
          // Check adapter state
          final adapterState = await FlutterBluePlus.adapterState.first;

          if (adapterState != BluetoothAdapterState.on) {
            setState(() => _status = 'Turning on Bluetooth...');

            // Try to turn on Bluetooth (Android only)
            if (Platform.isAndroid) {
              try {
                await FlutterBluePlus.turnOn();
              } catch (e) {
                // User might have declined, continue anyway
                debugPrint('Could not turn on Bluetooth: $e');
              }
            }

            // Wait for Bluetooth to be ready
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      } catch (e) {
        debugPrint('Bluetooth check error: $e');
        // Continue anyway, the app will handle Bluetooth state later
      }

      setState(() => _status = 'Ready!');

      // Small delay before navigation
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TeacherScreen()),
        );
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
      if (mounted) {
        setState(() {
          _status = 'Error: $e';
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_hasError) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
              ] else ...[
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 24),
              ],
              Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: _hasError ? Colors.red : Colors.grey[600],
                ),
              ),
              if (_hasError) ...[
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _status = 'Retrying...';
                    });
                    _initialize();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
