# 工作原理

> Session Memory 是如何让 Agent "记住"一切的。

---

## 核心协议：每轮五步

每当用户发消息，Agent 按以下顺序执行（不可跳过）：

### Step 1 — 解析 project key

```bash
bash ~/.cursor/skills/session-memory/scripts/sm-project-key.sh "$(pwd)"
```

输出格式：`项目名@md5前8位`，如 `7verse-ug@a3f2e1b9`。

这个 key 唯一标识当前 workspace，解决"不同项目可能重名"的问题。

### Step 2 — 读取 INDEX.md（强制）

读取两个 INDEX 文件：

- `memory/sessions/_global/INDEX.md`（全局级，≤30 行）
- `memory/sessions/projects/<key>/INDEX.md`（项目级，≤50 行）

**INDEX 只包含文件路径和一句话摘要**，Token 开销极低（≤200 tokens），但能告诉 Agent 这个项目有哪些可用记忆。

### Step 3 — CORE 已在上下文中

`CORE.md` 在会话启动时已经注入，Agent 无需重新读取。继续处理当前任务即可。

### Step 4 — 判断是否需要下钻

根据 INDEX 的指向和当前任务，决定是否读取详情文件：

| 任务类型 | 是否下钻 | 读取文件 |
|---------|---------|---------|
| 修 typo、简单提问 | 否 | — |
| 新增 API handler | 是 | `facts/api-conventions.md` |
| 问技术选型 | 是 | `decisions.md` |
| 问需求约束 | 是 | `requirements.md` |
| 回溯某次讨论 | 是 | `sessions/YYYY-MM-DD-*.md` |

### Step 5 — 处理任务

执行用户请求。如果识别到关键信息，立即写入记忆（见下一节）。

---

## 会话启动时发生了什么

```
用户打开新窗口 / clear 后发消息
        │
        ▼
  sm-bootstrap.sh <workspace_path>
        │
        ├─ project_key 不存在？
        │     └─ 从模板创建 INDEX.md + CORE.md
        │
        ├─ INDEX.md 存在但为空？
        │     └─ 重新 bootstrap
        │
        └─ INDEX.md 有内容？
              └─ 直接使用
        │
        ▼
  输出 CORE.md 全文 + INDEX.md 摘要
        │
        ▼
  注入到 Agent 上下文的 primacy zone（对话开头）
```

这就是为什么 `/clear` 后 Agent 依然知道"这个项目用 Redis 不用 Memcached"——因为它从 `CORE.md` 读取了。

---

## 什么时候写入记忆

**时机比方式更重要**——Agent 在识别到以下信号时立即写入（不等会话结束）：

| 信号 | 目标文件 | 示例 |
|------|---------|------|
| 用户明确要求（"记住 X"、"以后都用 Y"）| `requirements.md` | "所有 handler 必须记录 traceID" |
| 技术决策（"决定用 X"、"we'll use X not Y"）| `decisions.md` | "用 Redis，不要 Memcached" |
| 用户提出的项目约定 | `facts/<topic>.md` | API 路由格式、命名规范 |
| 长时间讨论得出结论 | `sessions/YYYY-MM-DD-*.md` | 压缩后写入 |
| 用户直接调用 `/remember <text>` | `CORE.md` | 追加 |

**不应该写入的**：
- 临时调试值、测试结果
- 已经存在于代码库中的信息
- API 密钥、Token、密码
- 重复信息（先查 INDEX 确认）

---

## 写入流程：sm-write.sh

所有写入必须通过 `sm-write.sh`，它保证：

1. **原子性**：先写 tmp 文件，再 rename，避免写入中断导致文件损坏
2. **INDEX 同步**：写入详情文件后，同步更新对应 INDEX 条目（标题 + 摘要）
3. **★ CURRENT 标记**：新条目自动加 `★ CURRENT`，旧冲突条目加 `~~删除线~~`

```bash
bash ~/.cursor/skills/session-memory/scripts/sm-write.sh \
  --project-key 7verse-ug@a3f2e1b9 \
  --file requirements.md \
  --title "所有 handler 记录 traceID" \
  --summary "每个 HTTP handler 入口记录 traceID 到结构化日志" \
  --body "## 2026-04-23\n\n..."
```

---

## 冲突处理：新决策推翻旧决策

当新决策与旧决策矛盾时：

```markdown
## 2026-04-20
~~用 Memcached 做 session 存储~~ <!-- superseded by 2026-04-23: 切换为 Redis -->
★ CURRENT ## 2026-04-23
用 Redis 做 session 存储，因为支持持久化和集群模式。
```

**永远不删除旧条目**，审计历史永远可查。

---

## CORE 膨胀处理

如果 `CORE.md` 超过 200 行，Agent 自动执行：

1. 从 CORE 中识别最少使用的 topic
2. 将该 section 迁移到 `facts/<topic>.md`
3. 在 CORE 中替换为一行指针
4. 更新 INDEX.md 添加新条目

---

## 隐私保护

- 记忆目录默认 `.gitignore`（安装脚本自动添加）
- Agent 被要求**永远不写入密钥和 PII**
- 提供 `/memory-scrub <正则>` 命令按需清理

---

## Token 成本

| 操作 | Token 开销 |
|------|-----------|
| 读两个 INDEX | ≤400 tokens / 轮 |
| CORE 注入 | 一次性，不重复计入 |
| L3 详情下钻 | 仅命中时（~30% 轮次），平均 <500 tokens |
| 写入记忆 | <100 tokens（atomic append）|

**每轮固定成本：≤400 tokens**。比让 Agent 重新理解项目上下文（约 2000-5000 tokens）便宜 5-10 倍。
