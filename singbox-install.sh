#!/bin/bash

# Sing-box 精简一键安装脚本
# 支持 VLESS Reality、VMess WebSocket、Hysteria2 协议
# 版本: v2.4.9
# 更新时间: 2025-01-16

set -e

# 脚本信息
SCRIPT_NAME="Sing-box 精简安装脚本"
SCRIPT_VERSION="v2.4.9"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# 定义关键函数 - 确保基础功能始终可用
define_essential_functions() {
    # 基础日志函数
    if ! command -v log_debug >/dev/null 2>&1; then
        log_debug() {
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $*" >&2
        }
    fi
    
    if ! command -v log_info >/dev/null 2>&1; then
        log_info() {
            echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*${NC}"
        }
    fi
    
    if ! command -v log_warn >/dev/null 2>&1; then
        log_warn() {
            echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $*${NC}" >&2
        }
    fi
    
    if ! command -v log_error >/dev/null 2>&1; then
        log_error() {
            echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*${NC}" >&2
        }
    fi
    
    # 基础验证函数
    if ! command -v validate_uuid >/dev/null 2>&1; then
        validate_uuid() {
            local uuid="$1"
            if [[ -z "$uuid" ]]; then
                log_error "UUID 参数不能为空"
                return 1
            fi
            
            if [[ "$uuid" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
                return 0
            else
                log_error "无效的 UUID 格式: $uuid"
                return 1
            fi
        }
    fi
    
    if ! command -v validate_port >/dev/null 2>&1; then
        validate_port() {
            local port="$1"
            if [[ -z "$port" ]]; then
                log_error "端口参数不能为空"
                return 1
            fi
            
            if [[ "$port" =~ ^[0-9]+$ ]] && [[ "$port" -ge 1 ]] && [[ "$port" -le 65535 ]]; then
                return 0
            else
                log_error "无效的端口号: $port (范围: 1-65535)"
                return 1
            fi
        }
    fi
    
    # 基础错误处理函数
    if ! command -v handle_error >/dev/null 2>&1; then
        handle_error() {
            local error_msg="$1"
            local exit_code="${2:-1}"
            log_error "$error_msg"
            exit "$exit_code"
        }
    fi
}

# 验证模块函数是否可用
verify_module_functions() {
    local missing_functions=()
    
    # 检查日志函数
    for func in log_debug log_info log_warn log_error; do
        if ! command -v "$func" >/dev/null 2>&1; then
            missing_functions+=("$func")
        fi
    done
    
    # 检查验证函数
    for func in validate_uuid validate_port; do
        if ! command -v "$func" >/dev/null 2>&1; then
            missing_functions+=("$func")
        fi
    done
    
    if [[ ${#missing_functions[@]} -gt 0 ]]; then
        echo "缺失函数: ${missing_functions[*]}"
        return 1
    fi
    
    return 0
}

# 自动修复缺失的模块函数
auto_repair_modules() {
    echo -e "${YELLOW}正在修复缺失的模块函数...${NC}"
    
    # 定义基础函数
    define_essential_functions
    
    # 重新验证
    if verify_module_functions; then
        echo -e "${GREEN}模块函数修复成功${NC}"
        return 0
    else
        echo -e "${RED}模块函数修复失败${NC}"
        return 1
    fi
}

# 诊断模块问题
diagnose_module_issues() {
    echo -e "${CYAN}正在诊断模块加载问题...${NC}"
    
    # 检查网络连接
    if ! curl -s --max-time 5 https://www.google.com >/dev/null 2>&1; then
        echo -e "${YELLOW}网络连接异常，可能影响远程模块下载${NC}"
    fi
    
    # 检查临时目录权限
    if [[ ! -w "/tmp" ]]; then
        echo -e "${RED}/tmp 目录无写入权限${NC}"
    fi
    
    # 检查本地模块目录
    local script_dir="$(dirname "$0")"
    if [[ -d "$script_dir/lib" ]]; then
        echo -e "${GREEN}发现本地模块目录: $script_dir/lib${NC}"
        ls -la "$script_dir/lib/" | head -10
    else
        echo -e "${YELLOW}本地模块目录不存在: $script_dir/lib${NC}"
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
        local version=$($SINGBOX_BINARY version 2>/dev/null | head -1 || echo "未知版本")
        details="二进制文件存在 ($version)"
    fi
    
    # 检查系统服务
    if systemctl list-unit-files 2>/dev/null | grep -q "sing-box.service"; then
        status="installed"
        if [[ "$install_method" == "unknown" ]]; then
            install_method="service"
            details="系统服务已安装"
        else
            install_method="complete"
            details="$details + 系统服务"
        fi
    fi
    
    # 检查配置文件
    if [[ -f "$CONFIG_FILE" ]]; then
        status="installed"
        if [[ "$install_method" == "unknown" ]]; then
            install_method="config"
            details="配置文件存在"
        else
            details="$details + 配置文件"
        fi
    fi
    
    # 检查配置目录
    if [[ -d "$WORK_DIR" ]] && [[ $(ls -A "$WORK_DIR" 2>/dev/null | wc -l) -gt 0 ]]; then
        status="installed"
        if [[ "$install_method" == "unknown" ]]; then
            install_method="config_dir"
            details="配置目录存在"
        else
            details="$details + 配置目录"
        fi
    fi
    
    echo "$status:$install_method:$details"
}

# 诊断安装状态
diagnose_installation() {
    echo -e "${CYAN}=== Sing-box 安装状态诊断 ===${NC}"
    echo
    
    # 检查二进制文件
    if [[ -f "$SINGBOX_BINARY" ]]; then
        local version=$($SINGBOX_BINARY version 2>/dev/null | head -1 || echo "版本获取失败")
        echo -e "${GREEN}[OK]${NC} 二进制文件: $SINGBOX_BINARY"
        echo -e "     版本: $version"
    else
        echo -e "${RED}[NO]${NC} 二进制文件: 未找到"
    fi
    
    # 检查系统服务
    if systemctl list-unit-files 2>/dev/null | grep -q "sing-box.service"; then
        local service_status=$(systemctl is-active sing-box 2>/dev/null || echo "未知")
        local service_enabled=$(systemctl is-enabled sing-box 2>/dev/null || echo "未知")
        echo -e "${GREEN}[OK]${NC} 系统服务: 已安装"
        echo -e "     状态: $service_status | 开机启动: $service_enabled"
    else
        echo -e "${RED}[NO]${NC} 系统服务: 未安装"
    fi
    
    # 检查配置文件
    if [[ -f "$CONFIG_FILE" ]]; then
        local config_size=$(du -h "$CONFIG_FILE" 2>/dev/null | cut -f1 || echo "未知")
        echo -e "${GREEN}[OK]${NC} 配置文件: $CONFIG_FILE"
        echo -e "     大小: $config_size"
    else
        echo -e "${RED}[NO]${NC} 配置文件: 未找到"
    fi
    
    # 检查配置目录
    if [[ -d "$WORK_DIR" ]]; then
        local file_count=$(ls -A "$WORK_DIR" 2>/dev/null | wc -l)
        echo -e "${GREEN}[OK]${NC} 配置目录: $WORK_DIR"
        echo -e "     文件数量: $file_count"
    else
        echo -e "${RED}[NO]${NC} 配置目录: 未找到"
    fi
    
    # 检查快捷命令
    if [[ -L "/usr/local/bin/sb" ]]; then
        local target=$(readlink /usr/local/bin/sb 2>/dev/null || echo "读取失败")
        echo -e "${GREEN}[OK]${NC} 快捷命令: /usr/local/bin/sb"
        echo -e "     指向: $target"
    else
        echo -e "${RED}[NO]${NC} 快捷命令: 未创建"
    fi
    
    # 检查端口占用
    if command -v netstat >/dev/null 2>&1; then
        local listening_ports=$(netstat -tlnp 2>/dev/null | grep sing-box | wc -l)
        if [[ $listening_ports -gt 0 ]]; then
            echo -e "${GREEN}[OK]${NC} 端口监听: $listening_ports 个端口"
        else
            echo -e "${YELLOW}[--]${NC} 端口监听: 无活动端口"
        fi
    fi
    
    echo
}

# 显示安装管理菜单
show_installation_menu() {
    local install_info="$1"
    local status=$(echo "$install_info" | cut -d: -f1)
    local method=$(echo "$install_info" | cut -d: -f2)
    local details=$(echo "$install_info" | cut -d: -f3)
    
    echo -e "${CYAN}=== Sing-box 管理菜单 ===${NC}"
    echo -e "${GREEN}当前状态:${NC} $details"
    echo
    
    case "$status" in
        "installed")
            echo -e "${GREEN}1.${NC} 显示主菜单（管理配置）"
            echo -e "${GREEN}2.${NC} 重新安装 Sing-box"
            echo -e "${GREEN}3.${NC} 更新 Sing-box 版本"
            echo -e "${GREEN}4.${NC} 显示安装状态诊断"
            echo -e "${GREEN}5.${NC} 卸载 Sing-box"
            echo -e "${GREEN}0.${NC} 退出"
            echo
            
            read -p "请选择 [0-5]: " choice
            
            case "$choice" in
                1)
                    # 加载现有配置并显示主菜单
                    load_existing_config
                    show_main_menu
                    ;;
                2)
                    echo -e "${YELLOW}确认重新安装？这将覆盖现有配置。${NC}"
                    read -p "输入 'yes' 确认: " confirm
                    if [[ "$confirm" == "yes" ]]; then
                        perform_installation
                    else
                        show_installation_menu "$install_info"
                    fi
                    ;;
                3)
                    update_singbox
                    ;;
                4)
                    diagnose_installation
                    read -p "按回车键返回菜单..." 
                    show_installation_menu "$install_info"
                    ;;
                5)
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
            echo -e "${YELLOW}Sing-box 未安装，开始安装流程...${NC}"
            perform_installation
            ;;
    esac
}

