@echo off
echo ========================================================
echo   Starting Notelekh Local Development Environment
echo ========================================================

for /f "tokens=*" %%a in ('python -c "import socket; s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.connect(('8.8.8.8', 80)); print(s.getsockname()[0]); s.close()" 2^>nul') do set LAN_IP=%%a
if "%LAN_IP%"=="" set LAN_IP=192.168.1.10

echo [1/2] Starting FastAPI Backend on 0.0.0.0:8000...
start "Notelekh Backend" cmd /k "cd /d "%~dp0apps\backend" && python -m uvicorn app.main:app --host 0.0.0.0 --port 8000"

echo [2/2] Starting High-Performance Web Server on 0.0.0.0:8080...
start "Notelekh Web Client" cmd /k "cd /d "%~dp0apps\client" && python serve.py 8080"

echo.
echo ========================================================
echo   Servers are running:
echo   - Local PC Web App:  http://localhost:8080/
echo   - Local PC Backend:  http://localhost:8000/docs
echo   - LAN (iPad/Tablet): http://%LAN_IP%:8080/
echo   - LAN Backend API:   http://%LAN_IP%:8000/
echo ========================================================
pause
