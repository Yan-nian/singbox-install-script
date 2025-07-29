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
        
        read -p "请输入选项 [0-12]: " choice
        
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
# 系统环境检测和依赖安装功能
#================================================================

# 检查并安装依赖
install_dependencies() {
    print_info "检查系统依赖..."
    
    local packages_to_install=()
    
    # 检查必需的命令
    local required_commands=("curl" "wget" "openssl" "systemctl" "jq")
    
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            case "$cmd" in
                "curl"|"wget"|"openssl")
                    if [[ "$OS_TYPE" == "debian" ]]; then
                        packages_to_install+=("$cmd")
                    elif [[ "$OS_TYPE" == "centos" ]]; then
                        packages_to_install+=("$cmd")
                    fi
                    ;;
                "jq")
                    packages_to_install+=("jq")
                    ;;
                "systemctl")
                    if ! command_exists "systemctl"; then
                        print_error "系统不支持systemd，无法继续安装"
                        exit 1
                    fi
                    ;;
            esac
        fi
    done
    
    # 安装缺失的包
    if [[ ${#packages_to_install[@]} -gt 0 ]]; then
        print_info "正在安装依赖包: ${packages_to_install[*]}"
        
        case "$OS_TYPE" in
            "debian")
                apt update -y
                apt install -y "${packages_to_install[@]}"
                ;;
            "centos")
                if command_exists "dnf"; then
                    dnf install -y "${packages_to_install[@]}"
                else
                    yum install -y "${packages_to_install[@]}"
                fi
                ;;
            "arch")
                pacman -Sy --noconfirm "${packages_to_install[@]}"
                ;;
        esac
        
        if [[ $? -eq 0 ]]; then
            print_success "依赖安装完成"
        else
            print_error "依赖安装失败"
            exit 1
        fi
    else
        print_success "所有依赖已满足"
    fi
}

# 检查防火墙状态
check_firewall() {
    print_info "检查防火墙状态..."
    
    if command_exists "ufw"; then
        if ufw status | grep -q "Status: active"; then
            print_info "检测到UFW防火墙已启用"
            FIREWALL_TYPE="ufw"
        else
            print_info "UFW防火墙未启用"
            FIREWALL_TYPE="none"
        fi
    elif command_exists "firewall-cmd"; then
        if systemctl is-active --quiet firewalld; then
            print_info "检测到firewalld防火墙已启用"
            FIREWALL_TYPE="firewalld"
        else
            print_info "firewalld防火墙未启用"
            FIREWALL_TYPE="none"
        fi
    elif command_exists "iptables"; then
        print_info "检测到iptables"
        FIREWALL_TYPE="iptables"
    else
        print_warning "未检测到防火墙管理工具"
        FIREWALL_TYPE="none"
    fi
}

# 检查端口占用
check_port_usage() {
    local port=$1
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        return 0  # 端口被占用
    elif ss -tuln 2>/dev/null | grep -q ":$port "; then
        return 0  # 端口被占用
    else
        return 1  # 端口未被占用
    fi
}

# 生成随机可用端口
generate_random_port() {
    local min_port=${1:-10000}
    local max_port=${2:-65535}
    
    while true; do
        local port=$((RANDOM % (max_port - min_port + 1) + min_port))
        if ! check_port_usage "$port"; then
            echo "$port"
            return 0
        fi
    done
}

