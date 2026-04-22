---
name: executor-dependency
description: >
  For Java Maven projects only.
  [User-triggered] Keywords: thread pool, executor, async, concurrent, scheduled task,
  ThreadPoolExecutor, ScheduledExecutor, CompletableFuture, @Async, @Scheduled, batch processing, message consumer.
  [AI self-triggered] When Codex is writing code that requires async/concurrent/scheduled capability
  in a Java Maven project, it MUST invoke this skill proactively.
  Never generate new ThreadPoolExecutor(...) or Executors.newXxx(...) directly in Java code.
  Automatically detects pom.xml dependency, injects base-executor-starter, generates YAML config and business code.
---

# Executor Dependency Skill

## Goal

Uniformly introduce `io.github.bridgewares:base-executor-starter` into Java/Spring Boot Maven projects.
Drive thread pool creation through YAML configuration.
**Prohibit** bare usage of `new ThreadPoolExecutor(...)` or `Executors.newXxx(...)` in business code.

---

## Trigger Rules

### User-triggered (any of the following)

| Type                 | Keywords / Scenarios                                                                                       |
|----------------------|------------------------------------------------------------------------------------------------------------|
| Explicit keywords    | thread pool, executor, async, concurrent, scheduled task                                                   |
| Java types           | `ThreadPoolExecutor`, `ScheduledExecutorService`, `CompletableFuture`, `@Async`                            |
| Business description | "async processing", "background execution", "batch import", "message consumer", "polling", "delayed retry" |
| Refactor intent      | "make this async", "run this concurrently", "add a scheduled task"                                         |

### AI self-triggered (Codex proactively triggers when writing code, any of the following)

| Scenario                                        | Typical Example                                    |
|-------------------------------------------------|----------------------------------------------------|
| About to generate `new ThreadPoolExecutor(...)` | Any bare thread pool constructor                   |
| About to generate `Executors.newXxx(...)`       | `newFixedThreadPool`, `newCachedThreadPool`, etc.  |
| Method needs async execution                    | Sending notifications, push messages, file uploads |
| Interface needs parallel background processing  | Batch queries, multi-source aggregation            |
| Needs a scheduled or delayed task               | Timed sync, polling check, delayed compensation    |

> When self-triggered, Codex **must** inform the user before output:  
> "Detected need for thread pool capability. Introducing `base-executor-starter` to avoid unmonitorable bare thread
> pools..."

### Skip conditions (skip this skill if any applies)

- Non-Java project (Python, Node.js, Go, etc.)
- Java project but non-Maven build (Gradle, Ant, etc.)
- Discussing thread pool concepts only, no code changes needed
- User explicitly says "no dependency needed" or "just show me an example"

---

## ⛔ Pre-check: Is This a Java Maven Project?

**Before any action**, this validation must pass. If it fails, terminate and notify the user.

### Check 1: Detect pom.xml

```bash
# Search for pom.xml within project root
find . -maxdepth 2 -name "pom.xml" | head -3
```

- **Found** → Proceed to Check 2.
- **Not found** → Terminate with message:
  > ⚠️ No `pom.xml` detected. This skill only applies to **Java Maven projects**.  
  > If you are using Gradle, please add the dependency manually. Let me know your build tool if you need help.

### Check 2: Confirm Java source

```bash
# Check for Java source files
find . -name "*.java" -maxdepth 5 | head -1

# Or check pom.xml for Java compiler config
grep -E "maven-compiler-plugin|java.version|<language>java" pom.xml | head -3
```

- **Java files or config found** → Validation passed, proceed to Step 0.
- **Not found** → Terminate with message:
  > ⚠️ `pom.xml` was found but no Java sources detected. Please confirm this is a Java project and retry.

> ✅ **Both checks must pass** before entering the main workflow.

---

## Workflow

### Step 0 — Confirm Trigger Source

