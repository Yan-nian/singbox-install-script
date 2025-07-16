#!/bin/bash

# =============================================================================
# 配置管理模块 - 增强版
# 版本: v2.4.3
# 功能: 提供完整的配置加载、保存、验证和状态管理功能
# =============================================================================

# 引入依赖模块
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/error_handler.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/error_handler.sh"
fi

if [[ -f "$(dirname "${BASH_SOURCE[0]}")/logger.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"
fi

if [[ -f "$(dirname "${BASH_SOURCE[0]}")/validator.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/validator.sh"
fi

# 配置状态缓存文件
CONFIG_STATE_FILE="${CONFIG_DIR:-/etc/singbox}/.config_state"

# 验证JSON配置文件
validate_json() {
    local file="$1"
    local context="${2:-JSON验证}"
    
    if [[ ! -f "$file" ]]; then
        handle_error "$(get_error_code "FILE_NOT_FOUND")" "配置文件不存在: $file" "$context" false
        return 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        handle_error "$(get_error_code "DEPENDENCY_MISSING")" "jq 未安装，无法验证JSON格式" "$context" false
        return 1
    fi
    
    if ! jq empty "$file" 2>/dev/null; then
        handle_error "$(get_error_code "CONFIG_PARSE_ERROR")" "JSON格式无效: $file" "$context" false
        return 1
    fi
    
    return 0
}

# 从 JSON 配置文件加载端口配置 - 增强版
load_config() {
    local force_reload="${1:-false}"
    local context="配置加载"
    
    log_info "开始加载配置" "文件: ${CONFIG_FILE:-未设置}"
    
    # 检查配置文件是否存在
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_warn "配置文件不存在，跳过加载" "$CONFIG_FILE"
        init_config_vars  # 确保变量初始化
        return 0
    fi
    
    # 验证JSON格式
    if ! validate_json "$CONFIG_FILE" "$context"; then
        log_error "配置文件格式验证失败，跳过加载"
        return 1
    fi
    
    # 检查是否需要重新加载（基于文件修改时间）
    if [[ "$force_reload" != "true" ]] && [[ -f "$CONFIG_STATE_FILE" ]]; then
        local config_mtime=$(stat -c %Y "$CONFIG_FILE" 2>/dev/null || echo 0)
        local state_mtime=$(stat -c %Y "$CONFIG_STATE_FILE" 2>/dev/null || echo 0)
        
        if [[ $config_mtime -le $state_mtime ]]; then
            log_debug "配置未变更，从缓存加载"
            if load_config_from_cache; then
                return 0
            fi
        fi
    fi
    
    log_info "正在解析配置文件" "$CONFIG_FILE"
    
    # 初始化计数器
    local configured_count=0
    local errors=()
    
    # 提取 VLESS 配置
    if extract_vless_config; then
        ((configured_count++))
    else
        errors+=("VLESS配置提取失败")
    fi
    
    # 提取 VMess 配置
    if extract_vmess_config; then
        ((configured_count++))
    else
        errors+=("VMess配置提取失败")
    fi
    
    # 提取 Hysteria2 配置
    if extract_hysteria2_config; then
        ((configured_count++))
    else
        errors+=("Hysteria2配置提取失败")
    fi
    
    # 报告结果
    if [[ $configured_count -gt 0 ]]; then
        log_info "配置加载完成" "成功加载 $configured_count 个协议"
        save_config_to_cache
    else
        log_warn "未找到任何已配置的协议"
    fi
    
    # 报告错误（如果有）
    if [[ ${#errors[@]} -gt 0 ]]; then
        for error in "${errors[@]}"; do
            log_warn "$error"
        done
    fi
    
    return 0
}

# 提取VLESS配置
extract_vless_config() {
    local vless_port vless_uuid vless_flow
    
    # 提取端口
    vless_port=$(jq -r '.inbounds[] | select(.type == "vless") | .listen_port' "$CONFIG_FILE" 2>/dev/null)
    if [[ "$vless_port" != "null" && -n "$vless_port" ]]; then
        if validate_port "$vless_port" "VLESS端口验证"; then
            VLESS_PORT="$vless_port"
            log_debug "VLESS端口: $VLESS_PORT"
        else
            return 1
        fi
    else
        return 1
    fi
    
    # 提取UUID
    vless_uuid=$(jq -r '.inbounds[] | select(.type == "vless") | .users[0].uuid' "$CONFIG_FILE" 2>/dev/null)
    if [[ "$vless_uuid" != "null" && -n "$vless_uuid" ]]; then
        if validate_uuid "$vless_uuid" "VLESS UUID验证"; then
            VLESS_UUID="$vless_uuid"
            log_debug "VLESS UUID: ${VLESS_UUID:0:8}..."
        fi
    fi
    
    # 提取Flow
    vless_flow=$(jq -r '.inbounds[] | select(.type == "vless") | .users[0].flow' "$CONFIG_FILE" 2>/dev/null)
    if [[ "$vless_flow" != "null" && -n "$vless_flow" ]]; then
        VLESS_FLOW="$vless_flow"
        log_debug "VLESS Flow: $VLESS_FLOW"
    fi
    
    return 0
}

# 提取VMess配置
extract_vmess_config() {
    local vmess_port vmess_uuid vmess_path
    
    # 提取端口
    vmess_port=$(jq -r '.inbounds[] | select(.type == "vmess") | .listen_port' "$CONFIG_FILE" 2>/dev/null)
    if [[ "$vmess_port" != "null" && -n "$vmess_port" ]]; then
        if validate_port "$vmess_port" "VMess端口验证"; then
            VMESS_PORT="$vmess_port"
            log_debug "VMess端口: $VMESS_PORT"
        else
            return 1
        fi
    else
        return 1
    fi
    
    # 提取UUID
    vmess_uuid=$(jq -r '.inbounds[] | select(.type == "vmess") | .users[0].uuid' "$CONFIG_FILE" 2>/dev/null)
    if [[ "$vmess_uuid" != "null" && -n "$vmess_uuid" ]]; then
        if validate_uuid "$vmess_uuid" "VMess UUID验证"; then
            VMESS_UUID="$vmess_uuid"
            log_debug "VMess UUID: ${VMESS_UUID:0:8}..."
        fi
    fi
    
    # 提取WebSocket路径
    vmess_path=$(jq -r '.inbounds[] | select(.type == "vmess") | .transport.path' "$CONFIG_FILE" 2>/dev/null)
    if [[ "$vmess_path" != "null" && -n "$vmess_path" ]]; then
        VMESS_PATH="$vmess_path"
        log_debug "VMess路径: $VMESS_PATH"
    fi
    
    return 0
}

# 提取Hysteria2配置
extract_hysteria2_config() {
    local hy2_port hy2_password hy2_obfs
    
    # 提取端口
    hy2_port=$(jq -r '.inbounds[] | select(.type == "hysteria2") | .listen_port' "$CONFIG_FILE" 2>/dev/null)
    if [[ "$hy2_port" != "null" && -n "$hy2_port" ]]; then
        if validate_port "$hy2_port" "Hysteria2端口验证"; then
            HY2_PORT="$hy2_port"
            log_debug "Hysteria2端口: $HY2_PORT"
        else
            return 1
        fi
    else
        return 1
    fi
    
    # 提取密码
    hy2_password=$(jq -r '.inbounds[] | select(.type == "hysteria2") | .users[0].password' "$CONFIG_FILE" 2>/dev/null)
    if [[ "$hy2_password" != "null" && -n "$hy2_password" ]]; then
        HY2_PASSWORD="$hy2_password"
        log_debug "Hysteria2密码: ${HY2_PASSWORD:0:8}..."
    fi
    
    # 提取混淆
    hy2_obfs=$(jq -r '.inbounds[] | select(.type == "hysteria2") | .obfs.password' "$CONFIG_FILE" 2>/dev/null)
    if [[ "$hy2_obfs" != "null" && -n "$hy2_obfs" ]]; then
        HY2_OBFS="$hy2_obfs"
        log_debug "Hysteria2混淆: 已设置"
    fi
    
    return 0
}

# 从缓存加载配置
load_config_from_cache() {
    if [[ ! -f "$CONFIG_STATE_FILE" ]]; then
        return 1
    fi
    
    local cache_data
    if ! cache_data=$(cat "$CONFIG_STATE_FILE" 2>/dev/null); then
        return 1
    fi
    
    # 解析缓存数据
    while IFS='=' read -r key value; do
        case "$key" in
            "VLESS_PORT") VLESS_PORT="$value" ;;
            "VLESS_UUID") VLESS_UUID="$value" ;;
            "VLESS_FLOW") VLESS_FLOW="$value" ;;
            "VMESS_PORT") VMESS_PORT="$value" ;;
            "VMESS_UUID") VMESS_UUID="$value" ;;
            "VMESS_PATH") VMESS_PATH="$value" ;;
            "HY2_PORT") HY2_PORT="$value" ;;
            "HY2_PASSWORD") HY2_PASSWORD="$value" ;;
            "HY2_OBFS") HY2_OBFS="$value" ;;
        esac
    done <<< "$cache_data"
    
    log_debug "从缓存加载配置完成"
    return 0
}

