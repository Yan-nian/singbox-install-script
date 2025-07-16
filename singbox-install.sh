#!/bin/bash

# Sing-box 精简一键安装脚本
# 支持 VLESS Reality、VMess WebSocket、Hysteria2 协议
# 版本: v2.5.0
# 更新时间: 2025-01-16

# 设置错误处理，但允许某些命令失败
set -e

# 检查脚本执行环境
check_execution_environment() {
    # 检查是否通过管道或进程替换执行
    if [[ "${BASH_SOURCE[0]}" == "/dev/fd/"* ]] || [[ "${BASH_SOURCE[0]}" == "/proc/"* ]]; then
        echo -e "\033[1;33m[警告] 检测到脚本通过管道执行，某些功能可能受限\033[0m"
        echo -e "\033[1;33m[建议] 下载脚本到本地后执行以获得最佳体验\033[0m"
        echo ""
        # 给用户一些时间阅读警告
        sleep 2
    fi
}

# 早期执行环境检查
check_execution_environment

# 脚本信息
SCRIPT_NAME="Sing-box 精简安装脚本"
SCRIPT_VERSION="v2.5.0"

# 安全获取脚本目录
get_script_dir() {
    local source="${BASH_SOURCE[0]}"
    local dir
    
    # 处理符号链接
    while [[ -L "$source" ]]; do
        dir="$(cd -P "$(dirname "$source")" && pwd)"
        source="$(readlink "$source")"
        [[ $source != /* ]] && source="$dir/$source"
    done
    
    dir="$(cd -P "$(dirname "$source")" && pwd)"
    
    # 如果是通过管道或进程替换执行，尝试其他方法
    if [[ "$source" == "/dev/fd/"* ]] || [[ "$source" == "/proc/"* ]]; then
        # 尝试从当前工作目录
        if [[ -f "$(pwd)/singbox-install.sh" ]]; then
            dir="$(pwd)"
        # 尝试从常见位置
        elif [[ -f "/root/singbox-install.sh" ]]; then
            dir="/root"
        elif [[ -f "/tmp/singbox-install.sh" ]]; then
            dir="/tmp"
        else
            # 使用当前目录作为备选
            dir="$(pwd)"
        fi
    fi
    
    echo "$dir"
}

SCRIPT_DIR="$(get_script_dir)"

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

# 系统信息
OS=""
ARCH=""
PUBLIC_IP=""

# 基础日志函数
log_info() {
    local message="$1"
    local details="${2:-}"
    echo -e "${GREEN}[INFO] $message${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $message" >> "$LOG_FILE" 2>/dev/null || true
    if [[ -n "$details" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Details: $details" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

log_warn() {
    echo -e "${YELLOW}[WARN] $*${NC}"
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

# 基础验证函数
validate_port() {
    local port="$1"
    if [[ "$port" =~ ^[0-9]+$ ]] && [[ "$port" -ge 1 ]] && [[ "$port" -le 65535 ]]; then
        return 0
    else
        return 1
    fi
}

# 检查 Sing-box 安装状态
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

# 简化的诊断功能
diagnose_installation() {
    echo -e "${CYAN}=== Sing-box 状态 ===${NC}"
    
    # 检查二进制文件
    if [[ -f "$SINGBOX_BINARY" ]]; then
        echo -e "${GREEN}[OK]${NC} 二进制文件已安装"
    else
        echo -e "${RED}[NO]${NC} 二进制文件未安装"
    fi
    
    # 检查系统服务
    if systemctl list-unit-files 2>/dev/null | grep -q "sing-box.service"; then
        echo -e "${GREEN}[OK]${NC} 系统服务已安装"
    else
        echo -e "${RED}[NO]${NC} 系统服务未安装"
    fi
    
    echo
}

# 简化的安装管理菜单
show_installation_menu() {
    local install_info="$1"
    local status=$(echo "$install_info" | cut -d: -f1)
    
    echo -e "${CYAN}=== Sing-box 管理 ===${NC}"
    
    case "$status" in
        "installed")
            echo "1. 重新安装"
            echo "2. 更新版本"
            echo "3. 卸载"
            echo "0. 退出"
            echo
            
            read -p "请选择 [0-3]: " choice
            
            case "$choice" in
                1)
                    perform_installation
                    ;;
                2)
                    update_singbox
                    ;;
                3)
                    uninstall_singbox
                    ;;
                0)
                    exit 0
                    ;;
                *)
                    echo -e "${RED}无效选择${NC}"
                    show_installation_menu "$install_info"
                    ;;
            esac
            ;;
        "not_installed")
            echo -e "${YELLOW}Sing-box 未安装，开始安装...${NC}"
            perform_installation
            ;;
    esac
}

# 下载和安装 Sing-box
download_and_install_singbox() {
    echo -e "${CYAN}正在下载和安装 Sing-box...${NC}"
    
    # 检查系统架构
    if [[ -z "$ARCH" ]]; then
        echo -e "${RED}错误: 系统架构未检测${NC}"
        return 1
    fi
    
    # 获取最新版本
    local latest_version
    latest_version=$(curl -fsSL "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep '"tag_name"' | cut -d'"' -f4 | sed 's/^v//')
    
    if [[ -z "$latest_version" ]]; then
        echo -e "${RED}错误: 无法获取最新版本信息${NC}"
        return 1
    fi
    
    echo -e "${GREEN}最新版本: $latest_version${NC}"
    
    # 构建下载URL
    local download_url="https://github.com/SagerNet/sing-box/releases/download/v${latest_version}/sing-box-${latest_version}-linux-${ARCH}.tar.gz"
    local temp_file="/tmp/sing-box-${latest_version}.tar.gz"
    
    # 下载文件
    echo -e "${CYAN}正在下载 Sing-box...${NC}"
    if ! curl -fsSL "$download_url" -o "$temp_file"; then
        echo -e "${RED}错误: 下载失败${NC}"
        return 1
    fi
    
    # 解压和安装
    local extract_dir="/tmp/sing-box-extract"
    mkdir -p "$extract_dir"
    
    if tar -xzf "$temp_file" -C "$extract_dir" --strip-components=1; then
        if [[ -f "$extract_dir/sing-box" ]]; then
            cp "$extract_dir/sing-box" "$SINGBOX_BINARY"
            chmod +x "$SINGBOX_BINARY"
            echo -e "${GREEN}Sing-box 安装成功${NC}"
        else
            echo -e "${RED}错误: 解压后未找到二进制文件${NC}"
            return 1
        fi
    else
        echo -e "${RED}错误: 解压失败${NC}"
        return 1
    fi
    
    # 清理临时文件
    rm -rf "$temp_file" "$extract_dir"
    return 0
}

# 创建系统服务
create_systemd_service() {
    echo -e "${CYAN}正在创建系统服务...${NC}"
    
    # 创建服务文件
    cat > "/etc/systemd/system/sing-box.service" << EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
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
    systemctl enable sing-box
    
    echo -e "${GREEN}系统服务创建完成${NC}"
}

# 简化的安装函数
perform_installation() {
    echo -e "${CYAN}=== 开始安装 Sing-box ===${NC}"
    
    # 检查是否为覆盖安装
    local is_reinstall=false
    if [[ -f "$SINGBOX_BINARY" ]] || systemctl list-unit-files 2>/dev/null | grep -q "sing-box.service"; then
        is_reinstall=true
        echo -e "${YELLOW}检测到现有安装，执行覆盖安装...${NC}"
        
        # 停止现有服务
        if systemctl is-active sing-box >/dev/null 2>&1; then
            echo -e "${YELLOW}停止现有 Sing-box 服务...${NC}"
            systemctl stop sing-box
        fi
        
        # 备份现有配置
        if [[ -f "$CONFIG_FILE" ]]; then
            local backup_file="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
            cp "$CONFIG_FILE" "$backup_file"
            echo -e "${GREEN}配置已备份到: $backup_file${NC}"
        fi
    fi
    
    # 安装依赖
    echo -e "${CYAN}检查和安装依赖...${NC}"
    
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
    
    # 使用新的下载安装函数
    if download_and_install_singbox; then
        log_info "二进制文件安装成功"
    else
        log_error "二进制文件安装失败"
        exit 1
    fi
    
    create_systemd_service
    
    # 创建快捷命令（允许失败）
    if ! create_shortcut_command; then
        echo -e "${YELLOW}快捷命令创建失败，但不影响主要功能${NC}"
    fi
    
    # 如果是覆盖安装，尝试恢复配置
    if [[ "$is_reinstall" == "true" ]] && [[ -f "$CONFIG_FILE" ]]; then
        echo -e "${CYAN}检测到现有配置，尝试重启服务...${NC}"
        if systemctl is-enabled sing-box >/dev/null 2>&1; then
            systemctl start sing-box
            if systemctl is-active sing-box >/dev/null 2>&1; then
                echo -e "${GREEN}服务已重启并运行正常${NC}"
            else
                echo -e "${YELLOW}服务重启失败，可能需要重新配置${NC}"
            fi
        fi
    fi
    
    echo -e "${GREEN}安装完成！快捷命令 'sb' 已创建。${NC}"
    if command -v show_main_menu >/dev/null 2>&1; then
        show_main_menu
    fi
}

# 加载现有配置
load_existing_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        echo -e "${CYAN}正在加载现有配置...${NC}"
        if command -v auto_load_config >/dev/null 2>&1; then
            auto_load_config
        else
            # 兼容旧版本
            load_config || echo -e "${YELLOW}配置加载失败，将使用默认设置${NC}"
        fi
        
        # 显示配置状态
        if command -v get_config_status >/dev/null 2>&1; then
            local status=$(get_config_status)
            if [[ -n "$status" ]]; then
                echo -e "${GREEN}配置状态: $status${NC}"
            fi
        fi
        
        # 记录配置加载信息
        if command -v log_info >/dev/null 2>&1; then
            log_info "配置加载完成" "VLESS端口: ${VLESS_PORT:-未配置}, VMess端口: ${VMESS_PORT:-未配置}, Hysteria2端口: ${HY2_PORT:-未配置}"
        fi
    else
        echo -e "${YELLOW}未找到配置文件，将创建新配置${NC}"
    fi
}

# 更新 Sing-box
update_singbox() {
    echo -e "${CYAN}=== 更新 Sing-box ===${NC}"
    
    # 确保系统信息已检测
    if [[ -z "$ARCH" ]] || [[ -z "$OS" ]]; then
        echo -e "${YELLOW}检测系统信息...${NC}"
        detect_system
    fi
    
    # 验证关键变量
    if [[ -z "$ARCH" ]]; then
        echo -e "${RED}错误: 无法检测系统架构${NC}"
        read -p "按回车键返回菜单..." 
        main
        return 1
    fi
    
    echo -e "${GREEN}系统架构: $ARCH${NC}"
    
    # 停止服务
    if systemctl is-active sing-box >/dev/null 2>&1; then
        echo -e "${YELLOW}停止 Sing-box 服务...${NC}"
        systemctl stop sing-box
    fi
    
    # 备份配置
    if [[ -f "$CONFIG_FILE" ]]; then
        local backup_file="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$CONFIG_FILE" "$backup_file"
        echo -e "${GREEN}配置已备份到: $backup_file${NC}"
    fi
    
    # 使用新的下载安装函数
    if download_and_install_singbox; then
        echo -e "${GREEN}Sing-box 更新成功${NC}"
        
        # 重启服务
        if systemctl is-enabled sing-box >/dev/null 2>&1; then
            echo -e "${YELLOW}重启 Sing-box 服务...${NC}"
            systemctl start sing-box
            
            if systemctl is-active sing-box >/dev/null 2>&1; then
                echo -e "${GREEN}Sing-box 更新完成并已重启${NC}"
            else
                echo -e "${RED}Sing-box 更新完成但启动失败，请检查配置${NC}"
            fi
        else
            echo -e "${GREEN}Sing-box 更新完成${NC}"
        fi
    else
        echo -e "${RED}更新失败: 无法安装新版本${NC}"
        
        # 尝试重启现有服务
        if systemctl is-enabled sing-box >/dev/null 2>&1; then
            echo -e "${YELLOW}尝试重启现有服务...${NC}"
            systemctl start sing-box
        fi
        
        read -p "按回车键返回菜单..." 
        main
        return 1
    fi
    
    read -p "按回车键返回菜单..." 
    main
}

# 一键完全卸载 Sing-box
uninstall_singbox() {
    echo -e "${CYAN}=== 一键完全卸载 Sing-box ===${NC}"
    echo -e "${RED}警告：这将完全删除 Sing-box 及其所有配置、日志、证书等文件！${NC}"
    echo -e "${YELLOW}将要删除的内容：${NC}"
    echo -e "  • Sing-box 服务和二进制文件"
    echo -e "  • 所有配置文件和目录"
    echo -e "  • 日志文件和证书"
    echo -e "  • 快捷命令和符号链接"
    echo -e "  • 防火墙规则（如果存在）"
    echo -e "  • 系统用户和组（如果存在）"
    echo
    read -p "输入 'UNINSTALL' 确认完全卸载: " confirm
    
    if [[ "$confirm" != "UNINSTALL" ]]; then
        echo -e "${YELLOW}卸载已取消${NC}"
        return
    fi
    
    echo -e "${CYAN}开始执行完全卸载...${NC}"
    
    # 1. 停止并禁用服务
    echo -e "${YELLOW}[1/8] 停止和禁用服务...${NC}"
    if systemctl is-active sing-box >/dev/null 2>&1; then
        systemctl stop sing-box
        log_info "已停止 Sing-box 服务"
    fi
    
    if systemctl is-enabled sing-box >/dev/null 2>&1; then
        systemctl disable sing-box
        log_info "已禁用 Sing-box 开机启动"
    fi
    
    # 2. 删除服务文件
    echo -e "${YELLOW}[2/8] 删除服务文件...${NC}"
    local service_files=(
        "/etc/systemd/system/sing-box.service"
        "/lib/systemd/system/sing-box.service"
        "/usr/lib/systemd/system/sing-box.service"
    )
    
    for service_file in "${service_files[@]}"; do
        if [[ -f "$service_file" ]]; then
            rm -f "$service_file"
            log_info "已删除服务文件: $service_file"
        fi
    done
    
    systemctl daemon-reload
    
    # 3. 删除二进制文件
    echo -e "${YELLOW}[3/8] 删除二进制文件...${NC}"
    local binary_files=(
        "$SINGBOX_BINARY"
        "/usr/bin/sing-box"
        "/usr/sbin/sing-box"
        "/opt/sing-box/sing-box"
    )
    
    for binary in "${binary_files[@]}"; do
        if [[ -f "$binary" ]]; then
            rm -f "$binary"
            log_info "已删除二进制文件: $binary"
        fi
    done
    
    # 4. 删除配置和工作目录
    echo -e "${YELLOW}[4/8] 删除配置和工作目录...${NC}"
    local config_dirs=(
        "$WORK_DIR"
        "/etc/sing-box"
        "/opt/sing-box"
        "/var/lib/sing-box"
        "/usr/local/etc/sing-box"
    )
    
    for dir in "${config_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            rm -rf "$dir"
            log_info "已删除目录: $dir"
        fi
    done
    
    # 5. 删除日志文件
    echo -e "${YELLOW}[5/8] 删除日志文件...${NC}"
    local log_files=(
        "$LOG_FILE"
        "/var/log/sing-box.log"
        "/var/log/sing-box/*.log"
        "/tmp/sing-box*.log"
    )
    
    for log_pattern in "${log_files[@]}"; do
        if ls $log_pattern >/dev/null 2>&1; then
            rm -f $log_pattern
            log_info "已删除日志文件: $log_pattern"
        fi
    done
    
    # 6. 删除快捷命令和符号链接
    echo -e "${YELLOW}[6/8] 删除快捷命令...${NC}"
    local shortcuts=(
        "/usr/local/bin/sb"
        "/usr/bin/sb"
        "/usr/local/bin/singbox"
        "/usr/bin/singbox"
    )
    
    for shortcut in "${shortcuts[@]}"; do
        if [[ -L "$shortcut" ]] || [[ -f "$shortcut" ]]; then
            rm -f "$shortcut"
            log_info "已删除快捷命令: $shortcut"
        fi
    done
    
    # 7. 清理防火墙规则（如果存在）
    echo -e "${YELLOW}[7/8] 清理防火墙规则...${NC}"
    if command -v ufw >/dev/null 2>&1; then
        # Ubuntu/Debian UFW
        ufw --force delete allow 443/tcp 2>/dev/null || true
        ufw --force delete allow 80/tcp 2>/dev/null || true
        log_info "已清理 UFW 防火墙规则"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        # CentOS/RHEL firewalld
        firewall-cmd --permanent --remove-port=443/tcp 2>/dev/null || true
        firewall-cmd --permanent --remove-port=80/tcp 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true
        log_info "已清理 firewalld 防火墙规则"
    fi
    
    # 8. 删除系统用户和组（如果存在）
    echo -e "${YELLOW}[8/8] 清理系统用户和组...${NC}"
    if id sing-box >/dev/null 2>&1; then
        userdel sing-box 2>/dev/null || true
        log_info "已删除系统用户: sing-box"
    fi
    
    if getent group sing-box >/dev/null 2>&1; then
        groupdel sing-box 2>/dev/null || true
        log_info "已删除系统组: sing-box"
    fi
    
    # 清理临时文件
    rm -rf /tmp/sing-box* 2>/dev/null || true
    rm -rf /tmp/singbox* 2>/dev/null || true
    
    echo
    echo -e "${GREEN}✅ Sing-box 已完全卸载！${NC}"
    echo -e "${GREEN}✅ 所有相关文件、配置、服务已清理完毕${NC}"
    echo -e "${CYAN}感谢使用 Sing-box 安装脚本！${NC}"
    exit 0
}

# 简化的模块加载
load_modules() {
    local lib_dir="$(dirname "$0")/lib"
    
    echo -e "${CYAN}正在加载模块...${NC}"
    
    # 只加载本地模块，简化逻辑
    if [[ -d "$lib_dir" ]]; then
        echo -e "${GREEN}使用本地模块目录: $lib_dir${NC}"
        
        # 按依赖顺序加载核心模块
        local core_modules=(
            "common.sh"
            "config_manager.sh"
            "protocols.sh"
            "menu.sh"
            "subscription.sh"
        )
        
        for module in "${core_modules[@]}"; do
            local module_path="$lib_dir/$module"
            if [[ -f "$module_path" ]]; then
                if source "$module_path" 2>/dev/null; then
                    echo -e "${GREEN}已加载模块: $module${NC}"
                else
                    echo -e "${YELLOW}警告: 加载模块失败: $module${NC}"
                fi
            else
                echo -e "${YELLOW}警告: 模块文件不存在: $module${NC}"
            fi
        done
        
        echo -e "${GREEN}模块加载完成${NC}"
        return 0
    else
        echo -e "${YELLOW}本地模块目录不存在，使用内置功能${NC}"
        return 1
    fi
}

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
    PUBLIC_IP=$(curl -s --max-time 10 ipv4.icanhazip.com || curl -s --max-time 10 ifconfig.me || echo "未知")
    
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

# 创建快捷命令（修复版）
create_shortcut_command() {
    echo -e "${CYAN}正在创建快捷命令...${NC}"
    
    # 检测操作系统类型
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$WINDIR" ]]; then
        # Windows 环境
        echo -e "${YELLOW}检测到 Windows 环境，创建批处理快捷命令...${NC}"
        
        # 创建批处理文件
        local batch_file="/c/Windows/System32/sb.bat"
        cat > "$batch_file" << EOF
@echo off
cd /d "%~dp0"
bash "$SCRIPT_DIR/singbox-install.sh" %*
EOF
        
        echo -e "${GREEN}Windows 快捷命令已创建${NC}"
        echo -e "${YELLOW}使用方法: 在 CMD 中输入 'sb'${NC}"
    else
        # Linux/Unix 环境
        local shortcut_path="/usr/local/bin/sb"
        
        # 获取脚本的绝对路径 - 修复版本
        local script_path
        
        # 首先尝试使用 SCRIPT_DIR 变量（在脚本开头定义）
        if [[ -n "$SCRIPT_DIR" ]] && [[ -f "$SCRIPT_DIR/$(basename "$0")" ]]; then
            script_path="$SCRIPT_DIR/$(basename "$0")"
        # 如果 $0 是绝对路径且文件存在
        elif [[ "$0" == /* ]] && [[ -f "$0" ]] && [[ "$0" != "/dev/fd/"* ]]; then
            script_path="$0"
        # 如果 $0 是相对路径
        elif [[ "$0" != "/dev/fd/"* ]] && [[ -f "$(pwd)/$0" ]]; then
            script_path="$(pwd)/$0"
        # 尝试通过 readlink 获取真实路径
        elif command -v readlink >/dev/null 2>&1 && [[ -f "$0" ]]; then
            script_path="$(readlink -f "$0" 2>/dev/null)"
        # 最后的备选方案：在常见位置查找脚本
        else
            local possible_paths=(
                "$SCRIPT_DIR/singbox-install.sh"
                "/root/singbox-install.sh"
                "/tmp/singbox-install.sh"
                "$(pwd)/singbox-install.sh"
            )
            
            for path in "${possible_paths[@]}"; do
                if [[ -f "$path" ]]; then
                    script_path="$path"
                    break
                fi
            done
        fi
        
        # 检查是否找到了有效的脚本路径
        if [[ -z "$script_path" ]] || [[ ! -f "$script_path" ]]; then
            echo -e "${YELLOW}警告: 无法确定脚本路径，跳过快捷命令创建${NC}"
            echo -e "${YELLOW}手动创建快捷命令: ln -sf /path/to/singbox-install.sh $shortcut_path${NC}"
            return 0
        fi
        
        # 删除已存在的符号链接（包括损坏的）
        if [[ -L "$shortcut_path" ]] || [[ -f "$shortcut_path" ]]; then
            rm -f "$shortcut_path" 2>/dev/null || sudo rm -f "$shortcut_path" 2>/dev/null
        fi
        
        # 创建新的符号链接
        if ln -sf "$script_path" "$shortcut_path" 2>/dev/null; then
            chmod +x "$shortcut_path" 2>/dev/null
            echo -e "${GREEN}快捷命令已创建: $shortcut_path -> $script_path${NC}"
        elif command -v sudo >/dev/null 2>&1; then
            # 使用sudo重试
            if sudo ln -sf "$script_path" "$shortcut_path" 2>/dev/null; then
                sudo chmod +x "$shortcut_path" 2>/dev/null
                echo -e "${GREEN}快捷命令已创建: $shortcut_path -> $script_path${NC}"
            else
                echo -e "${YELLOW}警告: 无法创建快捷命令${NC}"
                echo -e "${YELLOW}手动创建: sudo ln -sf \"$script_path\" $shortcut_path${NC}"
            fi
        else
            echo -e "${YELLOW}警告: 权限不足，无法创建快捷命令${NC}"
            echo -e "${YELLOW}手动创建: ln -sf \"$script_path\" $shortcut_path${NC}"
        fi
        
        echo -e "${CYAN}使用方法: 输入 'sb' 命令${NC}"
    fi
}

# 创建工作目录
create_directories() {
    echo -e "${CYAN}创建工作目录...${NC}"
    
    # 创建主要目录
    mkdir -p "$WORK_DIR"
    mkdir -p "$WORK_DIR/certs"
    mkdir -p "$WORK_DIR/logs"
    mkdir -p "$WORK_DIR/clients"
    mkdir -p "$WORK_DIR/qrcodes"
    mkdir -p "$WORK_DIR/subscription"
    
    # 设置目录权限
    chmod 755 "$WORK_DIR"
    chmod 750 "$WORK_DIR/logs"
    chmod 755 "$WORK_DIR/clients" "$WORK_DIR/qrcodes" "$WORK_DIR/subscription"
    
    # 创建日志文件
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    echo -e "${GREEN}工作目录创建完成${NC}"
}

# 清理临时文件
cleanup_temp_files() {
    local temp_dir="/tmp/singbox-modules"
    if [[ -d "$temp_dir" ]]; then
        rm -rf "$temp_dir"
        echo -e "${GREEN}已清理临时模块文件${NC}"
    fi
}

# 设置退出时清理
trap cleanup_temp_files EXIT

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

# 简化的主函数
main() {
    # 基础检查
    check_root
    show_banner
    detect_system
    create_directories
    
    # 加载模块（可选）
    load_modules 2>/dev/null || true
    
    # 检查安装状态并显示菜单
    local install_info=$(check_installation_status)
    local status=$(echo "$install_info" | cut -d: -f1)
    
    case "$status" in
        "installed")
            echo -e "${GREEN}Sing-box 已安装${NC}"
            show_installation_menu "$install_info"
            ;;
        "not_installed")
            echo -e "${YELLOW}Sing-box 未安装${NC}"
            show_installation_menu "$install_info"
            ;;
        *)
            echo -e "${RED}未知安装状态${NC}"
            exit 1
            ;;
    esac
}

# 处理命令行参数
case "${1:-}" in
    --install)
        check_root
        detect_system
        perform_installation
        ;;
    --uninstall)
        check_root
        uninstall_singbox
        ;;
    --help|-h)
        echo -e "${CYAN}$SCRIPT_NAME $SCRIPT_VERSION${NC}"
        echo ""
        echo -e "${YELLOW}用法:${NC}"
        echo -e "  $0                # 启动交互式菜单"
        echo -e "  $0 --install      # 直接安装"
        echo -e "  $0 --uninstall    # 一键完全卸载"
        echo -e "  $0 --help         # 显示帮助"
        echo ""
        echo -e "${YELLOW}快捷命令:${NC}"
        echo -e "  sb                # 等同于 $0"
        ;;
    *)
        main
        ;;
esac