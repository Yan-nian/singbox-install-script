#!/bin/bash

# 服务管理模块
# 负责 Singbox 的系统服务管理

# 服务相关变量
SERVICE_NAME="sing-box"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
SERVICE_USER="sing-box"
SERVICE_GROUP="sing-box"

# 创建系统用户
create_service_user() {
    log_info "创建服务用户..."
    
    # 检查用户是否已存在
    if id "$SERVICE_USER" >/dev/null 2>&1; then
        log_info "用户 $SERVICE_USER 已存在"
        return 0
    fi
    
    # 创建系统用户
    if command_exists useradd; then
        useradd -r -s /bin/false -d /var/lib/sing-box -m "$SERVICE_USER" 2>/dev/null || {
            log_error "创建用户失败"
            return 1
        }
    else
        log_error "useradd 命令不存在"
        return 1
    fi
    
    # 设置目录权限
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$WORK_DIR" 2>/dev/null || true
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$CONFIG_DIR" 2>/dev/null || true
    
    log_success "用户 $SERVICE_USER 创建成功"
    return 0
}

# 创建 systemd 服务文件
create_systemd_service() {
    log_info "创建 systemd 服务文件..."
    
    # 检查 systemd 是否可用
    if ! command_exists systemctl; then
        log_error "systemd 不可用，无法创建服务"
        return 1
    fi
    
    # 创建服务文件
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=$SERVICE_USER
Group=$SERVICE_GROUP
Type=simple
ExecStart=$SINGBOX_BINARY run -c $CONFIG_FILE
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

# 安全设置
NoNewPrivileges=true
SystemCallArchitectures=native
SystemCallFilter=~@clock @debug @module @mount @obsolete @reboot @setuid @swap

# 文件系统保护
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

# 网络保护
RestrictAddressFamilies=AF_INET AF_INET6 AF_NETLINK
RestrictNamespaces=true
LockPersonality=true
MemoryDenyWriteExecute=true
RestrictRealtime=true
RestrictSUIDSGID=true
RemoveIPC=true

# 权限设置
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE

# 工作目录
WorkingDirectory=$WORK_DIR
ReadWritePaths=$WORK_DIR $CONFIG_DIR $SINGBOX_LOG_DIR

[Install]
WantedBy=multi-user.target
EOF
    
    if [[ $? -eq 0 ]]; then
        log_success "systemd 服务文件创建成功"
        
        # 重新加载 systemd
        systemctl daemon-reload
        
        return 0
    else
        log_error "systemd 服务文件创建失败"
        return 1
    fi
}

# 创建 SysV init 脚本 (适用于旧系统)
create_sysv_service() {
    log_info "创建 SysV init 脚本..."
    
    local init_script="/etc/init.d/$SERVICE_NAME"
    
    cat > "$init_script" << 'EOF'
#!/bin/bash
# sing-box        sing-box service
# chkconfig: 35 99 99
# description: sing-box service
#

. /etc/rc.d/init.d/functions

USER="sing-box"
DAEMON="sing-box"
ROOT_DIR="/var/lib/sing-box"

SERVER="$ROOT_DIR/sing-box"
LOCK_FILE="/var/lock/subsys/sing-box"

start() {
    if [ -f $LOCK_FILE ] ; then
        echo "$DAEMON is locked."
        return 1
    fi
    
    echo -n $"Starting $DAEMON: "
    daemon --user "$USER" --pidfile="$LOCK_FILE" \
        "$SERVER" run -c "$ROOT_DIR/config.json" >/dev/null 2>&1 &
    RETVAL=$?
    echo
    [ $RETVAL -eq 0 ] && touch $LOCK_FILE
    return $RETVAL
}

stop() {
    if [ ! -f $LOCK_FILE ] ; then
        echo "$DAEMON is not started."
        return 1
    fi
    
    echo -n $"Shutting down $DAEMON: "
    pid=`ps -aefw | grep "$DAEMON" | grep -v " grep " | awk '{print $2}'`
    kill -9 $pid > /dev/null 2>&1
    [ $? -eq 0 ] && echo_success || echo_failure
    echo
    [ $? -eq 0 ] && rm -f $LOCK_FILE
}

restart() {
    stop
    start
}

status() {
    if [ -f $LOCK_FILE ] ; then
        echo "$DAEMON is running."
    else
        echo "$DAEMON is stopped."
    fi
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    status)
        status
        ;;
    restart)
        restart
        ;;
    *)
        echo "Usage: {start|stop|status|restart}"
        exit 1
        ;;
esac

exit $?
EOF
    
    # 设置执行权限
    chmod +x "$init_script"
    
    # 添加到启动项
    if command_exists chkconfig; then
        chkconfig --add "$SERVICE_NAME"
        chkconfig "$SERVICE_NAME" on
    elif command_exists update-rc.d; then
        update-rc.d "$SERVICE_NAME" defaults
    fi
    
    log_success "SysV init 脚本创建成功"
    return 0
}

