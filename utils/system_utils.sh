#!/bin/bash

# 系统工具模块
# 提供系统信息获取、网络工具、文件操作等通用功能
# 版本: v2.4.14

set -euo pipefail

# 系统工具模块信息
SYSTEM_UTILS_VERSION="v2.4.14"
SYSTEM_CACHE_DIR="${SINGBOX_CACHE_DIR:-/tmp/singbox}"
SYSTEM_CACHE_TTL="${SYSTEM_CACHE_TTL:-300}"  # 5分钟

# 系统信息缓存
declare -A SYSTEM_CACHE=()

# 引入依赖模块
source "${BASH_SOURCE%/*}/../core/logger.sh" 2>/dev/null || {
    log_info() { echo "[INFO] $1"; }
    log_warn() { echo "[WARN] $1" >&2; }
    log_error() { echo "[ERROR] $1" >&2; }
    log_debug() { [[ "${DEBUG:-}" == "true" ]] && echo "[DEBUG] $1" >&2; }
}

# 初始化系统工具
init_system_utils() {
    log_info "初始化系统工具模块 (版本: $SYSTEM_UTILS_VERSION)" "system"
    
    # 创建缓存目录
    [[ ! -d "$SYSTEM_CACHE_DIR" ]] && mkdir -p "$SYSTEM_CACHE_DIR"
    
    # 检测系统基本信息
    detect_system_info
    
    log_debug "系统工具模块初始化完成" "system"
}

# 检测系统信息
detect_system_info() {
    log_debug "检测系统信息" "system"
    
    # 操作系统
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        SYSTEM_CACHE["os_name"]="$NAME"
        SYSTEM_CACHE["os_version"]="$VERSION_ID"
        SYSTEM_CACHE["os_id"]="$ID"
    else
        SYSTEM_CACHE["os_name"]="$(uname -s)"
        SYSTEM_CACHE["os_version"]="unknown"
        SYSTEM_CACHE["os_id"]="unknown"
    fi
    
    # 架构
    SYSTEM_CACHE["arch"]="$(uname -m)"
    
    # 内核版本
    SYSTEM_CACHE["kernel"]="$(uname -r)"
    
    # CPU信息
    if [[ -f /proc/cpuinfo ]]; then
        SYSTEM_CACHE["cpu_cores"]="$(nproc)"
        SYSTEM_CACHE["cpu_model"]="$(grep 'model name' /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)"
    else
        SYSTEM_CACHE["cpu_cores"]="unknown"
        SYSTEM_CACHE["cpu_model"]="unknown"
    fi
    
    # 内存信息
    if [[ -f /proc/meminfo ]]; then
        local total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        SYSTEM_CACHE["memory_total"]="$((total_mem / 1024))"  # MB
    else
        SYSTEM_CACHE["memory_total"]="unknown"
    fi
    
    log_debug "系统信息检测完成" "system"
}

# 获取系统信息
get_system_info() {
    local key="${1:-}"
    
    if [[ -n "$key" ]]; then
        echo "${SYSTEM_CACHE[$key]:-unknown}"
    else
        # 返回所有系统信息
        echo "=== 系统信息 ==="
        echo "操作系统: ${SYSTEM_CACHE["os_name"]} ${SYSTEM_CACHE["os_version"]}"
        echo "系统ID: ${SYSTEM_CACHE["os_id"]}"
        echo "架构: ${SYSTEM_CACHE["arch"]}"
        echo "内核: ${SYSTEM_CACHE["kernel"]}"
        echo "CPU: ${SYSTEM_CACHE["cpu_model"]} (${SYSTEM_CACHE["cpu_cores"]} 核心)"
        echo "内存: ${SYSTEM_CACHE["memory_total"]} MB"
    fi
}

# 检查命令是否存在
command_exists() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1
}

# 检查多个命令
check_commands() {
    local commands=("$@")
    local missing_commands=()
    
    for cmd in "${commands[@]}"; do
        if ! command_exists "$cmd"; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "缺少命令: ${missing_commands[*]}" "system"
        return 1
    fi
    
    return 0
}

