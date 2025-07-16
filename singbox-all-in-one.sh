#!/bin/bash

# Sing-box 全能一键安装脚本
# 支持 VLESS Reality、VMess WebSocket、Hysteria2 协议
# 版本: v3.0.0 (All-in-One)
# 更新时间: 2025-01-16
# 特点: 无需外部模块，所有功能集成在一个文件中

# 设置错误处理
set -e

# 脚本信息
SCRIPT_NAME="Sing-box 全能一键安装脚本"
SCRIPT_VERSION="v3.0.0"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 基础变量
WORK_DIR="/var/lib/sing-box"
CONFIG_FILE="$WORK_DIR/config.json"
SINGBOX_BINARY="/usr/local/bin/sing-box"
SERVICE_NAME="sing-box"
LOG_FILE="/var/log/sing-box.log"

# 调试模式 (可通过环境变量 DEBUG=true 启用)
DEBUG="${DEBUG:-false}"

# 系统信息
OS=""
ARCH=""
PUBLIC_IP=""

# 协议变量
VLESS_UUID=""
VLESS_PORT="10443"
VLESS_PRIVATE_KEY=""
VLESS_PUBLIC_KEY=""
VLESS_SHORT_ID=""
VLESS_TARGET="www.yahoo.com:443"
VLESS_SERVER_NAME="www.yahoo.com"

VMESS_UUID=""
VMESS_PORT="10080"
VMESS_WS_PATH=""
VMESS_HOST=""

HY2_PASSWORD=""
HY2_PORT="36712"
HY2_OBFS_PASSWORD=""
HY2_UP_MBPS="100"
HY2_DOWN_MBPS="100"
HY2_DOMAIN=""
HY2_CERT_FILE=""
HY2_KEY_FILE=""

# ==================== 通用函数库 ====================

# ==================== 日志记录功能 ====================

