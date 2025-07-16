#!/bin/bash

# Sing-box 管理脚本
# 版本: v1.0.0
# 作者: 个人定制版本

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
CONFIG_DIR="/etc/sing-box"
DATA_DIR="/usr/local/etc/sing-box"
LOG_DIR="/var/log/sing-box"
CONFIG_FILE="$CONFIG_DIR/config.json"
DB_FILE="$DATA_DIR/sing-box.db"
CERT_FILE="$CONFIG_DIR/cert.pem"
KEY_FILE="$CONFIG_DIR/key.pem"

# 输出函数
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

highlight() {
    echo -e "${PURPLE}$1${NC}"
}

# 交互界面函数
print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                              Sing-box 一键管理脚本                              ║"
    echo "║                                   版本: $SCRIPT_VERSION                                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_separator() {
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════════════${NC}"
}

print_sub_separator() {
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────────────────────${NC}"
}

# 主菜单
show_main_menu() {
    clear
    print_banner
    echo -e "${GREEN}请选择操作：${NC}"
    echo
    echo -e "${YELLOW}  [1]${NC} 添加配置"
    echo -e "${YELLOW}  [2]${NC} 管理配置"
    echo -e "${YELLOW}  [3]${NC} 系统管理"
    echo -e "${YELLOW}  [4]${NC} 分享链接"
    echo -e "${YELLOW}  [5]${NC} 系统信息"
    echo -e "${YELLOW}  [6]${NC} 更新脚本"
    echo -e "${YELLOW}  [0]${NC} 退出脚本"
    echo
    print_sub_separator
}

# 添加配置菜单
show_add_menu() {
    clear
    print_banner
    echo -e "${GREEN}选择要添加的协议：${NC}"
    echo
    echo -e "${YELLOW}  [1]${NC} VLESS Reality (推荐)"
    echo -e "${YELLOW}  [2]${NC} VMess"
    echo -e "${YELLOW}  [3]${NC} Hysteria2"
    echo -e "${YELLOW}  [4]${NC} Shadowsocks"
    echo -e "${YELLOW}  [0]${NC} 返回主菜单"
    echo
    print_sub_separator
}

# 管理配置菜单
show_manage_menu() {
    clear
    print_banner
    echo -e "${GREEN}配置管理：${NC}"
    echo
    echo -e "${YELLOW}  [1]${NC} 查看所有配置"
    echo -e "${YELLOW}  [2]${NC} 查看配置详情"
    echo -e "${YELLOW}  [3]${NC} 删除配置"
    echo -e "${YELLOW}  [4]${NC} 更换端口"
    echo -e "${YELLOW}  [5]${NC} 重新生成 UUID"
    echo -e "${YELLOW}  [0]${NC} 返回主菜单"
    echo
    print_sub_separator
}

# 系统管理菜单
show_system_menu() {
    clear
    print_banner
    echo -e "${GREEN}系统管理：${NC}"
    echo
    echo -e "${YELLOW}  [1]${NC} 启动服务"
    echo -e "${YELLOW}  [2]${NC} 停止服务"
    echo -e "${YELLOW}  [3]${NC} 重启服务"
    echo -e "${YELLOW}  [4]${NC} 查看状态"
    echo -e "${YELLOW}  [5]${NC} 查看日志"
    echo -e "${YELLOW}  [6]${NC} 系统优化"
    echo -e "${YELLOW}  [7]${NC} 卸载 Sing-box"
    echo -e "${YELLOW}  [0]${NC} 返回主菜单"
    echo
    print_sub_separator
}

# 分享链接菜单
show_share_menu() {
    clear
    print_banner
    echo -e "${GREEN}分享链接：${NC}"
    echo
    echo -e "${YELLOW}  [1]${NC} 显示所有分享链接"
    echo -e "${YELLOW}  [2]${NC} 显示指定配置链接"
    echo -e "${YELLOW}  [3]${NC} 生成二维码"
    echo -e "${YELLOW}  [4]${NC} 导出配置文件"
    echo -e "${YELLOW}  [0]${NC} 返回主菜单"
    echo
    print_sub_separator
}

# 输入验证函数
read_input() {
    local prompt="$1"
    local default="$2"
    local input
    
    if [[ -n $default ]]; then
        echo -ne "${GREEN}$prompt${NC} [${YELLOW}$default${NC}]: "
    else
        echo -ne "${GREEN}$prompt${NC}: "
    fi
    
    read -r input
    # 去除前后空白字符并返回
    input="${input:-$default}"
    input="${input// /}"  # 移除所有空格
    printf "%s" "$input"
}

read_port() {
    local prompt="$1"
    local default="$2"
    local port
    
    while true; do
        port=$(read_input "$prompt" "$default")
        if [[ $port =~ ^[0-9]+$ ]] && [[ $port -ge 1 ]] && [[ $port -le 65535 ]]; then
            if check_port $port; then
                echo $port
                break
            else
                warn "端口 $port 已被占用，请选择其他端口"
            fi
        else
            warn "请输入有效的端口号 (1-65535)"
        fi
    done
}

read_domain() {
    local prompt="$1"
    local default="$2"
    local domain
    
    while true; do
        domain=$(read_input "$prompt" "$default")
        if [[ $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$ ]]; then
            echo $domain
            break
        else
            warn "请输入有效的域名格式"
        fi
    done
}

confirm() {
    local prompt="$1"
    local input
    
    while true; do
        echo -ne "${GREEN}$prompt${NC} [${YELLOW}y/N${NC}]: "
        read -r input
        case $input in
            [yY]|[yY][eE][sS])
                return 0
                ;;
            [nN]|[nN][oO]|"")
                return 1
                ;;
            *)
                warn "请输入 y 或 n"
                ;;
        esac
    done
}

# 进度条函数
show_progress() {
    local current=$1
    local total=$2
    local desc="$3"
    local percent=$((current * 100 / total))
    local bar_length=50
    local filled_length=$((percent * bar_length / 100))
    
    printf "\r${GREEN}$desc${NC} ["
    for ((i = 0; i < filled_length; i++)); do
        printf "█"
    done
    for ((i = filled_length; i < bar_length; i++)); do
        printf "░"
    done
    printf "] ${YELLOW}%d%%${NC}" $percent
    
    if [[ $current -eq $total ]]; then
        echo
    fi
}

# 等待用户输入
wait_for_input() {
    echo
    echo -ne "${CYAN}按回车键继续...${NC}"
    read -r
}

# 工具函数
generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen
    else
        cat /proc/sys/kernel/random/uuid
    fi
}

generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-16
}

get_random_port() {
    local port
    while true; do
        port=$((RANDOM % 55535 + 10000))
        if ! ss -tuln | grep -q ":$port "; then
            echo $port
            break
        fi
    done
}

check_port() {
    local port=$1
    if ss -tuln | grep -q ":$port "; then
        return 1
    else
        return 0
    fi
}

get_public_ip() {
    local ip
    ip=$(curl -s ipv4.icanhazip.com 2>/dev/null || curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null)
    if [[ -z $ip ]]; then
        ip="YOUR_SERVER_IP"
    fi
    echo $ip
}

generate_reality_keys() {
    /usr/local/bin/sing-box generate reality-keypair
}

get_short_id() {
    openssl rand -hex 8
}

# 数据库操作
init_db() {
    if [[ ! -f $DB_FILE ]]; then
        touch $DB_FILE
    fi
}

add_config_to_db() {
    local name=$1
    local protocol=$2
    local port=$3
    local uuid=$4
    local extra=$5
    
    echo "$name|$protocol|$port|$uuid|$extra|$(date '+%Y-%m-%d %H:%M:%S')" >> $DB_FILE
}

get_config_from_db() {
    local name=$1
    grep "^$name|" $DB_FILE 2>/dev/null || true
}

list_configs_from_db() {
    if [[ -f $DB_FILE ]] && [[ -s $DB_FILE ]]; then
        cat $DB_FILE
    fi
}

delete_config_from_db() {
    local name=$1
    if [[ -f $DB_FILE ]]; then
        sed -i "/^$name|/d" $DB_FILE
    fi
}

