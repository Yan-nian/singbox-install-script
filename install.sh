#!/bin/bash

# Sing-box VPS一键安装脚本
# 支持协议: VLESS Reality, VMess WebSocket, Hysteria2
# 作者: Solo Coding
# 版本: v1.0.0
# 更新时间: 2024-12-19

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 全局变量
SCRIPT_VERSION="v1.0.0"
SINGBOX_VERSION=""
SINGBOX_CONFIG_DIR="/etc/sing-box"
SINGBOX_LOG_DIR="/var/log/sing-box"
SINGBOX_SERVICE_FILE="/etc/systemd/system/sing-box.service"
SINGBOX_BINARY="/usr/local/bin/sing-box"
CURRENT_PROTOCOL=""
CURRENT_PORT=""
INSTALL_PATH="$(pwd)"

# 系统信息
OS_TYPE=""
OS_VERSION=""
ARCH=""
IP_ADDRESS=""

# 协议配置
VLESS_UUID=""
VLESS_PRIVATE_KEY=""
VLESS_PUBLIC_KEY=""
VLESS_SHORT_ID=""
VMESS_UUID=""
VMESS_WS_PATH=""
HY2_PASSWORD=""
HY2_PORT=""

# 证书相关
DOMAIN_NAME=""
CERT_PATH=""
KEY_PATH=""

# 显示Logo和版本信息
show_logo() {
    clear
    echo -e "${BLUE}"
    echo "  ███████╗██╗███╗   ██╗ ██████╗       ██████╗  ██████╗ ██╗  ██╗"
    echo "  ██╔════╝██║████╗  ██║██╔════╝       ██╔══██╗██╔═══██╗╚██╗██╔╝"
    echo "  ███████╗██║██╔██╗ ██║██║  ███╗█████╗██████╔╝██║   ██║ ╚███╔╝ "
    echo "  ╚════██║██║██║╚██╗██║██║   ██║╚════╝██╔══██╗██║   ██║ ██╔██╗ "
    echo "  ███████║██║██║ ╚████║╚██████╔╝      ██████╔╝╚██████╔╝██╔╝ ██╗"
    echo "  ╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝       ╚═════╝  ╚═════╝ ╚═╝  ╚═╝"
    echo -e "${NC}"
    echo -e "${GREEN}  Sing-box VPS一键安装脚本 ${SCRIPT_VERSION}${NC}"
    echo -e "${CYAN}  支持协议: VLESS Reality | VMess WebSocket | Hysteria2${NC}"
    echo -e "${YELLOW}  =================================================${NC}"
    echo
}

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

log_debug() {
    echo -e "${PURPLE}[DEBUG]${NC} $1"
}

# 进度显示函数
show_progress() {
    local current=$1
    local total=$2
    local desc=$3
    local percent=$((current * 100 / total))
    local bar_length=30
    local filled_length=$((percent * bar_length / 100))
    
    printf "\r${CYAN}[%3d%%]${NC} [" "$percent"
    for ((i=0; i<filled_length; i++)); do printf "█"; done
    for ((i=filled_length; i<bar_length; i++)); do printf "░"; done
    printf "] %s" "$desc"
}

# 错误处理函数
error_handler() {
    local line_number=$1
    log_error "脚本在第 $line_number 行发生错误"
    log_error "请检查网络连接和系统权限"
    exit 1
}

# 设置错误处理
trap 'error_handler $LINENO' ERR

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        log_info "请使用: sudo bash $0"
        exit 1
    fi
}

# 系统检测模块
check_system() {
    log_info "正在检测系统环境..."
    
    # 检测操作系统
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS_TYPE=$ID
        OS_VERSION=$VERSION_ID
    elif [[ -f /etc/redhat-release ]]; then
        OS_TYPE="centos"
        OS_VERSION=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+')
    else
        log_error "不支持的操作系统"
        exit 1
    fi
    
    # 检测系统架构
    ARCH=$(uname -m)
    case $ARCH in
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
            log_error "不支持的系统架构: $ARCH"
            exit 1
            ;;
    esac
    
    # 获取公网IP
    log_info "正在获取服务器IP地址..."
    IP_ADDRESS=$(curl -s --max-time 10 ipv4.icanhazip.com || curl -s --max-time 10 ifconfig.me || curl -s --max-time 10 ip.sb)
    
    if [[ -z "$IP_ADDRESS" ]]; then
        log_warn "无法获取公网IP，请手动确认网络连接"
        read -p "请输入服务器IP地址: " IP_ADDRESS
    fi
    
    log_info "系统信息检测完成:"
    echo -e "  操作系统: ${GREEN}$OS_TYPE $OS_VERSION${NC}"
    echo -e "  系统架构: ${GREEN}$ARCH${NC}"
    echo -e "  服务器IP: ${GREEN}$IP_ADDRESS${NC}"
    echo
}

# 检查系统依赖
check_dependencies() {
    log_info "正在检查系统依赖..."
    
    local deps=("curl" "wget" "unzip" "systemctl")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_warn "缺少以下依赖: ${missing_deps[*]}"
        log_info "正在自动安装依赖..."
        
        case $OS_TYPE in
            ubuntu|debian)
                apt update && apt install -y "${missing_deps[@]}"
                ;;
            centos|rhel|fedora)
                if command -v dnf &> /dev/null; then
                    dnf install -y "${missing_deps[@]}"
                else
                    yum install -y "${missing_deps[@]}"
                fi
                ;;
            *)
                log_error "不支持的包管理器，请手动安装: ${missing_deps[*]}"
                exit 1
                ;;
        esac
    fi
    
    log_info "系统依赖检查完成"
}

