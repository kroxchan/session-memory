# 常见问题

> 遇到问题先来这里看看。

---

## 安装问题

### Q: 报错 "rsync not found"

不影响安装。脚本会自动回退到 `cp -R`，功能完全相同。

### Q: Cursor 没有显示 session-memory Skill

1. 确认安装成功：
   ```bash
   ls ~/.cursor/skills/session-memory/
   ```
2. 重启 Cursor（必须）
3. 确认 skill 目录下有 `SKILL.md`：
   ```bash
   cat ~/.cursor/skills/session-memory/SKILL.md | head -5
   ```

### Q: 安装后 Skill 出现在 Rules 里而不是 Skills 里

正常。`session-memory` 既有 SKILL.md（Skill 入口），又有对应的 `.cursor/rules/session-memory.mdc`（Rule 约束）。两者同时生效，Rule 负责让 Agent 强制执行每轮协议。

---

## 记忆不工作问题

### Q: Agent 似乎没有读记忆

按以下顺序排查：

1. **检查 project key 是否正确**：
   ```bash
   cd /你的/项目/目录
   bash ~/.cursor/skills/session-memory/scripts/sm-project-key.sh "$(pwd)"
   ```
   如果输出为空，说明路径计算失败。

2. **检查记忆目录是否存在**：
   ```bash
   ls -la /Users/vivx/cursor/digital-human/skills/SKILLFORGE/memory/sessions/projects/
   ```

3. **检查 INDEX.md 是否为空（常见原因）**：
   如果是新建项目，Agent 还没有写入任何记忆，所以 INDEX 是空模板。这是正常的——Session Memory 是**按需写入**的，不是自动扫描。

4. **手动测试写入**：
   ```
   /remember 测试：我是一个虚拟人物，我叫小明
   ```
   然后：
   ```
   我叫什么名字？
   ```
   如果 Agent 回答"小明"，说明记忆功能正常。

### Q: 记忆写入了但 Agent 回答时没有用到

检查是否满足下钻条件（见 [docs/how-it-works.md](how-it-works.md) §Step 4）。对于简单任务（修 typo、简单提问），Agent 故意不读取 L3 文件以节省 token。

如果确实应该读取但没读，说明 Agent 对规则的遵循率问题，可以尝试：
1. 在项目 `CORE.md` 里手动写入关键约束
2. 用 `[STICKY]` 标记重要条目

### Q: 跨项目记忆串了

检查 project key 是否正确。不同项目有不同 key，不会串内容。

如果发现同一项目有多个 key（因为移动过目录或从不同路径打开），可以合并：

1. 确认两个 key 的记忆内容
2. 将一个目录的内容合并到另一个
3. 删除多余目录

---

## 隐私与安全

### Q: 误写了敏感信息怎么办

立即使用 `/memory-scrub` 命令：

```
/memory-scrub "sk-.*"
```

这会用正则匹配所有记忆文件中的内容并删除。删除前 Agent 会显示将被删除的内容供确认。

### Q: 记忆数据有多大

```bash
bash ~/.cursor/skills/session-memory/scripts/sm-status.sh <project_key>
```

或手动查看：

```bash
du -sh /Users/vivx/cursor/digital-human/skills/SKILLFORGE/memory/sessions/
```

### Q: 记忆能被其他人看到吗

如果你把项目代码 push 到 GitHub，只要 `memory/sessions/` 没有被 `.gitignore` 忽略，就有可能泄露。**安装脚本已自动添加 `.gitignore`**，但如果你手动删除了，可以重新添加：

```bash
echo 'memory/sessions/' >> /Users/vivx/cursor/digital-human/skills/SKILLFORGE/.gitignore
```

---

## 性能问题

### Q: 每轮读 INDEX 会让回答变慢吗

不会。读两个 INDEX 文件约 200-400 tokens，毫秒级 IO，与 LLM 推理时间相比可以忽略。

如果发现明显变慢，可能是 INDEX.md 超过了大小限制（项目级 50 行，全局级 30 行）。检查并拆分：

```bash
wc -l /Users/vivx/cursor/digital-human/skills/SKILLFORGE/memory/sessions/projects/<key>/INDEX.md
```

### Q: 记忆文件太多了怎么办

用压缩命令清理：

```bash
/memory-compress
```

这会将长会话摘要写入 `sessions/YYYY-MM-DD-*.md`，并更新 INDEX。

---

## 高级用法

### Q: 可以手动编辑记忆文件吗

可以。Markdown 文件直接可读可写。但注意：

- **不要直接用 Write 工具写 INDEX.md**——跳过 `sm-write.sh` 会导致 INDEX 与内容不同步
- **用 Write 直接写 L3 文件可以**，但记得之后用 `sm-write.sh` 更新 INDEX 条目
- **手动编辑 CORE.md** 是安全的，只要不超过 200 行

### Q: 能把记忆迁移到新电脑吗

可以。只需复制整个 `memory/sessions/` 目录：

```bash
# 旧电脑
tar -czf sessions.tar.gz /Users/vivx/cursor/digital-human/skills/SKILLFORGE/memory/sessions/

# 新电脑
tar -xzf sessions.tar.gz -C /Users/vivx/cursor/digital-human/skills/SKILLFORGE/memory/
```

### Q: 能和团队共享项目记忆吗

目前不支持。`memory/sessions/` 是单用户本地存储，不支持多人协作。如有需求，可以把项目级 `CORE.md` 和 `decisions.md` 手动复制到项目代码仓库的 `docs/` 目录，作为团队共享文档。
