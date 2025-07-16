#!/bin/bash

# 构建脚本
# 将 install.sh 和所有模块合并成一个单文件脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_FILE="$PROJECT_ROOT/one-click-install.sh"

# 模块列表
MODULES=(
    "scripts/common.sh"
    "scripts/system.sh"
    "scripts/singbox.sh"
    "scripts/protocols/vless.sh"
    "scripts/protocols/vmess.sh"
    "scripts/protocols/hysteria2.sh"
    "scripts/config.sh"
    "scripts/service.sh"
    "scripts/menu.sh"
)

echo "正在构建 one-click-install.sh..."

# 创建一个临时文件
TEMP_FILE=$(mktemp)

# 1. 将 install.sh 的内容（不包括 load_modules 和 main 调用）复制到临时文件
awk '
  /load_modules\(\) \{/ {p=1} 
  !p {print} 
  /\}/ {p=0}
' "$PROJECT_ROOT/install.sh" | grep -v 'main "$@"' > "$TEMP_FILE"

# 2. 将所有模块的内容追加到临时文件
for module in "${MODULES[@]}"; do
    # 从模块中移除 #!/bin/bash
    sed 's/#!\/bin\/bash//g' "$PROJECT_ROOT/$module" >> "$TEMP_FILE"
    echo -e "\n" >> "$TEMP_FILE"
done

# 3. 将 main 函数调用追加到临时文件末尾
echo 'main "$@"' >> "$TEMP_FILE"

# 4. 将临时文件移动到最终位置
mv "$TEMP_FILE" "$OUTPUT_FILE"

# 5. 赋予执行权限
chmod +x "$OUTPUT_FILE"

echo "构建完成: $OUTPUT_FILE"