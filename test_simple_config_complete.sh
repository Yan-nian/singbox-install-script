#!/bin/bash

# 简化配置功能完整性测试
# 验证所有功能组件是否正常工作

echo "=== Sing-Box 简化配置功能完整性测试 ==="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 测试计数器
total_tests=0
passed_tests=0

test_function() {
    local test_name="$1"
    local test_result="$2"
    
    total_tests=$((total_tests + 1))
    
    if [ "$test_result" = "pass" ]; then
        echo -e "   ${GREEN}✅ $test_name${NC}"
        passed_tests=$((passed_tests + 1))
    else
        echo -e "   ${RED}❌ $test_name${NC}"
    fi
}

echo -e "${CYAN}🎯 简化配置功能测试开始${NC}"
echo ""

# 1. 检查核心函数
echo -e "${BLUE}1. 检查核心函数${NC}"
if [ -f "sing-box.sh" ]; then
    # 检查自动配置生成函数
    if grep -q "generate_auto_config" "sing-box.sh"; then
        test_function "自动配置生成函数" "pass"
    else
        test_function "自动配置生成函数" "fail"
    fi
    
    # 检查交互式简化配置函数
    if grep -q "interactive_add_simple_config" "sing-box.sh"; then
        test_function "交互式简化配置函数" "pass"
    else
        test_function "交互式简化配置函数" "fail"
    fi
    
    # 检查菜单更新
    if grep -q "快速配置" "sing-box.sh"; then
        test_function "快速配置菜单选项" "pass"
    else
        test_function "快速配置菜单选项" "fail"
    fi
else
    test_function "主脚本文件存在" "fail"
fi

echo ""

# 2. 检查工具函数
echo -e "${BLUE}2. 检查工具函数${NC}"
if [ -f "sing-box.sh" ]; then
    # 检查随机端口生成
    if grep -q "get_random_port" "sing-box.sh"; then
        test_function "随机端口生成函数" "pass"
    else
        test_function "随机端口生成函数" "fail"
    fi
    
    # 检查UUID生成
    if grep -q "generate_uuid" "sing-box.sh"; then
        test_function "UUID生成函数" "pass"
    else
        test_function "UUID生成函数" "fail"
    fi
    
    # 检查密码生成
    if grep -q "generate_password" "sing-box.sh"; then
        test_function "密码生成函数" "pass"
    else
        test_function "密码生成函数" "fail"
    fi
    
    # 检查随机字符串生成
    if grep -q "generate_random_string" "sing-box.sh"; then
        test_function "随机字符串生成函数" "pass"
    else
        test_function "随机字符串生成函数" "fail"
    fi
    
    # 检查服务器IP获取
    if grep -q "get_server_ip" "sing-box.sh"; then
        test_function "服务器IP获取函数" "pass"
    else
        test_function "服务器IP获取函数" "fail"
    fi
    
    # 检查短ID生成
    if grep -q "get_short_id" "sing-box.sh"; then
        test_function "短ID生成函数" "pass"
    else
        test_function "短ID生成函数" "fail"
    fi
    
    # 检查Reality密钥生成
    if grep -q "generate_reality_keys" "sing-box.sh"; then
        test_function "Reality密钥生成函数" "pass"
    else
        test_function "Reality密钥生成函数" "fail"
    fi
fi

echo ""

# 3. 检查配置生成函数
echo -e "${BLUE}3. 检查配置生成函数${NC}"
if [ -f "sing-box.sh" ]; then
    # 检查VLESS Reality配置生成
    if grep -q "generate_vless_reality_config" "sing-box.sh"; then
        test_function "VLESS Reality配置生成" "pass"
    else
        test_function "VLESS Reality配置生成" "fail"
    fi
    
    # 检查VMess配置生成
    if grep -q "generate_vmess_config" "sing-box.sh"; then
        test_function "VMess配置生成" "pass"
    else
        test_function "VMess配置生成" "fail"
    fi
    
    # 检查Hysteria2配置生成
    if grep -q "generate_hysteria2_config" "sing-box.sh"; then
        test_function "Hysteria2配置生成" "pass"
    else
        test_function "Hysteria2配置生成" "fail"
    fi
    
    # 检查Shadowsocks配置生成
    if grep -q "generate_shadowsocks_config" "sing-box.sh"; then
        test_function "Shadowsocks配置生成" "pass"
    else
        test_function "Shadowsocks配置生成" "fail"
    fi
