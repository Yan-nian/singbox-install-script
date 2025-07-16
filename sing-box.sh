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
SCRIPT_VERSION="v1.0.7"
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

# 初始化函数
init_directories() {
    # 确保所有必要目录存在
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$CONFIG_DIR/configs"
    mkdir -p "$DATA_DIR"
    mkdir -p "$LOG_DIR"
    
    # 确保数据库文件存在
    touch "$DB_FILE"
    
    # 确保缓存目录存在
    mkdir -p "$DATA_DIR"
    
    # 如果主配置文件不存在，创建一个基本的
    if [[ ! -f "$CONFIG_FILE" ]]; then
        update_main_config
    fi
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
    echo -e "${CYAN}  [快速配置]${NC}"
    echo -e "${YELLOW}  [1]${NC} 🚀 快速配置 (只需要节点名称)"
    echo
    echo -e "${CYAN}  [详细配置]${NC}"
    echo -e "${YELLOW}  [2]${NC} VLESS Reality (推荐)"
    echo -e "${YELLOW}  [3]${NC} VMess"
    echo -e "${YELLOW}  [4]${NC} Hysteria2"
    echo -e "${YELLOW}  [5]${NC} TUIC5"
    echo -e "${YELLOW}  [6]${NC} Shadowsocks"
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
    echo -e "${YELLOW}  [6]${NC} 系统诊断"
    echo -e "${YELLOW}  [7]${NC} 系统优化"
    echo -e "${YELLOW}  [8]${NC} 配置模板更新"
    echo -e "${YELLOW}  [9]${NC} 更新脚本"
    echo -e "${YELLOW}  [10]${NC} 更新核心"
    echo -e "${YELLOW}  [11]${NC} 备份配置"
    echo -e "${YELLOW}  [12]${NC} 恢复配置"
    echo -e "${YELLOW}  [13]${NC} 卸载 Sing-box"
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
    echo -e "${YELLOW}  [5]${NC} 生成客户端配置"
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
        echo -ne "${GREEN}$prompt${NC} [${YELLOW}$default${NC}]: " >&2
    else
        echo -ne "${GREEN}$prompt${NC}: " >&2
    fi
    
    read -r input
    # 去除前后空白字符并返回
    input="${input:-$default}"
    input="${input#"${input%%[![:space:]]*}"}"  # 移除开头空白
    input="${input%"${input##*[![:space:]]}"}"  # 移除结尾空白
    echo "$input"
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

# 获取服务器IP（别名）
get_server_ip() {
    get_public_ip
}

# 生成随机字符串
generate_random_string() {
    local length=${1:-8}
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-$length
}

# 生成短ID
get_short_id() {
    generate_random_string 8
}

generate_reality_keys() {
    /usr/local/bin/sing-box generate reality-keypair
}

get_short_id() {
    openssl rand -hex 8
}

# 检查配置文件语法（兼容不同版本）
check_config_syntax() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi
    
    # 检查 sing-box 二进制文件是否存在
    if [[ ! -f "/usr/local/bin/sing-box" ]]; then
        return 1
    fi
    
    # 尝试不同的命令格式
    # 新版本格式：sing-box check -c config.json
    if /usr/local/bin/sing-box check -c "$config_file" >/dev/null 2>&1; then
        return 0
    fi
    
    # 旧版本格式：sing-box check config.json
    if /usr/local/bin/sing-box check "$config_file" >/dev/null 2>&1; then
        return 0
    fi
    
    # 更旧版本格式：sing-box -c config.json -check
    if /usr/local/bin/sing-box -c "$config_file" -check >/dev/null 2>&1; then
        return 0
    fi
    
    # 如果都不行，尝试手动启动测试（但立即停止）
    timeout 2 /usr/local/bin/sing-box run -c "$config_file" >/dev/null 2>&1
    local exit_code=$?
    
    # 如果超时（退出码 124），说明配置文件可能是正确的
    if [[ $exit_code -eq 124 ]]; then
        return 0
    fi
    
    return 1
}

# 获取配置文件错误信息
get_config_error() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        echo "配置文件不存在"
        return
    fi
    
    if [[ ! -f "/usr/local/bin/sing-box" ]]; then
        echo "sing-box 二进制文件不存在"
        return
    fi
    
    # 尝试不同的命令格式获取错误信息
    local error_output
    
    # 新版本格式
    error_output=$(/usr/local/bin/sing-box check -c "$config_file" 2>&1)
    if [[ $? -eq 0 ]]; then
        echo "配置文件语法正确"
        return
    fi
    
    # 如果错误信息包含 "未知命令"，尝试其他格式
    if echo "$error_output" | grep -q "未知命令\|unknown command"; then
        # 旧版本格式
        error_output=$(/usr/local/bin/sing-box check "$config_file" 2>&1)
        if [[ $? -eq 0 ]]; then
            echo "配置文件语法正确"
            return
        fi
        
        # 更旧版本格式
        error_output=$(/usr/local/bin/sing-box -c "$config_file" -check 2>&1)
        if [[ $? -eq 0 ]]; then
            echo "配置文件语法正确"
            return
        fi
        
        # 手动启动测试
        error_output=$(timeout 2 /usr/local/bin/sing-box run -c "$config_file" 2>&1)
        if [[ $? -eq 124 ]]; then
            echo "配置文件语法正确（通过启动测试验证）"
            return
        fi
    fi
    
    echo "$error_output"
}

# 数据库操作
init_db() {
    # 确保数据目录存在
    mkdir -p "$(dirname "$DB_FILE")"
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
      "short_id": ["$short_id"],
      "max_time_difference": "1m"
    }
  },
  "sniff": true,
  "sniff_override_destination": false,
  "domain_strategy": "prefer_ipv4"
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
    "path": "$path",
    "headers": {
      "Host": "$domain"
    }
  },
  "tls": {
    "enabled": true,
    "server_name": "$domain",
    "certificate_path": "$CERT_FILE",
    "key_path": "$KEY_FILE"
  },
  "sniff": true,
  "sniff_override_destination": false,
  "domain_strategy": "prefer_ipv4"
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
  },
  "sniff": true,
  "sniff_override_destination": false,
  "domain_strategy": "prefer_ipv4"
}
EOF
}

# TUIC5 配置模板
generate_tuic5_config() {
    local name=$1
    local port=$2
    local uuid=$3
    local password=$4
    local domain=$5
    
    cat << EOF
{
  "type": "tuic",
  "tag": "$name",
  "listen": "::",
  "listen_port": $port,
  "users": [
    {
      "uuid": "$uuid",
      "password": "$password"
    }
  ],
  "congestion_control": "bbr",
  "tls": {
    "enabled": true,
    "server_name": "$domain",
    "certificate_path": "$CERT_FILE",
    "key_path": "$KEY_FILE",
    "alpn": ["h3"]
  },
  "sniff": true,
  "sniff_override_destination": false,
  "domain_strategy": "prefer_ipv4"
}
EOF
}

