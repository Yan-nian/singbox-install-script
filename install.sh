#!/bin/bash

# Sing-box 一键安装/更新/覆盖脚本
# 作者: 个人定制版本
# 版本: v1.0.0
# 支持: 新安装、更新、覆盖安装

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 全局变量
SCRIPT_NAME="sing-box"
SCRIPT_PATH="/usr/local/bin/sing-box"
CONFIG_DIR="/etc/sing-box"
DATA_DIR="/usr/local/etc/sing-box"
LOG_DIR="/var/log/sing-box"
DB_FILE="$DATA_DIR/sing-box.db"
CONFIG_FILE="$CONFIG_DIR/config.json"
SERVICE_FILE="/etc/systemd/system/sing-box.service"
SINGBOX_VERSION="latest"

# 安装模式
INSTALL_MODE=""
FORCE_REINSTALL=false

# 输出函数
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# 显示使用帮助
show_help() {
    echo "Sing-box 一键安装/更新/覆盖脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help       显示帮助信息"
    echo "  -f, --force      强制重新安装"
    echo "  -u, --update     更新模式（仅更新脚本）"
    echo "  -c, --core       仅更新核心程序"
    echo "  -s, --script     仅更新管理脚本"
    echo ""
    echo "示例:"
    echo "  $0               # 自动检测并安装/更新"
    echo "  $0 -f            # 强制重新安装"
    echo "  $0 -u            # 更新模式"
    echo "  $0 -c            # 仅更新核心"
    echo "  $0 -s            # 仅更新脚本"
    echo ""
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--force)
                FORCE_REINSTALL=true
                shift
                ;;
            -u|--update)
                INSTALL_MODE="update"
                shift
                ;;
            -c|--core)
                INSTALL_MODE="core"
                shift
                ;;
            -s|--script)
                INSTALL_MODE="script"
                shift
                ;;
            *)
                error "未知选项: $1"
                ;;
        esac
    done
}

# 检查系统
check_system() {
    info "检查系统环境..."
    
    # 检查是否为 root 用户
    if [[ $EUID -ne 0 ]]; then
        error "请使用 root 用户运行此脚本"
    fi
    
    # 检查系统类型
    if [[ -f /etc/redhat-release ]]; then
        OS="centos"
        PM="yum"
    elif cat /etc/issue | grep -Eqi "debian"; then
        OS="debian"
        PM="apt-get"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        OS="ubuntu"
        PM="apt-get"
    else
        error "不支持的操作系统"
    fi
    
    # 检查架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64)
            ARCH="arm64"
            ;;
        armv7l)
            ARCH="armv7"
            ;;
        *)
            error "不支持的架构: $ARCH"
            ;;
    esac
    
    success "系统检查完成: $OS ($ARCH)"
}

