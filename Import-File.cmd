@echo off
setlocal
"%SystemRoot%\System32\tasklist.exe" /FI "IMAGENAME eq j68k-nvram.exe" /NH | "%SystemRoot%\System32\find.exe" /I "j68k-nvram.exe" >nul
if not errorlevel 1 (
  echo ERROR: Close the J68K MAME window before importing files into the live disk.
  exit /b 1
)
"%SystemRoot%\System32\tasklist.exe" /FI "IMAGENAME eq j68k.exe" /NH | "%SystemRoot%\System32\find.exe" /I "j68k.exe" >nul
if not errorlevel 1 (
  echo ERROR: Close the J68K MAME window before importing files into the live disk.
  exit /b 1
)
set "PYTHON=%~dp0..\..\work\mame-build\msys64\ucrt64\bin\python.exe"
set "PYTHONW=%~dp0..\..\work\mame-build\msys64\ucrt64\bin\pythonw.exe"
if "%~1"=="" (
  start "" /wait "%PYTHONW%" "%~dp0tools\import_file_gui.py"
  exit /b %errorlevel%
)
if "%~2"=="" (
  start "" /wait "%PYTHONW%" "%~dp0tools\import_file_gui.py" "%~f1"
  exit /b %errorlevel%
)
set "DEST=%~2"
"%PYTHON%" "%~dp0tools\fat12_import.py" --replace "%~dp0disk\j68k\ramdisk" "%~f1" "%DEST%"
exit /b %errorlevel%
