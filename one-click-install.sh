#!/bin/bash

# Sing-box 在线一键安装脚本
# 支持 VLESS Reality Vision、VMess WebSocket、Hysteria2 协议
# 作者: Sing-box Install Script
# 版本: v1.1.0
# 更新时间: 2024-01-01
# 使用方法: curl -fsSL https://your-domain.com/one-click-install.sh | sudo bash
#          或: wget -qO- https://your-domain.com/one-click-install.sh | sudo bash

set -e

# 脚本信息
SCRIPT_NAME="Sing-box 在线一键安装脚本"
SCRIPT_VERSION="v1.1.0"
SCRIPT_AUTHOR="Sing-box Install Script"
SCRIPT_URL="https://github.com/your-repo/singbox-install"

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

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1" | tee -a "$LOG_FILE"
}

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        echo -e "${YELLOW}请使用以下命令重新运行:${NC}"
        echo -e "${GREEN}curl -fsSL https://your-domain.com/one-click-install.sh | sudo bash${NC}"
        echo -e "${GREEN}或: wget -qO- https://your-domain.com/one-click-install.sh | sudo bash${NC}"
        exit 1
    fi
}

# 创建必要目录
create_directories() {
    local dirs=(
        "$WORK_DIR"
        "$CONFIG_DIR"
        "$CONFIG_BACKUP_DIR"
        "$TEMP_DIR"
        "/var/log"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_info "创建目录: $dir"
        fi
    done
}

# 检测系统信息
detect_system() {
    log_info "检测系统信息..."
    
    # 检测操作系统
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS="$ID"
        OS_VERSION="$VERSION_ID"
    elif [[ -f /etc/redhat-release ]]; then
        OS="centos"
        OS_VERSION=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | head -1)
    else
        log_error "不支持的操作系统"
        exit 1
    fi
    
    # 检测架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64)
            ARCH="arm64"
            ;;
        armv7l)
            ARCH="armv7"
            ;;
        *)
            log_error "不支持的架构: $ARCH"
            exit 1
            ;;
    esac
    
    # 获取公网IP
    PUBLIC_IP=$(curl -s https://api.ipify.org || curl -s https://ipinfo.io/ip || echo "未知")
    
    log_info "系统: $OS $OS_VERSION"
    log_info "架构: $ARCH"
    log_info "公网IP: $PUBLIC_IP"
}

# 安装系统依赖
install_dependencies() {
    log_info "安装系统依赖..."
    
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y curl wget tar unzip jq openssl
            ;;
        centos|rhel|fedora)
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y curl wget tar unzip jq openssl
            else
                yum install -y curl wget tar unzip jq openssl
            fi
            ;;
        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac
}

# 下载并安装 Sing-box
install_singbox() {
    log_info "下载并安装 Sing-box..."
    
    # 获取最新版本
    local latest_version
    latest_version=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | jq -r '.tag_name' | sed 's/^v//')
    
    if [[ -z "$latest_version" ]]; then
        log_error "无法获取 Sing-box 最新版本"
        exit 1
    fi
    
    log_info "最新版本: $latest_version"
    
    # 下载二进制文件
    local download_url="https://github.com/SagerNet/sing-box/releases/download/v${latest_version}/sing-box-${latest_version}-linux-${ARCH}.tar.gz"
    local temp_file="$TEMP_DIR/sing-box.tar.gz"
    
    log_info "下载地址: $download_url"
    
    if ! curl -L "$download_url" -o "$temp_file"; then
        log_error "下载失败"
        exit 1
    fi
    
    # 解压并安装
    cd "$TEMP_DIR"
    tar -xzf sing-box.tar.gz
    
    local extracted_dir="sing-box-${latest_version}-linux-${ARCH}"
    if [[ -f "$extracted_dir/sing-box" ]]; then
        cp "$extracted_dir/sing-box" "$SINGBOX_BINARY"
        chmod +x "$SINGBOX_BINARY"
        log_info "Sing-box 安装完成"
    else
        log_error "找不到 sing-box 二进制文件"
        exit 1
    fi
}

# 生成 UUID
generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen
    else
        cat /proc/sys/kernel/random/uuid
    fi
}

# 生成随机字符串
generate_random_string() {
    local length=${1:-16}
    openssl rand -base64 $((length * 3 / 4)) | tr -d '\n' | head -c $length
}

# 生成 Reality 密钥对
generate_reality_keypair() {
    local keypair
    keypair=$($SINGBOX_BINARY generate reality-keypair)
    
    VLESS_REALITY_PRIVATE_KEY=$(echo "$keypair" | grep "PrivateKey:" | awk '{print $2}')
    VLESS_REALITY_PUBLIC_KEY=$(echo "$keypair" | grep "PublicKey:" | awk '{print $2}')
    VLESS_REALITY_SHORT_ID=$(openssl rand -hex 8)
}

