# 快速上手

> 从零安装到第一次看到效果，10 分钟完成。

---

## 系统要求

- **Cursor**（任意版本，支持 Rules 和 Skills）
- **macOS / Linux**（Windows 支持理论上有，需调整路径）
- **Bash 4+**（`sm-project-key.sh` 依赖 `md5sum`，macOS 用 `md5`）
- 网络（首次安装需克隆仓库）

---

## 安装步骤

### 第一步：克隆仓库（如果还没有）

```bash
cd ~/cursor  # 或你存放 skills 的目录
git clone https://github.com/kroxchan/session-memory.git
```

### 第二步：运行安装脚本

```bash
cd session-memory
bash install.sh
```

安装脚本会做以下事情：

1. **复制 skill 目录** → `~/.cursor/skills/session-memory/`（Cursor Skills 扫描路径）
2. **创建记忆存储根目录** → `$MEMORY_ROOT/sessions/`（默认在 SkillForge 的 memory 下）
3. **初始化全局记忆目录** → `_global/`（INDEX.md + CORE.md 模板）
4. **添加 .gitignore** → 在 SkillForge 根目录加入 `memory/sessions/` 忽略规则
5. **Smoke test** → 运行 `sm-project-key.sh` 验证路径计算正确

成功输出示例：

```
✓ copied ./skill → ~/.cursor/skills/session-memory
✓ scripts made executable
✓ memory root: /Users/vivx/cursor/digital-human/skills/SKILLFORGE/memory/sessions/
✓ added memory/sessions/ to /Users/vivx/cursor/digital-human/skills/SKILLFORGE/.gitignore
=== smoke test ===
7verse-ug@a3f2e1b9
Install complete. Restart Cursor to load the skill.
```

### 第三步：重启 Cursor

重启 Cursor IDE，使 Skill 在 Rules 面板中可见。

---

## 验证是否生效

打开 Cursor，选一个项目目录（如下 `/Users/vivx/cursor/7verse-ug`），对 Agent 说：

```
你好，记住这个项目的目标是做一个 linktree crawler。
```

然后对 Agent 说：

```
我们的技术选型是什么？
```

如果 Agent 能正确回答，说明记忆已经写入并被读取。

---

## 卸载

```bash
bash install.sh --uninstall
```

**注意**：这只会移除 Skill 本身，**不会**删除记忆数据。如需清除所有记忆：

```bash
rm -rf /Users/vivx/cursor/digital-human/skills/SKILLFORGE/memory/sessions/
```

---

## 安装常见问题

### Q: 报错 "rsync not found"

不影响安装，脚本会回退到 `cp -R`。

### Q: Cursor 没有显示 Skill

确保安装脚本输出的 `~/.cursor/skills/session-memory` 存在。也可以手动检查：

```bash
ls ~/.cursor/skills/session-memory/
```

### Q: 记忆没有持久化

检查 `MEMORY_ROOT` 目录是否存在且有写入权限：

```bash
ls -la /Users/vivx/cursor/digital-human/skills/SKILLFORGE/memory/sessions/
```

### Q: 想指定其他记忆存储路径

在运行安装脚本前设置环境变量：

```bash
export MEMORY_ROOT=/你的/自定义/路径
bash install.sh
```