# 检查安装状态
check_installation() {
    info "检查安装状态..."
    
    # 检查 sing-box 核心
    local core_installed=false
    local script_installed=false
    local service_installed=false
    
    if [[ -f "/usr/local/bin/sing-box" ]] && [[ -x "/usr/local/bin/sing-box" ]]; then
        if /usr/local/bin/sing-box version >/dev/null 2>&1; then
            core_installed=true
            local current_version=$(/usr/local/bin/sing-box version 2>/dev/null | head -1 | awk '{print $3}' || echo "unknown")
            info "检测到 sing-box 核心: $current_version"
        fi
    fi
    
    # 检查管理脚本
    if [[ -f "$SCRIPT_PATH" ]] && [[ -x "$SCRIPT_PATH" ]]; then
        if grep -q "interactive_main\|main_menu" "$SCRIPT_PATH" 2>/dev/null; then
            script_installed=true
            info "检测到管理脚本: 交互式版本"
        else
            info "检测到管理脚本: 旧版本"
        fi
    fi
    
    # 检查服务
    if [[ -f "$SERVICE_FILE" ]]; then
        service_installed=true
        local service_status=$(systemctl is-active sing-box 2>/dev/null || echo "inactive")
        info "检测到 systemd 服务: $service_status"
    fi
    
    # 检查配置文件
    if [[ -f "$CONFIG_FILE" ]]; then
        info "检测到配置文件"
        
        # 检查是否有配置数据库
        if [[ -f "$DB_FILE" ]]; then
            local config_count=$(wc -l < "$DB_FILE" 2>/dev/null || echo "0")
            info "配置数据库: $config_count 个配置"
        fi
    fi
    
    # 根据检查结果决定安装模式
    if [[ $FORCE_REINSTALL == true ]]; then
        INSTALL_MODE="reinstall"
        info "强制重新安装模式"
    elif [[ $core_installed == true ]] && [[ $script_installed == true ]] && [[ $service_installed == true ]]; then
        if [[ -z $INSTALL_MODE ]]; then
            INSTALL_MODE="update"
            info "检测到完整安装，将进行更新"
        fi
    elif [[ $core_installed == true ]] || [[ $script_installed == true ]]; then
        if [[ -z $INSTALL_MODE ]]; then
            INSTALL_MODE="upgrade"
            info "检测到部分安装，将进行升级"
        fi
    else
        if [[ -z $INSTALL_MODE ]]; then
            INSTALL_MODE="install"
            info "未检测到安装，将进行新安装"
        fi
    fi
    
    success "安装状态检查完成: $INSTALL_MODE"
}

# 安装依赖
install_dependencies() {
    info "安装依赖包..."
    
    if [[ $PM == "yum" ]]; then
        yum update -y
        yum install -y curl wget unzip systemd openssl qrencode bc
    else
        apt-get update -y
        apt-get install -y curl wget unzip systemd openssl qrencode bc
    fi
    
    success "依赖包安装完成"
}

# 备份现有安装
backup_existing() {
    if [[ $INSTALL_MODE == "install" ]]; then
        return 0
    fi
    
    info "备份现有安装..."
    
    local backup_dir="/tmp/sing-box-backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # 备份核心程序
    if [[ -f "/usr/local/bin/sing-box" ]]; then
        cp "/usr/local/bin/sing-box" "$backup_dir/sing-box-core"
        info "备份核心程序"
    fi
    
    # 备份管理脚本
    if [[ -f "$SCRIPT_PATH" ]]; then
        cp "$SCRIPT_PATH" "$backup_dir/sing-box-script"
        info "备份管理脚本"
    fi
    
    # 备份配置文件（仅复制，不移动）
    if [[ -f "$CONFIG_FILE" ]]; then
        cp "$CONFIG_FILE" "$backup_dir/config.json"
        info "备份配置文件"
    fi
    
    # 备份数据库
    if [[ -f "$DB_FILE" ]]; then
        cp "$DB_FILE" "$backup_dir/sing-box.db"
        info "备份配置数据库"
    fi
    
    # 备份服务文件
    if [[ -f "$SERVICE_FILE" ]]; then
        cp "$SERVICE_FILE" "$backup_dir/sing-box.service"
        info "备份服务文件"
    fi
    
    success "备份完成: $backup_dir"
}

