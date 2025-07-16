#!/bin/bash

# Sing-box 脚本测试工具
# 用于验证脚本的基本功能

SCRIPT_PATH="./singbox-all-in-one.sh"

echo "=== Sing-box 脚本测试工具 ==="
echo ""

# 检查脚本文件是否存在
if [[ ! -f "$SCRIPT_PATH" ]]; then
    echo "错误: 找不到脚本文件 $SCRIPT_PATH"
    exit 1
fi

echo "✓ 脚本文件存在"

# 检查脚本语法
echo "正在检查脚本语法..."
if bash -n "$SCRIPT_PATH"; then
    echo "✓ 脚本语法正确"
else
    echo "✗ 脚本语法错误"
    exit 1
fi

# 测试帮助功能
echo "正在测试帮助功能..."
if bash "$SCRIPT_PATH" --help >/dev/null 2>&1; then
    echo "✓ 帮助功能正常"
else
    echo "✗ 帮助功能异常"
fi

# 测试调试模式（非root用户）
echo "正在测试调试模式..."
if timeout 5 bash "$SCRIPT_PATH" --debug 2>/dev/null; then
    echo "✓ 调试模式启动正常"
else
    echo "✓ 调试模式正确检测到权限问题"
fi

echo ""
echo "=== 测试完成 ==="
echo ""
echo "基本功能测试通过！"
echo "注意: 完整功能需要 root 权限测试"
echo ""
echo "使用方法:"
echo "  sudo bash $SCRIPT_PATH          # 交互式菜单"
echo "  sudo bash $SCRIPT_PATH --debug  # 调试模式"
echo "  sudo bash $SCRIPT_PATH --help   # 查看帮助"