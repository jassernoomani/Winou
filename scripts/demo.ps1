# Starts Winou on this laptop for a demo, and says which address to type in the app.
#
#   powershell -ExecutionPolicy Bypass -File scripts\demo.ps1          # start
#   powershell -ExecutionPolicy Bypass -File scripts\demo.ps1 -Stop    # stop everything
#
# Connect the phone one of two ways:
#   - USB cable: the script forwards the phone's port 8080 here; in the app use 127.0.0.1
#   - hotspot: turn on the phone's hotspot, join it from the laptop; in the app use the
#     laptop's address printed below (most Wi-Fi routers keep their clients apart, hotspots don't)
param([switch]$Stop)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

# Docker Desktop is installed per user; its CLI may not be on PATH in older shells
$dockerHome = Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop'
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { $env:Path += ";$dockerHome\resources\bin" }
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'

function Test-Docker {
    try { docker info *> $null; return $LASTEXITCODE -eq 0 } catch { return $false }
}

if ($Stop) {
    docker compose stop
    Write-Host 'Winou stopped. Data is kept for next time.'
    exit 0
}

Write-Host '== Docker'
if (-not (Test-Docker)) {
    Write-Host 'Starting Docker Desktop...'
    Start-Process (Join-Path $dockerHome 'Docker Desktop.exe')
    $deadline = (Get-Date).AddMinutes(3)
    while (-not (Test-Docker)) {
        if ((Get-Date) -gt $deadline) { throw 'Docker Desktop did not start within 3 minutes. Start it by hand and rerun.' }
        Start-Sleep -Seconds 3
    }
}

Write-Host '== Winou (backend, worker, ML service, database)'
docker compose up -d
if ($LASTEXITCODE -ne 0) { throw 'docker compose up failed' }
Write-Host -NoNewline 'Waiting for the API'
$deadline = (Get-Date).AddMinutes(4)
$up = $false
while (-not $up) {
    try { $up = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 http://localhost:8080/health).StatusCode -eq 200 } catch { }
    if (-not $up) {
        if ((Get-Date) -gt $deadline) { throw "`nThe API did not answer. Logs: docker compose logs api" }
        Write-Host -NoNewline '.'
        Start-Sleep -Seconds 3
    }
}
Write-Host ' up.'

Write-Host '== Firewall'
# Docker's own rule only covers "Public" networks; a hotspot may be "Private"
if (Get-NetFirewallRule -DisplayName 'Winou API' -ErrorAction SilentlyContinue) {
    Write-Host 'Port 8080 is open on every network.'
} else {
    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($admin) {
        New-NetFirewallRule -DisplayName 'Winou API' -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow -Profile Any | Out-Null
        Write-Host 'Opened port 8080 on every network.'
    } else {
        Write-Host 'Port 8080 may be blocked on private networks. Once, in an admin PowerShell:' -ForegroundColor Yellow
        Write-Host "  New-NetFirewallRule -DisplayName 'Winou API' -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow -Profile Any"
    }
}

Write-Host ''
Write-Host '== In the app: Server address (gear on the sign-in screen, or My activity > menu)' -ForegroundColor Cyan
$usb = $false
if (Test-Path $adb) {
    $devices = & $adb devices | Select-String -Pattern "`tdevice$"
    if ($devices) {
        & $adb reverse tcp:8080 tcp:8080 | Out-Null
        $usb = $true
        Write-Host '  USB cable:         127.0.0.1' -ForegroundColor Green
    }
}
$addresses = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.PrefixOrigin -in 'Dhcp', 'Manual' -and $_.InterfaceAlias -notmatch 'vEthernet|WSL|Docker|Loopback' }
foreach ($a in $addresses) {
    Write-Host ("  {0,-18} {1}" -f ($a.InterfaceAlias + ':'), $a.IPAddress) -ForegroundColor Green
}
if (-not $usb -and -not $addresses) {
    Write-Host '  No network: plug the phone in by USB, or join its hotspot, then rerun.' -ForegroundColor Yellow
}
Write-Host ''
Write-Host 'Live match for the audience: python scripts\seed_demo.py sighting'
Write-Host 'Stop afterwards:           powershell -ExecutionPolicy Bypass -File scripts\demo.ps1 -Stop'