# 更新配置的 UUID
update_config_uuid_in_db() {
    local name=$1
    local new_uuid=$2
    
    if [[ -f $DB_FILE ]]; then
        local temp_file=$(mktemp)
        while IFS='|' read -r config_name protocol port old_uuid extra created; do
            if [[ $config_name == $name ]]; then
                echo "$config_name|$protocol|$port|$new_uuid|$extra|$created" >> $temp_file
            else
                echo "$config_name|$protocol|$port|$old_uuid|$extra|$created" >> $temp_file
            fi
        done < $DB_FILE
        mv $temp_file $DB_FILE
    fi
}

# VLESS Reality 配置模板
generate_vless_reality_config() {
    local name=$1
    local port=$2
    local uuid=$3
    local private_key=$4
    local public_key=$5
    local short_id=$6
    local sni=${7:-"www.google.com"}
    
    cat << EOF
{
  "type": "vless",
  "tag": "$name",
  "listen": "::",
  "listen_port": $port,
  "users": [
    {
      "uuid": "$uuid",
      "flow": "xtls-rprx-vision"
    }
  ],
  "tls": {
    "enabled": true,
    "server_name": "$sni",
    "reality": {
      "enabled": true,
      "handshake": {
        "server": "$sni",
        "server_port": 443
      },
      "private_key": "$private_key",
      "short_id": ["$short_id"]
    }
  }
}
EOF
}

# VMess 配置模板
generate_vmess_config() {
    local name=$1
    local port=$2
    local uuid=$3
    local path=$4
    local domain=$5
    
    cat << EOF
{
  "type": "vmess",
  "tag": "$name",
  "listen": "::",
  "listen_port": $port,
  "users": [
    {
      "uuid": "$uuid",
      "alterId": 0
    }
  ],
  "transport": {
    "type": "ws",
    "path": "$path"
  },
  "tls": {
    "enabled": true,
    "server_name": "$domain",
    "certificate_path": "$CERT_FILE",
    "key_path": "$KEY_FILE"
  }
}
EOF
}

# Hysteria2 配置模板
generate_hy2_config() {
    local name=$1
    local port=$2
    local password=$3
    local domain=$4
    
    cat << EOF
{
  "type": "hysteria2",
  "tag": "$name",
  "listen": "::",
  "listen_port": $port,
  "users": [
    {
      "password": "$password"
    }
  ],
  "tls": {
    "enabled": true,
    "server_name": "$domain",
    "certificate_path": "$CERT_FILE",
    "key_path": "$KEY_FILE"
  }
}
EOF
}

# Shadowsocks 配置模板
generate_shadowsocks_config() {
    local name=$1
    local port=$2
    local method=$3
    local password=$4
    
    cat << EOF
{
  "type": "shadowsocks",
  "tag": "$name",
  "listen": "::",
  "listen_port": $port,
  "method": "$method",
  "password": "$password"
}
EOF
}

