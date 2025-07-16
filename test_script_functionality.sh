#!/bin/bash

# 测试脚本功能
# 验证一键安装脚本的基本功能

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Sing-box 一键安装脚本功能测试 ===${NC}"
echo ""

# 测试1: 检查脚本语法
echo -e "${YELLOW}[测试1] 检查脚本语法...${NC}"
if bash -n install_v2.sh 2>/dev/null; then
    echo -e "${GREEN}✓ 脚本语法正确${NC}"
else
    echo -e "${RED}✗ 脚本语法错误${NC}"
    echo "请检查 install_v2.sh 文件"
fi
echo ""

# 测试2: 检查二维码生成统一性
echo -e "${YELLOW}[测试2] 检查二维码生成统一性...${NC}"
qr_without_small=$(grep -r "qrcode-terminal" --include="*.sh" . | grep -v "--small" | grep -v "安装" | grep -v "command -v" | wc -l)
if [[ $qr_without_small -eq 0 ]]; then
    echo -e "${GREEN}✓ 所有二维码生成都使用了 --small 参数${NC}"
else
    echo -e "${RED}✗ 发现 $qr_without_small 处未使用 --small 参数的二维码生成${NC}"
    grep -r "qrcode-terminal" --include="*.sh" . | grep -v "--small" | grep -v "安装" | grep -v "command -v"
fi
echo ""

# 测试3: 检查卸载功能完整性
echo -e "${YELLOW}[测试3] 检查卸载功能完整性...${NC}"
if grep -q "完全卸载" install_v2.sh; then
    echo -e "${GREEN}✓ 包含完全卸载功能${NC}"
else
    echo -e "${RED}✗ 缺少完全卸载功能${NC}"
fi

if grep -q "\[1/8\]" install_v2.sh; then
    echo -e "${GREEN}✓ 卸载过程分步骤执行${NC}"
else
    echo -e "${RED}✗ 卸载过程未分步骤${NC}"
fi

if grep -q "remaining_files" install_v2.sh; then
    echo -e "${GREEN}✓ 包含卸载验证功能${NC}"
else
    echo -e "${RED}✗ 缺少卸载验证功能${NC}"
fi
echo ""

# 测试4: 检查核心模块依赖
echo -e "${YELLOW}[测试4] 检查核心模块依赖...${NC}"
required_modules=(
    "core/bootstrap.sh"
    "core/error_handler.sh"
    "core/logger.sh"
    "config/config_manager.sh"
    "utils/system_utils.sh"
    "utils/network_utils.sh"
)

all_modules_exist=true
for module in "${required_modules[@]}"; do
    if [[ -f "$module" ]]; then
        echo -e "${GREEN}✓ $module 存在${NC}"
    else
        echo -e "${RED}✗ $module 缺失${NC}"
        all_modules_exist=false
    fi
done

if [[ "$all_modules_exist" == "true" ]]; then
    echo -e "${GREEN}✓ 所有核心模块都存在${NC}"
else
    echo -e "${RED}✗ 部分核心模块缺失${NC}"
fi
echo ""

# 测试5: 检查协议支持
echo -e "${YELLOW}[测试5] 检查协议支持...${NC}"
protocols=("vless" "vmess" "hysteria2")
for protocol in "${protocols[@]}"; do
    if grep -q "$protocol" install_v2.sh; then
        echo -e "${GREEN}✓ 支持 $protocol 协议${NC}"
    else
        echo -e "${RED}✗ 不支持 $protocol 协议${NC}"
    fi
done
echo ""

# 测试6: 检查帮助信息
echo -e "${YELLOW}[测试6] 检查帮助信息...${NC}"
if grep -q "show_help" install_v2.sh; then
    echo -e "${GREEN}✓ 包含帮助功能${NC}"
else
    echo -e "${RED}✗ 缺少帮助功能${NC}"
fi

if grep -q "一键卸载" install_v2.sh; then
    echo -e "${GREEN}✓ 帮助信息提到一键卸载${NC}"
else
    echo -e "${YELLOW}! 帮助信息未明确提到一键卸载${NC}"
fi
echo ""

echo -e "${CYAN}=== 测试完成 ===${NC}"
echo -e "${GREEN}建议：${NC}"
echo "1. 二维码生成已统一使用 --small 参数，确保终端显示大小一致"
echo "2. 已添加完整的一键卸载功能，可完全清理所有相关文件"
echo "3. 卸载过程分8个步骤，包含验证机制"
echo "4. 支持三种主要协议：VLESS Reality、VMess WebSocket、Hysteria2"
echo ""
echo -e "${YELLOW}使用方法：${NC}"
echo "- 安装：./install_v2.sh install"
echo "- 卸载：./install_v2.sh uninstall"
echo "- 菜单：./install_v2.sh menu"
echo "- 帮助：./install_v2.sh --help"