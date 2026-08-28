import { io } from 'socket.io-client';

const API_BASE = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
  ? `http://${window.location.hostname}:5000`
  : '';

let socket = null;

export function getSocket() {
  if (!socket) {
    socket = io(API_BASE, {
      transports: ['websocket', 'polling']
    });
  }
  return socket;
}

// Generic fetch wrapper
async function request(endpoint, options = {}) {
  const url = `${API_BASE}${endpoint}`;
  const headers = {
    'Content-Type': 'application/json',
    ...(options.headers || {})
  };

  try {
    const res = await fetch(url, { ...options, headers });
    const json = await res.json();
    if (!res.ok) {
      throw new Error(json.error || json.message || `Request failed with status ${res.status}`);
    }
    return json;
  } catch (err) {
    console.error(`API Error on [${endpoint}]:`, err.message);
    throw err;
  }
}

export const api = {
  // Admin
  adminLogin: (password) => request('/api/admin/login', { method: 'POST', body: JSON.stringify({ password }) }),
  getAdminStats: () => request('/api/admin/stats'),
  getStudents: (params = {}) => {
    const query = new URLSearchParams(params).toString();
    return request(`/api/admin/students${query ? `?${query}` : ''}`);
  },
  addStudent: (data) => request('/api/admin/students', { method: 'POST', body: JSON.stringify(data) }),
  bulkImportStudents: (data) => request('/api/admin/students/bulk', { method: 'POST', body: JSON.stringify(data) }),
  resetStudentDevice: (studentId) => request(`/api/admin/students/${studentId}/reset-device`, { method: 'POST' }),
  getSettings: () => request('/api/admin/settings'),
  updateSettings: (data) => request('/api/admin/settings', { method: 'POST', body: JSON.stringify(data) }),
  getTeachers: () => request('/api/admin/teachers'),
  getSubjects: () => request('/api/admin/subjects'),
  getMasterExcelUrl: (division = 'SY-A') => `${API_BASE}/api/admin/export/master?division=${division}`,

  // Teacher
  getTeacherActiveSession: (teacherId) => request(`/api/teacher/session/active${teacherId ? `?teacherId=${teacherId}` : ''}`),
  startSession: (data) => request('/api/teacher/session/start', { method: 'POST', body: JSON.stringify(data) }),
  extendSession: (sessionId, extraMinutes = 1) => request('/api/teacher/session/extend', { method: 'POST', body: JSON.stringify({ sessionId, extraMinutes }) }),
  endSession: (sessionId) => request('/api/teacher/session/end', { method: 'POST', body: JSON.stringify({ sessionId }) }),
  manualMarkAttendance: (sessionId, studentId) => request('/api/teacher/session/manual-mark', { method: 'POST', body: JSON.stringify({ sessionId, studentId }) }),
  getSessionExcelUrl: (sessionId) => `${API_BASE}/api/teacher/session/${sessionId}/export`,

  // Student
  studentLogin: (data) => request('/api/student/login', { method: 'POST', body: JSON.stringify(data) }),
  getStudentActiveSession: (division, studentId) => request(`/api/student/session/active?division=${division || 'SY-A'}&studentId=${studentId || ''}`),
  submitPin: (data) => request('/api/student/attendance/submit', { method: 'POST', body: JSON.stringify(data) }),
  getStudentDashboard: (studentId) => request(`/api/student/dashboard/${studentId}`)
};
