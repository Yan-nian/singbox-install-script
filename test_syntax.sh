#!/bin/bash

# 简单的语法检查脚本
echo "检查 install.sh 语法..."

# 使用 bash -n 检查语法
if bash -n install.sh 2>/dev/null; then
    echo "✅ install.sh 语法检查通过"
else
    echo "❌ install.sh 语法检查失败"
    bash -n install.sh
fi

echo ""
echo "检查 sing-box.sh 语法..."

# 检查主脚本语法
if bash -n sing-box.sh 2>/dev/null; then
    echo "✅ sing-box.sh 语法检查通过"
else
    echo "❌ sing-box.sh 语法检查失败"
    bash -n sing-box.sh
fi

echo ""
echo "语法检查完成！"