import { db } from '../config/db.js';

// In-memory session device submission tracking: Map of `${sessionId}:${deviceId}` -> rollNo
const sessionDeviceSubmissions = new Map();

export class DeviceService {
  /**
   * Validates or binds a student to a device fingerprint
   */
  static verifyOrBindDevice(studentId, rollNo, deviceId, fingerprint) {
    if (!deviceId || !fingerprint) {
      return { success: false, error: 'Device fingerprint required for secure binding' };
    }

    const students = db.get('students');
    const student = students.find(s => s.id === studentId || s.rollNo === Number(rollNo));

    if (!student) {
      return { success: false, error: 'Student record not found in department roster' };
    }

    // Check if this device is already bound to a DIFFERENT student
    const deviceBoundToOther = students.find(
      s => s.id !== student.id && (s.boundDeviceId === deviceId || s.boundFingerprint === fingerprint)
    );

    if (deviceBoundToOther) {
      return {
        success: false,
        error: `This device is already locked to Roll No. ${deviceBoundToOther.rollNo} (${deviceBoundToOther.name}). Multiple accounts on one device are prohibited.`
      };
    }

    // Check if this student is already bound to a DIFFERENT device
    if (student.boundDeviceId && (student.boundDeviceId !== deviceId || student.boundFingerprint !== fingerprint)) {
      return {
        success: false,
        error: `Your account is already bound to another phone. Please contact the Admin / HOD to reset your device registration.`
      };
    }

    // If not bound yet, bind now!
    if (!student.boundDeviceId) {
      student.boundDeviceId = deviceId;
      student.boundFingerprint = fingerprint;
      student.boundAt = new Date().toISOString();
      db.set('students', students);
    }

    return {
      success: true,
      student: {
        id: student.id,
        rollNo: student.rollNo,
        name: student.name,
        division: student.division,
        batch: student.batch,
        boundAt: student.boundAt
      }
    };
  }

  /**
   * Checks if this device has already submitted attendance in this active lecture session
   */
  static checkInSessionLock(sessionId, deviceId, studentRollNo) {
    const key = `${sessionId}:${deviceId}`;
    if (sessionDeviceSubmissions.has(key)) {
      const priorRollNo = sessionDeviceSubmissions.get(key);
      if (Number(priorRollNo) !== Number(studentRollNo)) {
        return {
          allowed: false,
          error: `Proxy Blocked: This phone has already submitted attendance for Roll No. ${priorRollNo} in this session.`
        };
      }
    }
    return { allowed: true };
  }

  /**
   * Records that this device has submitted in this session
   */
  static recordSessionSubmission(sessionId, deviceId, studentRollNo) {
    const key = `${sessionId}:${deviceId}`;
    sessionDeviceSubmissions.set(key, studentRollNo);
  }

  /**
   * Resets a student's device binding (Admin only)
   */
  static resetStudentDevice(studentId) {
    const students = db.get('students');
    const student = students.find(s => s.id === studentId || s.rollNo === Number(studentId));
    if (!student) return { success: false, error: 'Student not found' };

    student.boundDeviceId = null;
    student.boundFingerprint = null;
    student.boundAt = null;
    db.set('students', students);

    return { success: true, message: `Device reset successfully for Roll No. ${student.rollNo} (${student.name})` };
  }
}