# 检查网络连接
check_network() {
    log_info "正在检查网络连接..."
    
    local test_urls=("google.com" "github.com" "cloudflare.com")
    local network_ok=false
    
    for url in "${test_urls[@]}"; do
        if ping -c 1 -W 3 "$url" &> /dev/null; then
            network_ok=true
            break
        fi
    done
    
    if [[ "$network_ok" == "false" ]]; then
        log_error "网络连接异常，请检查网络设置"
        exit 1
    fi
    
    log_info "网络连接正常"
}

# 检查端口占用
check_port() {
    local port=$1
    if ss -tuln | grep -q ":$port "; then
        return 1
    else
        return 0
    fi
}

# 生成随机端口
generate_random_port() {
    local min_port=10000
    local max_port=65535
    local port
    
    while true; do
        port=$((RANDOM % (max_port - min_port + 1) + min_port))
        if check_port "$port"; then
            echo "$port"
            break
        fi
    done
}

# 检查sing-box安装状态
check_singbox_status() {
    if [[ -f "$SINGBOX_BINARY" ]] && [[ -f "$SINGBOX_SERVICE_FILE" ]]; then
        if systemctl is-active --quiet sing-box; then
            echo "running"
        else
            echo "installed"
        fi
    else
        echo "not_installed"
    fi
}

# 获取当前配置信息
get_current_config() {
    if [[ -f "$SINGBOX_CONFIG_DIR/config.json" ]]; then
        # 尝试从配置文件中提取协议和端口信息
        local config_file="$SINGBOX_CONFIG_DIR/config.json"
        if grep -q "vless" "$config_file"; then
            CURRENT_PROTOCOL="VLESS Reality"
        elif grep -q "vmess" "$config_file"; then
            CURRENT_PROTOCOL="VMess WebSocket"
        elif grep -q "hysteria2" "$config_file"; then
            CURRENT_PROTOCOL="Hysteria2"
        fi
        
        # 提取端口信息
        CURRENT_PORT=$(grep -o '"listen_port":[[:space:]]*[0-9]*' "$config_file" | grep -o '[0-9]*' | head -1)
        if [[ -z "$CURRENT_PORT" ]]; then
            CURRENT_PORT=$(grep -o '"listen":[[:space:]]*"[^:]*:[0-9]*"' "$config_file" | grep -o '[0-9]*' | head -1)
        fi
    fi
}

# 显示主菜单
show_main_menu() {
    while true; do
        show_logo
        
        local status=$(check_singbox_status)
        get_current_config
        
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                    系统状态信息${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        case $status in
            "running")
                echo -e "  服务状态: ${GREEN}●${NC} 运行中"
                echo -e "  当前协议: ${GREEN}$CURRENT_PROTOCOL${NC}"
                echo -e "  监听端口: ${GREEN}$CURRENT_PORT${NC}"
                echo -e "  服务器IP: ${GREEN}$IP_ADDRESS${NC}"
                ;;
            "installed")
                echo -e "  服务状态: ${YELLOW}●${NC} 已安装未启动"
                echo -e "  当前协议: ${YELLOW}$CURRENT_PROTOCOL${NC}"
                echo -e "  监听端口: ${YELLOW}$CURRENT_PORT${NC}"
                echo -e "  服务器IP: ${GREEN}$IP_ADDRESS${NC}"
                ;;
            "not_installed")
                echo -e "  服务状态: ${RED}●${NC} 未安装"
                echo -e "  当前协议: ${RED}无${NC}"
                echo -e "  监听端口: ${RED}无${NC}"
                echo -e "  服务器IP: ${GREEN}$IP_ADDRESS${NC}"
                ;;
        esac
        
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                    功能菜单${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        if [[ "$status" == "not_installed" ]]; then
            echo -e "  ${GREEN}1.${NC} 安装 VLESS Reality 协议"
            echo -e "  ${GREEN}2.${NC} 安装 VMess WebSocket 协议"
            echo -e "  ${GREEN}3.${NC} 安装 Hysteria2 协议"
        else
            echo -e "  ${GREEN}1.${NC} 查看连接信息"
            echo -e "  ${GREEN}2.${NC} 管理服务 (启动/停止/重启)"
            echo -e "  ${GREEN}3.${NC} 更改端口"
            echo -e "  ${GREEN}4.${NC} 配置分享 (链接/二维码)"
            echo -e "  ${GREEN}5.${NC} 查看日志"
            echo -e "  ${GREEN}6.${NC} 重新安装协议"
            echo -e "  ${GREEN}7.${NC} 完全卸载"
        fi
        
        echo -e "  ${RED}0.${NC} 退出脚本"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        read -p "请选择操作 [0-7]: " choice
        
        case $choice in
            1)
                if [[ "$status" == "not_installed" ]]; then
                    install_vless_reality
                else
                    show_connection_info
                fi
                ;;
            2)
                if [[ "$status" == "not_installed" ]]; then
                    install_vmess_ws
                else
                    manage_service_menu
                fi
                ;;
            3)
                if [[ "$status" == "not_installed" ]]; then
                    install_hysteria2
                else
                    change_port_menu
                fi
                ;;
            4)
                if [[ "$status" != "not_installed" ]]; then
                    share_config
                fi
                ;;
            5)
                if [[ "$status" != "not_installed" ]]; then
                    show_logs_menu
                fi
                ;;
            6)
                if [[ "$status" != "not_installed" ]]; then
                    reinstall_menu
                fi
                ;;
            7)
                if [[ "$status" != "not_installed" ]]; then
                    uninstall_singbox
                fi
                ;;
            0)
                log_info "感谢使用 Sing-box 一键安装脚本！"
                exit 0
                ;;
            *)
                log_error "无效选择，请重新输入"
                read -p "按回车键继续..." -r
                ;;
        esac
    done
}

