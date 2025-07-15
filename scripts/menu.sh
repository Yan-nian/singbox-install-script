#!/bin/bash

# 用户交互界面模块
# 提供友好的菜单和交互功能

# 菜单相关变量
MENU_TITLE="Sing-box 一键安装脚本"
MENU_VERSION="v1.0.0"
MENU_WIDTH=60

# 显示主菜单
show_main_menu() {
    clear
    
    # 显示标题
    echo -e "${CYAN}$(printf '%*s' $MENU_WIDTH '' | tr ' ' '=')${NC}"
    echo -e "${CYAN}$(printf '%*s' $(((MENU_WIDTH + ${#MENU_TITLE})/2)) "$MENU_TITLE")${NC}"
    echo -e "${CYAN}$(printf '%*s' $(((MENU_WIDTH + ${#MENU_VERSION})/2)) "$MENU_VERSION")${NC}"
    echo -e "${CYAN}$(printf '%*s' $MENU_WIDTH '' | tr ' ' '=')${NC}"
    echo ""
    
    # 显示系统信息
    if [[ -n "$OS" ]] && [[ -n "$ARCH" ]]; then
        echo -e "${GREEN}系统信息:${NC} $OS $OS_VERSION ($ARCH)"
        if [[ -n "$PUBLIC_IP" ]]; then
            echo -e "${GREEN}公网 IP:${NC} $PUBLIC_IP"
        fi
        echo ""
    fi
    
    # 显示 Sing-box 状态
    if [[ -f "$SINGBOX_BINARY" ]]; then
        local version
        version=$($SINGBOX_BINARY version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        local status
        status=$(get_singbox_status)
        
        case "$status" in
            running)
                echo -e "${GREEN}Sing-box 状态:${NC} v$version (${GREEN}运行中${NC})"
                ;;
            stopped)
                echo -e "${GREEN}Sing-box 状态:${NC} v$version (${YELLOW}已停止${NC})"
                ;;
            *)
                echo -e "${GREEN}Sing-box 状态:${NC} v$version (${RED}未启用${NC})"
                ;;
        esac
    else
        echo -e "${GREEN}Sing-box 状态:${NC} ${RED}未安装${NC}"
    fi
    echo ""
    
    # 显示菜单选项
    echo -e "${YELLOW}请选择操作:${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC} 安装 Sing-box"
    echo -e "  ${GREEN}2.${NC} 配置协议"
    echo -e "  ${GREEN}3.${NC} 管理服务"
    echo -e "  ${GREEN}4.${NC} 查看配置"
    echo -e "  ${GREEN}5.${NC} 系统工具"
    echo -e "  ${GREEN}6.${NC} 卸载 Sing-box"
    echo -e "  ${GREEN}0.${NC} 退出脚本"
    echo ""
    echo -e "${CYAN}$(printf '%*s' $MENU_WIDTH '' | tr ' ' '-')${NC}"
}

# 显示协议配置菜单
show_protocol_menu() {
    clear
    
    echo -e "${CYAN}=== 协议配置菜单 ===${NC}"
    echo ""
    echo -e "${YELLOW}请选择要配置的协议:${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC} VLESS Reality Vision"
    echo -e "  ${GREEN}2.${NC} VMess WebSocket"
    echo -e "  ${GREEN}3.${NC} VMess WebSocket + TLS"
    echo -e "  ${GREEN}4.${NC} Hysteria2"
    echo -e "  ${GREEN}5.${NC} 多协议配置"
    echo -e "  ${GREEN}6.${NC} 自定义配置"
    echo -e "  ${GREEN}0.${NC} 返回主菜单"
    echo ""
    echo -e "${CYAN}$(printf '%*s' 40 '' | tr ' ' '-')${NC}"
}

# 显示服务管理菜单
show_service_menu() {
    clear
    
    echo -e "${CYAN}=== 服务管理菜单 ===${NC}"
    echo ""
    
    # 显示当前状态
    local status
    status=$(get_singbox_status)
    
    case "$status" in
        running)
            echo -e "${GREEN}当前状态: 运行中${NC}"
            ;;
        stopped)
            echo -e "${YELLOW}当前状态: 已停止${NC}"
            ;;
        *)
            echo -e "${RED}当前状态: 未启用${NC}"
            ;;
    esac
    echo ""
    
    echo -e "${YELLOW}请选择操作:${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC} 启动服务"
    echo -e "  ${GREEN}2.${NC} 停止服务"
    echo -e "  ${GREEN}3.${NC} 重启服务"
    echo -e "  ${GREEN}4.${NC} 重新加载配置"
    echo -e "  ${GREEN}5.${NC} 查看服务状态"
    echo -e "  ${GREEN}6.${NC} 查看日志"
    echo -e "  ${GREEN}7.${NC} 启用开机自启"
    echo -e "  ${GREEN}8.${NC} 禁用开机自启"
    echo -e "  ${GREEN}0.${NC} 返回主菜单"
    echo ""
    echo -e "${CYAN}$(printf '%*s' 40 '' | tr ' ' '-')${NC}"
}

# 显示配置查看菜单
show_config_menu() {
    clear
    
    echo -e "${CYAN}=== 配置查看菜单 ===${NC}"
    echo ""
    echo -e "${YELLOW}请选择操作:${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC} 查看配置信息"
    echo -e "  ${GREEN}2.${NC} 查看客户端配置"
    echo -e "  ${GREEN}3.${NC} 生成分享链接"
    echo -e "  ${GREEN}4.${NC} 生成 QR 码"
    echo -e "  ${GREEN}5.${NC} 验证配置文件"
    echo -e "  ${GREEN}6.${NC} 编辑配置文件"
    echo -e "  ${GREEN}7.${NC} 备份配置"
    echo -e "  ${GREEN}8.${NC} 恢复配置"
    echo -e "  ${GREEN}0.${NC} 返回主菜单"
    echo ""
    echo -e "${CYAN}$(printf '%*s' 40 '' | tr ' ' '-')${NC}"
}

# 显示系统工具菜单
show_system_menu() {
    clear
    
    echo -e "${CYAN}=== 系统工具菜单 ===${NC}"
    echo ""
    echo -e "${YELLOW}请选择操作:${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC} 系统信息检查"
    echo -e "  ${GREEN}2.${NC} 网络连通性测试"
    echo -e "  ${GREEN}3.${NC} 端口占用检查"
    echo -e "  ${GREEN}4.${NC} 防火墙配置"
    echo -e "  ${GREEN}5.${NC} 系统优化"
    echo -e "  ${GREEN}6.${NC} 更新脚本"
    echo -e "  ${GREEN}7.${NC} 清理临时文件"
    echo -e "  ${GREEN}8.${NC} 重置所有配置"
    echo -e "  ${GREEN}0.${NC} 返回主菜单"
    echo ""
    echo -e "${CYAN}$(printf '%*s' 40 '' | tr ' ' '-')${NC}"
}

# 多协议选择菜单
show_multi_protocol_menu() {
    clear
    
    echo -e "${CYAN}=== 多协议配置 ===${NC}"
    echo ""
    echo -e "${YELLOW}请选择要启用的协议 (可多选，用空格分隔):${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC} VLESS Reality Vision"
    echo -e "  ${GREEN}2.${NC} VMess WebSocket"
    echo -e "  ${GREEN}3.${NC} VMess WebSocket + TLS"
    echo -e "  ${GREEN}4.${NC} Hysteria2"
    echo ""
    echo -e "${CYAN}示例: 输入 '1 2 4' 启用 VLESS、VMess 和 Hysteria2${NC}"
    echo ""
}

# 获取用户输入
get_user_choice() {
    local prompt="${1:-请输入选择}"
    local choice
    
    echo -n -e "${YELLOW}$prompt: ${NC}"
    read -r choice
    echo "$choice"
}

# 等待用户按键
wait_for_key() {
    local message="${1:-按任意键继续...}"
    
    echo ""
    echo -n -e "${YELLOW}$message${NC}"
    read -n 1 -s
    echo ""
}

# 显示操作结果
show_result() {
    local success="$1"
    local message="$2"
    
    echo ""
    if [[ "$success" == "true" ]]; then
        echo -e "${GREEN}✓ $message${NC}"
    else
        echo -e "${RED}✗ $message${NC}"
    fi
    echo ""
}

# 显示进度条
show_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-处理中}"
    local width=50
    
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r${CYAN}%s [" "$message"
    printf "%*s" $filled '' | tr ' ' '█'
    printf "%*s" $empty '' | tr ' ' '░'
    printf "] %d%%${NC}" $percentage
    
    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# 显示加载动画
show_loading() {
    local message="$1"
    local duration="${2:-3}"
    
    local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local delay=0.1
    local iterations=$((duration * 10))
    
    for ((i=0; i<iterations; i++)); do
        local char_index=$((i % ${#chars}))
        printf "\r${CYAN}%s %s${NC}" "${chars:$char_index:1}" "$message"
        sleep $delay
    done
    
    printf "\r${GREEN}✓ %s${NC}\n" "$message"
}

# 显示协议配置信息
show_protocol_info() {
    local protocol="$1"
    local server_ip="$2"
    
    case "$protocol" in
        vless)
            show_vless_config "$server_ip"
            ;;
        vmess)
            show_vmess_config "$server_ip" false
            ;;
        vmess-tls)
            show_vmess_config "$server_ip" true
            ;;
        hysteria2)
            show_hysteria2_config "$server_ip"
            ;;
    esac
}

# 处理主菜单选择
handle_main_menu() {
    local choice
    choice=$(get_user_choice "请输入选择 (0-6)")
    
    case "$choice" in
        1)
            handle_install_menu
            ;;
        2)
            handle_protocol_menu
            ;;
        3)
            handle_service_menu
            ;;
        4)
            handle_config_menu
            ;;
        5)
            handle_system_menu
            ;;
        6)
            handle_uninstall
            ;;
        0)
            log_info "感谢使用 Sing-box 一键安装脚本！"
            exit 0
            ;;
        *)
            show_result false "无效选择，请重新输入"
            wait_for_key
            ;;
    esac
}

# 处理安装菜单
handle_install_menu() {
    if [[ -f "$SINGBOX_BINARY" ]]; then
        echo -e "${YELLOW}检测到 Sing-box 已安装，是否重新安装？${NC}"
        if ! confirm "确认重新安装"; then
            return
        fi
    fi
    
    show_loading "正在安装 Sing-box" 5
    
    if install_singbox; then
        show_result true "Sing-box 安装成功"
    else
        show_result false "Sing-box 安装失败"
    fi
    
    wait_for_key
}

# 处理协议配置菜单
handle_protocol_menu() {
    while true; do
        show_protocol_menu
        local choice
        choice=$(get_user_choice "请输入选择 (0-6)")
        
        case "$choice" in
            1)
                configure_single_protocol "vless"
                ;;
            2)
                configure_single_protocol "vmess"
                ;;
            3)
                configure_single_protocol "vmess-tls"
                ;;
            4)
                configure_single_protocol "hysteria2"
                ;;
            5)
                configure_multiple_protocols
                ;;
            6)
                edit_config
                wait_for_key
                ;;
            0)
                break
                ;;
            *)
                show_result false "无效选择，请重新输入"
                wait_for_key
                ;;
        esac
    done
}

# 配置单个协议
configure_single_protocol() {
    local protocol="$1"
    
    show_loading "正在配置 $protocol 协议" 3
    
    case "$protocol" in
        vless)
            if configure_vless; then
                generate_config "vless"
                show_result true "VLESS Reality Vision 配置完成"
            else
                show_result false "VLESS Reality Vision 配置失败"
            fi
            ;;
        vmess)
            if configure_vmess false; then
                generate_config "vmess"
                show_result true "VMess WebSocket 配置完成"
            else
                show_result false "VMess WebSocket 配置失败"
            fi
            ;;
        vmess-tls)
            if configure_vmess true; then
                generate_config "vmess-tls"
                show_result true "VMess WebSocket TLS 配置完成"
            else
                show_result false "VMess WebSocket TLS 配置失败"
            fi
            ;;
        hysteria2)
            if configure_hysteria2; then
                generate_config "hysteria2"
                show_result true "Hysteria2 配置完成"
            else
                show_result false "Hysteria2 配置失败"
            fi
            ;;
    esac
    
    wait_for_key
}

# 配置多个协议
configure_multiple_protocols() {
    show_multi_protocol_menu
    
    local choices
    choices=$(get_user_choice "请输入协议编号")
    
    if [[ -z "$choices" ]]; then
        show_result false "未选择任何协议"
        wait_for_key
        return
    fi
    
    local protocols=()
    
    for choice in $choices; do
        case "$choice" in
            1)
                protocols+=("vless")
                ;;
            2)
                protocols+=("vmess")
                ;;
            3)
                protocols+=("vmess-tls")
                ;;
            4)
                protocols+=("hysteria2")
                ;;
            *)
                show_result false "无效选择: $choice"
                wait_for_key
                return
                ;;
        esac
    done
    
    if [[ ${#protocols[@]} -eq 0 ]]; then
        show_result false "未选择有效协议"
        wait_for_key
        return
    fi
    
    show_loading "正在配置多协议" 5
    
    # 配置各个协议
    local success=true
    
    for protocol in "${protocols[@]}"; do
        case "$protocol" in
            vless)
                configure_vless || success=false
                ;;
            vmess)
                configure_vmess false || success=false
                ;;
            vmess-tls)
                configure_vmess true || success=false
                ;;
            hysteria2)
                configure_hysteria2 || success=false
                ;;
        esac
    done
    
    if [[ "$success" == "true" ]]; then
        generate_config "${protocols[@]}"
        show_result true "多协议配置完成"
    else
        show_result false "多协议配置失败"
    fi
    
    wait_for_key
}

# 处理服务管理菜单
handle_service_menu() {
    while true; do
        show_service_menu
        local choice
        choice=$(get_user_choice "请输入选择 (0-8)")
        
        case "$choice" in
            1)
                if start_singbox; then
                    show_result true "服务启动成功"
                else
                    show_result false "服务启动失败"
                fi
                wait_for_key
                ;;
            2)
                stop_singbox
                show_result true "服务已停止"
                wait_for_key
                ;;
            3)
                if restart_singbox; then
                    show_result true "服务重启成功"
                else
                    show_result false "服务重启失败"
                fi
                wait_for_key
                ;;
            4)
                if reload_singbox; then
                    show_result true "配置重新加载成功"
                else
                    show_result false "配置重新加载失败"
                fi
                wait_for_key
                ;;
            5)
                show_singbox_info
                wait_for_key
                ;;
            6)
                show_singbox_logs
                ;;
            7)
                systemctl enable sing-box
                show_result true "开机自启已启用"
                wait_for_key
                ;;
            8)
                systemctl disable sing-box
                show_result true "开机自启已禁用"
                wait_for_key
                ;;
            0)
                break
                ;;
            *)
                show_result false "无效选择，请重新输入"
                wait_for_key
                ;;
        esac
    done
}

# 处理配置查看菜单
handle_config_menu() {
    while true; do
        show_config_menu
        local choice
        choice=$(get_user_choice "请输入选择 (0-8)")
        
        case "$choice" in
            1)
                show_config_info
                wait_for_key
                ;;
            2)
                # 显示客户端配置文件列表
                echo -e "${CYAN}=== 客户端配置文件 ===${NC}"
                ls -la "$WORK_DIR"/*-client.json 2>/dev/null || echo "未找到客户端配置文件"
                wait_for_key
                ;;
            3)
                # 生成分享链接
                generate_share_links
                wait_for_key
                ;;
            4)
                # 生成 QR 码
                generate_qr_codes
                wait_for_key
                ;;
            5)
                if validate_config; then
                    show_result true "配置文件验证通过"
                else
                    show_result false "配置文件验证失败"
                fi
                wait_for_key
                ;;
            6)
                edit_config
                wait_for_key
                ;;
            7)
                if backup_config; then
                    show_result true "配置备份成功"
                else
                    show_result false "配置备份失败"
                fi
                wait_for_key
                ;;
            8)
                restore_config
                wait_for_key
                ;;
            0)
                break
                ;;
            *)
                show_result false "无效选择，请重新输入"
                wait_for_key
                ;;
        esac
    done
}

# 处理系统工具菜单
handle_system_menu() {
    while true; do
        show_system_menu
        local choice
        choice=$(get_user_choice "请输入选择 (0-8)")
        
        case "$choice" in
            1)
                show_system_summary
                wait_for_key
                ;;
            2)
                test_network_connectivity
                wait_for_key
                ;;
            3)
                check_port_usage
                wait_for_key
                ;;
            4)
                configure_firewall_interactive
                wait_for_key
                ;;
            5)
                optimize_system
                show_result true "系统优化完成"
                wait_for_key
                ;;
            6)
                update_script
                wait_for_key
                ;;
            7)
                cleanup_temp_files
                show_result true "临时文件清理完成"
                wait_for_key
                ;;
            8)
                if confirm "确认重置所有配置？此操作不可恢复！"; then
                    reset_all_config
                    show_result true "配置重置完成"
                else
                    show_result false "操作已取消"
                fi
                wait_for_key
                ;;
            0)
                break
                ;;
            *)
                show_result false "无效选择，请重新输入"
                wait_for_key
                ;;
        esac
    done
}

# 处理卸载
handle_uninstall() {
    echo -e "${RED}警告: 此操作将完全卸载 Sing-box 及其配置文件！${NC}"
    echo ""
    
    if confirm "确认卸载 Sing-box"; then
        show_loading "正在卸载 Sing-box" 3
        
        if uninstall_singbox; then
            show_result true "Sing-box 卸载完成"
        else
            show_result false "Sing-box 卸载失败"
        fi
    else
        show_result false "操作已取消"
    fi
    
    wait_for_key
}

# 主菜单循环
menu_loop() {
    while true; do
        show_main_menu
        handle_main_menu
    done
}

# 一些辅助函数
test_network_connectivity() {
    echo -e "${CYAN}=== 网络连通性测试 ===${NC}"
    echo ""
    
    local test_hosts=("8.8.8.8" "1.1.1.1" "223.5.5.5" "github.com")
    
    for host in "${test_hosts[@]}"; do
        echo -n "测试 $host ... "
        if ping -c 1 -W 3 "$host" >/dev/null 2>&1; then
            echo -e "${GREEN}成功${NC}"
        else
            echo -e "${RED}失败${NC}"
        fi
    done
}

check_port_usage() {
    echo -e "${CYAN}=== 端口占用检查 ===${NC}"
    echo ""
    
    local common_ports=(22 53 80 443 8080 8443)
    
    for port in "${common_ports[@]}"; do
        echo -n "端口 $port ... "
        if check_port "$port"; then
            echo -e "${RED}已占用${NC}"
        else
            echo -e "${GREEN}可用${NC}"
        fi
    done
}

generate_share_links() {
    echo -e "${CYAN}=== 分享链接 ===${NC}"
    echo ""
    
    local server_ip
    server_ip=$(get_public_ip)
    
    if [[ -n "$VLESS_UUID" ]]; then
        echo -e "${GREEN}VLESS Reality Vision:${NC}"
        generate_vless_share_link "$server_ip"
        echo ""
    fi
    
    if [[ -n "$VMESS_UUID" ]]; then
        echo -e "${GREEN}VMess WebSocket:${NC}"
        generate_vmess_share_link "$server_ip" false
        echo ""
    fi
    
    if [[ -n "$HY2_PASSWORD" ]]; then
        echo -e "${GREEN}Hysteria2:${NC}"
        generate_hysteria2_share_link "$server_ip"
        echo ""
    fi
}

generate_qr_codes() {
    echo -e "${CYAN}=== 生成 QR 码 ===${NC}"
    echo ""
    
    local server_ip
    server_ip=$(get_public_ip)
    
    if command_exists qrencode; then
        if [[ -n "$VLESS_UUID" ]]; then
            generate_vless_qr_code "$server_ip"
        fi
        
        if [[ -n "$VMESS_UUID" ]]; then
            generate_vmess_qr_code "$server_ip" false
        fi
        
        if [[ -n "$HY2_PASSWORD" ]]; then
            generate_hysteria2_qr_code "$server_ip"
        fi
        
        echo "QR 码已生成到 $WORK_DIR 目录"
    else
        echo "qrencode 未安装，无法生成 QR 码"
        echo "请运行: apt install qrencode (Debian/Ubuntu) 或 yum install qrencode (CentOS/RHEL)"
    fi
}

configure_firewall_interactive() {
    echo -e "${CYAN}=== 防火墙配置 ===${NC}"
    echo ""
    
    if [[ "$FIREWALL_ACTIVE" != "true" ]]; then
        echo "防火墙未激活，无需配置"
        return
    fi
    
    echo "当前防火墙类型: $FIREWALL_TYPE"
    echo ""
    
    if confirm "是否自动配置防火墙规则"; then
        # 配置常用端口
        local ports=("$VLESS_PORT" "$VMESS_PORT" "$VMESS_TLS_PORT" "$HY2_PORT")
        
        for port in "${ports[@]}"; do
            if [[ -n "$port" ]] && [[ "$port" != "0" ]]; then
                echo "开放端口 $port ..."
                
                case "$FIREWALL_TYPE" in
                    ufw)
                        ufw allow "$port" >/dev/null 2>&1
                        ;;
                    firewalld)
                        firewall-cmd --permanent --add-port="$port"/tcp >/dev/null 2>&1
                        firewall-cmd --permanent --add-port="$port"/udp >/dev/null 2>&1
                        ;;
                    iptables)
                        iptables -A INPUT -p tcp --dport "$port" -j ACCEPT >/dev/null 2>&1
                        iptables -A INPUT -p udp --dport "$port" -j ACCEPT >/dev/null 2>&1
                        ;;
                esac
            fi
        done
        
        if [[ "$FIREWALL_TYPE" == "firewalld" ]]; then
            firewall-cmd --reload >/dev/null 2>&1
        fi
        
        echo "防火墙规则配置完成"
    fi
}

update_script() {
    echo -e "${CYAN}=== 更新脚本 ===${NC}"
    echo ""
    echo "当前版本: $MENU_VERSION"
    echo ""
    echo "检查更新功能暂未实现"
    echo "请访问项目主页获取最新版本"
}

cleanup_temp_files() {
    echo -e "${CYAN}=== 清理临时文件 ===${NC}"
    echo ""
    
    # 清理临时文件
    cleanup_temp
    
    # 清理日志文件 (保留最近 7 天)
    if [[ -d "/var/log/sing-box" ]]; then
        find /var/log/sing-box -name "*.log" -mtime +7 -delete 2>/dev/null || true
    fi
    
    # 清理旧的备份文件 (保留最近 10 个)
    if [[ -d "$CONFIG_BACKUP_DIR" ]]; then
        ls -1t "$CONFIG_BACKUP_DIR"/config_*.json 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
    fi
}

reset_all_config() {
    echo -e "${CYAN}=== 重置所有配置 ===${NC}"
    echo ""
    
    # 停止服务
    stop_singbox
    
    # 删除配置文件
    rm -rf "$WORK_DIR/config" 2>/dev/null || true
    rm -rf "$WORK_DIR/certs" 2>/dev/null || true
    
    # 重置变量
    VLESS_UUID=""
    VMESS_UUID=""
    HY2_PASSWORD=""
    
    # 重新创建目录
    create_directories
}