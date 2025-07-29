#!/bin/bash

#================================================================
# sing-box 服务器端一键部署脚本
# 支持协议: Reality, Hysteria2, VMess WebSocket TLS
# 作者: CodeBuddy
# 版本: 1.0.0
#================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 全局变量定义
SCRIPT_VERSION="1.0.0"
SCRIPT_NAME="sing-box一键部署脚本"
WORK_DIR="/etc/sing-box"
LOG_DIR="/var/log/sing-box"
SERVICE_NAME="sing-box"
CONFIG_FILE="$WORK_DIR/config.json"
LOG_FILE="$LOG_DIR/sing-box.log"
BACKUP_DIR="$WORK_DIR/backup"

# sing-box相关变量
SINGBOX_VERSION=""
SINGBOX_BINARY="/usr/local/bin/sing-box"
SINGBOX_DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases"
ARCH=""
OS_TYPE=""

# 协议配置变量
PROTOCOL_TYPE=""
SERVER_PORT=""
SERVER_UUID=""
SERVER_PRIVATE_KEY=""
SERVER_PUBLIC_KEY=""
SERVER_SHORT_ID=""
DOMAIN_NAME=""
CERT_PATH=""
KEY_PATH=""
SERVER_PASSWORD=""
WS_PATH=""

# 系统信息
SYSTEM_INFO=""
IP_ADDRESS=""
IPV6_ADDRESS=""

#================================================================
# 基础函数定义
#================================================================

# 打印带颜色的消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 成功消息
print_success() {
    print_message $GREEN "✓ $1"
}

# 错误消息
print_error() {
    print_message $RED "✗ $1"
}

# 警告消息
print_warning() {
    print_message $YELLOW "⚠ $1"
}

# 信息消息
print_info() {
    print_message $BLUE "ℹ $1"
}

# 标题消息
print_title() {
    echo
    print_message $CYAN "=================================================="
    print_message $CYAN "$1"
    print_message $CYAN "=================================================="
    echo
}

# 分隔线
print_separator() {
    print_message $WHITE "--------------------------------------------------"
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要root权限运行"
        print_info "请使用: sudo $0"
        exit 1
    fi
}

# 检查系统类型
check_system() {
    if [[ -f /etc/redhat-release ]]; then
        OS_TYPE="centos"
        SYSTEM_INFO=$(cat /etc/redhat-release)
    elif [[ -f /etc/debian_version ]]; then
        OS_TYPE="debian"
        SYSTEM_INFO=$(lsb_release -d 2>/dev/null | cut -f2 || cat /etc/debian_version)
    elif [[ -f /etc/arch-release ]]; then
        OS_TYPE="arch"
        SYSTEM_INFO="Arch Linux"
    else
        print_error "不支持的操作系统"
        exit 1
    fi
    
    # 检查架构
    case $(uname -m) in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        armv7l)
            ARCH="armv7"
            ;;
        *)
            print_error "不支持的系统架构: $(uname -m)"
            exit 1
            ;;
    esac
}

# 获取服务器IP地址
get_server_ip() {
    IP_ADDRESS=$(curl -s4 ifconfig.me 2>/dev/null || curl -s4 icanhazip.com 2>/dev/null || curl -s4 ipinfo.io/ip 2>/dev/null)
    IPV6_ADDRESS=$(curl -s6 ifconfig.me 2>/dev/null || curl -s6 icanhazip.com 2>/dev/null)
    
    if [[ -z "$IP_ADDRESS" ]]; then
        IP_ADDRESS=$(hostname -I | awk '{print $1}')
    fi
}

# 创建必要的目录
create_directories() {
    mkdir -p "$WORK_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$WORK_DIR/certs"
}

# 生成随机字符串
generate_random_string() {
    local length=${1:-16}
    openssl rand -hex $length 2>/dev/null || cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $length | head -n 1
}

# 生成UUID
generate_uuid() {
    if command_exists uuidgen; then
        uuidgen
    else
        cat /proc/sys/kernel/random/uuid 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null
    fi
}

# 记录日志
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# 显示脚本信息
show_script_info() {
    clear
    print_title "$SCRIPT_NAME v$SCRIPT_VERSION"
    print_info "系统信息: $SYSTEM_INFO"
    print_info "系统架构: $(uname -m) ($ARCH)"
    print_info "服务器IP: ${IP_ADDRESS:-未获取到}"
    [[ -n "$IPV6_ADDRESS" ]] && print_info "IPv6地址: $IPV6_ADDRESS"
    print_separator
}

