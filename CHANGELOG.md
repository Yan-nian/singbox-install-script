# 更新日志

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