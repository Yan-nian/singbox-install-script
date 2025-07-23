#!/bin/bash

# 测试VLESS配置分享功能
echo "=== 测试VLESS配置分享功能 ==="
echo

# 1. 检查配置分享函数中是否包含VLESS检测
echo "1. 检查配置分享函数中的VLESS支持..."
if grep -A 50 'share_config()' install.sh | grep -q 'has_vless'; then
    echo "  ✓ share_config函数包含VLESS检测"
else
    echo "  ✗ share_config函数缺少VLESS检测"
fi

# 2. 检查generate_share_links函数中是否包含VLESS
echo "2. 检查generate_share_links函数中的VLESS支持..."
if grep -A 20 'generate_share_links()' install.sh | grep -q 'has_vless'; then
    echo "  ✓ generate_share_links函数包含VLESS检测"
else
    echo "  ✗ generate_share_links函数缺少VLESS检测"
fi

# 3. 检查generate_single_protocol_link函数中是否支持VLESS
echo "3. 检查generate_single_protocol_link函数中的VLESS支持..."
if grep -A 50 'generate_single_protocol_link()' install.sh | grep -q '"vless"'; then
    echo "  ✓ generate_single_protocol_link函数支持VLESS"
else
    echo "  ✗ generate_single_protocol_link函数不支持VLESS"
fi

# 4. 检查VLESS链接生成逻辑
echo "4. 检查VLESS链接生成逻辑..."
if grep -A 20 '"vless"' install.sh | grep -q 'vless_link='; then
    echo "  ✓ VLESS链接生成逻辑存在"
else
    echo "  ✗ VLESS链接生成逻辑缺失"
fi

# 5. 检查配置分享菜单中是否包含VLESS选项
echo "5. 检查配置分享菜单中的VLESS选项..."
if grep -A 10 '请选择要生成二维码的协议' install.sh | grep -q 'VLESS Reality'; then
    echo "  ✓ 二维码生成菜单包含VLESS Reality选项"
else
    echo "  ✗ 二维码生成菜单缺少VLESS Reality选项"
fi

if grep -A 10 '请选择要分享的协议' install.sh | grep -q 'VLESS Reality'; then
    echo "  ✓ 协议分享菜单包含VLESS Reality选项"
else
    echo "  ✗ 协议分享菜单缺少VLESS Reality选项"
fi

# 6. 检查多协议显示中是否包含VLESS
echo "6. 检查多协议显示中的VLESS支持..."
if grep -A 10 '多协议配置 - 所有协议分享链接' install.sh | grep -q 'VLESS Reality'; then
    echo "  ✓ 多协议分享包含VLESS Reality"
else
    echo "  ✗ 多协议分享缺少VLESS Reality"
fi

echo
echo "=== 测试完成 ==="