# Claude Board Watchdog

The drift-detection layer of the board: emails you your advisors' get-back-on-track
letter when Claude Code has been silent for 48+ hours. Scheduled reminders handle
your *tasks*; this handles your *disappearing* — and it only speaks when you've
actually gone dark.

## How it works
- A Windows Scheduled Task (`ClaudeBoardWatchdog`) runs `claude-watchdog.ps1` daily.
- The script checks the newest file-modified time under `%USERPROFILE%\.claude\projects\`
  (Claude Code session transcripts — a reliable proxy for "last time you showed up").
- Silent < 48h → logs "on track", does nothing.
- Silent ≥ 48h → sends your customized `letter.txt` from/to your own Gmail via SMTP.
- Cooldown: at most one letter per 48h. Everything logs to `watchdog.log`.

## Setup (one time, Windows)
1. Create a Gmail App Password: Google Account → Security → 2-Step Verification → App passwords.
2. Run `setup-watchdog.ps1` in PowerShell and follow the prompts. It stores the credential
   DPAPI-encrypted (only your Windows user on your machine can decrypt), creates `letter.txt`
   from the template, registers the daily task, and test-fires one letter to your inbox.
3. Customize `letter.txt` — best done by asking Claude to write it in your advisors' voices
   from your `PROFILE.md` and wikis. Supports `{DAYS}` and `{HOURS}` placeholders.

## Design notes
- **Why file mtimes?** No API, no polling an external service — the session transcripts are
  already on disk and update on every message. Zero-cost, private, reliable.
- **Why Gmail SMTP + App Password?** The Claude Gmail connector is draft-only (cannot send),
  so notification email needs its own rail. The credential never leaves your machine.
- **Threshold and cooldown** are constants at the top of `claude-watchdog.ps1` — tune to taste.

## Files
- `claude-watchdog.ps1` — check + email logic (`-Force` sends now, for testing)
- `setup-watchdog.ps1` — credential, letter, scheduled task, test-fire
- `letter.template.txt` — starting point for your letter (`letter.txt` is gitignored — it's personal)
- `gmail-cred.xml`, `last-sent.txt`, `watchdog.log` — created at runtime, all gitignored

## Uninstall
`Unregister-ScheduledTask -TaskName ClaudeBoardWatchdog -Confirm:$false` and delete the runtime files.
