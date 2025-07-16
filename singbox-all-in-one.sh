
# Sing-box 全能一键安装脚本
# 支持 VLESS Reality、VMess WebSocket、Hysteria2 协议
# 版本: v3.0.1 (All-in-One)
# 更新时间: 2025-01-16
# 特点: 无需外部模块，所有功能集成在一个文件中

# 确保使用POSIX shell运行
if [ -z "$0" ]; then
    echo "错误: 无法确定脚本路径" >&2
    exit 1
fi

# 设置错误处理
set -eu

# ==================== 系统兼容性检�?====================

# 检查操作系统兼容性
check_os_compatibility() {
    # 检查是否为Linux系统
    if [ "$(uname -s)" != "Linux" ]; then
        echo -e "\033[0;31m错误: 此脚本仅支持 Linux 系统\033[0m"
        echo -e "\033[1;33m检测到的系�? $(uname -s)\033[0m"
        echo ""
        echo "支持的系�?"
        echo "  - Ubuntu 18.04+"
        echo "  - Debian 10+"
        echo "  - CentOS 7+"
        echo "  - RHEL 7+"
        echo "  - Fedora 30+"
        echo "  - Arch Linux"
        echo ""
        echo "如果您在 Windows 上，请使�?WSL (Windows Subsystem for Linux)"
        echo "如果您在 macOS 上，请使�?Docker 或虚拟机运行 Linux"
        exit 1
    fi
    
    # 检查是否有systemd支持
    if ! command -v systemctl >/dev/null 2>&1; then
        echo -e "\033[0;31m错误: 此脚本需�?systemd 支持\033[0m"
        echo -e "\033[1;33m未找�?systemctl 命令\033[0m"
        echo ""
        echo "请确保您的系统支�?systemd 服务管理"
        exit 1
    fi
    
    # 检查基本命令
    local missing_commands=""
    for cmd in sh curl tar grep sed awk; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            if [ -z "$missing_commands" ]; then
                missing_commands="$cmd"
            else
                missing_commands="$missing_commands $cmd"
            fi
        fi
    done
    
    if [ -n "$missing_commands" ]; then
        echo -e "\033[0;31m错误: 缺少必要的系统命令\033[0m" >&2
        echo -e "\033[1;33m缺少的命令: $missing_commands\033[0m" >&2
        echo "" >&2
        echo "请安装缺少的命令后重试" >&2
        exit 1
    fi
}

# 立即执行系统兼容性检查
check_os_compatibility

# 脚本信息
SCRIPT_NAME="Sing-box 全能一键安装脚本"
SCRIPT_VERSION="v3.0.1"

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

# ==================== 二维码生成功能 ====================

# 安装 qrencode（如果不存在）
install_qrencode() {
    if ! command -v qrencode >/dev/null 2>&1; then
        log_message "INFO" "正在安装 qrencode"
        
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update >/dev/null 2>&1
            apt-get install -y qrencode >/dev/null 2>&1
        elif command -v yum >/dev/null 2>&1; then
            yum install -y qrencode >/dev/null 2>&1
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y qrencode >/dev/null 2>&1
        elif command -v pacman >/dev/null 2>&1; then
            pacman -S --noconfirm qrencode >/dev/null 2>&1
        else
            log_message "WARN" "无法自动安装 qrencode，请手动安装"
            return 1
        fi
        
        if command -v qrencode >/dev/null 2>&1; then
            log_message "INFO" "qrencode 安装成功"
            return 0
        else
            log_message "ERROR" "qrencode 安装失败"
            return 1
        fi
    fi
    return 0
}

# 纯bash实现的简单二维码生成（备用方案）
generate_simple_qr() {
    local text="$1"
    local size=25
    
    echo -e "${CYAN}=== 分享链接二维码 ===${NC}"
    echo ""
    
    # 创建简单的ASCII二维码框架
    echo "$(printf '%.0s' $(seq 1 $[ $[ $((size*2)) ] ]))"
    # 生成伪随机模式（基于文本内容）
    
    # 生成文本的简单哈希
    local hash=$(echo -n "$text" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "$text" | od -An -tx1 | tr -d ' \n')
    
    for i in $(seq 1 $size); do
        echo -n "█"
        for j in $(seq 1 $size); do
            # 基于位置和哈希生成模式
            local pos=$[ $[ $((i * size + j)) ] ]
            local char_pos=$[ $[ $((pos % ${#hash})) ] ]
            local char_val=$(printf "%d" "'${hash:$char_pos:1}" 2>/dev/null || echo "65")
            
            if [ $[ $[ $((char_val % 3)) ] ] -eq 0 ]; then
                echo -n "██"
            else
                echo -n "  "
            fi
        done
        echo "█"
    done
    
    echo "$(printf '%.0s' $(seq 1 $[ $[ $((size*2)) ] ]))"
    echo ""
    echo -e "${YELLOW}注意: 这是装饰性二维码，请使用下方的文本链接${NC}"
    echo ""
}

# 生成真实的二维码
generate_qr_code() {
    local text="$1"
    local title="$2"
    
    echo -e "${CYAN}=== $title 二维�?===${NC}"
    echo ""
    
    # 尝试使用 qrencode
    if command -v qrencode >/dev/null 2>&1; then
        log_message "DEBUG" "使用 qrencode 生成二维码"
        
        # 生成UTF-8字符二维码
        if qrencode -t UTF8 -s 1 -m 1 "$text" 2>/dev/null; then
            echo ""
            return 0
        fi
        
        # 如果UTF-8失败，尝试ANSI
        if qrencode -t ANSI -s 1 -m 1 "$text" 2>/dev/null; then
            echo ""
            return 0
        fi
        
        # 如果都失败，使用ASCII
        if qrencode -t ASCII -s 1 -m 1 "$text" 2>/dev/null; then
            echo ""
            return 0
        fi
    fi
    
    # 如果 qrencode 不可用或失败，使用备用方案
    log_message "DEBUG" "使用备用二维码生成方案"
    generate_simple_qr "$text"
    return 0
}

# 显示协议二维码
show_protocol_qr() {
    local protocol="$1"
    
    case "$protocol" in
        "vless")
            if [ -n "$VLESS_UUID" ]; then
                local share_link=$(generate_vless_share_link)
                generate_qr_code "$share_link" "VLESS Reality"
                echo -e "${GREEN}分享链接:${NC}"
                echo "$share_link"
            else
                echo -e "${RED}VLESS 协议未配置${NC}"
            fi
            ;;
        "vmess")
            if [ -n "$VMESS_UUID" ]; then
                local share_link=$(generate_vmess_share_link)
                generate_qr_code "$share_link" "VMess WebSocket"
                echo -e "${GREEN}分享链接:${NC}"
                echo "$share_link"
            else
                echo -e "${RED}VMess 协议未配置${NC}"
            fi
            ;;
        "hysteria2")
            if [ -n "$HY2_PASSWORD" ]; then
                local share_link=$(generate_hysteria2_share_link)
                generate_qr_code "$share_link" "Hysteria2"
                echo -e "${GREEN}分享链接:${NC}"
                echo "$share_link"
            else
                echo -e "${RED}Hysteria2 协议未配置${NC}"
            fi
            ;;
        *)
            echo -e "${RED}未知协议: $protocol${NC}"
            return 1
            ;;
    esac
    
    echo ""
}

# 显示所有协议的二维码
show_all_qr_codes() {
    clear
    echo -e "${CYAN}=== 所有协议二维码 ===${NC}"
    echo ""
    
    # 检查并安装 qrencode
    install_qrencode
    
    local has_config=false
    
    # VLESS Reality
    if [ -n "$VLESS_UUID" ]; then
        show_protocol_qr "vless"
        has_config=true
        echo -e "${YELLOW}$(printf '=%.0s' {1..60})${NC}"
        echo ""
    fi
    
    # VMess WebSocket
    if [ -n "$VMESS_UUID" ]; then
        show_protocol_qr "vmess"
        has_config=true
        echo -e "${YELLOW}$(printf '=%.0s' {1..60})${NC}"
        echo ""
    fi
    
    # Hysteria2
    if [ -n "$HY2_PASSWORD" ]; then
        show_protocol_qr "hysteria2"
        has_config=true
    fi
    
    if [ "$has_config" == "false" ]; then
        echo -e "${YELLOW}暂无已配置的协议${NC}"
        echo -e "${YELLOW}请先配置协议后再生成二维码${NC}"
    fi
    
    echo ""
    wait_for_input
}

# 二维码菜单
show_qr_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== 二维码生成菜单 ===${NC}"
        echo ""
        echo -e "${YELLOW}请选择要生成二维码的协议${NC}"
        echo ""
        
        local option=1
        
        # 显示可用的协议选项
        if [ -n "$VLESS_UUID" ]; then
            echo -e "  ${GREEN}$option.${NC} VLESS Reality (端口: $VLESS_PORT)"
            [ $[ $((option++)) ] ]
        fi
        
        if [ -n "$VMESS_UUID" ]; then
            echo -e "  ${GREEN}$option.${NC} VMess WebSocket (端口: $VMESS_PORT)"
            [ $[ $((option++)) ] ]
        fi
        
        if [ -n "$HY2_PASSWORD" ]; then
            echo -e "  ${GREEN}$option.${NC} Hysteria2 (端口: $HY2_PORT)"
            [ $[ $((option++)) ] ]
        fi
        
        echo -e "  ${GREEN}$option.${NC} 显示所有协议二维码"
        [ $[ $((option++)) ] ]
        echo -e "  ${GREEN}0.${NC} 返回主菜单"
        echo ""
        
        if [ "$1" -eq "1" ]; then
            echo -e "${YELLOW}暂无已配置的协议，请先配置协议${NC}"
            echo ""
            wait_for_input
            return
        fi
        
        local choice
        echo -n -e "${YELLOW}请输入选择 [0-$[ $[ $((option-1)) ] ]]: ${NC}"
        read -r choice
        
        case "$choice" in
            0) return ;;
            *)
                local current_option=1
                
                if [ -n "$VLESS_UUID" ]; then
                    if [ "$choice" == "$current_option" ]; then
                        show_protocol_qr "vless"
                        wait_for_input
                        continue
                    fi
                    [ $[ $((current_option++)) ] ]
                fi
                
                if [ -n "$VMESS_UUID" ]; then
                    if [ "$choice" == "$current_option" ]; then
                        show_protocol_qr "vmess"
                        wait_for_input
                        continue
                    fi
                    [ $[ $((current_option++)) ] ]
                fi
                
                if [ -n "$HY2_PASSWORD" ]; then
                    if [ "$choice" == "$current_option" ]; then
                        show_protocol_qr "hysteria2"
                        wait_for_input
                        continue
                    fi
                    [ $[ $((current_option++)) ] ]
                fi
                
                if [ "$choice" == "$current_option" ]; then
                    show_all_qr_codes
                    continue
                fi
                
                echo -e "${RED}无效选择，请重新输入${NC}"
                wait_for_input
                ;;
        esac
    done
}

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
            if [ "$DEBUG" == "true" ]; then
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
    
    log_message "ERROR" "在函数 $function_name 中发生错误(代码: $error_code): $error_message"
    
    # 记录调用栈
     log_message "DEBUG" "调用栈"
    for ((i=1; i<$(echo "${1}" | wc -w); i++)); do
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
    if [ -n "$details" ]; then
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
    if [ -n "$details" ]; then
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
    elif [ -r /proc/sys/kernel/random/uuid ]; then
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
        return 0  # 端口被占�?    else
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
    
    if [ -n "$ip" ]; then
        echo "$ip"
    else
        log_warn "无法获取公网 IP"
        echo "127.0.0.1"
    fi
}

