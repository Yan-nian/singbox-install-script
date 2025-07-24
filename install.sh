#!/bin/bash

# Sing-box 一键安装脚本
# 支持协议: VLESS Reality, VMess WebSocket, Hysteria2
# 作者: Auto Generated
# 版本: 1.0.0

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
SINGBOX_DIR="/etc/sing-box"
SINGBOX_CONFIG="$SINGBOX_DIR/config.json"
SINGBOX_SERVICE="/etc/systemd/system/sing-box.service"
SINGBOX_BIN="/usr/local/bin/sing-box"
LOG_FILE="/var/log/sing-box-install.log"

# 协议配置变量
PROTOCOL_TYPE=""
SERVER_PORT=""
SERVER_UUID=""
SERVER_DOMAIN=""
SERVER_PRIVATE_KEY=""
SERVER_PUBLIC_KEY=""
SERVER_SHORT_ID=""
VMESS_WS_PATH=""
HY2_PASSWORD=""
HY2_OBFS=""

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误: 此脚本需要root权限运行${NC}"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 日志函数
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case $level in
        "INFO")
            echo -e "${GREEN}[信息]${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[警告]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[错误]${NC} $message"
            ;;
        "DEBUG")
            echo -e "${BLUE}[调试]${NC} $message"
            ;;
    esac
}

# 显示横幅
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                    Sing-box 一键安装脚本                      ║
║                                                              ║
║  支持协议: VLESS Reality | VMess WebSocket | Hysteria2       ║
║  版本: v1.0.0                                               ║
║  作者: Auto Generated                                        ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# 系统检测
detect_system() {
    log "INFO" "开始系统环境检测..."
    
    # 检测操作系统
    if [[ -f /etc/redhat-release ]]; then
        OS="centos"
        PM="yum"
    elif cat /etc/issue | grep -Eqi "debian"; then
        OS="debian"
        PM="apt"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        OS="ubuntu"
        PM="apt"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        OS="centos"
        PM="yum"
    elif cat /proc/version | grep -Eqi "debian"; then
        OS="debian"
        PM="apt"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        OS="ubuntu"
        PM="apt"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        OS="centos"
        PM="yum"
    else
        log "ERROR" "不支持的操作系统"
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
            log "ERROR" "不支持的系统架构: $ARCH"
            exit 1
            ;;
    esac
    
    log "INFO" "系统检测完成: $OS ($ARCH)"
    echo -e "${GREEN}✓ 操作系统: $OS${NC}"
    echo -e "${GREEN}✓ 系统架构: $ARCH${NC}"
    echo -e "${GREEN}✓ 包管理器: $PM${NC}"
}

# 安装依赖
install_dependencies() {
    log "INFO" "安装系统依赖..."
    
    if [[ $PM == "apt" ]]; then
        apt update -y
        apt install -y curl wget unzip jq openssl
    elif [[ $PM == "yum" ]]; then
        yum update -y
        yum install -y curl wget unzip jq openssl
    fi
    
    log "INFO" "依赖安装完成"
}

# 下载并安装sing-box
install_singbox() {
    log "INFO" "开始下载和安装sing-box..."
    
    # 获取最新版本
    local latest_version=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | jq -r '.tag_name')
    if [[ -z "$latest_version" ]]; then
        log "ERROR" "无法获取sing-box最新版本"
        exit 1
    fi
    
    log "INFO" "最新版本: $latest_version"
    
    # 下载地址
    local download_url="https://github.com/SagerNet/sing-box/releases/download/${latest_version}/sing-box-${latest_version#v}-linux-${ARCH}.tar.gz"
    local temp_dir="/tmp/sing-box-install"
    
    # 创建临时目录
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    # 下载文件
    log "INFO" "下载sing-box: $download_url"
    if ! wget -O "sing-box.tar.gz" "$download_url"; then
        log "ERROR" "下载失败"
        exit 1
    fi
    
    # 解压并安装
    tar -xzf "sing-box.tar.gz"
    local extracted_dir=$(find . -name "sing-box-*" -type d | head -1)
    
    if [[ -z "$extracted_dir" ]]; then
        log "ERROR" "解压失败"
        exit 1
    fi
    
    # 复制二进制文件
    cp "$extracted_dir/sing-box" "/usr/local/bin/"
    chmod +x "/usr/local/bin/sing-box"
    
    # 创建配置目录
    mkdir -p "$SINGBOX_DIR"
    
    # 清理临时文件
    cd /
    rm -rf "$temp_dir"
    
    log "INFO" "sing-box安装完成"
    echo -e "${GREEN}✓ sing-box ${latest_version} 安装成功${NC}"
}

# 创建systemd服务
create_service() {
    log "INFO" "创建systemd服务..."
    
    cat > "$SINGBOX_SERVICE" << EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/sing-box run -c $SINGBOX_CONFIG
Restart=on-failure
RestartSec=1800s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable sing-box
    
    log "INFO" "systemd服务创建完成"
}

