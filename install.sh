#!/bin/bash

# Sing-box VPS一键安装脚本
# 支持协议: VLESS Reality, VMess WebSocket, Hysteria2
# 作者: Solo Coding
# 版本: v2.0.0
# 更新时间: 2024-12-19

# 基础设置
IFS=$'\n\t'

# 清理函数
cleanup_on_error() {
    log_warn "正在清理临时文件..."
    [[ -d "/tmp/sing-box-install" ]] && rm -rf "/tmp/sing-box-install"
    [[ -f "/tmp/sing-box-backup.tar.gz" ]] && rm -f "/tmp/sing-box-backup.tar.gz"
}

# 设置中断信号处理
trap 'echo "脚本被中断"; cleanup_on_error; exit 130' INT TERM

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 全局常量
readonly SCRIPT_VERSION="v2.0.0"
readonly SCRIPT_NAME="Sing-box VPS一键安装脚本"
readonly SCRIPT_AUTHOR="Solo Coding"
readonly SCRIPT_DATE="2024-12-19"

# Sing-box 相关路径
readonly SINGBOX_CONFIG_DIR="/etc/sing-box"
readonly SINGBOX_LOG_DIR="/var/log/sing-box"
readonly SINGBOX_SERVICE_FILE="/etc/systemd/system/sing-box.service"
readonly SINGBOX_BINARY="/usr/local/bin/sing-box"
readonly SINGBOX_BACKUP_DIR="/etc/sing-box/backup"
readonly SINGBOX_CERT_DIR="/etc/sing-box/certs"

# 网络配置
readonly DEFAULT_DNS_SERVERS=("1.1.1.1" "8.8.8.8" "223.5.5.5")
readonly GITHUB_API_URL="https://api.github.com/repos/SagerNet/sing-box/releases/latest"
readonly GITHUB_MIRROR="https://mirror.ghproxy.com"

# 端口范围
readonly MIN_PORT=10000
readonly MAX_PORT=65535

# 全局变量
SINGBOX_VERSION=""
CURRENT_PROTOCOL=""
CURRENT_PORT=""
INSTALL_PATH="$(pwd)"
DEBUG_MODE=false

# 系统信息
OS_TYPE=""
OS_VERSION=""
ARCH=""
IP_ADDRESS=""

# 协议配置
VLESS_UUID=""
VLESS_REALITY_PRIVATE_KEY=""
VLESS_REALITY_PUBLIC_KEY=""
VLESS_REALITY_SHORT_ID=""
VLESS_TARGET_WEBSITE=""
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

# 增强的日志函数
log_info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[INFO]${NC} [$timestamp] $1"
    [[ "$DEBUG_MODE" == "true" ]] && echo "[INFO] [$timestamp] $1" >> "/tmp/sing-box-install.log"
}

log_warn() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[WARN]${NC} [$timestamp] $1"
    [[ "$DEBUG_MODE" == "true" ]] && echo "[WARN] [$timestamp] $1" >> "/tmp/sing-box-install.log"
}

log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[ERROR]${NC} [$timestamp] $1" >&2
    echo "[ERROR] [$timestamp] $1" >> "/tmp/sing-box-install.log"
}

log_debug() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    if [[ "$DEBUG_MODE" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} [$timestamp] $1"
        echo "[DEBUG] [$timestamp] $1" >> "/tmp/sing-box-install.log"
    fi
}

log_success() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[SUCCESS]${NC} [$timestamp] $1"
    [[ "$DEBUG_MODE" == "true" ]] && echo "[SUCCESS] [$timestamp] $1" >> "/tmp/sing-box-install.log"
}

# 增强的进度显示函数
show_progress() {
    local current=$1
    local total=$2
    local desc=$3
    local percent=$((current * 100 / total))
    local bar_length=40
    local filled_length=$((percent * bar_length / 100))
    
    # 清除当前行
    printf "\r\033[K"
    
    # 显示进度条
    printf "${CYAN}[%3d%%]${NC} [" "$percent"
    for ((i=0; i<filled_length; i++)); do printf "${GREEN}█${NC}"; done
    for ((i=filled_length; i<bar_length; i++)); do printf "${BLUE}░${NC}"; done
    printf "] ${YELLOW}%s${NC}" "$desc"
    
    # 如果完成，换行
    [[ $current -eq $total ]] && echo
}

# 旋转进度指示器
show_spinner() {
    local pid=$1
    local desc=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        printf "\r${CYAN}%s${NC} ${YELLOW}%s${NC}" "${spin:$i:1}" "$desc"
        i=$(( (i+1) % ${#spin} ))
        sleep 0.1
    done
    printf "\r\033[K"
}

# 状态指示器
show_status() {
    local status=$1
    local message=$2
    
    case $status in
        "success")
            echo -e "${GREEN}✓${NC} $message"
            ;;
        "error")
            echo -e "${RED}✗${NC} $message"
            ;;
        "warning")
            echo -e "${YELLOW}⚠${NC} $message"
            ;;
        "info")
            echo -e "${BLUE}ℹ${NC} $message"
            ;;
        "loading")
            echo -e "${CYAN}⟳${NC} $message"
            ;;
        *)
            echo -e "${NC}$message"
            ;;
    esac
}

# 错误处理函数
error_handler() {
    local line_number=$1
    log_error "脚本在第 $line_number 行发生错误"
    log_error "请检查网络连接和系统权限"
    exit 1
}

# 设置信号处理
trap 'echo "脚本被中断"; exit 1' INT TERM

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        log_info "请使用: sudo bash $0"
        exit 1
    fi
}

