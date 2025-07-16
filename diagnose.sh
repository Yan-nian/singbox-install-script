#!/bin/bash

# Sing-box 快速诊断脚本
# 用于诊断服务启动问题

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 检查配置文件语法（兼容不同版本）
check_config_syntax() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi
    
    # 检查 sing-box 二进制文件是否存在
    if [[ ! -f "/usr/local/bin/sing-box" ]]; then
        return 1
    fi
    
    # 尝试不同的命令格式
    # 新版本格式：sing-box check -c config.json
    if /usr/local/bin/sing-box check -c "$config_file" >/dev/null 2>&1; then
        return 0
    fi
    
    # 旧版本格式：sing-box check config.json  
    if /usr/local/bin/sing-box check "$config_file" >/dev/null 2>&1; then
        return 0
    fi
    
    # 更旧版本格式：sing-box -c config.json -check
    if /usr/local/bin/sing-box -c "$config_file" -check >/dev/null 2>&1; then
        return 0
    fi
    
    # 如果都不行，尝试手动启动测试（但立即停止）
    timeout 2 /usr/local/bin/sing-box run -c "$config_file" >/dev/null 2>&1
    local exit_code=$?
    
    # 如果超时（退出码 124），说明配置文件可能是正确的
    if [[ $exit_code -eq 124 ]]; then
        return 0
    fi
    
    return 1
}

# 获取配置文件错误信息
get_config_error() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        echo "配置文件不存在"
        return
    fi
    
    if [[ ! -f "/usr/local/bin/sing-box" ]]; then
        echo "sing-box 二进制文件不存在"
        return
    fi
    
    # 尝试不同的命令格式获取错误信息
    local error_output
    
    # 新版本格式
    error_output=$(/usr/local/bin/sing-box check -c "$config_file" 2>&1)
    if [[ $? -eq 0 ]]; then
        echo "配置文件语法正确"
        return
    fi
    
    # 如果错误信息包含 "未知命令"，尝试其他格式
    if echo "$error_output" | grep -q "未知命令\|unknown command"; then
        # 旧版本格式
        error_output=$(/usr/local/bin/sing-box check "$config_file" 2>&1)
        if [[ $? -eq 0 ]]; then
            echo "配置文件语法正确"
            return
        fi
        
        # 更旧版本格式
        error_output=$(/usr/local/bin/sing-box -c "$config_file" -check 2>&1)
        if [[ $? -eq 0 ]]; then
            echo "配置文件语法正确"
            return
        fi
        
        # 手动启动测试
        error_output=$(timeout 2 /usr/local/bin/sing-box run -c "$config_file" 2>&1)
        if [[ $? -eq 124 ]]; then
            echo "配置文件语法正确（通过启动测试验证）"
            return
        fi
    fi
    
    echo "$error_output"
}

CONFIG_FILE="/etc/sing-box/config.json"

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}                 Sing-box 快速诊断工具                    ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo

# 1. 检查服务状态
echo -e "${YELLOW}1. 检查服务状态${NC}"
if systemctl is-active --quiet sing-box; then
    echo -e "  ${GREEN}✓ 服务正在运行${NC}"
else
    echo -e "  ${RED}✗ 服务未运行${NC}"
    echo -e "  ${BLUE}详细状态:${NC}"
    systemctl status sing-box --no-pager -l
    echo
fi

# 2. 检查配置文件
echo -e "${YELLOW}2. 检查配置文件${NC}"
if [[ -f "$CONFIG_FILE" ]]; then
    echo -e "  ${GREEN}✓ 配置文件存在: $CONFIG_FILE${NC}"
    
    # 检查配置文件语法
    echo -e "  ${BLUE}检查配置文件语法...${NC}"
    if check_config_syntax "$CONFIG_FILE"; then
        echo -e "  ${GREEN}✓ 配置文件语法正确${NC}"
    else
        echo -e "  ${RED}✗ 配置文件语法错误${NC}"
        echo -e "  ${BLUE}详细错误:${NC}"
        get_config_error "$CONFIG_FILE"
        echo
    fi
else
    echo -e "  ${RED}✗ 配置文件不存在: $CONFIG_FILE${NC}"
fi

# 3. 检查最近的错误日志
echo -e "${YELLOW}3. 最近的错误日志${NC}"
echo -e "  ${BLUE}最近 10 条错误日志:${NC}"
journalctl -u sing-box --no-pager -p err -n 10 2>/dev/null || echo -e "  ${GREEN}✓ 近期无错误日志${NC}"
echo

# 4. 检查文件权限
echo -e "${YELLOW}4. 检查文件权限${NC}"
if [[ -f "$CONFIG_FILE" ]]; then
    config_perm=$(stat -c "%a" "$CONFIG_FILE" 2>/dev/null || stat -f "%A" "$CONFIG_FILE")
    config_owner=$(stat -c "%U:%G" "$CONFIG_FILE" 2>/dev/null || stat -f "%Su:%Sg" "$CONFIG_FILE")
    echo -e "  配置文件权限: $config_perm ($config_owner)"
fi

if [[ -f "/usr/local/bin/sing-box" ]]; then
    binary_perm=$(stat -c "%a" "/usr/local/bin/sing-box" 2>/dev/null || stat -f "%A" "/usr/local/bin/sing-box")
    echo -e "  二进制文件权限: $binary_perm"
else
    echo -e "  ${RED}✗ Sing-box 二进制文件不存在${NC}"
fi

# 5. 手动测试启动
echo -e "${YELLOW}5. 手动测试启动${NC}"
echo -e "  ${BLUE}尝试手动启动 sing-box...${NC}"
if [[ -f "$CONFIG_FILE" ]]; then
    if check_config_syntax "$CONFIG_FILE"; then
        echo -e "  ${GREEN}✓ 配置文件语法正确，可以启动${NC}"
        echo -e "  ${BLUE}启动测试输出:${NC}"
        timeout 3 /usr/local/bin/sing-box run -c "$CONFIG_FILE" 2>&1 | head -10
    else
        echo -e "  ${RED}✗ 配置文件语法错误，无法启动${NC}"
        echo -e "  ${BLUE}错误详情:${NC}"
        get_config_error "$CONFIG_FILE"
    fi
else
    echo -e "  ${RED}✗ 无法测试，配置文件不存在${NC}"
fi

echo -e "\n${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}                      诊断完成                            ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"

# 提供修复建议
echo -e "\n${YELLOW}修复建议:${NC}"
echo -e "1. 如果配置文件语法错误，请重新生成配置"
echo -e "2. 如果权限问题，运行: chmod 644 $CONFIG_FILE"
echo -e "3. 如果端口冲突，检查其他进程是否占用端口"
echo -e "4. 查看详细日志: journalctl -u sing-box -f"
echo -e "5. 重启服务: systemctl restart sing-box"
