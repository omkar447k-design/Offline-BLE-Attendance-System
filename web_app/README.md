# 🎓 SY Attendance System (Web & PWA Platform)
**Department of Computer Engineering • 100% Free & Cross-Platform (iOS Safari, Android Chrome, Laptops)**

---

## 🌟 Key Features

1. **10-Second Dynamic 4-Digit Rolling PIN**:
   - Giant high-contrast numbers projected on the classroom screen.
   - Rotates dynamically every 10 seconds with an animated circular progress ring.
   - Prevents screenshot forwarding over WhatsApp/Telegram.
   - Sliding 12-second grace window absorbs slow 2G/3G mobile network latency.

2. **1-Device = 1-Student Hardware Fingerprint Binding**:
   - WebGL, Canvas, and Screen hardware signatures permanently bind 1 Roll Number to 1 physical device.
   - Stops multiple logins and proxy submissions on the same phone.
   - Admin has 1-click device reset if a student gets a new phone.

3. **Role-Based Portals**:
   - **Student Portal**: 4-digit PIN auto-advance, haptic vibration, celebratory confetti, overall % gauge, subject-wise breakdown, and 75% target calculator.
   - **Faculty / Teacher Portal**: Classroom projector mode, live attendee stream updating in real-time, timer extensions (+1m/+2m), manual override, and 1-click formatted `.xlsx` Excel download.
   - **HOD / Admin Portal**: SY student roster management, CSV/Excel import, faculty & subject mapping, 75% defaulter detection & export, global duration policy controls.

4. **100% Free Hosting Stack (₹0 Budget)**:
   - **Frontend**: Deploy on **Vercel** / **Cloudflare Pages** (Free SSL, global CDN).
   - **Backend**: Deploy on **Render** / **Supabase** (Zero-cost tier).
   - **Offline Mode**: Works 100% offline via local Wi-Fi hotspot or classroom LAN without external internet!

---

## 🚀 How to Run Locally

1. **Prerequisites**: Node.js LTS installed.
2. **Launch with 1 Click**: Double-click `start.bat` in this folder.
   - Or start manually:
     ```bash
     # Terminal 1: Backend Server (Port 5000)
     cd server
     npm run dev

     # Terminal 2: Frontend Web App (Port 3000)
     cd client
     npm run dev
     ```
3. Open **`http://localhost:3000`** in your browser.

---

## 🔐 Default Access Credentials

- **Admin Portal**: Password: `admin`
- **Faculty Portal**: Select any teacher from dropdown (e.g. `Dr. A. K. Sharma`)
- **Student Portal**: Division: `SY-A`, Roll No: `24` (Omkar Pawar) or any roll `1` to `30`.
