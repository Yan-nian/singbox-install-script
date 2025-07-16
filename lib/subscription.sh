#!/bin/bash

# 订阅生成模块
# 提供分享链接、QR码、客户端配置和订阅链接生成功能

# 生成 VLESS Reality 分享链接
generate_vless_share_link() {
    local server_ip="${1:-$PUBLIC_IP}"
    local remark="${2:-VLESS-Reality}"
    
    if [[ -z "$VLESS_UUID" ]] || [[ -z "$VLESS_PORT" ]]; then
        log_error "VLESS 配置信息不完整"
        return 1
    fi
    
    # 构建 VLESS 链接
    local vless_link="vless://${VLESS_UUID}@${server_ip}:${VLESS_PORT}"
    vless_link+="?encryption=none"
    vless_link+="&flow=${VLESS_FLOW}"
    vless_link+="&security=reality"
    vless_link+="&sni=${VLESS_SERVER_NAME}"
    vless_link+="&fp=chrome"
    vless_link+="&pbk=${VLESS_PUBLIC_KEY}"
    vless_link+="&sid=${VLESS_SHORT_ID}"
    vless_link+="&type=tcp"
    vless_link+="&headerType=none"
    vless_link+="#${remark}"
    
    echo "$vless_link"
}

# 生成 VMess WebSocket 分享链接
generate_vmess_share_link() {
    local server_ip="${1:-$PUBLIC_IP}"
    local remark="${2:-VMess-WS}"
    
    if [[ -z "$VMESS_UUID" ]] || [[ -z "$VMESS_PORT" ]]; then
        log_error "VMess 配置信息不完整"
        return 1
    fi
    
    # 构建 VMess 配置 JSON
    local vmess_json
    vmess_json=$(cat << EOF
{
  "v": "2",
  "ps": "$remark",
  "add": "$server_ip",
  "port": "$VMESS_PORT",
  "id": "$VMESS_UUID",
  "aid": "0",
  "scy": "auto",
  "net": "ws",
  "type": "none",
  "host": "$VMESS_HOST",
  "path": "$VMESS_WS_PATH",
  "tls": "",
  "sni": "",
  "alpn": ""
}
EOF
    )
    
    # Base64 编码
    local encoded
    encoded=$(echo -n "$vmess_json" | base64 -w 0)
    
    echo "vmess://$encoded"
}

# 生成 Hysteria2 分享链接
generate_hysteria2_share_link() {
    local server_ip="${1:-$PUBLIC_IP}"
    local remark="${2:-Hysteria2}"
    
    if [[ -z "$HY2_PASSWORD" ]] || [[ -z "$HY2_PORT" ]]; then
        log_error "Hysteria2 配置信息不完整"
        return 1
    fi
    
    # 构建 Hysteria2 链接
    local hy2_link="hysteria2://${HY2_PASSWORD}@${server_ip}:${HY2_PORT}"
    hy2_link+="?obfs=salamander"
    hy2_link+="&obfs-password=${HY2_OBFS_PASSWORD}"
    hy2_link+="&sni=${HY2_DOMAIN}"
    hy2_link+="&insecure=1"
    hy2_link+="#${remark}"
    
    echo "$hy2_link"
}

# 生成所有分享链接
generate_share_links() {
    echo -e "${CYAN}=== 分享链接 ===${NC}"
    echo ""
    
    local has_config=false
    
    # VLESS Reality
    if [[ -n "$VLESS_UUID" ]]; then
        echo -e "${GREEN}VLESS Reality Vision:${NC}"
        local vless_link
        vless_link=$(generate_vless_share_link)
        echo "$vless_link"
        echo ""
        has_config=true
    fi
    
    # VMess WebSocket
    if [[ -n "$VMESS_UUID" ]]; then
        echo -e "${GREEN}VMess WebSocket:${NC}"
        local vmess_link
        vmess_link=$(generate_vmess_share_link)
        echo "$vmess_link"
        echo ""
        has_config=true
    fi
    
    # Hysteria2
    if [[ -n "$HY2_PASSWORD" ]]; then
        echo -e "${GREEN}Hysteria2:${NC}"
        local hy2_link
        hy2_link=$(generate_hysteria2_share_link)
        echo "$hy2_link"
        echo ""
        has_config=true
    fi
    
    if [[ "$has_config" == "false" ]]; then
        echo -e "${YELLOW}未找到已配置的协议${NC}"
        echo -e "${YELLOW}请先配置协议后再生成分享链接${NC}"
    fi
    
    wait_for_input
}

