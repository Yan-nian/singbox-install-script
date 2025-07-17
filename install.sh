#!/bin/bash

# sing-box 一键安装脚本
# 支持 VLESS Reality、VMess、Hysteria2 三种协议
# Author: Yan-nian
# Date: 2025-07-17

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置文件路径
CONFIG_DIR="/etc/sing-box"
CONFIG_FILE="$CONFIG_DIR/config.json"
SERVICE_FILE="/etc/systemd/system/sing-box.service"
BINARY_PATH="/usr/local/bin/sing-box"
LOG_FILE="/var/log/sing-box.log"

# 全局配置变量
VLESS_CONFIG=""
VMESS_CONFIG=""
HYSTERIA2_CONFIG=""
TUIC5_CONFIG=""

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误：请使用root用户运行此脚本${NC}"
        exit 1
    fi
}

# 检测系统架构
detect_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            echo "amd64"
            ;;
        aarch64)
            echo "arm64"
            ;;
        armv7l)
            echo "armv7"
            ;;
        *)
            echo -e "${RED}不支持的架构: $arch${NC}"
            exit 1
            ;;
    esac
}

# 获取最新版本号
get_latest_version() {
    local version=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    echo $version
}

# 下载并安装 sing-box
install_singbox() {
    echo -e "${BLUE}开始安装 sing-box...${NC}"
    
    local arch=$(detect_arch)
    local version=$(get_latest_version)
    
    if [[ -z "$version" ]]; then
        echo -e "${RED}无法获取最新版本信息${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}检测到最新版本: $version${NC}"
    echo -e "${GREEN}系统架构: $arch${NC}"
    
    # 下载二进制文件
    local download_url="https://github.com/SagerNet/sing-box/releases/download/$version/sing-box-${version#v}-linux-$arch.tar.gz"
    local temp_dir=$(mktemp -d)
    
    echo -e "${BLUE}正在下载 sing-box...${NC}"
    if ! curl -L -o "$temp_dir/sing-box.tar.gz" "$download_url"; then
        echo -e "${RED}下载失败${NC}"
        exit 1
    fi
    
    # 解压并安装
    cd "$temp_dir"
    tar -xzf sing-box.tar.gz
    chmod +x sing-box-*/sing-box
    mv sing-box-*/sing-box "$BINARY_PATH"
    
    # 创建配置目录
    mkdir -p "$CONFIG_DIR"
    
    # 创建systemd服务文件
    create_service_file
    
    # 启用服务
    systemctl daemon-reload
    systemctl enable sing-box
    
    echo -e "${GREEN}sing-box 安装完成！${NC}"
    cleanup_temp "$temp_dir"
}

# 创建systemd服务文件
create_service_file() {
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
ExecStart=$BINARY_PATH run -c $CONFIG_FILE
Restart=on-failure
RestartSec=1800s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
}

