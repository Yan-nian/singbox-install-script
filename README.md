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
bash <(curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/master/singbox-install.sh)
```

### 离线安装

```bash
# 下载脚本
wget https://raw.githubusercontent.com/Yan-nian/singbox-install-script/master/singbox-install.sh

# 添加执行权限
chmod +x singbox-install.sh

# 运行脚本
./singbox-install.sh
```

## 📖 使用指南

### 命令行参数

```bash
# 显示帮助信息
./singbox-install.sh --help

# 显示版本信息
./singbox-install.sh --version

# 静默安装
./singbox-install.sh --silent

# 仅安装 Sing-box
./singbox-install.sh --install-only

# 卸载
./singbox-install.sh --uninstall
```

### 交互式菜单

运行脚本将进入交互式菜单。安装完成后，您也可以使用快捷命令 `sb` 重新打开此菜单。

```
╔══════════════════════════════════════╗
║         Sing-box 管理脚本 v3.0       ║
╠══════════════════════════════════════╣
║  1. 协议配置                         ║
║  2. 服务管理                         ║
║  3. 配置管理                         ║
║  4. 分享链接                         ║
║  5. 系统工具                         ║
║  0. 退出脚本                         ║
╚══════════════════════════════════════╝
```

## 🔧 服务管理

```bash
# 服务控制
systemctl start sing-box      # 启动
systemctl stop sing-box       # 停止
systemctl restart sing-box    # 重启
systemctl status sing-box     # 状态

# 开机自启
systemctl enable sing-box     # 启用
systemctl disable sing-box    # 禁用

# 日志查看
journalctl -u sing-box -f     # 实时日志
journalctl -u sing-box --since "1 hour ago"  # 最近1小时
```

## 🔧 支持的协议

### VLESS Reality Vision
- **特点**: 无特征流量，抗检测能力强
- **适用**: 网络环境严格的地区
- **配置**: 自动检测最佳 Reality 目标

### VMess WebSocket
- **特点**: 成熟稳定，兼容性好
- **适用**: 一般网络环境
- **配置**: 支持 TLS 和非 TLS 模式

### Hysteria2
- **特点**: 基于 UDP，速度快
- **适用**: 对速度要求高的场景
- **配置**: 自动带宽检测和优化

## 📁 项目结构

```
singbox/
├── singbox-install.sh          # 主安装脚本
├── lib/                         # 核心模块
│   ├── common.sh               # 通用函数库
│   ├── protocols.sh            # 协议配置模块
│   ├── menu.sh                 # 菜单模块
│   └── subscription.sh         # 订阅生成模块
├── templates/                   # 配置模板
│   ├── config.json             # 基础配置模板
│   └── sing-box.service        # 系统服务模板
└── issues/                      # 项目文档
    └── 精简重构计划-v1.0.md     # 重构计划
```

## 🛠️ 配置管理

### 配置文件位置

```
/etc/sing-box/
├── config.json              # 主配置文件
├── geoip.db                # GeoIP 数据库
└── geosite.db              # GeoSite 数据库

/opt/sing-box/
├── clients/                # 客户端配置
├── qrcodes/               # 二维码文件
├── subscription/          # 订阅文件
└── certs/                 # 证书文件
```

### 配置操作

```bash
# 验证配置
sing-box check -c /etc/sing-box/config.json

# 重载配置
systemctl reload sing-box

# 备份配置
cp /etc/sing-box/config.json /opt/sing-box/config.json.backup
```

## 🔗 客户端配置

### 获取配置方式

1. **分享链接** - 复制粘贴到客户端
2. **二维码** - 扫码导入
3. **配置文件** - 下载 JSON 配置
4. **订阅链接** - 支持批量更新

### 支持的客户端

- **Windows**: v2rayN, Clash for Windows, sing-box
- **macOS**: ClashX Pro, sing-box
- **iOS**: Shadowrocket, Quantumult X
- **Android**: v2rayNG, ClashForAndroid
- **Linux**: sing-box, Clash

## 🐛 故障排除

### 常见问题

#### 服务启动失败
```bash
# 检查配置语法
sing-box check -c /etc/sing-box/config.json

# 查看错误日志
journalctl -u sing-box --no-pager
```

#### 端口冲突
```bash
# 检查端口占用
ss -tlnp | grep :443

# 修改配置中的端口
vim /etc/sing-box/config.json
```

#### 防火墙问题
```bash
# Ubuntu/Debian
ufw allow 443/tcp

# CentOS/RHEL
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --reload
```

## 📈 性能优化

### 系统优化
```bash
# 增加文件描述符限制
echo "* soft nofile 65535" >> /etc/security/limits.conf
echo "* hard nofile 65535" >> /etc/security/limits.conf

# 网络参数优化
echo "net.core.rmem_max = 134217728" >> /etc/sysctl.conf
echo "net.core.wmem_max = 134217728" >> /etc/sysctl.conf
sysctl -p
```

## 🔒 安全建议

1. **定期更新** - 保持系统和 Sing-box 最新版本
2. **防火墙配置** - 只开放必要端口
3. **密钥管理** - 定期更换 UUID 和密钥
4. **日志监控** - 定期检查异常访问
5. **配置备份** - 定期备份重要配置

## 📝 更新日志

### v3.0.0-beta1 (2024-01-20)
- 🔄 **重大重构** - 精简架构，提升性能
- 📦 **模块化设计** - 清晰的代码结构
- 🚀 **安装优化** - 更快的部署速度
- 🔧 **功能整合** - 核心功能集中管理
- 📱 **客户端增强** - 更好的配置生成

### v2.1.0 (2024-01-15)
- 新增 Hysteria2 协议支持
- 优化配置生成逻辑
- 改进错误处理机制



## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

### 开发流程
```bash
# 克隆仓库
git clone https://github.com/Yan-nian/singbox-install-script.git
cd singbox

# 创建功能分支
git checkout -b feature/your-feature

# 提交更改
git commit -am "Add your feature"
git push origin feature/your-feature
```

### 代码规范
- 使用 4 个空格缩进
- 函数名使用下划线命名
- 添加适当的注释
- 遵循 Shell 最佳实践



## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 📞 联系方式

- **GitHub Issues**: [提交问题](https://github.com/Yan-nian/singbox-install-script/issues)
- **讨论区**: [GitHub Discussions](https://github.com/Yan-nian/singbox-install-script/discussions)

## ⚠️ 免责声明

本项目仅供学习和研究使用，请遵守当地法律法规。使用本脚本产生的任何后果由用户自行承担。

---

**Sing-box 精简安装脚本 v3.0** - 让部署更简单，让使用更便捷！