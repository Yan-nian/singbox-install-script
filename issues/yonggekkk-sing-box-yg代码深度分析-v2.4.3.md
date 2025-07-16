# yonggekkk/sing-box-yg 脚本代码深度分析报告

## 版本信息
- **分析版本**: v2.4.3
- **分析日期**: 2024年
- **脚本来源**: https://github.com/yonggekkk/sing-box-yg
- **主要脚本**: sb.sh (5251行)

## 1. 脚本架构概览

### 1.1 整体结构
```
sb.sh (5251行)
├── 初始化与环境检测 (1-200行)
├── 系统配置与防火墙 (200-400行)
├── 核心安装与证书管理 (400-800行)
├── JSON配置生成 (800-1500行)
├── 协议配置与端口管理 (1500-3000行)
├── 高级功能模块 (3000-4500行)
├── 用户界面与菜单 (4500-5251行)
```

### 1.2 核心设计理念
- **单文件部署**: 所有功能集成在一个脚本文件中
- **在线安装**: 通过curl直接从GitHub下载执行
- **多协议支持**: 同时支持4种主流代理协议
- **用户友好**: 丰富的交互界面和自动化配置

## 2. 核心功能模块分析

### 2.1 环境检测与初始化
```bash
# 系统检测
if [[ $(id -u) != 0 ]]; then
    red "当前非ROOT账号(或没有ROOT权限)，无法继续操作，请切换到ROOT账号或使用 sudo su 命令获取临时ROOT权限"
    exit 1
fi

# 操作系统支持
if [[ "$release" == "centos" ]]; then
    systemPackage="yum"
elif [[ "$release" == "alpine" ]]; then
    systemPackage="apk"
else
    systemPackage="apt"
fi
```

**特点分析**:
- 严格的权限检查
- 支持主流Linux发行版 (CentOS, Debian, Ubuntu, Alpine)
- 自动检测包管理器
- 不支持Arch Linux (明确排除)

### 2.2 证书管理系统
```bash
inscertificate(){
    # 自动生成自签证书
    openssl ecparam -genkey -name prime256v1 -out /etc/s-box/private.key
    openssl req -new -x509 -days 36500 -key /etc/s-box/private.key -out /etc/s-box/cert.pem
    
    # 检测已有Acme证书
    if [[ -f /root/ygkkkca/cert.crt && -f /root/ygkkkca/private.key ]]; then
        # 提供证书选择选项
    fi
}
```

**创新特点**:
- **双证书系统**: 自签证书 + Acme域名证书
- **智能检测**: 自动识别已申请的域名证书
- **用户选择**: 允许用户在两种证书间切换
- **集成Acme脚本**: 内置证书申请功能

### 2.3 端口管理策略
```bash
chooseport(){
    if [[ -z $port ]]; then
        port=$(shuf -i 10000-65535 -n 1)
        until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") && 
                 -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]
        do
            # 端口冲突检测与重新生成
        done
    fi
}
```

**智能特性**:
- **冲突检测**: 实时检查TCP/UDP端口占用
- **随机生成**: 10000-65535范围内随机端口
- **CDN优化**: Vmess-ws协议使用CDN友好端口
- **多端口跳跃**: 支持端口复用和跳跃

### 2.4 JSON配置生成

#### 支持两种内核版本
```bash
# Sing-box 1.10系列 (支持geosite)
cat > /etc/s-box/sb10.json <<EOF
{
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-sb",
      "listen_port": ${port_vl_re},
      "tls": {
        "enabled": true,
        "reality": {
          "enabled": true,
          "private_key": "$private_key",
          "short_id": ["$short_id"]
        }
      }
    }
  ]
}
EOF

# Sing-box 1.11+系列 (新架构)
cat > /etc/s-box/sb11.json <<EOF
# 使用endpoints替代outbounds中的wireguard配置
EOF
```

**配置特点**:
- **版本兼容**: 同时支持1.10和1.11+内核
- **完整配置**: 包含所有4种协议的完整配置
- **动态生成**: 根据用户选择动态生成配置
- **路由规则**: 复杂的分流规则配置

### 2.5 高级功能模块

#### WARP集成
```bash
inssbwpph(){
    # 下载WARP-plus-Socks5客户端
    curl -L -o /etc/s-box/sbwpph -# --retry 2 --insecure \
        https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sbwpph_$cpu
    
    # 支持多地区Psiphon代理
    nohup setsid /etc/s-box/sbwpph -b 127.0.0.1:$port --cfon --country $guojia -$sw46
}
```

#### Argo隧道支持
```bash
# 检测Argo状态
argopid
if [[ -n $(ps -e | grep -w $ym 2>/dev/null) || -n $(ps -e | grep -w $ls 2>/dev/null) ]]; then
    argoym="已开启"
else
    argoym="未开启"
fi
```

**高级特性**:
- **WARP-plus集成**: 支持本地WARP和多地区Psiphon VPN
- **Argo隧道**: 支持临时域名和固定域名
- **域名分流**: 复杂的域名分流规则
- **TG通知**: 支持Telegram机器人通知

## 3. 用户体验设计

### 3.1 交互界面
```bash
# 彩色输出函数
red(){ echo -e "\033[31m\033[01m$1\033[0m"; }
green(){ echo -e "\033[32m\033[01m$1\033[0m"; }
yellow(){ echo -e "\033[33m\033[01m$1\033[0m"; }
blue(){ echo -e "\033[34m\033[01m$1\033[0m"; }

# 主菜单设计
echo -e "${bblue} ░██     ░██      ░██ ██ ██         ░█${plain}█   ░██     ░██   ░██     ░█${red}█   ░██${plain}  "
echo -e "${bblue}  ░██   ░██      ░██    ░░██${plain}        ░██  ░██      ░██  ░██${red}      ░██  ░██${plain}   "
```

