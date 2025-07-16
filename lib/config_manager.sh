#!/bin/bash

# 配置管理模块
# 负责从 JSON 配置文件中加载和保存端口配置

# 从 JSON 配置文件加载端口配置
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_warn "配置文件不存在: $CONFIG_FILE"
        return 1
    fi
    
    if ! command_exists jq; then
        log_warn "jq 未安装，无法解析配置文件"
        return 1
    fi
    
    log_info "正在加载配置文件: $CONFIG_FILE"
    
    # 提取 VLESS 端口
    local vless_port
    vless_port=$(jq -r '.inbounds[] | select(.type == "vless") | .listen_port' "$CONFIG_FILE" 2>/dev/null)
    if [[ "$vless_port" != "null" && -n "$vless_port" ]]; then
        VLESS_PORT="$vless_port"
        log_info "加载 VLESS 端口: $VLESS_PORT"
    fi
    
    # 提取 VMess 端口
    local vmess_port
    vmess_port=$(jq -r '.inbounds[] | select(.type == "vmess") | .listen_port' "$CONFIG_FILE" 2>/dev/null)
    if [[ "$vmess_port" != "null" && -n "$vmess_port" ]]; then
        VMESS_PORT="$vmess_port"
        log_info "加载 VMess 端口: $VMESS_PORT"
    fi
    
    # 提取 Hysteria2 端口
    local hy2_port
    hy2_port=$(jq -r '.inbounds[] | select(.type == "hysteria2") | .listen_port' "$CONFIG_FILE" 2>/dev/null)
    if [[ "$hy2_port" != "null" && -n "$hy2_port" ]]; then
        HY2_PORT="$hy2_port"
        log_info "加载 Hysteria2 端口: $HY2_PORT"
    fi
    
    # 提取其他配置信息
    local vless_uuid
    vless_uuid=$(jq -r '.inbounds[] | select(.type == "vless") | .users[0].uuid' "$CONFIG_FILE" 2>/dev/null)
    if [[ "$vless_uuid" != "null" && -n "$vless_uuid" ]]; then
        VLESS_UUID="$vless_uuid"
    fi
    
    local vmess_uuid
    vmess_uuid=$(jq -r '.inbounds[] | select(.type == "vmess") | .users[0].uuid' "$CONFIG_FILE" 2>/dev/null)
    if [[ "$vmess_uuid" != "null" && -n "$vmess_uuid" ]]; then
        VMESS_UUID="$vmess_uuid"
    fi
    
    local hy2_password
    hy2_password=$(jq -r '.inbounds[] | select(.type == "hysteria2") | .users[0].password' "$CONFIG_FILE" 2>/dev/null)
    if [[ "$hy2_password" != "null" && -n "$hy2_password" ]]; then
        HY2_PASSWORD="$hy2_password"
    fi
    
    log_success "配置加载完成"
    return 0
}

# 保存端口配置到 JSON 配置文件
save_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_warn "配置文件不存在: $CONFIG_FILE"
        return 1
    fi
    
    if ! command_exists jq; then
        log_warn "jq 未安装，无法更新配置文件"
        return 1
    fi
    
    log_info "正在保存配置到: $CONFIG_FILE"
    
    # 备份原配置文件
    local backup_file="$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$CONFIG_FILE" "$backup_file"
    log_info "配置文件已备份到: $backup_file"
    
    local temp_file
    temp_file=$(mktemp)
    
    # 更新 VLESS 端口
    if [[ -n "$VLESS_PORT" ]]; then
        jq --arg port "$VLESS_PORT" '(.inbounds[] | select(.type == "vless") | .listen_port) = ($port | tonumber)' "$CONFIG_FILE" > "$temp_file"
        mv "$temp_file" "$CONFIG_FILE"
        log_info "更新 VLESS 端口: $VLESS_PORT"
    fi
    
    # 更新 VMess 端口
    if [[ -n "$VMESS_PORT" ]]; then
        temp_file=$(mktemp)
        jq --arg port "$VMESS_PORT" '(.inbounds[] | select(.type == "vmess") | .listen_port) = ($port | tonumber)' "$CONFIG_FILE" > "$temp_file"
        mv "$temp_file" "$CONFIG_FILE"
        log_info "更新 VMess 端口: $VMESS_PORT"
    fi
    
    # 更新 Hysteria2 端口
    if [[ -n "$HY2_PORT" ]]; then
        temp_file=$(mktemp)
        jq --arg port "$HY2_PORT" '(.inbounds[] | select(.type == "hysteria2") | .listen_port) = ($port | tonumber)' "$CONFIG_FILE" > "$temp_file"
        mv "$temp_file" "$CONFIG_FILE"
        log_info "更新 Hysteria2 端口: $HY2_PORT"
    fi
    
    # 验证配置文件
    if validate_json "$CONFIG_FILE"; then
        log_success "配置保存成功"
        return 0
    else
        log_error "配置文件验证失败，恢复备份"
        cp "$backup_file" "$CONFIG_FILE"
        return 1
    fi
}

# 显示当前配置
show_current_config() {
    echo -e "${CYAN}=== 当前配置信息 ===${NC}"
    echo ""
    
    if [[ -n "$VLESS_PORT" ]]; then
        echo -e "${GREEN}VLESS Reality:${NC}"
        echo -e "  端口: $VLESS_PORT"
        echo -e "  UUID: ${VLESS_UUID:-未配置}"
        echo ""
    fi
    
    if [[ -n "$VMESS_PORT" ]]; then
        echo -e "${GREEN}VMess WebSocket:${NC}"
        echo -e "  端口: $VMESS_PORT"
        echo -e "  UUID: ${VMESS_UUID:-未配置}"
        echo ""
    fi
    
    if [[ -n "$HY2_PORT" ]]; then
        echo -e "${GREEN}Hysteria2:${NC}"
        echo -e "  端口: $HY2_PORT"
        echo -e "  密码: ${HY2_PASSWORD:-未配置}"
        echo ""
    fi
    
    if [[ -z "$VLESS_PORT" && -z "$VMESS_PORT" && -z "$HY2_PORT" ]]; then
        echo -e "${YELLOW}未找到任何协议配置${NC}"
    fi
}

# 初始化配置变量
init_config_vars() {
    # 协议端口变量
    VLESS_PORT=""
    VMESS_PORT=""
    HY2_PORT=""
    
    # 协议配置变量
    VLESS_UUID=""
    VMESS_UUID=""
    HY2_PASSWORD=""
    
    log_info "配置变量已初始化"
}