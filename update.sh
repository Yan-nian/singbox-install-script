#!/bin/bash

# Sing-box 脚本更新工具
# 版本: v1.0.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 全局变量
SCRIPT_PATH="/usr/local/bin/sing-box"
BACKUP_PATH="/usr/local/bin/sing-box.bak"

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
    exit 1
}

# 检查权限
check_permission() {
    if [[ $EUID -ne 0 ]]; then
        error "请使用 root 权限运行此脚本"
    fi
}

# 备份现有脚本
backup_script() {
    if [[ -f "$SCRIPT_PATH" ]]; then
        info "备份现有脚本..."
        cp "$SCRIPT_PATH" "$BACKUP_PATH"
        success "备份完成: $BACKUP_PATH"
    else
        warn "未找到现有脚本文件"
    fi
}

# 更新脚本
update_script() {
    info "更新管理脚本..."
    
    # 检查当前目录是否有 sing-box.sh 文件
    if [[ -f "./sing-box.sh" ]]; then
        info "使用本地 sing-box.sh 文件"
        cp "./sing-box.sh" "$SCRIPT_PATH"
    else
        info "从 GitHub 下载最新脚本..."
        # 下载完整的管理脚本
        wget -O "$SCRIPT_PATH" "https://raw.githubusercontent.com/Yan-nian/singbox-install-script/master/sing-box.sh" || {
            error "下载管理脚本失败，请检查网络连接"
        }
    fi
    
    # 设置执行权限
    chmod +x "$SCRIPT_PATH"
    
    # 更新软链接
    ln -sf "$SCRIPT_PATH" /usr/local/bin/sb
    
    success "管理脚本更新完成"
}

# 验证更新
verify_update() {
    info "验证更新..."
    
    if [[ -f "$SCRIPT_PATH" ]] && [[ -x "$SCRIPT_PATH" ]]; then
        # 检查脚本语法
        if bash -n "$SCRIPT_PATH"; then
            success "脚本语法验证通过"
        else
            error "脚本语法验证失败"
        fi
        
        # 检查版本信息
        local version_info
        version_info=$("$SCRIPT_PATH" version 2>/dev/null || echo "无法获取版本信息")
        info "当前版本: $version_info"
        
        success "更新验证完成"
    else
        error "脚本文件不存在或无执行权限"
    fi
}

# 显示更新完成信息
show_completion() {
    echo ""
    success "=== Sing-box 脚本更新完成 ==="
    echo ""
    info "🎨 交互式界面:"
    echo "  sing-box             - 启动交互式菜单（推荐）"
    echo "  sb                   - 快捷命令"
    echo ""
    info "📋 新功能:"
    echo "  ✅ 美观的交互式界面"
    echo "  ✅ 支持 4 种协议配置"
    echo "  ✅ 智能输入验证"
    echo "  ✅ 配置管理功能"
    echo "  ✅ 系统优化功能"
    echo "  ✅ 分享链接和二维码"
    echo ""
    info "🔧 如果更新后出现问题，可以恢复备份:"
    echo "  cp $BACKUP_PATH $SCRIPT_PATH"
    echo ""
    success "✅ 更新成功！运行 'sing-box' 开始使用新界面"
    echo ""
}

# 主函数
main() {
    echo "=== Sing-box 脚本更新工具 ==="
    echo ""
    
    check_permission
    backup_script
    update_script
    verify_update
    show_completion
}

# 执行更新
main "$@"
