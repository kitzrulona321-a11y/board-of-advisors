#!/usr/bin/env bash
# Claude Board Watchdog v2 — macOS port
# Checks when Claude Code was last used. If silent past the threshold,
# emails you your board's get-back-on-track letter via Gmail SMTP (curl).
# Run setup-watchdog.sh once before this works.
#
# Letter selection (three-tier fallback, reliability first) — mirrors the
# Windows version:
#   1. AI-generated  - headless `claude -p` writes today's letter from your
#                      PROFILE.md + knowledge/wiki/ (runs on your existing
#                      Claude subscription; no API cost). Skipped if the
#                      claude CLI isn't installed or generation times out.
#   2. Rotation      - random pre-written letter from letters/*.txt,
#                      falling back to letter.txt
#   3. Last resort   - short built-in message (only if 1 and 2 both fail)
#
# Usage: claude-watchdog.sh [--force]
#   --force  sends regardless of thresholds (used by setup's test-fire)

set -u

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$ROOT/watchdog.conf"          # written by setup: EMAIL=...
LETTERS_DIR="$ROOT/letters"
LETTER_PATH="$ROOT/letter.txt"
STATE_PATH="$ROOT/last-sent.txt"
LOG_PATH="$ROOT/watchdog.log"

PROJECT_DIR="$(cd "$ROOT/.." && pwd)"          # repo root: PROFILE.md + knowledge/ live here
PROJECTS_DIR="$HOME/.claude/projects"          # Claude Code session transcripts
KEYCHAIN_SERVICE="claude-board-watchdog"

THRESHOLD_HOURS=48   # silence longer than this = off track
COOLDOWN_HOURS=48    # wait at least this long between emails
GEN_TIMEOUT=240      # max seconds to wait for the AI-generated letter

log() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_PATH"; }

# Portable timeout: run claude in the background, poll, kill if it overruns.
generate_letter() {
  command -v claude >/dev/null 2>&1 || return 1
  local hours="$1" days="$2"
  local prompt="You are the watchdog for the user's board of advisors. They have not used Claude Code for about ${hours} hours (~${days} days) - their self-declared drift warning sign. Read PROFILE.md and every file in knowledge/wiki/. Then write TODAY'S get-back-on-track email: one short paragraph per advisor, each in that advisor's documented voice and vocabulary, matched to the coaching-style instructions in PROFILE.md. Reference their real goals and key dates. End with a numbered 'THE WAY BACK' list of 4 small steps, step 1 being: open Claude Code and type 'I drifted'. Plain text only - no markdown, advisor names in caps as the only headers, under 350 words. Output ONLY the email body, nothing else."

  local tmp; tmp="$(mktemp)"
  ( cd "$PROJECT_DIR" && claude -p "$prompt" --output-format text >"$tmp" 2>/dev/null ) &
  local pid=$! waited=0
  while kill -0 "$pid" 2>/dev/null; do
    sleep 3; waited=$((waited + 3))
    if [ "$waited" -ge "$GEN_TIMEOUT" ]; then
      kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
      rm -f "$tmp"; return 1
    fi
  done
  wait "$pid" 2>/dev/null
  local out; out="$(cat "$tmp")"; rm -f "$tmp"
  [ "${#out}" -gt 200 ] || return 1
  printf '%s' "$out"
}

send_email() {
  local subject="$1" body="$2"
  local app_pass; app_pass="$(security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$EMAIL" -w 2>/dev/null)"
  [ -n "$app_pass" ] || { log 'ERROR: no app password in keychain. Run setup-watchdog.sh.'; return 1; }

  local msg; msg="$(mktemp)"
  {
    printf 'From: %s\n' "$EMAIL"
    printf 'To: %s\n' "$EMAIL"
    printf 'Subject: %s\n' "$subject"
    printf 'MIME-Version: 1.0\n'
    printf 'Content-Type: text/plain; charset=UTF-8\n'
    printf '\n'
    printf '%s\n' "$body"
  } > "$msg"

  curl -s --url 'smtps://smtp.gmail.com:465' --ssl-reqd \
       --mail-from "$EMAIL" --mail-rcpt "$EMAIL" \
       --user "$EMAIL:$app_pass" -T "$msg"
  local rc=$?
  rm -f "$msg"
  return $rc
}

# --- main ---------------------------------------------------------------
[ -f "$CONF" ] || { log 'No watchdog.conf. Run setup-watchdog.sh first.'; exit 0; }
# shellcheck disable=SC1090
. "$CONF"
[ -n "${EMAIL:-}" ] || { log 'watchdog.conf has no EMAIL. Run setup-watchdog.sh.'; exit 0; }

newest="$(find "$PROJECTS_DIR" -type f -exec stat -f '%m' {} \; 2>/dev/null | sort -nr | head -1)"
if [ -z "$newest" ]; then log 'No Claude session files found.'; exit 0; fi

now="$(date +%s)"
hours_silent="$(awk -v n="$newest" -v c="$now" 'BEGIN{printf "%.1f", (c-n)/3600}')"

# int comparison via awk (bash can't do float compares)
past_threshold="$(awk -v h="$hours_silent" -v t="$THRESHOLD_HOURS" 'BEGIN{print (h>=t)?1:0}')"
if [ "$FORCE" -eq 0 ] && [ "$past_threshold" -eq 0 ]; then
  log "On track. Last Claude activity $hours_silent hours ago."
  exit 0
fi

if [ "$FORCE" -eq 0 ] && [ -f "$STATE_PATH" ]; then
  last_sent="$(head -n1 "$STATE_PATH")"
  since_sent="$(awk -v l="$last_sent" -v c="$now" 'BEGIN{printf "%.1f", (c-l)/3600}')"
  in_cooldown="$(awk -v s="$since_sent" -v cd="$COOLDOWN_HOURS" 'BEGIN{print (s<cd)?1:0}')"
  if [ "$in_cooldown" -eq 1 ]; then
    log "Off track ($hours_silent h) but letter already sent $since_sent h ago. Cooldown."
    exit 0
  fi
fi

days="$(awk -v h="$hours_silent" 'BEGIN{printf "%d", int(h/24)}')"

# Tier 1: AI-generated letter (headless Claude Code on your subscription)
body="$(generate_letter "$hours_silent" "$days")"
source='AI-generated'

# Tier 2: rotation — random pre-written letter (letters/*.txt, else letter.txt)
if [ -z "$body" ]; then
  pick=""
  if [ -d "$LETTERS_DIR" ]; then
    pick="$(find "$LETTERS_DIR" -maxdepth 1 -name '*.txt' -type f 2>/dev/null | sort -R | head -1)"
  fi
  [ -z "$pick" ] && [ -f "$LETTER_PATH" ] && pick="$LETTER_PATH"
  if [ -n "$pick" ]; then
    body="$(sed -e "s/{DAYS}/$days/g" -e "s/{HOURS}/$hours_silent/g" "$pick")"
    source="rotation ($(basename "$pick"))"
  fi
fi

# Tier 3: last resort
if [ -z "$body" ]; then
  source='last-resort'
  body="It's been about $hours_silent hours without Claude Code - your own
early-warning sign. Open Claude Code, type \"I drifted\", and run
/ask-the-board. Getting back on track IS the win. - The Board"
fi

subject="[THE BOARD] It's been $days+ days. Time to come back."

if send_email "$subject" "$body"; then
  date +%s > "$STATE_PATH"
  log "Board letter SENT via $source ($hours_silent hours silent, Force=$FORCE)."
else
  log "ERROR: send failed via $source ($hours_silent hours silent)."
  exit 1
fi