# 获取最新sing-box版本
get_latest_version() {
    log_info "正在获取最新版本信息..."
    local api_url="https://api.github.com/repos/SagerNet/sing-box/releases/latest"
    SINGBOX_VERSION=$(curl -s "$api_url" | grep '"tag_name":' | cut -d'"' -f4)
    
    if [[ -z "$SINGBOX_VERSION" ]]; then
        log_error "无法获取版本信息，使用默认版本"
        SINGBOX_VERSION="v1.8.0"
    fi
    
    log_info "最新版本: $SINGBOX_VERSION"
}

# 下载sing-box
download_singbox() {
    log_info "正在下载 sing-box $SINGBOX_VERSION..."
    
    local download_url="https://github.com/SagerNet/sing-box/releases/download/${SINGBOX_VERSION}/sing-box-${SINGBOX_VERSION#v}-linux-${ARCH}.tar.gz"
    local temp_dir="/tmp/sing-box-install"
    local temp_file="$temp_dir/sing-box.tar.gz"
    
    # 创建临时目录
    mkdir -p "$temp_dir"
    
    # 下载文件
    if ! wget -q --show-progress -O "$temp_file" "$download_url"; then
        log_error "下载失败，请检查网络连接"
        return 1
    fi
    
    # 解压文件
    log_info "正在解压文件..."
    tar -xzf "$temp_file" -C "$temp_dir"
    
    # 查找二进制文件
    local binary_path=$(find "$temp_dir" -name "sing-box" -type f)
    if [[ -z "$binary_path" ]]; then
        log_error "未找到 sing-box 二进制文件"
        return 1
    fi
    
    # 复制到系统目录
    cp "$binary_path" "$SINGBOX_BINARY"
    chmod +x "$SINGBOX_BINARY"
    
    # 清理临时文件
    rm -rf "$temp_dir"
    
    log_info "sing-box 下载安装完成"
}

# 创建系统服务
create_systemd_service() {
    log_info "正在创建系统服务..."
    
    cat > "$SINGBOX_SERVICE_FILE" << EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=$SINGBOX_BINARY run -c $SINGBOX_CONFIG_DIR/config.json
Restart=on-failure
RestartSec=1800s
ExecReload=/bin/kill -HUP \$MAINPID

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载systemd
    systemctl daemon-reload
    systemctl enable sing-box
    
    log_info "系统服务创建完成"
}

# 创建配置目录
create_config_dirs() {
    log_info "正在创建配置目录..."
    
    mkdir -p "$SINGBOX_CONFIG_DIR"
    mkdir -p "$SINGBOX_LOG_DIR"
    mkdir -p "$SINGBOX_CONFIG_DIR/certs"
    
    log_info "配置目录创建完成"
}

# 生成UUID
generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen
    else
        cat /proc/sys/kernel/random/uuid
    fi
}

# 生成随机字符串
generate_random_string() {
    local length=${1:-16}
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
}

