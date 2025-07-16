#!/bin/bash

# Sing-box 配置语法检查脚本
# 兼容不同版本的 sing-box

CONFIG_FILE="/etc/sing-box/config.json"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
    echo -e "${BLUE}正在尝试不同的命令格式...${NC}"
    
    # 新版本格式：sing-box check -c config.json
    echo -e "${YELLOW}尝试: sing-box check -c config.json${NC}"
    if /usr/local/bin/sing-box check -c "$config_file" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 新版本格式检查通过${NC}"
        return 0
    fi
    
    # 旧版本格式：sing-box check config.json  
    echo -e "${YELLOW}尝试: sing-box check config.json${NC}"
    if /usr/local/bin/sing-box check "$config_file" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 旧版本格式检查通过${NC}"
        return 0
    fi
    
    # 更旧版本格式：sing-box -c config.json -check
    echo -e "${YELLOW}尝试: sing-box -c config.json -check${NC}"
    if /usr/local/bin/sing-box -c "$config_file" -check >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 更旧版本格式检查通过${NC}"
        return 0
    fi
    
    # 如果都不行，尝试手动启动测试（但立即停止）
    echo -e "${YELLOW}尝试: 手动启动测试${NC}"
    timeout 2 /usr/local/bin/sing-box run -c "$config_file" >/dev/null 2>&1
    local exit_code=$?
    
    # 如果超时（退出码 124），说明配置文件可能是正确的
    if [[ $exit_code -eq 124 ]]; then
        echo -e "${GREEN}✓ 手动启动测试通过（超时退出，说明配置正确）${NC}"
        return 0
    fi
    
    echo -e "${RED}✗ 所有格式都检查失败${NC}"
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
        echo -e "${YELLOW}检测到旧版本 sing-box，尝试其他格式...${NC}"
        
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

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}              Sing-box 配置语法检查工具                   ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo

# 检查 sing-box 版本
echo -e "${YELLOW}1. 检查 sing-box 版本${NC}"
if [[ -f "/usr/local/bin/sing-box" ]]; then
    echo -e "${GREEN}✓ sing-box 二进制文件存在${NC}"
    echo -e "${BLUE}版本信息:${NC}"
    /usr/local/bin/sing-box version 2>&1 | head -3
else
    echo -e "${RED}✗ sing-box 二进制文件不存在${NC}"
    exit 1
fi

echo

# 检查配置文件
echo -e "${YELLOW}2. 检查配置文件${NC}"
if [[ -f "$CONFIG_FILE" ]]; then
    echo -e "${GREEN}✓ 配置文件存在: $CONFIG_FILE${NC}"
    
    # 文件大小
    local file_size=$(stat -c%s "$CONFIG_FILE" 2>/dev/null || stat -f%z "$CONFIG_FILE" 2>/dev/null || echo "unknown")
    echo -e "${BLUE}文件大小: $file_size 字节${NC}"
    
    # 文件权限
    local file_perms=$(stat -c%a "$CONFIG_FILE" 2>/dev/null || stat -f%A "$CONFIG_FILE" 2>/dev/null || echo "unknown")
    echo -e "${BLUE}文件权限: $file_perms${NC}"
else
    echo -e "${RED}✗ 配置文件不存在: $CONFIG_FILE${NC}"
    exit 1
fi

echo

# 检查 JSON 格式
echo -e "${YELLOW}3. 检查 JSON 格式${NC}"
if command -v jq >/dev/null 2>&1; then
    if jq empty "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓ JSON 格式正确${NC}"
    else
        echo -e "${RED}✗ JSON 格式错误${NC}"
        echo -e "${BLUE}JSON 错误详情:${NC}"
        jq empty "$CONFIG_FILE" 2>&1
    fi
else
    echo -e "${YELLOW}⚠ 未安装 jq，跳过 JSON 格式检查${NC}"
fi

echo

# 检查配置语法
echo -e "${YELLOW}4. 检查配置语法${NC}"
if check_config_syntax "$CONFIG_FILE"; then
    echo -e "${GREEN}✓ 配置文件语法检查通过${NC}"
else
    echo -e "${RED}✗ 配置文件语法检查失败${NC}"
    echo -e "${BLUE}详细错误信息:${NC}"
    get_config_error "$CONFIG_FILE"
fi

echo
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                    检查完成                            ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
