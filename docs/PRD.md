# Session Memory Skill — PRD

> 让 Cursor Agent 在长上下文对话中不丢失关键信息，且新开窗口可恢复记忆。

---

## 1. 背景与问题

### 1.1 现状痛点

在 Cursor 里做长任务（架构讨论、多轮需求迭代、跨文件重构）时常遇到：

1. **长窗口遗忘**：对话超过一定轮次，Agent 开始忽略早期的约束和决策
2. **跨窗口失忆**：`/clear` 或新开窗口后，所有上下文归零，必须重新交代背景
3. **现有工具不够用**：Cursor 官方 `@memories` 等只记录用户级全局记忆，不覆盖项目级的需求、决策、约束

### 1.2 用户场景

- 在 `7verse-ug` 做 linktree agent 开发，讨论了 10 轮的 API 设计，开新窗口接着做时 Agent 不知道
- 明确要求"所有 handler 加 traceID 日志"，30 轮后 Agent 写新 handler 又忘了加
- 多项目切换时，每个项目的技术栈、约定、注意事项必须重复说明

---

## 2. 理论依据

### 2.1 Lost in the Middle（Liu et al. 2023）

> *Liu, N. F., et al. "Lost in the Middle: How Language Models Use Long Contexts." TACL 2024. arXiv:2307.03172*

核心结论（在我们设计中必须体现）：

| 发现 | 设计启示 |
|---|---|
| **U 型注意力曲线**：模型对开头（primacy bias）和结尾（recency bias）记忆最强，中间最弱 | 关键信息必须置顶或置底，**绝不能埋在对话中间** |
| **长度越长衰减越严重**，即便是 100K 长上下文模型 | 不能依赖"长 context window 自己会记住"，必须主动压缩 |
| **Query-aware contextualization 有效**：根据当前问题重排上下文 | 每次注入记忆时按相关性筛选，不全部塞入 |

### 2.2 MemGPT / Letta（Packer et al. 2023）

> *Packer, C., et al. "MemGPT: Towards LLMs as Operating Systems." arXiv:2310.08560*

**OS 分层记忆模型**——我们直接借鉴：

| 层级 | Letta 术语 | 类比 | 本 skill 对应 |
|---|---|---|---|
| 始终在 context | Core Memory | RAM | `CORE.md`（项目约束、当前目标）|
| 按需检索 | Recall Memory | Cache | `sessions/*.md`（历史对话摘要）|
| 持久化存储 | Archival Memory | Disk | `facts/*.md`（跨 session 知识库）|

**关键原则**：Agent 自己管理记忆（self-editing memory），而不是被动接收。

### 2.3 RAPTOR（Sarthi et al., ICLR 2024）

> *Sarthi, P., et al. "RAPTOR: Recursive Abstractive Processing for Tree-Organized Retrieval." ICLR 2024. arXiv:2401.18059*

提出**递归抽象树**：对长文档自底向上做 embedding + 聚类 + 摘要，构建多层抽象树。检索时用 **collapsed tree**（扁平化一次匹配）比 tree traversal（逐层下钻）更简单且效果相当。在 QuALITY 基准上比传统 RAG 绝对准确率提升 20%。

**本设计借鉴**：
- Collapsed tree 思想 → `INDEX.md` 做扁平化索引层，一次读完
- 多层抽象 → 用目录层级（全局 / 项目 / topic）替代 embedding 聚类

### 2.4 HippoRAG（Gutiérrez et al., NeurIPS 2024 / ICML 2025）

> *Gutiérrez, B. J., et al. "HippoRAG: Neurobiologically Inspired Long-Term Memory for Large Language Models." NeurIPS 2024. arXiv:2405.14831*
> *Gutiérrez, B. J., et al. "From RAG to Memory: Non-Parametric Continual Learning for Large Language Models." ICML 2025. arXiv:2502.14802*

借鉴海马体索引理论：**索引与内容分离**，用稀疏索引（KG + PageRank）做 mediator，实现单步多跳检索。HippoRAG 2 的 dense-sparse 混合索引在 indexing 阶段比 GraphRAG 节省 ~92% token。

**本设计借鉴**：
- 索引与内容分离原则 → `INDEX.md` 只存标题+摘要+路径，不含具体内容
- 稀疏索引思想 → 不用 embedding，用 Markdown 路径直接寻址

### 2.5 Claude Code 工程实践

来自 Anthropic 官方 + HumanLayer 团队的实战经验：

- **CLAUDE.md 控制在 60-200 行**（模型可靠遵循指令数 ~150-200 条，系统 prompt 已用 ~50）
- **50% context 时手动 compact**，不等 60-70% 才做（"dumb zone"）
- **Progressive disclosure**：主文件只放索引 + 核心规则，详情放子目录按需加载
- 超过 200 行必须拆成 topic-specific 文件

