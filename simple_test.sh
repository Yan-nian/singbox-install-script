#!/bin/bash

# 简单的功能测试脚本

echo "=== 测试脚本语法 ==="
if bash -n install.sh; then
    echo "✓ 脚本语法正确"
else
    echo "✗ 脚本语法错误"
fi

echo ""
echo "=== 测试端口验证逻辑 ==="
# 从install.sh中提取端口验证函数
validate_port() {
    local port=$1
    if [[ ! "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
        return 1
    fi
    return 0
}

# 测试有效端口
if validate_port 443; then
    echo "✓ 端口443验证通过"
else
    echo "✗ 端口443验证失败"
fi

# 测试无效端口
if ! validate_port 70000; then
    echo "✓ 端口70000正确被拒绝"
else
    echo "✗ 端口70000应该被拒绝"
fi

# 测试字符串端口
if ! validate_port "abc"; then
    echo "✓ 字符串端口正确被拒绝"
else
    echo "✗ 字符串端口应该被拒绝"
fi

echo ""
echo "=== 测试UUID生成 ==="
generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen
    else
        cat /proc/sys/kernel/random/uuid
    fi
}

uuid1=$(generate_uuid)
uuid2=$(generate_uuid)

echo "生成的UUID1: $uuid1"
echo "生成的UUID2: $uuid2"

if [[ "$uuid1" != "$uuid2" ]]; then
    echo "✓ UUID生成正常（不重复）"
else
    echo "✗ UUID生成异常（重复）"
fi

echo ""
echo "=== 测试随机端口生成 ==="
generate_random_port() {
    local min_port=10000
    local max_port=65535
    echo $((RANDOM % (max_port - min_port + 1) + min_port))
}

port=$(generate_random_port)
echo "生成的随机端口: $port"

if [[ "$port" -ge 10000 && "$port" -le 65535 ]]; then
    echo "✓ 随机端口在有效范围内"
else
    echo "✗ 随机端口超出有效范围"
fi

echo ""
echo "测试完成！"
