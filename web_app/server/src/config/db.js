import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const DB_FILE = path.join(__dirname, '../../attendance_db.json');

// Default SY Computer Department seed data
const initialData = {
  settings: {
    departmentName: 'Second Year (SY) Computer Engineering',
    academicYear: '2025-2026',
    defaultDurationMinutes: 3,
    maxDurationMinutes: 10,
    pinRotationSeconds: 10,
    pinToleranceSeconds: 12,
    adminPassword: 'admin' // default admin access key
  },
  teachers: [
    { id: 'T101', name: 'Dr. A. K. Sharma', email: 'sharma@college.edu', role: 'Teacher', subjects: ['SUB101', 'SUB104'] },
    { id: 'T102', name: 'Prof. S. R. Patil', email: 'patil@college.edu', role: 'Teacher', subjects: ['SUB102', 'SUB105'] },
    { id: 'T103', name: 'Prof. N. V. Deshmukh', email: 'deshmukh@college.edu', role: 'Teacher', subjects: ['SUB103'] }
  ],
  subjects: [
    { id: 'SUB101', code: 'CS201', name: 'Operating Systems', division: 'SY-A', type: 'Theory', teacherId: 'T101' },
    { id: 'SUB102', code: 'CS202', name: 'Database Management Systems (DBMS)', division: 'SY-A', type: 'Theory', teacherId: 'T102' },
    { id: 'SUB103', code: 'CS203', name: 'Computer Networks (CN)', division: 'SY-A', type: 'Theory', teacherId: 'T103' },
    { id: 'SUB104', code: 'CS204', name: 'OS Practical Lab', division: 'SY-A', type: 'Lab', teacherId: 'T101' },
    { id: 'SUB105', code: 'CS205', name: 'DBMS Practical Lab', division: 'SY-A', type: 'Lab', teacherId: 'T102' },
    { id: 'SUB106', code: 'CS201-B', name: 'Operating Systems', division: 'SY-B', type: 'Theory', teacherId: 'T101' }
  ],
  students: [
    { id: 'S01', rollNo: 1, prn: '20240101', name: 'Aarav Mehta', division: 'SY-A', batch: 'B1', boundDeviceId: null, boundFingerprint: null },
    { id: 'S02', rollNo: 2, prn: '20240102', name: 'Aditi Rao', division: 'SY-A', batch: 'B1', boundDeviceId: null, boundFingerprint: null },
    { id: 'S03', rollNo: 3, prn: '20240103', name: 'Akash Verma', division: 'SY-A', batch: 'B1', boundDeviceId: null, boundFingerprint: null },
    { id: 'S04', rollNo: 4, prn: '20240104', name: 'Ananya Joshi', division: 'SY-A', batch: 'B1', boundDeviceId: null, boundFingerprint: null },
    { id: 'S05', rollNo: 5, prn: '20240105', name: 'Atharva Kulkarni', division: 'SY-A', batch: 'B1', boundDeviceId: null, boundFingerprint: null },
    { id: 'S06', rollNo: 6, prn: '20240106', name: 'Devendra Shinde', division: 'SY-A', batch: 'B1', boundDeviceId: null, boundFingerprint: null },
    { id: 'S07', rollNo: 7, prn: '20240107', name: 'Divya Nair', division: 'SY-A', batch: 'B1', boundDeviceId: null, boundFingerprint: null },
    { id: 'S08', rollNo: 8, prn: '20240108', name: 'Gaurav Jadhav', division: 'SY-A', batch: 'B1', boundDeviceId: null, boundFingerprint: null },
    { id: 'S09', rollNo: 9, prn: '20240109', name: 'Ishita Roy', division: 'SY-A', batch: 'B1', boundDeviceId: null, boundFingerprint: null },
    { id: 'S10', rollNo: 10, prn: '20240110', name: 'Karan Malhotra', division: 'SY-A', batch: 'B1', boundDeviceId: null, boundFingerprint: null },
    { id: 'S11', rollNo: 11, prn: '20240111', name: 'Manish Kumar', division: 'SY-A', batch: 'B2', boundDeviceId: null, boundFingerprint: null },
    { id: 'S12', rollNo: 12, prn: '20240112', name: 'Neha Gupta', division: 'SY-A', batch: 'B2', boundDeviceId: null, boundFingerprint: null },
    { id: 'S13', rollNo: 13, prn: '20240113', name: 'Nikhil Chavan', division: 'SY-A', batch: 'B2', boundDeviceId: null, boundFingerprint: null },
    { id: 'S14', rollNo: 14, prn: '20240114', name: 'Pooja Hegde', division: 'SY-A', batch: 'B2', boundDeviceId: null, boundFingerprint: null },
    { id: 'S15', rollNo: 15, prn: '20240115', name: 'Pranav Mane', division: 'SY-A', batch: 'B2', boundDeviceId: null, boundFingerprint: null },
    { id: 'S16', rollNo: 16, prn: '20240116', name: 'Priya Sharma', division: 'SY-A', batch: 'B2', boundDeviceId: null, boundFingerprint: null },
    { id: 'S17', rollNo: 17, prn: '20240117', name: 'Rahul Deshmukh', division: 'SY-A', batch: 'B2', boundDeviceId: null, boundFingerprint: null },
    { id: 'S18', rollNo: 18, prn: '20240118', name: 'Rhea Sen', division: 'SY-A', batch: 'B2', boundDeviceId: null, boundFingerprint: null },
    { id: 'S19', rollNo: 19, prn: '20240119', name: 'Rohan Gaikwad', division: 'SY-A', batch: 'B2', boundDeviceId: null, boundFingerprint: null },
    { id: 'S20', rollNo: 20, prn: '20240120', name: 'Sakshi More', division: 'SY-A', batch: 'B2', boundDeviceId: null, boundFingerprint: null },
    { id: 'S21', rollNo: 21, prn: '20240121', name: 'Sameer Khan', division: 'SY-A', batch: 'B3', boundDeviceId: null, boundFingerprint: null },
    { id: 'S22', rollNo: 22, prn: '20240122', name: 'Sanket Bhosale', division: 'SY-A', batch: 'B3', boundDeviceId: null, boundFingerprint: null },
    { id: 'S23', rollNo: 23, prn: '20240123', name: 'Shruti Tawde', division: 'SY-A', batch: 'B3', boundDeviceId: null, boundFingerprint: null },
    { id: 'S24', rollNo: 24, prn: '20240124', name: 'Omkar Pawar', division: 'SY-A', batch: 'B3', boundDeviceId: null, boundFingerprint: null },
    { id: 'S25', rollNo: 25, prn: '20240125', name: 'Tanmay Salunkhe', division: 'SY-A', batch: 'B3', boundDeviceId: null, boundFingerprint: null },
    { id: 'S26', rollNo: 26, prn: '20240126', name: 'Vaishnavi Patil', division: 'SY-A', batch: 'B3', boundDeviceId: null, boundFingerprint: null },
    { id: 'S27', rollNo: 27, prn: '20240127', name: 'Varun Bhat', division: 'SY-A', batch: 'B3', boundDeviceId: null, boundFingerprint: null },
    { id: 'S28', rollNo: 28, prn: '20240128', name: 'Vedant Kadam', division: 'SY-A', batch: 'B3', boundDeviceId: null, boundFingerprint: null },
    { id: 'S29', rollNo: 29, prn: '20240129', name: 'Yashwardhan More', division: 'SY-A', batch: 'B3', boundDeviceId: null, boundFingerprint: null },
    { id: 'S30', rollNo: 30, prn: '20240130', name: 'Zoya Qureshi', division: 'SY-A', batch: 'B3', boundDeviceId: null, boundFingerprint: null }
  ],
  sessions: [],
  attendance: []
};