---

## 3. 设计目标

### 3.1 MUST（必须）

1. **M1 — 项目级持久化**：以项目（workspace 路径）为维度区分记忆
2. **M2 — 会话启动自动注入**：Agent 接收新任务时，自动读取当前项目的 Core 记忆
3. **M3 — 对话中自动更新**：识别新需求/决策/约束后，Agent 立即写入对应文件
4. **M4 — 独立存储**：使用独立的 `~/.cursor/session-memory/memory/` 目录，不依赖任何外部系统
5. **M5 — 防 Lost-in-Middle**：Core 记忆注入位置在对话开头，关键约束可在每轮重复置底
6. **M6 — 分级索引**：每个项目维护 `INDEX.md` 顶层索引（仅列标题+一句话摘要+文件路径），详情按需加载，避免 Core 无限膨胀
7. **M7 — 每轮强制索引检查**：Agent 每轮处理新任务前必须"扫一眼索引"（读 INDEX.md），判断是否需要下钻读详情——**扫索引是强制的，下钻是可选的**

### 3.2 SHOULD（应该）

1. **S1 — 压缩触发**：对话轮次/token 超过阈值时，自动摘要压缩
2. **S2 — 跨项目知识**：用户级全局记忆（跨所有项目）+ 项目级（当前 workspace）双层
3. **S3 — 审计可追溯**：每条记忆带时间戳、来源会话 ID
4. **S4 — 索引自动维护**：写入详情文件后同步更新 INDEX.md 的标题/摘要条目

### 3.3 NON-GOALS（不做）

- ❌ 语义搜索 / embedding（依赖重、项目小用不上，靠 `rg` 关键词搜索足够）
- ❌ 多 agent 共享记忆（当前是单用户场景）
- ❌ 图谱结构（YAML/Markdown 扁平结构已够用）
- ❌ 自动遗忘机制（显式删除，不搞 TTL）

---

## 4. 架构设计

### 4.1 存储结构（三级索引）

独立存储在 `~/.cursor/session-memory/memory/sessions/`，**采用 INDEX → CORE → DETAIL 三级结构**：

```
~/.cursor/session-memory/memory/
├── .gitignore                    # 防止误提交记忆数据
└── sessions/
    ├── _global/
    │   ├── INDEX.md             # L1 全局索引（≤30 行）
    │   ├── CORE.md              # L2 全局核心（≤60 行）
    │   └── facts/               # L3 全局详情
    │       └── tech-stack.md
    └── projects/
        ├── 7verse-ug@a3f2e1b9/
        │   ├── INDEX.md          # L1 项目索引（≤50 行 ★强制每轮读）
        │   ├── CORE.md          # L2 项目核心（≤200 行）
        │   ├── decisions.md      # L3 详情（按需）
        │   ├── requirements.md  # L3 详情（按需）
        │   ├── facts/           # L3 详情（按需）
        │   │   └── api-conventions.md
        │   └── sessions/        # L3 历史会话摘要
        │       ├── 2026-04-23-linktree-api.md
        │       └── 2026-04-22-auth-refactor.md
        ├── seedance-pipeline@c0b64168/
        └── ug-fe@1a2b3c4d/
```

**项目识别规则**：按 workspace 路径的 basename + 完整路径 MD5 前 8 位做 key（如 `7verse-ug@a3f2e1b9`）。

### 4.2 三级索引模型（★ 核心设计）

**理论依据**：

- **RAPTOR**（Sarthi et al., ICLR 2024, arXiv:2401.18059）提出递归抽象树检索：对文档**自底向上递归聚类 + 摘要**，形成多层抽象的树结构。检索时可用两种策略：**tree traversal**（逐层下钻）或 **collapsed tree**（扁平化后一次性匹配）。实验证明 collapsed tree 更简单且效果更好，在 QuALITY 上比传统 RAG 绝对准确率提升 20%。
- **HippoRAG**（Gutiérrez et al., NeurIPS 2024, arXiv:2405.14831）借鉴海马体索引理论：**索引是轻量 mediator，与内容分离**，通过稀疏索引 + PageRank 实现"单步多跳检索"，比迭代检索快 6-13 倍、便宜 10-30 倍。
- **HippoRAG 2 / From RAG to Memory**（Gutiérrez et al., ICML 2025, arXiv:2502.14802）进一步证明：dense-sparse 混合索引、passage-phrase 双节点结构在关联性检索上比纯 embedding RAG 好 7 个 F1 点，indexing token 消耗仅为 GraphRAG 的 1/10（9M vs 115M）。

