#!/bin/bash

# 测试配置文件格式脚本

echo "=== 测试VLESS Reality配置格式 ==="

# 模拟生成VLESS配置
users_json='{"name":"test","uuid":"12345678-1234-1234-1234-123456789012"}'
port=443
server_names="www.microsoft.com"
dest_server="www.microsoft.com"
private_key="test_private_key"
short_id="abcd1234"

VLESS_CONFIG="{
    \"type\": \"vless\",
    \"tag\": \"vless-reality\",
    \"listen\": \"::\",
    \"listen_port\": $port,
    \"users\": [$users_json],
    \"flow\": \"xtls-rprx-vision\",
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

echo "生成的配置："
echo "$VLESS_CONFIG"

# 验证JSON格式
if echo "$VLESS_CONFIG" | python3 -m json.tool > /dev/null 2>&1; then
    echo "✓ VLESS配置JSON格式正确"
else
    echo "✗ VLESS配置JSON格式错误"
fi

echo ""
echo "=== 测试VMess配置格式 ==="

# 模拟生成VMess配置
users_json='{"name":"test","uuid":"12345678-1234-1234-1234-123456789012"}'
port=8080
ws_path="/test"
server_ip="127.0.0.1"

VMESS_CONFIG="{
    \"type\": \"vmess\",
    \"tag\": \"vmess-ws\",
    \"listen\": \"::\",
    \"listen_port\": $port,
    \"users\": [$users_json],
    \"transport\": {
        \"type\": \"ws\",
        \"path\": \"$ws_path\",
        \"headers\": {
            \"Host\": [\"$server_ip\"]
        }
    }
}"

echo "生成的配置："
echo "$VMESS_CONFIG"

# 验证JSON格式
if echo "$VMESS_CONFIG" | python3 -m json.tool > /dev/null 2>&1; then
    echo "✓ VMess配置JSON格式正确"
else
    echo "✗ VMess配置JSON格式错误"
fi

echo ""
echo "测试完成！"