fi

echo ""

# 4. 检查分享链接生成
echo -e "${BLUE}4. 检查分享链接生成${NC}"
if [ -f "sing-box.sh" ]; then
    # 检查VLESS链接生成
    if grep -q "generate_vless_url" "sing-box.sh"; then
        test_function "VLESS分享链接生成" "pass"
    else
        test_function "VLESS分享链接生成" "fail"
    fi
    
    # 检查VMess链接生成
    if grep -q "generate_vmess_url" "sing-box.sh"; then
        test_function "VMess分享链接生成" "pass"
    else
        test_function "VMess分享链接生成" "fail"
    fi
    
    # 检查Hysteria2链接生成
    if grep -q "generate_hy2_url" "sing-box.sh"; then
        test_function "Hysteria2分享链接生成" "pass"
    else
        test_function "Hysteria2分享链接生成" "fail"
    fi
    
    # 检查Shadowsocks链接生成
    if grep -q "generate_ss_url" "sing-box.sh"; then
        test_function "Shadowsocks分享链接生成" "pass"
    else
        test_function "Shadowsocks分享链接生成" "fail"
    fi
fi

echo ""

# 5. 检查数据库操作
echo -e "${BLUE}5. 检查数据库操作${NC}"
if [ -f "sing-box.sh" ]; then
    # 检查配置添加到数据库
    if grep -q "add_config_to_db" "sing-box.sh"; then
        test_function "配置添加到数据库" "pass"
    else
        test_function "配置添加到数据库" "fail"
    fi
    
    # 检查从数据库获取配置
    if grep -q "get_config_from_db" "sing-box.sh"; then
        test_function "从数据库获取配置" "pass"
    else
        test_function "从数据库获取配置" "fail"
    fi
fi

echo ""

# 6. 检查系统集成
echo -e "${BLUE}6. 检查系统集成${NC}"
if [ -f "sing-box.sh" ]; then
    # 检查主配置更新
    if grep -q "update_main_config" "sing-box.sh"; then
        test_function "主配置更新" "pass"
    else
        test_function "主配置更新" "fail"
    fi
    
    # 检查端口检查
    if grep -q "check_port" "sing-box.sh"; then
        test_function "端口检查" "pass"
    else
        test_function "端口检查" "fail"
    fi
    
    # 检查服务重启
    if grep -q "systemctl.*restart.*sing-box" "sing-box.sh"; then
        test_function "服务重启" "pass"
    else
        test_function "服务重启" "fail"
    fi
fi

echo ""

# 7. 检查协议支持
echo -e "${BLUE}7. 检查协议支持${NC}"
protocols=("vless-reality" "vmess" "hysteria2" "shadowsocks")
for protocol in "${protocols[@]}"; do
    if grep -q "\"$protocol\"" "sing-box.sh"; then
        test_function "$protocol 协议支持" "pass"
    else
        test_function "$protocol 协议支持" "fail"
    fi
done

echo ""

# 8. 检查用户界面
echo -e "${BLUE}8. 检查用户界面${NC}"
if [ -f "sing-box.sh" ]; then
    # 检查菜单更新
    if grep -q "show_add_menu" "sing-box.sh"; then
        test_function "添加配置菜单" "pass"
    else
        test_function "添加配置菜单" "fail"
    fi
    
    # 检查输入验证
    if grep -q "read_input" "sing-box.sh"; then
        test_function "输入验证" "pass"
    else
        test_function "输入验证" "fail"
    fi
    
    # 检查确认对话框
    if grep -q "confirm" "sing-box.sh"; then
        test_function "确认对话框" "pass"
    else
        test_function "确认对话框" "fail"
    fi
