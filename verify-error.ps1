# 简单验证脚本
Write-Host "检查第306行内容..."

$lines = Get-Content singbox-all-in-one.sh
$line306 = $lines[305]
Write-Host "第306行: '$line306'"
Write-Host "字符数: $($line306.Length)"

# 检查字节表示
$bytes = [System.Text.Encoding]::UTF8.GetBytes($line306)
Write-Host "字节表示: $($bytes | ForEach-Object { '{0:X2}' -f $_ })"

# 检查行结束符
$content = Get-Content singbox-all-in-one.sh -Raw
if ($content.Contains("`r`n")) {
    Write-Host "文件使用Windows行结束符 (CRLF)"
} elseif ($content.Contains("`n")) {
    Write-Host "文件使用Unix行结束符 (LF)"
}

Write-Host "检查完成。"