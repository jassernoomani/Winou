# Keeps <name>.duckdns.org pointing at this PC when the home IP changes: a scheduled task that
# calls DuckDNS every 5 minutes, as you, no admin needed. Run once:
#
#   powershell -ExecutionPolicy Bypass -File deploy\windows\install-duckdns-task.ps1 winou
#
# The token is read from secrets\duckdns-token.txt (git-ignored). Remove the task with:
#   Unregister-ScheduledTask -TaskName 'Winou DuckDNS'
param([Parameter(Mandatory)][string]$Subdomain)

$tokenFile = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'secrets\duckdns-token.txt'
$token = (Get-Content -Raw $tokenFile).Trim()
$url = "https://www.duckdns.org/update?domains=$Subdomain&token=$token&ip="

$action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\curl.exe" -Argument "-fsS -o NUL `"$url`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 5)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden
Register-ScheduledTask -TaskName 'Winou DuckDNS' -Description "Keeps $Subdomain.duckdns.org pointing at this PC" `
    -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null

Write-Host "DuckDNS now: $(curl.exe -fsS $url)  (OK = updated)"
Write-Host "Scheduled every 5 minutes as 'Winou DuckDNS'."
