@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ============================================
echo  课程日历 安卓版 - 一键生成工程并打包 APK
echo ============================================
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
echo.
pause
