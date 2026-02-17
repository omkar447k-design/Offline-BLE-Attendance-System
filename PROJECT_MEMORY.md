==============================
PROJECT MEMORY FILE
==============================

Memory Version: v1.0
Last Updated: 2026-01-21

Project Name: Offline BLE Attendance System

Project Tagline (1 line): A fully offline, Bluetooth-based attendance system with anti-cheat protection using Flutter for Android/iOS.

---

## Problem Statement

Traditional attendance systems require internet connectivity, centralized servers, QR codes, or fingerprint hardware—creating deployment complexity, ongoing costs, and single points of failure. Educational institutions need a simple, cost-free, infrastructure-less solution that prevents proxy attendance and works reliably in offline environments.

---

## Solution Overview

This system uses Bluetooth Low Energy (BLE) to enable teachers to broadcast attendance sessions from their phone while students automatically mark their presence when within BLE range. The teacher's device acts as a BLE peripheral (advertiser) while student devices scan for the broadcast. A 3-layer anti-cheat system prevents proxy attendance using session tokens, device ID tracking, and mandatory biometric authentication.

---

## Project Scope

### IN SCOPE:
- Two standalone Flutter apps: Teacher App and Student App
- BLE-based session broadcasting and scanning (no pairing required)
- Session-based attendance with unique tokens per session
- Anti-cheat protection via device ID tracking and biometric authentication
- Local data persistence using SharedPreferences
- Session history with date grouping for both apps
- Cheat detection display on Teacher App
- Android and iOS support (iOS build requires macOS)
- Pre-built APKs for Android deployment

