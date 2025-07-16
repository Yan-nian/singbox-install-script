#!/bin/bash

# 通用函数库
# 提供常用的工具函数

# 日志函数
log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >> "$LOG_FILE" 2>/dev/null || true
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $1" >> "$LOG_FILE" 2>/dev/null || true
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $1" >> "$LOG_FILE" 2>/dev/null || true
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >> "$LOG_FILE" 2>/dev/null || true
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 生成随机字符串
generate_random_string() {
    local length=${1:-16}
    local chars='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local result=''
    
    for ((i=0; i<length; i++)); do
        result+="${chars:RANDOM%${#chars}:1}"
    done
    
    echo "$result"
}

# 生成 UUID
generate_uuid() {
    if command_exists uuidgen; then
        uuidgen
    elif [[ -r /proc/sys/kernel/random/uuid ]]; then
        cat /proc/sys/kernel/random/uuid
    else
        # 使用 openssl 生成
        openssl rand -hex 16 | sed 's/\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.\{12\}\)/\1-\2-\3-\4-\5/'
    fi
}

# 检查端口是否被占用
check_port() {
    local port="$1"
    if ss -tuln | grep -q ":$port "; then
        return 0  # 端口被占用
    else
        return 1  # 端口可用
    fi
}

# 获取随机可用端口
get_random_port() {
    local port
    while true; do
        port=$((RANDOM % 55535 + 10000))
        if ! check_port "$port"; then
            echo "$port"
            break
        fi
    done
}

# 获取公网 IP
get_public_ip() {
    local ip
    ip=$(curl -s --max-time 10 ipv4.icanhazip.com 2>/dev/null || 
         curl -s --max-time 10 ifconfig.me 2>/dev/null || 
         curl -s --max-time 10 ip.sb 2>/dev/null || 
         echo "")
    
    if [[ -n "$ip" ]]; then
        echo "$ip"
    else
        log_warn "无法获取公网 IP"
        echo "127.0.0.1"
    fi
}

# 验证 IP 地址格式
validate_ip() {
    local ip="$1"
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ $ip =~ $regex ]]; then
        local IFS='.'
        local -a octets=($ip)
        for octet in "${octets[@]}"; do
            if ((octet > 255)); then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# 验证域名格式
validate_domain() {
    local domain="$1"
    local regex='^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$'
    
    if [[ $domain =~ $regex ]] && [[ ${#domain} -le 253 ]]; then
        return 0
    else
        return 1
    fi
}

# 验证端口范围
validate_port() {
    local port="$1"
    if [[ "$port" =~ ^[0-9]+$ ]] && ((port >= 1 && port <= 65535)); then
        return 0
    else
        return 1
    fi
}

# 检查网络连通性
check_network() {
    local host="${1:-8.8.8.8}"
    local timeout="${2:-5}"
    
    if ping -c 1 -W "$timeout" "$host" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 检查 DNS 解析
check_dns() {
    local domain="${1:-google.com}"
    
    if nslookup "$domain" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 获取服务状态
get_service_status() {
    local service="$1"
    
    if systemctl is-active "$service" >/dev/null 2>&1; then
        echo "running"
    elif systemctl is-enabled "$service" >/dev/null 2>&1; then
        echo "stopped"
    else
        echo "disabled"
    fi
}

# 启动服务
start_service() {
    local service="$1"
    
    log_info "启动服务: $service"
    if systemctl start "$service"; then
        log_success "服务启动成功: $service"
        return 0
    else
        log_error "服务启动失败: $service"
        return 1
    fi
}

# 停止服务
stop_service() {
    local service="$1"
    
    log_info "停止服务: $service"
    if systemctl stop "$service"; then
        log_success "服务停止成功: $service"
        return 0
    else
        log_error "服务停止失败: $service"
        return 1
    fi
}

# 重启服务
restart_service() {
    local service="$1"
    
    log_info "重启服务: $service"
    if systemctl restart "$service"; then
        log_success "服务重启成功: $service"
        return 0
    else
        log_error "服务重启失败: $service"
        return 1
    fi
}

# 重新加载服务配置
reload_service() {
    local service="$1"
    
    log_info "重新加载服务配置: $service"
    if systemctl reload "$service"; then
        log_success "配置重新加载成功: $service"
        return 0
    else
        log_warn "配置重新加载失败，尝试重启服务"
        restart_service "$service"
    fi
}

# 启用服务开机自启
enable_service() {
    local service="$1"
    
    log_info "启用服务开机自启: $service"
    if systemctl enable "$service"; then
        log_success "开机自启启用成功: $service"
        return 0
    else
        log_error "开机自启启用失败: $service"
        return 1
    fi
}

# 禁用服务开机自启
disable_service() {
    local service="$1"
    
    log_info "禁用服务开机自启: $service"
    if systemctl disable "$service"; then
        log_success "开机自启禁用成功: $service"
        return 0
    else
        log_error "开机自启禁用失败: $service"
        return 1
    fi
}

# 验证 JSON 格式
validate_json() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        log_error "文件不存在: $file"
        return 1
    fi
    
    if command_exists jq; then
        if jq empty "$file" >/dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    elif "$SINGBOX_BINARY" check -c "$file" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 备份文件
backup_file() {
    local file="$1"
    local backup_dir="${2:-$WORK_DIR/backup}"
    
    if [[ ! -f "$file" ]]; then
        log_warn "文件不存在，跳过备份: $file"
        return 1
    fi
    
    mkdir -p "$backup_dir"
    local backup_file="$backup_dir/$(basename "$file").$(date +%Y%m%d_%H%M%S).bak"
    
    if cp "$file" "$backup_file"; then
        log_success "文件备份成功: $backup_file"
        return 0
    else
        log_error "文件备份失败: $file"
        return 1
    fi
}

# 等待用户输入
wait_for_input() {
    local prompt="${1:-按回车键继续...}"
    echo -n -e "${YELLOW}$prompt${NC}"
    read -r
}

# 确认操作
confirm_action() {
    local prompt="${1:-确认执行此操作吗?}"
    local choice
    
    while true; do
        echo -n -e "${YELLOW}$prompt [y/N]: ${NC}"
        read -r choice
        case "$choice" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo]|"")
                return 1
                ;;
            *)
                echo -e "${RED}请输入 y 或 n${NC}"
                ;;
        esac
    done
}

# 显示进度条
show_progress() {
    local current="$1"
    local total="$2"
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    
    printf "\r${CYAN}进度: [%s%s] %d%%${NC}" \
        "$(printf '%*s' "$completed" '' | tr ' ' '█')" \
        "$(printf '%*s' "$remaining" '' | tr ' ' '░')" \
        "$percentage"
    
    if [[ "$current" -eq "$total" ]]; then
        echo ""
    fi
}

# 清理临时文件
cleanup_temp() {
    local temp_dirs=("/tmp/sing-box*" "/tmp/sb-*")
    
    for pattern in "${temp_dirs[@]}"; do
        rm -rf $pattern 2>/dev/null || true
    done
    
    log_info "临时文件清理完成"
}