# 更新主配置文件
update_main_config() {
    local configs_json="[]"
    
    # 读取所有配置文件
    if [[ -d "$CONFIG_DIR/configs" ]]; then
        local first=true
        configs_json="["
        for config_file in "$CONFIG_DIR/configs"/*.json; do
            if [[ -f "$config_file" ]]; then
                if [[ $first == true ]]; then
                    first=false
                else
                    configs_json="$configs_json,"
                fi
                configs_json="$configs_json$(cat "$config_file")"
            fi
        done
        configs_json="$configs_json]"
    fi
    
    # 生成主配置
    cat > "$CONFIG_FILE" << EOF
{
  "log": {
    "level": "info",
    "timestamp": true,
    "output": "$LOG_DIR/sing-box.log"
  },
  "inbounds": $configs_json,
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF
}

# 交互式配置添加函数
interactive_add_vless_reality() {
    clear
    print_banner
    echo -e "${GREEN}添加 VLESS Reality 配置${NC}"
    print_sub_separator
    
    # 获取配置名称
    local name
    while true; do
        name=$(read_input "请输入配置名称" "vless-$(date +%s)")
        if [[ -z $(get_config_from_db "$name") ]]; then
            break
        else
            warn "配置名称 '$name' 已存在，请使用其他名称"
        fi
    done
    
    # 获取端口
    local default_port=$(get_random_port)
    local port=$(read_port "请输入监听端口" "$default_port")
    
    # 获取 SNI
    local sni=$(read_domain "请输入 SNI 域名" "www.google.com")
    
    # 确认配置
    echo
    print_sub_separator
    echo -e "${YELLOW}配置预览：${NC}"
    echo "  名称: $name"
    echo "  端口: $port"
    echo "  SNI: $sni"
    echo "  UUID: 将自动生成"
    echo "  Reality 密钥: 将自动生成"
    print_sub_separator
    
    if confirm "确认添加此配置吗？"; then
        echo
        info "正在添加配置..."
        add_vless_reality "$name" "$port" "$sni"
        wait_for_input
    else
        warn "配置添加已取消"
        wait_for_input
    fi
}

interactive_add_vmess() {
    clear
    print_banner
    echo -e "${GREEN}添加 VMess 配置${NC}"
    print_sub_separator
    
    # 获取配置名称
    local name
    while true; do
        name=$(read_input "请输入配置名称" "vmess-$(date +%s)")
        if [[ -z $(get_config_from_db "$name") ]]; then
            break
        else
            warn "配置名称 '$name' 已存在，请使用其他名称"
        fi
    done
    
    # 获取端口
    local default_port=$(get_random_port)
    local port=$(read_port "请输入监听端口" "$default_port")
    
    # 获取域名
    local domain=$(read_domain "请输入域名" "example.com")
    
    # 获取 WebSocket 路径
    local path=$(read_input "请输入 WebSocket 路径" "/ws")
    
    # 确认配置
    echo
    print_sub_separator
    echo -e "${YELLOW}配置预览：${NC}"
    echo "  名称: $name"
    echo "  端口: $port"
    echo "  域名: $domain"
    echo "  路径: $path"
    echo "  UUID: 将自动生成"
    print_sub_separator
    
    if confirm "确认添加此配置吗？"; then
        echo
        info "正在添加配置..."
        add_vmess "$name" "$port" "$domain" "$path"
        wait_for_input
    else
        warn "配置添加已取消"
        wait_for_input
    fi
}

interactive_add_hysteria2() {
    clear
    print_banner
    echo -e "${GREEN}添加 Hysteria2 配置${NC}"
    print_sub_separator
    
    # 获取配置名称
    local name
    while true; do
        name=$(read_input "请输入配置名称" "hy2-$(date +%s)")
        if [[ -z $(get_config_from_db "$name") ]]; then
            break
        else
            warn "配置名称 '$name' 已存在，请使用其他名称"
        fi
    done
    
    # 获取端口
    local default_port=$(get_random_port)
    local port=$(read_port "请输入监听端口" "$default_port")
    
    # 获取域名
    local domain=$(read_domain "请输入域名" "example.com")
    
    # 获取密码
    local password=$(read_input "请输入密码" "$(generate_password)")
    
    # 确认配置
    echo
    print_sub_separator
    echo -e "${YELLOW}配置预览：${NC}"
    echo "  名称: $name"
    echo "  端口: $port"
    echo "  域名: $domain"
    echo "  密码: $password"
    print_sub_separator
    
    if confirm "确认添加此配置吗？"; then
        echo
        info "正在添加配置..."
        add_hysteria2 "$name" "$port" "$domain" "$password"
        wait_for_input
    else
        warn "配置添加已取消"
        wait_for_input
    fi
}

interactive_add_shadowsocks() {
    clear
    print_banner
    echo -e "${GREEN}添加 Shadowsocks 配置${NC}"
    print_sub_separator
    
    # 获取配置名称
    local name
    while true; do
        name=$(read_input "请输入配置名称" "ss-$(date +%s)")
        if [[ -z $(get_config_from_db "$name") ]]; then
            break
        else
            warn "配置名称 '$name' 已存在，请使用其他名称"
        fi
    done
    
    # 获取端口
    local default_port=$(get_random_port)
    local port=$(read_port "请输入监听端口" "$default_port")
    
    # 获取加密方式
    echo -e "${GREEN}请选择加密方式：${NC}"
    echo "  [1] chacha20-ietf-poly1305 (推荐)"
    echo "  [2] aes-256-gcm"
    echo "  [3] aes-128-gcm"
    echo "  [4] chacha20-poly1305"
    
    local method_choice
    while true; do
        method_choice=$(read_input "请选择加密方式" "1")
        case "$method_choice" in
            "1") method="chacha20-ietf-poly1305"; break ;;
            "2") method="aes-256-gcm"; break ;;
            "3") method="aes-128-gcm"; break ;;
            "4") method="chacha20-poly1305"; break ;;
            *) warn "请输入有效的选项 (1-4)" ;;
        esac
    done
    
    # 获取密码
    local password=$(read_input "请输入密码" "$(generate_password)")
    
    # 确认配置
    echo
    print_sub_separator
    echo -e "${YELLOW}配置预览：${NC}"
    echo "  名称: $name"
    echo "  端口: $port"
    echo "  加密: $method"
    echo "  密码: $password"
    print_sub_separator
    
    if confirm "确认添加此配置吗？"; then
        echo
        info "正在添加配置..."
        add_shadowsocks "$name" "$port" "$method" "$password"
        wait_for_input
    else
        warn "配置添加已取消"
        wait_for_input
    fi
}

# 添加 VLESS Reality 配置
add_vless_reality() {
    local name=${1:-"vless-$(date +%s)"}
    local port=${2:-$(get_random_port)}
    local sni=${3:-"www.google.com"}
    
    info "添加 VLESS Reality 配置: $name"
    
    # 检查端口
    if ! check_port $port; then
        error "端口 $port 已被占用"
    fi
    
    # 检查配置是否已存在
    if [[ -n $(get_config_from_db $name) ]]; then
        error "配置 $name 已存在"
    fi
    
    # 生成参数
    local uuid=$(generate_uuid)
    local keys=$(generate_reality_keys)
    local private_key=$(echo "$keys" | grep "PrivateKey:" | awk '{print $2}')
    local public_key=$(echo "$keys" | grep "PublicKey:" | awk '{print $2}')
    local short_id=$(get_short_id)
    
    # 生成配置文件
    local config_content=$(generate_vless_reality_config "$name" "$port" "$uuid" "$private_key" "$public_key" "$short_id" "$sni")
    echo "$config_content" > "$CONFIG_DIR/configs/$name.json"
    
    # 更新数据库
    add_config_to_db "$name" "vless-reality" "$port" "$uuid" "$private_key|$public_key|$short_id|$sni"
    
    # 更新主配置
    update_main_config
    
    # 重启服务
    if systemctl is-active --quiet sing-box; then
        systemctl restart sing-box
    fi
    
    success "VLESS Reality 配置添加完成"
    
    # 显示配置信息
    echo ""
    highlight "=== 配置信息 ==="
    echo "名称: $name"
    echo "协议: VLESS Reality"
    echo "端口: $port"
    echo "UUID: $uuid"
    echo "SNI: $sni"
    echo "Short ID: $short_id"
    echo "Public Key: $public_key"
    echo ""
    highlight "=== 分享链接 ==="
    generate_vless_url "$name"
}

# 添加 VMess 配置
add_vmess() {
    local name=${1:-"vmess-$(date +%s)"}
    local port=${2:-$(get_random_port)}
    local domain=${3:-"example.com"}
    
    info "添加 VMess 配置: $name"
    
    # 检查端口
    if ! check_port $port; then
        error "端口 $port 已被占用"
    fi
    
    # 检查配置是否已存在
    if [[ -n $(get_config_from_db $name) ]]; then
        error "配置 $name 已存在"
    fi
    
    # 生成参数
    local uuid=$(generate_uuid)
    local path="/$(generate_password | cut -c1-8)"
    
    # 检查 TLS 证书
    if [[ ! -f $CERT_FILE ]] || [[ ! -f $KEY_FILE ]]; then
        warn "TLS 证书不存在，请手动配置证书文件:"
        echo "证书文件: $CERT_FILE"
        echo "私钥文件: $KEY_FILE"
    fi
    
    # 生成配置文件
    local config_content=$(generate_vmess_config "$name" "$port" "$uuid" "$path" "$domain")
    echo "$config_content" > "$CONFIG_DIR/configs/$name.json"
    
    # 更新数据库
    add_config_to_db "$name" "vmess" "$port" "$uuid" "$path|$domain"
    
    # 更新主配置
    update_main_config
    
    # 重启服务
    if systemctl is-active --quiet sing-box; then
        systemctl restart sing-box
    fi
    
    success "VMess 配置添加完成"
    
    # 显示配置信息
    echo ""
    highlight "=== 配置信息 ==="
    echo "名称: $name"
    echo "协议: VMess"
    echo "端口: $port"
    echo "UUID: $uuid"
    echo "路径: $path"
    echo "域名: $domain"
    echo ""
    highlight "=== 分享链接 ==="
    generate_vmess_url "$name"
}

# 添加 Hysteria2 配置
add_hysteria2() {
    local name=${1:-"hy2-$(date +%s)"}
    local port=${2:-$(get_random_port)}
    local domain=${3:-"example.com"}
    
    info "添加 Hysteria2 配置: $name"
    
    # 检查端口
    if ! check_port $port; then
        error "端口 $port 已被占用"
    fi
    
    # 检查配置是否已存在
    if [[ -n $(get_config_from_db $name) ]]; then
        error "配置 $name 已存在"
    fi
    
    # 生成参数
    local password=$(generate_password)
    
    # 检查 TLS 证书
    if [[ ! -f $CERT_FILE ]] || [[ ! -f $KEY_FILE ]]; then
        warn "TLS 证书不存在，请手动配置证书文件:"
        echo "证书文件: $CERT_FILE"
        echo "私钥文件: $KEY_FILE"
    fi
    
    # 生成配置文件
    local config_content=$(generate_hy2_config "$name" "$port" "$password" "$domain")
    echo "$config_content" > "$CONFIG_DIR/configs/$name.json"
    
    # 更新数据库
    add_config_to_db "$name" "hysteria2" "$port" "$password" "$domain"
    
    # 更新主配置
    update_main_config
    
    # 重启服务
    if systemctl is-active --quiet sing-box; then
        systemctl restart sing-box
    fi
    
    success "Hysteria2 配置添加完成"
    
    # 显示配置信息
    echo ""
    highlight "=== 配置信息 ==="
    echo "名称: $name"
    echo "协议: Hysteria2"
    echo "端口: $port"
    echo "密码: $password"
    echo "域名: $domain"
    echo ""
    highlight "=== 分享链接 ==="
    generate_hy2_url "$name"
}

# 添加 Shadowsocks 配置
add_shadowsocks() {
    local name=${1:-"ss-$(date +%s)"}
    local port=${2:-$(get_random_port)}
    local method=${3:-"chacha20-ietf-poly1305"}
    local password=${4:-$(generate_password)}
    
    info "添加 Shadowsocks 配置: $name"
    
    # 检查端口
    if ! check_port $port; then
        error "端口 $port 已被占用"
    fi
    
    # 检查配置是否已存在
    if [[ -n $(get_config_from_db $name) ]]; then
        error "配置 $name 已存在"
    fi
    
    # 生成配置文件
    local config_content=$(generate_shadowsocks_config "$name" "$port" "$method" "$password")
    echo "$config_content" > "$CONFIG_DIR/configs/$name.json"
    
    # 更新数据库
    add_config_to_db "$name" "shadowsocks" "$port" "$password" "$method"
    
    # 更新主配置
    update_main_config
    
    # 重启服务
    if systemctl is-active --quiet sing-box; then
        systemctl restart sing-box
    fi
    
    success "Shadowsocks 配置添加完成"
    
    # 显示配置信息
    echo ""
    highlight "=== 配置信息 ==="
    echo "名称: $name"
    echo "协议: Shadowsocks"
    echo "端口: $port"
    echo "加密: $method"
    echo "密码: $password"
    echo ""
    highlight "=== 分享链接 ==="
    generate_ss_url "$name"
}

# 生成 VLESS 分享链接
generate_vless_url() {
    local name=$1
    local config_info=$(get_config_from_db "$name")
    
    if [[ -z $config_info ]]; then
        error "配置 $name 不存在"
    fi
    
    local protocol=$(echo "$config_info" | cut -d'|' -f2)
    if [[ $protocol != "vless-reality" ]]; then
        error "配置 $name 不是 VLESS Reality 协议"
    fi
    
    local port=$(echo "$config_info" | cut -d'|' -f3)
    local uuid=$(echo "$config_info" | cut -d'|' -f4)
    local extra=$(echo "$config_info" | cut -d'|' -f5)
    local public_key=$(echo "$extra" | cut -d'|' -f2)
    local short_id=$(echo "$extra" | cut -d'|' -f3)
    local sni=$(echo "$extra" | cut -d'|' -f4)
    local server_ip=$(get_public_ip)
    
    local url="vless://${uuid}@${server_ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${public_key}&sid=${short_id}&type=tcp&headerType=none#${name}"
    
    echo "$url"
}

# 生成 VMess 分享链接
generate_vmess_url() {
    local name=$1
    local config_info=$(get_config_from_db "$name")
    
    if [[ -z $config_info ]]; then
        error "配置 $name 不存在"
    fi
    
    local protocol=$(echo "$config_info" | cut -d'|' -f2)
    if [[ $protocol != "vmess" ]]; then
        error "配置 $name 不是 VMess 协议"
    fi
    
    local port=$(echo "$config_info" | cut -d'|' -f3)
    local uuid=$(echo "$config_info" | cut -d'|' -f4)
    local extra=$(echo "$config_info" | cut -d'|' -f5)
    local path=$(echo "$extra" | cut -d'|' -f1)
    local domain=$(echo "$extra" | cut -d'|' -f2)
    local server_ip=$(get_public_ip)
    
    local vmess_json='{"v":"2","ps":"'$name'","add":"'$server_ip'","port":"'$port'","id":"'$uuid'","aid":"0","scy":"auto","net":"ws","type":"none","host":"'$domain'","path":"'$path'","tls":"tls","sni":"'$domain'","alpn":""}'
    local encoded=$(echo -n "$vmess_json" | base64 -w 0)
    
    echo "vmess://$encoded"
}

# 生成 Hysteria2 分享链接
generate_hy2_url() {
    local name=$1
    local config_info=$(get_config_from_db "$name")
    
    if [[ -z $config_info ]]; then
        error "配置 $name 不存在"
    fi
    
    local protocol=$(echo "$config_info" | cut -d'|' -f2)
    if [[ $protocol != "hysteria2" ]]; then
        error "配置 $name 不是 Hysteria2 协议"
    fi
    
    local port=$(echo "$config_info" | cut -d'|' -f3)
    local password=$(echo "$config_info" | cut -d'|' -f4)
    local domain=$(echo "$config_info" | cut -d'|' -f5)
    local server_ip=$(get_public_ip)
    
    local url="hysteria2://${password}@${server_ip}:${port}?sni=${domain}#${name}"
    
    echo "$url"
}

# 生成 Shadowsocks 分享链接
generate_ss_url() {
    local name=$1
    local config_info=$(get_config_from_db "$name")
    
    if [[ -z $config_info ]]; then
        error "配置 $name 不存在"
    fi
    
    local protocol=$(echo "$config_info" | cut -d'|' -f2)
    if [[ $protocol != "shadowsocks" ]]; then
        error "配置 $name 不是 Shadowsocks 协议"
    fi
    
    local port=$(echo "$config_info" | cut -d'|' -f3)
    local password=$(echo "$config_info" | cut -d'|' -f4)
    local method=$(echo "$config_info" | cut -d'|' -f5)
    local server_ip=$(get_public_ip)
    
    local auth_string="${method}:${password}"
    local encoded_auth=$(echo -n "$auth_string" | base64 -w 0)
    local url="ss://${encoded_auth}@${server_ip}:${port}#${name}"
    
    echo "$url"
}

# 交互式管理功能
interactive_list_configs() {
    clear
    print_banner
    echo -e "${GREEN}配置列表${NC}"
    print_sub_separator
    
    local configs=$(list_configs_from_db)
    if [[ -z $configs ]]; then
        warn "暂无配置"
        wait_for_input
        return
    fi
    
    echo -e "${YELLOW}当前配置：${NC}"
    echo
    printf "%-3s %-15s %-15s %-8s %-15s %-20s\n" "No" "名称" "协议" "端口" "状态" "创建时间"
    echo "$(printf '%*s' 80 '' | tr ' ' '-')"
    
    local count=1
    while IFS='|' read -r name protocol port uuid extra created; do
        local status="运行中"
        if ! systemctl is-active --quiet sing-box; then
            status="已停止"
        fi
        printf "%-3s %-15s %-15s %-8s %-15s %-20s\n" "$count" "$name" "$protocol" "$port" "$status" "$created"
        ((count++))
    done <<< "$configs"
    
    wait_for_input
}

interactive_show_config_info() {
    clear
    print_banner
    echo -e "${GREEN}配置详情${NC}"
    print_sub_separator
    
    local configs=$(list_configs_from_db)
    if [[ -z $configs ]]; then
        warn "暂无配置"
        wait_for_input
        return
    fi
    
    echo -e "${YELLOW}请选择要查看的配置：${NC}"
    echo
    
    local count=1
    local config_names=()
    while IFS='|' read -r name protocol port uuid extra created; do
        echo "  [$count] $name ($protocol)"
        config_names+=("$name")
        ((count++))
    done <<< "$configs"
    
    echo "  [0] 返回上级菜单"
    echo
    
    local choice
    while true; do
        choice=$(read_input "请选择" "0")
        if [[ $choice =~ ^[0-9]+$ ]] && [[ $choice -ge 0 ]] && [[ $choice -lt $count ]]; then
            break
        else
            warn "请输入有效的选项"
        fi
    done
    
    if [[ $choice -eq 0 ]]; then
        return
    fi
    
    local selected_name="${config_names[$((choice-1))]}"
    
    clear
    print_banner
    echo -e "${GREEN}配置详情 - $selected_name${NC}"
    print_sub_separator
    
    show_config_info "$selected_name"
    
    echo
    print_sub_separator
    echo -e "${YELLOW}分享链接：${NC}"
    case $(get_config_from_db "$selected_name" | cut -d'|' -f2) in
        "vless-reality") generate_vless_url "$selected_name" ;;
        "vmess") generate_vmess_url "$selected_name" ;;
        "hysteria2") generate_hy2_url "$selected_name" ;;
        "shadowsocks") generate_ss_url "$selected_name" ;;
    esac
    
    wait_for_input
}

interactive_delete_config() {
    clear
    print_banner
    echo -e "${GREEN}删除配置${NC}"
    print_sub_separator
    
    local configs=$(list_configs_from_db)
    if [[ -z $configs ]]; then
        warn "暂无配置"
        wait_for_input
        return
    fi
    
    echo -e "${YELLOW}请选择要删除的配置：${NC}"
    echo
    
    local count=1
    local config_names=()
    while IFS='|' read -r name protocol port uuid extra created; do
        echo "  [$count] $name ($protocol)"
        config_names+=("$name")
        ((count++))
    done <<< "$configs"
    
    echo "  [0] 返回上级菜单"
    echo
    
    local choice
    while true; do
        choice=$(read_input "请选择" "0")
        if [[ $choice =~ ^[0-9]+$ ]] && [[ $choice -ge 0 ]] && [[ $choice -lt $count ]]; then
            break
        else
            warn "请输入有效的选项"
        fi
    done
    
    if [[ $choice -eq 0 ]]; then
        return
    fi
    
    local selected_name="${config_names[$((choice-1))]}"
    
    echo
    warn "即将删除配置: $selected_name"
    if confirm "确认删除吗？此操作无法撤销"; then
        delete_config "$selected_name"
        success "配置删除成功"
    else
        info "删除操作已取消"
    fi
    
    wait_for_input
}

interactive_change_port() {
    clear
    print_banner
    echo -e "${GREEN}更换端口${NC}"
    print_sub_separator
    
    local configs=$(list_configs_from_db)
    if [[ -z $configs ]]; then
        warn "暂无配置"
        wait_for_input
        return
    fi
    
    echo -e "${YELLOW}请选择要更换端口的配置：${NC}"
    echo
    
    local count=1
    local config_names=()
    while IFS='|' read -r name protocol port uuid extra created; do
        echo "  [$count] $name ($protocol) - 当前端口: $port"
        config_names+=("$name")
        ((count++))
    done <<< "$configs"
    
    echo "  [0] 返回上级菜单"
    echo
    
    local choice
    while true; do
        choice=$(read_input "请选择" "0")
        if [[ $choice =~ ^[0-9]+$ ]] && [[ $choice -ge 0 ]] && [[ $choice -lt $count ]]; then
            break
        else
            warn "请输入有效的选项"
        fi
    done
    
    if [[ $choice -eq 0 ]]; then
        return
    fi
    
    local selected_name="${config_names[$((choice-1))]}"
    local current_port=$(get_config_from_db "$selected_name" | cut -d'|' -f3)
    
    echo
    echo "当前端口: $current_port"
    local new_port=$(read_port "请输入新端口" "$(get_random_port)")
    
    if [[ $new_port -eq $current_port ]]; then
        warn "新端口与当前端口相同"
        wait_for_input
        return
    fi
    
    if confirm "确认将端口从 $current_port 更改为 $new_port 吗？"; then
        change_port "$selected_name" "$new_port"
        success "端口更换成功"
    else
        info "端口更换已取消"
    fi
    
    wait_for_input
}

interactive_regenerate_uuid() {
    clear
    print_banner
    echo -e "${GREEN}重新生成 UUID${NC}"
    print_sub_separator
    
    local configs=$(list_configs_from_db)
    if [[ -z $configs ]]; then
        warn "暂无配置"
        wait_for_input
        return
    fi
    
    echo -e "${YELLOW}请选择要重新生成 UUID 的配置：${NC}"
    echo
    
    local count=1
    local config_names=()
    while IFS='|' read -r name protocol port uuid extra created; do
        if [[ $protocol == "vless-reality" || $protocol == "vmess" ]]; then
            echo "  [$count] $name ($protocol)"
            config_names+=("$name")
            ((count++))
        fi
    done <<< "$configs"
    
    if [[ ${#config_names[@]} -eq 0 ]]; then
        warn "没有支持 UUID 的配置"
        wait_for_input
        return
    fi
    
    echo "  [0] 返回上级菜单"
    echo
    
    local choice
    while true; do
        choice=$(read_input "请选择" "0")
        if [[ $choice =~ ^[0-9]+$ ]] && [[ $choice -ge 0 ]] && [[ $choice -lt $count ]]; then
            break
        else
            warn "请输入有效的选项"
        fi
    done
    
    if [[ $choice -eq 0 ]]; then
        return
    fi
    
    local selected_name="${config_names[$((choice-1))]}"
    local current_uuid=$(get_config_from_db "$selected_name" | cut -d'|' -f4)
    local new_uuid=$(generate_uuid)
    
    echo
    echo "当前 UUID: $current_uuid"
    echo "新 UUID: $new_uuid"
    
    if confirm "确认重新生成 UUID 吗？"; then
        regenerate_uuid "$selected_name"
        success "UUID 重新生成成功"
    else
        info "UUID 重新生成已取消"
    fi
    
    wait_for_input
}

# 交互式系统管理功能
interactive_start_service() {
    clear
    print_banner
    echo -e "${GREEN}启动 Sing-box 服务${NC}"
    print_sub_separator
    
    if systemctl is-active --quiet sing-box; then
        warn "服务已经在运行中"
        wait_for_input
        return
    fi
    
    info "正在启动 Sing-box 服务..."
    if systemctl start sing-box; then
        success "服务启动成功"
    else
        error "服务启动失败"
    fi
    
    wait_for_input
}

interactive_stop_service() {
    clear
    print_banner
    echo -e "${GREEN}停止 Sing-box 服务${NC}"
    print_sub_separator
    
    if ! systemctl is-active --quiet sing-box; then
        warn "服务未在运行"
        wait_for_input
        return
    fi
    
    if confirm "确认停止 Sing-box 服务吗？"; then
        info "正在停止服务..."
        if systemctl stop sing-box; then
            success "服务停止成功"
        else
            error "服务停止失败"
        fi
    else
        info "操作已取消"
    fi
    
    wait_for_input
}

interactive_restart_service() {
    clear
    print_banner
    echo -e "${GREEN}重启 Sing-box 服务${NC}"
    print_sub_separator
    
    info "正在重启 Sing-box 服务..."
    if systemctl restart sing-box; then
        success "服务重启成功"
    else
        error "服务重启失败"
    fi
    
    wait_for_input
}

interactive_show_status() {
    clear
    print_banner
    echo -e "${GREEN}服务状态${NC}"
    print_sub_separator
    
    if systemctl is-active --quiet sing-box; then
        success "服务正在运行"
    else
        warn "服务未运行"
    fi
    
    echo
    echo -e "${YELLOW}详细状态：${NC}"
    systemctl status sing-box --no-pager
    
    echo
    echo -e "${YELLOW}端口占用情况：${NC}"
    local configs=$(list_configs_from_db)
    if [[ -n $configs ]]; then
        while IFS='|' read -r name protocol port uuid extra created; do
            if ss -tuln | grep -q ":$port "; then
                echo "  ✓ 端口 $port ($name) - 正在监听"
            else
                echo "  ✗ 端口 $port ($name) - 未监听"
            fi
        done <<< "$configs"
    fi
    
    wait_for_input
}

interactive_show_logs() {
    clear
    print_banner
    echo -e "${GREEN}查看日志${NC}"
    print_sub_separator
    
    echo -e "${YELLOW}请选择日志查看方式：${NC}"
    echo "  [1] 查看最近日志"
    echo "  [2] 实时查看日志"
    echo "  [3] 查看错误日志"
    echo "  [0] 返回上级菜单"
    echo
    
    local choice
    while true; do
        choice=$(read_input "请选择" "1")
        case "$choice" in
            "1")
                clear
                print_banner
                echo -e "${GREEN}最近日志${NC}"
                print_sub_separator
                journalctl -u sing-box --no-pager -n 50
                wait_for_input
                break
                ;;
            "2")
                clear
                print_banner
                echo -e "${GREEN}实时日志 (按 Ctrl+C 退出)${NC}"
                print_sub_separator
                journalctl -u sing-box -f
                break
                ;;
            "3")
                clear
                print_banner
                echo -e "${GREEN}错误日志${NC}"
                print_sub_separator
                journalctl -u sing-box --no-pager -p err
                wait_for_input
                break
                ;;
            "0")
                return
                ;;
            *)
                warn "请输入有效的选项"
                ;;
        esac
    done
}

interactive_system_optimize() {
    clear
    print_banner
    echo -e "${GREEN}系统优化${NC}"
    print_sub_separator
    
    echo -e "${YELLOW}可用的优化选项：${NC}"
    echo "  [1] 启用 BBR 拥塞控制"
    echo "  [2] 优化系统参数"
    echo "  [3] 配置防火墙"
    echo "  [4] 全部优化"
    echo "  [0] 返回上级菜单"
    echo
    
    local choice
    while true; do
        choice=$(read_input "请选择" "0")
        case "$choice" in
            "1")
                info "正在启用 BBR..."
                enable_bbr
                success "BBR 优化完成"
                break
                ;;
            "2")
                info "正在优化系统参数..."
                optimize_system
                success "系统参数优化完成"
                break
                ;;
            "3")
                info "正在配置防火墙..."
                configure_firewall
                success "防火墙配置完成"
                break
                ;;
            "4")
                info "正在执行全部优化..."
                enable_bbr
                optimize_system
                configure_firewall
                success "系统优化完成"
                break
                ;;
            "0")
                return
                ;;
            *)
                warn "请输入有效的选项"
                ;;
        esac
    done
    
    wait_for_input
}

interactive_uninstall() {
    clear
    print_banner
    echo -e "${RED}卸载 Sing-box${NC}"
    print_sub_separator
    
    warn "此操作将完全卸载 Sing-box 并删除所有配置文件"
    echo
    echo -e "${YELLOW}将会删除：${NC}"
    echo "  • Sing-box 核心程序"
    echo "  • 所有配置文件"
    echo "  • 服务文件"
    echo "  • 日志文件"
    echo "  • 管理脚本"
    echo
    
    if confirm "确认卸载吗？此操作无法撤销"; then
        echo
        if confirm "再次确认卸载吗？"; then
            uninstall_singbox
        else
            info "卸载已取消"
        fi
    else
        info "卸载已取消"
    fi
    
    wait_for_input
}

# 交互式分享功能
interactive_show_all_urls() {
    clear
    print_banner
    echo -e "${GREEN}所有分享链接${NC}"
    print_sub_separator
    
    local configs=$(list_configs_from_db)
    if [[ -z $configs ]]; then
        warn "暂无配置"
        wait_for_input
        return
    fi
    
    while IFS='|' read -r name protocol port uuid extra created; do
        echo -e "${YELLOW}配置: $name ($protocol)${NC}"
        case $protocol in
            "vless-reality") generate_vless_url "$name" ;;
            "vmess") generate_vmess_url "$name" ;;
            "hysteria2") generate_hy2_url "$name" ;;
            "shadowsocks") generate_ss_url "$name" ;;
        esac
        echo
    done <<< "$configs"
    
    wait_for_input
}

interactive_show_single_url() {
    clear
    print_banner
    echo -e "${GREEN}分享链接${NC}"
    print_sub_separator
    
    local configs=$(list_configs_from_db)
    if [[ -z $configs ]]; then
        warn "暂无配置"
        wait_for_input
        return
    fi
    
    echo -e "${YELLOW}请选择配置：${NC}"
    echo
    
    local count=1
    local config_names=()
    while IFS='|' read -r name protocol port uuid extra created; do
        echo "  [$count] $name ($protocol)"
        config_names+=("$name")
        ((count++))
    done <<< "$configs"
    
    echo "  [0] 返回上级菜单"
    echo
    
    local choice
    while true; do
        choice=$(read_input "请选择" "0")
        if [[ $choice =~ ^[0-9]+$ ]] && [[ $choice -ge 0 ]] && [[ $choice -lt $count ]]; then
            break
        else
            warn "请输入有效的选项"
        fi
    done
    
    if [[ $choice -eq 0 ]]; then
        return
    fi
    
    local selected_name="${config_names[$((choice-1))]}"
    local protocol=$(get_config_from_db "$selected_name" | cut -d'|' -f2)
    
    clear
    print_banner
    echo -e "${GREEN}分享链接 - $selected_name${NC}"
    print_sub_separator
    
    case $protocol in
        "vless-reality") generate_vless_url "$selected_name" ;;
        "vmess") generate_vmess_url "$selected_name" ;;
        "hysteria2") generate_hy2_url "$selected_name" ;;
        "shadowsocks") generate_ss_url "$selected_name" ;;
    esac
    
    wait_for_input
}

interactive_generate_qr() {
    clear
    print_banner
    echo -e "${GREEN}生成二维码${NC}"
    print_sub_separator
    
    local configs=$(list_configs_from_db)
    if [[ -z $configs ]]; then
        warn "暂无配置"
        wait_for_input
        return
    fi
    
    echo -e "${YELLOW}请选择配置：${NC}"
    echo
    
    local count=1
    local config_names=()
    while IFS='|' read -r name protocol port uuid extra created; do
        echo "  [$count] $name ($protocol)"
        config_names+=("$name")
        ((count++))
    done <<< "$configs"
    
    echo "  [0] 返回上级菜单"
    echo
    
    local choice
    while true; do
        choice=$(read_input "请选择" "0")
        if [[ $choice =~ ^[0-9]+$ ]] && [[ $choice -ge 0 ]] && [[ $choice -lt $count ]]; then
            break
        else
            warn "请输入有效的选项"
        fi
    done
    
    if [[ $choice -eq 0 ]]; then
        return
    fi
    
    local selected_name="${config_names[$((choice-1))]}"
    
    clear
    print_banner
    echo -e "${GREEN}二维码 - $selected_name${NC}"
    print_sub_separator
    
    generate_qr_code "$selected_name"
    
    wait_for_input
}

interactive_export_config() {
    clear
    print_banner
    echo -e "${GREEN}导出配置${NC}"
    print_sub_separator
    
    local configs=$(list_configs_from_db)
    if [[ -z $configs ]]; then
        warn "暂无配置"
        wait_for_input
        return
    fi
    
    echo -e "${YELLOW}请选择要导出的配置：${NC}"
    echo
    
    local count=1
    local config_names=()
    while IFS='|' read -r name protocol port uuid extra created; do
        echo "  [$count] $name ($protocol)"
        config_names+=("$name")
        ((count++))
    done <<< "$configs"
    
    echo "  [0] 返回上级菜单"
    echo
    
    local choice
    while true; do
        choice=$(read_input "请选择" "0")
        if [[ $choice =~ ^[0-9]+$ ]] && [[ $choice -ge 0 ]] && [[ $choice -lt $count ]]; then
            break
        else
            warn "请输入有效的选项"
        fi
    done
    
    if [[ $choice -eq 0 ]]; then
        return
    fi
    
    local selected_name="${config_names[$((choice-1))]}"
    local export_file="/tmp/${selected_name}.json"
    
    cp "$CONFIG_DIR/configs/$selected_name.json" "$export_file"
    
    success "配置已导出到: $export_file"
    echo
    echo -e "${YELLOW}配置内容：${NC}"
    cat "$export_file"
    
    wait_for_input
}

interactive_show_system_info() {
    clear
    print_banner
    echo -e "${GREEN}系统信息${NC}"
    print_sub_separator
    
    echo -e "${YELLOW}系统信息：${NC}"
    echo "  操作系统: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
    echo "  内核版本: $(uname -r)"
    echo "  架构: $(uname -m)"
    echo "  CPU 核心: $(nproc)"
    echo "  内存: $(free -h | awk 'NR==2{print $2}')"
    echo "  磁盘: $(df -h / | awk 'NR==2{print $2}')"
    echo "  公网IP: $(get_public_ip)"
    
    echo
    echo -e "${YELLOW}Sing-box 信息：${NC}"
    if command -v /usr/local/bin/sing-box >/dev/null 2>&1; then
        echo "  版本: $(/usr/local/bin/sing-box version | head -1)"
    else
        echo "  版本: 未安装"
    fi
    
    echo "  脚本版本: $SCRIPT_VERSION"
    
    if systemctl is-active --quiet sing-box; then
        echo "  服务状态: 运行中"
    else
        echo "  服务状态: 已停止"
    fi
    
    echo
    echo -e "${YELLOW}配置统计：${NC}"
    local configs=$(list_configs_from_db)
    if [[ -n $configs ]]; then
        local total_configs=$(echo "$configs" | wc -l)
        local vless_count=$(echo "$configs" | grep "vless-reality" | wc -l)
        local vmess_count=$(echo "$configs" | grep "vmess" | wc -l)
        local hy2_count=$(echo "$configs" | grep "hysteria2" | wc -l)
        local ss_count=$(echo "$configs" | grep "shadowsocks" | wc -l)
        
        echo "  总配置数: $total_configs"
        echo "  VLESS Reality: $vless_count"
        echo "  VMess: $vmess_count"
        echo "  Hysteria2: $hy2_count"
        echo "  Shadowsocks: $ss_count"
    else
        echo "  总配置数: 0"
    fi
    
    echo
    echo -e "${YELLOW}网络优化：${NC}"
    if sysctl net.ipv4.tcp_congestion_control | grep -q bbr; then
        echo "  BBR: 已启用"
    else
        echo "  BBR: 未启用"
    fi
    
    wait_for_input
}

# 系统优化函数
enable_bbr() {
    info "启用 BBR 拥塞控制算法..."
    
    # 检查内核版本
    local kernel_version=$(uname -r | cut -d. -f1,2)
    if [[ $(echo "$kernel_version >= 4.9" | bc -l) -eq 0 ]]; then
        warn "内核版本过低，BBR 需要 4.9 或更高版本"
        return 1
    fi
    
    # 启用 BBR
    echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
    
    # 应用设置
    sysctl -p
    
    # 验证 BBR 是否启用
    if sysctl net.ipv4.tcp_congestion_control | grep -q bbr; then
        success "BBR 已成功启用"
    else
        error "BBR 启用失败"
    fi
}

optimize_system() {
    info "优化系统参数..."
    
    # 备份原始配置
    cp /etc/sysctl.conf /etc/sysctl.conf.bak
    
    # 网络优化参数
    cat >> /etc/sysctl.conf << 'EOF'

# Sing-box 网络优化参数
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 4096
net.core.somaxconn = 4096
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_rmem = 4096 65536 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fastopen = 3
net.core.netdev_budget = 50000
net.core.netdev_max_backlog = 4096
EOF
    
    # 应用设置
    sysctl -p
    
    success "系统参数优化完成"
}

configure_firewall() {
    info "配置防火墙..."
    
    # 检查防火墙状态
    if command -v ufw >/dev/null 2>&1; then
        # Ubuntu/Debian 系统使用 ufw
        ufw --force enable
        
        # 开放必要端口
        local configs=$(list_configs_from_db)
        if [[ -n $configs ]]; then
            while IFS='|' read -r name protocol port uuid extra created; do
                ufw allow $port
                info "已开放端口: $port ($name)"
            done <<< "$configs"
        fi
        
        # 开放 SSH 端口
        ufw allow ssh
        
        success "UFW 防火墙配置完成"
        
    elif command -v firewall-cmd >/dev/null 2>&1; then
        # CentOS/RHEL 系统使用 firewalld
        systemctl enable firewalld
        systemctl start firewalld
        
        # 开放必要端口
        local configs=$(list_configs_from_db)
        if [[ -n $configs ]]; then
            while IFS='|' read -r name protocol port uuid extra created; do
                firewall-cmd --permanent --add-port=$port/tcp
                info "已开放端口: $port ($name)"
            done <<< "$configs"
        fi
        
        # 重新加载防火墙规则
        firewall-cmd --reload
        
        success "Firewalld 防火墙配置完成"
        
    else
        warn "未检测到支持的防火墙工具"
    fi
}

# 列出所有配置
list_configs() {
    info "配置列表:"
    echo ""
    
    local configs=$(list_configs_from_db)
    if [[ -z $configs ]]; then
        warn "暂无配置"
        return
    fi
    
    printf "%-15s %-15s %-8s %-36s %-20s\n" "名称" "协议" "端口" "UUID/密码" "创建时间"
    echo "$(printf '%*s' 100 '' | tr ' ' '-')"
    
    while IFS='|' read -r name protocol port uuid extra created; do
        printf "%-15s %-15s %-8s %-36s %-20s\n" "$name" "$protocol" "$port" "${uuid:0:8}..." "$created"
    done <<< "$configs"
}

# 显示配置详情
show_config_info() {
    local name=$1
    if [[ -z $name ]]; then
        error "请指定配置名称"
    fi
    
    local config_info=$(get_config_from_db "$name")
    if [[ -z $config_info ]]; then
        error "配置 $name 不存在"
    fi
    
    local protocol=$(echo "$config_info" | cut -d'|' -f2)
    local port=$(echo "$config_info" | cut -d'|' -f3)
    local uuid=$(echo "$config_info" | cut -d'|' -f4)
    local extra=$(echo "$config_info" | cut -d'|' -f5)
    local created=$(echo "$config_info" | cut -d'|' -f6)
    
    highlight "=== 配置详情: $name ==="
    echo "协议: $protocol"
    echo "端口: $port"
    echo "创建时间: $created"
    
    case $protocol in
        "vless-reality")
            local private_key=$(echo "$extra" | cut -d'|' -f1)
            local public_key=$(echo "$extra" | cut -d'|' -f2)
            local short_id=$(echo "$extra" | cut -d'|' -f3)
            local sni=$(echo "$extra" | cut -d'|' -f4)
            echo "UUID: $uuid"
            echo "SNI: $sni"
            echo "Short ID: $short_id"
            echo "Public Key: $public_key"
            echo "Private Key: $private_key"
            ;;
        "vmess")
            local path=$(echo "$extra" | cut -d'|' -f1)
            local domain=$(echo "$extra" | cut -d'|' -f2)
            echo "UUID: $uuid"
            echo "路径: $path"
            echo "域名: $domain"
            ;;
        "hysteria2")
            local domain=$extra
            echo "密码: $uuid"
            echo "域名: $domain"
            ;;
    esac
    
    echo ""
    highlight "=== 分享链接 ==="
    case $protocol in
        "vless-reality")
            generate_vless_url "$name"
            ;;
        "vmess")
            generate_vmess_url "$name"
            ;;
        "hysteria2")
            generate_hy2_url "$name"
            ;;
    esac
}

# 删除配置
delete_config() {
    local name=$1
    if [[ -z $name ]]; then
        error "请指定配置名称"
    fi
    
    local config_info=$(get_config_from_db "$name")
    if [[ -z $config_info ]]; then
        error "配置 $name 不存在"
    fi
    
    # 确认删除
    read -p "确认删除配置 $name? (y/N): " confirm
    if [[ $confirm != "y" ]] && [[ $confirm != "Y" ]]; then
        info "取消删除"
        return
    fi
    
    # 删除配置文件
    rm -f "$CONFIG_DIR/configs/$name.json"
    
    # 从数据库删除
    delete_config_from_db "$name"
    
    # 更新主配置
    update_main_config
    
    # 重启服务
    if systemctl is-active --quiet sing-box; then
        systemctl restart sing-box
    fi
    
    success "配置 $name 已删除"
}

# 更换端口
change_port() {
    local name=$1
    local new_port=$2
    
    if [[ -z $name ]] || [[ -z $new_port ]]; then
        error "请指定配置名称和新端口"
    fi
    
    local config_info=$(get_config_from_db "$name")
    if [[ -z $config_info ]]; then
        error "配置 $name 不存在"
    fi
    
    # 检查新端口
    if ! check_port $new_port; then
        error "端口 $new_port 已被占用"
    fi
    
    # 更新配置文件
    if [[ -f "$CONFIG_DIR/configs/$name.json" ]]; then
        sed -i "s/\"listen_port\": [0-9]*/\"listen_port\": $new_port/" "$CONFIG_DIR/configs/$name.json"
    fi
    
    # 更新数据库
    local protocol=$(echo "$config_info" | cut -d'|' -f2)
    local uuid=$(echo "$config_info" | cut -d'|' -f4)
    local extra=$(echo "$config_info" | cut -d'|' -f5)
    
    delete_config_from_db "$name"
    add_config_to_db "$name" "$protocol" "$new_port" "$uuid" "$extra"
    
    # 更新主配置
    update_main_config
    
    # 重启服务
    if systemctl is-active --quiet sing-box; then
        systemctl restart sing-box
    fi
    
    success "配置 $name 端口已更换为 $new_port"
}

