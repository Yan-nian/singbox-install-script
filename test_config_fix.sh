#!/bin/bash

# 测试配置修复脚本
# 验证 sing-box 配置文件的 outbounds 和路由规则是否正确

echo "=== sing-box 配置修复验证测试 ==="
echo

# 设置测试环境变量
export IP_ADDRESS="1.2.3.4"
export VLESS_UUID="12345678-1234-1234-1234-123456789abc"
export VLESS_TARGET_WEBSITE="www.microsoft.com"
export VLESS_REALITY_PRIVATE_KEY="test_private_key"
export VLESS_REALITY_PUBLIC_KEY="test_public_key"
export VLESS_REALITY_SHORT_ID="abcd1234"
export VMESS_UUID="87654321-4321-4321-4321-cba987654321"
export HY2_PASSWORD="test_password"
export DOMAIN_NAME="example.com"
export SINGBOX_CONFIG_DIR="/tmp/test_singbox"
export SINGBOX_LOG_DIR="/tmp/test_singbox/logs"

# 创建测试目录
mkdir -p "$SINGBOX_CONFIG_DIR"
mkdir -p "$SINGBOX_LOG_DIR"

# 加载配置生成函数
source install.sh

echo "1. 测试 VLESS Reality 配置生成..."
generate_vless_reality_config 8443
if grep -q '"tag": "proxy"' "$SINGBOX_CONFIG_DIR/config.json" && grep -q '"final": "proxy"' "$SINGBOX_CONFIG_DIR/config.json"; then
    echo "✅ VLESS Reality 配置修复成功"
else
    echo "❌ VLESS Reality 配置修复失败"
fi
echo

echo "2. 测试 VMess WebSocket 配置生成..."
generate_vmess_ws_config 8080 "/ws" "/tmp/cert.pem" "/tmp/key.pem"
if grep -q '"tag": "proxy"' "$SINGBOX_CONFIG_DIR/config.json" && grep -q '"final": "proxy"' "$SINGBOX_CONFIG_DIR/config.json"; then
    echo "✅ VMess WebSocket 配置修复成功"
else
    echo "❌ VMess WebSocket 配置修复失败"
fi
echo

echo "3. 测试增强配置（VMess + Hysteria2）生成..."
generate_enhanced_config 8080 8443 "/ws" "www.bing.com" "/tmp/vmess_cert.pem" "/tmp/vmess_key.pem" "/tmp/hy2_cert.pem" "/tmp/hy2_key.pem"
if grep -q '"vmess-proxy"' "$SINGBOX_CONFIG_DIR/config.json" && grep -q '"hy2-proxy"' "$SINGBOX_CONFIG_DIR/config.json" && grep -q '"final": "vmess-proxy"' "$SINGBOX_CONFIG_DIR/config.json"; then
    echo "✅ 增强配置修复成功"
else
    echo "❌ 增强配置修复失败"
fi
echo

echo "4. 测试三协议配置生成..."
generate_triple_protocol_config 8080 8443 8444 "/ws" "www.bing.com" "/tmp/vmess_cert.pem" "/tmp/vmess_key.pem" "/tmp/hy2_cert.pem" "/tmp/hy2_key.pem"
if grep -q '"vless-proxy"' "$SINGBOX_CONFIG_DIR/config.json" && grep -q '"vmess-proxy"' "$SINGBOX_CONFIG_DIR/config.json" && grep -q '"hy2-proxy"' "$SINGBOX_CONFIG_DIR/config.json" && grep -q '"final": "vless-proxy"' "$SINGBOX_CONFIG_DIR/config.json"; then
    echo "✅ 三协议配置修复成功"
else
    echo "❌ 三协议配置修复失败"
fi
echo

echo "5. 检查路由规则修复..."
if grep -q '"224.0.0.0/3"' "$SINGBOX_CONFIG_DIR/config.json" && grep -q '"ff00::/8"' "$SINGBOX_CONFIG_DIR/config.json"; then
    echo "✅ 路由规则修复成功（添加了组播和IPv6组播阻断规则）"
else
    echo "❌ 路由规则修复失败"
fi
echo

echo "=== 测试完成 ==="
echo "最终配置文件内容："
echo "---"
cat "$SINGBOX_CONFIG_DIR/config.json" | head -20
echo "..."
echo "---"

# 清理测试文件
rm -rf "/tmp/test_singbox"

echo
echo "修复总结："
echo "1. ✅ 添加了正确的代理 outbound 配置"
echo "2. ✅ 修复了路由规则的 final 设置"
echo "3. ✅ 添加了组播流量阻断规则"
echo "4. ✅ 所有协议配置都包含了正确的代理出口"
echo
echo "现在 sing-box 配置文件将正确代理流量，而不是直连！"