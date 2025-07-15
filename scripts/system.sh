#!/bin/bash

# 系统检测和配置模块
# 负责系统环境检测、依赖安装、基础配置等

# 检测操作系统
detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        OS_CODENAME=${VERSION_CODENAME:-}
    elif [[ -f /etc/redhat-release ]]; then
        OS="centos"
        OS_VERSION=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | head -1)
    else
        log_error "无法检测操作系统类型"
        exit 1
    fi
    
    # 标准化操作系统名称
    case "$OS" in
        ubuntu|debian)
            PACKAGE_MANAGER="apt"
            PACKAGE_UPDATE="apt update"
            PACKAGE_INSTALL="apt install -y"
            ;;
        centos|rhel|fedora|rocky|almalinux)
            if command_exists dnf; then
                PACKAGE_MANAGER="dnf"
                PACKAGE_UPDATE="dnf check-update"
                PACKAGE_INSTALL="dnf install -y"
            else
                PACKAGE_MANAGER="yum"
                PACKAGE_UPDATE="yum check-update"
                PACKAGE_INSTALL="yum install -y"
            fi
            ;;
        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac
    
    log_info "检测到操作系统: $OS $OS_VERSION"
    log_info "包管理器: $PACKAGE_MANAGER"
}

# 检测系统架构
detect_arch() {
    local arch=$(uname -m)
    
    case "$arch" in
        x86_64|amd64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        armv7l)
            ARCH="armv7"
            ;;
        *)
            log_error "不支持的系统架构: $arch"
            exit 1
            ;;
    esac
    
    log_info "检测到系统架构: $ARCH"
}

# 检查系统资源
check_system_resources() {
    # 检查内存
    local mem_total=$(free -m | awk '/^Mem:/ {print $2}')
    if [[ $mem_total -lt 512 ]]; then
        log_warn "系统内存不足 512MB，可能影响性能"
    else
        log_info "系统内存: ${mem_total}MB"
    fi
    
    # 检查磁盘空间
    local disk_available=$(df / | awk 'NR==2 {print int($4/1024)}')
    if [[ $disk_available -lt 1024 ]]; then
        log_error "磁盘可用空间不足 1GB"
        exit 1
    else
        log_info "磁盘可用空间: ${disk_available}MB"
    fi
}

# 检查网络环境
check_network_environment() {
    log_info "检查网络环境..."
    
    # 检查网络连通性
    if ! check_network; then
        log_error "网络连接检查失败，请检查网络设置"
        exit 1
    fi
    
    # 获取公网 IP
    PUBLIC_IP=$(get_public_ip)
    if [[ -n "$PUBLIC_IP" ]]; then
        log_info "公网 IP: $PUBLIC_IP"
    else
        log_warn "无法获取公网 IP，可能影响某些功能"
    fi
    
    # 检查 IPv6 支持
    if ip -6 addr show | grep -q "inet6.*global"; then
        IPV6_SUPPORT=true
        log_info "检测到 IPv6 支持"
    else
        IPV6_SUPPORT=false
        log_info "未检测到 IPv6 支持"
    fi
}

# 更新包管理器
update_package_manager() {
    log_info "更新包管理器..."
    
    case "$PACKAGE_MANAGER" in
        apt)
            $PACKAGE_UPDATE >/dev/null 2>&1 || {
                log_error "更新 apt 包列表失败"
                exit 1
            }
            ;;
        yum|dnf)
            $PACKAGE_UPDATE >/dev/null 2>&1 || true
            ;;
    esac
    
    log_success "包管理器更新完成"
}

# 安装基础依赖
install_basic_dependencies() {
    log_info "安装基础依赖包..."
    
    local basic_packages
    case "$PACKAGE_MANAGER" in
        apt)
            basic_packages=("curl" "wget" "unzip" "tar" "openssl" "ca-certificates" "systemd")
            ;;
        yum|dnf)
            basic_packages=("curl" "wget" "unzip" "tar" "openssl" "ca-certificates" "systemd")
            ;;
    esac
    
    for package in "${basic_packages[@]}"; do
        if ! command_exists "$package"; then
            log_info "安装 $package..."
            $PACKAGE_INSTALL "$package" >/dev/null 2>&1 || {
                log_error "安装 $package 失败"
                exit 1
            }
        else
            log_debug "$package 已安装"
        fi
    done
    
    log_success "基础依赖安装完成"
}

# 检查防火墙状态
check_firewall() {
    log_info "检查防火墙状态..."
    
    # 检查 ufw (Ubuntu/Debian)
    if command_exists ufw; then
        FIREWALL_TYPE="ufw"
        if ufw status | grep -q "Status: active"; then
            FIREWALL_ACTIVE=true
            log_info "检测到活跃的 ufw 防火墙"
        else
            FIREWALL_ACTIVE=false
            log_info "ufw 防火墙未激活"
        fi
    # 检查 firewalld (CentOS/RHEL/Fedora)
    elif command_exists firewall-cmd; then
        FIREWALL_TYPE="firewalld"
        if systemctl is-active firewalld >/dev/null 2>&1; then
            FIREWALL_ACTIVE=true
            log_info "检测到活跃的 firewalld 防火墙"
        else
            FIREWALL_ACTIVE=false
            log_info "firewalld 防火墙未激活"
        fi
    # 检查 iptables
    elif command_exists iptables; then
        FIREWALL_TYPE="iptables"
        if iptables -L | grep -q "Chain"; then
            FIREWALL_ACTIVE=true
            log_info "检测到 iptables 规则"
        else
            FIREWALL_ACTIVE=false
            log_info "未检测到 iptables 规则"
        fi
    else
        FIREWALL_TYPE="none"
        FIREWALL_ACTIVE=false
        log_info "未检测到防火墙"
    fi
}