**本设计的借鉴**：

1. **RAPTOR 的 collapsed tree 思想** → 我们用 `INDEX.md` 做"扁平化索引层"，Agent 一次读完就知道全局，不需要逐层下钻（对小工程足够）
2. **HippoRAG 的"索引与内容分离"** → INDEX.md 只存标题+摘要+路径，不存具体内容；详情在 L3 文件里按需 Read
3. **递归抽象思想的简化版** → 用文件系统目录结构做天然的两层抽象（项目级 INDEX + 全局 INDEX），不需要 embedding/clustering 这种重机制

**为什么不直接用 RAPTOR/HippoRAG**：
- 依赖 embedding 模型、向量 DB、GMM 聚类，部署成本高
- 我们的场景是单用户 IDE 内的项目级记忆，体量 < 1000 条，文件系统 + Markdown + `rg` 已经够用
- Markdown 可以人工阅读/修改，embedding 向量不能

**落地为 B+ 树简化版**——Agent 像查数据库一样查记忆，**先看索引，再下钻读详情**。

```
L1 INDEX.md  (始终加载，极短)
  ↓ 判断相关性
L2 CORE.md   (始终加载，关键约束)
  ↓ 按需下钻
L3 详情文件   (仅当 INDEX 指向时才读)
```

**INDEX.md 格式规范**：

```markdown
# 7verse-ug 记忆索引

## CORE（自动加载）
- CORE.md — 项目约束和当前目标

## 需求/决策（按需）
- requirements.md — 用户提出的所有明确需求
- decisions.md — 关键技术决策（Redis vs Memcached 等）

## 专题知识（按需）
- facts/api-conventions.md — API 路由/错误码/traceID 规范
- facts/auth-flow.md — 鉴权流程和 middleware 设计

## 历史会话（按需）
- sessions/2026-04-23-linktree-api.md — linktree API 设计讨论
- sessions/2026-04-22-auth-refactor.md — admin auth middleware 重构
```

**硬约束**：
- INDEX.md 每个条目**一行**：`- 相对路径 — 一句话摘要（≤30 字）`
- INDEX.md 总长不超过 50 行（项目级）/ 30 行（全局级）
- 超过就必须按分类拆成多个 INDEX（如 `INDEX-sessions.md`）

### 4.3 每轮强制索引检查（★ M7 落地）

**Agent 行为契约**：

```
每轮用户消息到达时：
  1. [强制] 读取 INDEX.md（全局 + 当前项目）  ← 极低 token 成本
  2. [强制] CORE.md 已在上下文中，继续生效
  3. [判断] 当前任务是否需要 L3 详情？
     ├─ 需要 → Read 指定详情文件（如 decisions.md）
     └─ 不需要 → 直接回答，不产生额外 IO
  4. 回答完毕
```

**简单任务示例**（不下钻）：
- 用户：「帮我修个 typo」
- Agent 内部：读 INDEX，没什么相关，直接改，完成

**复杂任务示例**（下钻）：
- 用户：「给这个 handler 加日志」
- Agent 内部：读 INDEX → 看到 `facts/api-conventions.md — traceID 规范` → Read 该文件 → 按规范加日志

**Token 成本估算**：
- INDEX.md 读取：≤200 tokens / 轮 × 每轮 1 次 = 可接受
- CORE.md 读取：一次性注入，不重复
- L3 详情：仅命中时才读，平均 < 30% 轮次需要

### 4.4 三层记忆模型（映射 MemGPT/Letta）

```
┌────────────────────────────────────────────────────────┐
│ Layer 1: Core Memory（RAM，始终在 context）            │
│ ├─ _global/CORE.md            ≤60 行                   │
│ └─ projects/<proj>/CORE.md    ≤200 行                  │
│ 会话启动时 Agent 自动读取并注入对话开头                │
└────────────────────────────────────────────────────────┘
                        ↑ 注入
┌────────────────────────────────────────────────────────┐
│ Layer 2: Recall Memory（Cache，按需检索）              │
│ └─ projects/<proj>/sessions/*.md                       │
│ Agent 用 rg 关键词搜索过往会话摘要                     │
└────────────────────────────────────────────────────────┘
                        ↑ 查询
┌────────────────────────────────────────────────────────┐
│ Layer 3: Archival Memory（Disk，持久知识）             │
│ ├─ projects/<proj>/decisions.md                        │
│ ├─ projects/<proj>/requirements.md                     │
│ └─ projects/<proj>/facts/                              │
│ 沉淀长期事实，用 Read 工具按需加载                     │
└────────────────────────────────────────────────────────┘
```

### 4.5 触发时机

