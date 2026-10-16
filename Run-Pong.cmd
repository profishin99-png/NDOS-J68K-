@echo off
setlocal
call "%~dp0Run-NDOS.cmd" -autoboot_script "%~dp0luatests\play-pong.lua"
exit /b %errorlevel%
