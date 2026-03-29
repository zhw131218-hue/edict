# OpenClaw Reset and Configuration Script (Windows)
# Function: Clear memory + Keep TG config + Configure proxy + Aliyun model
# Encoding: UTF-8 with BOM

#Requires -Version 5.1
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Banner {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "  OpenClaw Reset & Config Script" -ForegroundColor Cyan
    Write-Host "  Clear Memory + Keep TG + Aliyun Model" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Log   { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Warn  { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Error { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }
function Info  { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Blue }

function Check-OpenClaw {
    Info "Checking OpenClaw installation..."
    $oc = Get-Command openclaw -ErrorAction SilentlyContinue
    if (-not $oc) {
        Error "openclaw CLI not found. Please install OpenClaw first."
        exit 1
    }
    Log "OpenClaw CLI: OK"
}

function Configure-Proxy {
    Info "Configuring proxy..."
    Write-Host ""
    
    # Try to detect system proxy
    $proxyAddress = $null
    $proxyPort = $null
    
    try {
        $proxyServer = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyServer" -ErrorAction SilentlyContinue
        if ($proxyServer -and $proxyServer.ProxyServer) {
            $proxyParts = $proxyServer.ProxyServer -split ":"
            if ($proxyParts.Count -ge 2) {
                $proxyAddress = $proxyParts[0]
                $proxyPort = $proxyParts[1]
                Info "Detected system proxy: $proxyAddress`:$proxyPort"
            }
        }
    } catch {
        Info "Cannot auto-detect system proxy"
    }
    
    Write-Host ""
    Write-Host "=== Proxy Configuration ===" -ForegroundColor Cyan
    Write-Host ""
    
    if ($proxyAddress -and $proxyPort) {
        Info "System proxy detected: $proxyAddress`:$proxyPort"
        $useSystemProxy = Read-Host "Use system proxy? (y/n)"
        
        if ($useSystemProxy -eq "y" -or $useSystemProxy -eq "Y" -or [string]::IsNullOrEmpty($useSystemProxy)) {
            $env:HTTP_PROXY = "http://$proxyAddress`:$proxyPort"
            $env:HTTPS_PROXY = "http://$proxyAddress`:$proxyPort"
            $env:NO_PROXY = "localhost,127.0.0.1"
            
            git config --global http.proxy "http://$proxyAddress`:$proxyPort" 2>$null
            git config --global https.proxy "http://$proxyAddress`:$proxyPort" 2>$null
            
            Log "System proxy configured"
            Log "HTTP_PROXY: $env:HTTP_PROXY"
            Log "HTTPS_PROXY: $env:HTTPS_PROXY"
            return
        }
    }
    
    Write-Host ""
    Info "Enter proxy address (press Enter to skip)"
    $proxyInput = Read-Host "Proxy address (e.g., 127.0.0.1)"
    
    if (-not [string]::IsNullOrEmpty($proxyInput)) {
        $proxyPortInput = Read-Host "Proxy port (e.g., 7890)"
        
        if (-not [string]::IsNullOrEmpty($proxyPortInput)) {
            $env:HTTP_PROXY = "http://$proxyInput`:$proxyPortInput"
            $env:HTTPS_PROXY = "http://$proxyInput`:$proxyPortInput"
            $env:NO_PROXY = "localhost,127.0.0.1"
            
            git config --global http.proxy "http://$proxyInput`:$proxyPortInput" 2>$null
            git config --global https.proxy "http://$proxyInput`:$proxyPortInput" 2>$null
            
            Log "Proxy configured"
            Log "HTTP_PROXY: $env:HTTP_PROXY"
            Log "HTTPS_PROXY: $env:HTTPS_PROXY"
        }
    } else {
        Info "Skip proxy configuration"
    }
    
    Write-Host ""
}

function Stop-Gateway {
    Info "Stopping OpenClaw Gateway..."
    
    $processes = Get-Process | Where-Object { $_.ProcessName -like "*node*" -or $_.ProcessName -like "*openclaw*" }
    if ($processes) {
        $processes | ForEach-Object {
            Info "Stopping process: $($_.ProcessName) (PID: $($_.Id))"
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds 2
        Log "Gateway stopped"
    } else {
        Info "No running Gateway process found"
    }
}

function Backup-TG-Config {
    Info "Backing up Telegram configuration..."
    
    $ocHome = Join-Path $env:USERPROFILE ".openclaw"
    $configFile = Join-Path $ocHome "openclaw.json"
    $backupFile = Join-Path $ocHome "openclaw.json.tg.backup"
    
    if (Test-Path $configFile) {
        $config = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
        
        $hasTelegram = $false
        $tgConfig = @{}
        
        if ($config.channels -and $config.channels.telegram) {
            $hasTelegram = $true
            $tgConfig.telegram = $config.channels.telegram
            Info "Telegram channel config detected"
        }
        
        if ($config.deliveryContext -and $config.deliveryContext.telegram) {
            $tgConfig.deliveryContext = $config.deliveryContext.telegram
            Info "Telegram delivery context detected"
        }
        
        if ($hasTelegram) {
            $tgConfig | ConvertTo-Json -Depth 10 | Set-Content $backupFile -Encoding UTF8
            Log "Telegram config backed up to: $backupFile"
        } else {
            Info "No Telegram config detected"
        }
    }
    
    Write-Host ""
}

function Clear-Memory {
    Info "Clearing OpenClaw memory (keeping Telegram config)..."
    
    $ocHome = Join-Path $env:USERPROFILE ".openclaw"
    
    # Clear MEMORY.md
    $memoryMd = Join-Path $ocHome "MEMORY.md"
    if (Test-Path $memoryMd) {
        Info "Deleting: MEMORY.md"
        Remove-Item -Path $memoryMd -Force
        Log "Deleted: MEMORY.md"
    } else {
        Info "MEMORY.md not found (skip)"
    }
    
    # Clear memory directory
    $memoryDir = Join-Path $ocHome "memory"
    if (Test-Path $memoryDir) {
        Info "Deleting: memory/ directory"
        Remove-Item -Path $memoryDir -Recurse -Force
        Log "Deleted: memory/"
    } else {
        Info "memory/ not found (skip)"
    }
    
    # Clear HEARTBEAT.md content
    $heartbeatMd = Join-Path $ocHome "HEARTBEAT.md"
    if (Test-Path $heartbeatMd) {
        Info "Clearing: HEARTBEAT.md"
        Set-Content -Path $heartbeatMd -Value "" -Encoding UTF8
        Log "Cleared: HEARTBEAT.md"
    }
    
    # Clear session history (keep main agent)
    $sessionsDir = Join-Path $ocHome "agents"
    if (Test-Path $sessionsDir) {
        Info "Scanning session directory..."
        $agentDirs = Get-ChildItem -Path $sessionsDir -Directory | Where-Object { $_.Name -ne "main" }
        foreach ($agentDir in $agentDirs) {
            $sessionFiles = Get-ChildItem -Path $agentDir.FullName -Filter "*.jsonl" -ErrorAction SilentlyContinue
            foreach ($file in $sessionFiles) {
                if ($file.Name -notlike "*main*") {
                    Info "Deleting session: $($file.Name)"
                    Remove-Item -Path $file.FullName -Force
                }
            }
        }
        Log "Session history cleared (main agent kept)"
    }
    
    # Keep openclaw.json (with TG config)
    Info "Keeping: openclaw.json (includes Telegram Token and UserID)"
    
    Write-Host ""
}

function Configure-Model {
    Info "Configuring Aliyun Bailian model..."
    
    Info "Setting default model: Aliyun Bailian/qwen3.5-plus"
    openclaw config set models.default "Aliyun Bailian/qwen3.5-plus" 2>&1 | ForEach-Object { Write-Host "  $_" }
    Log "Default model set"
    
    Info "Setting current session model: Aliyun Bailian/qwen3.5-plus"
    openclaw config set models.current "Aliyun Bailian/qwen3.5-plus" 2>&1 | ForEach-Object { Write-Host "  $_" }
    Log "Current session model set"
    
    Write-Host ""
}

function Enable-Reasoning {
    Info "Configuring reasoning settings..."
    
    Info "Enabling reasoning"
    openclaw config set thinking.enabled true 2>&1 | ForEach-Object { Write-Host "  $_" }
    Log "Reasoning: enabled"
    
    Info "Setting reasoning level: high"
    openclaw config set thinking.level "high" 2>&1 | ForEach-Object { Write-Host "  $_" }
    Log "Reasoning level: high"
    
    Info "Setting reasoning mode: enabled"
    openclaw config set thinking.mode "enabled" 2>&1 | ForEach-Object { Write-Host "  $_" }
    Log "Reasoning mode: enabled"
    
    Write-Host ""
}

function Restore-TG-Config {
    Info "Checking Telegram configuration..."
    
    $ocHome = Join-Path $env:USERPROFILE ".openclaw"
    $backupFile = Join-Path $ocHome "openclaw.json.tg.backup"
    
    if (Test-Path $backupFile) {
        Info "Telegram config backup exists, no extra action needed"
        Info "openclaw.json kept original config (includes TG Token and UserID)"
        Log "Telegram config: kept"
    } else {
        Info "No Telegram config backup found"
    }
    
    Write-Host ""
}

function Verify-Config {
    Info "Verifying configuration..."
    Write-Host ""
    Write-Host "=== Configuration Verification ===" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "[Model Config]" -ForegroundColor Yellow
    Info "Default model:"
    openclaw config get models.default 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    
    Write-Host ""
    Info "Current session model:"
    openclaw config get models.current 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    
    Write-Host ""
    Write-Host "[Reasoning Settings]" -ForegroundColor Yellow
    Info "Reasoning config:"
    openclaw config get thinking 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    
    Write-Host ""
    Write-Host "[Telegram Config]" -ForegroundColor Yellow
    $ocHome = Join-Path $env:USERPROFILE ".openclaw"
    $configFile = Join-Path $ocHome "openclaw.json"
    if (Test-Path $configFile) {
        $config = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($config.channels -and $config.channels.telegram) {
            Log "Telegram channel config: exists"
        } else {
            Warn "Telegram channel config: not found"
        }
    }
    
    Write-Host ""
    Log "Configuration verification complete!"
    Write-Host ""
}

function Restart-Gateway {
    Info "Restarting OpenClaw Gateway..."
    
    openclaw gateway restart 2>&1 | ForEach-Object { Write-Host "  $_" }
    
    Start-Sleep -Seconds 5
    Log "Gateway restarted"
    
    Write-Host ""
}

# Main Program
Write-Banner

Warn "WARNING: This script will clear OpenClaw memory data!"
Warn "But will KEEP the following:"
Warn "  - Telegram Bot Token and UserID"
Warn "  - All configs in openclaw.json"
Warn "Other memory data will be cleared. This action is irreversible."
Write-Host ""
$confirm = Read-Host "Continue? (type yes to confirm)"

if ($confirm -ne "yes") {
    Info "Operation cancelled"
    exit 0
}

Write-Host ""
Info "Starting reset and configuration..."
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
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "  OpenClaw Reset & Config Complete!" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host ""
    Info "Next step: Run Edict installation script"
    Info "Command: cd <edict directory> && powershell -ExecutionPolicy Bypass -File .\install.ps1"
    Write-Host ""
    Info "Configuration complete! Ready to install Edict!"
    Write-Host ""
    
} catch {
    Error "Error occurred: $($_.Exception.Message)"
    Write-Host ""
    Error "Error details: $($_.ScriptStackTrace)"
    exit 1
}