# 记录日志
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 确保日志目录存在
    mkdir -p "$(dirname "$LOG_FILE")"
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case "$level" in
        "ERROR")
            echo -e "${RED}[错误] $message${NC}"
            ;;
        "WARN")
            echo -e "${YELLOW}[警告] $message${NC}"
            ;;
        "INFO")
            echo -e "${GREEN}[信息] $message${NC}"
            ;;
        "DEBUG")
            if [[ "$DEBUG" == "true" ]]; then
                echo -e "${CYAN}[调试] $message${NC}"
            fi
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# 错误处理函数
handle_error() {
    local error_code="$1"
    local error_message="$2"
    local function_name="${FUNCNAME[1]}"
    
    log_message "ERROR" "在函数 $function_name 中发生错误 (代码: $error_code): $error_message"
    
    # 记录调用栈
    log_message "DEBUG" "调用栈:"
    for ((i=1; i<${#FUNCNAME[@]}; i++)); do
        log_message "DEBUG" "  $i: ${FUNCNAME[i]} (${BASH_SOURCE[i]}:${BASH_LINENO[i-1]})"
    done
    
    return "$error_code"
}

# 检查命令执行结果
check_command() {
    local command="$1"
    local description="$2"
    
    log_message "DEBUG" "执行命令: $command"
    
    if eval "$command"; then
        log_message "INFO" "$description 成功"
        return 0
    else
        local exit_code=$?
        handle_error "$exit_code" "$description 失败"
        return "$exit_code"
    fi
}

# 日志函数
log_info() {
    local message="$1"
    local details="${2:-}"
    echo -e "${GREEN}[INFO] $message${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $message" >> "$LOG_FILE" 2>/dev/null || true
    if [[ -n "$details" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Details: $details" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

log_success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $1" >> "$LOG_FILE" 2>/dev/null || true
}

log_warn() {
    echo -e "${YELLOW}[WARN] $*${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $*" >> "$LOG_FILE" 2>/dev/null || true
}

log_error() {
    local message="$1"
    local details="${2:-}"
    echo -e "${RED}[ERROR] $message${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $message" >> "$LOG_FILE" 2>/dev/null || true
    if [[ -n "$details" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] Details: $details" >> "$LOG_FILE" 2>/dev/null || true
    fi
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

# 验证端口范围
validate_port() {
    local port="$1"
    if [[ "$port" =~ ^[0-9]+$ ]] && ((port >= 1 && port <= 65535)); then
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
    
    log_message "INFO" "开始重启服务: $service"
    
    # 验证配置文件
    if [[ -f "$CONFIG_FILE" ]]; then
        log_message "DEBUG" "正在验证配置文件"
        if ! "$SINGBOX_BINARY" check -c "$CONFIG_FILE" 2>/dev/null; then
            handle_error 1 "配置文件验证失败"
            log_message "ERROR" "请检查配置文件语法: $CONFIG_FILE"
            return 1
        fi
        log_message "INFO" "配置文件验证通过"
    else
        handle_error 1 "配置文件不存在: $CONFIG_FILE"
        return 1
    fi
    
    # 检查服务是否存在
    if ! systemctl list-unit-files 2>/dev/null | grep -q "^$service.service"; then
        handle_error 1 "服务 $service 不存在"
        return 1
    fi
    
    log_message "DEBUG" "正在重启服务"
    
    if ! check_command "systemctl restart '$service'" "重启服务 $service"; then
        log_message "ERROR" "建议查看服务日志: journalctl -u $service -f"
        return 1
    fi
    
    # 等待服务启动
    log_message "DEBUG" "等待服务启动"
    sleep 3
    
    # 检查服务状态
    local max_attempts=10
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if systemctl is-active "$service" >/dev/null 2>&1; then
            log_message "INFO" "服务 $service 重启成功"
            return 0
        fi
        
        log_message "DEBUG" "等待服务启动 (尝试 $attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    # 服务启动失败，获取详细错误信息
    local service_status
    service_status=$(systemctl status "$service" --no-pager -l 2>/dev/null || echo "无法获取服务状态")
    
    handle_error 1 "服务 $service 启动超时或失败"
    log_message "ERROR" "服务状态: $service_status"
    log_message "ERROR" "建议查看详细日志: journalctl -u $service -f"
    
    return 1
}

# 等待用户输入
wait_for_input() {
    echo ""
    read -p "按回车键继续..." 
}

# ==================== 系统检查和安装 ====================

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误: 此脚本需要 root 权限运行${NC}"
        echo -e "${YELLOW}请使用 sudo 或切换到 root 用户${NC}"
        exit 1
    fi
}

# 检测系统信息
detect_system() {
    # 检测操作系统
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS="$ID"
    elif [[ -f /etc/redhat-release ]]; then
        OS="centos"
    else
        echo -e "${RED}错误: 不支持的操作系统${NC}"
        exit 1
    fi
    
    # 检测架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        *) 
            echo -e "${RED}错误: 不支持的架构 $ARCH${NC}"
            exit 1
            ;;
    esac
    
    # 获取公网 IP
    PUBLIC_IP=$(get_public_ip)
    
    echo -e "${GREEN}系统检测完成:${NC}"
    echo -e "  操作系统: $OS"
    echo -e "  架构: $ARCH"
    echo -e "  公网IP: $PUBLIC_IP"
}

# 安装依赖
install_dependencies() {
    echo -e "${CYAN}检查和安装基础依赖...${NC}"
    
    # 检查必要的命令
    local missing_deps=()
    
    if ! command -v curl >/dev/null 2>&1; then
        missing_deps+=("curl")
    fi
    
    if ! command -v tar >/dev/null 2>&1; then
        missing_deps+=("tar")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${YELLOW}正在安装缺失的依赖: ${missing_deps[*]}${NC}"
        
        # 根据系统类型安装依赖
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update >/dev/null 2>&1
            apt-get install -y "${missing_deps[@]}" >/dev/null 2>&1
        elif command -v yum >/dev/null 2>&1; then
            yum install -y "${missing_deps[@]}" >/dev/null 2>&1
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y "${missing_deps[@]}" >/dev/null 2>&1
        else
            echo -e "${RED}错误: 无法自动安装依赖，请手动安装: ${missing_deps[*]}${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}依赖安装完成${NC}"
    else
        echo -e "${GREEN}所有依赖已满足${NC}"
    fi
}

# 创建工作目录
create_directories() {
    echo -e "${CYAN}创建工作目录...${NC}"
    
    mkdir -p "$WORK_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # 设置权限
    chmod 755 "$WORK_DIR"
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    echo -e "${GREEN}工作目录创建完成${NC}"
}

# 下载和安装 Sing-box
download_and_install_singbox() {
    log_message "INFO" "开始下载和安装 Sing-box"
    
    # 检查系统架构
    if [[ -z "$ARCH" ]]; then
        handle_error 1 "系统架构未检测"
        return 1
    fi
    
    # 获取最新版本
    local latest_version
    log_message "DEBUG" "正在获取最新版本信息"
    
    if ! latest_version=$(curl -fsSL --max-time 30 "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep '"tag_name"' | cut -d'"' -f4 | sed 's/^v//'); then
        handle_error 1 "无法连接到 GitHub API"
        return 1
    fi
    
    if [[ -z "$latest_version" ]]; then
        handle_error 1 "无法解析最新版本信息"
        return 1
    fi
    
    log_message "INFO" "最新版本: $latest_version"
    
    # 构建下载URL
    local download_url="https://github.com/SagerNet/sing-box/releases/download/v${latest_version}/sing-box-${latest_version}-linux-${ARCH}.tar.gz"
    local temp_file="/tmp/sing-box-${latest_version}.tar.gz"
    
    log_message "DEBUG" "下载URL: $download_url"
    
    # 下载文件
    log_message "INFO" "正在下载 Sing-box"
    if ! check_command "curl -fsSL --progress-bar --max-time 300 -o '$temp_file' '$download_url'" "下载 Sing-box"; then
        return 1
    fi
    
    # 验证下载的文件
    if [[ ! -f "$temp_file" ]] || [[ ! -s "$temp_file" ]]; then
        handle_error 1 "下载的文件无效或为空"
        rm -f "$temp_file"
        return 1
    fi
    
    # 解压和安装
    local extract_dir="/tmp/sing-box-extract"
    log_message "DEBUG" "创建临时目录: $extract_dir"
    
    if ! mkdir -p "$extract_dir"; then
        handle_error 1 "无法创建临时目录"
        rm -f "$temp_file"
        return 1
    fi
    
    if ! check_command "tar -xzf '$temp_file' -C '$extract_dir' --strip-components=1" "解压 Sing-box"; then
        rm -rf "$temp_file" "$extract_dir"
        return 1
    fi
    
    # 验证解压的二进制文件
    if [[ ! -f "$extract_dir/sing-box" ]]; then
        handle_error 1 "解压后未找到 sing-box 二进制文件"
        rm -rf "$temp_file" "$extract_dir"
        return 1
    fi
    
    # 复制二进制文件
    if ! check_command "cp '$extract_dir/sing-box' '$SINGBOX_BINARY'" "安装 Sing-box 二进制文件"; then
        rm -rf "$temp_file" "$extract_dir"
        return 1
    fi
    
    # 设置权限
    if ! check_command "chmod +x '$SINGBOX_BINARY'" "设置执行权限"; then
        rm -rf "$temp_file" "$extract_dir"
        return 1
    fi
    
    # 验证安装
    if ! "$SINGBOX_BINARY" version >/dev/null 2>&1; then
        handle_error 1 "Sing-box 安装验证失败"
        rm -rf "$temp_file" "$extract_dir"
        return 1
    fi
    
    # 清理临时文件
    rm -rf "$temp_file" "$extract_dir"
    
    log_message "INFO" "Sing-box 安装完成"
    return 0
}

# 创建系统服务
create_service() {
    echo -e "${CYAN}正在创建系统服务...${NC}"
    
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=$SINGBOX_BINARY run -c $CONFIG_FILE
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    
    echo -e "${GREEN}系统服务创建完成${NC}"
}

# ==================== 协议配置模块 ====================

# 生成 Reality 密钥对
generate_reality_keypair() {
    local keypair
    
    # 检查 sing-box 二进制文件是否存在
    if [[ ! -f "$SINGBOX_BINARY" ]]; then
        log_error "Sing-box 二进制文件不存在: $SINGBOX_BINARY"
        return 1
    fi
    
    keypair=$($SINGBOX_BINARY generate reality-keypair 2>/dev/null)
    
    if [[ -n "$keypair" ]]; then
        VLESS_PRIVATE_KEY=$(echo "$keypair" | grep "PrivateKey" | awk '{print $2}')
        VLESS_PUBLIC_KEY=$(echo "$keypair" | grep "PublicKey" | awk '{print $2}')
        
        # 验证密钥格式
        if [[ -n "$VLESS_PRIVATE_KEY" ]] && [[ -n "$VLESS_PUBLIC_KEY" ]]; then
            log_success "Reality 密钥对生成成功"
        else
            log_error "密钥对格式验证失败"
            return 1
        fi
    else
        log_error "Reality 密钥对生成失败"
        return 1
    fi
}

# 生成 Reality Short ID
generate_reality_short_id() {
    VLESS_SHORT_ID=$(openssl rand -hex 8)
    log_info "生成 Short ID: $VLESS_SHORT_ID"
}

# 检测可用的 Reality 目标
detect_reality_target() {
    local targets=(
        "www.yahoo.com:443"
        "www.microsoft.com:443"
        "www.cloudflare.com:443"
        "www.apple.com:443"
        "www.amazon.com:443"
        "www.google.com:443"
    )
    
    log_info "检测可用的 Reality 目标..."
    
    # 优先使用 yahoo.com，因为它在大多数地区都可访问
    local priority_target="www.yahoo.com:443"
    local host port
    host=$(echo "$priority_target" | cut -d':' -f1)
    port=$(echo "$priority_target" | cut -d':' -f2)
    
    if timeout 5 bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
        VLESS_TARGET="$priority_target"
        VLESS_SERVER_NAME="$host"
        log_success "选择 Reality 目标: $priority_target"
        return 0
    fi
    
    # 如果优先目标不可用，测试其他目标
    for target in "${targets[@]}"; do
        [[ "$target" == "$priority_target" ]] && continue
        host=$(echo "$target" | cut -d':' -f1)
        port=$(echo "$target" | cut -d':' -f2)
        
        if timeout 5 bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
            VLESS_TARGET="$target"
            VLESS_SERVER_NAME="$host"
            log_success "选择 Reality 目标: $target"
            return 0
        fi
    done
    
    log_warn "无法连接到预设目标，使用默认配置"
    VLESS_TARGET="www.yahoo.com:443"
    VLESS_SERVER_NAME="www.yahoo.com"
}

# 配置 VLESS Reality
configure_vless_reality() {
    log_info "配置 VLESS Reality Vision..."
    
    # 生成 UUID
    if [[ -z "$VLESS_UUID" ]]; then
        VLESS_UUID=$(generate_uuid)
        log_info "生成 UUID: $VLESS_UUID"
    fi
    
    # 检查端口
    if check_port "$VLESS_PORT"; then
        log_warn "端口 $VLESS_PORT 已被占用"
        VLESS_PORT=$(get_random_port)
        log_info "使用随机端口: $VLESS_PORT"
    fi
    
    # 确保使用高端口
    if [ "$VLESS_PORT" -lt 10000 ]; then
        log_warn "VLESS端口 $VLESS_PORT 低于10000，重新分配高端口"
        VLESS_PORT=$(get_random_port)
        log_info "VLESS高端口: $VLESS_PORT"
    fi
    
    # 生成密钥对
    if [[ -z "$VLESS_PRIVATE_KEY" ]] || [[ -z "$VLESS_PUBLIC_KEY" ]]; then
        generate_reality_keypair
    fi
    
    # 生成 Short ID
    if [[ -z "$VLESS_SHORT_ID" ]]; then
        generate_reality_short_id
    fi
    
    # 检测目标
    detect_reality_target
    
    log_success "VLESS Reality 配置完成"
}

# 配置 VMess WebSocket
configure_vmess_websocket() {
    log_info "配置 VMess WebSocket..."
    
    # 生成 UUID
    if [[ -z "$VMESS_UUID" ]]; then
        VMESS_UUID=$(generate_uuid)
        log_info "生成 UUID: $VMESS_UUID"
    fi
    
    # 生成 WebSocket 路径
    if [[ -z "$VMESS_WS_PATH" ]]; then
        VMESS_WS_PATH="/$(generate_random_string 8)"
        log_info "生成 WebSocket 路径: $VMESS_WS_PATH"
    fi
    
    # 设置 Host
    if [[ -z "$VMESS_HOST" ]]; then
        VMESS_HOST="$PUBLIC_IP"
    fi
    
    # 检查端口
    if check_port "$VMESS_PORT"; then
        log_warn "端口 $VMESS_PORT 已被占用"
        VMESS_PORT=$(get_random_port)
        log_info "使用随机端口: $VMESS_PORT"
    fi
    
    # 确保使用高端口
    if [ "$VMESS_PORT" -lt 10000 ]; then
        log_warn "VMess端口 $VMESS_PORT 低于10000，重新分配高端口"
        VMESS_PORT=$(get_random_port)
        log_info "VMess高端口: $VMESS_PORT"
    fi
    
    log_success "VMess WebSocket 配置完成"
}

# 配置 Hysteria2
configure_hysteria2() {
    log_info "配置 Hysteria2..."
    
    # 生成密码
    if [[ -z "$HY2_PASSWORD" ]]; then
        HY2_PASSWORD=$(generate_random_string 16)
        log_info "生成密码: $HY2_PASSWORD"
    fi
    
    # 生成混淆密码
    if [[ -z "$HY2_OBFS_PASSWORD" ]]; then
        HY2_OBFS_PASSWORD=$(generate_random_string 16)
        log_info "生成混淆密码: $HY2_OBFS_PASSWORD"
    fi
    
    # 设置域名
    if [[ -z "$HY2_DOMAIN" ]]; then
        HY2_DOMAIN="$PUBLIC_IP"
    fi
    
    # 检查端口
    if check_port "$HY2_PORT"; then
        log_warn "端口 $HY2_PORT 已被占用"
        HY2_PORT=$(get_random_port)
        log_info "使用随机端口: $HY2_PORT"
    fi
    
    # 确保使用高端口
    if [ "$HY2_PORT" -lt 10000 ]; then
        log_warn "Hysteria2端口 $HY2_PORT 低于10000，重新分配高端口"
        HY2_PORT=$(get_random_port)
        log_info "Hysteria2高端口: $HY2_PORT"
    fi
    
    log_success "Hysteria2 配置完成"
}

# 生成完整配置文件
generate_config() {
    log_message "INFO" "开始生成配置文件"
    
    # 确保配置目录存在
    if ! mkdir -p "$(dirname "$CONFIG_FILE")"; then
        handle_error 1 "无法创建配置目录"
        return 1
    fi
    
    # 备份现有配置
    if [[ -f "$CONFIG_FILE" ]]; then
        local backup_file="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        if cp "$CONFIG_FILE" "$backup_file"; then
            log_message "INFO" "已备份现有配置到: $backup_file"
        else
            log_message "WARN" "无法备份现有配置文件"
        fi
    fi
    
    log_message "DEBUG" "正在写入基础配置"
    
    if ! cat > "$CONFIG_FILE" << EOF
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
EOF
    then
        handle_error 1 "无法写入基础配置文件"
        return 1
    fi

    local inbounds=()
    
    # VLESS Reality 入站
    if [[ -n "$VLESS_UUID" ]]; then
        log_message "DEBUG" "添加 VLESS Reality 配置"
        inbounds+=("vless")
        if ! cat >> "$CONFIG_FILE" << EOF
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": $VLESS_PORT,
      "users": [
        {
          "uuid": "$VLESS_UUID"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$VLESS_SERVER_NAME",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "$VLESS_TARGET",
            "server_port": $(echo "$VLESS_TARGET" | cut -d':' -f2)
          },
          "private_key": "$VLESS_PRIVATE_KEY",
          "short_id": ["$VLESS_SHORT_ID"]
        }
      }
    }
EOF
        then
            handle_error 1 "无法写入 VLESS 配置"
            return 1
        fi
    fi
    
    # VMess WebSocket 入站
    if [[ -n "$VMESS_UUID" ]]; then
        log_message "DEBUG" "添加 VMess WebSocket 配置"
        [[ ${#inbounds[@]} -gt 0 ]] && echo "," >> "$CONFIG_FILE"
        inbounds+=("vmess")
        if ! cat >> "$CONFIG_FILE" << EOF
    {
      "type": "vmess",
      "tag": "vmess-in",
      "listen": "::",
      "listen_port": $VMESS_PORT,
      "users": [
        {
          "uuid": "$VMESS_UUID",
          "alterId": 0
        }
      ],
      "transport": {
        "type": "ws",
        "path": "$VMESS_WS_PATH",
        "headers": {
          "Host": "$VMESS_HOST"
        }
      }
    }
EOF
        then
            handle_error 1 "无法写入 VMess 配置"
            return 1
        fi
    fi
    
    # Hysteria2 入站
    if [[ -n "$HY2_PASSWORD" ]]; then
        log_message "DEBUG" "添加 Hysteria2 配置"
        [[ ${#inbounds[@]} -gt 0 ]] && echo "," >> "$CONFIG_FILE"
        inbounds+=("hysteria2")
        if ! cat >> "$CONFIG_FILE" << EOF
    {
      "type": "hysteria2",
      "tag": "hy2-in",
      "listen": "::",
      "listen_port": $HY2_PORT,
      "users": [
        {
          "password": "$HY2_PASSWORD"
        }
      ],
      "masquerade": "https://bing.com",
      "tls": {
        "enabled": true,
        "alpn": [
          "h3"
        ],
        "certificate_path": "/etc/ssl/private/hysteria.crt",
        "key_path": "/etc/ssl/private/hysteria.key"
      },
      "obfs": {
        "type": "salamander",
        "salamander": {
          "password": "$HY2_OBFS_PASSWORD"
        }
      }
    }
EOF
        then
            handle_error 1 "无法写入 Hysteria2 配置"
            return 1
        fi
    fi
    
    # 写入配置文件结尾
    if ! cat >> "$CONFIG_FILE" << EOF
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
  ]
}
EOF
    then
        handle_error 1 "无法完成配置文件写入"
        return 1
    fi
    
    # 验证生成的配置文件
    if [[ ! -f "$CONFIG_FILE" ]] || [[ ! -s "$CONFIG_FILE" ]]; then
        handle_error 1 "生成的配置文件无效或为空"
        return 1
    fi
    
    # 为 Hysteria2 生成自签名证书
    if [[ -n "$HY2_PASSWORD" ]]; then
        if ! generate_hysteria2_cert; then
            handle_error 1 "Hysteria2 证书生成失败"
            return 1
        fi
    fi
    
    log_message "INFO" "配置文件生成完成: $CONFIG_FILE"
    return 0
}

# 生成 Hysteria2 自签名证书
generate_hysteria2_cert() {
    log_info "生成 Hysteria2 自签名证书..."
    
    mkdir -p /etc/ssl/private
    
    # 生成私钥
    openssl genpkey -algorithm RSA -out /etc/ssl/private/hysteria.key -pkcs8
    
    # 生成证书
    openssl req -new -x509 -key /etc/ssl/private/hysteria.key -out /etc/ssl/private/hysteria.crt -days 36500 -subj "/CN=$HY2_DOMAIN"
    
    # 设置权限
    chmod 600 /etc/ssl/private/hysteria.key
    chmod 644 /etc/ssl/private/hysteria.crt
    
    log_success "Hysteria2 证书生成完成"
}

# ==================== 分享链接生成 ====================

# 生成 VLESS Reality 分享链接
generate_vless_share_link() {
    local server_ip="${1:-$PUBLIC_IP}"
    local remark="${2:-VLESS-Reality}"
    
    if [[ -z "$VLESS_UUID" ]] || [[ -z "$VLESS_PORT" ]]; then
        log_error "VLESS 配置信息不完整"
        return 1
    fi
    
    # 构建 VLESS 链接
    local vless_link="vless://${VLESS_UUID}@${server_ip}:${VLESS_PORT}"
    vless_link+="?encryption=none"
    vless_link+="&security=reality"
    vless_link+="&sni=${VLESS_SERVER_NAME}"
    vless_link+="&fp=chrome"
    vless_link+="&pbk=${VLESS_PUBLIC_KEY}"
    vless_link+="&sid=${VLESS_SHORT_ID}"
    vless_link+="&type=tcp"
    vless_link+="&headerType=none"
    vless_link+="#${remark}"
    
    echo "$vless_link"
}

# 生成 VMess WebSocket 分享链接
generate_vmess_share_link() {
    local server_ip="${1:-$PUBLIC_IP}"
    local remark="${2:-VMess-WS}"
    
    if [[ -z "$VMESS_UUID" ]] || [[ -z "$VMESS_PORT" ]]; then
        log_error "VMess 配置信息不完整"
        return 1
    fi
    
    # 构建 VMess 配置 JSON
    local vmess_json
    vmess_json=$(cat << EOF
{
  "v": "2",
  "ps": "$remark",
  "add": "$server_ip",
  "port": "$VMESS_PORT",
  "id": "$VMESS_UUID",
  "aid": "0",
  "scy": "auto",
  "net": "ws",
  "type": "none",
  "host": "$VMESS_HOST",
  "path": "$VMESS_WS_PATH",
  "tls": "",
  "sni": "",
  "alpn": ""
}
EOF
    )
    
    # Base64 编码
    local encoded
    encoded=$(echo -n "$vmess_json" | base64 -w 0)
    
    echo "vmess://$encoded"
}

# 生成 Hysteria2 分享链接
generate_hysteria2_share_link() {
    local server_ip="${1:-$PUBLIC_IP}"
    local remark="${2:-Hysteria2}"
    
    if [[ -z "$HY2_PASSWORD" ]] || [[ -z "$HY2_PORT" ]]; then
        log_error "Hysteria2 配置信息不完整"
        return 1
    fi
    
    # 构建 Hysteria2 链接
    local hy2_link="hysteria2://${HY2_PASSWORD}@${server_ip}:${HY2_PORT}"
    hy2_link+="?obfs=salamander"
    hy2_link+="&obfs-password=${HY2_OBFS_PASSWORD}"
    hy2_link+="&sni=${HY2_DOMAIN}"
    hy2_link+="&insecure=1"
    hy2_link+="#${remark}"
    
    echo "$hy2_link"
}

# 生成所有分享链接
generate_share_links() {
    echo -e "${CYAN}=== 分享链接 ===${NC}"
    echo ""
    
    local has_config=false
    
    # VLESS Reality
    if [[ -n "$VLESS_UUID" ]]; then
        echo -e "${GREEN}VLESS Reality Vision:${NC}"
        local vless_link
        vless_link=$(generate_vless_share_link)
        echo "$vless_link"
        echo ""
        has_config=true
    fi
    
    # VMess WebSocket
    if [[ -n "$VMESS_UUID" ]]; then
        echo -e "${GREEN}VMess WebSocket:${NC}"
        local vmess_link
        vmess_link=$(generate_vmess_share_link)
        echo "$vmess_link"
        echo ""
        has_config=true
    fi
    
    # Hysteria2
    if [[ -n "$HY2_PASSWORD" ]]; then
        echo -e "${GREEN}Hysteria2:${NC}"
        local hy2_link
        hy2_link=$(generate_hysteria2_share_link)
        echo "$hy2_link"
        echo ""
        has_config=true
    fi
    
    if [[ "$has_config" == "false" ]]; then
        echo -e "${YELLOW}未找到已配置的协议${NC}"
        echo -e "${YELLOW}请先配置协议后再生成分享链接${NC}"
    fi
    
    wait_for_input
}

# ==================== 菜单系统 ====================

# 显示横幅
show_banner() {
    clear
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${CYAN}                    $SCRIPT_NAME${NC}"
    echo -e "${CYAN}                      $SCRIPT_VERSION${NC}"
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${GREEN}支持协议:${NC}"
    echo -e "  ${YELLOW}•${NC} VLESS Reality Vision"
    echo -e "  ${YELLOW}•${NC} VMess WebSocket"
    echo -e "  ${YELLOW}•${NC} Hysteria2"
    echo -e "${CYAN}================================================================${NC}"
    echo ""
}

# 显示主菜单
show_main_menu() {
    while true; do
        clear
        echo -e "${CYAN}================================================================${NC}"
        echo -e "${CYAN}                    Sing-box 管理面板${NC}"
        echo -e "${CYAN}================================================================${NC}"
        echo ""
        
        # 显示系统信息
        echo -e "${GREEN}系统信息:${NC} $OS ($ARCH)"
        echo -e "${GREEN}公网IP:${NC} $PUBLIC_IP"
        
        # 显示服务状态
        local status=$(get_service_status "$SERVICE_NAME")
        case "$status" in
            "running")
                echo -e "${GREEN}服务状态:${NC} ${GREEN}运行中${NC}"
                ;;
            "stopped")
                echo -e "${GREEN}服务状态:${NC} ${YELLOW}已停止${NC}"
                ;;
            *)
                echo -e "${GREEN}服务状态:${NC} ${RED}未启用${NC}"
                ;;
        esac
        
        # 显示配置状态
        echo -e "${GREEN}配置状态:${NC}"
        local status_line=""
        [[ -n "$VLESS_PORT" ]] && status_line+="VLESS(${VLESS_PORT}) "
        [[ -n "$VMESS_PORT" ]] && status_line+="VMess(${VMESS_PORT}) "
        [[ -n "$HY2_PORT" ]] && status_line+="Hysteria2(${HY2_PORT}) "
        
        if [[ -n "$status_line" ]]; then
            echo -e "${GREEN}已配置:${NC} $status_line"
        else
            echo -e "${YELLOW}未配置任何协议${NC}"
        fi
        echo ""
        
        # 菜单选项
        echo -e "${YELLOW}请选择操作:${NC}"
        echo ""
        echo -e "  ${GREEN}1.${NC} 一键配置三协议"
        echo -e "  ${GREEN}2.${NC} 配置单个协议"
        echo -e "  ${GREEN}3.${NC} 管理服务"
        echo -e "  ${GREEN}4.${NC} 查看配置信息"
        echo -e "  ${GREEN}5.${NC} 生成分享链接"
        echo -e "  ${GREEN}6.${NC} 故障排除"
        echo -e "  ${GREEN}7.${NC} 卸载 Sing-box"
        echo -e "  ${GREEN}0.${NC} 退出"
        echo ""
        echo -e "${CYAN}================================================================${NC}"
        
        local choice
        echo -n -e "${YELLOW}请输入选择 [0-7]: ${NC}"
        read -r choice
        
        case "$choice" in
            1) quick_setup_all_protocols ;;
            2) show_protocol_menu ;;
            3) show_service_menu ;;
            4) show_config_info ;;
            5) generate_share_links ;;
            6) troubleshoot_menu ;;
            7) uninstall_singbox ;;
            0) 
                echo -e "${GREEN}感谢使用！${NC}"
                exit 0
                ;;
            *) 
                echo -e "${RED}无效选择，请重新输入${NC}"
                wait_for_input
                ;;
        esac
    done
}

