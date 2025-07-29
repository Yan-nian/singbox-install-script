# sing-box服务器端一键部署脚本

## Core Features

- 多协议支持(Reality/Hysteria2/VMess)

- 内核自动管理

- 端口动态更换

- 服务生命周期管理

- 状态监控

- 配置管理

## Tech Stack

{
  "language": "Bash Shell Script",
  "environment": "Linux服务器 (systemd)",
  "dependencies": [
    "curl/wget",
    "systemd",
    "iptables/ufw",
    "openssl",
    "jq"
  ]
}

## Design

模块化函数设计，配置文件统一管理，systemd服务集成

## Plan

Note: 

- [ ] is holding
- [/] is doing
- [X] is done

---

[X] 创建脚本基础框架和全局变量定义

[X] 实现系统环境检测和依赖安装功能

[X] 开发sing-box内核下载和安装模块

[X] 实现Reality协议配置生成功能

[X] 实现Hysteria2协议配置生成功能

[X] 实现VMess WebSocket TLS协议配置生成功能

[X] 开发systemd服务管理模块

[X] 实现防火墙规则自动配置功能

[X] 开发端口更换和配置更新功能

[X] 实现内核升级和版本管理功能

[X] 开发状态查看和日志监控功能

[X] 创建交互式主菜单和用户界面

[X] 添加配置备份和恢复功能

[X] 实现完整的卸载和清理功能

[X] 进行脚本测试和错误处理优化
