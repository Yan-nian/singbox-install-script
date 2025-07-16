# Sing-box 一键配置脚本使用说明

## 特性

### 🎯 交互式用户界面
- 美观的彩色菜单界面
- 用户友好的交互式配置流程
- 智能输入验证和错误处理
- 实时配置预览和确认

### 🔧 协议支持
- **VLESS Reality** (推荐) - 最新的抗封锁协议
- **VMess** - 经典的 V2Ray 协议
- **Hysteria2** - 基于 QUIC 的高性能协议
- **Shadowsocks** - 轻量级代理协议

### 📊 配置管理
- 查看所有配置列表
- 查看配置详细信息
- 删除不需要的配置
- 动态更换端口
- 重新生成 UUID

### 🛠️ 系统管理
- 启动/停止/重启服务
- 查看服务状态
- 实时日志查看
- 系统性能优化
- 完整卸载功能

### 📱 分享功能
- 生成分享链接
- 生成二维码
- 导出配置文件
- 批量显示所有链接

## 使用方法

### 1. 交互式菜单模式（推荐）

直接运行脚本进入交互式菜单：

```bash
./sing-box.sh
```

### 2. 命令行模式

#### 添加配置
```bash
# 添加 VLESS Reality 配置
./sing-box.sh add vless [名称] [端口] [SNI域名]

# 添加 VMess 配置
./sing-box.sh add vmess [名称] [端口] [域名]

# 添加 Hysteria2 配置
./sing-box.sh add hy2 [名称] [端口] [域名]
```

#### 管理配置
```bash
# 查看所有配置
./sing-box.sh list

# 查看配置详情
./sing-box.sh info <配置名称>

# 删除配置
./sing-box.sh del <配置名称>

# 获取分享链接
./sing-box.sh url <配置名称>

# 生成二维码
./sing-box.sh qr <配置名称>

# 更换端口
./sing-box.sh port <配置名称> <新端口>
```

#### 系统管理
```bash
# 启动服务
./sing-box.sh start

# 停止服务
./sing-box.sh stop

# 重启服务
./sing-box.sh restart

# 查看状态
./sing-box.sh status

# 查看日志
./sing-box.sh log

# 卸载程序
./sing-box.sh uninstall
```

## 交互式界面导航

### 主菜单
```
╔═══════════════════════════════════════════════════════════════════════════════════╗
║                              Sing-box 一键管理脚本                              ║
║                                   版本: v1.0.0                                   ║
╚═══════════════════════════════════════════════════════════════════════════════════╝

请选择操作：

  [1] 添加配置
  [2] 管理配置
  [3] 系统管理
  [4] 分享链接
  [5] 系统信息
  [6] 更新脚本
  [0] 退出脚本
```

### 添加配置菜单
```
选择要添加的协议：

  [1] VLESS Reality (推荐)
  [2] VMess
  [3] Hysteria2
  [4] Shadowsocks
  [0] 返回主菜单
```

### 管理配置菜单
```
配置管理：

  [1] 查看所有配置
  [2] 查看配置详情
  [3] 删除配置
  [4] 更换端口
  [5] 重新生成 UUID
  [0] 返回主菜单
```

### 系统管理菜单
```
系统管理：

  [1] 启动服务
  [2] 停止服务
  [3] 重启服务
  [4] 查看状态
  [5] 查看日志
  [6] 系统优化
  [7] 卸载 Sing-box
  [0] 返回主菜单
```

## 配置示例

### VLESS Reality 配置流程
1. 选择 "添加配置" -> "VLESS Reality"
2. 输入配置名称（如：vless-main）
3. 输入监听端口（如：8443）
4. 输入 SNI 域名（如：www.google.com）
5. 确认配置信息
6. 系统自动生成 UUID 和 Reality 密钥
7. 显示分享链接

### VMess 配置流程
1. 选择 "添加配置" -> "VMess"
2. 输入配置名称（如：vmess-main）
3. 输入监听端口（如：8080）
4. 输入域名（如：example.com）
5. 输入 WebSocket 路径（如：/ws）
6. 确认配置信息
7. 系统自动生成 UUID
8. 显示分享链接

## 系统优化功能

### BBR 优化
- 启用 BBR 拥塞控制算法
- 提高网络传输效率
- 减少延迟和丢包

### 系统参数优化
- 优化网络缓冲区大小
- 调整 TCP 参数
- 提高并发连接数

### 防火墙配置
- 自动开放必要端口
- 配置安全规则
- 支持 UFW 和 Firewalld

## 文件结构

```
/etc/sing-box/
├── config.json             # 主配置文件
├── configs/                # 各协议配置存储
│   ├── vless-001.json
│   ├── vmess-001.json
│   └── hy2-001.json
├── cert.pem                # TLS 证书
├── key.pem                 # TLS 私钥
└── sing-box.db             # 配置数据库

/usr/local/bin/
└── sing-box                # 主程序

/usr/local/etc/sing-box/
└── sing-box.db             # 配置数据库备份
```

## 注意事项

1. **权限要求**：脚本需要 root 权限运行
2. **系统兼容性**：支持 Ubuntu、Debian、CentOS、RHEL 等主流发行版
3. **防火墙**：确保配置的端口在防火墙中开放
4. **证书配置**：VMess 和 Hysteria2 需要有效的 TLS 证书
5. **端口冲突**：脚本会自动检查端口占用情况

## 故障排查

### 服务无法启动
1. 检查配置文件语法：`sing-box check -c /etc/sing-box/config.json`
2. 查看系统日志：`journalctl -u sing-box -f`
3. 检查端口占用：`ss -tuln | grep <端口>`

### 连接失败
1. 确认防火墙规则
2. 检查服务状态：`systemctl status sing-box`
3. 验证分享链接格式

### 性能问题
1. 运行系统优化功能
2. 检查系统资源使用情况
3. 调整并发连接数

## 更新日志

### v1.0.0
- 初始版本发布
- 支持 VLESS Reality、VMess、Hysteria2、Shadowsocks
- 完整的交互式用户界面
- 配置管理功能
- 系统优化功能
- 分享链接生成

## 技术支持

如果遇到问题，请：
1. 查看日志文件
2. 检查系统兼容性
3. 验证网络连接
4. 确认配置参数

---

**享受使用 Sing-box 一键配置脚本！**