# 检查 SELinux 状态
check_selinux() {
    if command_exists getenforce; then
        local selinux_status=$(getenforce 2>/dev/null)
        case "$selinux_status" in
            Enforcing)
                SELINUX_STATUS="enforcing"
                log_warn "SELinux 处于强制模式，可能需要额外配置"
                ;;
            Permissive)
                SELINUX_STATUS="permissive"
                log_info "SELinux 处于宽松模式"
                ;;
            Disabled)
                SELINUX_STATUS="disabled"
                log_info "SELinux 已禁用"
                ;;
            *)
                SELINUX_STATUS="unknown"
                log_info "SELinux 状态未知"
                ;;
        esac
    else
        SELINUX_STATUS="not_installed"
        log_debug "SELinux 未安装"
    fi
}

# 创建工作目录
create_directories() {
    log_info "创建工作目录..."
    
    local directories=(
        "$WORK_DIR"
        "$WORK_DIR/config"
        "$WORK_DIR/certs"
        "$WORK_DIR/logs"
        "/var/log/sing-box"
    )
    
    for dir in "${directories[@]}"; do
        create_directory "$dir" 755
    done
    
    # 设置日志目录权限
    chown -R root:root "$WORK_DIR"
    chmod -R 755 "$WORK_DIR"
    
    log_success "工作目录创建完成"
}

# 检查端口占用
check_required_ports() {
    log_info "检查端口占用情况..."
    
    local common_ports=(80 443 22 53)
    local occupied_ports=()
    
    for port in "${common_ports[@]}"; do
        if check_port "$port"; then
            occupied_ports+=("$port")
        fi
    done
    
    if [[ ${#occupied_ports[@]} -gt 0 ]]; then
        log_warn "以下常用端口已被占用: ${occupied_ports[*]}"
        log_warn "这可能影响某些协议的默认配置"
    fi
}

# 检查时间同步
check_time_sync() {
    log_info "检查系统时间同步..."
    
    # 检查 systemd-timesyncd
    if systemctl is-active systemd-timesyncd >/dev/null 2>&1; then
        log_info "systemd-timesyncd 正在运行"
    # 检查 ntp
    elif systemctl is-active ntp >/dev/null 2>&1; then
        log_info "ntp 服务正在运行"
    # 检查 chrony
    elif systemctl is-active chronyd >/dev/null 2>&1; then
        log_info "chrony 服务正在运行"
    else
        log_warn "未检测到时间同步服务，建议启用时间同步"
        
        # 尝试启用 systemd-timesyncd
        if command_exists timedatectl; then
            timedatectl set-ntp true >/dev/null 2>&1 || true
            log_info "已尝试启用 systemd-timesyncd"
        fi
    fi
    
    # 显示当前时间
    log_info "当前系统时间: $(date)"
}

# 优化系统参数
optimize_system() {
    log_info "优化系统参数..."
    
    # 创建 sysctl 配置文件
    cat > /etc/sysctl.d/99-sing-box.conf << EOF
# Sing-box 系统优化参数

# 网络优化
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# 文件描述符限制
fs.file-max = 1000000

# 连接跟踪优化
net.netfilter.nf_conntrack_max = 1000000
net.netfilter.nf_conntrack_tcp_timeout_established = 7200
EOF
    
    # 应用 sysctl 配置
    sysctl -p /etc/sysctl.d/99-sing-box.conf >/dev/null 2>&1 || true
    
    # 设置文件描述符限制
    cat > /etc/security/limits.d/99-sing-box.conf << EOF
# Sing-box 文件描述符限制
* soft nofile 1000000
* hard nofile 1000000
root soft nofile 1000000
root hard nofile 1000000
EOF
    
    log_success "系统参数优化完成"
}

# 主系统检查函数
check_system() {
    log_info "开始系统环境检查..."
    
    # 检查 root 权限
    check_root
    
    # 检测操作系统和架构
    detect_os
    detect_arch
    
    # 检查系统资源
    check_system_resources
    
    # 检查网络环境
    check_network_environment
    
    # 检查防火墙和 SELinux
    check_firewall
    check_selinux
    
    # 检查时间同步
    check_time_sync
    
    # 检查端口占用
    check_required_ports
    
    log_success "系统环境检查完成"
}

# 检查和安装依赖
check_dependencies() {
    log_info "检查和安装依赖..."
    
    # 更新包管理器
    update_package_manager
    
    # 安装基础依赖
    install_basic_dependencies
    
    # 优化系统参数
    optimize_system
    
    log_success "依赖检查和安装完成"
}

# 显示系统信息摘要
show_system_summary() {
    echo -e "${CYAN}=== 系统信息摘要 ===${NC}"
    echo -e "操作系统: ${GREEN}$OS $OS_VERSION${NC}"
    echo -e "系统架构: ${GREEN}$ARCH${NC}"
    echo -e "公网 IP: ${GREEN}${PUBLIC_IP:-"未知"}${NC}"
    echo -e "IPv6 支持: ${GREEN}${IPV6_SUPPORT:-false}${NC}"
    echo -e "防火墙: ${GREEN}$FIREWALL_TYPE${NC} (${GREEN}${FIREWALL_ACTIVE:-false}${NC})"
    echo -e "SELinux: ${GREEN}${SELINUX_STATUS:-"未知"}${NC}"
    echo ""
}