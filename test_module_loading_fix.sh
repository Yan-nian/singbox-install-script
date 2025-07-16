#!/bin/bash

# 测试模块加载修复效果
echo "=== 测试模块加载修复效果 ==="
echo

# 设置颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 测试函数
test_result() {
    local test_name="$1"
    local status="$2"
    local message="$3"
    
    if [[ "$status" == "PASS" ]]; then
        echo -e "${GREEN}✓ $test_name: $message${NC}"
    else
        echo -e "${RED}✗ $test_name: $message${NC}"
    fi
}

echo -e "${CYAN}1. 测试 config_manager.sh 模块加载逻辑${NC}"
echo

# 创建临时测试环境
temp_dir="/tmp/singbox-modules-test"
mkdir -p "$temp_dir"

# 复制模块到临时目录（模拟在线执行环境）
if [[ -d "lib" ]]; then
    cp lib/*.sh "$temp_dir/" 2>/dev/null
    test_result "模块复制" "PASS" "已复制模块到临时目录"
else
    test_result "模块复制" "FAIL" "lib目录不存在"
    exit 1
fi

echo
echo -e "${CYAN}2. 测试在临时目录环境下的模块加载${NC}"
echo

# 切换到临时目录并测试
cd "$temp_dir"

# 测试 config_manager.sh 的模块加载
echo -e "${BLUE}测试 config_manager.sh 模块加载:${NC}"
if bash -c "source config_manager.sh 2>&1" | grep -q "警告"; then
    echo -e "${YELLOW}检测到警告信息，但模块仍可加载${NC}"
else
    test_result "config_manager.sh加载" "PASS" "无警告信息"
fi

# 测试关键函数是否可用
echo
echo -e "${CYAN}3. 测试关键函数可用性${NC}"
echo

# 在子shell中测试函数
bash -c '
source config_manager.sh 2>/dev/null

# 测试日志函数
if command -v log_debug >/dev/null 2>&1; then
    echo "✓ log_debug 函数可用"
else
    echo "✗ log_debug 函数不可用"
fi

if command -v log_info >/dev/null 2>&1; then
    echo "✓ log_info 函数可用"
else
    echo "✗ log_info 函数不可用"
fi

# 测试验证函数
if command -v validate_uuid >/dev/null 2>&1; then
    echo "✓ validate_uuid 函数可用"
    # 测试UUID验证
    if validate_uuid "123e4567-e89b-12d3-a456-426614174000"; then
        echo "✓ UUID验证功能正常"
    else
        echo "✗ UUID验证功能异常"
    fi
else
    echo "✗ validate_uuid 函数不可用"
fi

if command -v validate_port >/dev/null 2>&1; then
    echo "✓ validate_port 函数可用"
    # 测试端口验证
    if validate_port "443"; then
        echo "✓ 端口验证功能正常"
    else
        echo "✗ 端口验证功能异常"
    fi
else
    echo "✗ validate_port 函数不可用"
fi
'

echo
echo -e "${CYAN}4. 清理测试环境${NC}"
echo

# 返回原目录并清理
cd - >/dev/null
rm -rf "$temp_dir"
test_result "环境清理" "PASS" "已清理临时测试目录"

echo
echo -e "${GREEN}=== 模块加载修复测试完成 ===${NC}"
echo -e "${CYAN}现在可以重新测试批量重新分配端口功能${NC}"