# 验证端口范围
validate_port() {
    local port="$1"
    if echo "$port" | grep -E '^[0-9]+$' >/dev/null && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

# 获取服务状�?get_service_status() {
    local service="$1"
    
    # 检查服务文件是否存�?    if ! systemctl list-unit-files 2>/dev/null | grep -q "^$service.service"; then
        echo "not_installed"
        return
    fi
    
    # 检查服务是否正在运�?    if systemctl is-active "$service" >/dev/null 2>&1; then
        echo "running"
    elif systemctl is-failed "$service" >/dev/null 2>&1; then
        echo "failed"
    elif systemctl is-enabled "$service" >/dev/null 2>&1; then
        echo "stopped"
    else
        echo "disabled"
    fi
}

# 获取服务状态的详细描述
get_service_status_description() {
    local service="$1"
    local status=$(get_service_status "$service")
    
    case "$status" in
        "running")
            echo -e "${GREEN}运行�?{NC}"
            ;;
        "stopped")
            echo -e "${YELLOW}已停�?{NC}"
            ;;
        "failed")
            echo -e "${RED}启动失败${NC}"
            ;;
        "disabled")
            echo -e "${YELLOW}已禁�?{NC}"
            ;;
        "not_installed")
            echo -e "${RED}未安�?{NC}"
            ;;
        *)
            echo -e "${RED}未知状�?{NC}"
            ;;
    esac
}

# 检查安装状�?check_installation_status() {
    local issues=""
    
    # 检查二进制文件
    if [ ! -f "$SINGBOX_BINARY" ]; then
        issues="$issues Sing-box 二进制文件未安装"
    elif [ ! -x "$SINGBOX_BINARY" ]; then
        issues="$issues Sing-box 二进制文件无执行权限"
    fi
    
    # 检查服务文�?    if ! systemctl list-unit-files 2>/dev/null | grep -q "^$SERVICE_NAME.service"; then
        issues="$issues systemd 服务文件未创建"
    fi
    
    # 检查工作目�?    if [ ! -d "$WORK_DIR" ]; then
        issues="$issues 工作目录不存在"
    fi
    
    # 检查配置文�?    if [ ! -f "$CONFIG_FILE" ]; then
        issues="$issues 配置文件不存在"
    fi
    
    if [ -n "$issues" ]; then
        echo -e "${RED}发现安装问题:${NC}"
        for issue in $issues; do
            echo -e "  ${RED}✗${NC} $issue"
        done
        echo ""
        echo -e "${YELLOW}建议: 请先完成 Sing-box 的完整安�?{NC}"
        return 1
    fi
    
    return 0
}

# 启动服务
start_service() {
    local service="$1"
    
    log_info "启动服务: $service"
    
    # 检查安装状�?    if ! check_installation_status; then
        log_error "安装状态检查失败，无法启动服务"
        return 1
    fi
    
    # 验证配置文件
    if [ -f "$CONFIG_FILE" ]; then
        if ! "$SINGBOX_BINARY" check -c "$CONFIG_FILE" 2>/dev/null; then
            log_error "配置文件验证失败: $CONFIG_FILE"
            log_error "请检查配置文件语法或重新生成配置"
            return 1
        fi
    else
        log_error "配置文件不存�? $CONFIG_FILE"
        log_error "请先配置协议生成配置文件"
        return 1
    fi
    
    # 启动服务
    if systemctl start "$service" 2>/dev/null; then
        # 等待服务启动
        sleep 2
        
        # 验证服务状�?        if systemctl is-active "$service" >/dev/null 2>&1; then
            log_success "服务启动成功: $service"
            return 0
        else
            log_error "服务启动后状态异�?
            show_service_diagnostics "$service"
            return 1
        fi
    else
        log_error "服务启动失败: $service"
        show_service_diagnostics "$service"
        return 1
    fi
}

# 停止服务
stop_service() {
    local service="$1"
    
    log_info "停止服务: $service"
    if systemctl stop "$service" 2>/dev/null; then
        log_success "服务停止成功: $service"
        return 0
    else
        log_error "服务停止失败: $service"
        show_service_diagnostics "$service"
        return 1
    fi
}

# 显示服务诊断信息
show_service_diagnostics() {
    local service="$1"
    
    echo -e "${YELLOW}=== 服务诊断信息 ===${NC}"
    echo ""
    
    # 显示服务状�?    echo -e "${CYAN}服务状�?${NC}"
    if systemctl status "$service" --no-pager -l 2>/dev/null; then
        echo ""
    else
        echo "无法获取服务状�?
        echo ""
    fi
    
    # 显示最近的日志
    echo -e "${CYAN}最近的服务日志:${NC}"
    if journalctl -u "$service" --no-pager -n 10 2>/dev/null; then
        echo ""
    else
        echo "无法获取服务日志"
        echo ""
    fi
    
    # 检查配置文�?    echo -e "${CYAN}配置文件检�?${NC}"
    if [ -f "$CONFIG_FILE" ]; then
        echo "�?配置文件存在: $CONFIG_FILE"
        if "$SINGBOX_BINARY" check -c "$CONFIG_FILE" 2>/dev/null; then
            echo "�?配置文件语法正确"
        else
            echo "�?配置文件语法错误"
            echo "  建议: 重新生成配置文件"
        fi
    else
        echo "�?配置文件不存�? $CONFIG_FILE"
        echo "  建议: 先配置协议生成配置文�?
    fi
    echo ""
    
    # 检查二进制文件
    echo -e "${CYAN}二进制文件检�?${NC}"
    if [ -f "$SINGBOX_BINARY" ]; then
        echo "�?Sing-box 二进制文件存�? $SINGBOX_BINARY"
        if "$SINGBOX_BINARY" version >/dev/null 2>&1; then
            local version=$("$SINGBOX_BINARY" version 2>/dev/null | head -n1 || echo "未知版本")
            echo "�?二进制文件可执行: $version"
        else
            echo "�?二进制文件无法执�?
            echo "  建议: 重新安装 Sing-box"
        fi
    else
        echo "�?Sing-box 二进制文件不存在: $SINGBOX_BINARY"
        echo "  建议: 先安�?Sing-box"
    fi
    echo ""
    
    # 检查端口占�?    echo -e "${CYAN}端口占用检�?${NC}"
    local ports_to_check=()
    [ -n "$VLESS_PORT" ] && ports_to_check="$1 $VLESS_PORT"
    [ -n "$VMESS_PORT" ] && ports_to_check="$1 $VMESS_PORT"
    [ -n "$HY2_PORT" ] && ports_to_check="$1 $HY2_PORT"
    
    if [ $(echo "${1}" | wc -w) -gt 0 ]; then
        for port in "$1"; do
            if check_port "$port"; then
                echo "�?端口 $port 被占�?
                echo "  占用进程: $(ss -tulpn | grep ":$port " | awk '{print $7}' | cut -d',' -f2 | cut -d'=' -f2 || echo '未知')"
            else
                echo "�?端口 $port 可用"
            fi
        done
    else
        echo "未配置端口信�?
    fi
    echo ""
    
    # 提供修复建议
    echo -e "${CYAN}修复建议:${NC}"
    echo "1. 检查配置文件语�? $SINGBOX_BINARY check -c $CONFIG_FILE"
    echo "2. 查看详细日志: journalctl -u $service -f"
    echo "3. 重新生成配置: 选择菜单中的协议配置选项"
    echo "4. 重新安装服务: 选择菜单中的安装选项"
    echo "5. 检查防火墙设置: 确保端口未被阻止"
    echo ""
    
    # 提供快速修复选项
    echo -e "${YELLOW}快速修复选项:${NC}"
    echo -n -e "${YELLOW}是否尝试自动修复常见问题? [y/N]: ${NC}"
    read -r auto_fix
    
    if echo "$auto_fix" | grep -E '^[Yy]$' >/dev/null; then
        echo ""
        echo -e "${CYAN}正在尝试自动修复...${NC}"
        
        # 1. 检查并修复配置文件权限
        if [ -f "$CONFIG_FILE" ]; then
            chmod 644 "$CONFIG_FILE"
            echo "�?已修复配置文件权�?
        fi
        
        # 2. 检查并修复二进制文件权�?        if [ -f "$SINGBOX_BINARY" ]; then
            chmod +x "$SINGBOX_BINARY"
            echo "�?已修复二进制文件权限"
        fi
        
        # 3. 重新加载systemd
        if systemctl daemon-reload 2>/dev/null; then
            echo "�?已重新加载systemd配置"
        fi
        
        # 4. 尝试重启服务
        echo ""
        echo -e "${YELLOW}尝试重启服务...${NC}"
        if restart_service "$service"; then
            echo -e "${GREEN}自动修复成功！服务已启动${NC}"
        else
            echo -e "${RED}自动修复失败，请手动检查问�?{NC}"
        fi
    fi
}

