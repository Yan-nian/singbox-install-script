#!/bin/bash

# Sing-box 一键覆盖安装脚本
# 用于已有 Sing-box 安装的用户升级到交互式界面版本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
    exit 1
}

print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                            Sing-box 一键覆盖安装脚本                            ║"
    echo "║                         升级到交互式界面版本 v1.0.0                             ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 检查系统
check_system() {
    if [[ $EUID -ne 0 ]]; then
        error "请使用 root 权限运行此脚本"
    fi
    
    info "检查系统环境..."
    
    # 检查是否已安装 Sing-box
    if ! command -v /usr/local/bin/sing-box >/dev/null 2>&1; then
        warn "未检测到 Sing-box 核心程序"
        echo "如果这是全新安装，请使用 install.sh 脚本"
        read -p "是否继续安装管理脚本? (y/N): " continue_install
        if [[ $continue_install != "y" && $continue_install != "Y" ]]; then
            exit 0
        fi
    fi
    
    success "系统检查完成"
}

# 检查现有配置
check_existing_config() {
    info "检查现有配置..."
    
    if [[ -f "/etc/sing-box/config.json" ]]; then
        success "发现现有配置文件"
        
        # 检查是否有现有的数据库文件
        if [[ -f "/usr/local/etc/sing-box/sing-box.db" ]]; then
            info "发现现有配置数据库"
        else
            warn "未发现配置数据库，将创建新的数据库"
            mkdir -p "/usr/local/etc/sing-box"
            touch "/usr/local/etc/sing-box/sing-box.db"
        fi
    else
        warn "未发现现有配置文件"
        info "将创建默认配置文件"
    fi
}

# 备份现有脚本
backup_existing() {
    info "备份现有管理脚本..."
    
    if [[ -f "/usr/local/bin/sing-box" ]]; then
        cp "/usr/local/bin/sing-box" "/usr/local/bin/sing-box.bak.$(date +%Y%m%d_%H%M%S)"
        success "备份完成"
    else
        warn "未找到现有管理脚本"
    fi
}

# 安装新脚本
install_new_script() {
    info "安装新的交互式管理脚本..."
    
    # 检查当前目录是否有 sing-box.sh 文件
    if [[ -f "./sing-box.sh" ]]; then
        info "使用本地 sing-box.sh 文件"
        cp "./sing-box.sh" "/usr/local/bin/sing-box"
    else
        info "从 GitHub 下载最新脚本..."
        wget -O "/usr/local/bin/sing-box" "https://raw.githubusercontent.com/Yan-nian/singbox-install-script/master/sing-box.sh" || {
            error "下载失败，请检查网络连接"
        }
    fi
    
    # 设置执行权限
    chmod +x "/usr/local/bin/sing-box"
    
    # 更新软链接
    ln -sf "/usr/local/bin/sing-box" "/usr/local/bin/sb"
    
    success "新脚本安装完成"
}

# 安装依赖
install_dependencies() {
    info "安装必要的依赖..."
    
    # 检查系统类型
    if [[ -f /etc/redhat-release ]]; then
        PM="yum"
    elif command -v apt-get >/dev/null 2>&1; then
        PM="apt-get"
    else
        warn "无法识别包管理器，请手动安装依赖: openssl qrencode bc"
        return
    fi
    
    if [[ $PM == "yum" ]]; then
        yum install -y openssl qrencode bc 2>/dev/null || true
    else
        apt-get update -y >/dev/null 2>&1 || true
        apt-get install -y openssl qrencode bc 2>/dev/null || true
    fi
    
    success "依赖安装完成"
}

# 创建默认配置
create_default_config() {
    if [[ ! -f "/etc/sing-box/config.json" ]]; then
        info "创建默认配置文件..."
        
        mkdir -p "/etc/sing-box"
        mkdir -p "/etc/sing-box/configs"
        mkdir -p "/var/log/sing-box"
        
        cat > "/etc/sing-box/config.json" << 'EOF'
{
  "log": {
    "level": "info",
    "timestamp": true,
    "output": "/var/log/sing-box/sing-box.log"
  },
  "inbounds": [],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF
        
        success "默认配置创建完成"
    fi
}

# 验证安装
verify_installation() {
    info "验证安装..."
    
    # 检查脚本是否存在且可执行
    if [[ -f "/usr/local/bin/sing-box" ]] && [[ -x "/usr/local/bin/sing-box" ]]; then
        # 检查脚本语法
        if bash -n "/usr/local/bin/sing-box"; then
            success "脚本语法验证通过"
        else
            error "脚本语法验证失败"
        fi
        
        # 检查是否包含交互式函数
        if grep -q "interactive_main" "/usr/local/bin/sing-box"; then
            success "交互式功能验证通过"
        else
            warn "未检测到交互式功能"
        fi
        
        success "安装验证完成"
    else
        error "脚本文件不存在或无执行权限"
    fi
}

# 显示完成信息
show_completion() {
    echo ""
    success "=== Sing-box 覆盖安装完成 ==="
    echo ""
    info "🎨 新功能特性:"
    echo "  ✅ 美观的彩色交互式界面"
    echo "  ✅ 支持 4 种协议 (VLESS Reality, VMess, Hysteria2, Shadowsocks)"
    echo "  ✅ 智能输入验证和错误处理"
    echo "  ✅ 配置管理和系统优化"
    echo "  ✅ 分享链接和二维码生成"
    echo ""
    info "🚀 使用方法:"
    echo "  sing-box             - 启动交互式菜单（推荐）"
    echo "  sing-box help        - 查看帮助信息"
    echo "  sb                   - 快捷命令"
    echo ""
    info "📋 快速命令:"
    echo "  sing-box add vless   - 添加 VLESS Reality 配置"
    echo "  sing-box list        - 查看所有配置"
    echo "  sing-box status      - 查看服务状态"
    echo ""
    success "✅ 安装成功！运行 'sing-box' 开始使用新的交互式界面"
    echo ""
}

# 主函数
main() {
    print_banner
    
    check_system
    check_existing_config
    backup_existing
    install_dependencies
    install_new_script
    create_default_config
    verify_installation
    show_completion
}

# 执行安装
main "$@"
