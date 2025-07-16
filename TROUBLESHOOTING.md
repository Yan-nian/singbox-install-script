# Sing-box 服务诊断与修复指南

## 问题描述
Sing-box 服务无法正常启动，出现以下错误：
- 服务状态：activating (auto-restart)
- 主进程退出状态：1/FAILURE
- 服务不断重启

## 解决方案

### 1. 使用内置诊断功能
已在主脚本中添加了系统诊断功能：
```bash
sudo ./sing-box.sh
# 选择 [3] 系统管理
# 选择 [6] 系统诊断
```

### 2. 使用快速诊断脚本
```bash
sudo ./diagnose.sh
```
这个脚本会检查：
- 服务运行状态
- 配置文件语法
- 文件权限
- 错误日志
- 手动启动测试

### 3. 使用自动修复脚本
```bash
sudo ./fix_service.sh
```
这个脚本会自动：
- 停止冲突进程
- 修复文件权限
- 重新创建服务文件
- 检查配置文件语法
- 创建备用配置（如果需要）
- 尝试重新启动服务

## 常见问题及解决方法

### 1. 配置文件语法错误
```bash
# 检查配置文件语法
/usr/local/bin/sing-box check -c /etc/sing-box/config.json

# 如果有错误，重新生成配置
sudo ./sing-box.sh
# 选择 [1] 添加配置
```

### 2. 文件权限问题
```bash
# 修复配置文件权限
sudo chmod 644 /etc/sing-box/config.json
sudo chown root:root /etc/sing-box/config.json

# 修复二进制文件权限
sudo chmod 755 /usr/local/bin/sing-box
sudo chown root:root /usr/local/bin/sing-box
```

### 3. 端口冲突
```bash
# 检查端口占用
sudo netstat -tulnp | grep :端口号

# 或者使用 ss 命令
sudo ss -tulnp | grep :端口号
```

### 4. 服务文件损坏
```bash
# 重新创建服务文件
sudo systemctl stop sing-box
sudo rm -f /etc/systemd/system/sing-box.service
# 使用修复脚本重新创建
sudo ./fix_service.sh
```

## 手动诊断步骤

### 1. 检查服务状态
```bash
sudo systemctl status sing-box
```

### 2. 查看详细日志
```bash
# 查看最近的错误日志
sudo journalctl -u sing-box -p err -n 20

# 实时查看日志
sudo journalctl -u sing-box -f
```

### 3. 手动测试启动
```bash
# 手动启动 sing-box（前台运行）
sudo /usr/local/bin/sing-box run -c /etc/sing-box/config.json
```

### 4. 检查配置文件
```bash
# 检查配置文件是否存在
ls -la /etc/sing-box/config.json

# 检查配置文件语法
sudo /usr/local/bin/sing-box check -c /etc/sing-box/config.json
```

## 新增功能说明

### 系统诊断功能
在主脚本的系统管理菜单中新增了"系统诊断"选项，提供：
- 全面的系统状态检查
- 配置文件语法验证
- 权限检查
- 端口占用检查
- 错误日志分析
- 快速修复选项

### 快速修复选项
诊断完成后提供以下快速修复选项：
1. 重启服务
2. 检查配置文件语法
3. 修复文件权限
4. 查看详细错误日志

## 预防措施

1. 定期备份配置文件
2. 使用脚本的备份功能
3. 避免手动修改系统文件权限
4. 定期检查服务状态
5. 监控系统日志

## 联系支持
如果以上方法都无法解决问题，请提供以下信息：
- 系统版本信息
- 完整的错误日志
- 配置文件内容
- 诊断脚本输出
