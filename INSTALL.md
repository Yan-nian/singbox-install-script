# 安装和升级说明

## 安装方式

### 1. 全新安装

如果您还没有安装 Sing-box，使用安装脚本：

```bash
sudo bash install.sh
```

这将：
- 安装 Sing-box 核心程序
- 创建完整的目录结构
- 安装我们的交互式管理脚本
- 配置 systemd 服务
- 安装必要的依赖包

### 2. 覆盖升级

如果您已经安装了 Sing-box 但想升级到交互式界面版本：

```bash
sudo bash upgrade.sh
```

这将：
- 检查现有安装
- 备份现有脚本
- 安装新的交互式管理脚本
- 保留现有配置
- 验证安装

### 3. 脚本更新

如果您已经安装了我们的脚本，只需要更新到最新版本：

```bash
sudo bash update.sh
```

这将：
- 备份现有脚本
- 下载最新版本
- 验证更新
- 保留所有配置和数据

## 使用说明

### 启动交互式界面

安装完成后，直接运行：

```bash
sing-box
```

或使用快捷命令：

```bash
sb
```

### 命令行模式

您也可以继续使用命令行模式：

```bash
# 添加配置
sing-box add vless
sing-box add vmess

# 管理配置
sing-box list
sing-box info vless-001
sing-box url vless-001

# 系统管理
sing-box start
sing-box stop
sing-box status
```

## 文件结构

```
/usr/local/bin/sing-box     # 主管理脚本
/usr/local/bin/sb           # 快捷命令链接
/usr/local/bin/sing-box     # Sing-box 核心程序
/etc/sing-box/              # 配置目录
├── config.json             # 主配置文件
├── configs/                # 各协议配置存储
├── cert.pem               # TLS 证书
└── key.pem                # TLS 私钥
/usr/local/etc/sing-box/    # 数据目录
└── sing-box.db            # 配置数据库
/var/log/sing-box/         # 日志目录
└── sing-box.log           # 日志文件
```

## 卸载

如果需要完全卸载：

```bash
sing-box uninstall
```

或使用交互式界面：
1. 运行 `sing-box`
2. 选择 `[3] 系统管理`
3. 选择 `[7] 卸载 Sing-box`

## 故障排查

### 权限问题
确保使用 root 权限运行安装脚本：
```bash
sudo bash install.sh
```

### 网络问题
如果无法下载，可以手动下载后本地安装：
```bash
# 下载脚本文件到本地
wget https://raw.githubusercontent.com/Yan-nian/singbox-install-script/master/sing-box.sh

# 本地安装
sudo bash install.sh
```

### 依赖问题
手动安装依赖包：
```bash
# Ubuntu/Debian
sudo apt-get install openssl qrencode bc

# CentOS/RHEL
sudo yum install openssl qrencode bc
```

### 服务问题
检查服务状态：
```bash
systemctl status sing-box
journalctl -u sing-box -f
```

## 版本历史

- v1.0.0: 初始版本，支持交互式界面和四种协议
