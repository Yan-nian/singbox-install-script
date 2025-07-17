# 版本信息

## 当前版本: v1.0.0

### 发布日期
2025-01-17

### 更新内容
- 初始版本发布
- 支持 Shadowsocks、SOCKS5、REALITY 三种协议
- 自动安装 sing-box 服务端
- 自动生成配置文件和密钥
- 自动配置防火墙规则
- 提供交互式菜单界面
- 支持服务管理（启动、停止、重启）
- 支持状态监控和日志查看
- 支持一键卸载

### 支持的系统
- Debian 9+
- Ubuntu 18.04+
- CentOS 7+
- RHEL 7+

### 支持的协议
- **SOCKS5**: 基于用户名密码认证的代理协议
- **Shadowsocks**: 使用 2022-blake3-aes-128-gcm 加密
- **REALITY**: 基于 VLESS 的新型协议，伪装性强

### 功能特点
1. 一键安装，无需手动配置
2. 自动生成随机密钥和端口
3. 自动配置防火墙规则
4. 支持多种系统和防火墙
5. 提供详细的客户端配置信息
6. 支持服务管理和监控
7. 提供完整的使用文档

### 文件结构
```
singbox-install-script/
├── install.sh              # 主安装脚本
├── README.md               # 使用说明
├── client-config.md        # 客户端配置示例
├── config-template.json    # 配置文件模板
└── VERSION.md             # 版本信息
```

### 使用方法
```bash
# 方法一：直接运行
sudo bash <(curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/master/install.sh)

# 方法二：下载后运行
curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/master/install.sh -o install.sh
chmod +x install.sh
sudo ./install.sh

# 方法三：一键安装
sudo bash <(curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/master/install.sh) install
```

### 已知问题
- 暂无

### 计划功能
- [ ] 支持更多协议（Trojan、Hysteria2、TUIC等）
- [ ] 支持配置文件备份和恢复
- [ ] 支持多用户管理
- [ ] 支持流量统计
- [ ] 支持定时任务（自动重启、日志清理等）
- [ ] 支持 Web 管理界面
- [ ] 支持一键更新功能

### 贡献者
- Yan-nian (主要开发者)

### 反馈和支持
如果您在使用过程中遇到问题，请通过以下方式反馈：
1. 在 GitHub 上提交 Issue
2. 发送邮件至开发者邮箱
3. 在相关技术论坛讨论

### 许可证
本项目采用 MIT 许可证，详见 LICENSE 文件。

### 免责声明
本脚本仅供学习和技术交流使用，请遵守当地法律法规。使用本脚本所产生的任何后果，由使用者自行承担。

---

**最后更新**: 2025-01-17  
**下次更新**: 待定
