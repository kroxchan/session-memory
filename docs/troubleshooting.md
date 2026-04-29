# 常见问题

> 遇到问题先来这里看看。

---

## 安装问题

### Q: 报错 "rsync not found"

不影响安装。脚本会自动回退到 `cp -R`。

### Q: Cursor 没有显示 session-memory Skill

1. 确认安装成功：
   ```bash
   ls ~/.cursor/skills/session-memory/
   ```
2. 重启 Cursor（必须）
3. 确认有 `SKILL.md`：
   ```bash
   cat ~/.cursor/skills/session-memory/SKILL.md | head -5
   ```

---

## 记忆不工作问题

### Q: Agent 似乎没有读记忆

按以下顺序排查：

1. **检查 project key 是否正确**：
   ```bash
   cd /你的/项目/目录
   bash ~/.cursor/skills/session-memory/scripts/sm-project-key.sh "$(pwd)"
   ```

2. **检查记忆目录是否存在**：
   ```bash
   ls -la ~/.cursor/session-memory/memory/sessions/projects/
   ```

3. **检查 INDEX.md 是否为空**：
   新建项目的 INDEX 初始为空是正常的——Session Memory 是**按需写入**的。

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

简单任务（修 typo、简单提问）故意不读取 L3 文件以节省 token。如果确实应该读取但没读，可以：
1. 在项目 `CORE.md` 里手动写入关键约束
2. 用 `[STICKY]` 标记重要条目

### Q: 跨项目记忆串了

不同项目有不同 key，不会串内容。如果发现同一项目有多个 key（移动过目录或从不同路径打开），可以合并两个目录的内容后删除多余目录。

---

## 隐私与安全

### Q: 误写了敏感信息怎么办

使用 `/memory-scrub` 命令清理：

```
/memory-scrub "sk-.*"
```

### Q: 记忆数据有多大

```bash
du -sh ~/.cursor/session-memory/memory/
```

### Q: 记忆能被其他人看到吗

只要 `~/.cursor/session-memory/memory/` 目录不在 git 追踪范围内就不会。安装脚本已生成自带的 `.gitignore`，但如果你把它复制到 git 仓库里，记得确认该目录已被忽略。

---

## 性能问题

### Q: 每轮读 INDEX 会让回答变慢吗

不会。读两个 INDEX 文件约 200-400 tokens，毫秒级 IO，与 LLM 推理时间相比可以忽略。

如果发现明显变慢，检查 INDEX.md 是否超过大小限制（项目级 50 行，全局级 30 行）：

```bash
wc -l ~/.cursor/session-memory/memory/sessions/projects/<key>/INDEX.md
```

---

## 高级用法

### Q: 可以手动编辑记忆文件吗

可以。但注意：
- **不要直接用 Write 工具写 INDEX.md**——跳过 `sm-write.sh` 会导致 INDEX 与内容不同步
- **用 Write 直接写 L3 文件可以**，但记得用 `sm-write.sh` 更新 INDEX 条目
- **手动编辑 CORE.md** 是安全的，只要不超过 200 行

### Q: 能把记忆迁移到新电脑吗

可以。只需复制整个记忆目录：

```bash
# 旧电脑
tar -czf memory.tar.gz ~/.cursor/session-memory/memory/

# 新电脑
tar -xzf memory.tar.gz -C ~/.cursor/session-memory/
```

### Q: 能和团队共享项目记忆吗

目前不支持。记忆目录是单用户本地存储，不支持多人协作。如有需求，可以把 `CORE.md` 和 `decisions.md` 手动复制到项目代码仓库的 `docs/` 目录作为团队共享文档。
