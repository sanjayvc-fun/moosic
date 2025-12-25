@echo off
echo Starting Moosic Backend Server...
echo Host: %COMPUTERNAME%
echo IP should be: 10.18.55.54 (Ensure your Wi-Fi matches this)
echo.

cd backend
..\.venv\Scripts\python.exe -m pip install -r requirements.txt
cls
echo Dependencies checked. Server starting...
echo.
..\.venv\Scripts\python.exe app.py
pause