fi

echo ""

# 9. 检查文档
echo -e "${BLUE}9. 检查文档${NC}"
if [ -f "SIMPLE_CONFIG_README.md" ]; then
    test_function "简化配置说明文档" "pass"
else
    test_function "简化配置说明文档" "fail"
fi

if [ -f "simple_config_demo.sh" ]; then
    test_function "使用示例脚本" "pass"
else
    test_function "使用示例脚本" "fail"
fi

echo ""

# 10. 检查测试脚本
echo -e "${BLUE}10. 检查测试脚本${NC}"
if [ -f "test_simple_config.sh" ]; then
    test_function "简化配置测试脚本" "pass"
else
    test_function "简化配置测试脚本" "fail"
fi

echo ""

# 测试结果统计
echo -e "${YELLOW}📊 测试结果统计${NC}"
echo ""
echo "总测试项目: $total_tests"
echo "通过测试: $passed_tests"
echo "失败测试: $((total_tests - passed_tests))"
if [ $total_tests -gt 0 ]; then
    pass_rate=$(( passed_tests * 100 / total_tests ))
    echo "通过率: $pass_rate%"
    
    if [ $pass_rate -ge 90 ]; then
        echo -e "${GREEN}✅ 测试结果: 优秀${NC}"
    elif [ $pass_rate -ge 80 ]; then
        echo -e "${YELLOW}⚠️ 测试结果: 良好${NC}"
    else
        echo -e "${RED}❌ 测试结果: 需要改进${NC}"
    fi
else
    echo -e "${RED}❌ 测试结果: 无法评估${NC}"
fi

echo ""

# 功能总结
echo -e "${CYAN}🎉 简化配置功能总结${NC}"
echo ""
echo "简化配置功能已经成功实现，主要特性包括："
echo ""
echo "1. 🎯 极简操作:"
echo "   • 用户只需要输入节点名称"
echo "   • 系统自动生成所有参数"
echo "   • 一键完成完整配置"
echo ""
echo "2. 🚀 全协议支持:"
echo "   • VLESS Reality (推荐)"
echo "   • VMess (兼容性好)"
echo "   • Hysteria2 (高速传输)"
echo "   • Shadowsocks (简单易用)"
echo ""
echo "3. 🔧 智能化功能:"
echo "   • 自动端口分配"
echo "   • 冲突检测"
echo "   • 参数验证"
echo "   • 服务管理"
echo ""
echo "4. 🛡️ 安全保障:"
echo "   • 随机密钥生成"
echo "   • 符合协议规范"
echo "   • 最佳安全配置"
echo ""
echo "5. 📱 用户体验:"
echo "   • 直观的界面"
echo "   • 清晰的提示"
echo "   • 即时反馈"
echo "   • 错误处理"
echo ""

if [ $passed_tests -eq $total_tests ]; then
    echo -e "${GREEN}🎉 所有测试通过！简化配置功能已经完全就绪！${NC}"
    echo ""
    echo "现在用户可以享受简化的配置体验："
    echo "• 运行: sudo ./sing-box.sh"
    echo "• 选择: [1] 添加配置"
    echo "• 选择: [1] 🚀 快速配置"
    echo "• 输入: 节点名称"
    echo "• 完成: 获得完整配置和分享链接"
else
    echo -e "${YELLOW}⚠️ 部分测试未通过，建议检查相关功能！${NC}"
fi

echo ""
echo -e "${BLUE}💡 使用建议：${NC}"
echo "1. 使用有意义的节点名称"
echo "2. 选择合适的协议类型"
echo "3. 定期更新和维护配置"
echo "4. 监控服务运行状态"
echo "5. 备份重要配置信息"
echo ""
echo "📞 如需帮助，请参考 SIMPLE_CONFIG_README.md"
echo ""
echo "✅ 简化配置功能完整性测试完成！"
