#!/bin/bash

# VMess WebSocket 协议配置模块
# 负责 VMess WebSocket 协议的配置生成和管理

# VMess WebSocket 相关变量
VMESS_PORT="80"
VMESS_UUID=""
VMESS_ALTID="0"
VMESS_SECURITY="auto"
VMESS_WS_PATH="/vmess"
VMESS_WS_HOST=""
VMESS_TLS_PORT="443"
VMESS_DOMAIN=""
VMESS_CERT_FILE=""
VMESS_KEY_FILE=""

# 生成 VMess UUID
generate_vmess_uuid() {
    if command_exists uuidgen; then
        uuidgen
    else
        # 使用 /proc/sys/kernel/random/uuid
        if [[ -r /proc/sys/kernel/random/uuid ]]; then
            cat /proc/sys/kernel/random/uuid
        else
            # 使用 openssl 生成
            openssl rand -hex 16 | sed 's/\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.\{12\}\)/\1-\2-\3-\4-\5/'
        fi
    fi
}

# 生成随机 WebSocket 路径
generate_ws_path() {
    local path_length=${1:-8}
    local random_string
    random_string=$(generate_random_string "$path_length")
    echo "/${random_string}"
}

# 配置 VMess WebSocket 参数
configure_vmess_websocket() {
    log_info "配置 VMess WebSocket 参数..."
    
    # 生成 UUID
    if [[ -z "$VMESS_UUID" ]]; then
        VMESS_UUID=$(generate_vmess_uuid)
        log_info "生成 UUID: $VMESS_UUID"
    fi
    
    # 生成 WebSocket 路径
    if [[ "$VMESS_WS_PATH" == "/vmess" ]]; then
        VMESS_WS_PATH=$(generate_ws_path)
        log_info "生成 WebSocket 路径: $VMESS_WS_PATH"
    fi
    
    # 检查端口可用性
    if check_port "$VMESS_PORT"; then
        log_warn "端口 $VMESS_PORT 已被占用"
        VMESS_PORT=$(get_random_port)
        log_info "使用随机端口: $VMESS_PORT"
    fi
    
    # 设置 WebSocket Host
    if [[ -z "$VMESS_WS_HOST" ]]; then
        VMESS_WS_HOST=$(get_public_ip)
        log_info "设置 WebSocket Host: $VMESS_WS_HOST"
    fi
    
    log_success "VMess WebSocket 参数配置完成"
}

# 配置 TLS 证书
configure_vmess_tls() {
    local use_tls="${1:-false}"
    
    if [[ "$use_tls" != "true" ]]; then
        log_info "跳过 TLS 配置"
        return 0
    fi
    
    log_info "配置 VMess TLS..."
    
    # 检查域名
    if [[ -z "$VMESS_DOMAIN" ]]; then
        read -p "请输入域名 (留空跳过 TLS): " VMESS_DOMAIN
        
        if [[ -z "$VMESS_DOMAIN" ]]; then
            log_info "跳过 TLS 配置"
            return 0
        fi
    fi
    
    # 设置证书路径
    VMESS_CERT_FILE="$WORK_DIR/certs/${VMESS_DOMAIN}.crt"
    VMESS_KEY_FILE="$WORK_DIR/certs/${VMESS_DOMAIN}.key"
    
    # 检查证书是否存在
    if [[ -f "$VMESS_CERT_FILE" ]] && [[ -f "$VMESS_KEY_FILE" ]]; then
        log_info "发现现有证书文件"
        
        # 验证证书
        if openssl x509 -in "$VMESS_CERT_FILE" -noout -checkend 86400 >/dev/null 2>&1; then
            log_success "证书有效"
            return 0
        else
            log_warn "证书已过期或无效"
        fi
    fi
    
    # 生成自签名证书
    log_info "生成自签名证书..."
    
    if ! generate_self_signed_cert "$VMESS_DOMAIN" "$VMESS_CERT_FILE" "$VMESS_KEY_FILE"; then
        log_error "证书生成失败"
        return 1
    fi
    
    # 检查 TLS 端口
    if check_port "$VMESS_TLS_PORT"; then
        log_warn "TLS 端口 $VMESS_TLS_PORT 已被占用"
        VMESS_TLS_PORT=$(get_random_port)
        log_info "使用随机 TLS 端口: $VMESS_TLS_PORT"
    fi
    
    log_success "VMess TLS 配置完成"
}

