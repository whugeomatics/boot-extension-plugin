---
name: executor-dependency
description: >
  仅适用于 Java Maven 项目。
  【用户触发】关键词：线程池、executor、异步、async、并发、定时任务、ThreadPoolExecutor、ScheduledExecutor、CompletableFuture、@Async、@Scheduled, 批量处理、消息消费。
  【AI 自触发】Claude 编写代码时判断需要异步/并发/定时能力，且当前是 Java Maven 项目，必须主动调用本技能。
  禁止在 Java 代码中直接生成 new ThreadPoolExecutor(...) 或 Executors.newXxx(...)。
  自动检测 pom.xml 依赖、注入 base-executor-starter、生成 YAML 配置与业务代码。
---

# Executor Dependency Skill

## 目标

在 Java/Spring Boot Maven 项目中统一引入 `io.github.bridgewares:base-executor-starter`，
通过 YAML 配置驱动线程池创建，**禁止**在业务代码中裸用 `new ThreadPoolExecutor(...)` 或
`Executors.newXxx(...)`。

---

## 触发规则

### 用户触发（满足以下任一条件）

| 类型      | 触发词 / 场景                                                                     |
|---------|------------------------------------------------------------------------------|
| 明确关键词   | 线程池、executor、异步、async、并发任务、定时任务                                              |
| Java 类型 | `ThreadPoolExecutor`、`ScheduledExecutorService`、`CompletableFuture`、`@Async` |
| 业务描述    | "异步处理"、"后台执行"、"批量导入"、"消息消费"、"定时轮询"、"延迟重试"                                    |
| 改造意图    | "把这个改成异步的"、"这里需要并发"、"加个定时任务"                                                 |

### AI 自触发（Claude 编写代码时主动判断，满足以下任一条件）

| 场景                                 | 典型例子                                         |
|------------------------------------|----------------------------------------------|
| 即将生成 `new ThreadPoolExecutor(...)` | 任何裸线程池构造                                     |
| 即将生成 `Executors.newXxx(...)`       | `newFixedThreadPool`、`newCachedThreadPool` 等 |
| 方法需要异步执行                           | 发送通知、推送消息、写日志、文件上传                           |
| 接口需要后台并行处理                         | 批量查询、聚合多数据源                                  |
| 需要生成定时/延迟任务                        | 定时同步、轮询检查、延迟补偿                               |

> 自触发时，Claude **必须**在输出前告知用户：  
> "检测到需要线程池能力，正在引入 `base-executor-starter`，避免裸用不可监控的线程池……"

### 不触发条件（满足任一则跳过本技能）

- 非 Java 项目（Python、Node.js、Go 等）
- Java 项目但非 Maven 构建（Gradle、Ant 等）
- 仅讨论线程池原理，无需修改项目代码
- 用户明确说明"不需要引入依赖"或"只看代码示例"

---

## ⛔ 前置校验：是否为 Java Maven 项目

**在执行任何操作前**，必须先通过此校验，不通过则终止并提示用户。

### 校验 1：检测 pom.xml

```bash
# 在项目根目录查找 pom.xml
find . -maxdepth 2 -name "pom.xml" | head -3
```

- **找到** → 继续校验 2。
- **未找到** → 终止，提示：
  > ⚠️ 未检测到 `pom.xml`，本技能仅适用于 **Java Maven 项目**。  
  > 若您使用 Gradle，请手动添加依赖；若需要，请告知构建工具类型。

### 校验 2：确认是 Java 项目

```bash
# 检查是否有 Java 源文件
find . -name "*.java" -maxdepth 5 | head -1

# 或检查 pom.xml 中是否有 Java 编译插件 / Java 源码目录配置
grep -E "maven-compiler-plugin|java.version|<language>java" pom.xml | head -3
```

- **找到 Java 文件或 Java 相关配置** → 校验通过，进入 Step 0。
- **未找到** → 终止，提示：
  > ⚠️ 检测到 `pom.xml` 但未发现 Java 源文件，请确认这是 Java 项目后重试。

> ✅ **两项校验均通过后**，才进入正式 Workflow。

---

## Workflow

### Step 0 — 触发源确认

