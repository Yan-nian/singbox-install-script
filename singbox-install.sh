#!/bin/bash

#================================================================
# sing-box 服务器端一键部署脚本
# 支持协议: Reality, Hysteria2, VMess WebSocket TLS
# 作者: CodeBuddy
# 版本: 1.2.0
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
SCRIPT_VERSION="1.3.0"
SCRIPT_NAME="sing-box一键部署脚本"
SCRIPT_BUILD_DATE="2024-01-16"
SCRIPT_AUTHOR="CodeBuddy"
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
FIREWALL_TYPE=""

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
    print_info "脚本版本: $SCRIPT_VERSION (构建日期: $SCRIPT_BUILD_DATE)"
    print_info "脚本作者: $SCRIPT_AUTHOR"
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
    print_message $WHITE "2. 配置代理协议"
    print_message $WHITE "3. 卸载 sing-box"
    print_message $WHITE "4. 启动服务"
    print_message $WHITE "5. 停止服务"
    print_message $WHITE "6. 重启服务"
    print_message $WHITE "7. 查看服务状态"
    print_message $WHITE "8. 查看配置信息"
    print_message $WHITE "9. 查看日志"
    print_message $WHITE "10. 更换端口"
    print_message $WHITE "11. 升级内核"
    print_message $WHITE "12. 备份配置"
    print_message $WHITE "13. 恢复配置"
    print_message $WHITE "14. 生成分享二维码"
    print_message $WHITE "15. 查看版本信息"
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
# 协议配置功能
#================================================================

# 配置协议主函数
configure_protocol() {
    print_title "配置代理协议"
    
    show_protocol_menu
    read -p "请选择协议 [1-3]: " protocol_choice
    
    case $protocol_choice in
        1)
            configure_reality
            ;;
        2)
            configure_hysteria2
            ;;
        3)
            configure_vmess_ws_tls
            ;;
        *)
            print_error "无效选项"
            return 1
            ;;
    esac
}

# 配置Reality协议
configure_reality() {
    print_title "配置Reality协议"
    
    # 生成配置参数
    SERVER_PORT=$(generate_random_port 1000 65535)
    SERVER_UUID=$(generate_uuid)
    
    # 生成Reality密钥对
    print_info "生成Reality密钥对..."
    local key_pair=$("$SINGBOX_BINARY" generate reality-keypair 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        SERVER_PRIVATE_KEY=$(echo "$key_pair" | grep "PrivateKey:" | awk '{print $2}')
        SERVER_PUBLIC_KEY=$(echo "$key_pair" | grep "PublicKey:" | awk '{print $2}')
    else
        print_error "生成密钥对失败"
        return 1
    fi
    
    # 生成短ID
    SERVER_SHORT_ID=$(openssl rand -hex 8)
    DOMAIN_NAME="www.microsoft.com"
    
    print_info "Reality协议配置参数:"
    print_info "端口: $SERVER_PORT"
    print_info "UUID: $SERVER_UUID"
    print_info "目标域名: $DOMAIN_NAME"
    print_info "短ID: $SERVER_SHORT_ID"
    
    # 生成服务器配置
    generate_reality_server_config
    
    # 生成客户端配置
    generate_reality_client_config
    
    # 配置防火墙
    configure_firewall "$SERVER_PORT"
    
    print_success "Reality协议配置完成"
    PROTOCOL_TYPE="reality"
}

# 配置Hysteria2协议
configure_hysteria2() {
    print_title "配置Hysteria2协议"
    
    # 生成配置参数
    SERVER_PORT=$(generate_random_port 1000 65535)
    SERVER_PASSWORD=$(generate_random_string 16)
    
    print_info "Hysteria2协议配置参数:"
    print_info "端口: $SERVER_PORT"
    print_info "密码: $SERVER_PASSWORD"
    
    # 生成自签名证书
    generate_self_signed_cert
    
    # 生成服务器配置
    generate_hysteria2_server_config
    
    # 生成客户端配置
    generate_hysteria2_client_config
    
    # 配置防火墙
    configure_firewall "$SERVER_PORT" "udp"
    
    print_success "Hysteria2协议配置完成"
    PROTOCOL_TYPE="hysteria2"
}

# 配置VMess WebSocket TLS协议
configure_vmess_ws_tls() {
    print_title "配置VMess WebSocket TLS协议"
    
    # 生成配置参数
    SERVER_PORT=443
    SERVER_UUID=$(generate_uuid)
    WS_PATH="/$(generate_random_string 8)"
    
    print_info "VMess WebSocket TLS协议配置参数:"
    print_info "端口: $SERVER_PORT"
    print_info "UUID: $SERVER_UUID"
    print_info "WebSocket路径: $WS_PATH"
    
    # 生成自签名证书
    generate_self_signed_cert
    
    # 生成服务器配置
    generate_vmess_server_config
    
    # 生成客户端配置
    generate_vmess_client_config
    
    # 配置防火墙
    configure_firewall "$SERVER_PORT"
    
    print_success "VMess WebSocket TLS协议配置完成"
    PROTOCOL_TYPE="vmess"
}

# 生成自签名证书
generate_self_signed_cert() {
    print_info "生成自签名证书..."
    
    CERT_PATH="$WORK_DIR/certs/cert.pem"
    KEY_PATH="$WORK_DIR/certs/key.pem"
    
    # 创建证书目录
    mkdir -p "$WORK_DIR/certs"
    
    # 生成私钥和证书
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$KEY_PATH" \
        -out "$CERT_PATH" \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=$IP_ADDRESS" \
        >/dev/null 2>&1
    
    if [[ $? -eq 0 ]]; then
        print_success "证书生成完成"
        chmod 600 "$KEY_PATH"
        chmod 644 "$CERT_PATH"
    else
        print_error "证书生成失败"
        return 1
    fi
}

# 生成Reality服务器配置
generate_reality_server_config() {
    cat > "$CONFIG_FILE" << EOF
{
  "log": {
    "level": "info",
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
          "short_id": ["$SERVER_SHORT_ID"]
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF
    print_success "Reality服务器配置文件已生成"
}

# 生成Reality客户端配置
generate_reality_client_config() {
    local client_config="$WORK_DIR/reality-client.json"
    cat > "$client_config" << EOF
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "mixed",
      "listen": "127.0.0.1",
      "listen_port": 1080
    }
  ],
  "outbounds": [
    {
      "type": "vless",
      "server": "$IP_ADDRESS",
      "server_port": $SERVER_PORT,
      "uuid": "$SERVER_UUID",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "$DOMAIN_NAME",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        },
        "reality": {
          "enabled": true,
          "public_key": "$SERVER_PUBLIC_KEY",
          "short_id": "$SERVER_SHORT_ID"
        }
      }
    }
  ]
}
EOF
    print_success "Reality客户端配置文件已生成: $client_config"
}

