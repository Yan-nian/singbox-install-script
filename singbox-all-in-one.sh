#!/bin/bash

# Sing-box 全能一键安装脚本
# 支持 VLESS Reality、VMess WebSocket、Hysteria2 协议
# 版本: v3.0.0 (All-in-One)
# 更新时间: 2025-01-16
# 特点: 无需外部模块，所有功能集成在一个文件中

# 设置错误处理
set -e

# 脚本信息
SCRIPT_NAME="Sing-box 全能一键安装脚本"
SCRIPT_VERSION="v3.0.0"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 基础变量
WORK_DIR="/var/lib/sing-box"
CONFIG_FILE="$WORK_DIR/config.json"
SINGBOX_BINARY="/usr/local/bin/sing-box"
SERVICE_NAME="sing-box"
LOG_FILE="/var/log/sing-box.log"

# 系统信息
OS=""
ARCH=""
PUBLIC_IP=""

# 协议变量
VLESS_UUID=""
VLESS_PORT="10443"
VLESS_PRIVATE_KEY=""
VLESS_PUBLIC_KEY=""
VLESS_SHORT_ID=""
VLESS_TARGET="www.yahoo.com:443"
VLESS_SERVER_NAME="www.yahoo.com"

VMESS_UUID=""
VMESS_PORT="10080"
VMESS_WS_PATH=""
VMESS_HOST=""

HY2_PASSWORD=""
HY2_PORT="36712"
HY2_OBFS_PASSWORD=""
HY2_UP_MBPS="100"
HY2_DOWN_MBPS="100"
HY2_DOMAIN=""
HY2_CERT_FILE=""
HY2_KEY_FILE=""

# ==================== 通用函数库 ====================

