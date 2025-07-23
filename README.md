# Sing-box VPS 一键安装脚本

一个功能强大、安全可靠的 Sing-box 一键安装脚本，支持多种协议配置。

## 🚀 特性

- **多协议支持**: VLESS Reality、VMess WebSocket、Hysteria2
- **智能系统检测**: 自动检测操作系统并安装依赖
- **安全证书生成**: 使用 ECC P-256 算法生成自签名证书
- **智能端口管理**: 自动检测并生成可用端口
- **完善的错误处理**: 严格的错误检查和恢复机制
- **详细的日志记录**: 支持调试模式和日志文件
- **用户友好界面**: 彩色输出和进度显示
- **配置验证**: 自动验证生成的配置文件

## 📋 系统要求

- **操作系统**: Ubuntu 18.04+, Debian 9+, CentOS 7+, RHEL 7+, Fedora 28+
- **内存**: 最少 512MB RAM
- **磁盘空间**: 最少 1GB 可用空间
- **网络**: 需要互联网连接下载 sing-box
- **权限**: 需要 root 权限

## 🛠️ 安装使用

### 快速安装

```bash
# 下载并运行脚本
wget -O install.sh https://raw.githubusercontent.com/your-repo/singbox-install-script/main/install.sh
sudo bash install.sh
```

### 手动安装

1. 下载脚本文件
2. 给予执行权限：`chmod +x install.sh`
3. 以 root 权限运行：`sudo bash install.sh`

## 📖 功能说明

### 协议选择

1. **VLESS Reality** (推荐)
   - 最新的协议，具有更好的抗检测能力
   - 支持 TLS 指纹伪装
   - 无需额外证书配置

2. **VMess WebSocket**
   - 经典协议，兼容性好
   - 支持 TLS 加密
   - 可选择启用/禁用 TLS

3. **Hysteria2**
   - 基于 QUIC 的高性能协议
   - 适合高延迟网络环境
   - 内置拥塞控制

4. **多协议模式**
   - 同时安装所有三种协议
   - 使用不同端口
   - 统一管理

### 主要功能

- **安装协议**: 选择并安装指定协议
- **查看连接信息**: 显示连接参数和二维码
- **服务管理**: 启动/停止/重启服务
- **端口更改**: 修改监听端口
- **配置分享**: 生成分享链接和二维码
- **日志查看**: 查看运行日志和错误信息
- **重新安装**: 重新配置协议
- **完全卸载**: 清理所有文件和配置

## 🔧 高级配置

### 调试模式

启用调试模式以获取详细的运行信息：

```bash
DEBUG_MODE=true sudo bash install.sh
```

### 自定义配置

脚本支持以下环境变量自定义：

- `DEBUG_MODE`: 启用调试模式 (true/false)
- `MIN_PORT`: 最小端口号 (默认: 10000)
- `MAX_PORT`: 最大端口号 (默认: 65535)

## 📁 文件结构

```
/etc/sing-box/
├── config.json          # 主配置文件
├── certs/               # 证书目录
│   ├── cert.pem        # 证书文件
│   └── key.pem         # 私钥文件
└── cache.db            # 缓存文件

/var/log/sing-box/
└── sing-box.log        # 日志文件

/etc/systemd/system/
└── sing-box.service    # 系统服务文件
```

## 🔍 故障排除

### 常见问题

1. **端口被占用**
   - 脚本会自动检测并生成可用端口
   - 可以手动指定端口范围

2. **证书生成失败**
   - 确保 OpenSSL 已安装
   - 检查磁盘空间是否充足

3. **服务启动失败**
   - 检查配置文件语法：`sing-box check -c /etc/sing-box/config.json`
   - 查看系统日志：`journalctl -u sing-box -f`

4. **网络连接问题**
   - 检查防火墙设置
   - 确认端口已开放

### 日志查看

```bash
# 查看服务状态
systemctl status sing-box

# 查看实时日志
journalctl -u sing-box -f

# 查看应用日志
tail -f /var/log/sing-box/sing-box.log
```

## 🛡️ 安全建议

1. **定期更新**: 保持 sing-box 版本最新
2. **防火墙配置**: 只开放必要的端口
3. **密码安全**: 使用强密码和随机 UUID
4. **证书管理**: 定期更新自签名证书
5. **日志监控**: 定期检查日志文件

## 📝 更新日志

### v2.0.0
- 重构整个脚本架构
- 增加严格的错误处理机制
- 优化用户界面和进度显示
- 增强安全性和稳定性
- 支持更多操作系统
- 改进证书生成算法
- 增加调试模式和详细日志

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目。

## 📄 许可证

MIT License

## ⚠️ 免责声明

本脚本仅供学习和研究使用，请遵守当地法律法规。使用本脚本所产生的任何后果由用户自行承担。