# 下载 sing-box 核心
download_singbox() {
    if [[ $INSTALL_MODE == "script" ]]; then
        info "跳过核心程序下载（仅更新脚本）"
        return 0
    fi
    
    info "下载 sing-box 核心程序..."
    
    # 获取最新版本
    if [[ $SINGBOX_VERSION == "latest" ]]; then
        info "正在获取最新版本信息..."
        SINGBOX_VERSION=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | head -1)
        
        # 如果获取失败，尝试备用方法
        if [[ -z $SINGBOX_VERSION ]]; then
            warn "API 获取失败，尝试备用方法..."
            SINGBOX_VERSION=$(curl -s "https://github.com/SagerNet/sing-box/releases/latest" | grep -oP 'tag/\K[^"]+' | head -1)
        fi
        
        # 如果仍然失败，使用预设版本
        if [[ -z $SINGBOX_VERSION ]]; then
            warn "无法获取最新版本，使用预设版本 v1.11.15"
            SINGBOX_VERSION="v1.11.15"
        fi
    fi
    
    if [[ -z $SINGBOX_VERSION ]]; then
        error "无法获取 sing-box 版本信息"
    fi
    
    info "下载版本: $SINGBOX_VERSION"
    
    # 检查是否需要更新
    if [[ -f "/usr/local/bin/sing-box" ]] && [[ $INSTALL_MODE == "update" ]]; then
        local current_version=$(/usr/local/bin/sing-box version 2>/dev/null | head -1 | awk '{print $3}' || echo "unknown")
        if [[ "$current_version" == "${SINGBOX_VERSION#v}" ]]; then
            info "核心程序已是最新版本: $current_version"
            return 0
        fi
    fi
    
    # 下载地址
    DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/${SINGBOX_VERSION}/sing-box-${SINGBOX_VERSION#v}-linux-${ARCH}.tar.gz"
    
    # 下载文件
    cd /tmp
    wget -O sing-box.tar.gz "$DOWNLOAD_URL" || error "下载失败"
    
    # 解压安装
    tar -xzf sing-box.tar.gz
    EXTRACT_DIR=$(find . -name "sing-box-*-linux-${ARCH}" -type d | head -1)
    
    if [[ -z $EXTRACT_DIR ]]; then
        error "解压失败"
    fi
    
    # 停止服务（如果正在运行）
    if systemctl is-active --quiet sing-box 2>/dev/null; then
        info "停止 sing-box 服务..."
        systemctl stop sing-box
    fi
    
    cp "$EXTRACT_DIR/sing-box" /usr/local/bin/
    chmod +x /usr/local/bin/sing-box
    
    # 清理临时文件
    rm -rf sing-box.tar.gz "$EXTRACT_DIR"
    
    success "sing-box 核心安装完成"
}

# 创建目录结构
create_directories() {
    if [[ $INSTALL_MODE == "core" ]]; then
        info "跳过目录创建（仅更新核心）"
        return 0
    fi
    
    info "创建目录结构..."
    
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$CONFIG_DIR/configs"
    mkdir -p "$DATA_DIR"
    mkdir -p "$LOG_DIR"
    
    # 设置正确的权限
    chmod 755 "$CONFIG_DIR"
    chmod 755 "$CONFIG_DIR/configs"
    chmod 755 "$DATA_DIR"
    chmod 755 "$LOG_DIR"
    
    success "目录创建完成"
}

# 下载主脚本
download_script() {
    if [[ $INSTALL_MODE == "core" ]]; then
        info "跳过管理脚本下载（仅更新核心）"
        return 0
    fi
    
    info "安装管理脚本..."
    
    # 检查是否已存在脚本
    if [[ -f "$SCRIPT_PATH" ]]; then
        info "检测到已安装的脚本，准备覆盖安装..."
        # 备份现有脚本
        local backup_path="$SCRIPT_PATH.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$SCRIPT_PATH" "$backup_path"
        success "已备份现有脚本到: $backup_path"
    fi
    
    # 检查当前目录是否有 sing-box.sh 文件
    if [[ -f "./sing-box.sh" ]]; then
        info "使用本地 sing-box.sh 文件进行安装..."
        cp "./sing-box.sh" "$SCRIPT_PATH"
    else
        info "从 GitHub 下载最新脚本..."
        # 下载完整的管理脚本
        wget -O "$SCRIPT_PATH" "https://raw.githubusercontent.com/Yan-nian/singbox-install-script/master/sing-box.sh" || {
            error "下载管理脚本失败，请检查网络连接"
        }
    fi
    
    # 设置执行权限
    chmod +x "$SCRIPT_PATH"
    
    # 创建软链接
    ln -sf "$SCRIPT_PATH" /usr/local/bin/sb
    
    success "管理脚本安装完成"
}

