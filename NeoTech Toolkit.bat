@echo off
REM =============================================================================
REM  NeoTech Toolkit - Lanceur Windows (CMD)
REM  Auteur : Neo Soda - TechSentinel.fr
REM  - Sans argument : lance la version GUI (WPF, fenetre moderne)
REM  - Avec argument CONSOLE : lance l'interface texte
REM =============================================================================

setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "LOG_DIR=%SCRIPT_DIR%\Logs"
set "LOG_FILE=%LOG_DIR%\launcher.log"

REM --- Quel mode ? GUI par defaut, ou console si passe en argument
set "MODE=GUI"
if /I "%1"=="CONSOLE" set "MODE=CONSOLE"
if /I "%1"=="--CONSOLE" set "MODE=CONSOLE"
if /I "%1"=="-C" set "MODE=CONSOLE"

if "%MODE%"=="GUI" (
    set "PS_SCRIPT=%SCRIPT_DIR%\NeoTech-Toolkit-GUI.ps1"
    set "PS_ARGS=-STA -NoProfile -ExecutionPolicy RemoteSigned -File"
) else (
    set "PS_SCRIPT=%SCRIPT_DIR%\NeoTech-Toolkit.ps1"
    set "PS_ARGS=-NoProfile -ExecutionPolicy RemoteSigned -File"
    mode con: cols=130 lines=42 >nul 2>&1
    title NeoTech Toolkit - Console
)

if not exist "%PS_SCRIPT%" (
    echo ERREUR : script introuvable : %PS_SCRIPT%
    pause
    exit /b 1
)
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1

echo [%DATE% %TIME%] Lancement %MODE% depuis %SCRIPT_DIR%>> "%LOG_FILE%"

powershell.exe %PS_ARGS% "%PS_SCRIPT%"
set "PS_EXIT=%ERRORLEVEL%"

echo [%DATE% %TIME%] PowerShell termine, exit code %PS_EXIT%>> "%LOG_FILE%"

if not "%PS_EXIT%"=="0" (
    echo.
    echo  ============================================================
    echo   NeoTech Toolkit s'est termine avec une erreur (code %PS_EXIT%^)
    echo  ============================================================
    echo  Log : %LOG_FILE%
    echo.
    pause
)

exit /b %PS_EXIT%
