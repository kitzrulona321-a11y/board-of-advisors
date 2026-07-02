# Claude Board Watchdog
# Checks when Claude Code was last used. If silent past the threshold,
# emails you your board's get-back-on-track letter via Gmail SMTP.
# Run setup-watchdog.ps1 once before this works.
# Customize the email content in letter.txt (created from letter.template.txt by setup).

param([switch]$Force)  # -Force sends regardless of thresholds (for testing)

$ErrorActionPreference = 'Stop'
$root       = Split-Path -Parent $MyInvocation.MyCommand.Path
$credPath   = Join-Path $root 'gmail-cred.xml'
$letterPath = Join-Path $root 'letter.txt'
$statePath  = Join-Path $root 'last-sent.txt'
$logPath    = Join-Path $root 'watchdog.log'

$projectsDir    = Join-Path $env:USERPROFILE '.claude\projects'
$thresholdHours = 48   # silence longer than this = off track
$cooldownHours  = 48   # wait at least this long between emails

function Log($msg) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $msg" | Add-Content -Path $logPath -Encoding utf8
}

try {
    if (-not (Test-Path $credPath))   { Log 'No credential file. Run setup-watchdog.ps1 first.'; exit 0 }
    if (-not (Test-Path $letterPath)) { Log 'No letter.txt. Run setup-watchdog.ps1 first.'; exit 0 }

    $latest = Get-ChildItem -Path $projectsDir -Recurse -File |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($null -eq $latest) { Log 'No Claude session files found.'; exit 0 }

    $hoursSilent = [math]::Round(((Get-Date) - $latest.LastWriteTime).TotalHours, 1)

    if (-not $Force -and $hoursSilent -lt $thresholdHours) {
        Log "On track. Last Claude activity $hoursSilent hours ago."
        exit 0
    }

    if (-not $Force -and (Test-Path $statePath)) {
        $lastSent = [datetime](Get-Content $statePath -TotalCount 1)
        $sinceSent = ((Get-Date) - $lastSent).TotalHours
        if ($sinceSent -lt $cooldownHours) {
            Log "Off track ($hoursSilent h) but letter already sent $([math]::Round($sinceSent,1)) h ago. Cooldown."
            exit 0
        }
    }

    $cred = Import-Clixml $credPath
    $days = [math]::Floor($hoursSilent / 24)

    # letter.txt supports two placeholders: {DAYS} and {HOURS}
    $subject = "[THE BOARD] It's been $days+ days. Time to come back."
    $body = (Get-Content $letterPath -Raw).Replace('{DAYS}', $days).Replace('{HOURS}', $hoursSilent)

    Send-MailMessage -From $cred.UserName -To $cred.UserName `
        -Subject $subject -Body $body `
        -SmtpServer 'smtp.gmail.com' -Port 587 -UseSsl `
        -Credential $cred -Encoding ([System.Text.Encoding]::UTF8)

    Get-Date -Format 'o' | Set-Content -Path $statePath
    Log "Board letter SENT ($hoursSilent hours silent, Force=$Force)."
}
catch {
    Log "ERROR: $($_.Exception.Message)"
    exit 1
}