# 日志函数
log_info() {
    local message="$1"
    local details="${2:-}"
    echo -e "${GREEN}[INFO] $message${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $message" >> "$LOG_FILE" 2>/dev/null || true
    if [[ -n "$details" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Details: $details" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

log_success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $1" >> "$LOG_FILE" 2>/dev/null || true
}

log_warn() {
    echo -e "${YELLOW}[WARN] $*${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $*" >> "$LOG_FILE" 2>/dev/null || true
}

log_error() {
    local message="$1"
    local details="${2:-}"
    echo -e "${RED}[ERROR] $message${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $message" >> "$LOG_FILE" 2>/dev/null || true
    if [[ -n "$details" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] Details: $details" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 生成随机字符串
generate_random_string() {
    local length=${1:-16}
    local chars='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local result=''
    
    for ((i=0; i<length; i++)); do
        result+="${chars:RANDOM%${#chars}:1}"
    done
    
    echo "$result"
}

# 生成 UUID
generate_uuid() {
    if command_exists uuidgen; then
        uuidgen
    elif [[ -r /proc/sys/kernel/random/uuid ]]; then
        cat /proc/sys/kernel/random/uuid
    else
        # 使用 openssl 生成
        openssl rand -hex 16 | sed 's/\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.\{12\}\)/\1-\2-\3-\4-\5/'
    fi
}

# 检查端口是否被占用
check_port() {
    local port="$1"
    if ss -tuln | grep -q ":$port "; then
        return 0  # 端口被占用
    else
        return 1  # 端口可用
    fi
}

# 获取随机可用端口
get_random_port() {
    local port
    while true; do
        port=$((RANDOM % 55535 + 10000))
        if ! check_port "$port"; then
            echo "$port"
            break
        fi
    done
}

# 获取公网 IP
get_public_ip() {
    local ip
    ip=$(curl -s --max-time 10 ipv4.icanhazip.com 2>/dev/null || 
         curl -s --max-time 10 ifconfig.me 2>/dev/null || 
         curl -s --max-time 10 ip.sb 2>/dev/null || 
         echo "")
    
    if [[ -n "$ip" ]]; then
        echo "$ip"
    else
        log_warn "无法获取公网 IP"
        echo "127.0.0.1"
    fi
}

# 验证端口范围
validate_port() {
    local port="$1"
    if [[ "$port" =~ ^[0-9]+$ ]] && ((port >= 1 && port <= 65535)); then
        return 0
    else
        return 1
    fi
}

# 获取服务状态
get_service_status() {
    local service="$1"
    
    if systemctl is-active "$service" >/dev/null 2>&1; then
        echo "running"
    elif systemctl is-enabled "$service" >/dev/null 2>&1; then
        echo "stopped"
    else
        echo "disabled"
    fi
}

# 启动服务
start_service() {
    local service="$1"
    
    log_info "启动服务: $service"
    if systemctl start "$service"; then
        log_success "服务启动成功: $service"
        return 0
    else
        log_error "服务启动失败: $service"
        return 1
    fi
}

# 停止服务
stop_service() {
    local service="$1"
    
    log_info "停止服务: $service"
    if systemctl stop "$service"; then
        log_success "服务停止成功: $service"
        return 0
    else
        log_error "服务停止失败: $service"
        return 1
    fi
}

# 重启服务
restart_service() {
    local service="$1"
    
    log_info "重启服务: $service"
    if systemctl restart "$service"; then
        log_success "服务重启成功: $service"
        return 0
    else
        log_error "服务重启失败: $service"
        return 1
    fi
}

# 等待用户输入
wait_for_input() {
    echo ""
    read -p "按回车键继续..." 
}

# ==================== 系统检查和安装 ====================

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误: 此脚本需要 root 权限运行${NC}"
        echo -e "${YELLOW}请使用 sudo 或切换到 root 用户${NC}"
        exit 1
    fi
}

# 检测系统信息
detect_system() {
    # 检测操作系统
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS="$ID"
    elif [[ -f /etc/redhat-release ]]; then
        OS="centos"
    else
        echo -e "${RED}错误: 不支持的操作系统${NC}"
        exit 1
    fi
    
    # 检测架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        *) 
            echo -e "${RED}错误: 不支持的架构 $ARCH${NC}"
            exit 1
            ;;
    esac
    
    # 获取公网 IP
    PUBLIC_IP=$(get_public_ip)
    
    echo -e "${GREEN}系统检测完成:${NC}"
    echo -e "  操作系统: $OS"
    echo -e "  架构: $ARCH"
    echo -e "  公网IP: $PUBLIC_IP"
}

# 安装依赖
install_dependencies() {
    echo -e "${CYAN}检查和安装基础依赖...${NC}"
    
    # 检查必要的命令
    local missing_deps=()
    
    if ! command -v curl >/dev/null 2>&1; then
        missing_deps+=("curl")
    fi
    
    if ! command -v tar >/dev/null 2>&1; then
        missing_deps+=("tar")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${YELLOW}正在安装缺失的依赖: ${missing_deps[*]}${NC}"
        
        # 根据系统类型安装依赖
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update >/dev/null 2>&1
            apt-get install -y "${missing_deps[@]}" >/dev/null 2>&1
        elif command -v yum >/dev/null 2>&1; then
            yum install -y "${missing_deps[@]}" >/dev/null 2>&1
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y "${missing_deps[@]}" >/dev/null 2>&1
        else
            echo -e "${RED}错误: 无法自动安装依赖，请手动安装: ${missing_deps[*]}${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}依赖安装完成${NC}"
    else
        echo -e "${GREEN}所有依赖已满足${NC}"
    fi
}

# 创建工作目录
create_directories() {
    echo -e "${CYAN}创建工作目录...${NC}"
    
    mkdir -p "$WORK_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # 设置权限
    chmod 755 "$WORK_DIR"
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    echo -e "${GREEN}工作目录创建完成${NC}"
}

# 下载和安装 Sing-box
download_and_install_singbox() {
    echo -e "${CYAN}正在下载和安装 Sing-box...${NC}"
    
    # 检查系统架构
    if [[ -z "$ARCH" ]]; then
        echo -e "${RED}错误: 系统架构未检测${NC}"
        return 1
    fi
    
    # 获取最新版本
    local latest_version
    latest_version=$(curl -fsSL "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep '"tag_name"' | cut -d'"' -f4 | sed 's/^v//')
    
    if [[ -z "$latest_version" ]]; then
        echo -e "${RED}错误: 无法获取最新版本信息${NC}"
        return 1
    fi
    
    echo -e "${GREEN}最新版本: $latest_version${NC}"
    
    # 构建下载URL
    local download_url="https://github.com/SagerNet/sing-box/releases/download/v${latest_version}/sing-box-${latest_version}-linux-${ARCH}.tar.gz"
    local temp_file="/tmp/sing-box-${latest_version}.tar.gz"
    
    # 下载文件
    echo -e "${CYAN}正在下载 Sing-box...${NC}"
    if ! curl -fsSL "$download_url" -o "$temp_file"; then
        echo -e "${RED}错误: 下载失败${NC}"
        return 1
    fi
    
    # 解压和安装
    local extract_dir="/tmp/sing-box-extract"
    mkdir -p "$extract_dir"
    
    if tar -xzf "$temp_file" -C "$extract_dir" --strip-components=1; then
        if [[ -f "$extract_dir/sing-box" ]]; then
            cp "$extract_dir/sing-box" "$SINGBOX_BINARY"
            chmod +x "$SINGBOX_BINARY"
            echo -e "${GREEN}Sing-box 安装成功${NC}"
        else
            echo -e "${RED}错误: 解压后未找到二进制文件${NC}"
            return 1
        fi
    else
        echo -e "${RED}错误: 解压失败${NC}"
        return 1
    fi
    
    # 清理临时文件
    rm -rf "$temp_file" "$extract_dir"
    return 0
}

# 创建系统服务
create_service() {
    echo -e "${CYAN}正在创建系统服务...${NC}"
    
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=$SINGBOX_BINARY run -c $CONFIG_FILE
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    
    echo -e "${GREEN}系统服务创建完成${NC}"
}

# ==================== 协议配置模块 ====================

# 生成 Reality 密钥对
generate_reality_keypair() {
    local keypair
    
    # 检查 sing-box 二进制文件是否存在
    if [[ ! -f "$SINGBOX_BINARY" ]]; then
        log_error "Sing-box 二进制文件不存在: $SINGBOX_BINARY"
        return 1
    fi
    
    keypair=$($SINGBOX_BINARY generate reality-keypair 2>/dev/null)
    
    if [[ -n "$keypair" ]]; then
        VLESS_PRIVATE_KEY=$(echo "$keypair" | grep "PrivateKey" | awk '{print $2}')
        VLESS_PUBLIC_KEY=$(echo "$keypair" | grep "PublicKey" | awk '{print $2}')
        
        # 验证密钥格式
        if [[ -n "$VLESS_PRIVATE_KEY" ]] && [[ -n "$VLESS_PUBLIC_KEY" ]]; then
            log_success "Reality 密钥对生成成功"
        else
            log_error "密钥对格式验证失败"
            return 1
        fi
    else
        log_error "Reality 密钥对生成失败"
        return 1
    fi
}

# 生成 Reality Short ID
generate_reality_short_id() {
    VLESS_SHORT_ID=$(openssl rand -hex 8)
    log_info "生成 Short ID: $VLESS_SHORT_ID"
}

# 检测可用的 Reality 目标
detect_reality_target() {
    local targets=(
        "www.yahoo.com:443"
        "www.microsoft.com:443"
        "www.cloudflare.com:443"
        "www.apple.com:443"
        "www.amazon.com:443"
        "www.google.com:443"
    )
    
    log_info "检测可用的 Reality 目标..."
    
    # 优先使用 yahoo.com，因为它在大多数地区都可访问
    local priority_target="www.yahoo.com:443"
    local host port
    host=$(echo "$priority_target" | cut -d':' -f1)
    port=$(echo "$priority_target" | cut -d':' -f2)
    
    if timeout 5 bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
        VLESS_TARGET="$priority_target"
        VLESS_SERVER_NAME="$host"
        log_success "选择 Reality 目标: $priority_target"
        return 0
    fi
    
    # 如果优先目标不可用，测试其他目标
    for target in "${targets[@]}"; do
        [[ "$target" == "$priority_target" ]] && continue
        host=$(echo "$target" | cut -d':' -f1)
        port=$(echo "$target" | cut -d':' -f2)
        
        if timeout 5 bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
            VLESS_TARGET="$target"
            VLESS_SERVER_NAME="$host"
            log_success "选择 Reality 目标: $target"
            return 0
        fi
    done
    
    log_warn "无法连接到预设目标，使用默认配置"
    VLESS_TARGET="www.yahoo.com:443"
    VLESS_SERVER_NAME="www.yahoo.com"
}

# 配置 VLESS Reality
configure_vless_reality() {
    log_info "配置 VLESS Reality Vision..."
    
    # 生成 UUID
    if [[ -z "$VLESS_UUID" ]]; then
        VLESS_UUID=$(generate_uuid)
        log_info "生成 UUID: $VLESS_UUID"
    fi
    
    # 检查端口
    if check_port "$VLESS_PORT"; then
        log_warn "端口 $VLESS_PORT 已被占用"
        VLESS_PORT=$(get_random_port)
        log_info "使用随机端口: $VLESS_PORT"
    fi
    
    # 确保使用高端口
    if [ "$VLESS_PORT" -lt 10000 ]; then
        log_warn "VLESS端口 $VLESS_PORT 低于10000，重新分配高端口"
        VLESS_PORT=$(get_random_port)
        log_info "VLESS高端口: $VLESS_PORT"
    fi
    
    # 生成密钥对
    if [[ -z "$VLESS_PRIVATE_KEY" ]] || [[ -z "$VLESS_PUBLIC_KEY" ]]; then
        generate_reality_keypair
    fi
    
    # 生成 Short ID
    if [[ -z "$VLESS_SHORT_ID" ]]; then
        generate_reality_short_id
    fi
    
    # 检测目标
    detect_reality_target
    
    log_success "VLESS Reality 配置完成"
}

# 配置 VMess WebSocket
configure_vmess_websocket() {
    log_info "配置 VMess WebSocket..."
    
    # 生成 UUID
    if [[ -z "$VMESS_UUID" ]]; then
        VMESS_UUID=$(generate_uuid)
        log_info "生成 UUID: $VMESS_UUID"
    fi
    
    # 生成 WebSocket 路径
    if [[ -z "$VMESS_WS_PATH" ]]; then
        VMESS_WS_PATH="/$(generate_random_string 8)"
        log_info "生成 WebSocket 路径: $VMESS_WS_PATH"
    fi
    
    # 设置 Host
    if [[ -z "$VMESS_HOST" ]]; then
        VMESS_HOST="$PUBLIC_IP"
    fi
    
    # 检查端口
    if check_port "$VMESS_PORT"; then
        log_warn "端口 $VMESS_PORT 已被占用"
        VMESS_PORT=$(get_random_port)
        log_info "使用随机端口: $VMESS_PORT"
    fi
    
    # 确保使用高端口
    if [ "$VMESS_PORT" -lt 10000 ]; then
        log_warn "VMess端口 $VMESS_PORT 低于10000，重新分配高端口"
        VMESS_PORT=$(get_random_port)
        log_info "VMess高端口: $VMESS_PORT"
    fi
    
    log_success "VMess WebSocket 配置完成"
}

# 配置 Hysteria2
configure_hysteria2() {
    log_info "配置 Hysteria2..."
    
    # 生成密码
    if [[ -z "$HY2_PASSWORD" ]]; then
        HY2_PASSWORD=$(generate_random_string 16)
        log_info "生成密码: $HY2_PASSWORD"
    fi
    
    # 生成混淆密码
    if [[ -z "$HY2_OBFS_PASSWORD" ]]; then
        HY2_OBFS_PASSWORD=$(generate_random_string 16)
        log_info "生成混淆密码: $HY2_OBFS_PASSWORD"
    fi
    
    # 设置域名
    if [[ -z "$HY2_DOMAIN" ]]; then
        HY2_DOMAIN="$PUBLIC_IP"
    fi
    
    # 检查端口
    if check_port "$HY2_PORT"; then
        log_warn "端口 $HY2_PORT 已被占用"
        HY2_PORT=$(get_random_port)
        log_info "使用随机端口: $HY2_PORT"
    fi
    
    # 确保使用高端口
    if [ "$HY2_PORT" -lt 10000 ]; then
        log_warn "Hysteria2端口 $HY2_PORT 低于10000，重新分配高端口"
        HY2_PORT=$(get_random_port)
        log_info "Hysteria2高端口: $HY2_PORT"
    fi
    
    log_success "Hysteria2 配置完成"
}

# 生成完整配置文件
generate_config() {
    echo -e "${CYAN}正在生成配置文件...${NC}"
    
    cat > "$CONFIG_FILE" << EOF
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
EOF

    local inbounds=()
    
    # VLESS Reality 入站
    if [[ -n "$VLESS_UUID" ]]; then
        inbounds+=("vless")
        cat >> "$CONFIG_FILE" << EOF
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": $VLESS_PORT,
      "users": [
        {
          "uuid": "$VLESS_UUID"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$VLESS_SERVER_NAME",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "$VLESS_TARGET",
            "server_port": $(echo "$VLESS_TARGET" | cut -d':' -f2)
          },
          "private_key": "$VLESS_PRIVATE_KEY",
          "short_id": ["$VLESS_SHORT_ID"]
        }
      }
    }
EOF
    fi
    
    # VMess WebSocket 入站
    if [[ -n "$VMESS_UUID" ]]; then
        [[ ${#inbounds[@]} -gt 0 ]] && echo "," >> "$CONFIG_FILE"
        inbounds+=("vmess")
        cat >> "$CONFIG_FILE" << EOF
    {
      "type": "vmess",
      "tag": "vmess-in",
      "listen": "::",
      "listen_port": $VMESS_PORT,
      "users": [
        {
          "uuid": "$VMESS_UUID",
          "alterId": 0
        }
      ],
      "transport": {
        "type": "ws",
        "path": "$VMESS_WS_PATH",
        "headers": {
          "Host": "$VMESS_HOST"
        }
      }
    }
EOF
    fi
    
    # Hysteria2 入站
    if [[ -n "$HY2_PASSWORD" ]]; then
        [[ ${#inbounds[@]} -gt 0 ]] && echo "," >> "$CONFIG_FILE"
        inbounds+=("hysteria2")
        cat >> "$CONFIG_FILE" << EOF
    {
      "type": "hysteria2",
      "tag": "hy2-in",
      "listen": "::",
      "listen_port": $HY2_PORT,
      "users": [
        {
          "password": "$HY2_PASSWORD"
        }
      ],
      "masquerade": "https://bing.com",
      "tls": {
        "enabled": true,
        "alpn": [
          "h3"
        ],
        "certificate_path": "/etc/ssl/private/hysteria.crt",
        "key_path": "/etc/ssl/private/hysteria.key"
      },
      "obfs": {
        "type": "salamander",
        "salamander": {
          "password": "$HY2_OBFS_PASSWORD"
        }
      }
    }
EOF
    fi
    
    cat >> "$CONFIG_FILE" << EOF
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
    
    # 为 Hysteria2 生成自签名证书
    if [[ -n "$HY2_PASSWORD" ]]; then
        generate_hysteria2_cert
    fi
    
    log_success "配置文件生成完成: $CONFIG_FILE"
}

# 生成 Hysteria2 自签名证书
generate_hysteria2_cert() {
    log_info "生成 Hysteria2 自签名证书..."
    
    mkdir -p /etc/ssl/private
    
    # 生成私钥
    openssl genpkey -algorithm RSA -out /etc/ssl/private/hysteria.key -pkcs8
    
    # 生成证书
    openssl req -new -x509 -key /etc/ssl/private/hysteria.key -out /etc/ssl/private/hysteria.crt -days 36500 -subj "/CN=$HY2_DOMAIN"
    
    # 设置权限
    chmod 600 /etc/ssl/private/hysteria.key
    chmod 644 /etc/ssl/private/hysteria.crt
    
    log_success "Hysteria2 证书生成完成"
}

# ==================== 分享链接生成 ====================

# 生成 VLESS Reality 分享链接
generate_vless_share_link() {
    local server_ip="${1:-$PUBLIC_IP}"
    local remark="${2:-VLESS-Reality}"
    
    if [[ -z "$VLESS_UUID" ]] || [[ -z "$VLESS_PORT" ]]; then
        log_error "VLESS 配置信息不完整"
        return 1
    fi
    
    # 构建 VLESS 链接
    local vless_link="vless://${VLESS_UUID}@${server_ip}:${VLESS_PORT}"
    vless_link+="?encryption=none"
    vless_link+="&security=reality"
    vless_link+="&sni=${VLESS_SERVER_NAME}"
    vless_link+="&fp=chrome"
    vless_link+="&pbk=${VLESS_PUBLIC_KEY}"
    vless_link+="&sid=${VLESS_SHORT_ID}"
    vless_link+="&type=tcp"
    vless_link+="&headerType=none"
    vless_link+="#${remark}"
    
    echo "$vless_link"
}

# 生成 VMess WebSocket 分享链接
generate_vmess_share_link() {
    local server_ip="${1:-$PUBLIC_IP}"
    local remark="${2:-VMess-WS}"
    
    if [[ -z "$VMESS_UUID" ]] || [[ -z "$VMESS_PORT" ]]; then
        log_error "VMess 配置信息不完整"
        return 1
    fi
    
    # 构建 VMess 配置 JSON
    local vmess_json
    vmess_json=$(cat << EOF
{
  "v": "2",
  "ps": "$remark",
  "add": "$server_ip",
  "port": "$VMESS_PORT",
  "id": "$VMESS_UUID",
  "aid": "0",
  "scy": "auto",
  "net": "ws",
  "type": "none",
  "host": "$VMESS_HOST",
  "path": "$VMESS_WS_PATH",
  "tls": "",
  "sni": "",
  "alpn": ""
}
EOF
    )
    
    # Base64 编码
    local encoded
    encoded=$(echo -n "$vmess_json" | base64 -w 0)
    
    echo "vmess://$encoded"
}

# 生成 Hysteria2 分享链接
generate_hysteria2_share_link() {
    local server_ip="${1:-$PUBLIC_IP}"
    local remark="${2:-Hysteria2}"
    
    if [[ -z "$HY2_PASSWORD" ]] || [[ -z "$HY2_PORT" ]]; then
        log_error "Hysteria2 配置信息不完整"
        return 1
    fi
    
    # 构建 Hysteria2 链接
    local hy2_link="hysteria2://${HY2_PASSWORD}@${server_ip}:${HY2_PORT}"
    hy2_link+="?obfs=salamander"
    hy2_link+="&obfs-password=${HY2_OBFS_PASSWORD}"
    hy2_link+="&sni=${HY2_DOMAIN}"
    hy2_link+="&insecure=1"
    hy2_link+="#${remark}"
    
    echo "$hy2_link"
}

# 生成所有分享链接
generate_share_links() {
    echo -e "${CYAN}=== 分享链接 ===${NC}"
    echo ""
    
    local has_config=false
    
    # VLESS Reality
    if [[ -n "$VLESS_UUID" ]]; then
        echo -e "${GREEN}VLESS Reality Vision:${NC}"
        local vless_link
        vless_link=$(generate_vless_share_link)
        echo "$vless_link"
        echo ""
        has_config=true
    fi
    
    # VMess WebSocket
    if [[ -n "$VMESS_UUID" ]]; then
        echo -e "${GREEN}VMess WebSocket:${NC}"
        local vmess_link
        vmess_link=$(generate_vmess_share_link)
        echo "$vmess_link"
        echo ""
        has_config=true
    fi
    
    # Hysteria2
    if [[ -n "$HY2_PASSWORD" ]]; then
        echo -e "${GREEN}Hysteria2:${NC}"
        local hy2_link
        hy2_link=$(generate_hysteria2_share_link)
        echo "$hy2_link"
        echo ""
        has_config=true
    fi
    
    if [[ "$has_config" == "false" ]]; then
        echo -e "${YELLOW}未找到已配置的协议${NC}"
        echo -e "${YELLOW}请先配置协议后再生成分享链接${NC}"
    fi
    
    wait_for_input
}

# ==================== 菜单系统 ====================

# 显示横幅
show_banner() {
    clear
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${CYAN}                    $SCRIPT_NAME${NC}"
    echo -e "${CYAN}                      $SCRIPT_VERSION${NC}"
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${GREEN}支持协议:${NC}"
    echo -e "  ${YELLOW}•${NC} VLESS Reality Vision"
    echo -e "  ${YELLOW}•${NC} VMess WebSocket"
    echo -e "  ${YELLOW}•${NC} Hysteria2"
    echo -e "${CYAN}================================================================${NC}"
    echo ""
}

# 显示主菜单
show_main_menu() {
    while true; do
        clear
        echo -e "${CYAN}================================================================${NC}"
        echo -e "${CYAN}                    Sing-box 管理面板${NC}"
        echo -e "${CYAN}================================================================${NC}"
        echo ""
        
        # 显示系统信息
        echo -e "${GREEN}系统信息:${NC} $OS ($ARCH)"
        echo -e "${GREEN}公网IP:${NC} $PUBLIC_IP"
        
        # 显示服务状态
        local status=$(get_service_status "$SERVICE_NAME")
        case "$status" in
            "running")
                echo -e "${GREEN}服务状态:${NC} ${GREEN}运行中${NC}"
                ;;
            "stopped")
                echo -e "${GREEN}服务状态:${NC} ${YELLOW}已停止${NC}"
                ;;
            *)
                echo -e "${GREEN}服务状态:${NC} ${RED}未启用${NC}"
                ;;
        esac
        
        # 显示配置状态
        echo -e "${GREEN}配置状态:${NC}"
        local status_line=""
        [[ -n "$VLESS_PORT" ]] && status_line+="VLESS(${VLESS_PORT}) "
        [[ -n "$VMESS_PORT" ]] && status_line+="VMess(${VMESS_PORT}) "
        [[ -n "$HY2_PORT" ]] && status_line+="Hysteria2(${HY2_PORT}) "
        
        if [[ -n "$status_line" ]]; then
            echo -e "${GREEN}已配置:${NC} $status_line"
        else
            echo -e "${YELLOW}未配置任何协议${NC}"
        fi
        echo ""
        
        # 菜单选项
        echo -e "${YELLOW}请选择操作:${NC}"
        echo ""
        echo -e "  ${GREEN}1.${NC} 一键配置三协议"
        echo -e "  ${GREEN}2.${NC} 配置单个协议"
        echo -e "  ${GREEN}3.${NC} 管理服务"
        echo -e "  ${GREEN}4.${NC} 查看配置信息"
        echo -e "  ${GREEN}5.${NC} 生成分享链接"
        echo -e "  ${GREEN}6.${NC} 卸载 Sing-box"
        echo -e "  ${GREEN}0.${NC} 退出"
        echo ""
        echo -e "${CYAN}================================================================${NC}"
        
        local choice
        echo -n -e "${YELLOW}请输入选择 [0-6]: ${NC}"
        read -r choice
        
        case "$choice" in
            1) quick_setup_all_protocols ;;
            2) show_protocol_menu ;;
            3) show_service_menu ;;
            4) show_config_info ;;
            5) generate_share_links ;;
            6) uninstall_singbox ;;
            0) 
                echo -e "${GREEN}感谢使用！${NC}"
                exit 0
                ;;
            *) 
                echo -e "${RED}无效选择，请重新输入${NC}"
                wait_for_input
                ;;
        esac
    done
}

