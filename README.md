# Spring Boot Extension Plugin

一个专门为 Spring Boot 开发设计的 Claude Code 插件，提供自动化的开发工作流、代码质量保证和安全扫描功能。

## 🎯 插件特性

### 1. 自动化 Git 工作流
- **提交前验证**：自动检查仓库状态和用户配置
- **规范提交信息**：基于更改内容生成标准化的提交信息
- **项目配置**：为开源项目强制使用一致的 git 身份配置

### 2. 命令安全防护
- **危险命令拦截**：阻止 potentially harmful 命令的执行
- **模式检测**：拦截 `rm -rf`、系统破坏和其他风险操作
- **覆盖能力**：允许通过显式确认执行合法的危险命令

### 3. Java 代码质量保证
- **自动代码检查**：编辑 Java 文件后自动运行代码检查
- **多工具支持**：Maven、Gradle、Checkstyle、Google Java Format 和 javac
- **失败预防**：代码检查问题必须解决才能继续工作

### 4. 安全扫描
- **密钥检测**：自动识别硬编码的凭证和 API 密钥
- **提供商覆盖**：AWS、Google、GitHub、Slack、OpenAI 等
- **智能遮蔽**：暴露模式而不暴露实际值

### 5. 线程池管理（Java 项目）
- **自动依赖注入**：为 Java Maven 项目添加 `base-executor-starter`
- **配置文件生成**：创建线程池配置
- **业务代码生成**：生成优化的异步和定时任务实现
- **主动监控**：防止未监控的原始线程池使用

## 📦 安装

### 开发环境安装
```bash
# 克隆插件仓库
git clone https://github.com/whugeomatics/boot-extension-plugin.git

# 将插件复制到 Claude Code 插件目录
cp -r boot-extension-plugin ~/.claude/plugins/
```

### 使用方式
1. 启动 Claude Code
2. 在 Spring Boot 项目中使用以下命令激活插件功能：
   - `/git-commit-check` - Git 提交检查
   - `/executor-dependency` - 线程池依赖管理

## 🛠️ 核心功能详解

### Git 工作流自动化
```bash
# 使用规范提交
git add .
/commit

# 或者直接使用
git commit -m "feat: add new feature"
```

**工作流程**：
1. 用户触发 `git commit`、`git push` 或使用 `/commit`
2. `/git-commit-check` 技能运行提交前验证
3. 系统生成规范的提交信息
4. 自动提交更改

### 线程池管理
当代码中检测到线程池相关关键词时，插件会：
1. 自动检测 Maven 项目
2. 注入 `base-executor-starter` 依赖
3. 生成线程池配置文件
4. 创建优化的异步和定时任务示例代码

### 代码质量检查
编辑 Java 文件后，插件会按优先级顺序尝试多种代码检查工具：
1. Maven checkstyle（如果存在 pom.xml）
2. Gradle checkstyle（如果存在 build.gradle）
3. 独立 checkstyle 二进制文件
4. google-java-format（格式化）
5. javac -Xlint（基本语法警告）

## 🏗️ 项目结构

```
boot-extension-plugin/
├── .claude-plugin/               # 插件元数据
│   ├── plugin.json              # 插件清单
│   └── marketplace.json         # 市场/仓库配置
├── .claude/skills/              # 自定义技能
│   ├── test/                    # 集成测试技能
│   └── verify/                  # 配置验证技能
├── skills/                      # 技能定义目录
│   ├── executor-dependency/    # 线程池依赖管理
│   ├── git-commit/              # 内部提交生成
│   └── git-commit-check/       # Git 提交检查入口
├── scripts/                     # 钩子脚本
│   ├── command-guard.sh        # 命令安全防护
│   ├── java-lint.sh           # Java 代码质量检查
│   ├── secret-scan.sh         # 安全扫描
│   └── session-summary.sh     # 会话摘要
├── CLAUDE.md                    # 项目指导文档
├── CLAUDE.local.md             # 个人配置（已加入 .gitignore）
└── README.md                    # 说明文档
```

## 🔧 技能列表

### `/git-commit-check`
- **用途**：所有 git 操作的唯一入口点
- **触发器**：`git commit`、`git push`、`/commit`
- **功能**：仓库验证、用户配置强制执行

### `/executor-dependency`
- **用途**：Java 线程池依赖管理
- **触发器**：线程池关键词、异步/并发代码模式
- **功能**：自动检测 Maven 项目、注入依赖、生成配置

### `/verify`
- **用途**：验证插件配置和技能定义
- **功能**：检查 JSON 配置语法、验证 YAML 前置格式

### `/test`
- **用途**：运行插件集成测试
- **功能**：测试所有技能的基本功能、验证钩子脚本执行

## 📋 钩子系统

### PreToolUse（命令执行前）
- `scripts/command-guard.sh` - 危险命令拦截

### PostToolUse（文件编辑后）
- `scripts/java-lint.sh` - Java 代码质量检查
- `scripts/secret-scan.sh` - 安全扫描

### Stop（会话结束）
- `scripts/session-summary.sh` - 会话摘要记录

## 🔐 安全特性

### 命令防护规则
- 系统破坏防护
- 磁盘操作拦截
- 权限提升检测
- Fork 炸弹防护
- 远程代码执行拦截
- 关键文件保护

### 密钥扫描模式
- AWS/GitHub/Slack token
- 数据库凭证
- API 密钥
- 私钥和证书
- 云服务认证

## 🚀 最佳实践

### 对于开发者
1. 使用 `/commit` 进行标准化的 git 操作
2. 确保 Java 项目遵循代码检查标准
3. 将密钥存储在环境变量或密钥管理器中
4. 使用提供的技能处理常见模式

### 对于插件维护者
1. 定期更新钩子脚本
2. 审查被拦截命令的误报
3. 维护密钥扫描模式
4. 更新代码检查工具配置

## 🎯 使用场景

### Spring Boot 项目初始化
```bash
# 创建新的 Spring Boot 项目
spring init --dependencies=web,actuator my-app

# 进入项目目录
cd my-app

# 使用插件初始化
/verify  # 验证配置
/test    # 运行测试
```

### 异步任务开发
```java
// 当检测到以下模式时，插件会自动生成配置
@Service
public class OrderService {
    
    // 异步处理订单
    @Async
    public void processOrder(Order order) {
        // 业务逻辑
    }
    
    // 定时任务
    @Scheduled(fixedRate = 5000)
    public void reportCurrentTime() {
        // 定时任务逻辑
    }
}
```

## 📈 性能优化

1. **快速反馈**：代码检查立即执行，无需等待
2. **智能检测**：只对相关文件运行检查
3. **可配置**：可以根据项目需求调整检查规则
4. **错误预防**：在开发早期发现问题

## 🤝 贡献指南

欢迎贡献代码或提出建议：

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开 Pull Request

## 📄 许可证

本项目采用 Apache-2.0 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🆘 故障排除

### 常见问题
1. **技能无法识别**：检查 `.claude-plugin/plugin.json` 配置
2. **钩子脚本不执行**：确认脚本有执行权限
3. **Git 提交失败**：检查仓库状态和用户配置

### 调试方法
1. 使用 `/verify` 验证配置
2. 查看 Claude Code 日志
3. 手动运行钩子脚本进行测试

---

*这个插件展示了 Claude Code 的扩展能力，通过自定义技能和钩子系统为 Spring Boot 开发提供自动化的工作流解决方案。*