# 协议配置菜单
show_protocol_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== 协议配置菜单 ===${NC}"
        echo ""
        echo -e "${YELLOW}请选择要配置的协议:${NC}"
        echo ""
        echo -e "  ${GREEN}1.${NC} VLESS Reality Vision"
        echo -e "  ${GREEN}2.${NC} VMess WebSocket"
        echo -e "  ${GREEN}3.${NC} Hysteria2"
        echo -e "  ${GREEN}0.${NC} 返回主菜单"
        echo ""
        
        local choice
        echo -n -e "${YELLOW}请输入选择 [0-3]: ${NC}"
        read -r choice
        
        case "$choice" in
            1)
                configure_vless_reality
                generate_config
                restart_service "$SERVICE_NAME"
                wait_for_input
                ;;
            2)
                configure_vmess_websocket
                generate_config
                restart_service "$SERVICE_NAME"
                wait_for_input
                ;;
            3)
                configure_hysteria2
                generate_config
                restart_service "$SERVICE_NAME"
                wait_for_input
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                wait_for_input
                ;;
        esac
    done
}

# 服务管理菜单
show_service_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== 服务管理菜单 ===${NC}"
        echo ""
        
        local status=$(get_service_status "$SERVICE_NAME")
        echo -e "${GREEN}当前状态:${NC} "
        case "$status" in
            "running") echo -e "${GREEN}运行中${NC}" ;;
            "stopped") echo -e "${YELLOW}已停止${NC}" ;;
            *) echo -e "${RED}未启用${NC}" ;;
        esac
        echo ""
        
        echo -e "${YELLOW}请选择操作:${NC}"
        echo ""
        echo -e "  ${GREEN}1.${NC} 启动服务"
        echo -e "  ${GREEN}2.${NC} 停止服务"
        echo -e "  ${GREEN}3.${NC} 重启服务"
        echo -e "  ${GREEN}4.${NC} 查看日志"
        echo -e "  ${GREEN}0.${NC} 返回主菜单"
        echo ""
        
        local choice
        echo -n -e "${YELLOW}请输入选择 [0-4]: ${NC}"
        read -r choice
        
        case "$choice" in
            1)
                start_service "$SERVICE_NAME"
                wait_for_input
                ;;
            2)
                stop_service "$SERVICE_NAME"
                wait_for_input
                ;;
            3)
                restart_service "$SERVICE_NAME"
                wait_for_input
                ;;
            4)
                show_service_logs
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                wait_for_input
                ;;
        esac
    done
}

