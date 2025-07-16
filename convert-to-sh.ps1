# PowerShell脚本：将bash语法转换为POSIX sh语法

$scriptPath = "singbox-all-in-one.sh"

if (-not (Test-Path $scriptPath)) {
    Write-Error "脚本文件不存在: $scriptPath"
    exit 1
}

# 读取文件内容
$content = Get-Content $scriptPath -Raw

Write-Host "开始转换bash语法为POSIX sh语法..."

# 1. 替换双方括号为单方括号 - 更精确的匹配
$content = $content -replace '\[\[\s+([^\]]+?)\s+\]\]', '[ $1 ]'
$content = $content -replace '\[\[([^\]]+?)\]\]', '[ $1 ]'

# 2. 替换bash特定的正则表达式匹配
$content = $content -replace '\[\[\s*"([^"]+)"\s*=~\s*([^\]]+)\s*\]\]', 'echo "$1" | grep -E "$2" >/dev/null'

# 3. 替换bash数组语法 ${#array[@]}
$content = $content -replace '\$\{#([^\[]+)\[@\]\}', '$(echo "$${1}" | wc -w)'

# 4. 替换bash数组追加语法 array+=("item")
$content = $content -replace '([a-zA-Z_][a-zA-Z0-9_]*)\+=\("([^"]+)"\)', '$1="$$1 $2"'

# 5. 替换算术表达式 ((expression))
$content = $content -replace '\(\(([^)]+)\)\)', '[ $(($1)) ]'

# 6. 替换bash特定的条件表达式
$content = $content -replace '\[\[\s*\$([a-zA-Z_][a-zA-Z0-9_]*)\s*-eq\s*(\d+)\s*\]\]', '[ "$$1" -eq "$2" ]'
$content = $content -replace '\[\[\s*\$([a-zA-Z_][a-zA-Z0-9_]*)\s*-gt\s*(\d+)\s*\]\]', '[ "$$1" -gt "$2" ]'
$content = $content -replace '\[\[\s*\$([a-zA-Z_][a-zA-Z0-9_]*)\s*-lt\s*(\d+)\s*\]\]', '[ "$$1" -lt "$2" ]'

# 7. 修复一些特殊的bash语法
$content = $content -replace 'set -euo pipefail', 'set -eu'

# 8. 替换bash特定的字符串操作
$content = $content -replace '\$\{([^}]+)\[@\]\}', '$$1'

Write-Host "转换完成，保存文件..."

# 保存修改后的内容
$content | Set-Content $scriptPath -Encoding UTF8

Write-Host "bash到POSIX sh的语法转换完成！"
Write-Host "Please note: Some complex bash features may need manual adjustment"