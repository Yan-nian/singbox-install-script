# Sing-box 在线一键安装

## 快速开始

### 方法一：使用 curl（推荐）
```bash
curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/main/one-click-install.sh | sudo bash
```

### 方法二：使用 wget
```bash
wget -qO- https://raw.githubusercontent.com/Yan-nian/singbox-install-script/main/one-click-install.sh | sudo bash
```

## 直接安装特定协议

### 安装 VLESS Reality Vision（推荐）
```bash
curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/main/one-click-install.sh | sudo bash -s -- --vless
```

### 安装 VMess WebSocket
```bash
curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/main/one-click-install.sh | sudo bash -s -- --vmess
```

### 安装 Hysteria2
```bash
curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/main/one-click-install.sh | sudo bash -s -- --hysteria2
```

## 部署说明

### 1. 构建脚本

在发布之前，开发者需要先在项目根目录运行构建脚本，生成 `one-click-install.sh` 文件：

```bash
bash scripts/build.sh
```

### 2. 发布脚本

构建成功后，将生成的 `one-click-install.sh` 文件上传到您的 Web 服务器或代码托管平台（如 GitHub Release），并确保可以通过一个稳定的 URL 公开访问。

### 2. GitHub Raw 地址
使用 GitHub Raw 地址：`https://raw.githubusercontent.com/Yan-nian/singbox-install-script/main/one-click-install.sh`

### 3. 设置正确的 MIME 类型
确保您的 Web 服务器为 `.sh` 文件设置了正确的 MIME 类型：
```
text/plain
```

### 4. 配置 HTTPS
为了安全起见，强烈建议使用 HTTPS 来提供安装脚本。

## 使用示例

### 完整的部署命令
```bash
# 使用 GitHub Raw 地址
curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/main/one-click-install.sh | sudo bash
```

### GitHub Raw 部署示例
直接使用 GitHub Raw 地址：
```bash
curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/main/one-click-install.sh | sudo bash
```

### 自建服务器部署示例
```bash
# 上传到服务器的 /var/www/html/ 目录
sudo cp one-click-install.sh /var/www/html/

# 设置权限
sudo chmod 644 /var/www/html/one-click-install.sh

# 使用（替换为您的服务器域名）
curl -fsSL https://your-server.com/one-click-install.sh | sudo bash
```

## 功能特性

- ✅ **真正的一键安装**：无需预先下载任何文件
- ✅ **自动检测系统**：支持 Ubuntu、Debian、CentOS、RHEL、Fedora
- ✅ **自动安装依赖**：自动安装所需的系统依赖
- ✅ **最新版本**：自动下载最新版本的 Sing-box
- ✅ **多协议支持**：支持 VLESS Reality Vision、VMess WebSocket、Hysteria2
- ✅ **自动配置**：自动生成配置文件和系统服务
- ✅ **防火墙配置**：自动配置防火墙规则
- ✅ **参数支持**：支持命令行参数直接安装特定协议

## 安全说明

1. **HTTPS 必须**：请确保使用 HTTPS 来提供安装脚本，避免中间人攻击
2. **域名验证**：建议用户验证域名的真实性
3. **脚本审查**：建议用户在执行前查看脚本内容
4. **权限最小化**：脚本只请求必要的 root 权限

## 故障排除

### 网络问题
如果遇到网络连接问题，可以尝试：
```bash
# 使用代理
export https_proxy=http://proxy-server:port
curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/main/one-click-install.sh | sudo bash
```

### 权限问题
确保使用 sudo 运行：
```bash
# 错误的方式
curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/main/one-click-install.sh | bash

# 正确的方式
curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/main/one-click-install.sh | sudo bash
```

### 系统不支持
目前支持的系统：
- Ubuntu 18.04+
- Debian 9+
- CentOS 7+
- RHEL 7+
- Fedora 30+

## 管理命令

安装完成后，可以使用以下命令管理 Sing-box：

```bash
# 查看服务状态
sudo systemctl status sing-box

# 启动服务
sudo systemctl start sing-box

# 停止服务
sudo systemctl stop sing-box

# 重启服务
sudo systemctl restart sing-box

# 查看日志
sudo journalctl -u sing-box -f

# 查看配置
sudo cat /var/lib/sing-box/config.json
```

## 卸载

如果需要卸载 Sing-box：

```bash
# 停止并禁用服务
sudo systemctl stop sing-box
sudo systemctl disable sing-box

# 删除服务文件
sudo rm /etc/systemd/system/sing-box.service

# 删除二进制文件
sudo rm /usr/local/bin/sing-box

# 删除配置目录（可选）
sudo rm -rf /var/lib/sing-box

# 重新加载 systemd
sudo systemctl daemon-reload
```

## 更新脚本

要更新到最新版本的安装脚本，只需重新运行安装命令即可。脚本会自动检测并更新到最新版本。

## 支持

如果遇到问题，请：
1. 检查系统日志：`sudo journalctl -u sing-box -f`
2. 查看安装日志：`sudo cat /var/log/sing-box-install.log`
3. 提交 Issue 到项目仓库

---

**注意**：本文档已更新为使用 GitHub Raw 地址，可直接复制使用。如需自建服务器部署，请将相关命令中的域名替换为您的实际域名。