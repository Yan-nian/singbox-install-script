# Sing-Box 简化配置功能说明

## 🎯 功能概述

传统的 Sing-Box 配置需要用户手动输入大量复杂参数，这个简化配置功能让用户只需要输入一个节点名称，系统就能自动生成完整的配置。

## 🚀 主要特性

### 1. 极简操作
- **只需要输入**: 节点名称
- **自动生成**: 所有其他参数
- **一键完成**: 完整配置部署

### 2. 支持协议
- ✅ VLESS Reality (推荐)
- ✅ VMess
- ✅ Hysteria2
- ✅ Shadowsocks

### 3. 自动生成参数
- 📡 **端口**: 10000-65535 随机端口 (自动检测冲突)
- 🔑 **UUID**: 标准UUID v4格式
- 🔐 **密码**: 16位随机字符串
- 🌐 **域名**: 默认使用 www.google.com
- 📝 **路径**: 随机8位字符串
- 🔒 **Reality密钥**: 自动生成密钥对
- 🏷️ **短ID**: 随机8位标识符

## 📋 使用步骤

### 1. 启动脚本
```bash
sudo ./sing-box.sh
```

### 2. 导航菜单
```
选择 [1] 添加配置
选择 [1] 🚀 快速配置 (只需要节点名称)
```

### 3. 选择协议
```
[1] VLESS Reality (推荐)
[2] VMess
[3] Hysteria2
[4] Shadowsocks
```

### 4. 输入节点名称
```
例如: my-vless-node
```

### 5. 确认配置
系统会自动:
- 生成所有参数
- 创建配置文件
- 更新数据库
- 重启服务
- 生成分享链接

## 🎨 配置示例

### VLESS Reality 配置
```
输入: my-vless-node
输出:
  📡 端口: 23456 (随机)
  🔑 UUID: 12345678-1234-1234-1234-123456789abc
  🌐 SNI: www.google.com
  🔒 Private Key: 自动生成
  🔓 Public Key: 自动生成
  🏷️ Short ID: abc12345
```

### VMess 配置
```
输入: my-vmess-node
输出:
  📡 端口: 34567 (随机)
  🔑 UUID: 87654321-4321-4321-4321-abcdef123456
  🌐 域名: www.google.com
  📝 路径: /abc12345
```

### Hysteria2 配置
```
输入: my-hy2-node
输出:
  📡 端口: 45678 (随机)
  🔐 密码: RandomPass123456
  🌐 域名: www.google.com
```

### Shadowsocks 配置
```
输入: my-ss-node
输出:
  📡 端口: 56789 (随机)
  🔐 密码: SSRandomPass123
  🔧 方法: 2022-blake3-chacha20-poly1305
```

## 🔧 技术实现

### 核心函数
- `generate_auto_config()`: 自动配置生成
- `interactive_add_simple_config()`: 交互式简化配置
- `get_random_port()`: 随机端口生成
- `generate_uuid()`: UUID生成
- `generate_password()`: 密码生成
- `generate_reality_keys()`: Reality密钥生成

### 配置文件生成
- `generate_vless_reality_config()`
- `generate_vmess_config()`
- `generate_hysteria2_config()`
- `generate_shadowsocks_config()`

### 分享链接生成
- `generate_vless_url()`
- `generate_vmess_url()`
- `generate_hy2_url()`
- `generate_ss_url()`

## 🛡️ 安全特性

### 1. 随机参数生成
- 端口号随机选择
- UUID符合标准
- 密码强度保证
- 密钥安全生成

### 2. 冲突检测
- 端口占用检测
- 配置名称唯一性
- 参数有效性验证

### 3. 最佳实践
- 使用推荐的加密方法
- 符合协议安全规范
- 自动应用安全配置

## 🎉 优势总结

### 1. 降低使用门槛
- 从复杂参数输入 → 简单名称输入
- 从技术门槛高 → 人人都能使用
- 从容易出错 → 自动化保证

### 2. 提高配置效率
- 从几分钟配置 → 30秒完成
- 从手动操作 → 自动化流程
- 从重复劳动 → 一键完成

### 3. 减少配置错误
- 自动参数生成
- 格式规范保证
- 冲突自动检测

### 4. 智能化管理
- 自动服务重启
- 配置文件管理
- 数据库记录

## 💡 使用建议

### 1. 节点命名
- 使用有意义的名称 (如: hk-node, us-node)
- 避免特殊字符
- 保持简洁明了

### 2. 协议选择
- **VLESS Reality**: 最佳性能+安全性 (推荐)
- **VMess**: 兼容性好
- **Hysteria2**: 高速传输
- **Shadowsocks**: 简单易用

### 3. 部署建议
- 定期更新配置
- 监控服务状态
- 备份重要配置

## 🔄 后续优化

### 1. 计划功能
- 批量节点创建
- 配置模板定制
- 自动负载均衡
- 智能故障转移

### 2. 用户体验
- 图形界面支持
- 移动端适配
- 配置导入导出
- 一键分享功能

## 📞 技术支持

如需技术支持或功能建议，请参考：
- 脚本内置帮助系统
- 配置文件示例
- 错误日志分析
- 社区支持文档

---

**© 2024 Sing-Box 简化配置功能**  
*让复杂的配置变得简单，让每个人都能轻松使用 Sing-Box*
