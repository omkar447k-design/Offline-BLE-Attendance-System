import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ble_service.dart';
import 'student_scanner.dart';
import 'session_record.dart';

class TeacherScreen extends StatefulWidget {
  const TeacherScreen({super.key});

  @override
  State<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends State<TeacherScreen>
    with WidgetsBindingObserver {
  final _subjectController = TextEditingController();
  final _classroomController = TextEditingController();
  final _durationController = TextEditingController(text: '10');

  bool _isAdvertising = false;
  int _remainingSeconds = 0;
  Timer? _timer;
  final BLEService _bleService = BLEService();
  StudentScanner? _studentScanner;

  // Session tracking
  String _currentSessionToken = '';
  DateTime? _sessionStartTime;
  List<SessionRecord> _sessionHistory = [];
  List<StudentAttendance> _currentStudents = [];
  List<CheatAttempt> _cheatAttempts = [];
  StreamSubscription? _studentSubscription;
  StreamSubscription? _cheatSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSessionHistory();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Auto-save session when app goes to background or is closed
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      if (_isAdvertising && _sessionStartTime != null) {
        _saveCurrentSession();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Save session before disposing if still active
    if (_isAdvertising && _sessionStartTime != null) {
      _saveCurrentSessionSync();
    }
    _subjectController.dispose();
    _classroomController.dispose();
    _durationController.dispose();
    _timer?.cancel();
    _studentSubscription?.cancel();
    _cheatSubscription?.cancel();
    _bleService.stopAdvertising();
    _studentScanner?.stopScanning();
    _studentScanner?.dispose();
    super.dispose();
  }

  Future<void> _loadSessionHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordsJson = prefs.getStringList('session_history') ?? [];
      if (mounted) {
        setState(() {
          _sessionHistory = recordsJson
              .map((json) {
                try {
                  return SessionRecord.fromJson(json);
                } catch (e) {
                  return null;
                }
              })
              .where((r) => r != null)
              .cast<SessionRecord>()
              .toList()
              .reversed
              .toList();
        });
      }
    } catch (e) {
      print('Error loading session history: $e');
    }
  }

  Future<void> _saveSessionRecord(SessionRecord record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordsJson = prefs.getStringList('session_history') ?? [];
      recordsJson.add(record.toJson());
      await prefs.setStringList('session_history', recordsJson);
      await _loadSessionHistory();
    } catch (e) {
      print('Error saving session: $e');
    }
  }

  // Save current session (called when app goes to background)
  Future<void> _saveCurrentSession() async {
    if (_sessionStartTime == null) return;

    final record = SessionRecord(
      subject: _subjectController.text,
      classroom: _classroomController.text,
      startTime: _sessionStartTime!,
      endTime: DateTime.now(),
      sessionToken: _currentSessionToken,
      durationMinutes: int.tryParse(_durationController.text) ?? 10,
      students: List.from(_currentStudents),
    );
    await _saveSessionRecord(record);
  }

  // Synchronous version for dispose
  void _saveCurrentSessionSync() {
    _saveCurrentSession();
  }

  String _generateSessionToken() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  void _startAttendance() async {
    if (_subjectController.text.isEmpty || _classroomController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final duration = int.tryParse(_durationController.text) ?? 10;
    _currentSessionToken = _generateSessionToken();
    _sessionStartTime = DateTime.now();
    final startTime = _sessionStartTime!.millisecondsSinceEpoch;

    setState(() {
      _isAdvertising = true;
      _remainingSeconds = duration * 60;
      _currentStudents = [];
      _cheatAttempts = [];
    });

    // Start BLE advertising
    try {
      final success = await _bleService.startAdvertising(
        subject: _subjectController.text,
        classroom: _classroomController.text,
        startTime: startTime,
        sessionToken: _currentSessionToken,
      );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start BLE advertising')),
        );
        setState(() => _isAdvertising = false);
        return;
      }
    } catch (e) {
      print('Error starting advertising: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error starting BLE advertising')),
        );
        setState(() => _isAdvertising = false);
      }
      return;
    }

    // Start scanning for student responses
    try {
      _studentScanner = StudentScanner();
      await _studentScanner!.startScanning(_currentSessionToken);
      _studentSubscription = _studentScanner!.studentStream.listen((student) {
        if (mounted) {
          setState(() {
            _currentStudents = _studentScanner!.students;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('✓ ${student.name} (${student.prn}) marked present'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }, onError: (e) {
        print('Student stream error: $e');
      });

      // Listen for cheating attempts
      _cheatSubscription = _studentScanner!.cheatStream.listen((cheat) {
        if (mounted) {
          setState(() {
            _cheatAttempts = _studentScanner!.cheatAttempts;
          });
          // Show warning for cheat attempt
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '⚠️ CHEAT DETECTED! ${cheat.attemptedName} (${cheat.attemptedPrn}) tried from same device as ${cheat.originalName} (${cheat.originalPrn})'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }, onError: (e) {
        print('Cheat stream error: $e');
      });
    } catch (e) {
      print('Error starting student scanner: $e');
    }

    // Start countdown timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remainingSeconds--;
          if (_remainingSeconds <= 0) {
            _stopAttendance();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _stopAttendance() async {
    _timer?.cancel();
    _studentSubscription?.cancel();
    _studentSubscription = null;
    _cheatSubscription?.cancel();
    _cheatSubscription = null;

    try {
      await _bleService.stopAdvertising();
    } catch (e) {
      print('Error stopping advertising: $e');
    }

    try {
      await _studentScanner?.stopScanning();
    } catch (e) {
      print('Error stopping scanner: $e');
    }

    // Save session record with students
    if (_sessionStartTime != null) {
      final record = SessionRecord(
        subject: _subjectController.text,
        classroom: _classroomController.text,
        startTime: _sessionStartTime!,
        endTime: DateTime.now(),
        sessionToken: _currentSessionToken,
        durationMinutes: int.tryParse(_durationController.text) ?? 10,
        students: List.from(_currentStudents),
      );
      await _saveSessionRecord(record);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Session saved: ${record.subject} (${record.studentCount} students)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }

    // Cleanup scanner
    _studentScanner?.dispose();
    _studentScanner = null;

    if (mounted) {
      setState(() {
        _isAdvertising = false;
        _remainingSeconds = 0;
        _sessionStartTime = null;
        _currentStudents = [];
      });
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher - Attendance'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showHistoryDialog(),
            tooltip: 'Session History',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.book),
              ),
              enabled: !_isAdvertising,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _classroomController,
              decoration: const InputDecoration(
                labelText: 'Classroom',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.room),
              ),
              enabled: !_isAdvertising,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _durationController,
              decoration: const InputDecoration(
                labelText: 'Duration (minutes)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.timer),
              ),
              keyboardType: TextInputType.number,
              enabled: !_isAdvertising,
            ),
            const SizedBox(height: 24),
            if (_isAdvertising) ...[
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Icon(Icons.bluetooth_searching,
                          size: 48, color: Colors.green),
                      const SizedBox(height: 12),
                      const Text(
                        'Broadcasting Attendance',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_subjectController.text} • ${_classroomController.text}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        'Token: $_currentSessionToken',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _formatTime(_remainingSeconds),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentStudents.length} Students Present',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Live student list
              if (_currentStudents.isNotEmpty) ...[
                const Text(
                  'Present Students:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: _currentStudents.length,
                    itemBuilder: (context, index) {
                      final student = _currentStudents[index];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.green,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                        title: Text(student.name),
                        subtitle: Text(student.prn),
                        trailing: Text(
                          student.formattedTime,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Cheat Attempts Section
              if (_cheatAttempts.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Cheating Attempts Detected (${_cheatAttempts.length})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 120),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _cheatAttempts.length,
                          itemBuilder: (context, index) {
                            final cheat = _cheatAttempts[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Original: ${cheat.originalName} (${cheat.originalPrn})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  Text(
                                    'Tried as: ${cheat.attemptedName} (${cheat.attemptedPrn})',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                  Text(
                                    'Device ID: ${cheat.deviceId}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ElevatedButton(
                onPressed: _stopAttendance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Stop Attendance',
                    style: TextStyle(fontSize: 18)),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: _startAttendance,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Start Attendance',
                    style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 32),
              // Recent Sessions Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Sessions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_sessionHistory.length} total',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_sessionHistory.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(Icons.history,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'No sessions yet',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...(_sessionHistory.take(5).map((record) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => _showSessionDetails(record),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text(
                            '${record.studentCount}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          record.subject,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${record.classroom} • ${record.relativeDate}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              record.formattedStartTime,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                            ),
                            const Icon(Icons.chevron_right, size: 20),
                          ],
                        ),
                      ),
                    ))),
            ],
          ],
        ),
      ),
    );
  }

  void _showSessionDetails(SessionRecord record) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionDetailsScreen(record: record),
      ),
    );
  }

  void _showHistoryDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Session History',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _sessionHistory.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No session history',
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _sessionHistory.length,
                      itemBuilder: (context, index) {
                        final record = _sessionHistory[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: ListTile(
                            onTap: () {
                              Navigator.pop(context);
                              _showSessionDetails(record);
                            },
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue,
                              child: Text(
                                '${record.studentCount}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              record.subject,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${record.classroom}\n${record.dayNameShort}, ${record.formattedDate} • ${record.formattedStartTime}',
                            ),
                            isThreeLine: true,
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  record.relativeDate,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Session Details Screen
class SessionDetailsScreen extends StatelessWidget {
  final SessionRecord record;

  const SessionDetailsScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(record.subject),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Session Info Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.blue.shade50,
            child: Column(
              children: [
                Text(
                  record.subject,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.room, size: 16, color: Colors.grey.shade700),
                    const SizedBox(width: 4),
                    Text(
                      record.classroom,
                      style:
                          TextStyle(fontSize: 16, color: Colors.grey.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${record.dayName}, ${record.formattedDate}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${record.formattedStartTime} - ${record.formattedEndTime}',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  record.relativeDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${record.studentCount} Students Present',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Student List Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  flex: 1,
                  child:
                      Text('#', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const Expanded(
                  flex: 3,
                  child: Text('PRN',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const Expanded(
                  flex: 3,
                  child: Text('Name',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const Expanded(
                  flex: 2,
                  child: Text('Time',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Student List
          Expanded(
            child: record.students.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No students recorded',
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This session was from an older version\nor no students marked attendance',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: record.students.length,
                    itemBuilder: (context, index) {
                      final student = record.students[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                student.prn,
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(student.name),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                student.formattedTime,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
