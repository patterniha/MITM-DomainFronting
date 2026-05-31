@echo off
setlocal EnableExtensions

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

set "OUT_DIR=%CD%"
set "WRITE_TEST=%OUT_DIR%\.mitm-write-test.tmp"
> "%WRITE_TEST%" echo test 2>nul
if errorlevel 1 (
  set "OUT_DIR=%USERPROFILE%\Desktop\MITM-DomainFronting-cert"
) else (
  del "%WRITE_TEST%" >nul 2>nul
)

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%" >nul 2>nul
if not exist "%OUT_DIR%" (
  echo Could not create output folder:
  echo %OUT_DIR%
  pause
  exit /b 1
)

set "TMP_JSON=%TEMP%\mitm-domainfronting-cert-%RANDOM%.json"
"%XRAY_BIN%" tls cert -ca > "%TMP_JSON%"
if errorlevel 1 (
  echo xray failed to generate the certificate.
  if exist "%TMP_JSON%" type "%TMP_JSON%"
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $j=Get-Content -Raw -Path $env:TMP_JSON | ConvertFrom-Json; [IO.File]::WriteAllText((Join-Path $env:OUT_DIR 'mycert.crt'), (($j.certificate -join [Environment]::NewLine) + [Environment]::NewLine)); [IO.File]::WriteAllText((Join-Path $env:OUT_DIR 'mycert.key'), (($j.key -join [Environment]::NewLine) + [Environment]::NewLine))"
if errorlevel 1 (
  echo Could not parse xray certificate output.
  if exist "%TMP_JSON%" type "%TMP_JSON%"
  pause
  exit /b 1
)

del "%TMP_JSON%" >nul 2>nul

echo Created:
echo   %OUT_DIR%\mycert.crt
echo   %OUT_DIR%\mycert.key
echo.
echo Keep mycert.key private. Do not send it to anyone.
if /I not "%OUT_DIR%"=="%CD%" (
  echo.
  echo The current folder was not writable, so the files were written to Desktop.
  echo Copy both files next to this Xray config before running MITM-DomainFronting.
)
pause
