#!/bin/bash

# Sing-box 独立安装脚本 v2.4.15
# 单文件版本 - 无需下载整个项目
# 支持 VLESS Reality、VMess WebSocket、Hysteria2 协议
# 作者: Sing-box 安装脚本项目组
# 版本: v2.4.15
# 更新时间: $(date +%Y-%m-%d)

set -euo pipefail

# 脚本信息
SCRIPT_VERSION="v2.4.15"
SCRIPT_NAME="Sing-box 独立安装脚本"
SCRIPT_DESCRIPTION="支持多协议的 Sing-box 一键安装和管理脚本（单文件版本）"
SCRIPT_AUTHOR="Sing-box 安装脚本项目组"
SCRIPT_URL="https://github.com/Yan-nian/singbox-install-script"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# QR码生成配置
QR_SIZE="small"  # 默认使用小尺寸QR码

# 全局变量
INSTALL_MODE="interactive"  # interactive, auto, silent
SELECTED_PROTOCOL=""        # vless, vmess, hysteria2
CONFIG_NAME=""              # 配置文件名称
SERVICE_ACTION=""           # install, uninstall, restart, status
FORCE_REINSTALL="false"     # 是否强制重新安装
SKIP_CHECKS="false"         # 是否跳过环境检查
DEBUG_MODE="false"          # 调试模式

# 安装配置
SINGBOX_VERSION="latest"    # Sing-box 版本
INSTALL_PATH="/usr/local/bin/sing-box"  # 安装路径
CONFIG_PATH="/etc/sing-box"             # 配置目录
SERVICE_NAME="sing-box"                 # 服务名称
LOG_PATH="/var/log/sing-box"            # 日志目录

# ==================== 日志系统 ====================

# 日志函数
log_info() {
    echo -e "${CYAN}[信息]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

log_error() {
    echo -e "${RED}[错误]${NC} $1" >&2
}

log_debug() {
    if [[ "$DEBUG_MODE" == "true" ]]; then
        echo -e "${PURPLE}[调试]${NC} $1"
    fi
}

# ==================== 错误处理 ====================

# 错误处理函数
handle_error() {
    local exit_code=$?
    local line_number=$1
    log_error "脚本在第 $line_number 行发生错误，退出码: $exit_code"
    cleanup_on_error
    exit $exit_code
}

# 错误清理函数
cleanup_on_error() {
    log_warn "正在清理临时文件..."
    # 清理可能的临时文件
    rm -f /tmp/sing-box* 2>/dev/null || true
    rm -f /tmp/config-*.json 2>/dev/null || true
}

# 设置错误处理
trap 'handle_error $LINENO' ERR

# ==================== 系统检查 ====================

# 检查系统架构
check_architecture() {
    local arch
    arch=$(uname -m)
    case $arch in
        x86_64|amd64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7l)
            echo "armv7"
            ;;
        *)
            log_error "不支持的系统架构: $arch"
            exit 1
            ;;
    esac
}

# 检查操作系统
check_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "$ID"
    elif [[ -f /etc/redhat-release ]]; then
        echo "centos"
    else
        echo "unknown"
    fi
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        log_info "请使用: sudo $0"
        exit 1
    fi
}

# 检查网络连接
check_network() {
    log_info "检查网络连接..."
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_error "网络连接失败，请检查网络设置"
        exit 1
    fi
    log_success "网络连接正常"
}

# 环境检查
perform_environment_check() {
    if [[ "$SKIP_CHECKS" == "true" ]]; then
        log_info "跳过环境检查"
        return 0
    fi
    
    log_info "开始环境检查..."
    
    check_root
    check_network
    
    # 检查必要工具
    local required_tools=("curl" "wget" "systemctl")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_warn "缺少工具: $tool，正在尝试安装..."
            install_package "$tool"
        fi
    done
    
    log_success "环境检查完成"
}

