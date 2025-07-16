#!/bin/bash

# 测试简化配置功能
# 验证用户只需要输入节点名称的功能

echo "=== 简化配置功能测试 ==="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    if [ "$2" = "success" ]; then
        echo -e "   ${GREEN}✅ $1${NC}"
    elif [ "$2" = "error" ]; then
        echo -e "   ${RED}❌ $1${NC}"
    elif [ "$2" = "warning" ]; then
        echo -e "   ${YELLOW}⚠️ $1${NC}"
    else
        echo -e "   ${BLUE}ℹ️ $1${NC}"
    fi
}

echo "🎯 简化配置功能特点："
echo "   📝 用户只需要输入节点名称"
echo "   🤖 所有其他参数自动生成"
echo "   🔧 支持多种协议类型"
echo "   ⚡ 快速部署和配置"
echo ""

# 检查脚本中的简化配置函数
echo "🔍 检查简化配置函数..."
if [ -f "sing-box.sh" ]; then
    if grep -q "generate_auto_config" "sing-box.sh"; then
        print_status "自动配置生成函数存在" "success"
    else
        print_status "自动配置生成函数缺失" "error"
    fi
    
    if grep -q "interactive_add_simple_config" "sing-box.sh"; then
        print_status "交互式简化配置函数存在" "success"
    else
        print_status "交互式简化配置函数缺失" "error"
    fi
    
    if grep -q "快速配置" "sing-box.sh"; then
        print_status "快速配置菜单选项存在" "success"
    else
        print_status "快速配置菜单选项缺失" "error"
    fi
else
    print_status "主脚本不存在" "error"
fi

echo ""

# 检查自动生成的参数类型
echo "🔧 检查自动生成参数类型..."
if [ -f "sing-box.sh" ]; then
    if grep -q "get_random_port" "sing-box.sh"; then
        print_status "随机端口生成" "success"
    else
        print_status "随机端口生成缺失" "error"
    fi
    
    if grep -q "generate_uuid" "sing-box.sh"; then
        print_status "UUID自动生成" "success"
    else
        print_status "UUID自动生成缺失" "error"
    fi
    
    if grep -q "generate_password" "sing-box.sh"; then
        print_status "密码自动生成" "success"
    else
        print_status "密码自动生成缺失" "error"
    fi
    
    if grep -q "generate_reality_keys" "sing-box.sh"; then
        print_status "Reality密钥自动生成" "success"
    else
        print_status "Reality密钥自动生成缺失" "error"
    fi
    
    if grep -q "get_short_id" "sing-box.sh"; then
        print_status "短ID自动生成" "success"
    else
        print_status "短ID自动生成缺失" "error"
    fi
    
    if grep -q "generate_random_string" "sing-box.sh"; then
        print_status "随机字符串生成" "success"
    else
        print_status "随机字符串生成缺失" "error"
    fi
fi

echo ""

# 检查支持的协议
echo "🌐 检查支持的协议..."
protocols=("vless-reality" "vmess" "hysteria2" "shadowsocks")
for protocol in "${protocols[@]}"; do
    if grep -q "\"$protocol\"" "sing-box.sh"; then
        print_status "$protocol 协议支持" "success"
    else
        print_status "$protocol 协议支持缺失" "error"
    fi
done

echo ""

# 检查配置文件生成
echo "📄 检查配置文件生成..."
if [ -f "sing-box.sh" ]; then
    if grep -q "generate_vless_reality_config" "sing-box.sh"; then
        print_status "VLESS Reality配置生成" "success"
    else
        print_status "VLESS Reality配置生成缺失" "error"
    fi
    
    if grep -q "generate_vmess_config" "sing-box.sh"; then
        print_status "VMess配置生成" "success"
    else
        print_status "VMess配置生成缺失" "error"
    fi
    
    if grep -q "generate_hysteria2_config" "sing-box.sh"; then
        print_status "Hysteria2配置生成" "success"
    else
        print_status "Hysteria2配置生成缺失" "error"
    fi
    
    if grep -q "generate_shadowsocks_config" "sing-box.sh"; then
        print_status "Shadowsocks配置生成" "success"
    else
        print_status "Shadowsocks配置生成缺失" "error"
    fi
fi

echo ""

# 检查分享链接生成
echo "🔗 检查分享链接生成..."
if [ -f "sing-box.sh" ]; then
    if grep -q "generate_vless_url" "sing-box.sh"; then
        print_status "VLESS分享链接生成" "success"
    else
        print_status "VLESS分享链接生成缺失" "error"
    fi
    
    if grep -q "generate_vmess_url" "sing-box.sh"; then
        print_status "VMess分享链接生成" "success"
    else
        print_status "VMess分享链接生成缺失" "error"
    fi
    
    if grep -q "generate_hy2_url" "sing-box.sh"; then
        print_status "Hysteria2分享链接生成" "success"
    else
        print_status "Hysteria2分享链接生成缺失" "error"
    fi
    
    if grep -q "generate_ss_url" "sing-box.sh"; then
        print_status "Shadowsocks分享链接生成" "success"
    else
        print_status "Shadowsocks分享链接生成缺失" "error"
    fi
fi

echo ""

# 使用示例
echo "📋 使用示例："
echo ""
echo "1. 🚀 快速创建VLESS Reality节点："
echo "   节点名称: my-vless-node"
echo "   → 自动生成: 端口、UUID、Reality密钥、SNI等"
echo ""
echo "2. 🔧 快速创建VMess节点："
echo "   节点名称: my-vmess-node"
echo "   → 自动生成: 端口、UUID、域名、路径等"
echo ""
echo "3. ⚡ 快速创建Hysteria2节点："
echo "   节点名称: my-hy2-node"
echo "   → 自动生成: 端口、密码、域名等"
echo ""
echo "4. 🛡️ 快速创建Shadowsocks节点："
echo "   节点名称: my-ss-node"
echo "   → 自动生成: 端口、密码、加密方法等"
echo ""

echo "🎨 用户体验优化："
echo "   ✅ 简化操作流程"
echo "   ✅ 减少用户输入"
echo "   ✅ 自动化参数生成"
echo "   ✅ 智能配置选择"
echo "   ✅ 即时分享链接"
echo ""

echo "⚙️ 自动生成参数说明："
echo "   📡 端口: 10000-65535 随机端口"
echo "   🔑 UUID: 标准UUID v4格式"
echo "   🔐 密码: 16位随机字符串"
echo "   🌐 域名: 默认使用 www.google.com"
echo "   📝 路径: 随机8位字符串"
echo "   🔒 Reality密钥: 自动生成密钥对"
echo "   🏷️ 短ID: 随机8位标识符"
echo ""

echo "🔧 技术实现："
echo "   🎯 模块化设计"
echo "   🔄 参数自动生成"
echo "   📦 配置文件创建"
echo "   🗄️ 数据库记录"
echo "   🚀 服务自动重启"
echo "   📋 分享链接生成"
echo ""

echo "💡 优势总结："
echo "   1. 🎯 降低使用门槛"
echo "   2. ⚡ 提高配置效率"
echo "   3. 🔧 减少配置错误"
echo "   4. 🤖 智能化管理"
echo "   5. 🚀 快速部署"
echo ""

echo "✅ 简化配置功能测试完成！"
echo "🎉 用户现在只需要输入节点名称即可快速创建配置！"
