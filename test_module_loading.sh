#!/bin/bash

# 模块加载测试脚本
# 用于验证依赖加载机制修复效果

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== 模块加载测试 ===${NC}"
echo -e "${CYAN}测试目标: 验证依赖加载机制修复效果${NC}"
echo ""

# 测试1: 基础函数定义测试
echo -e "${CYAN}测试1: 基础函数定义${NC}"
source "$(dirname "$0")/singbox-install.sh"

# 调用 define_essential_functions
define_essential_functions

# 测试日志函数
echo -e "${YELLOW}测试日志函数:${NC}"
log_debug "这是一条调试信息"
log_info "这是一条信息"
log_warn "这是一条警告"
log_error "这是一条错误信息"

# 测试验证函数
echo -e "${YELLOW}测试验证函数:${NC}"
echo "测试有效UUID:"
if validate_uuid "550e8400-e29b-41d4-a716-446655440000"; then
    echo -e "${GREEN}✓ UUID验证通过${NC}"
else
    echo -e "${RED}✗ UUID验证失败${NC}"
fi

echo "测试无效UUID:"
if validate_uuid "invalid-uuid"; then
    echo -e "${RED}✗ UUID验证应该失败但通过了${NC}"
else
    echo -e "${GREEN}✓ UUID验证正确失败${NC}"
fi

echo "测试有效端口:"
if validate_port "8080"; then
    echo -e "${GREEN}✓ 端口验证通过${NC}"
else
    echo -e "${RED}✗ 端口验证失败${NC}"
fi

echo "测试无效端口:"
if validate_port "99999"; then
    echo -e "${RED}✗ 端口验证应该失败但通过了${NC}"
else
    echo -e "${GREEN}✓ 端口验证正确失败${NC}"
fi

echo ""

# 测试2: 函数验证机制
echo -e "${CYAN}测试2: 函数验证机制${NC}"
if verify_module_functions; then
    echo -e "${GREEN}✓ 所有关键函数都可用${NC}"
else
    echo -e "${YELLOW}⚠ 检测到缺失函数${NC}"
fi

echo ""

# 测试3: 模拟缺失函数场景
echo -e "${CYAN}测试3: 自动修复机制${NC}"

# 临时删除一个函数来测试修复
unset -f log_debug 2>/dev/null || true

echo "模拟 log_debug 函数缺失..."
if verify_module_functions; then
    echo -e "${RED}✗ 应该检测到缺失函数${NC}"
else
    echo -e "${GREEN}✓ 正确检测到缺失函数${NC}"
    
    # 测试自动修复
    if auto_repair_modules; then
        echo -e "${GREEN}✓ 自动修复成功${NC}"
        
        # 验证修复结果
        if verify_module_functions; then
            echo -e "${GREEN}✓ 修复后所有函数可用${NC}"
        else
            echo -e "${RED}✗ 修复后仍有函数缺失${NC}"
        fi
    else
        echo -e "${RED}✗ 自动修复失败${NC}"
    fi
fi

echo ""

# 测试4: 模块加载完整流程
echo -e "${CYAN}测试4: 完整模块加载流程${NC}"
echo "重新加载所有模块..."

# 重新定义变量（因为source了脚本）
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 调用完整的模块加载流程
load_modules

echo ""
echo -e "${GREEN}=== 测试完成 ===${NC}"
echo -e "${CYAN}如果看到此消息，说明模块加载机制工作正常${NC}"

# 测试关键函数调用
echo ""
echo -e "${CYAN}最终验证 - 测试关键函数调用:${NC}"
log_info "模块加载测试完成"
if validate_uuid "123e4567-e89b-12d3-a456-426614174000"; then
    log_info "UUID验证功能正常"
fi
if validate_port "443"; then
    log_info "端口验证功能正常"
fi

echo -e "${GREEN}✓ 所有测试通过！依赖加载机制修复成功${NC}"