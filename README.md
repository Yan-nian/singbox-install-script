# sing-box 一键安装脚本

## 简介

这是一个功能完整的 sing-box 一键安装脚本，支持多种代理协议的快速部署和管理。

## 支持的协议

- **VLESS Reality** - 基于 TLS 的高性能协议
- **VMess WebSocket** - 经典的 V2Ray 协议
- **Hysteria2** - 基于 QUIC 的高速协议

## 主要功能

### 🚀 一键安装
- 自动检测系统架构
- 下载最新版本的 sing-box
- 配置系统服务
- 支持多种 Linux 发行版

### 🔧 协议配置
- 支持单独或组合配置多种协议
- 交互式配置用户信息
- 自动生成密钥和证书
- 智能端口分配

### ⚙️ 管理功能
- 动态更改端口号
- 一键更新 sing-box 核心
- 查看配置和运行状态
- 完整卸载功能

### 🛡️ 安全特性
- 自动生成强随机密码
- Reality 协议支持
- 自签名证书生成
- 安全的配置文件权限

## 使用方法

### 1. 下载脚本
```bash
wget -O install.sh https://raw.githubusercontent.com/Yan-nian/singbox-install-script/master/install.sh
chmod +x install.sh
./install.sh
./install.sh
```

### 2. 运行脚本
```bash
sudo ./install.sh
```

### 3. 选择功能
脚本提供交互式菜单：
```
========================================
         sing-box 一键安装脚本
         支持 VLESS Reality/VMess/Hysteria2
========================================
1. 安装 sing-box
2. 配置协议
3. 更改端口号
4. 更新 sing-box 核心
5. 查看配置信息
6. 卸载 sing-box
0. 退出
========================================
```

## 详细功能说明

### 安装 sing-box
- 自动检测系统架构（amd64/arm64/armv7）
- 从 GitHub 下载最新版本
- 创建系统服务
- 配置基本目录结构

### 协议配置

#### VLESS Reality
- **端口**: 默认 443，可自定义
- **用户**: 支持多用户配置
- **目标服务器**: 默认 www.microsoft.com
- **密钥**: 自动生成公私钥对
- **短ID**: 随机生成

#### VMess WebSocket
- **端口**: 随机生成，可自定义
- **用户**: 支持多用户配置
- **路径**: 随机生成 8 位路径
- **传输**: WebSocket 传输

#### Hysteria2
- **端口**: 随机生成，可自定义
- **用户**: 支持多用户配置
- **带宽**: 可配置上下行带宽
- **证书**: 自动生成自签名证书

### 管理功能

#### 更改端口号
- 显示当前端口配置
- 验证端口号有效性
- 自动备份和恢复配置
- 服务自动重启

#### 更新核心
- 停止当前服务
- 备份现有配置
- 下载最新版本
- 恢复配置并重启

#### 查看配置
- 显示服务状态
- 显示端口信息
- 显示日志内容
- 配置文件路径

#### 卸载功能
- 停止并禁用服务
- 删除二进制文件
- 删除配置文件
- 删除日志文件
- 清理系统服务

## 配置文件结构

脚本生成的配置文件包含：
- **日志配置**: 错误级别日志，输出到文件
- **DNS 配置**: 国内外分流 DNS 解析
- **入站配置**: 根据选择的协议生成
- **出站配置**: 直连和阻断出站
- **路由配置**: 基于 GeoSite 的分流规则

## 文件位置

- **二进制文件**: `/usr/local/bin/sing-box`
- **配置文件**: `/etc/sing-box/config.json`
- **服务文件**: `/etc/systemd/system/sing-box.service`
- **日志文件**: `/var/log/sing-box.log`
- **证书目录**: `/etc/sing-box/certs/`

## 系统要求

- Linux 系统（Ubuntu/Debian/CentOS/RHEL）
- Root 权限
- 网络连接
- 基本工具：curl、tar、systemctl、openssl

## 支持的架构

- x86_64 (amd64)
- aarch64 (arm64)
- armv7l (armv7)

## 常用命令

```bash
# 查看服务状态
systemctl status sing-box

# 查看实时日志
tail -f /var/log/sing-box.log

# 重启服务
systemctl restart sing-box

# 检查配置文件
sing-box check -c /etc/sing-box/config.json

# 格式化配置文件
sing-box format -w -c /etc/sing-box/config.json
```

## 注意事项

1. **防火墙设置**: 确保配置的端口在防火墙中开放
2. **SSL 证书**: Hysteria2 使用自签名证书，客户端需要跳过证书验证
3. **端口冲突**: 避免使用已被占用的端口
4. **系统资源**: 确保服务器有足够的资源运行服务
5. **定期更新**: 建议定期更新 sing-box 核心版本

## 故障排除

### 服务启动失败
1. 检查配置文件语法: `sing-box check -c /etc/sing-box/config.json`
2. 查看错误日志: `tail -f /var/log/sing-box.log`
3. 检查端口占用: `netstat -tlnp | grep :端口号`

### 连接问题
1. 确认防火墙设置
2. 检查服务器网络连接
3. 验证客户端配置参数

### 配置错误
1. 使用脚本重新生成配置
2. 检查用户权限
3. 验证证书文件

## 贡献

欢迎提交 Issue 和 Pull Request 来改进这个脚本。

## 许可证

MIT License

## 作者

Yan-nian

## 更新日志

### v1.0.0 (2025-07-17)
- 初始版本发布
- 支持 VLESS Reality、VMess、Hysteria2 协议
- 完整的安装、配置、管理功能
- 交互式用户界面