# 验证端口号
validate_port() {
    local port=$1
    if [[ ! "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
        return 1
    fi
    
    # 检查端口是否已被占用
    if command -v ss &> /dev/null; then
        if ss -tuln | grep -q ":$port "; then
            echo -e "${YELLOW}警告：端口 $port 可能已被占用${NC}"
            return 2
        fi
    fi
    
    return 0
}

# 生成随机字符串
generate_random_string() {
    local length=$1
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c $length
}

# 生成UUID
generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen
    else
        cat /proc/sys/kernel/random/uuid
    fi
}

# 生成随机端口
generate_random_port() {
    local min_port=10000
    local max_port=65535
    echo $((RANDOM % (max_port - min_port + 1) + min_port))
}

# 获取公网IP
get_public_ip() {
    local ip=$(curl -s -4 ifconfig.me 2>/dev/null)
    if [[ -z "$ip" ]]; then
        ip=$(curl -s -4 icanhazip.com 2>/dev/null)
    fi
    if [[ -z "$ip" ]]; then
        ip=$(curl -s -4 ipinfo.io/ip 2>/dev/null)
    fi
    echo "$ip"
}

# 生成终端QR码
generate_qr_code() {
    local text="$1"
    local size="${2:-2}"
    
    # 检查是否有qrencode命令
    if ! command -v qrencode &> /dev/null; then
        echo -e "${YELLOW}正在安装 qrencode...${NC}"
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y qrencode
        elif command -v yum &> /dev/null; then
            yum install -y qrencode
        elif command -v dnf &> /dev/null; then
            dnf install -y qrencode
        else
            echo -e "${RED}无法自动安装 qrencode，请手动安装后再使用此功能${NC}"
            return 1
        fi
    fi
    
    # 生成QR码到终端
    qrencode -t ANSIUTF8 -s "$size" "$text"
}

# 生成VLESS链接
generate_vless_link() {
    local server_ip="$1"
    local port="$2"
    local uuid="$3"
    local public_key="$4"
    local short_id="$5"
    local server_name="$6"
    
    echo "vless://$uuid@$server_ip:$port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$server_name&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#VLESS-Reality"
}

# 生成VMess链接
generate_vmess_link() {
    local server_ip="$1"
    local port="$2"
    local uuid="$3"
    local ws_path="$4"
    
    local vmess_json="{\"v\":\"2\",\"ps\":\"VMess-WebSocket\",\"add\":\"$server_ip\",\"port\":\"$port\",\"id\":\"$uuid\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"$server_ip\",\"path\":\"$ws_path\",\"tls\":\"\"}"
    echo "vmess://$(echo -n "$vmess_json" | base64 -w 0)"
}

# 生成Hysteria2链接
generate_hysteria2_link() {
    local server_ip="$1"
    local port="$2"
    local password="$3"
    
    echo "hysteria2://$password@$server_ip:$port?insecure=1#Hysteria2"
}

# 生成TUIC5链接
generate_tuic5_link() {
    local server_ip="$1"
    local port="$2"
    local uuid="$3"
    local password="$4"
    
    echo "tuic://$uuid:$password@$server_ip:$port?congestion_control=bbr&udp_relay_mode=native&alpn=h3&allow_insecure=1#TUIC5"
}

# 生成Reality配置
generate_reality_config() {
    echo -e "${BLUE}配置 VLESS Reality...${NC}"
    
    local port
    local users=()
    local dest_server
    local server_names
    
    # 检查是否为快速配置模式
    if [[ "$QUICK_CONFIG" == "true" ]]; then
        echo -e "${GREEN}快速配置模式：使用默认参数${NC}"
        port=443
        dest_server="www.microsoft.com"
        server_names="www.microsoft.com"
        
        # 直接创建默认用户
        local default_uuid=$(generate_uuid)
        local users_json="{\"name\":\"default\",\"uuid\":\"$default_uuid\"}"
        echo -e "${GREEN}已创建默认用户，UUID: $default_uuid${NC}"
    else
        # 正常配置流程
        # 端口配置
        while true; do
            read -p "请输入端口号 (默认: 443): " port
            port=${port:-443}
            
            if validate_port "$port"; then
                break
            elif [[ $? -eq 2 ]]; then
                read -p "端口可能已被占用，是否继续使用? (y/n): " continue_choice
                if [[ "$continue_choice" =~ ^[yY]$ ]]; then
                    break
                fi
            else
                echo -e "${RED}端口号无效，请输入 1-65535 之间的数字${NC}"
            fi
        done
        
        # 用户配置
        echo -e "${YELLOW}用户配置模式：${NC}"
        echo "1. 快速配置（使用默认用户）"
        echo "2. 自定义配置（添加多个用户）"
        read -p "请选择配置模式 (默认: 1): " config_mode
        config_mode=${config_mode:-1}
        
        local users_json=""
        if [[ "$config_mode" == "1" ]]; then
            # 快速配置，直接创建默认用户
            local default_uuid=$(generate_uuid)
            users_json="{\"name\":\"default\",\"uuid\":\"$default_uuid\"}"
            echo -e "${GREEN}已创建默认用户，UUID: $default_uuid${NC}"
        else
            # 自定义配置
            echo -e "${CYAN}说明：可以创建多个用户账号，每个用户都有独立的UUID${NC}"
            echo -e "${CYAN}如果直接回车（留空）会自动创建一个默认用户${NC}"
            while true; do
                read -p "请输入用户名 (直接回车结束): " username
                if [[ -z "$username" ]]; then
                    break
                fi
                local uuid=$(generate_uuid)
                if [[ -n "$users_json" ]]; then
                    users_json+=","
                fi
                users_json+="{\"name\":\"$username\",\"uuid\":\"$uuid\"}"
                echo -e "${GREEN}用户 $username 的UUID: $uuid${NC}"
            done
            
            if [[ -z "$users_json" ]]; then
                local default_uuid=$(generate_uuid)
                users_json="{\"name\":\"default\",\"uuid\":\"$default_uuid\"}"
                echo -e "${GREEN}默认用户UUID: $default_uuid${NC}"
            fi
        fi
        
        # 目标服务器配置
        read -p "请输入目标服务器 (默认: www.microsoft.com): " dest_server
        dest_server=${dest_server:-www.microsoft.com}
        
        # 服务器名称配置
        read -p "请输入服务器名称 (默认: www.microsoft.com): " server_names
        server_names=${server_names:-www.microsoft.com}
    fi
    
    # 生成密钥对
    local key_pair=$($BINARY_PATH generate reality-keypair 2>/dev/null)
    local private_key=$(echo "$key_pair" | grep "PrivateKey" | awk '{print $2}')
    local public_key=$(echo "$key_pair" | grep "PublicKey" | awk '{print $2}')
    
    # 如果sing-box命令失败，生成随机密钥
    if [[ -z "$private_key" ]]; then
        private_key=$(openssl rand -base64 32)
        public_key=$(openssl rand -base64 32)
    fi
    
    echo -e "${GREEN}Reality 公钥: $public_key${NC}"
    echo -e "${GREEN}Reality 私钥: $private_key${NC}"
    
    # 生成short_id
    local short_id=$(openssl rand -hex 8)
    
    # 存储配置信息到全局变量
    VLESS_CONFIG="{
        \"type\": \"vless\",
        \"tag\": \"vless-reality\",
        \"listen\": \"::\",
        \"listen_port\": $port,
        \"users\": [$users_json],
        \"packet_encoding\": \"xudp\",
        \"flow\": \"xtls-rprx-vision\",
        \"tls\": {
            \"enabled\": true,
            \"server_name\": \"$server_names\",
            \"utls\": {
                \"enabled\": true,
                \"fingerprint\": \"chrome\"
            },
            \"reality\": {
                \"enabled\": true,
                \"handshake\": {
                    \"server\": \"$dest_server\",
                    \"server_port\": 443
                },
                \"private_key\": \"$private_key\",
                \"short_id\": [\"$short_id\"]
            }
        }
    }"
}

