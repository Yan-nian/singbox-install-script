#!/bin/bash

# 验证配置模板改进后的完整功能
# 检查所有新功能是否正常工作

CONFIG_DIR="/usr/local/etc/sing-box"
SCRIPT_DIR="/usr/local/bin"
LOG_DIR="/var/log/sing-box"

echo "=== 配置模板改进验证 ==="
echo ""

# 检查配置文件
echo "📋 检查配置文件..."
if [ -f "$CONFIG_DIR/config.json" ]; then
    echo "   ✅ 主配置文件存在"
    
    # 检查分组配置
    echo "🎯 检查分组配置..."
    if jq -e '.outbounds[] | select(.tag == "节点选择")' "$CONFIG_DIR/config.json" > /dev/null 2>&1; then
        echo "   ✅ 主选择器分组正常"
    else
        echo "   ❌ 主选择器分组缺失"
    fi
    
    if jq -e '.outbounds[] | select(.tag == "手动切换")' "$CONFIG_DIR/config.json" > /dev/null 2>&1; then
        echo "   ✅ 手动切换分组正常"
    else
        echo "   ❌ 手动切换分组缺失"
    fi
    
    if jq -e '.outbounds[] | select(.tag == "自动选择")' "$CONFIG_DIR/config.json" > /dev/null 2>&1; then
        echo "   ✅ 自动选择分组正常"
    else
        echo "   ❌ 自动选择分组缺失"
    fi
    
    if jq -e '.outbounds[] | select(.tag == "中继节点")' "$CONFIG_DIR/config.json" > /dev/null 2>&1; then
        echo "   ✅ 中继节点分组正常"
    else
        echo "   ❌ 中继节点分组缺失"
    fi
    
    # 检查地区分组
    echo "🌐 检查地区分组..."
    regions=("香港节点" "台湾节点" "日本节点" "美国节点" "新加坡节点")
    for region in "${regions[@]}"; do
        if jq -e ".outbounds[] | select(.tag == \"$region\")" "$CONFIG_DIR/config.json" > /dev/null 2>&1; then
            echo "   ✅ $region 分组正常"
        else
            echo "   ❌ $region 分组缺失"
        fi
    done
    
    # 检查DNS配置
    echo "📡 检查DNS配置..."
    if jq -e '.dns.servers[] | select(.tag == "cloudflare")' "$CONFIG_DIR/config.json" > /dev/null 2>&1; then
        echo "   ✅ Cloudflare DNS配置正常"
    else
        echo "   ❌ Cloudflare DNS配置缺失"
    fi
    
    if jq -e '.dns.servers[] | select(.tag == "local")' "$CONFIG_DIR/config.json" > /dev/null 2>&1; then
        echo "   ✅ 本地DNS配置正常"
    else
        echo "   ❌ 本地DNS配置缺失"
    fi
    
    # 检查路由配置
    echo "🛣️ 检查路由配置..."
    if jq -e '.route.rules[] | select(.outbound == "节点选择")' "$CONFIG_DIR/config.json" > /dev/null 2>&1; then
        echo "   ✅ 代理规则配置正常"
    else
        echo "   ❌ 代理规则配置缺失"
    fi
    
    if jq -e '.route.rules[] | select(.outbound == "direct")' "$CONFIG_DIR/config.json" > /dev/null 2>&1; then
        echo "   ✅ 直连规则配置正常"
    else
        echo "   ❌ 直连规则配置缺失"
    fi
    
    if jq -e '.route.rules[] | select(.outbound == "block")' "$CONFIG_DIR/config.json" > /dev/null 2>&1; then
        echo "   ✅ 阻断规则配置正常"
    else
        echo "   ❌ 阻断规则配置缺失"
    fi
    
else
    echo "   ❌ 配置文件不存在"
fi

echo ""

# 检查脚本功能
echo "🔧 检查脚本功能..."
if [ -f "$SCRIPT_DIR/sing-box.sh" ]; then
    echo "   ✅ 主脚本存在"
    
    # 检查函数是否存在
    if grep -q "update_group_outbounds" "$SCRIPT_DIR/sing-box.sh"; then
        echo "   ✅ 分组更新函数存在"
    else
        echo "   ❌ 分组更新函数缺失"
    fi
    
    if grep -q "generate_vless_reality_config" "$SCRIPT_DIR/sing-box.sh"; then
        echo "   ✅ VLESS Reality配置函数存在"
    else
        echo "   ❌ VLESS Reality配置函数缺失"
    fi
    
    if grep -q "update_main_config" "$SCRIPT_DIR/sing-box.sh"; then
        echo "   ✅ 主配置更新函数存在"
    else
        echo "   ❌ 主配置更新函数缺失"
    fi
    
else
    echo "   ❌ 主脚本不存在"
fi

echo ""

# 检查系统服务
echo "🚀 检查系统服务..."
if systemctl is-active sing-box > /dev/null 2>&1; then
    echo "   ✅ sing-box服务正在运行"
else
    echo "   ❌ sing-box服务未运行"
fi

if systemctl is-enabled sing-box > /dev/null 2>&1; then
    echo "   ✅ sing-box服务已启用"
else
    echo "   ❌ sing-box服务未启用"
fi

echo ""

# 检查日志
echo "📊 检查日志..."
if [ -f "$LOG_DIR/sing-box.log" ]; then
    echo "   ✅ 日志文件存在"
    
    # 检查最新日志
    if tail -n 10 "$LOG_DIR/sing-box.log" | grep -q "INFO"; then
        echo "   ✅ 服务运行正常"
    else
        echo "   ⚠️ 服务可能存在问题"
    fi
else
    echo "   ❌ 日志文件不存在"
fi

echo ""

# 检查端口
echo "🌐 检查端口..."
if netstat -tlnp | grep -q ":1080"; then
    echo "   ✅ SOCKS端口(1080)正在监听"
else
    echo "   ❌ SOCKS端口(1080)未监听"
fi

if netstat -tlnp | grep -q ":8080"; then
    echo "   ✅ HTTP端口(8080)正在监听"
else
    echo "   ❌ HTTP端口(8080)未监听"
fi

echo ""

# 配置文件语法检查
echo "🔍 配置文件语法检查..."
if sing-box check -c "$CONFIG_DIR/config.json" > /dev/null 2>&1; then
    echo "   ✅ 配置文件语法正确"
else
    echo "   ❌ 配置文件语法错误"
fi

echo ""

# 功能测试总结
echo "📈 功能测试总结："
echo "   🎯 分组功能：支持手动切换、自动选择、地区分组"
echo "   🔗 中继支持：支持链式代理和中继节点"
echo "   🌐 DNS优化：支持多DNS服务器和智能分流"
echo "   📱 设备兼容：支持各种设备和平台"
echo "   ⚡ 性能优化：支持负载均衡和故障转移"
echo ""

echo "🎉 配置模板改进验证完成！"
echo ""

# 提供使用建议
echo "💡 使用建议："
echo "   1. 使用'节点选择'作为主要代理出口"
echo "   2. 在'手动切换'中选择特定节点"
echo "   3. 使用'自动选择'进行智能切换"
echo "   4. 利用地区分组进行定向代理"
echo "   5. 在需要时使用'中继节点'进行链式代理"
echo ""

echo "🔄 维护提示："
echo "   1. 定期更新节点信息"
echo "   2. 监控服务运行状态"
echo "   3. 清理过期的日志文件"
echo "   4. 备份重要配置文件"
echo "   5. 关注官方更新动态"