# VLESS Reality 安装
install_vless_reality() {
    show_logo
    log_info "开始安装 VLESS Reality 协议..."
    
    # 获取并下载最新版本
    get_latest_version
    create_config_dirs
    
    if ! download_singbox; then
        log_error "安装失败"
        read -p "按回车键返回主菜单..." -r
        return 1
    fi
    
    # 生成配置参数
    VLESS_UUID=$(generate_uuid)
    local vless_port=$(generate_random_port)
    
    # 生成Reality密钥对
    log_info "正在生成 Reality 密钥对..."
    local key_pair=$("$SINGBOX_BINARY" generate reality-keypair)
    VLESS_PRIVATE_KEY=$(echo "$key_pair" | grep "PrivateKey:" | awk '{print $2}')
    VLESS_PUBLIC_KEY=$(echo "$key_pair" | grep "PublicKey:" | awk '{print $2}')
    VLESS_SHORT_ID=$(generate_random_string 8)
    
    # 获取目标网站
    echo
    log_info "请选择 Reality 伪装网站:"
    echo "  1. www.microsoft.com (推荐)"
    echo "  2. www.cloudflare.com"
    echo "  3. www.apple.com"
    echo "  4. 自定义网站"
    
    read -p "请选择 [1-4]: " site_choice
    
    case $site_choice in
        1) local dest_site="www.microsoft.com" ;;
        2) local dest_site="www.cloudflare.com" ;;
        3) local dest_site="www.apple.com" ;;
        4) 
            read -p "请输入自定义网站 (如: www.example.com): " dest_site
            if [[ -z "$dest_site" ]]; then
                dest_site="www.microsoft.com"
            fi
            ;;
        *) local dest_site="www.microsoft.com" ;;
    esac
    
    # 生成配置文件
    log_info "正在生成配置文件..."
    
    cat > "$SINGBOX_CONFIG_DIR/config.json" << EOF
{
  "log": {
    "level": "info",
    "output": "$SINGBOX_LOG_DIR/sing-box.log"
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": $vless_port,
      "users": [
        {
          "uuid": "$VLESS_UUID",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$dest_site",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "$dest_site",
            "server_port": 443
          },
          "private_key": "$VLESS_PRIVATE_KEY",
          "short_id": [
            "$VLESS_SHORT_ID"
          ]
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
    
    # 创建系统服务
    create_systemd_service
    
    # 启动服务
    log_info "正在启动 sing-box 服务..."
    if systemctl start sing-box; then
        log_info "VLESS Reality 安装完成！"
        
        # 显示连接信息
        echo
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                连接信息${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  协议类型: ${GREEN}VLESS Reality${NC}"
        echo -e "  服务器地址: ${GREEN}$IP_ADDRESS${NC}"
        echo -e "  端口: ${GREEN}$vless_port${NC}"
        echo -e "  UUID: ${GREEN}$VLESS_UUID${NC}"
        echo -e "  Flow: ${GREEN}xtls-rprx-vision${NC}"
        echo -e "  TLS: ${GREEN}Reality${NC}"
        echo -e "  SNI: ${GREEN}$dest_site${NC}"
        echo -e "  PublicKey: ${GREEN}$VLESS_PUBLIC_KEY${NC}"
        echo -e "  ShortId: ${GREEN}$VLESS_SHORT_ID${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # 保存当前配置信息
        CURRENT_PROTOCOL="VLESS Reality"
        CURRENT_PORT="$vless_port"
        
    else
        log_error "服务启动失败，请检查配置"
    fi
    
    echo
    read -p "按回车键返回主菜单..." -r
}

# VMess WebSocket 安装
install_vmess_ws() {
    show_logo
    log_info "开始安装 VMess WebSocket 协议..."
    
    # 获取并下载最新版本
    get_latest_version
    create_config_dirs
    
    if ! download_singbox; then
        log_error "安装失败"
        read -p "按回车键返回主菜单..." -r
        return 1
    fi
    
    # 生成配置参数
    VMESS_UUID=$(generate_uuid)
    local vmess_port=$(generate_random_port)
    local ws_path="/$(generate_random_string 12)"
    
    # 询问是否启用TLS
    echo
    log_info "请选择传输安全:"
    echo "  1. 启用 TLS (推荐)"
    echo "  2. 不启用 TLS"
    
    read -p "请选择 [1-2]: " tls_choice
    
    local enable_tls=false
    local tls_config=""
    
    if [[ "$tls_choice" == "1" ]]; then
        enable_tls=true
        
        # 获取域名
        echo
        read -p "请输入您的域名 (如: example.com): " domain_name
        
        if [[ -z "$domain_name" ]]; then
            log_error "域名不能为空"
            read -p "按回车键返回主菜单..." -r
            return 1
        fi
        
        # 生成自签名证书
        log_info "正在生成自签名证书..."
        local cert_dir="$SINGBOX_CONFIG_DIR/certs"
        local cert_file="$cert_dir/cert.pem"
        local key_file="$cert_dir/key.pem"
        
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$key_file" \
            -out "$cert_file" \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=$domain_name" 2>/dev/null
        
        tls_config=',
        "tls": {
          "enabled": true,
          "certificate_path": "'$cert_file'",
          "key_path": "'$key_file'"
        }'
    fi
    
    # 生成配置文件
    log_info "正在生成配置文件..."
    
    cat > "$SINGBOX_CONFIG_DIR/config.json" << EOF
{
  "log": {
    "level": "info",
    "output": "$SINGBOX_LOG_DIR/sing-box.log"
  },
  "inbounds": [
    {
      "type": "vmess",
      "tag": "vmess-in",
      "listen": "::",
      "listen_port": $vmess_port,
      "users": [
        {
          "uuid": "$VMESS_UUID",
          "alterId": 0
        }
      ],
      "transport": {
        "type": "ws",
        "path": "$ws_path"
      }$tls_config
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
    
    # 创建系统服务
    create_systemd_service
    
    # 启动服务
    log_info "正在启动 sing-box 服务..."
    if systemctl start sing-box; then
        log_info "VMess WebSocket 安装完成！"
        
        # 显示连接信息
        echo
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                连接信息${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  协议类型: ${GREEN}VMess WebSocket${NC}"
        echo -e "  服务器地址: ${GREEN}$IP_ADDRESS${NC}"
        echo -e "  端口: ${GREEN}$vmess_port${NC}"
        echo -e "  UUID: ${GREEN}$VMESS_UUID${NC}"
        echo -e "  AlterID: ${GREEN}0${NC}"
        echo -e "  传输协议: ${GREEN}WebSocket${NC}"
        echo -e "  路径: ${GREEN}$ws_path${NC}"
        
        if [[ "$enable_tls" == "true" ]]; then
            echo -e "  TLS: ${GREEN}启用${NC}"
            echo -e "  域名: ${GREEN}$domain_name${NC}"
        else
            echo -e "  TLS: ${RED}未启用${NC}"
        fi
        
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # 保存当前配置信息
        CURRENT_PROTOCOL="VMess WebSocket"
        CURRENT_PORT="$vmess_port"
        
    else
        log_error "服务启动失败，请检查配置"
    fi
    
    echo
    read -p "按回车键返回主菜单..." -r
}

# Hysteria2 安装
install_hysteria2() {
    show_logo
    log_info "开始安装 Hysteria2 协议..."
    
    # 获取并下载最新版本
    get_latest_version
    create_config_dirs
    
    if ! download_singbox; then
        log_error "安装失败"
        read -p "按回车键返回主菜单..." -r
        return 1
    fi
    
    # 生成配置参数
    HY2_PASSWORD=$(generate_random_string 32)
    local hy2_port=$(generate_random_port)
    
    # 询问伪装网站
    echo
    log_info "请选择伪装网站:"
    echo "  1. www.bing.com (推荐)"
    echo "  2. www.yahoo.com"
    echo "  3. www.microsoft.com"
    echo "  4. 自定义网站"
    
    read -p "请选择 [1-4]: " masq_choice
    
    case $masq_choice in
        1) local masq_site="https://www.bing.com" ;;
        2) local masq_site="https://www.yahoo.com" ;;
        3) local masq_site="https://www.microsoft.com" ;;
        4) 
            read -p "请输入自定义网站 (如: https://www.example.com): " masq_site
            if [[ -z "$masq_site" ]]; then
                masq_site="https://www.bing.com"
            fi
            ;;
        *) local masq_site="https://www.bing.com" ;;
    esac
    
    # 生成自签名证书
    log_info "正在生成自签名证书..."
    local cert_dir="$SINGBOX_CONFIG_DIR/certs"
    local cert_file="$cert_dir/cert.pem"
    local key_file="$cert_dir/key.pem"
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$key_file" \
        -out "$cert_file" \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=hysteria.local" 2>/dev/null
    
    # 生成配置文件
    log_info "正在生成配置文件..."
    
    cat > "$SINGBOX_CONFIG_DIR/config.json" << EOF
{
  "log": {
    "level": "info",
    "output": "$SINGBOX_LOG_DIR/sing-box.log"
  },
  "inbounds": [
    {
      "type": "hysteria2",
      "tag": "hy2-in",
      "listen": "::",
      "listen_port": $hy2_port,
      "users": [
        {
          "password": "$HY2_PASSWORD"
        }
      ],
      "masquerade": "$masq_site",
      "tls": {
        "enabled": true,
        "alpn": [
          "h3"
        ],
        "certificate_path": "$cert_file",
        "key_path": "$key_file"
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
    
    # 创建系统服务
    create_systemd_service
    
    # 启动服务
    log_info "正在启动 sing-box 服务..."
    if systemctl start sing-box; then
        log_info "Hysteria2 安装完成！"
        
        # 显示连接信息
        echo
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                连接信息${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  协议类型: ${GREEN}Hysteria2${NC}"
        echo -e "  服务器地址: ${GREEN}$IP_ADDRESS${NC}"
        echo -e "  端口: ${GREEN}$hy2_port${NC}"
        echo -e "  密码: ${GREEN}$HY2_PASSWORD${NC}"
        echo -e "  伪装网站: ${GREEN}$masq_site${NC}"
        echo -e "  TLS: ${GREEN}启用 (自签名证书)${NC}"
        echo -e "  ALPN: ${GREEN}h3${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # 保存当前配置信息
        CURRENT_PROTOCOL="Hysteria2"
        CURRENT_PORT="$hy2_port"
        
    else
        log_error "服务启动失败，请检查配置"
    fi
    
    echo
    read -p "按回车键返回主菜单..." -r
}

show_connection_info() {
    show_logo
    
    if [[ ! -f "$SINGBOX_CONFIG_DIR/config.json" ]]; then
        log_error "未找到配置文件，请先安装协议"
        read -p "按回车键返回主菜单..." -r
        return 1
    fi
    
    # 解析配置文件获取信息
    local config_file="$SINGBOX_CONFIG_DIR/config.json"
    local protocol_type=$(grep -o '"type": "[^"]*"' "$config_file" | head -1 | cut -d'"' -f4)
    local listen_port=$(grep -o '"listen_port": [0-9]*' "$config_file" | cut -d':' -f2 | tr -d ' ')
    
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}                当前连接信息${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  服务器地址: ${GREEN}$IP_ADDRESS${NC}"
    echo -e "  端口: ${GREEN}$listen_port${NC}"
    echo -e "  协议类型: ${GREEN}$protocol_type${NC}"
    
    case $protocol_type in
        "vless")
            local uuid=$(grep -o '"uuid": "[^"]*"' "$config_file" | cut -d'"' -f4)
            local flow=$(grep -o '"flow": "[^"]*"' "$config_file" | cut -d'"' -f4)
            local server_name=$(grep -o '"server_name": "[^"]*"' "$config_file" | cut -d'"' -f4)
            echo -e "  UUID: ${GREEN}$uuid${NC}"
            echo -e "  Flow: ${GREEN}$flow${NC}"
            echo -e "  SNI: ${GREEN}$server_name${NC}"
            echo -e "  TLS: ${GREEN}Reality${NC}"
            ;;
        "vmess")
            local uuid=$(grep -o '"uuid": "[^"]*"' "$config_file" | cut -d'"' -f4)
            local ws_path=$(grep -o '"path": "[^"]*"' "$config_file" | cut -d'"' -f4)
            local tls_enabled=$(grep -q '"tls"' "$config_file" && echo "启用" || echo "未启用")
            echo -e "  UUID: ${GREEN}$uuid${NC}"
            echo -e "  传输协议: ${GREEN}WebSocket${NC}"
            echo -e "  路径: ${GREEN}$ws_path${NC}"
            echo -e "  TLS: ${GREEN}$tls_enabled${NC}"
            ;;
        "hysteria2")
            local password=$(grep -o '"password": "[^"]*"' "$config_file" | cut -d'"' -f4)
            local masquerade=$(grep -o '"masquerade": "[^"]*"' "$config_file" | cut -d'"' -f4)
            echo -e "  密码: ${GREEN}$password${NC}"
            echo -e "  伪装网站: ${GREEN}$masquerade${NC}"
            echo -e "  TLS: ${GREEN}启用${NC}"
            ;;
    esac
    
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo
    read -p "按回车键返回主菜单..." -r
}

manage_service_menu() {
    show_logo
    
    while true; do
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                服务管理${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # 获取服务状态
        local service_status
        if systemctl is-active sing-box &>/dev/null; then
            service_status="${GREEN}运行中${NC}"
        else
            service_status="${RED}已停止${NC}"
        fi
        
        echo -e "  当前状态: $service_status"
        echo
        echo -e "  ${GREEN}1.${NC} 启动服务"
        echo -e "  ${GREEN}2.${NC} 停止服务"
        echo -e "  ${GREEN}3.${NC} 重启服务"
        echo -e "  ${GREEN}4.${NC} 查看服务状态"
        echo -e "  ${GREEN}5.${NC} 设置开机自启"
        echo -e "  ${GREEN}6.${NC} 取消开机自启"
        echo -e "  ${GREEN}0.${NC} 返回主菜单"
        echo
        
        read -p "请选择操作 [0-6]: " choice
        
        case $choice in
            1)
                log_info "正在启动 sing-box 服务..."
                if systemctl start sing-box; then
                    log_info "服务启动成功"
                else
                    log_error "服务启动失败"
                fi
                ;;
            2)
                log_info "正在停止 sing-box 服务..."
                if systemctl stop sing-box; then
                    log_info "服务停止成功"
                else
                    log_error "服务停止失败"
                fi
                ;;
            3)
                log_info "正在重启 sing-box 服务..."
                if systemctl restart sing-box; then
                    log_info "服务重启成功"
                else
                    log_error "服务重启失败"
                fi
                ;;
            4)
                echo
                log_info "服务详细状态:"
                systemctl status sing-box --no-pager
                ;;
            5)
                log_info "正在设置开机自启..."
                if systemctl enable sing-box; then
                    log_info "开机自启设置成功"
                else
                    log_error "开机自启设置失败"
                fi
                ;;
            6)
                log_info "正在取消开机自启..."
                if systemctl disable sing-box; then
                    log_info "开机自启取消成功"
                else
                    log_error "开机自启取消失败"
                fi
                ;;
            0)
                return
                ;;
            *)
                log_error "无效选择，请重新输入"
                ;;
        esac
        
        echo
        read -p "按回车键继续..." -r
        show_logo
    done
}

