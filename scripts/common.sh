#!/bin/bash

# 公共函数库
# 提供通用的工具函数

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_debug() {
    if [[ "${DEBUG:-}" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1" | tee -a "$LOG_FILE"
    fi
}

# 生成随机字符串
generate_random_string() {
    local length=${1:-16}
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$length"
}

# 生成随机数字
generate_random_number() {
    local min=${1:-1000}
    local max=${2:-9999}
    shuf -i "$min-$max" -n 1
}

# 生成 UUID
generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        # 如果没有 uuidgen，使用 /proc/sys/kernel/random/uuid
        if [[ -f /proc/sys/kernel/random/uuid ]]; then
            cat /proc/sys/kernel/random/uuid
        else
            # 最后的备选方案：使用随机数生成
            printf '%08x-%04x-%04x-%04x-%012x\n' \
                $((RANDOM * RANDOM)) \
                $((RANDOM % 65536)) \
                $(((RANDOM % 4096) | 16384)) \
                $(((RANDOM % 16384) | 32768)) \
                $((RANDOM * RANDOM * RANDOM))
        fi
    fi
}

# 检查端口是否被占用
check_port() {
    local port=$1
    if ss -tuln | grep -q ":$port "; then
        return 0  # 端口被占用
    else
        return 1  # 端口未被占用
    fi
}

# 获取可用端口
get_available_port() {
    local start_port=${1:-10000}
    local end_port=${2:-65535}
    
    for ((port=start_port; port<=end_port; port++)); do
        if ! check_port "$port"; then
            echo "$port"
            return 0
        fi
    done
    
    log_error "在范围 $start_port-$end_port 内未找到可用端口"
    return 1
}

# 验证 IP 地址
validate_ip() {
    local ip=$1
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ $ip =~ $regex ]]; then
        IFS='.' read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if [[ $i -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# 获取公网 IP
get_public_ip() {
    local ip
    
    # 尝试多个服务获取公网 IP
    for service in "curl -s https://ipv4.icanhazip.com" \
                   "curl -s https://api.ipify.org" \
                   "curl -s https://checkip.amazonaws.com" \
                   "wget -qO- https://ipv4.icanhazip.com"; do
        ip=$(eval "$service" 2>/dev/null | tr -d '\n\r')
        if validate_ip "$ip"; then
            echo "$ip"
            return 0
        fi
    done
    
    log_error "无法获取公网 IP 地址"
    return 1
}

# 检查网络连通性
check_network() {
    local test_urls=("google.com" "cloudflare.com" "github.com")
    
    for url in "${test_urls[@]}"; do
        if ping -c 1 -W 3 "$url" >/dev/null 2>&1; then
            return 0
        fi
    done
    
    log_error "网络连接检查失败"
    return 1
}

# 确认操作
confirm() {
    local message=${1:-"是否继续?"}
    local default=${2:-"n"}
    
    if [[ "$default" == "y" ]]; then
        read -p "$message [Y/n]: " -r reply
        reply=${reply:-"y"}
    else
        read -p "$message [y/N]: " -r reply
        reply=${reply:-"n"}
    fi
    
    case "$reply" in
        [Yy]|[Yy][Ee][Ss])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# 等待用户按键
press_any_key() {
    local message=${1:-"按任意键继续..."}
    read -n 1 -s -r -p "$message"
    echo
}

# 显示进度条
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    
    printf "\r["
    printf "%*s" "$completed" | tr ' ' '='
    printf "%*s" "$((width - completed))" | tr ' ' '-'
    printf "] %d%% (%d/%d)" "$percentage" "$current" "$total"
    
    if [[ $current -eq $total ]]; then
        echo
    fi
}

# 创建目录
create_directory() {
    local dir=$1
    local mode=${2:-755}
    
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        chmod "$mode" "$dir"
        log_info "创建目录: $dir"
    fi
}

# 备份文件
backup_file() {
    local file=$1
    local backup_dir=${2:-"/tmp/sing-box-backup"}
    
    if [[ -f "$file" ]]; then
        create_directory "$backup_dir"
        local backup_file="$backup_dir/$(basename "$file").$(date +%Y%m%d_%H%M%S).bak"
        cp "$file" "$backup_file"
        log_info "备份文件: $file -> $backup_file"
    fi
}

# 下载文件
download_file() {
    local url=$1
    local output=$2
    local max_retries=${3:-3}
    
    for ((i=1; i<=max_retries; i++)); do
        log_info "下载文件 (尝试 $i/$max_retries): $url"
        
        if command -v curl >/dev/null 2>&1; then
            if curl -fsSL -o "$output" "$url"; then
                log_success "文件下载成功: $output"
                return 0
            fi
        elif command -v wget >/dev/null 2>&1; then
            if wget -q -O "$output" "$url"; then
                log_success "文件下载成功: $output"
                return 0
            fi
        else
            log_error "未找到 curl 或 wget 命令"
            return 1
        fi
        
        if [[ $i -lt $max_retries ]]; then
            log_warn "下载失败，3秒后重试..."
            sleep 3
        fi
    done
    
    log_error "文件下载失败: $url"
    return 1
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 获取系统信息
get_system_info() {
    echo "系统信息:"
    echo "  操作系统: $(uname -s)"
    echo "  内核版本: $(uname -r)"
    echo "  架构: $(uname -m)"
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "  发行版: $PRETTY_NAME"
    fi
    
    echo "  内存: $(free -h | awk '/^Mem:/ {print $2}')"
    echo "  磁盘: $(df -h / | awk 'NR==2 {print $4}') 可用"
}

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        log_info "请使用 sudo 运行此脚本"
        exit 1
    fi
}

# 清理临时文件
cleanup() {
    local temp_dir=${1:-"/tmp/sing-box-temp"}
    if [[ -d "$temp_dir" ]]; then
        rm -rf "$temp_dir"
        log_info "清理临时文件: $temp_dir"
    fi
}

# 设置信号处理
setup_signal_handlers() {
    trap 'log_warn "收到中断信号，正在清理..."; cleanup; exit 130' INT TERM
}

# 初始化日志
init_log() {
    local log_file=${1:-"$LOG_FILE"}
    local log_dir=$(dirname "$log_file")
    
    create_directory "$log_dir"
    
    # 创建日志文件
    touch "$log_file"
    
    # 记录开始时间
    echo "=== Sing-box 安装日志 - $(date) ===" >> "$log_file"
}