# 生成自签名证书
generate_self_signed_cert() {
    local domain="$1"
    local cert_file="$2"
    local key_file="$3"
    
    # 创建证书目录
    create_directory "$(dirname "$cert_file")" 755
    
    # 生成私钥
    openssl genrsa -out "$key_file" 2048 >/dev/null 2>&1
    
    # 生成证书
    openssl req -new -x509 -key "$key_file" -out "$cert_file" -days 365 \
        -subj "/C=US/ST=State/L=City/O=Organization/OU=Unit/CN=$domain" >/dev/null 2>&1
    
    # 设置权限
    chmod 600 "$key_file"
    chmod 644 "$cert_file"
    
    if [[ -f "$cert_file" ]] && [[ -f "$key_file" ]]; then
        return 0
    else
        return 1
    fi
}

# 生成 VMess WebSocket 入站配置 (无 TLS)
generate_vmess_ws_inbound() {
    cat << EOF
    {
      "type": "vmess",
      "tag": "vmess-in",
      "listen": "::",
      "listen_port": $VMESS_PORT,
      "users": [
        {
          "uuid": "$VMESS_UUID",
          "alterId": $VMESS_ALTID
        }
      ],
      "transport": {
        "type": "ws",
        "path": "$VMESS_WS_PATH",
        "headers": {
          "Host": "$VMESS_WS_HOST"
        }
      }
    }
EOF
}

# 生成 VMess WebSocket TLS 入站配置
generate_vmess_ws_tls_inbound() {
    cat << EOF
    {
      "type": "vmess",
      "tag": "vmess-tls-in",
      "listen": "::",
      "listen_port": $VMESS_TLS_PORT,
      "users": [
        {
          "uuid": "$VMESS_UUID",
          "alterId": $VMESS_ALTID
        }
      ],
      "tls": {
        "enabled": true,
        "certificate_path": "$VMESS_CERT_FILE",
        "key_path": "$VMESS_KEY_FILE"
      },
      "transport": {
        "type": "ws",
        "path": "$VMESS_WS_PATH",
        "headers": {
          "Host": "$VMESS_DOMAIN"
        }
      }
    }
EOF
}

# 生成 VMess WebSocket 客户端配置
generate_vmess_client_config() {
    local server_ip="$1"
    local use_tls="${2:-false}"
    local config_name="vmess-websocket"
    
    local server_port="$VMESS_PORT"
    local tls_config=""
    local ws_host="$VMESS_WS_HOST"
    
    if [[ "$use_tls" == "true" ]]; then
        server_port="$VMESS_TLS_PORT"
        ws_host="$VMESS_DOMAIN"
        tls_config='"tls": {
        "enabled": true,
        "server_name": "'"$VMESS_DOMAIN"'",
        "insecure": true
      },'
    fi
    
    cat << EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "experimental": {
    "clash_api": {
      "external_controller": "127.0.0.1:9090",
      "external_ui": "ui",
      "secret": "",
      "external_ui_download_url": "https://mirror.ghproxy.com/https://github.com/MetaCubeX/Yacd-meta/archive/gh-pages.zip",
      "external_ui_download_detour": "direct",
      "default_mode": "rule"
    }
  },
  "dns": {
    "servers": [
      {
        "tag": "google",
        "address": "tls://8.8.8.8",
        "strategy": "ipv4_only",
        "detour": "proxy"
      },
      {
        "tag": "local",
        "address": "223.5.5.5",
        "strategy": "ipv4_only",
        "detour": "direct"
      }
    ],
    "rules": [
      {
        "domain_suffix": [
          ".cn"
        ],
        "server": "local"
      }
    ],
    "final": "google",
    "strategy": "ipv4_only"
  },
  "inbounds": [
    {
      "type": "mixed",
      "listen": "127.0.0.1",
      "listen_port": 2080,
      "sniff": true,
      "users": []
    }
  ],
  "outbounds": [
    {
      "type": "vmess",
      "tag": "proxy",
      "server": "$server_ip",
      "server_port": $server_port,
      "uuid": "$VMESS_UUID",
      "security": "$VMESS_SECURITY",
      "alter_id": $VMESS_ALTID,
      $tls_config
      "transport": {
        "type": "ws",
        "path": "$VMESS_WS_PATH",
        "headers": {
          "Host": "$ws_host"
        }
      }
    },
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
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
        "geosite": "cn",
        "geoip": "cn",
        "outbound": "direct"
      },
      {
        "geosite": "geolocation-!cn",
        "outbound": "proxy"
      }
    ],
    "final": "proxy",
    "auto_detect_interface": true
  }
}
EOF
}

