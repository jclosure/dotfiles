@echo off
REM Launch remote Ubuntu terminal Emacs directly into mu4e Inbox.
REM Delegates to the PowerShell launcher so URL forwarding is enabled.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0mu4e-ubuntu.ps1"