# 验证域名格式
validate_domain() {
    local domain=$1
    if [[ $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 0
    else
        return 1
    fi
}

# 检查域名解析
check_domain_resolution() {
    local domain=$1
    local resolved_ip
    
    resolved_ip=$(dig +short "$domain" 2>/dev/null | tail -n1)
    
    if [[ -z "$resolved_ip" ]]; then
        resolved_ip=$(nslookup "$domain" 2>/dev/null | awk '/^Address: / { print $2 }' | tail -n1)
    fi
    
    if [[ -n "$resolved_ip" && "$resolved_ip" == "$IP_ADDRESS" ]]; then
        return 0
    else
        return 1
    fi
}

# 系统环境完整性检查
system_check() {
    print_title "系统环境检查"
    
    # 检查系统信息
    print_info "操作系统: $SYSTEM_INFO"
    print_info "系统架构: $(uname -m) ($ARCH)"
    print_info "内核版本: $(uname -r)"
    
    # 检查内存
    local total_mem=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    print_info "系统内存: ${total_mem}MB"
    
    if [[ $total_mem -lt 512 ]]; then
        print_warning "系统内存较低，可能影响性能"
    fi
    
    # 检查磁盘空间
    local available_space=$(df / | awk 'NR==2 {print $4}')
    print_info "可用磁盘空间: $((available_space / 1024))MB"
    
    if [[ $available_space -lt 1048576 ]]; then  # 小于1GB
        print_warning "磁盘空间不足，建议至少保留1GB空间"
    fi
    
    # 检查网络连接
    print_info "检查网络连接..."
    if curl -s --connect-timeout 10 https://www.google.com > /dev/null; then
        print_success "网络连接正常"
    elif curl -s --connect-timeout 10 https://www.baidu.com > /dev/null; then
        print_success "网络连接正常（国内网络）"
    else
        print_error "网络连接异常，请检查网络设置"
        return 1
    fi
    
    # 安装依赖
    install_dependencies
    
    # 检查防火墙
    check_firewall
    
    print_success "系统环境检查完成"
    return 0
}

#================================================================
# sing-box内核下载和安装模块
#================================================================

# 获取最新版本号
get_latest_version() {
    print_info "获取sing-box最新版本信息..."
    
    local api_url="https://api.github.com/repos/SagerNet/sing-box/releases/latest"
    local version_info
    
    version_info=$(curl -s "$api_url" 2>/dev/null)
    
    if [[ $? -ne 0 || -z "$version_info" ]]; then
        print_warning "无法从GitHub获取版本信息，尝试备用方法..."
        # 备用方法：解析GitHub页面
        version_info=$(curl -s "https://github.com/SagerNet/sing-box/releases/latest" 2>/dev/null | grep -oP 'tag/v\K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        if [[ -n "$version_info" ]]; then
            SINGBOX_VERSION="v$version_info"
        else
            print_error "无法获取版本信息"
            return 1
        fi
    else
        SINGBOX_VERSION=$(echo "$version_info" | jq -r '.tag_name' 2>/dev/null)
        if [[ -z "$SINGBOX_VERSION" || "$SINGBOX_VERSION" == "null" ]]; then
            print_error "解析版本信息失败"
            return 1
        fi
    fi
    
    print_success "获取到最新版本: $SINGBOX_VERSION"
    return 0
}

# 下载sing-box内核
download_singbox() {
    local version=${1:-$SINGBOX_VERSION}
    
    if [[ -z "$version" ]]; then
        print_error "版本信息为空"
        return 1
    fi
    
    print_info "开始下载sing-box内核..."
    
    # 构建下载URL
    local filename="sing-box-${version#v}-linux-${ARCH}.tar.gz"
    local download_url="https://github.com/SagerNet/sing-box/releases/download/${version}/${filename}"
    local temp_file="/tmp/${filename}"
    
    print_info "下载地址: $download_url"
    
    # 下载文件
    if curl -L -o "$temp_file" "$download_url" --progress-bar; then
        print_success "下载完成"
    else
        print_error "下载失败"
        return 1
    fi
    
    # 验证文件
    if [[ ! -f "$temp_file" || ! -s "$temp_file" ]]; then
        print_error "下载的文件无效"
        return 1
    fi
    
    # 解压文件
    print_info "正在解压文件..."
    local temp_dir="/tmp/sing-box-${version#v}"
    mkdir -p "$temp_dir"
    
    if tar -xzf "$temp_file" -C "$temp_dir" --strip-components=1; then
        print_success "解压完成"
    else
        print_error "解压失败"
        return 1
    fi
    
    # 安装二进制文件
    if [[ -f "$temp_dir/sing-box" ]]; then
        chmod +x "$temp_dir/sing-box"
        cp "$temp_dir/sing-box" "$SINGBOX_BINARY"
        print_success "sing-box内核安装完成"
    else
        print_error "未找到sing-box二进制文件"
        return 1
    fi
    
    # 清理临时文件
    rm -rf "$temp_file" "$temp_dir"
    
    # 验证安装
    if "$SINGBOX_BINARY" version >/dev/null 2>&1; then
        local installed_version=$("$SINGBOX_BINARY" version 2>/dev/null | head -1)
        print_success "安装验证成功: $installed_version"
        log_message "INFO" "sing-box内核安装成功: $installed_version"
        return 0
    else
        print_error "安装验证失败"
        return 1
    fi
}

# 检查sing-box是否已安装
check_singbox_installed() {
    if [[ -f "$SINGBOX_BINARY" ]] && "$SINGBOX_BINARY" version >/dev/null 2>&1; then
        local current_version=$("$SINGBOX_BINARY" version 2>/dev/null | head -1)
        print_info "检测到已安装的sing-box: $current_version"
        return 0
    else
        return 1
    fi
}

# 创建systemd服务文件
create_systemd_service() {
    print_info "创建systemd服务文件..."
    
    cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
ExecStart=$SINGBOX_BINARY run -c $CONFIG_FILE
Restart=on-failure
RestartSec=1800s
ExecReload=/bin/kill -HUP \$MAINPID

[Install]
WantedBy=multi-user.target
EOF

    if [[ $? -eq 0 ]]; then
        systemctl daemon-reload
        print_success "systemd服务文件创建完成"
        log_message "INFO" "systemd服务文件创建成功"
        return 0
    else
        print_error "systemd服务文件创建失败"
        return 1
    fi
}

#================================================================
# Reality协议配置生成功能
#================================================================

# 生成Reality密钥对
generate_reality_keypair() {
    print_info "生成Reality密钥对..."
    
    local keypair_output
    keypair_output=$("$SINGBOX_BINARY" generate reality-keypair 2>/dev/null)
    
    if [[ $? -eq 0 && -n "$keypair_output" ]]; then
        SERVER_PRIVATE_KEY=$(echo "$keypair_output" | grep "PrivateKey:" | awk '{print $2}')
        SERVER_PUBLIC_KEY=$(echo "$keypair_output" | grep "PublicKey:" | awk '{print $2}')
        
        if [[ -n "$SERVER_PRIVATE_KEY" && -n "$SERVER_PUBLIC_KEY" ]]; then
            print_success "Reality密钥对生成成功"
            return 0
        fi
    fi
    
    print_error "Reality密钥对生成失败"
    return 1
}

# 生成Reality短ID
generate_reality_short_id() {
    SERVER_SHORT_ID=$(openssl rand -hex 8 2>/dev/null | head -c 16)
    if [[ -n "$SERVER_SHORT_ID" ]]; then
        print_success "Reality短ID生成成功: $SERVER_SHORT_ID"
        return 0
    else
        print_error "Reality短ID生成失败"
        return 1
    fi
}

# Reality协议配置
configure_reality() {
    print_title "配置Reality协议"
    
    # 生成UUID
    SERVER_UUID=$(generate_uuid)
    if [[ -z "$SERVER_UUID" ]]; then
        print_error "UUID生成失败"
        return 1
    fi
    print_success "UUID生成成功: $SERVER_UUID"
    
    # 设置端口
    while true; do
        read -p "请输入Reality端口 (默认443): " input_port
        SERVER_PORT=${input_port:-443}
        
        if [[ "$SERVER_PORT" =~ ^[0-9]+$ ]] && [[ "$SERVER_PORT" -ge 1 ]] && [[ "$SERVER_PORT" -le 65535 ]]; then
            if check_port_usage "$SERVER_PORT"; then
                print_warning "端口 $SERVER_PORT 已被占用，请选择其他端口"
                continue
            else
                print_success "端口设置: $SERVER_PORT"
                break
            fi
        else
            print_error "无效端口，请输入1-65535之间的数字"
        fi
    done
    
    # 设置目标域名
    while true; do
        read -p "请输入目标域名 (默认www.microsoft.com): " input_domain
        DOMAIN_NAME=${input_domain:-"www.microsoft.com"}
        
        if validate_domain "$DOMAIN_NAME"; then
            print_success "目标域名设置: $DOMAIN_NAME"
            break
        else
            print_error "无效域名格式，请重新输入"
        fi
    done
    
    # 生成密钥对
    if ! generate_reality_keypair; then
        return 1
    fi
    
    # 生成短ID
    if ! generate_reality_short_id; then
        return 1
    fi
    
    # 生成配置文件
    generate_reality_config
    
    return $?
}

# 生成Reality配置文件
generate_reality_config() {
    print_info "生成Reality配置文件..."
    
    cat > "$CONFIG_FILE" << EOF
{
  "log": {
    "level": "info",
    "timestamp": true,
    "output": "$LOG_FILE"
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": $SERVER_PORT,
      "users": [
        {
          "uuid": "$SERVER_UUID",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$DOMAIN_NAME",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "$DOMAIN_NAME",
            "server_port": 443
          },
          "private_key": "$SERVER_PRIVATE_KEY",
          "short_id": [
            "$SERVER_SHORT_ID"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    }
  ]
}
EOF

    if [[ $? -eq 0 ]]; then
        print_success "Reality配置文件生成完成"
        log_message "INFO" "Reality配置文件生成成功"
        
        # 生成客户端配置信息
        generate_reality_client_config
        
        return 0
    else
        print_error "Reality配置文件生成失败"
        return 1
    fi
}

# 生成Reality客户端配置信息
generate_reality_client_config() {
    print_info "生成客户端配置信息..."
    
    local client_config_file="$WORK_DIR/reality-client.json"
    
    cat > "$client_config_file" << EOF
{
  "客户端配置信息": {
    "协议": "VLESS",
    "地址": "$IP_ADDRESS",
    "端口": $SERVER_PORT,
    "UUID": "$SERVER_UUID",
    "流控": "xtls-rprx-vision",
    "传输协议": "tcp",
    "TLS": "reality",
    "SNI": "$DOMAIN_NAME",
    "Fingerprint": "chrome",
    "PublicKey": "$SERVER_PUBLIC_KEY",
    "ShortId": "$SERVER_SHORT_ID",
    "SpiderX": "/"
  },
  "分享链接": "vless://$SERVER_UUID@$IP_ADDRESS:$SERVER_PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$DOMAIN_NAME&fp=chrome&pbk=$SERVER_PUBLIC_KEY&sid=$SERVER_SHORT_ID&type=tcp&headerType=none#Reality-$IP_ADDRESS"
}
EOF

    if [[ $? -eq 0 ]]; then
        print_success "客户端配置信息已保存到: $client_config_file"
        
        # 显示配置信息
        echo
        print_message $CYAN "Reality客户端配置信息:"
        print_separator
        print_message $WHITE "服务器地址: $IP_ADDRESS"
        print_message $WHITE "端口: $SERVER_PORT"
        print_message $WHITE "UUID: $SERVER_UUID"
        print_message $WHITE "流控: xtls-rprx-vision"
        print_message $WHITE "传输协议: tcp"
        print_message $WHITE "TLS: reality"
        print_message $WHITE "SNI: $DOMAIN_NAME"
        print_message $WHITE "Fingerprint: chrome"
        print_message $WHITE "PublicKey: $SERVER_PUBLIC_KEY"
        print_message $WHITE "ShortId: $SERVER_SHORT_ID"
        print_separator
        
        # 显示分享链接
        local share_link="vless://$SERVER_UUID@$IP_ADDRESS:$SERVER_PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$DOMAIN_NAME&fp=chrome&pbk=$SERVER_PUBLIC_KEY&sid=$SERVER_SHORT_ID&type=tcp&headerType=none#Reality-$IP_ADDRESS"
        print_message $GREEN "分享链接:"
        echo "$share_link"
        print_separator
        
        return 0
    else
        print_error "客户端配置信息生成失败"
        return 1
    fi
}

#================================================================
# Hysteria2协议配置生成功能
#================================================================

# 生成自签名证书
generate_self_signed_cert() {
    print_info "生成自签名证书..."
    
    local cert_dir="$WORK_DIR/certs"
    CERT_PATH="$cert_dir/server.crt"
    KEY_PATH="$cert_dir/server.key"
    
    # 生成私钥
    openssl genrsa -out "$KEY_PATH" 2048 2>/dev/null
    
    # 生成证书
    openssl req -new -x509 -key "$KEY_PATH" -out "$CERT_PATH" -days 3650 -subj "/C=US/ST=State/L=City/O=Organization/OU=Unit/CN=$IP_ADDRESS" 2>/dev/null
    
    if [[ -f "$CERT_PATH" && -f "$KEY_PATH" ]]; then
        chmod 600 "$KEY_PATH"
        chmod 644 "$CERT_PATH"
        print_success "自签名证书生成完成"
        return 0
    else
        print_error "自签名证书生成失败"
        return 1
    fi
}

# Hysteria2协议配置
configure_hysteria2() {
    print_title "配置Hysteria2协议"
    
    # 生成UUID
    SERVER_UUID=$(generate_uuid)
    if [[ -z "$SERVER_UUID" ]]; then
        print_error "UUID生成失败"
        return 1
    fi
    print_success "UUID生成成功: $SERVER_UUID"
    
    # 设置端口
    while true; do
        read -p "请输入Hysteria2端口 (默认随机生成): " input_port
        if [[ -z "$input_port" ]]; then
            SERVER_PORT=$(generate_random_port 10000 50000)
        else
            SERVER_PORT="$input_port"
        fi
        
        if [[ "$SERVER_PORT" =~ ^[0-9]+$ ]] && [[ "$SERVER_PORT" -ge 1 ]] && [[ "$SERVER_PORT" -le 65535 ]]; then
            if check_port_usage "$SERVER_PORT"; then
                print_warning "端口 $SERVER_PORT 已被占用，请选择其他端口"
                continue
            else
                print_success "端口设置: $SERVER_PORT"
                break
            fi
        else
            print_error "无效端口，请输入1-65535之间的数字"
        fi
    done
    
    # 设置密码
    while true; do
        read -p "请输入Hysteria2密码 (默认随机生成): " input_password
        if [[ -z "$input_password" ]]; then
            SERVER_PASSWORD=$(generate_random_string 16)
        else
            SERVER_PASSWORD="$input_password"
        fi
        
        if [[ ${#SERVER_PASSWORD} -ge 6 ]]; then
            print_success "密码设置完成"
            break
        else
            print_error "密码长度至少6位，请重新输入"
        fi
    done
    
    # 生成证书
    if ! generate_self_signed_cert; then
        return 1
    fi
    
    # 生成配置文件
    generate_hysteria2_config
    
    return $?
}

# 生成Hysteria2配置文件
generate_hysteria2_config() {
    print_info "生成Hysteria2配置文件..."
    
    cat > "$CONFIG_FILE" << EOF
{
  "log": {
    "level": "info",
    "timestamp": true,
    "output": "$LOG_FILE"
  },
  "inbounds": [
    {
      "type": "hysteria2",
      "tag": "hy2-in",
      "listen": "::",
      "listen_port": $SERVER_PORT,
      "users": [
        {
          "password": "$SERVER_PASSWORD"
        }
      ],
      "tls": {
        "enabled": true,
        "certificate_path": "$CERT_PATH",
        "key_path": "$KEY_PATH"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    }
  ]
}
EOF

    if [[ $? -eq 0 ]]; then
        print_success "Hysteria2配置文件生成完成"
        log_message "INFO" "Hysteria2配置文件生成成功"
        
        # 生成客户端配置信息
        generate_hysteria2_client_config
        
        return 0
    else
        print_error "Hysteria2配置文件生成失败"
        return 1
    fi
}

# 生成Hysteria2客户端配置信息
generate_hysteria2_client_config() {
    print_info "生成客户端配置信息..."
    
    local client_config_file="$WORK_DIR/hysteria2-client.json"
    
    cat > "$client_config_file" << EOF
{
  "客户端配置信息": {
    "协议": "Hysteria2",
    "地址": "$IP_ADDRESS",
    "端口": $SERVER_PORT,
    "密码": "$SERVER_PASSWORD",
    "TLS": "自签名证书",
    "跳过证书验证": true
  },
  "分享链接": "hysteria2://$SERVER_PASSWORD@$IP_ADDRESS:$SERVER_PORT/?insecure=1#Hysteria2-$IP_ADDRESS"
}
EOF

    if [[ $? -eq 0 ]]; then
        print_success "客户端配置信息已保存到: $client_config_file"
        
        # 显示配置信息
        echo
        print_message $CYAN "Hysteria2客户端配置信息:"
        print_separator
        print_message $WHITE "服务器地址: $IP_ADDRESS"
        print_message $WHITE "端口: $SERVER_PORT"
        print_message $WHITE "密码: $SERVER_PASSWORD"
        print_message $WHITE "TLS: 自签名证书"
        print_message $WHITE "跳过证书验证: 是"
        print_separator
        
        # 显示分享链接
        local share_link="hysteria2://$SERVER_PASSWORD@$IP_ADDRESS:$SERVER_PORT/?insecure=1#Hysteria2-$IP_ADDRESS"
        print_message $GREEN "分享链接:"
        echo "$share_link"
        print_separator
        
        return 0
    else
        print_error "客户端配置信息生成失败"
        return 1
    fi
}

#================================================================
# VMess WebSocket TLS协议配置生成功能
#================================================================

# VMess WebSocket TLS协议配置
configure_vmess_ws_tls() {
    print_title "配置VMess WebSocket TLS协议"
    
    # 生成UUID
    SERVER_UUID=$(generate_uuid)
    if [[ -z "$SERVER_UUID" ]]; then
        print_error "UUID生成失败"
        return 1
    fi
    print_success "UUID生成成功: $SERVER_UUID"
    
    # 设置端口
    while true; do
        read -p "请输入VMess端口 (默认443): " input_port
        SERVER_PORT=${input_port:-443}
        
        if [[ "$SERVER_PORT" =~ ^[0-9]+$ ]] && [[ "$SERVER_PORT" -ge 1 ]] && [[ "$SERVER_PORT" -le 65535 ]]; then
            if check_port_usage "$SERVER_PORT"; then
                print_warning "端口 $SERVER_PORT 已被占用，请选择其他端口"
                continue
            else
                print_success "端口设置: $SERVER_PORT"
                break
            fi
        else
            print_error "无效端口，请输入1-65535之间的数字"
        fi
    done
    
    # 设置WebSocket路径
    while true; do
        read -p "请输入WebSocket路径 (默认随机生成): " input_path
        if [[ -z "$input_path" ]]; then
            WS_PATH="/$(generate_random_string 8)"
        else
            if [[ "$input_path" =~ ^/.+ ]]; then
                WS_PATH="$input_path"
            else
                WS_PATH="/$input_path"
            fi
        fi
        print_success "WebSocket路径设置: $WS_PATH"
        break
    done
    
    # 生成证书
    if ! generate_self_signed_cert; then
        return 1
    fi
    
    # 生成配置文件
    generate_vmess_ws_tls_config
    
    return $?
}

# 生成VMess WebSocket TLS配置文件
generate_vmess_ws_tls_config() {
    print_info "生成VMess WebSocket TLS配置文件..."
    
    cat > "$CONFIG_FILE" << EOF
{
  "log": {
    "level": "info",
    "timestamp": true,
    "output": "$LOG_FILE"
  },
  "inbounds": [
    {
      "type": "vmess",
      "tag": "vmess-in",
      "listen": "::",
      "listen_port": $SERVER_PORT,
      "users": [
        {
          "uuid": "$SERVER_UUID",
          "alterId": 0
        }
      ],
      "transport": {
        "type": "ws",
        "path": "$WS_PATH"
      },
      "tls": {
        "enabled": true,
        "certificate_path": "$CERT_PATH",
        "key_path": "$KEY_PATH"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    }
  ]
}
EOF

    if [[ $? -eq 0 ]]; then
        print_success "VMess WebSocket TLS配置文件生成完成"
        log_message "INFO" "VMess WebSocket TLS配置文件生成成功"
        
        # 生成客户端配置信息
        generate_vmess_ws_tls_client_config
        
        return 0
    else
        print_error "VMess WebSocket TLS配置文件生成失败"
        return 1
    fi
}

# 生成VMess WebSocket TLS客户端配置信息
generate_vmess_ws_tls_client_config() {
    print_info "生成客户端配置信息..."
    
    local client_config_file="$WORK_DIR/vmess-ws-tls-client.json"
    
    # 生成VMess配置JSON
    local vmess_config=$(cat << EOF
{
  "v": "2",
  "ps": "VMess-WS-TLS-$IP_ADDRESS",
  "add": "$IP_ADDRESS",
  "port": "$SERVER_PORT",
  "id": "$SERVER_UUID",
  "aid": "0",
  "scy": "auto",
  "net": "ws",
  "type": "none",
  "host": "",
  "path": "$WS_PATH",
  "tls": "tls",
  "sni": "",
  "alpn": ""
}
EOF
)
    
    # Base64编码
    local vmess_link="vmess://$(echo -n "$vmess_config" | base64 -w 0)"
    
    cat > "$client_config_file" << EOF
{
  "客户端配置信息": {
    "协议": "VMess",
    "地址": "$IP_ADDRESS",
    "端口": $SERVER_PORT,
    "UUID": "$SERVER_UUID",
    "额外ID": 0,
    "加密方式": "auto",
    "传输协议": "ws",
    "WebSocket路径": "$WS_PATH",
    "TLS": "启用",
    "跳过证书验证": true
  },
  "分享链接": "$vmess_link"
}
EOF

    if [[ $? -eq 0 ]]; then
        print_success "客户端配置信息已保存到: $client_config_file"
        
        # 显示配置信息
        echo
        print_message $CYAN "VMess WebSocket TLS客户端配置信息:"
        print_separator
        print_message $WHITE "服务器地址: $IP_ADDRESS"
        print_message $WHITE "端口: $SERVER_PORT"
        print_message $WHITE "UUID: $SERVER_UUID"
        print_message $WHITE "额外ID: 0"
        print_message $WHITE "加密方式: auto"
        print_message $WHITE "传输协议: ws"
        print_message $WHITE "WebSocket路径: $WS_PATH"
        print_message $WHITE "TLS: 启用"
        print_separator
        
        # 显示分享链接
        print_message $GREEN "分享链接:"
        echo "$vmess_link"
        print_separator
        
        return 0
    else
        print_error "客户端配置信息生成失败"
        return 1
    fi
}

#================================================================
# systemd服务管理模块
#================================================================

# 启动sing-box服务
start_singbox_service() {
    print_info "启动sing-box服务..."
    
    if ! systemctl is-enabled "$SERVICE_NAME" >/dev/null 2>&1; then
        systemctl enable "$SERVICE_NAME"
        print_info "已设置开机自启"
    fi
    
    if systemctl start "$SERVICE_NAME"; then
        sleep 2
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            print_success "sing-box服务启动成功"
            log_message "INFO" "sing-box服务启动成功"
            return 0
        else
            print_error "sing-box服务启动失败"
            print_info "查看错误日志:"
            systemctl status "$SERVICE_NAME" --no-pager -l
            return 1
        fi
    else
        print_error "sing-box服务启动失败"
        return 1
    fi
}

# 停止sing-box服务
stop_singbox_service() {
    print_info "停止sing-box服务..."
    
    if systemctl stop "$SERVICE_NAME"; then
        print_success "sing-box服务已停止"
        log_message "INFO" "sing-box服务已停止"
        return 0
    else
        print_error "sing-box服务停止失败"
        return 1
    fi
}

# 重启sing-box服务
restart_singbox_service() {
    print_info "重启sing-box服务..."
    
    if systemctl restart "$SERVICE_NAME"; then
        sleep 2
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            print_success "sing-box服务重启成功"
            log_message "INFO" "sing-box服务重启成功"
            return 0
        else
            print_error "sing-box服务重启后状态异常"
            return 1
        fi
    else
        print_error "sing-box服务重启失败"
        return 1
    fi
}

# 查看服务状态
show_singbox_status() {
    print_title "sing-box服务状态"
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "服务状态: 运行中"
    else
        print_error "服务状态: 已停止"
    fi
    
    if systemctl is-enabled --quiet "$SERVICE_NAME"; then
        print_success "开机自启: 已启用"
    else
        print_warning "开机自启: 未启用"
    fi
    
    # 显示详细状态
    echo
    print_message $CYAN "详细状态信息:"
    systemctl status "$SERVICE_NAME" --no-pager -l
    
    # 显示端口监听情况
    echo
    print_message $CYAN "端口监听情况:"
    if command_exists "ss"; then
        ss -tuln | grep ":$SERVER_PORT " || print_warning "未检测到端口监听"
    elif command_exists "netstat"; then
        netstat -tuln | grep ":$SERVER_PORT " || print_warning "未检测到端口监听"
    fi
    
    read -p "按回车键继续..."
}

# 验证配置文件
validate_config() {
    print_info "验证配置文件..."
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "配置文件不存在: $CONFIG_FILE"
        return 1
    fi
    
    # 使用sing-box验证配置
    if "$SINGBOX_BINARY" check -c "$CONFIG_FILE" >/dev/null 2>&1; then
        print_success "配置文件验证通过"
        return 0
    else
        print_error "配置文件验证失败"
        print_info "错误详情:"
        "$SINGBOX_BINARY" check -c "$CONFIG_FILE"
        return 1
    fi
}

#================================================================
# 防火墙规则自动配置功能
#================================================================

# 配置防火墙规则
configure_firewall() {
    local port=$1
    local action=${2:-"allow"}  # allow 或 remove
    
    if [[ -z "$port" ]]; then
        print_error "端口参数为空"
        return 1
    fi
    
    print_info "配置防火墙规则 - 端口: $port, 操作: $action"
    
    case "$FIREWALL_TYPE" in
        "ufw")
            if [[ "$action" == "allow" ]]; then
                ufw allow "$port" >/dev/null 2>&1
                print_success "UFW规则已添加: 允许端口 $port"
            elif [[ "$action" == "remove" ]]; then
                ufw delete allow "$port" >/dev/null 2>&1
                print_success "UFW规则已删除: 端口 $port"
            fi
            ;;
        "firewalld")
            if [[ "$action" == "allow" ]]; then
                firewall-cmd --permanent --add-port="$port/tcp" >/dev/null 2>&1
                firewall-cmd --permanent --add-port="$port/udp" >/dev/null 2>&1
                firewall-cmd --reload >/dev/null 2>&1
                print_success "firewalld规则已添加: 允许端口 $port"
            elif [[ "$action" == "remove" ]]; then
                firewall-cmd --permanent --remove-port="$port/tcp" >/dev/null 2>&1
                firewall-cmd --permanent --remove-port="$port/udp" >/dev/null 2>&1
                firewall-cmd --reload >/dev/null 2>&1
                print_success "firewalld规则已删除: 端口 $port"
            fi
            ;;
        "iptables")
            if [[ "$action" == "allow" ]]; then
                iptables -I INPUT -p tcp --dport "$port" -j ACCEPT >/dev/null 2>&1
                iptables -I INPUT -p udp --dport "$port" -j ACCEPT >/dev/null 2>&1
                print_success "iptables规则已添加: 允许端口 $port"
            elif [[ "$action" == "remove" ]]; then
                iptables -D INPUT -p tcp --dport "$port" -j ACCEPT >/dev/null 2>&1
                iptables -D INPUT -p udp --dport "$port" -j ACCEPT >/dev/null 2>&1
                print_success "iptables规则已删除: 端口 $port"
            fi
            ;;
        "none")
            print_warning "未检测到防火墙，跳过规则配置"
            ;;
        *)
            print_warning "不支持的防火墙类型: $FIREWALL_TYPE"
            ;;
    esac
    
    return 0
}

# 保存iptables规则
save_iptables_rules() {
    if [[ "$FIREWALL_TYPE" == "iptables" ]]; then
        if command_exists "iptables-save"; then
            case "$OS_TYPE" in
                "debian")
                    iptables-save > /etc/iptables/rules.v4 2>/dev/null
                    ;;
                "centos")
                    service iptables save >/dev/null 2>&1 || systemctl save iptables >/dev/null 2>&1
                    ;;
            esac
            print_info "iptables规则已保存"
        fi
    fi
}

#================================================================
# 端口更换和配置更新功能
#================================================================

# 更换端口
change_service_port() {
    print_title "更换服务端口"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "配置文件不存在，请先安装sing-box"
        return 1
    fi
    
    # 获取当前端口
    local current_port
    current_port=$(jq -r '.inbounds[0].listen_port' "$CONFIG_FILE" 2>/dev/null)
    
    if [[ -z "$current_port" || "$current_port" == "null" ]]; then
        print_error "无法获取当前端口信息"
        return 1
    fi
    
    print_info "当前端口: $current_port"
    
    # 输入新端口
    while true; do
        read -p "请输入新端口 (1-65535): " new_port
        
        if [[ "$new_port" =~ ^[0-9]+$ ]] && [[ "$new_port" -ge 1 ]] && [[ "$new_port" -le 65535 ]]; then
            if [[ "$new_port" == "$current_port" ]]; then
                print_warning "新端口与当前端口相同"
                continue
            fi
            
            if check_port_usage "$new_port"; then
                print_warning "端口 $new_port 已被占用，请选择其他端口"
                continue
            else
                break
            fi
        else
            print_error "无效端口，请输入1-65535之间的数字"
        fi
    done
    
    # 停止服务
    print_info "停止sing-box服务..."
    systemctl stop "$SERVICE_NAME" >/dev/null 2>&1
    
    # 更新配置文件中的端口
    print_info "更新配置文件..."
    if jq ".inbounds[0].listen_port = $new_port" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"; then
        mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        print_success "配置文件更新完成"
    else
        print_error "配置文件更新失败"
        return 1
    fi
    
    # 更新防火墙规则
    configure_firewall "$current_port" "remove"
    configure_firewall "$new_port" "allow"
    save_iptables_rules
    
    # 验证配置
    if validate_config; then
        # 启动服务
        if start_singbox_service; then
            print_success "端口更换完成: $current_port -> $new_port"
            SERVER_PORT="$new_port"
            
            # 更新客户端配置
            update_client_config_after_port_change "$new_port"
            
            log_message "INFO" "端口更换成功: $current_port -> $new_port"
        else
            print_error "服务启动失败，正在回滚..."
            # 回滚配置
            jq ".inbounds[0].listen_port = $current_port" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
            mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
            configure_firewall "$new_port" "remove"
            configure_firewall "$current_port" "allow"
            start_singbox_service
            return 1
        fi
    else
        print_error "配置验证失败，正在回滚..."
        # 回滚配置
        jq ".inbounds[0].listen_port = $current_port" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
        mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        start_singbox_service
        return 1
    fi
    
    read -p "按回车键继续..."
    return 0
}

# 端口更换后更新客户端配置
update_client_config_after_port_change() {
    local new_port=$1
    
    print_info "更新客户端配置信息..."
    
    # 检测协议类型
    local protocol_type
    protocol_type=$(jq -r '.inbounds[0].type' "$CONFIG_FILE" 2>/dev/null)
    
    case "$protocol_type" in
        "vless")
            # Reality协议
            if [[ -f "$WORK_DIR/reality-client.json" ]]; then
                local uuid=$(jq -r '.inbounds[0].users[0].uuid' "$CONFIG_FILE")
                local public_key=$(jq -r '.inbounds[0].tls.reality.public_key' "$CONFIG_FILE" 2>/dev/null)
                local short_id=$(jq -r '.inbounds[0].tls.reality.short_id[0]' "$CONFIG_FILE" 2>/dev/null)
                local sni=$(jq -r '.inbounds[0].tls.server_name' "$CONFIG_FILE" 2>/dev/null)
                
                # 更新分享链接
                local share_link="vless://$uuid@$IP_ADDRESS:$new_port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$sni&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#Reality-$IP_ADDRESS"
                
                jq ".客户端配置信息.端口 = $new_port | .分享链接 = \"$share_link\"" "$WORK_DIR/reality-client.json" > "$WORK_DIR/reality-client.json.tmp"
                mv "$WORK_DIR/reality-client.json.tmp" "$WORK_DIR/reality-client.json"
            fi
            ;;
        "hysteria2")
            # Hysteria2协议
            if [[ -f "$WORK_DIR/hysteria2-client.json" ]]; then
                local password=$(jq -r '.inbounds[0].users[0].password' "$CONFIG_FILE")
                local share_link="hysteria2://$password@$IP_ADDRESS:$new_port/?insecure=1#Hysteria2-$IP_ADDRESS"
                
                jq ".客户端配置信息.端口 = $new_port | .分享链接 = \"$share_link\"" "$WORK_DIR/hysteria2-client.json" > "$WORK_DIR/hysteria2-client.json.tmp"
                mv "$WORK_DIR/hysteria2-client.json.tmp" "$WORK_DIR/hysteria2-client.json"
            fi
            ;;
        "vmess")
            # VMess协议
            if [[ -f "$WORK_DIR/vmess-ws-tls-client.json" ]]; then
                local uuid=$(jq -r '.inbounds[0].users[0].uuid' "$CONFIG_FILE")
                local ws_path=$(jq -r '.inbounds[0].transport.path' "$CONFIG_FILE")
                
                # 重新生成VMess链接
                local vmess_config=$(cat << EOF
{
  "v": "2",
  "ps": "VMess-WS-TLS-$IP_ADDRESS",
  "add": "$IP_ADDRESS",
  "port": "$new_port",
  "id": "$uuid",
  "aid": "0",
  "scy": "auto",
  "net": "ws",
  "type": "none",
  "host": "",
  "path": "$ws_path",
  "tls": "tls",
  "sni": "",
  "alpn": ""
}
EOF
)
                local vmess_link="vmess://$(echo -n "$vmess_config" | base64 -w 0)"
                
                jq ".客户端配置信息.端口 = $new_port | .分享链接 = \"$vmess_link\"" "$WORK_DIR/vmess-ws-tls-client.json" > "$WORK_DIR/vmess-ws-tls-client.json.tmp"
                mv "$WORK_DIR/vmess-ws-tls-client.json.tmp" "$WORK_DIR/vmess-ws-tls-client.json"
            fi
            ;;
    esac
    
    print_success "客户端配置信息已更新"
}

