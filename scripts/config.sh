#!/bin/bash

# Sing-box 配置文件生成模块
# 负责生成完整的 Sing-box 配置文件

# 配置文件相关变量
CONFIG_FILE="$WORK_DIR/config/config.json"
CONFIG_BACKUP_DIR="$WORK_DIR/config/backup"
ENABLED_PROTOCOLS=()
CONFIG_VERSION="1.0.0"

# 基础配置模板
generate_base_config() {
    cat << EOF
{
  "log": {
    "disabled": false,
    "level": "info",
    "output": "$SINGBOX_LOG",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "google",
        "address": "tls://8.8.8.8",
        "address_resolver": "local",
        "strategy": "prefer_ipv4",
        "detour": "direct"
      },
      {
        "tag": "cloudflare",
        "address": "tls://1.1.1.1",
        "address_resolver": "local",
        "strategy": "prefer_ipv4",
        "detour": "direct"
      },
      {
        "tag": "local",
        "address": "223.5.5.5",
        "strategy": "prefer_ipv4",
        "detour": "direct"
      },
      {
        "tag": "block",
        "address": "rcode://success"
      }
    ],
    "rules": [
      {
        "domain_suffix": [
          ".cn"
        ],
        "server": "local"
      },
      {
        "geosite": "cn",
        "server": "local"
      },
      {
        "geosite": "geolocation-!cn",
        "server": "google"
      }
    ],
    "final": "google",
    "strategy": "prefer_ipv4",
    "disable_cache": false,
    "disable_expire": false
  },
  "ntp": {
    "enabled": true,
    "server": "time.nist.gov",
    "server_port": 123,
    "interval": "30m"
  },
  "inbounds": [],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    },
    {
      "type": "dns",
      "tag": "dns-out"
    }
  ],
  "route": {
    "geoip": {
      "path": "geoip.db",
      "download_url": "https://mirror.ghproxy.com/https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db",
      "download_detour": "direct"
    },
    "geosite": {
      "path": "geosite.db",
      "download_url": "https://mirror.ghproxy.com/https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db",
      "download_detour": "direct"
    },
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      },
      {
        "geosite": "private",
        "outbound": "direct"
      },
      {
        "geoip": "private",
        "outbound": "direct"
      },
      {
        "geosite": "cn",
        "outbound": "direct"
      },
      {
        "geoip": "cn",
        "outbound": "direct"
      },
      {
        "geosite": "geolocation-!cn",
        "outbound": "direct"
      }
    ],
    "final": "direct",
    "auto_detect_interface": true
  },
  "experimental": {
    "cache_file": {
      "enabled": true,
      "path": "$WORK_DIR/cache.db",
      "cache_id": "sing-box-server",
      "store_fakeip": false
    }
  }
}
EOF
}

# 添加入站配置到基础配置
add_inbound_to_config() {
    local config_file="$1"
    local inbound_config="$2"
    
    # 使用 jq 添加入站配置
    if command_exists jq; then
        local temp_file
        temp_file=$(mktemp)
        
        jq --argjson inbound "$inbound_config" '.inbounds += [$inbound]' "$config_file" > "$temp_file"
        mv "$temp_file" "$config_file"
    else
        # 手动添加入站配置
        local temp_file
        temp_file=$(mktemp)
        
        # 读取现有配置
        local config_content
        config_content=$(cat "$config_file")
        
        # 在 inbounds 数组中添加新配置
        echo "$config_content" | sed "s/\"inbounds\": \[/\"inbounds\": [\n$inbound_config,/" > "$temp_file"
        mv "$temp_file" "$config_file"
    fi
}

# 生成多协议配置文件
generate_multi_protocol_config() {
    local protocols=("$@")
    
    log_info "生成多协议配置文件..."
    
    # 创建配置目录
    create_directory "$(dirname "$CONFIG_FILE")" 755
    
    # 生成基础配置
    generate_base_config > "$CONFIG_FILE"
    
    # 添加各协议的入站配置
    for protocol in "${protocols[@]}"; do
        case "$protocol" in
            vless)
                log_info "添加 VLESS Reality Vision 入站配置..."
                local vless_inbound
                vless_inbound=$(generate_vless_inbound)
                add_inbound_to_config "$CONFIG_FILE" "$vless_inbound"
                ;;
            vmess)
                log_info "添加 VMess WebSocket 入站配置..."
                local vmess_inbound
                vmess_inbound=$(generate_vmess_ws_inbound)
                add_inbound_to_config "$CONFIG_FILE" "$vmess_inbound"
                ;;
            vmess-tls)
                log_info "添加 VMess WebSocket TLS 入站配置..."
                local vmess_tls_inbound
                vmess_tls_inbound=$(generate_vmess_ws_tls_inbound)
                add_inbound_to_config "$CONFIG_FILE" "$vmess_tls_inbound"
                ;;
            hysteria2)
                log_info "添加 Hysteria2 入站配置..."
                local hy2_inbound
                hy2_inbound=$(generate_hysteria2_inbound)
                add_inbound_to_config "$CONFIG_FILE" "$hy2_inbound"
                ;;
            *)
                log_warn "未知协议: $protocol"
                ;;
        esac
    done
    
    # 格式化 JSON 文件
    format_json_config "$CONFIG_FILE"
    
    log_success "多协议配置文件生成完成: $CONFIG_FILE"
}