# 生成 QR 码
generate_qr_codes() {
    if ! command_exists qrencode; then
        echo -e "${YELLOW}qrencode 未安装，正在安装...${NC}"
        case $OS in
            ubuntu|debian)
                apt update && apt install -y qrencode
                ;;
            centos|rhel|fedora)
                if command -v dnf >/dev/null 2>&1; then
                    dnf install -y qrencode
                else
                    yum install -y qrencode
                fi
                ;;
            *)
                echo -e "${RED}无法自动安装 qrencode，请手动安装${NC}"
                wait_for_input
                return
                ;;
        esac
    fi
    
    echo -e "${CYAN}=== 生成 QR 码 ===${NC}"
    echo ""
    
    local qr_dir="$WORK_DIR/qrcodes"
    mkdir -p "$qr_dir"
    
    local has_config=false
    
    # VLESS Reality QR 码
    if [[ -n "$VLESS_UUID" ]]; then
        local vless_link
        vless_link=$(generate_vless_share_link)
        local qr_file="$qr_dir/vless-reality.png"
        
        if qrencode -t PNG -o "$qr_file" "$vless_link"; then
            echo -e "${GREEN}VLESS Reality QR 码已生成: $qr_file${NC}"
        else
            echo -e "${RED}VLESS Reality QR 码生成失败${NC}"
        fi
        has_config=true
    fi
    
    # VMess WebSocket QR 码
    if [[ -n "$VMESS_UUID" ]]; then
        local vmess_link
        vmess_link=$(generate_vmess_share_link)
        local qr_file="$qr_dir/vmess-websocket.png"
        
        if qrencode -t PNG -o "$qr_file" "$vmess_link"; then
            echo -e "${GREEN}VMess WebSocket QR 码已生成: $qr_file${NC}"
        else
            echo -e "${RED}VMess WebSocket QR 码生成失败${NC}"
        fi
        has_config=true
    fi
    
    # Hysteria2 QR 码
    if [[ -n "$HY2_PASSWORD" ]]; then
        local hy2_link
        hy2_link=$(generate_hysteria2_share_link)
        local qr_file="$qr_dir/hysteria2.png"
        
        if qrencode -t PNG -o "$qr_file" "$hy2_link"; then
            echo -e "${GREEN}Hysteria2 QR 码已生成: $qr_file${NC}"
        else
            echo -e "${RED}Hysteria2 QR 码生成失败${NC}"
        fi
        has_config=true
    fi
    
    if [[ "$has_config" == "false" ]]; then
        echo -e "${YELLOW}未找到已配置的协议${NC}"
    else
        echo ""
        echo -e "${CYAN}QR 码文件保存在: $qr_dir${NC}"
    fi
    
    wait_for_input
}

# 生成客户端配置文件
generate_client_configs() {
    echo -e "${CYAN}=== 生成客户端配置 ===${NC}"
    echo ""
    
    local client_dir="$WORK_DIR/clients"
    mkdir -p "$client_dir"
    
    local has_config=false
    
    # VLESS Reality 客户端配置
    if [[ -n "$VLESS_UUID" ]]; then
        generate_vless_client_config "$client_dir/vless-reality-client.json"
        echo -e "${GREEN}VLESS Reality 客户端配置已生成${NC}"
        has_config=true
    fi
    
    # VMess WebSocket 客户端配置
    if [[ -n "$VMESS_UUID" ]]; then
        generate_vmess_client_config "$client_dir/vmess-websocket-client.json"
        echo -e "${GREEN}VMess WebSocket 客户端配置已生成${NC}"
        has_config=true
    fi
    
    # Hysteria2 客户端配置
    if [[ -n "$HY2_PASSWORD" ]]; then
        generate_hysteria2_client_config "$client_dir/hysteria2-client.json"
        echo -e "${GREEN}Hysteria2 客户端配置已生成${NC}"
        has_config=true
    fi
    
    if [[ "$has_config" == "false" ]]; then
        echo -e "${YELLOW}未找到已配置的协议${NC}"
    else
        echo ""
        echo -e "${CYAN}客户端配置文件保存在: $client_dir${NC}"
    fi
    
    wait_for_input
}

