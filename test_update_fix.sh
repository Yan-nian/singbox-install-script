#!/bin/bash

# 测试更新功能修复效果
# 版本: v2.4.5
# 日期: 2024-12-19

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Sing-box 更新功能修复测试 ===${NC}"
echo

# 测试脚本路径
SCRIPT_FILE="./singbox-install.sh"

if [[ ! -f "$SCRIPT_FILE" ]]; then
    echo -e "${RED}[FAIL]${NC} 脚本文件不存在: $SCRIPT_FILE"
    exit 1
fi

echo -e "${GREEN}[INFO]${NC} 测试脚本: $SCRIPT_FILE"
echo

# 1. 检查 update_singbox 函数是否包含系统检测
echo -e "${CYAN}1. 检查 update_singbox 函数修复...${NC}"
if grep -A 10 "update_singbox()" "$SCRIPT_FILE" | grep -q "detect_system"; then
    echo -e "${GREEN}[OK]${NC} update_singbox 函数已添加系统检测"
else
    echo -e "${RED}[FAIL]${NC} update_singbox 函数缺少系统检测"
fi

# 2. 检查 ARCH 变量验证
if grep -A 15 "update_singbox()" "$SCRIPT_FILE" | grep -q "ARCH.*变量"; then
    echo -e "${GREEN}[OK]${NC} 已添加 ARCH 变量验证"
else
    echo -e "${RED}[FAIL]${NC} 缺少 ARCH 变量验证"
fi

# 3. 检查 install_singbox 函数增强
echo -e "${CYAN}2. 检查 install_singbox 函数增强...${NC}"
if grep -A 20 "install_singbox()" "$SCRIPT_FILE" | grep -q "前置条件"; then
    echo -e "${GREEN}[OK]${NC} install_singbox 函数已添加前置条件检查"
else
    echo -e "${RED}[FAIL]${NC} install_singbox 函数缺少前置条件检查"
fi

# 4. 检查重试机制
if grep -A 30 "install_singbox()" "$SCRIPT_FILE" | grep -q "retry_count"; then
    echo -e "${GREEN}[OK]${NC} 已添加重试机制"
else
    echo -e "${RED}[FAIL]${NC} 缺少重试机制"
fi

# 5. 检查下载URL调试信息
if grep -A 40 "install_singbox()" "$SCRIPT_FILE" | grep -q "下载URL"; then
    echo -e "${GREEN}[OK]${NC} 已添加下载URL调试信息"
else
    echo -e "${RED}[FAIL]${NC} 缺少下载URL调试信息"
fi

# 6. 检查文件验证
if grep -A 50 "install_singbox()" "$SCRIPT_FILE" | grep -q "验证下载文件"; then
    echo -e "${GREEN}[OK]${NC} 已添加下载文件验证"
else
    echo -e "${RED}[FAIL]${NC} 缺少下载文件验证"
fi

# 7. 检查安装验证
if grep -A 60 "install_singbox()" "$SCRIPT_FILE" | grep -q "验证安装"; then
    echo -e "${GREEN}[OK]${NC} 已添加安装验证"
else
    echo -e "${RED}[FAIL]${NC} 缺少安装验证"
fi

# 8. 检查错误处理改进
echo -e "${CYAN}3. 检查错误处理改进...${NC}"
if grep -A 10 "重新安装二进制文件" "$SCRIPT_FILE" | grep -q "if ! install_singbox"; then
    echo -e "${GREEN}[OK]${NC} update_singbox 函数已改进错误处理"
else
    echo -e "${RED}[FAIL]${NC} update_singbox 函数错误处理未改进"
fi

# 9. 检查 exit 改为 return
if grep -A 50 "install_singbox()" "$SCRIPT_FILE" | grep -q "return 1" && ! grep -A 50 "install_singbox()" "$SCRIPT_FILE" | grep -q "exit 1"; then
    echo -e "${GREEN}[OK]${NC} 已将 exit 改为 return，避免脚本意外退出"
else
    echo -e "${YELLOW}[WARN]${NC} 可能仍存在 exit 语句"
fi

# 10. 语法检查
echo -e "${CYAN}4. 语法检查...${NC}"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
    echo -e "${GREEN}[OK]${NC} 脚本语法正确"
else
    echo -e "${RED}[FAIL]${NC} 脚本语法错误"
    bash -n "$SCRIPT_FILE"
fi

echo
echo -e "${CYAN}=== 修复内容总结 ===${NC}"
echo -e "${GREEN}1.${NC} update_singbox 函数增加系统检测和变量验证"
echo -e "${GREEN}2.${NC} install_singbox 函数增加前置条件检查"
echo -e "${GREEN}3.${NC} 添加网络请求重试机制（最多3次）"
echo -e "${GREEN}4.${NC} 增加下载URL和文件验证调试信息"
echo -e "${GREEN}5.${NC} 改进错误处理，避免脚本意外退出"
echo -e "${GREEN}6.${NC} 添加安装后的二进制文件验证"
echo -e "${GREEN}7.${NC} 增强解压和安装过程的错误处理"
echo

echo -e "${CYAN}=== 测试建议 ===${NC}"
echo -e "${YELLOW}1.${NC} 在实际环境中测试更新功能"
echo -e "${YELLOW}2.${NC} 检查网络连接和GitHub访问"
echo -e "${YELLOW}3.${NC} 验证系统架构检测是否正确"
echo -e "${YELLOW}4.${NC} 测试在不同操作系统上的兼容性"
echo

echo -e "${GREEN}测试完成！${NC}"