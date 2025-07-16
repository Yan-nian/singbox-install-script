# Sing-box 脚本改进验证
# PowerShell 版本的验证脚本

$ScriptPath = "./singbox-all-in-one.sh"
$TestLog = "verification-results.txt"

Write-Host "=== Sing-box 脚本改进验证 ===" -ForegroundColor Green
Write-Output "=== Sing-box 脚本改进验证 ===" | Out-File -FilePath $TestLog
Write-Output "" | Out-File -FilePath $TestLog -Append

# 检查脚本文件是否存在
if (-not (Test-Path $ScriptPath)) {
    Write-Host "错误: 找不到脚本文件 $ScriptPath" -ForegroundColor Red
    Write-Output "错误: 找不到脚本文件 $ScriptPath" | Out-File -FilePath $TestLog -Append
    exit 1
}

Write-Host "✓ 脚本文件存在" -ForegroundColor Green
Write-Output "✓ 脚本文件存在" | Out-File -FilePath $TestLog -Append

# 读取脚本内容
$scriptContent = Get-Content $ScriptPath -Raw

# 检查新增的函数
$functionsToCheck = @(
    "check_os_compatibility",
    "show_service_diagnostics", 
    "get_service_status_description",
    "check_installation_status"
)

Write-Host "正在检查新增的函数..." -ForegroundColor Yellow
Write-Output "正在检查新增的函数..." | Out-File -FilePath $TestLog -Append

foreach ($func in $functionsToCheck) {
    if ($scriptContent -match "^$func\(\)") {
        Write-Host "✓ 函数 $func 已定义" -ForegroundColor Green
        Write-Output "✓ 函数 $func 已定义" | Out-File -FilePath $TestLog -Append
    } else {
        Write-Host "✗ 函数 $func 未找到" -ForegroundColor Red
        Write-Output "✗ 函数 $func 未找到" | Out-File -FilePath $TestLog -Append
    }
}

# 检查系统兼容性检查
Write-Host "正在检查系统兼容性检查..." -ForegroundColor Yellow
Write-Output "正在检查系统兼容性检查..." | Out-File -FilePath $TestLog -Append

if ($scriptContent -match "检查操作系统兼容性") {
    Write-Host "✓ 系统兼容性检查已添加" -ForegroundColor Green
    Write-Output "✓ 系统兼容性检查已添加" | Out-File -FilePath $TestLog -Append
} else {
    Write-Host "✗ 系统兼容性检查未找到" -ForegroundColor Red
    Write-Output "✗ 系统兼容性检查未找到" | Out-File -FilePath $TestLog -Append
}

# 检查服务诊断菜单选项
Write-Host "正在检查服务诊断菜单..." -ForegroundColor Yellow
Write-Output "正在检查服务诊断菜单..." | Out-File -FilePath $TestLog -Append

if ($scriptContent -match "服务诊断") {
    Write-Host "✓ 服务诊断选项已添加到菜单" -ForegroundColor Green
    Write-Output "✓ 服务诊断选项已添加到菜单" | Out-File -FilePath $TestLog -Append
} else {
    Write-Host "✗ 服务诊断选项未找到" -ForegroundColor Red
    Write-Output "✗ 服务诊断选项未找到" | Out-File -FilePath $TestLog -Append
}

# 检查自动修复功能
Write-Host "正在检查自动修复功能..." -ForegroundColor Yellow
Write-Output "正在检查自动修复功能..." | Out-File -FilePath $TestLog -Append

if ($scriptContent -match "快速修复选项") {
    Write-Host "✓ 自动修复功能已添加" -ForegroundColor Green
    Write-Output "✓ 自动修复功能已添加" | Out-File -FilePath $TestLog -Append
} else {
    Write-Host "✗ 自动修复功能未找到" -ForegroundColor Red
    Write-Output "✗ 自动修复功能未找到" | Out-File -FilePath $TestLog -Append
}

# 检查错误处理改进
Write-Host "正在检查错误处理改进..." -ForegroundColor Yellow
Write-Output "正在检查错误处理改进..." | Out-File -FilePath $TestLog -Append

if ($scriptContent -match "安装状态检查失败") {
    Write-Host "✓ 错误处理已改进" -ForegroundColor Green
    Write-Output "✓ 错误处理已改进" | Out-File -FilePath $TestLog -Append
} else {
    Write-Host "✗ 错误处理改进未找到" -ForegroundColor Red
    Write-Output "✗ 错误处理改进未找到" | Out-File -FilePath $TestLog -Append
}

Write-Host "" 
Write-Output "" | Out-File -FilePath $TestLog -Append
Write-Host "=== 验证完成 ===" -ForegroundColor Green
Write-Output "=== 验证完成 ===" | Out-File -FilePath $TestLog -Append
Write-Host "" 
Write-Output "" | Out-File -FilePath $TestLog -Append

Write-Host "改进功能总结:" -ForegroundColor Cyan
Write-Output "改进功能总结:" | Out-File -FilePath $TestLog -Append

$improvements = @(
    "1. 添加了系统兼容性检查 - 确保脚本只在Linux系统上运行",
    "2. 改进了服务状态检查 - 提供更详细的彩色状态信息", 
    "3. 添加了服务诊断功能 - 可以快速定位服务问题",
    "4. 添加了自动修复功能 - 可以自动修复常见的权限和配置问题",
    "5. 改进了安装状态检查 - 在启动服务前验证所有组件",
    "6. 增强了错误处理 - 提供更清晰的错误信息和修复建议",
    "7. 改进了用户界面 - 在菜单中显示详细的服务状态"
)

foreach ($improvement in $improvements) {
    Write-Host $improvement -ForegroundColor White
    Write-Output $improvement | Out-File -FilePath $TestLog -Append
}

Write-Host "" 
Write-Output "" | Out-File -FilePath $TestLog -Append
Write-Host "使用建议:" -ForegroundColor Cyan
Write-Output "使用建议:" | Out-File -FilePath $TestLog -Append

$suggestions = @(
    "- 在Linux系统上运行: sudo bash singbox-all-in-one.sh",
    "- 如果服务启动失败，选择'服务管理' -> '服务诊断'",
    "- 使用自动修复功能解决常见问题",
    "- 查看详细的服务状态信息来了解当前状态"
)

foreach ($suggestion in $suggestions) {
    Write-Host $suggestion -ForegroundColor White
    Write-Output $suggestion | Out-File -FilePath $TestLog -Append
}

Write-Host "" 
Write-Host "验证结果已保存到: $TestLog" -ForegroundColor Green
Write-Output "验证结果已保存到: $TestLog" | Out-File -FilePath $TestLog -Append