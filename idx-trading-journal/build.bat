@echo off
chcp 65001 >nul
title Build IDX Trading Journal EXE

echo ╔══════════════════════════════════════════════════════════╗
echo ║      Build IDX Trading Journal — Standalone EXE          ║
echo ╚══════════════════════════════════════════════════════════╝
echo.

:: Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python tidak ditemukan. Install Python dulu ya!
    pause
    exit /b 1
)

echo ✅ Python found

:: Install PyInstaller if not exists
python -c "import PyInstaller" 2>nul
if errorlevel 1 (
    echo 📦 Installing PyInstaller...
    python -m pip install pyinstaller>=6.0
)

echo 🔨 Building...
python build.py

if errorlevel 1 (
    echo ❌ Build failed!
    pause
    exit /b 1
)

echo.
echo ✅ Build sukses!
echo.
echo 📂 Output: dist\IDX_Trading_Journal\
echo 🚀 Jalankan: dist\IDX_Trading_Journal\IDX_Trading_Journal.exe
echo.
echo Catatan:
echo - Edit config.json di folder dist untuk API key
echo - Folder journal/ auto-create di sebelah EXE
echo.
pause