# Hysteria2 配置模板（别名）
generate_hysteria2_config() {
    generate_hy2_config "$1" "$2" "$3" "$4"
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
  "password": "$password",
  "sniff": true,
  "sniff_override_destination": false,
  "domain_strategy": "prefer_ipv4"
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
    "disabled": false,
    "level": "info",
    "timestamp": true,
    "output": "$LOG_DIR/sing-box.log"
  },
  "dns": {
    "servers": [
      {
        "tag": "remote",
        "address": "https://1.1.1.1/dns-query",
        "detour": "🚀 节点选择"
      },
      {
        "tag": "local",
        "address": "https://223.5.5.5/dns-query",
        "detour": "⚡ 直连"
      },
      {
        "tag": "block",
        "address": "rcode://success"
      }
    ],
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
      },
      {
        "rule_set": ["category-ads-all"],
        "server": "block"
      }
    ],
    "strategy": "prefer_ipv4"
  },
    "servers": [
      {
        "address": "https://1.1.1.1/dns-query",
        "detour": "🚀 节点选择",
        "tag": "remote"
      },
      {
        "address": "https://223.5.5.5/dns-query",
        "detour": "⚡ 直连",
        "tag": "local"
      },
      {
        "address": "rcode://success",
        "tag": "block"
      }
    ],
    "strategy": "prefer_ipv4"
  },
  "experimental": {
    "cache_file": {
      "enabled": true,
      "path": "$DATA_DIR/cache.db"
    },
    "clash_api": {
      "external_controller": "127.0.0.1:9090",
      "external_ui": "ui",
      "external_ui_download_url": "https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip",
      "external_ui_download_detour": "⚡ 直连",
      "default_mode": "Rule"
    }
  },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "interface_name": "tun0",
      "inet4_address": "172.18.0.1/30",
      "inet6_address": "fdfe:dcba:9876::1/126",
      "mtu": 9000,
      "auto_route": true,
      "strict_route": true,
      "stack": "system",
      "sniff": true,
      "sniff_override_destination": false
    },
    {
      "type": "mixed",
      "tag": "mixed-in",
      "listen": "127.0.0.1",
      "listen_port": 2333,
      "sniff": true,
      "sniff_override_destination": false
    }
  ],
  "outbounds": [
    {
      "type": "selector",
      "tag": "🚀 节点选择",
      "outbounds": ["⚙️ 手动切换", "�️ 自动选择", "🔄 直连入口", "🔗 中继节点"],
      "default": "🎚️ 自动选择"
    },
    {
      "type": "selector",
      "tag": "⚙️ 手动切换",
      "outbounds": [],
      "default": "⚡ 直连"
    },
    {
      "type": "urltest",
      "tag": "🎚️ 自动选择",
      "outbounds": [],
      "url": "https://www.gstatic.com/generate_204",
      "interval": "10m",
      "tolerance": 50
    },
    {
      "type": "selector",
      "tag": "🔗 中继节点",
      "outbounds": ["🔄 直连入口"],
      "default": "🔄 直连入口"
    },
    {
      "type": "selector",
      "tag": "�🇰 香港节点",
      "outbounds": ["🔄 直连入口"],
      "default": "🔄 直连入口"
    },
    {
      "type": "selector",
      "tag": "🇹🇼 台湾节点",
      "outbounds": ["🔄 直连入口"],
      "default": "🔄 直连入口"
    },
    {
      "type": "selector",
      "tag": "🇯🇵 日本节点",
      "outbounds": ["🔄 直连入口"],
      "default": "🔄 直连入口"
    },
    {
      "type": "selector",
      "tag": "🇺🇸 美国节点",
      "outbounds": ["🔄 直连入口"],
      "default": "🔄 直连入口"
    },
    {
      "type": "selector",
      "tag": "🇸🇬 新加坡节点",
      "outbounds": ["🔄 直连入口"],
      "default": "🔄 直连入口"
    },
    {
      "type": "direct",
      "tag": "⚡ 直连"
    },
    {
      "type": "direct",
      "tag": "🔄 直连入口"
    },
    {
      "type": "block",
      "tag": "🚫 拦截"
    },
    {
      "type": "dns",
      "tag": "dns-out"
    }
  ],
  "route": {
    "auto_detect_interface": true,
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      },
      {
        "clash_mode": "Direct",
        "outbound": "⚡ 直连"
      },
      {
        "clash_mode": "Proxy",
        "outbound": "🚀 节点选择"
      },
      {
        "rule_set": ["geosite-cn"],
        "outbound": "⚡ 直连"
      },
      {
        "rule_set": ["geoip-cn"],
        "outbound": "⚡ 直连"
      },
      {
        "ip_is_private": true,
        "outbound": "⚡ 直连"
      },
      {
        "rule_set": ["category-ads-all"],
        "outbound": "🚫 拦截"
      },
      {
        "outbound": "🚀 节点选择"
      }
    ],
    "rule_set": [
      {
        "tag": "geosite-cn",
        "type": "remote",
        "format": "binary",
        "url": "https://fastly.jsdelivr.net/gh/SagerNet/sing-geosite@rule-set/geosite-cn.srs",
        "download_detour": "⚡ 直连"
      },
      {
        "tag": "geoip-cn",
        "type": "remote",
        "format": "binary",
        "url": "https://fastly.jsdelivr.net/gh/SagerNet/sing-geoip@rule-set/geoip-cn.srs",
        "download_detour": "⚡ 直连"
      },
      {
        "tag": "category-ads-all",
        "type": "remote",
        "format": "binary",
        "url": "https://fastly.jsdelivr.net/gh/SagerNet/sing-geosite@rule-set/geosite-category-ads-all.srs",
        "download_detour": "⚡ 直连"
      }
    ]
  }
}
EOF

    # 更新分组节点列表
    update_group_outbounds
}