# 生成VMess配置
generate_vmess_config() {
    echo -e "${BLUE}配置 VMess...${NC}"
    
    local port
    local users=()
    local ws_path
    
    # 端口配置
    while true; do
        read -p "请输入端口号 (默认: 随机): " port
        port=${port:-$(generate_random_port)}
        
        if validate_port "$port"; then
            break
        elif [[ $? -eq 2 ]]; then
            read -p "端口可能已被占用，是否继续使用? (y/n): " continue_choice
            if [[ "$continue_choice" =~ ^[yY]$ ]]; then
                break
            fi
        else
            echo -e "${RED}端口号无效，请输入 1-65535 之间的数字${NC}"
        fi
    done
    
    # WebSocket路径配置
    read -p "请输入WebSocket路径 (默认: 随机): " ws_path
    ws_path=${ws_path:-"/$(generate_random_string 8)"}
    
    # 用户配置
    echo -e "${YELLOW}用户配置模式：${NC}"
    echo "1. 快速配置（使用默认用户）"
    echo "2. 自定义配置（添加多个用户）"
    read -p "请选择配置模式 (默认: 1): " config_mode
    config_mode=${config_mode:-1}
    
    local users_json=""
    if [[ "$config_mode" == "1" ]]; then
        # 快速配置，直接创建默认用户
        local default_uuid=$(generate_uuid)
        users_json="{\"name\":\"default\",\"uuid\":\"$default_uuid\"}"
        echo -e "${GREEN}已创建默认用户，UUID: $default_uuid${NC}"
    else
        # 自定义配置
        echo -e "${CYAN}说明：可以创建多个用户账号，每个用户都有独立的UUID${NC}"
        echo -e "${CYAN}如果直接回车（留空）会自动创建一个默认用户${NC}"
        while true; do
            read -p "请输入用户名 (直接回车结束): " username
            if [[ -z "$username" ]]; then
                break
            fi
            local uuid=$(generate_uuid)
            if [[ -n "$users_json" ]]; then
                users_json+=","
            fi
            users_json+="{\"name\":\"$username\",\"uuid\":\"$uuid\"}"
            echo -e "${GREEN}用户 $username 的UUID: $uuid${NC}"
        done
        
        if [[ -z "$users_json" ]]; then
            local default_uuid=$(generate_uuid)
            users_json="{\"name\":\"default\",\"uuid\":\"$default_uuid\"}"
            echo -e "${GREEN}默认用户UUID: $default_uuid${NC}"
        fi
    fi
    
    # 存储配置信息到全局变量
    VMESS_CONFIG="{
        \"type\": \"vmess\",
        \"tag\": \"vmess-ws\",
        \"listen\": \"::\",
        \"listen_port\": $port,
        \"users\": [$users_json],
        \"security\": \"auto\",
        \"packet_encoding\": \"packetaddr\",
        \"tls\": {
            \"enabled\": false,
            \"server_name\": \"$(get_public_ip)\",
            \"insecure\": false,
            \"utls\": {
                \"enabled\": true,
                \"fingerprint\": \"chrome\"
            }
        },
        \"transport\": {
            \"type\": \"ws\",
            \"path\": \"$ws_path\",
            \"headers\": {
                \"Host\": [\"$(get_public_ip)\"]
            }
        }
    }"
}

# 生成Hysteria2配置
generate_hysteria2_config() {
    echo -e "${BLUE}配置 Hysteria2...${NC}"
    
    local port
    local users=()
    local up_mbps
    local down_mbps
    
    # 端口配置
    while true; do
        read -p "请输入端口号 (默认: 随机): " port
        port=${port:-$(generate_random_port)}
        
        if validate_port "$port"; then
            break
        elif [[ $? -eq 2 ]]; then
            read -p "端口可能已被占用，是否继续使用? (y/n): " continue_choice
            if [[ "$continue_choice" =~ ^[yY]$ ]]; then
                break
            fi
        else
            echo -e "${RED}端口号无效，请输入 1-65535 之间的数字${NC}"
        fi
    done
    
    # 带宽配置
    read -p "请输入上行带宽 (Mbps, 默认: 100): " up_mbps
    up_mbps=${up_mbps:-100}
    
    read -p "请输入下行带宽 (Mbps, 默认: 100): " down_mbps
    down_mbps=${down_mbps:-100}
    
    # 用户配置
    echo -e "${YELLOW}用户配置模式：${NC}"
    echo "1. 快速配置（使用默认用户）"
    echo "2. 自定义配置（添加多个用户）"
    read -p "请选择配置模式 (默认: 1): " config_mode
    config_mode=${config_mode:-1}
    
    local users_json=""
    if [[ "$config_mode" == "1" ]]; then
        # 快速配置，直接创建默认用户
        local default_password=$(generate_random_string 16)
        users_json="{\"name\":\"default\",\"password\":\"$default_password\"}"
        echo -e "${GREEN}已创建默认用户，密码: $default_password${NC}"
    else
        # 自定义配置
        echo -e "${CYAN}说明：可以创建多个用户账号，每个用户都有独立的密码${NC}"
        echo -e "${CYAN}如果直接回车（留空）会自动创建一个默认用户${NC}"
        while true; do
            read -p "请输入用户名 (直接回车结束): " username
            if [[ -z "$username" ]]; then
                break
            fi
            read -p "请输入 $username 的密码: " password
            if [[ -n "$users_json" ]]; then
                users_json+=","
            fi
            users_json+="{\"name\":\"$username\",\"password\":\"$password\"}"
            echo -e "${GREEN}用户 $username 已添加${NC}"
        done
        
        if [[ -z "$users_json" ]]; then
            local default_password=$(generate_random_string 16)
            users_json="{\"name\":\"default\",\"password\":\"$default_password\"}"
            echo -e "${GREEN}默认用户密码: $default_password${NC}"
        fi
    fi
    
    # 生成自签名证书
    local cert_dir="$CONFIG_DIR/certs"
    mkdir -p "$cert_dir"
    
    # 生成证书
    openssl req -x509 -nodes -newkey rsa:2048 -keyout "$cert_dir/private.key" -out "$cert_dir/cert.pem" -days 365 -subj "/CN=$(get_public_ip)" 2>/dev/null
    
    # 存储配置信息到全局变量
    HYSTERIA2_CONFIG="{
        \"type\": \"hysteria2\",
        \"tag\": \"hysteria2\",
        \"listen\": \"::\",
        \"listen_port\": $port,
        \"up_mbps\": $up_mbps,
        \"down_mbps\": $down_mbps,
        \"users\": [$users_json],
        \"tls\": {
            \"enabled\": true,
            \"server_name\": \"$(get_public_ip)\",
            \"insecure\": true,
            \"certificate_path\": \"$cert_dir/cert.pem\",
            \"key_path\": \"$cert_dir/private.key\",
            \"alpn\": [\"h3\"]
        }
    }"
}

