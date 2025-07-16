#!/bin/bash

# 测试客户端配置生成功能
# 这是一个独立的测试脚本

# 模拟配置数据
cat > /tmp/test_config.db << 'EOF'
vless-test|vless-reality|63103|0c216e0f-944c-4770-874e-c819eda5a51e|private_key|QhCEpq9JbLLKd3LqG65shu_w7avFnST9AYMOzpSolCY|9c6d6b1a|www.yahoo.com|2025-07-17
vmess-test|vmess|25341|0c216e0f-944c-4770-874e-c819eda5a51e|0c216e0f-944c-4770-874e-c819eda5a51e-vm|www.bing.com|2025-07-17
hy2-test|hysteria2|36107|0c216e0f-944c-4770-874e-c819eda5a51e|www.bing.com|2025-07-17
tuic5-test|tuic5|22482|0c216e0f-944c-4770-874e-c819eda5a51e|www.bing.com|0c216e0f-944c-4770-874e-c819eda5a51e|2025-07-17
EOF

# 测试客户端配置生成
echo "=== 测试客户端配置生成 ==="
echo

# 模拟函数
get_public_ip() {
    echo "46.3.36.155"
}

list_configs_from_db() {
    cat /tmp/test_config.db
}

# 生成客户端配置
generate_client_config() {
    local server_ip=$(get_public_ip)
    local configs=$(list_configs_from_db)
    
    if [[ -z $configs ]]; then
        echo "Error: 暂无配置"
        return 1
    fi
    
    # 生成 outbounds 配置
    local outbounds_json=""
    local outbound_names=""
    
    while IFS='|' read -r name protocol port uuid extra1 extra2 extra3 extra4 created; do
        if [[ -n "$name" ]]; then
            # 添加到选择器列表
            if [[ -n "$outbound_names" ]]; then
                outbound_names="$outbound_names, \"$name\""
            else
                outbound_names="\"$name\""
            fi
            
            # 生成对应的 outbound 配置
            case "$protocol" in
                "vless-reality")
                    local public_key="$extra2"
                    local short_id="$extra3"
                    local sni="$extra4"
                    
                    outbounds_json="$outbounds_json,
    {
      \"type\": \"vless\",
      \"tag\": \"$name\",
      \"server\": \"$server_ip\",
      \"server_port\": $port,
      \"uuid\": \"$uuid\",
      \"packet_encoding\": \"xudp\",
      \"flow\": \"xtls-rprx-vision\",
      \"tls\": {
        \"enabled\": true,
        \"server_name\": \"$sni\",
        \"utls\": {
          \"enabled\": true,
          \"fingerprint\": \"chrome\"
        },
        \"reality\": {
          \"enabled\": true,
          \"public_key\": \"$public_key\",
          \"short_id\": \"$short_id\"
        }
      }
    }"
                    ;;
                "vmess")
                    local path="$extra1"
                    local domain="$extra2"
                    
                    outbounds_json="$outbounds_json,
    {
      \"type\": \"vmess\",
      \"tag\": \"$name\",
      \"server\": \"$server_ip\",
      \"server_port\": $port,
      \"uuid\": \"$uuid\",
      \"security\": \"auto\",
      \"packet_encoding\": \"packetaddr\",
      \"transport\": {
        \"type\": \"ws\",
        \"path\": \"$path\",
        \"headers\": {
          \"Host\": [\"$domain\"]
        }
      },
      \"tls\": {
        \"enabled\": false,
        \"server_name\": \"$domain\",
        \"insecure\": false,
        \"utls\": {
          \"enabled\": true,
          \"fingerprint\": \"chrome\"
        }
      }
    }"
                    ;;
                "hysteria2")
                    local domain="$extra1"
                    
                    outbounds_json="$outbounds_json,
    {
      \"type\": \"hysteria2\",
      \"tag\": \"$name\",
      \"server\": \"$server_ip\",
      \"server_port\": $port,
      \"password\": \"$uuid\",
      \"tls\": {
        \"enabled\": true,
        \"server_name\": \"$domain\",
        \"insecure\": true,
        \"alpn\": [\"h3\"]
      }
    }"
                    ;;
                "tuic5")
                    local domain="$extra1"
                    local password="$extra2"
                    
                    outbounds_json="$outbounds_json,
    {
      \"type\": \"tuic\",
      \"tag\": \"$name\",
      \"server\": \"$server_ip\",
      \"server_port\": $port,
      \"uuid\": \"$uuid\",
      \"password\": \"$password\",
      \"congestion_control\": \"bbr\",
      \"udp_relay_mode\": \"native\",
      \"udp_over_stream\": false,
      \"zero_rtt_handshake\": false,
      \"heartbeat\": \"10s\",
      \"tls\": {
        \"enabled\": true,
        \"server_name\": \"$domain\",
        \"insecure\": true,
        \"alpn\": [\"h3\"]
      }
    }"
                    ;;
            esac
        fi
    done <<< "$configs"
    
    # 生成完整的客户端配置
    cat << EOF
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "experimental": {
    "clash_api": {
      "external_controller": "127.0.0.1:9090",
      "external_ui": "ui",
      "default_mode": "Rule"
    },
    "cache_file": {
      "enabled": true,
      "path": "cache.db",
      "store_fakeip": true
    }
  },
  "dns": {
    "servers": [
      {
        "tag": "proxydns",
        "address": "tls://8.8.8.8/dns-query",
        "detour": "select"
      },
      {
        "tag": "localdns",
        "address": "h3://223.5.5.5/dns-query",
        "detour": "direct"
      },
      {
        "tag": "dns_fakeip",
        "address": "fakeip"
      }
    ],
    "rules": [
      {
        "outbound": "any",
        "server": "localdns",
        "disable_cache": true
      },
      {
        "clash_mode": "Global",
        "server": "proxydns"
      },
      {
        "clash_mode": "Direct",
        "server": "localdns"
      },
      {
        "rule_set": "geosite-cn",
        "server": "localdns"
      },
      {
        "rule_set": "geosite-geolocation-!cn",
        "server": "proxydns"
      },
      {
        "rule_set": "geosite-geolocation-!cn",
        "query_type": ["A", "AAAA"],
        "server": "dns_fakeip"
      }
    ],
    "fakeip": {
      "enabled": true,
      "inet4_range": "198.18.0.0/15",
      "inet6_range": "fc00::/18"
    },
    "independent_cache": true,
    "final": "proxydns"
  },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "address": ["172.19.0.1/30", "fd00::1/126"],
      "auto_route": true,
      "strict_route": true,
      "sniff": true,
      "sniff_override_destination": true,
      "domain_strategy": "prefer_ipv4"
    }
  ],
  "outbounds": [
    {
      "tag": "select",
      "type": "selector",
      "default": "auto",
      "outbounds": ["auto", $outbound_names]
    },
    {
      "tag": "auto",
      "type": "urltest",
      "outbounds": [$outbound_names],
      "url": "https://www.gstatic.com/generate_204",
      "interval": "1m",
      "tolerance": 50,
      "interrupt_exist_connections": false
    },
    {
      "tag": "direct",
      "type": "direct"
    }$outbounds_json
  ],
  "route": {
    "rule_set": [
      {
        "tag": "geosite-geolocation-!cn",
        "type": "remote",
        "format": "binary",
        "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/geolocation-!cn.srs",
        "download_detour": "select",
        "update_interval": "1d"
      },
      {
        "tag": "geosite-cn",
        "type": "remote",
        "format": "binary",
        "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/geolocation-cn.srs",
        "download_detour": "select",
        "update_interval": "1d"
      },
      {
        "tag": "geoip-cn",
        "type": "remote",
        "format": "binary",
        "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/cn.srs",
        "download_detour": "select",
        "update_interval": "1d"
      }
    ],
    "auto_detect_interface": true,
    "final": "select",
    "rules": [
      {
        "inbound": "tun-in",
        "action": "sniff"
      },
      {
        "protocol": "dns",
        "action": "hijack-dns"
      },
      {
        "port": 443,
        "network": "udp",
        "action": "reject"
      },
      {
        "clash_mode": "Direct",
        "outbound": "direct"
      },
      {
        "clash_mode": "Global",
        "outbound": "select"
      },
      {
        "rule_set": "geoip-cn",
        "outbound": "direct"
      },
      {
        "rule_set": "geosite-cn",
        "outbound": "direct"
      },
      {
        "ip_is_private": true,
        "outbound": "direct"
      },
      {
        "rule_set": "geosite-geolocation-!cn",
        "outbound": "select"
      }
    ]
  },
  "ntp": {
    "enabled": true,
    "server": "time.apple.com",
    "server_port": 123,
    "interval": "30m",
    "detour": "direct"
  }
}
EOF
}

# 执行测试
echo "正在生成客户端配置..."
generate_client_config > /tmp/test_client_config.json

echo "✅ 客户端配置生成成功"
echo "配置文件已保存到: /tmp/test_client_config.json"
echo

# 验证 JSON 格式
if command -v jq >/dev/null 2>&1; then
    echo "✅ JSON 格式验证:"
    jq empty /tmp/test_client_config.json && echo "  格式正确" || echo "  格式错误"
else
    echo "⚠️  未安装 jq，跳过 JSON 格式验证"
fi

echo
echo "📄 配置文件预览 (前50行):"
head -50 /tmp/test_client_config.json

# 清理临时文件
rm -f /tmp/test_config.db

echo
echo "🎉 测试完成！"
