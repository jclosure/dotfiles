@echo off
REM Check mail with remote mu4e from Windows.
REM Usage: check-mail.cmd --remote user@ubuntu
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0check-mail.ps1" %*