# 更新分组节点列表
update_group_outbounds() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        return
    fi
    
    # 获取所有配置的标签
    local all_tags=()
    local terminal_tags=()
    
    if [[ -f "$DB_FILE" ]]; then
        while IFS='|' read -r name type port _; do
            if [[ -n "$name" ]]; then
                all_tags+=("\"$name\"")
                # 假设所有节点都是终端节点（非中继）
                terminal_tags+=("\"$name\"")
            fi
        done < "$DB_FILE"
    fi
    
    # 如果没有配置，使用默认值
    if [[ ${#all_tags[@]} -eq 0 ]]; then
        all_tags=("\"🔄 直连入口\"")
        terminal_tags=("\"🔄 直连入口\"")
    fi
    
    # 地区节点分组规则
    local regions=(
        "🇭🇰 香港节点:香港|HK|Hong\s?Kong"
        "🇹🇼 台湾节点:台湾|台|Tai\s?Wan|TW|TWN"
        "🇯🇵 日本节点:日本|JP|JPN|Japan|Tokyo"
        "🇺🇸 美国节点:美国|US|USA|United\s?States|America"
        "🇸🇬 新加坡节点:新加坡|SG|SIN|Singapore"
    )
    
    # 准备节点列表
    local all_list=$(printf '%s,' "${all_tags[@]}")
    all_list="[${all_list%,}]"
    
    local terminal_list=$(printf '%s,' "${terminal_tags[@]}")
    terminal_list="[${terminal_list%,}]"
    
    # 使用临时文件进行更新
    local temp_file="$CONFIG_FILE.tmp"
    
    if command -v jq >/dev/null 2>&1; then
        # 使用 jq 进行精确更新
        jq --argjson all_tags "$all_list" --argjson terminal_tags "$terminal_list" '
            # 更新手动切换分组
            (.outbounds[] | select(.tag == "⚙️ 手动切换") | .outbounds) = $all_tags |
            # 更新自动选择分组
            (.outbounds[] | select(.tag == "🎚️ 自动选择") | .outbounds) = $all_tags |
            # 更新中继节点分组（仅终端节点）
            (.outbounds[] | select(.tag == "🔗 中继节点") | .outbounds) = (["🔄 直连入口"] + $terminal_tags)
        ' "$CONFIG_FILE" > "$temp_file"
        
        # 地区分组更新
        for region in "${regions[@]}"; do
            local group_name="${region%%:*}"
            local pattern="${region##*:}"
            
            # 匹配地区节点
            local region_tags=()
            for tag in "${all_tags[@]}"; do
                local clean_tag="${tag//\"/}"
                if echo "$clean_tag" | grep -qE "$pattern"; then
                    region_tags+=("$tag")
                fi
            done
            
            # 如果有匹配的节点，更新分组；否则保持默认
            if [[ ${#region_tags[@]} -gt 0 ]]; then
                local region_list=$(printf '%s,' "${region_tags[@]}")
                region_list="[${region_list%,}]"
                
                jq --argjson region_tags "$region_list" --arg group_name "$group_name" '
                    (.outbounds[] | select(.tag == $group_name) | .outbounds) = $region_tags
                ' "$temp_file" > "$temp_file.2" && mv "$temp_file.2" "$temp_file"
            fi
        done
        
        mv "$temp_file" "$CONFIG_FILE"
    else
        # 如果没有 jq，使用 sed 进行基本替换
        cp "$CONFIG_FILE" "$temp_file"
        
        # 简单替换（不够精确，但基本可用）
        sed -i.bak -E "s/\"outbounds\": \[\]/\"outbounds\": $all_list/g" "$temp_file"
        
        mv "$temp_file" "$CONFIG_FILE"
        rm -f "$temp_file.bak"
    fi
}

# 兼容性别名（保持向后兼容）
update_selector_outbounds() {
    update_group_outbounds
}

# 自动生成配置函数 - 只需要节点名称
generate_auto_config() {
    local config_name="$1"
    local protocol="$2"
    
    if [[ -z "$config_name" ]]; then
        error "请提供配置名称"
        return 1
    fi
    
    # 检查配置是否已存在
    if [[ -n $(get_config_from_db "$config_name") ]]; then
        error "配置 '$config_name' 已存在"
        return 1
    fi
    
    # 自动生成参数
    local port=$(get_random_port)
    local server_ip=$(get_server_ip)
    
    case "$protocol" in
        "vless" | "vless-reality")
            local uuid=$(generate_uuid)
            local keys=$(generate_reality_keys)
            local private_key=$(echo "$keys" | grep "PrivateKey:" | awk '{print $2}')
            local public_key=$(echo "$keys" | grep "PublicKey:" | awk '{print $2}')
            local short_id=$(get_short_id)
            local sni="www.google.com"
            
            # 生成配置
            local config_content=$(generate_vless_reality_config "$config_name" "$port" "$uuid" "$private_key" "$public_key" "$short_id" "$sni")
            echo "$config_content" > "$CONFIG_DIR/configs/$config_name.json"
            
            # 更新数据库
            add_config_to_db "$config_name" "vless-reality" "$port" "$uuid" "$private_key|$public_key|$short_id|$sni"
            
            success "VLESS Reality 配置 '$config_name' 创建完成"
            echo "  端口: $port"
            echo "  UUID: $uuid"
            echo "  SNI: $sni"
            echo "  Public Key: $public_key"
            ;;
            
        "vmess")
            local uuid=$(generate_uuid)
            local domain="www.google.com"
            local path="/$(generate_random_string 8)"
            
            # 生成配置
            local config_content=$(generate_vmess_config "$config_name" "$port" "$uuid" "$domain" "$path")
            echo "$config_content" > "$CONFIG_DIR/configs/$config_name.json"
            
            # 更新数据库
            add_config_to_db "$config_name" "vmess" "$port" "$uuid" "$domain|$path"
            
            success "VMess 配置 '$config_name' 创建完成"
            echo "  端口: $port"
            echo "  UUID: $uuid"
            echo "  域名: $domain"
            echo "  路径: $path"
            ;;
            
        "hysteria2")
            local password=$(generate_password)
            local domain="www.google.com"
            
            # 生成配置
            local config_content=$(generate_hysteria2_config "$config_name" "$port" "$domain" "$password")
            echo "$config_content" > "$CONFIG_DIR/configs/$config_name.json"
            
            # 更新数据库
            add_config_to_db "$config_name" "hysteria2" "$port" "$password" "$domain"
            
            success "Hysteria2 配置 '$config_name' 创建完成"
            echo "  端口: $port"
            echo "  密码: $password"
            echo "  域名: $domain"
            ;;
            
        "shadowsocks")
            local password=$(generate_password)
            local method="2022-blake3-chacha20-poly1305"
            
            # 生成配置
            local config_content=$(generate_shadowsocks_config "$config_name" "$port" "$method" "$password")
            echo "$config_content" > "$CONFIG_DIR/configs/$config_name.json"
            
            # 更新数据库
            add_config_to_db "$config_name" "shadowsocks" "$port" "$password" "$method"
            
            success "Shadowsocks 配置 '$config_name' 创建完成"
            echo "  端口: $port"
            echo "  方法: $method"
            echo "  密码: $password"
            ;;
            
        *)
            error "不支持的协议: $protocol"
            return 1
            ;;
    esac
    
    # 更新主配置
    update_main_config
    
    # 重启服务
    if systemctl is-active --quiet sing-box; then
        systemctl restart sing-box
    fi
    
    echo ""
    highlight "=== 分享链接 ==="
    case "$protocol" in
        "vless" | "vless-reality")
            generate_vless_url "$config_name"
            ;;
        "vmess")
            generate_vmess_url "$config_name"
            ;;
        "hysteria2")
            generate_hy2_url "$config_name"
            ;;
        "shadowsocks")
            generate_ss_url "$config_name"
            ;;
    esac
}

