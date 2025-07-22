#!/bin/bash

# sing-box 服务诊断脚本
# 用于诊断和修复 sing-box 服务启动失败问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 检查sing-box二进制文件
check_binary() {
    log_info "检查 sing-box 二进制文件..."
    
    if [[ -f "/usr/local/bin/sing-box" ]]; then
        log_info "✓ sing-box 二进制文件存在: /usr/local/bin/sing-box"
        
        # 检查权限
        if [[ -x "/usr/local/bin/sing-box" ]]; then
            log_info "✓ sing-box 二进制文件可执行"
        else
            log_warn "sing-box 二进制文件不可执行，正在修复权限..."
            chmod +x /usr/local/bin/sing-box
            log_info "✓ 权限已修复"
        fi
        
        # 检查版本
        local version=$(/usr/local/bin/sing-box version 2>/dev/null || echo "未知")
        log_info "sing-box 版本: $version"
    else
        log_error "✗ sing-box 二进制文件不存在: /usr/local/bin/sing-box"
        return 1
    fi
}

# 检查配置目录和文件
check_config() {
    log_info "检查配置目录和文件..."
    
    # 检查配置目录
    if [[ -d "/etc/sing-box" ]]; then
        log_info "✓ 配置目录存在: /etc/sing-box"
    else
        log_warn "配置目录不存在，正在创建..."
        mkdir -p /etc/sing-box
        log_info "✓ 配置目录已创建"
    fi
    
    # 检查配置文件
    if [[ -f "/etc/sing-box/config.json" ]]; then
        log_info "✓ 配置文件存在: /etc/sing-box/config.json"
        
        # 检查配置文件语法
        log_info "检查配置文件语法..."
        if /usr/local/bin/sing-box check -c /etc/sing-box/config.json 2>/dev/null; then
            log_info "✓ 配置文件语法正确"
        else
            log_error "✗ 配置文件语法错误"
            log_info "配置文件内容:"
            cat /etc/sing-box/config.json
            return 1
        fi
    else
        log_error "✗ 配置文件不存在: /etc/sing-box/config.json"
        return 1
    fi
}

# 检查日志目录
check_logs() {
    log_info "检查日志目录..."
    
    if [[ -d "/var/log/sing-box" ]]; then
        log_info "✓ 日志目录存在: /var/log/sing-box"
    else
        log_warn "日志目录不存在，正在创建..."
        mkdir -p /var/log/sing-box
        log_info "✓ 日志目录已创建"
    fi
    
    # 检查日志文件
    if [[ -f "/var/log/sing-box/sing-box.log" ]]; then
        log_info "日志文件存在，显示最近的错误信息:"
        tail -20 /var/log/sing-box/sing-box.log
    else
        log_warn "日志文件不存在: /var/log/sing-box/sing-box.log"
    fi
}

# 检查systemd服务
check_service() {
    log_info "检查 systemd 服务..."
    
    if [[ -f "/etc/systemd/system/sing-box.service" ]]; then
        log_info "✓ systemd 服务文件存在"
        
        # 显示服务状态
        log_info "服务状态:"
        systemctl status sing-box --no-pager || true
        
        # 显示服务日志
        log_info "最近的服务日志:"
        journalctl -u sing-box --no-pager -n 20 || true
    else
        log_error "✗ systemd 服务文件不存在: /etc/systemd/system/sing-box.service"
        return 1
    fi
}

# 检查端口占用
check_ports() {
    log_info "检查端口占用情况..."
    
    if command -v netstat >/dev/null 2>&1; then
        log_info "当前监听的端口:"
        netstat -tlnp | grep -E ':(443|80|8080|1080|10808|10809)' || log_info "未发现常用代理端口被占用"
    elif command -v ss >/dev/null 2>&1; then
        log_info "当前监听的端口:"
        ss -tlnp | grep -E ':(443|80|8080|1080|10808|10809)' || log_info "未发现常用代理端口被占用"
    else
        log_warn "无法检查端口占用（netstat 和 ss 命令都不可用）"
    fi
}

# 尝试手动启动sing-box
manual_start() {
    log_info "尝试手动启动 sing-box..."
    
    if [[ -f "/usr/local/bin/sing-box" ]] && [[ -f "/etc/sing-box/config.json" ]]; then
        log_info "执行命令: /usr/local/bin/sing-box run -c /etc/sing-box/config.json"
        timeout 10s /usr/local/bin/sing-box run -c /etc/sing-box/config.json || {
            local exit_code=$?
            if [[ $exit_code -eq 124 ]]; then
                log_info "✓ sing-box 启动成功（10秒测试）"
            else
                log_error "✗ sing-box 启动失败，退出码: $exit_code"
            fi
        }
    else
        log_error "无法手动启动，缺少必要文件"
    fi
}

# 修复常见问题
fix_common_issues() {
    log_info "尝试修复常见问题..."
    
    # 确保目录存在
    mkdir -p /etc/sing-box
    mkdir -p /var/log/sing-box
    mkdir -p /etc/sing-box/certs
    
    # 设置正确的权限
    if [[ -f "/usr/local/bin/sing-box" ]]; then
        chmod +x /usr/local/bin/sing-box
    fi
    
    if [[ -d "/etc/sing-box" ]]; then
        chmod 755 /etc/sing-box
    fi
    
    if [[ -f "/etc/sing-box/config.json" ]]; then
        chmod 644 /etc/sing-box/config.json
    fi
    
    # 重新加载systemd
    systemctl daemon-reload
    
    log_info "✓ 基本修复完成"
}

# 主函数
main() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}           sing-box 服务诊断工具${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    
    check_root
    
    local has_error=false
    
    # 执行各项检查
    check_binary || has_error=true
    echo
    
    check_config || has_error=true
    echo
    
    check_logs
    echo
    
    check_service
    echo
    
    check_ports
    echo
    
    manual_start
    echo
    
    if [[ "$has_error" == "true" ]]; then
        log_warn "发现问题，尝试自动修复..."
        fix_common_issues
        echo
        
        log_info "修复完成，建议重新运行安装脚本或手动配置"
        echo
        echo "如果问题仍然存在，请检查:"
        echo "1. 网络连接是否正常"
        echo "2. 防火墙设置"
        echo "3. 系统资源是否充足"
        echo "4. 配置文件中的端口是否被其他程序占用"
    else
        log_info "所有检查通过，尝试重启服务..."
        systemctl restart sing-box
        sleep 3
        systemctl status sing-box --no-pager
    fi
    
    echo
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}                诊断完成${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 运行主函数
main "$@"