# 配置 VLESS Reality Vision
configure_vless() {
    log_info "配置 VLESS Reality Vision..."
    
    VLESS_UUID=$(generate_uuid)
    generate_reality_keypair
    
    # 生成配置文件
    cat > "$CONFIG_FILE" << EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": $VLESS_PORT,
      "users": [
        {
          "uuid": "$VLESS_UUID",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$VLESS_SERVER_NAME",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "$VLESS_TARGET_SERVER",
            "server_port": $VLESS_TARGET_PORT
          },
          "private_key": "$VLESS_REALITY_PRIVATE_KEY",
          "short_id": [
            "$VLESS_REALITY_SHORT_ID"
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

    log_info "VLESS Reality Vision 配置完成"
}

# 配置 VMess WebSocket
configure_vmess() {
    log_info "配置 VMess WebSocket..."
    
    VMESS_UUID=$(generate_uuid)
    VMESS_WS_PATH="/$(generate_random_string 8)"
    
    # 生成配置文件
    cat > "$CONFIG_FILE" << EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
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
        "path": "$VMESS_WS_PATH"
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

    log_info "VMess WebSocket 配置完成"
}

# 配置 Hysteria2
configure_hysteria2() {
    log_info "配置 Hysteria2..."
    
    HY2_PASSWORD=$(generate_random_string 16)
    HY2_OBFS_PASSWORD=$(generate_random_string 16)
    
    # 生成自签名证书
    openssl req -x509 -nodes -newkey rsa:2048 -keyout "$WORK_DIR/private.key" \
        -out "$WORK_DIR/cert.crt" -days 365 \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=$PUBLIC_IP" 2>/dev/null
    
    HY2_CERT="$WORK_DIR/cert.crt"
    HY2_KEY="$WORK_DIR/private.key"
    
    # 生成配置文件
    cat > "$CONFIG_FILE" << EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
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
      "masquerade": "https://$HY2_MASQUERADE_DOMAIN",
      "tls": {
        "enabled": true,
        "certificate_path": "$HY2_CERT",
        "key_path": "$HY2_KEY"
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

    log_info "Hysteria2 配置完成"
}

# 创建系统服务
create_service() {
    log_info "创建系统服务..."
    
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
Restart=on-failure
RestartSec=1800s
ExecReload=/bin/kill -HUP \$MAINPID

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable $SERVICE_NAME
    log_info "系统服务创建完成"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."
    
    local ports=()
    
    # 根据配置的协议开放端口
    if [[ -n "$VLESS_PORT" ]]; then
        ports+=("$VLESS_PORT")
    fi
    if [[ -n "$VMESS_PORT" ]]; then
        ports+=("$VMESS_PORT")
    fi
    if [[ -n "$HY2_PORT" ]]; then
        ports+=("$HY2_PORT")
    fi
    
    for port in "${ports[@]}"; do
        if command -v ufw >/dev/null 2>&1; then
            ufw allow $port
        elif command -v firewall-cmd >/dev/null 2>&1; then
            firewall-cmd --permanent --add-port=$port/tcp
            firewall-cmd --permanent --add-port=$port/udp
            firewall-cmd --reload
        fi
        log_info "开放端口: $port"
    done
}

# 启动服务
start_service() {
    log_info "启动 Sing-box 服务..."
    
    if systemctl start $SERVICE_NAME; then
        log_info "服务启动成功"
    else
        log_error "服务启动失败"
        exit 1
    fi
}

# 显示配置信息
show_config_info() {
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${CYAN}                  Sing-box 安装完成${NC}"
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${GREEN}服务状态:${NC} $(systemctl is-active $SERVICE_NAME)"
    echo -e "${GREEN}配置文件:${NC} $CONFIG_FILE"
    echo -e "${GREEN}日志文件:${NC} $LOG_FILE"
    echo -e "${GREEN}公网IP:${NC} $PUBLIC_IP"
    echo ""
    
    if [[ -n "$VLESS_UUID" ]]; then
        echo -e "${YELLOW}VLESS Reality Vision 配置:${NC}"
        echo -e "${GREEN}UUID:${NC} $VLESS_UUID"
        echo -e "${GREEN}端口:${NC} $VLESS_PORT"
        echo -e "${GREEN}公钥:${NC} $VLESS_REALITY_PUBLIC_KEY"
        echo -e "${GREEN}短ID:${NC} $VLESS_REALITY_SHORT_ID"
        echo -e "${GREEN}目标服务器:${NC} $VLESS_TARGET_SERVER"
        echo ""
    fi
    
    if [[ -n "$VMESS_UUID" ]]; then
        echo -e "${YELLOW}VMess WebSocket 配置:${NC}"
        echo -e "${GREEN}UUID:${NC} $VMESS_UUID"
        echo -e "${GREEN}端口:${NC} $VMESS_PORT"
        echo -e "${GREEN}路径:${NC} $VMESS_WS_PATH"
        echo ""
    fi
    
    if [[ -n "$HY2_PASSWORD" ]]; then
        echo -e "${YELLOW}Hysteria2 配置:${NC}"
        echo -e "${GREEN}密码:${NC} $HY2_PASSWORD"
        echo -e "${GREEN}端口:${NC} $HY2_PORT"
        echo -e "${GREEN}混淆密码:${NC} $HY2_OBFS_PASSWORD"
        echo ""
    fi
    
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${GREEN}管理命令:${NC}"
    echo -e "  启动服务: ${YELLOW}systemctl start $SERVICE_NAME${NC}"
    echo -e "  停止服务: ${YELLOW}systemctl stop $SERVICE_NAME${NC}"
    echo -e "  重启服务: ${YELLOW}systemctl restart $SERVICE_NAME${NC}"
    echo -e "  查看状态: ${YELLOW}systemctl status $SERVICE_NAME${NC}"
    echo -e "  查看日志: ${YELLOW}journalctl -u $SERVICE_NAME -f${NC}"
    echo -e "${CYAN}================================================================${NC}"
}

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

# 协议选择菜单
protocol_menu() {
    echo -e "${YELLOW}请选择要配置的协议:${NC}"
    echo -e "  ${GREEN}1)${NC} VLESS Reality Vision (推荐)"
    echo -e "  ${GREEN}2)${NC} VMess WebSocket"
    echo -e "  ${GREEN}3)${NC} Hysteria2"
    echo ""
    
    while true; do
        read -p "请输入选项 [1-3]: " choice
        case $choice in
            1)
                configure_vless
                break
                ;;
            2)
                configure_vmess
                break
                ;;
            3)
                configure_hysteria2
                break
                ;;
            *)
                echo -e "${RED}无效选项，请重新选择${NC}"
                ;;
        esac
    done
}

