import { db } from '../config/db.js';
import { PinService } from '../services/pinService.js';
import { DeviceService } from '../services/deviceService.js';

export class StudentController {
  // Student Login & Device Binding
  static login(req, res) {
    const { rollNo, prn, division = 'SY-A', deviceId, fingerprint } = req.body;
    if (!rollNo) {
      return res.status(400).json({ success: false, error: 'Roll Number is required' });
    }

    const students = db.get('students');
    const student = students.find(
      s => s.rollNo === Number(rollNo) && s.division === division && (!prn || s.prn === String(prn))
    );

    if (!student) {
      return res.status(404).json({ success: false, error: `Student with Roll No. ${rollNo} not found in ${division}` });
    }

    // Verify or bind device fingerprint
    const bindResult = DeviceService.verifyOrBindDevice(student.id, student.rollNo, deviceId, fingerprint);
    if (!bindResult.success) {
      return res.status(403).json(bindResult);
    }

    res.json({
      success: true,
      student: bindResult.student,
      token: `std_tok_${student.id}_${Date.now()}`
    });
  }

  // Get active session for student's division
  static getActiveSession(req, res) {
    const { division = 'SY-A', studentId } = req.query;
    const sessions = db.get('sessions');
    const active = sessions.find(s => s.status === 'active' && s.division === division);

    if (!active) {
      return res.json({ success: true, hasActiveSession: false });
    }

    // Check if session has timed out
    const now = new Date();
    const endTime = new Date(active.endTime);
    if (now > endTime) {
      active.status = 'closed';
      db.set('sessions', sessions);
      return res.json({ success: true, hasActiveSession: false });
    }

    const attendance = db.get('attendance');
    const alreadyMarked = studentId
      ? attendance.some(a => a.sessionId === active.id && a.studentId === studentId)
      : false;

    const remainingSec = Math.max(0, Math.ceil((endTime.getTime() - now.getTime()) / 1000));

    res.json({
      success: true,
      hasActiveSession: true,
      session: {
        id: active.id,
        subjectName: active.subjectName,
        division: active.division,
        batch: active.batch,
        remainingSec,
        alreadyMarked
      }
    });
  }

  // Submit PIN for attendance
  static submitPin(req, res) {
    const { studentId, rollNo, sessionId, pin, deviceId, fingerprint } = req.body;

    if (!studentId || !sessionId || !pin) {
      return res.status(400).json({ success: false, error: 'Student ID, Session ID, and PIN are required' });
    }

    const sessions = db.get('sessions');
    const session = sessions.find(s => s.id === sessionId && s.status === 'active');
    if (!session) {
      return res.status(400).json({ success: false, error: 'This attendance session has ended or is not active.' });
    }

    // Check session duration time
    const now = new Date();
    if (now > new Date(session.endTime)) {
      session.status = 'closed';
      db.set('sessions', sessions);
      return res.status(400).json({ success: false, error: 'Attendance window has closed for this lecture.' });
    }

    // Device Verification
    const students = db.get('students');
    const student = students.find(s => s.id === studentId || s.rollNo === Number(rollNo));
    if (!student) {
      return res.status(404).json({ success: false, error: 'Student record not found' });
    }

    // In-Session Device Lock: 1 device cannot submit for multiple roll numbers
    const lockCheck = DeviceService.checkInSessionLock(sessionId, deviceId, student.rollNo);
    if (!lockCheck.allowed) {
      return res.status(403).json({ success: false, error: lockCheck.error });
    }

    // Validate PIN (with 10-12s sliding grace tolerance)
    const pinCheck = PinService.validatePin(sessionId, pin);
    if (!pinCheck.valid) {
      return res.status(400).json({ success: false, error: pinCheck.reason });
    }

    // Check if already marked
    const attendance = db.get('attendance');
    const existing = attendance.find(a => a.sessionId === sessionId && a.studentId === student.id);
    if (existing) {
      return res.json({
        success: true,
        alreadyMarked: true,
        message: 'You are already marked Present for this lecture.',
        record: existing
      });
    }

    // Create attendance record
    const record = {
      id: `ATT_${sessionId}_${student.id}`,
      sessionId: session.id,
      studentId: student.id,
      rollNo: student.rollNo,
      studentName: student.name,
      division: student.division,
      batch: student.batch,
      subjectId: session.subjectId,
      subjectName: session.subjectName,
      timestamp: now.toISOString(),
      status: 'Present',
      verifiedVia: '4-Digit PIN'
    };

    attendance.push(record);
    db.set('attendance', attendance);

    session.totalPresent = (session.totalPresent || 0) + 1;
    db.set('sessions', sessions);

    // Record device lock for this session
    DeviceService.recordSessionSubmission(sessionId, deviceId, student.rollNo);

    // Broadcast attendance update via WebSocket if available
    if (req.app.get('io')) {
      req.app.get('io').to(sessionId).emit('student_attended', record);
    }

    res.json({
      success: true,
      message: '✅ Attendance recorded successfully!',
      record
    });
  }

  // Student Dashboard Personal Analytics & Defaulter Calculator
  static getDashboard(req, res) {
    const { studentId } = req.params;
    const students = db.get('students');
    const student = students.find(s => s.id === studentId || s.rollNo === Number(studentId));

    if (!student) {
      return res.status(404).json({ success: false, error: 'Student not found' });
    }

    const sessions = db.get('sessions').filter(s => s.division === student.division);
    const attendance = db.get('attendance').filter(a => a.studentId === student.id);
    const subjects = db.get('subjects').filter(s => s.division === student.division);

    const totalLectures = sessions.length;
    const attendedLectures = attendance.length;
    const overallPercentage = totalLectures > 0
      ? Number(((attendedLectures / totalLectures) * 100).toFixed(1))
      : 100.0;

    // Calculate how many more consecutive classes needed to reach 75% if below 75
    let lecturesNeededFor75 = 0;
    if (overallPercentage < 75.0 && totalLectures > 0) {
      // (attended + x) / (total + x) >= 0.75 => x >= (0.75 * total - attended) / 0.25
      lecturesNeededFor75 = Math.max(0, Math.ceil((0.75 * totalLectures - attendedLectures) / 0.25));
    }

    // Subject-wise stats
    const subjectStats = subjects.map(sub => {
      const subSessions = sessions.filter(s => s.subjectId === sub.id);
      const subAttended = attendance.filter(a => a.subjectId === sub.id);
      const pct = subSessions.length > 0
        ? Number(((subAttended.length / subSessions.length) * 100).toFixed(1))
        : 100.0;

      return {
        id: sub.id,
        name: sub.name,
        code: sub.code,
        type: sub.type,
        total: subSessions.length,
        attended: subAttended.length,
        percentage: pct,
        isSafe: pct >= 75.0
      };
    });

    // Recent 10 history logs
    const history = attendance
      .slice(-10)
      .reverse()
      .map(a => ({
        id: a.id,
        subjectName: a.subjectName,
        timestamp: a.timestamp,
        status: a.status,
        verifiedVia: a.verifiedVia
      }));

    res.json({
      success: true,
      data: {
        student: {
          id: student.id,
          rollNo: student.rollNo,
          prn: student.prn,
          name: student.name,
          division: student.division,
          batch: student.batch
        },
        stats: {
          overallPercentage,
          totalLectures,
          attendedLectures,
          isDefaulter: overallPercentage < 75.0,
          lecturesNeededFor75
        },
        subjectStats,
        recentHistory: history
      }
    });
  }
}
