# 协议配置详解

本文档详细介绍 Sing-box 一键安装脚本支持的各种代理协议的配置方法、特点和使用场景。

## 协议概述

| 协议 | 传输方式 | 加密方式 | 抗检测能力 | 性能 | 适用场景 |
|------|----------|----------|------------|------|----------|
| VLESS Reality Vision | TCP | TLS 1.3 + Reality | 极强 | 高 | 严格网络环境 |
| VMess WebSocket | WebSocket | VMess | 中等 | 中等 | 一般环境，CDN 中转 |
| VMess WebSocket TLS | WebSocket + TLS | VMess + TLS | 强 | 中等 | 需要更高安全性 |
| Hysteria2 | QUIC/UDP | TLS 1.3 | 强 | 极高 | 高带宽需求 |

## VLESS Reality Vision

### 协议特点

- **无特征**: Reality 技术消除了 TLS 指纹特征
- **高性能**: 基于 XTLS Vision 流控，性能优异
- **强抗检测**: 流量特征与真实 HTTPS 完全一致
- **配置简单**: 无需域名和证书

### 技术原理

Reality 协议通过以下技术实现无特征代理：

1. **TLS 握手劫持**: 劫持真实网站的 TLS 握手过程
2. **流量伪装**: 将代理流量伪装成访问目标网站的流量
3. **指纹消除**: 消除 TLS 客户端指纹特征

### 配置参数

```json
{
  "type": "vless",
  "tag": "vless-in",
  "listen": "::",
  "listen_port": 443,
  "users": [
    {
      "uuid": "生成的UUID",
      "flow": "xtls-rprx-vision"
    }
  ],
  "tls": {
    "enabled": true,
    "server_name": "伪装域名",
    "reality": {
      "enabled": true,
      "handshake": {
        "server": "目标服务器",
        "server_port": 443
      },
      "private_key": "Reality私钥",
      "short_id": ["短ID"]
    }
  }
}
```

### 关键参数说明

- **UUID**: 用户标识符，必须与客户端一致
- **server_name**: 伪装的域名，建议使用知名网站
- **target_server**: 目标服务器，用于 TLS 握手
- **private_key**: Reality 私钥，与公钥配对
- **short_id**: 短标识符，用于快速识别

### 推荐目标网站

脚本会自动选择以下目标网站之一：

- `www.microsoft.com`
- `www.apple.com`
- `www.cloudflare.com`
- `www.amazon.com`
- `www.samsung.com`

### 客户端配置示例

```json
{
  "type": "vless",
  "tag": "vless-out",
  "server": "服务器IP",
  "server_port": 443,
  "uuid": "与服务端相同的UUID",
  "flow": "xtls-rprx-vision",
  "tls": {
    "enabled": true,
    "server_name": "伪装域名",
    "utls": {
      "enabled": true,
      "fingerprint": "chrome"
    },
    "reality": {
      "enabled": true,
      "public_key": "Reality公钥",
      "short_id": "短ID"
    }
  }
}
```

## VMess WebSocket

### 协议特点

- **成熟稳定**: 经过长期验证的协议
- **CDN 友好**: 支持通过 CDN 中转
- **兼容性好**: 支持多种客户端
- **配置灵活**: 支持多种传输方式

### 技术原理

VMess 协议特点：

1. **动态端口**: 支持端口跳跃（可选）
2. **时间验证**: 基于时间的身份验证
3. **流量混淆**: 内置流量混淆机制
4. **WebSocket 传输**: 伪装成正常 Web 流量

### 配置参数

```json
{
  "type": "vmess",
  "tag": "vmess-in",
  "listen": "::",
  "listen_port": 8080,
  "users": [
    {
      "uuid": "生成的UUID",
      "alterId": 0
    }
  ],
  "transport": {
    "type": "ws",
    "path": "/随机路径",
    "headers": {
      "Host": "伪装域名"
    },
    "max_early_data": 2048,
    "early_data_header_name": "Sec-WebSocket-Protocol"
  }
}
```

### 关键参数说明

- **UUID**: 用户标识符
- **alterId**: 额外ID数量，建议设为0
- **path**: WebSocket 路径，随机生成
- **Host**: 伪装的主机名
- **max_early_data**: 早期数据大小

### CDN 配置

使用 CDN 中转时的配置要点：

1. **域名解析**: 将域名解析到 CDN
2. **回源配置**: CDN 回源到服务器IP
3. **WebSocket 支持**: 确保 CDN 支持 WebSocket
4. **SSL 配置**: 配置 SSL 证书