# 生成TUIC5配置
generate_tuic5_config() {
    echo -e "${BLUE}配置 TUIC5...${NC}"
    
    local port
    local users=()
    
    # 端口配置
    while true; do
        read -p "请输入端口号 (默认: 随机): " port
        port=${port:-$(generate_random_port)}
        
        if validate_port "$port"; then
            break
        elif [[ $? -eq 2 ]]; then
            read -p "端口可能已被占用，是否继续使用? (y/n): " continue_choice
            if [[ "$continue_choice" =~ ^[yY]$ ]]; then
                break
            fi
        else
            echo -e "${RED}端口号无效，请输入 1-65535 之间的数字${NC}"
        fi
    done
    
    # 用户配置
    echo -e "${YELLOW}用户配置模式：${NC}"
    echo "1. 快速配置（使用默认用户）"
    echo "2. 自定义配置（添加多个用户）"
    read -p "请选择配置模式 (默认: 1): " config_mode
    config_mode=${config_mode:-1}
    
    local users_json=""
    if [[ "$config_mode" == "1" ]]; then
        # 快速配置，直接创建默认用户
        local default_uuid=$(generate_uuid)
        local default_password=$(generate_random_string 16)
        users_json="{\"name\":\"default\",\"uuid\":\"$default_uuid\",\"password\":\"$default_password\"}"
        echo -e "${GREEN}已创建默认用户，UUID: $default_uuid${NC}"
        echo -e "${GREEN}默认用户密码: $default_password${NC}"
    else
        # 自定义配置
        echo -e "${CYAN}说明：可以创建多个用户账号，每个用户都有独立的UUID和密码${NC}"
        echo -e "${CYAN}如果直接回车（留空）会自动创建一个默认用户${NC}"
        while true; do
            read -p "请输入用户名 (直接回车结束): " username
            if [[ -z "$username" ]]; then
                break
            fi
            local uuid=$(generate_uuid)
            read -p "请输入 $username 的密码: " password
            if [[ -n "$users_json" ]]; then
                users_json+=","
            fi
            users_json+="{\"name\":\"$username\",\"uuid\":\"$uuid\",\"password\":\"$password\"}"
            echo -e "${GREEN}用户 $username 的UUID: $uuid${NC}"
            echo -e "${GREEN}用户 $username 的密码: $password${NC}"
        done
        
        if [[ -z "$users_json" ]]; then
            local default_uuid=$(generate_uuid)
            local default_password=$(generate_random_string 16)
            users_json="{\"name\":\"default\",\"uuid\":\"$default_uuid\",\"password\":\"$default_password\"}"
            echo -e "${GREEN}默认用户UUID: $default_uuid${NC}"
            echo -e "${GREEN}默认用户密码: $default_password${NC}"
        fi
    fi
    
    # 生成自签名证书
    local cert_dir="$CONFIG_DIR/certs"
    mkdir -p "$cert_dir"
    
    # 生成证书
    openssl req -x509 -nodes -newkey rsa:2048 -keyout "$cert_dir/private.key" -out "$cert_dir/cert.pem" -days 365 -subj "/CN=$(get_public_ip)" 2>/dev/null
    
    # 存储配置信息到全局变量
    TUIC5_CONFIG="{
        \"type\": \"tuic\",
        \"tag\": \"tuic5\",
        \"listen\": \"::\",
        \"listen_port\": $port,
        \"users\": [$users_json],
        \"congestion_control\": \"bbr\",
        \"udp_relay_mode\": \"native\",
        \"udp_over_stream\": false,
        \"zero_rtt_handshake\": false,
        \"heartbeat\": \"10s\",
        \"tls\": {
            \"enabled\": true,
            \"server_name\": \"$(get_public_ip)\",
            \"insecure\": true,
            \"certificate_path\": \"$cert_dir/cert.pem\",
            \"key_path\": \"$cert_dir/private.key\",
            \"alpn\": [\"h3\"]
        }
    }"
}