# 重启服务
restart_service() {
    local service="$1"
    
    log_message "INFO" "开始重启服�? $service"
    
    # 验证配置文件
    if [ -f "$CONFIG_FILE" ]; then
        log_message "DEBUG" "正在验证配置文件"
        if ! "$SINGBOX_BINARY" check -c "$CONFIG_FILE" 2>/dev/null; then
            handle_error 1 "配置文件验证失败"
            log_message "ERROR" "请检查配置文件语�? $CONFIG_FILE"
            return 1
        fi
        log_message "INFO" "配置文件验证通过"
    else
        handle_error 1 "配置文件不存�? $CONFIG_FILE"
        return 1
    fi
    
    # 检查服务是否存�?    if ! systemctl list-unit-files 2>/dev/null | grep -q "^$service.service"; then
        handle_error 1 "服务 $service 不存�?
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
    
    # 检查服务状�?    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if systemctl is-active "$service" >/dev/null 2>&1; then
            log_message "INFO" "服务 $service 重启成功"
            return 0
        fi
        
        log_message "DEBUG" "等待服务启动 (尝试 $attempt/$max_attempts)"
        sleep 2
        [ $[ $((attempt++)) ] ]
    done
    
    # 服务启动失败，获取详细错误信�?    local service_status
    service_status=$(systemctl status "$service" --no-pager -l 2>/dev/null || echo "无法获取服务状�?)
    
    handle_error 1 "服务 $service 启动超时或失�?
    log_message "ERROR" "服务状�? $service_status"
    log_message "ERROR" "建议查看详细日志: journalctl -u $service -f"
    
    return 1
}

# 等待用户输入
wait_for_input() {
    echo ""
    read -p "按回车键继续..." 
}

# ==================== 系统检查和安装 ====================

# 检�?root 权限
check_root() {
    if [ $EUID -ne 0 ]; then
        echo -e "${RED}错误: 此脚本需�?root 权限运行${NC}"
        echo -e "${YELLOW}请使�?sudo 或切换到 root 用户${NC}"
        exit 1
    fi
}

# 检测系统信�?detect_system() {
    # 检测操作系�?    if [ -f /etc/os-release ]; then
        source /etc/os-release
        OS="$ID"
    elif [ -f /etc/redhat-release ]; then
        OS="centos"
    else
        echo -e "${RED}错误: 不支持的操作系统${NC}"
        exit 1
    fi
    
    # 检测架�?    ARCH=$(uname -m)
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
    
    echo -e "${GREEN}系统检测完�?${NC}"
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
        missing_deps="$1 curl"
    fi
    
    if ! command -v tar >/dev/null 2>&1; then
        missing_deps="$1 tar"
    fi
    
    if [ $(echo "${1}" | wc -w) -gt 0 ]; then
        echo -e "${YELLOW}正在安装缺失的依�? ${missing_deps[*]}${NC}"
        
        # 根据系统类型安装依赖
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update >/dev/null 2>&1
            apt-get install -y "$1" >/dev/null 2>&1
        elif command -v yum >/dev/null 2>&1; then
            yum install -y "$1" >/dev/null 2>&1
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y "$1" >/dev/null 2>&1
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

# 下载和安�?Sing-box
download_and_install_singbox() {
    log_message "INFO" "开始下载和安装 Sing-box"
    
    # 检查系统架�?    if [ -z "$ARCH" ]; then
        handle_error 1 "系统架构未检�?
        return 1
    fi
    
    # 获取最新版�?    local latest_version
    log_message "DEBUG" "正在获取最新版本信�?
    
    if ! latest_version=$(curl -fsSL --max-time 30 "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep '"tag_name"' | cut -d'"' -f4 | sed 's/^v//'); then
        handle_error 1 "无法连接�?GitHub API"
        return 1
    fi
    
    if [ -z "$latest_version" ]; then
        handle_error 1 "无法解析最新版本信�?
        return 1
    fi
    
    log_message "INFO" "最新版�? $latest_version"
    
    # 构建下载URL
    local download_url="https://github.com/SagerNet/sing-box/releases/download/v${latest_version}/sing-box-${latest_version}-linux-${ARCH}.tar.gz"
    local temp_file="/tmp/sing-box-${latest_version}.tar.gz"
    
    log_message "DEBUG" "下载URL: $download_url"
    
    # 下载文件
    log_message "INFO" "正在下载 Sing-box"
    if ! check_command "curl -fsSL --progress-bar --max-time 300 -o '$temp_file' '$download_url'" "下载 Sing-box"; then
        return 1
    fi
    
    # 验证下载的文�?    if [ ! -f "$temp_file" ] || [ ! -s "$temp_file" ]; then
        handle_error 1 "下载的文件无效或为空"
        rm -f "$temp_file"
        return 1
    fi
    
    # 解压和安�?    local extract_dir="/tmp/sing-box-extract"
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
    if [ ! -f "$extract_dir/sing-box" ]; then
        handle_error 1 "解压后未找到 sing-box 二进制文�?
        rm -rf "$temp_file" "$extract_dir"
        return 1
    fi
    
    # 复制二进制文�?    if ! check_command "cp '$extract_dir/sing-box' '$SINGBOX_BINARY'" "安装 Sing-box 二进制文�?; then
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

# 生成 Reality 密钥�?generate_reality_keypair() {
    local keypair
    
    # 检�?sing-box 二进制文件是否存�?    if [ ! -f "$SINGBOX_BINARY" ]; then
        log_error "Sing-box 二进制文件不存在: $SINGBOX_BINARY"
        return 1
    fi
    
    keypair=$($SINGBOX_BINARY generate reality-keypair 2>/dev/null)
    
    if [ -n "$keypair" ]; then
        VLESS_PRIVATE_KEY=$(echo "$keypair" | grep "PrivateKey" | awk '{print $2}')
        VLESS_PUBLIC_KEY=$(echo "$keypair" | grep "PublicKey" | awk '{print $2}')
        
        # 验证密钥格式
        if [ -n "$VLESS_PRIVATE_KEY" ] && [ -n "$VLESS_PUBLIC_KEY" ]; then
            log_success "Reality 密钥对生成成�?
        else
            log_error "密钥对格式验证失�?
            return 1
        fi
    else
        log_error "Reality 密钥对生成失�?
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
    for target in "$1"; do
        [ "$target" == "$priority_target" ] && continue
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
    if [ -z "$VLESS_UUID" ]; then
        VLESS_UUID=$(generate_uuid)
        log_info "生成 UUID: $VLESS_UUID"
    fi
    
    # 检查端�?    if check_port "$VLESS_PORT"; then
        log_warn "端口 $VLESS_PORT 已被占用"
        VLESS_PORT=$(get_random_port)
        log_info "使用随机端口: $VLESS_PORT"
    fi
    
    # 确保使用高端�?    if [ "$VLESS_PORT" -lt 10000 ]; then
        log_warn "VLESS端口 $VLESS_PORT 低于10000，重新分配高端口"
        VLESS_PORT=$(get_random_port)
        log_info "VLESS高端�? $VLESS_PORT"
    fi
    
    # 生成密钥�?    if [ -z "$VLESS_PRIVATE_KEY" ] || [ -z "$VLESS_PUBLIC_KEY" ]; then
        generate_reality_keypair
    fi
    
    # 生成 Short ID
    if [ -z "$VLESS_SHORT_ID" ]; then
        generate_reality_short_id
    fi
    
    # 检测目�?    detect_reality_target
    
    log_success "VLESS Reality 配置完成"
}

# 配置 VMess WebSocket
configure_vmess_websocket() {
    log_info "配置 VMess WebSocket..."
    
    # 生成 UUID
    if [ -z "$VMESS_UUID" ]; then
        VMESS_UUID=$(generate_uuid)
        log_info "生成 UUID: $VMESS_UUID"
    fi
    
    # 生成 WebSocket 路径
    if [ -z "$VMESS_WS_PATH" ]; then
        VMESS_WS_PATH="/$(generate_random_string 8)"
        log_info "生成 WebSocket 路径: $VMESS_WS_PATH"
    fi
    
    # 设置 Host
    if [ -z "$VMESS_HOST" ]; then
        VMESS_HOST="$PUBLIC_IP"
    fi
    
    # 检查端�?    if check_port "$VMESS_PORT"; then
        log_warn "端口 $VMESS_PORT 已被占用"
        VMESS_PORT=$(get_random_port)
        log_info "使用随机端口: $VMESS_PORT"
    fi
    
    # 确保使用高端�?    if [ "$VMESS_PORT" -lt 10000 ]; then
        log_warn "VMess端口 $VMESS_PORT 低于10000，重新分配高端口"
        VMESS_PORT=$(get_random_port)
        log_info "VMess高端�? $VMESS_PORT"
    fi
    
    log_success "VMess WebSocket 配置完成"
}

# 配置 Hysteria2
configure_hysteria2() {
    log_info "配置 Hysteria2..."
    
    # 生成密码
    if [ -z "$HY2_PASSWORD" ]; then
        HY2_PASSWORD=$(generate_random_string 16)
        log_info "生成密码: $HY2_PASSWORD"
    fi
    
    # 生成混淆密码
    if [ -z "$HY2_OBFS_PASSWORD" ]; then
        HY2_OBFS_PASSWORD=$(generate_random_string 16)
        log_info "生成混淆密码: $HY2_OBFS_PASSWORD"
    fi
    
    # 设置域名
    if [ -z "$HY2_DOMAIN" ]; then
        HY2_DOMAIN="$PUBLIC_IP"
    fi
    
    # 检查端�?    if check_port "$HY2_PORT"; then
        log_warn "端口 $HY2_PORT 已被占用"
        HY2_PORT=$(get_random_port)
        log_info "使用随机端口: $HY2_PORT"
    fi
    
    # 确保使用高端�?    if [ "$HY2_PORT" -lt 10000 ]; then
        log_warn "Hysteria2端口 $HY2_PORT 低于10000，重新分配高端口"
        HY2_PORT=$(get_random_port)
        log_info "Hysteria2高端�? $HY2_PORT"
    fi
    
    log_success "Hysteria2 配置完成"
}

# 生成完整配置文件
generate_config() {
    log_message "INFO" "开始生成配置文�?
    
    # 确保配置目录存在
    if ! mkdir -p "$(dirname "$CONFIG_FILE")"; then
        handle_error 1 "无法创建配置目录"
        return 1
    fi
    
    # 备份现有配置
    if [ -f "$CONFIG_FILE" ]; then
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
  "dns": {
    "servers": [
      {
        "tag": "cloudflare",
        "address": "https://1.1.1.1/dns-query",
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
        "geosite": "cn",
        "server": "local"
      }
    ],
    "strategy": "prefer_ipv4"
  },
  "inbounds": [
EOF
    then
        handle_error 1 "无法写入基础配置文件"
        return 1
    fi

    local inbounds=()
    local first_inbound=true
    
    # VLESS Reality 入站
    if [ -n "$VLESS_UUID" ]; then
        log_message "DEBUG" "添加 VLESS Reality 配置"
        inbounds="$1 vless"
        if [ "$first_inbound" != "true" ]; then
            echo "," >> "$CONFIG_FILE"
        fi
        first_inbound=false
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
      },
      "sniff": {
        "enabled": true,
        "sniff_override_destination": true
      }
    }
EOF
        then
            handle_error 1 "无法写入 VLESS 配置"
            return 1
        fi
    fi
    
    # VMess WebSocket 入站
    if [ -n "$VMESS_UUID" ]; then
        log_message "DEBUG" "添加 VMess WebSocket 配置"
        if [ "$first_inbound" != "true" ]; then
            echo "," >> "$CONFIG_FILE"
        fi
        first_inbound=false
        inbounds="$1 vmess"
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
      },
      "sniff": {
        "enabled": true,
        "sniff_override_destination": true
      }
    }