### 客户端配置示例

```json
{
  "type": "vmess",
  "tag": "vmess-out",
  "server": "服务器IP或域名",
  "server_port": 8080,
  "uuid": "与服务端相同的UUID",
  "security": "auto",
  "alter_id": 0,
  "transport": {
    "type": "ws",
    "path": "/相同路径",
    "headers": {
      "Host": "伪装域名"
    }
  }
}
```

## VMess WebSocket + TLS

### 协议特点

- **双重加密**: VMess + TLS 双重保护
- **更高安全性**: TLS 1.3 加密传输
- **证书验证**: 支持证书验证
- **ALPN 支持**: 支持应用层协议协商

### 配置参数

```json
{
  "type": "vmess",
  "tag": "vmess-tls-in",
  "listen": "::",
  "listen_port": 8443,
  "users": [
    {
      "uuid": "生成的UUID",
      "alterId": 0
    }
  ],
  "tls": {
    "enabled": true,
    "server_name": "域名",
    "certificate_path": "证书路径",
    "key_path": "私钥路径",
    "alpn": ["h2", "http/1.1"]
  },
  "transport": {
    "type": "ws",
    "path": "/随机路径",
    "headers": {
      "Host": "域名"
    }
  }
}
```

### 证书配置

**自签名证书**（脚本自动生成）：
```bash
# 生成私钥
openssl genrsa -out server.key 2048

# 生成证书
openssl req -new -x509 -key server.key -out server.crt -days 365
```

**Let's Encrypt 证书**：
```bash
# 安装 certbot
apt install certbot

# 申请证书
certbot certonly --standalone -d your-domain.com
```

### 客户端配置示例

```json
{
  "type": "vmess",
  "tag": "vmess-tls-out",
  "server": "服务器IP或域名",
  "server_port": 8443,
  "uuid": "与服务端相同的UUID",
  "security": "auto",
  "alter_id": 0,
  "tls": {
    "enabled": true,
    "server_name": "域名",
    "insecure": false,
    "alpn": ["h2", "http/1.1"]
  },
  "transport": {
    "type": "ws",
    "path": "/相同路径",
    "headers": {
      "Host": "域名"
    }
  }
}
```

## Hysteria2

### 协议特点

- **基于 QUIC**: 使用 QUIC 协议，性能优异
- **拥塞控制**: 内置 BBR 拥塞控制算法
- **多路复用**: 原生支持多路复用
- **快速握手**: 0-RTT 连接建立
- **抗丢包**: 优秀的网络适应性

### 技术原理

Hysteria2 的核心技术：

1. **QUIC 协议**: 基于 UDP 的可靠传输
2. **拥塞控制**: 自适应带宽检测
3. **流量整形**: 模拟真实网络行为
4. **混淆技术**: Salamander 混淆算法

### 配置参数

```json
{
  "type": "hysteria2",
  "tag": "hy2-in",
  "listen": "::",
  "listen_port": 36712,
  "users": [
    {
      "password": "生成的密码"
    }
  ],
  "tls": {
    "enabled": true,
    "server_name": "域名",
    "certificate_path": "证书路径",
    "key_path": "私钥路径",
    "alpn": ["h3"]
  },
  "masquerade": {
    "type": "proxy",
    "proxy": {
      "url": "https://伪装网站",
      "rewrite_host": true
    }
  },
  "obfs": {
    "type": "salamander",
    "password": "混淆密码"
  },
  "up_mbps": 100,
  "down_mbps": 100
}
```

### 关键参数说明

- **password**: 认证密码
- **masquerade**: 伪装配置，用于流量检测时的回退
- **obfs**: 混淆配置，增强抗检测能力
- **up_mbps/down_mbps**: 带宽限制

### 带宽配置

脚本会自动检测服务器带宽，也可以手动配置：

```bash
# 测试带宽
wget -O /dev/null http://speedtest.wdc01.softlayer.com/downloads/test100.zip

# 或使用 iperf3
iperf3 -c speedtest.net
```

### 防火墙配置

Hysteria2 使用 UDP 协议，需要开放 UDP 端口：

```bash
# UFW
ufw allow 36712/udp

# iptables
iptables -A INPUT -p udp --dport 36712 -j ACCEPT

# firewalld
firewall-cmd --permanent --add-port=36712/udp
```

### 客户端配置示例

