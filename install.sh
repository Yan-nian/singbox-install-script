#!/bin/bash

# Sing-box 一键安装脚本
# 支持 VLESS Reality Vision、VMess WebSocket、Hysteria2 协议
# 作者: Sing-box Install Script
# 版本: v1.0.0
# 更新时间: 2024-01-01

set -e

# 脚本信息
SCRIPT_NAME="Sing-box 一键安装脚本"
SCRIPT_VERSION="v1.0.0"
SCRIPT_AUTHOR="Sing-box Install Script"
SCRIPT_URL="https://github.com/your-repo/singbox-install"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 基础变量
WORK_DIR="/var/lib/sing-box"
CONFIG_DIR="$WORK_DIR/config"
CONFIG_FILE="$WORK_DIR/config.json"
CONFIG_BACKUP_DIR="$WORK_DIR/backup"
SINGBOX_BINARY="/usr/local/bin/sing-box"
SERVICE_NAME="sing-box"
LOG_FILE="/var/log/sing-box-install.log"
TEMP_DIR="/tmp/sing-box-install"

# 协议配置变量
VLESS_UUID=""
VLESS_PORT="443"
VLESS_REALITY_PRIVATE_KEY=""
VLESS_REALITY_PUBLIC_KEY=""
VLESS_REALITY_SHORT_ID=""
VLESS_TARGET_SERVER="www.microsoft.com"
VLESS_TARGET_PORT="443"
VLESS_SERVER_NAME="www.microsoft.com"

VMESS_UUID=""
VMESS_PORT="8080"
VMESS_TLS_PORT="8443"
VMESS_WS_PATH=""
VMESS_HOST=""
VMESS_TLS_CERT=""
VMESS_TLS_KEY=""

HY2_PASSWORD=""
HY2_PORT="36712"
HY2_OBFS_PASSWORD=""
HY2_UP_MBPS="100"
HY2_DOWN_MBPS="100"
HY2_CERT=""
HY2_KEY=""
HY2_SERVER_NAME=""
HY2_MASQUERADE_DOMAIN="www.bing.com"

# 系统信息变量
OS=""
OS_VERSION=""
ARCH=""
PUBLIC_IP=""
FIREWALL_TYPE=""
FIREWALL_ACTIVE="false"

# 加载模块
load_modules() {
    local modules=(
        "scripts/common.sh"
        "scripts/system.sh"
        "scripts/singbox.sh"
        "scripts/protocols/vless.sh"
        "scripts/protocols/vmess.sh"
        "scripts/protocols/hysteria2.sh"
        "scripts/config.sh"
        "scripts/service.sh"
        "scripts/menu.sh"
    )
    
    for module in "${modules[@]}"; do
        local module_path="$SCRIPT_DIR/$module"
        if [[ -f "$module_path" ]]; then
            source "$module_path"
        else
            echo -e "${RED}错误: 无法加载模块 $module${NC}"
            echo -e "${YELLOW}请确保所有脚本文件都在正确位置${NC}"
            exit 1
        fi
    done
}

# 初始化环境
init_environment() {
    # 检查 root 权限
    check_root
    
    # 创建必要目录
    create_directories
    
    # 创建日志文件
    touch "$LOG_FILE"
    
    # 检测系统信息
    detect_system
    
    # 设置信号处理
    setup_signal_handlers
    
    log_info "环境初始化完成"
}

# 显示脚本信息
show_banner() {
    clear
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${CYAN}                    $SCRIPT_NAME${NC}"
    echo -e "${CYAN}                      $SCRIPT_VERSION${NC}"
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${GREEN}支持协议:${NC}"
    echo -e "  ${YELLOW}•${NC} VLESS Reality Vision"
    echo -e "  ${YELLOW}•${NC} VMess WebSocket"
    echo -e "  ${YELLOW}•${NC} VMess WebSocket + TLS"
    echo -e "  ${YELLOW}•${NC} Hysteria2"
    echo -e "${CYAN}================================================================${NC}"
    echo ""
}

# 显示帮助信息
show_help() {
    echo -e "${CYAN}$SCRIPT_NAME $SCRIPT_VERSION${NC}"
    echo ""
    echo -e "${YELLOW}用法:${NC}"
    echo -e "  $0 [选项]"
    echo ""
    echo -e "${YELLOW}选项:${NC}"
    echo -e "  ${GREEN}-h, --help${NC}        显示此帮助信息"
    echo -e "  ${GREEN}-v, --version${NC}     显示版本信息"
    echo -e "  ${GREEN}-i, --install${NC}     直接安装 Sing-box"
    echo -e "  ${GREEN}-u, --uninstall${NC}   卸载 Sing-box"
    echo -e "  ${GREEN}-c, --config${NC}      配置向导模式"
    echo -e "  ${GREEN}-s, --status${NC}      显示服务状态"
    echo -e "  ${GREEN}--vless${NC}           配置 VLESS Reality Vision"
    echo -e "  ${GREEN}--vmess${NC}           配置 VMess WebSocket"
    echo -e "  ${GREEN}--vmess-tls${NC}       配置 VMess WebSocket + TLS"
    echo -e "  ${GREEN}--hysteria2${NC}       配置 Hysteria2"
    echo -e "  ${GREEN}--multi${NC}           配置多协议"
    echo ""
    echo -e "${YELLOW}示例:${NC}"
    echo -e "  $0                    # 启动交互式菜单"
    echo -e "  $0 --install          # 直接安装 Sing-box"
    echo -e "  $0 --vless            # 配置 VLESS Reality Vision"
    echo -e "  $0 --multi            # 配置多协议"
    echo ""
}

# 显示版本信息
show_version() {
    echo -e "${CYAN}$SCRIPT_NAME${NC}"
    echo -e "${GREEN}版本: $SCRIPT_VERSION${NC}"
    echo -e "${GREEN}作者: $SCRIPT_AUTHOR${NC}"
    echo -e "${GREEN}项目: $SCRIPT_URL${NC}"
}

# 命令行参数处理
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -i|--install)
                init_environment
                install_singbox
                exit 0
                ;;
            -u|--uninstall)
                init_environment
                uninstall_singbox
                exit 0
                ;;
            -c|--config)
                init_environment
                show_banner
                handle_protocol_menu
                exit 0
                ;;
            -s|--status)
                init_environment
                show_singbox_info
                exit 0
                ;;
            --vless)
                init_environment
                configure_single_protocol "vless"
                exit 0
                ;;
            --vmess)
                init_environment
                configure_single_protocol "vmess"
                exit 0
                ;;
            --vmess-tls)
                init_environment
                configure_single_protocol "vmess-tls"
                exit 0
                ;;
            --hysteria2)
                init_environment
                configure_single_protocol "hysteria2"
                exit 0
                ;;
            --multi)
                init_environment
                configure_multiple_protocols
                exit 0
                ;;
            *)
                echo -e "${RED}未知选项: $1${NC}"
                echo -e "${YELLOW}使用 $0 --help 查看帮助信息${NC}"
                exit 1
                ;;
        esac
        shift
    done
}



# 主函数
main() {
    # 加载所有模块
    load_modules
    
    # 处理命令行参数
    if [[ $# -gt 0 ]]; then
        parse_arguments "$@"
    fi
    
    # 初始化环境
    init_environment
    
    # 显示横幅
    show_banner
    
    # 启动菜单循环
    menu_loop
}

# 运行主函数
main "$@"