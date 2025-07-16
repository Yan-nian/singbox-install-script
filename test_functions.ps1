# PowerShell 测试脚本 - 验证关键函数修复

Write-Host "=== 模块加载修复验证 ===" -ForegroundColor Cyan
Write-Host "测试目标: 验证 singbox-install.sh 中的关键函数定义" -ForegroundColor Cyan
Write-Host ""

# 检查 singbox-install.sh 文件
$scriptPath = "./singbox-install.sh"
if (Test-Path $scriptPath) {
    Write-Host "[OK] 找到 singbox-install.sh 文件" -ForegroundColor Green
} else {
    Write-Host "[ERROR] 未找到 singbox-install.sh 文件" -ForegroundColor Red
    exit 1
}

# 读取文件内容
$content = Get-Content $scriptPath -Raw

# 检查关键函数是否存在
$functions = @(
    "define_essential_functions",
    "verify_module_functions", 
    "auto_repair_modules",
    "diagnose_module_issues",
    "log_debug",
    "log_info", 
    "log_warn",
    "log_error",
    "validate_uuid",
    "validate_port"
)

Write-Host "检查关键函数定义:" -ForegroundColor Yellow
foreach ($func in $functions) {
    if ($content -match "$func\s*\(\)") {
        Write-Host "  [OK] $func" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] $func" -ForegroundColor Red
    }
}

Write-Host ""

# 检查模块加载逻辑改进
Write-Host "检查模块加载逻辑改进:" -ForegroundColor Yellow

$improvements = @{
    "本地模块优先" = "使用本地模块目录"
    "下载失败处理" = "download_failed.*true"
    "函数验证" = "verify_module_functions"
    "自动修复" = "auto_repair_modules"
    "诊断功能" = "diagnose_module_issues"
}

foreach ($improvement in $improvements.GetEnumerator()) {
    if ($content -match $improvement.Value) {
        Write-Host "  [OK] $($improvement.Key)" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] $($improvement.Key)" -ForegroundColor Red
    }
}

Write-Host ""

# 检查 UUID 正则表达式
Write-Host "检查 UUID 验证正则表达式:" -ForegroundColor Yellow
if ($content -match "0-9a-fA-F.*8.*-.*4.*-.*4.*-.*4.*-.*12") {
    Write-Host "  [OK] UUID 正则表达式正确" -ForegroundColor Green
} else {
    Write-Host "  [MISSING] UUID 正则表达式缺失或错误" -ForegroundColor Red
}

# 检查端口验证逻辑
Write-Host "检查端口验证逻辑:" -ForegroundColor Yellow
if ($content -match "port.*-ge 1.*-le 65535") {
    Write-Host "  [OK] 端口范围验证正确" -ForegroundColor Green
} else {
    Write-Host "  [MISSING] 端口范围验证缺失或错误" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== 验证完成 ===" -ForegroundColor Green
Write-Host "如果所有项目都显示 [OK]，说明修复成功" -ForegroundColor Cyan

# 显示文件大小变化
$fileSize = (Get-Item $scriptPath).Length
Write-Host "文件大小: $fileSize 字节" -ForegroundColor Yellow

# 统计新增行数
$lines = (Get-Content $scriptPath).Count
Write-Host "总行数: $lines 行" -ForegroundColor Yellow