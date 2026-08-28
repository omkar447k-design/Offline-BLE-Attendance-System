@echo off
title SY Attendance System Launcher
echo ========================================================
echo   SY Computer Dept - Attendance System (100% Free)
echo ========================================================
echo.
echo Starting Backend Server on http://localhost:5000...
start cmd /k "cd server && npm run dev"

timeout /t 2 /nobreak >nul

echo Starting Frontend Web App on http://localhost:3000...
start cmd /k "cd client && npm run dev"

echo.
echo ========================================================
echo   Both Servers Started Successfully!
echo   Open http://localhost:3000 in your browser
echo ========================================================
