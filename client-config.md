# 客户端配置示例

## SOCKS5 代理配置

### 通用配置
```
协议: SOCKS5
服务器: 您的服务器IP
端口: 脚本生成的端口
用户名: 脚本生成的用户名
密码: 脚本生成的密码
```

### 浏览器代理设置
在浏览器中设置代理：
- 代理类型: SOCKS5
- 代理服务器: 您的服务器IP
- 端口: 脚本生成的端口
- 用户名: 脚本生成的用户名
- 密码: 脚本生成的密码

## Shadowsocks 配置

### 通用配置
```json
{
  "server": "您的服务器IP",
  "server_port": 脚本生成的端口,
  "password": "脚本生成的密码",
  "method": "2022-blake3-aes-128-gcm"
}
```

### Shadowsocks Android 配置
```
服务器: 您的服务器IP
远程端口: 脚本生成的端口
密码: 脚本生成的密码
加密方法: 2022-blake3-aes-128-gcm
```

### Shadowsocks URL 格式
```
ss://MjAyMi1ibGFrZTMtYWVzLTEyOC1nY206[base64编码的密码]@[服务器IP]:[端口]
```

## REALITY 配置

### sing-box 客户端配置
```json
{
  "type": "vless",
  "tag": "reality-out",
  "server": "您的服务器IP",
  "server_port": 443,
  "uuid": "脚本生成的UUID",
  "flow": "xtls-rprx-vision",
  "tls": {
    "enabled": true,
    "server_name": "www.microsoft.com",
    "utls": {
      "enabled": true,
      "fingerprint": "chrome"
    },
    "reality": {
      "enabled": true,
      "public_key": "脚本生成的公钥",
      "short_id": "0123456789abcdef"
    }
  }
}
```

### V2Ray 客户端配置
```json
{
  "vnext": [
    {
      "address": "您的服务器IP",
      "port": 443,
      "users": [
        {
          "id": "脚本生成的UUID",
          "flow": "xtls-rprx-vision",
          "encryption": "none"
        }
      ]
    }
  ],
  "streamSettings": {
    "network": "tcp",
    "security": "reality",
    "realitySettings": {
      "serverName": "www.microsoft.com",
      "fingerprint": "chrome",
      "publicKey": "脚本生成的公钥",
      "shortId": "0123456789abcdef"
    }
  }
}
```

### REALITY URL 格式
```
vless://[UUID]@[服务器IP]:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.microsoft.com&fp=chrome&pbk=[公钥]&sid=0123456789abcdef&type=tcp&headerType=none#REALITY
```

## 客户端软件推荐

### Android
- **sing-box** (推荐): 官方客户端，支持所有协议
- **v2rayNG**: 支持 VLESS/REALITY
- **Shadowsocks Android**: 支持 Shadowsocks
- **Matsuri**: 基于 sing-box 的客户端

### iOS
- **sing-box**: 官方客户端
- **Shadowrocket**: 支持多种协议
- **Quantumult X**: 功能强大的代理客户端

### Windows
- **sing-box**: 官方客户端
- **v2rayN**: 支持 VLESS/REALITY
- **Shadowsocks Windows**: 支持 Shadowsocks
- **Clash for Windows**: 支持多种协议

### macOS
- **sing-box**: 官方客户端
- **ClashX**: 支持多种协议
- **Shadowsocks macOS**: 支持 Shadowsocks

### Linux
- **sing-box**: 官方客户端
- **v2ray-core**: 官方 V2Ray 客户端
- **Shadowsocks-libev**: 支持 Shadowsocks

## 路由器配置

### OpenWrt + homeproxy

#### SOCKS5 配置
```
类型: SOCKS
服务器: 您的服务器IP
端口: 脚本生成的端口
用户名: 脚本生成的用户名
密码: 脚本生成的密码
```

#### Shadowsocks 配置
```
类型: Shadowsocks
服务器: 您的服务器IP
端口: 脚本生成的端口
密码: 脚本生成的密码
加密方式: 2022-blake3-aes-128-gcm
```

#### REALITY 配置
```
类型: VLESS
服务器: 您的服务器IP
端口: 443
UUID: 脚本生成的UUID
流控: xtls-rprx-vision
传输: TCP
TLS: 启用
SNI: www.microsoft.com
Reality: 启用
公钥: 脚本生成的公钥
短ID: 0123456789abcdef
```

## 测试连接

### 1. 测试 SOCKS5
```bash
# 使用 curl 测试
curl --socks5 用户名:密码@服务器IP:端口 http://ipinfo.io

# 使用 proxychains 测试
echo "socks5 服务器IP 端口 用户名 密码" >> /etc/proxychains.conf
proxychains curl http://ipinfo.io
```

### 2. 测试 Shadowsocks
```bash
# 使用 ss-local 测试
ss-local -s 服务器IP -p 端口 -k 密码 -m 2022-blake3-aes-128-gcm -l 1080
curl --socks5 127.0.0.1:1080 http://ipinfo.io
```

### 3. 测试 REALITY
使用 sing-box 客户端或 v2ray-core 客户端测试连接。

## 常见问题

### Q1: 连接失败怎么办？
- 检查防火墙设置
- 确认端口是否开放
- 检查服务器状态: `systemctl status sing-box`

### Q2: 速度慢怎么办？
- 尝试不同的协议
- 检查服务器带宽
- 使用 BBR 拥塞控制算法

### Q3: 被封锁怎么办？
- 更换端口
- 使用 REALITY 协议
- 更换服务器IP

### Q4: 配置文件在哪里？
- 服务器配置: `/etc/sing-box/config.json`
- 客户端配置: 根据客户端而定

## 性能优化

### 1. 启用 BBR
```bash
# 检查当前拥塞控制算法
sysctl net.ipv4.tcp_congestion_control

# 启用 BBR
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
```

### 2. 优化内核参数
```bash
# 编辑 /etc/sysctl.conf
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.ip_forward = 1
```

### 3. 增加文件描述符限制
```bash
# 编辑 /etc/security/limits.conf
* soft nofile 65536
* hard nofile 65536
```

## 安全建议

1. **定期更新**: 保持 sing-box 版本最新
2. **强密码**: 使用复杂的密码和密钥
3. **端口变更**: 定期更换端口号
4. **防火墙**: 只开放必要的端口
5. **监控**: 定期检查服务状态和日志

## 备份与恢复

### 备份配置
```bash
# 备份配置文件
cp /etc/sing-box/config.json ~/config.json.backup

# 备份完整配置目录
tar -czf sing-box-config.tar.gz /etc/sing-box/
```

### 恢复配置
```bash
# 恢复配置文件
cp ~/config.json.backup /etc/sing-box/config.json

# 重启服务
systemctl restart sing-box
```
