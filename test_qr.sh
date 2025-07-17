#!/bin/bash

# QR码功能测试脚本

# 检查qrencode是否安装
if ! command -v qrencode &> /dev/null; then
    echo "qrencode 未安装，正在安装..."
    
    # 检测系统类型并安装
    if command -v brew &> /dev/null; then
        echo "使用 Homebrew 安装 qrencode..."
        brew install qrencode
    elif command -v apt-get &> /dev/null; then
        echo "使用 apt-get 安装 qrencode..."
        sudo apt-get update && sudo apt-get install -y qrencode
    elif command -v yum &> /dev/null; then
        echo "使用 yum 安装 qrencode..."
        sudo yum install -y qrencode
    elif command -v dnf &> /dev/null; then
        echo "使用 dnf 安装 qrencode..."
        sudo dnf install -y qrencode
    else
        echo "无法自动安装 qrencode，请手动安装后再试"
        exit 1
    fi
fi

# 生成测试QR码
generate_test_qr() {
    local text="$1"
    local title="$2"
    
    echo "=================================="
    echo "$title"
    echo "=================================="
    echo "$text"
    echo ""
    echo "QR码:"
    echo "$text" | qrencode -t ANSIUTF8 -s 1 -m 1
    echo ""
}

# 测试各种协议链接
echo "=== sing-box QR码功能测试 ==="
echo ""

# 测试VLESS链接
vless_link="vless://12345678-1234-1234-1234-123456789012@example.com:443?security=reality&sni=www.microsoft.com&fp=chrome&pbk=abcdefghijk&sid=123456&type=tcp&flow=xtls-rprx-vision#VLESS-Reality"
generate_test_qr "$vless_link" "VLESS Reality QR码"

# 测试VMess链接
vmess_config='{"add":"example.com","aid":"0","host":"","id":"12345678-1234-1234-1234-123456789012","net":"ws","path":"/abcdefgh","port":"8080","ps":"VMess-WebSocket","tls":"","type":"none","v":"2"}'
vmess_link="vmess://$(echo -n "$vmess_config" | base64)"
generate_test_qr "$vmess_link" "VMess WebSocket QR码"

# 测试Hysteria2链接
hysteria2_link="hysteria2://12345678-1234-1234-1234-123456789012@example.com:8443?sni=www.microsoft.com#Hysteria2"
generate_test_qr "$hysteria2_link" "Hysteria2 QR码"

# 测试TUIC5链接
tuic5_link="tuic://12345678-1234-1234-1234-123456789012:your-password@example.com:8844?congestion_control=bbr&udp_relay_mode=native&alpn=h3&allow_insecure=1#TUIC5"
generate_test_qr "$tuic5_link" "TUIC5 QR码"

echo "=== 测试完成 ==="
echo "提示：上述QR码为测试用例，请使用实际的配置信息"
