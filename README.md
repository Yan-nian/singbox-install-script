# sing-box 服务器端一键部署脚本

这是一个功能完整的 sing-box 服务器端一键部署脚本，支持多种主流代理协议的自动配置和管理。

## 功能特性

### 🚀 核心功能
- **多协议支持**: Reality、Hysteria2、VMess WebSocket TLS
- **内核管理**: 自动下载、安装和升级 sing-box 内核
- **端口管理**: 支持动态更换服务端口，自动更新防火墙规则
- **服务管理**: 完整的服务生命周期管理（安装、卸载、启动、停止、重启）
- **状态监控**: 实时查看服务运行状态、配置信息和连接日志
- **配置管理**: 自动生成客户端连接配置，支持配置文件的查看和备份
- **分享功能**: 自动生成分享链接和二维码，支持多种客户端导入

### 🛡️ 安全特性
- 自动生成密钥对和证书
- 支持 Reality 协议的真实 TLS 握手
- 防火墙规则自动配置
- 配置文件权限管理

### 📊 管理功能
- 交互式菜单界面
- 配置备份和恢复
- 日志查看和监控
- 内核版本管理
- 完整的卸载清理

### 📱 分享功能
- **二维码生成**: 自动生成配置二维码，支持手机客户端扫码导入
- **分享链接**: 生成标准格式的分享链接，兼容主流客户端
- **多种方式**: 支持终端显示、PNG文件保存、在线二维码生成
- **客户端兼容**: 支持 v2rayN、Clash、sing-box 等主流客户端

## 系统要求

### 支持的操作系统
- Ubuntu 18.04+
- Debian 9+
- CentOS 7+
- RHEL 7+
- Arch Linux

### 系统要求
- **内存**: 最低 512MB，推荐 1GB+
- **磁盘空间**: 最低 1GB 可用空间
- **网络**: 需要能够访问 GitHub 和相关下载源
- **权限**: 需要 root 权限运行

### 依赖软件
脚本会自动检查并安装以下依赖：
- `curl` 或 `wget` - 用于下载文件
- `openssl` - 用于生成证书和密钥
- `jq` - 用于处理 JSON 配置文件
- `systemd` - 用于服务管理
- `qrencode` - 用于生成二维码（可选，自动安装）

## 快速开始

### 一键安装命令
wget -O singbox-install.sh https://raw.githubusercontent.com/Yan-nian/singbox-install-script/master/singbox-install.sh && chmod +x singbox-install.sh && sudo ./singbox-install.sh

## 使用说明

### 主菜单选项

运行脚本后，您将看到以下主菜单：

```
==================================================
sing-box一键部署脚本 v1.0.0
==================================================

请选择操作:

1. 安装 sing-box
2. 卸载 sing-box
3. 启动服务
4. 停止服务
5. 重启服务
6. 查看服务状态
7. 查看配置信息
8. 查看日志
9. 更换端口
10. 升级内核
11. 备份配置
12. 恢复配置
13. 生成分享二维码
0. 退出脚本
```

### 协议配置

#### Reality 协议（推荐）
- **特点**: 最新的代理协议，具有极强的抗检测能力
- **端口**: 默认 443，可自定义
- **配置**: 自动生成密钥对和短ID
- **目标域名**: 默认 www.microsoft.com，可自定义

#### Hysteria2 协议
- **特点**: 基于 QUIC 的高性能代理协议
- **端口**: 随机生成，可自定义
- **认证**: 密码认证，自动生成或手动设置
- **证书**: 自动生成自签名证书

#### VMess WebSocket TLS 协议
- **特点**: 经典的代理协议，兼容性好
- **端口**: 默认 443，可自定义
- **传输**: WebSocket + TLS
- **路径**: 随机生成，可自定义

### 分享二维码功能
脚本提供了便捷的节点分享功能：

#### 生成方式
1. **终端二维码**: 直接在终端显示二维码（需要安装 qrencode）
2. **PNG文件**: 保存二维码图片到配置目录
3. **在线二维码**: 提供在线二维码生成链接
4. **分享链接**: 显示标准格式的分享链接