# 生成二维码
generate_qr_code() {
    local name=$1
    if [[ -z $name ]]; then
        error "请指定配置名称"
    fi
    
    local config_info=$(get_config_from_db "$name")
    if [[ -z $config_info ]]; then
        error "配置 $name 不存在"
    fi
    
    local protocol=$(echo "$config_info" | cut -d'|' -f2)
    local url
    
    case $protocol in
        "vless-reality")
            url=$(generate_vless_url "$name")
            ;;
        "vmess")
            url=$(generate_vmess_url "$name")
            ;;
        "hysteria2")
            url=$(generate_hy2_url "$name")
            ;;
        *)
            error "不支持的协议: $protocol"
            ;;
    esac
    
    if command -v qrencode >/dev/null 2>&1; then
        echo "$url" | qrencode -t ansiutf8
    else
        warn "qrencode 未安装，无法生成二维码"
        echo "分享链接: $url"
    fi
}

# 重新生成 UUID
regenerate_uuid() {
    local name=$1
    if [[ -z $name ]]; then
        error "请指定配置名称"
    fi
    
    local config_info=$(get_config_from_db "$name")
    if [[ -z $config_info ]]; then
        error "配置 $name 不存在"
    fi
    
    local protocol=$(echo "$config_info" | cut -d'|' -f2)
    if [[ $protocol != "vless-reality" && $protocol != "vmess" ]]; then
        error "配置 $name 不支持 UUID 重新生成"
    fi
    
    local port=$(echo "$config_info" | cut -d'|' -f3)
    local extra=$(echo "$config_info" | cut -d'|' -f5)
    local new_uuid=$(generate_uuid)
    
    info "重新生成 UUID: $name"
    
    # 更新数据库
    update_config_uuid_in_db "$name" "$new_uuid"
    
    # 重新生成配置文件
    case $protocol in
        "vless-reality")
            local private_key=$(echo "$extra" | cut -d'|' -f1)
            local public_key=$(echo "$extra" | cut -d'|' -f2)
            local short_id=$(echo "$extra" | cut -d'|' -f3)
            local sni=$(echo "$extra" | cut -d'|' -f4)
            local config_content=$(generate_vless_reality_config "$name" "$port" "$new_uuid" "$private_key" "$public_key" "$short_id" "$sni")
            ;;
        "vmess")
            local domain=$(echo "$extra" | cut -d'|' -f1)
            local path=$(echo "$extra" | cut -d'|' -f2)
            local config_content=$(generate_vmess_config "$name" "$port" "$new_uuid" "$path" "$domain")
            ;;
    esac
    
    echo "$config_content" > "$CONFIG_DIR/configs/$name.json"
    
    # 更新主配置
    update_main_config
    
    # 重启服务
    if systemctl is-active --quiet sing-box; then
        systemctl restart sing-box
    fi
    
    success "UUID 重新生成完成"
    echo "新 UUID: $new_uuid"
}