# 创建 systemd 服务
create_service() {
    if [[ $INSTALL_MODE == "core" ]] || [[ $INSTALL_MODE == "script" ]]; then
        info "跳过服务创建"
        return 0
    fi
    
    info "创建 systemd 服务..."
    
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/sing-box run -c $CONFIG_FILE
Restart=on-failure
RestartSec=3s
ExecReload=/bin/kill -HUP \$MAINPID

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable sing-box
    
    success "systemd 服务创建完成"
}

# 创建初始配置
create_initial_config() {
    if [[ $INSTALL_MODE == "core" ]] || [[ $INSTALL_MODE == "script" ]]; then
        info "跳过配置文件创建"
        return 0
    fi
    
    # 如果配置文件已存在，不覆盖
    if [[ -f "$CONFIG_FILE" ]] && [[ $INSTALL_MODE != "reinstall" ]]; then
        info "配置文件已存在，跳过创建"
        
        # 确保数据库文件存在
        if [[ ! -f "$DB_FILE" ]]; then
            info "创建配置数据库..."
            touch "$DB_FILE"
        fi
        
        return 0
    fi
    
    info "创建初始配置..."
    
    cat > "$CONFIG_FILE" << EOF
{
  "log": {
    "level": "info",
    "timestamp": true,
    "output": "$LOG_DIR/sing-box.log"
  },
  "inbounds": [],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "rules": [],
    "final": "direct"
  }
}
EOF

    # 设置配置文件权限
    chmod 644 "$CONFIG_FILE"
    
    # 创建数据库文件
    touch "$DB_FILE"
    chmod 644 "$DB_FILE"
    
    # 创建日志文件并设置权限
    touch "$LOG_DIR/sing-box.log"
    chmod 644 "$LOG_DIR/sing-box.log"
    
    success "初始配置创建完成"
}

# 启动服务
start_service() {
    if [[ $INSTALL_MODE == "script" ]]; then
        info "跳过服务启动"
        return 0
    fi
    
    # 启动或重启服务（添加超时机制）
    if systemctl is-active --quiet sing-box 2>/dev/null; then
        info "重启 sing-box 服务..."
        if timeout 30 systemctl restart sing-box; then
            info "服务重启命令执行完成"
        else
            warn "服务重启超时或失败"
        fi
    else
        info "启动 sing-box 服务..."
        if timeout 30 systemctl start sing-box; then
            info "服务启动命令执行完成"
        else
            warn "服务启动超时或失败"
        fi
    fi
    
    # 检查服务状态
    sleep 3  # 等待服务启动
    local service_status=$(systemctl is-active sing-box 2>/dev/null)
    
    if [[ "$service_status" == "active" ]]; then
        success "服务启动成功"
        
        # 显示服务状态
        info "服务运行状态:"
        systemctl status sing-box --no-pager -l | head -10
    else
        warn "服务启动失败，当前状态: $service_status"
        
        # 显示错误日志
        warn "最近的错误日志:"
        journalctl -u sing-box --no-pager -l --since "5 minutes ago" | tail -10
        
        # 提供故障排除建议
        info "故障排除建议:"
        echo "  1. 检查配置文件: $CONFIG_FILE"
        echo "  2. 查看详细日志: journalctl -u sing-box -f"
        echo "  3. 手动启动测试: /usr/local/bin/sing-box run -c $CONFIG_FILE"
        echo "  4. 检查端口占用: netstat -tuln | grep :端口号"
    fi
}