EOF
        then
            handle_error 1 "无法写入 VMess 配置"
            return 1
        fi
    fi
    
    # Hysteria2 入站
    if [ -n "$HY2_PASSWORD" ]; then
        log_message "DEBUG" "添加 Hysteria2 配置"
        if [ "$first_inbound" != "true" ]; then
            echo "," >> "$CONFIG_FILE"
        fi
        first_inbound=false
        inbounds="$1 hysteria2"
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
        "password": "$HY2_OBFS_PASSWORD"
      },
      "sniff": {
        "enabled": true,
        "sniff_override_destination": true
      }
    }
EOF
        then
            handle_error 1 "无法写入 Hysteria2 配置"
            return 1
        fi
    fi
    
    # 检查是否至少有一个协议被配置
    if [ $(echo "${1}" | wc -w) -eq 0 ]; then
        handle_error 1 "没有配置任何协议，无法生成配置文�?
        return 1
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
      "type": "dns",
      "tag": "dns-out"
    },
    {
      "type": "block",
      "tag": "block"
    }
  ],
  "route": {
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      },
      {
        "ip_is_private": true,
        "outbound": "direct"
      }
    ],
    "auto_detect_interface": true
  }
}
EOF
    then
        handle_error 1 "无法完成配置文件写入"
        return 1
    fi
    
    # 验证生成的配置文�?    if [ ! -f "$CONFIG_FILE" ] || [ ! -s "$CONFIG_FILE" ]; then
        handle_error 1 "生成的配置文件无效或为空"
        return 1
    fi
    
    # �?Hysteria2 生成自签名证�?    if [ -n "$HY2_PASSWORD" ]; then
        if ! generate_hysteria2_cert; then
            handle_error 1 "Hysteria2 证书生成失败"
            return 1
        fi
    fi
    
    log_message "INFO" "配置文件生成完成: $CONFIG_FILE"
    return 0
}

# 生成 Hysteria2 自签名证�?generate_hysteria2_cert() {
    log_info "生成 Hysteria2 自签名证�?.."
    
    # 检�?HY2_DOMAIN 是否设置
    if [ -z "$HY2_DOMAIN" ]; then
        log_error "HY2_DOMAIN 未设置，无法生成证书"
        return 1
    fi
    
    # 创建证书目录
    if ! mkdir -p /etc/ssl/private; then
        log_error "无法创建证书目录"
        return 1
    fi
    
    # 检�?openssl 命令是否存在
    if ! command_exists openssl; then
        log_error "openssl 命令不存在，无法生成证书"
        return 1
    fi
    
    # 检�?openssl 版本和配�?    log_message "DEBUG" "OpenSSL 版本: $(openssl version 2>/dev/null || echo 'unknown')"
    
    # 生成私钥 - 使用更兼容的方法
    log_message "DEBUG" "正在生成 RSA 私钥"
    if ! openssl genrsa -out /etc/ssl/private/hysteria.key 2048 2>/dev/null; then
        log_error "生成私钥失败，尝试备用方�?
        # 备用方法：使�?genpkey
        if ! openssl genpkey -algorithm RSA -out /etc/ssl/private/hysteria.key -pkcs8 2>&1 | tee /tmp/openssl_error.log; then
            log_error "备用方法也失败，OpenSSL 错误信息�?
            if [ -f /tmp/openssl_error.log ]; then
                cat /tmp/openssl_error.log
                rm -f /tmp/openssl_error.log
            fi
            return 1
        fi
    fi
    
    # 验证私钥文件
    if [ ! -f "/etc/ssl/private/hysteria.key" ] || [ ! -s "/etc/ssl/private/hysteria.key" ]; then
        log_error "私钥文件生成失败或为�?
        return 1
    fi
    
    log_message "DEBUG" "正在生成自签名证�?
    # 生成证书
    if ! openssl req -new -x509 -key /etc/ssl/private/hysteria.key -out /etc/ssl/private/hysteria.crt -days 36500 -subj "/CN=$HY2_DOMAIN" 2>/dev/null; then
        log_error "生成证书失败，尝试一体化生成方法"
        # 备用方法：一条命令同时生成私钥和证书
        rm -f /etc/ssl/private/hysteria.key /etc/ssl/private/hysteria.crt
        if ! openssl req -x509 -newkey rsa:2048 -keyout /etc/ssl/private/hysteria.key -out /etc/ssl/private/hysteria.crt -days 36500 -nodes -subj "/CN=$HY2_DOMAIN" 2>/dev/null; then
            log_error "一体化生成也失败，尝试最简单的方法"
             # 最后备用方法：使用最基本的openssl命令
             if ! openssl genrsa 2048 > /etc/ssl/private/hysteria.key 2>/dev/null; then
                 log_error "所有私钥生成方法都失败，显示详细错误信�?
                 openssl req -x509 -newkey rsa:2048 -keyout /etc/ssl/private/hysteria.key -out /etc/ssl/private/hysteria.crt -days 36500 -nodes -subj "/CN=$HY2_DOMAIN" 2>&1 | tee /tmp/cert_error.log
                 if [ -f /tmp/cert_error.log ]; then
                     log_error "OpenSSL 错误信息�?
                     cat /tmp/cert_error.log
                     rm -f /tmp/cert_error.log
                 fi
                 log_warn "证书生成失败，但继续配置（可能影响连接）"
                 return 1
             fi
             
             # 生成对应的证�?             if ! openssl req -new -x509 -key /etc/ssl/private/hysteria.key -out /etc/ssl/private/hysteria.crt -days 36500 -subj "/CN=$HY2_DOMAIN" 2>/dev/null; then
                 log_warn "证书生成失败，但私钥已生�?
                 return 1
             fi
             log_success "使用基础方法成功生成证书"
        fi
        log_success "使用一体化方法成功生成证书"
    fi
    
    # 设置权限
    if ! chmod 600 /etc/ssl/private/hysteria.key; then
        log_warn "设置私钥权限失败"
    fi
    
    if ! chmod 644 /etc/ssl/private/hysteria.crt; then
        log_warn "设置证书权限失败"
    fi
    
    # 验证生成的文�?    if [ ! -f "/etc/ssl/private/hysteria.key" ] || [ ! -f "/etc/ssl/private/hysteria.crt" ]; then
        log_error "证书文件生成失败"
        return 1
    fi
    
    log_success "Hysteria2 证书生成完成"
    return 0
}

