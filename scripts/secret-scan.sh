#!/bin/bash
# ─────────────────────────────────────────────────────────────
# secret-scan.sh  —  PostToolUse hook (async)
# Scans written/edited files for hardcoded credentials.
#
# Event:   PostToolUse (Write | Edit | MultiEdit), async=true
# Action:  Returns decision:"block" + reason to tell Claude
#          to remove secrets. Runs in background (non-blocking).
# ─────────────────────────────────────────────────────────────

set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name')

# ── Extract file content (from tool_input, not disk) ─────────
# We scan tool_input.content so we catch secrets even if the
# file was immediately deleted after writing.
case "$TOOL_NAME" in
  Write)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
    ;;
  Edit)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
    # Scan the new_string (what was actually inserted)
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // empty')
    ;;
  MultiEdit)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.edits[0].file_path // empty')
    CONTENT=$(echo "$INPUT" | jq -r '[.tool_input.edits[]?.new_string // ""] | join("\n")')
    ;;
  *)
    exit 0
    ;;
esac

# Skip test files, fixtures, and documentation
if echo "$FILE_PATH" | grep -qiE "(test|spec|fixture|mock|example|\.md$|\.txt$)"; then
  exit 0
fi

if [[ -z "$CONTENT" ]]; then
  exit 0
fi

# ── Secret patterns ───────────────────────────────────────────
# Each entry: "PATTERN|description"
declare -a SECRET_PATTERNS=(
  # Generic high-confidence patterns
  "(password|passwd|pwd)[[:space:]]*=[[:space:]]*['\"][^'\"]{6,}['\"]|hardcoded password"
  "(secret|api_secret)[[:space:]]*=[[:space:]]*['\"][^'\"]{8,}['\"]|hardcoded secret"
  "api[_-]?key[[:space:]]*=[[:space:]]*['\"][^'\"]{8,}['\"]|hardcoded API key"
  "access[_-]?token[[:space:]]*=[[:space:]]*['\"][^'\"]{8,}['\"]|hardcoded access token"
  "auth[_-]?token[[:space:]]*=[[:space:]]*['\"][^'\"]{8,}['\"]|hardcoded auth token"
  "private[_-]?key[[:space:]]*=[[:space:]]*['\"][^'\"]{8,}['\"]|hardcoded private key"

  # Cloud provider credentials
  "AKIA[0-9A-Z]{16}|AWS Access Key ID"
  "aws[_-]?secret[_-]?access[_-]?key[[:space:]]*=[[:space:]]*['\"][^'\"]{20,}['\"]|AWS Secret Access Key"
  "AIza[0-9A-Za-z\-_]{35}|Google API Key"
  "ya29\.[0-9A-Za-z\-_]+|Google OAuth Token"
  "ghp_[0-9A-Za-z]{36}|GitHub Personal Access Token"
  "ghs_[0-9A-Za-z]{36}|GitHub App Token"
  "xox[baprs]-[0-9A-Za-z\-]+|Slack Token"
  "sk-[a-zA-Z0-9]{48}|OpenAI API Key"
  "sk-ant-[a-zA-Z0-9\-]{90,}|Anthropic API Key"

  # Private key blocks
  "BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY|PEM private key block"
  "BEGIN CERTIFICATE|PEM certificate block"

  # Database connection strings with credentials
  "(mysql|postgresql|postgres|mongodb|redis)://[^:]+:[^@]{4,}@|database URI with credentials"
  "jdbc:[a-z]+://[^?]+\?.*password=[^&]+|JDBC URL with password"
)

# ── Scan ──────────────────────────────────────────────────────
FINDINGS=""

for rule in "${SECRET_PATTERNS[@]}"; do
  PATTERN="${rule%%|*}"
  DESCRIPTION="${rule##*|}"

  if echo "$CONTENT" | grep -qiE "$PATTERN"; then
    # Mask the actual value in the finding for safety
    MATCH=$(echo "$CONTENT" | grep -iE "$PATTERN" | head -1 | \
            sed 's/\(.\{4\}\).\{4,\}\(.\{4\}\)/\1****\2/g')
    FINDINGS+="  • $DESCRIPTION\n    Match: $MATCH\n"
  fi
done

# ── Report ────────────────────────────────────────────────────
if [[ -n "$FINDINGS" ]]; then
  REASON="[secret-scan] Potential secret(s) detected in $FILE_PATH.\nPlease remove hardcoded credentials and use environment variables or a secrets manager instead.\n\nFindings:\n$FINDINGS"
  jq -n --arg reason "$REASON" '{
    "decision": "block",
    "reason": $reason
  }'
  exit 0
fi

exit 0
