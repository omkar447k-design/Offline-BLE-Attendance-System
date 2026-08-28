import React, { useState, useEffect } from 'react';
import { Play, Plus, Square, Download, Users, Clock, CheckCircle, RefreshCw, Sparkles, UserPlus } from 'lucide-react';
import { api, getSocket } from '../services/api';
import { TimerRing } from '../components/TimerRing';

export function TeacherPortal({ teacher }) {
  const [subjects, setSubjects] = useState([]);
  const [activeSession, setActiveSession] = useState(null);
  const [selectedSubjectId, setSelectedSubjectId] = useState('');
  const [division, setDivision] = useState('SY-A');
  const [batch, setBatch] = useState('All');
  const [durationMinutes, setDurationMinutes] = useState(3);
  const [loading, setLoading] = useState(false);
  const [manualRollNo, setManualRollNo] = useState('');

  // Load teacher subjects and check active session
  useEffect(() => {
    async function loadData() {
      try {
        const subRes = await api.getSubjects();
        if (subRes.success) {
          const teacherSubs = subRes.data.filter(s => s.teacherId === teacher.id);
          setSubjects(teacherSubs.length > 0 ? teacherSubs : subRes.data);
          if (teacherSubs.length > 0) setSelectedSubjectId(teacherSubs[0].id);
        }

        const sessRes = await api.getTeacherActiveSession(teacher.id);
        if (sessRes.success && sessRes.active) {
          setActiveSession(sessRes.session);
        }
      } catch (err) {
        console.error('Error loading teacher portal:', err);
      }
    }
    loadData();
  }, [teacher.id]);

  // Real-time WebSocket sync for live PIN and attendees
  useEffect(() => {
    const socket = getSocket();

    if (activeSession?.id) {
      socket.emit('join_session', activeSession.id);
    }

    const handlePinTick = (data) => {
      if (activeSession && data.sessionId === activeSession.id) {
        setActiveSession(prev => ({
          ...prev,
          pinInfo: data.pinInfo,
          remainingSessionSec: data.remainingSessionSec,
          totalPresent: data.totalPresent,
          totalStudents: data.totalStudents,
          attendees: data.attendees
        }));
      }
    };

    const handleSessionClosed = () => {
      setActiveSession(null);
    };

    socket.on('pin_tick', handlePinTick);
    socket.on('session_closed', handleSessionClosed);

    return () => {
      if (activeSession?.id) socket.emit('leave_session', activeSession.id);
      socket.off('pin_tick', handlePinTick);
      socket.off('session_closed', handleSessionClosed);
    };
  }, [activeSession?.id]);

  // Start Session
  const handleStartSession = async (e) => {
    e.preventDefault();
    if (!selectedSubjectId) return;
    setLoading(true);

    try {
      const res = await api.startSession({
        teacherId: teacher.id,
        subjectId: selectedSubjectId,
        division,
        batch,
        durationMinutes: Number(durationMinutes)
      });

      if (res.success) {
        setActiveSession(res.session);
      }
    } catch (err) {
      alert(err.message || 'Failed to start session');
    } finally {
      setLoading(false);
    }
  };

  // Extend Session (+1 or +2 mins)
  const handleExtend = async (mins) => {
    if (!activeSession) return;
    try {
      const res = await api.extendSession(activeSession.id, mins);
      if (res.success) {
        setActiveSession(prev => ({
          ...prev,
          remainingSessionSec: res.remainingSessionSec,
          durationMinutes: res.session.durationMinutes
        }));
      }
    } catch (err) {
      alert(err.message || 'Failed to extend session');
    }
  };

  // End Session
  const handleEndSession = async () => {
    if (!activeSession) return;
    if (!window.confirm('Are you sure you want to end this attendance session?')) return;

    try {
      const res = await api.endSession(activeSession.id);
      if (res.success) {
        // Trigger download
        window.open(api.getSessionExcelUrl(activeSession.id), '_blank');
        setActiveSession(null);
      }
    } catch (err) {
      alert(err.message || 'Failed to end session');
    }
  };

  // Manual Roll No Add
  const handleManualMark = async (e) => {
    e.preventDefault();
    if (!manualRollNo || !activeSession) return;

    try {
      const res = await api.manualMarkAttendance(activeSession.id, manualRollNo);
      if (res.success) {
        setManualRollNo('');
        // Refresh session
        const sessRes = await api.getTeacherActiveSession(teacher.id);
        if (sessRes.success && sessRes.active) setActiveSession(sessRes.session);
      }
    } catch (err) {
      alert(err.message || 'Could not mark student');
    }
  };

  const formatTime = (seconds) => {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  };

  return (
    <div className="max-w-6xl mx-auto px-4 sm:px-6 py-6 sm:py-8 space-y-6">
      
      {/* Teacher Profile Bar */}
      <div className="bg-slate-800/80 border border-slate-700/80 rounded-3xl p-5 sm:p-6 shadow-xl flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <span className="text-xs font-bold uppercase tracking-wider text-brand-400">Faculty In-Charge</span>
          <h2 className="text-xl sm:text-2xl font-extrabold text-white">{teacher.name}</h2>
          <p className="text-xs text-slate-400 mt-0.5">Department of Computer Engineering • SY Coordinator</p>
        </div>

        {activeSession && (
          <div className="flex items-center space-x-2">
            <a
              href={api.getSessionExcelUrl(activeSession.id)}
              download
              className="flex items-center space-x-1.5 px-4 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold shadow-lg shadow-emerald-600/30 transition active:scale-95"
            >
              <Download className="w-4 h-4" />
              <span>Export Lecture Sheet (.xlsx)</span>
            </a>
          </div>
        )}
      </div>

      {/* ACTIVE SESSION PROJECTOR SCREEN */}
      {activeSession ? (
        <div className="bg-gradient-to-b from-slate-900 via-slate-900 to-indigo-950/40 border-2 border-brand-500/60 rounded-3xl p-6 sm:p-10 shadow-2xl glow-indigo">
          
          <div className="flex flex-col lg:flex-row items-center justify-between gap-8">
            
            {/* Left: Huge Glowing PIN Display */}
            <div className="flex-1 text-center lg:text-left">
              <div className="inline-flex items-center space-x-2 px-3 py-1 rounded-full bg-emerald-500/20 text-emerald-300 text-xs font-bold uppercase tracking-wider mb-3 border border-emerald-500/30">
                <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
                <span>Classroom Attendance Active</span>
              </div>

              <h1 className="text-2xl sm:text-4xl font-extrabold text-white tracking-tight">
                {activeSession.subjectName}
              </h1>
              <p className="text-slate-300 text-sm mt-1">
                Division: <span className="text-brand-300 font-bold text-base">{activeSession.division}</span>
                {activeSession.batch !== 'All' ? ` • Batch: ${activeSession.batch}` : ''}
              </p>

              {/* GIANT PIN BOX */}
              <div className="my-6 inline-flex flex-col items-center p-6 sm:p-8 rounded-3xl bg-slate-950 border-2 border-brand-500/80 shadow-2xl shadow-brand-500/20">
                <span className="text-xs uppercase font-extrabold tracking-widest text-slate-400 mb-2">
                  CLASSROOM ACTIVE PIN (ROTATES IN 10s)
                </span>
                
                <div className="flex items-center space-x-3 sm:space-x-5">
                  {String(activeSession?.pinInfo?.pin || '8492').split('').map((digit, idx) => (
                    <div
                      key={idx}
                      className="w-16 h-20 sm:w-20 sm:h-24 rounded-2xl bg-gradient-to-b from-slate-800 to-slate-900 border-2 border-brand-400/80 flex items-center justify-center text-4xl sm:text-6xl font-black text-white shadow-xl shadow-brand-500/30"
                    >
                      {digit}
                    </div>
                  ))}
                </div>

                {/* 10-Second Timer Ring */}
                <div className="flex items-center space-x-3 mt-4">
                  <TimerRing
                    secondsRemaining={activeSession?.pinInfo?.secondsRemaining || 10}
                    totalSeconds={10}
                    size={46}
                    stroke={4}
                  />
                  <span className="text-xs text-slate-400 font-semibold">
                    New PIN in {activeSession?.pinInfo?.secondsRemaining || 10} seconds...
                  </span>
                </div>
              </div>

              {/* Timer Controls */}
              <div className="flex flex-wrap items-center justify-center lg:justify-start gap-3 mt-2">
                <div className="flex items-center space-x-2 px-4 py-2 rounded-xl bg-slate-800 border border-slate-700 text-white font-extrabold text-sm">
                  <Clock className="w-4 h-4 text-amber-400 animate-pulse" />
                  <span>Session Window: {formatTime(activeSession.remainingSessionSec || 0)}</span>
                </div>

                <button
                  onClick={() => handleExtend(1)}
                  className="flex items-center space-x-1 px-3.5 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-brand-300 text-xs font-bold border border-slate-700 transition"
                >
                  <Plus className="w-3.5 h-3.5" />
                  <span>+1 Min</span>
                </button>

                <button
                  onClick={() => handleExtend(2)}
                  className="flex items-center space-x-1 px-3.5 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-brand-300 text-xs font-bold border border-slate-700 transition"
                >
                  <Plus className="w-3.5 h-3.5" />
                  <span>+2 Mins</span>
                </button>

                <button
                  onClick={handleEndSession}
                  className="flex items-center space-x-1.5 px-4 py-2 rounded-xl bg-rose-600 hover:bg-rose-500 text-white text-xs font-bold shadow-lg shadow-rose-600/30 transition"
                >
                  <Square className="w-3.5 h-3.5" />
                  <span>Lock & End Session</span>
                </button>
              </div>
            </div>

            {/* Right: Live Attendee Stats */}
            <div className="w-full lg:w-80 bg-slate-950/80 border border-slate-800 rounded-3xl p-6 flex flex-col justify-between">
              <div className="text-center pb-4 border-b border-slate-800">
                <span className="text-xs font-extrabold uppercase tracking-wider text-slate-400">Total Verified Present</span>
                <div className="text-5xl font-black text-emerald-400 mt-1">
                  {activeSession.totalPresent || 0}
                  <span className="text-lg text-slate-500 font-bold"> / {activeSession.totalStudents || 30}</span>
                </div>
                <div className="text-xs text-slate-400 mt-1">
                  {((((activeSession.totalPresent || 0) / (activeSession.totalStudents || 1)) * 100).toFixed(0))}% of Division Present
                </div>
              </div>

              {/* Manual Mark Input for Dead Battery */}
              <form onSubmit={handleManualMark} className="mt-4">
                <label className="block text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-1">
                  Manual Override (Dead Battery)
                </label>
                <div className="flex space-x-2">
                  <input
                    type="number"
                    value={manualRollNo}
                    onChange={(e) => setManualRollNo(e.target.value)}
                    placeholder="Roll No"
                    className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-1.5 text-xs text-white outline-none focus:border-brand-500"
                  />
                  <button
                    type="submit"
                    className="px-3 py-1.5 rounded-xl bg-brand-600 hover:bg-brand-500 text-white text-xs font-bold flex items-center space-x-1"
                  >
                    <UserPlus className="w-3.5 h-3.5" />
                    <span>Add</span>
                  </button>
                </div>
              </form>
            </div>

          </div>

          {/* LIVE ATTENDEE ROSTER GRID */}
          <div className="mt-8 pt-6 border-t border-slate-800">
            <h3 className="text-sm font-bold text-slate-300 uppercase tracking-wider mb-3 flex items-center space-x-2">
              <Users className="w-4 h-4 text-brand-400" />
              <span>Live Attendance Feed (Updating in Real-Time)</span>
            </h3>

            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2.5 max-h-60 overflow-y-auto pr-1">
              {activeSession.attendees?.map((att) => (
                <div
                  key={att.id}
                  className="p-2.5 rounded-xl bg-slate-800/90 border border-emerald-500/40 flex items-center space-x-2 shadow-sm animate-fade-in"
                >
                  <div className="w-7 h-7 rounded-lg bg-emerald-500/20 text-emerald-300 font-extrabold text-xs flex items-center justify-center">
                    {att.rollNo}
                  </div>
                  <div className="overflow-hidden">
                    <p className="font-bold text-white text-xs truncate">{att.studentName}</p>
                    <p className="text-[10px] text-slate-400">{new Date(att.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>

        </div>
      ) : (
        /* LAUNCH NEW SESSION FORM */
        <div className="bg-slate-800/80 border border-slate-700/80 rounded-3xl p-6 sm:p-8 shadow-xl max-w-2xl mx-auto">
          <div className="text-center mb-6">
            <div className="w-12 h-12 rounded-2xl bg-brand-500/20 text-brand-400 flex items-center justify-center mx-auto mb-3">
              <Play className="w-6 h-6" />
            </div>
            <h3 className="text-xl font-extrabold text-white">Start New Lecture Attendance</h3>
            <p className="text-slate-400 text-xs mt-0.5">Launches the 10-second rotating PIN on screen for students.</p>
          </div>

          <form onSubmit={handleStartSession} className="space-y-4">
            <div>
              <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                Select Subject
              </label>
              <select
                value={selectedSubjectId}
                onChange={(e) => setSelectedSubjectId(e.target.value)}
                className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3.5 py-2.5 text-sm text-white focus:border-brand-500 outline-none"
                required
              >
                {subjects.map(s => (
                  <option key={s.id} value={s.id}>
                    {s.code} - {s.name} ({s.type})
                  </option>
                ))}
              </select>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                  Division
                </label>
                <select
                  value={division}
                  onChange={(e) => setDivision(e.target.value)}
                  className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3.5 py-2.5 text-sm text-white focus:border-brand-500 outline-none"
                >
                  <option value="SY-A">SY-A (Div A)</option>
                  <option value="SY-B">SY-B (Div B)</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                  Batch
                </label>
                <select
                  value={batch}
                  onChange={(e) => setBatch(e.target.value)}
                  className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3.5 py-2.5 text-sm text-white focus:border-brand-500 outline-none"
                >
                  <option value="All">All Batches (Theory)</option>
                  <option value="B1">Batch B1 (Practical)</option>
                  <option value="B2">Batch B2 (Practical)</option>
                  <option value="B3">Batch B3 (Practical)</option>
                </select>
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                Attendance Window Duration
              </label>
              <div className="grid grid-cols-4 gap-2">
                {[2, 3, 5, 10].map(mins => (
                  <button
                    key={mins}
                    type="button"
                    onClick={() => setDurationMinutes(mins)}
                    className={`py-2 rounded-xl text-xs font-extrabold border transition ${
                      durationMinutes === mins
                        ? 'bg-brand-600 text-white border-brand-500 shadow-md shadow-brand-500/20'
                        : 'bg-slate-900 border-slate-700 text-slate-400 hover:text-white'
                    }`}
                  >
                    {mins} Mins
                  </button>
                ))}
              </div>
            </div>

            <div className="pt-4">
              <button
                type="submit"
                disabled={loading}
                className="w-full py-3.5 rounded-xl bg-gradient-to-r from-brand-600 to-indigo-600 hover:from-brand-500 hover:to-indigo-500 text-white font-extrabold text-sm shadow-xl shadow-brand-500/30 flex items-center justify-center space-x-2 transition active:scale-[0.98]"
              >
                <Play className="w-4 h-4 fill-white" />
                <span>Launch Attendance Session</span>
              </button>
            </div>
          </form>
        </div>
      )}

    </div>
  );
}
