# 命令参考

> 用户和 Agent 可用的所有命令。

---

## Agent 自动执行的命令

以下命令由 Agent 在每轮协议中自动调用，用户无感知：

### sm-project-key.sh

```bash
bash ~/.cursor/skills/session-memory/scripts/sm-project-key.sh <workspace_path>
```

从 workspace 路径计算 project key：`basename@md5前8位`。

### sm-bootstrap.sh

```bash
bash ~/.cursor/skills/session-memory/scripts/sm-bootstrap.sh <workspace_path>
```

会话启动时调用：确保项目目录存在，初始化或读取 INDEX/CORE，返回内容供 Agent 注入。

### sm-write.sh

```bash
bash ~/.cursor/skills/session-memory/scripts/sm-write.sh \
  --project-key <key> \
  --file <target.md> \
  --title "<标题>" \
  --summary "<≤30字摘要>" \
  --body "<markdown 正文>"
```

原子写入 + INDEX 同步。**Agent 所有记忆写入必须走此命令**。

---

## 用户显式调用的命令

### /remember <text>

让 Agent 把内容追加到当前项目的 `CORE.md`。

```
/remember 这个项目用 pnpm，不用 npm
```

Agent 会调用 `sm-write.sh` 写入，并更新 INDEX。

---

### /recall <query>

全文关键词搜索，跨 `sessions/` 和 `facts/`。

```
/recall redis session store
```

Agent 会调用 `sm-recall.sh`：

```bash
bash ~/.cursor/skills/session-memory/scripts/sm-recall.sh <query>
```

输出匹配的文件路径、行号、上下文片段。

---

### /memory-status

查看当前项目的记忆状态：文件大小、最后修改时间、条目数量。

```
/memory-status
```

Agent 会调用 `sm-status.sh`：

```bash
bash ~/.cursor/skills/session-memory/scripts/sm-status.sh <project_key>
```

示例输出：

```
projects/7verse-ug@a3f2e1b9/
  INDEX.md          1.2 KB   2026-04-28 14:32
  CORE.md            3.1 KB   2026-04-28 14:32
  decisions.md       0.8 KB   2026-04-26 09:15
  requirements.md    1.5 KB   2026-04-27 11:40
  sessions/          4 files  2026-04-25
  facts/             2 files  2026-04-23
```

---

### /memory-scrub <regex>

删除记忆文件中匹配正则表达式的条目（用于清理误写入的 PII、密钥、测试数据）。

```
/memory-scrub "sk-.*?"
```

> ⚠️ 此命令不可逆。删除前 Agent 会显示将被删除的内容供确认。

---

### /memory-compress

手动触发当前会话摘要压缩。当会话特别长（>50 轮）但用户没有明确结束时可以使用。

```
/memory-compress
```

Agent 会调用 `sm-compress.sh`，生成 `sessions/YYYY-MM-DD-<topic>.md` 并更新 INDEX。

---

## 调试命令

### 查看当前 project key

```bash
bash ~/.cursor/skills/session-memory/scripts/sm-project-key.sh "$(pwd)"
```

### 查看全局 INDEX

```bash
cat ~/.cursor/skills/session-memory/scripts/sm-project-key.sh
# 或直接
cat /Users/vivx/cursor/digital-human/skills/SKILLFORGE/memory/sessions/_global/INDEX.md
```

### 查看某项目的 CORE

```bash
# 先算 project key
KEY=$(bash ~/.cursor/skills/session-memory/scripts/sm-project-key.sh /Users/vivx/cursor/7verse-ug)
cat /Users/vivx/cursor/digital-human/skills/SKILLFORGE/memory/sessions/projects/$KEY/CORE.md
```

---

## 命令速查表

| 命令 | 谁触发 | 作用 |
|------|--------|------|
| `sm-project-key.sh` | Agent（每轮自动）| 计算当前 workspace 的 project key |
| `sm-bootstrap.sh` | Agent（会话启动）| 初始化或读取项目记忆 |
| `sm-write.sh` | Agent（识别到关键信息）| 原子写入 + INDEX 同步 |
| `sm-recall.sh` | Agent 或用户 | 关键词全文搜索 |
| `sm-status.sh` | Agent 或用户 | 查看记忆文件大小/时间 |
| `sm-compress.sh` | Agent 或用户 | 长会话摘要压缩 |
| `/remember <text>` | 用户 | 追加到 CORE |
| `/recall <query>` | 用户 | 搜索记忆 |
| `/memory-status` | 用户 | 查看状态 |
| `/memory-scrub <regex>` | 用户 | 清理敏感数据 |
| `/memory-compress` | 用户 | 手动压缩会话 |
