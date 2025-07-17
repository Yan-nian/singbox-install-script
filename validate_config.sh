#!/bin/bash

# sing-box 配置验证脚本

CONFIG_FILE="/etc/sing-box/config.json"
BINARY_PATH="/usr/local/bin/sing-box"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== sing-box 配置验证工具 ===${NC}"
echo

# 检查配置文件是否存在
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}错误：配置文件 $CONFIG_FILE 不存在${NC}"
    exit 1
fi

# 检查二进制文件是否存在
if [[ ! -f "$BINARY_PATH" ]]; then
    echo -e "${RED}错误：sing-box 二进制文件 $BINARY_PATH 不存在${NC}"
    exit 1
fi

echo -e "${YELLOW}1. 检查 JSON 语法...${NC}"
# 使用 jq 验证 JSON 格式
if command -v jq &> /dev/null; then
    if jq . "$CONFIG_FILE" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ JSON 格式正确${NC}"
    else
        echo -e "${RED}❌ JSON 格式错误${NC}"
        echo -e "${RED}错误详情：${NC}"
        jq . "$CONFIG_FILE"
        exit 1
    fi
elif command -v python3 &> /dev/null; then
    if python3 -m json.tool "$CONFIG_FILE" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ JSON 格式正确${NC}"
    else
        echo -e "${RED}❌ JSON 格式错误${NC}"
        echo -e "${RED}错误详情：${NC}"
        python3 -m json.tool "$CONFIG_FILE"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  没有找到 JSON 验证工具 (jq 或 python3)${NC}"
fi

echo -e "${YELLOW}2. 检查 sing-box 配置...${NC}"
# 使用 sing-box 验证配置
if "$BINARY_PATH" check -c "$CONFIG_FILE" 2>/dev/null; then
    echo -e "${GREEN}✅ sing-box 配置验证通过${NC}"
else
    echo -e "${RED}❌ sing-box 配置验证失败${NC}"
    echo -e "${RED}错误详情：${NC}"
    "$BINARY_PATH" check -c "$CONFIG_FILE"
    exit 1
fi

echo -e "${YELLOW}3. 检查端口占用...${NC}"
# 检查配置中的端口是否被占用
ports=$(grep -o '"listen_port": [0-9]*' "$CONFIG_FILE" | grep -o '[0-9]*')
for port in $ports; do
    if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        process=$(netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f2 | head -1)
        if [[ "$process" == "sing-box" ]]; then
            echo -e "${GREEN}✅ 端口 $port 已被 sing-box 使用${NC}"
        else
            echo -e "${RED}❌ 端口 $port 被其他进程占用: $process${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  端口 $port 未被使用${NC}"
    fi
done

echo -e "${YELLOW}4. 检查证书文件...${NC}"
# 检查证书文件是否存在
cert_files=$(grep -o '"certificate_path": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
key_files=$(grep -o '"key_path": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)

for cert_file in $cert_files; do
    if [[ -f "$cert_file" ]]; then
        echo -e "${GREEN}✅ 证书文件存在: $cert_file${NC}"
    else
        echo -e "${RED}❌ 证书文件不存在: $cert_file${NC}"
    fi
done

for key_file in $key_files; do
    if [[ -f "$key_file" ]]; then
        echo -e "${GREEN}✅ 私钥文件存在: $key_file${NC}"
    else
        echo -e "${RED}❌ 私钥文件不存在: $key_file${NC}"
    fi
done

echo -e "${YELLOW}5. 检查服务状态...${NC}"
# 检查服务状态
if systemctl is-active --quiet sing-box; then
    echo -e "${GREEN}✅ sing-box 服务正在运行${NC}"
    systemctl status sing-box --no-pager --lines=3
else
    echo -e "${RED}❌ sing-box 服务未运行${NC}"
    echo -e "${YELLOW}最近的日志：${NC}"
    journalctl -u sing-box --no-pager -n 5
fi

echo
echo -e "${BLUE}=== 验证完成 ===${NC}"
echo -e "${YELLOW}如果发现问题，请检查配置文件或重新运行安装脚本${NC}"
