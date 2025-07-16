#!/bin/bash

# 协议配置模块
# 支持 VLESS Reality、VMess WebSocket、Hysteria2

# 协议变量
VLESS_UUID=""
VLESS_PORT="10443"
# VLESS_FLOW="xtls-rprx-vision"  # Reality模式不支持flow字段
VLESS_PRIVATE_KEY=""
VLESS_PUBLIC_KEY=""
VLESS_SHORT_ID=""
VLESS_TARGET="www.yahoo.com:443"
VLESS_SERVER_NAME="www.yahoo.com"

VMESS_UUID=""
VMESS_PORT="10080"
VMESS_WS_PATH=""
VMESS_HOST=""

HY2_PASSWORD=""
HY2_PORT="36712"
HY2_OBFS_PASSWORD=""
HY2_UP_MBPS="100"
HY2_DOWN_MBPS="100"
HY2_DOMAIN=""
HY2_CERT_FILE=""
HY2_KEY_FILE=""

# VLESS Reality 配置函数

# 生成 Reality 密钥对
generate_reality_keypair() {
    local keypair
    
    # 检查 sing-box 二进制文件是否存在
    if [[ ! -f "$SINGBOX_BINARY" ]]; then
        log_error "Sing-box 二进制文件不存在: $SINGBOX_BINARY"
        return 1
    fi
    
    keypair=$($SINGBOX_BINARY generate reality-keypair 2>/dev/null)
    
    if [[ -n "$keypair" ]]; then
        VLESS_PRIVATE_KEY=$(echo "$keypair" | grep "PrivateKey" | awk '{print $2}')
        VLESS_PUBLIC_KEY=$(echo "$keypair" | grep "PublicKey" | awk '{print $2}')
        
        # 验证密钥格式
        if [[ -n "$VLESS_PRIVATE_KEY" ]] && [[ -n "$VLESS_PUBLIC_KEY" ]]; then
            log_success "Reality 密钥对生成成功"
            log_debug "Private Key: $VLESS_PRIVATE_KEY"
            log_debug "Public Key: $VLESS_PUBLIC_KEY"
        else
            log_error "密钥对格式验证失败"
            return 1
        fi
    else
        log_error "Reality 密钥对生成失败"
        return 1
    fi
}

# 生成 Reality Short ID
generate_reality_short_id() {
    VLESS_SHORT_ID=$(openssl rand -hex 8)
    log_info "生成 Short ID: $VLESS_SHORT_ID"
}

# 检测可用的 Reality 目标
detect_reality_target() {
    local targets=(
        "www.yahoo.com:443"
        "www.microsoft.com:443"
        "www.cloudflare.com:443"
        "www.apple.com:443"
        "www.amazon.com:443"
        "www.google.com:443"
    )
    
    log_info "检测可用的 Reality 目标..."
    
    # 优先使用 yahoo.com，因为它在大多数地区都可访问
    local priority_target="www.yahoo.com:443"
    local host port
    host=$(echo "$priority_target" | cut -d':' -f1)
    port=$(echo "$priority_target" | cut -d':' -f2)
    
    if timeout 5 bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
        VLESS_TARGET="$priority_target"
        VLESS_SERVER_NAME="$host"
        log_success "选择 Reality 目标: $priority_target"
        return 0
    fi
    
    # 如果优先目标不可用，测试其他目标
    for target in "${targets[@]}"; do
        [[ "$target" == "$priority_target" ]] && continue
        host=$(echo "$target" | cut -d':' -f1)
        port=$(echo "$target" | cut -d':' -f2)
        
        if timeout 5 bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
            VLESS_TARGET="$target"
            VLESS_SERVER_NAME="$host"
            log_success "选择 Reality 目标: $target"
            return 0
        fi
    done
    
    log_warn "无法连接到预设目标，使用默认配置"
    VLESS_TARGET="www.yahoo.com:443"
    VLESS_SERVER_NAME="www.yahoo.com"
}