# 安装服务
install_service() {
    log_info "安装 Sing-box 服务..."
    
    # 创建服务用户
    create_service_user || return 1
    
    # 创建日志目录
    mkdir -p /var/log/sing-box
    chown "$SERVICE_USER:$SERVICE_GROUP" /var/log/sing-box
    
    # 根据系统类型创建服务
    if command_exists systemctl; then
        create_systemd_service
    else
        create_sysv_service
    fi
    
    return $?
}

# 卸载服务
uninstall_service() {
    log_info "卸载 Sing-box 服务..."
    
    # 停止服务
    stop_singbox
    
    # 禁用服务
    if command_exists systemctl; then
        systemctl disable "$SERVICE_NAME" 2>/dev/null || true
        rm -f "$SERVICE_FILE"
        systemctl daemon-reload
    else
        if command_exists chkconfig; then
            chkconfig "$SERVICE_NAME" off 2>/dev/null || true
            chkconfig --del "$SERVICE_NAME" 2>/dev/null || true
        elif command_exists update-rc.d; then
            update-rc.d -f "$SERVICE_NAME" remove 2>/dev/null || true
        fi
        rm -f "/etc/init.d/$SERVICE_NAME"
    fi
    
    # 删除服务用户
    if id "$SERVICE_USER" >/dev/null 2>&1; then
        userdel "$SERVICE_USER" 2>/dev/null || true
        groupdel "$SERVICE_GROUP" 2>/dev/null || true
    fi
    
    # 删除日志目录
    rm -rf /var/log/sing-box
    
    log_success "服务卸载完成"
    return 0
}

# 启动服务
start_singbox() {
    log_info "启动 Sing-box 服务..."
    
    # 检查配置文件
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "配置文件不存在: $CONFIG_FILE"
        return 1
    fi
    
    # 验证配置文件
    if ! validate_config; then
        log_error "配置文件验证失败"
        return 1
    fi
    
    # 启动服务
    if command_exists systemctl; then
        systemctl start "$SERVICE_NAME"
        local status=$?
        
        if [[ $status -eq 0 ]]; then
            log_success "Sing-box 服务启动成功"
            
            # 等待服务完全启动
            sleep 2
            
            # 检查服务状态
            if systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
                log_success "服务运行正常"
            else
                log_error "服务启动后异常"
                show_singbox_logs 20
                return 1
            fi
        else
            log_error "Sing-box 服务启动失败"
            show_singbox_logs 20
            return 1
        fi
    else
        service "$SERVICE_NAME" start
        local status=$?
        
        if [[ $status -eq 0 ]]; then
            log_success "Sing-box 服务启动成功"
        else
            log_error "Sing-box 服务启动失败"
            return 1
        fi
    fi
    
    return 0
}

# 停止服务
stop_singbox() {
    log_info "停止 Sing-box 服务..."
    
    if command_exists systemctl; then
        systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    else
        service "$SERVICE_NAME" stop 2>/dev/null || true
    fi
    
    # 强制杀死进程
    local pids
    pids=$(pgrep -f "$SINGBOX_BINARY" 2>/dev/null || true)
    
    if [[ -n "$pids" ]]; then
        log_info "强制终止残留进程..."
        echo "$pids" | xargs kill -TERM 2>/dev/null || true
        sleep 2
        
        # 如果还有进程，强制杀死
        pids=$(pgrep -f "$SINGBOX_BINARY" 2>/dev/null || true)
        if [[ -n "$pids" ]]; then
            echo "$pids" | xargs kill -KILL 2>/dev/null || true
        fi
    fi
    
    log_success "Sing-box 服务已停止"
    return 0
}

# 重启服务
restart_singbox() {
    log_info "重启 Sing-box 服务..."
    
    stop_singbox
    sleep 1
    start_singbox
    
    return $?
}

# 重新加载配置
reload_singbox() {
    log_info "重新加载 Sing-box 配置..."
    
    # 验证配置文件
    if ! validate_config; then
        log_error "配置文件验证失败，无法重新加载"
        return 1
    fi
    
    if command_exists systemctl; then
        systemctl reload "$SERVICE_NAME"
        local status=$?
        
        if [[ $status -eq 0 ]]; then
            log_success "配置重新加载成功"
        else
            log_error "配置重新加载失败"
            return 1
        fi
    else
        # 对于 SysV，重启服务
        restart_singbox
        return $?
    fi
    
    return 0
}

# 获取服务状态
get_singbox_status() {
    if command_exists systemctl; then
        if systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
            echo "running"
        elif systemctl is-enabled "$SERVICE_NAME" >/dev/null 2>&1; then
            echo "stopped"
        else
            echo "disabled"
        fi
    else
        # 检查进程是否存在
        if pgrep -f "$SINGBOX_BINARY" >/dev/null 2>&1; then
            echo "running"
        else
            echo "stopped"
        fi
    fi
}