# 协议配置菜单
show_protocol_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== 协议配置菜单 ===${NC}"
        echo ""
        echo -e "${YELLOW}请选择要配置的协议:${NC}"
        echo ""
        echo -e "  ${GREEN}1.${NC} VLESS Reality Vision"
        echo -e "  ${GREEN}2.${NC} VMess WebSocket"
        echo -e "  ${GREEN}3.${NC} Hysteria2"
        echo -e "  ${GREEN}0.${NC} 返回主菜单"
        echo ""
        
        local choice
        echo -n -e "${YELLOW}请输入选择 [0-3]: ${NC}"
        read -r choice
        
        case "$choice" in
            1)
                configure_vless_reality
                generate_config
                restart_service "$SERVICE_NAME"
                wait_for_input
                ;;
            2)
                configure_vmess_websocket
                generate_config
                restart_service "$SERVICE_NAME"
                wait_for_input
                ;;
            3)
                configure_hysteria2
                generate_config
                restart_service "$SERVICE_NAME"
                wait_for_input
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                wait_for_input
                ;;
        esac
    done
}

# 服务管理菜单
show_service_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== 服务管理菜单 ===${NC}"
        echo ""
        
        local status=$(get_service_status "$SERVICE_NAME")
        echo -e "${GREEN}当前状态:${NC} "
        case "$status" in
            "running") echo -e "${GREEN}运行中${NC}" ;;
            "stopped") echo -e "${YELLOW}已停止${NC}" ;;
            *) echo -e "${RED}未启用${NC}" ;;
        esac
        echo ""
        
        echo -e "${YELLOW}请选择操作:${NC}"
        echo ""
        echo -e "  ${GREEN}1.${NC} 启动服务"
        echo -e "  ${GREEN}2.${NC} 停止服务"
        echo -e "  ${GREEN}3.${NC} 重启服务"
        echo -e "  ${GREEN}4.${NC} 查看日志"
        echo -e "  ${GREEN}0.${NC} 返回主菜单"
        echo ""
        
        local choice
        echo -n -e "${YELLOW}请输入选择 [0-4]: ${NC}"
        read -r choice
        
        case "$choice" in
            1)
                start_service "$SERVICE_NAME"
                wait_for_input
                ;;
            2)
                stop_service "$SERVICE_NAME"
                wait_for_input
                ;;
            3)
                restart_service "$SERVICE_NAME"
                wait_for_input
                ;;
            4)
                show_service_logs
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                wait_for_input
                ;;
        esac
    done
}