# 执行安装流程
perform_installation() {
    echo -e "${CYAN}=== 开始安装 Sing-box ===${NC}"
    
    # 记录安装开始
    if command -v log_info >/dev/null 2>&1; then
        log_info "开始安装Sing-box" "系统: $OS_TYPE"
    fi
    
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
    
    install_dependencies
    install_singbox
    create_service
    create_shortcut_command
    
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
    
    # 记录安装完成
    if command -v log_info >/dev/null 2>&1; then
        log_info "Sing-box安装完成" "服务已创建"
    fi
    
    echo -e "${GREEN}安装完成！快捷命令 'sb' 已创建。${NC}"
    show_main_menu
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
    
    # 重新安装二进制文件
    if ! install_singbox; then
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
    
    read -p "按回车键返回菜单..." 
    main
}

# 卸载 Sing-box
uninstall_singbox() {
    echo -e "${CYAN}=== 卸载 Sing-box ===${NC}"
    echo -e "${RED}警告：这将完全删除 Sing-box 及其所有配置！${NC}"
    read -p "输入 'UNINSTALL' 确认卸载: " confirm
    
    if [[ "$confirm" != "UNINSTALL" ]]; then
        echo -e "${YELLOW}卸载已取消${NC}"
        return
    fi
    
    # 停止并禁用服务
    if systemctl is-active sing-box >/dev/null 2>&1; then
        systemctl stop sing-box
    fi
    
    if systemctl is-enabled sing-box >/dev/null 2>&1; then
        systemctl disable sing-box
    fi
    
    # 删除服务文件
    if [[ -f "/etc/systemd/system/sing-box.service" ]]; then
        rm -f /etc/systemd/system/sing-box.service
        systemctl daemon-reload
    fi
    
    # 删除二进制文件
    if [[ -f "$SINGBOX_BINARY" ]]; then
        rm -f "$SINGBOX_BINARY"
    fi
    
    # 删除配置目录
    if [[ -d "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR"
    fi
    
    # 删除快捷命令
    if [[ -L "/usr/local/bin/sb" ]]; then
        rm -f /usr/local/bin/sb
    fi
    
    echo -e "${GREEN}Sing-box 已完全卸载${NC}"
    exit 0
}

# 加载模块 - 增强版
load_modules() {
    local lib_dir="$(dirname "$0")/lib"
    local base_url="https://raw.githubusercontent.com/Yan-nian/singbox-install-script/master/lib"
    local temp_dir="/tmp/singbox-modules"
    
    echo -e "${CYAN}正在加载模块...${NC}"
    
    # 首先定义关键函数，确保基础功能可用
    define_essential_functions
    
    # 优先使用本地模块目录
    if [[ -d "$lib_dir" ]] && [[ "$0" != "bash" ]] && [[ "$0" != "-bash" ]] && [[ "$(dirname "$0")" != "/dev/fd" ]]; then
        echo -e "${GREEN}使用本地模块目录: $lib_dir${NC}"
    else
        echo -e "${CYAN}检测到在线执行，正在下载模块...${NC}"
        
        # 创建临时目录
        mkdir -p "$temp_dir"
        
        # 下载模块文件（按依赖顺序）
        local modules=("error_handler.sh" "logger.sh" "validator.sh" "common.sh" "protocols.sh" "menu.sh" "subscription.sh" "config_manager.sh")
        local download_failed=false
        
        for module in "${modules[@]}"; do
            if curl -fsSL "$base_url/$module" -o "$temp_dir/$module" 2>/dev/null; then
                echo -e "${GREEN}已下载: $module${NC}"
            else
                echo -e "${RED}下载失败: $module${NC}"
                download_failed=true
            fi
        done
        
        if [[ "$download_failed" == "true" ]]; then
            echo -e "${YELLOW}部分模块下载失败，将使用内嵌函数${NC}"
            diagnose_module_issues
        fi
        
        lib_dir="$temp_dir"
    fi
    
    # 按依赖顺序加载模块
    
    # 1. 首先加载错误处理模块
    if [[ -f "$lib_dir/error_handler.sh" ]]; then
        source "$lib_dir/error_handler.sh"
        echo -e "${GREEN}已加载错误处理模块${NC}"
    else
        echo -e "${YELLOW}警告: 错误处理模块不存在，使用基础错误处理${NC}"
    fi
    
    # 2. 加载日志模块
    if [[ -f "$lib_dir/logger.sh" ]]; then
        source "$lib_dir/logger.sh"
        echo -e "${GREEN}已加载日志模块${NC}"
        # 初始化日志系统
        if command -v init_logger >/dev/null 2>&1; then
            init_logger
        fi
    else
        echo -e "${YELLOW}警告: 日志模块不存在，使用基础日志${NC}"
    fi
    
    # 3. 加载验证模块
    if [[ -f "$lib_dir/validator.sh" ]]; then
        source "$lib_dir/validator.sh"
        echo -e "${GREEN}已加载验证模块${NC}"
    else
        echo -e "${YELLOW}警告: 验证模块不存在，使用内嵌验证函数${NC}"
    fi
    
    # 4. 加载通用函数库
    if [[ -f "$lib_dir/common.sh" ]]; then
        source "$lib_dir/common.sh"
        echo -e "${GREEN}已加载通用函数库${NC}"
    else
        echo -e "${RED}错误: 通用函数库不存在${NC}"
        exit 1
    fi
    
    # 5. 加载配置管理模块（在协议模块之前）
    if [[ -f "$lib_dir/config_manager.sh" ]]; then
        source "$lib_dir/config_manager.sh"
        echo -e "${GREEN}已加载配置管理模块${NC}"
    else
        echo -e "${RED}错误: 配置管理模块不存在${NC}"
        exit 1
    fi
    
    # 6. 加载协议模块
    if [[ -f "$lib_dir/protocols.sh" ]]; then
        source "$lib_dir/protocols.sh"
        echo -e "${GREEN}已加载协议模块${NC}"
    else
        echo -e "${RED}错误: 协议模块不存在${NC}"
        exit 1
    fi
    
    # 7. 加载菜单模块
    if [[ -f "$lib_dir/menu.sh" ]]; then
        source "$lib_dir/menu.sh"
        echo -e "${GREEN}已加载菜单模块${NC}"
    else
        echo -e "${RED}错误: 菜单模块不存在${NC}"
        exit 1
    fi
    
    # 8. 加载订阅模块
    if [[ -f "$lib_dir/subscription.sh" ]]; then
        source "$lib_dir/subscription.sh"
        echo -e "${GREEN}已加载订阅模块${NC}"
    else
        echo -e "${RED}错误: 订阅模块不存在${NC}"
        exit 1
    fi
    
    # 验证关键函数是否可用
    echo -e "${CYAN}验证模块函数...${NC}"
    if ! verify_module_functions; then
        echo -e "${YELLOW}检测到缺失的函数，正在自动修复...${NC}"
        if ! auto_repair_modules; then
            echo -e "${RED}自动修复失败，某些功能可能不可用${NC}"
        fi
    fi
    
    echo -e "${GREEN}所有模块加载完成${NC}"
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
    echo -e "${CYAN}正在安装依赖...${NC}"
    
    case $OS in
        ubuntu|debian)
            echo -e "${CYAN}更新软件包列表...${NC}"
            apt update
            echo -e "${CYAN}安装必要依赖...${NC}"
            apt install -y \
                curl \
                wget \
                unzip \
                tar \
                gzip \
                openssl \
                qrencode \
                jq \
                uuid-runtime \
                coreutils \
                net-tools \
                procps \
                systemd \
                grep \
                gawk \
                sed \
                util-linux \
                ca-certificates
            ;;
        centos|rhel|fedora)
            if command -v dnf >/dev/null 2>&1; then
                echo -e "${CYAN}安装必要依赖...${NC}"
                dnf install -y \
                    curl \
                    wget \
                    unzip \
                    tar \
                    gzip \
                    openssl \
                    qrencode \
                    jq \
                    util-linux \
                    coreutils \
                    net-tools \
                    procps-ng \
                    systemd \
                    grep \
                    gawk \
                    sed \
                    ca-certificates
            else
                echo -e "${CYAN}安装必要依赖...${NC}"
                yum install -y \
                    curl \
                    wget \
                    unzip \
                    tar \
                    gzip \
                    openssl \
                    qrencode \
                    jq \
                    util-linux \
                    coreutils \
                    net-tools \
                    procps \
                    systemd \
                    grep \
                    gawk \
                    sed \
                    ca-certificates
            fi
            ;;
        *)
            echo -e "${YELLOW}警告: 未知系统 ($OS)，尝试安装基础依赖...${NC}"
            # 尝试使用通用包管理器
            if command -v apt >/dev/null 2>&1; then
                apt update && apt install -y curl wget unzip tar openssl jq
            elif command -v yum >/dev/null 2>&1; then
                yum install -y curl wget unzip tar openssl jq
            elif command -v pacman >/dev/null 2>&1; then
                pacman -Sy --noconfirm curl wget unzip tar openssl jq
            else
                echo -e "${RED}错误: 无法识别包管理器，请手动安装以下依赖:${NC}"
                echo -e "${YELLOW}curl wget unzip tar openssl jq uuid-runtime coreutils net-tools${NC}"
                read -p "按回车键继续..."
            fi
            ;;
    esac
    
    # 验证关键依赖是否安装成功
    echo -e "${CYAN}验证依赖安装...${NC}"
    local missing_deps=()
    local required_deps=("curl" "wget" "jq" "openssl" "tar" "unzip")
    
    for dep in "${required_deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}错误: 以下依赖安装失败: ${missing_deps[*]}${NC}"
        echo -e "${YELLOW}请手动安装这些依赖后重新运行脚本${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}所有依赖安装完成${NC}"
}