# 生成Hysteria2服务器配置
generate_hysteria2_server_config() {
    cat > "$CONFIG_FILE" << EOF
{
  "log": {
    "level": "info",
    "output": "$LOG_FILE"
  },
  "inbounds": [
    {
      "type": "hysteria2",
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
    }
  ]
}
EOF
    print_success "Hysteria2服务器配置文件已生成"
}

# 生成Hysteria2客户端配置
generate_hysteria2_client_config() {
    local client_config="$WORK_DIR/hysteria2-client.json"
    cat > "$client_config" << EOF
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "mixed",
      "listen": "127.0.0.1",
      "listen_port": 1080
    }
  ],
  "outbounds": [
    {
      "type": "hysteria2",
      "server": "$IP_ADDRESS",
      "server_port": $SERVER_PORT,
      "password": "$SERVER_PASSWORD",
      "tls": {
        "enabled": true,
        "server_name": "$IP_ADDRESS",
        "insecure": true
      }
    }
  ]
}
EOF
    print_success "Hysteria2客户端配置文件已生成: $client_config"
}

# 生成VMess服务器配置
generate_vmess_server_config() {
    cat > "$CONFIG_FILE" << EOF
{
  "log": {
    "level": "info",
    "output": "$LOG_FILE"
  },
  "inbounds": [
    {
      "type": "vmess",
      "listen": "::",
      "listen_port": $SERVER_PORT,
      "users": [
        {
          "uuid": "$SERVER_UUID"
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
    }
  ]
}
EOF
    print_success "VMess服务器配置文件已生成"
}

# 生成VMess客户端配置
generate_vmess_client_config() {
    local client_config="$WORK_DIR/vmess-client.json"
    cat > "$client_config" << EOF
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "mixed",
      "listen": "127.0.0.1",
      "listen_port": 1080
    }
  ],
  "outbounds": [
    {
      "type": "vmess",
      "server": "$IP_ADDRESS",
      "server_port": $SERVER_PORT,
      "uuid": "$SERVER_UUID",
      "transport": {
        "type": "ws",
        "path": "$WS_PATH"
      },
      "tls": {
        "enabled": true,
        "server_name": "$IP_ADDRESS",
        "insecure": true
      }
    }
  ]
}
EOF
    print_success "VMess客户端配置文件已生成: $client_config"
}

# 配置防火墙
configure_firewall() {
    local port=$1
    local protocol=${2:-tcp}
    
    print_info "配置防火墙规则..."
    
    case "$FIREWALL_TYPE" in
        "ufw")
            ufw allow "$port/$protocol" >/dev/null 2>&1
            print_success "UFW防火墙规则已添加: $port/$protocol"
            ;;
        "firewalld")
            firewall-cmd --permanent --add-port="$port/$protocol" >/dev/null 2>&1
            firewall-cmd --reload >/dev/null 2>&1
            print_success "firewalld防火墙规则已添加: $port/$protocol"
            ;;
        "iptables")
            if [[ "$protocol" == "tcp" ]]; then
                iptables -I INPUT -p tcp --dport "$port" -j ACCEPT >/dev/null 2>&1
            else
                iptables -I INPUT -p udp --dport "$port" -j ACCEPT >/dev/null 2>&1
            fi
            print_success "iptables防火墙规则已添加: $port/$protocol"
            ;;
        "none")
            print_warning "未检测到防火墙，请手动开放端口: $port/$protocol"
            ;;
    esac
}

