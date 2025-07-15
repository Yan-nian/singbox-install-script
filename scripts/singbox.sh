#!/bin/bash

# Sing-box 安装和管理模块
# 负责 Sing-box 的下载、安装、配置、启动、停止等核心功能

# Sing-box 相关变量
SINGBOX_VERSION="latest"
SINGBOX_BINARY="/usr/local/bin/sing-box"
SINGBOX_CONFIG="$WORK_DIR/config/config.json"
SINGBOX_SERVICE="/etc/systemd/system/sing-box.service"
SINGBOX_LOG="/var/log/sing-box/sing-box.log"

# GitHub API 相关
GITHUB_API="https://api.github.com/repos/SagerNet/sing-box/releases"
GITHUB_RELEASE="https://github.com/SagerNet/sing-box/releases/download"

# 获取最新版本号
get_latest_version() {
    log_info "获取 Sing-box 最新版本..."
    
    local version
    version=$(curl -s "$GITHUB_API/latest" | grep '"tag_name"' | cut -d'"' -f4)
    
    if [[ -z "$version" ]]; then
        log_error "无法获取最新版本信息"
        return 1
    fi
    
    # 移除 v 前缀
    version=${version#v}
    echo "$version"
}

# 获取指定版本的下载链接
get_download_url() {
    local version="$1"
    local arch="$2"
    
    # 构建文件名
    local filename="sing-box-${version}-linux-${arch}.tar.gz"
    local download_url="${GITHUB_RELEASE}/v${version}/${filename}"
    
    echo "$download_url"
}

# 检查 Sing-box 是否已安装
check_singbox_installed() {
    if [[ -f "$SINGBOX_BINARY" ]]; then
        local installed_version
        installed_version=$($SINGBOX_BINARY version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        
        if [[ -n "$installed_version" ]]; then
            log_info "检测到已安装的 Sing-box 版本: $installed_version"
            return 0
        fi
    fi
    
    return 1
}

# 下载 Sing-box
download_singbox() {
    local version="$1"
    local force="${2:-false}"
    
    # 如果已安装且不强制更新，则跳过
    if [[ "$force" != "true" ]] && check_singbox_installed; then
        log_info "Sing-box 已安装，跳过下载"
        return 0
    fi
    
    log_info "开始下载 Sing-box v$version..."
    
    # 获取下载链接
    local download_url
    download_url=$(get_download_url "$version" "$ARCH")
    
    # 创建临时目录
    local temp_dir
    temp_dir=$(mktemp -d)
    
    # 下载文件
    local filename="sing-box-${version}-linux-${ARCH}.tar.gz"
    local temp_file="$temp_dir/$filename"
    
    log_info "下载地址: $download_url"
    
    if ! download_file "$download_url" "$temp_file"; then
        log_error "下载 Sing-box 失败"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 验证下载的文件
    if [[ ! -f "$temp_file" ]] || [[ ! -s "$temp_file" ]]; then
        log_error "下载的文件无效"
        rm -rf "$temp_dir"
        return 1
    fi
    
    log_success "Sing-box 下载完成"
    
    # 解压文件
    log_info "解压 Sing-box..."
    
    if ! tar -xzf "$temp_file" -C "$temp_dir"; then
        log_error "解压 Sing-box 失败"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 查找二进制文件
    local binary_path
    binary_path=$(find "$temp_dir" -name "sing-box" -type f -executable | head -1)
    
    if [[ ! -f "$binary_path" ]]; then
        log_error "未找到 Sing-box 二进制文件"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 停止服务（如果正在运行）
    if systemctl is-active sing-box >/dev/null 2>&1; then
        log_info "停止 Sing-box 服务..."
        systemctl stop sing-box
    fi
    
    # 备份旧版本
    if [[ -f "$SINGBOX_BINARY" ]]; then
        backup_file "$SINGBOX_BINARY"
    fi
    
    # 安装新版本
    log_info "安装 Sing-box..."
    
    cp "$binary_path" "$SINGBOX_BINARY"
    chmod +x "$SINGBOX_BINARY"
    
    # 清理临时文件
    rm -rf "$temp_dir"
    
    # 验证安装
    if ! "$SINGBOX_BINARY" version >/dev/null 2>&1; then
        log_error "Sing-box 安装验证失败"
        return 1
    fi
    
    local installed_version
    installed_version=$($SINGBOX_BINARY version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    
    log_success "Sing-box v$installed_version 安装完成"
    return 0
}

# 创建 systemd 服务文件
create_systemd_service() {
    log_info "创建 systemd 服务文件..."
    
    cat > "$SINGBOX_SERVICE" << EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=$SINGBOX_BINARY run -c $SINGBOX_CONFIG
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
    
    # 重新加载 systemd
    systemctl daemon-reload
    
    log_success "systemd 服务文件创建完成"
}

# 启动 Sing-box 服务
start_singbox() {
    log_info "启动 Sing-box 服务..."
    
    # 检查配置文件
    if [[ ! -f "$SINGBOX_CONFIG" ]]; then
        log_error "配置文件不存在: $SINGBOX_CONFIG"
        return 1
    fi
    
    # 验证配置文件
    if ! "$SINGBOX_BINARY" check -c "$SINGBOX_CONFIG"; then
        log_error "配置文件验证失败"
        return 1
    fi
    
    # 启用并启动服务
    systemctl enable sing-box
    systemctl start sing-box
    
    # 等待服务启动
    sleep 2
    
    # 检查服务状态
    if systemctl is-active sing-box >/dev/null 2>&1; then
        log_success "Sing-box 服务启动成功"
        return 0
    else
        log_error "Sing-box 服务启动失败"
        
        # 显示错误日志
        log_info "错误日志:"
        journalctl -u sing-box --no-pager -n 10
        
        return 1
    fi
}

# 停止 Sing-box 服务
stop_singbox() {
    log_info "停止 Sing-box 服务..."
    
    if systemctl is-active sing-box >/dev/null 2>&1; then
        systemctl stop sing-box
        log_success "Sing-box 服务已停止"
    else
        log_info "Sing-box 服务未运行"
    fi
}

# 重启 Sing-box 服务
restart_singbox() {
    log_info "重启 Sing-box 服务..."
    
    # 验证配置文件
    if [[ -f "$SINGBOX_CONFIG" ]]; then
        if ! "$SINGBOX_BINARY" check -c "$SINGBOX_CONFIG"; then
            log_error "配置文件验证失败，取消重启"
            return 1
        fi
    fi
    
    systemctl restart sing-box
    
    # 等待服务启动
    sleep 2
    
    # 检查服务状态
    if systemctl is-active sing-box >/dev/null 2>&1; then
        log_success "Sing-box 服务重启成功"
        return 0
    else
        log_error "Sing-box 服务重启失败"
        return 1
    fi
}

# 重新加载配置
reload_singbox() {
    log_info "重新加载 Sing-box 配置..."
    
    # 验证配置文件
    if ! "$SINGBOX_BINARY" check -c "$SINGBOX_CONFIG"; then
        log_error "配置文件验证失败，取消重新加载"
        return 1
    fi
    
    if systemctl is-active sing-box >/dev/null 2>&1; then
        systemctl reload sing-box
        log_success "Sing-box 配置重新加载成功"
    else
        log_warn "Sing-box 服务未运行，启动服务..."
        start_singbox
    fi
}

# 获取 Sing-box 状态
get_singbox_status() {
    if systemctl is-active sing-box >/dev/null 2>&1; then
        echo "running"
    elif systemctl is-enabled sing-box >/dev/null 2>&1; then
        echo "stopped"
    else
        echo "disabled"
    fi
}

# 显示 Sing-box 信息
show_singbox_info() {
    echo -e "${CYAN}=== Sing-box 信息 ===${NC}"
    
    # 版本信息
    if [[ -f "$SINGBOX_BINARY" ]]; then
        local version
        version=$($SINGBOX_BINARY version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        echo -e "版本: ${GREEN}${version:-"未知"}${NC}"
    else
        echo -e "版本: ${RED}未安装${NC}"
    fi
    
    # 服务状态
    local status
    status=$(get_singbox_status)
    case "$status" in
        running)
            echo -e "状态: ${GREEN}运行中${NC}"
            ;;
        stopped)
            echo -e "状态: ${YELLOW}已停止${NC}"
            ;;
        disabled)
            echo -e "状态: ${RED}未启用${NC}"
            ;;
    esac
    
    # 配置文件
    if [[ -f "$SINGBOX_CONFIG" ]]; then
        echo -e "配置文件: ${GREEN}$SINGBOX_CONFIG${NC}"
    else
        echo -e "配置文件: ${RED}不存在${NC}"
    fi
    
    # 日志文件
    if [[ -f "$SINGBOX_LOG" ]]; then
        echo -e "日志文件: ${GREEN}$SINGBOX_LOG${NC}"
    else
        echo -e "日志文件: ${YELLOW}$SINGBOX_LOG${NC}"
    fi
    
    echo ""
}

# 显示 Sing-box 日志
show_singbox_logs() {
    local lines="${1:-50}"
    
    log_info "显示 Sing-box 日志 (最近 $lines 行)..."
    
    if systemctl is-active sing-box >/dev/null 2>&1; then
        journalctl -u sing-box --no-pager -n "$lines" -f
    else
        journalctl -u sing-box --no-pager -n "$lines"
    fi
}

# 检查 Sing-box 配置
check_singbox_config() {
    if [[ ! -f "$SINGBOX_CONFIG" ]]; then
        log_error "配置文件不存在: $SINGBOX_CONFIG"
        return 1
    fi
    
    log_info "检查 Sing-box 配置文件..."
    
    if "$SINGBOX_BINARY" check -c "$SINGBOX_CONFIG"; then
        log_success "配置文件验证通过"
        return 0
    else
        log_error "配置文件验证失败"
        return 1
    fi
}

# 卸载 Sing-box
uninstall_singbox() {
    log_info "开始卸载 Sing-box..."
    
    # 停止并禁用服务
    if systemctl is-active sing-box >/dev/null 2>&1; then
        systemctl stop sing-box
    fi
    
    if systemctl is-enabled sing-box >/dev/null 2>&1; then
        systemctl disable sing-box
    fi
    
    # 删除服务文件
    if [[ -f "$SINGBOX_SERVICE" ]]; then
        rm -f "$SINGBOX_SERVICE"
        systemctl daemon-reload
    fi
    
    # 删除二进制文件
    if [[ -f "$SINGBOX_BINARY" ]]; then
        rm -f "$SINGBOX_BINARY"
    fi
    
    # 询问是否删除配置文件和日志
    if confirm "是否删除配置文件和日志？"; then
        rm -rf "$WORK_DIR"
        rm -rf "/var/log/sing-box"
        
        # 删除系统优化配置
        rm -f /etc/sysctl.d/99-sing-box.conf
        rm -f /etc/security/limits.d/99-sing-box.conf
    fi
    
    log_success "Sing-box 卸载完成"
}

# 安装 Sing-box
install_singbox() {
    local version="${1:-latest}"
    local force="${2:-false}"
    
    log_info "开始安装 Sing-box..."
    
    # 获取版本号
    if [[ "$version" == "latest" ]]; then
        version=$(get_latest_version)
        if [[ -z "$version" ]]; then
            log_error "无法获取最新版本"
            return 1
        fi
    fi
    
    # 下载和安装
    if ! download_singbox "$version" "$force"; then
        return 1
    fi
    
    # 创建服务文件
    create_systemd_service
    
    log_success "Sing-box 安装完成"
    
    # 显示安装信息
    show_singbox_info
}

# 更新 Sing-box
update_singbox() {
    log_info "检查 Sing-box 更新..."
    
    # 获取最新版本
    local latest_version
    latest_version=$(get_latest_version)
    
    if [[ -z "$latest_version" ]]; then
        log_error "无法获取最新版本信息"
        return 1
    fi
    
    # 获取当前版本
    local current_version
    if [[ -f "$SINGBOX_BINARY" ]]; then
        current_version=$($SINGBOX_BINARY version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    fi
    
    if [[ -z "$current_version" ]]; then
        log_info "未检测到已安装的版本，开始安装最新版本..."
        install_singbox "$latest_version"
        return $?
    fi
    
    log_info "当前版本: $current_version"
    log_info "最新版本: $latest_version"
    
    # 比较版本
    if [[ "$current_version" == "$latest_version" ]]; then
        log_info "已是最新版本，无需更新"
        return 0
    fi
    
    # 确认更新
    if confirm "发现新版本 $latest_version，是否更新？"; then
        install_singbox "$latest_version" true
    else
        log_info "取消更新"
    fi
}