# 显示服务日志
show_service_logs() {
    clear
    echo -e "${CYAN}=== Sing-box 服务日志 ===${NC}"
    echo ""
    echo -e "${YELLOW}最近50行日志:${NC}"
    echo ""
    
    if systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
        journalctl -u "$SERVICE_NAME" -n 50 --no-pager
    else
        echo -e "${RED}服务未运行${NC}"
    fi
    
    wait_for_input
}

# 显示配置信息
show_config_info() {
    clear
    echo -e "${CYAN}=== 配置信息 ===${NC}"
    echo ""
    
    # VLESS Reality
    if [[ -n "$VLESS_UUID" ]]; then
        echo -e "${GREEN}VLESS Reality Vision:${NC}"
        echo -e "  端口: $VLESS_PORT"
        echo -e "  UUID: $VLESS_UUID"
        echo -e "  目标: $VLESS_TARGET"
        echo -e "  服务器名: $VLESS_SERVER_NAME"
        echo -e "  公钥: $VLESS_PUBLIC_KEY"
        echo -e "  Short ID: $VLESS_SHORT_ID"
        echo ""
    fi
    
    # VMess WebSocket
    if [[ -n "$VMESS_UUID" ]]; then
        echo -e "${GREEN}VMess WebSocket:${NC}"
        echo -e "  端口: $VMESS_PORT"
        echo -e "  UUID: $VMESS_UUID"
        echo -e "  路径: $VMESS_WS_PATH"
        echo -e "  Host: $VMESS_HOST"
        echo ""
    fi
    
    # Hysteria2
    if [[ -n "$HY2_PASSWORD" ]]; then
        echo -e "${GREEN}Hysteria2:${NC}"
        echo -e "  端口: $HY2_PORT"
        echo -e "  密码: $HY2_PASSWORD"
        echo -e "  混淆密码: $HY2_OBFS_PASSWORD"
        echo -e "  域名: $HY2_DOMAIN"
        echo ""
    fi
    
    if [[ -z "$VLESS_UUID" ]] && [[ -z "$VMESS_UUID" ]] && [[ -z "$HY2_PASSWORD" ]]; then
        echo -e "${YELLOW}未配置任何协议${NC}"
    fi
    
    wait_for_input
}

