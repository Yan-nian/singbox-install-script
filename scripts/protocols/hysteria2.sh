#!/bin/bash

# Hysteria2 协议配置模块
# 负责 Hysteria2 协议的配置生成和管理

# Hysteria2 相关变量
HY2_PORT="443"
HY2_PASSWORD=""
HY2_DOMAIN=""
HY2_CERT_FILE=""
HY2_KEY_FILE=""
HY2_OBFS_TYPE="salamander"
HY2_OBFS_PASSWORD=""
HY2_UP_MBPS="100"
HY2_DOWN_MBPS="100"
HY2_IGNORE_CLIENT_BANDWIDTH="false"
HY2_MASQUERADE_TYPE="proxy"
HY2_MASQUERADE_URL="https://www.bing.com"

# 生成 Hysteria2 密码
generate_hy2_password() {
    local length=${1:-16}
    generate_random_string "$length"
}

# 生成混淆密码
generate_obfs_password() {
    local length=${1:-8}
    generate_random_string "$length"
}

# 检测网络带宽
detect_bandwidth() {
    log_info "检测网络带宽..."
    
    # 尝试使用 speedtest-cli
    if command_exists speedtest-cli; then
        log_info "使用 speedtest-cli 检测带宽..."
        
        local speedtest_result
        speedtest_result=$(speedtest-cli --simple 2>/dev/null | grep -E "Download|Upload")
    elif command_exists ooklaserver;
        log_info "使用 ooklaserver 检测带宽..."

        local speedtest_result
        speedtest_result=$(ooklaserver --simple 2>/dev/null | grep -E "Download|Upload")
        
        if [[ -n "$speedtest_result" ]]; then
            local download_speed
            local upload_speed
            
            download_speed=$(echo "$speedtest_result" | grep "Download" | awk '{print $2}' | cut -d'.' -f1)
            upload_speed=$(echo "$speedtest_result" | grep "Upload" | awk '{print $2}' | cut -d'.' -f1)
            
            if [[ -n "$download_speed" ]] && [[ "$download_speed" -gt 0 ]]; then
                HY2_DOWN_MBPS="$download_speed"
                log_info "检测到下载带宽: ${download_speed} Mbps"
            fi
            
            if [[ -n "$upload_speed" ]] && [[ "$upload_speed" -gt 0 ]]; then
                HY2_UP_MBPS="$upload_speed"
                log_info "检测到上传带宽: ${upload_speed} Mbps"
            fi
            
            return 0
        fi
    fi
    
    # 使用默认带宽设置
    log_warn "无法自动检测带宽，使用默认设置"
    log_info "默认上传带宽: $HY2_UP_MBPS Mbps"
    log_info "默认下载带宽: $HY2_DOWN_MBPS Mbps"
}

# 配置 Hysteria2 参数
configure_hysteria2() {
    log_info "配置 Hysteria2 参数..."
    
    # 生成密码
    if [[ -z "$HY2_PASSWORD" ]]; then
        HY2_PASSWORD=$(generate_hy2_password)
        log_info "生成认证密码: $HY2_PASSWORD"
    fi
    
    # 生成混淆密码
    if [[ -z "$HY2_OBFS_PASSWORD" ]]; then
        HY2_OBFS_PASSWORD=$(generate_obfs_password)
        log_info "生成混淆密码: $HY2_OBFS_PASSWORD"
    fi
    
    # 检查端口可用性
    if check_port "$HY2_PORT"; then
        log_warn "端口 $HY2_PORT 已被占用"
        HY2_PORT=$(get_random_port)
        log_info "使用随机端口: $HY2_PORT"
    fi
    
    # 检测带宽
    detect_bandwidth
    
    log_success "Hysteria2 参数配置完成"
}

# 配置 Hysteria2 TLS 证书
configure_hysteria2_tls() {
    log_info "配置 Hysteria2 TLS 证书..."
    
    # 检查域名
    if [[ -z "$HY2_DOMAIN" ]]; then
        read -p "请输入域名 (留空使用自签名证书): " HY2_DOMAIN
    fi
    
    if [[ -z "$HY2_DOMAIN" ]]; then
        # 使用自签名证书
        HY2_DOMAIN="hysteria2.local"
        log_info "使用自签名证书域名: $HY2_DOMAIN"
    fi
    
    # 设置证书路径
    HY2_CERT_FILE="$WORK_DIR/certs/${HY2_DOMAIN}.crt"
    HY2_KEY_FILE="$WORK_DIR/certs/${HY2_DOMAIN}.key"
    
    # 检查证书是否存在
    if [[ -f "$HY2_CERT_FILE" ]] && [[ -f "$HY2_KEY_FILE" ]]; then
        log_info "发现现有证书文件"
        
        # 验证证书
        if openssl x509 -in "$HY2_CERT_FILE" -noout -checkend 86400 >/dev/null 2>&1; then
            log_success "证书有效"
            return 0
        else
            log_warn "证书已过期或无效，重新生成"
        fi
    fi
    
    # 生成自签名证书
    log_info "生成自签名证书..."
    
    if ! generate_hysteria2_cert "$HY2_DOMAIN" "$HY2_CERT_FILE" "$HY2_KEY_FILE"; then
        log_error "证书生成失败"
        return 1
    fi
    
    log_success "Hysteria2 TLS 证书配置完成"
}