**触发源 A（用户）**：用户明确提到线程池相关需求，向用户简要说明将要执行的操作。  
**触发源 B（AI 自触发）**：Claude 编写代码时判断需要异步/并发/定时能力，向用户说明自动引入原因。

两种触发源均继续 Step 1。

---

### Step 1 — 检查是否已引入依赖

```bash
grep -r "base-executor-starter" . --include="pom.xml" -l
```

- **已找到** → 提示"项目已引入 `base-executor-starter`，无需重复添加"，直接跳至 **Step 4**。
- **未找到** → 进入 Step 2。

---

### Step 2 — 确认版本号

#### 2.1 检查是否使用 base-parent

```bash
grep -A5 "<parent>" pom.xml | grep "base-parent"
```

- **是 base-parent 子项目** → 版本由父 pom 统一管理，`<version>` 标签**省略**，跳至 Step 3。
- **不是** → 执行 2.2。

#### 2.2 获取最新稳定版本

使用 `web_fetch` 抓取：

```
https://central.sonatype.com/artifact/io.github.bridgewares/base-executor-starter/versions
```

- **成功** → 展示最多 5 个近期稳定版（非 SNAPSHOT），询问用户：
  > 检测到可用版本：`1.2.0`（最新）、`1.1.0`、`1.0.0`  
  > 请选择版本，直接回车或输入 `auto` 使用最新版 `1.2.0`

- **失败（网络不通）** → 默认 `1.0.0`，告知用户后继续，不阻断主流程。

用户输入 `auto`、空回车、无效输入 → 使用**最新稳定版**。

---

### Step 3 — 修改 pom.xml

使用 `str_replace` 工具，在 `</dependencies>` 前插入依赖。

**场景 A（有 base-parent，省略 version）**：

```xml

<dependency>
    <groupId>io.github.bridgewares</groupId>
    <artifactId>base-executor-starter</artifactId>
</dependency>
```

**场景 B（无 base-parent，带 version）**：

```xml

<dependency>
    <groupId>io.github.bridgewares</groupId>
    <artifactId>base-executor-starter</artifactId>
    <version>${选定版本}</version>
</dependency>
```

插入后验证 XML 合法性：

```bash
cp pom.xml pom.xml.bak          # 先备份
xmllint --noout pom.xml && echo "XML OK"
```

若验证失败 → **回滚** `pom.xml.bak` 并报告错误原因，终止流程。

---

### Step 4 — 生成 YAML 配置

#### 4.1 ConfigurationProperties 字段映射规则

Spring Boot `@ConfigurationProperties` 使用**宽松绑定（Relaxed Binding）**：
Java 字段的 `camelCase` 自动映射到 YAML 的 `kebab-case`（全小写 + 连字符）。

```
Java 字段名（camelCase）   →   YAML 配置键（kebab-case）
──────────────────────────────────────────────────────
poolName                  →   pool-name
corePoolSize              →   core-pool-size
maxPoolSize               →   max-pool-size
keepAliveTimeMs           →   keep-alive-time-ms
queueSize                 →   queue-size
rejectHandler             →   reject-handler
showLogMinCostTimeMs      →   show-log-min-cost-time-ms
scheduleExecutors (Map)   →   schedule-executors        ← Map 字段名同样转换
```

`ThreadPoolProperties` 绑定根路径：`spring.executor.extension.thread-pool`

其下有两个 `Map<String, ThreadPoolProperty>`：

- `executors`         → 普通线程池配置集合
- `scheduleExecutors` → `schedule-executors` → 定时线程池配置集合

**关键区分**：

- **Map 的 key**（如 `orderExecutor`）：仅为 YAML 内的配置标识符，区分多组线程池，**不是** Bean name。
- **`pool-name` 的 value**：注册到 Spring 容器的 **Bean name**，`@Async(value="xxx")` 与 `@Qualifier("xxx")` 均使用此值。

#### 4.2 完整字段参考表