```json
{
  "type": "hysteria2",
  "tag": "hy2-out",
  "server": "服务器IP",
  "server_port": 36712,
  "password": "与服务端相同的密码",
  "tls": {
    "enabled": true,
    "server_name": "域名",
    "insecure": false,
    "alpn": ["h3"]
  },
  "obfs": {
    "type": "salamander",
    "password": "混淆密码"
  }
}
```

## 多协议配置

### 配置策略

脚本支持同时配置多个协议，提供以下优势：

1. **负载均衡**: 分散流量到不同协议
2. **故障切换**: 一个协议失效时自动切换
3. **场景适配**: 不同场景使用不同协议
4. **性能优化**: 根据网络状况选择最优协议

### 端口分配

默认端口分配：

- VLESS Reality: 443/tcp
- VMess WebSocket: 8080/tcp
- VMess WebSocket TLS: 8443/tcp
- Hysteria2: 36712/udp

### 配置文件结构

```json
{
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen_port": 443
    },
    {
      "type": "vmess",
      "tag": "vmess-in",
      "listen_port": 8080
    },
    {
      "type": "hysteria2",
      "tag": "hy2-in",
      "listen_port": 36712
    }
  ]
}
```

## 性能优化

### 系统参数优化

```bash
# 网络缓冲区
echo 'net.core.rmem_max = 134217728' >> /etc/sysctl.conf
echo 'net.core.wmem_max = 134217728' >> /etc/sysctl.conf

# TCP 优化
echo 'net.ipv4.tcp_congestion_control = bbr' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_fastopen = 3' >> /etc/sysctl.conf

# 应用配置
sysctl -p
```

### 文件描述符限制

```bash
# 临时设置
ulimit -n 65536

# 永久设置
echo '* soft nofile 65536' >> /etc/security/limits.conf
echo '* hard nofile 65536' >> /etc/security/limits.conf
```

### 协议特定优化

**VLESS Reality**:
- 使用高性能目标网站
- 优化 TLS 握手参数
- 启用 XTLS Vision 流控

**VMess WebSocket**:
- 调整 WebSocket 缓冲区
- 优化路径随机性
- 启用压缩（谨慎使用）

**Hysteria2**:
- 准确配置带宽参数
- 启用 BBR 拥塞控制
- 优化 UDP 缓冲区

## 安全建议

### 通用安全措施

1. **定期更新**: 保持软件最新版本
2. **强密码**: 使用复杂的密码和 UUID
3. **端口安全**: 不使用默认端口
4. **访问控制**: 限制管理接口访问
5. **日志监控**: 定期检查访问日志

### 协议特定安全

**VLESS Reality**:
- 选择可信的目标网站
- 定期更换 Reality 密钥
- 监控握手成功率

**VMess**:
- 启用时间验证
- 使用随机 WebSocket 路径
- 定期更换 UUID

**Hysteria2**:
- 使用强混淆密码
- 配置合适的伪装网站
- 监控 UDP 流量特征

## 故障排除

### 常见问题

**连接失败**:
1. 检查防火墙设置
2. 验证配置参数
3. 测试网络连通性
4. 查看服务日志

**性能问题**:
1. 检查带宽配置
2. 优化系统参数
3. 监控资源使用
4. 调整协议参数

**检测问题**:
1. 更换协议参数
2. 调整流量特征
3. 使用多协议配置
4. 监控连接状态

### 调试工具

```bash
# 配置验证
sing-box check -c config.json

# 网络测试
telnet server_ip port
nc -zv server_ip port

# 流量分析
tcpdump -i any -n port 443
ss -tulnp | grep sing-box

# 性能测试
iperf3 -c server_ip
ping -c 10 server_ip
```

## 最佳实践

### 部署建议

1. **多协议部署**: 同时配置多个协议
2. **负载均衡**: 使用多个服务器
3. **监控告警**: 设置服务监控
4. **备份恢复**: 定期备份配置
5. **文档记录**: 记录配置变更

### 维护建议

1. **定期检查**: 每周检查服务状态
2. **日志分析**: 分析访问模式
3. **性能监控**: 监控带宽和延迟
4. **安全审计**: 定期安全检查
5. **版本更新**: 及时更新软件版本

### 扩展建议

1. **CDN 集成**: 使用 CDN 加速
2. **域名轮换**: 定期更换域名
3. **多地部署**: 部署多个地区节点
4. **智能路由**: 实现智能分流
5. **自动化**: 使用脚本自动化管理