@echo off
chcp 65001 >nul
title SmartLocker Database Setup & Seed
color 0b

echo ============================================================
echo    SmartLocker - Database Setup ^& 100 Demo Accounts Seed
echo ============================================================
echo.
echo Running PowerShell setup script...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_demo_db.ps1"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Database setup encountered an error!
    pause
    exit /b %ERRORLEVEL%
)

echo.
pause
