# Teacher Attendance App

Offline BLE-based attendance management app for teachers.

## 🎯 Features

- ✅ Start/stop attendance sessions
- ✅ Real-time student detection via BLE
- ✅ View present students with PRN, name, time
- ✅ **Anti-cheat**: Detects same device with different PRN
- ✅ **Cheat alerts**: Shows who tried to cheat
- ✅ Session history with student lists
- ✅ Auto-save when app backgrounds
- ✅ Works offline - no internet needed

## 🔒 Anti-Cheat Detection

The app tracks students by Device ID, not just PRN:

- Same phone can only mark once per session
- If same device tries with different PRN → **BLOCKED**
- You'll see a red alert with both PRNs

### Cheat Alert Example:
```
⚠️ CHEAT DETECTED!
Original: Amit (PRN001) ✓
Tried as: Rahul (PRN002) ✗
Device ID: abc12345
```

## 📱 How to Use

1. **Start Session**:
   - Open app
   - Grant Bluetooth permissions
   - Enter Subject name
   - Enter Classroom
   - Set Duration (minutes)
   - Tap "Start Attendance"

2. **During Session**:
   - Students appear as they mark attendance
   - Green notification for each student
   - Red alert if cheating detected
   - Timer counts down

3. **End Session**:
   - Tap "Stop Attendance" or wait for timer
   - Session saved automatically
   - View in history

4. **View History**:
   - Tap history icon in app bar
   - Tap any session to see full student list
   - Shows date, time, student count

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

## 🗂️ Files

```
lib/
├── main.dart           # App entry, permissions
├── teacher_screen.dart # Main UI, session management
├── ble_service.dart    # BLE advertising
├── student_scanner.dart # BLE scanning, cheat detection
└── session_record.dart  # Session & student models
```

## 📡 BLE Protocol

### Broadcasts to Students:
```json
{
  "s": "Mathematics",   // Subject
  "c": "Room 101",      // Classroom
  "t": 1703750400000,   // Start time
  "k": "ABC123"         // Session token
}
```

### Receives from Students:
```json
{
  "d": "deviceId8",     // Device ID (anti-cheat)
  "p": "PRN001",        // Student PRN
  "n": "StudentName",   // Student name
  "k": "ABC123"         // Session token
}
```

## 📊 Data Storage

Sessions are stored locally using SharedPreferences:
- Subject, classroom, duration
- Start/end time
- All students with PRN, name, marked time
- Survives app restart