# 生成UUID
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
    openssl rand -hex $length
}

# 生成Reality密钥对
generate_reality_keys() {
    log "INFO" "生成Reality密钥对..."
    
    # 使用sing-box生成密钥对
    local keys_output
    keys_output=$($SINGBOX_BIN generate reality-keypair)
    
    SERVER_PRIVATE_KEY=$(echo "$keys_output" | grep "PrivateKey:" | awk '{print $2}')
    SERVER_PUBLIC_KEY=$(echo "$keys_output" | grep "PublicKey:" | awk '{print $2}')
    
    if [[ -z "$SERVER_PRIVATE_KEY" || -z "$SERVER_PUBLIC_KEY" ]]; then
        log "ERROR" "生成Reality密钥对失败"
        exit 1
    fi
    
    log "INFO" "Reality密钥对生成完成"
}

# 配置VLESS Reality
configure_vless_reality() {
    echo -e "${CYAN}配置 VLESS Reality 协议${NC}"
    echo
    
    # 输入域名
    while true; do
        read -p "请输入伪装域名 (例如: www.microsoft.com): " SERVER_DOMAIN
        if [[ -n "$SERVER_DOMAIN" ]]; then
            break
        fi
        echo -e "${RED}域名不能为空${NC}"
    done
    
    # 输入端口
    while true; do
        read -p "请输入监听端口 (默认: 443): " SERVER_PORT
        SERVER_PORT=${SERVER_PORT:-443}
        if [[ "$SERVER_PORT" =~ ^[0-9]+$ ]] && [ "$SERVER_PORT" -ge 1 ] && [ "$SERVER_PORT" -le 65535 ]; then
            break
        fi
        echo -e "${RED}请输入有效的端口号 (1-65535)${NC}"
    done
    
    # 生成UUID和密钥
    SERVER_UUID=$(generate_uuid)
    generate_reality_keys
    SERVER_SHORT_ID=$(generate_random_string 8)
    
    # 创建配置文件
    cat > "$SINGBOX_CONFIG" << EOF
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
      "listen_port": $SERVER_PORT,
      "users": [
        {
          "uuid": "$SERVER_UUID",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$SERVER_DOMAIN",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "$SERVER_DOMAIN",
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
    
    PROTOCOL_TYPE="vless-reality"
    log "INFO" "VLESS Reality配置完成"
}

# 配置VMess WebSocket
configure_vmess_ws() {
    echo -e "${CYAN}配置 VMess WebSocket 协议${NC}"
    echo
    
    # 输入端口
    while true; do
        read -p "请输入监听端口 (默认: 8080): " SERVER_PORT
        SERVER_PORT=${SERVER_PORT:-8080}
        if [[ "$SERVER_PORT" =~ ^[0-9]+$ ]] && [ "$SERVER_PORT" -ge 1 ] && [ "$SERVER_PORT" -le 65535 ]; then
            break
        fi
        echo -e "${RED}请输入有效的端口号 (1-65535)${NC}"
    done
    
    # 输入WebSocket路径
    while true; do
        read -p "请输入WebSocket路径 (默认: /ws): " VMESS_WS_PATH
        VMESS_WS_PATH=${VMESS_WS_PATH:-/ws}
        if [[ "$VMESS_WS_PATH" =~ ^/.* ]]; then
            break
        fi
        echo -e "${RED}路径必须以 / 开头${NC}"
    done
    
    # 生成UUID
    SERVER_UUID=$(generate_uuid)
    
    # 创建配置文件
    cat > "$SINGBOX_CONFIG" << EOF
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
      "listen_port": $SERVER_PORT,
      "users": [
        {
          "uuid": "$SERVER_UUID",
          "alterId": 0
        }
      ],
      "transport": {
        "type": "ws",
        "path": "$VMESS_WS_PATH",
        "headers": {
          "Host": "localhost"
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
    
    PROTOCOL_TYPE="vmess-ws"
    log "INFO" "VMess WebSocket配置完成"
}

# 配置Hysteria2
configure_hysteria2() {
    echo -e "${CYAN}配置 Hysteria2 协议${NC}"
    echo
    
    # 输入端口
    while true; do
        read -p "请输入监听端口 (默认: 8443): " SERVER_PORT
        SERVER_PORT=${SERVER_PORT:-8443}
        if [[ "$SERVER_PORT" =~ ^[0-9]+$ ]] && [ "$SERVER_PORT" -ge 1 ] && [ "$SERVER_PORT" -le 65535 ]; then
            break
        fi
        echo -e "${RED}请输入有效的端口号 (1-65535)${NC}"
    done
    
    # 输入密码
    while true; do
        read -p "请输入连接密码 (默认随机生成): " HY2_PASSWORD
        if [[ -z "$HY2_PASSWORD" ]]; then
            HY2_PASSWORD=$(generate_random_string 16)
        fi
        break
    done
    
    # 输入混淆密码
    read -p "请输入混淆密码 (可选，默认不启用): " HY2_OBFS
    
    # 创建配置文件
    local obfs_config=""
    if [[ -n "$HY2_OBFS" ]]; then
        obfs_config=",\n        \"obfs\": {\n          \"type\": \"salamander\",\n          \"salamander\": {\n            \"password\": \"$HY2_OBFS\"\n          }\n        }"
    fi
    
    cat > "$SINGBOX_CONFIG" << EOF
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
      "listen_port": $SERVER_PORT,
      "users": [
        {
          "password": "$HY2_PASSWORD"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "localhost",
        "key_path": "/etc/sing-box/private.key",
        "certificate_path": "/etc/sing-box/cert.pem"
      }$obfs_config
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
    
    # 生成自签名证书
    generate_self_signed_cert
    
    PROTOCOL_TYPE="hysteria2"
    log "INFO" "Hysteria2配置完成"
}

# 生成自签名证书
generate_self_signed_cert() {
    log "INFO" "生成自签名证书..."
    
    openssl req -x509 -nodes -newkey rsa:2048 -keyout "$SINGBOX_DIR/private.key" \
        -out "$SINGBOX_DIR/cert.pem" -days 365 \
        -subj "/C=US/ST=State/L=City/O=Organization/OU=Unit/CN=localhost"
    
    chmod 600 "$SINGBOX_DIR/private.key"
    chmod 644 "$SINGBOX_DIR/cert.pem"
    
    log "INFO" "自签名证书生成完成"
}

# 启动服务
start_service() {
    log "INFO" "启动sing-box服务..."
    
    systemctl start sing-box
    systemctl enable sing-box
    
    if systemctl is-active --quiet sing-box; then
        log "INFO" "服务启动成功"
        echo -e "${GREEN}✓ sing-box服务已启动${NC}"
    else
        log "ERROR" "服务启动失败"
        echo -e "${RED}✗ sing-box服务启动失败${NC}"
        echo "请检查日志: journalctl -u sing-box -f"
        exit 1
    fi
}

# 生成客户端配置
generate_client_config() {
    local server_ip=$(curl -s ipv4.icanhazip.com)
    if [[ -z "$server_ip" ]]; then
        server_ip="YOUR_SERVER_IP"
    fi
    
    echo -e "${CYAN}客户端配置信息${NC}"
    echo "═══════════════════════════════════════════════════════════════"
    
    case $PROTOCOL_TYPE in
        "vless-reality")
            echo -e "${YELLOW}协议类型:${NC} VLESS Reality"
            echo -e "${YELLOW}服务器地址:${NC} $server_ip"
            echo -e "${YELLOW}端口:${NC} $SERVER_PORT"
            echo -e "${YELLOW}UUID:${NC} $SERVER_UUID"
            echo -e "${YELLOW}Flow:${NC} xtls-rprx-vision"
            echo -e "${YELLOW}TLS:${NC} Reality"
            echo -e "${YELLOW}SNI:${NC} $SERVER_DOMAIN"
            echo -e "${YELLOW}公钥:${NC} $SERVER_PUBLIC_KEY"
            echo -e "${YELLOW}Short ID:${NC} $SERVER_SHORT_ID"
            echo
            echo -e "${CYAN}分享链接:${NC}"
            echo "vless://$SERVER_UUID@$server_ip:$SERVER_PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$SERVER_DOMAIN&fp=chrome&pbk=$SERVER_PUBLIC_KEY&sid=$SERVER_SHORT_ID&type=tcp&headerType=none#VLESS-Reality"
            ;;
        "vmess-ws")
            echo -e "${YELLOW}协议类型:${NC} VMess WebSocket"
            echo -e "${YELLOW}服务器地址:${NC} $server_ip"
            echo -e "${YELLOW}端口:${NC} $SERVER_PORT"
            echo -e "${YELLOW}UUID:${NC} $SERVER_UUID"
            echo -e "${YELLOW}传输协议:${NC} WebSocket"
            echo -e "${YELLOW}路径:${NC} $VMESS_WS_PATH"
            echo -e "${YELLOW}TLS:${NC} 无"
            ;;
        "hysteria2")
            echo -e "${YELLOW}协议类型:${NC} Hysteria2"
            echo -e "${YELLOW}服务器地址:${NC} $server_ip"
            echo -e "${YELLOW}端口:${NC} $SERVER_PORT"
            echo -e "${YELLOW}密码:${NC} $HY2_PASSWORD"
            if [[ -n "$HY2_OBFS" ]]; then
                echo -e "${YELLOW}混淆:${NC} salamander"
                echo -e "${YELLOW}混淆密码:${NC} $HY2_OBFS"
            fi
            echo -e "${YELLOW}TLS:${NC} 自签名证书"
            ;;
    esac
    
    echo "═══════════════════════════════════════════════════════════════"
}

# 服务管理菜单
service_management() {
    while true; do
        clear
        echo -e "${CYAN}"
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                      服务管理菜单                             ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
        echo
        echo -e "${GREEN}1.${NC} 启动服务"
        echo -e "${GREEN}2.${NC} 停止服务"
        echo -e "${GREEN}3.${NC} 重启服务"
        echo -e "${GREEN}4.${NC} 查看服务状态"
        echo -e "${GREEN}5.${NC} 查看服务日志"
        echo -e "${GREEN}6.${NC} 显示配置信息"
        echo -e "${GREEN}7.${NC} 生成客户端配置"
        echo -e "${GREEN}0.${NC} 返回主菜单"
        echo
        read -p "请输入选项 [0-7]: " choice
        
        case $choice in
            1)
                systemctl start sing-box
                echo -e "${GREEN}服务已启动${NC}"
                read -p "按回车键继续..."
                ;;
            2)
                systemctl stop sing-box
                echo -e "${YELLOW}服务已停止${NC}"
                read -p "按回车键继续..."
                ;;
            3)
                systemctl restart sing-box
                echo -e "${GREEN}服务已重启${NC}"
                read -p "按回车键继续..."
                ;;
            4)
                systemctl status sing-box
                read -p "按回车键继续..."
                ;;
            5)
                journalctl -u sing-box -f
                ;;
            6)
                if [[ -f "$SINGBOX_CONFIG" ]]; then
                    echo -e "${CYAN}当前配置:${NC}"
                    cat "$SINGBOX_CONFIG"
                else
                    echo -e "${RED}配置文件不存在${NC}"
                fi
                read -p "按回车键继续..."
                ;;
            7)
                if [[ -f "$SINGBOX_CONFIG" ]]; then
                    generate_client_config
                else
                    echo -e "${RED}配置文件不存在，请先安装协议${NC}"
                fi
                read -p "按回车键继续..."
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选项${NC}"
                read -p "按回车键继续..."
                ;;
        esac
    done
}

