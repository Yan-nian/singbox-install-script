#!/bin/bash

# Sing-box 精简一键安装脚本
# 支持 VLESS Reality、VMess WebSocket、Hysteria2 协议
# 版本: v2.2.0
# 更新时间: 2024-12-19

set -e

# 脚本信息
SCRIPT_NAME="Sing-box 精简安装脚本"
SCRIPT_VERSION="v2.4.2"
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

# 加载模块
load_modules() {
    local lib_dir="$(dirname "$0")/lib"
    local base_url="https://raw.githubusercontent.com/Yan-nian/singbox-install-script/master/lib"
    local temp_dir="/tmp/singbox-modules"
    
    # 检查是否为在线执行（curl管道）
    if [[ "$0" == "bash" ]] || [[ "$0" == "-bash" ]] || [[ "$(dirname "$0")" == "/dev/fd" ]] || [[ ! -d "$lib_dir" ]]; then
        echo -e "${CYAN}检测到在线执行，正在下载模块...${NC}"
        
        # 创建临时目录
        mkdir -p "$temp_dir"
        
        # 下载模块文件
        local modules=("common.sh" "protocols.sh" "menu.sh" "subscription.sh" "config_manager.sh")
        for module in "${modules[@]}"; do
            if curl -fsSL "$base_url/$module" -o "$temp_dir/$module"; then
                echo -e "${GREEN}已下载: $module${NC}"
            else
                echo -e "${RED}错误: 无法下载模块 $module${NC}"
                exit 1
            fi
        done
        
        lib_dir="$temp_dir"
    fi
    
    # 加载通用函数库
    if [[ -f "$lib_dir/common.sh" ]]; then
        source "$lib_dir/common.sh"
        echo -e "${GREEN}已加载通用函数库${NC}"
    else
        echo -e "${RED}错误: 通用函数库不存在${NC}"
        exit 1
    fi
    
    # 加载协议模块
    if [[ -f "$lib_dir/protocols.sh" ]]; then
        source "$lib_dir/protocols.sh"
        echo -e "${GREEN}已加载协议模块${NC}"
    else
        echo -e "${RED}错误: 协议模块不存在${NC}"
        exit 1
    fi
    
    # 加载菜单模块
    if [[ -f "$lib_dir/menu.sh" ]]; then
        source "$lib_dir/menu.sh"
        echo -e "${GREEN}已加载菜单模块${NC}"
    else
        echo -e "${RED}错误: 菜单模块不存在${NC}"
        exit 1
    fi
    
    # 加载订阅模块
    if [[ -f "$lib_dir/subscription.sh" ]]; then
        source "$lib_dir/subscription.sh"
        echo -e "${GREEN}已加载订阅模块${NC}"
    else
        echo -e "${RED}错误: 订阅模块不存在${NC}"
        exit 1
    fi
    
    # 加载配置管理模块
    if [[ -f "$lib_dir/config_manager.sh" ]]; then
        source "$lib_dir/config_manager.sh"
        echo -e "${GREEN}已加载配置管理模块${NC}"
    else
        echo -e "${RED}错误: 配置管理模块不存在${NC}"
        exit 1
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
    
    # 获取最新版本
    local latest_version
    latest_version=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep '"tag_name"' | cut -d'"' -f4 | sed 's/v//')
    
    if [[ -z "$latest_version" ]]; then
        echo -e "${RED}错误: 无法获取最新版本信息${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}最新版本: v$latest_version${NC}"
    
    # 下载文件
    local download_url="https://github.com/SagerNet/sing-box/releases/download/v${latest_version}/sing-box-${latest_version}-linux-${ARCH}.tar.gz"
    local temp_file="/tmp/sing-box.tar.gz"
    
    echo -e "${CYAN}正在下载 Sing-box...${NC}"
    if ! curl -L -o "$temp_file" "$download_url"; then
        echo -e "${RED}错误: 下载失败${NC}"
        exit 1
    fi
    
    # 解压并安装
    cd /tmp
    tar -xzf "$temp_file"
    
    local extract_dir="sing-box-${latest_version}-linux-${ARCH}"
    if [[ -f "$extract_dir/sing-box" ]]; then
        cp "$extract_dir/sing-box" "$SINGBOX_BINARY"
        chmod +x "$SINGBOX_BINARY"
    else
        echo -e "${RED}错误: 解压失败${NC}"
        exit 1
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

# 主函数
main() {
    # 检查权限
    check_root
    
    # 显示横幅
    show_banner
    
    # 检测系统
    detect_system
    
    # 创建目录
    create_directories
    
    # 加载模块
    load_modules
    
    # 检查是否已安装
    if [[ -f "$SINGBOX_BINARY" ]]; then
        echo -e "${GREEN}检测到 Sing-box 已安装${NC}"
        # 从现有配置文件提取信息
        if [[ -f "$CONFIG_FILE" ]]; then
            echo -e "${CYAN}正在加载现有配置...${NC}"
        fi
        show_main_menu
    else
        echo -e "${YELLOW}Sing-box 未安装，开始安装...${NC}"
        install_dependencies
        install_singbox
        create_service
        ln -sf "$SCRIPT_DIR/singbox-install.sh" /usr/local/bin/sb
        echo -e "${GREEN}安装完成！快捷命令 'sb' 已创建。${NC}"
        show_main_menu
    fi
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