# 安装软件包
install_package() {
    local package="$1"
    local os
    os=$(check_os)
    
    case $os in
        ubuntu|debian)
            apt-get update >/dev/null 2>&1
            apt-get install -y "$package"
            ;;
        centos|rhel|fedora)
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y "$package"
            else
                yum install -y "$package"
            fi
            ;;
        arch)
            pacman -S --noconfirm "$package"
            ;;
        *)
            log_error "不支持的操作系统: $os"
            exit 1
            ;;
    esac
}

# ==================== Sing-box 安装 ====================

# 获取最新版本
get_latest_version() {
    local api_url="https://api.github.com/repos/SagerNet/sing-box/releases/latest"
    local version
    
    if command -v curl >/dev/null 2>&1; then
        version=$(curl -s "$api_url" | grep '"tag_name"' | cut -d'"' -f4)
    elif command -v wget >/dev/null 2>&1; then
        version=$(wget -qO- "$api_url" | grep '"tag_name"' | cut -d'"' -f4)
    else
        log_error "无法获取最新版本，请安装 curl 或 wget"
        exit 1
    fi
    
    if [[ -z "$version" ]]; then
        log_warn "无法获取最新版本，使用默认版本"
        echo "v1.8.0"
    else
        echo "$version"
    fi
}

# 下载 Sing-box
download_singbox() {
    local version="$1"
    local arch
    local os
    local download_url
    local filename
    
    arch=$(check_architecture)
    os="linux"
    
    filename="sing-box-${version#v}-${os}-${arch}.tar.gz"
    download_url="https://github.com/SagerNet/sing-box/releases/download/${version}/${filename}"
    
    log_info "下载 Sing-box ${version}..."
    log_debug "下载地址: $download_url"
    
    # 创建临时目录
    local temp_dir
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    # 下载文件
    if command -v curl >/dev/null 2>&1; then
        curl -L -o "$filename" "$download_url" || {
            log_error "下载失败"
            exit 1
        }
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$filename" "$download_url" || {
            log_error "下载失败"
            exit 1
        }
    else
        log_error "无法下载文件，请安装 curl 或 wget"
        exit 1
    fi
    
    # 解压文件
    tar -xzf "$filename"
    
    # 查找二进制文件
    local binary_path
    binary_path=$(find . -name "sing-box" -type f | head -n1)
    
    if [[ -z "$binary_path" ]]; then
        log_error "未找到 sing-box 二进制文件"
        exit 1
    fi
    
    # 安装二进制文件
    chmod +x "$binary_path"
    cp "$binary_path" "$INSTALL_PATH"
    
    # 清理临时文件
    cd /
    rm -rf "$temp_dir"
    
    log_success "Sing-box 安装完成"
}

# 安装 Sing-box
install_singbox() {
    log_info "开始安装 Sing-box..."
    
    # 创建必要目录
    mkdir -p "$(dirname "$INSTALL_PATH")"
    mkdir -p "$CONFIG_PATH"
    mkdir -p "$LOG_PATH"
    
    # 获取版本
    local version
    if [[ "$SINGBOX_VERSION" == "latest" ]]; then
        version=$(get_latest_version)
    else
        version="$SINGBOX_VERSION"
    fi
    
    log_info "安装版本: $version"
    
    # 下载并安装
    download_singbox "$version"
    
    # 设置权限
    chmod +x "$INSTALL_PATH"
    
    # 验证安装
    if "$INSTALL_PATH" version >/dev/null 2>&1; then
        log_success "Sing-box 安装验证成功"
    else
        log_error "Sing-box 安装验证失败"
        exit 1
    fi
}

# ==================== 配置生成 ====================

