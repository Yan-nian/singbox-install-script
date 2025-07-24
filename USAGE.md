# 使用示例

本文档提供了 Sing-box 一键安装脚本的详细使用示例。

## 快速安装示例

### 安装 VLESS Reality（推荐）

```bash
# 1. 下载脚本
wget https://raw.githubusercontent.com/your-repo/singbox-install-script/main/install.sh

# 2. 添加执行权限
chmod +x install.sh

# 3. 运行脚本
sudo ./install.sh

# 4. 选择选项 1 (安装 VLESS Reality)
# 5. 按提示输入配置信息：
#    - 伪装域名: www.microsoft.com
#    - 监听端口: 443 (默认)
```

**输出示例：**
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

请输入选项 [0-5]: 1

✓ 操作系统: ubuntu
✓ 系统架构: amd64
✓ 包管理器: apt

[信息] 安装系统依赖...
[信息] 依赖安装完成
[信息] 开始下载和安装sing-box...
[信息] 最新版本: v1.8.0
✓ sing-box v1.8.0 安装成功
[信息] 创建systemd服务...
[信息] systemd服务创建完成

配置 VLESS Reality 协议

请输入伪装域名 (例如: www.microsoft.com): www.microsoft.com
请输入监听端口 (默认: 443): 443

[信息] 生成Reality密钥对...
[信息] Reality密钥对生成完成
[信息] VLESS Reality配置完成
[信息] 启动sing-box服务...
✓ sing-box服务已启动

客户端配置信息
═══════════════════════════════════════════════════════════════
协议类型: VLESS Reality
服务器地址: 1.2.3.4
端口: 443
UUID: 12345678-1234-1234-1234-123456789abc
Flow: xtls-rprx-vision
TLS: Reality
SNI: www.microsoft.com
公钥: abcdef1234567890...
Short ID: 12345678

分享链接:
vless://12345678-1234-1234-1234-123456789abc@1.2.3.4:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.microsoft.com&fp=chrome&pbk=abcdef1234567890...&sid=12345678&type=tcp&headerType=none#VLESS-Reality
═══════════════════════════════════════════════════════════════
```

### 安装 VMess WebSocket

```bash
# 运行脚本并选择选项 2
sudo ./install.sh

# 按提示输入：
# - 监听端口: 8080 (默认)
# - WebSocket路径: /ws (默认)
```

**配置输出：**
```
配置 VMess WebSocket 协议

请输入监听端口 (默认: 8080): 8080
请输入WebSocket路径 (默认: /ws): /ws

客户端配置信息
═══════════════════════════════════════════════════════════════
协议类型: VMess WebSocket
服务器地址: 1.2.3.4
端口: 8080
UUID: 87654321-4321-4321-4321-210987654321
传输协议: WebSocket
路径: /ws
TLS: 无
═══════════════════════════════════════════════════════════════
```

### 安装 Hysteria2

```bash
# 运行脚本并选择选项 3
sudo ./install.sh

# 按提示输入：
# - 监听端口: 8443 (默认)
# - 连接密码: (留空自动生成)
# - 混淆密码: (可选)
```

**配置输出：**
```
配置 Hysteria2 协议

请输入监听端口 (默认: 8443): 8443
请输入连接密码 (默认随机生成): 
请输入混淆密码 (可选，默认不启用): myobfspassword

[信息] 生成自签名证书...
[信息] 自签名证书生成完成

客户端配置信息
═══════════════════════════════════════════════════════════════
协议类型: Hysteria2
服务器地址: 1.2.3.4
端口: 8443
密码: a1b2c3d4e5f6g7h8
混淆: salamander
混淆密码: myobfspassword
TLS: 自签名证书
═══════════════════════════════════════════════════════════════
```

## 服务管理示例

### 查看服务状态

```bash
# 运行脚本并选择选项 4，然后选择选项 4
sudo ./install.sh
```

**输出示例：**
```
● sing-box.service - sing-box service
   Loaded: loaded (/etc/systemd/system/sing-box.service; enabled; vendor preset: enabled)
   Active: active (running) since Mon 2024-01-15 10:30:00 UTC; 5min ago
     Docs: https://sing-box.sagernet.org
 Main PID: 12345 (sing-box)
    Tasks: 1 (limit: 1024)
   Memory: 15.2M
   CGroup: /system.slice/sing-box.service
           └─12345 /usr/local/bin/sing-box run -c /etc/sing-box/config.json