| YAML 键                      | Java 字段                | 类型      | 说明                                               | 适用范围    |
|-----------------------------|------------------------|---------|--------------------------------------------------|---------|
| `pool-name`                 | `poolName`             | String  | **Spring Bean name**，`@Async` / `@Qualifier` 中使用 | 普通 / 定时 |
| `core-pool-size`            | `corePoolSize`         | int     | 核心线程数                                            | 普通 / 定时 |
| `max-pool-size`             | `maxPoolSize`          | int     | 最大线程数                                            | 仅普通 ⚠️  |
| `queue-size`                | `queueSize`            | int     | 阻塞队列长度                                           | 仅普通 ⚠️  |
| `keep-alive-time-ms`        | `keepAliveTimeMs`      | long    | 非核心线程空闲存活时间(ms)                                  | 仅普通 ⚠️  |
| `primary`                   | `primary`              | boolean | 是否为主 Bean（`@Autowired` 时优先注入）                    | 普通 / 定时 |
| `reject-handler`            | `rejectHandler`        | String  | 拒绝策略，见下表                                         | 普通 / 定时 |
| `show-log-min-cost-time-ms` | `showLogMinCostTimeMs` | long    | 任务耗时超过此值打印慢日志(ms)，0 = 关闭                         | 普通 / 定时 |

⚠️ `MonitorableScheduleThreadPoolExecutor` **不支持**这三个字段，**生成定时线程池配置时不输出**。

拒绝策略枚举：

| YAML 值           | 对应策略                  | 行为                                  |
|------------------|-----------------------|-------------------------------------|
| `abort`          | `AbortPolicy`         | 抛出 `RejectedExecutionException`（默认） |
| `discard`        | `DiscardPolicy`       | 静默丢弃新任务                             |
| `discard-oldest` | `DiscardOldestPolicy` | 丢弃队列中最旧任务后重试                        |
| `caller-runs`    | `CallerRunsPolicy`    | 由调用方线程直接执行（削峰，不丢任务）                 |

#### 4.3 普通线程池配置模板

```yaml
spring:
  executor:
    extension:
      thread-pool:
        executors:
          orderExecutor: # Map key：YAML 内配置标识符（非 Bean name）
            pool-name: orderExecutor        # ← Spring Bean name，@Async / @Qualifier 使用此值
            core-pool-size: 10
            max-pool-size: 20
            queue-size: 200
            keep-alive-time-ms: 60000
            primary: true                   # true = @Autowired 时优先注入此 Bean
            reject-handler: caller-runs     # 推荐：调用方降级执行，不丢任务
            show-log-min-cost-time-ms: 500  # 任务超 500ms 打印慢日志，0 = 关闭
```

#### 4.4 定时线程池配置模板

```yaml
spring:
  executor:
    extension:
      thread-pool:
        schedule-executors: # scheduleExecutors (camelCase) → schedule-executors (kebab-case)
          retryScheduler: # Map key：YAML 内配置标识符
            pool-name: retryScheduler       # ← Spring Bean name
            core-pool-size: 4
            primary: true
            reject-handler: abort
            show-log-min-cost-time-ms: 1000
            # 注意：不输出 max-pool-size / queue-size / keep-alive-time-ms（定时线程池不支持）
```

#### 4.5 混合配置（普通 + 定时并存）

```yaml
spring:
  executor:
    extension:
      thread-pool:
        executors:
          orderExecutor:
            pool-name: orderExecutor
            core-pool-size: 10
            max-pool-size: 20
            queue-size: 200
            keep-alive-time-ms: 60000
            primary: true
            reject-handler: caller-runs
        schedule-executors:
          retryScheduler:
            pool-name: retryScheduler
            core-pool-size: 2
            reject-handler: abort
```

---

### Step 5 — 生成业务代码

#### 普通异步任务（@Async）

`@Async` 需在启动类或任意 `@Configuration` 类上添加 `@EnableAsync`：

```java

@SpringBootApplication
@EnableAsync   // 缺失此注解，@Async 方法将同步执行
public class Application { ...
}
```

业务代码：

```java

@Service
public class OrderService {

    // value = pool-name 的值（Bean name）
    @Async(value = "orderExecutor")
    public CompletableFuture<Void> asyncNotify(Long orderId) {
        // 异步通知逻辑
        return CompletableFuture.completedFuture(null);
    }
}
```

#### 手动提交任务