**Source A (user)**: User explicitly mentions thread pool needs. Briefly explain the planned actions.  
**Source B (AI self-triggered)**: Codex identifies async/concurrent/scheduled need while writing code. Explain why the
skill is being invoked automatically.

Both sources proceed to Step 1.

---

### Step 1 — Check Existing Dependency

```bash
grep -r "base-executor-starter" . --include="pom.xml" -l
```

- **Found** → Notify: "`base-executor-starter` already exists, no need to add again." Jump to **Step 4**.
- **Not found** → Proceed to Step 2.

---

### Step 2 — Determine Version

#### 2.1 Check for base-parent

```bash
grep -A5 "<parent>" pom.xml | grep "base-parent"
```

- **Is a base-parent subproject** → Version is managed by parent pom. **Omit `<version>` tag**. Jump to Step 3.
- **Not base-parent** → Proceed to 2.2.

#### 2.2 Fetch Latest Stable Version

Use `web_fetch` to retrieve:

```
https://central.sonatype.com/artifact/io.github.bridgewares/base-executor-starter/versions
```

- **Success** → Show up to 5 recent stable versions (no SNAPSHOT), ask the user:
  > Available versions: `1.2.0` (latest), `1.1.0`, `1.0.0`  
  > Please select a version, or press Enter / type `auto` to use the latest `1.2.0`

- **Failure (network error)** → Default to `1.0.0`, notify user, continue without blocking.

User inputs `auto`, empty Enter, or invalid input → use **latest stable version**.

---

### Step 3 — Modify pom.xml

Use `str_replace` tool to insert the dependency before `</dependencies>`.

**Scenario A (with base-parent, omit version)**:

```xml

<dependency>
    <groupId>io.github.bridgewares</groupId>
    <artifactId>base-executor-starter</artifactId>
</dependency>
```

**Scenario B (no base-parent, with version)**:

```xml

<dependency>
    <groupId>io.github.bridgewares</groupId>
    <artifactId>base-executor-starter</artifactId>
    <version>${selected-version}</version>
</dependency>
```

Validate XML after insertion:

```bash
cp pom.xml pom.xml.bak       # backup first
xmllint --noout pom.xml && echo "XML OK"
```

If validation fails → **rollback** from `pom.xml.bak` and report the error. Terminate.

---

### Step 4 — Generate YAML Configuration

### 4.1 Determine if the project's src/main/resources/application.yml exists

**Determine if the project's `src/main/resources/application.yml` exists; if not, create
the `src/main/resources/application.yml` file.**

```bash
touch src/main/resources/application.yml
```

#### 4.2 ConfigurationProperties Field Mapping Rules

Spring Boot `@ConfigurationProperties` uses **Relaxed Binding**:
Java `camelCase` field names are automatically mapped to YAML `kebab-case` keys (lowercase + hyphens).

```
Java field (camelCase)     →   YAML key (kebab-case)
─────────────────────────────────────────────────────
poolName                   →   pool-name
corePoolSize               →   core-pool-size
maxPoolSize                →   max-pool-size
keepAliveTimeMs            →   keep-alive-time-ms
queueSize                  →   queue-size
rejectHandler              →   reject-handler
showLogMinCostTimeMs       →   show-log-min-cost-time-ms
scheduleExecutors (Map)    →   schedule-executors         ← Map field names are also converted
```

`ThreadPoolProperties` binding root: `spring.executor.extension.thread-pool`

It contains two `Map<String, ThreadPoolProperty>` fields:

- `executors`         → regular thread pool configurations
- `scheduleExecutors` → `schedule-executors` → scheduled thread pool configurations

**Key distinction**:

- **Map key** (e.g., `orderExecutor`): A configuration identifier in YAML to distinguish multiple pools. **Not** the
  Bean name.
- **`pool-name` value**: The **Spring Bean name** registered in the container. Used in `@Async(value="xxx")` and
  `@Qualifier("xxx")`.

#### 4.3 Full Field Reference

