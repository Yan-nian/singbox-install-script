# Sing-box 一键安装脚本

基于 [BandWh.com](https://www.bandwh.com/net/2175.html) 教程制作的 Sing-box 一键安装脚本，支持多种协议配置。

## 功能特点

- 🚀 **一键安装**: 自动安装 Sing-box 服务端
- 🌐 **多协议支持**: 支持 Shadowsocks、SOCKS5、REALITY 等协议
- 🔧 **自动配置**: 自动生成配置文件和密钥
- 🛡️ **防火墙配置**: 自动配置防火墙规则
- 📊 **状态监控**: 提供服务状态查看功能
- 🔄 **服务管理**: 支持启动、停止、重启服务

## 支持的系统

- ✅ Debian 9+ / Ubuntu 18.04+
- ✅ CentOS 7+ / RHEL 7+
- ✅ 其他基于 systemd 的 Linux 发行版

## 支持的协议

### 1. SOCKS5 代理
- 支持用户名密码认证
- 自动生成随机端口和认证信息

### 2. Shadowsocks
- 使用 2022-blake3-aes-128-gcm 加密方式
- 自动生成密钥和端口

### 3. REALITY
- 基于 VLESS 协议
- 使用 xtls-rprx-vision 流控
- 伪装成 Microsoft 官网

## 使用方法

### 方法一：交互式安装

```bash
# 下载脚本
curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/master/install.sh -o install.sh

# 添加执行权限
chmod +x install.sh

# 运行脚本
sudo ./install.sh
```

### 方法二：一键安装

```bash
# 直接安装
sudo bash <(curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/master/install.sh) install

# 或者下载后安装
wget https://raw.githubusercontent.com/Yan-nian/singbox-install-script/master/install.sh
chmod +x install.sh
sudo ./install.sh install
```

### 方法三：快速一键命令

```bash
# 下载并运行
sudo bash <(curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/master/install.sh)
```

## 菜单选项

运行脚本后会显示以下菜单：

```
==========================================
         Sing-box 一键安装脚本
==========================================
1. 安装 Sing-box
2. 卸载 Sing-box
3. 重启 Sing-box
4. 查看状态
5. 查看配置
6. 查看日志
0. 退出
==========================================
```

## 配置信息

安装完成后，脚本会显示以下配置信息：

### SOCKS5 代理配置
```
地址: 您的服务器IP
端口: 随机生成的端口
用户名: 随机生成的用户名
密码: 随机生成的密码
```

### Shadowsocks 配置
```
地址: 您的服务器IP
端口: 随机生成的端口
密码: 自动生成的密钥
加密方式: 2022-blake3-aes-128-gcm
```

### REALITY 配置
```
地址: 您的服务器IP
端口: 443
UUID: 自动生成的UUID
Flow: xtls-rprx-vision
SNI: www.microsoft.com
公钥: 自动生成的公钥
Short ID: 0123456789abcdef
```

## 常用命令

```bash
# 启动服务
sudo systemctl start sing-box

# 停止服务
sudo systemctl stop sing-box

# 重启服务
sudo systemctl restart sing-box

# 查看状态
sudo systemctl status sing-box

# 查看日志
sudo journalctl -u sing-box --output cat -e

# 查看端口占用
sudo netstat -tulnp | grep sing-box

# 实时查看日志
sudo journalctl -u sing-box -f
```

## 配置文件位置

- 配置文件：`/etc/sing-box/config.json`
- 服务文件：`/etc/systemd/system/sing-box.service`
- 可执行文件：`/usr/local/bin/sing-box`

## 手动修改配置

如需手动修改配置，请编辑配置文件：

```bash
# 编辑配置文件
sudo nano /etc/sing-box/config.json

# 重启服务使配置生效
sudo systemctl restart sing-box
```

## 防火墙设置

脚本会自动配置防火墙规则，支持：

- **UFW** (Ubuntu/Debian)
- **firewalld** (CentOS/RHEL)
- **iptables** (传统防火墙)

如果自动配置失败，请手动开放以下端口：

```bash
# UFW
sudo ufw allow [SOCKS端口]/tcp
sudo ufw allow [SS端口]/tcp
sudo ufw allow [SS端口]/udp
sudo ufw allow 443/tcp

# firewalld
sudo firewall-cmd --permanent --add-port=[端口]/tcp
sudo firewall-cmd --permanent --add-port=[端口]/udp
sudo firewall-cmd --reload

# iptables
sudo iptables -A INPUT -p tcp --dport [端口] -j ACCEPT
sudo iptables -A INPUT -p udp --dport [端口] -j ACCEPT
```

## 客户端配置

### Android 客户端
推荐使用 [sing-box](https://github.com/SagerNet/sing-box) 官方客户端

### iOS 客户端
推荐使用 [sing-box](https://apps.apple.com/app/sing-box/id6451272673) 官方客户端

### Windows 客户端
推荐使用 [sing-box](https://github.com/SagerNet/sing-box/releases) 官方客户端

### 路由器
推荐使用 [homeproxy](https://github.com/immortalwrt/homeproxy) 插件

## 故障排除

### 1. 服务启动失败

```bash
# 查看详细日志
sudo journalctl -u sing-box --output cat -e

# 检查配置文件语法
sudo sing-box check -c /etc/sing-box/config.json
```

### 2. 端口被占用

```bash
# 查看端口占用
sudo netstat -tulnp | grep [端口号]

# 修改配置文件中的端口
sudo nano /etc/sing-box/config.json
```

### 3. 防火墙问题

```bash
# 检查防火墙状态
sudo ufw status
sudo firewall-cmd --list-ports

# 手动开放端口
sudo ufw allow [端口]/tcp
```

### 4. 重新生成配置

```bash
# 停止服务
sudo systemctl stop sing-box

# 重新运行脚本
sudo ./install.sh

# 选择安装选项重新生成配置
```

## 卸载方法

```bash
# 使用脚本卸载
sudo ./install.sh uninstall

# 或者在菜单中选择卸载选项
sudo ./install.sh
# 然后选择选项 2
```

## 更新日志

### v1.0.0
- 初始版本发布
- 支持 Shadowsocks、SOCKS5、REALITY 协议
- 自动配置防火墙
- 交互式菜单界面

## 贡献

欢迎提交 Issue 和 Pull Request 来改进这个脚本。

## 许可证

本项目采用 MIT 许可证。

## 免责声明

本脚本仅供学习和技术交流使用，请遵守当地法律法规。使用本脚本所产生的任何后果，由使用者自行承担。

## 参考资料

- [Sing-box 官方文档](https://sing-box.sagernet.org/)
- [BandWh.com 教程](https://www.bandwh.com/net/2175.html)
- [Sing-box GitHub](https://github.com/SagerNet/sing-box)

---

**作者**: Yan-nian  
**版本**: 1.0.0  
**更新时间**: 2025-01-17
