#!/bin/bash
# ─────────────────────────────────────────────────────────────
# session-summary.sh  —  Stop hook (async)
# Logs a compact summary when Claude finishes a task.
#
# Event:   Stop, async=true (runs in background, non-blocking)
# Output:  Appends a summary entry to .claude/logs/session.log
# ─────────────────────────────────────────────────────────────

set -euo pipefail

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT"    | jq -r '.session_id // "unknown"')
CWD=$(echo "$INPUT"           | jq -r '.cwd // "unknown"')
LAST_MSG=$(echo "$INPUT"      | jq -r '.last_assistant_message // ""')
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')

# Avoid infinite loops — don't log if we're already inside a stop hook
if [[ "$STOP_HOOK_ACTIVE" == "true" ]]; then
  exit 0
fi

# ── Build log entry ───────────────────────────────────────────
LOG_DIR="$CWD/.claude/logs"
LOG_FILE="$LOG_DIR/session.log"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
PROJECT=$(basename "$CWD")

# Truncate last message to 200 chars for the log
SUMMARY="${LAST_MSG:0:200}"
[[ ${#LAST_MSG} -gt 200 ]] && SUMMARY+="…"

cat >> "$LOG_FILE" <<EOF
────────────────────────────────────────────
[$TIMESTAMP] Session: $SESSION_ID
Project : $PROJECT ($CWD)
Summary : $SUMMARY
EOF

# ── Optional: macOS/Linux desktop notification ────────────────
NOTIF_TITLE="Claude ✓ $PROJECT"
NOTIF_BODY="${SUMMARY:0:80}"

if command -v osascript &>/dev/null; then
  # macOS
  osascript -e "display notification \"$NOTIF_BODY\" with title \"$NOTIF_TITLE\"" 2>/dev/null || true
elif command -v notify-send &>/dev/null; then
  # Linux (libnotify)
  notify-send "$NOTIF_TITLE" "$NOTIF_BODY" 2>/dev/null || true
fi

exit 0
