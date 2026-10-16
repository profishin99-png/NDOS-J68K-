@echo off
setlocal
call "%~dp0Build.cmd"
if errorlevel 1 exit /b 1
"%SystemRoot%\System32\tasklist.exe" /FI "IMAGENAME eq j68k-nvram.exe" /NH | "%SystemRoot%\System32\find.exe" /I "j68k-nvram.exe" >nul
if not errorlevel 1 (
  echo ERROR: Close the existing J68K MAME window before restarting it.
  exit /b 1
)
"%SystemRoot%\System32\tasklist.exe" /FI "IMAGENAME eq j68k.exe" /NH | "%SystemRoot%\System32\find.exe" /I "j68k.exe" >nul
if not errorlevel 1 (
  echo ERROR: Close the existing J68K MAME window before restarting it.
  exit /b 1
)
set "PYTHON=%~dp0..\..\work\mame-build\msys64\ucrt64\bin\python.exe"
"%PYTHON%" "%~dp0tools\disk_manager.py" --prepare
if errorlevel 1 exit /b 1
"%PYTHON%" "%~dp0tools\sdcard_manager.py" --prepare
if errorlevel 1 exit /b 1
rem Deploy the current reduced J68K target after a successful build.  This
rem This remains separate from the live RAM-disk file and only runs before MAME starts.
copy /y "%~dp0..\..\work\mame-build\mame-mame0289\j68k.exe" "%~dp0..\j68k-mame\bin\j68k-nvram.exe" >nul
if errorlevel 1 exit /b 1
pushd "%~dp0build"
if not exist "%~dp0disk\j68k" mkdir "%~dp0disk\j68k"
rem Open the MAME raster window for the temporary 320x200 framebuffer.
rem The MC68681 serial terminal remains a separate window for the NDOS shell.
"%~dp0..\j68k-mame\bin\j68k-nvram.exe" j68k -rompath "%~dp0build\roms" -nvram_directory "%~dp0disk" -sdcard "%~dp0disk\j68k\sdcard.img" -numscreens 2 -window -ui_active -nomaximize -nokeepaspect -screen0 auto -view0 standard -resolution0 960x600 -screen1 auto -view1 standard -resolution1 960x600 -video gdi -sound none -skip_gameinfo %*
set "RESULT=%errorlevel%"
popd
exit /b %RESULT%
