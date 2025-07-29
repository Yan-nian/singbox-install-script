#!/bin/bash

#================================================================
# sing-box 一键安装脚本
# 快速下载并运行主安装脚本
#================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 打印消息函数
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_success() {
    print_message $GREEN "✓ $1"
}

print_error() {
    print_message $RED "✗ $1"
}

print_info() {
    print_message $BLUE "ℹ $1"
}

print_warning() {
    print_message $YELLOW "⚠ $1"
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要root权限运行"
        print_info "请使用: sudo $0"
        exit 1
    fi
}

# 主函数
main() {
    clear
    print_info "sing-box 服务器端一键部署脚本"
    print_info "正在准备安装环境..."
    echo
    
    check_root
    
    # 检查是否已存在主脚本
    if [[ -f "singbox-install.sh" ]]; then
        print_info "检测到本地安装脚本"
        chmod +x singbox-install.sh
        exec ./singbox-install.sh
    else
        print_error "未找到 singbox-install.sh 文件"
        print_info "请确保 singbox-install.sh 文件与此脚本在同一目录"
        exit 1
    fi
}

# 运行主函数
main "$@"