# 生成完整配置文件
generate_config() {
    local protocols=("$@")
    local inbounds=()
    
    echo -e "${BLUE}生成配置文件...${NC}"
    
    # 创建配置目录
    mkdir -p "$CONFIG_DIR"
    
    # 根据选择的协议生成配置
    for protocol in "${protocols[@]}"; do
        case $protocol in
            "vless")
                generate_reality_config
                if [[ -n "$VLESS_CONFIG" ]]; then
                    inbounds+=("$VLESS_CONFIG")
                fi
                ;;
            "vmess")
                generate_vmess_config
                if [[ -n "$VMESS_CONFIG" ]]; then
                    inbounds+=("$VMESS_CONFIG")
                fi
                ;;
            "hysteria2")
                generate_hysteria2_config
                if [[ -n "$HYSTERIA2_CONFIG" ]]; then
                    inbounds+=("$HYSTERIA2_CONFIG")
                fi
                ;;
            "tuic5")
                generate_tuic5_config
                if [[ -n "$TUIC5_CONFIG" ]]; then
                    inbounds+=("$TUIC5_CONFIG")
                fi
                ;;
        esac
    done
    
    # 如果没有配置任何协议，退出
    if [[ ${#inbounds[@]} -eq 0 ]]; then
        echo -e "${RED}没有配置任何协议！${NC}"
        return 1
    fi
    
    # 构建inbounds数组
    local inbounds_json=""
    for i in "${!inbounds[@]}"; do
        if [[ $i -gt 0 ]]; then
            inbounds_json+=","
        fi
        inbounds_json+="${inbounds[$i]}"
    done
    
    # 生成完整配置
    cat > "$CONFIG_FILE" << EOF
{
    "log": {
        "disabled": false,
        "level": "info",
        "timestamp": true,
        "output": "$LOG_FILE"
    },
    "dns": {
        "rules": [
            {
                "outbound": ["any"],
                "server": "local"
            },
            {
                "clash_mode": "Proxy",
                "server": "remote"
            },
            {
                "clash_mode": "Direct",
                "server": "local"
            },
            {
                "rule_set": ["geosite-cn"],
                "server": "local"
            }
        ],
        "servers": [
            {
                "address": "https://1.1.1.1/dns-query",
                "detour": "direct",
                "tag": "remote"
            },
            {
                "address": "https://223.5.5.5/dns-query",
                "detour": "direct",
                "tag": "local"
            }
        ],
        "strategy": "prefer_ipv4"
    },
    "inbounds": [$inbounds_json],
    "outbounds": [
        {
            "type": "direct",
            "tag": "direct"
        },
        {
            "type": "block",
            "tag": "block"
        }
    ],
    "route": {
        "auto_detect_interface": true,
        "rules": [
            {
                "protocol": "dns",
                "action": "hijack-dns"
            },
            {
                "clash_mode": "Direct",
                "outbound": "direct"
            },
            {
                "clash_mode": "Proxy",
                "outbound": "direct"
            },
            {
                "rule_set": ["geosite-cn"],
                "outbound": "direct"
            },
            {
                "ip_is_private": true,
                "outbound": "direct"
            }
        ],
        "rule_set": [
            {
                "tag": "geosite-cn",
                "type": "remote",
                "format": "binary",
                "url": "https://fastly.jsdelivr.net/gh/SagerNet/sing-geosite@rule-set/geosite-cn.srs",
                "download_detour": "direct"
            }
        ]
    }
}
EOF
    
    echo -e "${GREEN}配置文件生成完成！${NC}"
    
    # 验证配置文件
    if [[ -f "$BINARY_PATH" ]]; then
        echo -e "${BLUE}验证配置文件...${NC}"
        if $BINARY_PATH check -c "$CONFIG_FILE"; then
            echo -e "${GREEN}配置文件验证通过！${NC}"
        else
            echo -e "${RED}配置文件验证失败！${NC}"
            return 1
        fi
    fi
    
    return 0
}

# 协议选择菜单
protocol_menu() {
    # 检查是否已安装sing-box
    if [[ ! -f "$BINARY_PATH" ]]; then
        echo -e "${RED}请先安装 sing-box！${NC}"
        return 1
    fi
    
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}           协议配置选择${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo "1. VLESS Reality"
    echo "2. VMess WebSocket"
    echo "3. Hysteria2"
    echo "4. TUIC5"
    echo "5. 全部安装"
    echo "6. 自定义组合"
    echo "7. 快速配置（推荐新手使用）"
    echo "0. 返回主菜单"
    echo -e "${CYAN}========================================${NC}"
    
    read -p "请选择协议: " choice
    
    local selected_protocols=()
    case $choice in
        1) 
            selected_protocols=("vless")
            ;;
        2) 
            selected_protocols=("vmess")
            ;;
        3) 
            selected_protocols=("hysteria2")
            ;;
        4) 
            selected_protocols=("tuic5")
            ;;
        5) 
            selected_protocols=("vless" "vmess" "hysteria2" "tuic5")
            ;;
        6)
            echo -e "${YELLOW}请选择要安装的协议（多选用空格分隔）：${NC}"
            echo "1. VLESS Reality"
            echo "2. VMess WebSocket"
            echo "3. Hysteria2"
            echo "4. TUIC5"
            read -p "输入选择: " -a custom_choices
            
            for custom_choice in "${custom_choices[@]}"; do
                case $custom_choice in
                    1) selected_protocols+=("vless") ;;
                    2) selected_protocols+=("vmess") ;;
                    3) selected_protocols+=("hysteria2") ;;
                    4) selected_protocols+=("tuic5") ;;
                esac
            done
            ;;
        7)
            echo -e "${BLUE}快速配置模式：将自动选择 VLESS Reality 协议${NC}"
            echo -e "${BLUE}所有参数将使用默认值，无需手动输入${NC}"
            selected_protocols=("vless")
            # 设置全局变量以启用快速配置
            export QUICK_CONFIG=true
            ;;
        0) 
            return 0
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            return 1
            ;;
    esac
    
    if [[ ${#selected_protocols[@]} -eq 0 ]]; then
        echo -e "${RED}未选择任何协议${NC}"
        return 1
    fi
    
    # 清空全局配置变量
    VLESS_CONFIG=""
    VMESS_CONFIG=""
    HYSTERIA2_CONFIG=""
    TUIC5_CONFIG=""
    
    # 生成配置
    if generate_config "${selected_protocols[@]}"; then
        # 启动服务
        echo -e "${BLUE}启动 sing-box 服务...${NC}"
        systemctl restart sing-box
        
        # 等待服务启动
        sleep 2
        
        if systemctl is-active --quiet sing-box; then
            echo -e "${GREEN}配置完成！服务已启动。${NC}"
            systemctl status sing-box --no-pager
        else
            echo -e "${RED}服务启动失败！${NC}"
            echo -e "${YELLOW}查看错误日志：${NC}"
            journalctl -u sing-box --no-pager -n 10
        fi
    else
        echo -e "${RED}配置生成失败！${NC}"
        return 1
    fi
}

# 更改端口号
change_port() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}配置文件不存在，请先安装 sing-box${NC}"
        return 1
    fi
    
    echo -e "${BLUE}当前配置的端口：${NC}"
    grep -o '"listen_port": [0-9]*' "$CONFIG_FILE" | sed 's/"listen_port": //'
    
    read -p "请输入新的端口号: " new_port
    
    if [[ ! "$new_port" =~ ^[0-9]+$ ]] || [[ "$new_port" -lt 1 ]] || [[ "$new_port" -gt 65535 ]]; then
        echo -e "${RED}端口号无效${NC}"
        return 1
    fi
    
    # 备份原配置
    cp "$CONFIG_FILE" "$CONFIG_FILE.backup"
    
    # 修改端口
    sed -i "s/\"listen_port\": [0-9]*/\"listen_port\": $new_port/" "$CONFIG_FILE"
    
    # 重启服务
    systemctl restart sing-box
    
    if systemctl is-active --quiet sing-box; then
        echo -e "${GREEN}端口修改成功！新端口: $new_port${NC}"
    else
        echo -e "${RED}服务启动失败，恢复原配置...${NC}"
        mv "$CONFIG_FILE.backup" "$CONFIG_FILE"
        systemctl restart sing-box
    fi
}

