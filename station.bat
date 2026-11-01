@echo off
rem The bot station on a second PC (station.ps1): 15 headless bots joining the host, the build kept up to date.
rem Edit the address below if the host's machine has another one on the network.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0station.ps1" -HostAddress 192.168.0.3 -Count 15 %*
pause