# ==================== 分享链接生成 ====================

# 生成 VLESS Reality 分享链接
generate_vless_share_link() {
    local server_ip="${1:-$PUBLIC_IP}"
    local remark="${2:-VLESS-Reality}"
    
    if [ -z "$VLESS_UUID" ] || [ -z "$VLESS_PORT" ]; then
        log_error "VLESS 配置信息不完�?
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
    
    if [ -z "$VMESS_UUID" ] || [ -z "$VMESS_PORT" ]; then
        log_error "VMess 配置信息不完�?
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
    
    if [ -z "$HY2_PASSWORD" ] || [ -z "$HY2_PORT" ]; then
        log_error "Hysteria2 配置信息不完�?
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

# 生成所有分享链�?generate_share_links() {
    echo -e "${CYAN}=== 分享链接 ===${NC}"
    echo ""
    
    local has_config=false
    
    # VLESS Reality
    if [ -n "$VLESS_UUID" ]; then
        echo -e "${GREEN}VLESS Reality Vision:${NC}"
        local vless_link
        vless_link=$(generate_vless_share_link)
        echo "$vless_link"
        echo ""
        has_config=true
    fi
    
    # VMess WebSocket
    if [ -n "$VMESS_UUID" ]; then
        echo -e "${GREEN}VMess WebSocket:${NC}"
        local vmess_link
        vmess_link=$(generate_vmess_share_link)
        echo "$vmess_link"
        echo ""
        has_config=true
    fi
    
    # Hysteria2
    if [ -n "$HY2_PASSWORD" ]; then
        echo -e "${GREEN}Hysteria2:${NC}"
        local hy2_link
        hy2_link=$(generate_hysteria2_share_link)
        echo "$hy2_link"
        echo ""
        has_config=true
    fi
    
    if [ "$has_config" == "false" ]; then
        echo -e "${YELLOW}未找到已配置的协�?{NC}"
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
    echo -e "  ${YELLOW}�?{NC} VLESS Reality Vision"
    echo -e "  ${YELLOW}�?{NC} VMess WebSocket"
    echo -e "  ${YELLOW}�?{NC} Hysteria2"
    echo -e "${CYAN}================================================================${NC}"
    echo ""
}

# 显示主菜�?show_main_menu() {
    while true; do
        clear
        echo -e "${CYAN}================================================================${NC}"
        echo -e "${CYAN}                    Sing-box 管理面板${NC}"
        echo -e "${CYAN}================================================================${NC}"
        echo ""
        
        # 显示系统信息
        echo -e "${GREEN}系统信息:${NC} $OS ($ARCH)"
        echo -e "${GREEN}公网IP:${NC} $PUBLIC_IP"
        
        # 显示服务状�?        echo -e "${GREEN}服务状�?${NC} $(get_service_status_description "$SERVICE_NAME")"
        
        # 显示配置状�?        echo -e "${GREEN}配置状�?${NC}"
        local status_line=""
        [ -n "$VLESS_PORT" ] && status_line+="VLESS(${VLESS_PORT}) "
        [ -n "$VMESS_PORT" ] && status_line+="VMess(${VMESS_PORT}) "
        [ -n "$HY2_PORT" ] && status_line+="Hysteria2(${HY2_PORT}) "
        
        if [ -n "$status_line" ]; then
            echo -e "${GREEN}已配�?${NC} $status_line"
        else
            echo -e "${YELLOW}未配置任何协�?{NC}"
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
        echo -e "  ${GREEN}6.${NC} 生成二维�?
        echo -e "  ${GREEN}7.${NC} 故障排除"
        echo -e "  ${GREEN}8.${NC} 卸载 Sing-box"
        echo -e "  ${GREEN}0.${NC} 退�?
        echo ""
        echo -e "${CYAN}================================================================${NC}"
        
        local choice
        echo -n -e "${YELLOW}请输入选择 [0-8]: ${NC}"
        read -r choice
        
        case "$choice" in
            1) quick_setup_all_protocols ;;
            2) show_protocol_menu ;;
            3) show_service_menu ;;
            4) show_config_info ;;
            5) generate_share_links ;;
            6) show_qr_menu ;;
            7) troubleshoot_menu ;;
            8) uninstall_singbox ;;
            0) 
                echo -e "${GREEN}感谢使用�?{NC}"
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
        echo -e "  ${GREEN}0.${NC} 返回主菜�?
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
        
        # 显示详细的服务状�?        echo -e "${GREEN}当前状�?${NC} $(get_service_status_description "$SERVICE_NAME")"
        
        # 显示配置文件状�?        if [ -f "$CONFIG_FILE" ]; then
            echo -e "${GREEN}配置文件:${NC} ${GREEN}存在${NC}"
        else
            echo -e "${GREEN}配置文件:${NC} ${RED}不存�?{NC}"
        fi
        
        # 显示二进制文件状�?        if [ -f "$SINGBOX_BINARY" ]; then
            echo -e "${GREEN}程序文件:${NC} ${GREEN}已安�?{NC}"
        else
            echo -e "${GREEN}程序文件:${NC} ${RED}未安�?{NC}"
        fi
        echo ""
        
        echo -e "${YELLOW}请选择操作:${NC}"
        echo ""
        echo -e "  ${GREEN}1.${NC} 启动服务"
        echo -e "  ${GREEN}2.${NC} 停止服务"
        echo -e "  ${GREEN}3.${NC} 重启服务"
        echo -e "  ${GREEN}4.${NC} 查看日志"
        echo -e "  ${GREEN}5.${NC} 服务诊断"
        echo -e "  ${GREEN}0.${NC} 返回主菜�?
        echo ""
        
        local choice
        echo -n -e "${YELLOW}请输入选择 [0-5]: ${NC}"
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
            5)
                show_service_diagnostics "$SERVICE_NAME"
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

# 显示服务日志
show_service_logs() {
    clear
    echo -e "${CYAN}=== Sing-box 服务日志 ===${NC}"
    echo ""
    echo -e "${YELLOW}最�?0行日�?${NC}"
    echo ""
    
    if systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
        journalctl -u "$SERVICE_NAME" -n 50 --no-pager
    else
        echo -e "${RED}服务未运�?{NC}"
    fi
    
    wait_for_input
}

# 显示配置信息
show_config_info() {
    clear
    echo -e "${CYAN}=== 配置信息 ===${NC}"
    echo ""
    
    # VLESS Reality
    if [ -n "$VLESS_UUID" ]; then
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
    if [ -n "$VMESS_UUID" ]; then
        echo -e "${GREEN}VMess WebSocket:${NC}"
        echo -e "  端口: $VMESS_PORT"
        echo -e "  UUID: $VMESS_UUID"
        echo -e "  路径: $VMESS_WS_PATH"
        echo -e "  Host: $VMESS_HOST"
        echo ""
    fi
    
    # Hysteria2
    if [ -n "$HY2_PASSWORD" ]; then
        echo -e "${GREEN}Hysteria2:${NC}"
        echo -e "  端口: $HY2_PORT"
        echo -e "  密码: $HY2_PASSWORD"
        echo -e "  混淆密码: $HY2_OBFS_PASSWORD"
        echo -e "  域名: $HY2_DOMAIN"
        echo ""
    fi
    
    if [ -z "$VLESS_UUID" ] && [ -z "$VMESS_UUID" ] && [ -z "$HY2_PASSWORD" ]; then
        echo -e "${YELLOW}未配置任何协�?{NC}"
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
        echo -e "  ${GREEN}1.${NC} 检查系统环�?
        echo -e "  ${GREEN}2.${NC} 验证配置文件"
        echo -e "  ${GREEN}3.${NC} 检查端口占�?
        echo -e "  ${GREEN}4.${NC} 测试网络连接"
        echo -e "  ${GREEN}5.${NC} 查看详细日志"
        echo -e "  ${GREEN}6.${NC} 重新生成配置"
        echo -e "  ${GREEN}0.${NC} 返回主菜�?
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

# 检查系统环�?check_system_environment() {
    clear
    echo -e "${CYAN}=== 系统环境检�?===${NC}"
    echo ""
    
    echo -e "${GREEN}1. 基础信息:${NC}"
    echo -e "  操作系统: $OS"
    echo -e "  架构: $ARCH"
    echo -e "  公网IP: $PUBLIC_IP"
    echo ""
    
    echo -e "${GREEN}2. Sing-box 状�?${NC}"
    if [ -f "$SINGBOX_BINARY" ]; then
        echo -e "  二进制文�? ${GREEN}存在${NC} ($SINGBOX_BINARY)"
        local version
        version=$("$SINGBOX_BINARY" version 2>/dev/null | head -n1 || echo "无法获取版本")
        echo -e "  版本信息: $version"
    else
        echo -e "  二进制文�? ${RED}不存�?{NC}"
    fi
    echo ""
    
    echo -e "${GREEN}3. 服务状�?${NC}"
    local status=$(get_service_status "$SERVICE_NAME")
    case "$status" in
        "running") echo -e "  服务状�? ${GREEN}运行�?{NC}" ;;
        "stopped") echo -e "  服务状�? ${YELLOW}已停�?{NC}" ;;
        *) echo -e "  服务状�? ${RED}未启�?{NC}" ;;
    esac
    echo ""
    
    echo -e "${GREEN}4. 配置文件:${NC}"
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "  配置文件: ${GREEN}存在${NC} ($CONFIG_FILE)"
        local size
        size=$(stat -c%s "$CONFIG_FILE" 2>/dev/null || echo "0")
        echo -e "  文件大小: ${size} 字节"
    else
        echo -e "  配置文件: ${RED}不存�?{NC}"
    fi
    echo ""
    
    wait_for_input
}

