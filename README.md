# Sing-box 一键安装脚本

这是一个用于在 VPS 上快速安装和配置 sing-box 的一键脚本，支持多种协议和完整的管理功能。

## 支持的协议

- **VLESS Reality** - 最新的无特征协议，推荐使用
- **VMess WebSocket** - 经典协议，支持 TLS 和非 TLS
- **Hysteria2** - 基于 QUIC 的高性能协议

## 功能特性

- 🚀 **一键安装**: 自动下载并安装最新版本的 sing-box
- 🔧 **多协议支持**: 默认同时安装 VLESS Reality、VMess WebSocket、Hysteria2 三种协议
- 🛡️ **安全配置**: 自动生成安全的密钥和证书，修复了 VLESS Reality 配置问题
- 📊 **服务管理**: 完整的 systemd 服务管理功能
- 🔄 **配置管理**: 支持端口更改、配置分享等功能
- 📝 **日志查看**: 方便的日志查看和故障排除
- 🗑️ **完全卸载**: 支持完全卸载和重新安装

### 🆕 v2.0.0 新增功能

- 📡 **DNS 优化**: 集成 DNS over HTTPS，支持 Cloudflare、Google 和本地 DNS 服务器
- 🛣️ **智能路由**: 基于域名和 IP 的路由规则，优化中国大陆网站访问性能
- 📈 **Clash API**: 内置 Clash API 支持，提供 Web 管理界面
- 💾 **缓存机制**: 启用缓存文件，提升连接性能和稳定性
- ✨ **增强日志**: 添加时间戳支持，便于问题追踪和调试
- 🏗️ **模块化架构**: 重构配置生成逻辑，提高代码可维护性

## 主要功能

### 协议安装
- 自动下载最新版本的 sing-box
- 一键安装和配置指定协议
- 自动生成配置文件和证书
- 创建系统服务并设置开机自启

### 服务管理
- 启动/停止/重启服务
- 查看服务状态
- 设置/取消开机自启

### 配置管理
- 查看当前连接信息
- 更改监听端口
- 生成分享链接和二维码
- 导出配置文件

### 日志管理
- 查看实时日志
- 查看历史日志
- 过滤错误日志
- 清空日志文件

### 其他功能
- 重新安装（保留备份）
- 完全卸载
- 系统环境检测
- 网络连通性测试

## 系统要求

- **操作系统**: Ubuntu 18+, Debian 9+, CentOS 7+, RHEL 7+
- **架构**: x86_64, aarch64
- **权限**: Root 用户
- **网络**: 能够访问 GitHub 和相关下载源

## 安装使用

### 1. 下载脚本

```bash
wget -O install.sh https://raw.githubusercontent.com/your-repo/sing-box-install/main/install.sh
```

或者

```bash
curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/master/install.sh -o install.sh
```

### 2. 运行脚本

```bash
chmod +x install.sh
sudo ./install.sh
```

### 3. 一键安装所有协议

脚本会自动检测系统环境，然后显示主菜单。选择 "一键安装所有协议" 选项，脚本将自动：

- 同时安装 VLESS Reality、VMess WebSocket、Hysteria2 三种协议
- 自动分配不冲突的端口
- 生成安全的密钥和证书
- 创建 systemd 服务并启动
- 显示所有协议的连接信息

## 使用说明

### 首次安装

1. 运行脚本后，选择要安装的协议
2. 根据提示输入必要的配置信息
3. 等待安装完成，记录连接信息

### 协议配置说明

#### VLESS Reality
- 推荐协议，无特征，抗封锁能力强
- 需要选择伪装网站（推荐 microsoft.com）
- 自动生成 Reality 密钥对

#### VMess WebSocket
- 经典协议，兼容性好
- 可选择是否启用 TLS
- 启用 TLS 需要提供域名

#### Hysteria2
- 基于 QUIC，速度快
- 需要选择伪装网站
- 自动生成自签名证书

### 客户端配置

安装完成后，脚本会显示连接信息，您可以：

1. 复制连接链接到客户端
2. 扫描二维码快速导入
3. 查看详细配置信息手动配置

### 常用操作

- **查看连接信息**: 主菜单选择 "查看连接信息"
- **更改端口**: 主菜单选择 "更改端口"
- **重启服务**: 主菜单选择 "管理服务" -> "重启服务"
- **查看日志**: 主菜单选择 "查看日志"

## 故障排除

### 常见问题

1. **服务启动失败**
   - 检查端口是否被占用
   - 查看日志文件排查错误
   - 验证配置文件格式

2. **无法连接**
   - 确认防火墙设置
   - 检查端口是否开放
   - 验证客户端配置

3. **下载失败**
   - 检查网络连接
   - 尝试更换下载源
   - 手动下载后放置到指定位置

### 日志位置

- 服务日志: `/var/log/sing-box/sing-box.log`
- 配置文件: `/etc/sing-box/config.json`
- 系统服务: `/etc/systemd/system/sing-box.service`

### 手动操作

```bash
# 查看服务状态
systemctl status sing-box

# 重启服务
systemctl restart sing-box

# 查看日志
tail -f /var/log/sing-box/sing-box.log

# 测试配置
/usr/local/bin/sing-box check -c /etc/sing-box/config.json
```

## 安全建议

1. **定期更新**: 定期运行脚本更新到最新版本
2. **端口安全**: 避免使用常见端口，定期更换端口
3. **访问控制**: 配置防火墙规则，限制访问来源
4. **监控日志**: 定期检查日志，发现异常及时处理

## 卸载

如需完全卸载 sing-box：

1. 运行脚本
2. 选择 "卸载 sing-box"
3. 确认卸载操作
4. 可选择是否备份配置文件

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request 来改进这个脚本。

## 免责声明

本脚本仅供学习和研究使用，请遵守当地法律法规。使用本脚本所产生的任何后果由用户自行承担。