# 显示服务日志
show_service_logs() {
    clear
    echo -e "${CYAN}=== Sing-box 服务日志 ===${NC}"
    echo ""
    echo -e "${YELLOW}最近50行日志:${NC}"
    echo ""
    
    if systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
        journalctl -u "$SERVICE_NAME" -n 50 --no-pager
    else
        echo -e "${RED}服务未运行${NC}"
    fi
    
    wait_for_input
}

# 显示配置信息
show_config_info() {
    clear
    echo -e "${CYAN}=== 配置信息 ===${NC}"
    echo ""
    
    # VLESS Reality
    if [[ -n "$VLESS_UUID" ]]; then
        echo -e "${GREEN}VLESS Reality Vision:${NC}"
        echo -e "  端口: $VLESS_PORT"
        echo -e "  UUID: $VLESS_UUID"
        echo -e "  目标: $VLESS_TARGET"
        echo -e "  服务器名: $VLESS_SERVER_NAME"
        echo -e "  公钥: $VLESS_PUBLIC_KEY"
        echo -e "  Short ID: $VLESS_SHORT_ID"
        echo ""
    fi
    
    # VMess WebSocket
    if [[ -n "$VMESS_UUID" ]]; then
        echo -e "${GREEN}VMess WebSocket:${NC}"
        echo -e "  端口: $VMESS_PORT"
        echo -e "  UUID: $VMESS_UUID"
        echo -e "  路径: $VMESS_WS_PATH"
        echo -e "  Host: $VMESS_HOST"
        echo ""
    fi
    
    # Hysteria2
    if [[ -n "$HY2_PASSWORD" ]]; then
        echo -e "${GREEN}Hysteria2:${NC}"
        echo -e "  端口: $HY2_PORT"
        echo -e "  密码: $HY2_PASSWORD"
        echo -e "  混淆密码: $HY2_OBFS_PASSWORD"
        echo -e "  域名: $HY2_DOMAIN"
        echo ""
    fi
    
    if [[ -z "$VLESS_UUID" ]] && [[ -z "$VMESS_UUID" ]] && [[ -z "$HY2_PASSWORD" ]]; then
        echo -e "${YELLOW}未配置任何协议${NC}"
    fi
    
    wait_for_input
}

