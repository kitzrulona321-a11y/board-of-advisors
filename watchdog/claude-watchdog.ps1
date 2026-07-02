# Claude Board Watchdog v2
# Checks when Claude Code was last used. If silent past the threshold,
# emails you your board's get-back-on-track letter via Gmail SMTP.
# Run setup-watchdog.ps1 once before this works.
#
# Letter selection (three-tier fallback, reliability first):
#   1. AI-generated  - headless `claude -p` writes today's letter from your
#                      PROFILE.md + knowledge/wiki/ (runs on your existing
#                      Claude subscription; no API cost). Skipped if the
#                      claude CLI isn't installed.
#   2. Rotation      - random pre-written letter from letters\*.txt,
#                      falling back to letter.txt
#   3. Last resort   - short built-in message (only if 1 and 2 both fail)

param([switch]$Force)  # -Force sends regardless of thresholds (for testing)

$ErrorActionPreference = 'Stop'
$root       = Split-Path -Parent $MyInvocation.MyCommand.Path
$credPath   = Join-Path $root 'gmail-cred.xml'
$lettersDir = Join-Path $root 'letters'
$letterPath = Join-Path $root 'letter.txt'
$statePath  = Join-Path $root 'last-sent.txt'
$logPath    = Join-Path $root 'watchdog.log'

$projectDir     = Split-Path -Parent $root   # repo root: PROFILE.md + knowledge/ live here
$projectsDir    = Join-Path $env:USERPROFILE '.claude\projects'
$thresholdHours = 48    # silence longer than this = off track
$cooldownHours  = 48    # wait at least this long between emails
$genTimeoutSec  = 240   # max wait for the AI-generated letter

function Log($msg) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $msg" | Add-Content -Path $logPath -Encoding utf8
}

function Get-GeneratedLetter([int]$days, [double]$hours) {
    if ($null -eq (Get-Command claude -ErrorAction SilentlyContinue)) { return $null }
    $prompt = "You are the watchdog for the user's board of advisors. They have not used Claude Code for about $hours hours (~$days days) - their self-declared drift warning sign. Read PROFILE.md and every file in knowledge\wiki\. Then write TODAY'S get-back-on-track email: one short paragraph per advisor, each in that advisor's documented voice and vocabulary, matched to the coaching-style instructions in PROFILE.md. Reference their real goals and key dates. End with a numbered 'THE WAY BACK' list of 4 small steps, step 1 being: open Claude Code and type 'I drifted'. Plain text only - no markdown, advisor names in caps as the only headers, under 350 words. Output ONLY the email body, nothing else."
    try {
        $job = Start-Job -ScriptBlock {
            param($dir, $p)
            Set-Location $dir
            & claude -p $p --output-format text 2>$null
        } -ArgumentList $projectDir, $prompt
        if (Wait-Job $job -Timeout $genTimeoutSec) {
            $out = ((Receive-Job $job) -join "`n").Trim()
            Remove-Job $job -Force
            if ($out.Length -gt 200) { return $out }
            return $null
        }
        Stop-Job $job; Remove-Job $job -Force
        return $null
    } catch { return $null }
}

try {
    if (-not (Test-Path $credPath)) { Log 'No credential file. Run setup-watchdog.ps1 first.'; exit 0 }

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

    # Tier 1: AI-generated letter (headless Claude Code on your subscription)
    $body = Get-GeneratedLetter -days $days -hours $hoursSilent
    $source = 'AI-generated'

    # Tier 2: rotation - random pre-written letter (letters\*.txt, else letter.txt)
    if (-not $body) {
        $pick = Get-ChildItem -Path $lettersDir -Filter '*.txt' -ErrorAction SilentlyContinue | Get-Random
        if (-not $pick -and (Test-Path $letterPath)) { $pick = Get-Item $letterPath }
        if ($pick) {
            $body = (Get-Content $pick.FullName -Raw).Replace('{DAYS}', $days).Replace('{HOURS}', $hoursSilent)
            $source = "rotation ($($pick.Name))"
        }
    }

    # Tier 3: last resort
    if (-not $body) {
        $source = 'last-resort'
        $body = @"
It's been about $hoursSilent hours without Claude Code - your own
early-warning sign. Open Claude Code, type "I drifted", and run
/ask-the-board. Getting back on track IS the win. - The Board
"@
    }

    $subject = "[THE BOARD] It's been $days+ days. Time to come back."

    Send-MailMessage -From $cred.UserName -To $cred.UserName `
        -Subject $subject -Body $body `
        -SmtpServer 'smtp.gmail.com' -Port 587 -UseSsl `
        -Credential $cred -Encoding ([System.Text.Encoding]::UTF8)

    Get-Date -Format 'o' | Set-Content -Path $statePath
    Log "Board letter SENT via $source ($hoursSilent hours silent, Force=$Force)."
}
catch {
    Log "ERROR: $($_.Exception.Message)"
    exit 1
}