# 验证配置文件
validate_config_file() {
    clear
    echo -e "${CYAN}=== 配置文件验证 ===${NC}"
    echo ""
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}配置文件不存�? $CONFIG_FILE${NC}"
        wait_for_input
        return
    fi
    
    echo -e "${YELLOW}正在验证配置文件...${NC}"
    echo ""
    
    if "$SINGBOX_BINARY" check -c "$CONFIG_FILE"; then
        echo ""
        echo -e "${GREEN}配置文件验证通过�?{NC}"
    else
        echo ""
        echo -e "${RED}配置文件验证失败�?{NC}"
        echo -e "${YELLOW}请检查上述错误信息并修复配置${NC}"
    fi
    
    wait_for_input
}

# 检查端口占�?check_port_usage() {
    clear
    echo -e "${CYAN}=== 端口占用检�?===${NC}"
    echo ""
    
    local ports=("$VLESS_PORT" "$VMESS_PORT" "$HY2_PORT")
    local names=("VLESS" "VMess" "Hysteria2")
    
    for i in "$1"; do
        local port="${ports[$i]}"
        local name="${names[$i]}"
        
        if [ -n "$port" ]; then
            echo -e "${GREEN}检�?$name 端口 $port:${NC}"
            if check_port "$port"; then
                echo -e "  状�? ${YELLOW}被占�?{NC}"
                echo -e "  进程信息:"
                ss -tulnp | grep ":$port " | head -5
            else
                echo -e "  状�? ${GREEN}可用${NC}"
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
    if [ -n "$VLESS_TARGET" ]; then
        local host port
        host=$(echo "$VLESS_TARGET" | cut -d':' -f1)
        port=$(echo "$VLESS_TARGET" | cut -d':' -f2)
        
        if timeout 5 bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
            echo -e "  $VLESS_TARGET: ${GREEN}连接正常${NC}"
        else
            echo -e "  $VLESS_TARGET: ${RED}连接失败${NC}"
        fi
    else
        echo -e "  ${YELLOW}未配�?Reality 目标${NC}"
    fi
    echo ""
    
    wait_for_input
}

# 显示详细日志
show_detailed_logs() {
    clear
    echo -e "${CYAN}=== 详细日志信息 ===${NC}"
    echo ""
    
    echo -e "${YELLOW}最�?00行系统日�?${NC}"
    echo ""
    
    if systemctl list-unit-files 2>/dev/null | grep -q "sing-box.service"; then
        journalctl -u "$SERVICE_NAME" -n 100 --no-pager
    else
        echo -e "${RED}服务未安�?{NC}"
    fi
    
    wait_for_input
}

# 重新生成配置
regenerate_config() {
    clear
    echo -e "${CYAN}=== 重新生成配置 ===${NC}"
    echo ""
    echo -e "${RED}警告: 这将重新生成配置文件，现有配置将被覆�?{NC}"
    echo ""
    
    read -p "确认重新生成配置？[y/N]: " confirm
    if ! echo "$confirm" | grep -E '^[Yy]$' >/dev/null; then
        echo -e "${YELLOW}取消操作${NC}"
        wait_for_input
        return
    fi
    
    echo -e "${YELLOW}正在重新生成配置...${NC}"
    
    # 备份现有配置
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${GREEN}已备份现有配�?{NC}"
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

# 诊断节点连接问题
diagnose_connection_issues() {
    clear
    echo -e "${CYAN}=== 节点连接诊断 ===${NC}"
    echo ""
    
    local issues_found=false
    
    echo -e "${YELLOW}正在检查常见问�?..${NC}"
    echo ""
    
    # 1. 检查服务状�?    echo -e "${GREEN}1. 检查服务状�?${NC}"
    local status=$(get_service_status "$SERVICE_NAME")
    case "$status" in
        "running") 
            echo -e "  �?服务正在运行"
            ;;
        "stopped") 
            echo -e "  �?服务已停�?
            issues_found=true
            echo -e "  ${YELLOW}建议: 启动服务 - systemctl start $SERVICE_NAME${NC}"
            ;;
        *) 
            echo -e "  �?服务未启�?
            issues_found=true
            echo -e "  ${YELLOW}建议: 启用并启动服�?{NC}"
            ;;
    esac
    echo ""
    
    # 2. 检查配置文�?    echo -e "${GREEN}2. 检查配置文�?${NC}"
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "  �?配置文件存在"
        if "$SINGBOX_BINARY" check -c "$CONFIG_FILE" 2>/dev/null; then
            echo -e "  �?配置文件语法正确"
        else
            echo -e "  �?配置文件语法错误"
            issues_found=true
            echo -e "  ${YELLOW}建议: 重新生成配置文件${NC}"
        fi
    else
        echo -e "  �?配置文件不存�?
        issues_found=true
        echo -e "  ${YELLOW}建议: 生成配置文件${NC}"
    fi
    echo ""
    
    # 3. 检查端口占�?    echo -e "${GREEN}3. 检查端口状�?${NC}"
    local ports=("$VLESS_PORT" "$VMESS_PORT" "$HY2_PORT")
    local names=("VLESS" "VMess" "Hysteria2")
    
    for i in "$1"; do
        local port="${ports[$i]}"
        local name="${names[$i]}"
        
        if [ -n "$port" ]; then
            if check_port "$port"; then
                echo -e "  �?$name 端口 $port 正在使用"
            else
                echo -e "  �?$name 端口 $port 未被使用"
                issues_found=true
                echo -e "  ${YELLOW}建议: 检查服务是否正常启�?{NC}"
            fi
        fi
    done
    echo ""
    
    # 4. 检查防火墙
    echo -e "${GREEN}4. 检查防火墙状�?${NC}"
    if command_exists ufw; then
        if ufw status | grep -q "Status: active"; then
            echo -e "  ! UFW 防火墙已启用"
            echo -e "  ${YELLOW}建议: 确保已开放相关端�?{NC}"
        else
            echo -e "  �?UFW 防火墙未启用"
        fi
    elif command_exists firewall-cmd; then
        if firewall-cmd --state 2>/dev/null | grep -q "running"; then
            echo -e "  ! Firewalld 防火墙已启用"
            echo -e "  ${YELLOW}建议: 确保已开放相关端�?{NC}"
        else
            echo -e "  �?Firewalld 防火墙未启用"
        fi
    else
        echo -e "  ? 无法检测防火墙状�?
    fi
    echo ""
    
    # 5. 检查证书文件（Hysteria2�?    if [ -n "$HY2_PASSWORD" ]; then
        echo -e "${GREEN}5. 检�?Hysteria2 证书:${NC}"
        if [ -f "/etc/ssl/private/hysteria.crt" ] && [ -f "/etc/ssl/private/hysteria.key" ]; then
            echo -e "  �?证书文件存在"
        else
            echo -e "  �?证书文件缺失"
            issues_found=true
            echo -e "  ${YELLOW}建议: 重新生成证书${NC}"
        fi
        echo ""
    fi
    
    # 6. 检查网络连通�?    echo -e "${GREEN}6. 检查网络连通�?${NC}"
    if curl -s --max-time 5 www.google.com >/dev/null; then
        echo -e "  �?外网连接正常"
    else
        echo -e "  �?外网连接异常"
        issues_found=true
        echo -e "  ${YELLOW}建议: 检查网络设�?{NC}"
    fi
    echo ""
    
    # 总结
    if [ "$issues_found" == "true" ]; then
        echo -e "${RED}发现问题，请根据上述建议进行修复${NC}"
        echo ""
        echo -e "${YELLOW}快速修复选项:${NC}"
        echo -e "  1. 重新生成配置并重启服�?
        echo -e "  2. 配置防火墙规�?
        echo -e "  3. 重新生成证书"
        echo ""
        read -p "是否执行快速修复？[y/N]: " fix_confirm
        if echo "$fix_confirm" | grep -E '^[Yy]$' >/dev/null; then
            echo -e "${CYAN}正在执行快速修�?..${NC}"
            
            # 重新生成配置
            if generate_config; then
                echo -e "${GREEN}�?配置文件重新生成完成${NC}"
            fi
            
            # 重启服务
            if restart_service "$SERVICE_NAME"; then
                echo -e "${GREEN}�?服务重启成功${NC}"
            fi
            
            # 配置防火�?            configure_firewall
            
            echo -e "${GREEN}快速修复完�?{NC}"
        fi
    else
        echo -e "${GREEN}未发现明显问题，配置看起来正�?{NC}"
        echo -e "${YELLOW}如果仍然无法连接，请检�?${NC}"
        echo -e "  �?客户端配置是否正�?
        echo -e "  �?服务器IP地址是否正确"
        echo -e "  �?网络环境是否支持相关协议"
    fi
    
    wait_for_input
}

