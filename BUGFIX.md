# Bug 修复报告

## 问题描述
用户在执行脚本时遇到错误：
```
/dev/fd/63: line 313: : No such file or directory
```

## 问题分析

### 根本原因
在 `install.sh` 脚本中，`CONFIG_FILE` 变量没有在脚本开头正确定义，导致在 `create_initial_config()` 函数中使用 heredoc 时，变量为空值，产生了空命令。

### 错误位置
- **文件**: `install.sh`
- **行号**: 第313行 `cat > "$CONFIG_FILE" << EOF`
- **问题**: `$CONFIG_FILE` 变量未定义，导致命令变成 `cat > "" << EOF`

### 错误详情
1. `CONFIG_FILE` 变量定义在 `download_script()` 函数内部的 heredoc 中
2. 这个定义实际上是写入到生成的脚本文件中，而不是在 `install.sh` 中生效
3. 当 `create_initial_config()` 函数执行时，`$CONFIG_FILE` 为空
4. 导致 `cat > "" << EOF` 命令语法错误

## 解决方案

### 修复内容
在 `install.sh` 脚本的全局变量部分添加 `CONFIG_FILE` 变量定义：

```bash
# 全局变量
SCRIPT_NAME="sing-box"
SCRIPT_PATH="/usr/local/bin/sing-box"
CONFIG_DIR="/etc/sing-box"
DATA_DIR="/usr/local/etc/sing-box"
LOG_DIR="/var/log/sing-box"
CONFIG_FILE="$CONFIG_DIR/config.json"  # 新增此行
SERVICE_FILE="/etc/systemd/system/sing-box.service"
SINGBOX_VERSION="latest"
```

### 修复位置
- **文件**: `install.sh`
- **行号**: 第21行（在 `LOG_DIR` 定义后）
- **修改**: 添加 `CONFIG_FILE="$CONFIG_DIR/config.json"`

## 验证方法

### 语法检查
```bash
# 检查脚本语法
bash -n install.sh
bash -n sing-box.sh
```

### 变量验证
```bash
# 验证变量定义
grep -n "CONFIG_FILE=" install.sh
```

## 预防措施

### 1. 变量定义规范
- 所有全局变量应在脚本开头统一定义
- 避免在函数内部定义全局变量
- 使用 `set -u` 检测未定义变量

### 2. 语法检查
- 开发过程中定期使用 `bash -n` 检查语法
- 使用 `shellcheck` 工具进行静态分析
- 添加自动化测试脚本

### 3. 错误处理
- 在关键操作前检查变量是否已定义
- 添加适当的错误提示信息
- 使用 `set -e` 在错误时立即退出

## 相关文件

### 已修复
- ✅ `install.sh` - 添加 CONFIG_FILE 变量定义

### 需要验证
- 🔍 `sing-box.sh` - 检查是否有类似问题
- 🔍 所有 heredoc 语句 - 确保变量正确定义

## 测试建议

### 基础测试
1. 语法检查通过
2. 变量定义正确
3. 脚本可以正常执行（在适当环境中）

### 功能测试
1. 安装流程完整性
2. 配置文件生成正确
3. 服务创建成功

## 版本更新

修复完成后，建议更新版本号：
- 当前版本: v1.0.0
- 建议版本: v1.0.1
- 更新内容: 修复 CONFIG_FILE 变量未定义问题

---

**修复时间**: 2024年
**修复状态**: ✅ 已完成
**测试状态**: 🔍 待验证