# 安装缺失的包
install_packages() {
    local packages=("$@")
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        return 0
    fi
    
    log_info "安装软件包: ${packages[*]}" "system"
    
    local os_id="${SYSTEM_CACHE["os_id"]:-unknown}"
    
    case "$os_id" in
        "ubuntu"|"debian")
            apt-get update && apt-get install -y "${packages[@]}"
            ;;
        "centos"|"rhel"|"fedora")
            if command_exists "dnf"; then
                dnf install -y "${packages[@]}"
            elif command_exists "yum"; then
                yum install -y "${packages[@]}"
            else
                log_error "无法找到包管理器" "system"
                return 1
            fi
            ;;
        "alpine")
            apk add "${packages[@]}"
            ;;
        "arch")
            pacman -S --noconfirm "${packages[@]}"
            ;;
        *)
            log_error "不支持的操作系统: $os_id" "system"
            return 1
            ;;
    esac
    
    log_info "软件包安装完成" "system"
}

# 获取公网IP
get_public_ip() {
    local cache_key="public_ip"
    local cache_file="${SYSTEM_CACHE_DIR}/${cache_key}"
    
    # 检查缓存
    if [[ -f "$cache_file" ]]; then
        local cache_time=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)
        local current_time=$(date +%s)
        
        if [[ $((current_time - cache_time)) -lt $SYSTEM_CACHE_TTL ]]; then
            cat "$cache_file"
            return 0
        fi
    fi
    
    log_debug "获取公网IP地址" "system"
    
    local ip_services=(
        "https://ipv4.icanhazip.com"
        "https://api.ipify.org"
        "https://checkip.amazonaws.com"
        "https://ipinfo.io/ip"
        "https://ifconfig.me/ip"
    )
    
    for service in "${ip_services[@]}"; do
        local ip
        if ip=$(curl -s --connect-timeout 5 --max-time 10 "$service" 2>/dev/null); then
            # 验证IP格式
            if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                echo "$ip" | tee "$cache_file"
                log_debug "公网IP: $ip" "system"
                return 0
            fi
        fi
    done
    
    log_warn "无法获取公网IP地址" "system"
    return 1
}

# 获取本地IP
get_local_ip() {
    local interface="${1:-}"
    
    if [[ -n "$interface" ]]; then
        # 获取指定接口的IP
        ip addr show "$interface" 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1 | head -1
    else
        # 获取默认路由接口的IP
        local default_interface
        default_interface=$(ip route | grep '^default' | awk '{print $5}' | head -1)
        
        if [[ -n "$default_interface" ]]; then
            get_local_ip "$default_interface"
        else
            # 备用方法
            hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1"
        fi
    fi
}

# 检查端口是否被占用
is_port_occupied() {
    local port="$1"
    local protocol="${2:-tcp}"
    
    case "$protocol" in
        "tcp")
            netstat -tlnp 2>/dev/null | grep -q ":${port} " || \
            ss -tlnp 2>/dev/null | grep -q ":${port} "
            ;;
        "udp")
            netstat -ulnp 2>/dev/null | grep -q ":${port} " || \
            ss -ulnp 2>/dev/null | grep -q ":${port} "
            ;;
        *)
            log_error "不支持的协议: $protocol" "system"
            return 1
            ;;
    esac
}

# 获取随机可用端口
get_random_port() {
    local min_port="${1:-10000}"
    local max_port="${2:-65535}"
    local protocol="${3:-tcp}"
    local max_attempts=100
    
    for ((i=0; i<max_attempts; i++)); do
        local port=$((RANDOM % (max_port - min_port + 1) + min_port))
        
        if ! is_port_occupied "$port" "$protocol"; then
            echo "$port"
            return 0
        fi
    done
    
    log_error "无法找到可用端口" "system"
    return 1
}

# 检查网络连通性
check_connectivity() {
    local host="${1:-8.8.8.8}"
    local port="${2:-53}"
    local timeout="${3:-5}"
    
    log_debug "检查网络连通性: $host:$port" "system"
    
    if command_exists "nc"; then
        nc -z -w"$timeout" "$host" "$port" 2>/dev/null
    elif command_exists "telnet"; then
        timeout "$timeout" telnet "$host" "$port" 2>/dev/null | grep -q "Connected"
    else
        # 使用ping作为备用
        ping -c 1 -W "$timeout" "$host" >/dev/null 2>&1
    fi
}

