# Harness Engineering Demonstration

A showcase of Claude Code's advanced hook system for automated development workflows. This project demonstrates how to enhance code safety, quality, and productivity through customizable hooks and skills.

## 🚀 Features

### 1. Automated Git Workflow
- **Pre-commit Validation**: Automatically checks git repository status and user configuration
- **Conventional Commits**: Generates standardized commit messages based on changes
- **Project-specific Config**: Forces consistent git identity for open source projects

### 2. Command Safety
- **Dangerous Command Blocking**: Prevents execution of potentially harmful commands
- **Pattern-based Detection**: Blocks `rm -rf`, system destruction, and other risky operations
- **Override Capability**: Allows explicit confirmation for legitimate dangerous commands

### 3. Code Quality Assurance
- **Java Lint Integration**: Automated linting after code edits
- **Multi-tool Support**: Maven, Gradle, Checkstyle, Google Java Format, and javac
- **Failure Prevention**: Blocks further work until lint issues are resolved

### 4. Security Scanning
- **Secret Detection**: Automatically identifies hardcoded credentials and API keys
- **Provider Coverage**: AWS, Google, GitHub, Slack, OpenAI, and more
- **Smart Masking**: Exposes patterns without exposing actual values

### 5. Thread Pool Management (Java Projects)
- **Automatic Dependency Injection**: Adds `base-executor-starter` to Java Maven projects
- **YAML Configuration Generation**: Creates thread pool configurations
- **Business Code Generation**: Produces optimized async and scheduled task implementations
- **Proactive Monitoring**: Prevents unmonitored bare thread pool usage

## 📁 Project Structure

```
├── .claude/
│   ├── hooks/                    # Hook scripts
│   │   ├── command-guard.sh     # Command safety
│   │   ├── java-lint.sh         # Java code quality
│   │   ├── secret-scan.sh       # Security scanning
│   │   └── session-summary.sh    # Session logging
│   ├── skills/                   # Custom skills
│   │   ├── git-commit-check/    # Git workflow management
│   │   ├── git-commit/          # Internal commit generation
│   │   └── executor-dependency/ # Thread pool management
│   ├── settings.json            # Hook configuration
├── CLAUDE.md                    # Project guidance for Claude Code
└── README.md                    # This file
```

## 🛠️ How It Works

### Git Commit Process
1. User triggers `git commit`, `git push`, or uses `/commit`
2. `/git-commit-check` skill runs pre-commit validations
3. System generates conventional commit message
4. Changes are committed automatically

### Hook System Flow
1. **PreToolUse**: Runs before any command execution
2. **PostToolUse**: Runs after file write/edit operations
3. **Stop**: Runs when the session ends

### Code Quality Enforcement
1. After editing Java files, automatic linting runs
2. Multiple lint tools attempt in priority order
3. Issues must be resolved before continuing

## 🔧 Skills Overview

### `/git-commit-check`
- **Purpose**: Sole entry point for all git operations
- **Triggers**: `git commit`, `git push`, `/commit`
- **Features**: Repository validation, user config enforcement

### `/executor-dependency`
- **Purpose**: Java thread pool dependency management
- **Triggers**: Thread pool keywords, async/concurrent code patterns
- **Features**: Auto-detects Maven projects, injects dependencies, generates configs

## 📊 Hook Execution Timeline

```
User Action → PreToolUse Hook → Tool Execution → PostToolUse Hook → Stop Hook
```

## 🔐 Security Features

### Command Guard Rules
- System destruction prevention
- Disk operations blocking
- Permission escalation detection
- Fork bomb protection
- Remote code execution blocking
- Critical file protection

### Secret Scanning Patterns
- AWS/GitHub/Slack tokens
- Database credentials
- API keys
- Private keys and certificates
- Cloud service authentication

## 🎯 Best Practices

### For Developers
1. Use `/commit` for standardized git operations
2. Ensure Java projects follow lint standards
3. Store secrets in environment variables or secrets managers
4. Use the provided skills for common patterns

### For Maintainers
1. Regularly update hook scripts
2. Review blocked commands for false positives
3. Maintain secret scanning patterns
4. Update lint tool configurations

## 🚀 Getting Started

1. Clone this repository
2. Explore the hook scripts in `.claude/hooks/`
3. Study the skill implementations in `.claude/skills/`
4. Customize hooks for your own project needs

## 📈 Benefits

- **Reduced Errors**: Automated checks prevent common mistakes
- **Consistent Standards**: Enforced coding and commit standards
- **Improved Security**: Continuous secret scanning and command blocking
- **Increased Productivity**: Automated workflows reduce manual work
- **Better Visibility**: Session logging for development awareness

## 🤝 Contributing

To contribute to this demonstration project:

1. Review the hook implementations
2. Test skills in your own environment
3. Provide feedback on patterns and configurations
4. Suggest improvements to documentation

---

*This project showcases the power of Claude Code's extensibility through hooks and custom skills, providing a foundation for automated development workflows.*