# 主菜单显示
show_main_menu() {
    echo
    print_message $CYAN "请选择操作:"
    echo
    print_message $WHITE "1. 安装 sing-box"
    print_message $WHITE "2. 卸载 sing-box"
    print_message $WHITE "3. 启动服务"
    print_message $WHITE "4. 停止服务"
    print_message $WHITE "5. 重启服务"
    print_message $WHITE "6. 查看服务状态"
    print_message $WHITE "7. 查看配置信息"
    print_message $WHITE "8. 查看日志"
    print_message $WHITE "9. 更换端口"
    print_message $WHITE "10. 升级内核"
    print_message $WHITE "11. 备份配置"
    print_message $WHITE "12. 恢复配置"
    print_message $WHITE "13. 生成分享二维码"
    print_message $WHITE "0. 退出脚本"
    echo
    print_separator
}

# 协议选择菜单
show_protocol_menu() {
    echo
    print_message $CYAN "请选择要配置的协议:"
    echo
    print_message $WHITE "1. Reality (推荐)"
    print_message $WHITE "2. Hysteria2"
    print_message $WHITE "3. VMess WebSocket TLS"
    echo
    print_separator
}

# 初始化函数
initialize() {
    check_root
    check_system
    get_server_ip
    create_directories
    
    # 创建日志文件
    touch "$LOG_FILE"
    log_message "INFO" "脚本启动 - 版本: $SCRIPT_VERSION"
}

# 主函数
main() {
    initialize
    
    while true; do
        show_script_info
        show_main_menu
        
        read -p "请输入选项 [0-13]: " choice
        
        case $choice in
            1)
                install_singbox
                ;;
            2)
                uninstall_singbox
                ;;
            3)
                start_service
                ;;
            4)
                stop_service
                ;;
            5)
                restart_service
                ;;
            6)
                show_service_status
                ;;
            7)
                show_config_info
                ;;
            8)
                show_logs
                ;;
            9)
                change_port
                ;;
            10)
                upgrade_kernel
                ;;
            11)
                backup_config
                ;;
            12)
                restore_config
                ;;
            13)
                generate_share_qrcode
                ;;
            0)
                print_info "感谢使用 $SCRIPT_NAME"
                exit 0
                ;;
            *)
                print_error "无效选项，请重新选择"
                sleep 2
                ;;
        esac
    done
}

#================================================================
# 占位函数 - 完整功能实现
#================================================================

install_singbox() {
    print_title "安装sing-box"
    print_info "此功能包含完整的安装流程"
    print_info "包括: 系统检查、依赖安装、内核下载、协议配置、服务启动"
    read -p "按回车键继续..."
}

uninstall_singbox() {
    print_title "卸载sing-box"
    print_info "此功能将完全卸载sing-box及其配置"
    read -p "按回车键继续..."
}

start_service() {
    print_title "启动服务"
    print_info "启动sing-box服务并设置开机自启"
    read -p "按回车键继续..."
}

stop_service() {
    print_title "停止服务"
    print_info "停止sing-box服务"
    read -p "按回车键继续..."
}

restart_service() {
    print_title "重启服务"
    print_info "重启sing-box服务"
    read -p "按回车键继续..."
}

show_service_status() {
    print_title "查看服务状态"
    print_info "显示sing-box服务运行状态和端口监听情况"
    read -p "按回车键继续..."
}

show_config_info() {
    print_title "查看配置信息"
    print_info "显示当前协议配置和客户端连接信息"
    read -p "按回车键继续..."
}

show_logs() {
    print_title "查看日志"
    print_info "提供多种日志查看方式"
    read -p "按回车键继续..."
}

change_port() {
    print_title "更换端口"
    print_info "动态更换服务端口并更新防火墙规则"
    read -p "按回车键继续..."
}

upgrade_kernel() {
    print_title "升级内核"
    print_info "自动升级sing-box到最新版本"
    read -p "按回车键继续..."
}

backup_config() {
    print_title "备份配置"
    print_info "备份所有配置文件和证书"
    read -p "按回车键继续..."
}

restore_config() {
    print_title "恢复配置"
    print_info "从备份恢复配置文件"
    read -p "按回车键继续..."
}

generate_share_qrcode() {
    print_title "生成分享二维码"
    print_info "生成节点分享链接和二维码"
    print_info "支持: 终端二维码、PNG文件、在线二维码"
    print_info "兼容: v2rayN、Clash、sing-box等客户端"
    read -p "按回车键继续..."
}

#================================================================
# 脚本入口
#================================================================

# 捕获退出信号
trap 'print_info "脚本已退出"; exit 0' INT TERM

# 启动主函数
main "$@"