# 保存配置到缓存
save_config_to_cache() {
    local cache_dir
    cache_dir=$(dirname "$CONFIG_STATE_FILE")
    
    # 确保缓存目录存在
    if [[ ! -d "$cache_dir" ]]; then
        mkdir -p "$cache_dir" 2>/dev/null || {
            log_warn "无法创建缓存目录: $cache_dir"
            return 1
        }
    fi
    
    # 写入缓存
    {
        [[ -n "$VLESS_PORT" ]] && echo "VLESS_PORT=$VLESS_PORT"
        [[ -n "$VLESS_UUID" ]] && echo "VLESS_UUID=$VLESS_UUID"
        [[ -n "$VLESS_FLOW" ]] && echo "VLESS_FLOW=$VLESS_FLOW"
        [[ -n "$VMESS_PORT" ]] && echo "VMESS_PORT=$VMESS_PORT"
        [[ -n "$VMESS_UUID" ]] && echo "VMESS_UUID=$VMESS_UUID"
        [[ -n "$VMESS_PATH" ]] && echo "VMESS_PATH=$VMESS_PATH"
        [[ -n "$HY2_PORT" ]] && echo "HY2_PORT=$HY2_PORT"
        [[ -n "$HY2_PASSWORD" ]] && echo "HY2_PASSWORD=$HY2_PASSWORD"
        [[ -n "$HY2_OBFS" ]] && echo "HY2_OBFS=$HY2_OBFS"
    } > "$CONFIG_STATE_FILE" 2>/dev/null || {
        log_warn "无法保存配置缓存"
        return 1
    }
    
    log_debug "配置已保存到缓存"
    return 0
}