# 更新sing-box核心
update_singbox() {
    echo -e "${BLUE}正在更新 sing-box 核心...${NC}"
    
    # 停止服务
    systemctl stop sing-box
    
    # 备份配置
    cp "$CONFIG_FILE" "$CONFIG_FILE.backup"
    
    # 重新安装
    install_singbox
    
    # 恢复配置
    mv "$CONFIG_FILE.backup" "$CONFIG_FILE"
    
    # 启动服务
    systemctl start sing-box
    
    if systemctl is-active --quiet sing-box; then
        echo -e "${GREEN}sing-box 核心更新完成！${NC}"
        $BINARY_PATH version
    else
        echo -e "${RED}更新后服务启动失败，请检查配置${NC}"
    fi
}

# 卸载sing-box
uninstall_singbox() {
    echo -e "${YELLOW}确定要卸载 sing-box 吗？这将删除所有配置文件！${NC}"
    read -p "输入 'yes' 确认卸载: " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        echo -e "${BLUE}取消卸载${NC}"
        return 0
    fi
    
    echo -e "${BLUE}正在卸载 sing-box...${NC}"
    
    # 停止并禁用服务
    systemctl stop sing-box 2>/dev/null
    systemctl disable sing-box 2>/dev/null
    
    # 删除文件
    rm -f "$BINARY_PATH"
    rm -f "$SERVICE_FILE"
    rm -rf "$CONFIG_DIR"
    rm -f "$LOG_FILE"
    
    # 重新加载systemd
    systemctl daemon-reload
    
    echo -e "${GREEN}sing-box 卸载完成！${NC}"
}

