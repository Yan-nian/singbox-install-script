# 部署指南

本文档说明如何部署修复后的 Sing-box 安装脚本。

## 🚨 当前问题说明

用户遇到的错误：
```
/dev/fd/63: line 313: : No such file or directory
```

**问题原因**：
- 用户执行的是远程仓库的旧版本脚本
- 本地已修复的 `install.sh` 文件没有推送到远程仓库
- README.md 中的下载链接指向了未修复的版本

## 🔧 立即解决方案

### 方案一：使用本地修复版本

如果你有服务器访问权限，直接使用本地修复后的脚本：

```bash
# 在服务器上下载修复后的脚本


# 或者直接复制本地文件内容到服务器
sudo nano install.sh
# 粘贴修复后的脚本内容

# 执行安装
sudo bash install.sh
```

### 方案二：Git 部署流程

1. **提交本地修改**
```bash
cd C:\Users\yy121\Desktop\github\singbox
git add .
git commit -m "fix: 修复 CONFIG_FILE 变量未定义导致的语法错误 (v1.0.1)"
```

2. **推送到远程仓库**
```bash
# 如果是新仓库，先添加远程地址
git remote add origin https://github.com/your-username/singbox.git

# 推送代码
git push -u origin main
```

3. **验证部署**
```bash
# 测试远程脚本
curl -fsSL https://raw.githubusercontent.com/your-username/singbox/main/install.sh | head -30
```

## 📋 部署检查清单

### 推送前检查
- [ ] 本地 `install.sh` 已修复 CONFIG_FILE 变量定义
- [ ] 版本号已更新到 v1.0.1
- [ ] CHANGELOG.md 已记录修复内容
- [ ] README.md 已更新安装说明
- [ ] 所有文件已提交到 Git

### 推送后验证
- [ ] 远程仓库文件已更新
- [ ] 下载链接可正常访问
- [ ] 脚本语法检查通过
- [ ] 在测试环境验证安装流程

## 🔄 GitHub Actions 自动部署（可选）

创建 `.github/workflows/deploy.yml` 实现自动部署：

```yaml
name: Deploy Sing-box Script

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Syntax Check
      run: |
        bash -n install.sh
        bash -n sing-box.sh
    
    - name: Test Installation
      run: |
        # 在容器中测试安装流程
        echo "Testing installation process..."
        # 这里可以添加更多测试

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
    - uses: actions/checkout@v3
    
    - name: Update Release
      run: |
        echo "Deployment successful"
        # 这里可以添加发布逻辑
```

## 🚀 发布新版本

### 创建 GitHub Release

1. **在 GitHub 仓库页面**：
   - 点击 "Releases" → "Create a new release"
   - Tag version: `v1.0.1`
   - Release title: `v1.0.1 - 修复 CONFIG_FILE 变量未定义问题`
   - 描述：参考 CHANGELOG.md 内容

2. **附加文件**：
   - `install.sh` - 安装脚本
   - `sing-box.sh` - 管理脚本
   - `CHANGELOG.md` - 更新日志

### 更新文档链接

确保以下文档中的链接正确：
- README.md 中的安装命令
- 相关博客或文档中的引用
- 社区分享的安装教程

## 🔍 验证部署

### 语法检查
```bash
# 下载并检查语法
wget -O test-install.sh https://raw.githubusercontent.com/your-username/singbox/main/install.sh
bash -n test-install.sh
echo "语法检查：$?"
```

### 功能测试
```bash
# 在测试环境中执行
docker run -it --rm ubuntu:20.04 bash -c "
  apt update && apt install -y curl wget && 
  bash <(curl -fsSL https://raw.githubusercontent.com/your-username/singbox/main/install.sh)
"
```

## 📞 用户通知

部署完成后，通知用户：

1. **问题已修复**：CONFIG_FILE 变量未定义的问题已解决
2. **新安装方式**：推荐使用 Git 克隆方式安装
3. **版本更新**：当前版本为 v1.0.1
4. **重新安装**：如果之前安装失败，请重新执行安装命令

## 🛠️ 故障排除

### 如果推送失败
```bash
# 检查远程仓库状态
git remote -v
git status

# 强制推送（谨慎使用）
git push --force-with-lease origin main
```

### 如果脚本仍有问题
```bash
# 本地测试
bash -n install.sh
bash -x install.sh  # 调试模式
```

---

**注意**：请将所有 `your-username` 替换为实际的 GitHub 用户名。