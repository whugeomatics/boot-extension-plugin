# 新建插件

## 标准的 Plugin 插件结构

>
参考文档：[Claude Plugin docs](https://code.claude.com/docs/zh-CN/plugins-reference#plugin-%E7%9B%AE%E5%BD%95%E7%BB%93%E6%9E%84)

```text
    harness-plugin/
    ├── .claude-plugin/           # 元数据目录（可选）
    │   └── plugin.json            # plugin 清单
    ├── skills/                   # Skills
    │   ├── code-reviewer/
    │   │   └── SKILL.md
    │   └── pdf-processor/
    │       ├── SKILL.md
    │       └── scripts/
    ├── commands/                 # Skills 作为平面 .md 文件
    │   ├── status.md
    │   └── logs.md
    ├── agents/                   # Subagent 定义
    │   ├── security-reviewer.md
    │   ├── performance-tester.md
    │   └── compliance-checker.md
    ├── output-styles/            # 输出样式定义
    │   └── terse.md
    ├── monitors/                 # 后台 monitor 配置
    │   └── monitors.json
    ├── hooks/                    # Hook 配置
    │   ├── hooks.json           # 主 hook 配置
    │   └── security-hooks.json  # 其他 hooks
    ├── bin/                      # 添加到 PATH 的 plugin 可执行文件
    │   └── my-tool               # 在 Bash tool 中可作为裸命令调用
    ├── settings.json            # plugin 的默认设置
    ├── .mcp.json                # MCP server 定义
    ├── .lsp.json                # LSP server 配置
    ├── scripts/                 # Hook 和实用脚本
    │   ├── security-scan.sh
    │   ├── format-code.py
    │   └── deploy.js
    ├── LICENSE                  # 许可证文件
    └── CHANGELOG.md             # 版本历史
```

# 配置插件

## marketplace

- 在 `~/.claude/plugins/` 目录下新建 `marketplaces` 目录
- 在 `marketplaces` 目录下新建 一个 `marketplace` 目录
- 在 `marketplace` 目录下新建 `.claude-plugin` 目录
- 在 `.claude-plugin` 目录下新建 `marketplace.json`
- 在 `marketplace` 目录下新建 `plugins` 目录， 将第一步创建的plugin放置于这个位置

```text

~/.claude/plugins/marketplaces
    └─ whugeomatics  # 新建plugins目录集合（以whugeomatics为例）
        ├─.claude-plugin  # 新建 .claude-plugin 目录
        ├─── marketplace.json  # 新建 marketplace.json
        └─plugins  # 新建 plugins 目录 
            └─harness-plugin
                ├─.claude-plugin
                ├─agents
                │  └─java-code-review
                ├─hooks
                └─skills
                    ├─executor-dependency
                    ├─git-commit
                    └─git-commit-check

```

`marketplace.json` 参考示例：

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "whugeomatics",
  "description": "Directory of popular Claude Code extensions including development tools, productivity plugins, and MCP integrations",
  "owner": {
    "name": "whugeomatics"
  },
  "plugins": [
    {
      "name": "harness-plugin",
      "description": "Agentforce Agent Development Life Cycle — author, discover, scaffold, deploy, test, and optimize .agent files",
      "source": "./plugins/harness-plugin"
    }
  ]
}

```

> 参考文档：[marketplace.json配置](https://code.claude.com/docs/en/plugin-marketplaces)
> **source 的配置相对于plugin根目录**

## `.claude/plugins` 目录下 新增 `known_marketplaces.json` 文件，配置 `marketplace`

```text
~/.claude/plugins         
└─known_marketplaces.json        # marketplace的配置
```

```json
{
  "claude-plugins-official": {
    "source": {
      "source": "github",
      "repo": "anthropics/claude-plugins-official"
    },
    "installLocation": "C:\\Users\\Administrator\\.claude\\plugins\\marketplaces\\claude-plugins-official",
    "lastUpdated": "2026-04-22T10:52:07.647Z"
  },
  "whugeomatics": {
    "source": {
      "source": "directory",
      "path": "C:\\Users\\Administrator\\.claude\\plugins\\marketplaces\\whugeomatics"
    },
    "installLocation": "C:\\Users\\Administrator\\.claude\\plugins\\marketplaces\\whugeomatics",
    "lastUpdated": "2026-04-22T10:52:07.647Z"
  }
}
```

> 参考文档：[known_marketplaces配置](https://code.claude.com/docs/en/settings#strictknownmarketplaces)

**官方支持的 source 类型总结：**

| 类型          | 用途                                                         |
|-------------|------------------------------------------------------------|
| "github     | "GitHub 仓库 owner/repo                                      |
| "git"       | 任意 Git URL                                                 |
| "directory" | 本地目录（含 .claude-plugin/marketplace.json的目录），（使用 path，仅用于开发） |
| "file"      | 直接指向 marketplace.json 文件的绝对路径                              |
| "npm"       | npm 包                                                      |

# 安装插件

> 参考文档：[plugin install](https://code.claude.com/docs/zh-CN/plugins-reference#plugin-install)

```bash
claude plugin install <plugin> [options]
```

参数：<plugin>：Plugin 名称或 plugin-name@marketplace-name 用于特定市场

选项：

| 选项                  | 描述                        | 默认值  |
|---------------------|---------------------------|------|
| -s, --scope <scope> | 安装范围：user、project 或 local | user |
| -h, --help          | 显示命令帮助                    |

Example:

```bash
claude plugin install harness-plugin@whugeomatics -s project
```

> 出于安全和验证目的，Claude Code 将_市场_ plugins 复制到用户的本地 plugin 缓存（~/.claude/plugins/cache），
> 而不是就地使用它们。在开发引用外部文件的 plugins 时，理解此行为很重要。

安装后的清单

```text
```text
~/.claude/plugins
└─cache                     # 缓存在cache里
│  ├─claude-plugins-official
│  └─whugeomatics
│      └─harness-plugin
│          └─1.0.0
│              ├─.claude-plugin
│              ├─agents
│              │  └─java-code-review
│              ├─hooks
│              └─skills
│                  ├─executor-dependency
│                  ├─git-commit
│                  └─git-commit-check
└─marketplaces
    ├─claude-plugins-official
    │  ├─.claude-plugin
    │  ├─.github
    │  │  ├─scripts
    │  │  └─workflows
    └─whugeomatics
        ├─.claude-plugin
        └─plugins
            └─harness-plugin
                ├─.claude-plugin
                ├─agents
                │  └─java-code-review
                ├─hooks
                └─skills
                    ├─executor-dependency
                    ├─git-commit
                    └─git-commit-check
└─installed_plugins.json         # plugin 安装映射json            
└─known_marketplaces.json        # marketplace的配置

```