# ==================== 一键配置功能 ====================

# 一键配置所有协议
quick_setup_all_protocols() {
    echo -e "${CYAN}=== 一键配置三协议 ===${NC}"
    echo ""
    echo -e "${YELLOW}正在配置 VLESS Reality + VMess WebSocket + Hysteria2...${NC}"
    echo ""
    
    # 配置所有协议
    configure_vless_reality
    configure_vmess_websocket
    configure_hysteria2
    
    # 生成配置文件
    generate_config
    
    # 重启服务
    restart_service "$SERVICE_NAME"
    
    echo ""
    echo -e "${GREEN}=== 配置完成 ===${NC}"
    echo ""
    echo -e "${CYAN}协议信息:${NC}"
    echo -e "  VLESS Reality: 端口 $VLESS_PORT"
    echo -e "  VMess WebSocket: 端口 $VMESS_PORT"
    echo -e "  Hysteria2: 端口 $HY2_PORT"
    echo ""
    
    # 显示分享链接
    generate_share_links
}

# ==================== 安装和卸载 ====================

# 执行完整安装
perform_installation() {
    echo -e "${CYAN}=== 开始安装 Sing-box ===${NC}"
    echo ""
    
    # 安装依赖
    install_dependencies
    
    # 创建目录
    create_directories
    
    # 下载和安装
    if ! download_and_install_singbox; then
        echo -e "${RED}安装失败${NC}"
        exit 1
    fi
    
    # 创建服务
    create_service
    
    echo ""
    echo -e "${GREEN}=== 安装完成 ===${NC}"
    echo -e "${YELLOW}现在可以配置协议了${NC}"
    
    wait_for_input
}

