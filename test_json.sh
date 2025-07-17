#!/bin/bash

# JSON 配置测试脚本

# 模拟用户配置生成
test_json_generation() {
    echo "=== 测试用户配置 JSON 生成 ==="
    
    # 模拟单用户配置
    local users_json="{\"name\":\"testuser\",\"uuid\":\"12345678-1234-1234-1234-123456789012\"}"
    echo "单用户配置:"
    echo "[$users_json]"
    echo
    
    # 模拟多用户配置
    local multi_users_json="{\"name\":\"user1\",\"uuid\":\"12345678-1234-1234-1234-123456789012\"},{\"name\":\"user2\",\"uuid\":\"87654321-4321-4321-4321-210987654321\"}"
    echo "多用户配置:"
    echo "[$multi_users_json]"
    echo
    
    # 测试 VLESS 配置
    echo "=== 测试 VLESS 配置 ==="
    local vless_config="{
        \"type\": \"vless\",
        \"tag\": \"vless-reality\",
        \"listen\": \"::\",
        \"listen_port\": 443,
        \"users\": [$users_json],
        \"packet_encoding\": \"xudp\",
        \"flow\": \"xtls-rprx-vision\",
        \"tls\": {
            \"enabled\": true,
            \"server_name\": \"www.microsoft.com\",
            \"utls\": {
                \"enabled\": true,
                \"fingerprint\": \"chrome\"
            },
            \"reality\": {
                \"enabled\": true,
                \"handshake\": {
                    \"server\": \"www.microsoft.com\",
                    \"server_port\": 443
                },
                \"private_key\": \"test-private-key\",
                \"short_id\": [\"abcdef01\"]
            }
        }
    }"
    
    echo "$vless_config" > test_vless.json
    
    # 验证 JSON 格式
    if command -v jq &> /dev/null; then
        echo "使用 jq 验证 JSON 格式..."
        if jq . test_vless.json > /dev/null 2>&1; then
            echo "✅ VLESS JSON 格式正确"
        else
            echo "❌ VLESS JSON 格式错误"
        fi
    elif command -v python3 &> /dev/null; then
        echo "使用 python3 验证 JSON 格式..."
        if python3 -m json.tool test_vless.json > /dev/null 2>&1; then
            echo "✅ VLESS JSON 格式正确"
        else
            echo "❌ VLESS JSON 格式错误"
        fi
    else
        echo "没有找到 JSON 验证工具，跳过验证"
    fi
    
    # 清理临时文件
    rm -f test_vless.json
}

# 测试完整配置文件
test_complete_config() {
    echo "=== 测试完整配置文件 ==="
    
    local complete_config='{
    "log": {
        "disabled": false,
        "level": "info",
        "timestamp": true,
        "output": "/var/log/sing-box.log"
    },
    "dns": {
        "rules": [
            {
                "outbound": ["any"],
                "server": "local"
            }
        ],
        "servers": [
            {
                "address": "https://1.1.1.1/dns-query",
                "detour": "direct",
                "tag": "remote"
            }
        ],
        "strategy": "prefer_ipv4"
    },
    "inbounds": [
        {
            "type": "vless",
            "tag": "vless-reality",
            "listen": "::",
            "listen_port": 443,
            "users": [
                {
                    "name": "testuser",
                    "uuid": "12345678-1234-1234-1234-123456789012"
                }
            ],
            "packet_encoding": "xudp",
            "flow": "xtls-rprx-vision",
            "tls": {
                "enabled": true,
                "server_name": "www.microsoft.com",
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                },
                "reality": {
                    "enabled": true,
                    "handshake": {
                        "server": "www.microsoft.com",
                        "server_port": 443
                    },
                    "private_key": "test-private-key",
                    "short_id": ["abcdef01"]
                }
            }
        }
    ],
    "outbounds": [
        {
            "type": "direct",
            "tag": "direct"
        }
    ],
    "route": {
        "auto_detect_interface": true,
        "rules": [
            {
                "protocol": "dns",
                "action": "hijack-dns"
            }
        ]
    }
}'
    
    echo "$complete_config" > test_complete.json
    
    # 验证完整配置
    if command -v jq &> /dev/null; then
        echo "使用 jq 验证完整配置..."
        if jq . test_complete.json > /dev/null 2>&1; then
            echo "✅ 完整配置 JSON 格式正确"
        else
            echo "❌ 完整配置 JSON 格式错误"
            jq . test_complete.json
        fi
    elif command -v python3 &> /dev/null; then
        echo "使用 python3 验证完整配置..."
        if python3 -m json.tool test_complete.json > /dev/null 2>&1; then
            echo "✅ 完整配置 JSON 格式正确"
        else
            echo "❌ 完整配置 JSON 格式错误"
            python3 -m json.tool test_complete.json
        fi
    else
        echo "没有找到 JSON 验证工具，跳过验证"
    fi
    
    # 清理临时文件
    rm -f test_complete.json
}

# 运行测试
test_json_generation
test_complete_config

echo "=== 测试完成 ==="