# 生成 Hysteria2 自签名证书
generate_hysteria2_cert() {
    local domain="$1"
    local cert_file="$2"
    local key_file="$3"
    
    # 创建证书目录
    create_directory "$(dirname "$cert_file")" 755
    
    # 生成私钥
    openssl genrsa -out "$key_file" 2048 >/dev/null 2>&1
    
    # 创建证书配置文件
    local config_file
    config_file=$(mktemp)
    
    cat > "$config_file" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = Organization
OU = Unit
CN = $domain

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $domain
DNS.2 = *.$domain
EOF
    
    # 生成证书
    openssl req -new -x509 -key "$key_file" -out "$cert_file" -days 365 \
        -config "$config_file" -extensions v3_req >/dev/null 2>&1
    
    # 清理临时文件
    rm -f "$config_file"
    
    # 设置权限
    chmod 600 "$key_file"
    chmod 644 "$cert_file"
    
    if [[ -f "$cert_file" ]] && [[ -f "$key_file" ]]; then
        return 0
    else
        return 1
    fi
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
        "type": "$HY2_OBFS_TYPE",
        "password": "$HY2_OBFS_PASSWORD"
      },
      "up_mbps": $HY2_UP_MBPS,
      "down_mbps": $HY2_DOWN_MBPS,
      "ignore_client_bandwidth": $HY2_IGNORE_CLIENT_BANDWIDTH,
      "masquerade": {
        "type": "$HY2_MASQUERADE_TYPE",
        "url": "$HY2_MASQUERADE_URL"
      }
    }
EOF
}

