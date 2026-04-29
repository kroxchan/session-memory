# 理论依据与设计决策

> 为什么 Session Memory 这样设计，以及每个关键决策背后的原因。

---

## 理论依据

Session Memory 的设计融合了 4 篇论文的核心思想，以及 Claude Code 官方工程实践。

---

### Lost in the Middle（Liu et al., 2023）

> *Liu, N. F., et al. "Lost in the Middle: How Language Models Use Long Contexts." TACL 2024. arXiv:2307.03172*

**核心发现**：LLM 对长上下文的记忆呈 U 型曲线——开头（primacy bias）和结尾（recency bias）记忆最强，中间最弱。长度越长衰减越严重。

**对 Session Memory 的影响**：

| 发现 | 我们的对策 |
|------|---------|
| primacy bias | `CORE.md` 在会话启动时注入到对话开头 |
| recency bias | `[STICKY]` 约束每 10 轮在对话末尾重放一次 |
| 中间衰减最严重 | 50% context 时压缩会话，不依赖中间段的记忆 |

---

### MemGPT / Letta（Packer et al., 2023）

> *Packer, C., et al. "MemGPT: Towards LLMs as Operating Systems." arXiv:2310.08560*

**核心思想**：LLM 应像操作系统一样管理记忆——分层存储、按需调度、自我编辑。

**三层映射**：

| MemGPT 层级 | 类比 | Session Memory 对应 |
|------------|------|-------------------|
| Core Memory（RAM，始终在 context）| 热数据 | `CORE.md`（项目约束、当前目标）|
| Recall Memory（Cache，按需检索）| 温数据 | `sessions/*.md`（历史对话摘要）|
| Archival Memory（Disk，持久知识）| 冷数据 | `facts/*.md`、`decisions.md` |

---

### RAPTOR（Sarthi et al., ICLR 2024）

> *Sarthi, P., et al. "RAPTOR: Recursive Abstractive Processing for Tree-Organized Retrieval." ICLR 2024. arXiv:2401.18059*

**核心发现**：对长文档构建 collapsed tree（扁平化一次匹配）比 tree traversal（逐层下钻）在 QuALITY 基准上效果更好，且实现更简单。

**对 Session Memory 的影响**：

- 不用 embedding 聚类 + 递归索引——用文件系统目录做天然的两层抽象
- `INDEX.md` 就是 collapsed tree，一次读完即知全局
- 细节在 L3 文件里，按需读取

---

### HippoRAG（Gutiérrez et al., NeurIPS 2024）

> *Gutiérrez, B. J., et al. "HippoRAG: Neurobiologically Inspired Long-Term Memory for LLMs." NeurIPS 2024. arXiv:2405.14831*

**核心发现**：海马体索引理论——索引与内容分离，用稀疏索引实现单步多跳检索，比迭代检索快 6-13 倍、便宜 10-30 倍。

**对 Session Memory 的影响**：

- `INDEX.md` = 稀疏索引（只存标题+摘要+路径，不含正文）
- L3 文件 = 内容存储
- Agent 先查索引，再按路径读取内容——两跳完成，不重复扫描

---

### Claude Code 工程实践（Anthropic）

- **200 行限制**：超过 200 行的上下文指令模型遵循率急剧下降
- **50% context 压缩**：不等 70% 才做，提前压缩避免进入"dumb zone"
- **渐进式披露**：主文件只放索引和核心规则，详情放子文件按需加载

---

## 设计决策

| # | 问题 | 决策 | 依据 |
|---|------|------|------|
| D1 | 项目同名冲突 | **完整路径 MD5 前 8 位做 key**，如 `7verse-ug@a3f2e1b9` | 避免冲突，同时保留可读前缀 |
| D2 | 记忆冲突（推翻旧决策）| **Append-only + `★ CURRENT` 标记**；旧条目保留但加 `~~删除线~~` + 原因注释 | 审计可追溯，MemGPT memory_replace 思路 |
| D3 | CORE 膨胀（超 200 行）| **Agent 自动迁移** topic 详情到 `facts/<topic>.md`，CORE 只留指针 | Anthropic 官方：200 行后遵循率下降 |
| D4 | Skill 是否 `disable-model-invocation` | **否**，自动触发 | 核心价值在"每轮强制索引"，手动调用失去意义 |
| D5 | 隐私（sessions/ 含敏感数据）| **强制 .gitignore** + Agent 不写入密钥 + `/memory-scrub` 命令 | Claude Code `.claude/agent-memory-local/` 模式 |
| D6 | 索引层数 | **两层**（全局 INDEX + 项目 INDEX），不做 RAPTOR 完整树 | 项目规模小，collapsed tree 足够 |
| D7 | 索引更新时机 | **同步更新**：`sm-write.sh` 原子写 tmp + rename，同时更新 INDEX 条目 | 避免 INDEX 与实际文件不一致 |
| D8 | 为什么不用 embedding | **纯 `rg` 关键词搜索**：单用户 IDE 场景，<1000 条记忆，`rg` 毫秒级，无需向量 DB | PRD §4.2 |
| D9 | 为什么用 Markdown 而非 YAML/JSON | **人类可读可改**、天然容纳自由格式、支持 git diff | PRD §4.3 |

---

## 为什么不用 embedding / 向量数据库

| 对比维度 | embedding 向量方案 | Session Memory（当前方案）|
|---------|-----------------|------------------------|
| 部署成本 | 需要 embedding 模型或 API + 向量 DB | 零额外依赖 |
| 写入成本 | 每次写入需要重新 embedding | 纯文件追加，O(1) |
| 检索延迟 | 毫秒级（ANN 索引）| 毫秒级（`rg` 搜索）|
| 人类可读 | ❌ 数值向量无法直接查看 | ✅ 直接 `cat` 查看 |
| 冲突处理 | 难以追踪 | `★ CURRENT` + `~~删除线~~` |
| 适用规模 | 亿级文档 | <1000 条记忆（本场景）|

结论：embedding 的优势在亿级文档才显现，我们的场景（单用户、单项目、<1000 条记忆）用文件系统 + 关键词搜索已经绑绑有余。

---

## 为什么与 SkillForge 共用 memory/ 目录

| 方案 | 优点 | 缺点 |
|------|------|------|
| 共用 memory/（当前）| 一次安装，两套记忆系统都可用 | 需要隔离 `sessions/` 子目录 |
| 独立 memory/ | 完全隔离 | 两套系统记忆割裂，用户体验碎片化 |
| 集成到 SkillForge | 单一系统 | SkillForge 是任务校准系统，与项目级记忆职责不同 |

**当前方案最优**：两个系统职责正交（SkillForge = Agent 能力校准，Session Memory = 项目知识），共用根目录但隔离子目录，零冲突。
