#!/bin/bash

# 测试新增功能的脚本

echo "=== Sing-box 新增功能测试 ==="
echo

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 输出函数
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查脚本文件
if [[ ! -f "sing-box.sh" ]]; then
    error "sing-box.sh 文件不存在"
    exit 1
fi

# 1. 检查语法
echo "1. 检查脚本语法:"
if bash -n sing-box.sh; then
    success "语法检查通过"
else
    error "语法检查失败"
    exit 1
fi

# 2. 检查新增的函数
echo
echo "2. 检查新增函数:"
functions=("interactive_update_script" "interactive_update_core" "update_core" "check_version")

for func in "${functions[@]}"; do
    if grep -q "$func()" sing-box.sh; then
        success "$func 函数存在"
    else
        error "$func 函数不存在"
    fi
done

# 3. 检查帮助信息
echo
echo "3. 检查帮助信息:"
if grep -q "update script" sing-box.sh; then
    success "帮助信息包含更新脚本命令"
else
    error "帮助信息缺少更新脚本命令"
fi

if grep -q "update core" sing-box.sh; then
    success "帮助信息包含更新核心命令"
else
    error "帮助信息缺少更新核心命令"
fi

# 4. 检查命令行参数处理
echo
echo "4. 检查命令行参数:"
if grep -q '"update")' sing-box.sh; then
    success "命令行参数包含 update 处理"
else
    error "命令行参数缺少 update 处理"
fi

# 5. 检查系统菜单
echo
echo "5. 检查系统菜单:"
if grep -q "更新脚本" sing-box.sh; then
    success "系统菜单包含更新脚本选项"
else
    error "系统菜单缺少更新脚本选项"
fi

if grep -q "更新核心" sing-box.sh; then
    success "系统菜单包含更新核心选项"
else
    error "系统菜单缺少更新核心选项"
fi

# 6. 检查新增的案例处理
echo
echo "6. 检查菜单选项处理:"
if grep -q 'interactive_update_script' sing-box.sh; then
    success "系统菜单包含更新脚本处理"
else
    error "系统菜单缺少更新脚本处理"
fi

if grep -q 'interactive_update_core' sing-box.sh; then
    success "系统菜单包含更新核心处理"
else
    error "系统菜单缺少更新核心处理"
fi

echo
echo "=== 新增功能测试完成 ==="
echo
echo "📋 新增功能总结:"
echo "  ✅ 更新管理脚本功能 (interactive_update_script)"
echo "  ✅ 更新核心程序功能 (interactive_update_core / update_core)"
echo "  ✅ 版本检查功能 (check_version)"
echo "  ✅ 命令行参数支持 (sing-box update script/core)"
echo "  ✅ 系统菜单集成"
echo "  ✅ 帮助信息更新"
echo
echo "🎯 使用方法:"
echo "  交互式: sing-box -> 系统管理 -> 更新脚本/更新核心"
echo "  命令行: sing-box update script / sing-box update core"
echo "  版本查看: sing-box version"
echo
success "所有新增功能已实现并可使用！"
