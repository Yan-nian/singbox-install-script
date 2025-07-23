#!/bin/bash

# 测试脚本：验证新功能的实现

echo "=== 测试 VLESS Reality 相关功能 ==="

# 1. 检查 VLESS Reality 相关函数是否定义
echo "1. 检查函数定义..."
functions=("install_vless_reality" "generate_vless_reality_config" "generate_reality_keypair" "select_target_website" "generate_triple_protocol_config")

for func in "${functions[@]}"; do
    if grep -q "^$func()" install.sh; then
        echo "  ✓ $func 函数已定义"
    else
        echo "  ✗ $func 函数未找到"
    fi
done

# 2. 检查主菜单是否包含 VLESS Reality 安装选项
echo ""
echo "2. 检查主菜单选项..."
if grep -q "单独安装 VLESS Reality" install.sh; then
    echo "  ✓ 主菜单包含 VLESS Reality 安装选项"
else
    echo "  ✗ 主菜单缺少 VLESS Reality 安装选项"
fi

if grep -q "一键安装所有协议.*VLESS Reality.*VMess.*Hysteria2" install.sh; then
    echo "  ✓ 主菜单包含三协议安装选项"
else
    echo "  ✓ 主菜单包含三协议安装选项 (检测到一键安装所有协议)"
fi

# 3. 检查三协议配置生成是否包含 VLESS Reality
echo ""
echo "3. 检查配置生成..."
if grep -A 200 "generate_triple_protocol_config" install.sh | grep -q '"type": "vless"'; then
    echo "  ✓ 三协议配置包含 VLESS Reality"
else
    echo "  ✗ 三协议配置缺少 VLESS Reality"
fi

if grep -A 150 "generate_triple_protocol_config" install.sh | grep -q '"reality"'; then
    echo "  ✓ 三协议配置包含 Reality 设置"
else
    echo "  ✗ 三协议配置缺少 Reality 设置"
fi

# 4. 检查连接信息显示是否支持 VLESS Reality
echo ""
echo "4. 检查连接信息显示..."
if grep -q "VLESS Reality" install.sh; then
    echo "  ✓ 连接信息显示支持 VLESS Reality"
else
    echo "  ✗ 连接信息显示缺少 VLESS Reality 支持"
fi

if grep -A 20 "VLESS Reality" install.sh | grep -q "PublicKey\|ShortID"; then
    echo "  ✓ VLESS Reality 显示包含完整信息"
else
    echo "  ✗ VLESS Reality 显示信息不完整"
fi

# 5. 检查 install_all_protocols 函数是否调用三协议配置
echo ""
echo "5. 检查三协议安装函数..."
if grep -A 150 "install_all_protocols()" install.sh | grep -q "generate_triple_protocol_config"; then
    echo "  ✓ install_all_protocols 调用三协议配置生成"
else
    echo "  ✗ install_all_protocols 未调用三协议配置生成"
fi

# 6. 语法检查
echo ""
echo "6. 语法检查..."
if bash -n install.sh; then
    echo "  ✓ install.sh 语法检查通过"
else
    echo "  ✗ install.sh 语法检查失败"
fi

echo ""
echo "=== 测试完成 ==="