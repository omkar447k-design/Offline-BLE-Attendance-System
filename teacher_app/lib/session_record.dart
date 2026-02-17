import 'dart:convert';

class StudentAttendance {
  final String prn;
  final String name;
  final DateTime markedAt;
  final String? deviceId; // Device ID for anti-cheat tracking

  StudentAttendance({
    required this.prn,
    required this.name,
    required this.markedAt,
    this.deviceId,
  });

  String get formattedTime {
    final hour = markedAt.hour;
    final minute = markedAt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$hour12:$minute $period';
  }

  Map<String, dynamic> toMap() {
    return {
      'prn': prn,
      'name': name,
      'markedAt': markedAt.millisecondsSinceEpoch,
      'deviceId': deviceId,
    };
  }

  factory StudentAttendance.fromMap(Map<String, dynamic> map) {
    return StudentAttendance(
      prn: map['prn'] as String,
      name: map['name'] as String,
      markedAt: DateTime.fromMillisecondsSinceEpoch(map['markedAt'] as int),
      deviceId: map['deviceId'] as String?,
    );
  }
}

class SessionRecord {
  final String subject;
  final String classroom;
  final DateTime startTime;
  final DateTime endTime;
  final String sessionToken;
  final int durationMinutes;
  final List<StudentAttendance> students;

  // Day and month name constants
  static const _dayNames = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
  ];
  static const _dayNamesShort = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat'
  ];
  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  SessionRecord({
    required this.subject,
    required this.classroom,
    required this.startTime,
    required this.endTime,
    required this.sessionToken,
    required this.durationMinutes,
    this.students = const [],
  });

  String get dayName => _dayNames[startTime.weekday % 7];
  String get dayNameShort => _dayNamesShort[startTime.weekday % 7];
  String get monthName => _monthNames[startTime.month - 1];

  String get formattedStartTime {
    final hour = startTime.hour;
    final minute = startTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$hour12:$minute $period';
  }

  String get formattedEndTime {
    final hour = endTime.hour;
    final minute = endTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$hour12:$minute $period';
  }

  String get formattedDate {
    return '${startTime.day} $monthName ${startTime.year}';
  }

  String get formattedShortDate {
    return '${startTime.day} $monthName';
  }

  String get formattedFullDateTime {
    return '$dayNameShort, ${startTime.day} $monthName ${startTime.year} • $formattedStartTime';
  }

  String get relativeDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final recordDate = DateTime(startTime.year, startTime.month, startTime.day);
    final difference = today.difference(recordDate).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '$difference days ago';
    if (difference < 14) return '1 week ago';
    if (difference < 30) return '${difference ~/ 7} weeks ago';
    if (difference < 60) return '1 month ago';
    return '${difference ~/ 30} months ago';
  }

  int get studentCount => students.length;

  Map<String, dynamic> toMap() {
    return {
      'subject': subject,
      'classroom': classroom,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'sessionToken': sessionToken,
      'durationMinutes': durationMinutes,
      'students': students.map((s) => s.toMap()).toList(),
    };
  }

  String toJson() {
    return json.encode(toMap());
  }

  factory SessionRecord.fromMap(Map<String, dynamic> map) {
    return SessionRecord(
      subject: map['subject'] as String,
      classroom: map['classroom'] as String,
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] as int),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['endTime'] as int),
      sessionToken: map['sessionToken'] as String,
      durationMinutes: map['durationMinutes'] as int,
      students: (map['students'] as List<dynamic>?)
              ?.map((s) => StudentAttendance.fromMap(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  factory SessionRecord.fromJson(String source) {
    return SessionRecord.fromMap(json.decode(source) as Map<String, dynamic>);
  }

  SessionRecord copyWith({List<StudentAttendance>? students}) {
    return SessionRecord(
      subject: subject,
      classroom: classroom,
      startTime: startTime,
      endTime: endTime,
      sessionToken: sessionToken,
      durationMinutes: durationMinutes,
      students: students ?? this.students,
    );
  }
}