#================================================================
# 内核升级和版本管理功能
#================================================================

# 升级sing-box内核
upgrade_singbox_kernel() {
    print_title "升级sing-box内核"
    
    # 检查当前版本
    if [[ ! -f "$SINGBOX_BINARY" ]]; then
        print_error "sing-box未安装，请先安装"
        return 1
    fi
    
    local current_version
    current_version=$("$SINGBOX_BINARY" version 2>/dev/null | head -1 | grep -oP 'sing-box version \K[0-9]+\.[0-9]+\.[0-9]+')
    
    if [[ -z "$current_version" ]]; then
        print_error "无法获取当前版本信息"
        return 1
    fi
    
    print_info "当前版本: v$current_version"
    
    # 获取最新版本
    if ! get_latest_version; then
        return 1
    fi
    
    local latest_version=${SINGBOX_VERSION#v}
    
    if [[ "$current_version" == "$latest_version" ]]; then
        print_success "当前已是最新版本"
        read -p "按回车键继续..."
        return 0
    fi
    
    print_info "最新版本: $SINGBOX_VERSION"
    
    # 确认升级
    echo
    read -p "是否确认升级到最新版本? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "取消升级"
        return 0
    fi
    
    # 备份当前版本
    print_info "备份当前版本..."
    cp "$SINGBOX_BINARY" "${SINGBOX_BINARY}.backup.v${current_version}"
    
    # 停止服务
    print_info "停止sing-box服务..."
    systemctl stop "$SERVICE_NAME" >/dev/null 2>&1
    
    # 下载新版本
    if download_singbox "$SINGBOX_VERSION"; then
        # 验证新版本
        if "$SINGBOX_BINARY" version >/dev/null 2>&1; then
            local new_version
            new_version=$("$SINGBOX_BINARY" version 2>/dev/null | head -1)
            print_success "内核升级成功: $new_version"
            
            # 验证配置文件兼容性
            if validate_config; then
                # 启动服务
                if start_singbox_service; then
                    print_success "升级完成，服务已重新启动"
                    log_message "INFO" "sing-box内核升级成功: v$current_version -> $SINGBOX_VERSION"
                    
                    # 清理备份文件
                    rm -f "${SINGBOX_BINARY}.backup.v${current_version}"
                else
                    print_error "服务启动失败，正在回滚..."
                    rollback_kernel "$current_version"
                    return 1
                fi
            else
                print_error "配置文件不兼容，正在回滚..."
                rollback_kernel "$current_version"
                return 1
            fi
        else
            print_error "新版本验证失败，正在回滚..."
            rollback_kernel "$current_version"
            return 1
        fi
    else
        print_error "下载失败，正在回滚..."
        rollback_kernel "$current_version"
        return 1
    fi
    
    read -p "按回车键继续..."
    return 0
}

# 回滚内核版本
rollback_kernel() {
    local backup_version=$1
    
    print_info "回滚到版本: v$backup_version"
    
    if [[ -f "${SINGBOX_BINARY}.backup.v${backup_version}" ]]; then
        cp "${SINGBOX_BINARY}.backup.v${backup_version}" "$SINGBOX_BINARY"
        chmod +x "$SINGBOX_BINARY"
        
        if start_singbox_service; then
            print_success "回滚成功，服务已恢复"
        else
            print_error "回滚后服务启动失败"
        fi
        
        # 清理备份文件
        rm -f "${SINGBOX_BINARY}.backup.v${backup_version}"
    else
        print_error "备份文件不存在，无法回滚"
    fi
}

#================================================================
# 状态查看和日志监控功能
#================================================================

# 显示配置信息
show_configuration_info() {
    print_title "sing-box配置信息"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "配置文件不存在"
        return 1
    fi
    
    # 获取协议类型
    local protocol_type
    protocol_type=$(jq -r '.inbounds[0].type' "$CONFIG_FILE" 2>/dev/null)
    
    print_info "协议类型: $protocol_type"
    print_info "配置文件: $CONFIG_FILE"
    print_info "日志文件: $LOG_FILE"
    print_separator
    
    case "$protocol_type" in
        "vless")
            print_message $CYAN "Reality协议配置:"
            if [[ -f "$WORK_DIR/reality-client.json" ]]; then
                cat "$WORK_DIR/reality-client.json" | jq '.'
            else
                print_warning "客户端配置文件不存在"
            fi
            ;;
        "hysteria2")
            print_message $CYAN "Hysteria2协议配置:"
            if [[ -f "$WORK_DIR/hysteria2-client.json" ]]; then
                cat "$WORK_DIR/hysteria2-client.json" | jq '.'
            else
                print_warning "客户端配置文件不存在"
            fi
            ;;
        "vmess")
            print_message $CYAN "VMess WebSocket TLS协议配置:"
            if [[ -f "$WORK_DIR/vmess-ws-tls-client.json" ]]; then
                cat "$WORK_DIR/vmess-ws-tls-client.json" | jq '.'
            else
                print_warning "客户端配置文件不存在"
            fi
            ;;
        *)
            print_warning "未知协议类型: $protocol_type"
            ;;
    esac
    
    echo
    read -p "按回车键继续..."
}