# 卸载 Sing-box
uninstall_singbox() {
    echo -e "${CYAN}=== 卸载 Sing-box ===${NC}"
    echo ""
    echo -e "${RED}警告: 这将完全删除 Sing-box 及其所有配置${NC}"
    echo ""
    
    read -p "确认卸载？[y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}取消卸载${NC}"
        return
    fi
    
    # 停止服务
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    
    # 删除服务文件
    rm -f "/etc/systemd/system/$SERVICE_NAME.service"
    systemctl daemon-reload
    
    # 删除二进制文件
    rm -f "$SINGBOX_BINARY"
    
    # 删除配置目录
    rm -rf "$WORK_DIR"
    
    # 删除日志文件
    rm -f "$LOG_FILE"
    
    # 删除证书文件
    rm -f /etc/ssl/private/hysteria.crt
    rm -f /etc/ssl/private/hysteria.key
    
    echo -e "${GREEN}卸载完成${NC}"
    wait_for_input
}

# 检查安装状态
check_installation_status() {
    local status="not_installed"
    local install_method="unknown"
    local details=""
    
    # 检查二进制文件
    if [[ -f "$SINGBOX_BINARY" ]]; then
        status="installed"
        install_method="binary"
        details="已安装"
    fi
    
    # 检查系统服务
    if systemctl list-unit-files 2>/dev/null | grep -q "sing-box.service"; then
        status="installed"
        if [[ "$install_method" == "unknown" ]]; then
            install_method="service"
            details="已安装"
        fi
    fi
    
    echo "$status:$install_method:$details"
}

