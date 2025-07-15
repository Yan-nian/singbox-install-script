#!/bin/bash

# Sing-box 快速安装脚本
# 一键下载并运行完整安装脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 脚本信息
SCRIPT_NAME="Sing-box 快速安装"
SCRIPT_VERSION="v1.0.0"
REPO_URL="https://github.com/your-repo/singbox-install"
RAW_URL="https://raw.githubusercontent.com/your-repo/singbox-install/main"
TEMP_DIR="/tmp/singbox-install"

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        echo -e "${YELLOW}请使用 sudo 运行此脚本${NC}"
        exit 1
    fi
}

# 检查网络连接
check_network() {
    log_info "检查网络连接..."
    
    if ! ping -c 1 github.com >/dev/null 2>&1; then
        log_error "无法连接到 GitHub，请检查网络连接"
        exit 1
    fi
    
    log_info "网络连接正常"
}

# 检查系统依赖
check_dependencies() {
    log_info "检查系统依赖..."
    
    local deps=("curl" "wget" "tar" "unzip")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_warn "缺少依赖: ${missing_deps[*]}"
        log_info "正在安装依赖..."
        
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update
            apt-get install -y "${missing_deps[@]}"
        elif command -v yum >/dev/null 2>&1; then
            yum install -y "${missing_deps[@]}"
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y "${missing_deps[@]}"
        else
            log_error "不支持的包管理器，请手动安装: ${missing_deps[*]}"
            exit 1
        fi
    fi
    
    log_info "依赖检查完成"
}

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
    echo -e "  ${YELLOW}•${NC} VMess WebSocket + TLS"
    echo -e "  ${YELLOW}•${NC} Hysteria2"
    echo -e "${CYAN}================================================================${NC}"
    echo ""
}

# 下载安装脚本
download_script() {
    log_info "下载安装脚本..."
    
    # 创建临时目录
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # 下载方式1: 使用 git clone
    if command -v git >/dev/null 2>&1; then
        log_info "使用 git 下载..."
        if git clone "$REPO_URL" singbox-install; then
            cd singbox-install
            return 0
        else
            log_warn "git 下载失败，尝试其他方式..."
        fi
    fi
    
    # 下载方式2: 下载 ZIP 文件
    log_info "下载 ZIP 文件..."
    if curl -L "$REPO_URL/archive/main.zip" -o singbox-install.zip; then
        unzip -q singbox-install.zip
        cd singbox-install-main
        return 0
    elif wget "$REPO_URL/archive/main.zip" -O singbox-install.zip; then
        unzip -q singbox-install.zip
        cd singbox-install-main
        return 0
    else
        log_error "下载失败，请检查网络连接"
        exit 1
    fi
}

# 运行安装脚本
run_install() {
    log_info "运行安装脚本..."
    
    # 检查安装脚本是否存在
    if [[ ! -f "install.sh" ]]; then
        log_error "找不到 install.sh 文件"
        exit 1
    fi
    
    # 添加执行权限
    chmod +x install.sh
    
    # 运行安装脚本
    ./install.sh "$@"
}

# 清理临时文件
cleanup() {
    log_info "清理临时文件..."
    rm -rf "$TEMP_DIR"
}

# 显示帮助信息
show_help() {
    echo -e "${CYAN}$SCRIPT_NAME $SCRIPT_VERSION${NC}"
    echo ""
    echo -e "${YELLOW}用法:${NC}"
    echo -e "  $0 [选项]"
    echo ""
    echo -e "${YELLOW}选项:${NC}"
    echo -e "  ${GREEN}-h, --help${NC}        显示此帮助信息"
    echo -e "  ${GREEN}-v, --version${NC}     显示版本信息"
    echo -e "  ${GREEN}--vless${NC}           直接配置 VLESS Reality Vision"
    echo -e "  ${GREEN}--vmess${NC}           直接配置 VMess WebSocket"
    echo -e "  ${GREEN}--hysteria2${NC}       直接配置 Hysteria2"
    echo -e "  ${GREEN}--multi${NC}           配置多协议"
    echo ""
    echo -e "${YELLOW}示例:${NC}"
    echo -e "  $0                    # 启动交互式安装"
    echo -e "  $0 --vless            # 直接安装 VLESS Reality Vision"
    echo -e "  $0 --multi            # 安装多协议配置"
    echo ""
    echo -e "${YELLOW}一键安装命令:${NC}"
    echo -e "  ${GREEN}curl -fsSL $RAW_URL/quick-install.sh | sudo bash${NC}"
    echo -e "  ${GREEN}wget -qO- $RAW_URL/quick-install.sh | sudo bash${NC}"
    echo ""
}

# 显示版本信息
show_version() {
    echo -e "${CYAN}$SCRIPT_NAME${NC}"
    echo -e "${GREEN}版本: $SCRIPT_VERSION${NC}"
    echo -e "${GREEN}项目: $REPO_URL${NC}"
}

# 主函数
main() {
    # 处理帮助和版本参数
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            show_version
            exit 0
            ;;
    esac
    
    # 显示横幅
    show_banner
    
    # 检查 root 权限
    check_root
    
    # 检查网络连接
    check_network
    
    # 检查系统依赖
    check_dependencies
    
    # 设置清理陷阱
    trap cleanup EXIT
    
    # 下载安装脚本
    download_script
    
    # 运行安装脚本
    run_install "$@"
}

# 运行主函数
main "$@"