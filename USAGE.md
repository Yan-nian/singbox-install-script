# 使用示例

## 快速开始

### 1. 基本安装流程

```bash
# 下载脚本
wget -O install.sh https://your-domain.com/install.sh

# 添加执行权限
chmod +x install.sh

# 运行脚本（需要 root 权限）
sudo ./install.sh
```

### 2. 安装 VLESS Reality（推荐）

1. 运行脚本后选择 `1` - 安装 VLESS Reality
2. 选择伪装网站（推荐选择 `1` - www.microsoft.com）
3. 等待安装完成
4. 记录显示的连接信息

**示例输出：**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                连接信息
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  协议类型: VLESS Reality
  服务器地址: 1.2.3.4
  端口: 12345
  UUID: 550e8400-e29b-41d4-a716-446655440000
  Flow: xtls-rprx-vision
  TLS: Reality
  SNI: www.microsoft.com
  PublicKey: abcd1234...
  ShortId: 12345678
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 3. 安装 VMess WebSocket

1. 运行脚本后选择 `2` - 安装 VMess WebSocket
2. 选择是否启用 TLS（推荐选择 `1` - 启用 TLS）
3. 如果启用 TLS，输入您的域名
4. 等待安装完成

### 4. 安装 Hysteria2

1. 运行脚本后选择 `3` - 安装 Hysteria2
2. 选择伪装网站（推荐选择 `1` - www.bing.com）
3. 等待安装完成

## 管理操作

### 查看连接信息

```bash
# 运行脚本
./install.sh

# 选择 "查看连接信息"
# 或者选择 "配置分享" -> "显示详细连接信息"
```

### 更改端口

```bash
# 运行脚本
./install.sh

# 选择 "更改端口"
# 输入新端口或选择随机生成
```

### 服务管理

```bash
# 运行脚本
./install.sh

# 选择 "管理服务"
# 可以启动、停止、重启服务
```

### 生成分享链接和二维码

```bash
# 运行脚本
./install.sh

# 选择 "配置分享"
# 选择 "显示连接链接" 或 "生成二维码"
```

## 客户端配置

### 支持的客户端

- **Windows**: v2rayN, Clash for Windows, sing-box
- **macOS**: ClashX, sing-box
- **iOS**: Shadowrocket, Quantumult X, sing-box
- **Android**: v2rayNG, Clash for Android, sing-box

### 配置方法

#### 方法一：使用分享链接
1. 在脚本中选择 "配置分享" -> "显示连接链接"
2. 复制生成的链接
3. 在客户端中导入链接

#### 方法二：扫描二维码
1. 在脚本中选择 "配置分享" -> "生成二维码"
2. 使用客户端扫描二维码

#### 方法三：手动配置
使用 "查看连接信息" 获取详细参数，手动在客户端中配置。

## 常用命令

### 系统服务操作

```bash
# 查看服务状态
systemctl status sing-box

# 启动服务
systemctl start sing-box

# 停止服务
systemctl stop sing-box

# 重启服务
systemctl restart sing-box

# 查看服务日志
journalctl -u sing-box -f
```

### 配置文件操作

```bash
# 查看配置文件
cat /etc/sing-box/config.json

# 测试配置文件
/usr/local/bin/sing-box check -c /etc/sing-box/config.json

# 查看日志文件
tail -f /var/log/sing-box/sing-box.log
```

### 网络测试

```bash
# 测试端口是否开放
ss -tulpn | grep :端口号

# 测试网络连接
curl -I http://www.google.com

# 查看公网IP
curl -s https://api.ipify.org
```

## 故障排除示例

### 问题1：服务无法启动

```bash
# 查看详细错误信息
systemctl status sing-box
journalctl -u sing-box --no-pager

# 检查配置文件
/usr/local/bin/sing-box check -c /etc/sing-box/config.json

# 检查端口占用
ss -tulpn | grep :端口号
```

### 问题2：客户端无法连接

```bash
# 检查防火墙
ufw status  # Ubuntu/Debian
firewall-cmd --list-all  # CentOS/RHEL

# 检查端口是否监听
ss -tulpn | grep :端口号

# 测试端口连通性（在客户端执行）
telnet 服务器IP 端口号
```

### 问题3：性能问题

```bash
# 查看系统资源使用
top
htop

# 查看网络连接
ss -s
netstat -i

# 查看磁盘使用
df -h
```

## 安全建议

### 1. 防火墙配置

```bash
# Ubuntu/Debian
ufw allow 端口号
ufw enable

# CentOS/RHEL
firewall-cmd --permanent --add-port=端口号/tcp
firewall-cmd --reload
```

### 2. 定期维护

```bash
# 定期更新系统
apt update && apt upgrade  # Ubuntu/Debian
yum update  # CentOS/RHEL

# 定期清理日志
journalctl --vacuum-time=7d

# 定期备份配置
cp -r /etc/sing-box /root/backup-$(date +%Y%m%d)
```

### 3. 监控脚本示例

```bash
#!/bin/bash
# 简单的监控脚本

if ! systemctl is-active --quiet sing-box; then
    echo "$(date): sing-box service is down, restarting..." >> /var/log/monitor.log
    systemctl restart sing-box
fi
```

## 高级用法

### 批量部署

```bash
# 创建自动化配置文件
cat > auto-config.conf << EOF
PROTOCOL=vless
PORT=12345
DOMAIN=example.com
EOF

# 使用配置文件运行（需要修改脚本支持）
./install.sh --config auto-config.conf
```

### 多协议共存

可以在不同端口上安装多个协议：

1. 安装第一个协议
2. 选择 "重新安装" 清理配置
3. 安装第二个协议（使用不同端口）

注意：当前脚本版本不支持多协议同时运行，需要手动修改配置文件。

## 更新和维护

### 更新 sing-box

```bash
# 运行脚本
./install.sh

# 选择 "重新安装"
# 会自动下载最新版本
```

### 备份和恢复

```bash
# 备份配置
tar -czf sing-box-backup-$(date +%Y%m%d).tar.gz /etc/sing-box /var/log/sing-box

# 恢复配置
tar -xzf sing-box-backup-20231201.tar.gz -C /
systemctl restart sing-box
```