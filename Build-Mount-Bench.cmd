@echo off
setlocal
pushd "%~dp0"

rem Assemble NDOS, the ROM image, and every supplied NEX application.
call "%~dp0Build.cmd"
if errorlevel 1 goto :failed

rem Replace only BENCH.NEX on the live persistent FAT12 disk.  The importer
rem refuses this operation when J68K MAME is running.
call "%~dp0Import-File.cmd" "%~dp0build\apps\BENCH.NEX" BENCH.NEX
if errorlevel 1 goto :failed

echo.
echo PASS: BENCH.NEX assembled and mounted on the live NDOS disk.
echo Start or restart NDOS, then type: RUN BENCH.NEX
popd
exit /b 0

:failed
echo.
echo BENCH build or mount failed.  If MAME is open, close it and run this again.
popd
exit /b 1
