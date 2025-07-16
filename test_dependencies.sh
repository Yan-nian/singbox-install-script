#!/bin/bash

# 依赖测试脚本
# 用于验证 Sing-box 安装脚本的依赖管理功能

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Sing-box 依赖测试脚本 ===${NC}"
echo ""

# 定义需要测试的依赖
REQUIRED_DEPS=("curl" "wget" "jq" "openssl" "tar" "unzip")
OPTIONAL_DEPS=("qrencode" "uuidgen" "netstat" "pgrep" "systemctl")
BASIC_TOOLS=("grep" "awk" "sed" "cut" "date" "free" "df")

# 测试函数
test_command() {
    local cmd="$1"
    local desc="$2"
    
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $cmd${NC} - $desc"
        return 0
    else
        echo -e "${RED}❌ $cmd${NC} - $desc"
        return 1
    fi
}

# 测试 JSON 处理功能
test_json_processing() {
    echo -e "\n${CYAN}测试 JSON 处理功能:${NC}"
    
    if command -v jq >/dev/null 2>&1; then
        # 创建测试 JSON
        local test_json='{"name":"test","port":8080,"enabled":true}'
        
        # 测试 jq 基本功能
        local name=$(echo "$test_json" | jq -r '.name' 2>/dev/null)
        local port=$(echo "$test_json" | jq -r '.port' 2>/dev/null)
        
        if [[ "$name" == "test" && "$port" == "8080" ]]; then
            echo -e "${GREEN}✅ JSON 解析功能正常${NC}"
        else
            echo -e "${RED}❌ JSON 解析功能异常${NC}"
        fi
    else
        echo -e "${RED}❌ jq 未安装，无法测试 JSON 处理${NC}"
    fi
}

# 测试网络功能
test_network_functions() {
    echo -e "\n${CYAN}测试网络功能:${NC}"
    
    # 测试 curl
    if command -v curl >/dev/null 2>&1; then
        if curl -s --max-time 5 https://httpbin.org/ip >/dev/null 2>&1; then
            echo -e "${GREEN}✅ curl 网络请求功能正常${NC}"
        else
            echo -e "${YELLOW}⚠️  curl 网络请求可能受限${NC}"
        fi
    fi
    
    # 测试 wget
    if command -v wget >/dev/null 2>&1; then
        if wget -q --timeout=5 --spider https://httpbin.org/ip 2>/dev/null; then
            echo -e "${GREEN}✅ wget 网络请求功能正常${NC}"
        else
            echo -e "${YELLOW}⚠️  wget 网络请求可能受限${NC}"
        fi
    fi
}

