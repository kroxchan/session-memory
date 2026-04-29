# Session Memory

> Cursor Agent 的项目级持久化记忆系统。防止长对话中信息丢失，支持跨窗口和 `/clear` 后恢复上下文。

Session Memory 让 Cursor Agent 在每个工作目录下拥有持久化的"记忆"——技术决策、需求约束、项目约定、历史讨论摘要——全都不依赖对话窗口，下次打开依然在。

基于 **INDEX → CORE → DETAIL** 三级索引，灵感来自 RAPTOR（ICLR 2024）和 HippoRAG（NeurIPS 2024），但采用纯 Markdown + 文件系统实现，无需 embedding 或向量数据库。

---

## 快速链接

| 想做什么 | 往哪走 |
|---------|--------|
| **安装 + 首次使用** | [docs/getting-started.md](docs/getting-started.md) |
| **了解工作原理** | [docs/how-it-works.md](docs/how-it-works.md) |
| **查看所有命令** | [docs/commands.md](docs/commands.md) |
| **理解存储结构** | [docs/storage.md](docs/storage.md) |
| **理论依据 + 设计决策** | [docs/design-rationale.md](docs/design-rationale.md) |
| **排查问题** | [docs/troubleshooting.md](docs/troubleshooting.md) |

---

## 一图读懂

```
用户打开项目 A（如 /Users/vivx/cursor/7verse-ug）
        │
        ▼
  sm-project-key.sh
  → 计算 project_key = 7verse-ug@a3f2e1b9
        │
        ▼
  读取 projects/7verse-ug@a3f2e1b9/
  ├── INDEX.md   ← 强制（每轮必读，极低 token）
  └── CORE.md    ← 自动进入 Agent 上下文
        │
        ▼ 视任务需要下钻
  decisions.md / requirements.md / facts/*.md
        │
        ▼
  Agent 带着项目记忆回答问题
  识别到关键信息时自动写入记忆
```

---

## 核心特性

| 特性 | 说明 |
|------|------|
| **项目级隔离** | 每个 workspace 独立记忆，切换项目不串内容 |
| **跨窗口持久化** | `/clear` 和新窗口后记忆仍在 |
| **三级索引** | INDEX（极轻）→ CORE（关键）→ DETAIL（按需）|
| **自动写入** | Agent 识别到决策/需求时自动写，无需用户提醒 |
| **冲突可追溯** | 新决策 append + `★ CURRENT` 标记，旧条目保留历史 |
| **隐私安全** | 记忆目录默认 `.gitignore`，不存密钥和 PII |
| **零依赖** | 纯 Bash + Markdown，不引入 Python 环境或向量数据库 |

---

## 快速安装

```bash
bash install.sh
```

重启 Cursor 即可生效。详见 [docs/getting-started.md](docs/getting-started.md)。

---

## 文件结构

```
session-memory-skill/
├── README.md                     # 本文件
├── install.sh                    # 一键安装脚本
├── docs/                         # 文档
│   ├── getting-started.md
│   ├── how-it-works.md
│   ├── commands.md
│   ├── storage.md
│   ├── design-rationale.md
│   └── troubleshooting.md
└── skill/                        # Cursor Skill 入口
    ├── SKILL.md
    ├── scripts/
    │   ├── sm-project-key.sh    # basename@md5(path)[:8]
    │   ├── sm-bootstrap.sh      # 会话启动初始化
    │   ├── sm-write.sh          # 原子写入 + INDEX 同步
    │   ├── sm-recall.sh         # 关键词检索
    │   ├── sm-compress.sh       # 长会话摘要压缩
    │   └── sm-status.sh         # 查看记忆状态
    └── references/
        └── templates/            # 新项目骨架模板
            ├── INDEX.md.tpl
            ├── CORE.md.tpl
            ├── global-INDEX.md.tpl
            └── global-CORE.md.tpl
```

---

## 理论依据

| 论文 | 年份 | 启发点 |
|------|------|--------|
| [MemGPT / Letta](https://arxiv.org/abs/2310.08560) | 2023 | OS 分层记忆模型（RAM / Cache / Disk）|
| [RAPTOR](https://arxiv.org/abs/2401.18059) | ICLR 2024 | collapsed tree 扁平索引优于递归下钻 |
| [HippoRAG](https://arxiv.org/abs/2405.14831) | NeurIPS 2024 | 索引与内容分离，稀疏索引优于 dense embedding |
| [Lost in the Middle](https://arxiv.org/abs/2307.03172) | Liu et al. | primacy/recency bias，关键信息放首尾 |
| Claude Code 最佳实践 | Anthropic | 60/200 行限制，50% context 压缩 |

详见 [docs/design-rationale.md](docs/design-rationale.md)。

---

Made by [@kroxchan](https://github.com/kroxchan)