# 显示帮助信息
show_help() {
    echo -e "${CYAN}$SCRIPT_NAME $SCRIPT_VERSION${NC}"
    echo ""
    echo -e "${YELLOW}用法:${NC}"
    echo -e "  curl -fsSL https://your-domain.com/one-click-install.sh | sudo bash"
    echo -e "  wget -qO- https://your-domain.com/one-click-install.sh | sudo bash"
    echo ""
    echo -e "${YELLOW}支持的参数:${NC}"
    echo -e "  ${GREEN}--vless${NC}           直接安装 VLESS Reality Vision"
    echo -e "  ${GREEN}--vmess${NC}           直接安装 VMess WebSocket"
    echo -e "  ${GREEN}--hysteria2${NC}       直接安装 Hysteria2"
    echo -e "  ${GREEN}--help${NC}            显示此帮助信息"
    echo ""
    echo -e "${YELLOW}示例:${NC}"
    echo -e "  curl -fsSL https://your-domain.com/one-click-install.sh | sudo bash -s -- --vless"
    echo -e "  wget -qO- https://your-domain.com/one-click-install.sh | sudo bash -s -- --hysteria2"
    echo ""
}

# 清理函数
cleanup() {
    log_info "清理临时文件..."
    rm -rf "$TEMP_DIR"
}

# 信号处理
trap cleanup EXIT

# 主函数
main() {
    # 处理命令行参数
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --vless)
            PROTOCOL="vless"
            ;;
        --vmess)
            PROTOCOL="vmess"
            ;;
        --hysteria2)
            PROTOCOL="hysteria2"
            ;;
        *)
            PROTOCOL=""
            ;;
    esac
    
    # 显示横幅
    show_banner
    
    # 检查 root 权限
    check_root
    
    # 创建必要目录
    create_directories
    
    # 创建日志文件
    touch "$LOG_FILE"
    
    # 检测系统信息
    detect_system
    
    # 安装系统依赖
    install_dependencies
    
    # 下载并安装 Sing-box
    install_singbox
    
    # 配置协议
    if [[ -n "$PROTOCOL" ]]; then
        case $PROTOCOL in
            vless)
                configure_vless
                ;;
            vmess)
                configure_vmess
                ;;
            hysteria2)
                configure_hysteria2
                ;;
        esac
    else
        protocol_menu
    fi
    
    # 创建系统服务
    create_service
    
    # 配置防火墙
    configure_firewall
    
    # 启动服务
    start_service
    
    # 显示配置信息
    show_config_info
    
    log_info "安装完成！"
}

# 运行主函数
main "$@"