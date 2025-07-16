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

# 主函数
main() {
    # 初始化数据库
    init_db
    
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