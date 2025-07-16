#!/bin/bash

# 语法检查脚本
# 用于验证 install.sh 和 sing-box.sh 的语法正确性

echo "=== Sing-box 脚本语法检查 ==="
echo ""

# 检查 install.sh
echo "[INFO] 检查 install.sh 语法..."
if bash -n install.sh; then
    echo "[SUCCESS] install.sh 语法检查通过"
else
    echo "[ERROR] install.sh 语法检查失败"
    exit 1
fi

echo ""

# 检查 sing-box.sh
echo "[INFO] 检查 sing-box.sh 语法..."
if bash -n sing-box.sh; then
    echo "[SUCCESS] sing-box.sh 语法检查通过"
else
    echo "[ERROR] sing-box.sh 语法检查失败"
    exit 1
fi

echo ""
echo "[SUCCESS] 所有脚本语法检查通过！"

# 检查关键变量定义
echo ""
echo "=== 变量定义检查 ==="
echo ""

echo "[INFO] 检查 CONFIG_FILE 变量定义..."
if grep -q "CONFIG_FILE=" install.sh; then
    echo "[SUCCESS] 找到 CONFIG_FILE 定义:"
    grep -n "CONFIG_FILE=" install.sh
else
    echo "[ERROR] 未找到 CONFIG_FILE 定义"
    exit 1
fi

echo ""
echo "[INFO] 检查 CONFIG_FILE 使用情况..."
echo "install.sh 中的使用:"
grep -n "\$CONFIG_FILE" install.sh || echo "未找到使用"

echo ""
echo "sing-box.sh 中的使用:"
grep -n "\$CONFIG_FILE" sing-box.sh || echo "未找到使用"

echo ""
echo "=== 检查完成 ==="