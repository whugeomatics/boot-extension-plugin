# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project Overview

This is a harness engineering demonstration project showcasing Codex's hook system for automated development workflows. The project demonstrates custom hooks for command safety, code quality, and git workflow management.

## Development Workflow

### Git Commit Process

This project implements a custom git commit workflow through the `/git-commit-check` skill:

1. **Pre-commit checks are automatically triggered** when you run `git commit`, `git push`, or use `/commit`
2. **The system validates**:
   - Current directory is a git repository
   - For GitHub/Gitee projects: Forces project-level git config to use `whugeomatics`/`whugeomatics@gmail.com`
3. **Conventional commits are enforced** - the system analyzes your changes and generates appropriate commit messages

**To commit changes**: Simply use `/commit` or `git commit` - the system handles everything automatically.

### Hook System

The project uses several Codex hooks:

- **PreToolUse (Bash)**: `.Codex/hooks/command-guard.sh` - Blocks dangerous commands like `rm -rf`
- **PostToolUse (Write/Edit)**: 
  - `.Codex/hooks/java-lint.sh` - Runs lint checks on Java files
  - `.Codex/hooks/secret-scan.sh` - Scans for hardcoded credentials
- **Stop**: `.Codex/hooks/session-summary.sh` - Logs session summaries

### Code Quality Enforcement

**Java Lint Process**:
- After editing Java files, automatic linting runs
- Supports multiple lint tools in priority order:
  1. Maven checkstyle (if pom.xml exists)
  2. Gradle checkstyle (if build.gradle exists)
  3. Standalone checkstyle binary
  4. google-java-format (for formatting)
  5. javac -Xlint (basic syntax warnings)
- Lint failures block further work until fixed

**Secret Scanning**:
- Automatically scans for hardcoded credentials, API keys, and secrets
- Blocks files with potential security issues
- Covers AWS, Google, GitHub, Slack, OpenAI, and other common secret patterns

## Skills System

The project includes several custom skills:

- `/git-commit-check`: Main entry point for all git operations
- `/git-commit`: Internal skill for conventional commit generation (not user-facing)
- `/executor-dependency`: For Java Maven projects to automatically configure thread pool dependencies and configurations

## Project Structure

- `.Codex/hooks/`: Hook scripts for automated workflows
  - `command-guard.sh`: Pre-tool hook to block dangerous commands
  - `java-lint.sh`: Post-tool hook for Java code quality checks
  - `secret-scan.sh`: Post-tool hook for security scanning
  - `session-summary.sh`: Stop hook for session logging
- `.Codex/skills/`: Custom skills extending Codex's capabilities
  - `git-commit-check/`: Git workflow management
  - `git-commit/`: Internal conventional commit generation
  - `executor-dependency/`: Thread pool dependency management for Java projects
- `.Codex/settings.json`: Configuration for hook system

## Important Notes

- The project uses Bash hybrid scripts for cross-platform compatibility
- All hooks are non-destructive - they provide feedback but don't prevent manual intervention
- Secret scanning includes intelligent masking to expose patterns without exposing actual values
- Session summaries include desktop notifications on macOS/Linux for development awareness
- The executor-dependency skill automatically detects Java Maven projects and manages thread pool dependencies