# 生成 VMess WebSocket 分享链接
generate_vmess_share_link() {
    local server_ip="$1"
    local use_tls="${2:-false}"
    local remark="${3:-VMess-WebSocket}"
    
    local server_port="$VMESS_PORT"
    local tls="none"
    local ws_host="$VMESS_WS_HOST"
    
    if [[ "$use_tls" == "true" ]]; then
        server_port="$VMESS_TLS_PORT"
        tls="tls"
        ws_host="$VMESS_DOMAIN"
    fi
    
    # 构建 VMess 配置 JSON
    local vmess_json
    vmess_json=$(cat << EOF
{
  "v": "2",
  "ps": "$remark",
  "add": "$server_ip",
  "port": "$server_port",
  "id": "$VMESS_UUID",
  "aid": "$VMESS_ALTID",
  "scy": "$VMESS_SECURITY",
  "net": "ws",
  "type": "none",
  "host": "$ws_host",
  "path": "$VMESS_WS_PATH",
  "tls": "$tls",
  "sni": "$ws_host",
  "alpn": ""
}
EOF
)
    
    # Base64 编码
    local encoded_config
    encoded_config=$(echo -n "$vmess_json" | base64 -w 0)
    
    echo "vmess://$encoded_config"
}

# 生成 VMess WebSocket QR 码
generate_vmess_qr_code() {
    local server_ip="$1"
    local use_tls="${2:-false}"
    local remark="${3:-VMess-WebSocket}"
    local output_file="${4:-$WORK_DIR/vmess-qr.png}"
    
    local share_link
    share_link=$(generate_vmess_share_link "$server_ip" "$use_tls" "$remark")
    
    if command_exists qrencode; then
        qrencode -t PNG -o "$output_file" "$share_link"
        log_success "QR 码已生成: $output_file"
    else
        log_warn "qrencode 未安装，无法生成 QR 码"
        log_info "分享链接: $share_link"
    fi
}

# 显示 VMess WebSocket 配置信息
show_vmess_config() {
    local server_ip="$1"
    local use_tls="${2:-false}"
    
    echo -e "${CYAN}=== VMess WebSocket 配置信息 ===${NC}"
    echo -e "协议: ${GREEN}VMess${NC}"
    echo -e "传输: ${GREEN}WebSocket${NC}"
    echo -e "加密: ${GREEN}$VMESS_SECURITY${NC}"
    echo -e "服务器: ${GREEN}$server_ip${NC}"
    
    if [[ "$use_tls" == "true" ]]; then
        echo -e "端口: ${GREEN}$VMESS_TLS_PORT${NC}"
        echo -e "TLS: ${GREEN}启用${NC}"
        echo -e "域名: ${GREEN}$VMESS_DOMAIN${NC}"
        echo -e "Host: ${GREEN}$VMESS_DOMAIN${NC}"
    else
        echo -e "端口: ${GREEN}$VMESS_PORT${NC}"
        echo -e "TLS: ${RED}禁用${NC}"
        echo -e "Host: ${GREEN}$VMESS_WS_HOST${NC}"
    fi
    
    echo -e "UUID: ${GREEN}$VMESS_UUID${NC}"
    echo -e "Alter ID: ${GREEN}$VMESS_ALTID${NC}"
    echo -e "路径: ${GREEN}$VMESS_WS_PATH${NC}"
    echo ""
    
    # 显示分享链接
    local share_link
    share_link=$(generate_vmess_share_link "$server_ip" "$use_tls")
    echo -e "${CYAN}分享链接:${NC}"
    echo -e "${GREEN}$share_link${NC}"
    echo ""
}

