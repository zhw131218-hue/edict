# Windows 部署完整指南

> 适用于 Windows 10/11，包含 OpenClaw 清理、模型配置、代理设置、三省六部安装

---

## 📋 部署流程总览

```
第 1 步：下载清理脚本
    ↓
第 2 步：运行清理脚本（清除记忆 + 配置代理 + 配置模型 + 保留 TG）
    ↓
第 3 步：验证配置
    ↓
第 4 步：安装三省六部
    ↓
第 5 步：启动服务
    ↓
第 6 步：测试验证
```

---

## 📝 详细操作步骤

### 【第 1 步】下载清理脚本

**打开 Windows PowerShell（管理员）**，执行以下命令：

```powershell
# 1. 进入 OpenClaw workspace 目录
cd C:\Users\$env:USERNAME\.openclaw\workspace\skills

# 2. 克隆或更新 edict 项目
# 如果还没克隆：
git clone https://github.com/zhw131218-hue/edict.git

# 如果已克隆，更新到最新：
cd edict
git pull origin main

# 3. 进入 scripts 目录
cd scripts
```

---

### 【第 2 步】运行清理与配置脚本

```powershell
# 运行清理脚本
powershell -ExecutionPolicy Bypass -File .\reset-openclaw.ps1
```

**脚本会提示确认：**
```
⚠️  警告：此脚本将清除 OpenClaw 的记忆数据！
⚠️  但会保留以下配置：
    - Telegram Bot Token 和 UserID
    - openclaw.json 中的所有配置
⚠️  其他记忆数据将被清除，此操作不可逆。

是否继续？(输入 yes 确认)
```

**输入 `yes` 并回车**

---

### 【第 2.5 步】代理配置（交互式）

**脚本会自动检测系统代理：**

```
══════════════════════════════════════════════════
  🌐 代理配置
══════════════════════════════════════════════════

ℹ️  检测到系统代理：127.0.0.1:7890
是否使用系统代理？(y/n)
```

**选项 A：使用系统代理**
- 输入 `y` 或直接回车

**选项 B：手动输入代理**
- 如果没检测到系统代理，会提示手动输入
- 输入代理地址（如：`127.0.0.1`）
- 输入代理端口（如：`7890`）

**选项 C：不使用代理**
- 直接回车跳过

---

### 【第 3 步】验证配置

脚本会自动显示配置验证结果：

```
╔══════════════════════════════════════════════════╗
║  📋 配置验证结果                                  ║
╚══════════════════════════════════════════════════╝

【模型配置】
ℹ️  当前默认模型：
  阿里云百炼/qwen3.5-plus

ℹ️  当前会话模型：
  阿里云百炼/qwen3.5-plus

【推理设置】
ℹ️  推理配置：
  thinking.enabled: true
  thinking.level: high
  thinking.mode: enabled

【Telegram 配置】
ℹ️  Telegram 渠道配置：存在
✅ Telegram 渠道配置：存在

✅ 配置验证完成！
```

---

### 【第 4 步】安装三省六部

```powershell
# 1. 进入 edict 根目录
cd C:\Users\$env:USERNAME\.openclaw\workspace\skills\edict

# 2. 运行安装脚本
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

**安装过程会显示：**
```
╔══════════════════════════════════════════════════╗
║  🏛️  三省六部 · OpenClaw Multi-Agent             ║
║       安装向导 (Windows)                          ║
╚══════════════════════════════════════════════════╝

