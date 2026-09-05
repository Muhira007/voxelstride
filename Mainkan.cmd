@echo off
setlocal
cd /d "%~dp0"
if exist "build\DuniaMinecraft.exe" (
    start "" "build\DuniaMinecraft.exe"
    exit /b 0
)
if exist ".tools\godot\Godot_v4.6.1-stable_win64.exe" (
    start "" ".tools\godot\Godot_v4.6.1-stable_win64.exe" --path "%~dp0."
    exit /b 0
)
echo Jalankan tools\build.ps1 dahulu, atau unduh game dari GitHub Releases.
pause
