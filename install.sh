#!/bin/bash

# Sing-box 一键安装脚本
# 支持 Shadowsocks、SOCKS5、REALITY 等多种协议

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 输出函数
echo_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

echo_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查系统是否为 root 用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo_error "请以 root 用户运行此脚本"
        exit 1
    fi
}

# 检查操作系统
check_os() {
    if [[ -f /etc/debian_version ]]; then
        OS="debian"
        echo_info "检测到 Debian/Ubuntu 系统"
    elif [[ -f /etc/redhat-release ]]; then
        OS="centos"
        echo_info "检测到 CentOS/RHEL 系统"
    else
        echo_error "不支持的操作系统"
        exit 1
    fi
}

# 安装必要的依赖
install_dependencies() {
    echo_info "安装必要的依赖..."
    
    if [[ "$OS" == "debian" ]]; then
        apt update
        apt install -y curl wget sudo nano
    elif [[ "$OS" == "centos" ]]; then
        yum update -y
        yum install -y curl wget sudo nano
    fi
}

# 安装 sing-box
install_singbox() {
    echo_info "开始安装 sing-box..."
    
    if [[ "$OS" == "debian" ]]; then
        bash <(curl -fsSL https://sing-box.app/deb-install.sh)
    elif [[ "$OS" == "centos" ]]; then
        bash <(curl -fsSL https://sing-box.app/rpm-install.sh)
    fi
    
    if [[ $? -eq 0 ]]; then
        echo_success "sing-box 安装成功"
    else
        echo_error "sing-box 安装失败"
        exit 1
    fi
}

# 生成随机密码
generate_password() {
    openssl rand -base64 16
}

# 生成随机端口
generate_port() {
    local min=10000
    local max=65000
    echo $((RANDOM % (max - min + 1) + min))
}

# 生成配置文件
generate_config() {
    echo_info "生成配置文件..."
    
    # 生成各种密钥和参数
    SS_PASSWORD=$(sing-box generate rand --base64 16)
    UUID=$(sing-box generate uuid)
    REALITY_KEYS=$(sing-box generate reality-keypair)
    PRIVATE_KEY=$(echo "$REALITY_KEYS" | grep "PrivateKey" | cut -d' ' -f2)
    PUBLIC_KEY=$(echo "$REALITY_KEYS" | grep "PublicKey" | cut -d' ' -f2)
    
    # 生成随机端口
    SOCKS_PORT=$(generate_port)
    SS_PORT=$(generate_port)
    REALITY_PORT=443
    
    # 生成 SOCKS5 用户名和密码
    SOCKS_USER="user$(date +%s)"
    SOCKS_PASS=$(generate_password)
    
    # 获取服务器公网IP
    SERVER_IP=$(curl -s ip.sb)
    
    cat > /etc/sing-box/config.json << EOF
{
  "log": {
    "disabled": false,
    "level": "warn",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "socks",
      "tag": "socks-in",
      "listen": "::",
      "listen_port": $SOCKS_PORT,
      "users": [
        {
          "username": "$SOCKS_USER",
          "password": "$SOCKS_PASS"
        }
      ]
    },
    {
      "type": "shadowsocks",
      "tag": "ss-in",
      "listen": "::",
      "listen_port": $SS_PORT,
      "method": "2022-blake3-aes-128-gcm",
      "password": "$SS_PASSWORD"
    },
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": $REALITY_PORT,
      "users": [
        {
          "uuid": "$UUID",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "www.microsoft.com",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "www.microsoft.com",
            "server_port": 443
          },
          "private_key": "$PRIVATE_KEY",
          "short_id": ["0123456789abcdef"]
        }
      }
    }
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

    echo_success "配置文件生成完成"
}

# 启动并设置开机自启
start_service() {
    echo_info "启动 sing-box 服务..."
    
    systemctl enable sing-box
    systemctl start sing-box
    
    if systemctl is-active --quiet sing-box; then
        echo_success "sing-box 服务启动成功"
    else
        echo_error "sing-box 服务启动失败，请检查配置"
        echo_info "查看日志: journalctl -u sing-box --output cat -e"
        exit 1
    fi
}

# 显示配置信息
show_config() {
    echo_info "正在获取配置信息..."
    
    echo ""
    echo "=========================================="
    echo_success "Sing-box 安装完成！"
    echo "=========================================="
    echo ""
    echo_info "服务器信息:"
    echo "  IP 地址: $SERVER_IP"
    echo ""
    echo_info "SOCKS5 代理配置:"
    echo "  地址: $SERVER_IP"
    echo "  端口: $SOCKS_PORT"
    echo "  用户名: $SOCKS_USER"
    echo "  密码: $SOCKS_PASS"
    echo ""
    echo_info "Shadowsocks 配置:"
    echo "  地址: $SERVER_IP"
    echo "  端口: $SS_PORT"
    echo "  密码: $SS_PASSWORD"
    echo "  加密方式: 2022-blake3-aes-128-gcm"
    echo ""
    echo_info "REALITY 配置:"
    echo "  地址: $SERVER_IP"
    echo "  端口: $REALITY_PORT"
    echo "  UUID: $UUID"
    echo "  Flow: xtls-rprx-vision"
    echo "  SNI: www.microsoft.com"
    echo "  公钥: $PUBLIC_KEY"
    echo "  Short ID: 0123456789abcdef"
    echo ""
    echo_info "常用命令:"
    echo "  启动服务: systemctl start sing-box"
    echo "  停止服务: systemctl stop sing-box"
    echo "  重启服务: systemctl restart sing-box"
    echo "  查看状态: systemctl status sing-box"
    echo "  查看日志: journalctl -u sing-box --output cat -e"
    echo "  查看端口: netstat -tulnp | grep sing-box"
    echo ""
    echo_warning "请保存好以上配置信息，用于客户端连接！"
    echo ""
}

# 防火墙设置
setup_firewall() {
    echo_info "配置防火墙..."
    
    # 尝试检测并配置防火墙
    if command -v ufw &> /dev/null; then
        echo_info "检测到 UFW 防火墙"
        ufw allow $SOCKS_PORT/tcp
        ufw allow $SS_PORT/tcp
        ufw allow $SS_PORT/udp
        ufw allow $REALITY_PORT/tcp
        echo_success "UFW 防火墙规则已添加"
    elif command -v firewall-cmd &> /dev/null; then
        echo_info "检测到 firewalld 防火墙"
        firewall-cmd --permanent --add-port=$SOCKS_PORT/tcp
        firewall-cmd --permanent --add-port=$SS_PORT/tcp
        firewall-cmd --permanent --add-port=$SS_PORT/udp
        firewall-cmd --permanent --add-port=$REALITY_PORT/tcp
        firewall-cmd --reload
        echo_success "firewalld 防火墙规则已添加"
    elif command -v iptables &> /dev/null; then
        echo_info "检测到 iptables 防火墙"
        iptables -A INPUT -p tcp --dport $SOCKS_PORT -j ACCEPT
        iptables -A INPUT -p tcp --dport $SS_PORT -j ACCEPT
        iptables -A INPUT -p udp --dport $SS_PORT -j ACCEPT
        iptables -A INPUT -p tcp --dport $REALITY_PORT -j ACCEPT
        # 尝试保存 iptables 规则
        if command -v iptables-save &> /dev/null; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
        fi
        echo_success "iptables 防火墙规则已添加"
    else
        echo_warning "未检测到防火墙，请手动开放端口: $SOCKS_PORT, $SS_PORT, $REALITY_PORT"
    fi
}

# 卸载函数
uninstall_singbox() {
    echo_warning "开始卸载 sing-box..."
    
    # 停止服务
    systemctl stop sing-box 2>/dev/null || true
    systemctl disable sing-box 2>/dev/null || true
    
    # 删除文件
    rm -f /usr/local/bin/sing-box
    rm -rf /etc/sing-box
    rm -f /etc/systemd/system/sing-box.service
    
    # 重新加载 systemd
    systemctl daemon-reload
    
    echo_success "sing-box 卸载完成"
}

# 主菜单
main_menu() {
    echo ""
    echo "=========================================="
    echo "         Sing-box 一键安装脚本"
    echo "=========================================="
    echo "1. 安装 Sing-box"
    echo "2. 卸载 Sing-box"
    echo "3. 重启 Sing-box"
    echo "4. 查看状态"
    echo "5. 查看配置"
    echo "6. 查看日志"
    echo "0. 退出"
    echo "=========================================="
    echo ""
    read -p "请输入选项 [0-6]: " choice
    
    case $choice in
        1)
            install_menu
            ;;
        2)
            uninstall_singbox
            ;;
        3)
            systemctl restart sing-box
            echo_success "服务重启完成"
            ;;
        4)
            systemctl status sing-box
            ;;
        5)
            if [[ -f /etc/sing-box/config.json ]]; then
                cat /etc/sing-box/config.json
            else
                echo_error "配置文件不存在"
            fi
            ;;
        6)
            journalctl -u sing-box --output cat -e
            ;;
        0)
            echo_info "退出脚本"
            exit 0
            ;;
        *)
            echo_error "无效选项"
            main_menu
            ;;
    esac
}

# 安装菜单
install_menu() {
    check_root
    check_os
    install_dependencies
    install_singbox
    generate_config
    start_service
    setup_firewall
    show_config
}

# 主程序
main() {
    if [[ $# -gt 0 ]]; then
        case $1 in
            install)
                install_menu
                ;;
            uninstall)
                uninstall_singbox
                ;;
            *)
                echo_error "未知参数: $1"
                echo_info "使用方法: $0 [install|uninstall]"
                ;;
        esac
    else
        main_menu
    fi
}

# 运行主程序
main "$@"
