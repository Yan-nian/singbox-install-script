#!/bin/bash

# Sing-box 服务修复脚本
# 专门用于解决服务启动失败问题

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
SERVICE_FILE="/etc/systemd/system/sing-box.service"

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}                 Sing-box 服务修复工具                    ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo

# 修复函数
fix_permissions() {
    echo -e "${YELLOW}修复文件权限...${NC}"
    
    # 修复配置文件权限
    if [[ -f "$CONFIG_FILE" ]]; then
        chmod 644 "$CONFIG_FILE"
        chown root:root "$CONFIG_FILE"
        echo -e "  ${GREEN}✓ 配置文件权限已修复${NC}"
    fi
    
    # 修复二进制文件权限
    if [[ -f "/usr/local/bin/sing-box" ]]; then
        chmod 755 "/usr/local/bin/sing-box"
        chown root:root "/usr/local/bin/sing-box"
        echo -e "  ${GREEN}✓ 二进制文件权限已修复${NC}"
    fi
    
    # 修复目录权限
    if [[ -d "/etc/sing-box" ]]; then
        chmod 755 "/etc/sing-box"
        chown root:root "/etc/sing-box"
        echo -e "  ${GREEN}✓ 配置目录权限已修复${NC}"
    fi
}

recreate_service() {
    echo -e "${YELLOW}重新创建服务文件...${NC}"
    
    cat > "$SERVICE_FILE" << 'EOF'
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target network-online.target nss-lookup.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
ExecReload=/bin/kill -HUP $MAINPID
LimitNOFILE=infinity
Restart=on-failure
RestartSec=5
TimeoutStartSec=infinity
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    echo -e "  ${GREEN}✓ 服务文件已重新创建${NC}"
    
    # 重新加载 systemd
    systemctl daemon-reload
    systemctl enable sing-box
    echo -e "  ${GREEN}✓ 服务已重新启用${NC}"
}

check_config_syntax_interactive() {
    echo -e "${YELLOW}检查配置文件语法...${NC}"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "  ${RED}✗ 配置文件不存在${NC}"
        return 1
    fi
    
    if check_config_syntax "$CONFIG_FILE"; then
        echo -e "  ${GREEN}✓ 配置文件语法正确${NC}"
        return 0
    else
        echo -e "  ${RED}✗ 配置文件语法错误${NC}"
        echo -e "  ${BLUE}详细错误:${NC}"
        get_config_error "$CONFIG_FILE"
        return 1
    fi
}

create_backup_config() {
    echo -e "${YELLOW}创建备用配置文件...${NC}"
    
    # 创建一个最基本的配置文件
    cat > "$CONFIG_FILE" << 'EOF'
{
    "log": {
        "level": "info",
        "timestamp": true
    },
    "inbounds": [
        {
            "type": "direct",
            "tag": "direct-in",
            "listen": "127.0.0.1",
            "listen_port": 8080
        }
    ],
    "outbounds": [
        {
            "type": "direct",
            "tag": "direct"
        }
    ],
    "route": {
        "rules": [
            {
                "outbound": "direct"
            }
        ]
    }
}
EOF
    
    echo -e "  ${GREEN}✓ 备用配置文件已创建${NC}"
}

kill_conflicting_processes() {
    echo -e "${YELLOW}检查并终止冲突进程...${NC}"
    
    # 查找可能的冲突进程
    local sing_box_pids=$(pgrep -f "sing-box")
    if [[ -n "$sing_box_pids" ]]; then
        echo -e "  ${BLUE}发现 sing-box 进程: $sing_box_pids${NC}"
        kill -9 $sing_box_pids 2>/dev/null
        echo -e "  ${GREEN}✓ 已终止冲突进程${NC}"
    else
        echo -e "  ${GREEN}✓ 未发现冲突进程${NC}"
    fi
}

# 主修复流程
echo -e "${BLUE}开始修复流程...${NC}"
echo

# 1. 停止服务
echo -e "${YELLOW}1. 停止服务${NC}"
systemctl stop sing-box
kill_conflicting_processes

# 2. 修复权限
echo -e "${YELLOW}2. 修复权限${NC}"
fix_permissions

# 3. 重新创建服务
echo -e "${YELLOW}3. 重新创建服务${NC}"
recreate_service

# 4. 检查配置文件
echo -e "${YELLOW}4. 检查配置文件${NC}"
if ! check_config_syntax_interactive; then
    echo -e "${YELLOW}配置文件有问题，创建备用配置...${NC}"
    create_backup_config
fi

# 5. 尝试启动服务
echo -e "${YELLOW}5. 尝试启动服务${NC}"
if systemctl start sing-box; then
    echo -e "  ${GREEN}✓ 服务启动成功${NC}"
    
    # 检查服务状态
    sleep 2
    if systemctl is-active --quiet sing-box; then
        echo -e "  ${GREEN}✓ 服务运行正常${NC}"
    else
        echo -e "  ${RED}✗ 服务启动后异常${NC}"
        echo -e "  ${BLUE}详细状态:${NC}"
        systemctl status sing-box --no-pager -l
    fi
else
    echo -e "  ${RED}✗ 服务启动失败${NC}"
    echo -e "  ${BLUE}详细错误:${NC}"
    systemctl status sing-box --no-pager -l
fi

echo -e "\n${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}                      修复完成                            ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"

# 最终状态检查
echo -e "\n${YELLOW}最终状态检查:${NC}"
if systemctl is-active --quiet sing-box; then
    echo -e "  ${GREEN}✓ Sing-box 服务运行正常${NC}"
    echo -e "  ${BLUE}服务状态:${NC}"
    systemctl status sing-box --no-pager -l | head -5
else
    echo -e "  ${RED}✗ Sing-box 服务仍未正常运行${NC}"
    echo -e "  ${BLUE}建议:${NC}"
    echo -e "    1. 检查配置文件: /usr/local/bin/sing-box check -c $CONFIG_FILE"
    echo -e "    2. 查看详细日志: journalctl -u sing-box -f"
    echo -e "    3. 手动测试启动: /usr/local/bin/sing-box run -c $CONFIG_FILE"
fi