# 格式化 JSON 配置文件
format_json_config() {
    local config_file="$1"
    
    if command_exists jq; then
        local temp_file
        temp_file=$(mktemp)
        
        jq '.' "$config_file" > "$temp_file" 2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            mv "$temp_file" "$config_file"
        else
            rm -f "$temp_file"
            log_warn "JSON 格式化失败，保持原格式"
        fi
    fi
}

# 验证配置文件
validate_config() {
    local config_file="${1:-$CONFIG_FILE}"
    
    log_info "验证配置文件: $config_file"
    
    # 检查文件是否存在
    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    # 检查 JSON 格式
    if command_exists jq; then
        if ! jq '.' "$config_file" >/dev/null 2>&1; then
            log_error "配置文件 JSON 格式错误"
            return 1
        fi
    else
        # 简单的 JSON 语法检查
        if ! python3 -m json.tool "$config_file" >/dev/null 2>&1; then
            if ! python -m json.tool "$config_file" >/dev/null 2>&1; then
                log_warn "无法验证 JSON 格式，请手动检查"
            fi
        fi
    fi
    
    # 使用 sing-box 验证配置
    if [[ -f "$SINGBOX_BINARY" ]]; then
        if "$SINGBOX_BINARY" check -c "$config_file"; then
            log_success "配置文件验证通过"
            return 0
        else
            log_error "Sing-box 配置验证失败"
            return 1
        fi
    else
        log_warn "Sing-box 未安装，跳过配置验证"
        return 0
    fi
}

# 备份配置文件
backup_config() {
    local config_file="${1:-$CONFIG_FILE}"
    local backup_name="${2:-$(date +%Y%m%d_%H%M%S)}"
    
    if [[ ! -f "$config_file" ]]; then
        log_warn "配置文件不存在，无需备份"
        return 0
    fi
    
    # 创建备份目录
    create_directory "$CONFIG_BACKUP_DIR" 755
    
    # 备份文件
    local backup_file="$CONFIG_BACKUP_DIR/config_${backup_name}.json"
    
    if cp "$config_file" "$backup_file"; then
        log_success "配置文件已备份到: $backup_file"
        
        # 保留最近 10 个备份
        local backup_count
        backup_count=$(ls -1 "$CONFIG_BACKUP_DIR"/config_*.json 2>/dev/null | wc -l)
        
        if [[ $backup_count -gt 10 ]]; then
            ls -1t "$CONFIG_BACKUP_DIR"/config_*.json | tail -n +11 | xargs rm -f
            log_info "清理旧备份文件"
        fi
        
        return 0
    else
        log_error "配置文件备份失败"
        return 1
    fi
}

