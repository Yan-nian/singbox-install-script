# Sing-box 一键安装脚本

一个功能完整的 Sing-box 服务器端一键搭建脚本，支持多种主流代理协议的快速部署和管理。

> **⚠️ 重要说明**: 本项目中的 GitHub URL（如 `your-repo/singbox-install`）为占位符，请根据实际情况替换为您的仓库地址。脚本已优化为本地使用模式，无需网络下载。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-v1.1.0-blue.svg)](#)
[![Platform](https://img.shields.io/badge/platform-Linux-lightgrey.svg)](#)

## ✨ 特性

- 🚀 **一键安装**: 自动检测系统环境，一键完成 Sing-box 的下载、安装和配置
- 🔧 **多协议支持**: 支持 VLESS Reality Vision、VMess WebSocket、Hysteria2 等主流协议
- 🎯 **智能配置**: 自动生成最优配置文件，无需手动编辑复杂的 JSON 配置
- 🛡️ **安全可靠**: 内置安全最佳实践，自动配置防火墙和 TLS 证书
- 📱 **客户端支持**: 自动生成客户端配置文件和分享链接
- 🔄 **服务管理**: 完整的服务启停、重启、状态查看功能
- 📊 **实时监控**: 支持流量统计、连接状态监控
- 🌐 **多系统支持**: 支持 Ubuntu、Debian、CentOS、RHEL 等主流 Linux 发行版
- 🎨 **友好界面**: 彩色交互式菜单，操作简单直观
- 🔐 **自动化配置**: UUID、密钥、证书自动生成
- 🌍 **多语言**: 支持中文界面
- 📋 **二维码生成**: 自动生成客户端配置二维码

## 🖥️ 系统要求

### 支持的操作系统
- Ubuntu 18.04+
- Debian 9+
- CentOS 7+
- RHEL 7+
- Rocky Linux 8+
- AlmaLinux 8+
- Fedora 30+

### 系统架构
- x86_64 (amd64)
- ARM64 (aarch64)
- ARMv7

### 最低配置要求
- **内存**: 512MB RAM
- **存储**: 1GB 可用空间
- **网络**: 公网 IP 地址
- **权限**: Root 权限
- **端口**: 确保所需端口未被占用

## 🚀 快速安装

### 方法一：在线一键安装（推荐）⭐

**真正的一键安装，无需下载任何文件！**

```bash
# 使用 curl（推荐）
curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/main/one-click-install.sh | sudo bash

# 或使用 wget
wget -qO- https://raw.githubusercontent.com/Yan-nian/singbox-install-script/main/one-click-install.sh | sudo bash
```

**直接安装特定协议：**

```bash
# 直接安装 VLESS Reality Vision
curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/main/one-click-install.sh | sudo bash -s -- --vless

# 直接安装 VMess WebSocket
curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/main/one-click-install.sh | sudo bash -s -- --vmess

# 直接安装 Hysteria2
curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/main/one-click-install.sh | sudo bash -s -- --hysteria2
```

> 📖 详细说明请查看：[在线安装文档](ONLINE_INSTALL.md)

### 方法二：快速安装

```bash
# 1. 下载完整项目
git clone https://github.com/Yan-nian/singbox-install-script.git
cd singbox-install-script

# 2. 运行快速安装脚本
sudo bash quick-install.sh
```

### 方法三：手动安装

```bash
# 1. 下载脚本
git clone https://github.com/Yan-nian/singbox-install-script.git
cd singbox-install-script

# 2. 添加执行权限
chmod +x install.sh

# 3. 运行安装脚本
sudo ./install.sh
```

### 方法四：仅下载主脚本

```bash
# 下载项目并使用主脚本
git clone https://github.com/Yan-nian/singbox-install-script.git
cd singbox-install-script
chmod +x install.sh
sudo ./install.sh
```

## 📖 使用说明

### 交互式安装

运行脚本后，按照提示选择要安装的协议：

```bash
sudo ./install.sh
```

### 命令行安装

```bash
# 显示帮助信息
./install.sh --help

# 显示版本信息
./install.sh --version

# 直接安装 Sing-box
sudo ./install.sh --install

# 配置 VLESS Reality Vision
sudo ./install.sh --vless

# 配置 VMess WebSocket
sudo ./install.sh --vmess

# 配置 VMess WebSocket + TLS
sudo ./install.sh --vmess-tls

# 配置 Hysteria2
sudo ./install.sh --hysteria2

# 配置多协议
sudo ./install.sh --multi

# 查看服务状态
sudo ./install.sh --status

# 配置向导模式
sudo ./install.sh --config

# 卸载 Sing-box
sudo ./install.sh --uninstall
```

### 服务管理

```bash
# 启动服务
sudo systemctl start sing-box

# 停止服务
sudo systemctl stop sing-box

# 重启服务
sudo systemctl restart sing-box

# 重载配置
sudo systemctl reload sing-box

# 查看状态
sudo systemctl status sing-box

# 启用开机自启
sudo systemctl enable sing-box

# 禁用开机自启
sudo systemctl disable sing-box

# 查看日志
sudo journalctl -u sing-box -f

# 查看最近日志
sudo journalctl -u sing-box --since "1 hour ago"
```

## 🔧 支持的协议

### VLESS Reality Vision
- ✅ 最新的伪装技术，抗检测能力极强
- ✅ 无需额外域名和证书
- ✅ 性能优异，延迟低
- ✅ 配置简单，一键生成
- ✅ 支持多种目标网站伪装

### VMess WebSocket
- ✅ 成熟稳定的协议
- ✅ 兼容性好，客户端支持广泛
- ✅ 支持 CDN 加速
- ✅ 可选 TLS 加密
- ✅ 自定义 WebSocket 路径

### VMess WebSocket + TLS
- ✅ 在 VMess WebSocket 基础上增加 TLS 加密
- ✅ 更高的安全性
- ✅ 支持自签名证书
- ✅ 支持域名证书

### Hysteria2
- ✅ 基于 QUIC 协议，性能卓越
- ✅ 低延迟高吞吐量
- ✅ 网络自适应，智能拥塞控制
- ✅ 抗丢包能力强
- ✅ 支持带宽检测和优化
- ✅ 支持端口跳跃

## 📁 项目结构

```
sing-box/
├── install.sh              # 主安装脚本
├── quick-install.sh        # 快速安装脚本
├── one-click-install.sh    # 在线一键安装脚本 ⭐
├── scripts/                # 功能模块
│   ├── common.sh          # 公共函数库
│   ├── system.sh          # 系统检测模块
│   ├── singbox.sh         # Sing-box 管理模块
│   ├── config.sh          # 配置文件生成模块
│   ├── service.sh         # 服务管理模块
│   ├── menu.sh            # 用户界面模块
│   └── protocols/         # 协议配置模块
│       ├── vless.sh       # VLESS Reality Vision
│       ├── vmess.sh       # VMess WebSocket
│       └── hysteria2.sh   # Hysteria2
├── templates/             # 配置模板
│   ├── config-base.json   # 基础配置模板
│   ├── vless-reality.json # VLESS Reality 模板
│   ├── vmess-ws.json      # VMess WebSocket 模板
│   ├── vmess-ws-tls.json  # VMess WebSocket TLS 模板
│   ├── hysteria2.json     # Hysteria2 模板
│   └── client-base.json   # 客户端基础模板
├── docs/                  # 文档目录
│   ├── usage.md           # 使用说明
│   └── protocols.md       # 协议说明
├── README.md              # 项目说明
├── ONLINE_INSTALL.md      # 在线安装说明 ⭐
├── LICENSE                # 许可证
├── VERSION                # 版本信息
├── CHANGELOG.md           # 更新日志
└── .gitignore            # Git 忽略文件
```

## 🎯 功能特性

### 自动化功能
- 🔍 **系统检测**: 自动检测操作系统、架构、网络环境
- 📦 **依赖安装**: 自动安装所需依赖包
- 🔑 **密钥生成**: 自动生成 UUID、Reality 密钥对、随机密码
- 🌐 **IP 检测**: 自动获取公网 IP 地址
- 🔥 **防火墙配置**: 自动配置防火墙规则
- 📜 **证书管理**: 自动生成和管理 TLS 证书

### 配置管理
- 📝 **配置生成**: 智能生成 Sing-box 配置文件
- 💾 **配置备份**: 自动备份配置文件
- 🔄 **配置恢复**: 支持配置文件恢复
- ✅ **配置验证**: 自动验证配置文件正确性
- 📊 **配置查看**: 美观的配置信息显示

### 客户端支持
- 📱 **多平台配置**: 生成适用于各平台的客户端配置
- 🔗 **分享链接**: 自动生成分享链接
- 📋 **二维码**: 生成配置二维码，手机扫码导入
- 📄 **配置文件**: 导出标准 JSON 配置文件

### 监控和管理
- 📈 **状态监控**: 实时查看服务运行状态
- 📊 **流量统计**: 查看流量使用情况
- 🔍 **日志查看**: 方便的日志查看功能
- 🔧 **服务管理**: 完整的服务启停控制
- 🛠️ **故障诊断**: 自动诊断常见问题

## 🔍 版本历史

### v1.1.0 (2024-01-01)
- 🚀 **新增在线一键安装功能**
- ✨ 添加 `one-click-install.sh` 自包含安装脚本
- 🌐 支持通过 curl/wget 直接安装，无需 git clone
- 📖 新增 `ONLINE_INSTALL.md` 在线安装文档
- 🎯 支持命令行参数直接安装特定协议
- 🔧 优化安装流程，提升用户体验
- 📦 自动检测和安装系统依赖
- 🛡️ 增强安全性和错误处理

### v1.0.0 (2024-01-01)
- 🎉 初始版本发布
- ✨ 支持 VLESS Reality Vision 协议
- ✨ 支持 VMess WebSocket 协议
- ✨ 支持 VMess WebSocket + TLS 协议
- ✨ 支持 Hysteria2 协议
- ✨ 完整的服务管理功能
- ✨ 自动配置生成
- ✨ 客户端配置导出
- ✨ 交互式菜单界面
- ✨ 命令行参数支持
- ✨ 模块化架构设计

查看完整更新日志：[CHANGELOG.md](CHANGELOG.md)

## 📚 文档

- [使用说明](docs/usage.md) - 详细的使用指南
- [协议说明](docs/protocols.md) - 各协议的详细配置说明
- [更新日志](CHANGELOG.md) - 版本更新记录
- [许可证](LICENSE) - 项目许可证

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

### 贡献指南

1. Fork 本项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

### 开发环境

```bash
# 克隆项目
git clone https://github.com/your-repo/singbox-install.git
cd singbox-install

# 安装开发依赖
sudo apt-get install shellcheck

# 运行测试
bash -n install.sh  # 语法检查
shellcheck install.sh  # 代码质量检查
```

## 🐛 问题反馈

如果你遇到任何问题，请通过以下方式反馈：

1. [GitHub Issues](https://github.com/your-repo/singbox-install/issues) - 推荐
2. 邮箱：support@example.com
3. Telegram：@your_telegram

### 反馈时请提供

- 操作系统版本
- 脚本版本
- 错误信息截图
- 详细的操作步骤

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## ⚠️ 免责声明

本脚本仅供学习和研究使用，请遵守当地法律法规。使用本脚本所产生的任何后果由使用者自行承担。

## 🙏 致谢

感谢以下项目和贡献者：

- [sing-box](https://github.com/SagerNet/sing-box) - 优秀的代理工具
- 所有贡献者和用户的支持

## 📞 支持

- 📧 邮箱：support@example.com
- 💬 Telegram：@your_telegram
- 🐛 问题反馈：[GitHub Issues](https://github.com/your-repo/singbox-install/issues)
- 📖 文档：[项目文档](https://github.com/your-repo/singbox-install/wiki)

---

⭐ 如果这个项目对你有帮助，请给个 Star 支持一下！

[![Star History Chart](https://api.star-history.com/svg?repos=your-repo/singbox-install&type=Date)](https://star-history.com/#your-repo/singbox-install&Date)