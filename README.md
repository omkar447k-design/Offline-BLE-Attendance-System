# Offline BLE Attendance System

A complete offline attendance system using Bluetooth Low Energy (BLE) with separate Teacher and Student apps built with Flutter.

##  System Overview

This system enables teachers to take attendance wirelessly via Bluetooth without requiring internet, servers, QR codes, fingerprinting, or any backend infrastructure. Students automatically mark attendance when they are within BLE range during active attendance sessions.

### Key Features
- **Fully Offline**: No internet or server required
-  **BLE Only**: Uses Bluetooth Low Energy for communication
-  **No Pairing**: Direct BLE advertising and scanning
-  **Scalable**: Supports 70-80 students simultaneously
-  **Session-Based**: Unique tokens prevent duplicate marking
- **Anti-Cheat Protection**: Device ID tracking prevents marking from same phone with different PRN
  - **Cheat Detection Display**: Teacher can see who tried to cheat
-  **Session History**: Both apps store attendance records locally
-  **Cross-Platform**: Android & iOS support (iOS needs Mac to build)
-  **Simple UI**: Clean, fast, minimal interface

## Apps

### Teacher App (Blue Theme)
**Purpose**: Broadcast attendance sessions via BLE and track students

**Features**:
- Start/stop attendance sessions with subject, classroom, duration
- Real-time student detection via BLE
- View present students with PRN, name, and time
- **Anti-cheat**: Detects same device trying with different PRN
- **Cheat alerts**: Shows warning with original & attempted PRN
- Session history with date grouping
- Session details with full student list
- Auto-save when app goes to background
- 12-hour time format with day names

### Student App (Green Theme)
**Purpose**: Automatically detect and mark attendance

**Features**:
- One-time registration (Name & PRN)
- Auto-scan for teacher's attendance session
- Auto-mark attendance when in BLE range
- Broadcasts PRN + Device ID to teacher
- **Anti-cheat**: Device ID prevents re-marking even after clearing app data
- **Fingerprint Lock**: Biometric authentication required before marking
- Attendance history with date grouping
- Relative dates (Today, Yesterday, 2 days ago)
- 12-hour time format

##  Anti-Cheat System (3-Layer Protection)

### Layer 1: Session Token
- Unique token generated per session
- Prevents duplicate marking in same session

### Layer 2: Device ID Tracking
Uses Android Device ID (`ANDROID_ID`) which:
- Survives app data clearing
- Survives app reinstall
- Unique per device

Teacher tracks by Device ID, not PRN:
- Same phone can only mark once per session
- If same device tries with different PRN → **BLOCKED**
- Teacher sees alert with both original and attempted PRN

### Layer 3: Biometric Authentication 
**Compulsory fingerprint verification on Student App:**
- Must authenticate EVERY time attendance is detected
- Even if Student A gives phone to Student B, B cannot mark A's attendance
- Only biometric auth allowed (no PIN/pattern fallback)
- Device must have fingerprint enrolled in system settings

### Cheat Detection Display (Teacher App):
```
 CHEAT DETECTED!
Original: Amit (PRN001) ✓
Tried as: Rahul (PRN002) ✗
Device ID: abc12345
```

##  APK Downloads

Pre-built APKs are available in the `apks/` folder:
- `student_app.apk` - Install on student phones
- `teacher_app.apk` - Install on teacher's phone

## 🛠️ Technical Stack

- **Framework**: Flutter 3.0+
- **BLE Scanning**: flutter_blue_plus ^1.32.8
- **BLE Advertising**: flutter_ble_peripheral ^1.2.0
- **Storage**: shared_preferences ^2.2.2
- **Permissions**: permission_handler ^11.2.0
- **Device ID**: device_info_plus ^10.1.0
- **Biometrics**: local_auth ^2.1.8
- **Icons**: flutter_launcher_icons ^0.13.1

##  Requirements

### Android
- Minimum SDK: 21 (Android 5.0)
- Target SDK: 34
- Bluetooth & Location permissions

### iOS
- iOS 12.0+
- Bluetooth permissions
- Needs Mac with Xcode to build

##  Building from Source

### Prerequisites
- Flutter SDK 3.0+
- Android Studio / VS Code
- Android NDK 27.0.12077973

### Build Commands

```bash
# Student App
cd student_app
flutter pub get
flutter build apk --release

# Teacher App
cd teacher_app
flutter pub get
flutter build apk --release
```

##  BLE Protocol

### Teacher Broadcasts (Manufacturer ID: 0xFFFF):
```json
{
  "s": "Subject Name",
  "c": "Classroom",
  "t": 1703750400000,
  "k": "ABC123"
}
```

### Student Responds (Manufacturer ID: 0xFFFE):
```json
{
  "d": "deviceId8",
  "p": "PRN001",
  "n": "StudentName",
  "k": "ABC123"
}
```

## Project Structure

```
atd/
├── apks/
│   ├── student_app.apk
│   └── teacher_app.apk
├── student_app/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── registration_screen.dart
│   │   ├── scan_screen.dart
│   │   ├── ble_scanner.dart
│   │   ├── student_advertiser.dart
│   │   ├── attendance_record.dart
│   │   └── device_service.dart
│   └── pubspec.yaml
├── teacher_app/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── teacher_screen.dart
│   │   ├── ble_service.dart
│   │   ├── student_scanner.dart
│   │   └── session_record.dart
│   └── pubspec.yaml
└── README.md
```

##  Usage

### Teacher:
1. Open Teacher App
2. Grant Bluetooth permissions
3. Enter Subject, Classroom, Duration
4. Tap "Start Attendance"
5. Wait for students to appear in list
6. View cheat attempts if any
7. Tap "Stop Attendance" or wait for timer

### Student:
1. Open Student App (first time)
2. Enter Name and PRN
3. Grant Bluetooth permissions
4. App automatically scans for attendance
5. When teacher starts session, attendance marks automatically
6. View history in the list below

##  Limitations

- iOS build requires macOS with Xcode
- BLE range: ~10-30 meters depending on device
- Factory reset bypasses device ID check (rare scenario)
- Maximum ~70-80 simultaneous students due to BLE limits

##  License

MIT License - Free to use and modify
