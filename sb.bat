@echo off
REM Sing-box Quick Start Script for Windows
REM Version: v1.0.0

setlocal enabledelayedexpansion

REM Get script directory
set "SCRIPT_DIR=%~dp0"
set "MAIN_SCRIPT=%SCRIPT_DIR%singbox-install.sh"

REM Check if main script exists
if not exist "%MAIN_SCRIPT%" (
    echo Error: Cannot find singbox-install.sh script
    echo Please ensure sb.bat is in the same directory as singbox-install.sh
    pause
    exit /b 1
)

REM Check if bash is available
where bash >nul 2>&1
if %errorlevel% equ 0 (
    echo Using bash to execute script...
    bash "%MAIN_SCRIPT%" %*
) else (
    echo Error: bash environment not found
    echo Please install one of the following:
    echo 1. Git for Windows (Recommended)
    echo 2. Windows Subsystem for Linux (WSL)
    echo 3. Cygwin
    echo.
    echo Download links:
    echo Git for Windows: https://git-scm.com/download/win
    echo WSL Installation Guide: https://docs.microsoft.com/en-us/windows/wsl/install
    pause
    exit /b 1
)