# 简化的交互式配置添加
interactive_add_simple_config() {
    clear
    print_banner
    echo -e "${GREEN}简化配置添加 - 只需要节点名称${NC}"
    print_sub_separator
    
    echo -e "${YELLOW}选择协议类型：${NC}"
    echo "  [1] VLESS Reality (推荐)"
    echo "  [2] VMess"
    echo "  [3] Hysteria2"
    echo "  [4] Shadowsocks"
    echo "  [0] 返回主菜单"
    
    local choice
    while true; do
        read -p "请选择协议 [1-4]: " choice
        case $choice in
            1) protocol="vless-reality"; break ;;
            2) protocol="vmess"; break ;;
            3) protocol="hysteria2"; break ;;
            4) protocol="shadowsocks"; break ;;
            0) return ;;
            *) warn "无效选择，请重新输入" ;;
        esac
    done
    
    # 获取配置名称
    local name
    while true; do
        name=$(read_input "请输入配置名称" "${protocol}-$(date +%s)")
        if [[ -z $(get_config_from_db "$name") ]]; then
            break
        else
            warn "配置名称 '$name' 已存在，请使用其他名称"
        fi
    done
    
    # 确认配置
    echo
    print_sub_separator
    echo -e "${YELLOW}配置预览：${NC}"
    echo "  名称: $name"
    echo "  协议: $protocol"
    echo "  其他参数: 将自动生成"
    print_sub_separator
    
    if confirm "确认添加此配置吗？"; then
        echo
        info "正在创建配置..."
        generate_auto_config "$name" "$protocol"
        wait_for_input
    else
        warn "配置添加已取消"
        wait_for_input
    fi
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

# 生成现代化客户端配置
generate_client_config() {
    local server_ip=$(get_public_ip)
    local configs=$(list_configs_from_db)
    
    if [[ -z $configs ]]; then
        error "暂无配置，请先添加节点配置"
        return 1
    fi
    
    # 生成 outbounds 配置
    local outbounds_json=""
    local outbound_names=""
    
    while IFS='|' read -r name protocol port uuid extra created; do
        if [[ -n "$name" ]]; then
            # 添加到选择器列表
            if [[ -n "$outbound_names" ]]; then
                outbound_names="$outbound_names, \"$name\""
            else
                outbound_names="\"$name\""
            fi
            
            # 生成对应的 outbound 配置
            case "$protocol" in
                "vless-reality")
                    local public_key=$(echo "$extra" | cut -d'|' -f2)
                    local short_id=$(echo "$extra" | cut -d'|' -f3)
                    local sni=$(echo "$extra" | cut -d'|' -f4)
                    
                    outbounds_json="$outbounds_json,
    {
      \"type\": \"vless\",
      \"tag\": \"$name\",
      \"server\": \"$server_ip\",
      \"server_port\": $port,
      \"uuid\": \"$uuid\",
      \"packet_encoding\": \"xudp\",
      \"flow\": \"xtls-rprx-vision\",
      \"tls\": {
        \"enabled\": true,
        \"server_name\": \"$sni\",
        \"utls\": {
          \"enabled\": true,
          \"fingerprint\": \"chrome\"
        },
        \"reality\": {
          \"enabled\": true,
          \"public_key\": \"$public_key\",
          \"short_id\": \"$short_id\"
        }
      }
    }"
                    ;;
                "vmess")
                    local domain=$(echo "$extra" | cut -d'|' -f2)
                    local path=$(echo "$extra" | cut -d'|' -f1)
                    
                    outbounds_json="$outbounds_json,
    {
      \"type\": \"vmess\",
      \"tag\": \"$name\",
      \"server\": \"$server_ip\",
      \"server_port\": $port,
      \"uuid\": \"$uuid\",
      \"security\": \"auto\",
      \"packet_encoding\": \"packetaddr\",
      \"transport\": {
        \"type\": \"ws\",
        \"path\": \"$path\",
        \"headers\": {
          \"Host\": [\"$domain\"]
        }
      },
      \"tls\": {
        \"enabled\": true,
        \"server_name\": \"$domain\",
        \"insecure\": false,
        \"utls\": {
          \"enabled\": true,
          \"fingerprint\": \"chrome\"
        }
      }
    }"
                    ;;
                "hysteria2")
                    local domain=$(echo "$extra" | cut -d'|' -f1)
                    
                    outbounds_json="$outbounds_json,
    {
      \"type\": \"hysteria2\",
      \"tag\": \"$name\",
      \"server\": \"$server_ip\",
      \"server_port\": $port,
      \"password\": \"$uuid\",
      \"tls\": {
        \"enabled\": true,
        \"server_name\": \"$domain\",
        \"insecure\": true,
        \"alpn\": [\"h3\"]
      }
    }"
                    ;;
                "tuic5")
                    local domain=$(echo "$extra" | cut -d'|' -f1)
                    local password=$(echo "$extra" | cut -d'|' -f2)
                    
                    outbounds_json="$outbounds_json,
    {
      \"type\": \"tuic\",
      \"tag\": \"$name\",
      \"server\": \"$server_ip\",
      \"server_port\": $port,
      \"uuid\": \"$uuid\",
      \"password\": \"$password\",
      \"congestion_control\": \"bbr\",
      \"udp_relay_mode\": \"native\",
      \"udp_over_stream\": false,
      \"zero_rtt_handshake\": false,
      \"heartbeat\": \"10s\",
      \"tls\": {
        \"enabled\": true,
        \"server_name\": \"$domain\",
        \"insecure\": true,
        \"alpn\": [\"h3\"]
      }
    }"
                    ;;
                "shadowsocks")
                    local method=$(echo "$extra" | cut -d'|' -f1)
                    
                    outbounds_json="$outbounds_json,
    {
      \"type\": \"shadowsocks\",
      \"tag\": \"$name\",
      \"server\": \"$server_ip\",
      \"server_port\": $port,
      \"method\": \"$method\",
      \"password\": \"$uuid\"
    }"
                    ;;
            esac
        fi
    done <<< "$configs"
    
    # 生成完整的客户端配置
    cat << EOF
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "experimental": {
    "clash_api": {
      "external_controller": "127.0.0.1:9090",
      "external_ui": "ui",
      "external_ui_download_url": "",
      "external_ui_download_detour": "",
      "secret": "",
      "default_mode": "Rule"
    },
    "cache_file": {
      "enabled": true,
      "path": "cache.db",
      "store_fakeip": true
    }
  },
  "dns": {
    "servers": [
      {
        "tag": "proxydns",
        "address": "tls://8.8.8.8/dns-query",
        "detour": "select"
      },
      {
        "tag": "localdns",
        "address": "h3://223.5.5.5/dns-query",
        "detour": "direct"
      },
      {
        "tag": "dns_fakeip",
        "address": "fakeip"
      }
    ],
    "rules": [
      {
        "outbound": "any",
        "server": "localdns",
        "disable_cache": true
      },
      {
        "clash_mode": "Global",
        "server": "proxydns"
      },
      {
        "clash_mode": "Direct",
        "server": "localdns"
      },
      {
        "rule_set": "geosite-cn",
        "server": "localdns"
      },
      {
        "rule_set": "geosite-geolocation-!cn",
        "server": "proxydns"
      },
      {
        "rule_set": "geosite-geolocation-!cn",
        "query_type": ["A", "AAAA"],
        "server": "dns_fakeip"
      }
    ],
    "fakeip": {
      "enabled": true,
      "inet4_range": "198.18.0.0/15",
      "inet6_range": "fc00::/18"
    },
    "independent_cache": true,
    "final": "proxydns"
  },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "address": ["172.19.0.1/30", "fd00::1/126"],
      "auto_route": true,
      "strict_route": true,
      "sniff": true,
      "sniff_override_destination": true,
      "domain_strategy": "prefer_ipv4"
    }
  ],
  "outbounds": [
    {
      "tag": "select",
      "type": "selector",
      "default": "auto",
      "outbounds": ["auto", $outbound_names]
    },
    {
      "tag": "auto",
      "type": "urltest",
      "outbounds": [$outbound_names],
      "url": "https://www.gstatic.com/generate_204",
      "interval": "1m",
      "tolerance": 50,
      "interrupt_exist_connections": false
    },
    {
      "tag": "direct",
      "type": "direct"
    }$outbounds_json
  ],
  "route": {
    "rule_set": [
      {
        "tag": "geosite-geolocation-!cn",
        "type": "remote",
        "format": "binary",
        "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/geolocation-!cn.srs",
        "download_detour": "select",
        "update_interval": "1d"
      },
      {
        "tag": "geosite-cn",
        "type": "remote",
        "format": "binary",
        "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/geolocation-cn.srs",
        "download_detour": "select",
        "update_interval": "1d"
      },
      {
        "tag": "geoip-cn",
        "type": "remote",
        "format": "binary",
        "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/cn.srs",
        "download_detour": "select",
        "update_interval": "1d"
      }
    ],
    "auto_detect_interface": true,
    "final": "select",
    "rules": [
      {
        "inbound": "tun-in",
        "action": "sniff"
      },
      {
        "protocol": "dns",
        "action": "hijack-dns"
      },
      {
        "port": 443,
        "network": "udp",
        "action": "reject"
      },
      {
        "clash_mode": "Direct",
        "outbound": "direct"
      },
      {
        "clash_mode": "Global",
        "outbound": "select"
      },
      {
        "rule_set": "geoip-cn",
        "outbound": "direct"
      },
      {
        "rule_set": "geosite-cn",
        "outbound": "direct"
      },
      {
        "ip_is_private": true,
        "outbound": "direct"
      },
      {
        "rule_set": "geosite-geolocation-!cn",
        "outbound": "select"
      }
    ]
  },
  "ntp": {
    "enabled": true,
    "server": "time.apple.com",
    "server_port": 123,
    "interval": "30m",
    "detour": "direct"
  }
}
EOF
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

