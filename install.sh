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

# 生成Reality配置
generate_reality_config() {
    echo -e "${BLUE}配置 VLESS Reality...${NC}"
    
    local port
    local users=()
    local dest_server
    local server_names
    
    # 端口配置
    read -p "请输入端口号 (默认: 443): " port
    port=${port:-443}
    
    # 用户配置
    echo -e "${YELLOW}用户配置：${NC}"
    while true; do
        read -p "请输入用户名 (留空结束): " username
        if [[ -z "$username" ]]; then
            break
        fi
        local uuid=$(generate_uuid)
        users+=("{\"name\":\"$username\",\"uuid\":\"$uuid\"}")
        echo -e "${GREEN}用户 $username 的UUID: $uuid${NC}"
    done
    
    if [[ ${#users[@]} -eq 0 ]]; then
        local default_uuid=$(generate_uuid)
        users+=("{\"name\":\"default\",\"uuid\":\"$default_uuid\"}")
        echo -e "${GREEN}默认用户UUID: $default_uuid${NC}"
    fi
    
    # 目标服务器配置
    read -p "请输入目标服务器 (默认: www.microsoft.com): " dest_server
    dest_server=${dest_server:-www.microsoft.com}
    
    # 服务器名称配置
    read -p "请输入服务器名称 (默认: www.microsoft.com): " server_names
    server_names=${server_names:-www.microsoft.com}
    
    # 生成密钥对
    local key_pair=$(sing-box generate reality-keypair)
    local private_key=$(echo "$key_pair" | grep "PrivateKey" | awk '{print $2}')
    local public_key=$(echo "$key_pair" | grep "PublicKey" | awk '{print $2}')
    
    echo -e "${GREEN}Reality 公钥: $public_key${NC}"
    echo -e "${GREEN}Reality 私钥: $private_key${NC}"
    
    # 生成short_id
    local short_id=$(openssl rand -hex 8)
    
    # 返回配置
    cat << EOF
{
    "type": "vless",
    "tag": "vless-reality",
    "listen": "::",
    "listen_port": $port,
    "users": [$(IFS=,; echo "${users[*]}")],
    "tls": {
        "enabled": true,
        "server_name": "$server_names",
        "reality": {
            "enabled": true,
            "handshake": {
                "server": "$dest_server",
                "server_port": 443
            },
            "private_key": "$private_key",
            "short_id": ["$short_id"]
        }
    }
}
EOF
}

# 生成VMess配置
generate_vmess_config() {
    echo -e "${BLUE}配置 VMess...${NC}"
    
    local port
    local users=()
    
    # 端口配置
    read -p "请输入端口号 (默认: 随机): " port
    port=${port:-$(generate_random_port)}
    
    # 用户配置
    echo -e "${YELLOW}用户配置：${NC}"
    while true; do
        read -p "请输入用户名 (留空结束): " username
        if [[ -z "$username" ]]; then
            break
        fi
        local uuid=$(generate_uuid)
        users+=("{\"name\":\"$username\",\"uuid\":\"$uuid\"}")
        echo -e "${GREEN}用户 $username 的UUID: $uuid${NC}"
    done
    
    if [[ ${#users[@]} -eq 0 ]]; then
        local default_uuid=$(generate_uuid)
        users+=("{\"name\":\"default\",\"uuid\":\"$default_uuid\"}")
        echo -e "${GREEN}默认用户UUID: $default_uuid${NC}"
    fi
    
    # 返回配置
    cat << EOF
{
    "type": "vmess",
    "tag": "vmess-ws",
    "listen": "::",
    "listen_port": $port,
    "users": [$(IFS=,; echo "${users[*]}")],
    "transport": {
        "type": "ws",
        "path": "/$(generate_random_string 8)",
        "headers": {
            "Host": "$(get_public_ip)"
        }
    }
}
EOF
}

# 生成Hysteria2配置
generate_hysteria2_config() {
    echo -e "${BLUE}配置 Hysteria2...${NC}"
    
    local port
    local users=()
    local up_mbps
    local down_mbps
    
    # 端口配置
    read -p "请输入端口号 (默认: 随机): " port
    port=${port:-$(generate_random_port)}
    
    # 带宽配置
    read -p "请输入上行带宽 (Mbps, 默认: 100): " up_mbps
    up_mbps=${up_mbps:-100}
    
    read -p "请输入下行带宽 (Mbps, 默认: 100): " down_mbps
    down_mbps=${down_mbps:-100}
    
    # 用户配置
    echo -e "${YELLOW}用户配置：${NC}"
    while true; do
        read -p "请输入用户名 (留空结束): " username
        if [[ -z "$username" ]]; then
            break
        fi
        read -p "请输入 $username 的密码: " password
        users+=("{\"name\":\"$username\",\"password\":\"$password\"}")
        echo -e "${GREEN}用户 $username 已添加${NC}"
    done
    
    if [[ ${#users[@]} -eq 0 ]]; then
        local default_password=$(generate_random_string 16)
        users+=("{\"name\":\"default\",\"password\":\"$default_password\"}")
        echo -e "${GREEN}默认用户密码: $default_password${NC}"
    fi
    
    # 生成自签名证书
    local cert_dir="$CONFIG_DIR/certs"
    mkdir -p "$cert_dir"
    
    # 生成证书
    openssl req -x509 -nodes -newkey rsa:2048 -keyout "$cert_dir/private.key" -out "$cert_dir/cert.pem" -days 365 -subj "/CN=$(get_public_ip)" 2>/dev/null
    
    # 返回配置
    cat << EOF
{
    "type": "hysteria2",
    "tag": "hysteria2",
    "listen": "::",
    "listen_port": $port,
    "up_mbps": $up_mbps,
    "down_mbps": $down_mbps,
    "users": [$(IFS=,; echo "${users[*]}")],
    "tls": {
        "enabled": true,
        "certificate_path": "$cert_dir/cert.pem",
        "key_path": "$cert_dir/private.key"
    }
}
EOF
}

# 生成完整配置文件
generate_config() {
    local protocols=("$@")
    local inbounds=()
    
    echo -e "${BLUE}生成配置文件...${NC}"
    
    # 根据选择的协议生成配置
    for protocol in "${protocols[@]}"; do
        case $protocol in
            "vless")
                inbounds+=($(generate_reality_config))
                ;;
            "vmess")
                inbounds+=($(generate_vmess_config))
                ;;
            "hysteria2")
                inbounds+=($(generate_hysteria2_config))
                ;;
        esac
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
    "inbounds": [$(IFS=,; echo "${inbounds[*]}")],
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
}

# 协议选择菜单
protocol_menu() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}           协议配置选择${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo "1. VLESS Reality"
    echo "2. VMess WebSocket"
    echo "3. Hysteria2"
    echo "4. 全部安装"
    echo "0. 返回主菜单"
    echo -e "${CYAN}========================================${NC}"
    
    read -p "请选择协议 (可多选，用空格分隔): " -a choices
    
    local selected_protocols=()
    for choice in "${choices[@]}"; do
        case $choice in
            1) selected_protocols+=("vless") ;;
            2) selected_protocols+=("vmess") ;;
            3) selected_protocols+=("hysteria2") ;;
            4) selected_protocols=("vless" "vmess" "hysteria2") ;;
            0) return 0 ;;
        esac
    done
    
    if [[ ${#selected_protocols[@]} -eq 0 ]]; then
        echo -e "${RED}未选择任何协议${NC}"
        return 1
    fi
    
    generate_config "${selected_protocols[@]}"
    
    # 启动服务
    systemctl restart sing-box
    systemctl status sing-box --no-pager
    
    echo -e "${GREEN}配置完成！服务已启动。${NC}"
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
        echo "3. 更改端口号"
        echo "4. 更新 sing-box 核心"
        echo "5. 查看配置信息"
        echo "6. 卸载 sing-box"
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
                change_port
                read -p "按回车键继续..."
                ;;
            4)
                update_singbox
                read -p "按回车键继续..."
                ;;
            5)
                show_config
                read -p "按回车键继续..."
                ;;
            6)
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
            else
                echo -e "${RED}无法自动安装依赖 $dep，请手动安装${NC}"
                exit 1
            fi
        fi
    done
}

# 主函数
main() {
    check_root
    check_dependencies
    main_menu
}

# 运行主函数
main "$@"
