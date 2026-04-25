#!/bin/bash
# ─────────────────────────────────────────────────────────────
# command-guard.sh  —  PreToolUse hook (Bash matcher)
# Blocks dangerous shell commands BEFORE they execute.
#
# Event:   PreToolUse (Bash)
# Action:  Returns permissionDecision:"deny" to hard-block
#          the command. exit 0 + JSON = structured deny.
# ─────────────────────────────────────────────────────────────

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# ── Dangerous pattern table ───────────────────────────────────
# Format: "PATTERN|Human-readable description"
# Patterns are matched via grep -E against the full command string.
declare -a RULES=(
  # System destruction
  "rm[[:space:]]+-[^[:space:]]*r[^[:space:]]*f[[:space:]]+/[^a-zA-Z]|rm -rf on root or near-root path"
  "rm[[:space:]]+-[^[:space:]]*r[^[:space:]]*f[[:space:]]+~|rm -rf on home directory"
  "rm[[:space:]]+-[^[:space:]]*r[^[:space:]]*f[[:space:]]+\\\$HOME|rm -rf \$HOME"
  "rm[[:space:]]+-[^[:space:]]*r[^[:space:]]*f[[:space:]]+\\\$\(|rm -rf with command substitution"

  # Disk operations
  "mkfs\.[a-z]+|disk format (mkfs)"
  "dd[[:space:]]+if=/dev/(zero|random|urandom)[[:space:]]+of=/dev/[a-z]+[0-9]*[[:space:]]|dd disk wipe"
  "[>|] ?/dev/sd[a-z][^/]|direct write to block device"

  # Permission escalation
  "chmod[[:space:]]+-R[[:space:]]+[0-7]*7[[:space:]]*/[^a-zA-Z]|chmod 777 on system path"
  "chmod[[:space:]]+-R[[:space:]]+777[[:space:]]+~|chmod 777 on home directory"

  # Fork bomb
  ":\(\)\{.*\|.*:.*&.*\}.*;.*:|fork bomb pattern"

  # Remote code execution via pipe
  "(curl|wget)[[:space:]].*[[:space:]]\|[[:space:]]*(bash|sh|zsh|fish)|piping remote download to shell"

  # Critical system file overwrite
  ">[[:space:]]*/etc/(passwd|shadow|sudoers|hosts)|overwriting critical system file"
  "tee[[:space:]]+(--append[[:space:]]+)?/etc/(passwd|shadow|sudoers)|writing to critical system file via tee"

  # Credential and key destruction
  "rm[[:space:]].*\.ssh/|deleting SSH keys"
  "rm[[:space:]].*\.gnupg/|deleting GPG keys"

  # History/audit destruction
  "history[[:space:]]+-c|clearing shell history"
  ">[[:space:]]*(~|\\\$HOME)/\.(bash|zsh|fish)_history|overwriting shell history file"

  # Database destruction
  "DROP[[:space:]]+DATABASE|SQL DROP DATABASE"
  "DROP[[:space:]]+TABLE[[:space:]]+[^I]|SQL DROP TABLE (not IF EXISTS)"

  # Package manager abuse
  "pip[[:space:]]+(install|uninstall)[[:space:]]+--break-system-packages[[:space:]]+-y[[:space:]]+--(user)?[[:space:]]*(os|sys|builtins)|uninstalling Python stdlib"
)

# ── Check each rule ───────────────────────────────────────────
for rule in "${RULES[@]}"; do
  PATTERN="${rule%%|*}"
  DESCRIPTION="${rule##*|}"

  if echo "$COMMAND" | grep -qiE "$PATTERN"; then
    REASON="[command-guard] Blocked: $DESCRIPTION.\nCommand: $COMMAND\nIf this is intentional, please confirm explicitly."
    jq -n --arg reason "$REASON" '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": $reason
      }
    }'
    exit 0
  fi
done

# ── All checks passed ─────────────────────────────────────────
exit 0