# 端口更改
change_port() {
    show_logo
    
    if [[ ! -f "$SINGBOX_CONFIG_DIR/config.json" ]]; then
        log_error "未找到配置文件，请先安装协议"
        read -p "按回车键返回主菜单..." -r
        return 1
    fi
    
    # 获取当前端口
    local config_file="$SINGBOX_CONFIG_DIR/config.json"
    local current_port=$(grep -o '"listen_port": [0-9]*' "$config_file" | cut -d':' -f2 | tr -d ' ')
    local protocol_type=$(grep -o '"type": "[^"]*"' "$config_file" | head -1 | cut -d'"' -f4)
    
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}                端口更改${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  当前协议: ${GREEN}$protocol_type${NC}"
    echo -e "  当前端口: ${GREEN}$current_port${NC}"
    echo
    
    # 输入新端口
    while true; do
        read -p "请输入新端口 (1024-65535) 或输入 'r' 随机生成: " new_port
        
        if [[ "$new_port" == "r" || "$new_port" == "R" ]]; then
            new_port=$(generate_random_port)
            log_info "随机生成端口: $new_port"
            break
        elif [[ "$new_port" =~ ^[0-9]+$ ]] && [[ $new_port -ge 1024 ]] && [[ $new_port -le 65535 ]]; then
            # 检查端口是否被占用
            if check_port "$new_port"; then
                log_error "端口 $new_port 已被占用，请选择其他端口"
                continue
            fi
            break
        else
            log_error "无效端口，请输入 1024-65535 之间的数字"
        fi
    done
    
    # 确认更改
    echo
    log_info "即将将端口从 $current_port 更改为 $new_port"
    read -p "确认更改？(y/N): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "操作已取消"
        read -p "按回车键返回主菜单..." -r
        return
    fi
    
    # 停止服务
    log_info "正在停止服务..."
    systemctl stop sing-box
    
    # 备份配置文件
    cp "$config_file" "$config_file.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 更新配置文件中的端口
    log_info "正在更新配置文件..."
    sed -i "s/\"listen_port\": $current_port/\"listen_port\": $new_port/g" "$config_file"
    
    # 验证配置文件
    if ! "$SINGBOX_BINARY" check -c "$config_file" &>/dev/null; then
        log_error "配置文件验证失败，正在恢复备份..."
        cp "$config_file.backup.$(date +%Y%m%d_%H%M%S)" "$config_file"
        systemctl start sing-box
        read -p "按回车键返回主菜单..." -r
        return 1
    fi
    
    # 启动服务
    log_info "正在启动服务..."
    if systemctl start sing-box; then
        log_info "端口更改成功！"
        echo
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  协议类型: ${GREEN}$protocol_type${NC}"
        echo -e "  服务器地址: ${GREEN}$IP_ADDRESS${NC}"
        echo -e "  新端口: ${GREEN}$new_port${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # 更新当前端口信息
        CURRENT_PORT="$new_port"
    else
        log_error "服务启动失败，正在恢复备份..."
        cp "$config_file.backup.$(date +%Y%m%d_%H%M%S)" "$config_file"
        systemctl start sing-box
    fi
    
    echo
    read -p "按回车键返回主菜单..." -r
}

