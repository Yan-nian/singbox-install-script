#!/bin/bash

# 网络工具模块
# 提供网络检测、端口管理、连接测试等功能
# 版本: v2.4.14

set -euo pipefail

# 网络工具模块信息
NETWORK_UTILS_VERSION="v2.4.14"
NETWORK_CACHE_DIR="${SINGBOX_CACHE_DIR:-/tmp/singbox}/network"
NETWORK_CACHE_TTL="${NETWORK_CACHE_TTL:-60}"  # 1分钟

# 网络配置
DEFAULT_TIMEOUT="${NETWORK_TIMEOUT:-10}"
DEFAULT_RETRIES="${NETWORK_RETRIES:-3}"
DEFAULT_DNS_SERVERS=("8.8.8.8" "1.1.1.1" "223.5.5.5" "114.114.114.114")
DEFAULT_TEST_HOSTS=("google.com" "github.com" "cloudflare.com")

# 端口范围定义
PORT_RANGES=(
    "system:1-1023"
    "registered:1024-49151"
    "dynamic:49152-65535"
    "singbox:10000-20000"
)

# 网络统计
declare -A NETWORK_STATS=(
    ["connectivity_checks"]="0"
    ["dns_queries"]="0"
    ["port_scans"]="0"
    ["speed_tests"]="0"
    ["ping_tests"]="0"
)

# 引入依赖模块
source "${BASH_SOURCE%/*}/../core/logger.sh" 2>/dev/null || {
    log_info() { echo "[INFO] $1"; }
    log_warn() { echo "[WARN] $1" >&2; }
    log_error() { echo "[ERROR] $1" >&2; }
    log_debug() { [[ "${DEBUG:-}" == "true" ]] && echo "[DEBUG] $1" >&2; }
}

# 初始化网络工具
init_network_utils() {
    log_info "初始化网络工具模块 (版本: $NETWORK_UTILS_VERSION)" "network"
    
    # 创建缓存目录
    [[ ! -d "$NETWORK_CACHE_DIR" ]] && mkdir -p "$NETWORK_CACHE_DIR"
    
    # 检查必需的网络工具
    check_network_tools
    
    log_debug "网络工具模块初始化完成" "network"
}