#### 支持的客户端
- **Windows**: v2rayN, Clash for Windows, sing-box
- **Android**: v2rayNG, Clash for Android, sing-box
- **iOS**: Shadowrocket, Quantumult X, sing-box
- **macOS**: ClashX, V2rayU, sing-box

#### 使用方法
```bash
sudo ./singbox-install.sh
# 选择菜单项 "13. 生成分享二维码"
```

## 配置文件位置

### 主要文件
- **配置文件**: `/etc/sing-box/config.json`
- **日志文件**: `/var/log/sing-box/sing-box.log`
- **客户端配置**: `/etc/sing-box/*-client.json`
- **证书文件**: `/etc/sing-box/certs/`
- **备份目录**: `/etc/sing-box/backup/`

### 系统文件
- **程序文件**: `/usr/local/bin/sing-box`
- **服务文件**: `/etc/systemd/system/sing-box.service`

## 常用命令

### 服务管理
```bash
# 查看服务状态
systemctl status sing-box

# 启动服务
systemctl start sing-box

# 停止服务
systemctl stop sing-box

# 重启服务
systemctl restart sing-box

# 查看日志
journalctl -u sing-box -f
```

### 配置管理
```bash
# 验证配置文件
/usr/local/bin/sing-box check -c /etc/sing-box/config.json

# 查看版本
/usr/local/bin/sing-box version
```

## 故障排除

### 常见问题

#### 1. 服务启动失败
```bash
# 查看详细错误信息
systemctl status sing-box -l
journalctl -u sing-box --no-pager

# 检查配置文件
/usr/local/bin/sing-box check -c /etc/sing-box/config.json
```

#### 2. 端口被占用
```bash
# 查看端口占用情况
netstat -tuln | grep :端口号
ss -tuln | grep :端口号

# 使用脚本更换端口
sudo ./singbox-install.sh
# 选择菜单项 "9. 更换端口"
```

#### 3. 防火墙问题
```bash
# Ubuntu/Debian (UFW)
sudo ufw allow 端口号

# CentOS/RHEL (firewalld)
sudo firewall-cmd --permanent --add-port=端口号/tcp
sudo firewall-cmd --reload

# 通用 (iptables)
sudo iptables -I INPUT -p tcp --dport 端口号 -j ACCEPT
```

#### 4. 网络连接问题
- 检查服务器网络连接
- 确认防火墙规则正确
- 验证域名解析（Reality 协议）
- 检查客户端配置是否正确

### 日志分析

#### 查看实时日志
```bash
tail -f /var/log/sing-box/sing-box.log
```

#### 查看错误日志
```bash
grep -i "error\|fail\|fatal" /var/log/sing-box/sing-box.log
```

## 安全建议

### 服务器安全
1. **定期更新**: 保持系统和 sing-box 内核为最新版本
2. **防火墙配置**: 只开放必要的端口
3. **SSH 安全**: 使用密钥认证，禁用密码登录
4. **监控日志**: 定期检查访问日志，发现异常及时处理

### 配置安全
1. **定期备份**: 使用脚本的备份功能定期备份配置
2. **密钥管理**: 妥善保管私钥和密码
3. **端口变更**: 定期更换服务端口
4. **访问控制**: 限制客户端连接数量

## 更新日志

### v1.0.0 (2024-01-XX)
- 初始版本发布
- 支持 Reality、Hysteria2、VMess WebSocket TLS 协议
- 完整的服务管理功能
- 配置备份和恢复功能
- 内核自动升级功能

## 贡献

欢迎提交 Issue 和 Pull Request 来改进这个脚本。

### 开发环境
- Bash 4.0+
- 支持的 Linux 发行版
- 具有 root 权限的测试环境

## 许可证

本项目采用 MIT 许可证，详见 LICENSE 文件。

## 免责声明

本脚本仅供学习和研究使用，请遵守当地法律法规。使用本脚本所产生的任何后果由使用者自行承担。

## 支持

如果您在使用过程中遇到问题，可以：

1. 查看本文档的故障排除部分
2. 提交 GitHub Issue
3. 查看 sing-box 官方文档：https://sing-box.sagernet.org/

---

**注意**: 首次安装后，请妥善保存客户端配置信息和分享链接，建议截图或复制到安全的地方保存。