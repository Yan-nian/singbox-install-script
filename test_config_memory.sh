#!/bin/bash

# 配置记忆功能测试脚本
# 测试脚本是否能正确记忆和加载配置

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 测试配置
TEST_CONFIG_FILE="/tmp/test_singbox_config.json"
TEST_WORK_DIR="/tmp/test_singbox"

echo -e "${CYAN}=== 配置记忆功能测试 ===${NC}"
echo ""

# 创建测试目录
mkdir -p "$TEST_WORK_DIR"

# 创建测试配置文件
cat > "$TEST_CONFIG_FILE" << 'EOF'
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": 8443,
      "users": [
        {
          "uuid": "12345678-1234-1234-1234-123456789abc",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "example.com",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "example.com",
            "server_port": 443
          },
          "private_key": "test_private_key",
          "short_id": ["abcd"]
        }
      }
    },
    {
      "type": "vmess",
      "tag": "vmess-in",
      "listen": "::",
      "listen_port": 8080,
      "users": [
        {
          "uuid": "87654321-4321-4321-4321-cba987654321",
          "alterId": 0
        }
      ],
      "transport": {
        "type": "ws",
        "path": "/vmess"
      }
    },
    {
      "type": "hysteria2",
      "tag": "hy2-in",
      "listen": "::",
      "listen_port": 9443,
      "users": [
        {
          "password": "test_password_123"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "example.com",
        "key_path": "/path/to/key.pem",
        "certificate_path": "/path/to/cert.pem"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF

echo -e "${GREEN}✓ 测试配置文件已创建${NC}"
echo -e "  文件位置: $TEST_CONFIG_FILE"
echo ""

# 设置测试环境变量
export CONFIG_FILE="$TEST_CONFIG_FILE"
export WORK_DIR="$TEST_WORK_DIR"

# 加载配置管理模块
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config_manager.sh"

echo -e "${CYAN}测试1: 初始化配置变量${NC}"
init_config_vars
echo -e "${GREEN}✓ 配置变量初始化完成${NC}"
echo ""

echo -e "${CYAN}测试2: 加载配置文件${NC}"
if load_config; then
    echo -e "${GREEN}✓ 配置加载成功${NC}"
else
    echo -e "${RED}✗ 配置加载失败${NC}"
    exit 1
fi
echo ""

echo -e "${CYAN}测试3: 验证加载的配置${NC}"
echo -e "VLESS端口: ${VLESS_PORT:-未设置}"
echo -e "VMess端口: ${VMESS_PORT:-未设置}"
echo -e "Hysteria2端口: ${HY2_PORT:-未设置}"
echo -e "VLESS UUID: ${VLESS_UUID:-未设置}"
echo -e "VMess UUID: ${VMESS_UUID:-未设置}"
echo -e "Hysteria2密码: ${HY2_PASSWORD:-未设置}"
echo ""

# 验证期望值
expected_vless_port="8443"
expected_vmess_port="8080"
expected_hy2_port="9443"
expected_vless_uuid="12345678-1234-1234-1234-123456789abc"
expected_vmess_uuid="87654321-4321-4321-4321-cba987654321"
expected_hy2_password="test_password_123"

test_passed=true

if [[ "$VLESS_PORT" != "$expected_vless_port" ]]; then
    echo -e "${RED}✗ VLESS端口不匹配: 期望 $expected_vless_port, 实际 $VLESS_PORT${NC}"
    test_passed=false
else
    echo -e "${GREEN}✓ VLESS端口正确${NC}"
fi

if [[ "$VMESS_PORT" != "$expected_vmess_port" ]]; then
    echo -e "${RED}✗ VMess端口不匹配: 期望 $expected_vmess_port, 实际 $VMESS_PORT${NC}"
    test_passed=false
else
    echo -e "${GREEN}✓ VMess端口正确${NC}"
fi

if [[ "$HY2_PORT" != "$expected_hy2_port" ]]; then
    echo -e "${RED}✗ Hysteria2端口不匹配: 期望 $expected_hy2_port, 实际 $HY2_PORT${NC}"
    test_passed=false
else
    echo -e "${GREEN}✓ Hysteria2端口正确${NC}"
fi

if [[ "$VLESS_UUID" != "$expected_vless_uuid" ]]; then
    echo -e "${RED}✗ VLESS UUID不匹配${NC}"
    test_passed=false
else
    echo -e "${GREEN}✓ VLESS UUID正确${NC}"
fi

if [[ "$VMESS_UUID" != "$expected_vmess_uuid" ]]; then
    echo -e "${RED}✗ VMess UUID不匹配${NC}"
    test_passed=false
else
    echo -e "${GREEN}✓ VMess UUID正确${NC}"
fi

if [[ "$HY2_PASSWORD" != "$expected_hy2_password" ]]; then
    echo -e "${RED}✗ Hysteria2密码不匹配${NC}"
    test_passed=false
else
    echo -e "${GREEN}✓ Hysteria2密码正确${NC}"
fi

echo ""

echo -e "${CYAN}测试4: 显示配置信息${NC}"
show_current_config
echo ""

# 清理测试文件
rm -f "$TEST_CONFIG_FILE"
rm -rf "$TEST_WORK_DIR"

if [[ "$test_passed" == "true" ]]; then
    echo -e "${GREEN}=== 所有测试通过！配置记忆功能正常工作 ===${NC}"
    exit 0
else
    echo -e "${RED}=== 测试失败！配置记忆功能存在问题 ===${NC}"
    exit 1
fi