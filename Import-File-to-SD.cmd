@echo off
setlocal
set "PYTHON=%~dp0..\..\work\mame-build\msys64\ucrt64\bin\python.exe"
set "PYTHONW=%~dp0..\..\work\mame-build\msys64\ucrt64\bin\pythonw.exe"

rem Prepare only when absent; preserve a valid existing SD image. This also
rem refuses to modify the image while MAME has it open.
"%PYTHON%" "%~dp0tools\sdcard_manager.py" --prepare
if errorlevel 1 exit /b 1

if "%~1"=="" (
  start "" /wait "%PYTHONW%" "%~dp0tools\import_file_gui.py" --sd
  exit /b %errorlevel%
)

if "%~2"=="" (
  start "" /wait "%PYTHONW%" "%~dp0tools\import_file_gui.py" --sd "%~f1"
  exit /b %errorlevel%
)

rem Explicit destination form: Import-File-to-SD.cmd host-file DEST.EXT
"%PYTHON%" "%~dp0tools\fat12_import.py" "%~dp0disk\j68k\sdcard.img" "%~f1" "%~2"
exit /b %errorlevel%
