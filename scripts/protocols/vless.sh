#!/bin/bash

# VLESS Reality Vision 协议配置模块
# 负责 VLESS Reality Vision 协议的配置生成和管理

# VLESS Reality 相关变量
VLESS_PORT="443"
VLESS_UUID=""
VLESS_DEST="www.microsoft.com:443"
VLESS_SERVER_NAME="www.microsoft.com"
VLESS_PRIVATE_KEY=""
VLESS_PUBLIC_KEY=""
VLESS_SHORT_ID=""

# 生成 VLESS UUID
generate_vless_uuid() {
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

# 生成 Reality 密钥对
generate_reality_keypair() {
    log_info "生成 Reality 密钥对..."
    
    # 使用 sing-box 生成密钥对
    local keypair_output
    keypair_output=$($SINGBOX_BINARY generate reality-keypair 2>/dev/null)
    
    if [[ -z "$keypair_output" ]]; then
        log_error "生成 Reality 密钥对失败"
        return 1
    fi
    
    # 解析密钥对
    VLESS_PRIVATE_KEY=$(echo "$keypair_output" | grep "PrivateKey:" | awk '{print $2}')
    VLESS_PUBLIC_KEY=$(echo "$keypair_output" | grep "PublicKey:" | awk '{print $2}')
    
    if [[ -z "$VLESS_PRIVATE_KEY" ]] || [[ -z "$VLESS_PUBLIC_KEY" ]]; then
        log_error "解析 Reality 密钥对失败"
        return 1
    fi
    
    log_success "Reality 密钥对生成成功"
    log_debug "私钥: $VLESS_PRIVATE_KEY"
    log_debug "公钥: $VLESS_PUBLIC_KEY"
}

# 生成 Reality Short ID
generate_reality_short_id() {
    # 生成 8 位随机十六进制字符串
    openssl rand -hex 4
}

# 检测可用的 Reality 目标网站
detect_reality_targets() {
    log_info "检测可用的 Reality 目标网站..."
    
    local targets=(
        "www.microsoft.com:443"
        "www.apple.com:443"
        "www.cloudflare.com:443"
        "www.amazon.com:443"
        "www.google.com:443",
        "github.com:443",
        "www.tesla.com:443",
        "www.nvidia.com:443",
        "www.bing.com:443",
        "www.yahoo.com:443"
    )
    
    local available_targets=()
    
    for target in "${targets[@]}"; do
        local host=${target%:*}
        local port=${target#*:}
        
        # 检查连通性
        if timeout 5 bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
            available_targets+=("$target")
            log_debug "目标网站可用: $target"
        else
            log_debug "目标网站不可用: $target"
        fi
    done
    
    if [[ ${#available_targets[@]} -eq 0 ]]; then
        log_warn "未检测到可用的 Reality 目标网站，使用默认配置"
        VLESS_DEST="www.microsoft.com:443"
        VLESS_SERVER_NAME="www.microsoft.com"
    else
        # 随机选择一个可用目标
        local random_index=$((RANDOM % ${#available_targets[@]}))
        VLESS_DEST="${available_targets[$random_index]}"
        VLESS_SERVER_NAME="${VLESS_DEST%:*}"
        
        log_info "选择 Reality 目标: $VLESS_DEST"
    fi
}

# 配置 VLESS Reality 参数
configure_vless_reality() {
    log_info "配置 VLESS Reality Vision 参数..."
    
    # 生成 UUID
    if [[ -z "$VLESS_UUID" ]]; then
        VLESS_UUID=$(generate_vless_uuid)
        log_info "生成 UUID: $VLESS_UUID"
    fi
    
    # 生成密钥对
    if [[ -z "$VLESS_PRIVATE_KEY" ]] || [[ -z "$VLESS_PUBLIC_KEY" ]]; then
        if ! generate_reality_keypair; then
            return 1
        fi
    fi
    
    # 生成 Short ID
    if [[ -z "$VLESS_SHORT_ID" ]]; then
        VLESS_SHORT_ID=$(generate_reality_short_id)
        log_info "生成 Short ID: $VLESS_SHORT_ID"
    fi
    
    # 检测目标网站
    detect_reality_targets
    
    # 检查端口可用性
    if check_port "$VLESS_PORT"; then
        log_warn "端口 $VLESS_PORT 已被占用"
        VLESS_PORT=$(get_random_port)
        log_info "使用随机端口: $VLESS_PORT"
    fi
    
    log_success "VLESS Reality Vision 参数配置完成"
}

# 生成 VLESS Reality 入站配置
generate_vless_inbound() {
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
            "server": "$VLESS_DEST",
            "server_port": ${VLESS_DEST#*:}
          },
          "private_key": "$VLESS_PRIVATE_KEY",
          "short_id": [
            "$VLESS_SHORT_ID"
          ]
        }
      }
    }
EOF
}

# 生成 VLESS Reality 客户端配置
generate_vless_client_config() {
    local server_ip="$1"
    local config_name="vless-reality-vision"
    
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
      "type": "vless",
      "tag": "proxy",
      "server": "$server_ip",
      "server_port": $VLESS_PORT,
      "uuid": "$VLESS_UUID",
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
    "final": "proxy"
  }
}
EOF
}

# 生成 VLESS Reality 分享链接
generate_vless_share_link() {
    local server_ip="$1"
    local remark="${2:-VLESS-Reality-Vision}"
    
    # 构建 VLESS 链接
    local vless_link="vless://${VLESS_UUID}@${server_ip}:${VLESS_PORT}"
    vless_link+="?encryption=none"
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

# 生成 VLESS Reality QR 码
generate_vless_qr_code() {
    local server_ip="$1"
    local remark="${2:-VLESS-Reality-Vision}"
    local output_file="${3:-$WORK_DIR/vless-qr.png}"
    
    local share_link
    share_link=$(generate_vless_share_link "$server_ip" "$remark")
    
    # 终端显示二维码
    if command -v qrcode-terminal >/dev/null 2>&1; then
        echo -e "${CYAN}VLESS Reality 二维码 (终端显示):${NC}"
        qrcode-terminal "$share_link" --small
        echo ""
    fi
    
    # 生成文件二维码
    if command_exists qrencode; then
        qrencode -t PNG -o "$output_file" "$share_link"
        log_success "QR 码已生成: $output_file"
    else
        log_warn "qrencode 未安装，无法生成 QR 码"
        log_info "分享链接: $share_link"
    fi
}

# 显示 VLESS Reality 配置信息
show_vless_config() {
    local server_ip="$1"
    
    echo -e "${CYAN}=== VLESS Reality 配置信息 ===${NC}"
    echo -e "协议: ${GREEN}VLESS${NC}"
    echo -e "传输: ${GREEN}TCP${NC}"
    echo -e "加密: ${GREEN}Reality${NC}"
    echo -e "服务器: ${GREEN}$server_ip${NC}"
    echo -e "端口: ${GREEN}$VLESS_PORT${NC}"
    echo -e "UUID: ${GREEN}$VLESS_UUID${NC}"
    echo -e "SNI: ${GREEN}$VLESS_SERVER_NAME${NC}"
    echo -e "公钥: ${GREEN}$VLESS_PUBLIC_KEY${NC}"
    echo -e "Short ID: ${GREEN}$VLESS_SHORT_ID${NC}"
    echo -e "目标网站: ${GREEN}$VLESS_DEST${NC}"
    echo ""
    
    # 显示分享链接
    local share_link
    share_link=$(generate_vless_share_link "$server_ip")
    echo -e "${CYAN}分享链接:${NC}"
    echo -e "${GREEN}$share_link${NC}"
    echo ""
}

# 保存 VLESS Reality 配置到文件
save_vless_config() {
    local server_ip="$1"
    local config_file="$WORK_DIR/vless-reality-config.txt"
    
    cat > "$config_file" << EOF
# VLESS Reality 配置信息
# 生成时间: $(date)

协议: VLESS
传输: TCP
加密: Reality
服务器: $server_ip
端口: $VLESS_PORT
UUID: $VLESS_UUID
SNI: $VLESS_SERVER_NAME
公钥: $VLESS_PUBLIC_KEY
Short ID: $VLESS_SHORT_ID
目标网站: $VLESS_DEST

分享链接:
$(generate_vless_share_link "$server_ip")

客户端配置文件已保存到: $WORK_DIR/vless-client.json
EOF
    
    # 保存客户端配置
    generate_vless_client_config "$server_ip" > "$WORK_DIR/vless-client.json"
    
    log_success "VLESS Reality 配置已保存到: $config_file"
}

# 测试 VLESS Reality 连接
test_vless_connection() {
    local server_ip="$1"
    
    log_info "测试 VLESS Reality 连接..."
    
    # 检查端口连通性
    if ! check_network_port "$server_ip" "$VLESS_PORT"; then
        log_error "无法连接到 $server_ip:$VLESS_PORT"
        return 1
    fi
    
    # 检查 Reality 握手
    local test_result
    test_result=$(timeout 10 openssl s_client -connect "$VLESS_DEST" -servername "$VLESS_SERVER_NAME" -verify_return_error 2>/dev/null | grep "Verification: OK")
    
    if [[ -n "$test_result" ]]; then
        log_success "Reality 目标网站连接正常"
    else
        log_warn "Reality 目标网站连接可能存在问题"
    fi
    
    log_success "VLESS Reality 连接测试完成"
}

# 主配置函数
configure_vless() {
    log_info "开始配置 VLESS Reality Vision..."
    
    # 配置参数
    if ! configure_vless_reality; then
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
    show_vless_config "$server_ip"
    
    # 保存配置
    save_vless_config "$server_ip"
    
    # 生成 QR 码
    generate_vless_qr_code "$server_ip"
    
    # 测试连接
    test_vless_connection "$server_ip"
    
    log_success "VLESS Reality Vision 配置完成"
    
    return 0
}