# 配置 VLESS Reality
configure_vless_reality() {
    log_info "配置 VLESS Reality Vision..."
    
    # 生成 UUID
    if [[ -z "$VLESS_UUID" ]]; then
        VLESS_UUID=$(generate_uuid)
        log_info "生成 UUID: $VLESS_UUID"
    fi
    
    # 检查端口
    if check_port "$VLESS_PORT"; then
        log_warn "端口 $VLESS_PORT 已被占用"
        VLESS_PORT=$(get_random_port)
        log_info "使用随机端口: $VLESS_PORT"
    fi
    
    # 确保使用高端口
    if [ "$VLESS_PORT" -lt 10000 ]; then
        log_warn "VLESS端口 $VLESS_PORT 低于10000，重新分配高端口"
        VLESS_PORT=$(get_random_port)
        log_info "VLESS高端口: $VLESS_PORT"
    fi
    
    # 生成密钥对
    if [[ -z "$VLESS_PRIVATE_KEY" ]] || [[ -z "$VLESS_PUBLIC_KEY" ]]; then
        generate_reality_keypair
    fi
    
    # 生成 Short ID
    if [[ -z "$VLESS_SHORT_ID" ]]; then
        generate_reality_short_id
    fi
    
    # 检测目标
    detect_reality_target
    
    log_success "VLESS Reality 配置完成"
}

# 生成 VLESS Reality 入站配置
generate_vless_reality_inbound() {
    cat << EOF
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": $VLESS_PORT,
      "users": [
        {
          "uuid": "$VLESS_UUID"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$VLESS_SERVER_NAME",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "$VLESS_TARGET",
            "server_port": $(echo "$VLESS_TARGET" | cut -d':' -f2)
          },
          "private_key": "$VLESS_PRIVATE_KEY",
          "short_id": ["$VLESS_SHORT_ID"]
        }
      }
    }
EOF
}

# VMess WebSocket 配置函数

# 配置 VMess WebSocket
configure_vmess_websocket() {
    log_info "配置 VMess WebSocket..."
    
    # 生成 UUID
    if [[ -z "$VMESS_UUID" ]]; then
        VMESS_UUID=$(generate_uuid)
        log_info "生成 UUID: $VMESS_UUID"
    fi
    
    # 生成 WebSocket 路径
    if [[ -z "$VMESS_WS_PATH" ]]; then
        VMESS_WS_PATH="/$(generate_random_string 8)"
        log_info "生成 WebSocket 路径: $VMESS_WS_PATH"
    fi
    
    # 检查端口
    if check_port "$VMESS_PORT"; then
        log_warn "端口 $VMESS_PORT 已被占用"
        VMESS_PORT=$(get_random_port)
        log_info "使用随机端口: $VMESS_PORT"
    fi
    
    # 确保使用高端口
    if [ "$VMESS_PORT" -lt 10000 ]; then
        log_warn "VMess端口 $VMESS_PORT 低于10000，重新分配高端口"
        VMESS_PORT=$(get_random_port)
        log_info "VMess高端口: $VMESS_PORT"
    fi
    
    # 设置 Host
    if [[ -z "$VMESS_HOST" ]]; then
        VMESS_HOST="$PUBLIC_IP"
        log_info "设置 Host: $VMESS_HOST"
    fi
    
    log_success "VMess WebSocket 配置完成"
}

# 生成 VMess WebSocket 入站配置
generate_vmess_websocket_inbound() {
    cat << EOF
    {
      "type": "vmess",
      "tag": "vmess-in",
      "listen": "::",
      "listen_port": $VMESS_PORT,
      "users": [
        {
          "uuid": "$VMESS_UUID",
          "alterId": 0
        }
      ],
      "transport": {
        "type": "ws",
        "path": "$VMESS_WS_PATH",
        "headers": {
          "Host": "$VMESS_HOST"
        }
      }
    }
EOF
}

# Hysteria2 配置函数

