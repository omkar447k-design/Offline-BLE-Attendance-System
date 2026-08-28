import XLSX from 'xlsx';
import { db } from '../config/db.js';

export class ExcelService {
  /**
   * Generates a formatted Excel workbook buffer for a single session
   */
  static generateSessionExcel(session, attendanceRecords) {
    const students = db.get('students').filter(s => s.division === session.division);
    const attendedStudentIds = new Set(attendanceRecords.map(a => a.studentId));

    const rows = [
      ['DEPARTMENT OF COMPUTER ENGINEERING - ATTENDANCE REPORT'],
      [`Academic Year: ${db.getSettings().academicYear}`, `Division: ${session.division}`, `Batch: ${session.batch}`],
      [`Subject: ${session.subjectName}`, `Date: ${session.date || new Date().toISOString().split('T')[0]}`, `Session ID: ${session.id}`],
      [],
      ['Sr. No.', 'Roll No.', 'PRN', 'Student Name', 'Division', 'Batch', 'Status', 'Marked Time', 'Verification Method']
    ];

    let presentCount = 0;
    let absentCount = 0;

    students.forEach((student, idx) => {
      const record = attendanceRecords.find(a => a.studentId === student.id);
      const isPresent = Boolean(record);
      if (isPresent) presentCount++;
      else absentCount++;

      rows.push([
        idx + 1,
        student.rollNo,
        student.prn,
        student.name,
        student.division,
        student.batch,
        isPresent ? 'PRESENT' : 'ABSENT',
        record ? new Date(record.timestamp).toLocaleTimeString() : '-',
        record ? record.verifiedVia || 'PIN' : '-'
      ]);
    });

    rows.push([]);
    rows.push(['SUMMARY STATISTICS']);
    rows.push(['Total Students', students.length]);
    rows.push(['Present', presentCount]);
    rows.push(['Absent', absentCount]);
    rows.push(['Attendance Percentage', `${((presentCount / (students.length || 1)) * 100).toFixed(1)}%`]);

    const worksheet = XLSX.utils.aoa_to_sheet(rows);
    
    // Set column widths
    worksheet['!cols'] = [
      { wch: 8 },  // Sr No
      { wch: 10 }, // Roll No
      { wch: 14 }, // PRN
      { wch: 25 }, // Name
      { wch: 10 }, // Division
      { wch: 10 }, // Batch
      { wch: 12 }, // Status
      { wch: 15 }, // Time
      { wch: 18 }  // Method
    ];

    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, 'Attendance Report');

    return XLSX.write(workbook, { type: 'buffer', bookType: 'xlsx' });
  }

  /**
   * Generates a Master Consolidated Excel sheet for the entire department with Defaulters marked
   */
  static generateMasterReport(division = 'SY-A') {
    const students = db.get('students').filter(s => s.division === division);
    const subjects = db.get('subjects').filter(s => s.division === division);
    const allSessions = db.get('sessions').filter(s => s.division === division);
    const allAttendance = db.get('attendance').filter(s => s.division === division);

    const header = ['Sr. No.', 'Roll No.', 'PRN', 'Student Name', 'Batch'];
    subjects.forEach(sub => {
      header.push(`${sub.name} (Total)`);
      header.push(`${sub.name} (%)`);
    });
    header.push('Overall Attended');
    header.push('Total Lectures');
    header.push('Overall (%)');
    header.push('Defaulter Status (<75%)');

    const rows = [
      [`${db.getSettings().departmentName.toUpperCase()} - CONSOLIDATED ATTENDANCE REPORT`],
      [`Academic Year: ${db.getSettings().academicYear}`, `Division: ${division}`, `Generated: ${new Date().toLocaleDateString()}`],
      [],
      header
    ];

    let defaulterCount = 0;

    students.forEach((student, idx) => {
      const row = [idx + 1, student.rollNo, student.prn, student.name, student.batch];
      let studentTotalAttended = 0;
      let studentTotalSessions = 0;

      subjects.forEach(sub => {
        const subSessions = allSessions.filter(s => s.subjectId === sub.id);
        const subAttendance = allAttendance.filter(a => a.studentId === student.id && a.subjectId === sub.id);
        const attended = subAttendance.length;
        const total = subSessions.length;
        const pct = total > 0 ? ((attended / total) * 100).toFixed(1) : '100.0';

        studentTotalAttended += attended;
        studentTotalSessions += total;

        row.push(`${attended}/${total}`);
        row.push(`${pct}%`);
      });

      const overallPct = studentTotalSessions > 0
        ? ((studentTotalAttended / studentTotalSessions) * 100).toFixed(1)
        : '100.0';
      const isDefaulter = Number(overallPct) < 75.0;
      if (isDefaulter) defaulterCount++;

      row.push(studentTotalAttended);
      row.push(studentTotalSessions);
      row.push(`${overallPct}%`);
      row.push(isDefaulter ? '⚠️ DEFAULTER (<75%)' : '✅ SAFE');

      rows.push(row);
    });

    rows.push([]);
    rows.push(['DEPARTMENT SUMMARY']);
    rows.push(['Total Enrolled Students', students.length]);
    rows.push(['Total Defaulters (<75%)', defaulterCount]);
    rows.push(['Overall Compliance Rate', `${(((students.length - defaulterCount) / (students.length || 1)) * 100).toFixed(1)}%`]);

    const worksheet = XLSX.utils.aoa_to_sheet(rows);
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, `Master ${division}`);

    return XLSX.write(workbook, { type: 'buffer', bookType: 'xlsx' });
  }
}
