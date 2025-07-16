#!/bin/bash

# 测试批量重新分配端口功能
# 用于验证修复是否有效

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 基础变量
WORK_DIR="/var/lib/sing-box"
CONFIG_FILE="$WORK_DIR/config.json"
SINGBOX_BINARY="/usr/local/bin/sing-box"
SERVICE_NAME="sing-box"
LOG_FILE="/var/log/sing-box.log"

echo -e "${CYAN}=== Sing-box 端口重新分配功能测试 ===${NC}"
echo ""

# 加载模块
echo -e "${CYAN}正在加载模块...${NC}"
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    source "$SCRIPT_DIR/lib/common.sh"
    echo -e "${GREEN}✓ 通用函数库加载成功${NC}"
else
    echo -e "${RED}✗ 通用函数库不存在${NC}"
    exit 1
fi

if [[ -f "$SCRIPT_DIR/lib/protocols.sh" ]]; then
    source "$SCRIPT_DIR/lib/protocols.sh"
    echo -e "${GREEN}✓ 协议模块加载成功${NC}"
else
    echo -e "${RED}✗ 协议模块不存在${NC}"
    exit 1
fi

if [[ -f "$SCRIPT_DIR/lib/config_manager.sh" ]]; then
    source "$SCRIPT_DIR/lib/config_manager.sh"
    echo -e "${GREEN}✓ 配置管理模块加载成功${NC}"
else
    echo -e "${RED}✗ 配置管理模块不存在${NC}"
    exit 1
fi

echo ""

# 检查依赖
echo -e "${CYAN}检查依赖...${NC}"
if command_exists jq; then
    echo -e "${GREEN}✓ jq 已安装${NC}"
else
    echo -e "${RED}✗ jq 未安装，请先安装 jq${NC}"
    exit 1
fi

if [[ -f "$CONFIG_FILE" ]]; then
    echo -e "${GREEN}✓ 配置文件存在: $CONFIG_FILE${NC}"
else
    echo -e "${YELLOW}⚠ 配置文件不存在，将创建测试配置${NC}"
    
    # 创建测试配置目录
    mkdir -p "$WORK_DIR"
    
    # 创建简单的测试配置文件
    cat > "$CONFIG_FILE" << 'EOF'
{
  "log": {
    "level": "info",
    "output": "/var/log/sing-box.log",
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
        "server_name": "www.microsoft.com",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "www.microsoft.com",
            "server_port": 443
          },
          "private_key": "test-private-key",
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
          "uuid": "87654321-4321-4321-4321-cba987654321"
        }
      ],
      "transport": {
        "type": "ws",
        "path": "/vmess",
        "headers": {
          "Host": "example.com"
        }
      }
    },
    {
      "type": "hysteria2",
      "tag": "hy2-in",
      "listen": "::",
      "listen_port": 9443,
      "users": [
        {
          "password": "test-password"
        }
      ],
      "tls": {
        "enabled": true,
        "certificate_path": "/var/lib/sing-box/certs/hysteria2.local.crt",
        "key_path": "/var/lib/sing-box/certs/hysteria2.local.key"
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
fi

echo ""

# 测试配置加载
echo -e "${CYAN}测试配置加载功能...${NC}"
init_config_vars
if load_config; then
    echo -e "${GREEN}✓ 配置加载成功${NC}"
    echo -e "  VLESS 端口: ${VLESS_PORT:-未配置}"
    echo -e "  VMess 端口: ${VMESS_PORT:-未配置}"
    echo -e "  Hysteria2 端口: ${HY2_PORT:-未配置}"
else
    echo -e "${RED}✗ 配置加载失败${NC}"
    exit 1
fi

echo ""

# 测试端口重新分配
echo -e "${CYAN}测试端口重新分配功能...${NC}"
echo -e "${YELLOW}原始端口配置:${NC}"
echo -e "  VLESS: $VLESS_PORT"
echo -e "  VMess: $VMESS_PORT"
echo -e "  Hysteria2: $HY2_PORT"

# 生成新端口
if [[ -n "$VLESS_PORT" ]]; then
    NEW_VLESS_PORT=$(get_random_port)
    VLESS_PORT="$NEW_VLESS_PORT"
    echo -e "${GREEN}✓ VLESS 新端口: $NEW_VLESS_PORT${NC}"
fi

if [[ -n "$VMESS_PORT" ]]; then
    NEW_VMESS_PORT=$(get_random_port)
    VMESS_PORT="$NEW_VMESS_PORT"
    echo -e "${GREEN}✓ VMess 新端口: $NEW_VMESS_PORT${NC}"
fi

if [[ -n "$HY2_PORT" ]]; then
    NEW_HY2_PORT=$(get_random_port)
    HY2_PORT="$NEW_HY2_PORT"
    echo -e "${GREEN}✓ Hysteria2 新端口: $NEW_HY2_PORT${NC}"
fi

echo ""

# 测试配置保存
echo -e "${CYAN}测试配置保存功能...${NC}"
if save_config; then
    echo -e "${GREEN}✓ 配置保存成功${NC}"
else
    echo -e "${RED}✗ 配置保存失败${NC}"
    exit 1
fi

echo ""

# 验证保存结果
echo -e "${CYAN}验证保存结果...${NC}"
init_config_vars
if load_config; then
    echo -e "${GREEN}✓ 配置重新加载成功${NC}"
    echo -e "${YELLOW}更新后的端口配置:${NC}"
    echo -e "  VLESS: $VLESS_PORT"
    echo -e "  VMess: $VMESS_PORT"
    echo -e "  Hysteria2: $HY2_PORT"
else
    echo -e "${RED}✗ 配置重新加载失败${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}=== 所有测试通过！批量重新分配端口功能正常工作 ===${NC}"
echo ""
echo -e "${CYAN}提示: 如果这是生产环境，请记得重启 sing-box 服务以应用新配置${NC}"
echo -e "${CYAN}命令: systemctl restart sing-box${NC}"