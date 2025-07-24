# Sing-box 一键安装脚本

这是一个功能完整的 Sing-box 一键安装脚本，支持多种代理协议的快速部署和管理。

## 支持的协议

- **VLESS Reality** - 最新的无特征代理协议，推荐使用
- **VMess WebSocket** - 经典的 VMess 协议配合 WebSocket 传输
- **Hysteria2** - 基于 QUIC 的高性能代理协议

## 系统要求

- **操作系统**: Ubuntu 18.04+, Debian 9+, CentOS 7+
- **架构**: x86_64 (amd64), ARM64, ARMv7
- **权限**: 需要 root 权限
- **网络**: 需要能够访问 GitHub 和相关下载源

## 快速开始

### 1. 下载脚本

```bash
wget https://raw.githubusercontent.com/your-repo/singbox-install-script/main/install.sh
# 或者使用 curl
curl -O https://raw.githubusercontent.com/your-repo/singbox-install-script/main/install.sh
```

### 2. 添加执行权限

```bash
chmod +x install.sh
```

### 3. 运行脚本

```bash
sudo ./install.sh
```

## 功能特性

### 🚀 一键安装
- 自动检测系统环境（操作系统、架构）
- 自动安装系统依赖
- 自动下载最新版本的 Sing-box
- 自动创建 systemd 服务

### 🔧 协议配置
- **VLESS Reality**: 自动生成密钥对、UUID，支持自定义伪装域名
- **VMess WebSocket**: 自动生成 UUID，支持自定义 WebSocket 路径
- **Hysteria2**: 自动生成密码，支持混淆功能，自动生成 TLS 证书

### 📊 服务管理
- 启动/停止/重启服务
- 查看服务状态和日志
- 显示当前配置
- 生成客户端配置信息

### 🗑️ 完整卸载
- 一键卸载 Sing-box
- 清理所有配置文件和服务

## 使用说明

### 主菜单选项

运行脚本后，您将看到以下主菜单：

```
╔══════════════════════════════════════════════════════════════╗
║                    Sing-box 一键安装脚本                      ║
║                                                              ║
║  支持协议: VLESS Reality | VMess WebSocket | Hysteria2       ║
║  版本: v1.0.0                                               ║
║  作者: Auto Generated                                        ║
╚══════════════════════════════════════════════════════════════╝

请选择要执行的操作:

1. 安装 VLESS Reality
2. 安装 VMess WebSocket  
3. 安装 Hysteria2
4. 管理现有服务
5. 卸载 Sing-box
0. 退出脚本
```

### 协议配置详解

#### VLESS Reality
- **推荐使用**，具有最佳的抗检测能力
- 需要输入伪装域名（如：www.microsoft.com）
- 默认端口：443
- 自动生成 Reality 密钥对和 UUID

#### VMess WebSocket
- 经典协议，兼容性好
- 默认端口：8080
- 默认 WebSocket 路径：/ws
- 自动生成 UUID

#### Hysteria2
- 基于 QUIC，性能优异
- 默认端口：8443
- 支持密码认证和混淆
- 自动生成自签名证书

### 服务管理

选择「管理现有服务」可以进行以下操作：

1. **启动服务** - 启动 Sing-box 服务
2. **停止服务** - 停止 Sing-box 服务
3. **重启服务** - 重启 Sing-box 服务
4. **查看服务状态** - 显示服务运行状态
5. **查看服务日志** - 实时查看服务日志
6. **显示配置信息** - 显示当前配置文件内容
7. **生成客户端配置** - 显示客户端连接信息

## 客户端配置

安装完成后，脚本会自动显示客户端配置信息，包括：

- 服务器地址（自动获取公网 IP）
- 端口号
- 认证信息（UUID/密码等）
- 协议特定参数
- 分享链接（VLESS Reality）

## 文件位置

- **配置文件**: `/etc/sing-box/config.json`
- **二进制文件**: `/usr/local/bin/sing-box`
- **服务文件**: `/etc/systemd/system/sing-box.service`
- **日志文件**: `/var/log/sing-box-install.log`
- **证书文件**: `/etc/sing-box/cert.pem` 和 `/etc/sing-box/private.key`（仅 Hysteria2）

## 常用命令

```bash
# 查看服务状态
sudo systemctl status sing-box

# 启动服务
sudo systemctl start sing-box

# 停止服务
sudo systemctl stop sing-box

# 重启服务
sudo systemctl restart sing-box

# 查看日志
sudo journalctl -u sing-box -f

# 查看配置
sudo cat /etc/sing-box/config.json
```

## 防火墙配置

安装完成后，请确保防火墙允许相应端口的流量：

```bash
# Ubuntu/Debian (ufw)
sudo ufw allow 443/tcp  # VLESS Reality
sudo ufw allow 8080/tcp # VMess WebSocket
sudo ufw allow 8443/udp # Hysteria2

# CentOS/RHEL (firewalld)
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --permanent --add-port=8443/udp
sudo firewall-cmd --reload
```

## 故障排除

### 服务无法启动

1. 检查配置文件语法：
   ```bash
   sudo /usr/local/bin/sing-box check -c /etc/sing-box/config.json
   ```

2. 查看详细日志：
   ```bash
   sudo journalctl -u sing-box -f
   ```

3. 检查端口占用：
   ```bash
   sudo netstat -tlnp | grep :443
   ```

### 连接问题

1. 确认防火墙设置
2. 检查服务器公网 IP 是否正确
3. 验证客户端配置参数
4. 查看服务日志中的错误信息

### 重新配置

如需重新配置，可以：
1. 运行脚本选择相应协议重新安装
2. 或手动编辑 `/etc/sing-box/config.json`
3. 然后重启服务：`sudo systemctl restart sing-box`

## 安全建议

1. **定期更新**: 定期运行脚本更新到最新版本
2. **端口安全**: 避免使用常见端口，选择随机端口
3. **密码强度**: 使用强密码（脚本默认生成随机密码）
4. **访问控制**: 配置防火墙规则限制访问来源
5. **日志监控**: 定期检查服务日志，发现异常及时处理

## 更新日志

### v1.0.0
- 初始版本发布
- 支持 VLESS Reality、VMess WebSocket、Hysteria2
- 完整的安装、配置、管理功能
- 自动化部署和服务管理

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目。

## 免责声明

本脚本仅供学习和研究使用，请遵守当地法律法规。使用本脚本所产生的任何后果由用户自行承担。