**设计特点**:
- **ASCII艺术**: 精美的Logo设计
- **彩色输出**: 丰富的颜色标识
- **状态显示**: 实时显示系统和服务状态
- **版本检测**: 自动检测脚本和内核版本

### 3.2 信息展示
```bash
showprotocol(){
    echo -e "🚀【 Vless-reality 】${yellow}端口:$vl_port  Reality域名证书伪装地址：$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.server_name')${plain}"
    echo -e "🚀【   Vmess-ws    】${yellow}端口:$vm_port   证书形式:$vm_zs   Argo状态:$argoym${plain}"
    echo -e "🚀【  Hysteria-2   】${yellow}端口:$hy2_port  证书形式:$hy2_zs  转发多端口: $hy2zfport${plain}"
    echo -e "🚀【    Tuic-v5    】${yellow}端口:$tu5_port  证书形式:$tu5_zs  转发多端口: $tu5zfport${plain}"
}
```

## 4. 技术实现亮点

### 4.1 错误处理
```bash
# 下载验证
if [[ -f '/etc/s-box/sing-box.tar.gz' ]]; then
    tar xzf /etc/s-box/sing-box.tar.gz -C /etc/s-box
    if [[ -f '/etc/s-box/sing-box' ]]; then
        blue "成功安装 Sing-box 内核版本：$(/etc/s-box/sing-box version | awk '/version/{print $NF}')"
    else
        red "下载 Sing-box 内核不完整，安装失败，请再运行安装一次" && exit
    fi
else
    red "下载 Sing-box 内核失败，请再运行安装一次，并检测VPS的网络是否可以访问Github" && exit
fi
```

### 4.2 服务管理
```bash
# 跨平台服务管理
if [[ x"${release}" == x"alpine" ]]; then
    status_cmd="rc-service sing-box status"
    status_pattern="started"
else
    status_cmd="systemctl status sing-box"
    status_pattern="active"
fi
```

### 4.3 配置持久化
```bash
# 自动启动配置
crontab -l > /tmp/crontab.tmp
echo '@reboot /bin/bash -c "nohup setsid $(cat /etc/s-box/sbwpph.log 2>/dev/null) & pid=\$! && echo \$pid > /etc/s-box/sbwpphid.log"' >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp
```

## 5. 与当前脚本对比分析

### 5.1 架构差异
| 特性 | yonggekkk脚本 | 当前脚本 |
|------|---------------|----------|
| 文件结构 | 单文件5251行 | 模块化多文件 |
| 部署方式 | 在线一键安装 | 本地脚本执行 |
| 配置管理 | 内置JSON生成 | 外部配置文件 |
| 功能集成度 | 高度集成 | 模块化分离 |

### 5.2 功能对比
| 功能 | yonggekkk脚本 | 当前脚本 |
|------|---------------|----------|
| 协议支持 | 4种协议 | 3种协议 |
| 证书管理 | 双证书系统 | 基础证书 |
| WARP集成 | 完整集成 | 无 |
| Argo支持 | 完整支持 | 无 |
| 配置记忆 | 无明显问题 | 存在问题 |

### 5.3 代码质量分析

**优点**:
- 功能完整，用户体验优秀
- 错误处理完善
- 兼容性好，支持多平台
- 自动化程度高

**缺点**:
- 单文件过大，维护困难
- 代码复用性低
- 模块化程度不足
- 缺乏单元测试

## 6. 改进建议

### 6.1 短期改进
1. **配置记忆功能**: 参考其配置持久化方案
2. **证书管理**: 学习其双证书系统设计
3. **端口管理**: 采用其智能端口检测机制
4. **用户界面**: 改进交互体验和状态显示

### 6.2 中期目标
1. **功能扩展**: 添加WARP和Argo支持
2. **协议支持**: 增加Tuic-v5协议
3. **监控功能**: 添加服务状态监控
4. **自动更新**: 实现脚本自动更新机制

### 6.3 长期规划
1. **架构重构**: 保持模块化的同时增强功能集成
2. **配置中心**: 建立统一的配置管理中心
3. **Web界面**: 开发Web管理界面
4. **API接口**: 提供RESTful API接口

## 7. 核心代码片段学习

### 7.1 智能端口选择
```bash
# 值得学习的端口管理逻辑
ports=()
for i in {1..4}; do
    while true; do
        port=$(shuf -i 10000-65535 -n 1)
        if ! [[ " ${ports[@]} " =~ " $port " ]] && \
           [[ -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && \
           [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]; then
            ports+=($port)
            break
        fi
    done
done
```

### 7.2 配置状态检测
```bash
# 实时状态检测机制
tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
if [[ "$tls" = "false" ]]; then
    vm_zs="TLS关闭"
else
    vm_zs="TLS开启"
fi
```

## 8. 总结

yonggekkk/sing-box-yg脚本是一个功能完整、用户体验优秀的代理配置脚本。其在功能集成度、自动化程度和用户友好性方面都有很多值得学习的地方。虽然其单文件架构在维护性方面存在挑战，但其设计理念和实现方案为我们的脚本改进提供了宝贵的参考。

通过学习其核心设计思路，我们可以在保持模块化架构优势的同时，提升功能完整性和用户体验，最终打造出更加优秀的Sing-box管理脚本。