# 卸载脚本
uninstall_singbox() {
    warn "即将卸载 sing-box，这将删除所有配置和数据"
    read -p "确认卸载? (y/N): " confirm
    if [[ $confirm != "y" ]] && [[ $confirm != "Y" ]]; then
        info "取消卸载"
        return
    fi
    
    info "停止服务..."
    systemctl stop sing-box 2>/dev/null || true
    systemctl disable sing-box 2>/dev/null || true
    
    info "删除文件..."
    rm -rf "$CONFIG_DIR"
    rm -rf "$DATA_DIR"
    rm -rf "$LOG_DIR"
    rm -f "/etc/systemd/system/sing-box.service"
    rm -f "/usr/local/bin/sing-box"
    rm -f "/usr/local/bin/sb"
    
    systemctl daemon-reload
    
    success "sing-box 已完全卸载"
}

# 显示帮助信息
show_help() {
    echo "Sing-box 管理脚本 $SCRIPT_VERSION"
    echo "使用方法: sing-box [命令] [参数]"
    echo ""
    echo "配置管理:"
    echo "  add vless [name] [port] [sni]     添加 VLESS Reality 配置"
    echo "  add vmess [name] [port] [domain]  添加 VMess 配置"
    echo "  add hy2 [name] [port] [domain]    添加 Hysteria2 配置"
    echo "  list                              列出所有配置"
    echo "  info <name>                       查看配置详情"
    echo "  del <name>                        删除配置"
    echo "  url <name>                        获取分享链接"
    echo "  qr <name>                         生成二维码"
    echo "  port <name> <port>                更换端口"
    echo ""
    echo "系统管理:"
    echo "  start                             启动服务"
    echo "  stop                              停止服务"
    echo "  restart                           重启服务"
    echo "  status                            查看状态"
    echo "  log                               查看日志"
    echo "  uninstall                         卸载脚本"
    echo ""
    echo "其他:"
    echo "  version                           显示版本"
    echo "  help                              显示帮助"
    echo ""
    echo "示例:"
    echo "  sing-box add vless                添加默认 VLESS Reality 配置"
    echo "  sing-box add vmess my-vmess 8080  添加指定端口的 VMess 配置"
    echo "  sing-box info vless-001           查看配置详情"
    echo "  sing-box url vless-001            获取分享链接"
}

