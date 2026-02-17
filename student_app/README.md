# Student Attendance App

Offline BLE-based attendance marking app for students.

## 🎯 Features

- ✅ One-time registration (Name & PRN)
- ✅ Auto-scan for teacher's attendance session
- ✅ Auto-mark attendance when in BLE range
- ✅ Anti-cheat: Device ID prevents re-marking
- ✅ **🔐 Fingerprint Authentication** - Required before marking attendance
- ✅ Attendance history with date grouping
- ✅ Works offline - no internet needed

## 🔒 Anti-Cheat Protection

### Layer 1: Device ID
Uses Android Device ID which:
- Survives app data clearing
- Survives app reinstall
- Prevents marking attendance for multiple students from same phone

### Layer 2: Biometric Authentication 🆕
**Compulsory fingerprint/biometric verification:**
- Must authenticate EVERY time attendance is detected
- Even if Student A gives phone to Student B, B cannot mark A's attendance
- Requires enrolled fingerprint on the device
- Only biometric auth allowed (no PIN/pattern fallback)
- Shows clear status indicator: "Fingerprint Required" or "No Biometric Available"

⚠️ **Important**: Device must have fingerprint/biometric enrolled in system settings

## 📱 How to Use

1. **First Time Setup**:
   - Open app
   - Grant Bluetooth permissions
   - Enter your Name and PRN
   - Tap Register
   - **Ensure fingerprint is set up in device settings**

2. **Mark Attendance**:
   - Just open the app
   - Stay near teacher (BLE range ~10-30m)
   - **When session detected, fingerprint prompt appears**
   - Verify with your fingerprint to mark attendance
   - You'll see a green notification when marked

3. **View History**:
   - Scroll down to see all past attendance records
   - Grouped by date with relative dates (Today, Yesterday, etc.)

## 🛠️ Build

```bash
flutter pub get
flutter build apk --release
```

APK location: `build/app/outputs/flutter-apk/app-release.apk`

## 📋 Permissions Required

- Bluetooth
- Bluetooth Scan
- Bluetooth Advertise
- Bluetooth Connect
- Location (required for BLE on Android)
- **Biometric/Fingerprint** (for authentication)

## 🗂️ Files

```
lib/
├── main.dart              # App entry, permissions
├── registration_screen.dart # First-time setup
├── scan_screen.dart       # Main screen, attendance marking + biometric auth
├── ble_scanner.dart       # BLE scanning logic
├── student_advertiser.dart # BLE advertising to teacher
├── attendance_record.dart  # Record model with date formatting
└── device_service.dart    # Device ID for anti-cheat
```

## 📡 BLE Data Sent to Teacher

```json
{
  "d": "deviceId8",    // Device ID (anti-cheat)
  "p": "PRN001",       // Your PRN
  "n": "YourName",     // Your name
  "k": "ABC123"        // Session token
}
```