# 生成 VLESS Reality 配置
generate_vless_config() {
    local port=${1:-443}
    local uuid
    local private_key
    local public_key
    local short_id
    local dest="www.microsoft.com:443"
    
    # 生成 UUID
    uuid=$("$INSTALL_PATH" generate uuid)
    
    # 生成密钥对
    local keypair
    keypair=$("$INSTALL_PATH" generate reality-keypair)
    private_key=$(echo "$keypair" | grep "PrivateKey" | cut -d' ' -f2)
    public_key=$(echo "$keypair" | grep "PublicKey" | cut -d' ' -f2)
    
    # 生成 short_id
    short_id=$(openssl rand -hex 8)
    
    cat > "${CONFIG_PATH}/config.json" << EOF
{
  "log": {
    "level": "info",
    "output": "${LOG_PATH}/sing-box.log"
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": ${port},
      "users": [
        {
          "uuid": "${uuid}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${dest%:*}",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "${dest}",
            "server_port": ${dest#*:}
          },
          "private_key": "${private_key}",
          "short_id": ["${short_id}"]
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF
    
    # 生成客户端配置信息
    local server_ip
    server_ip=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "YOUR_SERVER_IP")
    
    cat > "${CONFIG_PATH}/client_info.txt" << EOF
=== VLESS Reality 客户端配置信息 ===

服务器地址: ${server_ip}
端口: ${port}
UUID: ${uuid}
流控: xtls-rprx-vision
传输协议: tcp
传输层安全: reality
目标网站: ${dest%:*}
Public Key: ${public_key}
Short ID: ${short_id}

分享链接:
vless://${uuid}@${server_ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${dest%:*}&fp=chrome&pbk=${public_key}&sid=${short_id}&type=tcp&headerType=none#VLESS-Reality
EOF
    
    log_success "VLESS Reality 配置生成完成"
    log_info "配置文件: ${CONFIG_PATH}/config.json"
    log_info "客户端信息: ${CONFIG_PATH}/client_info.txt"
}

# 生成 VMess WebSocket 配置
generate_vmess_config() {
    local port=${1:-80}
    local uuid
    local path="/$(openssl rand -hex 8)"
    
    # 生成 UUID
    uuid=$("$INSTALL_PATH" generate uuid)
    
    cat > "${CONFIG_PATH}/config.json" << EOF
{
  "log": {
    "level": "info",
    "output": "${LOG_PATH}/sing-box.log"
  },
  "inbounds": [
    {
      "type": "vmess",
      "tag": "vmess-in",
      "listen": "::",
      "listen_port": ${port},
      "users": [
        {
          "uuid": "${uuid}",
          "alterId": 0
        }
      ],
      "transport": {
        "type": "ws",
        "path": "${path}"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF
    
    # 生成客户端配置信息
    local server_ip
    server_ip=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "YOUR_SERVER_IP")
    
    cat > "${CONFIG_PATH}/client_info.txt" << EOF
=== VMess WebSocket 客户端配置信息 ===

服务器地址: ${server_ip}
端口: ${port}
UUID: ${uuid}
额外ID: 0
加密方式: auto
传输协议: ws
路径: ${path}

分享链接:
vmess://$(echo -n "{
  \"v\": \"2\",
  \"ps\": \"VMess-WS\",
  \"add\": \"${server_ip}\",
  \"port\": \"${port}\",
  \"id\": \"${uuid}\",
  \"aid\": \"0\",
  \"net\": \"ws\",
  \"type\": \"none\",
  \"host\": \"\",
  \"path\": \"${path}\",
  \"tls\": \"\"
}" | base64 -w 0)
EOF
    
    log_success "VMess WebSocket 配置生成完成"
    log_info "配置文件: ${CONFIG_PATH}/config.json"
    log_info "客户端信息: ${CONFIG_PATH}/client_info.txt"
}

# 生成 Hysteria2 配置
generate_hysteria2_config() {
    local port=${1:-443}
    local password
    
    # 生成密码
    password=$(openssl rand -base64 32)
    
    cat > "${CONFIG_PATH}/config.json" << EOF
{
  "log": {
    "level": "info",
    "output": "${LOG_PATH}/sing-box.log"
  },
  "inbounds": [
    {
      "type": "hysteria2",
      "tag": "hy2-in",
      "listen": "::",
      "listen_port": ${port},
      "users": [
        {
          "password": "${password}"
        }
      ],
      "tls": {
        "enabled": true,
        "alpn": ["h3"],
        "certificate_path": "${CONFIG_PATH}/cert.pem",
        "key_path": "${CONFIG_PATH}/key.pem"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF
    
    # 生成自签名证书
    openssl req -x509 -nodes -newkey rsa:2048 -keyout "${CONFIG_PATH}/key.pem" \
        -out "${CONFIG_PATH}/cert.pem" -days 365 -subj "/CN=hysteria2" >/dev/null 2>&1
    
    # 生成客户端配置信息
    local server_ip
    server_ip=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "YOUR_SERVER_IP")
    
    cat > "${CONFIG_PATH}/client_info.txt" << EOF
=== Hysteria2 客户端配置信息 ===

服务器地址: ${server_ip}
端口: ${port}
密码: ${password}

分享链接:
hysteria2://${password}@${server_ip}:${port}/?insecure=1#Hysteria2
EOF
    
    log_success "Hysteria2 配置生成完成"
    log_info "配置文件: ${CONFIG_PATH}/config.json"
    log_info "客户端信息: ${CONFIG_PATH}/client_info.txt"
}

# 生成配置
generate_config() {
    local protocol="$1"
    local port="$2"
    
    log_info "生成 $protocol 配置..."
    
    case $protocol in
        "vless")
            generate_vless_config "$port"
            ;;
        "vmess")
            generate_vmess_config "$port"
            ;;
        "hysteria2")
            generate_hysteria2_config "$port"
            ;;
        *)
            log_error "不支持的协议: $protocol"
            exit 1
            ;;
    esac
    
    # 验证配置
    if "$INSTALL_PATH" check -c "${CONFIG_PATH}/config.json" >/dev/null 2>&1; then
        log_success "配置验证成功"
    else
        log_error "配置验证失败"
        exit 1
    fi
}

# ==================== 服务管理 ====================

# 创建 systemd 服务
create_service() {
    log_info "创建 systemd 服务..."
    
    cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=${INSTALL_PATH} run -c ${CONFIG_PATH}/config.json
Restart=on-failure
RestartSec=1800s
ExecReload=/bin/kill -HUP \$MAINPID

[Install]
WantedBy=multi-user.target
EOF
    
    # 重新加载 systemd
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    
    log_success "systemd 服务创建完成"
}

# 启动服务
start_service() {
    log_info "启动 Sing-box 服务..."
    
    systemctl start "$SERVICE_NAME"
    
    # 等待服务启动
    sleep 3
    
    # 检查服务状态
    if systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
        log_success "Sing-box 服务启动成功"
    else
        log_error "Sing-box 服务启动失败"
        systemctl status "$SERVICE_NAME"
        exit 1
    fi
}

# 停止服务
stop_service() {
    log_info "停止 Sing-box 服务..."
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    log_success "服务已停止"
}

# 重启服务
restart_service() {
    log_info "重启 Sing-box 服务..."
    systemctl restart "$SERVICE_NAME"
    sleep 3
    
    if systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
        log_success "服务重启成功"
    else
        log_error "服务重启失败"
        exit 1
    fi
}

# 查看服务状态
show_status() {
    echo ""
    echo "=== Sing-box 服务状态 ==="
    systemctl status "$SERVICE_NAME" --no-pager
    
    echo ""
    echo "=== 端口监听状态 ==="
    if command -v ss >/dev/null 2>&1; then
        ss -tlnp | grep sing-box || echo "未发现 sing-box 监听端口"
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tlnp | grep sing-box || echo "未发现 sing-box 监听端口"
    else
        log_warn "缺少网络检查工具"
    fi
}

# ==================== 卸载功能 ====================

# 一键完全卸载
uninstall_singbox() {
    echo ""
    log_warn "=== Sing-box 完全卸载 ==="
    echo ""
    log_warn "此操作将完全删除 Sing-box 及其所有相关文件，包括："
    echo "  • 二进制文件和快捷命令"
    echo "  • systemd 服务文件"
    echo "  • 配置文件和目录"
    echo "  • 日志文件"
    echo "  • 客户端配置和QR码"
    echo "  • 备份文件"
    echo "  • 临时文件和缓存"
    echo ""
    
    if [[ "$INSTALL_MODE" != "silent" ]]; then
        read -p "确定要继续吗？[y/N] " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "取消卸载"
            return 0
        fi
    fi
    
    echo ""
    log_info "开始卸载 Sing-box..."
    
    # 1. 停止和禁用服务
    log_info "[1/8] 停止和禁用服务..."
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    log_success "服务已停止和禁用"
    
    # 2. 删除服务文件
    log_info "[2/8] 删除服务文件..."
    local service_files=(
        "/etc/systemd/system/${SERVICE_NAME}.service"
        "/lib/systemd/system/${SERVICE_NAME}.service"
        "/usr/lib/systemd/system/${SERVICE_NAME}.service"
    )
    for service_file in "${service_files[@]}"; do
        if [[ -f "$service_file" ]]; then
            rm -f "$service_file" && log_info "已删除服务文件: $service_file"
        fi
    done
    systemctl daemon-reload 2>/dev/null || true
    log_success "服务文件已删除"
    
    # 3. 删除二进制文件和快捷命令
    log_info "[3/8] 删除二进制文件和快捷命令..."
    local binary_paths=(
        "$INSTALL_PATH"
        "/usr/local/bin/sing-box"
        "/usr/bin/sing-box"
        "/usr/local/bin/sb"
        "/usr/bin/sb"
    )
    for binary_path in "${binary_paths[@]}"; do
        if [[ -f "$binary_path" ]]; then
            rm -f "$binary_path" && log_info "已删除二进制文件: $binary_path"
        fi
    done
    log_success "二进制文件已删除"
    
    # 4. 删除配置目录
    log_info "[4/8] 删除配置目录..."
    local config_paths=(
        "$CONFIG_PATH"
        "/etc/sing-box"
        "/opt/sing-box"
        "/var/lib/sing-box"
    )
    for config_path in "${config_paths[@]}"; do
        if [[ -d "$config_path" ]]; then
            rm -rf "$config_path" && log_info "已删除配置目录: $config_path"
        fi
    done
    log_success "配置目录已删除"
    
    # 5. 删除日志文件
    log_info "[5/8] 删除日志文件..."
    local log_paths=(
        "$LOG_PATH"
        "/var/log/sing-box"
        "/var/log/sing-box.log"
    )
    for log_path in "${log_paths[@]}"; do
        if [[ -d "$log_path" ]]; then
            rm -rf "$log_path" && log_info "已删除日志目录: $log_path"
        elif [[ -f "$log_path" ]]; then
            rm -f "$log_path" && log_info "已删除日志文件: $log_path"
        fi
    done
    log_success "日志文件已清理"
    
    # 6. 删除备份文件
    log_info "[6/8] 删除备份文件..."
    find /etc /opt /var -name "*sing-box*.backup*" -type f -delete 2>/dev/null || true
    find /etc /opt /var -name "*sing-box*.bak*" -type f -delete 2>/dev/null || true
    log_success "备份文件已清理"
    
    # 7. 清理临时文件
    log_info "[7/8] 清理临时文件..."
    rm -f /tmp/sing-box* 2>/dev/null || true
    rm -f /tmp/config-*.json 2>/dev/null || true
    log_success "临时文件已清理"
    
    # 8. 验证卸载结果
    log_info "[8/8] 验证卸载结果..."
    local remaining_files=()
    
    # 检查是否还有残留文件
    for path in "${binary_paths[@]}" "${config_paths[@]}" "${log_paths[@]}"; do
        if [[ -e "$path" ]]; then
            remaining_files+=("$path")
        fi
    done
    
    if [[ ${#remaining_files[@]} -eq 0 ]]; then
        log_success "卸载完成，未发现残留文件"
    else
        log_warn "发现以下残留文件，请手动删除："
        for file in "${remaining_files[@]}"; do
            echo "  - $file"
        done
    fi
    
    echo ""
    log_success "Sing-box 卸载完成！"
}

# ==================== QR码生成 ====================

# 生成QR码
generate_qrcode() {
    local content="$1"
    local output_file="$2"
    
    # 检查是否安装了qrcode-terminal
    if ! command -v qrcode-terminal >/dev/null 2>&1; then
        log_warn "qrcode-terminal 未安装，正在尝试安装..."
        if command -v npm >/dev/null 2>&1; then
            npm install -g qrcode-terminal >/dev/null 2>&1 || {
                log_warn "无法安装 qrcode-terminal"
                return 1
            }
        else
            log_warn "未找到 npm，无法安装 qrcode-terminal"
            return 1
        fi
    fi
    
    # 生成QR码
    if [[ -n "$output_file" ]]; then
        qrcode-terminal "$content" --${QR_SIZE} > "$output_file"
    else
        echo ""
        echo "=== 分享链接二维码 ==="
        qrcode-terminal "$content" --${QR_SIZE}
        echo ""
    fi
}

# ==================== 协议选择 ====================

# 选择协议
select_protocol() {
    if [[ -n "$SELECTED_PROTOCOL" ]]; then
        return 0
    fi
    
    if [[ "$INSTALL_MODE" == "silent" ]]; then
        SELECTED_PROTOCOL="vless"
        log_info "静默模式，使用默认协议: $SELECTED_PROTOCOL"
        return 0
    fi
    
    echo ""
    echo "=== 选择协议类型 ==="
    echo "1. VLESS Reality (推荐)"
    echo "2. VMess WebSocket"
    echo "3. Hysteria2"
    echo ""
    
    while true; do
        read -p "请选择协议 [1-3]: " choice
        case $choice in
            1)
                SELECTED_PROTOCOL="vless"
                break
                ;;
            2)
                SELECTED_PROTOCOL="vmess"
                break
                ;;
            3)
                SELECTED_PROTOCOL="hysteria2"
                break
                ;;
            *)
                log_error "无效选择，请输入 1-3"
                ;;
        esac
    done
    
    log_info "已选择协议: $SELECTED_PROTOCOL"
}

# 选择端口
select_port() {
    local default_port
    
    case $SELECTED_PROTOCOL in
        "vless")
            default_port=443
            ;;
        "vmess")
            default_port=80
            ;;
        "hysteria2")
            default_port=443
            ;;
        *)
            default_port=443
            ;;
    esac
    
    if [[ "$INSTALL_MODE" == "silent" ]]; then
        echo "$default_port"
        return 0
    fi
    
    echo ""
    read -p "请输入端口号 [默认: $default_port]: " port
    
    if [[ -z "$port" ]]; then
        port="$default_port"
    fi
    
    # 验证端口号
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
        log_error "无效端口号: $port"
        exit 1
    fi
    
    echo "$port"
}

