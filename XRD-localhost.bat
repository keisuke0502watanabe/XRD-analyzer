@echo off
REM =====================================================================
REM  XRD Analyzer - open on http://localhost  (Windows: double-click)
REM
REM  Why: opening the app as file:// lets the browser evict the IndexedDB
REM  cache (your DB / projects). http://localhost is a proper origin, so
REM  the data is kept far more reliably.
REM
REM  Requires Python 3 (https://www.python.org/downloads/  -> tick
REM  "Add python.exe to PATH" during install).
REM =====================================================================
setlocal
set PORT=8753
set FILE=xrd_analyzer_v18.html
cd /d "%~dp0"

REM Start a static server in its own minimized window (leave it open while you use the app).
REM Tries "python" first, then the "py" launcher.
start "XRD server (keep open)" /min cmd /k "python -m http.server %PORT% 2>nul || py -m http.server %PORT%"

REM Give the server a moment, then open the browser.
timeout /t 2 >nul
start "" "http://localhost:%PORT%/%FILE%"

echo Opening http://localhost:%PORT%/%FILE%
echo Keep the minimized "XRD server" window open while using the app.
endlocal