# 显示安装完成信息
show_completion() {
    echo ""
    case $INSTALL_MODE in
        "install")
            success "=== Sing-box 新安装完成 ==="
            ;;
        "update")
            success "=== Sing-box 更新完成 ==="
            ;;
        "upgrade")
            success "=== Sing-box 升级完成 ==="
            ;;
        "reinstall")
            success "=== Sing-box 重新安装完成 ==="
            ;;
        "core")
            success "=== Sing-box 核心更新完成 ==="
            ;;
        "script")
            success "=== Sing-box 脚本更新完成 ==="
            ;;
        *)
            success "=== Sing-box 安装完成 ==="
            ;;
    esac
    echo ""
    
    # 显示版本信息
    if [[ -f "/usr/local/bin/sing-box" ]]; then
        local core_version=$(/usr/local/bin/sing-box version 2>/dev/null | head -1 | awk '{print $3}' || echo "unknown")
        info "🔧 核心版本: $core_version"
    fi
    
    if [[ -f "$SCRIPT_PATH" ]]; then
        if grep -q "interactive_main\|main_menu" "$SCRIPT_PATH" 2>/dev/null; then
            info "📱 管理脚本: 交互式版本"
        else
            info "📱 管理脚本: 标准版本"
        fi
    fi
    
    if [[ -f "$CONFIG_FILE" ]]; then
        info "⚙️  配置文件: 已就绪"
    fi
    
    if [[ -f "$DB_FILE" ]]; then
        local config_count=$(wc -l < "$DB_FILE" 2>/dev/null || echo "0")
        info "📊 配置数据库: $config_count 个配置"
    fi
    
    echo ""
    info "🎨 交互式界面:"
    echo "  sing-box             - 启动交互式菜单（推荐）"
    echo "  sb                   - 快捷命令"
    echo ""
    info "🔧 快速开始:"
    echo "  sing-box add vless   - 添加 VLESS Reality 配置"
    echo "  sing-box add vmess   - 添加 VMess 配置"
    echo "  sing-box add hy2     - 添加 Hysteria2 配置"
    echo "  sing-box add ss      - 添加 Shadowsocks 配置"
    echo ""
    info "📊 管理命令:"
    echo "  sing-box list        - 查看所有配置"
    echo "  sing-box info <name> - 查看配置详情"
    echo "  sing-box url <name>  - 获取分享链接"
    echo "  sing-box qr <name>   - 生成二维码"
    echo ""
    info "🛠️ 服务管理:"
    echo "  sing-box start       - 启动服务"
    echo "  sing-box stop        - 停止服务"
    echo "  sing-box restart     - 重启服务"
    echo "  sing-box status      - 查看状态"
    echo "  sing-box log         - 查看日志"
    echo ""
    info "🔄 更新管理:"
    echo "  $0 -u                - 更新检查"
    echo "  $0 -c                - 仅更新核心"
    echo "  $0 -s                - 仅更新脚本"
    echo "  $0 -f                - 强制重新安装"
    echo ""
    success "✅ 安装成功！运行 'sing-box' 开始使用交互式界面"
    echo ""
}

# 主安装流程
main() {
    echo "=== Sing-box 一键安装/更新/覆盖脚本 ==="
    echo ""
    
    # 解析参数
    parse_args "$@"
    
    # 执行安装流程
    check_system
    check_installation
    
    # 根据模式执行不同的安装步骤
    case $INSTALL_MODE in
        "install")
            info "执行新安装流程..."
            install_dependencies
            download_singbox
            create_directories
            download_script
            create_service
            create_initial_config
            start_service
            ;;
        "update")
            info "执行更新流程..."
            backup_existing
            install_dependencies
            download_singbox
            download_script
            create_service
            create_initial_config
            start_service
            ;;
        "upgrade")
            info "执行升级流程..."
            backup_existing
            install_dependencies
            download_singbox
            create_directories
            download_script
            create_service
            create_initial_config
            start_service
            ;;
        "reinstall")
            info "执行重新安装流程..."
            backup_existing
            install_dependencies
            download_singbox
            create_directories
            download_script
            create_service
            create_initial_config
            start_service
            ;;
        "core")
            info "执行核心更新流程..."
            backup_existing
            download_singbox
            start_service
            ;;
        "script")
            info "执行脚本更新流程..."
            backup_existing
            download_script
            ;;
        *)
            error "未知的安装模式: $INSTALL_MODE"
            ;;
    esac
    
    show_completion
}

# 执行安装
main "$@"