# 生成分享链接
generate_share_links() {
    local config_file="$SINGBOX_CONFIG_DIR/config.json"
    local protocol_type=$(grep -o '"type": "[^"]*"' "$config_file" | head -1 | cut -d'"' -f4)
    local listen_port=$(grep -o '"listen_port": [0-9]*' "$config_file" | cut -d':' -f2 | tr -d ' ')
    
    case $protocol_type in
        "vless")
            local uuid=$(grep -o '"uuid": "[^"]*"' "$config_file" | cut -d'"' -f4)
            local flow=$(grep -o '"flow": "[^"]*"' "$config_file" | cut -d'"' -f4)
            local server_name=$(grep -o '"server_name": "[^"]*"' "$config_file" | cut -d'"' -f4)
            local private_key=$(grep -o '"private_key": "[^"]*"' "$config_file" | cut -d'"' -f4)
            local short_id=$(grep -o '"short_id": \[\s*"[^"]*"' "$config_file" | cut -d'"' -f4)
            
            # 生成公钥
            local public_key=$(echo "$private_key" | base64 -d 2>/dev/null | xxd -p -c 32 | head -c 64)
            if [[ -z "$public_key" ]]; then
                # 如果无法解析私钥，尝试重新生成密钥对
                local key_pair=$("$SINGBOX_BINARY" generate reality-keypair 2>/dev/null)
                public_key=$(echo "$key_pair" | grep "PublicKey:" | awk '{print $2}')
            fi
            
            # VLESS Reality 链接
            local vless_link="vless://${uuid}@${IP_ADDRESS}:${listen_port}?encryption=none&flow=${flow}&security=reality&sni=${server_name}&fp=chrome&pbk=${public_key}&sid=${short_id}&type=tcp&headerType=none#VLESS-Reality-${IP_ADDRESS}"
            echo "$vless_link"
            ;;
        "vmess")
            local uuid=$(grep -o '"uuid": "[^"]*"' "$config_file" | cut -d'"' -f4)
            local ws_path=$(grep -o '"path": "[^"]*"' "$config_file" | cut -d'"' -f4)
            local tls_enabled=$(grep -q '"tls"' "$config_file" && echo "tls" || echo "none")
            
            # VMess 配置 JSON
            local vmess_json='{"v":"2","ps":"VMess-WS-'$IP_ADDRESS'","add":"'$IP_ADDRESS'","port":"'$listen_port'","id":"'$uuid'","aid":"0","scy":"auto","net":"ws","type":"none","host":"","path":"'$ws_path'","tls":"'$tls_enabled'","sni":"","alpn":""}'
            
            # Base64 编码
            local vmess_link="vmess://$(echo -n "$vmess_json" | base64 -w 0)"
            echo "$vmess_link"
            ;;
        "hysteria2")
            local password=$(grep -o '"password": "[^"]*"' "$config_file" | cut -d'"' -f4)
            
            # Hysteria2 链接
            local hy2_link="hysteria2://${password}@${IP_ADDRESS}:${listen_port}/?insecure=1#Hysteria2-${IP_ADDRESS}"
            echo "$hy2_link"
            ;;
    esac
}

