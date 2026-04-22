---
name: git-commit-check
description: >
  SOLE ENTRY POINT for all git commit and push operations. Triggers on any user
  request to commit code, push changes, or mention of "git commit" / "git push" /
  "/commit". Runs pre-commit checks (git repo validation, open source project
  user config) and then delegates to the internal /git-commit skill.
  Do NOT invoke /git-commit directly — always go through this skill first.
disable-model-invocation: true
compatibility:
  - bash: required for executing git commands
  - git: required for git operations
---

# Git Commit Check Skill

This skill is the **sole user-facing entry point** for all git commit operations.
It runs a two-step pre-commit checklist and then executes the `/git-commit`
sub-skill inline.

> The `/git-commit` skill must never be invoked directly by the AI in response
> to a user request — it is only called at the end of Step 2 below.

---

## When to Use

Trigger this skill for **every** git commit or push request, regardless of
project type.

Trigger keywords: `git commit`, `git push`, `提交代码`, `/commit`, `commit changes`

---

## Workflow

### Step 1 — Run Pre-Commit Guard Script

**Goal**: Validate the git environment and ensure project-level user config is
correct for open source projects, before any commit takes place.

**Action**: Execute the guard script from the skill's directory:

```bash
bash .Codex/skills/git-commit-check/git-commit-check.sh
```

This single script performs two internal checks in sequence:

**Check A — Git Repository Validation**
Verifies the current directory is inside a valid git repository.

| Script output                                                      | Meaning        | Next action                                                          |
|--------------------------------------------------------------------|----------------|----------------------------------------------------------------------|
| `[git-commit-check] Not a git repository. No action taken.`        | Not a git repo | Script exits with code `1` — **stop here, do NOT proceed to Step 2** |
| `[git-commit-check] Step 1 passed: valid git repository detected.` | Valid git repo | Script continues to Check B                                          |

**Check B — Open Source Project Config**
Checks whether the remote origin is GitHub/Gitee and fixes project-level `user.name` / `user.email` if needed.

| Script output                                                                | Meaning                     | Next action                                    |
|------------------------------------------------------------------------------|-----------------------------|------------------------------------------------|
| `[git-commit-check] Step 2 skipped: not a GitHub/Gitee repository.`          | Not an open source remote   | Script exits with code `0` — proceed to Step 2 |
| `[git-commit-check] Step 2 passed: project-level config is already correct.` | Config already correct      | Script exits with code `0` — proceed to Step 2 |
| `[git-commit-check] Updating project-level git user config...`               | Config was wrong, now fixed | Script exits with code `0` — proceed to Step 2 |

> If the script exits with code `1`, stop immediately. Do not proceed to Step 2.
> If the script exits with code `0`, proceed to Step 2 regardless of which
> Check B branch was taken.

---

### Step 2 — Execute /git-commit Sub-Skill Inline

**Goal**: Perform git staging, commit message generation, and the actual commit.

**Action**: Read and execute the `/git-commit` skill **inline within the current context** — do not spawn a new agent or
a new context. All bash commands run in the same working directory as Step 1.

Concretely:

1. Locate and read `.Codex/skills/git-commit/SKILL.md`
2. Follow its Workflow section: Analyze Diff → Stage Files → Generate Commit Message → Execute Commit
3. All bash commands run in the same working directory as Step 1

> **Why inline, not sub-agent**: `git-commit` shares the working directory and
> environment with Step 1. A sub-agent would require re-passing context and adds
> unnecessary overhead for a sequential, single-directory workflow.

---

## Flow Diagram

```
User: "git commit" / "git push" / "/commit"
  │
  ▼
[git-commit-check] ◀── ONLY entry point
  │
  └─ Step 1: run git-commit-check.sh
        │
        ├─ Check A: git rev-parse
        │     ├─ exit 1: Not a repo ──▶ STOP (nothing happens)
        │     └─ pass: valid repo ──▶ Check B
        │
        ├─ Check B: remote URL + config
        │     ├─ Not GitHub/Gitee ──────────────┐
        │     ├─ Config already correct ─────┐  │
        │     └─ Config wrong → fix & log    │  │
        │                          │         │  │
        │                          └────┬────┘  │
        │                               │       │
        │                    exit 0 ◀──-┴───────┘
        │
        └─ Step 2: read & execute /git-commit inline
```

---

## Script Reference

**File**: `.Codex/skills/git-commit-check/git-commit-check.sh`

| Responsibility     | Handled by             |
|--------------------|------------------------|
| What to do and why | `SKILL.md` (this file) |
| How to do it       | `git-commit-check.sh`  |

The script covers Step 1 Check A and Check B entirely. Step 2 is performed by
the AI reading and executing `/git-commit` inline — it is not part of the script.

---

## Test Cases

| # | Scenario                   | Check A         | Check B    | Step 2   |
|---|----------------------------|-----------------|------------|----------|
| 1 | Plain directory (no git)   | ❌ exit 1 → STOP | —          | —        |
| 2 | GitHub repo, wrong config  | ✅ pass          | Fix config | ✅ Commit |
| 3 | Gitee repo, correct config | ✅ pass          | No change  | ✅ Commit |
| 4 | Internal/private repo      | ✅ pass          | Skipped    | ✅ Commit |
