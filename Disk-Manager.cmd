@echo off
setlocal
set "PYTHONW=%~dp0..\..\work\mame-build\msys64\ucrt64\bin\pythonw.exe"
start "" /wait "%PYTHONW%" "%~dp0tools\disk_manager_gui.py"
exit /b %errorlevel%
