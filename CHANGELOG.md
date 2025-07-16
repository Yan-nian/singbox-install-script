# 更新日志

所有重要的项目变更都会记录在这个文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
并且本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [2.0.1] - 2024-12-19

### 修复
- **在线执行支持**: 修复通过curl管道执行时模块加载失败的问题
- **模块下载**: 添加在线执行时自动下载模块文件的功能
- **临时文件清理**: 添加脚本退出时自动清理临时模块文件的机制
- **错误处理**: 改进模块加载的错误处理和用户提示

### 技术改进
- 检测在线执行环境（/dev/fd路径）
- 自动从GitHub下载所需模块文件
- 使用trap机制确保临时文件清理
- 增强脚本的容错性和用户体验

---

## [3.0.0-beta1] - 2024-01-20

### 🔄 重大重构 - 精简架构

这是一个重大的架构重构版本，专注于简化和优化核心功能。

#### 新增
- 🏗️ **全新模块化架构** - 采用精简的模块设计
- 📦 **统一安装脚本** - `singbox-install.sh` 作为单一入口点
- 🔧 **核心模块库** - `lib/` 目录包含所有核心功能
  - `common.sh` - 通用函数库
  - `protocols.sh` - 协议配置模块
  - `menu.sh` - 菜单系统
  - `subscription.sh` - 订阅生成模块
- 📋 **配置模板系统** - 标准化的 JSON 配置模板
- 🔗 **增强的订阅功能** - 完整的分享链接和订阅生成
- 📱 **客户端配置生成** - 自动生成各平台客户端配置
- 📊 **二维码支持** - 自动生成配置二维码
- 🎯 **精简重构计划** - 详细的重构文档和计划

#### 变更
- 🗂️ **简化目录结构** - 移除复杂的嵌套目录
- ⚡ **优化安装流程** - 更快的部署和配置过程
- 🎨 **改进用户界面** - 更清晰的菜单和交互
- 🔧 **统一配置管理** - 集中的配置文件管理
- 📝 **更新文档** - 全新的 README 和使用指南

#### 移除
- 🗑️ **清理冗余模块** - 移除 `core/`, `system/`, `tests/`, `ui/`, `utils/`, `docs/`, `generators/` 目录
- 🧹 **简化依赖** - 移除不必要的复杂功能
- 📦 **精简代码** - 移除重复和冗余的代码

#### 修复
- 🐛 **模块加载优化** - 改进模块加载机制
- 🔒 **权限管理** - 优化文件和目录权限设置
- 📊 **配置提取** - 改进从现有配置文件提取信息的功能

#### 技术改进
- 🏗️ **架构优化** - 采用更清晰的模块化设计
- 📈 **性能提升** - 减少资源占用，提高执行效率
- 🛡️ **安全增强** - 改进安全配置和权限管理
- 🔧 **维护性** - 更易于维护和扩展的代码结构

### 升级指南

从 v2.x 升级到 v3.0：

1. **备份现有配置**：
   ```bash
   cp /etc/sing-box/config.json /opt/sing-box/config.json.backup
   ```

2. **下载新版本**：
   ```bash
   wget https://raw.githubusercontent.com/Yan-nian/singbox-install-script/master/singbox-install.sh
   chmod +x singbox-install.sh
   ```

3. **运行新脚本**：
   ```bash
   ./singbox-install.sh
   ```

新版本会自动检测并导入现有配置。

---

## [v1.1.0] - 2024-01-01

### 🚀 重大更新
- ✨ **新增在线一键安装功能** - 真正的一键安装体验
- 🌐 支持通过 curl/wget 直接安装，无需 git clone
- 📦 创建自包含安装脚本 `one-click-install.sh`

### 新增功能
- ✨ 在线一键安装脚本，集成所有必要模块
- ✨ 支持命令行参数直接安装特定协议
- ✨ 自动检测和安装系统依赖
- ✨ 增强的错误处理和用户提示
- ✨ 支持多种安装方式选择

