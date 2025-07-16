# Sing-box 精简安装脚本 v3.0

一个精简、高效的 Sing-box 一键安装和配置脚本，专注于核心功能和易用性。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-v3.0.0--beta1-blue.svg)](#)
[![Platform](https://img.shields.io/badge/platform-Linux-lightgrey.svg)](#)

## ✨ 特性

- 🚀 **一键安装** - 自动检测系统环境，快速部署
- 🔧 **三大协议** - 支持 VLESS Reality、VMess WebSocket、Hysteria2
- 📱 **客户端支持** - 自动生成配置文件、分享链接和二维码
- 🛡️ **安全优先** - 自动配置防火墙和安全参数
- 📊 **服务管理** - 完整的 systemd 服务集成
- 🔄 **配置管理** - 支持备份、验证和热重载

## 🎯 设计理念

**精简重构版本**专注于：
- **简单优先** - 减少复杂配置，提供开箱即用体验
- **易于维护** - 模块化架构，清晰的代码结构
- **快速部署** - 最小化依赖，快速安装配置
- **稳定可靠** - 经过优化的核心功能

## 📋 系统要求

- **操作系统**: Ubuntu 20.04+, Debian 11+, CentOS 8+, RHEL 8+
- **架构**: x86_64, ARM64
- **内存**: 最少 512MB RAM
- **存储**: 最少 1GB 可用空间
- **网络**: 公网 IP 地址

## 🚀 快速开始

### 在线安装

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/master/install_standalone.sh)
```

### 离线安装

```bash
wget https://raw.githubusercontent.com/Yan-nian/singbox-install-script/master/install_standalone.sh
chmod +x install_standalone.sh
sudo ./install_standalone.sh
```



## 📖 使用指南

### 基本命令

```bash
./install_standalone.sh              # 交互式安装
./install_standalone.sh --vless     # 安装 VLESS Reality
./install_standalone.sh --vmess     # 安装 VMess WebSocket
./install_standalone.sh --hysteria  # 安装 Hysteria2
./install_standalone.sh --status    # 查看状态
./install_standalone.sh --uninstall # 卸载
```



## 🔧 服务管理

```bash
systemctl start sing-box      # 启动
systemctl stop sing-box       # 停止
systemctl restart sing-box    # 重启
systemctl status sing-box     # 状态
```




## 🔧 支持的协议

- **VLESS Reality** - 无特征流量，抗检测
- **VMess WebSocket** - 成熟稳定，兼容性好
- **Hysteria2** - 基于 UDP，速度快



## 🛠️ 配置管理

配置文件位置：`/etc/sing-box/config.json`

```bash
# 验证配置
sing-box check -c /etc/sing-box/config.json

# 重载配置
systemctl reload sing-box
```

## 🔗 客户端配置

支持分享链接、二维码和配置文件导入

**支持的客户端**：v2rayN, Clash, Shadowrocket, v2rayNG 等

## 🐛 故障排除

```bash
# 检查配置
sing-box check -c /etc/sing-box/config.json

# 查看日志
journalctl -u sing-box --no-pager

# 检查端口
ss -tlnp | grep :443
```













## 📄 许可证

MIT License

## ⚠️ 免责声明

本项目仅供学习和研究使用，请遵守当地法律法规。