# 保存 VMess WebSocket 配置到文件
save_vmess_config() {
    local server_ip="$1"
    local use_tls="${2:-false}"
    local config_file="$WORK_DIR/vmess-websocket-config.txt"
    
    cat > "$config_file" << EOF
# VMess WebSocket 配置信息
# 生成时间: $(date)

协议: VMess
传输: WebSocket
加密: $VMESS_SECURITY
服务器: $server_ip
EOF
    
    if [[ "$use_tls" == "true" ]]; then
        cat >> "$config_file" << EOF
端口: $VMESS_TLS_PORT
TLS: 启用
域名: $VMESS_DOMAIN
Host: $VMESS_DOMAIN
EOF
    else
        cat >> "$config_file" << EOF
端口: $VMESS_PORT
TLS: 禁用
Host: $VMESS_WS_HOST
EOF
    fi
    
    cat >> "$config_file" << EOF
UUID: $VMESS_UUID
Alter ID: $VMESS_ALTID
路径: $VMESS_WS_PATH

分享链接:
$(generate_vmess_share_link "$server_ip" "$use_tls")

客户端配置文件已保存到: $WORK_DIR/vmess-client.json
EOF
    
    # 保存客户端配置
    generate_vmess_client_config "$server_ip" "$use_tls" > "$WORK_DIR/vmess-client.json"
    
    log_success "VMess WebSocket 配置已保存到: $config_file"
}

# 测试 VMess WebSocket 连接
test_vmess_connection() {
    local server_ip="$1"
    local use_tls="${2:-false}"
    
    log_info "测试 VMess WebSocket 连接..."
    
    local test_port="$VMESS_PORT"
    if [[ "$use_tls" == "true" ]]; then
        test_port="$VMESS_TLS_PORT"
    fi
    
    # 检查端口连通性
    if ! check_network_port "$server_ip" "$test_port"; then
        log_error "无法连接到 $server_ip:$test_port"
        return 1
    fi
    
    # 测试 WebSocket 握手
    local ws_test_result
    if [[ "$use_tls" == "true" ]]; then
        ws_test_result=$(timeout 5 curl -s -k -H "Upgrade: websocket" -H "Connection: Upgrade" \
            -H "Host: $VMESS_DOMAIN" "https://$server_ip:$test_port$VMESS_WS_PATH" 2>/dev/null || true)
    else
        ws_test_result=$(timeout 5 curl -s -H "Upgrade: websocket" -H "Connection: Upgrade" \
            -H "Host: $VMESS_WS_HOST" "http://$server_ip:$test_port$VMESS_WS_PATH" 2>/dev/null || true)
    fi
    
    if [[ -n "$ws_test_result" ]]; then
        log_success "WebSocket 握手测试通过"
    else
        log_warn "WebSocket 握手测试可能存在问题"
    fi
    
    log_success "VMess WebSocket 连接测试完成"
}

# 主配置函数
configure_vmess() {
    local use_tls="${1:-false}"
    
    log_info "开始配置 VMess WebSocket..."
    
    # 配置基础参数
    if ! configure_vmess_websocket; then
        return 1
    fi
    
    # 配置 TLS (如果需要)
    if ! configure_vmess_tls "$use_tls"; then
        return 1
    fi
    
    # 获取服务器 IP
    local server_ip
    server_ip=$(get_public_ip)
    
    if [[ -z "$server_ip" ]]; then
        log_error "无法获取服务器公网 IP"
        return 1
    fi
    
    # 显示配置信息
    show_vmess_config "$server_ip" "$use_tls"
    
    # 保存配置
    save_vmess_config "$server_ip" "$use_tls"
    
    # 生成 QR 码
    generate_vmess_qr_code "$server_ip" "$use_tls"
    
    # 测试连接
    test_vmess_connection "$server_ip" "$use_tls"
    
    log_success "VMess WebSocket 配置完成"
    
    return 0
}