| YAML Key                    | Java Field             | Type    | Description                                                | Scope           |
|-----------------------------|------------------------|---------|------------------------------------------------------------|-----------------|
| `pool-name`                 | `poolName`             | String  | **Spring Bean name** used in `@Async` / `@Qualifier`       | Both            |
| `core-pool-size`            | `corePoolSize`         | int     | Core thread count                                          | Both            |
| `max-pool-size`             | `maxPoolSize`          | int     | Maximum thread count                                       | Regular only ⚠️ |
| `queue-size`                | `queueSize`            | int     | Blocking queue length                                      | Regular only ⚠️ |
| `keep-alive-time-ms`        | `keepAliveTimeMs`      | long    | Non-core thread idle timeout (ms)                          | Regular only ⚠️ |
| `primary`                   | `primary`              | boolean | Primary Bean for `@Autowired` injection                    | Both            |
| `reject-handler`            | `rejectHandler`        | String  | Rejection policy, see table below                          | Both            |
| `show-log-min-cost-time-ms` | `showLogMinCostTimeMs` | long    | Log slow tasks exceeding this threshold (ms), 0 = disabled | Both            |

⚠️ `MonitorableScheduleThreadPoolExecutor` **does not support** these three fields. **Do not output them** when
generating scheduled thread pool config.

Rejection policy enum:

| YAML Value       | Policy Class          | Behavior                                                      |
|------------------|-----------------------|---------------------------------------------------------------|
| `abort`          | `AbortPolicy`         | Throws `RejectedExecutionException` (default)                 |
| `discard`        | `DiscardPolicy`       | Silently drops new tasks                                      |
| `discard-oldest` | `DiscardOldestPolicy` | Drops oldest queued task, then retries                        |
| `caller-runs`    | `CallerRunsPolicy`    | Caller thread executes the task (no task loss, load shedding) |

#### 4.4 Regular Thread Pool Config Template

```yaml
spring:
  executor:
    extension:
      thread-pool:
        executors:
          orderExecutor: # Map key: YAML config identifier (NOT the Bean name)
            pool-name: orderExecutor        # ← Spring Bean name, used in @Async / @Qualifier
            core-pool-size: 10
            max-pool-size: 20
            queue-size: 200
            keep-alive-time-ms: 60000
            primary: true                   # true = preferred @Autowired injection target
            reject-handler: caller-runs     # Recommended: caller fallback, no task loss
            show-log-min-cost-time-ms: 500  # Log tasks exceeding 500ms, 0 = disabled
```

** `application.yaml` is in `src/main/resources` **

#### 4.5 Scheduled Thread Pool Config Template

```yaml
spring:
  executor:
    extension:
      thread-pool:
        schedule-executors: # scheduleExecutors (camelCase) → schedule-executors (kebab-case)
          retryScheduler: # Map key: YAML config identifier
            pool-name: retryScheduler       # ← Spring Bean name
            core-pool-size: 4
            primary: true # true = preferred @Autowired injection target
            reject-handler: abort
            show-log-min-cost-time-ms: 1000
            # Do NOT include: max-pool-size / queue-size / keep-alive-time-ms (not supported)
```

** `application.yaml` is in `src/main/resources` **

#### 4.6 Mixed Config (Regular + Scheduled)

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

### Step 5 — Generate Business Code

#### Async Task with @Async

`@Async` requires `@EnableAsync` on a startup or configuration class:

```java

@SpringBootApplication
@EnableAsync   // Without this, @Async methods run synchronously
public class Application { ...
}
```

Business code:

```java

@Service
public class OrderService {

    // value = pool-name value (Bean name)
    @Async(value = "orderExecutor")
    public CompletableFuture<Void> asyncNotify(Long orderId) {
        // async notification logic
        return CompletableFuture.completedFuture(null);
    }
}
```

#### Manual Task Submission