# 检查服务是否运行
is_singbox_running() {
    local status
    status=$(get_singbox_status)
    [[ "$status" == "running" ]]
}

# 启用开机自启
enable_singbox() {
    log_info "启用 Sing-box 开机自启..."
    
    if command_exists systemctl; then
        systemctl enable "$SERVICE_NAME"
        local status=$?
        
        if [[ $status -eq 0 ]]; then
            log_success "开机自启已启用"
        else
            log_error "开机自启启用失败"
            return 1
        fi
    else
        if command_exists chkconfig; then
            chkconfig "$SERVICE_NAME" on
        elif command_exists update-rc.d; then
            update-rc.d "$SERVICE_NAME" enable
        fi
        log_success "开机自启已启用"
    fi
    
    return 0
}

# 禁用开机自启
disable_singbox() {
    log_info "禁用 Sing-box 开机自启..."
    
    if command_exists systemctl; then
        systemctl disable "$SERVICE_NAME"
        local status=$?
        
        if [[ $status -eq 0 ]]; then
            log_success "开机自启已禁用"
        else
            log_error "开机自启禁用失败"
            return 1
        fi
    else
        if command_exists chkconfig; then
            chkconfig "$SERVICE_NAME" off
        elif command_exists update-rc.d; then
            update-rc.d "$SERVICE_NAME" disable
        fi
        log_success "开机自启已禁用"
    fi
    
    return 0
}

# 显示服务信息
show_singbox_info() {
    echo -e "${CYAN}=== Sing-box 服务信息 ===${NC}"
    echo ""
    
    # 基本信息
    if [[ -f "$SINGBOX_BINARY" ]]; then
        local version
        version=$($SINGBOX_BINARY version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        echo -e "${GREEN}版本:${NC} $version"
    else
        echo -e "${RED}Sing-box 未安装${NC}"
        return 1
    fi
    
    echo -e "${GREEN}二进制文件:${NC} $SINGBOX_BINARY"
    echo -e "${GREEN}配置文件:${NC} $CONFIG_FILE"
    echo -e "${GREEN}工作目录:${NC} $WORK_DIR"
    echo ""
    
    # 服务状态
    local status
    status=$(get_singbox_status)
    
    case "$status" in
        running)
            echo -e "${GREEN}服务状态: 运行中${NC}"
            ;;
        stopped)
            echo -e "${YELLOW}服务状态: 已停止${NC}"
            ;;
        disabled)
            echo -e "${RED}服务状态: 未启用${NC}"
            ;;
        *)
            echo -e "${RED}服务状态: 未知${NC}"
            ;;
    esac
    
    # 开机自启状态
    if command_exists systemctl; then
        if systemctl is-enabled "$SERVICE_NAME" >/dev/null 2>&1; then
            echo -e "${GREEN}开机自启: 已启用${NC}"
        else
            echo -e "${YELLOW}开机自启: 已禁用${NC}"
        fi
    fi
    
    echo ""
    
    # 进程信息
    if is_singbox_running; then
        echo -e "${GREEN}进程信息:${NC}"
        ps aux | grep "$SINGBOX_BINARY" | grep -v grep | while read -r line; do
            echo "  $line"
        done
        echo ""
        
        # 端口监听
        echo -e "${GREEN}端口监听:${NC}"
        netstat -tlnp 2>/dev/null | grep "$(pgrep -f "$SINGBOX_BINARY" | head -1)" | while read -r line; do
            echo "  $line"
        done
        echo ""
    fi
    
    # 配置摘要
    if [[ -f "$CONFIG_FILE" ]]; then
        echo -e "${GREEN}配置摘要:${NC}"
        show_config_summary
    fi
}

# 显示服务日志
show_singbox_logs() {
    local lines="${1:-50}"
    
    echo -e "${CYAN}=== Sing-box 服务日志 (最近 $lines 行) ===${NC}"
    echo ""
    
    if command_exists systemctl; then
        journalctl -u "$SERVICE_NAME" -n "$lines" --no-pager
    else
        # 查找日志文件
        local log_files=(
            "/var/log/sing-box/sing-box.log"
            "/var/log/sing-box.log"
            "/var/log/messages"
            "/var/log/syslog"
        )
        
        for log_file in "${log_files[@]}"; do
            if [[ -f "$log_file" ]]; then
                echo "从 $log_file 读取日志:"
                tail -n "$lines" "$log_file" | grep -i sing-box || true
                break
            fi
        done
    fi
    
    echo ""
    echo -e "${YELLOW}按 'q' 退出，按任意键刷新${NC}"
    
    while true; do
        read -n 1 -s key
        case "$key" in
            q|Q)
                break
                ;;
            *)
                clear
                echo -e "${CYAN}=== Sing-box 服务日志 (最近 $lines 行) ===${NC}"
                echo ""
                
                if command_exists systemctl; then
                    journalctl -u "$SERVICE_NAME" -n "$lines" --no-pager
                else
                    for log_file in "${log_files[@]}"; do
                        if [[ -f "$log_file" ]]; then
                            tail -n "$lines" "$log_file" | grep -i sing-box || true
                            break
                        fi
                    done
                fi
                
                echo ""
                echo -e "${YELLOW}按 'q' 退出，按任意键刷新${NC}"
                ;;
        esac
    done
}