# 卸载sing-box
uninstall_singbox() {
    echo -e "${YELLOW}确定要卸载sing-box吗？这将删除所有配置文件。${NC}"
    read -p "输入 'yes' 确认卸载: " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        log "INFO" "开始卸载sing-box..."
        
        # 停止并禁用服务
        systemctl stop sing-box 2>/dev/null || true
        systemctl disable sing-box 2>/dev/null || true
        
        # 删除文件
        rm -f "$SINGBOX_BIN"
        rm -f "$SINGBOX_SERVICE"
        rm -rf "$SINGBOX_DIR"
        
        # 重新加载systemd
        systemctl daemon-reload
        
        log "INFO" "sing-box卸载完成"
        echo -e "${GREEN}✓ sing-box已成功卸载${NC}"
    else
        echo -e "${YELLOW}取消卸载${NC}"
    fi
    
    read -p "按回车键继续..."
}

# 主菜单
main_menu() {
    while true; do
        show_banner
        echo -e "${CYAN}请选择要执行的操作:${NC}"
        echo
        echo -e "${GREEN}1.${NC} 安装 VLESS Reality"
        echo -e "${GREEN}2.${NC} 安装 VMess WebSocket"
        echo -e "${GREEN}3.${NC} 安装 Hysteria2"
        echo -e "${GREEN}4.${NC} 管理现有服务"
        echo -e "${GREEN}5.${NC} 卸载 Sing-box"
        echo -e "${GREEN}0.${NC} 退出脚本"
        echo
        read -p "请输入选项 [0-5]: " choice
        
        case $choice in
            1)
                detect_system
                install_dependencies
                install_singbox
                create_service
                configure_vless_reality
                start_service
                generate_client_config
                read -p "按回车键继续..."
                ;;
            2)
                detect_system
                install_dependencies
                install_singbox
                create_service
                configure_vmess_ws
                start_service
                generate_client_config
                read -p "按回车键继续..."
                ;;
            3)
                detect_system
                install_dependencies
                install_singbox
                create_service
                configure_hysteria2
                start_service
                generate_client_config
                read -p "按回车键继续..."
                ;;
            4)
                service_management
                ;;
            5)
                uninstall_singbox
                ;;
            0)
                echo -e "${GREEN}感谢使用！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选项，请重新选择${NC}"
                read -p "按回车键继续..."
                ;;
        esac
    done
}

# 主程序入口
main() {
    # 检查root权限
    check_root
    
    # 创建日志文件
    touch "$LOG_FILE"
    
    # 启动主菜单
    main_menu
}

# 运行主程序
main "$@"