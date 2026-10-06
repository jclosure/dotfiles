@echo off
REM Launch remote Ubuntu terminal Emacs directly into mu4e Inbox.
REM Usage: check-remote-mail.cmd user@ubuntu
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0check-remote-mail.ps1" %*