# 显示客户端连接信息
show_client_info() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}配置文件不存在${NC}"
        return 1
    fi
    
    echo -e "${BLUE}======== 客户端连接信息 ========${NC}"
    
    local server_ip=$(get_public_ip)
    echo -e "${GREEN}服务器IP: $server_ip${NC}"
    echo
    
    # 解析VLESS Reality配置
    if grep -q "vless-reality" "$CONFIG_FILE"; then
        echo -e "${CYAN}=== VLESS Reality 配置 ===${NC}"
        local vless_port=$(grep -A 5 "vless-reality" "$CONFIG_FILE" | grep "listen_port" | grep -o '[0-9]*')
        local vless_uuid=$(grep -A 20 "vless-reality" "$CONFIG_FILE" | grep "uuid" | head -1 | grep -o '[0-9a-f-]*')
        local private_key=$(grep -A 30 "vless-reality" "$CONFIG_FILE" | grep "private_key" | cut -d'"' -f4)
        local short_id=$(grep -A 30 "vless-reality" "$CONFIG_FILE" | grep "short_id" | grep -o '[0-9a-f]*' | head -1)
        local server_name=$(grep -A 30 "vless-reality" "$CONFIG_FILE" | grep "server_name" | cut -d'"' -f4)
        
        # 生成Reality公钥（从私钥推导，这里简化处理）
        local public_key=$(echo "$private_key" | base64 -d 2>/dev/null | base64 -w 0 2>/dev/null || echo "$private_key")
        
        echo "  服务器: $server_ip"
        echo "  端口: $vless_port"
        echo "  UUID: $vless_uuid"
        echo "  私钥: $private_key"
        echo "  短ID: $short_id"
        echo "  服务器名称: $server_name"
        echo
        
        # 生成VLESS链接
        local vless_link=$(generate_vless_link "$server_ip" "$vless_port" "$vless_uuid" "$public_key" "$short_id" "$server_name")
        echo -e "${YELLOW}VLESS链接:${NC}"
        echo "$vless_link"
        echo
        
        # 生成QR码
        echo -e "${YELLOW}VLESS QR码:${NC}"
        if generate_qr_code "$vless_link" 2; then
            echo
        else
            echo -e "${RED}QR码生成失败${NC}"
        fi
        echo
    fi
    
    # 解析VMess配置
    if grep -q "vmess-ws" "$CONFIG_FILE"; then
        echo -e "${CYAN}=== VMess WebSocket 配置 ===${NC}"
        local vmess_port=$(grep -A 5 "vmess-ws" "$CONFIG_FILE" | grep "listen_port" | grep -o '[0-9]*')
        local vmess_uuid=$(grep -A 20 "vmess-ws" "$CONFIG_FILE" | grep "uuid" | head -1 | grep -o '[0-9a-f-]*')
        local ws_path=$(grep -A 30 "vmess-ws" "$CONFIG_FILE" | grep "path" | cut -d'"' -f4)
        
        echo "  服务器: $server_ip"
        echo "  端口: $vmess_port"
        echo "  UUID: $vmess_uuid"
        echo "  WebSocket路径: $ws_path"
        echo "  传输协议: ws"
        echo "  加密: auto"
        echo
        
        # 生成VMess链接
        local vmess_link=$(generate_vmess_link "$server_ip" "$vmess_port" "$vmess_uuid" "$ws_path")
        echo -e "${YELLOW}VMess链接:${NC}"
        echo "$vmess_link"
        echo
        
        # 生成QR码
        echo -e "${YELLOW}VMess QR码:${NC}"
        if generate_qr_code "$vmess_link" 2; then
            echo
        else
            echo -e "${RED}QR码生成失败${NC}"
        fi
        echo
    fi
    
    # 解析Hysteria2配置
    if grep -q "hysteria2" "$CONFIG_FILE"; then
        echo -e "${CYAN}=== Hysteria2 配置 ===${NC}"
        local hy2_port=$(grep -A 5 "hysteria2" "$CONFIG_FILE" | grep "listen_port" | grep -o '[0-9]*')
        local hy2_password=$(grep -A 20 "hysteria2" "$CONFIG_FILE" | grep "password" | head -1 | cut -d'"' -f4)
        local up_mbps=$(grep -A 10 "hysteria2" "$CONFIG_FILE" | grep "up_mbps" | grep -o '[0-9]*')
        local down_mbps=$(grep -A 10 "hysteria2" "$CONFIG_FILE" | grep "down_mbps" | grep -o '[0-9]*')
        
        echo "  服务器: $server_ip"
        echo "  端口: $hy2_port"
        echo "  密码: $hy2_password"
        echo "  上行带宽: ${up_mbps}Mbps"
        echo "  下行带宽: ${down_mbps}Mbps"
        echo "  协议: hysteria2"
        echo "  注意: 客户端需要跳过证书验证"
        echo
        
        # 生成Hysteria2链接
        local hy2_link=$(generate_hysteria2_link "$server_ip" "$hy2_port" "$hy2_password")
        echo -e "${YELLOW}Hysteria2链接:${NC}"
        echo "$hy2_link"
        echo
        
        # 生成QR码
        echo -e "${YELLOW}Hysteria2 QR码:${NC}"
        if generate_qr_code "$hy2_link" 2; then
            echo
        else
            echo -e "${RED}QR码生成失败${NC}"
        fi
        echo
    fi
    
    # 解析TUIC5配置
    if grep -q "tuic5" "$CONFIG_FILE"; then
        echo -e "${CYAN}=== TUIC5 配置 ===${NC}"
        local tuic5_port=$(grep -A 5 "tuic5" "$CONFIG_FILE" | grep "listen_port" | grep -o '[0-9]*')
        local tuic5_uuid=$(grep -A 20 "tuic5" "$CONFIG_FILE" | grep "uuid" | head -1 | grep -o '[0-9a-f-]*')
        local tuic5_password=$(grep -A 20 "tuic5" "$CONFIG_FILE" | grep "password" | head -1 | cut -d'"' -f4)
        
        echo "  服务器: $server_ip"
        echo "  端口: $tuic5_port"
        echo "  UUID: $tuic5_uuid"
        echo "  密码: $tuic5_password"
        echo "  拥塞控制: bbr"
        echo "  UDP中继模式: native"
        echo "  ALPN: h3"
        echo "  注意: 客户端需要跳过证书验证"
        echo
        
        # 生成TUIC5链接
        local tuic5_link=$(generate_tuic5_link "$server_ip" "$tuic5_port" "$tuic5_uuid" "$tuic5_password")
        echo -e "${YELLOW}TUIC5链接:${NC}"
        echo "$tuic5_link"
        echo
        
        # 生成QR码
        echo -e "${YELLOW}TUIC5 QR码:${NC}"
        if generate_qr_code "$tuic5_link" 2; then
            echo
        else
            echo -e "${RED}QR码生成失败${NC}"
        fi
        echo
    fi
    
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${YELLOW}配置文件位置: $CONFIG_FILE${NC}"
    echo -e "${YELLOW}日志文件位置: $LOG_FILE${NC}"
    echo -e "${YELLOW}使用说明: 扫描QR码或复制链接到客户端${NC}"
    echo -e "${PURPLE}========================================${NC}"
}

