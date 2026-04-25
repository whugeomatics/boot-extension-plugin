#!/bin/bash
# git-commit-check.sh
# Pre-commit guard for open source projects.
# Called by the /git-commit-check skill (Step 1) before /git-commit runs (Step 2).
#
# Internal checks:
#   Check A — Verify the current directory is a git repository
#   Check B — If remote is GitHub/Gitee, ensure project-level user config is correct
#
# Exit codes:
#   0 — all checks passed (or not applicable), caller proceeds to /git-commit
#   1 — not a git repository, caller must abort

set -euo pipefail

EXPECTED_NAME="whugeomatics"
EXPECTED_EMAIL="whugeomatics@gmail.com"

# ────────────────────────────────────────────────────────────────
# Check A: Git Repository Validation
# ────────────────────────────────────────────────────────────────
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "[git-commit-check] Not a git repository. No action taken."
    exit 1
fi

echo "[git-commit-check] Step 1 passed: valid git repository detected."

# ────────────────────────────────────────────────────────────────
# Check B: Open Source Project Config
# ────────────────────────────────────────────────────────────────
remote_url=$(git remote get-url origin 2>/dev/null || true)

if [[ "$remote_url" =~ (github|gitee)\.com ]]; then
    echo "[git-commit-check] Step 2: open source project detected (remote: $remote_url)"

    current_name=$(git config --local user.name 2>/dev/null || true)
    current_email=$(git config --local user.email 2>/dev/null || true)

    needs_update=false
    [[ "$current_name"  != "$EXPECTED_NAME"  ]] && needs_update=true
    [[ "$current_email" != "$EXPECTED_EMAIL" ]] && needs_update=true

    if $needs_update; then
        echo "[git-commit-check] Updating project-level git user config..."
        git config --local user.name  "$EXPECTED_NAME"
        git config --local user.email "$EXPECTED_EMAIL"
        echo "[git-commit-check]   user.name  → $(git config --local user.name)"
        echo "[git-commit-check]   user.email → $(git config --local user.email)"
    else
        echo "[git-commit-check] Step 2 passed: project-level config is already correct."
    fi
else
    echo "[git-commit-check] Step 2 skipped: not a GitHub/Gitee repository."
fi

echo "[git-commit-check] All checks passed. Proceeding to /git-commit."
exit 0
