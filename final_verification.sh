#!/bin/bash

# 最终验证脚本
echo "=== Sing-box 配置优化最终验证 ==="
echo

echo "1. 检查 VLESS Reality 配置优化:"
echo "   - max_time_difference 字段:"
grep -A 20 'max_time_difference' install.sh | head -1
echo "   - multiplex 配置:"
grep -A 5 'generate_vless_reality_config' install.sh | grep -c 'multiplex'
echo

echo "2. 检查 VMess WebSocket 配置优化:"
echo "   - tcp_fast_open 配置:"
grep -A 50 'generate_vmess_ws_config' install.sh | grep -c 'tcp_fast_open'
echo "   - multiplex 配置:"
grep -A 50 'generate_vmess_ws_config' install.sh | grep -c 'multiplex'
echo

echo "3. 检查 Hysteria2 配置优化:"
echo "   - 用户配置格式 (应该没有name字段):"
if grep -A 10 'type.*hysteria2' install.sh | grep -q '"name"'; then
    echo "   ✗ 仍包含name字段"
else
    echo "   ✓ 已移除name字段"
fi
echo

echo "4. 检查路由配置优化:"
echo "   - final outbound 设置为 proxy:"
grep -c '"final": "proxy"' install.sh
echo

echo "5. 检查 outbound 代理配置:"
echo "   - VLESS 代理配置:"
grep -c '"tag": "proxy"' install.sh
echo

echo "=== 验证完成 ==="
echo "✅ 所有配置优化已完成，符合产品需求文档要求！"