### OUT OF SCOPE:
- Server-side backend or cloud infrastructure
- Internet connectivity for attendance marking
- Data synchronization between devices
- Teacher dashboard or admin panel
- Report generation or export features
- Multiple simultaneous sessions from same teacher
- Student-to-student communication
- Attendance analytics or visualization
- Push notifications
- Multi-language support

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           SYSTEM ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌─────────────────────┐          BLE Broadcast           ┌─────────────────────┐
│   │    TEACHER APP      │ ─────────────────────────────────▶│    STUDENT APP      │
│   │    (Blue Theme)     │   (Subject, Classroom, Token)     │    (Green Theme)    │
│   │                     │                                   │                     │
│   │ ┌─────────────────┐ │                                   │ ┌─────────────────┐ │
│   │ │  BLEService     │ │          BLE Response             │ │  BLEScanner     │ │
│   │ │ (Advertising)   │ │◀─────────────────────────────────│ │  (Scanning)     │ │
│   │ └─────────────────┘ │   (DeviceID, PRN, Name, Token)   │ └─────────────────┘ │
│   │                     │                                   │                     │
│   │ ┌─────────────────┐ │                                   │ ┌─────────────────┐ │
│   │ │ StudentScanner  │ │                                   │ │StudentAdvertiser│ │
│   │ │ (Receives PRN)  │ │                                   │ │ (Broadcasts ID) │ │
│   │ └─────────────────┘ │                                   │ └─────────────────┘ │
│   │                     │                                   │                     │
│   │ ┌─────────────────┐ │                                   │ ┌─────────────────┐ │
│   │ │ SessionRecord   │ │                                   │ │ AttendanceRecord│ │
│   │ │ (Local Storage) │ │                                   │ │ (Local Storage) │ │
│   │ └─────────────────┘ │                                   │ └─────────────────┘ │
│   │                     │                                   │                     │
│   │ ┌─────────────────┐ │                                   │ ┌─────────────────┐ │
│   │ │ CheatDetection  │ │                                   │ │  DeviceService  │ │
│   │ └─────────────────┘ │                                   │ │ (Anti-cheat ID) │ │
│   └─────────────────────┘                                   │ └─────────────────┘ │
│                                                              │                     │
│                                                              │ ┌─────────────────┐ │
│                                                              │ │  local_auth     │ │
│                                                              │ │ (Fingerprint)   │ │
│                                                              │ └─────────────────┘ │
│                                                              └─────────────────────┘
└─────────────────────────────────────────────────────────────────────────┘
```

### Data Flow:
1. **Session Start**: Teacher enters subject, classroom, duration → App generates unique session token → BLE advertising starts with manufacturer ID `0xFFFF`
2. **Student Detection**: Student app continuously scans for BLE broadcasts with manufacturer ID `0xFFFF`
3. **Attendance Marking**: When session detected → Biometric auth required → Student broadcasts response with PRN, name, device ID, token using manufacturer ID `0xFFFE`
4. **Cheat Prevention**: Teacher app tracks device IDs; if same device broadcasts different PRN → cheat attempt logged and displayed
5. **Session End**: Teacher stops session manually or timer expires → Data saved to SharedPreferences

---

## Tech Stack

### Frontend:
- Flutter 3.0+ (cross-platform mobile UI framework)
- Material Design 3 (Material You)
- Dart SDK >=3.0.0 <4.0.0

### Backend:
- None (fully offline, peer-to-peer via BLE)

### AI/ML:
- Not applicable

### Database:
- SharedPreferences (local key-value storage)
- JSON serialization for complex objects

### Cloud / Hosting:
- None (fully offline system)

### DevOps / Tools:
- Android Studio / VS Code (development)
- Android NDK 27.0.12077973 (native build)
- flutter_launcher_icons ^0.13.1 (app icon generation)

---

## AI Details

Not applicable - this project does not use AI/ML components.

---

## Data Design

### Data Sources:
- User input (student registration: name, PRN)
- BLE broadcasts (attendance session data)
- System APIs (device ID, biometric auth)

### Storage Format:
- SharedPreferences (key-value pairs)
- JSON strings for complex objects

### Schema Philosophy:
- Denormalized for simplicity
- Session-based isolation (each session has unique token)
- Device ID as anti-spoofing anchor

### Key Data Models:

**StudentAttendance** (stored in Teacher App):
```dart
{
  "prn": String,
  "name": String,
  "markedAt": DateTime,
  "deviceId": String
}
```

**SessionRecord** (stored in Teacher App):
```dart
{
  "subject": String,
  "classroom": String,
  "duration": int (minutes),
  "startTime": DateTime,
  "endTime": DateTime,
  "token": String,
  "students": List<StudentAttendance>
}
```

**AttendanceRecord** (stored in Student App):
```dart
{
  "subject": String,
  "classroom": String,
  "markedAt": DateTime,
  "sessionToken": String
}
```

---

## Key Features

### Teacher App (Blue Theme):
- Start/stop attendance sessions with subject, classroom, duration
- Real-time student detection via BLE scanning
- View present students with PRN, name, timestamp
- Anti-cheat: Detects same device attempting with different PRN
- Cheat alerts: Shows original vs attempted PRN
- Session history with date grouping
- Auto-save when app goes to background
- 12-hour time format with day names

### Student App (Green Theme):
- One-time registration (Name & PRN)
- Auto-scan for teacher's attendance session
- Auto-mark attendance when in BLE range
- Broadcasts PRN + Device ID to teacher
- Mandatory fingerprint authentication before marking
- Attendance history with date grouping
- Relative dates (Today, Yesterday, 2 days ago)
- 12-hour time format

### Anti-Cheat System (3-Layer Protection):
1. **Layer 1 - Session Token**: Unique token per session prevents duplicate marking
2. **Layer 2 - Device ID Tracking**: Uses Android ID (survives app reinstall and data clear)
3. **Layer 3 - Biometric Authentication**: Mandatory fingerprint verification for every attendance mark

---

## Non-Functional Requirements

### Performance:
- BLE scanning with continuous updates
- Session timeout: up to 2 hours
- Real-time student list updates
- Low memory footprint (local storage only)

### Scalability:
- Supports 70-80 simultaneous students per session
- Limited by BLE advertising/scanning capacity
- No server bottlenecks

### Cost:
- Zero infrastructure cost (no servers, no cloud)
- Free to deploy and operate
- Requires only teacher and student smartphones

### Security:
- Device ID tied to hardware (survives reinstall)
- Biometric authentication prevents phone sharing
- Session tokens prevent replay attacks
- No network attack surface (fully offline)

### Privacy:
- All data stored locally on devices
- No data transmission to external servers
- Student information limited to PRN and name
- Device ID not personally identifiable

---

## Design Constraints

- BLE range: ~10-30 meters (device-dependent)
- Factory reset bypasses device ID check (edge case)
- iOS requires macOS with Xcode to build
- AndroidX minimum SDK: 21 (Android 5.0)
- Target SDK: 34
- Maximum BLE payload: ~27 bytes for manufacturer data (handled via JSON compression with single-letter keys)
- Single session at a time per teacher device
- No persistent storage redundancy

---

## Target Users

### Primary:
- **Teachers/Professors**: Taking attendance in classrooms, labs, or lecture halls
- **Students**: Enrolled students with smartphones attending classes

### Use Cases:
- College/university classroom attendance
- Coaching institute batch attendance
- Small office team meetings
- Any offline environment needing proximity-based attendance

---

## Current Project Status

- **Version**: 1.0.0+1
- **Status**: Complete and functional
- **Platforms**: 
  - Android: Pre-built APKs available (~22MB each)
  - iOS: Requires building from source on macOS
- **Source Files**:
  - Student App: 7 Dart files
  - Teacher App: 5 Dart files
- **License**: MIT License

---

## Known Limitations

1. **iOS Build Requirement**: iOS version requires macOS with Xcode to compile
2. **BLE Range Variability**: 10-30 meters depending on device Bluetooth hardware
3. **Factory Reset Bypass**: A device factory reset will generate a new Android ID, bypassing device tracking
4. **Concurrent Student Limit**: BLE capacity limits simultaneous students to ~70-80
5. **No Data Export**: No built-in feature to export attendance records
6. **No Cross-Device Sync**: Each teacher's attendance history is device-local
7. **Single Session**: Teacher can only run one session at a time
8. **Biometric Dependency**: Student device must have fingerprint enrolled in system settings

---

## Future Expansion (Optional)

- Export attendance to CSV/Excel
- QR-based backup attendance method
- Multi-session support for multiple classrooms
- Cloud sync option for data backup
- Teacher web dashboard for aggregate reporting
- Student attendance statistics and analytics
- Push notifications for upcoming sessions
- Integration with university ERP systems

---

## Project File Structure

```
Attendance System/
├── README.md
├── PROJECT_MEMORY.md
├── apks/
│   ├── student_app.apk    (~22 MB)
│   └── teacher_app.apk    (~22 MB)
├── student_app/
│   ├── lib/
│   │   ├── main.dart                 # App entry, initialization, permissions
│   │   ├── registration_screen.dart  # One-time student registration
│   │   ├── scan_screen.dart          # BLE scanning and attendance UI
│   │   ├── ble_scanner.dart          # BLE scan logic for teacher broadcasts
│   │   ├── student_advertiser.dart   # BLE advertise student response
│   │   ├── attendance_record.dart    # Local attendance history model
│   │   └── device_service.dart       # Anti-cheat device ID service
│   └── pubspec.yaml
└── teacher_app/
    ├── lib/
    │   ├── main.dart                 # App entry, initialization, permissions
    │   ├── teacher_screen.dart       # Main session management UI
    │   ├── ble_service.dart          # BLE advertising for sessions
    │   ├── student_scanner.dart      # Scan and track student responses
    │   └── session_record.dart       # Session history and student list model
    └── pubspec.yaml
