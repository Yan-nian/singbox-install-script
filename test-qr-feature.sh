#!/bin/bash

# 测试二维码功能
echo "=== 测试二维码功能 ==="
echo ""

# 检查主脚本是否存在
if [[ ! -f "singbox-all-in-one.sh" ]]; then
    echo "❌ 主脚本不存在"
    exit 1
fi

echo "✅ 主脚本存在"

# 检查二维码相关函数是否存在
echo "检查二维码相关函数..."

functions=("show_qr_menu" "generate_qr_code" "show_protocol_qr" "install_qrencode" "generate_simple_qr")

for func in "${functions[@]}"; do
    if grep -q "^$func()" singbox-all-in-one.sh; then
        echo "✅ 函数 $func 存在"
    else
        echo "❌ 函数 $func 不存在"
    fi
done

# 检查菜单是否正确更新
echo ""
echo "检查菜单更新..."

if grep -q "生成二维码" lib/menu.sh; then
    echo "✅ 主菜单已添加二维码选项"
else
    echo "❌ 主菜单未添加二维码选项"
fi

if grep -q "show_qr_menu" lib/menu.sh; then
    echo "✅ 菜单调用函数正确"
else
    echo "❌ 菜单调用函数错误"
fi

# 检查分享链接生成函数
echo ""
echo "检查分享链接生成函数..."

share_functions=("generate_vless_share_link" "generate_vmess_share_link" "generate_hysteria2_share_link")

for func in "${share_functions[@]}"; do
    if grep -q "^$func()" singbox-all-in-one.sh; then
        echo "✅ 函数 $func 存在"
    else
        echo "❌ 函数 $func 不存在"
    fi
done

echo ""
echo "=== 测试完成 ==="
echo ""
echo "📋 功能说明:"
echo "1. 在主菜单中选择 '6. 生成二维码'"
echo "2. 可以为每个协议单独生成二维码"
echo "3. 支持终端直接显示二维码（需要 qrencode）"
echo "4. 如果 qrencode 不可用，会显示装饰性二维码"
echo "5. 二维码下方会显示对应的分享链接"
echo ""
echo "🔧 使用方法:"
echo "sudo ./singbox-all-in-one.sh"
echo "然后选择菜单选项 6"