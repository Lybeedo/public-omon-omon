@echo off
chcp 65001 >nul
echo 🚀 IDX Trading Journal - Web UI (Gradio)
echo =========================================
echo.

:: Check Python
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Python tidak ditemukan. Install Python 3.10+ dulu.
    pause
    exit /b
)

:: Check venv
if not exist "venv\Scripts\python.exe" (
    echo 📦 Membuat virtual environment...
    python -m venv venv
)

:: Install deps
echo 📦 Install dependencies...
venv\Scripts\pip install -q -r requirements.txt

:: Launch Web UI
echo 🔗 Buka browser: http://localhost:7860
echo.
venv\Scripts\python app.py

pause
