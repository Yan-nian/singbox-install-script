#!/bin/bash

# 测试修正后的配置格式
echo "=== 测试修正后的配置格式 ==="

# 模拟必要的变量和函数
generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen
    else
        echo "12345678-1234-1234-1234-123456789abc"
    fi
}

get_public_ip() {
    echo "192.168.1.100"
}

# 模拟VLESS Reality配置生成
echo "1. 测试VLESS Reality配置："
port=443
server_names="www.microsoft.com"
dest_server="www.microsoft.com"
private_key="test_private_key"
short_id="12345678"
export QUICK_CONFIG=true

# 生成默认用户
default_uuid=$(generate_uuid)
users_json="{\"name\":\"default\",\"uuid\":\"$default_uuid\"}"

# 修正用户配置，添加flow字段
corrected_users_json="{\"name\":\"default\",\"uuid\":\"$default_uuid\",\"flow\":\"xtls-rprx-vision\"}"

VLESS_CONFIG="{
    \"type\": \"vless\",
    \"tag\": \"vless-reality\",
    \"listen\": \"::\",
    \"listen_port\": $port,
    \"users\": [$corrected_users_json],
    \"tls\": {
        \"enabled\": true,
        \"server_name\": \"$server_names\",
        \"utls\": {
            \"enabled\": true,
            \"fingerprint\": \"chrome\"
        },
        \"reality\": {
            \"enabled\": true,
            \"handshake\": {
                \"server\": \"$dest_server\",
                \"server_port\": 443
            },
            \"private_key\": \"$private_key\",
            \"short_id\": [\"$short_id\"]
        }
    }
}"

echo "VLESS配置结构："
echo "$VLESS_CONFIG" | python3 -m json.tool 2>/dev/null || echo "JSON格式错误"

echo ""
echo "2. 测试VMess配置："
port=8080
ws_path="/test"
config_mode="1"

# 生成默认用户
default_uuid=$(generate_uuid)
users_json="{\"name\":\"default\",\"uuid\":\"$default_uuid\"}"

# 修正用户配置，添加alterId字段
corrected_users_json="{\"name\":\"default\",\"uuid\":\"$default_uuid\",\"alterId\":0}"

VMESS_CONFIG="{
    \"type\": \"vmess\",
    \"tag\": \"vmess-ws\",
    \"listen\": \"::\",
    \"listen_port\": $port,
    \"users\": [$corrected_users_json],
    \"transport\": {
        \"type\": \"ws\",
        \"path\": \"$ws_path\",
        \"headers\": {
            \"Host\": [\"$(get_public_ip)\"]
        }
    }
}"

echo "VMess配置结构："
echo "$VMESS_CONFIG" | python3 -m json.tool 2>/dev/null || echo "JSON格式错误"

echo ""
echo "3. 测试完整配置文件："
inbounds_json="$VLESS_CONFIG,$VMESS_CONFIG"

FULL_CONFIG="{
    \"log\": {
        \"disabled\": false,
        \"level\": \"info\",
        \"timestamp\": true,
        \"output\": \"/var/log/sing-box.log\"
    },
    \"inbounds\": [$inbounds_json],
    \"outbounds\": [
        {
            \"type\": \"direct\",
            \"tag\": \"direct\"
        },
        {
            \"type\": \"block\",
            \"tag\": \"block\"
        }
    ]
}"

echo "完整配置文件结构："
echo "$FULL_CONFIG" | python3 -m json.tool 2>/dev/null || echo "JSON格式错误"

echo ""
echo "=== 测试完成 ==="