# 监控服务状态
monitor_singbox() {
    local interval="${1:-5}"
    
    echo -e "${CYAN}=== Sing-box 服务监控 (每 $interval 秒刷新) ===${NC}"
    echo -e "${YELLOW}按 Ctrl+C 退出监控${NC}"
    echo ""
    
    while true; do
        clear
        echo -e "${CYAN}=== Sing-box 服务监控 ===${NC}"
        echo -e "${YELLOW}刷新时间: $(date)${NC}"
        echo ""
        
        # 显示服务状态
        show_singbox_info
        
        # 显示最近的日志
        echo -e "${CYAN}=== 最近日志 ===${NC}"
        if command_exists systemctl; then
            journalctl -u "$SERVICE_NAME" -n 10 --no-pager --since "1 minute ago"
        fi
        
        echo ""
        echo -e "${YELLOW}下次刷新: $interval 秒后 (按 Ctrl+C 退出)${NC}"
        
        sleep "$interval"
    done
}

# 服务健康检查
health_check() {
    local issues=()
    
    echo -e "${CYAN}=== Sing-box 健康检查 ===${NC}"
    echo ""
    
    # 检查二进制文件
    if [[ ! -f "$SINGBOX_BINARY" ]]; then
        issues+=("Sing-box 二进制文件不存在")
    elif [[ ! -x "$SINGBOX_BINARY" ]]; then
        issues+=("Sing-box 二进制文件无执行权限")
    fi
    
    # 检查配置文件
    if [[ ! -f "$CONFIG_FILE" ]]; then
        issues+=("配置文件不存在")
    elif ! validate_config >/dev/null 2>&1; then
        issues+=("配置文件格式错误")
    fi
    
    # 检查服务状态
    if ! is_singbox_running; then
        issues+=("服务未运行")
    fi
    
    # 检查端口监听
    if is_singbox_running; then
        local listening_ports
        listening_ports=$(netstat -tlnp 2>/dev/null | grep "$(pgrep -f "$SINGBOX_BINARY" | head -1)" | awk '{print $4}' | cut -d: -f2 | sort -u)
        
        if [[ -z "$listening_ports" ]]; then
            issues+=("服务运行但未监听任何端口")
        fi
    fi
    
    # 检查防火墙
    if [[ "$FIREWALL_ACTIVE" == "true" ]]; then
        # 这里可以添加防火墙规则检查
        echo -e "${YELLOW}注意: 防火墙已启用，请确保相关端口已开放${NC}"
    fi
    
    # 显示检查结果
    if [[ ${#issues[@]} -eq 0 ]]; then
        echo -e "${GREEN}✓ 健康检查通过，未发现问题${NC}"
    else
        echo -e "${RED}✗ 发现以下问题:${NC}"
        for issue in "${issues[@]}"; do
            echo -e "  ${RED}- $issue${NC}"
        done
        echo ""
        echo -e "${YELLOW}建议运行相应的修复操作${NC}"
    fi
    
    return ${#issues[@]}
}

# 自动修复常见问题
auto_fix() {
    echo -e "${CYAN}=== 自动修复 ===${NC}"
    echo ""
    
    local fixed=0
    
    # 修复权限问题
    if [[ -f "$SINGBOX_BINARY" ]] && [[ ! -x "$SINGBOX_BINARY" ]]; then
        echo "修复二进制文件权限..."
        chmod +x "$SINGBOX_BINARY"
        ((fixed++))
    fi
    
    # 修复目录权限
    if [[ -d "$WORK_DIR" ]]; then
        echo "修复目录权限..."
        chown -R "$SERVICE_USER:$SERVICE_GROUP" "$WORK_DIR" 2>/dev/null || true
        ((fixed++))
    fi
    
    # 重新创建服务文件
    if [[ ! -f "$SERVICE_FILE" ]] && command_exists systemctl; then
        echo "重新创建服务文件..."
        create_systemd_service
        ((fixed++))
    fi
    
    if [[ $fixed -gt 0 ]]; then
        echo -e "${GREEN}已修复 $fixed 个问题${NC}"
    else
        echo -e "${YELLOW}未发现可自动修复的问题${NC}"
    fi
    
    return 0
}