```

---

## BLE Protocol Specification

### Teacher Broadcast (Manufacturer ID: 0xFFFF / 65535):
```json
{
  "s": "Subject Name",     // Max 15 chars
  "c": "Classroom",        // Max 10 chars  
  "t": 1703750400000,      // Epoch milliseconds
  "k": "ABC123"            // 6-char session token
}
```

### Student Response (Manufacturer ID: 0xFFFE / 65534):
```json
{
  "d": "deviceId8",        // 8-char device ID
  "p": "PRN001",           // Student PRN
  "n": "StudentName",      // Student name
  "k": "ABC123"            // Matching session token
}
```

---

## Dependency Versions

| Package | Version | Purpose |
|---------|---------|---------|
| flutter_blue_plus | ^1.32.8 | BLE scanning (both apps) |
| flutter_ble_peripheral | ^1.2.0 | BLE advertising (both apps) |
| shared_preferences | ^2.2.2 | Local data persistence |
| permission_handler | ^11.2.0 | Runtime permission requests |
| device_info_plus | ^10.1.0 | Device ID retrieval (Student App) |
| local_auth | ^2.1.8 | Biometric authentication (Student App) |
| flutter_launcher_icons | ^0.13.1 | App icon generation |

---

==============================
USAGE INSTRUCTIONS
==============================

This file must be pasted at the START of any new AI conversation.
The AI should treat it as persistent project memory and assume all future
queries relate to this project unless stated otherwise.

==============================
END OF PROJECT MEMORY FILE
==============================