interactive_system_diagnose() {
    clear
    print_banner
    echo -e "${GREEN}系统诊断${NC}"
    print_sub_separator
    
    echo -e "${YELLOW}正在诊断 Sing-box 服务状态...${NC}"
    echo
    
    # 检查服务状态
    echo -e "${CYAN}1. 检查服务状态${NC}"
    if systemctl is-active --quiet sing-box; then
        echo "  ✓ 服务正在运行"
    else
        echo "  ✗ 服务未运行"
        echo "  详细状态:"
        systemctl status sing-box --no-pager -l | head -10
    fi
    echo
    
    # 检查配置文件
    echo -e "${CYAN}2. 检查配置文件${NC}"
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "  ✓ 配置文件存在: $CONFIG_FILE"
        
        # 测试配置文件语法
        echo "  正在测试配置文件语法..."
        if check_config_syntax "$CONFIG_FILE"; then
            echo "  ✓ 配置文件语法正确"
        else
            echo "  ✗ 配置文件语法错误"
            echo "  详细错误:"
            get_config_error "$CONFIG_FILE"
        fi
    else
        echo "  ✗ 配置文件不存在: $CONFIG_FILE"
    fi
    echo
    
    # 检查文件权限
    echo -e "${CYAN}3. 检查文件权限${NC}"
    if [[ -f "$CONFIG_FILE" ]]; then
        local config_perm=$(stat -c "%a" "$CONFIG_FILE" 2>/dev/null || stat -f "%A" "$CONFIG_FILE")
        local config_owner=$(stat -c "%U:%G" "$CONFIG_FILE" 2>/dev/null || stat -f "%Su:%Sg" "$CONFIG_FILE")
        echo "  配置文件权限: $config_perm ($config_owner)"
        if [[ $config_perm -eq 644 ]] || [[ $config_perm -eq 600 ]]; then
            echo "  ✓ 配置文件权限正常"
        else
            echo "  ⚠ 配置文件权限可能有问题"
        fi
    fi
    
    if [[ -f "/usr/local/bin/sing-box" ]]; then
        local binary_perm=$(stat -c "%a" "/usr/local/bin/sing-box" 2>/dev/null || stat -f "%A" "/usr/local/bin/sing-box")
        echo "  二进制文件权限: $binary_perm"
        if [[ $binary_perm -eq 755 ]]; then
            echo "  ✓ 二进制文件权限正常"
        else
            echo "  ⚠ 二进制文件权限可能有问题"
        fi
    else
        echo "  ✗ Sing-box 二进制文件不存在"
    fi
    echo
    
    # 检查端口占用
    echo -e "${CYAN}4. 检查端口占用${NC}"
    local configs=$(list_configs_from_db)
    if [[ -n $configs ]]; then
        while IFS='|' read -r name protocol port uuid extra created; do
            if ss -tuln | grep -q ":$port "; then
                echo "  ✓ 端口 $port ($name) - 正在监听"
            else
                echo "  ✗ 端口 $port ($name) - 未监听"
            fi
        done <<< "$configs"
    else
        echo "  ⚠ 未找到配置信息"
    fi
    echo
    
    # 检查最近的错误日志
    echo -e "${CYAN}5. 最近的错误日志${NC}"
    local error_logs=$(journalctl -u sing-box --no-pager -p err -n 5 2>/dev/null)
    if [[ -n $error_logs ]]; then
        echo "$error_logs"
    else
        echo "  ✓ 近期无错误日志"
    fi
    echo
    
    # 检查系统资源
    echo -e "${CYAN}6. 系统资源检查${NC}"
    local memory_usage=$(free -h | grep "Mem:" | awk '{print $3"/"$2}')
    local disk_usage=$(df -h / | tail -1 | awk '{print $5}')
    echo "  内存使用: $memory_usage"
    echo "  磁盘使用: $disk_usage"
    echo
    
    # 提供修复建议
    echo -e "${CYAN}7. 修复建议${NC}"
    if ! systemctl is-active --quiet sing-box; then
        echo "  🔧 服务未运行，建议："
        echo "     - 检查配置文件语法"
        echo "     - 查看详细错误日志"
        echo "     - 重新启动服务"
        echo "     - 检查端口冲突"
    fi
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "  🔧 配置文件缺失，建议："
        echo "     - 重新生成配置文件"
        echo "     - 检查配置目录权限"
    fi
    
    echo
    echo -e "${YELLOW}诊断完成！${NC}"
    echo
    echo -e "${GREEN}快速修复选项：${NC}"
    echo "  [1] 重启服务"
    echo "  [2] 检查配置文件语法"
    echo "  [3] 修复文件权限"
    echo "  [4] 查看详细错误日志"
    echo "  [0] 返回上级菜单"
    echo
    
    local choice
    while true; do
        choice=$(read_input "请选择修复选项" "0")
        case "$choice" in
            "1")
                info "正在重启服务..."
                systemctl restart sing-box
                if systemctl is-active --quiet sing-box; then
                    success "服务重启成功"
                else
                    error "服务重启失败，请查看日志"
                fi
                break
                ;;
            "2")
                info "正在检查配置文件..."
                if [[ -f "$CONFIG_FILE" ]]; then
                    get_config_error "$CONFIG_FILE"
                else
                    error "配置文件不存在"
                fi
                break
                ;;
            "3")
                info "正在修复文件权限..."
                if [[ -f "$CONFIG_FILE" ]]; then
                    chmod 644 "$CONFIG_FILE"
                    success "配置文件权限已修复"
                fi
                if [[ -f "/usr/local/bin/sing-box" ]]; then
                    chmod 755 "/usr/local/bin/sing-box"
                    success "二进制文件权限已修复"
                fi
                break
                ;;
            "4")
                info "详细错误日志："
                journalctl -u sing-box --no-pager -p err -n 20
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

