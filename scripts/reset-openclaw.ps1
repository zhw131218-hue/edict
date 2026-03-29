# ══════════════════════════════════════════════════════════════
# OpenClaw 清理与配置脚本 (Windows)
# 功能：清除记忆数据 + 配置阿里云百炼模型 + 打开推理开关
# ══════════════════════════════════════════════════════════════
#Requires -Version 5.1
$ErrorActionPreference = "Stop"

function Write-Banner {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  🦞 OpenClaw 清理与配置脚本              ║" -ForegroundColor Cyan
    Write-Host "║   清除记忆 + 配置阿里云百炼 + 推理 High   ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Cyan
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

# ── Step 2: 清除记忆数据 ──
function Clear-Memory {
    Info "清除 OpenClaw 记忆数据..."
    
    $ocHome = Join-Path $env:USERPROFILE ".openclaw"
    $memoryFiles = @(
        "MEMORY.md",
        "memory"
    )
    
    foreach ($item in $memoryFiles) {
        $path = Join-Path $ocHome $item
        if (Test-Path $path) {
            Info "删除：$path"
            if (Test-Path $path -PathType Container) {
                Remove-Item -Path $path -Recurse -Force
            } else {
                Remove-Item -Path $path -Force
            }
            Log "已删除：$item"
        } else {
            Info "不存在：$item (跳过)"
        }
    }
    
    # 清除会话历史（可选，谨慎操作）
    $sessionsDir = Join-Path $ocHome "agents"
    if (Test-Path $sessionsDir) {
        Info "扫描会话目录..."
        $agentDirs = Get-ChildItem -Path $sessionsDir -Directory | Where-Object { $_.Name -ne "main" }
        foreach ($agentDir in $agentDirs) {
            $sessionFiles = Get-ChildItem -Path $agentDir.FullName -Filter "*.jsonl" -ErrorAction SilentlyContinue
            foreach ($file in $sessionFiles) {
                if ($file.Name -notlike "*main*") {
                    Info "删除会话：$($file.FullName)"
                    Remove-Item -Path $file.FullName -Force
                }
            }
        }
        Log "会话历史已清理（保留 main agent）"
    }
}

# ── Step 3: 配置阿里云百炼模型 ──
function Configure-Model {
    Info "配置阿里云百炼模型..."
    
    # 设置默认模型
    Info "设置默认模型：阿里云百炼/qwen3.5-plus"
    openclaw config set model.default "阿里云百炼/qwen3.5-plus"
    Log "默认模型已设置"
    
    # 设置当前会话模型
    Info "设置当前会话模型：阿里云百炼/qwen3.5-plus"
    openclaw config set model "阿里云百炼/qwen3.5-plus"
    Log "当前会话模型已设置"
}

# ── Step 4: 打开推理开关 ──
function Enable-Reasoning {
    Info "配置推理设置..."
    
    # 打开推理开关
    Info "打开推理开关"
    openclaw config set thinking.enabled true
    Log "推理开关：已打开"
    
    # 设置推理等级为 High
    Info "设置推理等级：High"
    openclaw config set thinking.level "high"
    Log "推理等级：High"
    
    # 设置推理模式（如果支持）
    Info "设置推理模式：enabled"
    openclaw config set thinking.mode "enabled"
    Log "推理模式：已启用"
}

# ── Step 5: 验证配置 ──
function Verify-Config {
    Info "验证配置..."
    Write-Host ""
    Write-Host "══════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  📋 配置验证结果" -ForegroundColor Cyan
    Write-Host "══════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # 检查模型配置
    Info "当前默认模型："
    openclaw config get model.default 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    
    Write-Host ""
    Info "当前会话模型："
    openclaw config get model 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    
    Write-Host ""
    Info "推理设置："
    openclaw config get thinking 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    
    Write-Host ""
    Log "配置验证完成！"
}

# ── Step 6: 重启 Gateway ──
function Restart-Gateway {
    Info "重启 OpenClaw Gateway..."
    
    # 使用 openclaw 命令重启
    openclaw gateway restart 2>&1 | ForEach-Object { Write-Host "  $_" }
    
    Start-Sleep -Seconds 5
    Log "Gateway 已重启"
}

# ══════════════════════════════════════════════════════════════
# 主程序
# ══════════════════════════════════════════════════════════════

Write-Banner

Warn "⚠️  警告：此脚本将清除 OpenClaw 的记忆数据！"
Warn "⚠️  此操作不可逆，请确认你已备份重要数据。"
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
    Stop-Gateway
    Clear-Memory
    Configure-Model
    Enable-Reasoning
    Verify-Config
    Restart-Gateway
    
    Write-Host ""
    Write-Host "══════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  ✅ OpenClaw 清理与配置完成！" -ForegroundColor Green
    Write-Host "══════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Info "下一步：运行三省六部安装脚本"
    Info "命令：cd <edict 目录> && powershell -ExecutionPolicy Bypass -File .\install.ps1"
    Write-Host ""
    
} catch {
    Error "发生错误：$($_.Exception.Message)"
    exit 1
}
