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

# 获取脚本的实际路径（增强版）
get_actual_script_path() {
    local script_path=""
    
    # 方法1: 通过 ps 命令获取当前进程的命令行
    if command -v ps >/dev/null 2>&1; then
        script_path=$(ps -o args= -p $$ 2>/dev/null | awk '{print $2}' 2>/dev/null)
        if [[ -f "$script_path" ]] && [[ "$script_path" != "/dev/fd/"* ]]; then
            echo "$script_path"
            return 0
        fi
    fi
    
    # 方法2: 检查 /proc/self/cmdline
    if [[ -r "/proc/self/cmdline" ]]; then
        script_path=$(tr '\0' ' ' < /proc/self/cmdline 2>/dev/null | awk '{print $2}')
        if [[ -f "$script_path" ]] && [[ "$script_path" != "/dev/fd/"* ]]; then
            echo "$script_path"
            return 0
        fi
    fi
    
    # 方法3: 使用 realpath 命令
    if command -v realpath >/dev/null 2>&1; then
        script_path=$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)
        if [[ -f "$script_path" ]] && [[ "$script_path" != "/dev/fd/"* ]]; then
            echo "$script_path"
            return 0
        fi
    fi
    
    # 方法4: 传统方法但排除特殊文件描述符
    local source="${BASH_SOURCE[0]}"
    if [[ "$source" != "/dev/fd/"* ]] && [[ "$source" != "/proc/"* ]]; then
        if [[ "$source" == /* ]] && [[ -f "$source" ]]; then
            echo "$source"
            return 0
        elif [[ -f "$(pwd)/$source" ]]; then
            echo "$(pwd)/$source"
            return 0
        fi
    fi
    
    # 方法5: 在常见位置搜索
    local possible_paths=(
        "$(pwd)/singbox-install.sh"
        "/root/singbox-install.sh"
        "/tmp/singbox-install.sh"
        "/home/*/singbox-install.sh"
        "/opt/singbox/singbox-install.sh"
    )
    
    for path in "${possible_paths[@]}"; do
        if [[ -f "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    
    # 如果都失败了，返回空
    return 1
}

# 安全获取脚本目录
get_script_dir() {
    local script_path=$(get_actual_script_path)
    if [[ -n "$script_path" ]]; then
        dirname "$script_path"
    else
        pwd
    fi
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

# 统一的错误处理函数
handle_error() {
    local error_code="$1"
    local error_message="$2"
    local suggestion="${3:-}"
    
    log_error "错误代码: $error_code - $error_message"
    echo -e "${RED}[错误 $error_code] $error_message${NC}"
    
    if [[ -n "$suggestion" ]]; then
        echo -e "${YELLOW}建议: $suggestion${NC}"
    fi
    
    # 记录到错误日志
    mkdir -p "$WORK_DIR" 2>/dev/null || true
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR[$error_code]: $error_message" >> "$WORK_DIR/error.log" 2>/dev/null || true
}

# 成功操作的确认函数
confirm_operation() {
    local operation="$1"
    local details="$2"
    
    echo -e "${GREEN}✓ $operation 成功${NC}"
    if [[ -n "$details" ]]; then
        echo -e "${CYAN}  详情: $details${NC}"
    fi
    log_info "$operation 成功" "$details"
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

# 检查PATH环境变量
check_path_environment() {
    echo -e "${CYAN}检查PATH环境变量...${NC}"
    
    local path_dirs=("/usr/local/bin" "/usr/bin" "$HOME/.local/bin")
    
    for dir in "${path_dirs[@]}"; do
        if [[ ":$PATH:" == *":$dir:"* ]]; then
            echo -e "${GREEN}✓ $dir 在PATH中${NC}"
        else
            echo -e "${YELLOW}⚠ $dir 不在PATH中${NC}"
            if [[ "$dir" == "$HOME/.local/bin" ]]; then
                echo -e "${YELLOW}建议添加到 ~/.bashrc: export PATH=\"$dir:\$PATH\"${NC}"
            fi
        fi
    done
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
            echo "3. 验证安装"
            echo "4. 卸载"
            echo "0. 退出"
            echo
            
            read -p "请选择 [0-4]: " choice
            
            case "$choice" in
                1)
                    perform_installation
                    ;;
                2)
                    update_singbox
                    ;;
                3)
                    verify_installation
                    read -p "按回车键返回菜单..." 
                    show_installation_menu "$install_info"
                    ;;
                4)
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
    
    echo -e "${GREEN}Sing-box 安装完成！快捷命令 'sb' 已创建。${NC}"
    echo -e "${CYAN}配置文件位置: $WORK_DIR/config.json${NC}"
    echo -e "${CYAN}日志文件位置: $LOG_FILE${NC}"
    echo -e "${CYAN}使用 'sb' 命令快速管理 Sing-box${NC}"
    echo ""
    
    # 自动验证安装
    echo -e "${CYAN}正在验证安装...${NC}"
    echo ""
    if verify_installation; then
        echo ""
        echo -e "${YELLOW}请根据需要编辑配置文件，然后启动服务${NC}"
        echo -e "${CYAN}启动命令: sudo systemctl start sing-box${NC}"
        echo -e "${CYAN}开机自启: sudo systemctl enable sing-box${NC}"
    else
        echo ""
        echo -e "${RED}安装验证发现问题，请检查上述建议${NC}"
        echo -e "${YELLOW}可以稍后运行脚本选择 '验证安装' 重新检查${NC}"
    fi
    
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

# 创建快捷命令（增强版）
create_shortcut_command() {
    echo -e "${CYAN}正在创建快捷命令...${NC}"
    
    # 检测操作系统类型
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$WINDIR" ]]; then
        # Windows 环境
        echo -e "${YELLOW}检测到 Windows 环境，创建批处理快捷命令...${NC}"
        
        local script_path=$(get_actual_script_path)
        if [[ -z "$script_path" ]]; then
            script_path="$SCRIPT_DIR/singbox-install.sh"
        fi
        
        # 创建批处理文件
        local batch_file="/c/Windows/System32/sb.bat"
        cat > "$batch_file" << EOF
@echo off
cd /d "%~dp0"
bash "$script_path" %*
EOF
        
        confirm_operation "Windows 快捷命令创建" "批处理文件: $batch_file"
        echo -e "${YELLOW}使用方法: 在 CMD 中输入 'sb'${NC}"
        return 0
    fi
    
    # Linux/Unix 环境
    # 获取脚本的真实路径
    local script_path=$(get_actual_script_path)
    
    # 如果无法自动检测，提供交互式选择
    if [[ -z "$script_path" ]] || [[ ! -f "$script_path" ]]; then
        echo -e "${YELLOW}无法自动检测脚本路径${NC}"
        
        # 尝试查找可能的脚本位置
        local found_scripts=()
        while IFS= read -r -d '' script; do
            found_scripts+=("$script")
        done < <(find /root /tmp /home /opt -name "singbox-install.sh" -type f 2>/dev/null | head -5 | tr '\n' '\0')
        
        if [[ ${#found_scripts[@]} -gt 0 ]]; then
            echo -e "${CYAN}找到以下可能的脚本位置:${NC}"
            for i in "${!found_scripts[@]}"; do
                echo -e "  $((i+1)). ${found_scripts[i]}"
            done
            echo -e "  0. 手动输入路径"
            
            read -p "请选择脚本位置 [1-${#found_scripts[@]}/0]: " choice
            
            if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && [[ "$choice" -le "${#found_scripts[@]}" ]]; then
                script_path="${found_scripts[$((choice-1))]}"
            elif [[ "$choice" == "0" ]]; then
                read -p "请输入脚本的完整路径: " script_path
            else
                handle_error "SC001" "无效选择" "跳过快捷命令创建"
                return 1
            fi
        else
            read -p "请输入脚本的完整路径 (留空跳过): " script_path
        fi
        
        if [[ -z "$script_path" ]]; then
            echo -e "${YELLOW}跳过快捷命令创建${NC}"
            return 1
        fi
        
        if [[ ! -f "$script_path" ]]; then
            handle_error "SC002" "指定的路径无效: $script_path" "请检查文件是否存在"
            return 1
        fi
    fi
    
    echo -e "${GREEN}使用脚本路径: $script_path${NC}"
    
    # 检查PATH环境变量
    check_path_environment
    
    # 尝试多个可能的快捷命令位置
    local shortcut_locations=(
        "/usr/local/bin/sb"
        "/usr/bin/sb"
        "$HOME/.local/bin/sb"
    )
    
    local success=false
    local created_location=""
    
    for location in "${shortcut_locations[@]}"; do
        local dir=$(dirname "$location")
        
        # 确保目录存在
        if [[ ! -d "$dir" ]]; then
            if mkdir -p "$dir" 2>/dev/null || sudo mkdir -p "$dir" 2>/dev/null; then
                echo -e "${GREEN}创建目录: $dir${NC}"
            else
                echo -e "${YELLOW}无法创建目录: $dir，尝试下一个位置${NC}"
                continue
            fi
        fi
        
        # 删除已存在的符号链接（包括损坏的）
        if [[ -L "$location" ]] || [[ -f "$location" ]]; then
            rm -f "$location" 2>/dev/null || sudo rm -f "$location" 2>/dev/null
        fi
        
        # 创建符号链接
        if ln -sf "$script_path" "$location" 2>/dev/null; then
            chmod +x "$location" 2>/dev/null
            success=true
            created_location="$location"
            break
        elif command -v sudo >/dev/null 2>&1 && sudo ln -sf "$script_path" "$location" 2>/dev/null; then
            sudo chmod +x "$location" 2>/dev/null
            success=true
            created_location="$location"
            break
        else
            echo -e "${YELLOW}无法在 $location 创建快捷命令，尝试下一个位置${NC}"
        fi
    done
    
    if [[ "$success" == "true" ]]; then
        confirm_operation "快捷命令创建" "$created_location -> $script_path"
        
        # 验证快捷命令是否可用
        if command -v sb >/dev/null 2>&1; then
            echo -e "${GREEN}✓ 快捷命令 'sb' 验证成功${NC}"
        else
            echo -e "${YELLOW}⚠ 快捷命令已创建但可能需要重新加载 shell 或重新登录${NC}"
            echo -e "${YELLOW}或者运行: export PATH=\"$(dirname "$created_location"):\$PATH\"${NC}"
        fi
        
        echo -e "${CYAN}使用方法: 输入 'sb' 命令${NC}"
        return 0
    else
        handle_error "SC003" "快捷命令创建失败" "请手动创建: sudo ln -sf \"$script_path\" /usr/local/bin/sb"
        return 1
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

# 手动修复快捷命令
manual_fix_shortcut() {
    echo -e "${CYAN}=== 手动修复快捷命令 ===${NC}"
    
    # 获取脚本路径
    local script_path=$(get_actual_script_path)
    if [[ -z "$script_path" ]] || [[ ! -f "$script_path" ]]; then
        echo -e "${RED}无法确定脚本路径，请手动操作${NC}"
        echo -e "${YELLOW}手动创建步骤:${NC}"
        echo -e "${CYAN}1. 找到此脚本的完整路径${NC}"
        echo -e "${CYAN}2. 运行: sudo ln -sf /path/to/script /usr/local/bin/sb${NC}"
        echo -e "${CYAN}3. 运行: sudo chmod +x /usr/local/bin/sb${NC}"
        return 1
    fi
    
    echo -e "${GREEN}找到脚本路径: $script_path${NC}"
    
    # 尝试创建到不同位置
    local target_dirs=("/usr/local/bin" "/usr/bin" "$HOME/.local/bin")
    local success=false
    
    for target_dir in "${target_dirs[@]}"; do
        if [[ -d "$target_dir" ]] || mkdir -p "$target_dir" 2>/dev/null; then
            local target_path="$target_dir/sb"
            
            if ln -sf "$script_path" "$target_path" 2>/dev/null && chmod +x "$target_path" 2>/dev/null; then
                echo -e "${GREEN}✓ 成功创建快捷命令: $target_path${NC}"
                success=true
                
                # 检查是否在PATH中
                if [[ ":$PATH:" == *":$target_dir:"* ]]; then
                    echo -e "${GREEN}✓ $target_dir 已在 PATH 中${NC}"
                else
                    echo -e "${YELLOW}⚠ $target_dir 不在 PATH 中${NC}"
                    echo -e "${CYAN}建议添加到 ~/.bashrc 或 ~/.profile:${NC}"
                    echo -e "${CYAN}export PATH=\"$target_dir:\$PATH\"${NC}"
                fi
                break
            else
                echo -e "${RED}✗ 无法创建到 $target_path${NC}"
            fi
        else
            echo -e "${RED}✗ 无法访问目录 $target_dir${NC}"
        fi
    done
    
    if [[ "$success" == "true" ]]; then
        echo -e "${GREEN}快捷命令修复完成！${NC}"
        echo -e "${CYAN}测试命令: sb --help${NC}"
        
        # 重新加载命令缓存
        hash -r 2>/dev/null || true
        
        # 测试命令
        if command -v sb >/dev/null 2>&1; then
            echo -e "${GREEN}✓ 'sb' 命令现在可用${NC}"
        else
            echo -e "${YELLOW}⚠ 'sb' 命令仍不可用，可能需要重新加载 shell${NC}"
            echo -e "${CYAN}尝试运行: source ~/.bashrc 或重新打开终端${NC}"
        fi
    else
        echo -e "${RED}快捷命令修复失败${NC}"
        echo -e "${YELLOW}请手动创建或联系管理员${NC}"
        return 1
    fi
}

# 安装后验证功能
verify_installation() {
    echo -e "${CYAN}=== 安装验证 ===${NC}"
    
    local issues=()
    local warnings=()
    
    # 检查二进制文件
    if [[ -f "$SINGBOX_BINARY" ]] && [[ -x "$SINGBOX_BINARY" ]]; then
        local version=$($SINGBOX_BINARY version 2>/dev/null | head -1 || echo "未知版本")
        confirm_operation "Sing-box 二进制文件检查" "路径: $SINGBOX_BINARY, 版本: $version"
    else
        echo -e "${RED}✗ Sing-box 二进制文件异常${NC}"
        issues+=("binary")
    fi
    
    # 检查系统服务
    if systemctl list-unit-files 2>/dev/null | grep -q "sing-box.service"; then
        if systemctl is-enabled sing-box >/dev/null 2>&1; then
            confirm_operation "系统服务检查" "已安装并启用"
        else
            echo -e "${YELLOW}⚠ 系统服务已安装但未启用${NC}"
            warnings+=("service_disabled")
        fi
    else
        echo -e "${RED}✗ 系统服务未安装${NC}"
        issues+=("service")
    fi
    
    # 检查快捷命令
    if command -v sb >/dev/null 2>&1; then
        local sb_path=$(which sb 2>/dev/null)
        confirm_operation "快捷命令检查" "路径: $sb_path"
    else
        echo -e "${YELLOW}⚠ 快捷命令 'sb' 不可用${NC}"
        warnings+=("shortcut")
    fi
    
    # 检查配置目录
    if [[ -d "$WORK_DIR" ]]; then
        local dir_size=$(du -sh "$WORK_DIR" 2>/dev/null | cut -f1 || echo "未知")
        confirm_operation "工作目录检查" "路径: $WORK_DIR, 大小: $dir_size"
    else
        echo -e "${RED}✗ 工作目录不存在${NC}"
        issues+=("workdir")
    fi
    
    # 检查日志文件
    if [[ -f "$LOG_FILE" ]]; then
        echo -e "${GREEN}✓ 日志文件存在: $LOG_FILE${NC}"
    else
        echo -e "${YELLOW}⚠ 日志文件不存在${NC}"
        warnings+=("logfile")
    fi
    
    # 检查网络连接（可选）
    if command -v curl >/dev/null 2>&1; then
        if curl -s --max-time 5 --connect-timeout 3 https://www.google.com >/dev/null 2>&1; then
            echo -e "${GREEN}✓ 网络连接正常${NC}"
        else
            echo -e "${YELLOW}⚠ 网络连接可能有问题${NC}"
            warnings+=("network")
        fi
    fi
    
    echo ""
    
    # 提供修复建议
    if [[ ${#issues[@]} -gt 0 ]]; then
        echo -e "${RED}发现 ${#issues[@]} 个严重问题:${NC}"
        for issue in "${issues[@]}"; do
            case "$issue" in
                "binary")
                    echo -e "${RED}  • 二进制文件问题${NC}"
                    echo -e "${YELLOW}    修复: 重新运行安装或手动下载二进制文件${NC}"
                    ;;
                "service")
                    echo -e "${RED}  • 系统服务问题${NC}"
                    echo -e "${YELLOW}    修复: sudo systemctl enable sing-box${NC}"
                    ;;
                "workdir")
                    echo -e "${RED}  • 工作目录问题${NC}"
                    echo -e "${YELLOW}    修复: sudo mkdir -p $WORK_DIR${NC}"
                    ;;
            esac
        done
        echo ""
    fi
    
    if [[ ${#warnings[@]} -gt 0 ]]; then
        echo -e "${YELLOW}发现 ${#warnings[@]} 个警告:${NC}"
        for warning in "${warnings[@]}"; do
            case "$warning" in
                 "shortcut")
                     echo -e "${YELLOW}  • 快捷命令不可用${NC}"
                     echo -e "${CYAN}    建议: 重新加载 shell 或运行 'hash -r'${NC}"
                     echo -e "${CYAN}    或者: 运行手动修复功能${NC}"
                     ;;
                "service_disabled")
                    echo -e "${YELLOW}  • 服务未启用${NC}"
                    echo -e "${CYAN}    建议: sudo systemctl enable sing-box${NC}"
                    ;;
                "logfile")
                    echo -e "${YELLOW}  • 日志文件缺失${NC}"
                    echo -e "${CYAN}    建议: sudo touch $LOG_FILE${NC}"
                    ;;
                "network")
                    echo -e "${YELLOW}  • 网络连接异常${NC}"
                    echo -e "${CYAN}    建议: 检查网络设置和防火墙${NC}"
                    ;;
            esac
        done
        echo ""
    fi
    
    if [[ ${#issues[@]} -eq 0 ]] && [[ ${#warnings[@]} -eq 0 ]]; then
        echo -e "${GREEN}🎉 所有组件安装正常！${NC}"
        echo -e "${CYAN}可以开始配置和使用 Sing-box 了${NC}"
    elif [[ ${#issues[@]} -eq 0 ]]; then
        echo -e "${GREEN}✅ 核心组件安装正常${NC}"
        echo -e "${YELLOW}建议处理上述警告以获得最佳体验${NC}"
        
        # 检查是否有快捷命令问题，提供自动修复选项
        for warning in "${warnings[@]}"; do
            if [[ "$warning" == "shortcut" ]]; then
                echo ""
                read -p "是否要尝试自动修复快捷命令？[y/N]: " fix_shortcut
                if [[ "$fix_shortcut" =~ ^[Yy]$ ]]; then
                    echo ""
                    manual_fix_shortcut
                fi
                break
            fi
        done
    else
        echo -e "${RED}❌ 安装存在问题，建议修复后再使用${NC}"
        return 1
    fi
    
    return 0
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
    --verify)
        check_root
        verify_installation
        ;;
    --quick-setup)
        check_root
        echo -e "${CYAN}=== 一键安装并配置三协议 ===${NC}"
        echo ""
        
        # 先安装 Sing-box
        if ! command -v sing-box &> /dev/null; then
            echo -e "${YELLOW}正在安装 Sing-box...${NC}"
            perform_installation
        else
            echo -e "${GREEN}Sing-box 已安装${NC}"
        fi
        
        # 加载库文件
        load_modules
        
        # 执行一键配置
        echo -e "${YELLOW}正在进行一键配置三协议...${NC}"
        if command -v quick_setup_all_protocols >/dev/null 2>&1; then
            quick_setup_all_protocols
        else
            echo -e "${RED}一键配置功能不可用，请使用交互式菜单${NC}"
        fi
        exit 0
        ;;
    --help|-h)
        echo -e "${CYAN}$SCRIPT_NAME $SCRIPT_VERSION${NC}"
        echo ""
        echo -e "${YELLOW}用法:${NC}"
        echo -e "  $0                # 启动交互式菜单"
        echo -e "  $0 --install      # 直接安装"
        echo -e "  $0 --uninstall    # 一键完全卸载"
        echo -e "  $0 --verify       # 验证安装状态"
        echo -e "  $0 --quick-setup  # 一键安装并配置三协议"
        echo -e "  $0 --help         # 显示帮助"
        echo ""
        echo -e "${YELLOW}快捷命令:${NC}"
        echo -e "  sb                # 等同于 $0"
        echo ""
        echo -e "${CYAN}一键安装特点:${NC}"
        echo -e "  ${GREEN}✓${NC} 自动安装 Sing-box"
        echo -e "  ${GREEN}✓${NC} 配置三种协议 (VLESS Reality + VMess WebSocket + Hysteria2)"
        echo -e "  ${GREEN}✓${NC} 自动分配高端口 (10000+)"
        echo -e "  ${GREEN}✓${NC} 生成连接信息和二维码"
        ;;
    *)
        main
        ;;
esac