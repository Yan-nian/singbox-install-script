#!/bin/bash

# 代码质量改进测试脚本
# 版本: v2.4.3
# 用途: 测试新增的错误处理、日志、验证和配置管理功能

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 测试计数器
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# 测试结果记录
test_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    ((TEST_COUNT++))
    
    if [[ "$result" == "PASS" ]]; then
        echo -e "${GREEN}[PASS]${NC} $test_name: $message"
        ((PASS_COUNT++))
    else
        echo -e "${RED}[FAIL]${NC} $test_name: $message"
        ((FAIL_COUNT++))
    fi
}

# 测试错误处理模块
test_error_handler() {
    echo -e "\n${CYAN}=== 测试错误处理模块 ===${NC}"
    
    local lib_dir="$(dirname "$0")/lib"
    
    # 测试模块加载
    if [[ -f "$lib_dir/error_handler.sh" ]]; then
        source "$lib_dir/error_handler.sh"
        test_result "错误处理模块加载" "PASS" "模块文件存在并成功加载"
    else
        test_result "错误处理模块加载" "FAIL" "模块文件不存在"
        return 1
    fi
    
    # 测试错误代码定义
    if [[ -n "${ERROR_CODES[CONFIG_NOT_FOUND]:-}" ]]; then
        test_result "错误代码定义" "PASS" "错误代码数组正确定义"
    else
        test_result "错误代码定义" "FAIL" "错误代码数组未定义"
    fi
    
    # 测试错误处理函数
    if command -v handle_error >/dev/null 2>&1; then
        test_result "错误处理函数" "PASS" "handle_error函数可用"
    else
        test_result "错误处理函数" "FAIL" "handle_error函数不可用"
    fi
    
    # 测试错误查询功能
    if command -v get_error_message >/dev/null 2>&1; then
        local msg=$(get_error_message "CONFIG_NOT_FOUND")
        if [[ -n "$msg" ]]; then
            test_result "错误查询功能" "PASS" "成功获取错误消息: $msg"
        else
            test_result "错误查询功能" "FAIL" "无法获取错误消息"
        fi
    else
        test_result "错误查询功能" "FAIL" "get_error_message函数不可用"
    fi
}

# 测试日志模块
test_logger() {
    echo -e "\n${CYAN}=== 测试日志模块 ===${NC}"
    
    local lib_dir="$(dirname "$0")/lib"
    
    # 测试模块加载
    if [[ -f "$lib_dir/logger.sh" ]]; then
        source "$lib_dir/logger.sh"
        test_result "日志模块加载" "PASS" "模块文件存在并成功加载"
    else
        test_result "日志模块加载" "FAIL" "模块文件不存在"
        return 1
    fi
    
    # 测试日志初始化
    if command -v init_logger >/dev/null 2>&1; then
        init_logger
        test_result "日志初始化" "PASS" "日志系统初始化成功"
    else
        test_result "日志初始化" "FAIL" "init_logger函数不可用"
    fi
    
    # 测试日志函数
    local log_functions=("log_debug" "log_info" "log_warn" "log_error" "log_fatal")
    for func in "${log_functions[@]}"; do
        if command -v "$func" >/dev/null 2>&1; then
            test_result "日志函数-$func" "PASS" "$func函数可用"
        else
            test_result "日志函数-$func" "FAIL" "$func函数不可用"
        fi
    done
    
    # 测试日志文件创建
    if [[ -n "${LOG_FILE:-}" ]] && [[ -f "$LOG_FILE" ]]; then
        test_result "日志文件创建" "PASS" "日志文件已创建: $LOG_FILE"
    else
        test_result "日志文件创建" "FAIL" "日志文件未创建"
    fi
}

# 测试验证模块
test_validator() {
    echo -e "\n${CYAN}=== 测试验证模块 ===${NC}"
    
    local lib_dir="$(dirname "$0")/lib"
    
    # 测试模块加载
    if [[ -f "$lib_dir/validator.sh" ]]; then
        source "$lib_dir/validator.sh"
        test_result "验证模块加载" "PASS" "模块文件存在并成功加载"
    else
        test_result "验证模块加载" "FAIL" "模块文件不存在"
        return 1
    fi
    
    # 测试端口验证
    if command -v validate_port >/dev/null 2>&1; then
        if validate_port "8080"; then
            test_result "端口验证-有效" "PASS" "端口8080验证通过"
        else
            test_result "端口验证-有效" "FAIL" "端口8080验证失败"
        fi
        
        if ! validate_port "99999"; then
            test_result "端口验证-无效" "PASS" "无效端口99999正确拒绝"
        else
            test_result "端口验证-无效" "FAIL" "无效端口99999未被拒绝"
        fi
    else
        test_result "端口验证函数" "FAIL" "validate_port函数不可用"
    fi
    
    # 测试域名验证
    if command -v validate_domain >/dev/null 2>&1; then
        if validate_domain "example.com"; then
            test_result "域名验证-有效" "PASS" "域名example.com验证通过"
        else
            test_result "域名验证-有效" "FAIL" "域名example.com验证失败"
        fi
        
        if ! validate_domain "invalid..domain"; then
            test_result "域名验证-无效" "PASS" "无效域名正确拒绝"
        else
            test_result "域名验证-无效" "FAIL" "无效域名未被拒绝"
        fi
    else
        test_result "域名验证函数" "FAIL" "validate_domain函数不可用"
    fi
    
    # 测试UUID验证
    if command -v validate_uuid >/dev/null 2>&1; then
        local valid_uuid="550e8400-e29b-41d4-a716-446655440000"
        if validate_uuid "$valid_uuid"; then
            test_result "UUID验证-有效" "PASS" "有效UUID验证通过"
        else
            test_result "UUID验证-有效" "FAIL" "有效UUID验证失败"
        fi
        
        if ! validate_uuid "invalid-uuid"; then
            test_result "UUID验证-无效" "PASS" "无效UUID正确拒绝"
        else
            test_result "UUID验证-无效" "FAIL" "无效UUID未被拒绝"
        fi
    else
        test_result "UUID验证函数" "FAIL" "validate_uuid函数不可用"
    fi
}

