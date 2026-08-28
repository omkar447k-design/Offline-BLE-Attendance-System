import React from 'react';
import { GraduationCap, LogOut, Shield, User, Sparkles } from 'lucide-react';

export function Navbar({ role, user, onLogout }) {
  return (
    <header className="bg-slate-900/80 backdrop-blur-md border-b border-slate-800 sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
        
        {/* Brand */}
        <div className="flex items-center space-x-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-brand-600 to-indigo-500 flex items-center justify-center shadow-lg shadow-brand-500/30 ring-1 ring-white/20">
            <GraduationCap className="w-6 h-6 text-white" />
          </div>
          <div>
            <div className="flex items-center space-x-2">
              <span className="font-bold text-lg text-white tracking-tight">SY Attendance</span>
              <span className="text-[10px] uppercase font-bold tracking-wider px-1.5 py-0.5 rounded bg-brand-500/20 text-brand-300 border border-brand-500/30">
                PWA
              </span>
            </div>
            <p className="text-xs text-slate-400 font-medium hidden sm:block">Dept. of Computer Engineering</p>
          </div>
        </div>

        {/* User Info & Role Badge */}
        <div className="flex items-center space-x-3">
          {role && (
            <div className="flex items-center space-x-2 bg-slate-800/80 border border-slate-700/60 rounded-full px-3 py-1 text-xs">
              <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
              <span className="text-slate-300 font-semibold uppercase tracking-wider">
                {role === 'admin' ? '👑 Admin' : role === 'teacher' ? '👨‍🏫 Faculty' : '🎓 Student'}
              </span>
              {user?.name && (
                <span className="text-slate-400 border-l border-slate-700 pl-2 hidden md:inline">
                  {user.name} {user.rollNo ? `(#${user.rollNo})` : ''}
                </span>
              )}
            </div>
          )}

          {role && (
            <button
              onClick={onLogout}
              className="flex items-center space-x-1.5 text-xs font-semibold px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-rose-500/20 hover:text-rose-300 text-slate-400 border border-slate-700 hover:border-rose-500/40 transition-all duration-150"
              title="Switch Account / Logout"
            >
              <LogOut className="w-3.5 h-3.5" />
              <span className="hidden sm:inline">Exit</span>
            </button>
          )}
        </div>
      </div>
    </header>
  );
}