| 时机 | 行为 | 触发方 | 强制 |
|---|---|---|---|
| **会话启动** | 读取 INDEX.md + CORE.md 注入系统上下文 | Skill 自动 | ✅ |
| **每轮消息到达** | 重新扫描 INDEX.md（CORE 已在 context 中）| Agent 自动 | ✅ |
| **索引命中相关条目** | 下钻 Read 对应 L3 详情文件 | Agent 判断 | 可选 |
| **用户明确约束**（"记住 X"、"以后都用 Y"）| 写入 `requirements.md` + 更新 INDEX | Agent 识别 | ✅ |
| **技术决策**（"我们决定用 Redis 不用 Memcached"）| 追加到 `decisions.md` + 更新 INDEX | Agent 识别 | ✅ |
| **长会话 50% context** | 生成摘要写入 `sessions/YYYY-MM-DD-*.md` + 更新 INDEX | Skill 提醒 | ✅ |
| **用户显式调用** `/remember xxx` | 写入 Core | 用户触发 | — |
| **用户显式调用** `/recall xxx` | 关键词搜索 sessions/ + facts/ | 用户触发 | — |

### 4.6 防 Lost-in-Middle 策略

针对论文发现，具体做三件事：

1. **Core 置顶**：每轮 Agent 回复前，把 `CORE.md` 前 200 行当作 system-level context（primacy bias 区）
2. **关键约束末端重放**：用户标了 `[STICKY]` 的需求，每 10 轮在对话末尾重复一次（recency bias 区）
3. **中段不放重要信息**：原始长对话中间部分到了 50% 阈值后必须压缩，不让 Agent 依赖中段检索

---

## 5. 与现有系统的关系

### 5.1 与 `.cursor/rules/`

- `.cursor/rules/` 存的是**静态规则**（编码规范、始终适用的约束）
- Session Memory 存的是**动态知识**（本次讨论产生的决策、当前任务目标）

### 5.2 与 Cursor 官方 Memories（`@memories`）

Cursor 2.0+ 原生支持的是用户级全局 memory，本 skill 聚焦项目级动态上下文，互补。

---

## 6. 里程碑

| 阶段 | 产出 | 状态 |
|---|---|---|
| **M0 — PRD**（本文档）| 需求 + 设计定稿 | ✅ |
| **M1 — SKILL.md 骨架** | 可注入、可读写的最小版本 | ✅ |
| **M2 — 项目识别 + 自动注入** | 会话启动自动读取对应项目 CORE | ✅ |
| **M3 — 压缩触发** | 长会话摘要写入 sessions/ | ✅ |
| **M4 — 回顾命令** | `/recall` 关键词检索 | ✅ |
| **M5 — 试用验证** | 在 7verse-ug 或 seedance-pipeline 实测 1-2 天 | ✅ |
| **M6 — 调优** | 根据实际使用调整阈值/结构 | 持续 |

---

## 7. 设计决策

| # | 问题 | 决策 | 依据 |
|---|---|---|---|
| D1 | 项目同名冲突 | **完整路径 MD5 前 8 位做 key**，如 `7verse-ug@a3f2e1b9` | 避免冲突，同时保留可读前缀 |
| D2 | 记忆冲突（新决策推翻旧决策）| **Append-only + 时间戳**，最新条目用 `★ CURRENT` 标记置顶；旧条目保留但加 `~~strikethrough~~` + 推翻原因注释 | 审计可追溯，MemGPT memory_replace 思路 |
| D3 | Core 膨胀（超 200 行）| **Claude Code 模式**：超阈值时 Agent 自动把 topic 详情迁移到 L3 文件，Core 只保留索引指针 | Anthropic 官方实践：200 行后模型遵循率下降 |
| D4 | Skill 是否 `disable-model-invocation` | **否**，自动触发 | 核心价值在"每轮强制索引"，手动调用会失去意义 |
| D5 | 隐私（sessions/ 含敏感数据）| **强制 .gitignore** + Agent 不写入密钥 + `/memory-scrub` 命令清理 | Claude Code `.claude/agent-memory-local/` 设计模式 |
| D6 | 索引层数 | **两层**（全局 INDEX + 项目 INDEX），不做 RAPTOR 完整树 | 项目规模小，collapsed tree 足够 |
| D7 | 索引更新时机 | **同步更新**：写 L3 文件必须同步更新 INDEX.md 对应条目；用 Git-like 原子操作（写临时文件 + rename） | 避免 INDEX 与实际文件不一致 |
| D8 | 记忆存储路径 | **独立 `~/.cursor/session-memory/memory/`**，可通过 `MEMORY_ROOT` 环境变量覆盖 | 完全自治，不依赖任何外部目录 |