# 生成 VLESS Reality 客户端配置
generate_vless_client_config() {
    local output_file="$1"
    
    cat > "$output_file" << EOF
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
        "domain_suffix": [".cn"],
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
      "type": "vless",
      "tag": "proxy",
      "server": "$PUBLIC_IP",
      "server_port": $VLESS_PORT,
      "uuid": "$VLESS_UUID",
      "flow": "$VLESS_FLOW",
      "tls": {
        "enabled": true,
        "server_name": "$VLESS_SERVER_NAME",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        },
        "reality": {
          "enabled": true,
          "public_key": "$VLESS_PUBLIC_KEY",
          "short_id": "$VLESS_SHORT_ID"
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

# 生成 VMess WebSocket 客户端配置
generate_vmess_client_config() {
    local output_file="$1"
    
    cat > "$output_file" << EOF
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
        "domain_suffix": [".cn"],
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
      "server": "$PUBLIC_IP",
      "server_port": $VMESS_PORT,
      "uuid": "$VMESS_UUID",
      "security": "auto",
      "alter_id": 0,
      "transport": {
        "type": "ws",
        "path": "$VMESS_WS_PATH",
        "headers": {
          "Host": "$VMESS_HOST"
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

# 生成 Hysteria2 客户端配置
generate_hysteria2_client_config() {
    local output_file="$1"
    
    cat > "$output_file" << EOF
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
        "domain_suffix": [".cn"],
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
      "type": "hysteria2",
      "tag": "proxy",
      "server": "$PUBLIC_IP",
      "server_port": $HY2_PORT,
      "password": "$HY2_PASSWORD",
      "tls": {
        "enabled": true,
        "server_name": "$HY2_DOMAIN",
        "insecure": true
      },
      "obfs": {
        "type": "salamander",
        "password": "$HY2_OBFS_PASSWORD"
      },
      "up_mbps": $HY2_UP_MBPS,
      "down_mbps": $HY2_DOWN_MBPS
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

# 生成订阅链接
generate_subscription() {
    echo -e "${CYAN}=== 生成订阅链接 ===${NC}"
    echo ""
    
    local sub_dir="$WORK_DIR/subscription"
    mkdir -p "$sub_dir"
    
    local sub_file="$sub_dir/subscription.txt"
    local sub_content=""
    
    # 收集所有分享链接
    if [[ -n "$VLESS_UUID" ]]; then
        local vless_link
        vless_link=$(generate_vless_share_link)
        sub_content+="$vless_link\n"
    fi
    
    if [[ -n "$VMESS_UUID" ]]; then
        local vmess_link
        vmess_link=$(generate_vmess_share_link)
        sub_content+="$vmess_link\n"
    fi
    
    if [[ -n "$HY2_PASSWORD" ]]; then
        local hy2_link
        hy2_link=$(generate_hysteria2_share_link)
        sub_content+="$hy2_link\n"
    fi
    
    if [[ -z "$sub_content" ]]; then
        echo -e "${YELLOW}未找到已配置的协议${NC}"
        wait_for_input
        return
    fi
    
    # 写入订阅文件
    echo -e "$sub_content" > "$sub_file"
    
    # Base64 编码订阅内容
    local encoded_sub
    encoded_sub=$(base64 -w 0 "$sub_file")
    
    local encoded_file="$sub_dir/subscription_base64.txt"
    echo "$encoded_sub" > "$encoded_file"
    
    echo -e "${GREEN}订阅文件已生成:${NC}"
    echo -e "  原始文件: $sub_file"
    echo -e "  Base64 编码: $encoded_file"
    echo ""
    
    echo -e "${CYAN}订阅链接内容:${NC}"
    echo "$encoded_sub"
    echo ""
    
    echo -e "${YELLOW}提示: 将 Base64 编码内容部署到 Web 服务器即可作为订阅链接使用${NC}"
    
    wait_for_input
}

# 从配置文件中提取协议信息
extract_config_info() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_warn "配置文件不存在: $CONFIG_FILE"
        return 1
    fi
    
    if ! command_exists jq; then
        log_warn "jq 未安装，无法解析配置文件"
        return 1
    fi
    
    # 提取 VLESS 配置
    local vless_inbound
    vless_inbound=$(jq -r '.inbounds[] | select(.type == "vless")' "$CONFIG_FILE" 2>/dev/null)
    if [[ -n "$vless_inbound" ]] && [[ "$vless_inbound" != "null" ]]; then
        VLESS_UUID=$(echo "$vless_inbound" | jq -r '.users[0].uuid' 2>/dev/null)
        VLESS_PORT=$(echo "$vless_inbound" | jq -r '.listen_port' 2>/dev/null)
        VLESS_FLOW=$(echo "$vless_inbound" | jq -r '.users[0].flow' 2>/dev/null)
        VLESS_SERVER_NAME=$(echo "$vless_inbound" | jq -r '.tls.server_name' 2>/dev/null)
        VLESS_PUBLIC_KEY=$(echo "$vless_inbound" | jq -r '.tls.reality.public_key' 2>/dev/null)
        VLESS_SHORT_ID=$(echo "$vless_inbound" | jq -r '.tls.reality.short_id[0]' 2>/dev/null)
    fi
    
    # 提取 VMess 配置
    local vmess_inbound
    vmess_inbound=$(jq -r '.inbounds[] | select(.type == "vmess")' "$CONFIG_FILE" 2>/dev/null)
    if [[ -n "$vmess_inbound" ]] && [[ "$vmess_inbound" != "null" ]]; then
        VMESS_UUID=$(echo "$vmess_inbound" | jq -r '.users[0].uuid' 2>/dev/null)
        VMESS_PORT=$(echo "$vmess_inbound" | jq -r '.listen_port' 2>/dev/null)
        VMESS_WS_PATH=$(echo "$vmess_inbound" | jq -r '.transport.path' 2>/dev/null)
        VMESS_HOST=$(echo "$vmess_inbound" | jq -r '.transport.headers.Host' 2>/dev/null)
    fi
    
    # 提取 Hysteria2 配置
    local hy2_inbound
    hy2_inbound=$(jq -r '.inbounds[] | select(.type == "hysteria2")' "$CONFIG_FILE" 2>/dev/null)
    if [[ -n "$hy2_inbound" ]] && [[ "$hy2_inbound" != "null" ]]; then
        HY2_PASSWORD=$(echo "$hy2_inbound" | jq -r '.users[0].password' 2>/dev/null)
        HY2_PORT=$(echo "$hy2_inbound" | jq -r '.listen_port' 2>/dev/null)
        HY2_OBFS_PASSWORD=$(echo "$hy2_inbound" | jq -r '.obfs.password' 2>/dev/null)
        HY2_UP_MBPS=$(echo "$hy2_inbound" | jq -r '.up_mbps' 2>/dev/null)
        HY2_DOWN_MBPS=$(echo "$hy2_inbound" | jq -r '.down_mbps' 2>/dev/null)
        
        # 从证书文件路径推断域名
        local cert_path
        cert_path=$(echo "$hy2_inbound" | jq -r '.tls.certificate_path' 2>/dev/null)
        if [[ -n "$cert_path" ]] && [[ "$cert_path" != "null" ]]; then
            HY2_DOMAIN=$(basename "$cert_path" .crt)
        fi
    fi
    
    log_info "配置信息提取完成"
}