#================================================================
# 主要功能函数实现
#================================================================

# 安装sing-box主函数
install_singbox() {
    print_title "安装sing-box"
    
    # 系统检查
    if ! system_check; then
        read -p "按回车键继续..."
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
        read -p "按回车键继续..."
        return 1
    fi
    
    if ! download_singbox; then
        read -p "按回车键继续..."
        return 1
    fi
    
    # 创建systemd服务
    if ! create_systemd_service; then
        read -p "按回车键继续..."
        return 1
    fi
    
    print_success "sing-box安装完成!"
    print_info "现在需要配置代理协议"
    
    # 询问是否立即配置协议
    read -p "是否立即配置代理协议? [Y/n]: " configure_now
    if [[ "$configure_now" =~ ^[Nn]$ ]]; then
        print_info "您可以稍后通过主菜单配置协议"
        read -p "按回车键继续..."
        return 0
    fi
    
    # 显示协议选择菜单并配置
    configure_protocol
}

# 卸载sing-box
uninstall_singbox() {
    print_title "卸载sing-box"
    
    print_warning "此操作将完全删除sing-box及其所有配置文件"
    read -p "是否确认卸载? [y/N]: " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "取消卸载"
        read -p "按回车键继续..."
        return 0
    fi
    
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
    
    print_success "sing-box卸载完成"
    read -p "按回车键继续..."
}

# 启动服务
start_service() {
    print_title "启动服务"
    
    if [[ ! -f "$SINGBOX_BINARY" ]]; then
        print_error "sing-box未安装，请先安装"
        read -p "按回车键继续..."
        return 1
    fi
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "配置文件不存在，请先配置协议"
        read -p "按回车键继续..."
        return 1
    fi
    
    print_info "启动sing-box服务..."
    
    if ! systemctl is-enabled "$SERVICE_NAME" >/dev/null 2>&1; then
        systemctl enable "$SERVICE_NAME"
        print_info "已设置开机自启"
    fi
    
    if systemctl start "$SERVICE_NAME"; then
        sleep 2
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            print_success "sing-box服务启动成功"
        else
            print_error "sing-box服务启动失败"
            systemctl status "$SERVICE_NAME" --no-pager -l
        fi
    else
        print_error "sing-box服务启动失败"
    fi
    
    read -p "按回车键继续..."
}

# 停止服务
stop_service() {
    print_title "停止服务"
    
    print_info "停止sing-box服务..."
    
    if systemctl stop "$SERVICE_NAME"; then
        print_success "sing-box服务已停止"
    else
        print_error "sing-box服务停止失败"
    fi
    
    read -p "按回车键继续..."
}

# 重启服务
restart_service() {
    print_title "重启服务"
    
    print_info "重启sing-box服务..."
    
    if systemctl restart "$SERVICE_NAME"; then
        sleep 2
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            print_success "sing-box服务重启成功"
        else
            print_error "sing-box服务重启后状态异常"
        fi
    else
        print_error "sing-box服务重启失败"
    fi
    
    read -p "按回车键继续..."
}

# 查看服务状态
show_service_status() {
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
    
    read -p "按回车键继续..."
}

# 查看配置信息
show_config_info() {
    print_title "查看配置信息"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "配置文件不存在"
        read -p "按回车键继续..."
        return 1
    fi
    
    print_info "配置文件: $CONFIG_FILE"
    print_info "日志文件: $LOG_FILE"
    print_separator
    
    # 显示配置文件内容
    print_message $CYAN "当前配置:"
    cat "$CONFIG_FILE" | jq '.' 2>/dev/null || cat "$CONFIG_FILE"
    
    read -p "按回车键继续..."
}

# 查看日志
show_logs() {
    print_title "查看日志"
    
    echo
    print_message $CYAN "请选择查看方式:"
    print_message $WHITE "1. 查看最近50行日志"
    print_message $WHITE "2. 查看systemd日志"
    print_message $WHITE "3. 查看错误日志"
    print_message $WHITE "0. 返回主菜单"
    echo
    
    read -p "请选择 [0-3]: " log_choice
    
    case $log_choice in
        1)
            print_info "最近50行日志:"
            echo
            if [[ -f "$LOG_FILE" ]]; then
                tail -n 50 "$LOG_FILE"
            else
                print_warning "日志文件不存在"
            fi
            ;;
        2)
            print_info "systemd服务日志:"
            echo
            journalctl -u "$SERVICE_NAME" -n 50 --no-pager
            ;;
        3)
            print_info "错误日志:"
            echo
            if [[ -f "$LOG_FILE" ]]; then
                grep -i "error\|fail\|fatal" "$LOG_FILE" | tail -n 20
            else
                print_warning "日志文件不存在"
            fi
            ;;
        0)
            return 0
            ;;
        *)
            print_error "无效选项"
            ;;
    esac
    
    read -p "按回车键继续..."
}

