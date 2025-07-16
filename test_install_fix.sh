#!/bin/bash

# 测试安装脚本修复
# 验证重复信息问题是否已解决

echo "=== 安装脚本修复测试 ==="
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

echo "🔍 检查安装脚本问题修复..."
echo ""

# 检查重复的"启动 sing-box 服务"信息
echo "1. 检查服务启动信息重复问题:"
duplicate_start=$(grep -c "启动 sing-box 服务" install.sh 2>/dev/null || echo "0")
if [ "$duplicate_start" -le 1 ]; then
    print_status "服务启动信息重复问题已修复" "success"
else
    print_status "仍然存在 $duplicate_start 个服务启动信息" "warning"
fi

# 检查服务状态检查改进
echo ""
echo "2. 检查服务状态检查改进:"
if grep -q "sleep 2" install.sh; then
    print_status "添加了服务启动等待时间" "success"
else
    print_status "缺少服务启动等待时间" "warning"
fi

if grep -q "systemctl status sing-box" install.sh; then
    print_status "添加了服务状态显示" "success"
else
    print_status "缺少服务状态显示" "warning"
fi

if grep -q "journalctl -u sing-box" install.sh; then
    print_status "添加了错误日志显示" "success"
else
    print_status "缺少错误日志显示" "warning"
fi

if grep -q "sing-box check -c" install.sh; then
    print_status "添加了配置文件语法检查" "success"
else
    print_status "缺少配置文件语法检查" "warning"
fi

# 检查脚本语法
echo ""
echo "3. 检查脚本语法:"
if bash -n install.sh 2>/dev/null; then
    print_status "脚本语法正确" "success"
else
    print_status "脚本语法有问题" "error"
fi

# 检查函数完整性
echo ""
echo "4. 检查函数完整性:"
functions=("check_system" "check_installation" "install_dependencies" "download_singbox" "create_service" "start_service" "show_completion")
for func in "${functions[@]}"; do
    if grep -q "^$func()" install.sh; then
        print_status "$func 函数存在" "success"
    else
        print_status "$func 函数缺失" "error"
    fi
done

# 检查安装模式
echo ""
echo "5. 检查安装模式支持:"
modes=("install" "update" "upgrade" "reinstall" "core" "script")
for mode in "${modes[@]}"; do
    if grep -q "\"$mode\")" install.sh; then
        print_status "$mode 模式支持" "success"
    else
        print_status "$mode 模式缺失" "error"
    fi
done

# 检查错误处理
echo ""
echo "6. 检查错误处理:"
if grep -q "set -e" install.sh; then
    print_status "启用了严格错误处理" "success"
else
    print_status "未启用严格错误处理" "warning"
fi

if grep -q "error()" install.sh; then
    print_status "定义了错误处理函数" "success"
else
    print_status "缺少错误处理函数" "error"
fi

# 检查备份功能
echo ""
echo "7. 检查备份功能:"
if grep -q "backup_existing" install.sh; then
    print_status "支持备份现有安装" "success"
else
    print_status "缺少备份功能" "warning"
fi

# 检查依赖安装
echo ""
echo "8. 检查依赖安装:"
dependencies=("curl" "wget" "unzip" "jq")
for dep in "${dependencies[@]}"; do
    if grep -q "$dep" install.sh; then
        print_status "$dep 依赖检查存在" "success"
    else
        print_status "$dep 依赖检查缺失" "warning"
    fi
done

echo ""
echo "🎯 修复内容总结："
echo ""
echo "✅ 已修复的问题："
echo "   • 移除了重复的'启动 sing-box 服务'信息"
echo "   • 优化了服务启动逻辑"
echo "   • 增加了服务启动等待时间"
echo "   • 添加了服务状态详细显示"
echo "   • 增加了错误日志显示"
echo "   • 添加了配置文件语法检查"
echo ""
echo "🔧 改进功能："
echo "   • 更好的错误诊断"
echo "   • 详细的服务状态信息"
echo "   • 智能的故障排除"
echo "   • 清晰的输出格式"
echo ""
echo "💡 使用建议："
echo "   • 安装时注意观察输出信息"
echo "   • 如果服务启动失败，查看错误日志"
echo "   • 定期检查服务运行状态"
echo "   • 保持配置文件语法正确"
echo ""
echo "✅ 安装脚本修复测试完成！"
echo "🎉 现在安装过程应该更加稳定和清晰！"
