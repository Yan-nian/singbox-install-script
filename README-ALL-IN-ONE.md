# Sing-box 全能一键安装脚本

## 概述

`singbox-all-in-one.sh` 是一个完全独立的 Sing-box 安装和配置脚本，将原本分散在多个模块中的功能整合到一个文件中，无需依赖外部模块文件。

## 主要特点

### ✅ 完全独立
- **单文件运行**: 所有功能集成在一个脚本文件中
- **无外部依赖**: 不需要 `lib/` 目录下的模块文件
- **即下即用**: 下载后可直接运行，无需额外配置

### ✅ 功能完整
- **三协议支持**: VLESS Reality Vision、VMess WebSocket、Hysteria2
- **自动安装**: 自动下载和安装最新版本的 Sing-box
- **智能配置**: 自动生成配置文件和证书
- **服务管理**: 完整的 systemd 服务管理功能

### ✅ 用户友好
- **交互式菜单**: 清晰的菜单导航系统
- **一键配置**: 支持一键配置所有协议
- **分享链接**: 自动生成客户端连接链接
- **状态显示**: 实时显示服务和配置状态

## 使用方法

### 基本使用

```bash
# 下载脚本
wget -O https://raw.githubusercontent.com/Yan-nian/singbox-install-script/master/singbox-all-in-one.sh

# 添加执行权限
chmod +x singbox-all-in-one.sh

# 运行脚本
sudo ./singbox-all-in-one.sh
```

### 命令行参数

```bash
# 启动交互式菜单（默认）
sudo ./singbox-all-in-one.sh

# 直接安装 Sing-box
sudo ./singbox-all-in-one.sh --install

# 一键安装并配置三协议
sudo ./singbox-all-in-one.sh --quick-setup

# 完全卸载
sudo ./singbox-all-in-one.sh --uninstall

# 显示帮助
./singbox-all-in-one.sh --help
```

## 功能对比

| 功能 | 原版脚本 | 全能版脚本 |
|------|----------|------------|
| 文件数量 | 主脚本 + 4个模块 | 单个文件 |
| 外部依赖 | 需要 lib/ 目录 | 无外部依赖 |
| 部署复杂度 | 需要完整目录结构 | 单文件部署 |
| 功能完整性 | ✅ 完整 | ✅ 完整 |
| 维护难度 | 多文件维护 | 单文件维护 |
| 执行效率 | 需要加载模块 | 直接执行 |

## 支持的协议

### 1. VLESS Reality Vision
- **端口**: 自动分配高端口 (10000+)
- **加密**: Reality 技术，抗检测能力强
- **目标**: 自动检测可用的伪装目标
- **密钥**: 自动生成 Reality 密钥对

### 2. VMess WebSocket
- **端口**: 自动分配高端口 (10000+)
- **传输**: WebSocket 协议
- **路径**: 随机生成 WebSocket 路径
- **兼容性**: 支持各种客户端

### 3. Hysteria2
- **端口**: 自动分配高端口 (10000+)
- **协议**: 基于 QUIC 的高速协议
- **混淆**: Salamander 混淆算法
- **证书**: 自动生成自签名证书

## 系统要求

- **操作系统**: Ubuntu 18.04+, Debian 10+, CentOS 7+, RHEL 7+
- **架构**: x86_64 (amd64), ARM64, ARMv7
- **权限**: 需要 root 权限
- **网络**: 需要互联网连接下载 Sing-box

## 安装流程

1. **系统检测**: 自动检测操作系统和架构
2. **依赖安装**: 安装必要的系统依赖
3. **下载安装**: 下载最新版本的 Sing-box
4. **服务配置**: 创建 systemd 服务
5. **协议配置**: 配置选择的协议
6. **启动服务**: 启动并启用服务

## 配置文件位置

- **主配置**: `/var/lib/sing-box/config.json`
- **服务文件**: `/etc/systemd/system/sing-box.service`
- **日志文件**: `/var/log/sing-box.log`
- **证书文件**: `/etc/ssl/private/hysteria.crt` (仅 Hysteria2)

## 常用操作

### 查看服务状态
```bash
sudo systemctl status sing-box
```

### 查看实时日志
```bash
sudo journalctl -u sing-box -f
```

### 重启服务
```bash
sudo systemctl restart sing-box
```

### 编辑配置
```bash
sudo nano /var/lib/sing-box/config.json
sudo systemctl restart sing-box
```

## 故障排除

### 服务无法启动
1. 检查配置文件语法: `sing-box check -c /var/lib/sing-box/config.json`
2. 查看详细日志: `sudo journalctl -u sing-box -n 50`
3. 检查端口占用: `sudo ss -tuln | grep 端口号`

### 连接失败
1. 确认防火墙设置
2. 检查服务器安全组配置
3. 验证客户端配置信息

## 更新日志

### v3.0.0 (All-in-One)
- ✅ 整合所有模块到单个文件
- ✅ 移除外部依赖
- ✅ 优化代码结构
- ✅ 增强错误处理
- ✅ 改进用户体验

## 许可证

本项目采用 MIT 许可证，详见 LICENSE 文件。

## 贡献

欢迎提交 Issue 和 Pull Request 来改进这个脚本。

## 免责声明

本脚本仅供学习和研究使用，请遵守当地法律法规。使用本脚本所产生的任何后果由用户自行承担。