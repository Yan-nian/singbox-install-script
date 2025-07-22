#!/bin/bash

# 测试sing-box配置文件的有效性

echo "正在测试sing-box配置..."

# 检查是否存在sing-box二进制文件
if [ ! -f "/usr/local/bin/sing-box" ]; then
    echo "错误：sing-box未安装"
    exit 1
fi

# 检查配置文件是否存在
if [ ! -f "/etc/sing-box/config.json" ]; then
    echo "错误：配置文件不存在"
    exit 1
fi

echo "配置文件内容："
cat /etc/sing-box/config.json

echo ""
echo "正在验证配置文件语法..."
/usr/local/bin/sing-box check -c /etc/sing-box/config.json

if [ $? -eq 0 ]; then
    echo "✅ 配置文件语法正确"
else
    echo "❌ 配置文件语法错误"
    exit 1
fi

echo ""
echo "正在检查服务状态..."
systemctl status sing-box --no-pager

echo ""
echo "正在检查服务日志..."
journalctl -u sing-box --no-pager -n 20