# ══════════════════════════════════════════════════════════════
# OpenClaw 清理与配置脚本 (Windows) - 增强版
# 功能：清除记忆数据 + 保留 TG 配置 + 配置代理 + 阿里云百炼模型
# 编码：UTF-8 with BOM (Windows PowerShell 兼容)
# ══════════════════════════════════════════════════════════════
#Requires -Version 5.1
$ErrorActionPreference = "Stop"

# 确保 UTF-8 输出
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Banner {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  🦞 OpenClaw 清理与配置脚本 (增强版)             ║" -ForegroundColor Cyan
    Write-Host "║   清除记忆 + 保留 TG + 配置代理 + 阿里云百炼     ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Log   { param($msg) Write-Host "✅ $msg" -ForegroundColor Green }
function Warn  { param($msg) Write-Host "⚠️  $msg" -ForegroundColor Yellow }
function Error { param($msg) Write-Host "❌ $msg" -ForegroundColor Red }
function Info  { param($msg) Write-Host "ℹ️  $msg" -ForegroundColor Blue }

# ── Step 0: 检查 OpenClaw 是否安装 ──
function Check-OpenClaw {
    Info "检查 OpenClaw 安装状态..."
    
    $oc = Get-Command openclaw -ErrorAction SilentlyContinue
    if (-not $oc) {
        Error "未找到 openclaw CLI。请先安装 OpenClaw。"
        exit 1
    }
    Log "OpenClaw CLI: OK ($($oc.Source))"
}

# ── Step 0.5: 配置代理 ──
function Configure-Proxy {
    Info "配置代理环境..."
    Write-Host ""
    
    # 检测系统代理
    $systemProxy = [System.Net.WebRequest]::DefaultWebProxy
    $proxyAddress = $null
    $proxyPort = $null
    
    try {
        # 尝试从注册表读取 IE/系统代理
        $proxyServer = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyServer" -ErrorAction SilentlyContinue
        if ($proxyServer -and $proxyServer.ProxyServer) {
            $proxyParts = $proxyServer.ProxyServer -split ":"
            if ($proxyParts.Count -ge 2) {
                $proxyAddress = $proxyParts[0]
                $proxyPort = $proxyParts[1]
                Info "检测到系统代理：$proxyAddress`:$proxyPort"
            }
        }
    } catch {
        Info "无法自动检测系统代理"
    }
    
    Write-Host ""
    Write-Host "══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  🌐 代理配置" -ForegroundColor Cyan
    Write-Host "══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    if ($proxyAddress -and $proxyPort) {
        Info "已检测到系统代理：$proxyAddress`:$proxyPort"
        $useSystemProxy = Read-Host "是否使用系统代理？(y/n)"
        
        if ($useSystemProxy -eq "y" -or $useSystemProxy -eq "Y" -or [string]::IsNullOrEmpty($useSystemProxy)) {
            # 设置环境变量
            $env:HTTP_PROXY = "http://$proxyAddress`:$proxyPort"
            $env:HTTPS_PROXY = "http://$proxyAddress`:$proxyPort"
            $env:NO_PROXY = "localhost,127.0.0.1"
            
            # 设置 Git 代理
            git config --global http.proxy "http://$proxyAddress`:$proxyPort" 2>$null
            git config --global https.proxy "http://$proxyAddress`:$proxyPort" 2>$null
            
            Log "系统代理已配置"
            Log "HTTP_PROXY: $env:HTTP_PROXY"
            Log "HTTPS_PROXY: $env:HTTPS_PROXY"
            return
        }
    }
    
    # 手动输入代理
    Write-Host ""
    Info "请输入代理服务器地址（如果不需要代理，直接回车跳过）"
    $proxyInput = Read-Host "代理地址 (例：127.0.0.1)"
    
    if (-not [string]::IsNullOrEmpty($proxyInput)) {
        $proxyPortInput = Read-Host "代理端口 (例：7890)"
        
        if (-not [string]::IsNullOrEmpty($proxyPortInput)) {
            # 设置环境变量
            $env:HTTP_PROXY = "http://$proxyInput`:$proxyPortInput"
            $env:HTTPS_PROXY = "http://$proxyInput`:$proxyPortInput"
            $env:NO_PROXY = "localhost,127.0.0.1"
            
            # 设置 Git 代理
            git config --global http.proxy "http://$proxyInput`:$proxyPortInput" 2>$null
            git config --global https.proxy "http://$proxyInput`:$proxyPortInput" 2>$null
            
            Log "代理已配置"
            Log "HTTP_PROXY: $env:HTTP_PROXY"
            Log "HTTPS_PROXY: $env:HTTPS_PROXY"
        }
    } else {
        Info "跳过代理配置"
    }
    
    Write-Host ""
}