# ==================== 故障排除功能 ====================

# 故障排除菜单
troubleshoot_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== 故障排除菜单 ===${NC}"
        echo ""
        echo -e "${YELLOW}请选择诊断项目:${NC}"
        echo ""
        echo -e "  ${GREEN}1.${NC} 检查系统环境"
        echo -e "  ${GREEN}2.${NC} 验证配置文件"
        echo -e "  ${GREEN}3.${NC} 检查端口占用"
        echo -e "  ${GREEN}4.${NC} 测试网络连接"
        echo -e "  ${GREEN}5.${NC} 查看详细日志"
        echo -e "  ${GREEN}6.${NC} 重新生成配置"
        echo -e "  ${GREEN}0.${NC} 返回主菜单"
        echo ""
        
        local choice
        echo -n -e "${YELLOW}请输入选择 [0-6]: ${NC}"
        read -r choice
        
        case "$choice" in
            1) check_system_environment ;;
            2) validate_config_file ;;
            3) check_port_usage ;;
            4) test_network_connectivity ;;
            5) show_detailed_logs ;;
            6) regenerate_config ;;
            0) return ;;
            *) 
                echo -e "${RED}无效选择，请重新输入${NC}"
                wait_for_input
                ;;
        esac
    done
}

# 检查系统环境
check_system_environment() {
    clear
    echo -e "${CYAN}=== 系统环境检查 ===${NC}"
    echo ""
    
    echo -e "${GREEN}1. 基础信息:${NC}"
    echo -e "  操作系统: $OS"
    echo -e "  架构: $ARCH"
    echo -e "  公网IP: $PUBLIC_IP"
    echo ""
    
    echo -e "${GREEN}2. Sing-box 状态:${NC}"
    if [[ -f "$SINGBOX_BINARY" ]]; then
        echo -e "  二进制文件: ${GREEN}存在${NC} ($SINGBOX_BINARY)"
        local version
        version=$("$SINGBOX_BINARY" version 2>/dev/null | head -n1 || echo "无法获取版本")
        echo -e "  版本信息: $version"
    else
        echo -e "  二进制文件: ${RED}不存在${NC}"
    fi
    echo ""
    
    echo -e "${GREEN}3. 服务状态:${NC}"
    local status=$(get_service_status "$SERVICE_NAME")
    case "$status" in
        "running") echo -e "  服务状态: ${GREEN}运行中${NC}" ;;
        "stopped") echo -e "  服务状态: ${YELLOW}已停止${NC}" ;;
        *) echo -e "  服务状态: ${RED}未启用${NC}" ;;
    esac
    echo ""
    
    echo -e "${GREEN}4. 配置文件:${NC}"
    if [[ -f "$CONFIG_FILE" ]]; then
        echo -e "  配置文件: ${GREEN}存在${NC} ($CONFIG_FILE)"
        local size
        size=$(stat -c%s "$CONFIG_FILE" 2>/dev/null || echo "0")
        echo -e "  文件大小: ${size} 字节"
    else
        echo -e "  配置文件: ${RED}不存在${NC}"
    fi
    echo ""
    
    wait_for_input
}

