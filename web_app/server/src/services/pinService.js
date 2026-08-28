import crypto from 'crypto';

const PIN_SECRET = process.env.PIN_SECRET || 'sy_dept_pin_secret_key_2026';
const PIN_INTERVAL_MS = 10000; // 10 seconds rotation

export class PinService {
  /**
   * Generates a deterministic 4-digit PIN for a given session and time slot
   */
  static getPinForSlot(sessionId, slotIndex) {
    const hash = crypto
      .createHmac('sha256', PIN_SECRET)
      .update(`${sessionId}:${slotIndex}`)
      .digest('hex');
    
    // Extract a 4-digit integer between 1000 and 9999
    const intVal = parseInt(hash.substring(0, 8), 16);
    const pin = 1000 + (intVal % 9000);
    return String(pin);
  }

  /**
   * Returns current active PIN, time remaining in seconds, and slot index
   */
  static getCurrentPinInfo(sessionId) {
    const now = Date.now();
    const currentSlot = Math.floor(now / PIN_INTERVAL_MS);
    const pin = this.getPinForSlot(sessionId, currentSlot);
    const msIntoCurrentSlot = now % PIN_INTERVAL_MS;
    const msRemaining = PIN_INTERVAL_MS - msIntoCurrentSlot;
    const secondsRemaining = Math.ceil(msRemaining / 1000);

    return {
      pin,
      slot: currentSlot,
      msRemaining,
      secondsRemaining,
      rotationPeriodSeconds: PIN_INTERVAL_MS / 1000
    };
  }

  /**
   * Validates a submitted PIN against the session.
   * Tolerates the current slot AND the previous slot (-1) to absorb slow network lag.
   */
  static validatePin(sessionId, submittedPin) {
    if (!submittedPin || String(submittedPin).trim().length !== 4) {
      return { valid: false, reason: 'Invalid PIN format (Must be 4 digits)' };
    }

    const cleanPin = String(submittedPin).trim();
    const now = Date.now();
    const currentSlot = Math.floor(now / PIN_INTERVAL_MS);

    // Check current slot
    const currentPin = this.getPinForSlot(sessionId, currentSlot);
    if (cleanPin === currentPin) {
      return { valid: true, slot: currentSlot, isCurrent: true };
    }

    // Check previous slot (up to 10-12s latency tolerance)
    const prevPin = this.getPinForSlot(sessionId, currentSlot - 1);
    if (cleanPin === prevPin) {
      return { valid: true, slot: currentSlot - 1, isCurrent: false, note: 'Accepted within network grace window' };
    }

    return { valid: false, reason: 'Incorrect or expired PIN. Please enter the current PIN on screen.' };
  }
}