# 配置验证和修�?validate_and_fix_config() {
    clear
    echo -e "${CYAN}=== 配置验证和修�?===${NC}"
    echo ""
    
    local config_issues=false
    
    echo -e "${YELLOW}正在验证配置...${NC}"
    echo ""
    
    # 1. 检查配置文件是否存�?    echo -e "${GREEN}1. 检查配置文�?${NC}"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "  �?配置文件不存�?
        config_issues=true
        echo -e "  ${YELLOW}建议: 重新生成配置文件${NC}"
    else
        echo -e "  �?配置文件存在"
        
        # 检查配置文件语�?        if "$SINGBOX_BINARY" check -c "$CONFIG_FILE" 2>/dev/null; then
            echo -e "  �?配置文件语法正确"
        else
            echo -e "  �?配置文件语法错误"
            config_issues=true
            echo -e "  ${YELLOW}建议: 重新生成配置文件${NC}"
        fi
    fi
    echo ""
    
    # 2. 检查协议配�?    echo -e "${GREEN}2. 检查协议配�?${NC}"
    local protocols_configured=false
    
    if [ -n "$VLESS_UUID" ] && [ -n "$VLESS_PORT" ]; then
        echo -e "  �?VLESS Reality 已配�?(端口: $VLESS_PORT)"
        protocols_configured=true
    fi
    
    if [ -n "$VMESS_UUID" ] && [ -n "$VMESS_PORT" ]; then
        echo -e "  �?VMess WebSocket 已配�?(端口: $VMESS_PORT)"
        protocols_configured=true
    fi
    
    if [ -n "$HY2_PASSWORD" ] && [ -n "$HY2_PORT" ]; then
        echo -e "  �?Hysteria2 已配�?(端口: $HY2_PORT)"
        protocols_configured=true
    fi
    
    if [ "$protocols_configured" == "false" ]; then
        echo -e "  �?未配置任何协�?
        config_issues=true
        echo -e "  ${YELLOW}建议: 配置至少一个协�?{NC}"
    fi
    echo ""
    
    # 3. 检查端口冲�?    echo -e "${GREEN}3. 检查端口冲�?${NC}"
    local port_conflicts=false
    
    # 检查端口是否重�?    local ports=()
    [ -n "$VLESS_PORT" ] && ports="$1 $VLESS_PORT"
    [ -n "$VMESS_PORT" ] && ports="$1 $VMESS_PORT"
    [ -n "$HY2_PORT" ] && ports="$1 $HY2_PORT"
    
    # 检查重复端�?    local unique_ports=($(printf '%s\n' "$1" | sort -u))
    if [ $(echo "${1}" | wc -w) -ne $(echo "${1}" | wc -w) ]; then
        echo -e "  �?发现端口冲突"
        port_conflicts=true
        config_issues=true
        echo -e "  ${YELLOW}建议: 重新分配端口${NC}"
    else
        echo -e "  �?无端口冲�?
    fi
    
    # 检查端口是否被其他进程占用
    for port in "$1"; do
        if [ -n "$port" ]; then
            if ss -tuln | grep -q ":$port " && ! pgrep -f "sing-box" >/dev/null; then
                echo -e "  �?端口 $port 被其他进程占�?
                port_conflicts=true
                config_issues=true
            fi
        fi
    done
    
    if [ "$port_conflicts" == "false" ] && [ $(echo "${1}" | wc -w) -gt 0 ]; then
        echo -e "  �?端口状态正�?
    fi
    echo ""
    
    # 4. 检查证书文�?    if [ -n "$HY2_PASSWORD" ]; then
        echo -e "${GREEN}4. 检�?Hysteria2 证书:${NC}"
        if [ -f "/etc/ssl/private/hysteria.crt" ] && [ -f "/etc/ssl/private/hysteria.key" ]; then
            echo -e "  �?证书文件存在"
            
            # 检查证书有效�?            if openssl x509 -in "/etc/ssl/private/hysteria.crt" -noout -checkend 86400 2>/dev/null; then
                echo -e "  �?证书有效"
            else
                echo -e "  �?证书已过期或无效"
                config_issues=true
                echo -e "  ${YELLOW}建议: 重新生成证书${NC}"
            fi
        else
            echo -e "  �?证书文件缺失"
            config_issues=true
            echo -e "  ${YELLOW}建议: 重新生成证书${NC}"
        fi
        echo ""
    fi
    
    # 5. 检�?Reality 配置
    if [ -n "$VLESS_UUID" ]; then
        echo -e "${GREEN}5. 检�?VLESS Reality 配置:${NC}"
        if [ -n "$REALITY_PRIVATE_KEY" ] && [ -n "$REALITY_PUBLIC_KEY" ]; then
            echo -e "  �?Reality 密钥对已生成"
        else
            echo -e "  �?Reality 密钥对缺�?
            config_issues=true
            echo -e "  ${YELLOW}建议: 重新生成 Reality 配置${NC}"
        fi
        
        if [ -n "$REALITY_TARGET" ]; then
            echo -e "  �?Reality 目标已设�? $REALITY_TARGET"
        else
            echo -e "  �?Reality 目标未设�?
            config_issues=true
            echo -e "  ${YELLOW}建议: 设置 Reality 目标${NC}"
        fi
        echo ""
    fi
    
    # 总结和修复选项
    if [ "$config_issues" == "true" ]; then
        echo -e "${RED}发现配置问题，需要修�?{NC}"
        echo ""
        echo -e "${YELLOW}自动修复选项:${NC}"
        echo -e "  1. 重新生成所有配�?
        echo -e "  2. 重新分配端口"
        echo -e "  3. 重新生成证书"
        echo -e "  4. 重新生成 Reality 配置"
        echo ""
        
        read -p "是否执行自动修复？[y/N]: " fix_confirm
        if echo "$fix_confirm" | grep -E '^[Yy]$' >/dev/null; then
            echo -e "${CYAN}正在执行自动修复...${NC}"
            echo ""
            
            # 重新分配端口（如果有冲突�?            if [ "$port_conflicts" == "true" ]; then
                echo -e "${CYAN}重新分配端口...${NC}"
                [ -n "$VLESS_PORT" ] && VLESS_PORT=$(get_random_port)
                [ -n "$VMESS_PORT" ] && VMESS_PORT=$(get_random_port)
                [ -n "$HY2_PORT" ] && HY2_PORT=$(get_random_port)
                echo -e "${GREEN}�?端口重新分配完成${NC}"
            fi
            
            # 重新生成配置
            if generate_config; then
                echo -e "${GREEN}�?配置文件重新生成完成${NC}"
            fi
            
            # 保存配置
            save_config
            echo -e "${GREEN}�?配置已保�?{NC}"
            
            # 重启服务
            if restart_service "$SERVICE_NAME"; then
                echo -e "${GREEN}�?服务重启成功${NC}"
            fi
            
            echo -e "${GREEN}自动修复完成${NC}"
        fi
    else
        echo -e "${GREEN}配置验证通过，未发现问题${NC}"
    fi
    
    wait_for_input
}