# 测试配置管理模块
test_config_manager() {
    echo -e "\n${CYAN}=== 测试配置管理模块 ===${NC}"
    
    local lib_dir="$(dirname "$0")/lib"
    
    # 测试模块加载
    if [[ -f "$lib_dir/config_manager.sh" ]]; then
        source "$lib_dir/config_manager.sh"
        test_result "配置管理模块加载" "PASS" "模块文件存在并成功加载"
    else
        test_result "配置管理模块加载" "FAIL" "模块文件不存在"
        return 1
    fi
    
    # 测试配置函数
    local config_functions=("init_config_vars" "load_config" "save_config" "get_config_status" "auto_load_config")
    for func in "${config_functions[@]}"; do
        if command -v "$func" >/dev/null 2>&1; then
            test_result "配置函数-$func" "PASS" "$func函数可用"
        else
            test_result "配置函数-$func" "FAIL" "$func函数不可用"
        fi
    done
    
    # 测试配置变量初始化
    if command -v init_config_vars >/dev/null 2>&1; then
        init_config_vars
        if [[ -n "${VLESS_PORT:-}" ]] || [[ -n "${VMESS_PORT:-}" ]] || [[ -n "${HY2_PORT:-}" ]]; then
            test_result "配置变量初始化" "PASS" "配置变量已初始化"
        else
            test_result "配置变量初始化" "FAIL" "配置变量未正确初始化"
        fi
    fi
    
    # 测试缓存功能
    if command -v save_config_to_cache >/dev/null 2>&1 && command -v load_config_from_cache >/dev/null 2>&1; then
        test_result "配置缓存功能" "PASS" "配置缓存函数可用"
    else
        test_result "配置缓存功能" "FAIL" "配置缓存函数不可用"
    fi
}

# 测试模块集成
test_integration() {
    echo -e "\n${CYAN}=== 测试模块集成 ===${NC}"
    
    # 测试主脚本
    local main_script="$(dirname "$0")/singbox-install.sh"
    if [[ -f "$main_script" ]]; then
        test_result "主脚本存在" "PASS" "主脚本文件存在"
        
        # 检查load_modules函数是否包含新模块
        if grep -q "error_handler.sh" "$main_script" && grep -q "logger.sh" "$main_script" && grep -q "validator.sh" "$main_script"; then
            test_result "模块集成" "PASS" "主脚本已集成新模块"
        else
            test_result "模块集成" "FAIL" "主脚本未正确集成新模块"
        fi
        
        # 检查auto_load_config调用
        if grep -q "auto_load_config" "$main_script"; then
            test_result "自动配置加载" "PASS" "主脚本包含自动配置加载"
        else
            test_result "自动配置加载" "FAIL" "主脚本缺少自动配置加载"
        fi
    else
        test_result "主脚本存在" "FAIL" "主脚本文件不存在"
    fi
}

# 主测试函数
main() {
    echo -e "${BLUE}代码质量改进测试开始${NC}"
    echo -e "${BLUE}测试时间: $(date)${NC}"
    echo -e "${BLUE}测试版本: v2.4.3${NC}"
    
    # 运行所有测试
    test_error_handler
    test_logger
    test_validator
    test_config_manager
    test_integration
    
    # 显示测试结果
    echo -e "\n${BLUE}=== 测试结果汇总 ===${NC}"
    echo -e "总测试数: $TEST_COUNT"
    echo -e "${GREEN}通过: $PASS_COUNT${NC}"
    echo -e "${RED}失败: $FAIL_COUNT${NC}"
    
    if [[ $FAIL_COUNT -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 所有测试通过！代码质量改进实施成功。${NC}"
        exit 0
    else
        echo -e "\n${RED}❌ 有 $FAIL_COUNT 个测试失败，请检查相关模块。${NC}"
        exit 1
    fi
}

# 运行测试
main "$@"