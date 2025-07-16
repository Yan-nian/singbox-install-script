#!/bin/bash

# 测试交互式菜单修复

echo "测试 read_input 函数..."

# 模拟 read_input 函数
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
    input="${input// /}"  # 移除所有空格
    printf "%s" "$input"
}

echo "请输入 1 进行测试:"
choice=$(read_input "请选择操作" "0")

echo ""
echo "您输入的值: '$choice'"
echo "值的长度: ${#choice}"

case "$choice" in
    "1")
        echo "✅ 选项 1 匹配成功"
        ;;
    "2")
        echo "✅ 选项 2 匹配成功"
        ;;
    "0")
        echo "✅ 选项 0 匹配成功"
        ;;
    *)
        echo "❌ 没有匹配的选项"
        ;;
esac