# 更换端口
change_port() {
    print_title "更换端口"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "配置文件不存在，请先配置协议"
        read -p "按回车键继续..."
        return 1
    fi
    
    # 读取当前端口
    local current_port=$(jq -r '.inbounds[0].listen_port' "$CONFIG_FILE" 2>/dev/null)
    if [[ -z "$current_port" || "$current_port" == "null" ]]; then
        print_error "无法读取当前端口配置"
        read -p "按回车键继续..."
        return 1
    fi
    
    print_info "当前端口: $current_port"
    print_separator
    
    # 获取新端口
    while true; do
        read -p "请输入新端口 [1000-65535]: " new_port
        
        # 验证端口格式
        if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [[ $new_port -lt 1000 ]] || [[ $new_port -gt 65535 ]]; then
            print_error "端口必须是1000-65535之间的数字"
            continue
        fi
        
        # 检查端口是否被占用
        if check_port_usage "$new_port"; then
            print_error "端口 $new_port 已被占用，请选择其他端口"
            continue
        fi
        
        # 确认更换
        if [[ "$new_port" == "$current_port" ]]; then
            print_warning "新端口与当前端口相同"
            read -p "按回车键继续..."
            return 0
        fi
        
        print_info "新端口: $new_port"
        read -p "确认更换端口? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            break
        fi
    done
    
    # 停止服务
    print_info "停止sing-box服务..."
    systemctl stop "$SERVICE_NAME" >/dev/null 2>&1
    
    # 更新配置文件中的端口
    print_info "更新配置文件..."
    local temp_config="/tmp/singbox_config_temp.json"
    jq ".inbounds[0].listen_port = $new_port" "$CONFIG_FILE" > "$temp_config"
    
    if [[ $? -eq 0 ]]; then
        mv "$temp_config" "$CONFIG_FILE"
        print_success "配置文件已更新"
    else
        print_error "配置文件更新失败"
        rm -f "$temp_config"
        read -p "按回车键继续..."
        return 1
    fi
    
    # 更新客户端配置文件
    print_info "更新客户端配置文件..."
    for client_file in "$WORK_DIR"/*-client.json; do
        if [[ -f "$client_file" ]]; then
            local temp_client="/tmp/singbox_client_temp.json"
            jq ".outbounds[0].server_port = $new_port" "$client_file" > "$temp_client"
            if [[ $? -eq 0 ]]; then
                mv "$temp_client" "$client_file"
                print_success "客户端配置已更新: $(basename "$client_file")"
            else
                rm -f "$temp_client"
                print_warning "客户端配置更新失败: $(basename "$client_file")"
            fi
        fi
    done
    
    # 更新防火墙规则
    print_info "更新防火墙规则..."
    
    # 删除旧端口规则
    case "$FIREWALL_TYPE" in
        "ufw")
            ufw delete allow "$current_port" >/dev/null 2>&1
            ;;
        "firewalld")
            firewall-cmd --permanent --remove-port="$current_port/tcp" >/dev/null 2>&1
            firewall-cmd --permanent --remove-port="$current_port/udp" >/dev/null 2>&1
            ;;
        "iptables")
            iptables -D INPUT -p tcp --dport "$current_port" -j ACCEPT >/dev/null 2>&1
            iptables -D INPUT -p udp --dport "$current_port" -j ACCEPT >/dev/null 2>&1
            ;;
    esac
    
    # 添加新端口规则
    local protocol_type=$(jq -r '.inbounds[0].type' "$CONFIG_FILE" 2>/dev/null)
    if [[ "$protocol_type" == "hysteria2" ]]; then
        configure_firewall "$new_port" "udp"
    else
        configure_firewall "$new_port" "tcp"
    fi
    
    # 启动服务
    print_info "启动sing-box服务..."
    if systemctl start "$SERVICE_NAME"; then
        sleep 2
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            print_success "端口更换完成！"
            print_info "新端口: $new_port"
            print_info "服务已重新启动"
            
            # 记录日志
            log_message "INFO" "端口已从 $current_port 更换为 $new_port"
        else
            print_error "服务启动失败，请检查配置"
            systemctl status "$SERVICE_NAME" --no-pager -l
        fi
    else
        print_error "服务启动失败"
    fi
    
    read -p "按回车键继续..."
}

# 升级内核
upgrade_kernel() {
    print_title "升级内核"
    
    if [[ ! -f "$SINGBOX_BINARY" ]]; then
        print_error "sing-box未安装，请先安装"
        read -p "按回车键继续..."
        return 1
    fi
    
    local current_version
    current_version=$("$SINGBOX_BINARY" version 2>/dev/null | head -1)
    print_info "当前版本: $current_version"
    
    if get_latest_version; then
        print_info "最新版本: $SINGBOX_VERSION"
        read -p "是否升级到最新版本? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            systemctl stop "$SERVICE_NAME" >/dev/null 2>&1
            if download_singbox; then
                systemctl start "$SERVICE_NAME" >/dev/null 2>&1
                print_success "升级完成"
            else
                print_error "升级失败"
            fi
        fi
    fi
    
    read -p "按回车键继续..."
}

# 备份配置
backup_config() {
    print_title "备份配置"
    
    local backup_name="singbox-backup-$(date +%Y%m%d-%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    print_info "创建备份: $backup_name"
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
    
    print_success "备份完成: $backup_path"
    read -p "按回车键继续..."
}

# 恢复配置
restore_config() {
    print_title "恢复配置"
    
    # 检查备份目录是否存在
    if [[ ! -d "$BACKUP_DIR" ]]; then
        print_error "备份目录不存在"
        read -p "按回车键继续..."
        return 1
    fi
    
    # 列出所有备份文件
    local backups=($(ls -1t "$BACKUP_DIR" 2>/dev/null | grep "singbox-backup-"))
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        print_error "未找到备份文件"
        print_info "请先使用备份功能创建备份"
        read -p "按回车键继续..."
        return 1
    fi
    
    print_info "找到 ${#backups[@]} 个备份文件:"
    print_separator
    
    # 显示备份列表
    for i in "${!backups[@]}"; do
        local backup_name="${backups[$i]}"
        local backup_path="$BACKUP_DIR/$backup_name"
        local backup_date=$(echo "$backup_name" | grep -oP '\d{8}-\d{6}')
        local formatted_date=$(echo "$backup_date" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)-\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')
        
        print_message $WHITE "$((i+1)). $backup_name"
        print_message $BLUE "   时间: $formatted_date"
        
        # 显示备份内容
        if [[ -f "$backup_path/config.json" ]]; then
            print_message $GREEN "   ✓ 服务器配置文件"
        fi
        
        local client_count=$(ls -1 "$backup_path"/*-client.json 2>/dev/null | wc -l)
        if [[ $client_count -gt 0 ]]; then
            print_message $GREEN "   ✓ 客户端配置文件 ($client_count 个)"
        fi
        
        if [[ -d "$backup_path/certs" ]]; then
            print_message $GREEN "   ✓ 证书文件"
        fi
        
        echo
    done
    
    print_separator
    print_message $WHITE "0. 返回主菜单"
    echo
    
    # 用户选择备份
    while true; do
        read -p "请选择要恢复的备份 [0-${#backups[@]}]: " choice
        
        if [[ "$choice" == "0" ]]; then
            return 0
        fi
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#backups[@]} ]]; then
            break
        else
            print_error "无效选项，请重新选择"
        fi
    done
    
    local selected_backup="${backups[$((choice-1))]}"
    local backup_path="$BACKUP_DIR/$selected_backup"
    
    print_info "选择的备份: $selected_backup"
    print_warning "恢复配置将覆盖当前所有配置文件"
    read -p "确认恢复配置? [y/N]: " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "取消恢复"
        read -p "按回车键继续..."
        return 0
    fi
    
    # 停止服务
    print_info "停止sing-box服务..."
    systemctl stop "$SERVICE_NAME" >/dev/null 2>&1
    
    # 备份当前配置（以防恢复失败）
    local temp_backup="$BACKUP_DIR/temp-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$temp_backup"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        cp "$CONFIG_FILE" "$temp_backup/" 2>/dev/null
    fi
    
    for client_file in "$WORK_DIR"/*-client.json; do
        if [[ -f "$client_file" ]]; then
            cp "$client_file" "$temp_backup/" 2>/dev/null
        fi
    done
    
    if [[ -d "$WORK_DIR/certs" ]]; then
        cp -r "$WORK_DIR/certs" "$temp_backup/" 2>/dev/null
    fi
    
    print_info "当前配置已临时备份到: $temp_backup"
    
    # 开始恢复
    local restore_success=true
    
    # 恢复服务器配置文件
    if [[ -f "$backup_path/config.json" ]]; then
        if cp "$backup_path/config.json" "$CONFIG_FILE"; then
            print_success "服务器配置文件已恢复"
        else
            print_error "服务器配置文件恢复失败"
            restore_success=false
        fi
    fi
    
    # 恢复客户端配置文件
    for backup_client in "$backup_path"/*-client.json; do
        if [[ -f "$backup_client" ]]; then
            local client_name=$(basename "$backup_client")
            if cp "$backup_client" "$WORK_DIR/$client_name"; then
                print_success "客户端配置已恢复: $client_name"
            else
                print_error "客户端配置恢复失败: $client_name"
                restore_success=false
            fi
        fi
    done
    
    # 恢复证书文件
    if [[ -d "$backup_path/certs" ]]; then
        if cp -r "$backup_path/certs" "$WORK_DIR/"; then
            print_success "证书文件已恢复"
        else
            print_error "证书文件恢复失败"
            restore_success=false
        fi
    fi
    
    # 验证配置文件
    if [[ -f "$CONFIG_FILE" ]]; then
        print_info "验证配置文件..."
        if "$SINGBOX_BINARY" check -c "$CONFIG_FILE" >/dev/null 2>&1; then
            print_success "配置文件验证通过"
        else
            print_error "配置文件验证失败"
            restore_success=false
        fi
    fi
    
    # 根据恢复结果决定下一步操作
    if [[ "$restore_success" == true ]]; then
        # 启动服务
        print_info "启动sing-box服务..."
        if systemctl start "$SERVICE_NAME"; then
            sleep 2
            if systemctl is-active --quiet "$SERVICE_NAME"; then
                print_success "配置恢复完成！"
                print_info "服务已重新启动"
                
                # 删除临时备份
                rm -rf "$temp_backup"
                
                # 记录日志
                log_message "INFO" "配置已从备份恢复: $selected_backup"
            else
                print_error "服务启动失败，请检查配置"
                systemctl status "$SERVICE_NAME" --no-pager -l
            fi
        else
            print_error "服务启动失败"
        fi
    else
        print_error "配置恢复过程中出现错误"
        print_info "正在恢复原始配置..."
        
        # 恢复原始配置
        if [[ -f "$temp_backup/config.json" ]]; then
            cp "$temp_backup/config.json" "$CONFIG_FILE" 2>/dev/null
        fi
        
        for temp_client in "$temp_backup"/*-client.json; do
            if [[ -f "$temp_client" ]]; then
                cp "$temp_client" "$WORK_DIR/" 2>/dev/null
            fi
        done
        
        if [[ -d "$temp_backup/certs" ]]; then
            cp -r "$temp_backup/certs" "$WORK_DIR/" 2>/dev/null
        fi
        
        print_info "原始配置已恢复"
        systemctl start "$SERVICE_NAME" >/dev/null 2>&1
    fi
    
    read -p "按回车键继续..."
}

# 生成真实分享链接
generate_real_share_link() {
    local protocol_type=$(jq -r '.inbounds[0].type' "$CONFIG_FILE" 2>/dev/null)
    local server_port=$(jq -r '.inbounds[0].listen_port' "$CONFIG_FILE" 2>/dev/null)
    local share_link=""
    
    case "$protocol_type" in
        "vless")
            # Reality协议分享链接
            local uuid=$(jq -r '.inbounds[0].users[0].uuid' "$CONFIG_FILE" 2>/dev/null)
            local server_name=$(jq -r '.inbounds[0].tls.server_name' "$CONFIG_FILE" 2>/dev/null)
            local public_key=$(jq -r '.inbounds[0].tls.reality.private_key' "$CONFIG_FILE" 2>/dev/null)
            local short_id=$(jq -r '.inbounds[0].tls.reality.short_id[0]' "$CONFIG_FILE" 2>/dev/null)
            
            # 从客户端配置读取public_key（因为服务器配置存储的是private_key）
            local client_config="$WORK_DIR/reality-client.json"
            if [[ -f "$client_config" ]]; then
                public_key=$(jq -r '.outbounds[0].tls.reality.public_key' "$client_config" 2>/dev/null)
            fi
            
            share_link="vless://${uuid}@${IP_ADDRESS}:${server_port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${server_name}&fp=chrome&pbk=${public_key}&sid=${short_id}&type=tcp&headerType=none#Reality-${IP_ADDRESS}"
            ;;
        "hysteria2")
            # Hysteria2协议分享链接
            local password=$(jq -r '.inbounds[0].users[0].password' "$CONFIG_FILE" 2>/dev/null)
            share_link="hysteria2://${password}@${IP_ADDRESS}:${server_port}?insecure=1#Hysteria2-${IP_ADDRESS}"
            ;;
        "vmess")
            # VMess协议分享链接
            local uuid=$(jq -r '.inbounds[0].users[0].uuid' "$CONFIG_FILE" 2>/dev/null)
            local ws_path=$(jq -r '.inbounds[0].transport.path' "$CONFIG_FILE" 2>/dev/null)
            
            # 构建VMess JSON配置
            local vmess_json="{\"v\":\"2\",\"ps\":\"VMess-${IP_ADDRESS}\",\"add\":\"${IP_ADDRESS}\",\"port\":\"${server_port}\",\"id\":\"${uuid}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"\",\"path\":\"${ws_path}\",\"tls\":\"tls\",\"sni\":\"${IP_ADDRESS}\",\"alpn\":\"\"}"
            
            # Base64编码
            share_link="vmess://$(echo -n "$vmess_json" | base64 -w 0)"
            ;;
        *)
            print_error "未知的协议类型: $protocol_type"
            return 1
            ;;
    esac
    
    echo "$share_link"
}

# 生成分享二维码
generate_share_qrcode() {
    print_title "生成分享二维码"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "配置文件不存在，请先安装并配置sing-box"
        read -p "按回车键继续..."
        return 1
    fi
    
    # 检测协议类型
    local protocol_type=$(jq -r '.inbounds[0].type' "$CONFIG_FILE" 2>/dev/null)
    local server_port=$(jq -r '.inbounds[0].listen_port' "$CONFIG_FILE" 2>/dev/null)
    
    print_info "检测到协议类型: $protocol_type"
    print_info "服务端口: $server_port"
    print_separator
    
    # 检查是否安装qrencode
    if ! command_exists "qrencode"; then
        print_info "正在安装二维码生成工具..."
        case "$OS_TYPE" in
            "debian")
                apt update -y >/dev/null 2>&1
                apt install -y qrencode >/dev/null 2>&1
                ;;
            "centos")
                if command_exists "dnf"; then
                    dnf install -y qrencode >/dev/null 2>&1
                else
                    yum install -y qrencode >/dev/null 2>&1
                fi
                ;;
            "arch")
                pacman -Sy --noconfirm qrencode >/dev/null 2>&1
                ;;
        esac
    fi
    
    # 生成真实分享链接
    print_info "生成分享链接..."
    local share_link=$(generate_real_share_link)
    
    if [[ -z "$share_link" ]]; then
        print_error "分享链接生成失败"
        read -p "按回车键继续..."
        return 1
    fi
    
    print_separator
    print_message $GREEN "分享链接:"
    echo "$share_link"
    print_separator
    
    # 显示二维码选项
    echo
    print_message $CYAN "请选择二维码生成方式:"
    print_message $WHITE "1. 终端显示二维码"
    print_message $WHITE "2. 保存为PNG图片"
    print_message $WHITE "3. 显示在线二维码链接"
    print_message $WHITE "4. 显示所有方式"
    print_message $WHITE "0. 返回主菜单"
    echo
    
    read -p "请选择 [0-4]: " qr_choice
    
    case $qr_choice in
        1)
            if command_exists "qrencode"; then
                print_info "终端二维码:"
                echo
                qrencode -t ANSIUTF8 "$share_link" 2>/dev/null || print_warning "终端二维码生成失败"
                echo
            else
                print_warning "qrencode未安装，无法生成终端二维码"
            fi
            ;;
        2)
            if command_exists "qrencode"; then
                local qr_file="$WORK_DIR/qrcode-$(date +%Y%m%d-%H%M%S).png"
                if qrencode -o "$qr_file" "$share_link" 2>/dev/null; then
                    print_success "二维码已保存: $qr_file"
                else
                    print_warning "PNG二维码生成失败"
                fi
            else
                print_warning "qrencode未安装，无法生成PNG二维码"
            fi
            ;;
        3)
            print_info "在线二维码链接:"
            local encoded_link=$(echo -n "$share_link" | sed 's/+/%2B/g; s/\//%2F/g; s/=/%3D/g')
            echo
            print_message $BLUE "1. QR Server: https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=$encoded_link"
            print_message $BLUE "2. QR Code Generator: https://chart.googleapis.com/chart?chs=300x300&cht=qr&chl=$encoded_link"
            print_message $BLUE "3. QuickChart: https://quickchart.io/qr?text=$encoded_link&size=300"
            echo
            print_info "复制上述链接到浏览器中查看二维码"
            ;;
        4)
            # 显示所有方式
            if command_exists "qrencode"; then
                print_info "终端二维码:"
                echo
                qrencode -t ANSIUTF8 "$share_link" 2>/dev/null || print_warning "终端二维码生成失败"
                echo
                
                local qr_file="$WORK_DIR/qrcode-$(date +%Y%m%d-%H%M%S).png"
                if qrencode -o "$qr_file" "$share_link" 2>/dev/null; then
                    print_success "二维码已保存: $qr_file"
                else
                    print_warning "PNG二维码生成失败"
                fi
            else
                print_warning "qrencode未安装，无法生成终端和PNG二维码"
            fi
            
            print_info "在线二维码链接:"
            local encoded_link=$(echo -n "$share_link" | sed 's/+/%2B/g; s/\//%2F/g; s/=/%3D/g')
            echo
            print_message $BLUE "1. QR Server: https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=$encoded_link"
            print_message $BLUE "2. QR Code Generator: https://chart.googleapis.com/chart?chs=300x300&cht=qr&chl=$encoded_link"
            print_message $BLUE "3. QuickChart: https://quickchart.io/qr?text=$encoded_link&size=300"
            echo
            print_info "复制上述链接到浏览器中查看二维码"
            ;;
        0)
            return 0
            ;;
        *)
            print_error "无效选项"
            ;;
    esac
    
    # 显示客户端配置信息
    echo
    print_separator
    print_message $CYAN "客户端配置信息:"
    print_separator
    
    case "$protocol_type" in
        "vless")
            print_message $WHITE "协议: Reality (VLESS)"
            print_message $WHITE "服务器: $IP_ADDRESS"
            print_message $WHITE "端口: $server_port"
            print_message $WHITE "UUID: $(jq -r '.inbounds[0].users[0].uuid' "$CONFIG_FILE" 2>/dev/null)"
            print_message $WHITE "流控: xtls-rprx-vision"
            print_message $WHITE "传输安全: reality"
            print_message $WHITE "SNI: $(jq -r '.inbounds[0].tls.server_name' "$CONFIG_FILE" 2>/dev/null)"
            ;;
        "hysteria2")
            print_message $WHITE "协议: Hysteria2"
            print_message $WHITE "服务器: $IP_ADDRESS"
            print_message $WHITE "端口: $server_port"
            print_message $WHITE "密码: $(jq -r '.inbounds[0].users[0].password' "$CONFIG_FILE" 2>/dev/null)"
            print_message $WHITE "传输安全: TLS (自签名)"
            ;;
        "vmess")
            print_message $WHITE "协议: VMess"
            print_message $WHITE "服务器: $IP_ADDRESS"
            print_message $WHITE "端口: $server_port"
            print_message $WHITE "UUID: $(jq -r '.inbounds[0].users[0].uuid' "$CONFIG_FILE" 2>/dev/null)"
            print_message $WHITE "传输协议: WebSocket"
            print_message $WHITE "路径: $(jq -r '.inbounds[0].transport.path' "$CONFIG_FILE" 2>/dev/null)"
            print_message $WHITE "传输安全: TLS"
            ;;
    esac
    
    print_separator
    print_message $YELLOW "支持的客户端:"
    print_message $WHITE "• Windows: v2rayN, Clash for Windows, sing-box"
    print_message $WHITE "• Android: v2rayNG, Clash for Android, sing-box"
    print_message $WHITE "• iOS: Shadowrocket, Quantumult X, sing-box"
    print_message $WHITE "• macOS: ClashX, V2rayU, sing-box"
    print_separator
    
    read -p "按回车键继续..."
}

# 查看版本信息
show_version_info() {
    print_title "版本信息"
    
    print_message $CYAN "脚本信息:"
    print_separator
    print_message $WHITE "脚本名称: $SCRIPT_NAME"
    print_message $WHITE "当前版本: $SCRIPT_VERSION"
    print_message $WHITE "构建日期: $SCRIPT_BUILD_DATE"
    print_message $WHITE "脚本作者: $SCRIPT_AUTHOR"
    print_separator
    
    # 显示sing-box版本信息
    if [[ -f "$SINGBOX_BINARY" ]]; then
        local singbox_version=$("$SINGBOX_BINARY" version 2>/dev/null | head -1)
        print_message $CYAN "sing-box信息:"
        print_separator
        print_message $WHITE "安装状态: 已安装"
        print_message $WHITE "当前版本: $singbox_version"
        print_message $WHITE "程序路径: $SINGBOX_BINARY"
        print_separator
    else
        print_message $CYAN "sing-box信息:"
        print_separator
        print_message $WHITE "安装状态: 未安装"
        print_separator
    fi
    
    # 显示系统信息
    print_message $CYAN "系统信息:"
    print_separator
    print_message $WHITE "操作系统: $SYSTEM_INFO"
    print_message $WHITE "系统架构: $(uname -m) ($ARCH)"
    print_message $WHITE "内核版本: $(uname -r)"
    print_message $WHITE "服务器IP: ${IP_ADDRESS:-未获取到}"
    [[ -n "$IPV6_ADDRESS" ]] && print_message $WHITE "IPv6地址: $IPV6_ADDRESS"
    print_separator
    
    # 显示版本历史
    print_message $CYAN "版本历史:"
    print_separator
    print_message $WHITE "v1.1.0 (2024-01-15)"
    print_message $WHITE "  - 添加版本管理功能"
    print_message $WHITE "  - 完善脚本信息显示"
    print_message $WHITE "  - 优化用户界面"
    print_message $WHITE ""
    print_message $WHITE "v1.0.0 (2024-01-14)"
    print_message $WHITE "  - 初始版本发布"
    print_message $WHITE "  - 支持Reality、Hysteria2、VMess协议"
    print_message $WHITE "  - 完整的服务管理功能"
    print_message $WHITE "  - QR码分享功能"
    print_separator
    
    read -p "按回车键继续..."
}

# 主函数
main() {
    initialize
    
    while true; do
        show_script_info
        show_main_menu
        
        read -p "请输入选项 [0-15]: " choice
        
        case $choice in
            1)
                install_singbox
                ;;
            2)
                configure_protocol
                ;;
            3)
                uninstall_singbox
                ;;
            4)
                start_service
                ;;
            5)
                stop_service
                ;;
            6)
                restart_service
                ;;
            7)
                show_service_status
                ;;
            8)
                show_config_info
                ;;
            9)
                show_logs
                ;;
            10)
                change_port
                ;;
            11)
                upgrade_kernel
                ;;
            12)
                backup_config
                ;;
            13)
                restore_config
                ;;
            14)
                generate_share_qrcode
                ;;
            15)
                show_version_info
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
# 脚本入口
#================================================================

# 捕获退出信号
trap 'print_info "脚本已退出"; exit 0' INT TERM

# 启动主函数
main "$@"
