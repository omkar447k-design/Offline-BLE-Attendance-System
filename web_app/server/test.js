import assert from 'assert';
import { PinService } from './src/services/pinService.js';
import { DeviceService } from './src/services/deviceService.js';
import { ExcelService } from './src/services/excelService.js';
import { db } from './src/config/db.js';

console.log('🧪 Starting Automated Logic & Security Tests...\n');

// 1. Test 10-Second PIN Generation
const sessionId = 'TEST_SESS_001';
const pinInfo = PinService.getCurrentPinInfo(sessionId);
assert.strictEqual(typeof pinInfo.pin, 'string', 'PIN should be a string');
assert.strictEqual(pinInfo.pin.length, 4, 'PIN should be 4 digits');
console.log('✅ Test 1 Passed: 4-digit PIN generated successfully ->', pinInfo.pin);

// 2. Test PIN Validation with Sliding Grace Window
const currentValidation = PinService.validatePin(sessionId, pinInfo.pin);
assert.strictEqual(currentValidation.valid, true, 'Current PIN must be valid');

const invalidValidation = PinService.validatePin(sessionId, '0000');
assert.strictEqual(invalidValidation.valid, false, 'Arbitrary PIN must be invalid');
console.log('✅ Test 2 Passed: Current PIN validated & fake PIN rejected');

// 3. Test Device Binding
const studentId = 'S01';
const rollNo = 1;
const deviceA = 'dev_phone_alpha';
const fpA = 'fp_alpha_canvas';
const deviceB = 'dev_phone_beta';
const fpB = 'fp_beta_canvas';

// Bind S01 to Device A
const bind1 = DeviceService.verifyOrBindDevice(studentId, rollNo, deviceA, fpA);
assert.strictEqual(bind1.success, true, 'Initial binding must succeed');

// S01 attempts to login from Device B (different phone) -> MUST FAIL
const bindDiffDevice = DeviceService.verifyOrBindDevice(studentId, rollNo, deviceB, fpB);
assert.strictEqual(bindDiffDevice.success, false, 'Different device binding must be blocked');

// S02 attempts to login from Device A (same phone as S01) -> MUST FAIL
const bindDiffStudentSameDevice = DeviceService.verifyOrBindDevice('S02', 2, deviceA, fpA);
assert.strictEqual(bindDiffStudentSameDevice.success, false, 'Multiple students on same phone must be blocked');
console.log('✅ Test 3 Passed: 1-Device-1-Student hardware lock enforced correctly');

// 4. Test Excel Export Generation
const testSession = {
  id: sessionId,
  subjectName: 'Operating Systems',
  division: 'SY-A',
  batch: 'All',
  date: '2026-08-28'
};
const testAttendance = [
  { studentId: 'S01', rollNo: 1, studentName: 'Aarav Mehta', timestamp: new Date().toISOString(), verifiedVia: 'PIN' }
];
const excelBuffer = ExcelService.generateSessionExcel(testSession, testAttendance);
assert.ok(excelBuffer && excelBuffer.length > 0, 'Excel buffer must not be empty');
console.log('✅ Test 4 Passed: Excel (.xlsx) generated successfully, size ->', excelBuffer.length, 'bytes');

console.log('\n🎉 ALL 4 SECURITY AND LOGIC TESTS PASSED WITH 100% SUCCESS!');