```java

@Service
public class BatchService {

    // @Qualifier value = pool-name 的值（Bean name）
    @Autowired
    @Qualifier("orderExecutor")
    private MonitorableThreadPoolExecutor orderExecutor;

    public void processBatch(List<Long> ids) {
        ids.forEach(id -> orderExecutor.execute(() -> process(id)));
    }
}
```

#### 定时任务

```java

@SpringBootApplication
@EnableScheduling   // 缺失此注解，定时任务不生效
public class Application { ...
}
```

```java

@Service
public class RetryService {

    // @Qualifier value = pool-name 的值（Bean name）
    @Autowired
    @Qualifier("retryScheduler")
    private MonitorableScheduleThreadPoolExecutor retryScheduler;

    @PostConstruct
    public void startRetryTask() {
        retryScheduler.scheduleWithFixedDelay(
                this::doRetry,
                5, 30, TimeUnit.SECONDS   // 初始延迟 5s，间隔 30s
        );
    }

    private void doRetry() { /* 重试逻辑 */ }
}
```

> ⛔ **禁止**在任何业务代码中直接使用 `new ThreadPoolExecutor(...)` 或 `Executors.newXxx(...)`

---

### Step 6 — 完成提示

```
✅ 已完成以下操作：
  1. 校验确认为 Java Maven 项目
  2. pom.xml 添加依赖 io.github.bridgewares:base-executor-starter:${version}
  3. application.yml 新增线程池配置（pool-name 即为 Spring Bean name）
  4. ${业务类}.java 使用 @Async(value="${pool-name}") / @Qualifier 完成异步逻辑

💡 注意事项：
  - @Async 需在配置类加 @EnableAsync，否则方法将同步执行
  - @Async 同类内直接调用会绕过 Spring 代理导致失效，需通过注入的 Bean 调用
  - @Qualifier("xxx") / @Async(value="xxx") 中 xxx = pool-name 的值（不是 Map key）
  - 可通过 /actuator/threadpool 查看线程池监控指标（需引入 spring-boot-starter-actuator）
  - 生产环境请依据实际 QPS 压测调整 core-pool-size / max-pool-size / queue-size
```

---

## 决策树速查

```
触发（用户关键词 或 AI 编写代码时主动判断）？
│
├─ 否 → 跳过本技能
│
└─ 是
    │
    ├─ 【前置校验】是 Java Maven 项目？
    │   ├─ 找到 pom.xml ✓ 且 找到 .java 文件 ✓ → 通过，继续
    │   └─ 任一不满足 → ⚠️ 终止，提示用户
    │
    ├─ [AI 自触发] 向用户说明自动引入原因
    │
    ├─ 已有 base-executor-starter？
    │   ├─ 是 → 跳过 Step 2-3，直接进入 Step 4
    │   └─ 否
    │       ├─ 使用 base-parent？
    │       │   ├─ 是 → 省略 version → Step 3A
    │       │   └─ 否 → web_fetch 获取版本 → 询问用户 → Step 3B
    │       └─ 备份 → 修改 pom.xml → 校验 XML（失败则回滚）
    │
    ├─ Step 4：生成 YAML 配置（普通 / 定时 / 混合）
    ├─ Step 5：生成业务代码
    └─ Step 6：输出操作摘要
```

---

## 注意事项

1. **前置校验优先**：任何操作前先确认 Java Maven 项目，非此类项目直接终止。
2. **幂等性**：每次执行前 grep 检查依赖，防止重复注入。
3. **XML 安全**：修改 pom.xml 前备份，修改后校验，失败则回滚。
4. **多模块项目**：优先将依赖加到最近的业务模块 pom.xml，而非根 pom，除非用户明确要求全局添加。
5. **Spring Boot 兼容性**：若项目 `spring-boot-starter-parent` 版本较旧，提示用户确认兼容性。
6. **网络降级**：版本获取失败时默认 `1.0.0`，不阻断主流程。
7. **@Async 失效陷阱**：提醒用户同类内直接调用会绕过 Spring 代理导致 `@Async` 失效。
8. **定时线程池参数限制**：生成 `schedule-executors` 配置时，不输出 `max-pool-size`、`queue-size`、`keep-alive-time-ms`。