# 查看日志
show_service_logs() {
    print_title "sing-box服务日志"
    
    echo
    print_message $CYAN "请选择查看方式:"
    print_message $WHITE "1. 查看实时日志 (tail -f)"
    print_message $WHITE "2. 查看最近50行日志"
    print_message $WHITE "3. 查看systemd日志"
    print_message $WHITE "4. 查看错误日志"
    print_message $WHITE "0. 返回主菜单"
    echo
    
    read -p "请选择 [0-4]: " log_choice
    
    case $log_choice in
        1)
            print_info "实时日志 (按Ctrl+C退出):"
            echo
            if [[ -f "$LOG_FILE" ]]; then
                tail -f "$LOG_FILE"
            else
                print_warning "日志文件不存在"
            fi
            ;;
        2)
            print_info "最近50行日志:"
            echo
            if [[ -f "$LOG_FILE" ]]; then
                tail -n 50 "$LOG_FILE"
            else
                print_warning "日志文件不存在"
            fi
            read -p "按回车键继续..."
            ;;
        3)
            print_info "systemd服务日志:"
            echo
            journalctl -u "$SERVICE_NAME" -n 50 --no-pager
            read -p "按回车键继续..."
            ;;
        4)
            print_info "错误日志:"
            echo
            if [[ -f "$LOG_FILE" ]]; then
                grep -i "error\|fail\|fatal" "$LOG_FILE" | tail -n 20
            else
                print_warning "日志文件不存在"
            fi
            read -p "按回车键继续..."
            ;;
        0)
            return 0
            ;;
        *)
            print_error "无效选项"
            ;;
    esac
}

