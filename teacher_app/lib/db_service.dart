// ============================================================
// FILE: teacher_app/lib/db_service.dart
// ADD THIS FILE to teacher_app/lib/ folder
// ============================================================

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBService {
  static Database? _database;
  static final DBService instance = DBService._init();

  DBService._init();

  // ── Get Database ──────────────────────────────────────────
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('attendance.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  // ── Create All Tables ─────────────────────────────────────
  Future _createDB(Database db, int version) async {
    // 1. Departments Table
    await db.execute('''
      CREATE TABLE departments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    // 2. Divisions Table
    await db.execute('''
      CREATE TABLE divisions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        department_id INTEGER NOT NULL,
        FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE,
        UNIQUE(name, department_id)
      )
    ''');

    // 3. Students Table (class list per division)
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        prn TEXT NOT NULL,
        name TEXT NOT NULL,
        division_id INTEGER NOT NULL,
        FOREIGN KEY (division_id) REFERENCES divisions(id) ON DELETE CASCADE,
        UNIQUE(prn, division_id)
      )
    ''');

    // 4. Sessions Table
    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject TEXT NOT NULL,
        classroom TEXT NOT NULL,
        department TEXT NOT NULL,
        division TEXT NOT NULL,
        session_key TEXT NOT NULL,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        duration_minutes INTEGER NOT NULL
      )
    ''');

    // 5. Attendance Table
    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        prn TEXT NOT NULL,
        student_name TEXT NOT NULL,
        marked_time INTEGER NOT NULL,
        device_id TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
      )
    ''');

    // 6. Cheat Log Table
    await db.execute('''
      CREATE TABLE cheat_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        device_id TEXT NOT NULL,
        original_prn TEXT NOT NULL,
        original_name TEXT NOT NULL,
        attempted_prn TEXT NOT NULL,
        attempted_name TEXT NOT NULL,
        attempt_time INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
      )
    ''');
  }

  // ════════════════════════════════════════════════════════════
  // DEPARTMENT OPERATIONS
  // ════════════════════════════════════════════════════════════

  // Add Department
  Future<int> addDepartment(String name) async {
    final db = await database;
    return await db.insert(
      'departments',
      {'name': name.toUpperCase().trim()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // Get All Departments
  Future<List<Map<String, dynamic>>> getDepartments() async {
    final db = await database;
    return await db.query('departments', orderBy: 'name ASC');
  }

  // Delete Department
  Future<int> deleteDepartment(int id) async {
    final db = await database;
    return await db.delete('departments', where: 'id = ?', whereArgs: [id]);
  }

  // ════════════════════════════════════════════════════════════
  // DIVISION OPERATIONS
  // ════════════════════════════════════════════════════════════

  // Add Division
  Future<int> addDivision(String name, int departmentId) async {
    final db = await database;
    return await db.insert(
      'divisions',
      {'name': name.toUpperCase().trim(), 'department_id': departmentId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // Get Divisions by Department
  Future<List<Map<String, dynamic>>> getDivisionsByDept(int departmentId) async {
    final db = await database;
    return await db.query(
      'divisions',
      where: 'department_id = ?',
      whereArgs: [departmentId],
      orderBy: 'name ASC',
    );
  }

  // Get All Divisions with Department Name
  Future<List<Map<String, dynamic>>> getAllDivisionsWithDept() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT divisions.id, divisions.name, departments.name as dept_name
      FROM divisions
      JOIN departments ON divisions.department_id = departments.id
      ORDER BY departments.name, divisions.name
    ''');
  }

  // Delete Division
  Future<int> deleteDivision(int id) async {
    final db = await database;
    return await db.delete('divisions', where: 'id = ?', whereArgs: [id]);
  }

  // ════════════════════════════════════════════════════════════
  // STUDENT (CLASS LIST) OPERATIONS
  // ════════════════════════════════════════════════════════════

  // Add Single Student
  Future<int> addStudent(String prn, String name, int divisionId) async {
    final db = await database;
    return await db.insert(
      'students',
      {
        'prn': prn.trim(),
        'name': name.trim(),
        'division_id': divisionId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Bulk Import Students (from CSV)
  Future<void> importStudents(List<Map<String, String>> students, int divisionId) async {
    final db = await database;
    final batch = db.batch();

    for (final student in students) {
      batch.insert(
        'students',
        {
          'prn': student['prn']!.trim(),
          'name': student['name']!.trim(),
          'division_id': divisionId,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // Get Students by Division
  Future<List<Map<String, dynamic>>> getStudentsByDivision(int divisionId) async {
    final db = await database;
    return await db.query(
      'students',
      where: 'division_id = ?',
      whereArgs: [divisionId],
      orderBy: 'name ASC',
    );
  }

  // Get Division ID by Dept + Div name
  Future<int?> getDivisionId(String deptName, String divName) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT divisions.id FROM divisions
      JOIN departments ON divisions.department_id = departments.id
      WHERE departments.name = ? AND divisions.name = ?
    ''', [deptName.toUpperCase(), divName.toUpperCase()]);
    if (result.isEmpty) return null;
    return result.first['id'] as int;
  }

  // Delete All Students in Division (before re-import)
  Future<void> clearStudentsInDivision(int divisionId) async {
    final db = await database;
    await db.delete('students', where: 'division_id = ?', whereArgs: [divisionId]);
  }

  // ════════════════════════════════════════════════════════════
  // SESSION OPERATIONS
  // ════════════════════════════════════════════════════════════

  // Save Session
  Future<int> saveSession({
    required String subject,
    required String classroom,
    required String department,
    required String division,
    required String sessionKey,
    required int startTime,
    required int durationMinutes,
  }) async {
    final db = await database;
    return await db.insert('sessions', {
      'subject': subject,
      'classroom': classroom,
      'department': department,
      'division': division,
      'session_key': sessionKey,
      'start_time': startTime,
      'duration_minutes': durationMinutes,
    });
  }

  // Update Session End Time
  Future<void> endSession(int sessionId) async {
    final db = await database;
    await db.update(
      'sessions',
      {'end_time': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  // Get All Sessions
  Future<List<Map<String, dynamic>>> getAllSessions() async {
    final db = await database;
    return await db.query('sessions', orderBy: 'start_time DESC');
  }

  // Get Sessions by Subject + Dept + Division (for master sheet)
  Future<List<Map<String, dynamic>>> getSessionsFiltered({
    required String subject,
    required String department,
    required String division,
  }) async {
    final db = await database;
    return await db.query(
      'sessions',
      where: 'subject = ? AND department = ? AND division = ?',
      whereArgs: [subject, department, division],
      orderBy: 'start_time ASC',
    );
  }

  // ════════════════════════════════════════════════════════════
  // ATTENDANCE OPERATIONS
  // ════════════════════════════════════════════════════════════

  // Save Attendance Record
  Future<int> saveAttendance({
    required int sessionId,
    required String prn,
    required String studentName,
    required String deviceId,
  }) async {
    final db = await database;
    return await db.insert(
      'attendance',
      {
        'session_id': sessionId,
        'prn': prn,
        'student_name': studentName,
        'marked_time': DateTime.now().millisecondsSinceEpoch,
        'device_id': deviceId,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // Get Attendance by Session (for single session sheet)
  Future<List<Map<String, dynamic>>> getAttendanceBySession(int sessionId) async {
    final db = await database;
    return await db.query(
      'attendance',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'marked_time ASC',
    );
  }

  // Get All Attendance for Master Sheet
  // Returns: { prn, student_name, session_id, marked_time }
  Future<List<Map<String, dynamic>>> getAttendanceForMasterSheet({
    required String subject,
    required String department,
    required String division,
  }) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT attendance.prn, attendance.student_name, 
             attendance.session_id, attendance.marked_time,
             sessions.start_time as session_date
      FROM attendance
      JOIN sessions ON attendance.session_id = sessions.id
      WHERE sessions.subject = ? 
        AND sessions.department = ? 
        AND sessions.division = ?
      ORDER BY sessions.start_time ASC, attendance.prn ASC
    ''', [subject, department, division]);
  }

  // ════════════════════════════════════════════════════════════
  // CHEAT LOG OPERATIONS
  // ════════════════════════════════════════════════════════════

  // Save Cheat Attempt
  Future<int> saveCheatLog({
    required int sessionId,
    required String deviceId,
    required String originalPrn,
    required String originalName,
    required String attemptedPrn,
    required String attemptedName,
  }) async {
    final db = await database;
    return await db.insert('cheat_log', {
      'session_id': sessionId,
      'device_id': deviceId,
      'original_prn': originalPrn,
      'original_name': originalName,
      'attempted_prn': attemptedPrn,
      'attempted_name': attemptedName,
      'attempt_time': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Get Cheat Log by Session
  Future<List<Map<String, dynamic>>> getCheatLog(int sessionId) async {
    final db = await database;
    return await db.query(
      'cheat_log',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'attempt_time ASC',
    );
  }

  // ════════════════════════════════════════════════════════════
  // CLOSE DATABASE
  // ════════════════════════════════════════════════════════════

  Future close() async {
    final db = await database;
    db.close();
  }
}