# 检查网络工具
check_network_tools() {
    local required_tools=("ping" "curl")
    local optional_tools=("wget" "nc" "nmap" "dig" "nslookup" "traceroute" "ss" "netstat")
    local missing_required=()
    local missing_optional=()
    
    # 检查必需工具
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_required+=("$tool")
        fi
    done
    
    # 检查可选工具
    for tool in "${optional_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_optional+=("$tool")
        fi
    done
    
    if [[ ${#missing_required[@]} -gt 0 ]]; then
        log_error "缺少必需的网络工具: ${missing_required[*]}" "network"
        return 1
    fi
    
    if [[ ${#missing_optional[@]} -gt 0 ]]; then
        log_warn "缺少可选的网络工具: ${missing_optional[*]}" "network"
    fi
    
    return 0
}

# 检查网络连通性
check_network_connectivity() {
    local host="${1:-8.8.8.8}"
    local timeout="${2:-$DEFAULT_TIMEOUT}"
    local retries="${3:-$DEFAULT_RETRIES}"
    
    log_debug "检查网络连通性: $host" "network"
    ((NETWORK_STATS["connectivity_checks"]++))
    
    for ((i=1; i<=retries; i++)); do
        if ping -c 1 -W "$timeout" "$host" >/dev/null 2>&1; then
            log_debug "网络连通性检查成功 (第 $i 次尝试)" "network"
            return 0
        fi
        
        if [[ $i -lt $retries ]]; then
            log_debug "网络连通性检查失败，重试中... ($i/$retries)" "network"
            sleep 1
        fi
    done
    
    log_warn "网络连通性检查失败: $host" "network"
    return 1
}

# 检查多个主机的连通性
check_multiple_hosts() {
    local hosts=("${@:-${DEFAULT_TEST_HOSTS[@]}}")
    local success_count=0
    local total_count=${#hosts[@]}
    
    log_info "检查多个主机连通性" "network"
    
    for host in "${hosts[@]}"; do
        if check_network_connectivity "$host" 5 1; then
            echo "✓ $host - 连通"
            ((success_count++))
        else
            echo "✗ $host - 不通"
        fi
    done
    
    local success_rate=$((success_count * 100 / total_count))
    echo "连通性测试结果: $success_count/$total_count (${success_rate}%)"
    
    # 如果成功率低于50%，认为网络有问题
    if [[ $success_rate -lt 50 ]]; then
        log_warn "网络连通性较差，成功率: ${success_rate}%" "network"
        return 1
    fi
    
    return 0
}

# DNS解析测试
test_dns_resolution() {
    local domain="${1:-google.com}"
    local dns_server="${2:-}"
    local timeout="${3:-5}"
    
    log_debug "DNS解析测试: $domain" "network"
    ((NETWORK_STATS["dns_queries"]++))
    
    local dns_cmd=""
    local result=""
    
    if command -v "dig" >/dev/null 2>&1; then
        if [[ -n "$dns_server" ]]; then
            dns_cmd="dig +time=$timeout @$dns_server $domain A +short"
        else
            dns_cmd="dig +time=$timeout $domain A +short"
        fi
        
        result=$(eval "$dns_cmd" 2>/dev/null | head -1)
    elif command -v "nslookup" >/dev/null 2>&1; then
        if [[ -n "$dns_server" ]]; then
            result=$(timeout "$timeout" nslookup "$domain" "$dns_server" 2>/dev/null | grep 'Address:' | tail -1 | awk '{print $2}')
        else
            result=$(timeout "$timeout" nslookup "$domain" 2>/dev/null | grep 'Address:' | tail -1 | awk '{print $2}')
        fi
    else
        log_error "没有可用的DNS查询工具" "network"
        return 1
    fi
    
    if [[ -n "$result" ]] && [[ "$result" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "$result"
        log_debug "DNS解析成功: $domain -> $result" "network"
        return 0
    else
        log_warn "DNS解析失败: $domain" "network"
        return 1
    fi
}

# 测试多个DNS服务器
test_dns_servers() {
    local domain="${1:-google.com}"
    local dns_servers=("${@:2}")
    
    if [[ ${#dns_servers[@]} -eq 0 ]]; then
        dns_servers=("${DEFAULT_DNS_SERVERS[@]}")
    fi
    
    log_info "测试DNS服务器" "network"
    
    echo "域名: $domain"
    echo "DNS服务器测试结果:"
    
    for dns_server in "${dns_servers[@]}"; do
        local start_time=$(date +%s%3N)
        local ip_result
        
        if ip_result=$(test_dns_resolution "$domain" "$dns_server" 3); then
            local end_time=$(date +%s%3N)
            local response_time=$((end_time - start_time))
            echo "✓ $dns_server - $ip_result (${response_time}ms)"
        else
            echo "✗ $dns_server - 解析失败"
        fi
    done
}

# 端口扫描
scan_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-3}"
    local protocol="${4:-tcp}"
    
    log_debug "扫描端口: $host:$port ($protocol)" "network"
    ((NETWORK_STATS["port_scans"]++))
    
    case "$protocol" in
        "tcp")
            if command -v "nc" >/dev/null 2>&1; then
                nc -z -w"$timeout" "$host" "$port" 2>/dev/null
            elif command -v "telnet" >/dev/null 2>&1; then
                timeout "$timeout" telnet "$host" "$port" 2>/dev/null | grep -q "Connected"
            else
                # 使用bash内置的网络功能
                timeout "$timeout" bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null
            fi
            ;;
        "udp")
            if command -v "nc" >/dev/null 2>&1; then
                nc -u -z -w"$timeout" "$host" "$port" 2>/dev/null
            else
                log_warn "UDP端口扫描需要nc工具" "network"
                return 1
            fi
            ;;
        *)
            log_error "不支持的协议: $protocol" "network"
            return 1
            ;;
    esac
}

# 批量端口扫描
scan_ports() {
    local host="$1"
    local ports="$2"  # 格式: "80,443,22" 或 "80-90"
    local protocol="${3:-tcp}"
    local timeout="${4:-3}"
    
    log_info "批量端口扫描: $host" "network"
    
    local port_list=()
    
    # 解析端口列表
    if [[ "$ports" == *"-"* ]]; then
        # 端口范围
        local start_port="${ports%-*}"
        local end_port="${ports#*-}"
        
        for ((port=start_port; port<=end_port; port++)); do
            port_list+=("$port")
        done
    else
        # 端口列表
        IFS=',' read -ra port_list <<< "$ports"
    fi
    
    local open_ports=()
    local closed_ports=()
    
    echo "扫描主机: $host"
    echo "协议: $protocol"
    echo "端口数量: ${#port_list[@]}"
    echo ""
    
    for port in "${port_list[@]}"; do
        if scan_port "$host" "$port" "$timeout" "$protocol"; then
            open_ports+=("$port")
            echo "✓ $port - 开放"
        else
            closed_ports+=("$port")
            echo "✗ $port - 关闭"
        fi
    done
    
    echo ""
    echo "扫描结果:"
    echo "开放端口: ${open_ports[*]:-无}"
    echo "关闭端口: ${#closed_ports[@]} 个"
}

# 获取本地监听端口
get_listening_ports() {
    local protocol="${1:-tcp}"
    
    log_debug "获取本地监听端口 ($protocol)" "network"
    
    if command -v "ss" >/dev/null 2>&1; then
        case "$protocol" in
            "tcp")
                ss -tlnp | grep LISTEN | awk '{print $4}' | cut -d':' -f2 | sort -n
                ;;
            "udp")
                ss -ulnp | awk '{print $4}' | cut -d':' -f2 | sort -n
                ;;
            "all")
                {
                    ss -tlnp | grep LISTEN | awk '{print $4 " (tcp)"}'
                    ss -ulnp | awk '{print $4 " (udp)"}'
                } | cut -d':' -f2 | sort -n
                ;;
        esac
    elif command -v "netstat" >/dev/null 2>&1; then
        case "$protocol" in
            "tcp")
                netstat -tlnp 2>/dev/null | grep LISTEN | awk '{print $4}' | cut -d':' -f2 | sort -n
                ;;
            "udp")
                netstat -ulnp 2>/dev/null | awk '{print $4}' | cut -d':' -f2 | sort -n
                ;;
            "all")
                {
                    netstat -tlnp 2>/dev/null | grep LISTEN | awk '{print $4 " (tcp)"}'
                    netstat -ulnp 2>/dev/null | awk '{print $4 " (udp)"}'
                } | cut -d':' -f2 | sort -n
                ;;
        esac
    else
        log_error "没有可用的端口查询工具" "network"
        return 1
    fi
}

# 查找可用端口
find_available_port() {
    local start_port="${1:-10000}"
    local end_port="${2:-20000}"
    local protocol="${3:-tcp}"
    local count="${4:-1}"
    
    log_debug "查找可用端口: $start_port-$end_port ($protocol)" "network"
    
    local available_ports=()
    local attempts=0
    local max_attempts=$((end_port - start_port + 1))
    
    while [[ ${#available_ports[@]} -lt $count ]] && [[ $attempts -lt $max_attempts ]]; do
        local port=$((RANDOM % (end_port - start_port + 1) + start_port))
        
        # 检查端口是否已在列表中
        local already_found=false
        for found_port in "${available_ports[@]}"; do
            if [[ "$port" == "$found_port" ]]; then
                already_found=true
                break
            fi
        done
        
        if [[ "$already_found" == "false" ]] && ! scan_port "127.0.0.1" "$port" 1 "$protocol"; then
            available_ports+=("$port")
        fi
        
        ((attempts++))
    done
    
    if [[ ${#available_ports[@]} -eq $count ]]; then
        printf '%s\n' "${available_ports[@]}"
        return 0
    else
        log_warn "只找到 ${#available_ports[@]} 个可用端口，需要 $count 个" "network"
        printf '%s\n' "${available_ports[@]}"
        return 1
    fi
}

# 网络延迟测试
ping_test() {
    local host="$1"
    local count="${2:-4}"
    local timeout="${3:-5}"
    
    log_debug "Ping测试: $host" "network"
    ((NETWORK_STATS["ping_tests"]++))
    
    if ! command -v "ping" >/dev/null 2>&1; then
        log_error "ping命令不可用" "network"
        return 1
    fi
    
    echo "Ping测试: $host (发送 $count 个包)"
    
    local ping_result
    ping_result=$(ping -c "$count" -W "$timeout" "$host" 2>/dev/null)
    local ping_exit_code=$?
    
    if [[ $ping_exit_code -eq 0 ]]; then
        echo "$ping_result" | tail -2
        
        # 提取统计信息
        local packet_loss
        packet_loss=$(echo "$ping_result" | grep 'packet loss' | awk '{print $6}' | tr -d '%')
        
        local avg_time
        avg_time=$(echo "$ping_result" | grep 'avg' | awk -F'/' '{print $5}')
        
        echo "数据包丢失率: ${packet_loss}%"
        echo "平均延迟: ${avg_time}ms"
        
        return 0
    else
        echo "Ping测试失败: $host"
        return 1
    fi
}

# 路由跟踪
trace_route() {
    local host="$1"
    local max_hops="${2:-30}"
    
    log_info "路由跟踪: $host" "network"
    
    if command -v "traceroute" >/dev/null 2>&1; then
        traceroute -m "$max_hops" "$host"
    elif command -v "tracert" >/dev/null 2>&1; then
        tracert -h "$max_hops" "$host"
    else
        log_error "没有可用的路由跟踪工具" "network"
        return 1
    fi
}

# 网络速度测试
speed_test() {
    local test_url="${1:-http://speedtest.tele2.net/1MB.zip}"
    local timeout="${2:-30}"
    
    log_info "网络速度测试" "network"
    ((NETWORK_STATS["speed_tests"]++))
    
    if ! command -v "curl" >/dev/null 2>&1; then
        log_error "curl命令不可用" "network"
        return 1
    fi
    
    echo "测试URL: $test_url"
    echo "开始下载测试..."
    
    local start_time=$(date +%s)
    local temp_file
    temp_file=$(mktemp)
    
    # 执行下载测试
    if curl -L --max-time "$timeout" --progress-bar -o "$temp_file" "$test_url" 2>/dev/null; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        local file_size
        file_size=$(stat -c%s "$temp_file" 2>/dev/null || stat -f%z "$temp_file" 2>/dev/null)
        
        if [[ $duration -gt 0 ]] && [[ $file_size -gt 0 ]]; then
            local speed_bps=$((file_size / duration))
            local speed_kbps=$((speed_bps / 1024))
            local speed_mbps=$((speed_kbps / 1024))
            
            echo "下载完成!"
            echo "文件大小: $((file_size / 1024)) KB"
            echo "用时: ${duration} 秒"
            echo "平均速度: ${speed_kbps} KB/s (${speed_mbps} MB/s)"
        else
            echo "无法计算速度"
        fi
        
        rm -f "$temp_file"
        return 0
    else
        echo "下载测试失败"
        rm -f "$temp_file"
        return 1
    fi
}

# 检查网络接口状态
check_interface_status() {
    local interface="${1:-}"
    
    if [[ -z "$interface" ]]; then
        # 显示所有接口
        echo "=== 网络接口状态 ==="
        
        if command -v "ip" >/dev/null 2>&1; then
            ip addr show | grep -E '^[0-9]+:|inet ' | while read -r line; do
                if [[ "$line" =~ ^[0-9]+: ]]; then
                    echo "$line"
                elif [[ "$line" =~ inet ]]; then
                    echo "  $line"
                fi
            done
        else
            ifconfig 2>/dev/null || echo "无法获取接口信息"
        fi
    else
        # 检查特定接口
        if command -v "ip" >/dev/null 2>&1; then
            ip addr show "$interface" 2>/dev/null || echo "接口不存在: $interface"
        else
            ifconfig "$interface" 2>/dev/null || echo "接口不存在: $interface"
        fi
    fi
}

# 获取网络统计信息
get_network_stats() {
    echo "=== 网络工具统计 ==="
    echo "连通性检查: ${NETWORK_STATS["connectivity_checks"]}"
    echo "DNS查询: ${NETWORK_STATS["dns_queries"]}"
    echo "端口扫描: ${NETWORK_STATS["port_scans"]}"
    echo "速度测试: ${NETWORK_STATS["speed_tests"]}"
    echo "Ping测试: ${NETWORK_STATS["ping_tests"]}"
}

# 网络诊断
network_diagnosis() {
    echo "=== 网络诊断 ==="
    
    # 基本连通性测试
    echo "1. 基本连通性测试"
    if check_network_connectivity "8.8.8.8" 5 1; then
        echo "✓ 网络连通正常"
    else
        echo "✗ 网络连通异常"
    fi
    echo ""
    
    # DNS解析测试
    echo "2. DNS解析测试"
    if test_dns_resolution "google.com" "" 5 >/dev/null; then
        echo "✓ DNS解析正常"
    else
        echo "✗ DNS解析异常"
    fi
    echo ""
    
    # 网络接口检查
    echo "3. 网络接口状态"
    check_interface_status
    echo ""
    
    # 监听端口检查
    echo "4. 本地监听端口"
    local listening_ports
    listening_ports=$(get_listening_ports "tcp" | head -10)
    if [[ -n "$listening_ports" ]]; then
        echo "TCP监听端口 (前10个):"
        echo "$listening_ports" | while read -r port; do
            echo "  $port"
        done
    else
        echo "没有TCP监听端口"
    fi
    echo ""
    
    # 路由表检查
    echo "5. 默认路由"
    if command -v "ip" >/dev/null 2>&1; then
        ip route show default 2>/dev/null || echo "无法获取路由信息"
    else
        route -n 2>/dev/null | grep '^0.0.0.0' || echo "无法获取路由信息"
    fi
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_network_utils
    
    case "${1:-diagnosis}" in
        "diagnosis")
            network_diagnosis
            ;;
        "stats")
            get_network_stats
            ;;
        "ping")
            ping_test "${2:-google.com}" "${3:-4}"
            ;;
        "dns")
            test_dns_servers "${2:-google.com}"
            ;;
        "ports")
            get_listening_ports "${2:-tcp}"
            ;;
        "scan")
            scan_ports "${2:-127.0.0.1}" "${3:-22,80,443}"
            ;;
        "speed")
            speed_test
            ;;
        *)
            echo "用法: $0 [diagnosis|stats|ping|dns|ports|scan|speed]"
            exit 1
            ;;
    esac
fi