# 交互式主菜单处理
interactive_main() {
    while true; do
        show_main_menu
        local choice
        choice=$(read_input "请选择操作" "0")
        
        # 调试信息（可选）
        # echo "DEBUG: choice='$choice', length=${#choice}"
        
        case "$choice" in
            "1")
                # 添加配置
                while true; do
                    show_add_menu
                    local add_choice
                    add_choice=$(read_input "请选择协议" "0")
                    
                    case "$add_choice" in
                        "1") interactive_add_vless_reality ;;
                        "2") interactive_add_vmess ;;
                        "3") interactive_add_hysteria2 ;;
                        "4") interactive_add_shadowsocks ;;
                        "0") break ;;
                        *) warn "请输入有效的选项"; sleep 1 ;;
                    esac
                done
                ;;
            "2")
                # 管理配置
                while true; do
                    show_manage_menu
                    local manage_choice
                    manage_choice=$(read_input "请选择操作" "0")
                    
                    case "$manage_choice" in
                        "1") interactive_list_configs ;;
                        "2") interactive_show_config_info ;;
                        "3") interactive_delete_config ;;
                        "4") interactive_change_port ;;
                        "5") interactive_regenerate_uuid ;;
                        "0") break ;;
                        *) warn "请输入有效的选项"; sleep 1 ;;
                    esac
                done
                ;;
            "3")
                # 系统管理
                while true; do
                    show_system_menu
                    local system_choice
                    system_choice=$(read_input "请选择操作" "0")
                    
                    case "$system_choice" in
                        "1") interactive_start_service ;;
                        "2") interactive_stop_service ;;
                        "3") interactive_restart_service ;;
                        "4") interactive_show_status ;;
                        "5") interactive_show_logs ;;
                        "6") interactive_system_optimize ;;
                        "7") interactive_uninstall ;;
                        "0") break ;;
                        *) warn "请输入有效的选项"; sleep 1 ;;
                    esac
                done
                ;;
            "4")
                # 分享链接
                while true; do
                    show_share_menu
                    local share_choice
                    share_choice=$(read_input "请选择操作" "0")
                    
                    case "$share_choice" in
                        "1") interactive_show_all_urls ;;
                        "2") interactive_show_single_url ;;
                        "3") interactive_generate_qr ;;
                        "4") interactive_export_config ;;
                        "0") break ;;
                        *) warn "请输入有效的选项"; sleep 1 ;;
                    esac
                done
                ;;
            "5")
                # 系统信息
                interactive_show_system_info
                ;;
            "6")
                # 更新脚本
                clear
                print_banner
                echo -e "${GREEN}更新脚本${NC}"
                print_sub_separator
                info "正在检查更新..."
                # 这里可以添加更新逻辑
                warn "更新功能尚未实现"
                wait_for_input
                ;;
            "0")
                # 退出
                clear
                print_banner
                success "感谢使用 Sing-box 管理脚本！"
                exit 0
                ;;
            *)
                warn "请输入有效的选项 (0-6)"
                sleep 1
                ;;
        esac
    done
}