# ==================== 主要功能 ====================

# 显示脚本信息
show_script_info() {
    echo ""
    echo "======================================"
    echo "  $SCRIPT_NAME"
    echo "  版本: $SCRIPT_VERSION"
    echo "  作者: $SCRIPT_AUTHOR"
    echo "  描述: $SCRIPT_DESCRIPTION"
    echo "======================================"
    echo ""
}

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项] [命令]

选项:
  -h, --help              显示此帮助信息
  -v, --version           显示版本信息
  -d, --debug             启用调试模式
  -f, --force             强制重新安装
  -s, --silent            静默模式（非交互）
  -p, --protocol <type>   指定协议类型 (vless|vmess|hysteria2)
  --skip-checks           跳过环境检查
  --install-path <path>   指定安装路径
  --config-path <path>    指定配置目录

命令:
  install                 安装 Sing-box
  uninstall              一键完全卸载 Sing-box（删除所有相关文件）
  restart                重启服务
  status                 查看服务状态
  qr                     显示分享链接二维码

协议类型:
  vless                  VLESS Reality 协议（推荐）
  vmess                  VMess WebSocket 协议
  hysteria2              Hysteria2 协议

示例:
  $0                     # 交互式安装
  $0 install             # 自动安装
  $0 -p vless install    # 安装 VLESS 协议
  $0 --silent install    # 静默安装
  $0 status              # 查看服务状态
  $0 uninstall           # 完全卸载
  $0 qr                  # 显示二维码