# 生成 Hysteria2 客户端配置
generate_hysteria2_client_config() {
    local server_ip="$1"
    local config_name="hysteria2"
    
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
      "type": "hysteria2",
      "tag": "proxy",
      "server": "$server_ip",
      "server_port": $HY2_PORT,
      "password": "$HY2_PASSWORD",
      "tls": {
        "enabled": true,
        "server_name": "$HY2_DOMAIN",
        "insecure": true
      },
      "obfs": {
        "type": "$HY2_OBFS_TYPE",
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

# 生成 Hysteria2 分享链接
generate_hysteria2_share_link() {
    local server_ip="$1"
    local remark="${2:-Hysteria2}"
    
    # 构建 Hysteria2 链接
    local hy2_link="hysteria2://${HY2_PASSWORD}@${server_ip}:${HY2_PORT}"
    hy2_link+="?obfs=${HY2_OBFS_TYPE}"
    hy2_link+="&obfs-password=${HY2_OBFS_PASSWORD}"
    hy2_link+="&sni=${HY2_DOMAIN}"
    hy2_link+="&insecure=1"
    hy2_link+="#${remark}"
    
    echo "$hy2_link"
}

# 生成 Hysteria2 QR 码
generate_hysteria2_qr_code() {
    local server_ip="$1"
    local remark="${2:-Hysteria2}"
    local output_file="${3:-$WORK_DIR/hysteria2-qr.png}"
    
    local share_link
    share_link=$(generate_hysteria2_share_link "$server_ip" "$remark")
    
    if command_exists qrencode; then
        qrencode -t PNG -o "$output_file" "$share_link"
        log_success "QR 码已生成: $output_file"
    else
        log_warn "qrencode 未安装，无法生成 QR 码"
        log_info "分享链接: $share_link"
    fi
}

# 显示 Hysteria2 配置信息
show_hysteria2_config() {
    local server_ip="$1"
    
    echo -e "${CYAN}=== Hysteria2 配置信息 ===${NC}"
    echo -e "协议: ${GREEN}Hysteria2${NC}"
    echo -e "服务器: ${GREEN}$server_ip${NC}"
    echo -e "端口: ${GREEN}$HY2_PORT${NC}"
    echo -e "密码: ${GREEN}$HY2_PASSWORD${NC}"
    echo -e "域名: ${GREEN}$HY2_DOMAIN${NC}"
    echo -e "混淆类型: ${GREEN}$HY2_OBFS_TYPE${NC}"
    echo -e "混淆密码: ${GREEN}$HY2_OBFS_PASSWORD${NC}"
    echo -e "上传带宽: ${GREEN}$HY2_UP_MBPS Mbps${NC}"
    echo -e "下载带宽: ${GREEN}$HY2_DOWN_MBPS Mbps${NC}"
    echo -e "伪装网站: ${GREEN}$HY2_MASQUERADE_URL${NC}"
    echo ""
    
    # 显示分享链接
    local share_link
    share_link=$(generate_hysteria2_share_link "$server_ip")
    echo -e "${CYAN}分享链接:${NC}"
    echo -e "${GREEN}$share_link${NC}"
    echo ""
}

# 保存 Hysteria2 配置到文件
save_hysteria2_config() {
    local server_ip="$1"
    local config_file="$WORK_DIR/hysteria2-config.txt"
    
    cat > "$config_file" << EOF
# Hysteria2 配置信息
# 生成时间: $(date)

协议: Hysteria2
服务器: $server_ip
端口: $HY2_PORT
密码: $HY2_PASSWORD
域名: $HY2_DOMAIN
混淆类型: $HY2_OBFS_TYPE
混淆密码: $HY2_OBFS_PASSWORD
上传带宽: $HY2_UP_MBPS Mbps
下载带宽: $HY2_DOWN_MBPS Mbps
伪装网站: $HY2_MASQUERADE_URL

分享链接:
$(generate_hysteria2_share_link "$server_ip")

客户端配置文件已保存到: $WORK_DIR/hysteria2-client.json
EOF
    
    # 保存客户端配置
    generate_hysteria2_client_config "$server_ip" > "$WORK_DIR/hysteria2-client.json"
    
    log_success "Hysteria2 配置已保存到: $config_file"
}

# 测试 Hysteria2 连接
test_hysteria2_connection() {
    local server_ip="$1"
    
    log_info "测试 Hysteria2 连接..."
    
    # 检查端口连通性
    if ! check_network_port "$server_ip" "$HY2_PORT"; then
        log_error "无法连接到 $server_ip:$HY2_PORT"
        return 1
    fi
    
    # 检查 TLS 握手
    local tls_test_result
    tls_test_result=$(timeout 5 openssl s_client -connect "$server_ip:$HY2_PORT" -servername "$HY2_DOMAIN" 2>/dev/null | grep "Verification: OK")
    
    if [[ -n "$tls_test_result" ]]; then
        log_success "TLS 握手测试通过"
    else
        log_warn "TLS 握手测试可能存在问题 (使用自签名证书时正常)"
    fi
    
    log_success "Hysteria2 连接测试完成"
}

# 优化 Hysteria2 性能
optimize_hysteria2() {
    log_info "优化 Hysteria2 性能参数..."
    
    # 创建 Hysteria2 专用 sysctl 配置
    cat > /etc/sysctl.d/99-hysteria2.conf << EOF
# Hysteria2 性能优化参数

# UDP 缓冲区优化
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.rmem_default = 65536
net.core.wmem_default = 65536
net.core.netdev_max_backlog = 5000

# UDP 接收缓冲区
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192

# 连接跟踪优化
net.netfilter.nf_conntrack_udp_timeout = 30
net.netfilter.nf_conntrack_udp_timeout_stream = 180

# 防止 UDP 洪水攻击
net.ipv4.icmp_ratelimit = 1000
net.ipv4.icmp_ratemask = 6168
EOF
    
    # 应用配置
    sysctl -p /etc/sysctl.d/99-hysteria2.conf >/dev/null 2>&1 || true
    
    log_success "Hysteria2 性能优化完成"
}

# 配置防火墙规则
configure_hysteria2_firewall() {
    log_info "配置 Hysteria2 防火墙规则..."
    
    case "$FIREWALL_TYPE" in
        ufw)
            ufw allow "$HY2_PORT"/udp comment "Hysteria2" >/dev/null 2>&1
            ;;
        firewalld)
            firewall-cmd --permanent --add-port="$HY2_PORT"/udp >/dev/null 2>&1
            firewall-cmd --reload >/dev/null 2>&1
            ;;
        iptables)
            iptables -A INPUT -p udp --dport "$HY2_PORT" -j ACCEPT >/dev/null 2>&1
            # 保存 iptables 规则
            if command_exists iptables-save; then
                iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
            fi
            ;;
    esac
    
    log_success "防火墙规则配置完成"
}

# 主配置函数
configure_hysteria2() {
    log_info "开始配置 Hysteria2..."
    
    # 配置基础参数
    if ! configure_hysteria2; then
        return 1
    fi
    
    # 配置 TLS 证书
    if ! configure_hysteria2_tls; then
        return 1
    fi
    
    # 优化性能
    optimize_hysteria2
    
    # 配置防火墙
    if [[ "$FIREWALL_ACTIVE" == "true" ]]; then
        configure_hysteria2_firewall
    fi
    
    # 获取服务器 IP
    local server_ip
    server_ip=$(get_public_ip)
    
    if [[ -z "$server_ip" ]]; then
        log_error "无法获取服务器公网 IP"
        return 1
    fi
    
    # 显示配置信息
    show_hysteria2_config "$server_ip"
    
    # 保存配置
    save_hysteria2_config "$server_ip"
    
    # 生成 QR 码
    generate_hysteria2_qr_code "$server_ip"
    
    # 测试连接
    test_hysteria2_connection "$server_ip"
    
    log_success "Hysteria2 配置完成"
    
    return 0
}