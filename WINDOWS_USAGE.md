# Windows 环境使用指南

## 问题说明

原始的 `singbox-install.sh` 脚本是为 Linux 系统设计的，在安装完成后会创建 `/usr/local/bin/sb` 软链接作为快捷命令。但在 Windows 环境中，这种方式不适用。

## 解决方案

我们提供了两种 Windows 环境下的快捷启动方案：

### 方案 1: 批处理文件 (推荐)

使用 `sb.bat` 文件：

```cmd
# 直接双击运行
sb.bat

# 或在命令行中运行
sb.bat

# 传递参数
sb.bat --help
sb.bat --install
```

### 方案 2: PowerShell 脚本

使用 `sb.ps1` 文件：

```powershell
# 在 PowerShell 中运行
.\sb.ps1

# 传递参数
.\sb.ps1 --help
.\sb.ps1 --install
```

**注意**: 首次运行 PowerShell 脚本可能需要修改执行策略：
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## 环境要求

这两种方案都需要 bash 环境支持，请安装以下任一环境：

### 1. Git for Windows (推荐)
- **下载地址**: https://git-scm.com/download/win
- **优点**: 轻量级，专为 Windows 设计
- **安装后**: 自动添加 bash 到 PATH

### 2. Windows Subsystem for Linux (WSL)
- **安装命令**: `wsl --install`
- **文档**: https://docs.microsoft.com/zh-cn/windows/wsl/install
- **优点**: 完整的 Linux 环境

### 3. Cygwin
- **下载地址**: https://www.cygwin.com/
- **优点**: 提供完整的 POSIX 环境

## 添加到系统 PATH (可选)

为了在任意位置都能使用 `sb` 命令，可以将脚本目录添加到系统 PATH：

1. 右键 "此电脑" → "属性"
2. 点击 "高级系统设置"
3. 点击 "环境变量"
4. 在 "系统变量" 中找到 "Path"，点击 "编辑"
5. 点击 "新建"，添加脚本所在目录路径
6. 确定保存

添加后，可以在任意位置使用：
```cmd
sb
```

## 故障排除

### 问题 1: "bash" 不是内部或外部命令
**解决方案**: 安装 Git for Windows 或 WSL

### 问题 2: PowerShell 脚本无法执行
**解决方案**: 修改执行策略
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 问题 3: 找不到 singbox-install.sh
**解决方案**: 确保 `sb.bat` 或 `sb.ps1` 与 `singbox-install.sh` 在同一目录

## 使用示例

```cmd
# 启动交互式菜单
sb

# 直接安装
sb --install

# 卸载
sb --uninstall

# 显示帮助
sb --help
```

## 注意事项

1. **权限要求**: 某些操作可能需要管理员权限
2. **路径问题**: Windows 和 Linux 路径格式不同，脚本会自动处理
3. **字符编码**: 建议使用 UTF-8 编码避免中文显示问题
4. **防火墙**: Windows 防火墙可能会阻止网络操作，请根据提示允许

## 更新日志

- **v1.0.0** (2024-12-19): 初始版本，支持 Windows 环境快捷启动