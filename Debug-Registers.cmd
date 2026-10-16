@echo off
setlocal

rem Build NDOS first
call "%~dp0Build.cmd"
if errorlevel 1 exit /b 1

rem Make sure the J68K NVRAM directory exists
if not exist "%~dp0disk\j68k" (
    mkdir "%~dp0disk\j68k"
)

rem Run from the build directory
pushd "%~dp0build"
if errorlevel 1 exit /b 1

rem Launch J68K with the MAME debugger
"%~dp0..\j68k-mame\bin\j68k-nvram.exe" j68k ^
    -rompath "%~dp0build\roms" ^
    -nvram_directory "%~dp0disk" ^
    -window ^
    -video gdi ^
    -sound none ^
    -skip_gameinfo ^
    -speed 1.0 ^
    -log ^
    -debug ^
    -debugscript "%~dp0cfg\mame\registers.cmd"

set "RESULT=%errorlevel%"

popd
endlocal & exit /b %RESULT%