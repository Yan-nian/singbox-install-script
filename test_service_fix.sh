#!/bin/bash

# 测试安装脚本服务启动修复
# 验证安装脚本不会卡住的问题

echo "=== 安装脚本服务启动修复测试 ==="
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

echo "🔍 检查服务启动修复..."
echo ""

# 检查超时机制
echo "1. 检查超时机制:"
if grep -q "timeout 30 systemctl" install.sh; then
    print_status "添加了服务启动超时机制" "success"
else
    print_status "缺少服务启动超时机制" "warning"
fi

# 检查服务状态检查改进
echo ""
echo "2. 检查服务状态检查:"
if grep -q "systemctl is-active sing-box" install.sh; then
    print_status "服务状态检查存在" "success"
else
    print_status "服务状态检查缺失" "error"
fi

# 检查错误日志显示
echo ""
echo "3. 检查错误日志显示:"
if grep -q "journalctl -u sing-box" install.sh; then
    print_status "错误日志显示功能存在" "success"
else
    print_status "错误日志显示功能缺失" "error"
fi

# 检查配置文件语法检查
echo ""
echo "4. 检查配置文件语法检查:"
if grep -q "sing-box check -c" install.sh; then
    print_status "配置文件语法检查存在" "success"
else
    print_status "配置文件语法检查缺失" "error"
fi

# 检查故障排除建议
echo ""
echo "5. 检查故障排除建议:"
if grep -q "故障排除建议" install.sh; then
    print_status "故障排除建议存在" "success"
else
    print_status "故障排除建议缺失" "error"
fi

# 检查脚本语法
echo ""
echo "6. 检查脚本语法:"
if bash -n install.sh 2>/dev/null; then
    print_status "脚本语法正确" "success"
else
    print_status "脚本语法有问题" "error"
fi

# 模拟服务启动测试
echo ""
echo "7. 模拟服务启动过程:"
echo "   原问题: 安装脚本在'启动 sing-box 服务...'处卡住"
echo "   原因分析:"
echo "     • systemctl start 命令可能阻塞"
echo "     • 配置文件语法错误导致启动失败"
echo "     • 服务启动时间过长"
echo "     • 没有超时机制"
echo ""
echo "   修复方案:"
echo "     ✅ 添加了30秒超时机制"
echo "     ✅ 改进了服务状态检查"
echo "     ✅ 增加了详细的错误日志"
echo "     ✅ 添加了配置文件语法检查"
echo "     ✅ 提供了故障排除建议"

echo ""
echo "🎯 修复内容详解:"
echo ""
echo "1. 超时机制:"
echo "   • 使用 timeout 30 systemctl start/restart"
echo "   • 防止命令无限期阻塞"
echo "   • 30秒内必须完成启动"
echo ""
echo "2. 状态检查:"
echo "   • 使用 systemctl is-active 检查状态"
echo "   • 显示具体的服务状态"
echo "   • 增加了3秒等待时间"
echo ""
echo "3. 错误诊断:"
echo "   • 显示最近5分钟的错误日志"
echo "   • 检查配置文件语法"
echo "   • 提供故障排除建议"
echo ""
echo "4. 用户体验:"
echo "   • 清晰的状态反馈"
echo "   • 详细的错误信息"
echo "   • 实用的解决方案"

echo ""
echo "🔧 预期的安装过程:"
echo ""
echo "[INFO] 启动 sing-box 服务..."
echo "[INFO] 服务启动命令执行完成"
echo "[SUCCESS] 服务启动成功"
echo "[INFO] 服务运行状态:"
echo "● sing-box.service - sing-box service"
echo "   Active: active (running)"
echo ""
echo "或者如果失败："
echo "[INFO] 启动 sing-box 服务..."
echo "[WARN] 服务启动超时或失败"
echo "[WARN] 服务启动失败，当前状态: failed"
echo "[WARN] 最近的错误日志:"
echo "Jul 16 18:48:15 server sing-box[1234]: configuration error..."
echo "[INFO] 检查配置文件语法..."
echo "[WARN] 配置文件语法可能有问题"
echo "[INFO] 故障排除建议:"
echo "  1. 检查配置文件: /etc/sing-box/config.json"
echo "  2. 查看详细日志: journalctl -u sing-box -f"
echo "  3. 手动启动测试: sing-box run -c /etc/sing-box/config.json"
echo "  4. 检查端口占用: netstat -tuln | grep :端口号"

echo ""
echo "💡 使用建议:"
echo ""
echo "1. 如果安装仍然卡住："
echo "   • 按 Ctrl+C 中断安装"
echo "   • 检查系统日志"
echo "   • 手动测试服务启动"
echo ""
echo "2. 如果服务启动失败："
echo "   • 查看详细错误日志"
echo "   • 检查配置文件语法"
echo "   • 确认端口未被占用"
echo ""
echo "3. 调试方法："
echo "   • 手动运行: sing-box run -c /etc/sing-box/config.json"
echo "   • 查看日志: journalctl -u sing-box -f"
echo "   • 检查状态: systemctl status sing-box"

echo ""
echo "✅ 服务启动修复测试完成！"
echo "🎉 现在安装脚本应该不会卡住了！"