### 安装方式
```bash
# 在线一键安装（推荐）
curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/main/one-click-install.sh | sudo bash

# 直接安装特定协议
curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/main/one-click-install.sh | sudo bash -s -- --vless
curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/main/one-click-install.sh | sudo bash -s -- --vmess
curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/main/one-click-install.sh | sudo bash -s -- --hysteria2
```

### 文档更新
- 📖 新增 `ONLINE_INSTALL.md` 在线安装详细文档
- 📖 更新 `README.md` 添加在线安装说明
- 📖 完善部署和使用指南

### 技术改进
- 🔧 优化安装流程，减少用户操作步骤
- 🔧 增强脚本的健壮性和容错能力
- 🔧 改进日志记录和错误提示
- 🔧 优化网络连接检测

### 项目结构更新
```
sing-box/
├── install.sh              # 主安装脚本
├── quick-install.sh        # 快速安装脚本
├── one-click-install.sh    # 在线一键安装脚本 ⭐ NEW
├── ONLINE_INSTALL.md       # 在线安装说明 ⭐ NEW
└── ...
```

---

## [v1.0.0] - 2024-01-01

### 新增功能
- ✨ 初始版本发布
- ✨ 支持 VLESS Reality Vision 协议配置
- ✨ 支持 VMess WebSocket 协议配置
- ✨ 支持 VMess WebSocket + TLS 协议配置
- ✨ 支持 Hysteria2 协议配置
- ✨ 支持多协议同时配置
- ✨ 自动系统检测和依赖安装
- ✨ 完整的服务管理功能
- ✨ 客户端配置自动生成
- ✨ 分享链接和二维码生成
- ✨ 交互式菜单界面
- ✨ 命令行参数支持
- ✨ 完整的日志记录
- ✨ 配置文件备份和恢复
- ✨ 防火墙自动配置
- ✨ TLS 证书自动生成
- ✨ 网络连通性测试
- ✨ 性能优化建议

### 技术特性
- 🔧 模块化架构设计
- 🔧 支持 Ubuntu/Debian/CentOS/RHEL 系统
- 🔧 支持 x86_64/ARM64/ARMv7 架构
- 🔧 systemd 服务管理
- 🔧 JSON 配置文件生成
- 🔧 Reality 密钥对自动生成
- 🔧 UUID 自动生成
- 🔧 端口冲突检测
- 🔧 公网 IP 自动获取
- 🔧 带宽检测和优化

### 文档
- 📚 完整的使用说明文档
- 📚 协议配置详细说明
- 📚 故障排除指南
- 📚 性能优化建议
- 📚 安全配置建议

### 项目结构
```
sing-box/
├── install.sh              # 主安装脚本
├── scripts/                 # 功能模块
│   ├── common.sh           # 公共函数库
│   ├── system.sh           # 系统检测模块
│   ├── singbox.sh          # Sing-box 管理模块
│   ├── config.sh           # 配置文件生成模块
│   ├── service.sh          # 服务管理模块
│   ├── menu.sh             # 用户界面模块
│   └── protocols/          # 协议配置模块
│       ├── vless.sh        # VLESS Reality Vision
│       ├── vmess.sh        # VMess WebSocket
│       └── hysteria2.sh    # Hysteria2
├── templates/              # 配置模板
│   ├── config-base.json    # 基础配置模板
│   ├── vless-reality.json  # VLESS Reality 模板
│   ├── vmess-ws.json       # VMess WebSocket 模板
│   ├── vmess-ws-tls.json   # VMess WebSocket TLS 模板
│   ├── hysteria2.json      # Hysteria2 模板
│   └── client-base.json    # 客户端基础模板
├── docs/                   # 文档目录
│   ├── usage.md            # 使用说明
│   └── protocols.md        # 协议说明
├── README.md               # 项目说明
├── VERSION                 # 版本信息
└── CHANGELOG.md            # 更新日志
```

---

## 版本说明

- **主版本号**: 重大功能更新或架构变更
- **次版本号**: 新功能添加或重要改进
- **修订版本号**: 错误修复和小幅改进

## 贡献指南

欢迎提交 Issue 和 Pull Request 来帮助改进这个项目。

## 许可证

本项目采用 MIT 许可证。