#================================================================
# 配置备份和恢复功能
#================================================================

# 备份配置
backup_configuration() {
    print_title "备份配置"
    
    local backup_name="singbox-backup-$(date +%Y%m%d-%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    print_info "创建备份: $backup_name"
    
    # 创建备份目录
    mkdir -p "$backup_path"
    
    # 备份配置文件
    if [[ -f "$CONFIG_FILE" ]]; then
        cp "$CONFIG_FILE" "$backup_path/"
        print_success "配置文件已备份"
    fi
    
    # 备份客户端配置
    for client_file in "$WORK_DIR"/*-client.json; do
        if [[ -f "$client_file" ]]; then
            cp "$client_file" "$backup_path/"
        fi
    done
    
    # 备份证书文件
    if [[ -d "$WORK_DIR/certs" ]]; then
        cp -r "$WORK_DIR/certs" "$backup_path/"
        print_success "证书文件已备份"
    fi
    
    # 备份systemd服务文件
    if [[ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]]; then
        cp "/etc/systemd/system/${SERVICE_NAME}.service" "$backup_path/"
        print_success "systemd服务文件已备份"
    fi
    
    # 创建备份信息文件
    cat > "$backup_path/backup-info.txt" << EOF
备份时间: $(date '+%Y-%m-%d %H:%M:%S')
脚本版本: $SCRIPT_VERSION
sing-box版本: $("$SINGBOX_BINARY" version 2>/dev/null | head -1 || echo "未知")
系统信息: $SYSTEM_INFO
服务器IP: $IP_ADDRESS
备份内容:
$(ls -la "$backup_path")
EOF

    # 压缩备份
    cd "$BACKUP_DIR"
    if tar -czf "${backup_name}.tar.gz" "$backup_name" 2>/dev/null; then
        rm -rf "$backup_path"
        print_success "备份完成: $BACKUP_DIR/${backup_name}.tar.gz"
        log_message "INFO" "配置备份完成: ${backup_name}.tar.gz"
    else
        print_success "备份完成: $backup_path"
        log_message "INFO" "配置备份完成: $backup_path"
    fi
    
    read -p "按回车键继续..."
}

# 恢复配置
restore_configuration() {
    print_title "恢复配置"
    
    # 列出可用备份
    print_info "可用备份列表:"
    echo
    
    local backup_files=()
    local counter=1
    
    # 查找压缩备份
    for backup in "$BACKUP_DIR"/singbox-backup-*.tar.gz; do
        if [[ -f "$backup" ]]; then
            backup_files+=("$backup")
            print_message $WHITE "$counter. $(basename "$backup")"
            ((counter++))
        fi
    done
    
    # 查找目录备份
    for backup in "$BACKUP_DIR"/singbox-backup-*; do
        if [[ -d "$backup" ]]; then
            backup_files+=("$backup")
            print_message $WHITE "$counter. $(basename "$backup")"
            ((counter++))
        fi
    done
    
    if [[ ${#backup_files[@]} -eq 0 ]]; then
        print_warning "未找到备份文件"
        read -p "按回车键继续..."
        return 1
    fi
    
    echo
    print_message $WHITE "0. 返回主菜单"
    echo
    
    read -p "请选择要恢复的备份 [0-$((counter-1))]: " backup_choice
    
    if [[ "$backup_choice" == "0" ]]; then
        return 0
    fi
    
    if [[ "$backup_choice" =~ ^[0-9]+$ ]] && [[ "$backup_choice" -ge 1 ]] && [[ "$backup_choice" -le ${#backup_files[@]} ]]; then
        local selected_backup="${backup_files[$((backup_choice-1))]}"
        
        print_warning "恢复配置将覆盖当前配置，是否继续?"
        read -p "请确认 [y/N]: " confirm
        
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            print_info "取消恢复"
            return 0
        fi
        
        # 停止服务
        print_info "停止sing-box服务..."
        systemctl stop "$SERVICE_NAME" >/dev/null 2>&1
        
        # 恢复配置
        print_info "恢复配置文件..."
        
        local temp_dir="/tmp/singbox-restore-$$"
        mkdir -p "$temp_dir"
        
        if [[ "$selected_backup" == *.tar.gz ]]; then
            # 解压备份
            tar -xzf "$selected_backup" -C "$temp_dir" 2>/dev/null
            local backup_content="$temp_dir/$(basename "$selected_backup" .tar.gz)"
        else
            # 目录备份
            local backup_content="$selected_backup"
        fi
        
        # 恢复文件
        if [[ -f "$backup_content/config.json" ]]; then
            cp "$backup_content/config.json" "$CONFIG_FILE"
            print_success "配置文件已恢复"
        fi
        
        # 恢复客户端配置
        for client_file in "$backup_content"/*-client.json; do
            if [[ -f "$client_file" ]]; then
                cp "$client_file" "$WORK_DIR/"
            fi
        done
        
        # 恢复证书
        if [[ -d "$backup_content/certs" ]]; then
            cp -r "$backup_content/certs" "$WORK_DIR/"
            print_success "证书文件已恢复"
        fi
        
        # 恢复systemd服务文件
        if [[ -f "$backup_content/${SERVICE_NAME}.service" ]]; then
            cp "$backup_content/${SERVICE_NAME}.service" "/etc/systemd/system/"
            systemctl daemon-reload
            print_success "systemd服务文件已恢复"
        fi
        
        # 清理临时文件
        rm -rf "$temp_dir"
        
        # 验证配置
        if validate_config; then
            # 启动服务
            if start_singbox_service; then
                print_success "配置恢复完成，服务已启动"
                log_message "INFO" "配置恢复成功: $(basename "$selected_backup")"
            else
                print_error "服务启动失败"
            fi
        else
            print_error "配置文件验证失败"
        fi
        
    else
        print_error "无效选择"
    fi
    
    read -p "按回车键继续..."
}

#================================================================
# 完整的卸载和清理功能
#================================================================

# 卸载sing-box
uninstall_singbox_complete() {
    print_title "卸载sing-box"
    
    print_warning "此操作将完全删除sing-box及其所有配置文件"
    print_warning "包括: 程序文件、配置文件、日志文件、证书文件等"
    echo
    read -p "是否确认卸载? [y/N]: " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "取消卸载"
        return 0
    fi
    
    # 再次确认
    read -p "请再次确认卸载 (输入 YES 确认): " final_confirm
    if [[ "$final_confirm" != "YES" ]]; then
        print_info "取消卸载"
        return 0
    fi
    
    print_info "开始卸载sing-box..."
    
    # 停止并禁用服务
    print_info "停止服务..."
    systemctl stop "$SERVICE_NAME" >/dev/null 2>&1
    systemctl disable "$SERVICE_NAME" >/dev/null 2>&1
    
    # 删除systemd服务文件
    if [[ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]]; then
        rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
        systemctl daemon-reload
        print_success "systemd服务文件已删除"
    fi
    
    # 删除程序文件
    if [[ -f "$SINGBOX_BINARY" ]]; then
        rm -f "$SINGBOX_BINARY"
        print_success "程序文件已删除"
    fi
    
    # 删除配置目录
    if [[ -d "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR"
        print_success "配置目录已删除"
    fi
    
    # 删除日志目录
    if [[ -d "$LOG_DIR" ]]; then
        rm -rf "$LOG_DIR"
        print_success "日志目录已删除"
    fi
    
    # 清理防火墙规则
    if [[ -n "$SERVER_PORT" ]]; then
        configure_firewall "$SERVER_PORT" "remove"
        save_iptables_rules
        print_success "防火墙规则已清理"
    fi
    
    print_success "sing-box卸载完成"
    log_message "INFO" "sing-box完全卸载"
    
    read -p "按回车键继续..."
}

#================================================================
# 主要功能函数实现
#================================================================

# 安装sing-box主函数
install_singbox() {
    print_title "安装sing-box"
    
    # 系统检查
    if ! system_check; then
        return 1
    fi
    
    # 检查是否已安装
    if check_singbox_installed; then
        read -p "sing-box已安装，是否重新安装? [y/N]: " reinstall
        if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    # 获取最新版本并下载
    if ! get_latest_version; then
        return 1
    fi
    
    if ! download_singbox; then
        return 1
    fi
    
    # 创建systemd服务
    if ! create_systemd_service; then
        return 1
    fi
    
    # 选择协议
    while true; do
        show_protocol_menu
        read -p "请选择协议 [1-3]: " protocol_choice
        
        case $protocol_choice in
            1)
                PROTOCOL_TYPE="reality"
                if configure_reality; then
                    break
                else
                    print_error "Reality协议配置失败"
                    return 1
                fi
                ;;
            2)
                PROTOCOL_TYPE="hysteria2"
                if configure_hysteria2; then
                    break
                else
                    print_error "Hysteria2协议配置失败"
                    return 1
                fi
                ;;
            3)
                PROTOCOL_TYPE="vmess"
                if configure_vmess_ws_tls; then
                    break
                else
                    print_error "VMess协议配置失败"
                    return 1
                fi
                ;;
            *)
                print_error "无效选项，请重新选择"
                ;;
        esac
    done
    
    # 配置防火墙
    configure_firewall "$SERVER_PORT" "allow"
    save_iptables_rules
    
    # 启动服务
    if start_singbox_service; then
        print_success "sing-box安装完成!"
        print_info "协议: $PROTOCOL_TYPE"
        print_info "端口: $SERVER_PORT"
        print_info "配置文件: $CONFIG_FILE"
        log_message "INFO" "sing-box安装成功 - 协议: $PROTOCOL_TYPE, 端口: $SERVER_PORT"
    else
        print_error "服务启动失败"
        return 1
    fi
    
    read -p "按回车键继续..."
}

# 更新占位函数为实际实现
start_service() {
    start_singbox_service
}

stop_service() {
    stop_singbox_service
}

restart_service() {
    restart_singbox_service
}

show_service_status() {
    show_singbox_status
}

show_config_info() {
    show_configuration_info
}

show_logs() {
    show_service_logs
}

change_port() {
    change_service_port
}

upgrade_kernel() {
    upgrade_singbox_kernel
}

backup_config() {
    backup_configuration
}

restore_config() {
    restore_configuration
}

uninstall_singbox() {
    uninstall_singbox_complete
}
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
        
        read -p "请输入选项 [0-12]: " choice
        
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
# 占位函数 - 将在后续步骤中实现
#================================================================

install_singbox() {
    print_warning "安装功能正在开发中..."
    sleep 2
}

uninstall_singbox() {
    print_warning "卸载功能正在开发中..."
    sleep 2
}

start_service() {
    print_warning "启动服务功能正在开发中..."
    sleep 2
}

stop_service() {
    print_warning "停止服务功能正在开发中..."
    sleep 2
}

restart_service() {
    print_warning "重启服务功能正在开发中..."
    sleep 2
}

show_service_status() {
    print_warning "查看状态功能正在开发中..."
    sleep 2
}

show_config_info() {
    print_warning "查看配置功能正在开发中..."
    sleep 2
}

show_logs() {
    print_warning "查看日志功能正在开发中..."
    sleep 2
}

change_port() {
    print_warning "更换端口功能正在开发中..."
    sleep 2
}

upgrade_kernel() {
    print_warning "升级内核功能正在开发中..."
    sleep 2
}

backup_config() {
    print_warning "备份配置功能正在开发中..."
    sleep 2
}

restore_config() {
    print_warning "恢复配置功能正在开发中..."
    sleep 2
}

#================================================================
# 脚本入口
#================================================================

# 捕获退出信号
trap 'print_info "脚本已退出"; exit 0' INT TERM

# 启动主函数
main "$@"