# Sing-box 快捷启动脚本 for Windows PowerShell
# 版本: v1.0.0

param(
    [string[]]$Arguments
)

# 获取脚本所在目录
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$MainScript = Join-Path $ScriptDir "singbox-install.sh"

# 检查主脚本是否存在
if (-not (Test-Path $MainScript)) {
    Write-Host "错误: 找不到 singbox-install.sh 脚本" -ForegroundColor Red
    Write-Host "请确保 sb.ps1 与 singbox-install.sh 在同一目录下" -ForegroundColor Yellow
    Read-Host "按任意键退出"
    exit 1
}

# 检查 bash 环境
$bashPath = $null
try {
    $bashPath = Get-Command bash -ErrorAction Stop
    Write-Host "使用 bash 执行脚本..." -ForegroundColor Green
    
    # 构建参数字符串
    $argString = if ($Arguments) { $Arguments -join " " } else { "" }
    
    # 执行脚本
    if ($argString) {
        & bash $MainScript $Arguments
    } else {
        & bash $MainScript
    }
} catch {
    Write-Host "错误: 未找到 bash 环境" -ForegroundColor Red
    Write-Host ""
    Write-Host "请安装以下任一环境:" -ForegroundColor Yellow
    Write-Host "1. Git for Windows (推荐)" -ForegroundColor Cyan
    Write-Host "2. Windows Subsystem for Linux (WSL)" -ForegroundColor Cyan
    Write-Host "3. Cygwin" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "下载链接:" -ForegroundColor Yellow
    Write-Host "Git for Windows: https://git-scm.com/download/win" -ForegroundColor Blue
    Write-Host "WSL 安装指南: https://docs.microsoft.com/zh-cn/windows/wsl/install" -ForegroundColor Blue
    Write-Host ""
    Read-Host "按任意键退出"
    exit 1
}