# 增强的系统检测模块
check_system() {
    show_status "loading" "正在检测系统环境..."
    
    # 检测操作系统
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS_TYPE=$ID
        OS_VERSION=$VERSION_ID
        OS_PRETTY_NAME="$PRETTY_NAME"
    elif [[ -f /etc/redhat-release ]]; then
        OS_TYPE="centos"
        OS_VERSION=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+')
        OS_PRETTY_NAME="CentOS $OS_VERSION"
    else
        show_status "error" "不支持的操作系统"
        log_error "当前系统不在支持列表中"
        exit 1
    fi
    
    # 检测系统架构
    local raw_arch=$(uname -m)
    case $raw_arch in
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
            show_status "error" "不支持的系统架构: $raw_arch"
            log_error "当前架构不在支持列表中"
            exit 1
            ;;
    esac
    
    # 检测操作系统类型（用于下载正确的二进制文件）
    local os_name=$(uname -s | tr '[:upper:]' '[:lower:]')
    case $os_name in
        linux)
            OS_BINARY="linux"
            ;;
        darwin)
            OS_BINARY="darwin"
            ;;
        *)
            OS_BINARY="linux"  # 默认使用linux版本
            ;;
    esac
    
    # 检测系统资源
    local total_mem=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    local available_space=$(df / | awk 'NR==2{printf "%.0f", $4/1024}')
    
    # 检查最低系统要求
    if [[ $total_mem -lt 512 ]]; then
        show_status "warning" "内存不足512MB，可能影响性能"
    fi
    
    if [[ $available_space -lt 1024 ]]; then
        show_status "warning" "可用磁盘空间不足1GB，可能影响安装"
    fi
    
    # 获取公网IP
    show_status "loading" "正在获取服务器IP地址..."
    local ip_services=(
        "ipv4.icanhazip.com"
        "ifconfig.me"
        "ip.sb"
        "ipinfo.io/ip"
        "api.ipify.org"
    )
    
    for service in "${ip_services[@]}"; do
        IP_ADDRESS=$(curl -s --connect-timeout 5 --max-time 10 "$service" 2>/dev/null | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$')
        if [[ -n "$IP_ADDRESS" ]]; then
            break
        fi
    done
    
    if [[ -z "$IP_ADDRESS" ]]; then
        show_status "warning" "无法自动获取公网IP"
        while true; do
            read -p "请手动输入服务器IP地址: " IP_ADDRESS
            if [[ $IP_ADDRESS =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                break
            else
                show_status "error" "IP地址格式不正确，请重新输入"
            fi
        done
    fi
    
    # 显示系统信息
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}                    系统信息${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  操作系统: ${GREEN}$OS_PRETTY_NAME${NC}"
    echo -e "  系统架构: ${GREEN}$raw_arch ($ARCH)${NC}"
    echo -e "  内存大小: ${GREEN}${total_mem}MB${NC}"
    echo -e "  可用空间: ${GREEN}${available_space}MB${NC}"
    echo -e "  服务器IP: ${GREEN}$IP_ADDRESS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    
    show_status "success" "系统环境检测完成"
    log_debug "系统检测结果: OS=$OS_TYPE/$OS_VERSION, ARCH=$ARCH, IP=$IP_ADDRESS"
}

# 增强的依赖检查函数
check_dependencies() {
    show_status "loading" "正在检查系统依赖..."
    
    # 必需依赖
    local required_deps=("curl" "wget" "unzip" "systemctl" "openssl")
    # 可选依赖
    local optional_deps=("jq" "ss" "netstat" "lsof")
    
    local missing_required=()
    local missing_optional=()
    
    # 检查必需依赖
    for dep in "${required_deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_required+=("$dep")
        else
            show_status "success" "$dep 已安装"
        fi
    done
    
    # 检查可选依赖
    for dep in "${optional_deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_optional+=("$dep")
        else
            show_status "success" "$dep 已安装"
        fi
    done
    
    # 安装缺失的必需依赖
    if [[ ${#missing_required[@]} -gt 0 ]]; then
        show_status "warning" "缺少必需依赖: ${missing_required[*]}"
        show_status "loading" "正在自动安装依赖..."
        
        case $OS_TYPE in
            ubuntu|debian)
                show_progress 1 3 "更新软件包列表..."
                if apt update >/dev/null 2>&1; then
                    show_progress 2 3 "安装依赖包..."
                    if apt install -y "${missing_required[@]}" >/dev/null 2>&1; then
                        show_progress 3 3 "依赖安装完成"
                        show_status "success" "依赖安装成功"
                    else
                        show_status "error" "依赖安装失败，请手动安装: ${missing_required[*]}"
                        return 1
                    fi
                else
                    show_status "error" "无法更新软件包列表"
                    return 1
                fi
                ;;
            centos|rhel|fedora)
                show_progress 1 3 "检查包管理器..."
                if command -v dnf >/dev/null 2>&1; then
                    show_progress 2 3 "使用DNF安装依赖..."
                    if dnf install -y "${missing_required[@]}" >/dev/null 2>&1; then
                        show_progress 3 3 "依赖安装完成"
                        show_status "success" "依赖安装成功"
                    else
                        show_status "error" "依赖安装失败，请手动安装: ${missing_required[*]}"
                        return 1
                    fi
                else
                    show_progress 2 3 "使用YUM安装依赖..."
                    if yum install -y "${missing_required[@]}" >/dev/null 2>&1; then
                        show_progress 3 3 "依赖安装完成"
                        show_status "success" "依赖安装成功"
                    else
                        show_status "error" "依赖安装失败，请手动安装: ${missing_required[*]}"
                        return 1
                    fi
                fi
                ;;
            *)
                show_status "error" "不支持的包管理器，请手动安装: ${missing_required[*]}"
                return 1
                ;;
        esac
    fi
    
    # 提示可选依赖
    if [[ ${#missing_optional[@]} -gt 0 ]]; then
        show_status "info" "可选依赖未安装: ${missing_optional[*]}"
        show_status "info" "这些依赖不影响基本功能，但可能影响某些高级特性"
    fi
    
    show_status "success" "系统依赖检查完成"
    log_debug "依赖检查结果: 必需=${#missing_required[@]}个缺失, 可选=${#missing_optional[@]}个缺失"
}

# 优化的自签证书生成函数
generate_self_signed_cert() {
    local cert_file="$1"
    local key_file="$2"
    local common_name="${3:-localhost}"
    local validity_days="${4:-730}"
    
    # 参数验证
    if [[ -z "$cert_file" ]] || [[ -z "$key_file" ]]; then
        show_status "error" "证书文件路径不能为空"
        return 1
    fi
    
    local cert_dir=$(dirname "$cert_file")
    
    show_status "loading" "正在生成自签名证书: $common_name"
    
    # 确保证书目录存在
    if ! mkdir -p "$cert_dir"; then
        show_status "error" "无法创建证书目录: $cert_dir"
        return 1
    fi
    
    # 检查OpenSSL可用性
    if ! command -v openssl >/dev/null 2>&1; then
        show_status "error" "OpenSSL未安装，无法生成证书"
        return 1
    fi
    
    # 创建临时配置文件用于证书扩展
    local config_file="$cert_dir/cert_config_$$.conf"
    cat > "$config_file" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = California
L = San Francisco
O = Sing-box
OU = VPN Server
CN = $common_name

[v3_req]
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = critical, serverAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer:always
subjectAltName = @alt_names

[alt_names]
DNS.1 = $common_name
DNS.2 = localhost
DNS.3 = *.local
IP.1 = 127.0.0.1
IP.2 = ::1
EOF
    
    # 生成ECC私钥（P-256曲线）
    if ! openssl ecparam -genkey -name prime256v1 -out "$key_file" 2>/dev/null; then
        show_status "error" "生成ECC私钥失败"
        rm -f "$config_file"
        return 1
    fi
    
    # 生成自签名证书（使用SHA256）
    if ! openssl req -new -x509 -key "$key_file" -out "$cert_file" \
        -days "$validity_days" -sha256 -config "$config_file" \
        -extensions v3_req 2>/dev/null; then
        show_status "error" "生成自签名证书失败"
        rm -f "$config_file" "$key_file"
        return 1
    fi
    
    # 验证生成的证书
    if ! openssl x509 -in "$cert_file" -noout -text >/dev/null 2>&1; then
        show_status "error" "生成的证书格式无效"
        rm -f "$config_file" "$cert_file" "$key_file"
        return 1
    fi
    
    # 设置适当的文件权限
    chmod 600 "$key_file"  # 私钥只有所有者可读写
    chmod 644 "$cert_file" # 证书所有者可读写，其他人只读
    
    # 清理临时配置文件
    rm -f "$config_file"
    
    # 获取证书信息用于验证
    local cert_subject
    cert_subject=$(openssl x509 -in "$cert_file" -noout -subject 2>/dev/null | sed 's/subject=//')
    local cert_validity
    cert_validity=$(openssl x509 -in "$cert_file" -noout -dates 2>/dev/null | grep 'notAfter' | cut -d'=' -f2)
    
    show_status "success" "ECC自签名证书生成成功"
    log_debug "证书文件: $cert_file"
    log_debug "私钥文件: $key_file"
    log_debug "证书主题: $cert_subject"
    log_debug "有效期至: $cert_validity"
    
    return 0
}

# 检查网络连接
check_network() {
    log_info "正在检查网络连接..."
    
    local test_urls=("google.com" "github.com" "cloudflare.com" "8.8.8.8")
    local network_ok=false
    
    for url in "${test_urls[@]}"; do
        if ping -c 1 -W 3 "$url" >/dev/null 2>&1; then
            network_ok=true
            break
        fi
    done
    
    if [[ "$network_ok" == "false" ]]; then
        log_warn "网络连接可能存在问题，但继续执行安装"
    else
        log_info "网络连接正常"
    fi
}

# 增强的端口检查函数
check_port() {
    local port=$1
    local protocol=${2:-"tcp"}
    
    log_debug "检查端口 $port ($protocol) 是否被占用"
    
    # 使用多种方法检查端口占用
    if command -v ss >/dev/null 2>&1; then
        if ss -${protocol}ln | grep -q ":$port "; then
            log_debug "端口 $port 已被占用 (通过ss检测)"
            return 1
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -${protocol}ln | grep -q ":$port "; then
            log_debug "端口 $port 已被占用 (通过netstat检测)"
            return 1
        fi
    elif command -v lsof >/dev/null 2>&1; then
        if lsof -i "$protocol:$port" >/dev/null 2>&1; then
            log_debug "端口 $port 已被占用 (通过lsof检测)"
            return 1
        fi
    else
        # 如果没有检测工具，尝试绑定端口
        if ! timeout 1 bash -c "</dev/tcp/127.0.0.1/$port" 2>/dev/null; then
            log_debug "端口 $port 可能可用 (通过连接测试)"
            return 0
        else
            log_debug "端口 $port 已被占用 (通过连接测试)"
            return 1
        fi
    fi
    
    log_debug "端口 $port 可用"
    return 0
}

# 智能端口生成函数
generate_random_port() {
    local protocol=${1:-"tcp"}
    local exclude_ports=(${2:-})
    local max_attempts=100
    local attempt=0
    local port
    
    # 常用端口范围避免列表
    local avoid_ranges=(
        "22 22"      # SSH
        "53 53"      # DNS
        "80 80"      # HTTP
        "443 443"    # HTTPS
        "3306 3306"  # MySQL
        "5432 5432"  # PostgreSQL
        "6379 6379"  # Redis
        "27017 27017" # MongoDB
    )
    
    while [[ $attempt -lt $max_attempts ]]; do
        port=$((RANDOM % (MAX_PORT - MIN_PORT + 1) + MIN_PORT))
        
        # 检查是否在排除列表中
        local excluded=false
        for exclude_port in "${exclude_ports[@]}"; do
            if [[ "$port" == "$exclude_port" ]]; then
                excluded=true
                break
            fi
        done
        
        if [[ "$excluded" == "true" ]]; then
            ((attempt++))
            continue
        fi
        
        # 检查是否在避免范围内
        local in_avoid_range=false
        for range in "${avoid_ranges[@]}"; do
            local start_port=$(echo "$range" | cut -d' ' -f1)
            local end_port=$(echo "$range" | cut -d' ' -f2)
            if [[ $port -ge $start_port && $port -le $end_port ]]; then
                in_avoid_range=true
                break
            fi
        done
        
        if [[ "$in_avoid_range" == "true" ]]; then
            ((attempt++))
            continue
        fi
        
        # 检查端口是否可用
        if check_port "$port" "$protocol"; then
            log_debug "生成可用端口: $port (协议: $protocol, 尝试次数: $((attempt + 1)))"
            echo "$port"
            return 0
        fi
        
        ((attempt++))
    done
    
    log_error "无法生成可用端口，已尝试 $max_attempts 次"
    return 1
}

# 批量生成不冲突的端口
generate_multiple_ports() {
    local count=$1
    local protocol=${2:-"tcp"}
    local ports=()
    local i=0
    
    while [[ $i -lt $count ]]; do
        local new_port
        if new_port=$(generate_random_port "$protocol" "${ports[@]}"); then
            ports+=("$new_port")
            ((i++))
        else
            log_error "无法生成足够的可用端口"
            return 1
        fi
    done
    
    echo "${ports[@]}"
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
        local protocols=()
        local ports=()
        
        # 检测所有协议类型
        if grep -q "vmess" "$config_file"; then
            protocols+=("VMess WebSocket")
        fi
        if grep -q "hysteria2" "$config_file"; then
            protocols+=("Hysteria2")
        fi
        
        # 提取所有端口信息
        local all_ports=$(grep -o '"listen_port":[[:space:]]*[0-9]*' "$config_file" | grep -o '[0-9]*')
        if [[ -z "$all_ports" ]]; then
            all_ports=$(grep -o '"listen":[[:space:]]*"[^:]*:[0-9]*"' "$config_file" | grep -o '[0-9]*')
        fi
        
        # 设置协议和端口显示
        if [[ ${#protocols[@]} -gt 1 ]]; then
            # 多协议配置
            CURRENT_PROTOCOL="多协议 (${protocols[*]})"
            CURRENT_PORT=$(echo "$all_ports" | tr '\n' ',' | sed 's/,$//')
        elif [[ ${#protocols[@]} -eq 1 ]]; then
            # 单协议配置
            CURRENT_PROTOCOL="${protocols[0]}"
            CURRENT_PORT=$(echo "$all_ports" | head -1)
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
            echo -e "  ${GREEN}1.${NC} 单独安装 VLESS Reality (推荐)"
            echo -e "  ${GREEN}2.${NC} 单独安装 VMess WebSocket"
            echo -e "  ${GREEN}3.${NC} 单独安装 Hysteria2"
            echo -e "  ${GREEN}4.${NC} 一键安装所有协议 (VLESS Reality + VMess WS + Hysteria2)"
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
        
        if [[ "$status" == "not_installed" ]]; then
            read -p "请选择操作 [0-4]: " choice
        else
            read -p "请选择操作 [0-7]: " choice
        fi
        
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
                elif [[ "$status" != "not_installed" ]]; then
                    manage_service_menu
                fi
                ;;
            3)
                if [[ "$status" == "not_installed" ]]; then
                    install_hysteria2
                elif [[ "$status" != "not_installed" ]]; then
                    change_port_menu
                fi
                ;;
            4)
                if [[ "$status" == "not_installed" ]]; then
                    install_all_protocols
                elif [[ "$status" != "not_installed" ]]; then
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

# 增强的版本获取函数
get_latest_version() {
    show_status "loading" "正在获取最新版本信息..."
    
    local api_urls=(
        "$GITHUB_API_URL"
        "$GITHUB_MIRROR/$GITHUB_API_URL"
    )
    
    for api_url in "${api_urls[@]}"; do
        log_debug "尝试从 $api_url 获取版本信息"
        
        local version_info
        if command -v curl >/dev/null 2>&1; then
            version_info=$(curl -s --connect-timeout 10 --max-time 30 "$api_url" 2>/dev/null)
        elif command -v wget >/dev/null 2>&1; then
            version_info=$(wget -qO- --timeout=30 "$api_url" 2>/dev/null)
        fi
        
        if [[ -n "$version_info" ]]; then
            # 尝试使用jq解析JSON（如果可用）
            if command -v jq >/dev/null 2>&1; then
                SINGBOX_VERSION=$(echo "$version_info" | jq -r '.tag_name' 2>/dev/null)
            else
                # 使用grep和cut解析
                SINGBOX_VERSION=$(echo "$version_info" | grep '"tag_name":' | head -1 | cut -d'"' -f4 2>/dev/null)
            fi
            
            # 验证版本格式
            if [[ "$SINGBOX_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+.*$ ]]; then
                show_status "success" "获取到最新版本: $SINGBOX_VERSION"
                log_debug "版本获取成功，来源: $api_url"
                return 0
            fi
        fi
        
        log_debug "从 $api_url 获取版本信息失败"
    done
    
    # 如果所有方法都失败，使用默认版本
    show_status "warning" "无法获取最新版本信息，使用默认版本"
    SINGBOX_VERSION="v1.8.0"
    log_debug "使用默认版本: $SINGBOX_VERSION"
}

# 增强的下载函数
download_singbox() {
    show_status "loading" "正在下载 sing-box $SINGBOX_VERSION..."
    
    local filename="sing-box-${SINGBOX_VERSION#v}-${OS_BINARY}-${ARCH}.tar.gz"
    local download_urls=(
        "https://github.com/SagerNet/sing-box/releases/download/${SINGBOX_VERSION}/${filename}"
        "${GITHUB_MIRROR}/https://github.com/SagerNet/sing-box/releases/download/${SINGBOX_VERSION}/${filename}"
    )
    
    local temp_dir="/tmp/sing-box-install"
    local temp_file="$temp_dir/sing-box.tar.gz"
    
    # 创建临时目录
    if ! mkdir -p "$temp_dir"; then
        show_status "error" "无法创建临时目录"
        return 1
    fi
    
    log_debug "临时目录: $temp_dir"
    
    # 尝试从多个源下载
    local download_success=false
    for download_url in "${download_urls[@]}"; do
        show_status "loading" "尝试从源下载: $(echo "$download_url" | cut -d'/' -f3)"
        log_debug "下载地址: $download_url"
        
        # 使用wget下载（带进度条）
        if command -v wget >/dev/null 2>&1; then
            if wget --progress=bar:force --timeout=60 --tries=3 -O "$temp_file" "$download_url" 2>&1; then
                download_success=true
                break
            fi
        # 使用curl下载（带进度条）
        elif command -v curl >/dev/null 2>&1; then
            if curl -L --connect-timeout 30 --max-time 300 --retry 3 \
                   --progress-bar -o "$temp_file" "$download_url"; then
                download_success=true
                break
            fi
        fi
        
        show_status "warning" "从当前源下载失败，尝试下一个源..."
        [[ -f "$temp_file" ]] && rm -f "$temp_file"
    done
    
    if [[ "$download_success" != "true" ]]; then
        show_status "error" "所有下载源均失败，请检查网络连接"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 验证下载的文件
    if [[ ! -f "$temp_file" ]] || [[ ! -s "$temp_file" ]]; then
        show_status "error" "下载的文件无效或为空"
        rm -rf "$temp_dir"
        return 1
    fi
    
    local file_size=$(stat -f%z "$temp_file" 2>/dev/null || stat -c%s "$temp_file" 2>/dev/null)
    if [[ $file_size -lt 1048576 ]]; then  # 小于1MB可能是错误页面
        show_status "error" "下载的文件大小异常 (${file_size} bytes)"
        rm -rf "$temp_dir"
        return 1
    fi
    
    show_status "success" "文件下载完成 (${file_size} bytes)"
    
    # 解压文件
    show_status "loading" "正在解压文件..."
    if ! tar -xzf "$temp_file" -C "$temp_dir" 2>/dev/null; then
        show_status "error" "解压失败，文件可能损坏"
        log_debug "尝试查看文件内容: $(file "$temp_file" 2>/dev/null || echo '无法识别文件类型')"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 查找二进制文件
    local binary_path=$(find "$temp_dir" -name "sing-box" -type f 2>/dev/null | head -1)
    if [[ -z "$binary_path" ]] || [[ ! -f "$binary_path" ]]; then
        show_status "error" "未找到 sing-box 二进制文件"
        log_debug "临时目录内容: $(find "$temp_dir" -type f 2>/dev/null)"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 设置执行权限（如果需要）
    chmod +x "$binary_path" 2>/dev/null || true
    
    log_debug "找到二进制文件: $binary_path"
    
    # 验证二进制文件
    if ! "$binary_path" version >/dev/null 2>&1; then
        show_status "error" "二进制文件无法执行或损坏"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 复制到系统目录
    show_status "loading" "正在安装二进制文件..."
    if ! cp "$binary_path" "$SINGBOX_BINARY"; then
        show_status "error" "无法复制二进制文件到系统目录"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 设置执行权限
    if ! chmod +x "$SINGBOX_BINARY"; then
        show_status "error" "无法设置执行权限"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 验证安装
    local installed_version
    if installed_version=$("$SINGBOX_BINARY" version 2>/dev/null | head -1); then
        show_status "success" "sing-box 安装完成: $installed_version"
        log_debug "安装路径: $SINGBOX_BINARY"
    else
        show_status "error" "安装验证失败"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 清理临时文件
    rm -rf "$temp_dir"
    log_debug "临时文件清理完成"
    
    return 0
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
    show_status "loading" "正在创建配置目录..."
    
    local dirs=(
        "$SINGBOX_CONFIG_DIR"
        "$SINGBOX_LOG_DIR"
        "$SINGBOX_CONFIG_DIR/certs"
        "/var/cache/sing-box"
    )
    
    for dir in "${dirs[@]}"; do
        if ! mkdir -p "$dir"; then
            show_status "error" "无法创建目录: $dir"
            return 1
        fi
        log_debug "创建目录: $dir"
    done
    
    # 设置适当的权限
    chmod 755 "$SINGBOX_CONFIG_DIR"
    chmod 755 "$SINGBOX_LOG_DIR"
    chmod 700 "$SINGBOX_CONFIG_DIR/certs"  # 证书目录需要更严格的权限
    chmod 755 "/var/cache/sing-box"
    
    show_status "success" "配置目录创建完成"
    return 0
}

# 验证配置文件
validate_config() {
    local config_file="$SINGBOX_CONFIG_DIR/config.json"
    
    if [[ ! -f "$config_file" ]]; then
        show_status "error" "配置文件不存在: $config_file"
        return 1
    fi
    
    show_status "loading" "正在验证配置文件..."
    
    # 检查配置文件是否为有效的JSON
    if command -v jq >/dev/null 2>&1; then
        if ! jq empty "$config_file" 2>/dev/null; then
            show_status "error" "配置文件不是有效的JSON格式"
            return 1
        fi
    fi
    
    # 使用sing-box验证配置
    local check_output
    if check_output=$("$SINGBOX_BINARY" check -c "$config_file" 2>&1); then
        show_status "success" "配置文件验证通过"
        log_debug "配置验证输出: $check_output"
        return 0
    else
        show_status "error" "配置文件验证失败"
        log_error "验证错误信息: $check_output"
        
        if [[ "$DEBUG_MODE" == "true" ]]; then
            echo "配置文件内容:"
            cat "$config_file"
        fi
        return 1
    fi
}

# 生成UUID
generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen 2>/dev/null
    elif [[ -r /proc/sys/kernel/random/uuid ]]; then
        cat /proc/sys/kernel/random/uuid 2>/dev/null
    else
        # 备用方法：使用随机数生成UUID格式
        printf '%08x-%04x-%04x-%04x-%012x\n' \
            $((RANDOM * RANDOM % 4294967296)) \
            $((RANDOM % 65536)) \
            $(((RANDOM % 16384) | 16384)) \
            $(((RANDOM % 16384) | 32768)) \
            $((RANDOM * RANDOM % 281474976710656))
    fi
}

# 生成随机字符串
generate_random_string() {
    local length=${1:-16}
    if [[ -r /dev/urandom ]]; then
        tr -dc 'A-Za-z0-9' < /dev/urandom 2>/dev/null | head -c "$length" 2>/dev/null
    else
        # 备用方法
        local chars="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        local result=""
        for ((i=0; i<length; i++)); do
            result+="${chars:$((RANDOM % ${#chars})):1}"
        done
        echo "$result"
    fi
}

# 生成十六进制随机字符串（用于 short_id）
generate_hex_string() {
    local length=${1:-8}
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -hex $((length/2)) 2>/dev/null | head -c "$length"
    elif [[ -r /dev/urandom ]]; then
        tr -dc '0-9a-f' < /dev/urandom 2>/dev/null | head -c "$length" 2>/dev/null
    else
        # 备用方法
        local chars="0123456789abcdef"
        local result=""
        for ((i=0; i<length; i++)); do
            result+="${chars:$((RANDOM % 16)):1}"
        done
        echo "$result"
    fi
}

# 生成Reality密钥对
generate_reality_keypair() {
    show_status "loading" "正在生成Reality密钥对..."
    
    # 查找可用的sing-box二进制文件
    local singbox_cmd=""
    
    # 优先级顺序：系统路径 -> 工作目录 -> 临时目录
    local possible_paths=(
        "$SINGBOX_BINARY"
        "$SINGBOX_CONFIG_DIR/sing-box"
        "/etc/sing-box/sing-box"
        "/tmp/sing-box/sing-box"
        "./sing-box"
        "sing-box"
    )
    
    for path in "${possible_paths[@]}"; do
        if [[ -f "$path" ]] && [[ -x "$path" ]]; then
            singbox_cmd="$path"
            log_debug "找到可执行的sing-box: $singbox_cmd"
            break
        fi
    done
    
    # 如果没有找到，尝试从系统PATH查找
    if [[ -z "$singbox_cmd" ]] && command -v sing-box >/dev/null 2>&1; then
        singbox_cmd="sing-box"
        log_debug "从系统PATH找到sing-box"
    fi
    
    # 如果仍然没有找到，自动下载安装
    if [[ -z "$singbox_cmd" ]]; then
        show_status "warning" "sing-box二进制文件不存在，正在自动下载安装..."
        
        # 检测系统架构（如果未设置）
        if [[ -z "$ARCH" ]]; then
            local raw_arch=$(uname -m)
            case $raw_arch in
                x86_64) ARCH="amd64" ;;
                aarch64|arm64) ARCH="arm64" ;;
                armv7l) ARCH="armv7" ;;
                *) 
                    show_status "error" "不支持的系统架构: $raw_arch"
                    return 1
                    ;;
            esac
            log_debug "检测到系统架构: $ARCH"
        fi
        
        # 检测操作系统类型（如果未设置）
        if [[ -z "$OS_BINARY" ]]; then
            local os_name=$(uname -s | tr '[:upper:]' '[:lower:]')
            case $os_name in
                linux) OS_BINARY="linux" ;;
                darwin) OS_BINARY="darwin" ;;
                *) OS_BINARY="linux" ;;
            esac
            log_debug "检测到操作系统: $OS_BINARY"
        fi
        
        # 获取最新版本并下载
        if ! get_latest_version; then
            show_status "error" "无法获取sing-box版本信息"
            return 1
        fi
        
        if ! download_singbox; then
            show_status "error" "sing-box下载安装失败"
            return 1
        fi
        
        # 重新查找sing-box
        for path in "${possible_paths[@]}"; do
            if [[ -f "$path" ]] && [[ -x "$path" ]]; then
                singbox_cmd="$path"
                break
            fi
        done
        
        if [[ -z "$singbox_cmd" ]]; then
            show_status "error" "sing-box安装后仍无法找到可执行文件"
            return 1
        fi
        
        show_status "success" "sing-box安装完成，继续生成密钥对..."
    fi
    
    local keypair_output
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        # 使用找到的sing-box命令生成密钥对，参考sing-box (1).sh的实现方式
        if keypair_output=$("$singbox_cmd" generate reality-keypair 2>&1); then
            log_debug "密钥生成尝试 $((retry_count+1)) 成功"
            log_debug "原始输出: $keypair_output"
            
            # 检查输出是否包含密钥信息
            if [[ "$keypair_output" == *"PrivateKey:"* ]] && [[ "$keypair_output" == *"PublicKey:"* ]]; then
                log_debug "检测到标准格式输出"
                break
            elif [[ "$keypair_output" == *"private_key"* ]] && [[ "$keypair_output" == *"public_key"* ]]; then
                log_debug "检测到JSON格式输出"
                break
            else
                log_debug "输出格式不符合预期，重试"
            fi
        else
            local exit_code=$?
            log_debug "密钥生成尝试 $((retry_count+1)) 失败，退出码: $exit_code"
            log_debug "错误输出: $keypair_output"
        fi
        
        ((retry_count++))
        if [[ $retry_count -lt $max_retries ]]; then
            show_status "warning" "生成失败，正在重试 ($retry_count/$max_retries)..."
            sleep 1
        fi
    done
    
    if [[ $retry_count -eq $max_retries ]]; then
        show_status "error" "生成Reality密钥对失败（已重试$max_retries次）"
        log_debug "最终失败输出: $keypair_output"
        return 1
    fi
    
    # 解析密钥对 - 参考sing-box (1).sh的解析方式
    if [[ "$keypair_output" == *"PrivateKey:"* ]] && [[ "$keypair_output" == *"PublicKey:"* ]]; then
        # 标准格式：PrivateKey: xxx\nPublicKey: xxx - 使用awk解析最后一个字段
        VLESS_REALITY_PRIVATE_KEY=$(awk '/PrivateKey/{print $NF}' <<< "$keypair_output")
        VLESS_REALITY_PUBLIC_KEY=$(awk '/PublicKey/{print $NF}' <<< "$keypair_output")
    elif [[ "$keypair_output" == *"private_key"* ]] && [[ "$keypair_output" == *"public_key"* ]]; then
        # JSON格式输出
        VLESS_REALITY_PRIVATE_KEY=$(echo "$keypair_output" | grep -o '"private_key"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        VLESS_REALITY_PUBLIC_KEY=$(echo "$keypair_output" | grep -o '"public_key"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    else
        # 尝试按行解析
        local lines=($(echo "$keypair_output" | tr '\n' ' '))
        if [[ ${#lines[@]} -ge 2 ]]; then
            VLESS_REALITY_PRIVATE_KEY="${lines[0]}"
            VLESS_REALITY_PUBLIC_KEY="${lines[1]}"
        fi
    fi
    
    # 清理密钥字符串，移除所有空白字符
    VLESS_REALITY_PRIVATE_KEY=$(echo "$VLESS_REALITY_PRIVATE_KEY" | tr -d '[:space:]')
    VLESS_REALITY_PUBLIC_KEY=$(echo "$VLESS_REALITY_PUBLIC_KEY" | tr -d '[:space:]')
    
    if [[ -z "$VLESS_REALITY_PRIVATE_KEY" ]] || [[ -z "$VLESS_REALITY_PUBLIC_KEY" ]]; then
        show_status "error" "解析Reality密钥对失败"
        log_debug "原始输出: $keypair_output"
        log_debug "解析后私钥: '$VLESS_REALITY_PRIVATE_KEY'"
        log_debug "解析后公钥: '$VLESS_REALITY_PUBLIC_KEY'"
        return 1
    fi
    
    # 验证密钥格式（Reality密钥通常是base64格式，但也可能包含其他字符）
    if [[ ${#VLESS_REALITY_PRIVATE_KEY} -lt 10 ]] || [[ ${#VLESS_REALITY_PUBLIC_KEY} -lt 10 ]]; then
        show_status "error" "生成的密钥长度过短"
        log_debug "私钥长度: ${#VLESS_REALITY_PRIVATE_KEY}, 公钥长度: ${#VLESS_REALITY_PUBLIC_KEY}"
        log_debug "私钥内容: '$VLESS_REALITY_PRIVATE_KEY'"
        log_debug "公钥内容: '$VLESS_REALITY_PUBLIC_KEY'"
        return 1
    fi
    
    show_status "success" "Reality密钥对生成成功"
    log_debug "私钥: ${VLESS_REALITY_PRIVATE_KEY:0:8}... (长度: ${#VLESS_REALITY_PRIVATE_KEY})"
    log_debug "公钥: ${VLESS_REALITY_PUBLIC_KEY:0:8}... (长度: ${#VLESS_REALITY_PUBLIC_KEY})"
    return 0
}

# 验证目标网站连通性
verify_target_website() {
    local website="$1"
    local timeout=5
    
    show_status "loading" "正在验证网站连通性: $website"
    
    # 尝试连接443端口
    if command -v nc >/dev/null 2>&1; then
        if timeout $timeout nc -z "$website" 443 2>/dev/null; then
            return 0
        fi
    elif command -v telnet >/dev/null 2>&1; then
        if timeout $timeout bash -c "echo '' | telnet $website 443" 2>/dev/null | grep -q "Connected"; then
            return 0
        fi
    elif command -v curl >/dev/null 2>&1; then
        if curl -s --connect-timeout $timeout "https://$website" >/dev/null 2>&1; then
            return 0
        fi
    fi
    
    return 1
}

# 选择目标网站
select_target_website() {
    echo
    show_status "info" "请选择Reality伪装目标网站:"
    echo "  1. microsoft.com (推荐)"
    echo "  2. cloudflare.com"
    echo "  3. www.bing.com"
    echo "  4. 自定义网站"
    echo
    
    local websites=("microsoft.com" "cloudflare.com" "www.bing.com")
    
    while true; do
        read -p "请选择 [1-4]: " website_choice
        
        case $website_choice in
            1|2|3)
                local selected_website="${websites[$((website_choice-1))]}"
                if verify_target_website "$selected_website"; then
                    VLESS_TARGET_WEBSITE="$selected_website"
                    show_status "success" "网站连通性验证通过"
                    break
                else
                    show_status "warning" "网站连通性验证失败，但仍可使用"
                    read -p "是否继续使用此网站? [y/N]: " confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        VLESS_TARGET_WEBSITE="$selected_website"
                        break
                    fi
                fi
                ;;
            4)
                while true; do
                    read -p "请输入目标网站域名 (如: example.com): " custom_website
                    if [[ -z "$custom_website" ]]; then
                        show_status "error" "域名不能为空"
                        continue
                    fi
                    
                    # 简单的域名格式验证
                    if [[ ! "$custom_website" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
                        show_status "error" "域名格式不正确"
                        continue
                    fi
                    
                    if verify_target_website "$custom_website"; then
                        VLESS_TARGET_WEBSITE="$custom_website"
                        show_status "success" "网站连通性验证通过"
                        break 2
                    else
                        show_status "warning" "网站连通性验证失败"
                        read -p "是否继续使用此网站? [y/N]: " confirm
                        if [[ "$confirm" =~ ^[Yy]$ ]]; then
                            VLESS_TARGET_WEBSITE="$custom_website"
                            break 2
                        fi
                    fi
                done
                ;;
            *)
                show_status "error" "无效选择，请重新输入"
                ;;
        esac
    done
    
    show_status "success" "已选择目标网站: $VLESS_TARGET_WEBSITE"
    log_debug "目标网站: $VLESS_TARGET_WEBSITE"
}

# 生成VLESS Reality配置文件
generate_vless_reality_config() {
    local vless_port=$1
    
    cat > "$SINGBOX_CONFIG_DIR/config.json" << EOF
{
  "log": {
    "level": "info",
    "output": "$SINGBOX_LOG_DIR/sing-box.log",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "cloudflare",
        "address": "https://1.1.1.1/dns-query",
        "detour": "direct"
      },
      {
        "tag": "google",
        "address": "https://8.8.8.8/dns-query",
        "detour": "direct"
      },
      {
        "tag": "local",
        "address": "223.5.5.5",
        "detour": "direct"
      }
    ],
    "rules": [
      {
        "domain_suffix": [
          ".cn"
        ],
        "server": "local"
      }
    ],
    "final": "cloudflare",
    "strategy": "prefer_ipv4"
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": $vless_port,
      "sniff": true,
      "sniff_override_destination": true,
      "domain_strategy": "ipv4_only",
      "users": [
        {
          "uuid": "$VLESS_UUID",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$VLESS_TARGET_WEBSITE",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "$VLESS_TARGET_WEBSITE",
            "server_port": 443
          },
          "private_key": "$VLESS_REALITY_PRIVATE_KEY",
          "short_id": [
            "$VLESS_REALITY_SHORT_ID"
          ]
        }
      },
      "multiplex": {
        "enabled": true,
        "padding": true,
        "brutal": {
          "enabled": true,
          "up_mbps": 1000,
          "down_mbps": 1000
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "vless",
      "tag": "proxy",
      "server": "$IP_ADDRESS",
      "server_port": $vless_port,
      "uuid": "$VLESS_UUID",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "$VLESS_TARGET_WEBSITE",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        },
        "reality": {
          "enabled": true,
          "public_key": "$VLESS_REALITY_PUBLIC_KEY",
          "short_id": "$VLESS_REALITY_SHORT_ID"
        }
      }
    },
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
    "rules": [
      {
        "ip_is_private": true,
        "outbound": "direct"
      },
      {
        "domain_suffix": [
          ".cn",
          ".chinanet.cn",
          ".chinaunicom.cn",
          ".chinatelcom.cn"
        ],
        "outbound": "direct"
      },
      {
        "ip_cidr": [
          "224.0.0.0/3",
          "ff00::/8"
        ],
        "outbound": "block"
      }
    ],
    "final": "proxy",
    "auto_detect_interface": true
  },
  "experimental": {
    "cache_file": {
      "enabled": true,
      "path": "$SINGBOX_CONFIG_DIR/cache.db"
    },
    "clash_api": {
      "external_controller": "127.0.0.1:9090",
      "external_ui": "ui",
      "secret": "",
      "external_ui_download_url": "https://mirror.ghproxy.com/https://github.com/MetaCubeX/Yacd-meta/archive/gh-pages.zip",
      "external_ui_download_detour": "direct",
      "default_mode": "rule"
    }
  }
}
EOF
}

# 生成VMess WebSocket配置
generate_vmess_ws_config() {
    local vmess_port=$1
    local ws_path=$2
    local cert_file=$3
    local key_file=$4
    
    cat > "$SINGBOX_CONFIG_DIR/config.json" << EOF
{
  "log": {
    "level": "info",
    "output": "$SINGBOX_LOG_DIR/sing-box.log",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "cloudflare",
        "address": "https://1.1.1.1/dns-query",
        "detour": "direct"
      },
      {
        "tag": "google",
        "address": "https://8.8.8.8/dns-query",
        "detour": "direct"
      },
      {
        "tag": "local",
        "address": "223.5.5.5",
        "detour": "direct"
      }
    ],
    "rules": [
      {
        "domain_suffix": [
          ".cn"
        ],
        "server": "local"
      }
    ],
    "final": "cloudflare",
    "strategy": "prefer_ipv4"
  },
  "inbounds": [
    {
      "type": "vmess",
      "tag": "vmess-in",
      "listen": "::",
      "listen_port": $vmess_port,
      "sniff": true,
      "sniff_override_destination": true,
      "domain_strategy": "ipv4_only",
      "tcp_fast_open": false,
      "proxy_protocol": false,
      "users": [
        {
          "uuid": "$VMESS_UUID",
          "alterId": 0
        }
      ],
      "transport": {
        "type": "ws",
        "path": "$ws_path",
        "max_early_data": 2048,
        "early_data_header_name": "Sec-WebSocket-Protocol"
      },
      "tls": {
        "enabled": true,
        "certificate_path": "$cert_file",
        "key_path": "$key_file"
      },
      "multiplex": {
        "enabled": true,
        "padding": true,
        "brutal": {
          "enabled": true,
          "up_mbps": 1000,
          "down_mbps": 1000
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "vmess",
      "tag": "proxy",
      "server": "$IP_ADDRESS",
      "server_port": $vmess_port,
      "uuid": "$VMESS_UUID",
      "transport": {
        "type": "ws",
        "path": "$ws_path"
      },
      "tls": {
        "enabled": true,
        "server_name": "$DOMAIN_NAME",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        }
      }
    },
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
    "rules": [
      {
        "ip_is_private": true,
        "outbound": "direct"
      },
      {
        "domain_suffix": [
          ".cn",
          ".chinanet.cn",
          ".chinaunicom.cn",
          ".chinatelcom.cn"
        ],
        "outbound": "direct"
      },
      {
        "ip_cidr": [
          "224.0.0.0/3",
          "ff00::/8"
        ],
        "outbound": "block"
      }
    ],
    "final": "proxy",
    "auto_detect_interface": true
  },
  "experimental": {
    "cache_file": {
      "enabled": true,
      "path": "$SINGBOX_CONFIG_DIR/cache.db"
    },
    "clash_api": {
      "external_controller": "127.0.0.1:9090",
      "external_ui": "ui",
      "secret": "",
      "external_ui_download_url": "https://mirror.ghproxy.com/https://github.com/MetaCubeX/Yacd-meta/archive/gh-pages.zip",
      "external_ui_download_detour": "direct",
      "default_mode": "rule"
    }
  }
}
EOF
}

# 生成增强配置文件
# 生成多协议配置（VMess WebSocket + Hysteria2）
generate_enhanced_config() {
    local vmess_port=$1
    local hy2_port=$2
    local ws_path=$3
    local masq_site=$4
    local vmess_cert_file=$5
    local vmess_key_file=$6
    local hy2_cert_file=$7
    local hy2_key_file=$8
    
    cat > "$SINGBOX_CONFIG_DIR/config.json" << EOF
{
  "log": {
    "level": "info",
    "output": "$SINGBOX_LOG_DIR/sing-box.log",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "cloudflare",
        "address": "https://1.1.1.1/dns-query",
        "detour": "direct"
      },
      {
        "tag": "google",
        "address": "https://8.8.8.8/dns-query",
        "detour": "direct"
      },
      {
        "tag": "local",
        "address": "223.5.5.5",
        "detour": "direct"
      }
    ],
    "rules": [
      {
        "domain_suffix": [
          ".cn"
        ],
        "server": "local"
      }
    ],
    "final": "cloudflare",
    "strategy": "prefer_ipv4"
  },
  "inbounds": [
    {
      "type": "vmess",
      "tag": "vmess-in",
      "listen": "::",
      "listen_port": $vmess_port,
      "sniff": true,
      "sniff_override_destination": true,
      "domain_strategy": "ipv4_only",
      "users": [
        {
          "uuid": "$VMESS_UUID"
        }
      ],
      "transport": {
        "type": "ws",
        "path": "$ws_path",
        "max_early_data": 2048,
        "early_data_header_name": "Sec-WebSocket-Protocol"
      },
      "tls": {
        "enabled": true,
        "certificate_path": "$vmess_cert_file",
        "key_path": "$vmess_key_file"
      }
    },
    {
      "type": "hysteria2",
      "tag": "hy2-in",
      "listen": "::",
      "listen_port": $hy2_port,
      "sniff": true,
      "sniff_override_destination": true,
      "domain_strategy": "ipv4_only",
      "up_mbps": 100,
      "down_mbps": 100,
      "users": [
        {
          "password": "$HY2_PASSWORD"
        }
      ],
      "masquerade": "https://www.bing.com",
      "tls": {
        "enabled": true,
        "alpn": [
          "h3"
        ],
        "certificate_path": "$hy2_cert_file",
        "key_path": "$hy2_key_file"
      }
    }
  ],
  "outbounds": [
    {
      "type": "vmess",
      "tag": "vmess-proxy",
      "server": "$IP_ADDRESS",
      "server_port": $vmess_port,
      "uuid": "$VMESS_UUID",
      "transport": {
        "type": "ws",
        "path": "$ws_path"
      },
      "tls": {
        "enabled": true,
        "server_name": "$DOMAIN_NAME",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        }
      }
    },
    {
      "type": "hysteria2",
      "tag": "hy2-proxy",
      "server": "$IP_ADDRESS",
      "server_port": $hy2_port,
      "password": "$HY2_PASSWORD",
      "tls": {
        "enabled": true,
        "server_name": "$DOMAIN_NAME",
        "alpn": [
          "h3"
        ],
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        }
      }
    },
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
    "rules": [
      {
        "ip_is_private": true,
        "outbound": "direct"
      },
      {
        "domain_suffix": [
          ".cn",
          ".chinanet.cn",
          ".chinaunicom.cn",
          ".chinatelcom.cn"
        ],
        "outbound": "direct"
      },
      {
        "ip_cidr": [
          "224.0.0.0/3",
          "ff00::/8"
        ],
        "outbound": "block"
      }
    ],
    "final": "vmess-proxy",
    "auto_detect_interface": true
  },
  "experimental": {
    "cache_file": {
      "enabled": true,
      "path": "$SINGBOX_CONFIG_DIR/cache.db"
    },
    "clash_api": {
      "external_controller": "127.0.0.1:9090",
      "external_ui": "ui",
      "secret": "",
      "external_ui_download_url": "https://mirror.ghproxy.com/https://github.com/MetaCubeX/Yacd-meta/archive/gh-pages.zip",
      "external_ui_download_detour": "direct",
      "default_mode": "rule"
    }
  }
}
EOF
}

# 生成三协议配置文件（VMess WebSocket + Hysteria2 + VLESS Reality）
generate_triple_protocol_config() {
    local vmess_port=$1
    local hy2_port=$2
    local vless_port=$3
    local ws_path=$4
    local masq_site=$5
    local vmess_cert_file=$6
    local vmess_key_file=$7
    local hy2_cert_file=$8
    local hy2_key_file=$9
    
    cat > "$SINGBOX_CONFIG_DIR/config.json" << EOF
{
  "log": {
    "level": "info",
    "output": "$SINGBOX_LOG_DIR/sing-box.log",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "cloudflare",
        "address": "https://1.1.1.1/dns-query",
        "detour": "direct"
      },
      {
        "tag": "google",
        "address": "https://8.8.8.8/dns-query",
        "detour": "direct"
      },
      {
        "tag": "local",
        "address": "223.5.5.5",
        "detour": "direct"
      }
    ],
    "rules": [
      {
        "domain_suffix": [
          ".cn"
        ],
        "server": "local"
      }
    ],
    "final": "cloudflare",
    "strategy": "prefer_ipv4"
  },
  "inbounds": [
    {
      "type": "vmess",
      "tag": "vmess-in",
      "listen": "::",
      "listen_port": $vmess_port,
      "sniff": true,
      "sniff_override_destination": true,
      "domain_strategy": "ipv4_only",
      "tcp_fast_open": false,
      "proxy_protocol": false,
      "users": [
        {
          "uuid": "$VMESS_UUID",
          "alterId": 0
        }
      ],
      "transport": {
        "type": "ws",
        "path": "$ws_path",
        "max_early_data": 2048,
        "early_data_header_name": "Sec-WebSocket-Protocol"
      },
      "tls": {
        "enabled": true,
        "certificate_path": "$vmess_cert_file",
        "key_path": "$vmess_key_file"
      },
      "multiplex": {
        "enabled": true,
        "padding": true,
        "brutal": {
          "enabled": true,
          "up_mbps": 1000,
          "down_mbps": 1000
        }
      }
    },
    {
      "type": "hysteria2",
      "tag": "hy2-in",
      "listen": "::",
      "listen_port": $hy2_port,
      "sniff": true,
      "sniff_override_destination": true,
      "domain_strategy": "ipv4_only",
      "up_mbps": 100,
      "down_mbps": 100,
      "users": [
        {
          "password": "$HY2_PASSWORD"
        }
      ],
      "masquerade": "https://www.bing.com",
      "tls": {
        "enabled": true,
        "alpn": [
          "h3"
        ],
        "certificate_path": "$hy2_cert_file",
        "key_path": "$hy2_key_file"
      }
    },
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
        "server_name": "$VLESS_TARGET_WEBSITE",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "$VLESS_TARGET_WEBSITE",
            "server_port": 443
          },
          "private_key": "$VLESS_REALITY_PRIVATE_KEY",
          "short_id": [
            "$VLESS_REALITY_SHORT_ID"
          ]
        }
      },
      "multiplex": {
        "enabled": true,
        "padding": true,
        "brutal": {
          "enabled": true,
          "up_mbps": 1000,
          "down_mbps": 1000
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "vless",
      "tag": "vless-proxy",
      "server": "$IP_ADDRESS",
      "server_port": $vless_port,
      "uuid": "$VLESS_UUID",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "$VLESS_TARGET_WEBSITE",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        },
        "reality": {
          "enabled": true,
          "public_key": "$VLESS_REALITY_PUBLIC_KEY",
          "short_id": "$VLESS_REALITY_SHORT_ID"
        }
      }
    },
    {
      "type": "vmess",
      "tag": "vmess-proxy",
      "server": "$IP_ADDRESS",
      "server_port": $vmess_port,
      "uuid": "$VMESS_UUID",
      "transport": {
        "type": "ws",
        "path": "$ws_path"
      },
      "tls": {
        "enabled": true,
        "server_name": "$DOMAIN_NAME",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        }
      }
    },
    {
      "type": "hysteria2",
      "tag": "hy2-proxy",
      "server": "$IP_ADDRESS",
      "server_port": $hy2_port,
      "password": "$HY2_PASSWORD",
      "tls": {
        "enabled": true,
        "server_name": "$DOMAIN_NAME",
        "alpn": [
          "h3"
        ],
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        }
      }
    },
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
    "rules": [
      {
        "ip_is_private": true,
        "outbound": "direct"
      },
      {
        "domain_suffix": [
          ".cn",
          ".chinanet.cn",
          ".chinaunicom.cn",
          ".chinatelcom.cn"
        ],
        "outbound": "direct"
      },
      {
        "ip_cidr": [
          "224.0.0.0/3",
          "ff00::/8"
        ],
        "outbound": "block"
      }
    ],
    "final": "vless-proxy",
    "auto_detect_interface": true
  },
  "experimental": {
    "cache_file": {
      "enabled": true,
      "path": "$SINGBOX_CONFIG_DIR/cache.db"
    },
    "clash_api": {
      "external_controller": "127.0.0.1:9090",
      "external_ui": "ui",
      "secret": "",
      "external_ui_download_url": "https://mirror.ghproxy.com/https://github.com/MetaCubeX/Yacd-meta/archive/gh-pages.zip",
      "external_ui_download_detour": "direct",
      "default_mode": "rule"
    }
  }
}
EOF
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
    VLESS_REALITY_SHORT_ID=$(generate_hex_string 8)
    local vless_port=$(generate_random_port)
    
    # 生成Reality密钥对
    if ! generate_reality_keypair; then
        log_error "Reality密钥对生成失败"
        read -p "按回车键返回主菜单..." -r
        return 1
    fi
    
    # 选择目标网站
    select_target_website
    
    # 生成配置文件
    log_info "正在生成VLESS Reality配置文件..."
    generate_vless_reality_config "$vless_port"
    
    # 创建系统服务
    create_systemd_service
    
    # 启动服务
    log_info "正在启动 sing-box 服务..."
    if systemctl start sing-box; then
        # 验证配置文件
        if validate_config; then
            log_info "VLESS Reality 安装完成！"
        else
            log_error "配置验证失败，请检查配置"
            systemctl stop sing-box
            read -p "按回车键返回主菜单..." -r
            return 1
        fi
        
        # 显示连接信息
        echo
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                连接信息${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        echo -e "${CYAN}【VLESS Reality】${NC}"
        echo -e "  服务器地址: ${GREEN}$IP_ADDRESS${NC}"
        echo -e "  端口: ${GREEN}$vless_port${NC}"
        echo -e "  UUID: ${GREEN}$VLESS_UUID${NC}"
        echo -e "  Flow: ${GREEN}xtls-rprx-vision${NC}"
        echo -e "  传输协议: ${GREEN}TCP${NC}"
        echo -e "  传输层安全: ${GREEN}Reality${NC}"
        echo -e "  SNI: ${GREEN}$VLESS_TARGET_WEBSITE${NC}"
        echo -e "  Fingerprint: ${GREEN}chrome${NC}"
        echo -e "  PublicKey: ${GREEN}$VLESS_REALITY_PUBLIC_KEY${NC}"
        echo -e "  ShortID: ${GREEN}$VLESS_REALITY_SHORT_ID${NC}"
        echo -e "  SpiderX: ${GREEN}/${NC}"
        
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # 保存当前配置信息
        CURRENT_PROTOCOL="VLESS Reality"
        CURRENT_PORT="$vless_port"
        
    else
        log_error "服务启动失败，请检查配置"
        echo
        log_info "正在检查配置文件..."
        "$SINGBOX_BINARY" check -c "$SINGBOX_CONFIG_DIR/config.json"
    fi
    
    echo
    read -p "按回车键返回主菜单..." -r
}