# 恢复配置文件
restore_config() {
    local backup_file="$1"
    
    if [[ -z "$backup_file" ]]; then
        # 列出可用备份
        log_info "可用的配置备份:"
        
        local backups
        backups=($(ls -1t "$CONFIG_BACKUP_DIR"/config_*.json 2>/dev/null))
        
        if [[ ${#backups[@]} -eq 0 ]]; then
            log_error "没有找到配置备份文件"
            return 1
        fi
        
        for i in "${!backups[@]}"; do
            local backup_name
            backup_name=$(basename "${backups[$i]}" .json)
            backup_name=${backup_name#config_}
            
            echo "  $((i+1)). $backup_name ($(stat -c %y "${backups[$i]}" | cut -d' ' -f1))"
        done
        
        read -p "请选择要恢复的备份 (1-${#backups[@]}): " choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#backups[@]} ]]; then
            backup_file="${backups[$((choice-1))]}"
        else
            log_error "无效选择"
            return 1
        fi
    fi
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "备份文件不存在: $backup_file"
        return 1
    fi
    
    # 备份当前配置
    if [[ -f "$CONFIG_FILE" ]]; then
        backup_config "$CONFIG_FILE" "before_restore_$(date +%Y%m%d_%H%M%S)"
    fi
    
    # 恢复配置
    if cp "$backup_file" "$CONFIG_FILE"; then
        log_success "配置文件已恢复: $backup_file"
        
        # 验证恢复的配置
        if validate_config "$CONFIG_FILE"; then
            log_success "恢复的配置文件验证通过"
        else
            log_error "恢复的配置文件验证失败"
        fi
        
        return 0
    else
        log_error "配置文件恢复失败"
        return 1
    fi
}

# 显示配置文件信息
show_config_info() {
    local config_file="${1:-$CONFIG_FILE}"
    
    echo -e "${CYAN}=== 配置文件信息 ===${NC}"
    
    if [[ ! -f "$config_file" ]]; then
        echo -e "状态: ${RED}不存在${NC}"
        return 1
    fi
    
    echo -e "文件路径: ${GREEN}$config_file${NC}"
    echo -e "文件大小: ${GREEN}$(du -h "$config_file" | cut -f1)${NC}"
    echo -e "修改时间: ${GREEN}$(stat -c %y "$config_file" | cut -d'.' -f1)${NC}"
    
    # 检查配置有效性
    if validate_config "$config_file" >/dev/null 2>&1; then
        echo -e "配置状态: ${GREEN}有效${NC}"
    else
        echo -e "配置状态: ${RED}无效${NC}"
    fi
    
    # 显示启用的协议
    if command_exists jq; then
        local inbound_types
        inbound_types=$(jq -r '.inbounds[].type' "$config_file" 2>/dev/null | sort | uniq | tr '\n' ' ')
        
        if [[ -n "$inbound_types" ]]; then
            echo -e "启用协议: ${GREEN}$inbound_types${NC}"
        fi
        
        # 显示监听端口
        local listen_ports
        listen_ports=$(jq -r '.inbounds[].listen_port' "$config_file" 2>/dev/null | sort -n | tr '\n' ' ')
        
        if [[ -n "$listen_ports" ]]; then
            echo -e "监听端口: ${GREEN}$listen_ports${NC}"
        fi
    fi
    
    echo ""
}

# 编辑配置文件
edit_config() {
    local config_file="${1:-$CONFIG_FILE}"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    # 备份当前配置
    backup_config "$config_file" "before_edit_$(date +%Y%m%d_%H%M%S)"
    
    # 选择编辑器
    local editor="${EDITOR:-nano}"
    
    if ! command_exists "$editor"; then
        if command_exists nano; then
            editor="nano"
        elif command_exists vi; then
            editor="vi"
        else
            log_error "未找到可用的文本编辑器"
            return 1
        fi
    fi
    
    log_info "使用 $editor 编辑配置文件..."
    
    # 编辑文件
    "$editor" "$config_file"
    
    # 验证编辑后的配置
    if validate_config "$config_file"; then
        log_success "配置文件编辑完成并验证通过"
    else
        log_error "配置文件验证失败"
        
        if confirm "是否恢复到编辑前的版本？"; then
            restore_config "$CONFIG_BACKUP_DIR/config_before_edit_$(date +%Y%m%d)*.json"
        fi
    fi
}

# 生成配置文件摘要
generate_config_summary() {
    local config_file="${1:-$CONFIG_FILE}"
    local output_file="$WORK_DIR/config-summary.txt"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    log_info "生成配置文件摘要..."
    
    cat > "$output_file" << EOF
# Sing-box 配置摘要
# 生成时间: $(date)
# 配置文件: $config_file

## 基本信息
文件大小: $(du -h "$config_file" | cut -f1)
修改时间: $(stat -c %y "$config_file" | cut -d'.' -f1)
配置版本: $CONFIG_VERSION

EOF
    
    if command_exists jq; then
        # 提取协议信息
        echo "## 启用的协议" >> "$output_file"
        jq -r '.inbounds[] | "- \(.type) (端口: \(.listen_port))"' "$config_file" 2>/dev/null >> "$output_file"
        echo "" >> "$output_file"
        
        # 提取 DNS 配置
        echo "## DNS 配置" >> "$output_file"
        jq -r '.dns.servers[] | "- \(.tag): \(.address)"' "$config_file" 2>/dev/null >> "$output_file"
        echo "" >> "$output_file"
        
        # 提取路由规则数量
        local rule_count
        rule_count=$(jq '.route.rules | length' "$config_file" 2>/dev/null)
        echo "## 路由规则" >> "$output_file"
        echo "规则数量: $rule_count" >> "$output_file"
        echo "" >> "$output_file"
    fi
    
    log_success "配置摘要已生成: $output_file"
}

# 主配置生成函数
generate_config() {
    local protocols=("$@")
    
    if [[ ${#protocols[@]} -eq 0 ]]; then
        log_error "未指定协议"
        return 1
    fi
    
    log_info "开始生成 Sing-box 配置文件..."
    
    # 备份现有配置
    if [[ -f "$CONFIG_FILE" ]]; then
        backup_config
    fi
    
    # 生成新配置
    if generate_multi_protocol_config "${protocols[@]}"; then
        # 验证配置
        if validate_config; then
            # 生成摘要
            generate_config_summary
            
            log_success "Sing-box 配置文件生成完成"
            
            # 显示配置信息
            show_config_info
            
            return 0
        else
            log_error "配置文件验证失败"
            return 1
        fi
    else
        log_error "配置文件生成失败"
        return 1
    fi
}