# 主函数
main() {
    # 初始化数据库
    init_db
    
    # 如果没有参数，启动交互式菜单
    if [[ $# -eq 0 ]]; then
        interactive_main
        return
    fi
    
    case "$1" in
        "add")
            case "$2" in
                "vless")
                    add_vless_reality "$3" "$4" "$5"
                    ;;
                "vmess")
                    add_vmess "$3" "$4" "$5"
                    ;;
                "hy2"|"hysteria2")
                    add_hysteria2 "$3" "$4" "$5"
                    ;;
                *)
                    error "不支持的协议: $2\n使用 'sing-box help' 查看帮助"
                    ;;
            esac
            ;;
        "list")
            list_configs
            ;;
        "info")
            show_config_info "$2"
            ;;
        "del"|"delete")
            delete_config "$2"
            ;;
        "url")
            local name=$2
            if [[ -z $name ]]; then
                error "请指定配置名称"
            fi
            local config_info=$(get_config_from_db "$name")
            if [[ -z $config_info ]]; then
                error "配置 $name 不存在"
            fi
            local protocol=$(echo "$config_info" | cut -d'|' -f2)
            case $protocol in
                "vless-reality")
                    generate_vless_url "$name"
                    ;;
                "vmess")
                    generate_vmess_url "$name"
                    ;;
                "hysteria2")
                    generate_hy2_url "$name"
                    ;;
            esac
            ;;
        "qr")
            generate_qr_code "$2"
            ;;
        "port")
            change_port "$2" "$3"
            ;;
        "start")
            systemctl start sing-box
            success "服务已启动"
            ;;
        "stop")
            systemctl stop sing-box
            success "服务已停止"
            ;;
        "restart")
            systemctl restart sing-box
            success "服务已重启"
            ;;
        "status")
            systemctl status sing-box
            ;;
        "log")
            journalctl -u sing-box -f
            ;;
        "version")
            echo "Sing-box 管理脚本 $SCRIPT_VERSION"
            if command -v /usr/local/bin/sing-box >/dev/null 2>&1; then
                /usr/local/bin/sing-box version
            fi
            ;;
        "uninstall")
            uninstall_singbox
            ;;
        "help"|"")
            show_help
            ;;
        *)
            error "未知命令: $1\n使用 'sing-box help' 查看帮助"
            ;;
    esac
}

# 执行主函数
main "$@"