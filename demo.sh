#!/bin/bash

# Sing-box 交互式界面演示脚本

echo "=== Sing-box 交互式界面功能演示 ==="
echo

echo "1. 主要功能特性："
echo "   ✅ 美观的彩色交互式菜单"
echo "   ✅ 支持 4 种协议：VLESS Reality、VMess、Hysteria2、Shadowsocks"
echo "   ✅ 智能输入验证和错误处理"
echo "   ✅ 实时配置预览和确认"
echo "   ✅ 完整的配置管理功能"
echo "   ✅ 系统优化和性能调优"
echo "   ✅ 分享链接和二维码生成"
echo "   ✅ 实时日志查看"
echo

echo "2. 交互式菜单结构："
echo "   [1] 添加配置"
echo "       ├── VLESS Reality (推荐)"
echo "       ├── VMess"
echo "       ├── Hysteria2"
echo "       └── Shadowsocks"
echo "   [2] 管理配置"
echo "       ├── 查看所有配置"
echo "       ├── 查看配置详情"
echo "       ├── 删除配置"
echo "       ├── 更换端口"
echo "       └── 重新生成 UUID"
echo "   [3] 系统管理"
echo "       ├── 启动/停止/重启服务"
echo "       ├── 查看状态和日志"
echo "       ├── 系统优化"
echo "       └── 卸载功能"
echo "   [4] 分享链接"
echo "       ├── 显示所有分享链接"
echo "       ├── 显示指定配置链接"
echo "       ├── 生成二维码"
echo "       └── 导出配置文件"
echo "   [5] 系统信息"
echo "   [6] 更新脚本"
echo

echo "3. 使用方法："
echo "   # 启动交互式菜单（推荐）"
echo "   ./sing-box.sh"
echo
echo "   # 命令行模式"
echo "   ./sing-box.sh add vless"
echo "   ./sing-box.sh list"
echo "   ./sing-box.sh info vless-001"
echo

echo "4. 安装使用："
echo "   sudo bash install.sh    # 安装脚本"
echo "   sing-box               # 启动交互式界面"
echo

echo "=== 开发完成，可以开始使用了！ ==="