# 生成自签名证书
generate_self_signed_cert() {
    local domain="$1"
    local cert_file="$2"
    local key_file="$3"
    
    # 创建证书目录
    mkdir -p "$(dirname "$cert_file")"
    
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

# 配置 Hysteria2
configure_hysteria2() {
    log_info "配置 Hysteria2..."
    
    # 生成密码
    if [[ -z "$HY2_PASSWORD" ]]; then
        HY2_PASSWORD=$(generate_random_string 16)
        log_info "生成认证密码: $HY2_PASSWORD"
    fi
    
    # 生成混淆密码
    if [[ -z "$HY2_OBFS_PASSWORD" ]]; then
        HY2_OBFS_PASSWORD=$(generate_random_string 8)
        log_info "生成混淆密码: $HY2_OBFS_PASSWORD"
    fi
    
    # 检查端口
    if check_port "$HY2_PORT"; then
        log_warn "端口 $HY2_PORT 已被占用"
        HY2_PORT=$(get_random_port)
        log_info "使用随机端口: $HY2_PORT"
    fi
    
    # 确保使用高端口
    if [ "$HY2_PORT" -lt 10000 ]; then
        log_warn "Hysteria2端口 $HY2_PORT 低于10000，重新分配高端口"
        HY2_PORT=$(get_random_port)
        log_info "Hysteria2高端口: $HY2_PORT"
    fi
    
    # 设置域名和证书
    if [[ -z "$HY2_DOMAIN" ]]; then
        HY2_DOMAIN="hysteria2.local"
    fi
    
    HY2_CERT_FILE="$WORK_DIR/certs/${HY2_DOMAIN}.crt"
    HY2_KEY_FILE="$WORK_DIR/certs/${HY2_DOMAIN}.key"
    
    # 生成自签名证书
    if [[ ! -f "$HY2_CERT_FILE" ]] || [[ ! -f "$HY2_KEY_FILE" ]]; then
        log_info "生成自签名证书..."
        if generate_self_signed_cert "$HY2_DOMAIN" "$HY2_CERT_FILE" "$HY2_KEY_FILE"; then
            log_success "证书生成成功"
        else
            log_error "证书生成失败"
            return 1
        fi
    fi
    
    log_success "Hysteria2 配置完成"
}

# 生成 Hysteria2 入站配置
generate_hysteria2_inbound() {
    cat << EOF
    {
      "type": "hysteria2",
      "tag": "hy2-in",
      "listen": "::",
      "listen_port": $HY2_PORT,
      "users": [
        {
          "password": "$HY2_PASSWORD"
        }
      ],
      "tls": {
        "enabled": true,
        "certificate_path": "$HY2_CERT_FILE",
        "key_path": "$HY2_KEY_FILE"
      },
      "obfs": {
        "type": "salamander",
        "password": "$HY2_OBFS_PASSWORD"
      },
      "up_mbps": $HY2_UP_MBPS,
      "down_mbps": $HY2_DOWN_MBPS,
      "ignore_client_bandwidth": false,
      "masquerade": {
        "type": "proxy",
        "url": "https://www.bing.com"
      }
    }
EOF
}

# 生成完整配置文件
generate_config() {
    local protocols=("$@")
    local inbounds=()
    
    log_info "生成配置文件..."
    
    # 根据选择的协议生成入站配置
    for protocol in "${protocols[@]}"; do
        case "$protocol" in
            "vless")
                configure_vless_reality
                inbounds+=("$(generate_vless_reality_inbound)")
                ;;
            "vmess")
                configure_vmess_websocket
                inbounds+=("$(generate_vmess_websocket_inbound)")
                ;;
            "hysteria2")
                configure_hysteria2
                inbounds+=("$(generate_hysteria2_inbound)")
                ;;
        esac
    done
    
    # 生成完整配置
    cat > "$CONFIG_FILE" << EOF
{
  "log": {
    "disabled": false,
    "level": "error",
    "output": "$LOG_FILE",
    "timestamp": true
  },
  "dns": {
    "rules": [
      {
        "rule_set": ["geosite-cn"],
        "server": "local"
      },
      {
        "rule_set": ["category-ads-all"],
        "server": "block"
      }
    ],
    "servers": [
      {
        "address": "https://1.1.1.1/dns-query",
        "detour": "direct",
        "tag": "remote"
      },
      {
        "address": "https://223.5.5.5/dns-query",
        "detour": "direct",
        "tag": "local"
      },
      {
        "address": "rcode://success",
        "tag": "block"
      }
    ],
    "final": "remote",
    "strategy": "prefer_ipv4"
  },
  "experimental": {
    "cache_file": {
      "enabled": true
    }
  },
  "inbounds": [
$(IFS=','; echo "${inbounds[*]}")
  ],
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
    "auto_detect_interface": true,
    "rules": [
      {
        "action": "sniff"
      },
      {
        "protocol": "dns",
        "action": "hijack-dns"
      },
      {
        "rule_set": ["geosite-cn"],
        "outbound": "direct"
      },
      {
        "ip_is_private": true,
        "outbound": "direct"
      },
      {
        "rule_set": ["category-ads-all"],
        "action": "reject"
      }
    ],
    "rule_set": [
      {
        "tag": "geosite-cn",
        "type": "remote",
        "format": "binary",
        "url": "https://fastly.jsdelivr.net/gh/SagerNet/sing-geosite@rule-set/geosite-cn.srs",
        "download_detour": "direct"
      },
      {
        "tag": "category-ads-all",
        "type": "remote",
        "format": "binary",
        "url": "https://fastly.jsdelivr.net/gh/SagerNet/sing-geosite@rule-set/geosite-category-ads-all.srs",
        "download_detour": "direct"
      }
    ],
    "final": "direct"
  }
}
EOF
    
    # 验证配置文件
    if validate_json "$CONFIG_FILE"; then
        log_success "配置文件生成成功: $CONFIG_FILE"
        return 0
    else
        log_error "配置文件格式错误"
        return 1
    fi
}

