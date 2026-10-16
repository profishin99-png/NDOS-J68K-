@echo off
setlocal
set "ROOT=%~dp0"
set "PYTHON=%ROOT%..\..\work\mame-build\msys64\ucrt64\bin\python.exe"
pushd "%ROOT%"
call "%ROOT%Build.cmd"
if errorlevel 1 (
  popd
  exit /b 1
)
"%PYTHON%" "%ROOT%tools\sdcard_manager.py" --update-ndos
set "RESULT=%errorlevel%"
popd
if not "%RESULT%"=="0" pause
exit /b %RESULT%
