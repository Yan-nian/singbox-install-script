#!/bin/bash

# 快速交互式菜单测试

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 输出函数
warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# 修复后的 read_input 函数
read_input() {
    local prompt="$1"
    local default="$2"
    local input
    
    if [[ -n $default ]]; then
        echo -ne "${GREEN}$prompt${NC} [${YELLOW}$default${NC}]: "
    else
        echo -ne "${GREEN}$prompt${NC}: "
    fi
    
    read -r input
    # 去除前后空白字符并返回
    input="${input:-$default}"
    input="${input// /}"  # 移除所有空格
    printf "%s" "$input"
}

# 简化的主菜单
show_test_menu() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                              Sing-box 测试菜单                                  ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${GREEN}请选择操作：${NC}"
    echo
    echo -e "${YELLOW}  [1]${NC} 测试选项 1"
    echo -e "${YELLOW}  [2]${NC} 测试选项 2"
    echo -e "${YELLOW}  [3]${NC} 测试选项 3"
    echo -e "${YELLOW}  [0]${NC} 退出测试"
    echo
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────────────────────${NC}"
}

# 测试主循环
test_main() {
    while true; do
        show_test_menu
        local choice
        choice=$(read_input "请选择操作" "0")
        
        echo ""
        echo "DEBUG: 您输入的值: '$choice', 长度: ${#choice}"
        
        case "$choice" in
            "1")
                success "选项 1 匹配成功！"
                echo "这证明输入验证工作正常。"
                read -p "按回车继续..."
                ;;
            "2")
                success "选项 2 匹配成功！"
                echo "这证明输入验证工作正常。"
                read -p "按回车继续..."
                ;;
            "3")
                success "选项 3 匹配成功！"
                echo "这证明输入验证工作正常。"
                read -p "按回车继续..."
                ;;
            "0")
                success "退出测试"
                exit 0
                ;;
            *)
                warn "请输入有效的选项 (0-3)"
                sleep 1
                ;;
        esac
    done
}

echo "开始交互式菜单测试..."
sleep 1
test_main
