@echo off
setlocal
if not exist "%~dp0build\disks\ndos-system.img" call "%~dp0Build.cmd"
if errorlevel 1 exit /b 1
set "PYTHON=%~dp0..\..\work\mame-build\msys64\ucrt64\bin\python.exe"
"%PYTHON%" "%~dp0tools\disk_manager.py" --install
exit /b %errorlevel%