// Generate some sample historical attendance data so defaulter reports immediately work
function generateInitialHistoricalData(data) {
  const pastDates = [
    '2026-08-20', '2026-08-21', '2026-08-22', '2026-08-24',
    '2026-08-25', '2026-08-26', '2026-08-27'
  ];

  pastDates.forEach((date, dateIdx) => {
    data.subjects.slice(0, 3).forEach((sub, subIdx) => {
      const sessionId = `HIST_SESS_${dateIdx}_${subIdx}`;
      data.sessions.push({
        id: sessionId,
        teacherId: sub.teacherId,
        subjectId: sub.id,
        subjectName: sub.name,
        division: sub.division,
        batch: 'All',
        date: date,
        startTime: `${date}T10:00:00.000Z`,
        endTime: `${date}T10:05:00.000Z`,
        status: 'closed',
        totalPresent: 0
      });

      let presentCount = 0;
      data.students.forEach((student) => {
        // Give varying attendance to demonstrate 75% defaulters
        // e.g. Roll 6, 13, 21 have lower attendance (<75%)
        let isPresent = true;
        if ([6, 13, 21, 28].includes(student.rollNo)) {
          isPresent = Math.random() > 0.6; // ~40% attendance
        } else {
          isPresent = Math.random() > 0.15; // ~85% attendance
        }

        if (isPresent) {
          presentCount++;
          data.attendance.push({
            id: `ATT_${sessionId}_${student.id}`,
            sessionId: sessionId,
            studentId: student.id,
            rollNo: student.rollNo,
            studentName: student.name,
            division: student.division,
            batch: student.batch,
            subjectId: sub.id,
            subjectName: sub.name,
            timestamp: `${date}T10:02:${String(Math.floor(Math.random() * 50) + 10).padStart(2, '0')}.000Z`,
            status: 'Present',
            verifiedVia: 'PIN'
          });
        }
      });

      const sess = data.sessions.find(s => s.id === sessionId);
      if (sess) sess.totalPresent = presentCount;
    });
  });
}

class Database {
  constructor() {
    this.data = null;
    this.load();
  }

  load() {
    try {
      if (fs.existsSync(DB_FILE)) {
        const fileContent = fs.readFileSync(DB_FILE, 'utf-8');
        this.data = JSON.parse(fileContent);
      } else {
        this.data = JSON.parse(JSON.stringify(initialData));
        generateInitialHistoricalData(this.data);
        this.save();
      }
    } catch (err) {
      console.error('Error loading database, initializing defaults:', err.message);
      this.data = JSON.parse(JSON.stringify(initialData));
      generateInitialHistoricalData(this.data);
      this.save();
    }
  }

  save() {
    try {
      fs.writeFileSync(DB_FILE, JSON.stringify(this.data, null, 2), 'utf-8');
    } catch (err) {
      console.error('Error writing to database file:', err.message);
    }
  }

  get(collection) {
    return this.data[collection] || [];
  }

  set(collection, items) {
    this.data[collection] = items;
    this.save();
  }

  getSettings() {
    return this.data.settings;
  }

  updateSettings(newSettings) {
    this.data.settings = { ...this.data.settings, ...newSettings };
    this.save();
    return this.data.settings;
  }
}

export const db = new Database();
