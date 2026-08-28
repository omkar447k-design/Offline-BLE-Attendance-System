import React, { useState, useEffect } from 'react';
import { Shield, Users, FileSpreadsheet, Settings, AlertTriangle, Download, RefreshCw, UserPlus, Unlock, Check, Search, BookOpen } from 'lucide-react';
import { api } from '../services/api';

export function AdminPortal() {
  const [activeTab, setActiveTab] = useState('overview'); // 'overview' | 'defaulters' | 'roster' | 'settings'
  const [stats, setStats] = useState(null);
  const [students, setStudents] = useState([]);
  const [teachers, setTeachers] = useState([]);
  const [subjects, setSubjects] = useState([]);
  const [settings, setSettings] = useState({});
  const [searchQuery, setSearchQuery] = useState('');
  const [divisionFilter, setDivisionFilter] = useState('SY-A');
  const [loading, setLoading] = useState(true);

  // New Student Form state
  const [showAddModal, setShowAddModal] = useState(false);
  const [newRollNo, setNewRollNo] = useState('');
  const [newPrn, setNewPrn] = useState('');
  const [newName, setNewName] = useState('');
  const [newDivision, setNewDivision] = useState('SY-A');
  const [newBatch, setNewBatch] = useState('B1');

  // Load Admin Data
  const loadData = async () => {
    setLoading(true);
    try {
      const [statsRes, studRes, teachRes, subRes, setRes] = await Promise.all([
        api.getAdminStats(),
        api.getStudents({ division: divisionFilter }),
        api.getTeachers(),
        api.getSubjects(),
        api.getSettings()
      ]);

      if (statsRes.success) setStats(statsRes.data);
      if (studRes.success) setStudents(studRes.data);
      if (teachRes.success) setTeachers(teachRes.data);
      if (subRes.success) setSubjects(subRes.data);
      if (setRes.success) setSettings(setRes.data);
    } catch (err) {
      console.error('Error loading admin data:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [divisionFilter]);

  // Reset Student Device Binding
  const handleResetDevice = async (studentId, name) => {
    if (!window.confirm(`Are you sure you want to reset the device binding for ${name}?`)) return;
    try {
      const res = await api.resetStudentDevice(studentId);
      if (res.success) {
        alert(res.message);
        loadData();
      }
    } catch (err) {
      alert(err.message || 'Failed to reset device');
    }
  };

  // Add Single Student
  const handleAddStudent = async (e) => {
    e.preventDefault();
    try {
      const res = await api.addStudent({
        rollNo: Number(newRollNo),
        prn: newPrn,
        name: newName,
        division: newDivision,
        batch: newBatch
      });

      if (res.success) {
        setShowAddModal(false);
        setNewRollNo('');
        setNewPrn('');
        setNewName('');
        loadData();
      }
    } catch (err) {
      alert(err.message || 'Failed to add student');
    }
  };

  // Update Settings
  const handleUpdateSettings = async (e) => {
    e.preventDefault();
    try {
      const res = await api.updateSettings(settings);
      if (res.success) {
        alert('Settings updated successfully');
        loadData();
      }
    } catch (err) {
      alert(err.message || 'Failed to update settings');
    }
  };

  const filteredStudents = students.filter(s => {
    const q = searchQuery.toLowerCase();
    return s.name.toLowerCase().includes(q) || String(s.rollNo).includes(q) || s.prn.includes(q);
  });

  const defaulters = students.filter(s => s.isDefaulter);

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 sm:py-8 space-y-6">
      
      {/* Header Bar */}
      <div className="bg-slate-800/80 border border-slate-700/80 rounded-3xl p-5 sm:p-6 shadow-xl flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center space-x-2">
            <span className="w-2.5 h-2.5 rounded-full bg-emerald-400"></span>
            <span className="text-xs font-bold uppercase tracking-wider text-brand-400">HOD & Department Admin Portal</span>
          </div>
          <h1 className="text-xl sm:text-2xl font-extrabold text-white">Department Administration & Compliance</h1>
          <p className="text-xs text-slate-400 mt-0.5">SY Computer Engineering • Academic Year 2025-2026</p>
        </div>

        <div className="flex items-center space-x-2">
          <a
            href={api.getMasterExcelUrl(divisionFilter)}
            download
            className="flex items-center space-x-1.5 px-4 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold shadow-lg shadow-emerald-600/30 transition"
          >
            <Download className="w-4 h-4" />
            <span>Master Excel ({divisionFilter})</span>
          </a>

          <button
            onClick={loadData}
            className="p-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 border border-slate-700 transition"
            title="Refresh Data"
          >
            <RefreshCw className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex space-x-2 border-b border-slate-800 pb-2 overflow-x-auto">
        {[
          { id: 'overview', label: '📊 Overview & Stats', icon: Shield },
          { id: 'defaulters', label: `⚠️ Defaulter List (${defaulters.length})`, icon: AlertTriangle },
          { id: 'roster', label: `👥 Student Roster (${students.length})`, icon: Users },
          { id: 'settings', label: '⚙️ Department Policies', icon: Settings }
        ].map(tab => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`px-4 py-2.5 rounded-xl text-xs sm:text-sm font-bold transition flex items-center space-x-2 whitespace-nowrap ${
              activeTab === tab.id
                ? 'bg-brand-600 text-white shadow-md shadow-brand-600/20'
                : 'text-slate-400 hover:text-white hover:bg-slate-800'
            }`}
          >
            <span>{tab.label}</span>
          </button>
        ))}
      </div>

      {/* TAB 1: OVERVIEW & STATS */}
      {activeTab === 'overview' && (
        <div className="space-y-6">
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            <div className="bg-slate-800/80 border border-slate-700/80 rounded-2xl p-5 shadow-lg">
              <span className="text-xs font-bold text-slate-400 uppercase">Total Students</span>
              <div className="text-3xl font-black text-white mt-1">{stats?.totalStudents || 0}</div>
              <p className="text-[11px] text-slate-500 mt-1">Enrolled across SY-A & SY-B</p>
            </div>

            <div className="bg-slate-800/80 border border-slate-700/80 rounded-2xl p-5 shadow-lg">
              <span className="text-xs font-bold text-slate-400 uppercase">Total Faculty</span>
              <div className="text-3xl font-black text-white mt-1">{stats?.totalTeachers || 0}</div>
              <p className="text-[11px] text-slate-500 mt-1">Active Department Teachers</p>
            </div>

            <div className="bg-slate-800/80 border border-slate-700/80 rounded-2xl p-5 shadow-lg">
              <span className="text-xs font-bold text-slate-400 uppercase">Lectures Conducted</span>
              <div className="text-3xl font-black text-brand-400 mt-1">{stats?.totalSessions || 0}</div>
              <p className="text-[11px] text-slate-500 mt-1">Total attendance sessions</p>
            </div>

            <div className="bg-slate-800/80 border border-slate-700/80 rounded-2xl p-5 shadow-lg">
              <span className="text-xs font-bold text-amber-400 uppercase">Defaulter Students</span>
              <div className="text-3xl font-black text-amber-400 mt-1">{stats?.defaulterCount || 0}</div>
              <p className="text-[11px] text-slate-500 mt-1">{stats?.defaulterPercentage}% below 75% threshold</p>
            </div>
          </div>

          {/* Department Subjects Matrix */}
          <div className="bg-slate-800/80 border border-slate-700/80 rounded-3xl p-6 shadow-xl">
            <h3 className="text-base font-extrabold text-white mb-4 flex items-center space-x-2">
              <BookOpen className="w-4 h-4 text-brand-400" />
              <span>Department Subject & Faculty Mapping</span>
            </h3>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
              {subjects.map(s => {
                const teach = teachers.find(t => t.id === s.teacherId);
                return (
                  <div key={s.id} className="p-4 rounded-2xl bg-slate-900 border border-slate-700/70">
                    <span className="text-[10px] uppercase font-bold text-brand-400">{s.code} • {s.division} ({s.type})</span>
                    <h4 className="font-bold text-white text-sm mt-0.5">{s.name}</h4>
                    <p className="text-xs text-slate-400 mt-2 flex items-center space-x-1">
                      <span>👨‍🏫</span>
                      <span>{teach ? teach.name : 'Unassigned'}</span>
                    </p>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}

      {/* TAB 2: DEFAULTERS LIST (< 75%) */}
      {activeTab === 'defaulters' && (
        <div className="bg-slate-800/80 border border-slate-700/80 rounded-3xl p-6 shadow-xl space-y-4">
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 pb-3 border-b border-slate-700/80">
            <div>
              <h3 className="text-base font-extrabold text-white flex items-center space-x-2">
                <AlertTriangle className="w-5 h-5 text-amber-400" />
                <span>Monthly Defaulter List (Attendance &lt; 75%)</span>
              </h3>
              <p className="text-xs text-slate-400 mt-0.5">Students below mandatory 75% attendance criteria</p>
            </div>

            <a
              href={api.getMasterExcelUrl(divisionFilter)}
              download
              className="flex items-center space-x-1 px-3 py-2 rounded-xl bg-amber-500/20 text-amber-300 border border-amber-500/30 text-xs font-bold hover:bg-amber-500/30 transition"
            >
              <Download className="w-3.5 h-3.5" />
              <span>Export Defaulter Report</span>
            </a>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs sm:text-sm">
              <thead className="text-slate-400 uppercase bg-slate-900/60 border-b border-slate-700">
                <tr>
                  <th className="py-3 px-3">Roll No</th>
                  <th className="py-3 px-3">PRN</th>
                  <th className="py-3 px-3">Student Name</th>
                  <th className="py-3 px-3">Division</th>
                  <th className="py-3 px-3">Batch</th>
                  <th className="py-3 px-3">Attended</th>
                  <th className="py-3 px-3">Attendance %</th>
                  <th className="py-3 px-3">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-700/60 text-slate-200">
                {defaulters.map(student => (
                  <tr key={student.id} className="hover:bg-slate-700/30 transition">
                    <td className="py-3 px-3 font-extrabold text-white">#{student.rollNo}</td>
                    <td className="py-3 px-3 text-slate-400">{student.prn}</td>
                    <td className="py-3 px-3 font-bold text-white">{student.name}</td>
                    <td className="py-3 px-3">{student.division}</td>
                    <td className="py-3 px-3">{student.batch}</td>
                    <td className="py-3 px-3">{student.attendedLectures} / {student.totalLectures}</td>
                    <td className="py-3 px-3 font-extrabold text-rose-400">{student.attendancePercentage}%</td>
                    <td className="py-3 px-3">
                      <span className="px-2 py-0.5 rounded-full bg-rose-500/20 text-rose-300 font-bold text-[11px] border border-rose-500/30">
                        ⚠️ Defaulter
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 3: STUDENT ROSTER & DEVICE RESET */}
      {activeTab === 'roster' && (
        <div className="bg-slate-800/80 border border-slate-700/80 rounded-3xl p-6 shadow-xl space-y-4">
          <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3 pb-3 border-b border-slate-700/80">
            <div className="flex items-center space-x-3">
              <select
                value={divisionFilter}
                onChange={(e) => setDivisionFilter(e.target.value)}
                className="bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-xs font-bold text-white focus:border-brand-500 outline-none"
              >
                <option value="SY-A">Division SY-A</option>
                <option value="SY-B">Division SY-B</option>
              </select>

              <div className="relative">
                <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-3" />
                <input
                  type="text"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  placeholder="Search name / roll..."
                  className="bg-slate-900 border border-slate-700 rounded-xl pl-8 pr-3 py-2 text-xs text-white placeholder-slate-500 outline-none focus:border-brand-500"
                />
              </div>
            </div>

            <button
              onClick={() => setShowAddModal(true)}
              className="flex items-center justify-center space-x-1.5 px-4 py-2 rounded-xl bg-brand-600 hover:bg-brand-500 text-white text-xs font-bold shadow-md shadow-brand-600/30 transition"
            >
              <UserPlus className="w-3.5 h-3.5" />
              <span>Add Student</span>
            </button>
          </div>

          {/* Roster Table */}
          <div className="overflow-x-auto max-h-[500px] overflow-y-auto">
            <table className="w-full text-left text-xs sm:text-sm">
              <thead className="text-slate-400 uppercase bg-slate-900/80 sticky top-0 border-b border-slate-700">
                <tr>
                  <th className="py-3 px-3">Roll No</th>
                  <th className="py-3 px-3">PRN</th>
                  <th className="py-3 px-3">Student Name</th>
                  <th className="py-3 px-3">Batch</th>
                  <th className="py-3 px-3">Attendance</th>
                  <th className="py-3 px-3">Device Lock</th>
                  <th className="py-3 px-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-700/60 text-slate-200">
                {filteredStudents.map(student => (
                  <tr key={student.id} className="hover:bg-slate-700/30 transition">
                    <td className="py-3 px-3 font-extrabold text-white">#{student.rollNo}</td>
                    <td className="py-3 px-3 text-slate-400">{student.prn}</td>
                    <td className="py-3 px-3 font-bold text-white">{student.name}</td>
                    <td className="py-3 px-3">{student.batch}</td>
                    <td className="py-3 px-3 font-bold">
                      <span className={student.isDefaulter ? 'text-rose-400' : 'text-emerald-400'}>
                        {student.attendancePercentage}%
                      </span>
                    </td>
                    <td className="py-3 px-3">
                      {student.boundDeviceId ? (
                        <span className="px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 font-semibold text-[11px] border border-emerald-500/30">
                          🔒 Bound
                        </span>
                      ) : (
                        <span className="px-2 py-0.5 rounded-full bg-slate-700 text-slate-400 font-semibold text-[11px]">
                          Unbound
                        </span>
                      )}
                    </td>
                    <td className="py-3 px-3 text-right">
                      {student.boundDeviceId && (
                        <button
                          onClick={() => handleResetDevice(student.id, student.name)}
                          className="px-2.5 py-1 rounded-lg bg-slate-800 hover:bg-rose-500/20 hover:text-rose-300 text-slate-400 border border-slate-700 text-[11px] font-bold transition"
                          title="Reset Device if student lost phone"
                        >
                          <Unlock className="w-3 h-3 inline mr-1" />
                          Reset Device
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 4: SETTINGS & POLICIES */}
      {activeTab === 'settings' && (
        <div className="bg-slate-800/80 border border-slate-700/80 rounded-3xl p-6 shadow-xl max-w-2xl mx-auto">
          <h3 className="text-base font-extrabold text-white mb-4 flex items-center space-x-2">
            <Settings className="w-4 h-4 text-brand-400" />
            <span>Global Department Attendance Policies</span>
          </h3>

          <form onSubmit={handleUpdateSettings} className="space-y-4">
            <div>
              <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                Department Name
              </label>
              <input
                type="text"
                value={settings.departmentName || ''}
                onChange={(e) => setSettings({ ...settings, departmentName: e.target.value })}
                className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3.5 py-2.5 text-sm text-white focus:border-brand-500 outline-none"
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                  Default Session Duration (Mins)
                </label>
                <input
                  type="number"
                  min="1"
                  max="15"
                  value={settings.defaultDurationMinutes || 3}
                  onChange={(e) => setSettings({ ...settings, defaultDurationMinutes: Number(e.target.value) })}
                  className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3.5 py-2.5 text-sm text-white focus:border-brand-500 outline-none"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                  Hard Max Session Cap (Mins)
                </label>
                <input
                  type="number"
                  min="3"
                  max="30"
                  value={settings.maxDurationMinutes || 10}
                  onChange={(e) => setSettings({ ...settings, maxDurationMinutes: Number(e.target.value) })}
                  className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3.5 py-2.5 text-sm text-white focus:border-brand-500 outline-none"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                PIN Rotation Interval (Seconds)
              </label>
              <input
                type="number"
                disabled
                value={10}
                className="w-full bg-slate-900/50 border border-slate-800 rounded-xl px-3.5 py-2.5 text-sm text-slate-400 outline-none cursor-not-allowed"
              />
              <p className="text-[11px] text-slate-500 mt-1">Locked at 10 seconds for optimum classroom projection anti-proxy.</p>
            </div>

            <div className="pt-3">
              <button
                type="submit"
                className="w-full py-3 rounded-xl bg-brand-600 hover:bg-brand-500 text-white font-bold text-sm shadow-lg shadow-brand-600/30 transition active:scale-[0.98]"
              >
                Save Department Settings
              </button>
            </div>
          </form>
        </div>
      )}

      {/* ADD STUDENT MODAL */}
      {showAddModal && (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-slate-800 border border-slate-700 rounded-3xl p-6 max-w-md w-full shadow-2xl">
            <h3 className="text-lg font-extrabold text-white mb-4">Add Student to Roster</h3>
            <form onSubmit={handleAddStudent} className="space-y-3">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-[11px] font-bold text-slate-300 uppercase mb-1">Roll No</label>
                  <input
                    type="number"
                    value={newRollNo}
                    onChange={(e) => setNewRollNo(e.target.value)}
                    placeholder="e.g. 31"
                    className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-sm text-white outline-none focus:border-brand-500"
                    required
                  />
                </div>
                <div>
                  <label className="block text-[11px] font-bold text-slate-300 uppercase mb-1">PRN</label>
                  <input
                    type="text"
                    value={newPrn}
                    onChange={(e) => setNewPrn(e.target.value)}
                    placeholder="20240131"
                    className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-sm text-white outline-none focus:border-brand-500"
                    required
                  />
                </div>
              </div>

              <div>
                <label className="block text-[11px] font-bold text-slate-300 uppercase mb-1">Student Full Name</label>
                <input
                  type="text"
                  value={newName}
                  onChange={(e) => setNewName(e.target.value)}
                  placeholder="e.g. Rahul Sharma"
                  className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-sm text-white outline-none focus:border-brand-500"
                  required
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-[11px] font-bold text-slate-300 uppercase mb-1">Division</label>
                  <select
                    value={newDivision}
                    onChange={(e) => setNewDivision(e.target.value)}
                    className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-sm text-white outline-none focus:border-brand-500"
                  >
                    <option value="SY-A">SY-A</option>
                    <option value="SY-B">SY-B</option>
                  </select>
                </div>
                <div>
                  <label className="block text-[11px] font-bold text-slate-300 uppercase mb-1">Batch</label>
                  <select
                    value={newBatch}
                    onChange={(e) => setNewBatch(e.target.value)}
                    className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-sm text-white outline-none focus:border-brand-500"
                  >
                    <option value="B1">B1</option>
                    <option value="B2">B2</option>
                    <option value="B3">B3</option>
                  </select>
                </div>
              </div>

              <div className="flex space-x-2 pt-3">
                <button
                  type="button"
                  onClick={() => setShowAddModal(false)}
                  className="flex-1 py-2.5 rounded-xl bg-slate-700 hover:bg-slate-600 text-slate-300 font-bold text-xs"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 py-2.5 rounded-xl bg-brand-600 hover:bg-brand-500 text-white font-bold text-xs shadow-md shadow-brand-600/30"
                >
                  Add Student
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

    </div>
  );
}
