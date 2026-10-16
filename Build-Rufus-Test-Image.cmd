@echo off
setlocal
pushd "%~dp0"
call "%~dp0Build.cmd"
if errorlevel 1 exit /b 1
"%~dp0..\..\work\mame-build\msys64\ucrt64\bin\python.exe" "%~dp0tools\make_disk.py" "%~dp0build\system.json" "%~dp0build\disks\NDOS-1.1-RUFUS-TEST.img" --layout floppy-1440k
set "RESULT=%errorlevel%"
popd
exit /b %RESULT%
