import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'registration_screen.dart';
import 'scan_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StudentApp());
}

class StudentApp extends StatelessWidget {
  const StudentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const InitialScreen(),
    );
  }
}

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
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
          final adapterState = await FlutterBluePlus.adapterState.first;

          if (adapterState != BluetoothAdapterState.on) {
            setState(() => _status = 'Turning on Bluetooth...');

            if (Platform.isAndroid) {
              try {
                await FlutterBluePlus.turnOn();
              } catch (e) {
                debugPrint('Could not turn on Bluetooth: $e');
              }
            }

            // Wait for Bluetooth to be ready
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      } catch (e) {
        debugPrint('Bluetooth check error: $e');
      }

      setState(() => _status = 'Loading...');

      // Check if user is registered
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('student_name');
      final prn = prefs.getString('student_prn');

      // Small delay before navigation
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        if (name != null && prn != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => ScanScreen(name: name, prn: prn)),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const RegistrationScreen()),
          );
        }
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