# 验证配置文件
validate_config_file() {
    clear
    echo -e "${CYAN}=== 配置文件验证 ===${NC}"
    echo ""
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}配置文件不存在: $CONFIG_FILE${NC}"
        wait_for_input
        return
    fi
    
    echo -e "${YELLOW}正在验证配置文件...${NC}"
    echo ""
    
    if "$SINGBOX_BINARY" check -c "$CONFIG_FILE"; then
        echo ""
        echo -e "${GREEN}配置文件验证通过！${NC}"
    else
        echo ""
        echo -e "${RED}配置文件验证失败！${NC}"
        echo -e "${YELLOW}请检查上述错误信息并修复配置${NC}"
    fi
    
    wait_for_input
}

# 检查端口占用
check_port_usage() {
    clear
    echo -e "${CYAN}=== 端口占用检查 ===${NC}"
    echo ""
    
    local ports=("$VLESS_PORT" "$VMESS_PORT" "$HY2_PORT")
    local names=("VLESS" "VMess" "Hysteria2")
    
    for i in "${!ports[@]}"; do
        local port="${ports[$i]}"
        local name="${names[$i]}"
        
        if [[ -n "$port" ]]; then
            echo -e "${GREEN}检查 $name 端口 $port:${NC}"
            if check_port "$port"; then
                echo -e "  状态: ${YELLOW}被占用${NC}"
                echo -e "  进程信息:"
                ss -tulnp | grep ":$port " | head -5
            else
                echo -e "  状态: ${GREEN}可用${NC}"
            fi
            echo ""
        fi
    done
    
    wait_for_input
}