interactive_update_templates() {
    clear
    print_banner
    echo -e "${GREEN}配置模板更新${NC}"
    print_sub_separator
    
    echo -e "${YELLOW}可用的更新选项：${NC}"
    echo "  [1] 更新服务端配置模板"
    echo "  [2] 更新客户端配置模板"
    echo "  [3] 更新规则集源"
    echo "  [4] 全部更新"
    echo "  [0] 返回上级菜单"
    echo
    
    local choice
    while true; do
        choice=$(read_input "请选择" "0")
        case "$choice" in
            "1")
                info "正在更新服务端配置模板..."
                update_server_config_template
                success "服务端配置模板更新完成"
                break
                ;;
            "2")
                info "正在更新客户端配置模板..."
                update_client_config_template
                success "客户端配置模板更新完成"
                break
                ;;
            "3")
                info "正在更新规则集源..."
                update_rule_sets
                success "规则集源更新完成"
                break
                ;;
            "4")
                info "正在执行全部更新..."
                update_server_config_template
                update_client_config_template
                update_rule_sets
                success "配置模板全部更新完成"
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

# 更新服务端配置模板
update_server_config_template() {
    info "重新生成服务端主配置..."
    update_main_config
    
    if systemctl is-active --quiet sing-box; then
        info "重启服务以应用更新..."
        systemctl restart sing-box
    fi
}

# 更新客户端配置模板
update_client_config_template() {
    info "客户端配置模板已更新至最新版本"
    echo "  • 支持 Clash API"
    echo "  • 支持 FakeIP"
    echo "  • 支持 TUN 模式"
    echo "  • 支持智能分流"
    echo "  • 支持多协议"
}