# 检查DNS解析
check_dns_resolution() {
    local domain="${1:-google.com}"
    local dns_server="${2:-}"
    
    log_debug "检查DNS解析: $domain" "system"
    
    if [[ -n "$dns_server" ]]; then
        nslookup "$domain" "$dns_server" >/dev/null 2>&1
    else
        nslookup "$domain" >/dev/null 2>&1 || \
        dig "$domain" >/dev/null 2>&1 || \
        host "$domain" >/dev/null 2>&1
    fi
}

# 获取系统负载
get_system_load() {
    if [[ -f /proc/loadavg ]]; then
        cat /proc/loadavg | awk '{print "1分钟:" $1 " 5分钟:" $2 " 15分钟:" $3}'
    else
        uptime | awk -F'load average:' '{print $2}' | xargs
    fi
}

# 获取内存使用情况
get_memory_usage() {
    if [[ -f /proc/meminfo ]]; then
        local total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        local available=$(grep MemAvailable /proc/meminfo | awk '{print $2}' || echo 0)
        local free=$(grep MemFree /proc/meminfo | awk '{print $2}')
        local buffers=$(grep Buffers /proc/meminfo | awk '{print $2}')
        local cached=$(grep '^Cached:' /proc/meminfo | awk '{print $2}')
        
        if [[ $available -eq 0 ]]; then
            available=$((free + buffers + cached))
        fi
        
        local used=$((total - available))
        local usage_percent=$((used * 100 / total))
        
        echo "总内存: $((total / 1024))MB, 已用: $((used / 1024))MB (${usage_percent}%), 可用: $((available / 1024))MB"
    else
        echo "无法获取内存信息"
    fi
}

# 获取磁盘使用情况
get_disk_usage() {
    local path="${1:-/}"
    
    if command_exists "df"; then
        df -h "$path" | tail -1 | awk '{print "总空间:" $2 " 已用:" $3 " 可用:" $4 " 使用率:" $5}'
    else
        echo "无法获取磁盘信息"
    fi
}

# 获取CPU使用率
get_cpu_usage() {
    local interval="${1:-1}"
    
    if [[ -f /proc/stat ]]; then
        # 读取两次CPU统计信息计算使用率
        local cpu1=($(grep '^cpu ' /proc/stat))
        sleep "$interval"
        local cpu2=($(grep '^cpu ' /proc/stat))
        
        # 计算CPU使用率
        local idle1=$((cpu1[4] + cpu1[5]))
        local total1=0
        for val in "${cpu1[@]:1}"; do
            total1=$((total1 + val))
        done
        
        local idle2=$((cpu2[4] + cpu2[5]))
        local total2=0
        for val in "${cpu2[@]:1}"; do
            total2=$((total2 + val))
        done
        
        local idle_diff=$((idle2 - idle1))
        local total_diff=$((total2 - total1))
        
        if [[ $total_diff -gt 0 ]]; then
            local usage=$((100 * (total_diff - idle_diff) / total_diff))
            echo "${usage}%"
        else
            echo "0%"
        fi
    else
        echo "无法获取CPU使用率"
    fi
}

# 获取网络接口信息
get_network_interfaces() {
    if command_exists "ip"; then
        ip addr show | grep -E '^[0-9]+:' | awk '{print $2}' | sed 's/:$//'
    elif [[ -d /sys/class/net ]]; then
        ls /sys/class/net/
    else
        ifconfig -a 2>/dev/null | grep -E '^[a-zA-Z0-9]+:' | awk '{print $1}' | sed 's/:$//'
    fi
}

# 获取进程信息
get_process_info() {
    local process_name="$1"
    
    if command_exists "pgrep"; then
        local pids
        pids=$(pgrep -f "$process_name" 2>/dev/null || true)
        
        if [[ -n "$pids" ]]; then
            echo "进程ID: $pids"
            ps -p "$pids" -o pid,ppid,user,cpu,mem,cmd --no-headers 2>/dev/null || true
        else
            echo "进程未运行: $process_name"
        fi
    else
        ps aux | grep "$process_name" | grep -v grep || echo "进程未运行: $process_name"
    fi
}

