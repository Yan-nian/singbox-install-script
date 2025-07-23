# Sing-box 配置优化总结

## 最新修复 (2024)

### VMess 配置兼容性修复

**问题**: sing-box 新版本不再支持 VMess 协议中的 `alter_id` 字段，导致配置验证失败。

**错误信息**: 
```
FATAL[0000] decode config at /etc/sing-box/config.json: inbounds[0].users[0].alter_id: json: unknown field "alter_id"
```

**修复内容**:
- ✅ 移除 `generate_vmess_ws_config()` 函数中的 `alter_id` 字段
- ✅ 移除 `generate_enhanced_config()` 函数中的 `alter_id` 字段  
- ✅ 移除 `generate_triple_protocol_config()` 函数中的 `alter_id` 字段
- ✅ 修复现有 `config.json` 文件中的 `alter_id` 字段

**影响范围**: 所有包含 VMess WebSocket 协议的配置函数

**兼容性**: 适配最新版本的 sing-box，确保配置文件能够正常验证和运行

## 优化概述

基于 GitHub 上 `chika0801/sing-box-examples` 仓库的标准模版，对 `install.sh` 脚本中的所有协议配置进行了现代化优化。

## 主要优化内容

### 1. VLESS Reality 配置优化
- ✅ 添加了 `sniff: true` - 启用流量嗅探
- ✅ 添加了 `sniff_override_destination: true` - 覆盖目标地址
- ✅ 添加了 `domain_strategy: "ipv4_only"` - IPv4 优先策略
- ✅ 完善了路由规则和 Clash API 配置

### 2. VMess WebSocket 配置优化
- ✅ 添加了 `sniff: true` - 启用流量嗅探
- ✅ 添加了 `sniff_override_destination: true` - 覆盖目标地址
- ✅ 添加了 `domain_strategy: "ipv4_only"` - IPv4 优先策略
- ✅ 在 `transport` 中添加了 `max_early_data: 2048` - 早期数据支持
- ✅ 在 `transport` 中添加了 `early_data_header_name: "Sec-WebSocket-Protocol"` - 早期数据头
- ✅ 完善了路由规则和 Clash API 配置

### 3. Hysteria2 配置优化
- ✅ 添加了 `sniff: true` - 启用流量嗅探
- ✅ 添加了 `sniff_override_destination: true` - 覆盖目标地址
- ✅ 添加了 `domain_strategy: "ipv4_only"` - IPv4 优先策略
- ✅ 添加了 `up_mbps: 100` 和 `down_mbps: 100` - 带宽限制
- ✅ 添加了 `masquerade` - 伪装网站配置
- ✅ 完善了 DNS 配置（Cloudflare、Google、本地）
- ✅ 添加了完整的路由规则（私有IP、中国域名）
- ✅ 添加了 Clash API 支持

### 4. 多协议配置优化

#### generate_enhanced_config 函数（VMess + Hysteria2）
- ✅ 同步应用了所有单协议的优化配置
- ✅ 确保配置一致性

#### generate_triple_protocol_config 函数（VMess + Hysteria2 + VLESS Reality）
- ✅ 同步应用了所有单协议的优化配置
- ✅ 确保三协议配置的一致性

## 配置标准化

### DNS 配置
```json
"dns": {
  "servers": [
    {
      "tag": "cloudflare",
      "address": "https://1.1.1.1/dns-query",
      "detour": "direct"
    },
    {
      "tag": "google",
      "address": "https://8.8.8.8/dns-query",
      "detour": "direct"
    },
    {
      "tag": "local",
      "address": "223.5.5.5",
      "detour": "direct"
    }
  ],
  "rules": [
    {
      "domain_suffix": [".cn"],
      "server": "local"
    }
  ],
  "final": "cloudflare",
  "strategy": "prefer_ipv4"
}
```

### 路由配置
```json
"route": {
  "rules": [
    {
      "ip_cidr": ["224.0.0.0/3", "ff00::/8"],
      "outbound": "block"
    },
    {
      "ip_cidr": [
        "10.0.0.0/8", "127.0.0.0/8", "169.254.0.0/16",
        "172.16.0.0/12", "192.168.0.0/16", "fc00::/7",
        "fe80::/10", "::1/128"
      ],
      "outbound": "direct"
    },
    {
      "domain_suffix": [".cn"],
      "outbound": "direct"
    }
  ],
  "final": "direct",
  "auto_detect_interface": true
}
```

### Clash API 配置
```json
"experimental": {
  "cache_file": {
    "enabled": true,
    "path": "$SINGBOX_CONFIG_DIR/cache.db"
  },
  "clash_api": {
    "external_controller": "127.0.0.1:9090",
    "external_ui": "ui",
    "secret": "",
    "external_ui_download_url": "https://mirror.ghproxy.com/https://github.com/MetaCubeX/Yacd-meta/archive/gh-pages.zip",
    "external_ui_download_detour": "direct",
    "default_mode": "rule"
  }
}
```

## 优化效果

1. **性能提升**: 通过流量嗅探和智能路由，提高了连接效率
2. **兼容性增强**: 支持更多现代客户端特性
3. **管理便利**: 集成 Clash API，支持 Web 管理界面
4. **配置统一**: 所有协议配置保持一致的标准
5. **安全性**: 完善的路由规则，避免流量泄露

## 验证状态

- ✅ 脚本语法检查通过 (`bash -n install.sh`)
- ✅ 所有配置函数已更新
- ✅ 配置格式符合 Sing-box 最新标准
- ✅ 基于官方示例仓库的最佳实践

## 更新的函数列表

1. `generate_vless_reality_config()` - VLESS Reality 单协议配置
2. `generate_vmess_ws_config()` - VMess WebSocket 单协议配置
3. `install_hysteria2()` - Hysteria2 单协议配置
4. `generate_enhanced_config()` - VMess + Hysteria2 双协议配置
5. `generate_triple_protocol_config()` - 三协议组合配置

所有配置现在都符合 Sing-box 的现代标准，提供了更好的性能、兼容性和管理体验。