Jan 15 10:30:00 server systemd[1]: Started sing-box service.
Jan 15 10:30:00 server sing-box[12345]: INFO[2024-01-15T10:30:00Z] sing-box started
```

### 查看实时日志

```bash
# 选择服务管理 -> 查看服务日志
# 或直接使用命令：
sudo journalctl -u sing-box -f
```

**日志示例：**
```
Jan 15 10:30:00 server sing-box[12345]: INFO[2024-01-15T10:30:00Z] sing-box started
Jan 15 10:30:00 server sing-box[12345]: INFO[2024-01-15T10:30:00Z] inbound/vless-in: started at [::]:443
Jan 15 10:35:12 server sing-box[12345]: INFO[2024-01-15T10:35:12Z] inbound/vless-in: new connection from 192.168.1.100:54321
```

### 重启服务

```bash
# 选择服务管理 -> 重启服务
# 或直接使用命令：
sudo systemctl restart sing-box
```

## 客户端配置示例

### V2rayN (Windows)

**VLESS Reality 配置：**
1. 添加服务器
2. 选择协议：VLESS
3. 填入服务器信息：
   - 地址：1.2.3.4
   - 端口：443
   - UUID：12345678-1234-1234-1234-123456789abc
   - 流控：xtls-rprx-vision
   - 传输协议：tcp
   - TLS：Reality
   - SNI：www.microsoft.com
   - 公钥：abcdef1234567890...
   - Short ID：12345678

**VMess WebSocket 配置：**
1. 添加服务器
2. 选择协议：VMess
3. 填入服务器信息：
   - 地址：1.2.3.4
   - 端口：8080
   - UUID：87654321-4321-4321-4321-210987654321
   - 传输协议：ws
   - 路径：/ws
   - TLS：none

### Clash Meta

**VLESS Reality 配置：**
```yaml
proxies:
  - name: "VLESS-Reality"
    type: vless
    server: 1.2.3.4
    port: 443
    uuid: 12345678-1234-1234-1234-123456789abc
    flow: xtls-rprx-vision
    tls: true
    reality-opts:
      public-key: abcdef1234567890...
      short-id: 12345678
    client-fingerprint: chrome
```

**Hysteria2 配置：**
```yaml
proxies:
  - name: "Hysteria2"
    type: hysteria2
    server: 1.2.3.4
    port: 8443
    password: a1b2c3d4e5f6g7h8
    obfs: salamander
    obfs-password: myobfspassword
    skip-cert-verify: true
```

## 故障排除示例

### 服务启动失败

```bash
# 1. 检查配置文件语法
sudo /usr/local/bin/sing-box check -c /etc/sing-box/config.json

# 2. 查看错误日志
sudo journalctl -u sing-box --no-pager

# 3. 检查端口占用
sudo netstat -tlnp | grep :443

# 4. 手动启动测试
sudo /usr/local/bin/sing-box run -c /etc/sing-box/config.json
```

### 连接超时

```bash
# 1. 检查防火墙状态
sudo ufw status
# 或
sudo firewall-cmd --list-all

# 2. 测试端口连通性
telnet your-server-ip 443

# 3. 检查服务监听状态
sudo netstat -tlnp | grep sing-box
```

### 重新配置

```bash
# 1. 停止服务
sudo systemctl stop sing-box

# 2. 备份当前配置
sudo cp /etc/sing-box/config.json /etc/sing-box/config.json.bak

# 3. 重新运行安装脚本
sudo ./install.sh

# 4. 选择相应协议重新配置
```

## 卸载示例

```bash
# 运行脚本并选择选项 5
sudo ./install.sh

# 输入 'yes' 确认卸载
```

**卸载输出：**
```
确定要卸载sing-box吗？这将删除所有配置文件。
输入 'yes' 确认卸载: yes

[信息] 开始卸载sing-box...
[信息] sing-box卸载完成
✓ sing-box已成功卸载
```

## 高级用法

### 自定义配置

安装完成后，您可以手动编辑配置文件：

```bash
# 编辑配置文件
sudo nano /etc/sing-box/config.json

# 验证配置
sudo /usr/local/bin/sing-box check -c /etc/sing-box/config.json

# 重启服务应用配置
sudo systemctl restart sing-box
```

### 多端口配置

您可以修改配置文件添加多个入站：

```json
{
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-443",
      "listen": "::",
      "listen_port": 443,
      // ... VLESS Reality 配置
    },
    {
      "type": "vmess",
      "tag": "vmess-8080",
      "listen": "::",
      "listen_port": 8080,
      // ... VMess WebSocket 配置
    }
  ]
}
```

### 定时更新

设置定时任务自动更新 Sing-box：

```bash
# 编辑 crontab
sudo crontab -e

# 添加每周更新任务（每周日凌晨2点）
0 2 * * 0 /path/to/install.sh
```

这些示例涵盖了脚本的主要使用场景，帮助用户快速上手和解决常见问题。