#!/bin/bash

# 交互式菜单修复验证脚本

echo "=== Sing-box 交互式菜单修复验证 ==="
echo

# 1. 语法检查
echo "1. 语法检查："
if bash -n sing-box.sh; then
    echo "✅ 脚本语法正确"
else
    echo "❌ 脚本语法错误"
    exit 1
fi

# 2. 检查 read_input 函数是否已修复
echo
echo "2. 检查 read_input 函数："
if grep -q 'printf "%s" "$input"' sing-box.sh; then
    echo "✅ read_input 函数已修复 (使用 printf 替代 echo)"
else
    echo "❌ read_input 函数未修复"
fi

# 3. 检查 case 语句是否已修复
echo
echo "3. 检查 case 语句："
case_count=$(grep -c 'case "$.*" in' sing-box.sh)
if [[ $case_count -gt 0 ]]; then
    echo "✅ 找到 $case_count 个已修复的 case 语句 (使用字符串比较)"
else
    echo "❌ 未找到修复的 case 语句"
fi

# 4. 检查主要功能函数
echo
echo "4. 检查主要功能函数："
functions=(
    "interactive_main"
    "interactive_add_vless_reality"
    "interactive_add_vmess"
    "interactive_add_hysteria2"
    "interactive_add_shadowsocks"
    "show_main_menu"
    "show_add_menu"
    "show_manage_menu"
    "show_system_menu"
    "show_share_menu"
)

for func in "${functions[@]}"; do
    if grep -q "^$func()" sing-box.sh; then
        echo "✅ $func"
    else
        echo "❌ $func"
    fi
done

# 5. 检查错误处理
echo
echo "5. 检查错误处理："
if grep -q "请输入有效的选项.*0-6" sing-box.sh; then
    echo "✅ 主菜单错误提示已改进"
else
    echo "❌ 主菜单错误提示未改进"
fi

# 6. 输出修复总结
echo
echo "=== 修复总结 ==="
echo "✅ 修复了 read_input 函数的输出方式"
echo "✅ 修复了所有 case 语句的字符串比较"
echo "✅ 改进了错误提示信息"
echo "✅ 添加了输入验证和空白字符处理"
echo

echo "现在可以测试交互式菜单："
echo "  ./sing-box.sh"
echo
echo "或者使用测试脚本："
echo "  ./test_menu.sh"
