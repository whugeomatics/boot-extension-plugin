#!/bin/bash
# ─────────────────────────────────────────────────────────────
# java-lint.sh  —  PostToolUse hook
# Runs lint checks after Claude writes or edits a Java file.
#
# Event:   PostToolUse (Write | Edit | MultiEdit)
# Action:  Returns decision:"block" + reason to tell Claude
#          to fix lint issues. Does NOT block file writing
#          (file is already written at this point).
# ─────────────────────────────────────────────────────────────

set -euo pipefail

INPUT=$(cat)

# ── 1. Extract all affected .java file paths ──────────────────
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name')

case "$TOOL_NAME" in
  Write|Edit)
    JAVA_FILES=$(echo "$INPUT" | jq -r '
      .tool_input.file_path
      | select(. != null and (endswith(".java")))
    ')
    ;;
  MultiEdit)
    JAVA_FILES=$(echo "$INPUT" | jq -r '
      .tool_input.edits[]?.file_path
      | select(. != null and (endswith(".java")))
    ')
    ;;
  *)
    exit 0
    ;;
esac

# No .java files involved — nothing to do
if [[ -z "$JAVA_FILES" ]]; then
  exit 0
fi

# ── 2. Choose lint strategy ───────────────────────────────────
PROJECT_ROOT=$(echo "$INPUT" | jq -r '.cwd')
LINT_ERRORS=""

run_lint_for_file() {
  local file="$1"
  local errors=""

  if [[ ! -f "$file" ]]; then
    return
  fi

  # Priority 1: Maven checkstyle (if pom.xml found in project root)
  if [[ -f "$PROJECT_ROOT/pom.xml" ]] && command -v mvn &>/dev/null; then
    errors=$(mvn -f "$PROJECT_ROOT/pom.xml" checkstyle:check \
               -Dcheckstyle.failsOnError=true \
               -Dcheckstyle.includeTestSourceDirectory=false \
               -q 2>&1 | grep -v "^\[INFO\]" || true)

  # Priority 2: Gradle checkstyle (if build.gradle found)
  elif [[ -f "$PROJECT_ROOT/build.gradle" || -f "$PROJECT_ROOT/build.gradle.kts" ]]; then
    local gradle_cmd="./gradlew"
    [[ ! -x "$PROJECT_ROOT/gradlew" ]] && gradle_cmd="gradle"
    errors=$(cd "$PROJECT_ROOT" && $gradle_cmd checkstyleMain -q 2>&1 || true)

  # Priority 3: Standalone checkstyle binary
  elif command -v checkstyle &>/dev/null; then
    local config_file=""
    # Look for project-local config first
    for cfg in "$PROJECT_ROOT/checkstyle.xml" \
               "$PROJECT_ROOT/.checkstyle.xml" \
               "$PROJECT_ROOT/config/checkstyle/checkstyle.xml"; do
      [[ -f "$cfg" ]] && config_file="$cfg" && break
    done
    # Fall back to Google style
    [[ -z "$config_file" ]] && config_file="/google_checks.xml"

    errors=$(checkstyle -c "$config_file" "$file" 2>&1 | grep -v "^Starting audit\|^Audit done" || true)

  # Priority 4: google-java-format dry-run (formatting check only)
  elif command -v google-java-format &>/dev/null; then
    local diff_output
    diff_output=$(google-java-format --dry-run "$file" 2>&1 || true)
    [[ -n "$diff_output" ]] && errors="Formatting issues (run google-java-format to fix):\n$diff_output"

  # Priority 5: javac -Xlint (syntax + compiler warnings)
  elif command -v javac &>/dev/null; then
    errors=$(javac -Xlint:all -proc:none -cp "" "$file" 2>&1 | grep -v "^Note:" || true)

  else
    echo "[java-lint] No lint tool available. Install checkstyle, google-java-format, or javac." >&2
    exit 0
  fi

  if [[ -n "$errors" ]]; then
    LINT_ERRORS+="── $file ──\n$errors\n\n"
  fi
}

# ── 3. Run lint on all changed Java files ─────────────────────
while IFS= read -r file; do
  [[ -n "$file" ]] && run_lint_for_file "$file"
done <<< "$JAVA_FILES"

# ── 4. Return result ──────────────────────────────────────────
if [[ -n "$LINT_ERRORS" ]]; then
  REASON="[java-lint] Lint issues found. Please fix before proceeding:\n\n${LINT_ERRORS}"
  jq -n --arg reason "$REASON" '{
    "decision": "block",
    "reason": $reason
  }'
  exit 0
fi

echo "[java-lint] All Java files passed lint check." >&2
exit 0