# 生成二维码
generate_qrcode() {
    local link="$1"
    local temp_file="/tmp/qrcode.txt"
    
    # 检查是否安装了 qrencode
    if ! command -v qrencode &> /dev/null; then
        log_info "正在安装二维码生成工具..."
        if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
            apt-get update && apt-get install -y qrencode
        elif [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
            yum install -y qrencode || dnf install -y qrencode
        fi
    fi
    
    if command -v qrencode &> /dev/null; then
        qrencode -t ANSIUTF8 "$link"
    else
        log_error "无法安装二维码生成工具，请手动复制链接"
    fi
}

# 配置分享
share_config() {
    show_logo
    
    if [[ ! -f "$SINGBOX_CONFIG_DIR/config.json" ]]; then
        log_error "未找到配置文件，请先安装协议"
        read -p "按回车键返回主菜单..." -r
        return 1
    fi
    
    local config_file="$SINGBOX_CONFIG_DIR/config.json"
    local protocol_type=$(grep -o '"type": "[^"]*"' "$config_file" | head -1 | cut -d'"' -f4)
    
    while true; do
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                配置分享${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  当前协议: ${GREEN}$protocol_type${NC}"
        echo
        echo -e "  ${GREEN}1.${NC} 显示连接链接"
        echo -e "  ${GREEN}2.${NC} 生成二维码"
        echo -e "  ${GREEN}3.${NC} 保存配置到文件"
        echo -e "  ${GREEN}4.${NC} 显示详细连接信息"
        echo -e "  ${GREEN}0.${NC} 返回主菜单"
        echo
        
        read -p "请选择操作 [0-4]: " choice
        
        case $choice in
            1)
                echo
                log_info "连接链接:"
                local share_link=$(generate_share_links)
                echo -e "${GREEN}$share_link${NC}"
                echo
                echo "请复制上述链接到客户端使用"
                ;;
            2)
                echo
                log_info "二维码:"
                local share_link=$(generate_share_links)
                echo
                generate_qrcode "$share_link"
                echo
                echo "请使用客户端扫描上述二维码"
                ;;
            3)
                local output_file="/root/sing-box-config-$(date +%Y%m%d_%H%M%S).txt"
                local share_link=$(generate_share_links)
                
                echo "协议类型: $protocol_type" > "$output_file"
                echo "服务器地址: $IP_ADDRESS" >> "$output_file"
                echo "连接链接: $share_link" >> "$output_file"
                echo "生成时间: $(date)" >> "$output_file"
                
                log_info "配置已保存到: $output_file"
                ;;
            4)
                show_connection_info
                return
                ;;
            0)
                return
                ;;
            *)
                log_error "无效选择，请重新输入"
                ;;
        esac
        
        echo
        read -p "按回车键继续..." -r
        show_logo
    done
}