# 创建安全的临时文件
create_temp_file() {
    local prefix="${1:-singbox}"
    local suffix="${2:-tmp}"
    
    local temp_file
    temp_file=$(mktemp "/tmp/${prefix}.XXXXXX.${suffix}")
    
    # 设置安全权限
    chmod 600 "$temp_file"
    
    echo "$temp_file"
}

# 创建安全的临时目录
create_temp_dir() {
    local prefix="${1:-singbox}"
    
    local temp_dir
    temp_dir=$(mktemp -d "/tmp/${prefix}.XXXXXX")
    
    # 设置安全权限
    chmod 700 "$temp_dir"
    
    echo "$temp_dir"
}

# 安全删除文件
secure_delete() {
    local file="$1"
    
    if [[ -f "$file" ]]; then
        # 覆盖文件内容
        if command_exists "shred"; then
            shred -vfz -n 3 "$file"
        else
            # 简单覆盖
            dd if=/dev/zero of="$file" bs=1024 count=1 2>/dev/null || true
            rm -f "$file"
        fi
        
        log_debug "安全删除文件: $file" "system"
    fi
}

# 验证文件校验和
verify_checksum() {
    local file="$1"
    local expected_checksum="$2"
    local algorithm="${3:-sha256}"
    
    if [[ ! -f "$file" ]]; then
        log_error "文件不存在: $file" "system"
        return 1
    fi
    
    local actual_checksum
    case "$algorithm" in
        "md5")
            actual_checksum=$(md5sum "$file" | cut -d' ' -f1)
            ;;
        "sha1")
            actual_checksum=$(sha1sum "$file" | cut -d' ' -f1)
            ;;
        "sha256")
            actual_checksum=$(sha256sum "$file" | cut -d' ' -f1)
            ;;
        "sha512")
            actual_checksum=$(sha512sum "$file" | cut -d' ' -f1)
            ;;
        *)
            log_error "不支持的校验算法: $algorithm" "system"
            return 1
            ;;
    esac
    
    if [[ "$actual_checksum" == "$expected_checksum" ]]; then
        log_debug "文件校验成功: $file" "system"
        return 0
    else
        log_error "文件校验失败: $file (期望: $expected_checksum, 实际: $actual_checksum)" "system"
        return 1
    fi
}

# 等待用户确认
wait_for_confirmation() {
    local message="${1:-继续操作吗?}"
    local default="${2:-n}"
    
    while true; do
        read -p "$message [y/N]: " -r response
        response="${response:-$default}"
        
        case "$response" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                echo "请输入 y 或 n"
                ;;
        esac
    done
}

# 显示进度条
show_progress() {
    local current="$1"
    local total="$2"
    local width="${3:-50}"
    local message="${4:-}"
    
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r[%s%s] %d%% %s" \
        "$(printf '%*s' "$filled" '' | tr ' ' '=')"\
        "$(printf '%*s' "$empty" '')"\
        "$percentage" \
        "$message"
    
    if [[ $current -eq $total ]]; then
        echo
    fi
}

# 清理系统缓存
cleanup_system_cache() {
    log_info "清理系统缓存" "system"
    
    # 清理临时文件
    find "$SYSTEM_CACHE_DIR" -type f -mtime +1 -delete 2>/dev/null || true
    
    # 清理内存缓存
    SYSTEM_CACHE=()
    
    log_info "系统缓存清理完成" "system"
}

# 显示系统状态
show_system_status() {
    echo "=== 系统状态 ==="
    get_system_info
    echo ""
    echo "系统负载: $(get_system_load)"
    echo "内存使用: $(get_memory_usage)"
    echo "磁盘使用: $(get_disk_usage)"
    echo "CPU使用率: $(get_cpu_usage)"
    echo "公网IP: $(get_public_ip 2>/dev/null || echo '获取失败')"
    echo "本地IP: $(get_local_ip)"
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_system_utils
    show_system_status
fi