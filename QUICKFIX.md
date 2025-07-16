# 🚨 紧急修复指南

## 问题描述

如果你遇到以下错误：
```
/dev/fd/63: line 313: : No such file or directory
```

这是因为你执行的是远程仓库的旧版本脚本，该版本存在 `CONFIG_FILE` 变量未定义的问题。

## ⚡ 立即解决方案

### 方案一：使用修复后的脚本（推荐）

1. **下载修复后的脚本**：
```bash
# 创建临时目录
mkdir -p /tmp/singbox-fix
cd /tmp/singbox-fix

# 下载修复后的脚本（请替换为正确的仓库地址）
wget https://raw.githubusercontent.com/your-username/singbox/main/install.sh

# 检查脚本是否包含修复
grep "CONFIG_FILE=" install.sh
# 应该看到：CONFIG_FILE="$CONFIG_DIR/config.json"
```

2. **执行修复后的脚本**：
```bash
sudo bash install.sh
```

### 方案二：手动修复现有脚本

如果无法下载新版本，可以手动修复：

1. **编辑脚本**：
```bash
sudo nano /tmp/install.sh  # 或者你下载的脚本路径
```

2. **添加变量定义**：
在脚本的全局变量部分（大约第20-25行）添加：
```bash
CONFIG_FILE="$CONFIG_DIR/config.json"
```

完整的全局变量部分应该类似：
```bash
# 全局变量
SCRIPT_NAME="sing-box"
SCRIPT_PATH="/usr/local/bin/sing-box"
CONFIG_DIR="/etc/sing-box"
DATA_DIR="/usr/local/etc/sing-box"
LOG_DIR="/var/log/sing-box"
CONFIG_FILE="$CONFIG_DIR/config.json"  # 添加这一行
SERVICE_FILE="/etc/systemd/system/sing-box.service"
SINGBOX_VERSION="latest"
```

3. **保存并执行**：
```bash
sudo bash install.sh
```

### 方案三：克隆仓库安装

```bash
# 克隆修复后的仓库
git clone https://github.com/your-username/singbox.git
cd singbox

# 执行安装
sudo bash install.sh
```

## 🔍 验证修复

安装完成后，验证服务是否正常：

```bash
# 检查服务状态
systemctl status sing-box

# 检查配置文件
ls -la /etc/sing-box/

# 测试命令
sing-box help
```

## 📋 如果仍有问题

### 检查日志
```bash
# 查看系统日志
journalctl -u sing-box -f

# 查看安装日志
tail -f /var/log/sing-box/sing-box.log
```

### 完全重新安装
```bash
# 停止服务
sudo systemctl stop sing-box
sudo systemctl disable sing-box

# 清理文件
sudo rm -rf /etc/sing-box
sudo rm -rf /usr/local/etc/sing-box
sudo rm -rf /var/log/sing-box
sudo rm -f /usr/local/bin/sing-box
sudo rm -f /usr/local/bin/sb
sudo rm -f /etc/systemd/system/sing-box.service

# 重新安装
sudo bash install.sh
```

## 🎯 预防措施

1. **使用正确的安装链接**：
   - 确保使用最新的仓库地址
   - 检查分支名称（main 或 master）

2. **验证脚本内容**：
   ```bash
   # 下载前先检查
   curl -s https://raw.githubusercontent.com/your-username/singbox/main/install.sh | head -30
   ```

3. **本地安装**：
   - 推荐克隆仓库到本地安装
   - 可以检查和修改脚本内容

## 📞 获取帮助

如果以上方案都无法解决问题：

1. **检查系统环境**：
   - 操作系统版本
   - 是否有足够权限
   - 网络连接状态

2. **提供错误信息**：
   - 完整的错误日志
   - 系统环境信息
   - 执行的具体命令

3. **联系支持**：
   - 在 GitHub 仓库提交 Issue
   - 提供详细的错误复现步骤

---

**重要提醒**：请将所有 `your-username` 替换为实际的 GitHub 用户名！

**版本信息**：此修复适用于 v1.0.2 及以上版本。