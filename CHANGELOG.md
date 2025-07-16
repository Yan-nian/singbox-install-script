# 更新日志

本文档记录了 Sing-box 一键配置脚本的所有重要更改。

## [v1.0.2] - 2024年

### 📝 文档更新
- **改进**: 更新 README.md 安装说明，提供本地安装和远程安装两种方式
- **新增**: `DEPLOYMENT.md` - 详细的部署指南和问题解决方案
- **修复**: 修正安装链接指向错误仓库的问题
- **优化**: 添加用户名占位符提醒，避免链接错误

### 🔧 改进
- **部署**: 提供完整的 Git 部署流程
- **验证**: 添加语法检查和功能测试指南
- **通知**: 明确用户问题解决方案和重新安装步骤

### 🚨 重要说明
- 解决了用户执行远程旧版本脚本导致的错误问题
- 推荐使用本地克隆方式安装以确保使用最新修复版本

---

## [v1.0.1] - 2024年

### 🐛 Bug 修复
- **修复**: 修复 `install.sh` 中 `CONFIG_FILE` 变量未定义导致的语法错误
- **问题**: 在 `create_initial_config()` 函数中使用未定义的 `$CONFIG_FILE` 变量
- **解决**: 在全局变量部分添加 `CONFIG_FILE="$CONFIG_DIR/config.json"` 定义
- **影响**: 解决了脚本执行时 `/dev/fd/63: line 313: : No such file or directory` 错误

### 📝 文档更新
- **新增**: `BUGFIX.md` - 详细的问题分析和修复报告
- **新增**: `test_syntax.sh` - 语法检查测试脚本
- **新增**: `CHANGELOG.md` - 版本更新历史记录

### 🔧 改进
- **优化**: 改进了变量定义的规范性
- **增强**: 添加了语法检查工具

---

## [v1.0.0] - 2024年

### 🎉 首次发布

#### ✨ 核心功能
- **协议支持**: VLESS Reality、VMess、Hysteria2 三种协议
- **一键安装**: 自动化安装和配置流程
- **配置管理**: 添加、删除、查看、修改配置
- **分享功能**: 生成分享链接和二维码
- **服务管理**: 启动、停止、重启、状态查看
- **系统管理**: 完整卸载、日志查看

#### 📁 项目结构
- `install.sh` - 一键安装脚本
- `sing-box.sh` - 主管理脚本
- `README.md` - 详细使用文档
- `需求文档.md` - 项目需求分析
- `实现计划.md` - 开发计划和技术细节
- `LICENSE` - GPL v3 开源协议

#### 🛠️ 技术特性
- **系统支持**: Ubuntu、Debian、CentOS
- **架构支持**: amd64、arm64、armv7
- **自动化**: 依赖安装、目录创建、服务配置
- **安全性**: Reality 协议、TLS 加密
- **易用性**: 命令行界面、帮助文档

#### 📋 支持的命令
```bash
# 基础命令
sing-box add <protocol>     # 添加配置
sing-box list               # 列出配置
sing-box info <name>        # 查看详情
sing-box del <name>         # 删除配置
sing-box url <name>         # 获取分享链接
sing-box qr <name>          # 生成二维码
sing-box port <name> <port> # 更换端口

# 系统管理
sing-box start              # 启动服务
sing-box stop               # 停止服务
sing-box restart            # 重启服务
sing-box status             # 查看状态
sing-box log                # 查看日志
sing-box uninstall          # 卸载脚本

# 其他
sing-box version            # 显示版本
sing-box help               # 显示帮助
```

#### 🎯 设计目标
- **简单易用**: 一键安装，简单配置
- **功能完整**: 涵盖常用代理协议
- **维护方便**: 模块化设计，易于扩展
- **安全可靠**: 遵循最佳实践

---

## 版本说明

### 版本号格式
采用语义化版本控制 (Semantic Versioning):
- **主版本号**: 不兼容的 API 修改
- **次版本号**: 向下兼容的功能性新增
- **修订号**: 向下兼容的问题修正

### 更新类型
- 🎉 **新功能** (Features)
- 🐛 **Bug修复** (Bug Fixes)
- 📝 **文档** (Documentation)
- 🔧 **改进** (Improvements)
- ⚡ **性能** (Performance)
- 🔒 **安全** (Security)
- 💥 **破坏性变更** (Breaking Changes)

### 支持政策
- **当前版本**: 完全支持，持续更新
- **前一版本**: 安全更新和重要修复
- **更早版本**: 仅安全更新

---

**维护者**: Sing-box 脚本开发团队  
**许可证**: GPL v3  
**仓库**: https://github.com/your-repo/sing-box-script