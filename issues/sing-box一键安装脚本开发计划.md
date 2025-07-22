# [模式：计划] Sing-box一键安装脚本开发计划

## 项目背景
基于需求文档开发sing-box VPS一键安装脚本，采用方案一（单文件模块化架构），支持vless reality、vmess ws、hy2三种协议，包含端口更改和配置分享功能。

## 实施计划

### 阶段1：基础框架搭建
**步骤1.1：创建主脚本文件**
- 文件：`install.sh`
- 功能：脚本入口点、版本信息、基础变量定义
- 预期结果：可执行的shell脚本框架

**步骤1.2：实现系统检测模块**
- 函数：`check_system()`, `check_dependencies()`
- 逻辑：检测操作系统类型、版本、网络环境、权限验证
- 预期结果：系统兼容性验证通过

**步骤1.3：实现主菜单界面**
- 函数：`show_main_menu()`, `handle_menu_choice()`
- 逻辑：显示协议选择、状态信息、操作选项
- 预期结果：用户友好的交互界面

### 阶段2：核心安装功能
**步骤2.1：实现sing-box下载安装**
- 函数：`download_singbox()`, `install_singbox()`
- 逻辑：获取最新版本、下载二进制文件、创建系统服务
- 预期结果：sing-box成功安装并配置为系统服务

**步骤2.2：实现证书管理模块**
- 函数：`generate_certificates()`, `setup_tls()`
- 逻辑：自动申请SSL证书、配置TLS、处理证书续期
- 预期结果：TLS证书自动配置完成

### 阶段3：协议配置实现
**步骤3.1：实现VLESS Reality配置**
- 函数：`setup_vless_reality()`, `generate_reality_config()`
- 逻辑：配置reality参数、目标网站、私钥公钥生成
- 预期结果：VLESS Reality协议配置文件生成

**步骤3.2：实现VMess WebSocket配置**
- 函数：`setup_vmess_ws()`, `generate_vmess_config()`
- 逻辑：配置websocket路径、UUID生成、伪装网站设置
- 预期结果：VMess WS协议配置文件生成

**步骤3.3：实现Hysteria2配置**
- 函数：`setup_hysteria2()`, `generate_hy2_config()`
- 逻辑：配置hy2端口、密码、混淆参数、带宽限制
- 预期结果：Hysteria2协议配置文件生成

### 阶段4：管理功能实现
**步骤4.1：实现服务管理模块**
- 函数：`manage_service()`, `check_service_status()`
- 逻辑：启动停止重启服务、查看服务状态、设置开机自启
- 预期结果：完整的服务管理功能

**步骤4.2：实现端口管理功能**
- 函数：`change_port()`, `check_port_availability()`
- 逻辑：修改监听端口、检测端口占用、自动重启服务
- 预期结果：动态端口更改功能

**步骤4.3：实现配置分享功能**
- 函数：`generate_share_links()`, `create_qr_code()`
- 逻辑：生成客户端配置链接、二维码、订阅链接
- 预期结果：多格式配置分享功能

### 阶段5：辅助功能完善
**步骤5.1：实现日志查看模块**
- 函数：`show_logs()`, `monitor_connections()`
- 逻辑：实时查看运行日志、错误日志、连接日志
- 预期结果：完整的日志监控功能

**步骤5.2：实现卸载功能**
- 函数：`uninstall_singbox()`, `cleanup_files()`
- 逻辑：完全卸载sing-box、清理配置文件、移除系统服务
- 预期结果：干净的卸载功能

**步骤5.3：实现错误处理和用户体验优化**
- 函数：`error_handler()`, `show_progress()`, `validate_input()`
- 逻辑：异常处理、进度显示、输入验证、用户提示
- 预期结果：稳定可靠的用户体验

## 技术要点
- 使用bash shell编写，兼容主流Linux发行版
- 模块化函数设计，便于维护和扩展
- 完善的错误处理和用户反馈机制
- 安全的配置文件生成和权限管理
- 自动化的服务管理和监控功能

## 预期交付物
1. `install.sh` - 主安装脚本文件
2. 完整的功能测试和验证
3. 用户使用文档和说明

## 开发顺序
按照阶段1→阶段2→阶段3→阶段4→阶段5的顺序进行开发，每个阶段完成后进行功能测试验证。