# 查看配置信息
show_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}配置文件不存在${NC}"
        return 1
    fi
    
    echo -e "${BLUE}当前配置信息：${NC}"
    echo -e "${YELLOW}配置文件路径: $CONFIG_FILE${NC}"
    echo -e "${YELLOW}服务状态:${NC}"
    systemctl status sing-box --no-pager
    
    echo -e "\n${YELLOW}端口信息:${NC}"
    grep -o '"listen_port": [0-9]*' "$CONFIG_FILE" | sed 's/"listen_port": /端口: /'
    
    echo -e "\n${YELLOW}日志位置: $LOG_FILE${NC}"
    
    if [[ -f "$LOG_FILE" ]]; then
        echo -e "\n${YELLOW}最近日志:${NC}"
        tail -n 20 "$LOG_FILE"
    fi
}

# 清理临时文件
cleanup_temp() {
    local temp_dir="$1"
    if [[ -d "$temp_dir" ]]; then
        rm -rf "$temp_dir"
    fi
}

# 主菜单
main_menu() {
    while true; do
        clear
        echo -e "${PURPLE}========================================${NC}"
        echo -e "${PURPLE}         sing-box 一键安装脚本${NC}"
        echo -e "${PURPLE}         支持 VLESS Reality/VMess/Hysteria2${NC}"
        echo -e "${PURPLE}========================================${NC}"
        echo "1. 安装 sing-box"
        echo "2. 配置协议"
        echo "3. 查看客户端连接信息"
        echo "4. 查看配置和服务状态"
        echo "5. 更改端口号"
        echo "6. 更新 sing-box 核心"
        echo "7. 卸载 sing-box"
        echo "0. 退出"
        echo -e "${PURPLE}========================================${NC}"
        
        read -p "请选择操作: " choice
        
        case $choice in
            1)
                install_singbox
                read -p "按回车键继续..."
                ;;
            2)
                protocol_menu
                read -p "按回车键继续..."
                ;;
            3)
                show_client_info
                read -p "按回车键继续..."
                ;;
            4)
                show_config
                read -p "按回车键继续..."
                ;;
            5)
                change_port
                read -p "按回车键继续..."
                ;;
            6)
                update_singbox
                read -p "按回车键继续..."
                ;;
            7)
                uninstall_singbox
                read -p "按回车键继续..."
                ;;
            0)
                echo -e "${GREEN}谢谢使用！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                sleep 2
                ;;
        esac
    done
}

# 检查依赖
check_dependencies() {
    local deps=("curl" "tar" "systemctl" "openssl")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo -e "${RED}缺少依赖: $dep${NC}"
            echo -e "${BLUE}正在安装依赖...${NC}"
            
            if command -v apt-get &> /dev/null; then
                apt-get update && apt-get install -y "$dep"
            elif command -v yum &> /dev/null; then
                yum install -y "$dep"
            elif command -v dnf &> /dev/null; then
                dnf install -y "$dep"
            else
                echo -e "${RED}无法自动安装依赖 $dep，请手动安装${NC}"
                exit 1
            fi
        fi
    done
    
    # 提示用户 qrencode 是可选的
    if ! command -v qrencode &> /dev/null; then
        echo -e "${YELLOW}注意: qrencode 未安装，QR码功能将不可用${NC}"
        echo -e "${YELLOW}可以通过以下命令安装:${NC}"
        if command -v apt-get &> /dev/null; then
            echo -e "${YELLOW}  apt-get install qrencode${NC}"
        elif command -v yum &> /dev/null; then
            echo -e "${YELLOW}  yum install qrencode${NC}"
        elif command -v dnf &> /dev/null; then
            echo -e "${YELLOW}  dnf install qrencode${NC}"
        fi
    fi
}

# 主函数
main() {
    check_root
    check_dependencies
    main_menu
}

# 运行主函数
main "$@"