```java

@Service
public class BatchService {

    // @Qualifier value = pool-name value (Bean name)
    @Autowired
    @Qualifier("orderExecutor")
    private MonitorableThreadPoolExecutor orderExecutor;

    public void processBatch(List<Long> ids) {
        ids.forEach(id -> orderExecutor.execute(() -> process(id)));
    }
}
```

#### Scheduled Task

```java

@SpringBootApplication
@EnableScheduling   // Without this, scheduled tasks won't run
public class Application { ...
}
```

```java

@Service
public class RetryService {

    // @Qualifier value = pool-name value (Bean name)
    @Autowired
    @Qualifier("retryScheduler")
    private MonitorableScheduleThreadPoolExecutor retryScheduler;

    @PostConstruct
    public void startRetryTask() {
        retryScheduler.scheduleWithFixedDelay(
                this::doRetry,
                5, 30, TimeUnit.SECONDS   // initial delay 5s, interval 30s
        );
    }

    private void doRetry() { /* retry logic */ }
}
```

> ⛔ **Never** use `new ThreadPoolExecutor(...)` or `Executors.newXxx(...)` in business code.

---

### Step 6 — Summary Output

```
✅ Completed the following:
  1. Confirmed Java Maven project
  2. Added dependency to pom.xml: io.github.bridgewares:base-executor-starter:${version}
  3. Added thread pool config to application.yml (pool-name = Spring Bean name)
  4. Updated ${BusinessClass}.java with @Async(value="${pool-name}") / @Qualifier

💡 Reminders:
  - @Async requires @EnableAsync on a config class, otherwise methods run synchronously
  - @Async invoked within the same class bypasses the Spring proxy and will NOT be async
  - Value in @Qualifier("xxx") / @Async(value="xxx") = pool-name value (NOT the Map key)
  - Thread pool metrics available at /actuator/threadpool (requires spring-boot-starter-actuator)
  - Tune core-pool-size / max-pool-size / queue-size based on actual QPS load testing in production
```

---

## Decision Tree

```
Triggered? (user keyword OR AI judges async/concurrent/scheduled need while coding)
│
├─ No → Skip this skill
│
└─ Yes
    │
    ├─ [Pre-check] Is this a Java Maven project?
    │   ├─ pom.xml found ✓ AND .java files found ✓ → Pass, continue
    │   └─ Either missing → ⚠️ Terminate, notify user
    │
    ├─ [AI self-triggered] Explain to user why the skill is invoked
    │
    ├─ base-executor-starter already in pom.xml?
    │   ├─ Yes → Skip Step 2-3, jump to Step 4
    │   └─ No
    │       ├─ Using base-parent?
    │       │   ├─ Yes → Omit version → Step 3A
    │       │   └─ No → web_fetch version → Ask user → Step 3B
    │       └─ Backup → Modify pom.xml → Validate XML (rollback on failure)
    │
    ├─ Step 4: Generate YAML config (regular / scheduled / mixed)
    ├─ Step 5: Generate business code
    └─ Step 6: Output summary
```

---

## Notes

1. **Pre-check first**: Always confirm Java Maven project before any action. Terminate immediately if not.
2. **Idempotency**: grep-check dependency before every run to prevent duplicate injection.
3. **XML safety**: Backup pom.xml before modification. Validate after. Rollback on failure.
4. **Multi-module projects**: Add dependency to the nearest business module pom.xml, not the root pom, unless the user
   explicitly requests global scope.
5. **Spring Boot compatibility**: If the project uses an older `spring-boot-starter-parent`, remind the user to verify
   compatibility.
6. **Network fallback**: If version fetch fails, default to `1.0.0` and continue without blocking.
7. **@Async proxy trap**: Remind users that calling `@Async` methods from within the same class bypasses the Spring
   proxy and makes the method run synchronously.
8. **Scheduled pool field restriction**: When generating `schedule-executors` config, do NOT output `max-pool-size`,
   `queue-size`, or `keep-alive-time-ms`.
