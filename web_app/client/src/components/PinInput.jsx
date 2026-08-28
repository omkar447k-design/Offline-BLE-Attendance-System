import React, { useRef, useState, useEffect } from 'react';

export function PinInput({ length = 4, onComplete, disabled = false, autoFocus = true }) {
  const [digits, setDigits] = useState(Array(length).fill(''));
  const inputRefs = useRef([]);

  useEffect(() => {
    if (autoFocus && inputRefs.current[0] && !disabled) {
      inputRefs.current[0].focus();
    }
  }, [autoFocus, disabled]);

  const handleChange = (index, value) => {
    if (disabled) return;
    const cleanVal = value.replace(/\D/g, '').slice(-1); // Take last single numeric digit

    const newDigits = [...digits];
    newDigits[index] = cleanVal;
    setDigits(newDigits);

    // Haptic feedback on mobile if supported
    if (navigator.vibrate) {
      navigator.vibrate(15);
    }

    if (cleanVal && index < length - 1) {
      inputRefs.current[index + 1]?.focus();
    }

    // Check if full pin entered
    const fullPin = newDigits.join('');
    if (fullPin.length === length && !newDigits.includes('')) {
      onComplete(fullPin);
    }
  };

  const handleKeyDown = (index, e) => {
    if (e.key === 'Backspace') {
      if (!digits[index] && index > 0) {
        inputRefs.current[index - 1]?.focus();
      }
    } else if (e.key === 'ArrowLeft' && index > 0) {
      inputRefs.current[index - 1]?.focus();
    } else if (e.key === 'ArrowRight' && index < length - 1) {
      inputRefs.current[index + 1]?.focus();
    }
  };

  const handlePaste = (e) => {
    e.preventDefault();
    const pasteData = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, length);
    if (!pasteData) return;

    const newDigits = Array(length).fill('');
    for (let i = 0; i < pasteData.length; i++) {
      newDigits[i] = pasteData[i];
    }
    setDigits(newDigits);

    const focusIdx = Math.min(pasteData.length, length - 1);
    inputRefs.current[focusIdx]?.focus();

    if (pasteData.length === length) {
      onComplete(pasteData);
    }
  };

  return (
    <div className="flex justify-center items-center space-x-3 sm:space-x-4 my-4" onPaste={handlePaste}>
      {Array(length).fill(0).map((_, i) => (
        <input
          key={i}
          ref={(el) => (inputRefs.current[i] = el)}
          type="text"
          inputMode="numeric"
          pattern="[0-9]*"
          maxLength={1}
          value={digits[i]}
          onChange={(e) => handleChange(i, e.target.value)}
          onKeyDown={(e) => handleKeyDown(i, e)}
          disabled={disabled}
          className={`w-14 h-16 sm:w-16 sm:h-20 text-center text-3xl sm:text-4xl font-extrabold rounded-2xl border-2 transition-all duration-200 outline-none select-none
            ${digits[i]
              ? 'border-brand-500 bg-brand-500/10 text-white shadow-lg shadow-brand-500/20'
              : 'border-slate-700 bg-slate-800/80 text-slate-300 focus:border-brand-400 focus:bg-slate-800'
            }
            ${disabled ? 'opacity-50 cursor-not-allowed' : 'cursor-text hover:border-slate-600'}
          `}
        />
      ))}
    </div>
  );
}