✅ 检查依赖...
✅ OpenClaw CLI: OK
✅ Python: OK
✅ openclaw.json: OK
✅ 创建 Agent Workspace...
✅ 配置已写入 openclaw.json
✅ 安装完成！
```

---

### 【第 5 步】启动服务

**需要打开两个终端窗口：**

#### 窗口 A：启动后台刷新循环（Git Bash）

```bash
# 打开 Git Bash（不是 PowerShell！）
cd ~/.openclaw/workspace/skills/edict/scripts
bash run_loop.sh
```

**会显示：**
```
[INFO] Starting refresh loop...
[INFO] Refreshing live data...
[INFO] Next refresh in 60 seconds...
```

**⚠️ 保持这个窗口运行，不要关闭！**

#### 窗口 B：启动 Dashboard（PowerShell）

```powershell
# 打开新的 PowerShell 窗口
cd C:\Users\$env:USERNAME\.openclaw\workspace\skills\edict
python dashboard\server.py
```

**会显示：**
```
 * Serving Flask app 'server'
 * Debug mode: off
 * Running on http://127.0.0.1:7891
Press CTRL+C to quit
```

---

### 【第 6 步】测试验证

**1. 打开浏览器访问 Dashboard：**
```
http://127.0.0.1:7891
```

**2. 检查看板是否正常显示**
- 应该能看到任务看板
- 应该能看到各部状态

**3. 测试太子 Agent（在 Telegram）：**
```
你好，测试三省六部系统
```

**4. 创建测试任务：**
```
创建一个任务：测试 edict 系统，派发给中书省
```

---

## 🔧 常见问题解决

### Q1: Git Bash 在哪里下载？

**下载地址：** https://git-scm.com/download/win

安装后，在开始菜单找到 "Git Bash" 启动。

---

### Q2: 脚本运行报错 "无法加载文件"

**解决方法：**
```powershell
# 以管理员身份运行 PowerShell，执行：
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

### Q3: 代理配置后仍然无法访问 GitHub

**解决方法：**
```powershell
# 手动设置 Git 代理
git config --global http.proxy http://127.0.0.1:7890
git config --global https.proxy http://127.0.0.1:7890

# 验证代理
git config --global --get http.proxy
```

---

### Q4: Telegram 配置丢失了怎么办？

**解决方法：**
```powershell
# 检查备份文件
$backup = "$env:USERPROFILE\.openclaw\openclaw.json.tg.backup"
if (Test-Path $backup) {
    Get-Content $backup
}

# 如果备份存在，手动恢复配置到 openclaw.json
```

---

### Q5: 模型配置后仍然显示其他模型

**解决方法：**
```powershell
# 强制重置模型
openclaw config set model.default "阿里云百炼/qwen3.5-plus"
openclaw config set model "阿里云百炼/qwen3.5-plus"
openclaw gateway restart
```

---

## 📊 配置检查清单

完成部署后，检查以下项目：

| 检查项 | 验证方法 | 预期结果 |
|--------|----------|----------|
| **模型配置** | `openclaw config get model.default` | 阿里云百炼/qwen3.5-plus |
| **推理开关** | `openclaw config get thinking` | enabled, high |
| **Telegram** | 发送消息给 Bot | Bot 正常回复 |
| **代理配置** | `git clone https://github.com` | 快速克隆 |
| **三省六部** | 访问 http://127.0.0.1:7891 | Dashboard 正常显示 |
| **后台刷新** | 检查 Git Bash 窗口 | run_loop.sh 运行中 |

---

## 🎯 下一步：配置 wx4py（微信自动化）

完成三省六部安装后，如需配置微信自动化：

```powershell
# 1. 安装 wx4py
pip install wx4py

# 2. 安装 wx4py skill
openclaw skills install https://raw.githubusercontent.com/claw-codes/wx4py/main/wx4-skill/SKILL.md

# 3. 启用技能
openclaw config set skills.entries.wx4py.enabled true

# 4. 重启 Gateway
openclaw gateway restart
```

---

## 📞 技术支持

如遇问题，请提供以下信息：

1. Windows 版本
2. PowerShell 版本（`$PSVersionTable.PSVersion`）
3. OpenClaw 版本（`openclaw --version`）
4. Python 版本（`python --version`）
5. 错误日志截图

---

**最后更新**: 2026-03-29  
**版本**: v1.0