# 测试加密功能
test_crypto_functions() {
    echo -e "\n${CYAN}测试加密功能:${NC}"
    
    if command -v openssl >/dev/null 2>&1; then
        # 测试随机数生成
        local random_hex=$(openssl rand -hex 8 2>/dev/null)
        if [[ ${#random_hex} -eq 16 ]]; then
            echo -e "${GREEN}✅ OpenSSL 随机数生成功能正常${NC}"
        else
            echo -e "${RED}❌ OpenSSL 随机数生成功能异常${NC}"
        fi
        
        # 测试 Base64 编码
        local test_string="Hello World"
        local encoded=$(echo -n "$test_string" | openssl base64 2>/dev/null)
        local decoded=$(echo "$encoded" | openssl base64 -d 2>/dev/null)
        
        if [[ "$decoded" == "$test_string" ]]; then
            echo -e "${GREEN}✅ Base64 编码解码功能正常${NC}"
        else
            echo -e "${RED}❌ Base64 编码解码功能异常${NC}"
        fi
    fi
}

# 测试文件处理功能
test_file_processing() {
    echo -e "\n${CYAN}测试文件处理功能:${NC}"
    
    # 创建临时测试文件
    local temp_file="/tmp/singbox_test_$(date +%s).txt"
    echo -e "line1\nline2\nline3" > "$temp_file"
    
    # 测试 tar
    if command -v tar >/dev/null 2>&1; then
        local tar_file="/tmp/test_$(date +%s).tar.gz"
        if tar -czf "$tar_file" "$temp_file" 2>/dev/null && tar -tzf "$tar_file" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ tar 压缩解压功能正常${NC}"
            rm -f "$tar_file"
        else
            echo -e "${RED}❌ tar 压缩解压功能异常${NC}"
        fi
    fi
    
    # 测试文本处理工具
    if command -v grep >/dev/null 2>&1 && command -v awk >/dev/null 2>&1; then
        local line_count=$(grep -c "line" "$temp_file" 2>/dev/null)
        local first_line=$(awk 'NR==1' "$temp_file" 2>/dev/null)
        
        if [[ "$line_count" == "3" && "$first_line" == "line1" ]]; then
            echo -e "${GREEN}✅ 文本处理工具功能正常${NC}"
        else
            echo -e "${RED}❌ 文本处理工具功能异常${NC}"
        fi
    fi
    
    # 清理测试文件
    rm -f "$temp_file"
}

# 主测试流程
main() {
    echo -e "${CYAN}检查必需依赖:${NC}"
    local missing_required=0
    for dep in "${REQUIRED_DEPS[@]}"; do
        case $dep in
            "curl") test_command "$dep" "HTTP 客户端，用于 API 请求和文件下载" || ((missing_required++)) ;;
            "wget") test_command "$dep" "备用下载工具" || ((missing_required++)) ;;
            "jq") test_command "$dep" "JSON 解析器，用于配置文件处理" || ((missing_required++)) ;;
            "openssl") test_command "$dep" "加密工具，用于证书和密钥生成" || ((missing_required++)) ;;
            "tar") test_command "$dep" "压缩工具，用于解压 Sing-box 安装包" || ((missing_required++)) ;;
            "unzip") test_command "$dep" "解压工具，用于处理 ZIP 文件" || ((missing_required++)) ;;
        esac
    done
    
    echo -e "\n${CYAN}检查可选依赖:${NC}"
    local missing_optional=0
    for dep in "${OPTIONAL_DEPS[@]}"; do
        case $dep in
            "qrencode") test_command "$dep" "二维码生成器" || ((missing_optional++)) ;;
            "uuidgen") test_command "$dep" "UUID 生成器" || ((missing_optional++)) ;;
            "netstat") test_command "$dep" "网络状态查看工具" || ((missing_optional++)) ;;
            "pgrep") test_command "$dep" "进程查找工具" || ((missing_optional++)) ;;
            "systemctl") test_command "$dep" "系统服务管理工具" || ((missing_optional++)) ;;
        esac
    done
    
    echo -e "\n${CYAN}检查基础工具:${NC}"
    local missing_basic=0
    for dep in "${BASIC_TOOLS[@]}"; do
        case $dep in
            "grep") test_command "$dep" "文本搜索工具" || ((missing_basic++)) ;;
            "awk") test_command "$dep" "文本处理工具" || ((missing_basic++)) ;;
            "sed") test_command "$dep" "流编辑器" || ((missing_basic++)) ;;
            "cut") test_command "$dep" "文本切割工具" || ((missing_basic++)) ;;
            "date") test_command "$dep" "日期时间工具" || ((missing_basic++)) ;;
            "free") test_command "$dep" "内存信息工具" || ((missing_basic++)) ;;
            "df") test_command "$dep" "磁盘信息工具" || ((missing_basic++)) ;;
        esac
    done
    
    # 功能测试
    test_json_processing
    test_network_functions
    test_crypto_functions
    test_file_processing
    
    # 总结报告
    echo -e "\n${CYAN}=== 测试总结 ===${NC}"
    echo -e "必需依赖缺失: ${RED}$missing_required${NC} / ${#REQUIRED_DEPS[@]}"
    echo -e "可选依赖缺失: ${YELLOW}$missing_optional${NC} / ${#OPTIONAL_DEPS[@]}"
    echo -e "基础工具缺失: ${YELLOW}$missing_basic${NC} / ${#BASIC_TOOLS[@]}"
    
    if [[ $missing_required -eq 0 ]]; then
        echo -e "\n${GREEN}✅ 所有必需依赖已安装，Sing-box 脚本可以正常运行${NC}"
        return 0
    else
        echo -e "\n${RED}❌ 存在缺失的必需依赖，请运行以下命令安装:${NC}"
        echo -e "${YELLOW}./singbox-install.sh --install${NC}"
        echo -e "${YELLOW}或手动安装缺失的依赖${NC}"
        return 1
    fi
}

# 运行测试
main "$@"