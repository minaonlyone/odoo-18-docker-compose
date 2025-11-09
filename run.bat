@echo off
setlocal enabledelayedexpansion

REM Check if all required parameters are provided
if "%~1"=="" (
    echo Error: Destination path is required
    echo Usage: run.bat DESTINATION PORT CHAT
    echo Example: run.bat C:\odoo 10018 20018
    exit /b 1
)

if "%~2"=="" (
    echo Error: Port is required
    echo Usage: run.bat DESTINATION PORT CHAT
    echo Example: run.bat C:\odoo 10018 20018
    exit /b 1
)

if "%~3"=="" (
    echo Error: Chat port is required
    echo Usage: run.bat DESTINATION PORT CHAT
    echo Example: run.bat C:\odoo 10018 20018
    exit /b 1
)

set DESTINATION=%~1
set PORT=%~2
set CHAT=%~3

REM Clone Odoo directory
echo Cloning Odoo repository...
git clone --depth=1 https://github.com/minaonlyone/odoo-18-docker-compose %DESTINATION%
if exist "%DESTINATION%\.git" (
    rmdir /s /q "%DESTINATION%\.git"
)

REM Create PostgreSQL directory
if not exist "%DESTINATION%\postgresql" (
    mkdir "%DESTINATION%\postgresql"
)

echo Setting up directory structure...
echo Running on Windows. Skipping inotify configuration.

REM Set ports in docker-compose.yml
echo Updating docker-compose.yml with ports...
set DOCKER_COMPOSE_FILE=%DESTINATION%\docker-compose.yml

REM Use PowerShell for string replacement in batch file
powershell -Command "(Get-Content '%DOCKER_COMPOSE_FILE%') -replace '10018', '%PORT%' -replace '20018', '%CHAT%' | Set-Content '%DOCKER_COMPOSE_FILE%'"

if not exist "%DOCKER_COMPOSE_FILE%" (
    echo Error: docker-compose.yml not found!
    exit /b 1
)

REM Ensure entrypoint.sh exists and has Unix line endings (LF) for Linux container
echo Preparing entrypoint.sh for Linux container...
set ENTRYPOINT_FILE=%DESTINATION%\entrypoint.sh
if exist "%ENTRYPOINT_FILE%" (
    REM Convert CRLF to LF and remove BOM for Linux compatibility using PowerShell
    powershell -Command "$bytes = [System.IO.File]::ReadAllBytes('%ENTRYPOINT_FILE%'); $content = [System.Text.Encoding]::UTF8.GetString($bytes); if ($content.StartsWith([char]0xFEFF)) { $content = $content.Substring(1) }; $content = $content -replace \"`r`n\", \"`n\"; $content = $content -replace \"`r\", \"`n\"; $utf8NoBom = New-Object System.Text.UTF8Encoding $false; [System.IO.File]::WriteAllText('%ENTRYPOINT_FILE%', $content, $utf8NoBom)"
    echo entrypoint.sh prepared with Unix line endings (LF, no BOM)
) else (
    echo Warning: entrypoint.sh not found in cloned repository!
    echo The docker-compose.yml expects entrypoint.sh to exist.
)

REM Check which docker-compose command is available
echo Starting Odoo containers...
docker compose version >nul 2>&1
if %errorlevel% equ 0 (
    set DOCKER_COMPOSE_CMD=docker compose
) else (
    docker-compose version >nul 2>&1
    if %errorlevel% equ 0 (
        set DOCKER_COMPOSE_CMD=docker-compose
    ) else (
        echo Error: Neither 'docker compose' nor 'docker-compose' found!
        exit /b 1
    )
)

REM Change to destination directory and run docker-compose
cd /d %DESTINATION%
%DOCKER_COMPOSE_CMD% -f docker-compose.yml up -d
cd /d %~dp0

echo.
echo ========================================
echo Odoo started successfully!
echo ========================================
echo URL: http://localhost:%PORT%
echo Master Password: smartsupport.tech
echo Live chat port: %CHAT%
echo ========================================

endlocal

