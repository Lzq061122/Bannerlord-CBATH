@echo off
REM P1-003 green run.
REM Step 1: get the payload through the DSH official MCP client (mcp__gabs__games_call_tool
REM         with tool "cbath/get_all_formations") while a real battle is running, and save
REM         its JSON text to %TEMP%\cbath-p1-003-payload.json
REM Step 2: run this file to assert it.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0test-p1-003.ps1" -PayloadFile "%TEMP%\cbath-p1-003-payload.json"
echo EXIT=%ERRORLEVEL%