更多信息请访问: $SCRIPT_URL
EOF
}

# 显示配置信息
show_config_info() {
    if [[ ! -f "${CONFIG_PATH}/client_info.txt" ]]; then
        log_error "未找到客户端配置信息"
        return 1
    fi
    
    echo ""
    cat "${CONFIG_PATH}/client_info.txt"
    echo ""
    
    # 显示二维码
    local share_link
    share_link=$(grep -E "^(vless://|vmess://|hysteria2://)" "${CONFIG_PATH}/client_info.txt" | head -n1)
    
    if [[ -n "$share_link" ]]; then
        generate_qrcode "$share_link"
    fi
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "$SCRIPT_NAME $SCRIPT_VERSION"
                exit 0
                ;;
            -d|--debug)
                DEBUG_MODE="true"
                ;;
            -f|--force)
                FORCE_REINSTALL="true"
                ;;
            -s|--silent)
                INSTALL_MODE="silent"
                ;;
            -p|--protocol)
                SELECTED_PROTOCOL="$2"
                shift
                ;;
            --skip-checks)
                SKIP_CHECKS="true"
                ;;
            --install-path)
                INSTALL_PATH="$2"
                shift
                ;;
            --config-path)
                CONFIG_PATH="$2"
                shift
                ;;
            install)
                SERVICE_ACTION="install"
                ;;
            uninstall)
                SERVICE_ACTION="uninstall"
                ;;
            restart)
                SERVICE_ACTION="restart"
                ;;
            status)
                SERVICE_ACTION="status"
                ;;
            qr)
                SERVICE_ACTION="qr"
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
    
    # 如果没有指定操作，默认为安装
    if [[ -z "$SERVICE_ACTION" ]]; then
        SERVICE_ACTION="install"
    fi
}

# 主安装流程
perform_install() {
    log_info "开始安装 Sing-box..."
    
    # 环境检查
    perform_environment_check
    
    # 选择协议
    select_protocol
    
    # 选择端口
    local port
    port=$(select_port)
    
    # 安装 Sing-box
    install_singbox
    
    # 生成配置
    generate_config "$SELECTED_PROTOCOL" "$port"
    
    # 创建服务
    create_service
    
    # 启动服务
    start_service
    
    # 显示配置信息
    echo ""
    log_success "Sing-box 安装完成！"
    show_config_info
}

# 主函数
main() {
    # 显示脚本信息
    if [[ "$INSTALL_MODE" != "silent" ]]; then
        show_script_info
    fi
    
    # 解析命令行参数
    parse_arguments "$@"
    
    # 根据操作执行相应功能
    case "$SERVICE_ACTION" in
        "install")
            perform_install
            ;;
        "uninstall")
            uninstall_singbox
            ;;
        "restart")
            restart_service
            ;;
        "status")
            show_status
            ;;
        "qr")
            show_config_info
            ;;
        *)
            log_error "未知操作: $SERVICE_ACTION"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"