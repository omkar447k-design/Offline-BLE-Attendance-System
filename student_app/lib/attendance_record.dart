import 'dart:convert';

class AttendanceRecord {
  final String subject;
  final String classroom;
  final DateTime timestamp;
  final String prn;
  final String sessionToken;

  AttendanceRecord({
    required this.subject,
    required this.classroom,
    required this.timestamp,
    required this.prn,
    required this.sessionToken,
  });

  // Day names
  static const List<String> _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  // Month names
  static const List<String> _monthNames = [
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

  String get dayName => _dayNames[timestamp.weekday - 1];

  String get monthName => _monthNames[timestamp.month - 1];

  // Full formatted date: "Saturday, 28 Dec 2025"
  String get formattedFullDate {
    return '$dayName, ${timestamp.day} $monthName ${timestamp.year}';
  }

  // Time only: "14:30"
  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  // Short date: "28/12/2025"
  String get formattedShortDate {
    return '${timestamp.day.toString().padLeft(2, '0')}/${timestamp.month.toString().padLeft(2, '0')}/${timestamp.year}';
  }

  // Date and time: "28 Dec 2025, 14:30"
  String get formattedDate {
    return '${timestamp.day} $monthName ${timestamp.year}, $formattedTime';
  }

  // Relative date: "Today", "Yesterday", or the date
  String get relativeDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final recordDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    final difference = today.difference(recordDate).inDays;

    if (difference == 0) {
      return 'Today, $formattedTime';
    } else if (difference == 1) {
      return 'Yesterday, $formattedTime';
    } else if (difference < 7) {
      return '$dayName, $formattedTime';
    } else {
      return formattedDate;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'subject': subject,
      'classroom': classroom,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'prn': prn,
      'sessionToken': sessionToken,
    };
  }

  String toJson() {
    return json.encode(toMap());
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      subject: map['subject'] as String,
      classroom: map['classroom'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      prn: map['prn'] as String,
      sessionToken: map['sessionToken'] as String,
    );
  }

  factory AttendanceRecord.fromJson(String source) {
    return AttendanceRecord.fromMap(
        json.decode(source) as Map<String, dynamic>);
  }
}