# 一键安装所有协议
install_all_protocols() {
    show_logo
    log_info "开始安装所有协议 (VMess WebSocket + Hysteria2 + VLESS Reality)..."
    
    # 获取并下载最新版本
    get_latest_version
    create_config_dirs
    
    if ! download_singbox; then
        log_error "安装失败"
        read -p "按回车键返回主菜单..." -r
        return 1
    fi
    
    # 生成所有协议的配置参数
    VMESS_UUID=$(generate_uuid)
    HY2_PASSWORD=$(generate_random_string 32)
    VLESS_UUID=$(generate_uuid)
    VLESS_REALITY_SHORT_ID=$(generate_hex_string 8)
    
    # 生成端口（确保不冲突）
    local vmess_port=$(generate_random_port)
    local hy2_port
    local vless_port
    
    # 确保端口不冲突
    while true; do
        hy2_port=$(generate_random_port)
        if [[ "$hy2_port" != "$vmess_port" ]]; then
            break
        fi
    done
    
    while true; do
        vless_port=$(generate_random_port)
        if [[ "$vless_port" != "$vmess_port" ]] && [[ "$vless_port" != "$hy2_port" ]]; then
            break
        fi
    done
    
    # 生成Reality密钥对
    if ! generate_reality_keypair; then
        log_error "Reality密钥对生成失败"
        read -p "按回车键返回主菜单..." -r
        return 1
    fi
    
    # 设置默认目标网站
    VLESS_TARGET_WEBSITE="microsoft.com"
    
    # 生成其他参数
    local ws_path="/$(generate_random_string 12)"
    local masq_site="https://www.bing.com"
    
    # 生成证书目录
    local cert_dir="$SINGBOX_CONFIG_DIR/certs"
    mkdir -p "$cert_dir"
    
    # 为VMess和Hysteria2生成自签名证书
    log_info "正在生成自签名证书..."
    local vmess_cert_file="$cert_dir/vmess_cert.pem"
    local vmess_key_file="$cert_dir/vmess_key.pem"
    local hy2_cert_file="$cert_dir/hy2_cert.pem"
    local hy2_key_file="$cert_dir/hy2_key.pem"
    
    # 生成VMess证书（使用ECC算法）
    generate_self_signed_cert "$vmess_cert_file" "$vmess_key_file" "vmess.local"
    
    # 生成Hysteria2证书（使用ECC算法）
    generate_self_signed_cert "$hy2_cert_file" "$hy2_key_file" "hysteria.local"
    
    # 生成三协议配置文件
    log_info "正在生成三协议配置文件..."
    
    generate_triple_protocol_config "$vmess_port" "$hy2_port" "$vless_port" "$ws_path" "$masq_site" "$vmess_cert_file" "$vmess_key_file" "$hy2_cert_file" "$hy2_key_file"
    
    # 创建系统服务
    create_systemd_service
    
    # 启动服务
    log_info "正在启动 sing-box 服务..."
    if systemctl start sing-box; then
        # 验证配置文件
        if validate_config; then
            log_info "所有协议安装完成！"
        else
            log_error "配置验证失败，请检查配置"
            systemctl stop sing-box
            read -p "按回车键返回主菜单..." -r
            return 1
        fi
        
        # 显示连接信息
        echo
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                连接信息${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        echo -e "${CYAN}【VMess WebSocket】${NC}"
        echo -e "  服务器地址: ${GREEN}$IP_ADDRESS${NC}"
        echo -e "  端口: ${GREEN}$vmess_port${NC}"
        echo -e "  UUID: ${GREEN}$VMESS_UUID${NC}"
        echo -e "  AlterID: ${GREEN}0${NC}"
        echo -e "  传输协议: ${GREEN}WebSocket${NC}"
        echo -e "  路径: ${GREEN}$ws_path${NC}"
        echo -e "  TLS: ${GREEN}启用${NC}"
        echo
        
        echo -e "${CYAN}【Hysteria2】${NC}"
        echo -e "  服务器地址: ${GREEN}$IP_ADDRESS${NC}"
        echo -e "  端口: ${GREEN}$hy2_port${NC}"
        echo -e "  密码: ${GREEN}$HY2_PASSWORD${NC}"
        echo -e "  伪装网站: ${GREEN}$masq_site${NC}"
        echo -e "  TLS: ${GREEN}启用${NC}"
        echo -e "  ALPN: ${GREEN}h3${NC}"
        echo
        
        echo -e "${CYAN}【VLESS Reality】${NC}"
        echo -e "  服务器地址: ${GREEN}$IP_ADDRESS${NC}"
        echo -e "  端口: ${GREEN}$vless_port${NC}"
        echo -e "  UUID: ${GREEN}$VLESS_UUID${NC}"
        echo -e "  Flow: ${GREEN}xtls-rprx-vision${NC}"
        echo -e "  传输协议: ${GREEN}TCP${NC}"
        echo -e "  传输层安全: ${GREEN}Reality${NC}"
        echo -e "  SNI: ${GREEN}$VLESS_TARGET_WEBSITE${NC}"
        echo -e "  Fingerprint: ${GREEN}chrome${NC}"
        echo -e "  PublicKey: ${GREEN}$VLESS_REALITY_PUBLIC_KEY${NC}"
        echo -e "  ShortID: ${GREEN}$VLESS_REALITY_SHORT_ID${NC}"
        echo -e "  SpiderX: ${GREEN}/${NC}"
        
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # 保存当前配置信息
        CURRENT_PROTOCOL="Multi-Protocol (VMess+Hysteria2+VLESS)"
        CURRENT_PORT="$vmess_port,$hy2_port,$vless_port"
        
    else
        log_error "服务启动失败，请检查配置"
        echo
        log_info "正在检查配置文件..."
        "$SINGBOX_BINARY" check -c "$SINGBOX_CONFIG_DIR/config.json"
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
        
        # 使用优化的证书生成函数
        generate_self_signed_cert "$cert_file" "$key_file" "$domain_name"
        
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
    "output": "$SINGBOX_LOG_DIR/sing-box.log",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vmess",
      "tag": "vmess-in",
      "listen": "::",
      "listen_port": $vmess_port,
      "sniff": true,
      "sniff_override_destination": true,
      "domain_strategy": "ipv4_only",
      "tcp_fast_open": false,
      "proxy_protocol": false,
      "users": [
        {
          "uuid": "$VMESS_UUID",
          "alterId": 0
        }
      ],
      "transport": {
        "type": "ws",
        "path": "$ws_path",
        "max_early_data": 2048,
        "early_data_header_name": "Sec-WebSocket-Protocol"
      }$tls_config,
      "multiplex": {
        "enabled": true,
        "padding": true,
        "brutal": {
          "enabled": true,
          "up_mbps": 1000,
          "down_mbps": 1000
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
  ],
  "route": {
    "rules": [
      {
        "ip_is_private": true,
        "outbound": "direct"
      },
      {
        "domain_suffix": [
          ".cn",
          ".chinanet.cn",
          ".chinaunicom.cn",
          ".chinatelcom.cn"
        ],
        "outbound": "direct"
      }
    ],
    "final": "direct",
    "auto_detect_interface": true
  },
  "experimental": {
    "cache_file": {
      "enabled": true,
      "path": "$SINGBOX_CONFIG_DIR/cache.db"
    },
    "clash_api": {
      "external_controller": "127.0.0.1:9090",
      "external_ui": "ui",
      "secret": "",
      "external_ui_download_url": "https://mirror.ghproxy.com/https://github.com/MetaCubeX/Yacd-meta/archive/gh-pages.zip",
      "external_ui_download_detour": "direct",
      "default_mode": "rule"
    }
  }
}
EOF
    
    # 创建系统服务
    create_systemd_service
    
    # 启动服务
    log_info "正在启动 sing-box 服务..."
    if systemctl start sing-box; then
        # 验证配置文件
        if validate_config; then
            log_info "VMess WebSocket 安装完成！"
        else
            log_error "配置验证失败，请检查配置"
            systemctl stop sing-box
            read -p "按回车键返回主菜单..." -r
            return 1
        fi
        
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
    
    # 使用优化的证书生成函数
    generate_self_signed_cert "$cert_file" "$key_file" "hysteria.local"
    
    # 生成配置文件
    log_info "正在生成配置文件..."
    
    cat > "$SINGBOX_CONFIG_DIR/config.json" << EOF
{
  "log": {
    "level": "info",
    "output": "$SINGBOX_LOG_DIR/sing-box.log",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "cloudflare",
        "address": "https://1.1.1.1/dns-query",
        "detour": "direct"
      },
      {
        "tag": "google",
        "address": "https://8.8.8.8/dns-query",
        "detour": "direct"
      },
      {
        "tag": "local",
        "address": "223.5.5.5",
        "detour": "direct"
      }
    ],
    "rules": [
      {
        "domain_suffix": [
          ".cn"
        ],
        "server": "local"
      }
    ],
    "final": "cloudflare",
    "strategy": "prefer_ipv4"
  },
  "inbounds": [
    {
      "type": "hysteria2",
      "tag": "hy2-in",
      "listen": "::",
      "listen_port": $hy2_port,
      "sniff": true,
      "sniff_override_destination": true,
      "domain_strategy": "ipv4_only",
      "up_mbps": 100,
      "down_mbps": 100,
      "users": [
        {
          "name": "user",
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
    },
    {
      "type": "block",
      "tag": "block"
    }
  ],
  "route": {
    "rules": [
      {
        "ip_cidr": [
          "224.0.0.0/3",
          "ff00::/8"
        ],
        "outbound": "block"
      },
      {
        "ip_cidr": [
          "10.0.0.0/8",
          "127.0.0.0/8",
          "169.254.0.0/16",
          "172.16.0.0/12",
          "192.168.0.0/16",
          "fc00::/7",
          "fe80::/10",
          "::1/128"
        ],
        "outbound": "direct"
      },
      {
        "domain_suffix": [
          ".cn"
        ],
        "outbound": "direct"
      }
    ],
    "final": "direct",
    "auto_detect_interface": true
  },
  "experimental": {
    "cache_file": {
      "enabled": true,
      "path": "$SINGBOX_CONFIG_DIR/cache.db"
    },
    "clash_api": {
      "external_controller": "127.0.0.1:9090",
      "external_ui": "ui",
      "secret": "",
      "external_ui_download_url": "https://mirror.ghproxy.com/https://github.com/MetaCubeX/Yacd-meta/archive/gh-pages.zip",
      "external_ui_download_detour": "direct",
      "default_mode": "rule"
    }
  }
}
EOF
    
    # 创建系统服务
    create_systemd_service
    
    # 启动服务
    log_info "正在启动 sing-box 服务..."
    if systemctl start sing-box; then
        # 验证配置文件
        if validate_config; then
            log_info "Hysteria2 安装完成！"
        else
            log_error "配置验证失败，请检查配置"
            systemctl stop sing-box
            read -p "按回车键返回主菜单..." -r
            return 1
        fi
        
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
    
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}                连接信息${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    
    # 检查并显示VMess WebSocket信息
    if grep -q "vmess" "$config_file"; then
        echo -e "${CYAN}【VMess WebSocket】${NC}"
        local vmess_uuid=$(grep -A 10 '"type": "vmess"' "$config_file" | grep -o '"uuid": "[^"]*"' | head -1 | cut -d'"' -f4)
        local vmess_port=$(grep -B 5 -A 10 '"type": "vmess"' "$config_file" | grep -o '"listen_port": [0-9]*' | head -1 | cut -d':' -f2 | tr -d ' ')
        local ws_path=$(grep -A 20 '"type": "vmess"' "$config_file" | grep -o '"path": "[^"]*"' | head -1 | cut -d'"' -f4)
        local tls_enabled=$(grep -A 20 '"type": "vmess"' "$config_file" | grep -q '"tls"' && echo "启用" || echo "未启用")
        
        echo -e "  服务器地址: ${GREEN}$IP_ADDRESS${NC}"
        echo -e "  端口: ${GREEN}$vmess_port${NC}"
        echo -e "  UUID: ${GREEN}$vmess_uuid${NC}"
        echo -e "  AlterID: ${GREEN}0${NC}"
        echo -e "  传输协议: ${GREEN}WebSocket${NC}"
        echo -e "  路径: ${GREEN}$ws_path${NC}"
        echo -e "  TLS: ${GREEN}$tls_enabled${NC}"
        echo
    fi
    
    # 检查并显示Hysteria2信息
    if grep -q "hysteria2" "$config_file"; then
        echo -e "${CYAN}【Hysteria2】${NC}"
        local hy2_password=$(grep -A 10 '"type": "hysteria2"' "$config_file" | grep -o '"password": "[^"]*"' | head -1 | cut -d'"' -f4)
        local hy2_port=$(grep -B 5 -A 10 '"type": "hysteria2"' "$config_file" | grep -o '"listen_port": [0-9]*' | head -1 | cut -d':' -f2 | tr -d ' ')
        local masquerade=$(grep -A 20 '"type": "hysteria2"' "$config_file" | grep -o '"masquerade": "[^"]*"' | head -1 | cut -d'"' -f4)
        
        echo -e "  服务器地址: ${GREEN}$IP_ADDRESS${NC}"
        echo -e "  端口: ${GREEN}$hy2_port${NC}"
        echo -e "  密码: ${GREEN}$hy2_password${NC}"
        echo -e "  伪装网站: ${GREEN}$masquerade${NC}"
        echo -e "  TLS: ${GREEN}启用${NC}"
        echo -e "  ALPN: ${GREEN}h3${NC}"
        echo
    fi
    
    # 检查并显示VLESS Reality信息
    if grep -q "vless" "$config_file"; then
        echo -e "${CYAN}【VLESS Reality】${NC}"
        local vless_uuid=$(grep -A 10 '"type": "vless"' "$config_file" | grep -o '"uuid": "[^"]*"' | head -1 | cut -d'"' -f4)
        local vless_port=$(grep -B 5 -A 10 '"type": "vless"' "$config_file" | grep -o '"listen_port": [0-9]*' | head -1 | cut -d':' -f2 | tr -d ' ')
        local flow=$(grep -A 10 '"type": "vless"' "$config_file" | grep -o '"flow": "[^"]*"' | head -1 | cut -d'"' -f4)
        local server_name=$(grep -A 30 '"type": "vless"' "$config_file" | grep -o '"server_name": "[^"]*"' | head -1 | cut -d'"' -f4)
        local public_key=$(grep -A 30 '"reality"' "$config_file" | grep -o '"public_key": "[^"]*"' | head -1 | cut -d'"' -f4)
        local short_id=$(grep -A 30 '"reality"' "$config_file" | grep -o '"short_id": \["[^"]*"\]' | head -1 | cut -d'"' -f2)
        
        echo -e "  服务器地址: ${GREEN}$IP_ADDRESS${NC}"
        echo -e "  端口: ${GREEN}$vless_port${NC}"
        echo -e "  UUID: ${GREEN}$vless_uuid${NC}"
        echo -e "  Flow: ${GREEN}$flow${NC}"
        echo -e "  传输协议: ${GREEN}TCP${NC}"
        echo -e "  传输层安全: ${GREEN}Reality${NC}"
        echo -e "  SNI: ${GREEN}$server_name${NC}"
        echo -e "  Fingerprint: ${GREEN}chrome${NC}"
        echo -e "  PublicKey: ${GREEN}$public_key${NC}"
        echo -e "  ShortID: ${GREEN}$short_id${NC}"
        echo -e "  SpiderX: ${GREEN}/${NC}"
        echo
    fi
    
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
    local protocol_choice="$1"  # 可选参数：指定协议类型
    
    # 检测配置文件中的所有协议
    local has_vmess=$(grep -q '"type": "vmess"' "$config_file" && echo "true" || echo "false")
    local has_hysteria2=$(grep -q '"type": "hysteria2"' "$config_file" && echo "true" || echo "false")
    
    # 如果是多协议配置且没有指定协议，显示所有协议
    local protocol_count=0
    [[ "$has_vmess" == "true" ]] && ((protocol_count++))
    [[ "$has_hysteria2" == "true" ]] && ((protocol_count++))
    
    if [[ $protocol_count -gt 1 && -z "$protocol_choice" ]]; then
        # 多协议配置，显示所有协议的链接
        echo "# 多协议配置 - 所有协议分享链接"
        echo
        
        if [[ "$has_vmess" == "true" ]]; then
            echo "【VMess WebSocket】"
            generate_single_protocol_link "vmess"
            echo
        fi
        
        if [[ "$has_hysteria2" == "true" ]]; then
            echo "【Hysteria2】"
            generate_single_protocol_link "hysteria2"
            echo
        fi
        return
    fi
    
    # 单协议配置或指定了协议类型
    local protocol_type="$protocol_choice"
    if [[ -z "$protocol_type" ]]; then
        protocol_type=$(grep -o '"type": "[^"]*"' "$config_file" | head -1 | cut -d'"' -f4)
    fi
    
    generate_single_protocol_link "$protocol_type"
}

# 生成单个协议的分享链接
generate_single_protocol_link() {
    local protocol_type="$1"
    local config_file="$SINGBOX_CONFIG_DIR/config.json"
    
    case $protocol_type in
        "vmess")
            # 获取VMess相关配置
            local vmess_inbound=$(grep -A 20 '"type": "vmess"' "$config_file")
            local listen_port=$(echo "$vmess_inbound" | grep -o '"listen_port": [0-9]*' | cut -d':' -f2 | tr -d ' ')
            local uuid=$(echo "$vmess_inbound" | grep -o '"uuid": "[^"]*"' | cut -d'"' -f4)
            local ws_path=$(echo "$vmess_inbound" | grep -A 10 '"transport"' | grep -o '"path": "[^"]*"' | cut -d'"' -f4)
            local tls_enabled=$(echo "$vmess_inbound" | grep -q '"tls"' && echo "tls" || echo "none")
            
            local vmess_json='{"v":"2","ps":"VMess-WS-'$IP_ADDRESS'","add":"'$IP_ADDRESS'","port":"'$listen_port'","id":"'$uuid'","aid":"0","scy":"auto","net":"ws","type":"none","host":"","path":"'$ws_path'","tls":"'$tls_enabled'","sni":"","alpn":""}'
            local vmess_link="vmess://$(echo -n "$vmess_json" | base64 -w 0)"
            echo "$vmess_link"
            ;;
        "hysteria2")
            # 获取Hysteria2相关配置
            local hy2_inbound=$(grep -A 20 '"type": "hysteria2"' "$config_file")
            local listen_port=$(echo "$hy2_inbound" | grep -o '"listen_port": [0-9]*' | cut -d':' -f2 | tr -d ' ')
            local password=$(echo "$hy2_inbound" | grep -o '"password": "[^"]*"' | cut -d'"' -f4)
            
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
    
    # 检测配置文件中的所有协议
    local has_vmess=$(grep -q '"type": "vmess"' "$config_file" && echo "true" || echo "false")
    local has_hysteria2=$(grep -q '"type": "hysteria2"' "$config_file" && echo "true" || echo "false")
    
    local protocol_count=0
    [[ "$has_vmess" == "true" ]] && ((protocol_count++))
    [[ "$has_hysteria2" == "true" ]] && ((protocol_count++))
    
    local current_protocols=""
    [[ "$has_vmess" == "true" ]] && current_protocols="${current_protocols}VMess WebSocket "
    [[ "$has_hysteria2" == "true" ]] && current_protocols="${current_protocols}Hysteria2 "
    
    while true; do
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                配置分享${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        if [[ $protocol_count -gt 1 ]]; then
            echo -e "  当前协议: ${GREEN}多协议配置 ($current_protocols)${NC}"
        else
            echo -e "  当前协议: ${GREEN}$current_protocols${NC}"
        fi
        echo
        
        if [[ $protocol_count -gt 1 ]]; then
            echo -e "  ${GREEN}1.${NC} 显示所有协议连接链接"
            echo -e "  ${GREEN}2.${NC} 选择协议生成二维码"
            echo -e "  ${GREEN}3.${NC} 保存所有配置到文件"
            echo -e "  ${GREEN}4.${NC} 显示详细连接信息"
            echo -e "  ${GREEN}5.${NC} 选择单个协议分享"
        else
            echo -e "  ${GREEN}1.${NC} 显示连接链接"
            echo -e "  ${GREEN}2.${NC} 生成二维码"
            echo -e "  ${GREEN}3.${NC} 保存配置到文件"
            echo -e "  ${GREEN}4.${NC} 显示详细连接信息"
        fi
        echo -e "  ${GREEN}0.${NC} 返回主菜单"
        echo
        
        if [[ $protocol_count -gt 1 ]]; then
            read -p "请选择操作 [0-5]: " choice
        else
            read -p "请选择操作 [0-4]: " choice
        fi
        
        case $choice in
            1)
                echo
                log_info "连接链接:"
                local share_links=$(generate_share_links)
                echo -e "${GREEN}$share_links${NC}"
                echo
                echo "请复制上述链接到客户端使用"
                ;;
            2)
                if [[ $protocol_count -gt 1 ]]; then
                    # 多协议配置，让用户选择协议生成二维码
                    echo
                    echo "请选择要生成二维码的协议:"
                    local menu_num=1
                    [[ "$has_vmess" == "true" ]] && echo "  ${menu_num}. VMess WebSocket" && ((menu_num++))
                    [[ "$has_hysteria2" == "true" ]] && echo "  ${menu_num}. Hysteria2" && ((menu_num++))
                    echo "  0. 返回"
                    echo
                    read -p "请选择协议 [0-$((menu_num-1))]: " protocol_choice
                    
                    local selected_protocol=""
                    local current_num=1
                    if [[ "$has_vmess" == "true" ]]; then
                        [[ "$protocol_choice" == "$current_num" ]] && selected_protocol="vmess"
                        ((current_num++))
                    fi
                    if [[ "$has_hysteria2" == "true" ]]; then
                        [[ "$protocol_choice" == "$current_num" ]] && selected_protocol="hysteria2"
                        ((current_num++))
                    fi
                    
                    if [[ -n "$selected_protocol" ]]; then
                        echo
                        log_info "二维码:"
                        local share_link=$(generate_share_links "$selected_protocol")
                        echo
                        generate_qrcode "$share_link"
                        echo
                        echo "请使用客户端扫描上述二维码"
                    elif [[ "$protocol_choice" != "0" ]]; then
                        log_error "无效选择"
                    fi
                else
                    # 单协议配置
                    echo
                    log_info "二维码:"
                    local share_link=$(generate_share_links)
                    echo
                    generate_qrcode "$share_link"
                    echo
                    echo "请使用客户端扫描上述二维码"
                fi
                ;;
            3)
                local output_file="/root/sing-box-config-$(date +%Y%m%d_%H%M%S).txt"
                local share_links=$(generate_share_links)
                
                echo "协议配置: $current_protocols" > "$output_file"
                echo "服务器地址: $IP_ADDRESS" >> "$output_file"
                echo "连接链接:" >> "$output_file"
                echo "$share_links" >> "$output_file"
                echo "生成时间: $(date)" >> "$output_file"
                
                log_info "配置已保存到: $output_file"
                ;;
            4)
                show_connection_info
                return
                ;;
            5)
                if [[ $protocol_count -gt 1 ]]; then
                    # 选择单个协议分享
                    echo
                    echo "请选择要分享的协议:"
                    local menu_num=1
                    [[ "$has_vmess" == "true" ]] && echo "  ${menu_num}. VMess WebSocket" && ((menu_num++))
                    [[ "$has_hysteria2" == "true" ]] && echo "  ${menu_num}. Hysteria2" && ((menu_num++))
                    echo "  0. 返回"
                    echo
                    read -p "请选择协议 [0-$((menu_num-1))]: " protocol_choice
                    
                    local selected_protocol=""
                    local current_num=1
                    if [[ "$has_vmess" == "true" ]]; then
                        [[ "$protocol_choice" == "$current_num" ]] && selected_protocol="vmess"
                        ((current_num++))
                    fi
                    if [[ "$has_hysteria2" == "true" ]]; then
                        [[ "$protocol_choice" == "$current_num" ]] && selected_protocol="hysteria2"
                        ((current_num++))
                    fi
                    
                    if [[ -n "$selected_protocol" ]]; then
                        echo
                        log_info "${selected_protocol^^} 协议连接链接:"
                        local share_link=$(generate_share_links "$selected_protocol")
                        echo -e "${GREEN}$share_link${NC}"
                        echo
                        echo "请复制上述链接到客户端使用"
                    elif [[ "$protocol_choice" != "0" ]]; then
                        log_error "无效选择"
                    fi
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
    
    # 清除当前协议和端口信息
    CURRENT_PROTOCOL=""
    CURRENT_PORT=""
    
    log_info "配置清理完成，现在可以重新选择协议安装"
    echo
    
    # 显示协议选择菜单
    while true; do
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}                选择要安装的协议${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo
        echo -e "  ${GREEN}1.${NC} 单独安装 VLESS Reality (推荐)"
        echo -e "  ${GREEN}2.${NC} 单独安装 VMess WebSocket"
        echo -e "  ${GREEN}3.${NC} 单独安装 Hysteria2"
        echo -e "  ${GREEN}4.${NC} 一键安装所有协议 (VLESS Reality + VMess WS + Hysteria2)"
        echo -e "  ${RED}0.${NC} 返回主菜单"
        echo
        
        read -p "请选择要安装的协议 [0-4]: " choice
        
        case $choice in
            1)
                install_vless_reality
                return
                ;;
            2)
                install_vmess_ws
                return
                ;;
            3)
                install_hysteria2
                return
                ;;
            4)
                install_all_protocols
                return
                ;;
            0)
                return
                ;;
            *)
                log_error "无效选择，请重新输入"
                echo
                ;;
        esac
    done
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