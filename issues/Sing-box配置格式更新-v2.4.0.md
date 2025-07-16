# Sing-box 配置格式更新 - v2.4.0

## 更新概述

本次更新将项目中所有使用废弃的 `geoip` 和 `geosite` 配置格式的文件全部更新为新的 `rule_set` 格式，以适应 Sing-box 最新版本的要求。

## 问题描述

### 废弃的配置格式
- `geoip` 和 `geosite` 数据库文件下载方式已废弃
- 旧的路由规则格式不再被支持
- 需要迁移到新的 `rule_set` 远程规则集格式

### 影响范围
- 所有协议配置文件（VLESS、VMess、Hysteria2）
- 配置模板文件
- 订阅生成模块
- 基础配置生成函数

## 解决方案

### 1. 配置格式迁移

#### 旧格式（已废弃）
```json
{
  "route": {
    "geoip": {
      "path": "geoip.db",
      "download_url": "https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db",
      "download_detour": "direct"
    },
    "geosite": {
      "path": "geosite.db",
      "download_url": "https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db",
      "download_detour": "direct"
    },
    "rules": [
      {
        "geosite": "cn",
        "geoip": "cn",
        "outbound": "direct"
      },
      {
        "geosite": "geolocation-!cn",
        "outbound": "proxy"
      }
    ]
  }
}
```

#### 新格式（推荐）
```json
{
  "route": {
    "auto_detect_interface": true,
    "rules": [
      {
        "action": "sniff"
      },
      {
        "protocol": "dns",
        "action": "hijack-dns"
      },
      {
        "rule_set": ["geosite-cn"],
        "outbound": "direct"
      },
      {
        "ip_is_private": true,
        "outbound": "direct"
      },
      {
        "rule_set": ["category-ads-all"],
        "action": "reject"
      }
    ],
    "rule_set": [
      {
        "tag": "geosite-cn",
        "type": "remote",
        "format": "binary",
        "url": "https://fastly.jsdelivr.net/gh/SagerNet/sing-geosite@rule-set/geosite-cn.srs",
        "download_detour": "direct"
      },
      {
        "tag": "category-ads-all",
        "type": "remote",
        "format": "binary",
        "url": "https://fastly.jsdelivr.net/gh/SagerNet/sing-geosite@rule-set/geosite-category-ads-all.srs",
        "download_detour": "direct"
      }
    ],
    "final": "proxy"
  }
}
```

### 2. DNS 配置优化

#### 新的 DNS 规则格式
```json
{
  "dns": {
    "rules": [
      {
        "outbound": ["any"],
        "server": "local"
      },
      {
        "clash_mode": "Proxy",
        "server": "remote"
      },
      {
        "clash_mode": "Direct",
        "server": "local"
      },
      {
        "rule_set": ["geosite-cn"],
        "server": "local"
      },
      {
        "rule_set": ["category-ads-all"],
        "server": "block"
      }
    ],
    "servers": [
      {
        "address": "https://1.1.1.1/dns-query",
        "detour": "Available",
        "tag": "remote"
      },
      {
        "address": "https://223.5.5.5/dns-query",
        "detour": "direct",
        "tag": "local"
      },
      {
        "address": "rcode://success",
        "tag": "block"
      }
    ],
    "strategy": "prefer_ipv4"
  }
}
```

## 技术细节

### 规则集 URL 说明
- **geosite-cn**: 中国大陆网站域名规则集
  - URL: `https://fastly.jsdelivr.net/gh/SagerNet/sing-geosite@rule-set/geosite-cn.srs`
- **category-ads-all**: 广告拦截规则集
  - URL: `https://fastly.jsdelivr.net/gh/SagerNet/sing-geosite@rule-set/geosite-category-ads-all.srs`

### 路由规则优化
1. **流量嗅探**: 添加 `action: "sniff"` 规则
2. **DNS 劫持**: 添加 `protocol: "dns"` 和 `action: "hijack-dns"` 规则
3. **私有 IP**: 添加 `ip_is_private: true` 规则直连
4. **广告拦截**: 使用 `category-ads-all` 规则集拦截广告

## 更新的文件列表

### 核心配置文件
- `lib/protocols.sh` - 主要配置生成函数
- `scripts/config.sh` - 基础配置生成
- `lib/subscription.sh` - 订阅配置生成

### 协议配置文件
- `scripts/protocols/vless.sh` - VLESS 协议配置
- `scripts/protocols/vmess.sh` - VMess 协议配置
- `scripts/protocols/hysteria2.sh` - Hysteria2 协议配置

### 模板文件
- `templates/config.json` - 主配置模板
- `templates/client-base.json` - 客户端基础模板
- `templates/config-base.json` - 服务端基础模板

### 安装脚本
- `singbox-install.sh` - 版本号更新至 v2.4.0

## 兼容性说明

### Sing-box 版本要求
- **最低版本**: 1.8.0+
- **推荐版本**: 1.11.13+
- **测试版本**: 1.11.13

### 配置兼容性
- 新配置格式向后兼容
- 旧的 `geoip/geosite` 格式已完全移除
- 支持 Clash API 模式切换

## 性能优化

### 规则集优势
1. **远程更新**: 规则集可自动从远程服务器更新
2. **二进制格式**: 使用 `.srs` 二进制格式，加载速度更快
3. **CDN 加速**: 使用 jsDelivr CDN 加速下载
4. **缓存机制**: 支持本地缓存，减少网络请求

### 内存使用
- 减少本地文件存储需求
- 降低内存占用
- 提高启动速度

## 测试验证

### 验证步骤
1. 检查配置文件语法正确性
2. 验证规则集下载功能
3. 测试路由规则生效情况
4. 确认 DNS 解析正常
5. 验证广告拦截功能

### 测试命令
```bash
# 验证配置文件
sing-box check -c /etc/sing-box/config.json

# 测试规则集下载
curl -I "https://fastly.jsdelivr.net/gh/SagerNet/sing-geosite@rule-set/geosite-cn.srs"

# 检查服务状态
systemctl status sing-box
```

## 后续优化建议

### 1. 规则集扩展
- 添加更多地区规则集
- 支持自定义规则集 URL
- 实现规则集自动更新机制

### 2. 配置管理
- 添加配置验证功能
- 实现配置备份和恢复
- 支持配置模板切换

### 3. 监控和日志
- 添加规则集更新日志
- 实现性能监控
- 支持规则匹配统计

## 版本信息

- **更新版本**: v2.4.0
- **更新日期**: 2024年
- **更新类型**: 重大配置格式更新
- **兼容性**: 向前兼容，不向后兼容

## 参考资料

- [Sing-box 官方文档](https://sing-box.sagernet.org/)
- [配置模板参考](https://blog.rewired.moe/post/sing-box-config/)
- [规则集仓库](https://github.com/SagerNet/sing-geosite)
- [Sing-box GitHub](https://github.com/SagerNet/sing-box)