#!/bin/bash

# 调试输入处理问题

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 从原脚本复制的 read_input 函数
read_input() {
    local prompt="$1"
    local default="$2"
    local input
    
    if [[ -n $default ]]; then
        echo -ne "${GREEN}$prompt${NC} [${YELLOW}$default${NC}]: "
    else
        echo -ne "${GREEN}$prompt${NC}: "
    fi
    
    read -r input
    # 去除前后空白字符并返回
    input="${input:-$default}"
    input="${input#"${input%%[![:space:]]*}"}"  # 移除开头空白
    input="${input%"${input##*[![:space:]]}"}"  # 移除结尾空白
    printf "%s" "$input"
}

echo "=== 输入处理测试 ==="
echo

# 测试各种输入
test_inputs=("0" "1" "2" "3" "4" "5" "6" "")

for test_input in "${test_inputs[@]}"; do
    echo "测试输入: '$test_input'"
    result=$(echo "$test_input" | (choice=$(read_input "请选择操作" "0"); echo "结果: '$choice', 长度: ${#choice}"))
    echo "$result"
    echo
done

echo "=== 手动测试 ==="
echo "请输入一个数字 (0-6):"
choice=$(read_input "请选择操作" "0")

echo "您输入的是: '$choice'"
echo "字符串长度: ${#choice}"
echo "ASCII码: $(printf '%d' "'$choice")"

case "$choice" in
    "0") echo "匹配: 退出" ;;
    "1") echo "匹配: 添加配置" ;;
    "2") echo "匹配: 管理配置" ;;
    "3") echo "匹配: 系统管理" ;;
    "4") echo "匹配: 分享链接" ;;
    "5") echo "匹配: 系统信息" ;;
    "6") echo "匹配: 更新脚本" ;;
    *) echo "无匹配: '$choice'" ;;
esac
