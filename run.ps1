param(
    [Parameter(Mandatory=$true)]
    [string]$DESTINATION,
    
    [Parameter(Mandatory=$true)]
    [string]$PORT,
    
    [Parameter(Mandatory=$true)]
    [string]$CHAT
)

# Clone Odoo directory
Write-Host "Cloning Odoo repository..." -ForegroundColor Green
git clone --depth=1 https://github.com/minaonlyone/odoo-18-docker-compose $DESTINATION
if (Test-Path "$DESTINATION\.git") {
    Remove-Item -Recurse -Force "$DESTINATION\.git"
}

# Create PostgreSQL directory
New-Item -ItemType Directory -Force -Path "$DESTINATION\postgresql" | Out-Null

# Note: Windows doesn't use chown/chmod like Unix systems
# File permissions are managed differently on Windows
Write-Host "Setting up directory structure..." -ForegroundColor Green

# Note: inotify is Linux-specific, not needed on Windows
Write-Host "Running on Windows. Skipping inotify configuration." -ForegroundColor Yellow

# Set ports in docker-compose.yml
Write-Host "Updating docker-compose.yml with ports..." -ForegroundColor Green
$dockerComposeFile = "$DESTINATION\docker-compose.yml"
if (Test-Path $dockerComposeFile) {
    $content = Get-Content $dockerComposeFile -Raw
    $content = $content -replace '10018', $PORT
    $content = $content -replace '20018', $CHAT
    Set-Content -Path $dockerComposeFile -Value $content -NoNewline
} else {
    Write-Host "Error: docker-compose.yml not found!" -ForegroundColor Red
    exit 1
}

# Ensure entrypoint.sh exists and has Unix line endings (LF) for Linux container
Write-Host "Preparing entrypoint.sh for Linux container..." -ForegroundColor Green
$entrypointFile = "$DESTINATION\entrypoint.sh"
if (Test-Path $entrypointFile) {
    # Convert CRLF to LF for Linux compatibility
    $content = Get-Content $entrypointFile -Raw
    $content = $content -replace "`r`n", "`n"
    $content = $content -replace "`r", "`n"
    [System.IO.File]::WriteAllText($entrypointFile, $content, [System.Text.Encoding]::UTF8)
    Write-Host "entrypoint.sh prepared with Unix line endings" -ForegroundColor Green
} else {
    Write-Host "Warning: entrypoint.sh not found in cloned repository!" -ForegroundColor Yellow
    Write-Host "The docker-compose.yml expects entrypoint.sh to exist." -ForegroundColor Yellow
}

# Run Odoo
Write-Host "Starting Odoo containers..." -ForegroundColor Green
$dockerComposeCmd = "docker compose"
$dockerComposeLegacyCmd = "docker-compose"

# Check which docker-compose command is available
$composeAvailable = $false
try {
    $null = docker compose version 2>&1
    $composeAvailable = $true
    $dockerComposeCmd = "docker compose"
} catch {
    try {
        $null = docker-compose version 2>&1
        $composeAvailable = $true
        $dockerComposeCmd = "docker-compose"
    } catch {
        Write-Host "Error: Neither 'docker compose' nor 'docker-compose' found!" -ForegroundColor Red
        exit 1
    }
}

Push-Location $DESTINATION
try {
    if ($dockerComposeCmd -eq "docker compose") {
        docker compose -f docker-compose.yml up -d
    } else {
        docker-compose -f docker-compose.yml up -d
    }
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Odoo started successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "URL: http://localhost:$PORT" -ForegroundColor Cyan
Write-Host "Master Password: smartsupport.tech" -ForegroundColor Cyan
Write-Host "Live chat port: $CHAT" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Green