# ── Step 1: 停止 Gateway ──
function Stop-Gateway {
    Info "停止 OpenClaw Gateway..."
    
    # 查找并终止所有 openclaw 相关进程
    $processes = Get-Process | Where-Object { $_.ProcessName -like "*node*" -or $_.ProcessName -like "*openclaw*" }
    if ($processes) {
        $processes | ForEach-Object {
            Info "终止进程：$($_.ProcessName) (PID: $($_.Id))"
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds 2
        Log "Gateway 已停止"
    } else {
        Info "未发现运行中的 Gateway 进程"
    }
}

# ── Step 2: 备份 TG 配置 ──
function Backup-TG-Config {
    Info "备份 Telegram 配置..."
    
    $ocHome = Join-Path $env:USERPROFILE ".openclaw"
    $configFile = Join-Path $ocHome "openclaw.json"
    $backupFile = Join-Path $ocHome "openclaw.json.tg.backup"
    
    if (Test-Path $configFile) {
        # 读取配置
        $config = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
        
        # 检查是否有 Telegram 配置
        $hasTelegram = $false
        $tgConfig = @{}
        
        if ($config.channels -and $config.channels.telegram) {
            $hasTelegram = $true
            $tgConfig.telegram = $config.channels.telegram
            Info "检测到 Telegram 渠道配置"
        }
        
        if ($config.deliveryContext -and $config.deliveryContext.telegram) {
            $tgConfig.deliveryContext = $config.deliveryContext.telegram
            Info "检测到 Telegram 投递上下文配置"
        }
        
        if ($hasTelegram) {
            # 保存备份
            $tgConfig | ConvertTo-Json -Depth 10 | Set-Content $backupFile -Encoding UTF8
            Log "Telegram 配置已备份到：$backupFile"
            Info "⚠️  此备份文件在安装完成后需要恢复"
        } else {
            Info "未检测到 Telegram 配置"
        }
    }
    
    Write-Host ""
}

# ── Step 3: 清除记忆数据（保留 TG 配置） ──
function Clear-Memory {
    Info "清除 OpenClaw 记忆数据（保留 Telegram 配置）..."
    
    $ocHome = Join-Path $env:USERPROFILE ".openclaw"
    
    # 清除 MEMORY.md
    $memoryMd = Join-Path $ocHome "MEMORY.md"
    if (Test-Path $memoryMd) {
        Info "删除：MEMORY.md"
        Remove-Item -Path $memoryMd -Force
        Log "已删除：MEMORY.md"
    } else {
        Info "MEMORY.md 不存在 (跳过)"
    }
    
    # 清除 memory 目录
    $memoryDir = Join-Path $ocHome "memory"
    if (Test-Path $memoryDir) {
        Info "删除：memory/ 目录"
        Remove-Item -Path $memoryDir -Recurse -Force
        Log "已删除：memory/"
    } else {
        Info "memory/ 不存在 (跳过)"
    }
    
    # 清除 HEARTBEAT.md 内容（保留文件）
    $heartbeatMd = Join-Path $ocHome "HEARTBEAT.md"
    if (Test-Path $heartbeatMd) {
        Info "清空：HEARTBEAT.md"
        Set-Content -Path $heartbeatMd -Value "" -Encoding UTF8
        Log "已清空：HEARTBEAT.md"
    }
    
    # 清除会话历史（保留 main agent）
    $sessionsDir = Join-Path $ocHome "agents"
    if (Test-Path $sessionsDir) {
        Info "扫描会话目录..."
        $agentDirs = Get-ChildItem -Path $sessionsDir -Directory | Where-Object { $_.Name -ne "main" }
        foreach ($agentDir in $agentDirs) {
            $sessionFiles = Get-ChildItem -Path $agentDir.FullName -Filter "*.jsonl" -ErrorAction SilentlyContinue
            foreach ($file in $sessionFiles) {
                if ($file.Name -notlike "*main*") {
                    Info "删除会话：$($file.Name)"
                    Remove-Item -Path $file.FullName -Force
                }
            }
        }
        Log "会话历史已清理（保留 main agent）"
    }
    
    # ⚠️ 不清除 openclaw.json（保留所有配置包括 TG）
    Info "保留：openclaw.json (包含 Telegram Token 和 UserID)"
    
    Write-Host ""
}

# ── Step 4: 配置阿里云百炼模型 ──
function Configure-Model {
    Info "配置阿里云百炼模型..."
    
    # 设置默认模型
    Info "设置默认模型：阿里云百炼/qwen3.5-plus"
    openclaw config set model.default "阿里云百炼/qwen3.5-plus" 2>&1 | ForEach-Object { Write-Host "  $_" }
    Log "默认模型已设置"
    
    # 设置当前会话模型
    Info "设置当前会话模型：阿里云百炼/qwen3.5-plus"
    openclaw config set model "阿里云百炼/qwen3.5-plus" 2>&1 | ForEach-Object { Write-Host "  $_" }
    Log "当前会话模型已设置"
    
    Write-Host ""
}

# ── Step 5: 打开推理开关 ──
function Enable-Reasoning {
    Info "配置推理设置..."
    
    # 打开推理开关
    Info "打开推理开关"
    openclaw config set thinking.enabled true 2>&1 | ForEach-Object { Write-Host "  $_" }
    Log "推理开关：已打开"
    
    # 设置推理等级为 High
    Info "设置推理等级：High"
    openclaw config set thinking.level "high" 2>&1 | ForEach-Object { Write-Host "  $_" }
    Log "推理等级：High"
    
    # 设置推理模式
    Info "设置推理模式：enabled"
    openclaw config set thinking.mode "enabled" 2>&1 | ForEach-Object { Write-Host "  $_" }
    Log "推理模式：已启用"
    
    Write-Host ""
}

# ── Step 6: 恢复 TG 配置 ──
function Restore-TG-Config {
    Info "检查 Telegram 配置..."
    
    $ocHome = Join-Path $env:USERPROFILE ".openclaw"
    $backupFile = Join-Path $ocHome "openclaw.json.tg.backup"
    
    if (Test-Path $backupFile) {
        Info "Telegram 配置备份存在，无需额外操作"
        Info "openclaw.json 已保留原始配置（包含 TG Token 和 UserID）"
        Log "Telegram 配置：已保留"
    } else {
        Info "未找到 Telegram 配置备份（可能之前未配置）"
    }
    
    Write-Host ""
}

# ── Step 7: 验证配置 ──
function Verify-Config {
    Info "验证配置..."
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  📋 配置验证结果                                  ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # 检查模型配置
    Write-Host "【模型配置】" -ForegroundColor Yellow
    Info "当前默认模型："
    openclaw config get model.default 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    
    Write-Host ""
    Info "当前会话模型："
    openclaw config get model 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    
    Write-Host ""
    Write-Host "【推理设置】" -ForegroundColor Yellow
    Info "推理配置："
    openclaw config get thinking 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    
    Write-Host ""
    Write-Host "【Telegram 配置】" -ForegroundColor Yellow
    $ocHome = Join-Path $env:USERPROFILE ".openclaw"
    $configFile = Join-Path $ocHome "openclaw.json"
    if (Test-Path $configFile) {
        $config = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($config.channels -and $config.channels.telegram) {
            Log "Telegram 渠道配置：存在"
        } else {
            Warn "Telegram 渠道配置：未找到"
        }
    }
    
    Write-Host ""
    Log "配置验证完成！"
    Write-Host ""
}

# ── Step 8: 重启 Gateway ──
function Restart-Gateway {
    Info "重启 OpenClaw Gateway..."
    
    # 使用 openclaw 命令重启
    openclaw gateway restart 2>&1 | ForEach-Object { Write-Host "  $_" }
    
    Start-Sleep -Seconds 5
    Log "Gateway 已重启"
    
    Write-Host ""
}

# ══════════════════════════════════════════════════════════════
# 主程序
# ══════════════════════════════════════════════════════════════

Write-Banner

Warn "⚠️  警告：此脚本将清除 OpenClaw 的记忆数据！"
Warn "⚠️  但会保留以下配置："
Warn "    - Telegram Bot Token 和 UserID"
Warn "    - openclaw.json 中的所有配置"
Warn "⚠️  其他记忆数据将被清除，此操作不可逆。"
Write-Host ""
$confirm = Read-Host "是否继续？(输入 yes 确认)"

if ($confirm -ne "yes") {
    Info "操作已取消"
    exit 0
}

Write-Host ""
Info "开始执行清理与配置..."
Write-Host ""

try {
    Check-OpenClaw
    Configure-Proxy
    Stop-Gateway
    Backup-TG-Config
    Clear-Memory
    Configure-Model
    Enable-Reasoning
    Restore-TG-Config
    Verify-Config
    Restart-Gateway
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║  ✅ OpenClaw 清理与配置完成！                     ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Info "📋 下一步：运行三省六部安装脚本"
    Info "命令：cd <edict 目录> && powershell -ExecutionPolicy Bypass -File .\install.ps1"
    Write-Host ""
    Info "🎉 配置完成！现在可以安装三省六部了！"
    Write-Host ""
    
} catch {
    Error "发生错误：$($_.Exception.Message)"
    Write-Host ""
    Error "错误详情：$($_.ScriptStackTrace)"
    exit 1
}