# 显示安装菜单
show_installation_menu() {
    local install_info="$1"
    local status=$(echo "$install_info" | cut -d: -f1)
    
    echo -e "${CYAN}=== Sing-box 管理 ===${NC}"
    
    case "$status" in
        "installed")
            show_main_menu
            ;;
        "not_installed")
            echo -e "${YELLOW}Sing-box 未安装，开始安装...${NC}"
            perform_installation
            # 安装完成后进入主菜单
            show_main_menu
            ;;
    esac
}

# ==================== 主函数 ====================

# 主函数
main() {
    # 基础检查
    check_root
    show_banner
    detect_system
    create_directories
    
    # 检查安装状态并显示菜单
    local install_info=$(check_installation_status)
    show_installation_menu "$install_info"
}

# ==================== 命令行参数处理 ====================

# 处理命令行参数
case "${1:-}" in
    --install)
        check_root
        detect_system
        perform_installation
        ;;
    --uninstall)
        check_root
        uninstall_singbox
        ;;
    --quick-setup)
        check_root
        echo -e "${CYAN}=== 一键安装并配置三协议 ===${NC}"
        echo ""
        
        # 先安装 Sing-box
        if ! command -v sing-box &> /dev/null; then
            echo -e "${YELLOW}正在安装 Sing-box...${NC}"
            detect_system
            perform_installation
        else
            echo -e "${GREEN}Sing-box 已安装${NC}"
        fi
        
        # 执行一键配置
        echo -e "${YELLOW}正在进行一键配置三协议...${NC}"
        quick_setup_all_protocols
        exit 0
        ;;
    --help|-h)
        echo -e "${CYAN}$SCRIPT_NAME $SCRIPT_VERSION${NC}"
        echo ""
        echo -e "${YELLOW}用法:${NC}"
        echo -e "  $0                # 启动交互式菜单"
        echo -e "  $0 --install      # 直接安装"
        echo -e "  $0 --uninstall    # 一键完全卸载"
        echo -e "  $0 --quick-setup  # 一键安装并配置三协议"
        echo -e "  $0 --help         # 显示帮助"
        echo ""
        echo -e "${CYAN}一键安装特点:${NC}"
        echo -e "  ${GREEN}✓${NC} 自动安装 Sing-box"
        echo -e "  ${GREEN}✓${NC} 配置三种协议 (VLESS Reality + VMess WebSocket + Hysteria2)"
        echo -e "  ${GREEN}✓${NC} 自动分配高端口 (10000+)"
        echo -e "  ${GREEN}✓${NC} 生成连接信息和分享链接"
        echo -e "  ${GREEN}✓${NC} 无需外部模块，单文件运行"
        ;;
    *)
        main
        ;;
esac