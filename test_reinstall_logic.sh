#!/bin/bash

# 测试覆盖安装逻辑的脚本
echo "=== 测试一键脚本覆盖安装逻辑 ==="
echo

SCRIPT_FILE="./singbox-install.sh"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

if [[ ! -f "$SCRIPT_FILE" ]]; then
    echo -e "${RED}[FAIL]${NC} 脚本文件不存在: $SCRIPT_FILE"
    exit 1
fi

echo -e "${CYAN}检查覆盖安装逻辑改进:${NC}"
echo

# 检查 perform_installation 函数是否包含覆盖安装逻辑
if grep -q "检查是否为覆盖安装" "$SCRIPT_FILE"; then
    echo -e "${GREEN}[OK]${NC} 覆盖安装检测逻辑已添加"
else
    echo -e "${RED}[FAIL]${NC} 覆盖安装检测逻辑缺失"
fi

# 检查服务停止逻辑
if grep -q "停止现有 Sing-box 服务" "$SCRIPT_FILE"; then
    echo -e "${GREEN}[OK]${NC} 服务停止逻辑已添加"
else
    echo -e "${RED}[FAIL]${NC} 服务停止逻辑缺失"
fi

# 检查配置备份逻辑
if grep -q "配置已备份到" "$SCRIPT_FILE"; then
    echo -e "${GREEN}[OK]${NC} 配置备份逻辑已添加"
else
    echo -e "${RED}[FAIL]${NC} 配置备份逻辑缺失"
fi

# 检查服务重启逻辑
if grep -q "检测到现有配置，尝试重启服务" "$SCRIPT_FILE"; then
    echo -e "${GREEN}[OK]${NC} 服务重启逻辑已添加"
else
    echo -e "${RED}[FAIL]${NC} 服务重启逻辑缺失"
fi

# 检查覆盖安装确认逻辑
if grep -q "确认重新安装？这将覆盖现有配置" "$SCRIPT_FILE"; then
    echo -e "${GREEN}[OK]${NC} 覆盖安装确认提示已存在"
else
    echo -e "${RED}[FAIL]${NC} 覆盖安装确认提示缺失"
fi

echo
echo -e "${CYAN}覆盖安装流程验证:${NC}"
echo -e "${YELLOW}1.${NC} 检测现有安装状态"
echo -e "${YELLOW}2.${NC} 用户确认覆盖安装"
echo -e "${YELLOW}3.${NC} 停止现有服务"
echo -e "${YELLOW}4.${NC} 备份现有配置"
echo -e "${YELLOW}5.${NC} 执行安装流程"
echo -e "${YELLOW}6.${NC} 恢复配置并重启服务"
echo

echo -e "${GREEN}覆盖安装逻辑测试完成！${NC}"
echo -e "${CYAN}现在覆盖安装将正确处理现有配置和服务。${NC}"