# 保存端口配置到 JSON 文件 - 增强版
save_config() {
    local context="配置保存"
    local backup_created=false
    
    log_info "开始保存配置" "文件: $CONFIG_FILE"
    
    # 验证配置文件存在
    if [[ ! -f "$CONFIG_FILE" ]]; then
        handle_error "$(get_error_code "FILE_NOT_FOUND")" "配置文件不存在: $CONFIG_FILE" "$context" false
        return 1
    fi
    
    # 验证JSON格式
    if ! validate_json "$CONFIG_FILE" "$context"; then
        return 1
    fi
    
    # 创建备份
    if ! create_config_backup; then
        handle_error "$(get_error_code "FILE_BACKUP_FAILED")" "无法创建配置备份" "$context" false
        return 1
    fi
    backup_created=true
    
    # 验证要保存的配置
    if ! validate_config_before_save; then
        restore_config_backup
        return 1
    fi
    
    # 执行配置更新
    local update_count=0
    local errors=()
    
    # 更新 VLESS 配置
    if [[ -n "$VLESS_PORT" ]] || [[ -n "$VLESS_UUID" ]] || [[ -n "$VLESS_FLOW" ]]; then
        if update_vless_config; then
            ((update_count++))
            log_debug "VLESS配置更新成功"
        else
            errors+=("VLESS配置更新失败")
        fi
    fi
    
    # 更新 VMess 配置
    if [[ -n "$VMESS_PORT" ]] || [[ -n "$VMESS_UUID" ]] || [[ -n "$VMESS_PATH" ]]; then
        if update_vmess_config; then
            ((update_count++))
            log_debug "VMess配置更新成功"
        else
            errors+=("VMess配置更新失败")
        fi
    fi
    
    # 更新 Hysteria2 配置
    if [[ -n "$HY2_PORT" ]] || [[ -n "$HY2_PASSWORD" ]] || [[ -n "$HY2_OBFS" ]]; then
        if update_hysteria2_config; then
            ((update_count++))
            log_debug "Hysteria2配置更新成功"
        else
            errors+=("Hysteria2配置更新失败")
        fi
    fi
    
    # 验证更新后的配置
    if ! validate_json "$CONFIG_FILE" "配置更新后验证"; then
        log_error "配置更新后验证失败，恢复备份"
        restore_config_backup
        return 1
    fi
    
    # 报告结果
    if [[ $update_count -gt 0 ]]; then
        log_info "配置保存完成" "成功更新 $update_count 个协议"
        save_config_to_cache
        cleanup_old_backups
    else
        log_warn "没有配置需要更新"
    fi
    
    # 报告错误（如果有）
    if [[ ${#errors[@]} -gt 0 ]]; then
        for error in "${errors[@]}"; do
            log_warn "$error"
        done
        return 1
    fi
    
    return 0
}

# 创建配置备份
create_config_backup() {
    local backup_dir="${CONFIG_DIR:-/etc/singbox}/backups"
    local backup_file="$backup_dir/config.$(date +%Y%m%d_%H%M%S).json"
    
    # 确保备份目录存在
    if [[ ! -d "$backup_dir" ]]; then
        mkdir -p "$backup_dir" 2>/dev/null || {
            log_error "无法创建备份目录: $backup_dir"
            return 1
        }
    fi
    
    # 创建备份
    if cp "$CONFIG_FILE" "$backup_file" 2>/dev/null; then
        LAST_BACKUP_FILE="$backup_file"
        log_debug "配置备份已创建: $backup_file"
        return 0
    else
        log_error "无法创建配置备份"
        return 1
    fi
}

# 恢复配置备份
restore_config_backup() {
    if [[ -n "$LAST_BACKUP_FILE" ]] && [[ -f "$LAST_BACKUP_FILE" ]]; then
        if cp "$LAST_BACKUP_FILE" "$CONFIG_FILE" 2>/dev/null; then
            log_info "配置已从备份恢复" "$LAST_BACKUP_FILE"
        else
            log_error "无法恢复配置备份"
        fi
    fi
}

# 清理旧备份
cleanup_old_backups() {
    local backup_dir="${CONFIG_DIR:-/etc/singbox}/backups"
    local max_backups=10
    
    if [[ -d "$backup_dir" ]]; then
        # 保留最新的10个备份
        find "$backup_dir" -name "config.*.json" -type f | sort -r | tail -n +$((max_backups + 1)) | xargs rm -f 2>/dev/null
        log_debug "旧备份清理完成"
    fi
}

# 验证配置保存前的数据
validate_config_before_save() {
    local errors=()
    
    # 验证端口
    if [[ -n "$VLESS_PORT" ]] && ! validate_port "$VLESS_PORT" "VLESS端口验证"; then
        errors+=("VLESS端口无效: $VLESS_PORT")
    fi
    
    if [[ -n "$VMESS_PORT" ]] && ! validate_port "$VMESS_PORT" "VMess端口验证"; then
        errors+=("VMess端口无效: $VMESS_PORT")
    fi
    
    if [[ -n "$HY2_PORT" ]] && ! validate_port "$HY2_PORT" "Hysteria2端口验证"; then
        errors+=("Hysteria2端口无效: $HY2_PORT")
    fi
    
    # 验证UUID
    if [[ -n "$VLESS_UUID" ]] && ! validate_uuid "$VLESS_UUID" "VLESS UUID验证"; then
        errors+=("VLESS UUID无效: $VLESS_UUID")
    fi
    
    if [[ -n "$VMESS_UUID" ]] && ! validate_uuid "$VMESS_UUID" "VMess UUID验证"; then
        errors+=("VMess UUID无效: $VMESS_UUID")
    fi
    
    # 报告验证错误
    if [[ ${#errors[@]} -gt 0 ]]; then
        for error in "${errors[@]}"; do
            log_error "配置验证失败: $error"
        done
        return 1
    fi
    
    return 0
}

# 更新VLESS配置
update_vless_config() {
    local temp_file
    temp_file=$(mktemp)
    
    # 更新端口
    if [[ -n "$VLESS_PORT" ]]; then
        if ! jq --arg port "$VLESS_PORT" '(.inbounds[] | select(.type == "vless") | .listen_port) = ($port | tonumber)' "$CONFIG_FILE" > "$temp_file"; then
            rm -f "$temp_file"
            return 1
        fi
        mv "$temp_file" "$CONFIG_FILE"
        log_debug "VLESS端口已更新: $VLESS_PORT"
    fi
    
    # 更新UUID
    if [[ -n "$VLESS_UUID" ]]; then
        temp_file=$(mktemp)
        if ! jq --arg uuid "$VLESS_UUID" '(.inbounds[] | select(.type == "vless") | .users[0].uuid) = $uuid' "$CONFIG_FILE" > "$temp_file"; then
            rm -f "$temp_file"
            return 1
        fi
        mv "$temp_file" "$CONFIG_FILE"
        log_debug "VLESS UUID已更新"
    fi
    
    # 更新Flow
    if [[ -n "$VLESS_FLOW" ]]; then
        temp_file=$(mktemp)
        if ! jq --arg flow "$VLESS_FLOW" '(.inbounds[] | select(.type == "vless") | .users[0].flow) = $flow' "$CONFIG_FILE" > "$temp_file"; then
            rm -f "$temp_file"
            return 1
        fi
        mv "$temp_file" "$CONFIG_FILE"
        log_debug "VLESS Flow已更新: $VLESS_FLOW"
    fi
    
    return 0
}

# 更新VMess配置
update_vmess_config() {
    local temp_file
    temp_file=$(mktemp)
    
    # 更新端口
    if [[ -n "$VMESS_PORT" ]]; then
        if ! jq --arg port "$VMESS_PORT" '(.inbounds[] | select(.type == "vmess") | .listen_port) = ($port | tonumber)' "$CONFIG_FILE" > "$temp_file"; then
            rm -f "$temp_file"
            return 1
        fi
        mv "$temp_file" "$CONFIG_FILE"
        log_debug "VMess端口已更新: $VMESS_PORT"
    fi
    
    # 更新UUID
    if [[ -n "$VMESS_UUID" ]]; then
        temp_file=$(mktemp)
        if ! jq --arg uuid "$VMESS_UUID" '(.inbounds[] | select(.type == "vmess") | .users[0].uuid) = $uuid' "$CONFIG_FILE" > "$temp_file"; then
            rm -f "$temp_file"
            return 1
        fi
        mv "$temp_file" "$CONFIG_FILE"
        log_debug "VMess UUID已更新"
    fi
    
    # 更新路径
    if [[ -n "$VMESS_PATH" ]]; then
        temp_file=$(mktemp)
        if ! jq --arg path "$VMESS_PATH" '(.inbounds[] | select(.type == "vmess") | .transport.path) = $path' "$CONFIG_FILE" > "$temp_file"; then
            rm -f "$temp_file"
            return 1
        fi
        mv "$temp_file" "$CONFIG_FILE"
        log_debug "VMess路径已更新: $VMESS_PATH"
    fi
    
    return 0
}

# 更新Hysteria2配置
update_hysteria2_config() {
    local temp_file
    temp_file=$(mktemp)
    
    # 更新端口
    if [[ -n "$HY2_PORT" ]]; then
        if ! jq --arg port "$HY2_PORT" '(.inbounds[] | select(.type == "hysteria2") | .listen_port) = ($port | tonumber)' "$CONFIG_FILE" > "$temp_file"; then
            rm -f "$temp_file"
            return 1
        fi
        mv "$temp_file" "$CONFIG_FILE"
        log_debug "Hysteria2端口已更新: $HY2_PORT"
    fi
    
    # 更新密码
    if [[ -n "$HY2_PASSWORD" ]]; then
        temp_file=$(mktemp)
        if ! jq --arg password "$HY2_PASSWORD" '(.inbounds[] | select(.type == "hysteria2") | .users[0].password) = $password' "$CONFIG_FILE" > "$temp_file"; then
            rm -f "$temp_file"
            return 1
        fi
        mv "$temp_file" "$CONFIG_FILE"
        log_debug "Hysteria2密码已更新"
    fi
    
    # 更新混淆
    if [[ -n "$HY2_OBFS" ]]; then
        temp_file=$(mktemp)
        if ! jq --arg obfs "$HY2_OBFS" '(.inbounds[] | select(.type == "hysteria2") | .obfs.password) = $obfs' "$CONFIG_FILE" > "$temp_file"; then
            rm -f "$temp_file"
            return 1
        fi
        mv "$temp_file" "$CONFIG_FILE"
        log_debug "Hysteria2混淆已更新"
    fi
    
    return 0
}

# 获取配置状态摘要
get_config_status() {
    local status_info=()
    local total_protocols=0
    
    # 检查VLESS
    if [[ -n "$VLESS_PORT" ]]; then
        status_info+=("VLESS: 端口 $VLESS_PORT")
        ((total_protocols++))
    fi
    
    # 检查VMess
    if [[ -n "$VMESS_PORT" ]]; then
        status_info+=("VMess: 端口 $VMESS_PORT")
        ((total_protocols++))
    fi
    
    # 检查Hysteria2
    if [[ -n "$HY2_PORT" ]]; then
        status_info+=("Hysteria2: 端口 $HY2_PORT")
        ((total_protocols++))
    fi
    
    if [[ $total_protocols -eq 0 ]]; then
        echo "未配置任何协议"
    else
        echo "已配置 $total_protocols 个协议: ${status_info[*]}"
    fi
}

# 重置配置缓存
reset_config_cache() {
    if [[ -f "$CONFIG_STATE_FILE" ]]; then
        rm -f "$CONFIG_STATE_FILE" 2>/dev/null
        log_info "配置缓存已重置"
    fi
}

# 显示当前配置
show_current_config() {
    local context="配置显示"
    
    log_info "显示当前配置信息"
    
    echo -e "\n${CYAN}=== 当前配置信息 ===${NC}"
    
    # 显示配置文件信息
    if [[ -f "$CONFIG_FILE" ]]; then
        local file_size=$(stat -c%s "$CONFIG_FILE" 2>/dev/null || echo "未知")
        local file_mtime=$(stat -c%Y "$CONFIG_FILE" 2>/dev/null || echo "0")
        local file_date=$(date -d "@$file_mtime" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "未知")
        echo -e "${BLUE}配置文件:${NC} $CONFIG_FILE"
        echo -e "${BLUE}文件大小:${NC} $file_size 字节"
        echo -e "${BLUE}修改时间:${NC} $file_date"
        echo
    fi
    
    local has_config=false
    
    # 显示VLESS配置
    if [[ -n "$VLESS_PORT" ]]; then
        echo -e "${GREEN}■ VLESS 协议:${NC}"
        echo -e "  ${CYAN}端口:${NC} $VLESS_PORT"
        [[ -n "$VLESS_UUID" ]] && echo -e "  ${CYAN}UUID:${NC} ${VLESS_UUID:0:8}...${VLESS_UUID: -4}"
        [[ -n "$VLESS_FLOW" ]] && echo -e "  ${CYAN}Flow:${NC} $VLESS_FLOW"
        
        # 检查端口状态
        if command -v netstat >/dev/null 2>&1; then
            if netstat -tuln 2>/dev/null | grep -q ":$VLESS_PORT "; then
                echo -e "  ${GREEN}状态: 端口正在监听${NC}"
            else
                echo -e "  ${YELLOW}状态: 端口未监听${NC}"
            fi
        fi
        echo
        has_config=true
    fi
    
    # 显示VMess配置
    if [[ -n "$VMESS_PORT" ]]; then
        echo -e "${GREEN}■ VMess 协议:${NC}"
        echo -e "  ${CYAN}端口:${NC} $VMESS_PORT"
        [[ -n "$VMESS_UUID" ]] && echo -e "  ${CYAN}UUID:${NC} ${VMESS_UUID:0:8}...${VMESS_UUID: -4}"
        [[ -n "$VMESS_PATH" ]] && echo -e "  ${CYAN}路径:${NC} $VMESS_PATH"
        
        # 检查端口状态
        if command -v netstat >/dev/null 2>&1; then
            if netstat -tuln 2>/dev/null | grep -q ":$VMESS_PORT "; then
                echo -e "  ${GREEN}状态: 端口正在监听${NC}"
            else
                echo -e "  ${YELLOW}状态: 端口未监听${NC}"
            fi
        fi
        echo
        has_config=true
    fi
    
    # 显示Hysteria2配置
    if [[ -n "$HY2_PORT" ]]; then
        echo -e "${GREEN}■ Hysteria2 协议:${NC}"
        echo -e "  ${CYAN}端口:${NC} $HY2_PORT"
        [[ -n "$HY2_PASSWORD" ]] && echo -e "  ${CYAN}密码:${NC} ${HY2_PASSWORD:0:8}...${HY2_PASSWORD: -4}"
        [[ -n "$HY2_OBFS" ]] && echo -e "  ${CYAN}混淆:${NC} 已启用"
        
        # 检查端口状态
        if command -v netstat >/dev/null 2>&1; then
            if netstat -tuln 2>/dev/null | grep -q ":$HY2_PORT "; then
                echo -e "  ${GREEN}状态: 端口正在监听${NC}"
            else
                echo -e "  ${YELLOW}状态: 端口未监听${NC}"
            fi
        fi
        echo
        has_config=true
    fi
    
    # 显示缓存状态
    if [[ -f "$CONFIG_STATE_FILE" ]]; then
        local cache_mtime=$(stat -c%Y "$CONFIG_STATE_FILE" 2>/dev/null || echo "0")
        local cache_date=$(date -d "@$cache_mtime" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "未知")
        echo -e "${BLUE}缓存状态:${NC} 已缓存 (更新时间: $cache_date)"
    else
        echo -e "${BLUE}缓存状态:${NC} 无缓存"
    fi
    
    if [[ "$has_config" != "true" ]]; then
        echo -e "${YELLOW}暂无协议配置信息${NC}"
        echo -e "${CYAN}提示: 请先安装并配置 Sing-box${NC}"
    fi
    
    echo -e "${CYAN}=========================${NC}\n"
}

# 初始化配置变量 - 增强版
init_config_vars() {
    local force_init="${1:-false}"
    
    # 如果不是强制初始化，且已有配置，则跳过
    if [[ "$force_init" != "true" ]] && [[ -n "$VLESS_PORT$VMESS_PORT$HY2_PORT" ]]; then
        log_debug "配置变量已存在，跳过初始化"
        return 0
    fi
    
    log_debug "初始化配置变量" "强制: $force_init"
    
    # VLESS 配置
    VLESS_PORT=""
    VLESS_UUID=""
    VLESS_FLOW=""
    
    # VMess 配置
    VMESS_PORT=""
    VMESS_UUID=""
    VMESS_PATH=""
    
    # Hysteria2 配置
    HY2_PORT=""
    HY2_PASSWORD=""
    HY2_OBFS=""
    
    # 其他配置
    DOMAIN=""
    CERT_PATH=""
    KEY_PATH=""
    
    # 清理缓存（如果是强制初始化）
    if [[ "$force_init" == "true" ]]; then
        reset_config_cache
    fi
    
    log_debug "配置变量初始化完成"
}

# 自动加载配置（在脚本启动时调用）
auto_load_config() {
    local context="自动加载配置"
    
    log_debug "开始自动加载配置"
    
    # 初始化变量
    init_config_vars false
    
    # 尝试加载配置
    if [[ -f "$CONFIG_FILE" ]]; then
        if load_config false; then
            log_info "配置自动加载成功" "$(get_config_status)"
        else
            log_warn "配置自动加载失败，使用默认配置"
        fi
    else
        log_debug "配置文件不存在，使用默认配置"
    fi
}

# 强制重新加载配置
reload_config() {
    log_info "强制重新加载配置"
    
    # 重置变量
    init_config_vars true
    
    # 重新加载
    if load_config true; then
        log_info "配置重新加载成功" "$(get_config_status)"
        return 0
    else
        log_error "配置重新加载失败"
        return 1
    fi
}