# 下载并安装 Sing-box
install_singbox() {
    echo -e "${CYAN}正在安装 Sing-box...${NC}"
    
    # 验证前置条件
    if [[ -z "$ARCH" ]]; then
        echo -e "${RED}错误: 系统架构未检测，请先运行系统检测${NC}"
        return 1
    fi
    
    echo -e "${GREEN}目标架构: $ARCH${NC}"
    
    # 获取最新版本（增加重试机制）
    local latest_version
    local retry_count=0
    local max_retries=3
    
    echo -e "${CYAN}正在获取最新版本信息...${NC}"
    while [[ $retry_count -lt $max_retries ]]; do
        latest_version=$(curl -s --max-time 30 "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep '"tag_name"' | cut -d'"' -f4 | sed 's/v//')
        
        if [[ -n "$latest_version" ]]; then
            break
        fi
        
        retry_count=$((retry_count + 1))
        echo -e "${YELLOW}获取版本信息失败，重试 $retry_count/$max_retries...${NC}"
        sleep 2
    done
    
    if [[ -z "$latest_version" ]]; then
        echo -e "${RED}错误: 无法获取最新版本信息，请检查网络连接${NC}"
        return 1
    fi
    
    echo -e "${GREEN}最新版本: v$latest_version${NC}"
    
    # 构建下载URL
    local download_url="https://github.com/SagerNet/sing-box/releases/download/v${latest_version}/sing-box-${latest_version}-linux-${ARCH}.tar.gz"
    local temp_file="/tmp/sing-box.tar.gz"
    
    echo -e "${CYAN}下载URL: $download_url${NC}"
    echo -e "${CYAN}正在下载 Sing-box...${NC}"
    
    # 下载文件（增加重试机制）
    retry_count=0
    while [[ $retry_count -lt $max_retries ]]; do
        if curl -L --max-time 300 -o "$temp_file" "$download_url"; then
            break
        fi
        
        retry_count=$((retry_count + 1))
        echo -e "${YELLOW}下载失败，重试 $retry_count/$max_retries...${NC}"
        sleep 3
    done
    
    if [[ $retry_count -eq $max_retries ]]; then
        echo -e "${RED}错误: 下载失败，请检查网络连接或URL有效性${NC}"
        return 1
    fi
    
    # 验证下载文件
    if [[ ! -f "$temp_file" ]] || [[ ! -s "$temp_file" ]]; then
        echo -e "${RED}错误: 下载的文件无效${NC}"
        return 1
    fi
    
    # 解压并安装
    echo -e "${CYAN}正在解压文件...${NC}"
    cd /tmp
    if ! tar -xzf "$temp_file"; then
        echo -e "${RED}错误: 解压失败${NC}"
        rm -f "$temp_file"
        return 1
    fi
    
    local extract_dir="sing-box-${latest_version}-linux-${ARCH}"
    echo -e "${CYAN}解压目录: $extract_dir${NC}"
    
    if [[ -f "$extract_dir/sing-box" ]]; then
        echo -e "${CYAN}正在安装二进制文件...${NC}"
        cp "$extract_dir/sing-box" "$SINGBOX_BINARY"
        chmod +x "$SINGBOX_BINARY"
        
        # 验证安装
        if "$SINGBOX_BINARY" version >/dev/null 2>&1; then
            local installed_version=$("$SINGBOX_BINARY" version 2>/dev/null | head -1 || echo "版本获取失败")
            echo -e "${GREEN}安装成功: $installed_version${NC}"
        else
            echo -e "${RED}错误: 安装的二进制文件无法运行${NC}"
            rm -f "$SINGBOX_BINARY"
            rm -rf "$temp_file" "$extract_dir"
            return 1
        fi
    else
        echo -e "${RED}错误: 解压后未找到 sing-box 二进制文件${NC}"
        echo -e "${YELLOW}解压目录内容:${NC}"
        ls -la "$extract_dir/" 2>/dev/null || echo "目录不存在"
        rm -rf "$temp_file" "$extract_dir"
        return 1
    fi
    
    # 清理临时文件
    rm -rf "$temp_file" "$extract_dir"
    
    echo -e "${GREEN}Sing-box 安装完成${NC}"
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

# 创建快捷命令（跨平台兼容）
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
        
        # 创建 PowerShell 脚本
        local ps_file="/c/Windows/System32/sb.ps1"
        cat > "$ps_file" << EOF
param([string[]]\$Arguments)
\$scriptPath = "$SCRIPT_DIR/singbox-install.sh"
if (Test-Path \$scriptPath) {
    & bash \$scriptPath @Arguments
} else {
    Write-Host "Error: singbox-install.sh not found" -ForegroundColor Red
}
EOF
        
        echo -e "${GREEN}Windows 快捷命令已创建${NC}"
        echo -e "${YELLOW}使用方法: 在 PowerShell 中输入 'sb' 或在 CMD 中输入 'sb.bat'${NC}"
    else
        # Linux/Unix 环境
        if [[ -d "/usr/local/bin" ]]; then
            # 确保使用绝对路径
            local script_path="$(realpath "$0")"
            
            # 检查是否有写入权限
            if [[ -w "/usr/local/bin" ]]; then
                if ln -sf "$script_path" /usr/local/bin/sb 2>/dev/null; then
                    chmod +x /usr/local/bin/sb
                    echo -e "${GREEN}Linux 快捷命令已创建: /usr/local/bin/sb${NC}"
                else
                    echo -e "${RED}快捷命令创建失败${NC}"
                fi
            else
                # 尝试使用sudo创建
                if command -v sudo >/dev/null 2>&1; then
                    echo -e "${YELLOW}需要管理员权限创建快捷命令...${NC}"
                    if sudo ln -sf "$script_path" /usr/local/bin/sb 2>/dev/null; then
                        sudo chmod +x /usr/local/bin/sb
                        echo -e "${GREEN}Linux 快捷命令已创建: /usr/local/bin/sb${NC}"
                    else
                        echo -e "${YELLOW}警告: 无法创建快捷命令${NC}"
                        echo -e "${YELLOW}手动创建命令: sudo ln -sf \"$script_path\" /usr/local/bin/sb${NC}"
                    fi
                else
                    echo -e "${YELLOW}警告: 无sudo权限，无法创建快捷命令${NC}"
                    echo -e "${YELLOW}手动创建命令: ln -sf \"$script_path\" /usr/local/bin/sb${NC}"
                fi
            fi
        else
            echo -e "${YELLOW}警告: /usr/local/bin 目录不存在，跳过快捷命令创建${NC}"
        fi
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

# 主函数 - 智能版
main() {
    # 基础系统检查
    check_root
    show_banner
    detect_system
    create_directories
    
    # 加载所有模块（包括错误处理、日志、验证等）
    load_modules
    
    # 记录启动信息
    if command -v log_info >/dev/null 2>&1; then
        log_info "Singbox安装脚本启动" "版本: v2.4.5, 系统: $OS_TYPE"
    fi
    
    # 初始化配置变量
    init_config_vars
    
    # 获取安装状态
    local install_info=$(check_installation_status)
    local status=$(echo "$install_info" | cut -d: -f1)
    
    if command -v log_debug >/dev/null 2>&1; then
        log_debug "安装状态检查结果: $install_info"
    fi
    
    # 根据安装状态选择处理方式
    case "$status" in
        "installed")
            echo -e "${GREEN}检测到 Sing-box 已安装${NC}"
            show_installation_menu "$install_info"
            ;;
        "not_installed")
            echo -e "${YELLOW}Sing-box 未安装，开始安装流程...${NC}"
            perform_installation
            ;;
        *)
            echo -e "${RED}安装状态检查异常: $install_info${NC}"
            diagnose_installation
            exit 1
            ;;
    esac
}

# 处理命令行参数
case "${1:-}" in
    --install)
        check_root
        detect_system
        create_directories
        install_dependencies
        install_singbox
        create_service
        echo -e "${GREEN}Sing-box 安装完成！${NC}"
        ;;
    --uninstall)
        check_root
        systemctl stop "$SERVICE_NAME" 2>/dev/null || true
        systemctl disable "$SERVICE_NAME" 2>/dev/null || true
        rm -f "/etc/systemd/system/$SERVICE_NAME.service"
        rm -f "$SINGBOX_BINARY"
        rm -rf "$WORK_DIR"
        rm -f /usr/local/bin/sb
        systemctl daemon-reload
        echo -e "${GREEN}Sing-box 卸载完成！${NC}"
        ;;
    --help|-h)
        echo -e "${CYAN}$SCRIPT_NAME $SCRIPT_VERSION${NC}"
        echo ""
        echo -e "${YELLOW}用法:${NC}"
        echo -e "  $0                # 启动交互式菜单"
        echo -e "  $0 --install      # 直接安装"
        echo -e "  $0 --uninstall    # 卸载"
        echo -e "  $0 --help         # 显示帮助"
        ;;
    *)
        main
        ;;
esac