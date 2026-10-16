@echo off
setlocal
cd /d "%~dp0"

set "PYTHON=%LocalAppData%\Programs\Python\Python312\python.exe"
if exist "%PYTHON%" goto run_fixed

set "PYTHON=%LocalAppData%\Programs\Python\Python311\python.exe"
if exist "%PYTHON%" goto run_fixed

if exist "%SystemRoot%\py.exe" goto run_py

for /f "delims=" %%P in ('powershell -NoProfile -Command "(Get-Command python.exe -ErrorAction SilentlyContinue).Source"') do set "PYTHON=%%P"
if defined PYTHON if exist "%PYTHON%" goto run_fixed

echo Python was not found.
echo Install Python 3 and Pillow, then run:
echo   py -m pip install Pillow
pause
exit /b 1

:run_fixed
"%PYTHON%" tools\png2j68k_gui.py
exit /b %errorlevel%

:run_py
py tools\png2j68k_gui.py
exit /b %errorlevel%
