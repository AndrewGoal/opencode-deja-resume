@echo off
setlocal EnableExtensions

rem opencode CLI shim (Windows).
rem
rem `deja resume <session-id> --exec` runs `opencode -s <session-id>`, which
rem this shim sends to the OpenCode desktop app: it writes a resume request and,
rem when the app is not running, starts it. The deja-resume GUI plugin in
rem %USERPROFILE%\.config\opencode\plugin\deja-resume reads the request and
rem opens the session's tab. Everything else falls back to the normal CLI.

set "SID="
if /I "%~1"=="-s" set "SID=%~2"
if /I "%~1"=="--session" set "SID=%~2"
if defined SID goto :resume

set "ARG=%~1"
if /I "%ARG:~0,4%"=="ses_" set "SID=%ARG%"
if /I "%ARG:~0,3%"=="-s=" set "SID=%ARG:~3%"
if /I "%ARG:~0,10%"=="--session=" set "SID=%ARG:~10%"
if defined SID goto :resume

goto :tui

:resume
set "DIR=%USERPROFILE%\.local\share\opencode"
if not exist "%DIR%" mkdir "%DIR%" >nul 2>&1
for /f %%t in ('powershell -NoProfile -Command "[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()"') do set "NOW=%%t"
> "%DIR%\deja-resume.json" echo {"session":"%SID%","time":%NOW%}

set "APP="
if exist "%OPENCODE_DESKTOP%" set "APP=%OPENCODE_DESKTOP%"
if not defined APP if exist "%LOCALAPPDATA%\Programs\opencode\OpenCode.exe" set "APP=%LOCALAPPDATA%\Programs\opencode\OpenCode.exe"
if not defined APP if exist "%LOCALAPPDATA%\Programs\OpenCode\OpenCode.exe" set "APP=%LOCALAPPDATA%\Programs\OpenCode\OpenCode.exe"
if not defined APP if exist "%ProgramFiles%\OpenCode\OpenCode.exe" set "APP=%ProgramFiles%\OpenCode\OpenCode.exe"
if not defined APP if exist "%USERPROFILE%\scoop\apps\opencode-desktop\current\OpenCode.exe" set "APP=%USERPROFILE%\scoop\apps\opencode-desktop\current\OpenCode.exe"

if defined APP (
  tasklist /FI "IMAGENAME eq OpenCode.exe" 2>nul | find /I "OpenCode.exe" >nul
  if errorlevel 1 start "" "%APP%"
)
exit /b 0

:tui
if exist "%USERPROFILE%\scoop\shims\opencode.exe" (
  "%USERPROFILE%\scoop\shims\opencode.exe" %*
  exit /b %ERRORLEVEL%
)
if exist "%USERPROFILE%\scoop\apps\opencode-desktop\current\resources\opencode-cli.exe" (
  "%USERPROFILE%\scoop\apps\opencode-desktop\current\resources\opencode-cli.exe" %*
  exit /b %ERRORLEVEL%
)
if exist "%ProgramFiles%\OpenCode\resources\opencode-cli.exe" (
  "%ProgramFiles%\OpenCode\resources\opencode-cli.exe" %*
  exit /b %ERRORLEVEL%
)
if exist "%LOCALAPPDATA%\Programs\opencode\resources\opencode-cli.exe" (
  "%LOCALAPPDATA%\Programs\opencode\resources\opencode-cli.exe" %*
  exit /b %ERRORLEVEL%
)
echo opencode: CLI not found >&2
exit /b 127
