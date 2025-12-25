@echo off
cd /d "%~dp0"
echo Starting Moosic Backend Server...
echo Host: %COMPUTERNAME%
echo IP should be: #replace it with your own ip (Ensure your Wi-Fi matches this) #use only for test thhis will make your running devices as server
echo.

cd backend
REM Use quotes for paths to handle spaces
"..\.venv\Scripts\python.exe" -m pip install -r requirements.txt
cls
echo Dependencies checked. Server starting...
echo.
"..\.venv\Scripts\python.exe" app.py
pause
