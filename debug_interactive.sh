#!/bin/bash

# 交互式界面调试脚本

echo "=== 交互式界面调试 ==="
echo

# 检查脚本语法
echo "1. 检查脚本语法:"
if bash -n sing-box.sh; then
    echo "✅ 语法正确"
else
    echo "❌ 语法错误"
    exit 1
fi

echo

# 检查关键函数
echo "2. 检查关键函数:"
functions=("read_input" "show_main_menu" "interactive_main")
for func in "${functions[@]}"; do
    if grep -q "$func()" sing-box.sh; then
        echo "✅ $func 函数存在"
    else
        echo "❌ $func 函数不存在"
    fi
done

echo

# 检查菜单处理
echo "3. 检查菜单处理:"
if grep -q 'case "$choice" in' sing-box.sh; then
    echo "✅ 主菜单处理存在"
else
    echo "❌ 主菜单处理不存在"
fi

if grep -q 'case "$add_choice" in' sing-box.sh; then
    echo "✅ 添加菜单处理存在"
else
    echo "❌ 添加菜单处理不存在"
fi

echo

# 检查输入验证
echo "4. 检查输入验证逻辑:"
echo "当前的 read_input 函数:"
grep -A 15 "read_input()" sing-box.sh | head -20

echo

echo "=== 测试完成 ==="
echo
echo "💡 问题排查建议："
echo "1. 检查 read_input 函数的空格处理"
echo "2. 确保菜单选项处理正确"
echo "3. 验证默认值设置"
echo "4. 测试交互式界面响应"

echo
echo "5. 手动测试："
echo "运行 'bash sing-box.sh' 应该显示主菜单"
echo "输入数字 1-6 应该进入相应的子菜单"
echo "输入 0 应该退出程序"
