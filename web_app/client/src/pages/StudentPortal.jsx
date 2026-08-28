import React, { useState, useEffect } from 'react';
import confetti from 'canvas-confetti';
import { CheckCircle2, AlertTriangle, Clock, BookOpen, User, ShieldCheck, Flame, RefreshCw } from 'lucide-react';
import { api, getSocket } from '../services/api';
import { PinInput } from '../components/PinInput';

export function StudentPortal({ student, device }) {
  const [activeSession, setActiveSession] = useState(null);
  const [dashboardData, setDashboardData] = useState(null);
  const [pin, setPin] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState('');
  const [submitSuccess, setSubmitSuccess] = useState(null);
  const [loading, setLoading] = useState(true);

  // Fetch student dashboard and active session
  const refreshData = async () => {
    try {
      const [dashRes, sessRes] = await Promise.all([
        api.getStudentDashboard(student.id || student.rollNo),
        api.getStudentActiveSession(student.division, student.id)
      ]);

      if (dashRes.success) {
        setDashboardData(dashRes.data);
      }

      if (sessRes.success && sessRes.hasActiveSession) {
        setActiveSession(sessRes.session);
        if (sessRes.session.alreadyMarked) {
          setSubmitSuccess('You are marked Present for this lecture session.');
        }
      } else {
        setActiveSession(null);
      }
    } catch (err) {
      console.error('Error refreshing student data:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    refreshData();
    const interval = setInterval(refreshData, 4000); // poll session status every 4s
    return () => clearInterval(interval);
  }, [student.id, student.division]);

  // Handle PIN Submission
  const handlePinSubmit = async (submittedPin) => {
    const pinToSubmit = submittedPin || pin;
    if (!pinToSubmit || pinToSubmit.length !== 4) {
      setSubmitError('Please enter the full 4-digit PIN');
      return;
    }

    if (!activeSession) {
      setSubmitError('No active attendance session currently.');
      return;
    }

    setSubmitting(true);
    setSubmitError('');

    try {
      const res = await api.submitPin({
        studentId: student.id,
        rollNo: student.rollNo,
        sessionId: activeSession.id,
        pin: pinToSubmit,
        deviceId: device.deviceId,
        fingerprint: device.fingerprint
      });

      if (res.success) {
        // Haptic feedback
        if (navigator.vibrate) {
          navigator.vibrate([100, 50, 100]);
        }

        // Confetti celebration
        try {
          confetti({
            particleCount: 80,
            spread: 70,
            origin: { y: 0.6 }
          });
        } catch (e) {}

        setSubmitSuccess(res.message || '✅ Attendance Recorded Successfully!');
        refreshData();
      }
    } catch (err) {
      setSubmitError(err.message || 'Failed to submit PIN. Please check the screen.');
    } finally {
      setSubmitting(false);
    }
  };

  const stats = dashboardData?.stats;
  const overallPct = stats?.overallPercentage ?? 100;
  const isSafe = overallPct >= 75.0;

  return (
    <div className="max-w-4xl mx-auto px-4 sm:px-6 py-6 sm:py-8 space-y-6">
      
      {/* Student Welcome Header Card */}
      <div className="bg-gradient-to-r from-slate-800/90 to-slate-900/90 backdrop-blur-xl border border-slate-700/80 rounded-3xl p-5 sm:p-6 shadow-xl flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div className="flex items-center space-x-4">
          <div className="w-14 h-14 rounded-2xl bg-gradient-to-tr from-brand-600 to-indigo-500 flex items-center justify-center text-white text-xl font-extrabold shadow-lg shadow-brand-500/20">
            {student.rollNo}
          </div>
          <div>
            <div className="flex items-center space-x-2">
              <h2 className="text-xl font-extrabold text-white">{student.name}</h2>
              <span className="text-[11px] font-bold px-2 py-0.5 rounded-full bg-brand-500/20 text-brand-300 border border-brand-500/30">
                {student.division} • {student.batch}
              </span>
            </div>
            <p className="text-xs text-slate-400 mt-0.5">
              PRN: {student.prn || '202401' + student.rollNo} • Device Locked 🔒
            </p>
          </div>
        </div>

        <button
          onClick={refreshData}
          className="self-end sm:self-center flex items-center space-x-1.5 px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold border border-slate-700 transition"
        >
          <RefreshCw className="w-3.5 h-3.5" />
          <span>Refresh</span>
        </button>
      </div>

      {/* ACTIVE CLASS ATTENDANCE CARD */}
      {activeSession ? (
        <div className="bg-gradient-to-br from-indigo-950/80 via-slate-900 to-slate-900 border-2 border-brand-500/50 rounded-3xl p-6 sm:p-8 shadow-2xl glow-indigo text-center relative overflow-hidden">
          
          {/* Live Indicator */}
          <div className="inline-flex items-center space-x-2 px-3 py-1 rounded-full bg-rose-500/20 border border-rose-500/30 text-rose-300 text-xs font-bold uppercase tracking-wider mb-4 animate-pulse">
            <span className="w-2 h-2 rounded-full bg-rose-400"></span>
            <span>Live Class Attendance Open</span>
          </div>

          <h3 className="text-2xl sm:text-3xl font-extrabold text-white tracking-tight">
            {activeSession.subjectName}
          </h3>
          <p className="text-slate-400 text-sm mt-1">
            Division: <span className="text-brand-300 font-semibold">{activeSession.division}</span>
            {activeSession.batch !== 'All' ? ` • Batch: ${activeSession.batch}` : ''}
          </p>

          {submitSuccess || activeSession.alreadyMarked ? (
            <div className="my-6 p-6 rounded-2xl bg-emerald-500/15 border border-emerald-500/40 text-emerald-300">
              <CheckCircle2 className="w-12 h-12 mx-auto mb-2 text-emerald-400" />
              <p className="font-extrabold text-lg text-white">Present Recorded!</p>
              <p className="text-xs text-emerald-300/90 mt-1">Your attendance is confirmed for this lecture.</p>
            </div>
          ) : (
            <div className="my-6 max-w-sm mx-auto">
              <p className="text-xs font-semibold text-slate-300 uppercase tracking-wider mb-2">
                Enter the 4-digit PIN on the Projector Screen:
              </p>

              <PinInput
                length={4}
                onComplete={handlePinSubmit}
                disabled={submitting}
              />

              {submitError && (
                <p className="text-xs text-rose-400 font-semibold mt-2 bg-rose-500/10 py-2 px-3 rounded-lg border border-rose-500/20">
                  ⚠️ {submitError}
                </p>
              )}

              <p className="text-[11px] text-slate-400 mt-3">
                ⏱️ PIN rotates every 10 seconds. Type the active number on the screen.
              </p>
            </div>
          )}
        </div>
      ) : (
        <div className="bg-slate-800/50 border border-slate-800 rounded-3xl p-6 text-center text-slate-400 text-sm">
          <Clock className="w-8 h-8 mx-auto mb-2 text-slate-500" />
          <p className="font-semibold text-slate-300">No Active Attendance Session Right Now</p>
          <p className="text-xs text-slate-500 mt-0.5">When your teacher starts a lecture, the PIN entry box will appear here automatically.</p>
        </div>
      )}

      {/* ATTENDANCE ANALYTICS GAUGE & 75% TARGET CALCULATOR */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
        
        {/* Overall Percentage Card */}
        <div className="bg-slate-800/80 border border-slate-700/80 rounded-3xl p-5 sm:p-6 shadow-lg flex flex-col items-center justify-center text-center">
          <span className="text-xs font-bold uppercase tracking-wider text-slate-400 mb-2">
            Overall Department Attendance
          </span>
          <div className="relative flex items-center justify-center my-2">
            <div className={`text-4xl sm:text-5xl font-black ${isSafe ? 'text-emerald-400' : 'text-amber-400'}`}>
              {overallPct}%
            </div>
          </div>
          <div className={`text-xs font-bold px-3 py-1 rounded-full mt-2 ${
            isSafe
              ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30'
              : 'bg-amber-500/20 text-amber-300 border border-amber-500/30'
          }`}>
            {isSafe ? '✅ Safe (> 75%)' : '⚠️ Defaulter (< 75%)'}
          </div>
          <p className="text-[11px] text-slate-400 mt-2">
            {stats?.attendedLectures ?? 0} attended out of {stats?.totalLectures ?? 0} lectures
          </p>
        </div>

        {/* 75% Target Calculator */}
        <div className="md:col-span-2 bg-slate-800/80 border border-slate-700/80 rounded-3xl p-5 sm:p-6 shadow-lg flex flex-col justify-between">
          <div>
            <div className="flex items-center space-x-2 text-slate-300 font-bold text-sm mb-2">
              <ShieldCheck className="w-4 h-4 text-brand-400" />
              <span>HOD 75% Mandatory Attendance Rule</span>
            </div>
            
            {isSafe ? (
              <div className="p-4 rounded-2xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-300 text-xs sm:text-sm leading-relaxed">
                🎉 <strong>Great job!</strong> Your attendance is above the departmental threshold (75%). Keep attending regularly to remain in the safe zone for term work submission.
              </div>
            ) : (
              <div className="p-4 rounded-2xl bg-amber-500/15 border border-amber-500/30 text-amber-300 text-xs sm:text-sm leading-relaxed">
                ⚠️ <strong>Attendance Warning:</strong> You are currently on the Defaulter List. You need to attend the next <span className="font-extrabold text-white underline">{stats?.lecturesNeededFor75 || 2} lectures consecutively</span> to cross 75%!
              </div>
            )}
          </div>

          <div className="grid grid-cols-2 gap-3 mt-4 pt-3 border-t border-slate-700/60 text-xs text-slate-400">
            <div>
              <span className="block text-slate-500">Min. Target Required</span>
              <span className="font-bold text-white text-sm">75.0%</span>
            </div>
            <div>
              <span className="block text-slate-500">Term Work Eligibility</span>
              <span className={`font-bold text-sm ${isSafe ? 'text-emerald-400' : 'text-amber-400'}`}>
                {isSafe ? 'Eligible' : 'At Risk'}
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* SUBJECT-WISE ATTENDANCE BREAKDOWN */}
      <div className="bg-slate-800/80 border border-slate-700/80 rounded-3xl p-6 shadow-xl">
        <h4 className="text-base font-extrabold text-white mb-4 flex items-center space-x-2">
          <BookOpen className="w-4 h-4 text-brand-400" />
          <span>Subject-Wise Attendance Breakdown</span>
        </h4>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {dashboardData?.subjectStats?.map((sub) => (
            <div key={sub.id} className="p-4 rounded-2xl bg-slate-900/70 border border-slate-700/60 flex flex-col justify-between">
              <div className="flex items-start justify-between">
                <div>
                  <span className="text-[10px] uppercase font-extrabold text-brand-400 tracking-wider">
                    {sub.code} • {sub.type}
                  </span>
                  <h5 className="font-bold text-white text-sm mt-0.5">{sub.name}</h5>
                </div>
                <span className={`text-xs font-extrabold px-2 py-0.5 rounded-full ${
                  sub.isSafe ? 'bg-emerald-500/20 text-emerald-300' : 'bg-rose-500/20 text-rose-300'
                }`}>
                  {sub.percentage}%
                </span>
              </div>

              {/* Progress Bar */}
              <div className="mt-3">
                <div className="w-full h-2 rounded-full bg-slate-800 overflow-hidden">
                  <div
                    className={`h-full rounded-full transition-all duration-500 ${
                      sub.isSafe ? 'bg-emerald-500' : 'bg-rose-500'
                    }`}
                    style={{ width: `${Math.min(100, sub.percentage)}%` }}
                  ></div>
                </div>
                <div className="flex justify-between text-[11px] text-slate-400 mt-1">
                  <span>{sub.attended} / {sub.total} classes attended</span>
                  <span>{sub.isSafe ? 'Safe' : 'Low (<75%)'}</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* RECENT ATTENDANCE HISTORY LOG */}
      <div className="bg-slate-800/80 border border-slate-700/80 rounded-3xl p-6 shadow-xl">
        <h4 className="text-base font-extrabold text-white mb-4 flex items-center space-x-2">
          <Clock className="w-4 h-4 text-brand-400" />
          <span>Recent Attendance Logs</span>
        </h4>

        {dashboardData?.recentHistory?.length > 0 ? (
          <div className="divide-y divide-slate-700/60">
            {dashboardData.recentHistory.map((item) => (
              <div key={item.id} className="py-3 flex items-center justify-between text-xs sm:text-sm">
                <div>
                  <p className="font-bold text-white">{item.subjectName}</p>
                  <p className="text-[11px] text-slate-400">{new Date(item.timestamp).toLocaleString()}</p>
                </div>
                <div className="flex items-center space-x-2">
                  <span className="px-2.5 py-1 rounded-full bg-emerald-500/20 text-emerald-300 font-bold text-xs">
                    ✅ {item.status}
                  </span>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <p className="text-xs text-slate-500 text-center py-4">No attendance records yet.</p>
        )}
      </div>

    </div>
  );
}
