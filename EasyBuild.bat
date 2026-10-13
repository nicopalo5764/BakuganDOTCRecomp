@echo off
rem One-click build: double-click this file.
title Bakugan DOTC Recompiled - EasyBuild
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Easy-Build.ps1" %*
echo.
pause