# 测试网络连接
test_network_connectivity() {
    clear
    echo -e "${CYAN}=== 网络连接测试 ===${NC}"
    echo ""
    
    echo -e "${GREEN}1. 测试外网连接:${NC}"
    if curl -s --max-time 5 www.google.com >/dev/null; then
        echo -e "  Google: ${GREEN}连接正常${NC}"
    else
        echo -e "  Google: ${RED}连接失败${NC}"
    fi
    
    if curl -s --max-time 5 www.cloudflare.com >/dev/null; then
        echo -e "  Cloudflare: ${GREEN}连接正常${NC}"
    else
        echo -e "  Cloudflare: ${RED}连接失败${NC}"
    fi
    echo ""
    
    echo -e "${GREEN}2. 测试 Reality 目标:${NC}"
    if [[ -n "$VLESS_TARGET" ]]; then
        local host port
        host=$(echo "$VLESS_TARGET" | cut -d':' -f1)
        port=$(echo "$VLESS_TARGET" | cut -d':' -f2)
        
        if timeout 5 bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
            echo -e "  $VLESS_TARGET: ${GREEN}连接正常${NC}"
        else
            echo -e "  $VLESS_TARGET: ${RED}连接失败${NC}"
        fi
    else
        echo -e "  ${YELLOW}未配置 Reality 目标${NC}"
    fi
    echo ""
    
    wait_for_input
}

# 显示详细日志
show_detailed_logs() {
    clear
    echo -e "${CYAN}=== 详细日志信息 ===${NC}"
    echo ""
    
    echo -e "${YELLOW}最近100行系统日志:${NC}"
    echo ""
    
    if systemctl list-unit-files 2>/dev/null | grep -q "sing-box.service"; then
        journalctl -u "$SERVICE_NAME" -n 100 --no-pager
    else
        echo -e "${RED}服务未安装${NC}"
    fi
    
    wait_for_input
}

# 重新生成配置
regenerate_config() {
    clear
    echo -e "${CYAN}=== 重新生成配置 ===${NC}"
    echo ""
    echo -e "${RED}警告: 这将重新生成配置文件，现有配置将被覆盖${NC}"
    echo ""
    
    read -p "确认重新生成配置？[y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}取消操作${NC}"
        wait_for_input
        return
    fi
    
    echo -e "${YELLOW}正在重新生成配置...${NC}"
    
    # 备份现有配置
    if [[ -f "$CONFIG_FILE" ]]; then
        cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${GREEN}已备份现有配置${NC}"
    fi
    
    # 重新生成配置
    if generate_config; then
        echo -e "${GREEN}配置重新生成完成${NC}"
        
        # 重启服务
        if restart_service "$SERVICE_NAME"; then
            echo -e "${GREEN}服务重启成功${NC}"
        else
            echo -e "${RED}服务重启失败${NC}"
        fi
    else
        echo -e "${RED}配置生成失败${NC}"
    fi
    
    wait_for_input
}

# ==================== 一键配置功能 ====================

# 一键配置所有协议
quick_setup_all_protocols() {
    echo -e "${CYAN}=== 一键配置三协议 ===${NC}"
    echo ""
    echo -e "${YELLOW}正在配置 VLESS Reality + VMess WebSocket + Hysteria2...${NC}"
    echo ""
    
    # 配置所有协议
    configure_vless_reality
    configure_vmess_websocket
    configure_hysteria2
    
    # 生成配置文件
    generate_config
    
    # 重启服务
    restart_service "$SERVICE_NAME"
    
    echo ""
    echo -e "${GREEN}=== 配置完成 ===${NC}"
    echo ""
    echo -e "${CYAN}协议信息:${NC}"
    echo -e "  VLESS Reality: 端口 $VLESS_PORT"
    echo -e "  VMess WebSocket: 端口 $VMESS_PORT"
    echo -e "  Hysteria2: 端口 $HY2_PORT"
    echo ""
    
    # 显示分享链接
    generate_share_links
}

# ==================== 安装和卸载 ====================

# 执行完整安装
perform_installation() {
    echo -e "${CYAN}=== 开始安装 Sing-box ===${NC}"
    echo ""
    
    # 安装依赖
    install_dependencies
    
    # 创建目录
    create_directories
    
    # 下载和安装
    if ! download_and_install_singbox; then
        echo -e "${RED}安装失败${NC}"
        exit 1
    fi
    
    # 创建服务
    create_service
    
    echo ""
    echo -e "${GREEN}=== 安装完成 ===${NC}"
    echo -e "${YELLOW}现在可以配置协议了${NC}"
    
    wait_for_input
}

# 卸载 Sing-box
uninstall_singbox() {
    echo -e "${CYAN}=== 卸载 Sing-box ===${NC}"
    echo ""
    echo -e "${RED}警告: 这将完全删除 Sing-box 及其所有配置${NC}"
    echo ""
    
    read -p "确认卸载？[y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}取消卸载${NC}"
        return
    fi
    
    # 停止服务
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    
    # 删除服务文件
    rm -f "/etc/systemd/system/$SERVICE_NAME.service"
    systemctl daemon-reload
    
    # 删除二进制文件
    rm -f "$SINGBOX_BINARY"
    
    # 删除配置目录
    rm -rf "$WORK_DIR"
    
    # 删除日志文件
    rm -f "$LOG_FILE"
    
    # 删除证书文件
    rm -f /etc/ssl/private/hysteria.crt
    rm -f /etc/ssl/private/hysteria.key
    
    echo -e "${GREEN}卸载完成${NC}"
    wait_for_input
}