# 查看日志
show_logs_menu() {
    show_logo
    
    if [[ ! -f "$SINGBOX_LOG_DIR/sing-box.log" ]]; then
        log_error "未找到日志文件"
        read -p "按回车键返回主菜单..." -r
        return 1
    fi
    
    while true; do
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                日志查看${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo
        echo -e "  ${GREEN}1.${NC} 查看实时日志"
        echo -e "  ${GREEN}2.${NC} 查看最近50行日志"
        echo -e "  ${GREEN}3.${NC} 查看最近100行日志"
        echo -e "  ${GREEN}4.${NC} 查看错误日志"
        echo -e "  ${GREEN}5.${NC} 清空日志"
        echo -e "  ${GREEN}0.${NC} 返回主菜单"
        echo
        
        read -p "请选择操作 [0-5]: " choice
        
        case $choice in
            1)
                echo
                log_info "实时日志 (按 Ctrl+C 退出):"
                echo
                tail -f "$SINGBOX_LOG_DIR/sing-box.log"
                ;;
            2)
                echo
                log_info "最近50行日志:"
                echo
                tail -n 50 "$SINGBOX_LOG_DIR/sing-box.log"
                ;;
            3)
                echo
                log_info "最近100行日志:"
                echo
                tail -n 100 "$SINGBOX_LOG_DIR/sing-box.log"
                ;;
            4)
                echo
                log_info "错误日志:"
                echo
                grep -i "error\|fail\|fatal" "$SINGBOX_LOG_DIR/sing-box.log" | tail -n 20
                ;;
            5)
                read -p "确认清空日志？(y/N): " confirm
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    > "$SINGBOX_LOG_DIR/sing-box.log"
                    log_info "日志已清空"
                else
                    log_info "操作已取消"
                fi
                ;;
            0)
                return
                ;;
            *)
                log_error "无效选择，请重新输入"
                ;;
        esac
        
        echo
        read -p "按回车键继续..." -r
        show_logo
    done
}

# 重新安装
reinstall_menu() {
    show_logo
    
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}                重新安装${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "  ${RED}警告: 此操作将删除当前配置并重新安装${NC}"
    echo -e "  ${RED}所有现有配置和数据将丢失！${NC}"
    echo
    
    read -p "确认重新安装？(y/N): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "操作已取消"
        read -p "按回车键返回主菜单..." -r
        return
    fi
    
    # 停止服务
    log_info "正在停止服务..."
    systemctl stop sing-box 2>/dev/null
    
    # 备份配置
    if [[ -f "$SINGBOX_CONFIG_DIR/config.json" ]]; then
        local backup_dir="/root/sing-box-backup-$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        cp -r "$SINGBOX_CONFIG_DIR"/* "$backup_dir"/
        log_info "配置已备份到: $backup_dir"
    fi
    
    # 删除配置文件
    rm -rf "$SINGBOX_CONFIG_DIR"
    rm -rf "$SINGBOX_LOG_DIR"
    
    log_info "配置清理完成，请选择要安装的协议"
    echo
    read -p "按回车键返回主菜单..." -r
}

# 卸载sing-box
uninstall_singbox() {
    show_logo
    
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}                卸载 sing-box${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "  ${RED}警告: 此操作将完全卸载 sing-box${NC}"
    echo -e "  ${RED}包括二进制文件、配置文件、日志文件和系统服务${NC}"
    echo
    
    read -p "确认卸载？(y/N): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "操作已取消"
        read -p "按回车键返回主菜单..." -r
        return
    fi
    
    # 停止并禁用服务
    log_info "正在停止服务..."
    systemctl stop sing-box 2>/dev/null
    systemctl disable sing-box 2>/dev/null
    
    # 删除系统服务文件
    if [[ -f "$SINGBOX_SERVICE_FILE" ]]; then
        rm -f "$SINGBOX_SERVICE_FILE"
        systemctl daemon-reload
        log_info "系统服务已删除"
    fi
    
    # 备份配置（可选）
    read -p "是否备份配置文件？(y/N): " backup_confirm
    if [[ "$backup_confirm" == "y" || "$backup_confirm" == "Y" ]]; then
        if [[ -d "$SINGBOX_CONFIG_DIR" ]]; then
            local backup_dir="/root/sing-box-backup-$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$backup_dir"
            cp -r "$SINGBOX_CONFIG_DIR"/* "$backup_dir"/
            log_info "配置已备份到: $backup_dir"
        fi
    fi
    
    # 删除文件和目录
    log_info "正在删除文件..."
    rm -f "$SINGBOX_BINARY"
    rm -rf "$SINGBOX_CONFIG_DIR"
    rm -rf "$SINGBOX_LOG_DIR"
    
    log_info "sing-box 卸载完成！"
    echo
    read -p "按回车键退出脚本..." -r
    exit 0
}

# 主函数
main() {
    show_logo
    check_root
    
    log_info "正在初始化安装环境..."
    
    # 系统检测
    check_system
    check_dependencies
    check_network
    
    log_info "系统环境检测完成，进入主菜单"
    sleep 2
    
    # 显示主菜单
    show_main_menu
}

# 脚本入口点
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi