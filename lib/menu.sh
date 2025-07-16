#!/bin/bash

# 菜单模块
# 提供简洁的用户交互界面

# 显示主菜单
show_main_menu() {
    while true; do
        clear
        echo -e "${CYAN}================================================================${NC}"
        echo -e "${CYAN}                    Sing-box 管理面板${NC}"
        echo -e "${CYAN}================================================================${NC}"
        echo ""
        
        # 显示系统信息
        echo -e "${GREEN}系统信息:${NC} $OS ($ARCH)"
        echo -e "${GREEN}公网IP:${NC} $PUBLIC_IP"
        
        # 显示服务状态
        local status=$(get_service_status "$SERVICE_NAME")
        case "$status" in
            "running")
                echo -e "${GREEN}服务状态:${NC} ${GREEN}运行中${NC}"
                ;;
            "stopped")
                echo -e "${GREEN}服务状态:${NC} ${YELLOW}已停止${NC}"
                ;;
            *)
                echo -e "${GREEN}服务状态:${NC} ${RED}未启用${NC}"
                ;;
        esac
        
        # 显示配置状态
        echo -e "${GREEN}配置状态:${NC}"
        local status_line=""
        [[ -n "$VLESS_PORT" ]] && status_line+="VLESS(${VLESS_PORT}) "
        [[ -n "$VMESS_PORT" ]] && status_line+="VMess(${VMESS_PORT}) "
        [[ -n "$HY2_PORT" ]] && status_line+="Hysteria2(${HY2_PORT}) "
        
        if [[ -n "$status_line" ]]; then
            echo -e "${GREEN}已配置:${NC} $status_line"
        else
            echo -e "${YELLOW}未配置任何协议${NC}"
        fi
        echo ""
        
        # 菜单选项
        echo -e "${YELLOW}请选择操作:${NC}"
        echo ""
        echo -e "  ${GREEN}1.${NC} 配置协议"
        echo -e "  ${GREEN}2.${NC} 管理服务"
        echo -e "  ${GREEN}3.${NC} 查看配置"
        echo -e "  ${GREEN}4.${NC} 生成分享"
        echo -e "  ${GREEN}5.${NC} 端口管理"
        echo -e "  ${GREEN}6.${NC} 系统工具"
        echo -e "  ${GREEN}0.${NC} 退出"
        echo ""
        echo -e "${CYAN}================================================================${NC}"
        
        local choice
        echo -n -e "${YELLOW}请输入选择 [0-6]: ${NC}"
        read -r choice
        
        case "$choice" in
            1) show_protocol_menu ;;
            2) show_service_menu ;;
            3) show_config_menu ;;
            4) show_share_menu ;;
            5) show_port_menu ;;
            6) show_system_menu ;;
            0) 
                echo -e "${GREEN}感谢使用！${NC}"
                exit 0
                ;;
            *) 
                echo -e "${RED}无效选择，请重新输入${NC}"
                wait_for_input
                ;;
        esac
    done
}

# 协议配置菜单
show_protocol_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== 协议配置菜单 ===${NC}"
        echo ""
        echo -e "${YELLOW}请选择要配置的协议:${NC}"
        echo ""
        echo -e "  ${GREEN}1.${NC} VLESS Reality Vision"
        echo -e "  ${GREEN}2.${NC} VMess WebSocket"
        echo -e "  ${GREEN}3.${NC} Hysteria2"
        echo -e "  ${GREEN}4.${NC} 多协议配置"
        echo -e "  ${GREEN}0.${NC} 返回主菜单"
        echo ""
        
        local choice
        echo -n -e "${YELLOW}请输入选择 [0-4]: ${NC}"
        read -r choice
        
        case "$choice" in
            1)
                configure_single_protocol "vless"
                ;;
            2)
                configure_single_protocol "vmess"
                ;;
            3)
                configure_single_protocol "hysteria2"
                ;;
            4)
                configure_multi_protocol
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                wait_for_input
                ;;
        esac
    done
}

# 服务管理菜单
show_service_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== 服务管理菜单 ===${NC}"
        echo ""
        
        local status=$(get_service_status "$SERVICE_NAME")
        echo -e "${GREEN}当前状态:${NC} "
        case "$status" in
            "running") echo -e "${GREEN}运行中${NC}" ;;
            "stopped") echo -e "${YELLOW}已停止${NC}" ;;
            *) echo -e "${RED}未启用${NC}" ;;
        esac
        echo ""
        
        echo -e "${YELLOW}请选择操作:${NC}"
        echo ""
        echo -e "  ${GREEN}1.${NC} 启动服务"
        echo -e "  ${GREEN}2.${NC} 停止服务"
        echo -e "  ${GREEN}3.${NC} 重启服务"
        echo -e "  ${GREEN}4.${NC} 查看日志"
        echo -e "  ${GREEN}5.${NC} 开机自启"
        echo -e "  ${GREEN}0.${NC} 返回主菜单"
        echo ""
        
        local choice
        echo -n -e "${YELLOW}请输入选择 [0-5]: ${NC}"
        read -r choice
        
        case "$choice" in
            1)
                start_service "$SERVICE_NAME"
                wait_for_input
                ;;
            2)
                stop_service "$SERVICE_NAME"
                wait_for_input
                ;;
            3)
                restart_service "$SERVICE_NAME"
                wait_for_input
                ;;
            4)
                show_service_logs
                ;;
            5)
                toggle_auto_start
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                wait_for_input
                ;;
        esac
    done
}

# 配置查看菜单
show_config_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== 配置查看菜单 ===${NC}"
        echo ""
        echo -e "${YELLOW}请选择操作:${NC}"
        echo ""
        echo -e "  ${GREEN}1.${NC} 查看配置信息"
        echo -e "  ${GREEN}2.${NC} 验证配置文件"
        echo -e "  ${GREEN}3.${NC} 编辑配置文件"
        echo -e "  ${GREEN}4.${NC} 备份配置"
        echo -e "  ${GREEN}0.${NC} 返回主菜单"
        echo ""
        
        local choice
        echo -n -e "${YELLOW}请输入选择 [0-4]: ${NC}"
        read -r choice
        
        case "$choice" in
            1)
                show_current_config
                ;;
            2)
                validate_current_config
                ;;
            3)
                edit_config_file
                ;;
            4)
                backup_current_config
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                wait_for_input
                ;;
        esac
    done
}

# 分享菜单
show_share_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== 分享链接菜单 ===${NC}"
        echo ""
        echo -e "${YELLOW}请选择操作:${NC}"
        echo ""
        echo -e "  ${GREEN}1.${NC} 生成分享链接"
        echo -e "  ${GREEN}2.${NC} 生成 QR 码"
        echo -e "  ${GREEN}3.${NC} 生成客户端配置"
        echo -e "  ${GREEN}4.${NC} 生成订阅链接"
        echo -e "  ${GREEN}0.${NC} 返回主菜单"
        echo ""
        
        local choice
        echo -n -e "${YELLOW}请输入选择 [0-4]: ${NC}"
        read -r choice
        
        case "$choice" in
            1)
                generate_share_links
                ;;
            2)
                generate_qr_codes
                ;;
            3)
                generate_client_configs
                ;;
            4)
                generate_subscription
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                wait_for_input
                ;;
        esac
    done
}

# 系统工具菜单
show_system_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== 系统工具菜单 ===${NC}"
        echo ""
        echo -e "${YELLOW}请选择操作:${NC}"
        echo ""
        echo -e "  ${GREEN}1.${NC} 系统信息"
        echo -e "  ${GREEN}2.${NC} 网络测试"
        echo -e "  ${GREEN}3.${NC} 端口检查"
        echo -e "  ${GREEN}4.${NC} 防火墙配置"
        echo -e "  ${GREEN}5.${NC} 清理临时文件"
        echo -e "  ${GREEN}6.${NC} 卸载 Sing-box"
        echo -e "  ${GREEN}0.${NC} 返回主菜单"
        echo ""
        
        local choice
        echo -n -e "${YELLOW}请输入选择 [0-6]: ${NC}"
        read -r choice
        
        case "$choice" in
            1)
                show_system_info
                ;;
            2)
                test_network_connectivity
                ;;
            3)
                check_port_usage
                ;;
            4)
                configure_firewall
                ;;
            5)
                cleanup_temp
                wait_for_input
                ;;
            6)
                uninstall_singbox
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                wait_for_input
                ;;
        esac
    done
}

# 配置单个协议
configure_single_protocol() {
    local protocol="$1"
    
    echo -e "${CYAN}正在配置 $protocol 协议...${NC}"
    
    if generate_config "$protocol"; then
        echo -e "${GREEN}配置生成成功！${NC}"
        
        # 显示配置信息
        case "$protocol" in
            "vless") show_protocol_info "VLESS Reality" ;;
            "vmess") show_protocol_info "VMess WebSocket" ;;
            "hysteria2") show_protocol_info "Hysteria2" ;;
        esac
        
        # 询问是否启动服务
             echo ""
             if confirm_action "是否立即启动服务?"; then
                 restart_service "$SERVICE_NAME"
             fi
         else
             echo -e "${RED}多协议配置生成失败！${NC}"
         fi
     else
         echo -e "${YELLOW}已取消多协议配置${NC}"
     fi
     
     wait_for_input
    else
        echo -e "${RED}配置生成失败！${NC}"
    fi
    
    wait_for_input
}

# 配置多协议
configure_multi_protocol() {
    echo -e "${CYAN}=== 多协议配置 ===${NC}"
    echo ""
    echo -e "${YELLOW}将自动配置以下三种协议:${NC}"
    echo ""
    echo -e "  ${GREEN}•${NC} VLESS Reality Vision"
    echo -e "  ${GREEN}•${NC} VMess WebSocket"
    echo -e "  ${GREEN}•${NC} Hysteria2"
    echo ""
    
    if confirm_action "是否继续配置多协议?"; then
        local protocols=("vless" "vmess" "hysteria2")
        
        echo -e "${CYAN}正在配置多协议...${NC}"
        
        if generate_config "${protocols[@]}"; then
            echo -e "${GREEN}多协议配置生成成功！${NC}"
            
            # 显示所有协议信息
            for protocol in "${protocols[@]}"; do
                case "$protocol" in
                    "vless") show_protocol_info "VLESS Reality" ;;
                    "vmess") show_protocol_info "VMess WebSocket" ;;
                    "hysteria2") show_protocol_info "Hysteria2" ;;
                esac
            done
            
            # 询问是否启动服务
            echo ""
            if confirm_action "是否立即启动服务?"; then
            restart_service "$SERVICE_NAME"
        fi
    else
        echo -e "${RED}多协议配置生成失败！${NC}"
    fi
    
    wait_for_input
}

# 显示当前配置
show_current_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}配置文件不存在${NC}"
        wait_for_input
        return
    fi
    
    echo -e "${CYAN}=== 当前配置信息 ===${NC}"
    echo ""
    
    # 解析配置文件显示协议信息
    if command_exists jq; then
        local inbounds
        inbounds=$(jq -r '.inbounds[].type' "$CONFIG_FILE" 2>/dev/null)
        
        if [[ -n "$inbounds" ]]; then
            echo -e "${GREEN}已配置的协议:${NC}"
            echo "$inbounds" | while read -r protocol; do
                echo -e "  • $protocol"
            done
        fi
    else
        echo -e "${YELLOW}配置文件路径:${NC} $CONFIG_FILE"
        echo -e "${YELLOW}文件大小:${NC} $(du -h "$CONFIG_FILE" | cut -f1)"
    fi
    
    echo ""
    wait_for_input
}

# 验证配置文件
validate_current_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}配置文件不存在${NC}"
        wait_for_input
        return
    fi
    
    echo -e "${CYAN}正在验证配置文件...${NC}"
    
    if validate_json "$CONFIG_FILE"; then
        echo -e "${GREEN}配置文件格式正确${NC}"
    else
        echo -e "${RED}配置文件格式错误${NC}"
    fi
    
    wait_for_input
}

# 编辑配置文件
edit_config_file() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}配置文件不存在${NC}"
        wait_for_input
        return
    fi
    
    # 备份配置文件
    backup_file "$CONFIG_FILE"
    
    # 选择编辑器
    local editor="nano"
    if command_exists vim; then
        editor="vim"
    elif command_exists vi; then
        editor="vi"
    fi
    
    echo -e "${CYAN}使用 $editor 编辑配置文件...${NC}"
    "$editor" "$CONFIG_FILE"
    
    # 验证编辑后的配置
    if validate_json "$CONFIG_FILE"; then
        echo -e "${GREEN}配置文件编辑完成${NC}"
        if confirm_action "是否重启服务以应用新配置?"; then
            restart_service "$SERVICE_NAME"
        fi
    else
        echo -e "${RED}配置文件格式错误，是否恢复备份?${NC}"
        if confirm_action; then
            # 恢复最新备份
            local backup_file
            backup_file=$(ls -t "$WORK_DIR/backup/"*.bak 2>/dev/null | head -1)
            if [[ -n "$backup_file" ]]; then
                cp "$backup_file" "$CONFIG_FILE"
                echo -e "${GREEN}配置文件已恢复${NC}"
            fi
        fi
    fi
    
    wait_for_input
}

# 备份当前配置
backup_current_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}配置文件不存在${NC}"
        wait_for_input
        return
    fi
    
    if backup_file "$CONFIG_FILE"; then
        echo -e "${GREEN}配置备份成功${NC}"
    else
        echo -e "${RED}配置备份失败${NC}"
    fi
    
    wait_for_input
}

# 显示服务日志
show_service_logs() {
    echo -e "${CYAN}=== 服务日志 (最近50行) ===${NC}"
    echo ""
    
    if [[ -f "$LOG_FILE" ]]; then
        tail -50 "$LOG_FILE"
    else
        journalctl -u "$SERVICE_NAME" -n 50 --no-pager
    fi
    
    echo ""
    wait_for_input
}

# 切换开机自启
toggle_auto_start() {
    local status
    status=$(systemctl is-enabled "$SERVICE_NAME" 2>/dev/null || echo "disabled")
    
    if [[ "$status" == "enabled" ]]; then
        if confirm_action "当前已启用开机自启，是否禁用?"; then
            disable_service "$SERVICE_NAME"
        fi
    else
        if confirm_action "当前未启用开机自启，是否启用?"; then
            enable_service "$SERVICE_NAME"
        fi
    fi
    
    wait_for_input
}

# 显示系统信息
show_system_info() {
    echo -e "${CYAN}=== 系统信息 ===${NC}"
    echo ""
    echo -e "${GREEN}操作系统:${NC} $OS"
    echo -e "${GREEN}架构:${NC} $ARCH"
    echo -e "${GREEN}公网IP:${NC} $PUBLIC_IP"
    echo -e "${GREEN}内核版本:${NC} $(uname -r)"
    echo -e "${GREEN}内存使用:${NC} $(free -h | awk 'NR==2{printf "%.1f/%.1f GB (%.1f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}')"
    echo -e "${GREEN}磁盘使用:${NC} $(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}')"
    echo ""
    wait_for_input
}

# 测试网络连通性
test_network_connectivity() {
    echo -e "${CYAN}=== 网络连通性测试 ===${NC}"
    echo ""
    
    local test_hosts=("8.8.8.8" "1.1.1.1" "google.com" "github.com")
    
    for host in "${test_hosts[@]}"; do
        echo -n -e "测试 ${GREEN}$host${NC}: "
        if check_network "$host" 3; then
            echo -e "${GREEN}✓ 连通${NC}"
        else
            echo -e "${RED}✗ 失败${NC}"
        fi
    done
    
    echo ""
    wait_for_input
}

# 检查端口使用情况
check_port_usage() {
    echo -e "${CYAN}=== 端口使用情况 ===${NC}"
    echo ""
    
    local common_ports=("22" "80" "443" "8080" "8443")
    
    for port in "${common_ports[@]}"; do
        echo -n -e "端口 ${GREEN}$port${NC}: "
        if check_port "$port"; then
            echo -e "${RED}已占用${NC}"
        else
            echo -e "${GREEN}可用${NC}"
        fi
    done
    
    echo ""
    wait_for_input
}

# 配置防火墙
configure_firewall() {
    echo -e "${CYAN}=== 防火墙配置 ===${NC}"
    echo ""
    
    # 检查防火墙状态
    if command_exists ufw; then
        echo -e "${GREEN}防火墙类型:${NC} UFW"
        echo -e "${GREEN}状态:${NC} $(ufw status | head -1)"
    elif command_exists firewall-cmd; then
        echo -e "${GREEN}防火墙类型:${NC} Firewalld"
        echo -e "${GREEN}状态:${NC} $(firewall-cmd --state 2>/dev/null || echo "未运行")"
    else
        echo -e "${YELLOW}未检测到支持的防火墙${NC}"
        wait_for_input
        return
    fi
    
    echo ""
    if confirm_action "是否自动配置防火墙规则?"; then
        configure_firewall_rules
    fi
    
    wait_for_input
}

# 配置防火墙规则
configure_firewall_rules() {
    local ports=()
    
    # 收集需要开放的端口
    [[ -n "$VLESS_PORT" ]] && ports+=("$VLESS_PORT")
    [[ -n "$VMESS_PORT" ]] && ports+=("$VMESS_PORT")
    [[ -n "$HY2_PORT" ]] && ports+=("$HY2_PORT")
    
    if [[ ${#ports[@]} -eq 0 ]]; then
        echo -e "${YELLOW}未找到需要开放的端口${NC}"
        return
    fi
    
    echo -e "${CYAN}正在配置防火墙规则...${NC}"
    
    for port in "${ports[@]}"; do
        if command_exists ufw; then
            ufw allow "$port" >/dev/null 2>&1
        elif command_exists firewall-cmd; then
            firewall-cmd --permanent --add-port="$port/tcp" >/dev/null 2>&1
            firewall-cmd --permanent --add-port="$port/udp" >/dev/null 2>&1
        fi
        echo -e "${GREEN}已开放端口: $port${NC}"
    done
    
    # 重新加载防火墙
    if command_exists firewall-cmd; then
        firewall-cmd --reload >/dev/null 2>&1
    fi
    
    echo -e "${GREEN}防火墙配置完成${NC}"
}

# 卸载 Sing-box
uninstall_singbox() {
    echo -e "${RED}=== 卸载 Sing-box ===${NC}"
    echo ""
    echo -e "${YELLOW}警告: 此操作将完全删除 Sing-box 及其所有配置文件${NC}"
    echo ""
    
    if ! confirm_action "确认卸载 Sing-box?"; then
        return
    fi
    
    echo -e "${CYAN}正在卸载 Sing-box...${NC}"
    
    # 停止并禁用服务
    stop_service "$SERVICE_NAME"
    disable_service "$SERVICE_NAME"
    
    # 删除服务文件
    rm -f "/etc/systemd/system/$SERVICE_NAME.service"
    systemctl daemon-reload
    
    # 删除二进制文件
    rm -f "$SINGBOX_BINARY"
    
    # 删除工作目录
    if confirm_action "是否删除所有配置文件和数据?"; then
        rm -rf "$WORK_DIR"
    fi
    
    echo -e "${GREEN}Sing-box 卸载完成${NC}"
    echo -e "${YELLOW}感谢使用！${NC}"
    
    wait_for_input
    exit 0
}

# 显示端口管理菜单
show_port_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== 端口管理 ===${NC}"
        echo ""
        echo -e "  ${GREEN}1.${NC} 查看当前端口"
        echo -e "  ${GREEN}2.${NC} 切换协议端口"
        echo -e "  ${GREEN}3.${NC} 批量重新分配端口"
        echo -e "  ${GREEN}4.${NC} 端口连通性测试"
        echo -e "  ${GREEN}0.${NC} 返回主菜单"
        echo ""
        
        local choice
        echo -n -e "${YELLOW}请输入选择 [0-4]: ${NC}"
        read -r choice
        
        case "$choice" in
            1) show_current_ports ;;
            2) change_protocol_port ;;
            3) reassign_all_ports ;;
            4) test_port_connectivity ;;
            0) break ;;
            *) echo -e "${RED}无效选择，请重新输入${NC}" && sleep 1 ;;
        esac
    done
}

# 查看当前端口
show_current_ports() {
    echo -e "${CYAN}=== 当前端口配置 ===${NC}"
    echo ""
    
    # 加载配置
    load_config
    
    echo -e "${GREEN}VLESS Reality:${NC} ${VLESS_PORT:-未配置}"
    echo -e "${GREEN}VMess WebSocket:${NC} ${VMESS_PORT:-未配置}"
    echo -e "${GREEN}Hysteria2:${NC} ${HY2_PORT:-未配置}"
    echo ""
    
    # 检查端口状态
    local ports=("$VLESS_PORT" "$VMESS_PORT" "$HY2_PORT")
    local names=("VLESS" "VMess" "Hysteria2")
    
    echo -e "${CYAN}端口状态检查:${NC}"
    for i in "${!ports[@]}"; do
        local port="${ports[$i]}"
        local name="${names[$i]}"
        
        if [[ -n "$port" ]]; then
            echo -n -e "${name} (${port}): "
            if check_port "$port"; then
                echo -e "${GREEN}正在使用${NC}"
            else
                echo -e "${YELLOW}未使用${NC}"
            fi
        fi
    done
    
    echo ""
    wait_for_input
}

# 切换协议端口
change_protocol_port() {
    echo -e "${CYAN}=== 切换协议端口 ===${NC}"
    echo ""
    
    echo -e "  ${GREEN}1.${NC} VLESS Reality"
    echo -e "  ${GREEN}2.${NC} VMess WebSocket"
    echo -e "  ${GREEN}3.${NC} Hysteria2"
    echo -e "  ${GREEN}0.${NC} 返回"
    echo ""
    
    local choice
    echo -n -e "${YELLOW}请选择要修改的协议 [0-3]: ${NC}"
    read -r choice
    
    case "$choice" in
        1) change_single_port "VLESS" "VLESS_PORT" ;;
        2) change_single_port "VMess" "VMESS_PORT" ;;
        3) change_single_port "Hysteria2" "HY2_PORT" ;;
        0) return ;;
        *) echo -e "${RED}无效选择${NC}" && sleep 1 && return ;;
    esac
}

