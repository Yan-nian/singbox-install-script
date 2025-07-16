#!/bin/bash

# Sing-box 一键安装脚本
# 作者: 个人定制版本
# 版本: v1.0.0

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
CONFIG_FILE="$CONFIG_DIR/config.json"
SERVICE_FILE="/etc/systemd/system/sing-box.service"
SINGBOX_VERSION="latest"

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

# 安装依赖
install_dependencies() {
    info "安装依赖包..."
    
    if [[ $PM == "yum" ]]; then
        yum update -y
        yum install -y curl wget unzip systemd
    else
        apt-get update -y
        apt-get install -y curl wget unzip systemd
    fi
    
    success "依赖包安装完成"
}

# 下载 sing-box 核心
download_singbox() {
    info "下载 sing-box 核心程序..."
    
    # 获取最新版本
    if [[ $SINGBOX_VERSION == "latest" ]]; then
        SINGBOX_VERSION=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    fi
    
    if [[ -z $SINGBOX_VERSION ]]; then
        error "无法获取 sing-box 版本信息"
    fi
    
    info "下载版本: $SINGBOX_VERSION"
    
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
    
    cp "$EXTRACT_DIR/sing-box" /usr/local/bin/
    chmod +x /usr/local/bin/sing-box
    
    # 清理临时文件
    rm -rf sing-box.tar.gz "$EXTRACT_DIR"
    
    success "sing-box 核心安装完成"
}

# 创建目录结构
create_directories() {
    info "创建目录结构..."
    
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$CONFIG_DIR/configs"
    mkdir -p "$DATA_DIR"
    mkdir -p "$LOG_DIR"
    
    success "目录创建完成"
}

# 下载主脚本
download_script() {
    info "下载管理脚本..."
    
    # 这里应该从你的仓库下载，暂时创建本地版本
    cat > "$SCRIPT_PATH" << 'EOF'
#!/bin/bash

# Sing-box 管理脚本
# 版本: v1.0.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置路径
CONFIG_DIR="/etc/sing-box"
DATA_DIR="/usr/local/etc/sing-box"
LOG_DIR="/var/log/sing-box"
CONFIG_FILE="$CONFIG_DIR/config.json"
DB_FILE="$DATA_DIR/sing-box.db"

# 输出函数
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# 显示帮助信息
show_help() {
    echo "Sing-box 管理脚本 v1.0.0"
    echo "使用方法: sing-box [命令] [参数]"
    echo ""
    echo "基础命令:"
    echo "  add <protocol>     添加配置 (vless/vmess/hy2)"
    echo "  list               列出所有配置"
    echo "  info <name>        查看配置详情"
    echo "  del <name>         删除配置"
    echo "  url <name>         获取分享链接"
    echo "  qr <name>          生成二维码"
    echo "  port <name> <port> 更换端口"
    echo ""
    echo "系统管理:"
    echo "  start              启动服务"
    echo "  stop               停止服务"
    echo "  restart            重启服务"
    echo "  status             查看状态"
    echo "  log                查看日志"
    echo "  uninstall          卸载脚本"
    echo ""
    echo "其他:"
    echo "  version            显示版本"
    echo "  help               显示帮助"
}

# 主函数
main() {
    case "$1" in
        "add")
            case "$2" in
                "vless")
                    info "添加 VLESS Reality 配置功能开发中..."
                    ;;
                "vmess")
                    info "添加 VMess 配置功能开发中..."
                    ;;
                "hy2")
                    info "添加 Hysteria2 配置功能开发中..."
                    ;;
                *)
                    error "不支持的协议: $2"
                    ;;
            esac
            ;;
        "list")
            info "列出配置功能开发中..."
            ;;
        "start")
            systemctl start sing-box
            success "服务已启动"
            ;;
        "stop")
            systemctl stop sing-box
            success "服务已停止"
            ;;
        "restart")
            systemctl restart sing-box
            success "服务已重启"
            ;;
        "status")
            systemctl status sing-box
            ;;
        "log")
            journalctl -u sing-box -f
            ;;
        "version")
            echo "Sing-box 管理脚本 v1.0.0"
            /usr/local/bin/sing-box version
            ;;
        "help"|"")
            show_help
            ;;
        "uninstall")
            info "卸载功能开发中..."
            ;;
        *)
            error "未知命令: $1，使用 'sing-box help' 查看帮助"
            ;;
    esac
}

main "$@"
EOF

    chmod +x "$SCRIPT_PATH"
    
    # 创建软链接
    ln -sf "$SCRIPT_PATH" /usr/local/bin/sb
    
    success "管理脚本安装完成"
}

# 创建 systemd 服务
create_service() {
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
RestartSec=1800s
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
  ]
}
EOF

    # 创建数据库文件
    touch "$DB_FILE"
    
    success "初始配置创建完成"
}

# 显示安装完成信息
show_completion() {
    echo ""
    success "=== Sing-box 安装完成 ==="
    echo ""
    info "管理命令:"
    echo "  sing-box help    - 查看帮助"
    echo "  sb help          - 快捷命令"
    echo ""
    info "快速开始:"
    echo "  sing-box add vless    - 添加 VLESS Reality 配置"
    echo "  sing-box add vmess    - 添加 VMess 配置"
    echo "  sing-box add hy2      - 添加 Hysteria2 配置"
    echo ""
    info "服务管理:"
    echo "  sing-box start        - 启动服务"
    echo "  sing-box status       - 查看状态"
    echo "  sing-box log          - 查看日志"
    echo ""
    warn "注意: 当前为基础框架，协议配置功能正在开发中"
    echo ""
}

# 主安装流程
main() {
    echo "=== Sing-box 一键安装脚本 ==="
    echo ""
    
    check_system
    install_dependencies
    download_singbox
    create_directories
    download_script
    create_service
    create_initial_config
    
    show_completion
}

# 执行安装
main "$@"