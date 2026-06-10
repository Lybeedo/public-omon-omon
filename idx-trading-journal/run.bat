@echo off
chcp 65001 >nul
echo 🚀 IDX Trading Journal - AI Powered
echo =========================================

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
venv\Scripts\pip install -q google-generativeai pillow pandas

:: Run
echo.
venv\Scripts\python trading_journal.py

pause
