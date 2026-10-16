@echo off
setlocal
pushd "%~dp0"
"%~dp0..\..\work\mame-build\msys64\ucrt64\bin\python.exe" "%~dp0build.py"
set "RESULT=%errorlevel%"
popd
exit /b %RESULT%
