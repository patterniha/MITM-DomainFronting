@echo off
setlocal EnableExtensions

rem Easy offline certificate generator for MITM-DomainFronting.
rem Put this file in the v2rayN bin folder or any folder where xray.exe is available.
rem It creates mycert.crt and mycert.key in the current folder.

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%" || (
  echo Could not enter script directory.
  pause
  exit /b 1
)

set "XRAY_BIN="
if exist "%SCRIPT_DIR%xray\xray.exe" set "XRAY_BIN=%SCRIPT_DIR%xray\xray.exe"
if not defined XRAY_BIN if exist "%SCRIPT_DIR%xray.exe" set "XRAY_BIN=%SCRIPT_DIR%xray.exe"
if not defined XRAY_BIN for %%X in (xray.exe) do if not defined XRAY_BIN set "XRAY_BIN=%%~$PATH:X"

if not defined XRAY_BIN (
  echo xray.exe was not found.
  echo Put this file in the v2rayN bin folder, or add xray.exe to PATH.
  pause
  exit /b 1
)

echo Generating local CA files using Xray...
"%XRAY_BIN%" tls cert -ca -file=mycert >nul
if errorlevel 1 (
  echo Xray failed to generate certificate files.
  pause
  exit /b 1
)

echo.
echo Created:
echo   %CD%\mycert.crt
echo   %CD%\mycert.key
echo.
echo Keep mycert.key private. Do not post it in issues or send it to anyone.
echo Install mycert.crt into the intended OS/browser trust store, then verify fingerprint.
pause
