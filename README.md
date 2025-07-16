# Sing-box 个人一键配置脚本

[![License](https://img.shields.io/badge/license-GPL%20v3-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-v1.0.0-green.svg)](https://github.com/yourusername/singbox)

最简单易用的 sing-box 个人配置脚本，支持 VLESS Reality、VMess、Hysteria2、Shadowsocks 四种主流协议的一键部署和管理。

## ✨ 特性

- 🚀 **一键安装**: 单条命令完成所有部署
- 🎨 **交互式界面**: 美观的彩色菜单，用户友好的操作体验
- 🔧 **四协议支持**: VLESS Reality、VMess、Hysteria2、Shadowsocks
- 📱 **分享便捷**: 自动生成分享链接和二维码
- ⚡ **管理简单**: 直观的交互式界面和命令行操作
- 🔒 **安全可靠**: 自动生成强随机参数
- � **配置管理**: 完整的配置增删改查功能
- 🛠️ **系统优化**: 内置 BBR 优化和系统参数调优
- �🗑️ **完全卸载**: 一键清理所有文件
- � **状态监控**: 实时查看服务状态和日志

## 🎯 交互式界面特色

### 主菜单界面
```
╔═══════════════════════════════════════════════════════════════════════════════════╗
║                              Sing-box 一键管理脚本                              ║
║                                   版本: v1.0.0                                   ║
╚═══════════════════════════════════════════════════════════════════════════════════╝

请选择操作：

  [1] 添加配置        [2] 管理配置        [3] 系统管理
  [4] 分享链接        [5] 系统信息        [6] 更新脚本
  [0] 退出脚本
```

### 智能化配置流程
- 🔍 **智能输入验证**: 自动检查端口占用、域名格式等
- 🎯 **配置预览**: 添加前显示完整配置信息
- ⚡ **一键确认**: 简化操作流程，减少出错概率
- 📋 **实时反馈**: 操作过程中的状态提示和进度显示

## 📋 系统要求

### 支持的操作系统
- Ubuntu 18.04+
- Debian 9+
- CentOS 7+

### 系统架构
- x86_64 (amd64)
- ARM64 (aarch64)
- ARMv7

### 基础要求
- Root 权限
- 网络连接
- Systemd 支持

## 🚀 快速开始

### 方式一：一键安装（推荐）

```bash
# 自动检测并安装/更新
bash <(curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/master/install.sh)

# 或者下载后安装
wget https://raw.githubusercontent.com/Yan-nian/singbox-install-script/master/install.sh
chmod +x install.sh
./install.sh
```

### 方式二：高级安装选项

```bash
# 强制重新安装
./install.sh -f

# 更新模式（智能检测并更新）
./install.sh -u

# 仅更新 sing-box 核心程序
./install.sh -c

# 仅更新管理脚本
./install.sh -s

# 显示帮助信息
./install.sh -h
```

### 集成安装脚本特性

- 🔍 **智能检测**: 自动识别是否已安装，选择最佳安装方式
- 📦 **多模式支持**: 新安装、更新、升级、重装等多种模式
- 🛡️ **自动备份**: 更新前自动备份现有配置和脚本
- ⚡ **部分更新**: 支持仅更新核心程序或管理脚本
- 🎯 **智能跳过**: 自动跳过不必要的操作，节省时间
- 🔄 **服务管理**: 智能处理服务启动、停止和重启

### 安装模式说明

| 模式 | 触发条件 | 执行操作 |
|------|----------|----------|
| **新安装** | 未检测到任何组件 | 完整安装所有组件 |
| **更新** | 检测到完整安装 | 更新核心和脚本，保持配置 |
| **升级** | 检测到部分安装 | 补充缺失组件，完善安装 |
| **重装** | 使用 `-f` 参数 | 强制重新安装所有组件 |
| **核心更新** | 使用 `-c` 参数 | 仅更新 sing-box 核心程序 |
| **脚本更新** | 使用 `-s` 参数 | 仅更新管理脚本 |

### 安装完成后

安装完成后，你可以使用以下命令：

```bash
sing-box         # 启动交互式界面（推荐）
sing-box help    # 查看帮助
sb help          # 快捷命令
```

## 📖 使用指南

### 🎨 交互式界面模式（推荐）

直接运行脚本即可进入美观的交互式菜单：

```bash
sing-box
```

#### 交互式操作指南

**1. 添加配置**
- 选择主菜单中的 `[1] 添加配置`
- 选择协议类型（VLESS Reality 推荐）
- 按提示输入配置信息
- 系统自动验证并生成配置

**2. 管理配置**
- 选择主菜单中的 `[2] 管理配置`
- 查看、修改或删除现有配置
- 支持端口更换和 UUID 重新生成

**3. 系统管理**
- 选择主菜单中的 `[3] 系统管理`
- 启动/停止/重启服务
- 查看系统状态和日志
- 执行系统优化

**4. 分享链接**
- 选择主菜单中的 `[4] 分享链接`
- 生成分享链接或二维码
- 导出配置文件

### 🖥️ 命令行模式

#### 添加配置

```bash
# 添加 VLESS Reality 配置（推荐）
sing-box add vless

# 添加 VMess 配置
sing-box add vmess

# 添加 Hysteria2 配置
sing-box add hy2

# 添加 Shadowsocks 配置
sing-box add ss

# 自定义参数
sing-box add vless my-vless 8443 www.google.com
sing-box add vmess my-vmess 8080 example.com
sing-box add hy2 my-hy2 9443 example.com
```

#### 管理配置

```bash
# 列出所有配置
sing-box list

# 查看配置详情
sing-box info vless-001

# 删除配置
sing-box del vless-001

# 更换端口
sing-box port vless-001 8443
```

#### 获取分享信息

```bash
# 获取分享链接
sing-box url vless-001

# 生成二维码
sing-box qr vless-001
```

### 服务管理

```bash
# 启动服务
sing-box start

# 停止服务
sing-box stop

# 重启服务
sing-box restart

# 查看状态
sing-box status

# 查看日志
sing-box log
```

### 系统操作

```bash
# 查看版本
sing-box version

# 完全卸载
sing-box uninstall
```

## 🔧 协议说明

### VLESS Reality

**推荐协议**，无需域名和证书，安全性高，伪装效果好。

- ✅ 无需域名
- ✅ 无需证书
- ✅ 抗检测能力强
- ✅ 性能优秀

```bash
sing-box add vless [名称] [端口] [SNI域名]
```

### VMess

经典协议，需要域名和 TLS 证书。

- ⚠️ 需要域名
- ⚠️ 需要 TLS 证书
- ✅ 兼容性好
- ✅ 客户端支持广泛

```bash
sing-box add vmess [名称] [端口] [域名]
```

### Hysteria2

基于 UDP 的高性能协议，需要域名和证书。

- ⚠️ 需要域名
- ⚠️ 需要 TLS 证书
- ✅ 速度极快
- ✅ 适合高带宽场景

```bash
sing-box add hy2 [名称] [端口] [域名]
```

## 📁 文件结构

```
/etc/sing-box/
├── config.json              # 主配置文件
├── configs/                 # 各协议配置
│   ├── vless-001.json
│   ├── vmess-001.json
│   └── hy2-001.json
├── cert.pem                 # TLS 证书（VMess/Hysteria2）
└── key.pem                  # TLS 私钥（VMess/Hysteria2）

/usr/local/etc/sing-box/
└── sing-box.db              # 配置数据库

/var/log/sing-box/
└── sing-box.log             # 运行日志

/usr/local/bin/
├── sing-box                 # 管理脚本
└── sb                       # 快捷命令
```

## 🔐 TLS 证书配置

对于 VMess 和 Hysteria2 协议，需要配置 TLS 证书：

### 方法一：使用 Certbot（推荐）

```bash
# 安装 Certbot
apt update && apt install -y certbot

# 申请证书
certbot certonly --standalone -d your-domain.com

# 复制证书
cp /etc/letsencrypt/live/your-domain.com/fullchain.pem /etc/sing-box/cert.pem
cp /etc/letsencrypt/live/your-domain.com/privkey.pem /etc/sing-box/key.pem
```

### 方法二：使用 acme.sh

```bash
# 安装 acme.sh
curl https://get.acme.sh | sh

# 申请证书
~/.acme.sh/acme.sh --issue -d your-domain.com --standalone

# 安装证书
~/.acme.sh/acme.sh --install-cert -d your-domain.com \
  --cert-file /etc/sing-box/cert.pem \
  --key-file /etc/sing-box/key.pem
```

## 🛠️ 故障排除

### 常见问题

#### 1. 端口被占用
```bash
# 检查端口占用
ss -tuln | grep :端口号

# 更换端口
sing-box port 配置名称 新端口
```

#### 2. 服务启动失败
```bash
# 查看详细错误
sing-box log

# 检查配置文件
/usr/local/bin/sing-box check -c /etc/sing-box/config.json
```

#### 3. 无法连接
```bash
# 检查防火墙
systemctl status firewalld
ufw status

# 开放端口（以 8443 为例）
firewall-cmd --permanent --add-port=8443/tcp
firewall-cmd --reload

# 或者
ufw allow 8443
```

#### 4. 证书问题
```bash
# 检查证书文件
ls -la /etc/sing-box/cert.pem /etc/sing-box/key.pem

# 验证证书
openssl x509 -in /etc/sing-box/cert.pem -text -noout
```

### 日志分析

```bash
# 实时查看日志
sing-box log

# 查看系统日志
journalctl -u sing-box -n 50

# 查看错误日志
journalctl -u sing-box -p err
```

## 🔄 更新和维护

### 更新脚本

```bash
# 重新运行安装脚本即可更新
bash <(curl -fsSL https://raw.githubusercontent.com/yourusername/singbox/main/install.sh)
```

### 备份配置

```bash
# 备份配置目录
tar -czf sing-box-backup-$(date +%Y%m%d).tar.gz /etc/sing-box /usr/local/etc/sing-box
```

### 恢复配置

```bash
# 恢复配置
tar -xzf sing-box-backup-20240101.tar.gz -C /
systemctl restart sing-box
```

## 📊 性能优化

### 系统优化

```bash
# 启用 BBR（如果支持）
echo 'net.core.default_qdisc=fq' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
sysctl -p

# 优化文件描述符限制
echo '* soft nofile 65536' >> /etc/security/limits.conf
echo '* hard nofile 65536' >> /etc/security/limits.conf
```

### 防火墙优化

```bash
# 关闭不必要的防火墙（谨慎操作）
systemctl stop firewalld
systemctl disable firewalld

# 或者精确开放端口
firewall-cmd --permanent --add-port=端口/tcp
firewall-cmd --reload
```

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

### 开发环境

```bash
# 克隆仓库
git clone https://github.com/yourusername/singbox.git
cd singbox

# 测试安装脚本
bash install.sh

# 测试管理脚本
bash sing-box.sh help
```

## 📄 许可证

本项目采用 [GPL v3](LICENSE) 许可证。

## ⚠️ 免责声明

本脚本仅供学习和研究使用，请遵守当地法律法规。使用本脚本所产生的任何后果由使用者自行承担。

## 🙏 致谢

- [SagerNet/sing-box](https://github.com/SagerNet/sing-box) - 核心程序
- [233boy/sing-box](https://github.com/233boy/sing-box) - 参考项目

## 📞 支持

如果你觉得这个项目有用，请给个 ⭐ Star！

有问题请提交 [Issue](https://github.com/yourusername/singbox/issues)。