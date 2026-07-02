# One-time setup for the Claude Board Watchdog.
# RUN THIS YOURSELF in a normal PowerShell window:
#   powershell -ExecutionPolicy Bypass -File "<path-to>\watchdog\setup-watchdog.ps1"
#
# You will need a Gmail App Password:
#   Google Account > Security > 2-Step Verification > App passwords > create one for "Mail"

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ''
Write-Host '=== Claude Board Watchdog Setup ===' -ForegroundColor Cyan
$email = Read-Host 'Your Gmail address'
Write-Host 'Paste your 16-character Gmail App Password (input is hidden):'
$sec = Read-Host -AsSecureString

# Store DPAPI-encrypted: only YOUR Windows user on THIS machine can decrypt it.
$cred = New-Object System.Management.Automation.PSCredential($email, $sec)
$cred | Export-Clixml -Path (Join-Path $root 'gmail-cred.xml')
Write-Host 'Credential stored (encrypted with Windows DPAPI).' -ForegroundColor Green

# Create letter.txt from the template if it doesn't exist yet.
$letterPath = Join-Path $root 'letter.txt'
if (-not (Test-Path $letterPath)) {
    Copy-Item (Join-Path $root 'letter.template.txt') $letterPath
    Write-Host 'Created letter.txt from template - customize it with YOUR advisors'' voices.' -ForegroundColor Yellow
}

# Register the daily scheduled task (9:00 AM, runs even on battery).
$scriptPath = Join-Path $root 'claude-watchdog.ps1'
$action   = New-ScheduledTaskAction -Execute 'powershell.exe' `
            -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger  = New-ScheduledTaskTrigger -Daily -At 9:00AM
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName 'ClaudeBoardWatchdog' -Action $action -Trigger $trigger `
    -Settings $settings -Description 'Emails the board letter if Claude Code has been silent 48+ hours' -Force | Out-Null
Write-Host "Scheduled task 'ClaudeBoardWatchdog' registered (daily, 9:00 AM)." -ForegroundColor Green

# Test-fire one email right now (ignores thresholds).
Write-Host ''
Write-Host 'Sending a TEST board letter to your inbox...' -ForegroundColor Yellow
& $scriptPath -Force
Write-Host "Done. Check $email - the board letter should arrive within a minute." -ForegroundColor Green
Write-Host 'If it did not arrive, open watchdog.log in this folder for the error.'