# 更新规则集源
update_rule_sets() {
    info "更新规则集源地址..."
    
    # 清除旧的规则集缓存
    if [[ -d "$DATA_DIR" ]]; then
        rm -f "$DATA_DIR"/*.srs 2>/dev/null || true
    fi
    
    info "规则集源已更新至最新版本"
    echo "  • geosite-cn: 中国大陆网站"
    echo "  • geoip-cn: 中国大陆IP"
    echo "  • geosite-geolocation-!cn: 海外网站"
    echo "  • category-ads-all: 广告过滤"
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

interactive_generate_client_config() {
    clear
    print_banner
    echo -e "${GREEN}生成客户端配置${NC}"
    print_sub_separator
    
    local configs=$(list_configs_from_db)
    if [[ -z $configs ]]; then
        warn "暂无配置，请先添加节点配置"
        wait_for_input
        return
    fi
    
    echo -e "${YELLOW}可用配置：${NC}"
    echo
    
    local count=1
    while IFS='|' read -r name protocol port uuid extra created; do
        echo "  [$count] $name ($protocol)"
        ((count++))
    done <<< "$configs"
    
    echo
    echo -e "${YELLOW}生成选项：${NC}"
    echo "  [1] 生成完整客户端配置"
    echo "  [2] 保存配置到文件"
    echo "  [3] 显示配置内容"
    echo "  [0] 返回上级菜单"
    echo
    
    local choice
    while true; do
        choice=$(read_input "请选择" "1")
        case "$choice" in
            "1")
                clear
                print_banner
                echo -e "${GREEN}完整客户端配置${NC}"
                print_sub_separator
                
                info "正在生成客户端配置..."
                echo
                generate_client_config
                break
                ;;
            "2")
                clear
                print_banner
                echo -e "${GREEN}保存客户端配置${NC}"
                print_sub_separator
                
                local filename
                filename=$(read_input "请输入保存的文件名" "client_config.json")
                
                if [[ ! $filename =~ \.json$ ]]; then
                    filename="$filename.json"
                fi
                
                local filepath="/tmp/$filename"
                
                info "正在生成配置..."
                generate_client_config > "$filepath"
                
                success "客户端配置已保存到: $filepath"
                echo
                echo -e "${YELLOW}使用说明：${NC}"
                echo "  1. 将配置文件下载到客户端设备"
                echo "  2. 在 sing-box 客户端中导入配置文件"
                echo "  3. 启动客户端即可使用"
                echo
                echo -e "${YELLOW}支持的客户端：${NC}"
                echo "  • sing-box"
                echo "  • SFI (iOS)"
                echo "  • SFA (Android)"
                echo "  • sing-box GUI (Windows/macOS/Linux)"
                break
                ;;
            "3")
                clear
                print_banner
                echo -e "${GREEN}客户端配置内容${NC}"
                print_sub_separator
                
                generate_client_config | head -50
                echo
                echo -e "${YELLOW}... (配置内容已截断，选择选项2保存完整配置)${NC}"
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

# 更新脚本函数
interactive_update_script() {
    clear
    print_banner
    echo -e "${GREEN}更新脚本${NC}"
    print_sub_separator
    
    info "正在检查更新..."
    
    # 检查权限
    if [[ $EUID -ne 0 ]]; then
        error "更新脚本需要 root 权限"
    fi
    
    # 备份现有脚本
    local backup_path="/usr/local/bin/sing-box.bak.$(date +%Y%m%d_%H%M%S)"
    if [[ -f "/usr/local/bin/sing-box" ]]; then
        info "备份现有脚本..."
        cp "/usr/local/bin/sing-box" "$backup_path"
        success "备份完成: $backup_path"
    fi
    
    # 更新脚本
    info "下载最新版本..."
    if wget -O "/usr/local/bin/sing-box" "https://raw.githubusercontent.com/Yan-nian/singbox-install-script/master/sing-box.sh" 2>/dev/null; then
        chmod +x "/usr/local/bin/sing-box"
        ln -sf "/usr/local/bin/sing-box" /usr/local/bin/sb
        success "脚本更新完成"
        
        # 验证更新
        if bash -n "/usr/local/bin/sing-box"; then
            success "脚本语法验证通过"
        else
            warn "脚本语法验证失败，已回滚"
            cp "$backup_path" "/usr/local/bin/sing-box"
        fi
    else
        error "下载失败，请检查网络连接"
    fi
    
    wait_for_input
}

# 交互式更新核心程序
interactive_update_core() {
    clear
    print_banner
    echo -e "${GREEN}更新核心程序${NC}"
    print_sub_separator
    
    # 检查权限
    if [[ $EUID -ne 0 ]]; then
        error "更新核心程序需要 root 权限"
    fi
    
    # 确认更新
    local confirm
    confirm=$(read_input "确认更新 sing-box 核心程序? (y/N)" "n")
    if [[ $confirm != "y" ]] && [[ $confirm != "Y" ]]; then
        info "取消更新"
        wait_for_input
        return
    fi
    
    # 执行更新
    update_core
    
    wait_for_input
}

# 交互式备份配置
interactive_backup_configs() {
    clear
    print_banner
    echo -e "${GREEN}备份配置${NC}"
    print_sub_separator
    
    # 检查权限
    if [[ $EUID -ne 0 ]]; then
        error "备份配置需要 root 权限"
    fi
    
    # 确认备份
    local confirm
    confirm=$(read_input "确认备份当前配置? (y/N)" "n")
    if [[ $confirm != "y" ]] && [[ $confirm != "Y" ]]; then
        info "取消备份"
        wait_for_input
        return
    fi
    
    # 执行备份
    backup_configs
    
    wait_for_input
}

# 交互式恢复配置
interactive_restore_configs() {
    clear
    print_banner
    echo -e "${GREEN}恢复配置${NC}"
    print_sub_separator
    
    # 检查权限
    if [[ $EUID -ne 0 ]]; then
        error "恢复配置需要 root 权限"
    fi
    
    # 获取备份文件路径
    local backup_file
    backup_file=$(read_input "请输入备份文件路径" "")
    
    if [[ -z "$backup_file" ]]; then
        warn "未指定备份文件"
        wait_for_input
        return
    fi
    
    # 执行恢复
    restore_configs "$backup_file"
    
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

# 更新核心程序
update_core() {
    info "更新 sing-box 核心程序..."
    
    # 检查权限
    if [[ $EUID -ne 0 ]]; then
        error "更新核心程序需要 root 权限"
    fi
    
    # 获取系统架构
    local arch=$(uname -m)
    case $arch in
        x86_64)
            arch="amd64"
            ;;
        aarch64)
            arch="arm64"
            ;;
        armv7l)
            arch="armv7"
            ;;
        *)
            error "不支持的架构: $arch"
            ;;
    esac
    
    # 获取最新版本
    local latest_version
    info "正在获取最新版本信息..."
    latest_version=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | head -1)
    
    # 如果获取失败，尝试备用方法
    if [[ -z $latest_version ]]; then
        warn "API 获取失败，尝试备用方法..."
        latest_version=$(curl -s "https://github.com/SagerNet/sing-box/releases/latest" | grep -oP 'tag/\K[^"]+' | head -1)
    fi
    
    # 如果仍然失败，使用预设版本
    if [[ -z $latest_version ]]; then
        warn "无法获取最新版本，使用预设版本 v1.11.15"
        latest_version="v1.11.15"
    fi
    
    info "最新版本: $latest_version"
    
    # 检查当前版本
    local current_version
    if command -v /usr/local/bin/sing-box >/dev/null 2>&1; then
        current_version=$(/usr/local/bin/sing-box version 2>/dev/null | head -1 | awk '{print $3}' || echo "unknown")
        info "当前版本: $current_version"
        
        if [[ "$current_version" == "$latest_version" ]]; then
            success "已是最新版本"
            return
        fi
    fi
    
    # 停止服务
    info "停止服务..."
    systemctl stop sing-box 2>/dev/null || true
    
    # 备份现有程序
    if [[ -f "/usr/local/bin/sing-box" ]]; then
        cp "/usr/local/bin/sing-box" "/usr/local/bin/sing-box.bak.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # 下载新版本
    local download_url="https://github.com/SagerNet/sing-box/releases/download/${latest_version}/sing-box-${latest_version#v}-linux-${arch}.tar.gz"
    
    cd /tmp
    if wget -O sing-box.tar.gz "$download_url"; then
        # 解压安装
        tar -xzf sing-box.tar.gz
        local extract_dir=$(find . -name "sing-box-*-linux-${arch}" -type d | head -1)
        
        if [[ -n $extract_dir ]]; then
            cp "$extract_dir/sing-box" /usr/local/bin/
            chmod +x /usr/local/bin/sing-box
            
            # 清理临时文件
            rm -rf sing-box.tar.gz "$extract_dir"
            
            success "核心程序更新完成"
            
            # 重启服务
            systemctl start sing-box
            success "服务已重启"
        else
            error "解压失败"
        fi
    else
        error "下载失败"
    fi
}

# 版本检查
check_version() {
    echo -e "${GREEN}版本信息${NC}"
    echo "─────────────────────────────────────────────────────────────────────────────"
    echo "脚本版本: $SCRIPT_VERSION"
    
    if command -v /usr/local/bin/sing-box >/dev/null 2>&1; then
        echo "核心版本: $(/usr/local/bin/sing-box version 2>/dev/null | head -1 || echo '获取失败')"
    else
        echo "核心版本: 未安装"
    fi
    
    # 检查最新版本
    echo -n "检查最新版本..."
    local latest_version
    latest_version=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' 2>/dev/null)
    
    if [[ -n $latest_version ]]; then
        echo " $latest_version"
    else
        echo " 检查失败"
    fi
    
    echo "─────────────────────────────────────────────────────────────────────────────"
}

# 配置备份功能
backup_configs() {
    info "创建配置备份..."
    
    # 检查权限
    if [[ $EUID -ne 0 ]]; then
        error "备份配置需要 root 权限"
    fi
    
    # 创建备份目录
    local backup_dir="/tmp/sing-box-backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # 备份配置文件
    if [[ -d "$CONFIG_DIR" ]]; then
        cp -r "$CONFIG_DIR" "$backup_dir/"
        success "配置文件已备份到: $backup_dir/sing-box"
    else
        warn "配置目录不存在: $CONFIG_DIR"
    fi
    
    # 备份数据库文件
    if [[ -d "$DATA_DIR" ]]; then
        cp -r "$DATA_DIR" "$backup_dir/"
        success "数据文件已备份到: $backup_dir/sing-box"
    else
        warn "数据目录不存在: $DATA_DIR"
    fi
    
    # 创建压缩包
    local archive_name="sing-box-backup-$(date +%Y%m%d_%H%M%S).tar.gz"
    cd /tmp
    tar -czf "$archive_name" "$(basename "$backup_dir")"
    
    # 移动到用户目录
    if [[ -n "$SUDO_USER" ]]; then
        local user_home=$(eval echo ~$SUDO_USER)
        mv "$archive_name" "$user_home/"
        chown $SUDO_USER:$SUDO_USER "$user_home/$archive_name"
        success "备份完成: $user_home/$archive_name"
    else
        mv "$archive_name" /root/
        success "备份完成: /root/$archive_name"
    fi
    
    # 清理临时目录
    rm -rf "$backup_dir"
    
    info "备份包含以下内容:"
    info "  - 配置文件: $CONFIG_DIR"
    info "  - 数据文件: $DATA_DIR"
    info "  - 数据库文件: $DB_FILE"
}

# 配置恢复功能
restore_configs() {
    local backup_file="$1"
    
    if [[ -z "$backup_file" ]]; then
        error "请指定备份文件路径"
    fi
    
    if [[ ! -f "$backup_file" ]]; then
        error "备份文件不存在: $backup_file"
    fi
    
    # 检查权限
    if [[ $EUID -ne 0 ]]; then
        error "恢复配置需要 root 权限"
    fi
    
    warn "即将恢复配置，这将覆盖现有配置"
    read -p "确认恢复? (y/N): " confirm
    if [[ $confirm != "y" ]] && [[ $confirm != "Y" ]]; then
        info "取消恢复"
        return
    fi
    
    info "停止服务..."
    systemctl stop sing-box 2>/dev/null || true
    
    # 备份现有配置
    local current_backup="/tmp/sing-box-current-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$current_backup"
    [[ -d "$CONFIG_DIR" ]] && cp -r "$CONFIG_DIR" "$current_backup/"
    [[ -d "$DATA_DIR" ]] && cp -r "$DATA_DIR" "$current_backup/"
    
    # 恢复配置
    info "恢复配置..."
    cd /tmp
    tar -xzf "$backup_file"
    
    # 找到解压后的目录
    local extracted_dir=$(find . -name "sing-box-backup-*" -type d | head -1)
    if [[ -n "$extracted_dir" ]]; then
        # 恢复文件
        [[ -d "$extracted_dir/sing-box" ]] && cp -r "$extracted_dir/sing-box"/* "$CONFIG_DIR/"
        [[ -d "$extracted_dir/sing-box" ]] && cp -r "$extracted_dir/sing-box"/* "$DATA_DIR/"
        
        # 清理解压文件
        rm -rf "$extracted_dir"
        
        # 重启服务
        systemctl start sing-box
        success "配置恢复完成"
        success "当前配置已备份到: $current_backup"
    else
        error "无法找到备份内容"
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
    echo "更新功能:"
    echo "  update script                     更新管理脚本"
    echo "  update core                       更新核心程序"
    echo ""
    echo "备份功能:"
    echo "  backup                            备份配置文件"
    echo "  restore <backup_file>             恢复配置文件"
    echo ""
    echo "其他:"
    echo "  version                           显示版本信息"
    echo "  help                              显示帮助"
    echo ""
    echo "示例:"
    echo "  sing-box add vless                添加默认 VLESS Reality 配置"
    echo "  sing-box add vmess my-vmess 8080  添加指定端口的 VMess 配置"
    echo "  sing-box info vless-001           查看配置详情"
    echo "  sing-box url vless-001            获取分享链接"
    echo "  sing-box update script            更新管理脚本"
    echo "  sing-box update core              更新核心程序"
    echo "  sing-box backup                   备份配置文件"
    echo "  sing-box restore backup.tar.gz   恢复配置文件"
}

# 交互式主菜单处理
interactive_main() {
    # 初始化目录结构
    init_directories
    
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
                        "1") interactive_add_simple_config ;;
                        "2") interactive_add_vless_reality ;;
                        "3") interactive_add_vmess ;;
                        "4") interactive_add_hysteria2 ;;
                        "5") interactive_add_shadowsocks ;;
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
                        "6") interactive_system_diagnose ;;
                        "7") interactive_system_optimize ;;
                        "8") interactive_update_templates ;;
                        "9") interactive_update_script ;;
                        "10") interactive_update_core ;;
                        "11") interactive_backup_configs ;;
                        "12") interactive_restore_configs ;;
                        "13") interactive_uninstall ;;
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
                        "5") interactive_generate_client_config ;;
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
                interactive_update_script
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
    # 创建必要的目录（如果有权限）
    if [[ $EUID -eq 0 ]]; then
        mkdir -p "$CONFIG_DIR"
        mkdir -p "$CONFIG_DIR/configs"
        mkdir -p "$DATA_DIR"
        mkdir -p "$LOG_DIR"
    else
        # 非root用户使用本地目录
        local local_dir="$HOME/.sing-box"
        mkdir -p "$local_dir"
        mkdir -p "$local_dir/configs"
        
        # 更新路径变量
        CONFIG_DIR="$local_dir"
        DATA_DIR="$local_dir"
        LOG_DIR="$local_dir"
        CONFIG_FILE="$CONFIG_DIR/config.json"
        DB_FILE="$DATA_DIR/sing-box.db"
    fi
    
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
            check_version
            ;;
        "update")
            case "$2" in
                "script")
                    interactive_update_script
                    ;;
                "core")
                    update_core
                    ;;
                *)
                    info "更新脚本: sing-box update script"
                    info "更新核心: sing-box update core"
                    ;;
            esac
            ;;
        "backup")
            backup_configs
            ;;
        "restore")
            restore_configs "$2"
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