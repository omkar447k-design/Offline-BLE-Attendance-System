import { db } from '../config/db.js';
import { PinService } from '../services/pinService.js';
import { ExcelService } from '../services/excelService.js';

export class TeacherController {
  // Get active session or start a new one
  static getActiveSession(req, res) {
    const { teacherId } = req.query;
    const sessions = db.get('sessions');
    const active = sessions.find(s => s.status === 'active' && (!teacherId || s.teacherId === teacherId));

    if (!active) {
      return res.json({ success: true, active: false });
    }

    // Check if session has exceeded duration
    const now = new Date();
    const endTime = new Date(active.endTime);
    if (now > endTime) {
      active.status = 'closed';
      db.set('sessions', sessions);
      return res.json({ success: true, active: false, message: 'Session auto-closed (time expired)' });
    }

    const pinInfo = PinService.getCurrentPinInfo(active.id);
    const attendance = db.get('attendance').filter(a => a.sessionId === active.id);
    const totalStudents = db.get('students').filter(s => s.division === active.division).length;

    const remainingSessionMs = Math.max(0, endTime.getTime() - now.getTime());
    const remainingSessionSec = Math.ceil(remainingSessionMs / 1000);

    res.json({
      success: true,
      active: true,
      session: {
        ...active,
        remainingSessionSec,
        pinInfo,
        totalPresent: attendance.length,
        totalStudents,
        attendees: attendance
      }
    });
  }

  // Start a new Attendance Session
  static startSession(req, res) {
    const { teacherId, subjectId, division = 'SY-A', batch = 'All', durationMinutes = 3 } = req.body;
    const subjects = db.get('subjects');
    const subject = subjects.find(s => s.id === subjectId) || { name: 'Class Lecture', id: subjectId };

    const sessions = db.get('sessions');
    // Close any previous active session for this teacher
    sessions.forEach(s => {
      if (s.teacherId === teacherId && s.status === 'active') {
        s.status = 'closed';
      }
    });

    const startTime = new Date();
    const settings = db.getSettings();
    const effectiveDuration = Math.min(Number(durationMinutes) || settings.defaultDurationMinutes, settings.maxDurationMinutes);
    const endTime = new Date(startTime.getTime() + effectiveDuration * 60 * 1000);
    const sessionId = `SESS_${Date.now()}`;

    const newSession = {
      id: sessionId,
      teacherId: teacherId || 'T101',
      subjectId: subject.id,
      subjectName: subject.name,
      division,
      batch,
      date: startTime.toISOString().split('T')[0],
      startTime: startTime.toISOString(),
      endTime: endTime.toISOString(),
      durationMinutes: effectiveDuration,
      status: 'active',
      totalPresent: 0
    };

    sessions.push(newSession);
    db.set('sessions', sessions);

    const pinInfo = PinService.getCurrentPinInfo(sessionId);

    res.json({
      success: true,
      session: {
        ...newSession,
        remainingSessionSec: effectiveDuration * 60,
        pinInfo,
        totalPresent: 0,
        totalStudents: db.get('students').filter(s => s.division === division).length,
        attendees: []
      }
    });
  }

  // Extend active session duration (+1 or +2 mins)
  static extendSession(req, res) {
    const { sessionId, extraMinutes = 1 } = req.body;
    const sessions = db.get('sessions');
    const session = sessions.find(s => s.id === sessionId && s.status === 'active');

    if (!session) {
      return res.status(404).json({ success: false, error: 'Active session not found' });
    }

    const currentEnd = new Date(session.endTime);
    const newEnd = new Date(currentEnd.getTime() + Number(extraMinutes) * 60 * 1000);
    session.endTime = newEnd.toISOString();
    session.durationMinutes += Number(extraMinutes);

    db.set('sessions', sessions);

    const remainingSessionSec = Math.max(0, Math.ceil((newEnd.getTime() - Date.now()) / 1000));
    res.json({ success: true, remainingSessionSec, session });
  }

  // End active session
  static endSession(req, res) {
    const { sessionId } = req.body;
    const sessions = db.get('sessions');
    const session = sessions.find(s => s.id === sessionId);

    if (!session) {
      return res.status(404).json({ success: false, error: 'Session not found' });
    }

    session.status = 'closed';
    session.endTime = new Date().toISOString();
    db.set('sessions', sessions);

    const attendance = db.get('attendance').filter(a => a.sessionId === sessionId);
    session.totalPresent = attendance.length;
    db.set('sessions', sessions);

    res.json({ success: true, message: 'Session closed successfully', totalPresent: attendance.length });
  }

  // Manual Attendance Override (e.g. for phone battery dead)
  static manualMark(req, res) {
    const { sessionId, studentId } = req.body;
    const sessions = db.get('sessions');
    const session = sessions.find(s => s.id === sessionId);
    if (!session) return res.status(404).json({ success: false, error: 'Session not found' });

    const students = db.get('students');
    const student = students.find(s => s.id === studentId || s.rollNo === Number(studentId));
    if (!student) return res.status(404).json({ success: false, error: 'Student not found' });

    const attendance = db.get('attendance');
    const alreadyMarked = attendance.find(a => a.sessionId === sessionId && a.studentId === student.id);
    if (alreadyMarked) {
      return res.json({ success: true, message: 'Student is already marked present' });
    }

    const record = {
      id: `ATT_${sessionId}_${student.id}`,
      sessionId,
      studentId: student.id,
      rollNo: student.rollNo,
      studentName: student.name,
      division: student.division,
      batch: student.batch,
      subjectId: session.subjectId,
      subjectName: session.subjectName,
      timestamp: new Date().toISOString(),
      status: 'Present',
      verifiedVia: 'Manual Override'
    };

    attendance.push(record);
    db.set('attendance', attendance);

    session.totalPresent = (session.totalPresent || 0) + 1;
    db.set('sessions', sessions);

    res.json({ success: true, data: record });
  }

  // Export Session Excel
  static exportSessionExcel(req, res) {
    const { sessionId } = req.params;
    const sessions = db.get('sessions');
    const session = sessions.find(s => s.id === sessionId);
    if (!session) return res.status(404).json({ success: false, error: 'Session not found' });

    const attendance = db.get('attendance').filter(a => a.sessionId === sessionId);
    const buffer = ExcelService.generateSessionExcel(session, attendance);

    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename=Attendance_${session.subjectName.replace(/\s+/g, '_')}_${session.date}.xlsx`);
    res.send(buffer);
  }
}
