#!/bin/bash

# Sing-box 自动安装示例脚本
# 此脚本展示如何自动化安装 sing-box 而无需交互

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        log_info "请使用: sudo bash $0"
        exit 1
    fi
}

# 下载安装脚本
download_script() {
    log_info "正在下载 sing-box 安装脚本..."
    
    if command -v wget >/dev/null 2>&1; then
        wget -O install.sh https://raw.githubusercontent.com/your-repo/singbox-install-script/main/install.sh
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL https://raw.githubusercontent.com/your-repo/singbox-install-script/main/install.sh -o install.sh
    else
        log_error "请安装 wget 或 curl"
        exit 1
    fi
    
    chmod +x install.sh
    log_info "脚本下载完成"
}

# 自动安装 VLESS Reality（推荐）
install_vless_reality() {
    log_info "开始自动安装 VLESS Reality..."
    
    # 使用 expect 或者预设输入来自动化安装过程
    # 这里是一个示例，实际使用时需要根据脚本的交互流程调整
    
    expect << EOF
set timeout 300
spawn bash install.sh

# 等待主菜单
expect "请选择操作"
send "1\r"

# 选择目标网站（选择默认的 microsoft.com）
expect "请选择"
send "1\r"

# 等待安装完成
expect "按回车键返回主菜单"
send "\r"

# 退出脚本
expect "请选择操作"
send "0\r"

expect eof
EOF

    log_info "VLESS Reality 安装完成"
}

# 自动安装所有协议
install_all_protocols() {
    log_info "开始自动安装所有协议..."
    
    expect << EOF
set timeout 600
spawn bash install.sh

# 等待主菜单
expect "请选择操作"
send "4\r"

# 选择目标网站（选择默认的 microsoft.com）
expect "请选择"
send "1\r"

# 等待安装完成
expect "按回车键返回主菜单"
send "\r"

# 退出脚本
expect "请选择操作"
send "0\r"

expect eof
EOF

    log_info "所有协议安装完成"
}

# 显示使用帮助
show_help() {
    echo "Sing-box 自动安装示例脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help              显示此帮助信息"
    echo "  -v, --vless             自动安装 VLESS Reality"
    echo "  -a, --all               自动安装所有协议"
    echo "  -d, --download-only     仅下载安装脚本"
    echo ""
    echo "示例:"
    echo "  $0 -v                   # 自动安装 VLESS Reality"
    echo "  $0 -a                   # 自动安装所有协议"
    echo "  $0 -d                   # 仅下载脚本"
    echo ""
    echo "注意: 此脚本需要安装 expect 工具来实现自动化交互"
    echo "      Ubuntu/Debian: apt-get install expect"
    echo "      CentOS/RHEL: yum install expect"
}

# 检查 expect 是否安装
check_expect() {
    if ! command -v expect >/dev/null 2>&1; then
        log_warn "expect 工具未安装，无法进行自动化安装"
        log_info "请安装 expect:"
        log_info "  Ubuntu/Debian: apt-get install expect"
        log_info "  CentOS/RHEL: yum install expect"
        log_info "  或者手动运行: bash install.sh"
        exit 1
    fi
}

# 主函数
main() {
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--vless)
            check_root
            check_expect
            download_script
            install_vless_reality
            ;;
        -a|--all)
            check_root
            check_expect
            download_script
            install_all_protocols
            ;;
        -d|--download-only)
            download_script
            log_info "脚本已下载到当前目录，请运行: sudo bash install.sh"
            ;;
        "")
            log_info "使用默认模式：自动安装 VLESS Reality"
            check_root
            check_expect
            download_script
            install_vless_reality
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"