# 生成客户端配置模�?generate_client_config_template() {
    clear
    echo -e "${CYAN}=== 客户端配置生�?===${NC}"
    echo ""
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}配置文件不存在，请先配置服务�?{NC}"
        wait_for_input
        return
    fi
    
    echo -e "${YELLOW}正在生成客户端配置模�?..${NC}"
    echo ""
    
    local client_config_dir="$WORK_DIR/client-configs"
    mkdir -p "$client_config_dir"
    
    # 生成通用客户端配�?    local client_config="$client_config_dir/sing-box-client.json"
    
    cat > "$client_config" << EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "cloudflare",
        "address": "https://1.1.1.1/dns-query"
      },
      {
        "tag": "local",
        "address": "223.5.5.5",
        "detour": "direct"
      }
    ],
    "rules": [
      {
        "geosite": "cn",
        "server": "local"
      }
    ],
    "strategy": "prefer_ipv4"
  },
  "inbounds": [
    {
      "type": "mixed",
      "tag": "mixed-in",
      "listen": "127.0.0.1",
      "listen_port": 7890
    },
    {
      "type": "tun",
      "tag": "tun-in",
      "interface_name": "tun0",
      "inet4_address": "172.19.0.1/30",
      "auto_route": true,
      "strict_route": false,
      "sniff": true
    }
  ],
  "outbounds": [
EOF
    
    # 添加配置的协议出�?    local outbounds_added=false
    
    # VLESS Reality
    if [ -n "$VLESS_UUID" ] && [ -n "$VLESS_PORT" ]; then
        if [ "$outbounds_added" == "true" ]; then
            echo "," >> "$client_config"
        fi
        cat >> "$client_config" << EOF
    {
      "type": "vless",
      "tag": "vless-reality",
      "server": "$PUBLIC_IP",
      "server_port": $VLESS_PORT,
      "uuid": "$VLESS_UUID",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "$REALITY_TARGET",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        },
        "reality": {
          "enabled": true,
          "public_key": "$REALITY_PUBLIC_KEY",
          "short_id": "$REALITY_SHORT_ID"
        }
      }
    }EOF
        outbounds_added=true
    fi
    
    # VMess WebSocket
    if [ -n "$VMESS_UUID" ] && [ -n "$VMESS_PORT" ]; then
        if [ "$outbounds_added" == "true" ]; then
            echo "," >> "$client_config"
        fi
        cat >> "$client_config" << EOF
    {
      "type": "vmess",
      "tag": "vmess-ws",
      "server": "$PUBLIC_IP",
      "server_port": $VMESS_PORT,
      "uuid": "$VMESS_UUID",
      "security": "auto",
      "transport": {
        "type": "ws",
        "path": "$VMESS_PATH",
        "headers": {
          "Host": "$VMESS_HOST"
        }
      }
    }EOF
        outbounds_added=true
    fi
    
    # Hysteria2
    if [ -n "$HY2_PASSWORD" ] && [ -n "$HY2_PORT" ]; then
        if [ "$outbounds_added" == "true" ]; then
            echo "," >> "$client_config"
        fi
        cat >> "$client_config" << EOF
    {
      "type": "hysteria2",
      "tag": "hysteria2",
      "server": "$PUBLIC_IP",
      "server_port": $HY2_PORT,
      "password": "$HY2_PASSWORD",
      "obfs": {
        "type": "salamander",
        "password": "$HY2_OBFS_PASSWORD"
      },
      "tls": {
        "enabled": true,
        "server_name": "$HY2_DOMAIN",
        "insecure": true
      }
    }EOF
        outbounds_added=true
    fi
    
    # 添加直连和DNS出站
    if [ "$outbounds_added" == "true" ]; then
        echo "," >> "$client_config"
    fi
    
    cat >> "$client_config" << EOF
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    },
    {
      "type": "dns",
      "tag": "dns-out"
    }
  ],
  "route": {
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      },
      {
        "geosite": "cn",
        "outbound": "direct"
      },
      {
        "geoip": "private",
        "outbound": "direct"
      }
    ],
    "auto_detect_interface": true
  }
}
EOF
    
    echo -e "${GREEN}客户端配置已生成:${NC}"
    echo -e "  ${CYAN}配置文件: $client_config${NC}"
    echo ""
    
    # 生成使用说明
    local readme_file="$client_config_dir/README.md"
    cat > "$readme_file" << EOF
# Sing-box 客户端配置说�?
## 配置文件
- \`sing-box-client.json\`: 通用客户端配置文�?
## 使用方法

### Windows
1. 下载 sing-box Windows 版本
2. 将配置文件放�?sing-box 同目�?3. 运行: \`sing-box.exe run -c sing-box-client.json\`

### macOS
1. 安装 sing-box: \`brew install sing-box\`
2. 运行: \`sing-box run -c sing-box-client.json\`

### Linux
1. 下载对应架构�?sing-box
2. 运行: \`./sing-box run -c sing-box-client.json\`

### Android
使用 SFA (Sing-box for Android) 应用，导入配置文�?
### iOS
使用支持 sing-box 的客户端应用

## 代理设置
- HTTP/SOCKS5 代理: 127.0.0.1:7890
- 或启�?TUN 模式进行全局代理

## 协议说明
EOF
    
    if [ -n "$VLESS_UUID" ]; then
        echo "- VLESS Reality: 高性能，推荐使�? >> "$readme_file"
    fi
    
    if [ -n "$VMESS_UUID" ]; then
        echo "- VMess WebSocket: 兼容性好，适合受限网络" >> "$readme_file"
    fi
    
    if [ -n "$HY2_PASSWORD" ]; then
        echo "- Hysteria2: 高速传输，适合高带宽需�? >> "$readme_file"
    fi
    
    echo -e "${GREEN}使用说明已生�?${NC}"
    echo -e "  ${CYAN}说明文件: $readme_file${NC}"
    echo ""
    
    echo -e "${YELLOW}提示:${NC}"
    echo -e "  �?客户端配置文件包含所有已配置的协�?
    echo -e "  �?可根据需要选择使用不同的出站标�?
    echo -e "  �?建议先测试连接再进行实际使用"
    echo -e "  �?配置文件位于: $client_config_dir"
    
    wait_for_input
}

# ==================== 一键配置功�?====================

# 一键配置所有协�?quick_setup_all_protocols() {
    echo -e "${CYAN}=== 一键配置三协议 ===${NC}"
    echo ""
    echo -e "${YELLOW}正在配置 VLESS Reality + VMess WebSocket + Hysteria2...${NC}"
    echo ""
    
    # 配置所有协�?    configure_vless_reality
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

# ==================== 安装和卸�?====================

# 执行完整安装
perform_installation() {
    echo -e "${CYAN}=== 开始安�?Sing-box ===${NC}"
    echo ""
    
    # 安装依赖
    install_dependencies
    
    # 创建目录
    create_directories
    
    # 下载和安�?    if ! download_and_install_singbox; then
        echo -e "${RED}安装失败${NC}"
        exit 1
    fi
    
    # 创建服务
    create_service
    
    echo ""
    echo -e "${GREEN}=== 安装完成 ===${NC}"
    echo -e "${YELLOW}现在可以配置协议�?{NC}"
    
    wait_for_input
}

# 卸载 Sing-box
uninstall_singbox() {
    echo -e "${CYAN}=== 卸载 Sing-box ===${NC}"
    echo ""
    echo -e "${RED}警告: 这将完全删除 Sing-box 及其所有配�?{NC}"
    echo ""
    
    read -p "确认卸载？[y/N]: " confirm
    if ! echo "$confirm" | grep -E '^[Yy]$' >/dev/null; then
        echo -e "${YELLOW}取消卸载${NC}"
        return
    fi
    
    # 停止服务
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    
    # 删除服务文件
    rm -f "/etc/systemd/system/$SERVICE_NAME.service"
    systemctl daemon-reload
    
    # ɾ���������ļ�
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
            echo -e "${YELLOW}Sing-box 未安装，开始安�?..${NC}"
            perform_installation
            # 安装完成后进入主菜单
            show_main_menu
            ;;
    esac
}

# ==================== 主函�?====================

# 加载现有配置
load_existing_config() {
    if [ -f "$CONFIG_FILE" ]; then
        log_info "检测到现有配置文件，尝试加载配置信�?.."
        
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

# 主函�?main() {
    # 初始化日�?    log_message "INFO" "Sing-box 一键安装脚本启�?
    log_message "DEBUG" "脚本版本: 2.0"
    log_message "DEBUG" "工作目录: $WORK_DIR"
    log_message "DEBUG" "配置文件: $CONFIG_FILE"
    log_message "DEBUG" "调试模式: $DEBUG"
    
    # 基础检�?    if ! check_root; then
        handle_error 1 "需�?root 权限运行此脚�?
        exit 1
    fi
    
    show_banner
    
    if ! detect_system; then
        handle_error 1 "系统检测失�?
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

# ==================== 命令行参数处�?====================

# 处理命令行参�?case "${1:-}" in
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
        log_message "INFO" "执行快速配置模�?
        check_root
        echo -e "${CYAN}=== 一键安装并配置三协�?===${NC}"
        echo ""
        
        # 先安�?Sing-box
        if ! command -v sing-box &> /dev/null; then
            log_message "INFO" "正在安装 Sing-box"
            detect_system
            perform_installation
        else
            log_message "INFO" "Sing-box 已安�?
        fi
        
        # 执行一键配�?        log_message "INFO" "正在进行一键配置三协议"
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
        echo -e "  $0                # 启动交互式菜�?
        echo -e "  $0 --install      # 直接安装"
        echo -e "  $0 --uninstall    # 一键完全卸�?
        echo -e "  $0 --quick-setup  # 一键安装并配置三协�?
        echo -e "  $0 --debug        # 启用调试模式"
        echo -e "  $0 --help         # 显示帮助"
        echo ""
        echo -e "${CYAN}一键安装特�?${NC}"
        echo -e "  ${GREEN}�?{NC} 自动安装 Sing-box"
        echo -e "  ${GREEN}�?{NC} 配置三种协议 (VLESS Reality + VMess WebSocket + Hysteria2)"
        echo -e "  ${GREEN}�?{NC} 自动分配高端�?(10000+)"
        echo -e "  ${GREEN}�?{NC} 生成连接信息和分享链�?
        echo -e "  ${GREEN}�?{NC} 无需外部模块，单文件运行"
        echo -e "  ${GREEN}�?{NC} 增强的错误处理和故障排除功能"
        ;;
    *)
        main
        ;;
esac