# 检查安装状态
check_installation_status() {
    local status="not_installed"
    local install_method="unknown"
    local details=""
    
    # 检查二进制文件
    if [[ -f "$SINGBOX_BINARY" ]]; then
        status="installed"
        install_method="binary"
        details="已安装"
    fi
    
    # 检查系统服务
    if systemctl list-unit-files 2>/dev/null | grep -q "sing-box.service"; then
        status="installed"
        if [[ "$install_method" == "unknown" ]]; then
            install_method="service"
            details="已安装"
        fi
    fi
    
    echo "$status:$install_method:$details"
}

# 显示安装菜单
show_installation_menu() {
    local install_info="$1"
    local status=$(echo "$install_info" | cut -d: -f1)
    
    echo -e "${CYAN}=== Sing-box 管理 ===${NC}"
    
    case "$status" in
        "installed")
            show_main_menu
            ;;
        "not_installed")
            echo -e "${YELLOW}Sing-box 未安装，开始安装...${NC}"
            perform_installation
            # 安装完成后进入主菜单
            show_main_menu
            ;;
    esac
}

# ==================== 主函数 ====================

# 加载现有配置
load_existing_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_info "检测到现有配置文件，尝试加载配置信息..."
        
        # 从配置文件中提取端口信息
        if grep -q '"type": "vless"' "$CONFIG_FILE"; then
            VLESS_PORT=$(grep -A 10 '"type": "vless"' "$CONFIG_FILE" | grep '"listen_port"' | grep -o '[0-9]*')
            VLESS_UUID=$(grep -A 10 '"type": "vless"' "$CONFIG_FILE" | grep '"uuid"' | cut -d'"' -f4)
            log_info "加载 VLESS 配置: 端口 $VLESS_PORT"
        fi
        
        if grep -q '"type": "vmess"' "$CONFIG_FILE"; then
            VMESS_PORT=$(grep -A 10 '"type": "vmess"' "$CONFIG_FILE" | grep '"listen_port"' | grep -o '[0-9]*')
            VMESS_UUID=$(grep -A 10 '"type": "vmess"' "$CONFIG_FILE" | grep '"uuid"' | cut -d'"' -f4)
            log_info "加载 VMess 配置: 端口 $VMESS_PORT"
        fi
        
        if grep -q '"type": "hysteria2"' "$CONFIG_FILE"; then
            HY2_PORT=$(grep -A 10 '"type": "hysteria2"' "$CONFIG_FILE" | grep '"listen_port"' | grep -o '[0-9]*')
            HY2_PASSWORD=$(grep -A 10 '"type": "hysteria2"' "$CONFIG_FILE" | grep '"password"' | cut -d'"' -f4)
            log_info "加载 Hysteria2 配置: 端口 $HY2_PORT"
        fi
    fi
}

# 主函数
main() {
    # 初始化日志
    log_message "INFO" "Sing-box 一键安装脚本启动"
    log_message "DEBUG" "脚本版本: 2.0"
    log_message "DEBUG" "工作目录: $WORK_DIR"
    log_message "DEBUG" "配置文件: $CONFIG_FILE"
    log_message "DEBUG" "调试模式: $DEBUG"
    
    # 基础检查
    if ! check_root; then
        handle_error 1 "需要 root 权限运行此脚本"
        exit 1
    fi
    
    show_banner
    
    if ! detect_system; then
        handle_error 1 "系统检测失败"
        exit 1
    fi
    
    log_message "INFO" "系统信息: $OS $ARCH, 公网IP: $PUBLIC_IP"
    
    if ! create_directories; then
        handle_error 1 "创建工作目录失败"
        exit 1
    fi
    
    # 加载现有配置
    log_message "DEBUG" "正在加载现有配置"
    load_existing_config
    
    # 检查安装状态并显示菜单
    local install_info=$(check_installation_status)
    show_installation_menu "$install_info"
    
    log_message "INFO" "脚本执行完成"
}

# ==================== 命令行参数处理 ====================

# 处理命令行参数
case "${1:-}" in
    --install)
        log_message "INFO" "执行安装模式"
        check_root
        detect_system
        perform_installation
        ;;
    --uninstall)
        log_message "INFO" "执行卸载模式"
        check_root
        uninstall_singbox
        ;;
    --quick-setup)
        log_message "INFO" "执行快速配置模式"
        check_root
        echo -e "${CYAN}=== 一键安装并配置三协议 ===${NC}"
        echo ""
        
        # 先安装 Sing-box
        if ! command -v sing-box &> /dev/null; then
            log_message "INFO" "正在安装 Sing-box"
            detect_system
            perform_installation
        else
            log_message "INFO" "Sing-box 已安装"
        fi
        
        # 执行一键配置
        log_message "INFO" "正在进行一键配置三协议"
        quick_setup_all_protocols
        exit 0
        ;;
    --debug)
        DEBUG="true"
        log_message "INFO" "启用调试模式"
        main
        ;;
    --help|-h)
        echo -e "${CYAN}$SCRIPT_NAME $SCRIPT_VERSION${NC}"
        echo ""
        echo -e "${YELLOW}用法:${NC}"
        echo -e "  $0                # 启动交互式菜单"
        echo -e "  $0 --install      # 直接安装"
        echo -e "  $0 --uninstall    # 一键完全卸载"
        echo -e "  $0 --quick-setup  # 一键安装并配置三协议"
        echo -e "  $0 --debug        # 启用调试模式"
        echo -e "  $0 --help         # 显示帮助"
        echo ""
        echo -e "${CYAN}一键安装特点:${NC}"
        echo -e "  ${GREEN}✓${NC} 自动安装 Sing-box"
        echo -e "  ${GREEN}✓${NC} 配置三种协议 (VLESS Reality + VMess WebSocket + Hysteria2)"
        echo -e "  ${GREEN}✓${NC} 自动分配高端口 (10000+)"
        echo -e "  ${GREEN}✓${NC} 生成连接信息和分享链接"
        echo -e "  ${GREEN}✓${NC} 无需外部模块，单文件运行"
        echo -e "  ${GREEN}✓${NC} 增强的错误处理和故障排除功能"
        ;;
    *)
        main
        ;;
esac