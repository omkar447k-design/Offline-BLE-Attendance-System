import React from 'react';

export function TimerRing({ secondsRemaining = 10, totalSeconds = 10, size = 70, stroke = 6 }) {
  const radius = (size - stroke) / 2;
  const circumference = 2 * Math.PI * radius;
  const progress = Math.max(0, Math.min(1, secondsRemaining / totalSeconds));
  const strokeDashoffset = circumference * (1 - progress);

  // Dynamic color based on urgency
  let strokeColor = '#10B981'; // Emerald
  if (secondsRemaining <= 3) strokeColor = '#EF4444'; // Rose
  else if (secondsRemaining <= 6) strokeColor = '#F59E0B'; // Amber

  return (
    <div className="relative flex items-center justify-center" style={{ width: size, height: size }}>
      <svg width={size} height={size} className="transform -rotate-90">
        {/* Background Circle */}
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          stroke="rgba(51, 65, 85, 0.5)"
          strokeWidth={stroke}
          fill="transparent"
        />
        {/* Progress Arc */}
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          stroke={strokeColor}
          strokeWidth={stroke}
          fill="transparent"
          strokeDasharray={circumference}
          strokeDashoffset={strokeDashoffset}
          strokeLinecap="round"
          className="transition-all duration-300 ease-linear"
        />
      </svg>
      <div className="absolute flex flex-col items-center justify-center text-center">
        <span className="text-sm font-extrabold text-white leading-none">
          {secondsRemaining}s
        </span>
      </div>
    </div>
  );
}
