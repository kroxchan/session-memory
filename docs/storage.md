# 存储结构

> 记忆数据放在哪里、如何组织。

---

## 存储根目录

```
$MEMORY_ROOT/sessions/
```

默认值（与 SkillForge 共用根目录）：

```
/Users/vivx/cursor/digital-human/skills/SKILLFORGE/memory/sessions/
```

可通过环境变量 `MEMORY_ROOT` 覆盖。

---

## 完整目录树

```
$MEMORY_ROOT/
└── sessions/
    ├── _global/                        # 全局记忆（跨所有项目）
    │   ├── INDEX.md                   # L1 · ≤30 行 · 每轮强制读
    │   ├── CORE.md                   # L2 · ≤60 行 · 个人偏好/通用约定
    │   └── facts/                    # L3 · 专题知识
    │       └── tech-stack.md          # 我的常用工具栈
    │
    └── projects/                      # 按项目隔离
        ├── 7verse-ug@a3f2e1b9/      # 项目名@md5前8位
        │   ├── INDEX.md              # L1 · ≤50 行 · 每轮强制读
        │   ├── CORE.md              # L2 · ≤200 行 · 项目约束+当前目标
        │   ├── requirements.md      # L3 · 明确的需求
        │   ├── decisions.md         # L3 · 技术决策
        │   ├── facts/              # L3 · 专题知识
        │   │   ├── api-conventions.md
        │   │   └── auth-flow.md
        │   └── sessions/           # L3 · 历史会话摘要
        │       ├── 2026-04-23-linktree-api.md
        │       └── 2026-04-22-auth-refactor.md
        │
        ├── seedance-character-pipeline@c0b64168/
        │   └── ...
        │
        └── another-project@1a2b3c4d/
            └── ...
```

---

## 三级索引说明

### L1 — INDEX.md（始终强制读取）

扁平索引，**只含路径和摘要，不含正文**。

格式规范：
- 每个文件一行：`- <相对路径> — <≤30字摘要>`
- 项目级 INDEX ≤50 行，全局 INDEX ≤30 行
- 超过必须按类别拆分成多个文件

示例：

```markdown
# 7verse-ug@a3f2e1b9 Memory Index

> Workspace: `/Users/vivx/cursor/7verse-ug`

## CORE（自动加载）
- CORE.md — 项目约束和当前目标

## 需求 & 决策（按需）
- requirements.md — 用户明确提出的需求
- decisions.md — 关键技术决策

## 专题知识（按需）
- facts/api-conventions.md — REST API 路由/错误码规范
- facts/auth-flow.md — 鉴权流程和 middleware 设计

## 历史会话（按需）
- sessions/2026-04-23-linktree-api.md — linktree API 设计讨论
- sessions/2026-04-22-auth-refactor.md — admin auth middleware 重构
```

### L2 — CORE.md（始终在上下文中）

项目的核心记忆，包含**不得违反的约束和当前目标**。

格式规范：
- 项目级 CORE ≤200 行，全局 CORE ≤60 行
- 用 `[STICKY]` 标记关键约束（每 10 轮在对话末尾重放一次）
- 正文按 section 组织，每个 section 最多 20 行

示例：

```markdown
# 7verse-ug@a3f2e1b9 — CORE

> Always in context.

## Current Goal
<!-- 当前正在做什么 -->

## Non-negotiable Constraints [STICKY]
<!-- 永远不能违反的规则 -->

## Project Conventions
<!-- 技术栈、命名、测试规范 -->

## Open Questions
<!-- 未解决的设计问题 -->
```

### L3 — 详情文件（按需读取）

正文内容，按需加载。Agent 根据 INDEX 的指向决定是否读取。

---

## 索引与内容分离的好处

| 好处 | 说明 |
|------|------|
| **INDEX 极轻** | 50 行 ≈ 1000 tokens，每次都读不心疼 |
| **INDEX 是索引** | 告诉 Agent"哪里有什么"，而不是"什么是什么" |
| **内容是详情** | 只有命中时才加载，不浪费 context |
| **人类可读** | 直接 `cat` 或在 Cursor 里打开即可查看 |
| **可版本化** | Markdown 文件天然支持 git diff |
| **无依赖** | 不需要 embedding 模型、向量数据库 |

---

## 为什么用 project key 而不是项目名做目录名

直接用项目名（如 `7verse-ug/`）的问题是：**不同路径可能重名**。

```
~/projects/7verse-ug/       → 7verse-ug
~/work/client-7verse-ug/    → 7verse-ug ❌ 冲突！
```

用 `basename@md5前8位`（如 `7verse-ug@a3f2e1b9`）保证唯一性，同时保留可读前缀方便人类识别。

MD5 计算时取**完整绝对路径**，确保不同位置的同名目录也被区分。

---

## 与 SkillForge 的目录关系

```
/Users/vivx/cursor/digital-human/skills/SKILLFORGE/
├── memory/
│   ├── capability-index.yaml   ← SkillForge L0 索引
│   ├── reflections.md           ← SkillForge L2 反思
│   ├── timings.yaml             ← SkillForge 执行时间
│   ├── self-made/               ← SkillForge Forger 草稿
│   ├── trajectories/            ← SkillForge 执行轨迹
│   └── sessions/               ← Session Memory（本文档）
│       ├── _global/
│       └── projects/
└── .gitignore                   ← sessions/ 已被忽略
```

**Session Memory 只操作 `sessions/` 子目录**，不碰 SkillForge 的其他文件。