# 显示协议配置信息
show_protocol_info() {
    local protocol="$1"
    
    echo -e "${CYAN}=== $protocol 配置信息 ===${NC}"
    
    case "$protocol" in
        "VLESS Reality")
            echo -e "协议: ${GREEN}VLESS Reality Vision${NC}"
            echo -e "服务器: ${GREEN}$PUBLIC_IP${NC}"
            echo -e "端口: ${GREEN}$VLESS_PORT${NC}"
            echo -e "UUID: ${GREEN}$VLESS_UUID${NC}"
            # echo -e "Flow: ${GREEN}$VLESS_FLOW${NC}"  # Reality模式不使用flow字段
            echo -e "Public Key: ${GREEN}$VLESS_PUBLIC_KEY${NC}"
            echo -e "Short ID: ${GREEN}$VLESS_SHORT_ID${NC}"
            echo -e "SNI: ${GREEN}$VLESS_SERVER_NAME${NC}"
            ;;
        "VMess WebSocket")
            echo -e "协议: ${GREEN}VMess WebSocket${NC}"
            echo -e "服务器: ${GREEN}$PUBLIC_IP${NC}"
            echo -e "端口: ${GREEN}$VMESS_PORT${NC}"
            echo -e "UUID: ${GREEN}$VMESS_UUID${NC}"
            echo -e "路径: ${GREEN}$VMESS_WS_PATH${NC}"
            echo -e "Host: ${GREEN}$VMESS_HOST${NC}"
            ;;
        "Hysteria2")
            echo -e "协议: ${GREEN}Hysteria2${NC}"
            echo -e "服务器: ${GREEN}$PUBLIC_IP${NC}"
            echo -e "端口: ${GREEN}$HY2_PORT${NC}"
            echo -e "密码: ${GREEN}$HY2_PASSWORD${NC}"
            echo -e "混淆密码: ${GREEN}$HY2_OBFS_PASSWORD${NC}"
            echo -e "域名: ${GREEN}$HY2_DOMAIN${NC}"
            ;;
    esac
    
    echo -e "${CYAN}================================${NC}"
}