# 修改单个协议端口
change_single_port() {
    local protocol_name="$1"
    local port_var="$2"
    
    # 加载当前配置
    load_config
    
    local current_port
    eval "current_port=\$$port_var"
    
    echo -e "${CYAN}=== 修改 $protocol_name 端口 ===${NC}"
    echo ""
    echo -e "${GREEN}当前端口:${NC} ${current_port:-未配置}"
    echo ""
    
    echo -e "  ${GREEN}1.${NC} 使用随机端口 (10000-65535)"
    echo -e "  ${GREEN}2.${NC} 手动输入端口"
    echo -e "  ${GREEN}0.${NC} 返回"
    echo ""
    
    local choice
    echo -n -e "${YELLOW}请选择 [0-2]: ${NC}"
    read -r choice
    
    local new_port
    case "$choice" in
        1)
            new_port=$(get_random_port)
            echo -e "${GREEN}生成随机端口: $new_port${NC}"
            ;;
        2)
            echo -n -e "${YELLOW}请输入新端口 (1-65535): ${NC}"
            read -r new_port
            
            if ! validate_port "$new_port"; then
                echo -e "${RED}端口格式无效${NC}"
                sleep 2
                return
            fi
            
            if [[ "$new_port" -lt 10000 ]]; then
                echo -e "${YELLOW}警告: 建议使用10000以上的端口${NC}"
                if ! confirm_action "是否继续使用端口 $new_port?"; then
                    return
                fi
            fi
            
            if check_port "$new_port"; then
                echo -e "${RED}端口 $new_port 已被占用${NC}"
                sleep 2
                return
            fi
            ;;
        0) return ;;
        *) echo -e "${RED}无效选择${NC}" && sleep 1 && return ;;
    esac
    
    # 确认修改
    echo ""
    if confirm_action "确认将 $protocol_name 端口从 ${current_port:-未配置} 修改为 $new_port?"; then
        # 更新配置变量
        eval "$port_var=$new_port"
        
        # 保存配置
        save_config
        
        # 重新生成配置文件
        local protocols=()
        [[ -n "$VLESS_PORT" ]] && protocols+=("vless")
        [[ -n "$VMESS_PORT" ]] && protocols+=("vmess")
        [[ -n "$HY2_PORT" ]] && protocols+=("hysteria2")
        
        if [[ ${#protocols[@]} -gt 0 ]]; then
            generate_config "${protocols[@]}"
        else
            echo -e "${YELLOW}警告: 没有找到已配置的协议${NC}"
        fi
        
        # 重启服务
        if [[ "$(get_service_status "$SERVICE_NAME")" == "running" ]]; then
            restart_service "$SERVICE_NAME"
        fi
        
        echo -e "${GREEN}端口修改成功！${NC}"
        echo -e "${GREEN}新端口: $new_port${NC}"
    fi
    
    echo ""
    wait_for_input
}

# 批量重新分配端口
reassign_all_ports() {
    echo -e "${CYAN}=== 批量重新分配端口 ===${NC}"
    echo ""
    
    # 加载当前配置
    load_config
    
    echo -e "${YELLOW}当前端口配置:${NC}"
    echo -e "VLESS Reality: ${VLESS_PORT:-未配置}"
    echo -e "VMess WebSocket: ${VMESS_PORT:-未配置}"
    echo -e "Hysteria2: ${HY2_PORT:-未配置}"
    echo ""
    
    if ! confirm_action "确认为所有协议重新分配随机端口?"; then
        return
    fi
    
    echo -e "${CYAN}正在重新分配端口...${NC}"
    
    # 生成新端口
    local new_vless_port new_vmess_port new_hy2_port
    
    if [[ -n "$VLESS_PORT" ]]; then
        new_vless_port=$(get_random_port)
        VLESS_PORT="$new_vless_port"
        echo -e "${GREEN}VLESS Reality: $new_vless_port${NC}"
    fi
    
    if [[ -n "$VMESS_PORT" ]]; then
        new_vmess_port=$(get_random_port)
        VMESS_PORT="$new_vmess_port"
        echo -e "${GREEN}VMess WebSocket: $new_vmess_port${NC}"
    fi
    
    if [[ -n "$HY2_PORT" ]]; then
        new_hy2_port=$(get_random_port)
        HY2_PORT="$new_hy2_port"
        echo -e "${GREEN}Hysteria2: $new_hy2_port${NC}"
    fi
    
    # 保存配置
    save_config
    
    # 重新生成配置文件
    local protocols=()
    [[ -n "$VLESS_PORT" ]] && protocols+=("vless")
    [[ -n "$VMESS_PORT" ]] && protocols+=("vmess")
    [[ -n "$HY2_PORT" ]] && protocols+=("hysteria2")
    
    if [[ ${#protocols[@]} -gt 0 ]]; then
        generate_config "${protocols[@]}"
    else
        echo -e "${YELLOW}警告: 没有找到已配置的协议${NC}"
    fi
    
    # 重启服务
    if [[ "$(get_service_status "$SERVICE_NAME")" == "running" ]]; then
        restart_service "$SERVICE_NAME"
    fi
    
    echo ""
    echo -e "${GREEN}端口重新分配完成！${NC}"
    echo ""
    wait_for_input
}

# 测试端口连通性
test_port_connectivity() {
    echo -e "${CYAN}=== 端口连通性测试 ===${NC}"
    echo ""
    
    # 加载配置
    load_config
    
    local ports=("$VLESS_PORT" "$VMESS_PORT" "$HY2_PORT")
    local names=("VLESS Reality" "VMess WebSocket" "Hysteria2")
    
    for i in "${!ports[@]}"; do
        local port="${ports[$i]}"
        local name="${names[$i]}"
        
        if [[ -n "$port" ]]; then
            echo -n -e "测试 ${GREEN}$name${NC} (端口 $port): "
            
            # 检查端口是否监听
            if ss -tuln | grep -q ":$port "; then
                echo -e "${GREEN}✓ 正在监听${NC}"
                
                # 尝试连接测试
                echo -n -e "  连接测试: "
                if timeout 3 bash -c "</dev/tcp/127.0.0.1/$port" 2>/dev/null; then
                    echo -e "${GREEN}✓ 可连接${NC}"
                else
                    echo -e "${YELLOW}⚠ 连接失败${NC}"
                fi
            else
                echo -e "${RED}✗ 未监听${NC}"
            fi
        fi
    done
    
    echo ""
    wait_for_input
}