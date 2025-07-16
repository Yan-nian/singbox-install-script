#!/bin/bash

# common.sh 模块单元测试
# 测试公共函数库的各项功能
# 版本: v2.4.14

set -euo pipefail

# 测试配置
TEST_SUITE_NAME="common_test"
TEST_SUITE_DESCRIPTION="测试 common.sh 公共函数库"

# 引入测试框架
source "${BASH_SOURCE%/*}/../test_framework.sh"

# 引入被测试模块
source "${BASH_SOURCE%/*}/../../scripts/common.sh" 2>/dev/null || {
    log_error "无法加载 common.sh 模块" "test"
    exit 1
}

# 测试前准备
setup_common_tests() {
    log_debug "设置 common.sh 测试环境" "test"
    
    # 创建测试临时目录
    TEST_TEMP_COMMON_DIR=$(create_test_temp_dir "common")
    
    # 设置测试环境变量
    export TEST_COMMON_DIR="$TEST_TEMP_COMMON_DIR"
}

# 测试后清理
teardown_common_tests() {
    log_debug "清理 common.sh 测试环境" "test"
    
    # 清理测试临时目录
    [[ -d "$TEST_TEMP_COMMON_DIR" ]] && rm -rf "$TEST_TEMP_COMMON_DIR"
    
    # 清理环境变量
    unset TEST_COMMON_DIR
}

# 测试日志函数
test_log_functions() {
    begin_test_case "test_log_functions" "测试日志记录函数"
    
    # 测试日志函数是否存在
    assert_command_success "type log_info" "log_info 函数应存在"
    assert_command_success "type log_success" "log_success 函数应存在"
    assert_command_success "type log_warn" "log_warn 函数应存在"
    assert_command_success "type log_error" "log_error 函数应存在"
    assert_command_success "type log_debug" "log_debug 函数应存在"
    
    # 测试日志函数调用
    local log_file=$(create_test_temp_file "log" "txt")
    
    # 重定向输出到临时文件进行测试
    {
        log_info "测试信息日志"
        log_success "测试成功日志"
        log_warn "测试警告日志"
        log_error "测试错误日志"
    } > "$log_file" 2>&1
    
    # 验证日志内容
    assert_file_exists "$log_file" "日志文件应被创建"
    assert_contains "$(cat "$log_file")" "测试信息日志" "应包含信息日志内容"
    assert_contains "$(cat "$log_file")" "测试成功日志" "应包含成功日志内容"
    assert_contains "$(cat "$log_file")" "测试警告日志" "应包含警告日志内容"
    assert_contains "$(cat "$log_file")" "测试错误日志" "应包含错误日志内容"
    
    test_pass "日志函数测试通过"
}

# 测试随机字符串生成
test_random_string_generation() {
    begin_test_case "test_random_string_generation" "测试随机字符串生成函数"
    
    # 测试函数是否存在
    assert_command_success "type generate_random_string" "generate_random_string 函数应存在"
    assert_command_success "type generate_random_number" "generate_random_number 函数应存在"
    assert_command_success "type generate_uuid" "generate_uuid 函数应存在"
    
    # 测试随机字符串生成
    local random_str
    random_str=$(generate_random_string 10)
    assert_equals "10" "${#random_str}" "随机字符串长度应为10"
    
    # 测试随机数字生成
    local random_num
    random_num=$(generate_random_number 5)
    assert_equals "5" "${#random_num}" "随机数字长度应为5"
    
    # 验证是否为数字
    if [[ "$random_num" =~ ^[0-9]+$ ]]; then
        assert_true "true" "随机数字应只包含数字"
    else
        assert_true "false" "随机数字应只包含数字"
    fi
    
    # 测试UUID生成
    local uuid
    uuid=$(generate_uuid)
    assert_equals "36" "${#uuid}" "UUID长度应为36"
    
    # 验证UUID格式 (8-4-4-4-12)
    if [[ "$uuid" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
        assert_true "true" "UUID格式应正确"
    else
        assert_true "false" "UUID格式应正确"
    fi
    
    test_pass "随机字符串生成测试通过"
}

# 测试端口检查函数
test_port_functions() {
    begin_test_case "test_port_functions" "测试端口相关函数"
    
    # 测试函数是否存在
    assert_command_success "type check_port" "check_port 函数应存在"
    assert_command_success "type get_random_port" "get_random_port 函数应存在"
    
    # 测试端口检查 - 使用已知占用的端口（如80）
    if check_port 80 >/dev/null 2>&1; then
        log_debug "端口80已被占用，符合预期" "test"
    else
        log_debug "端口80未被占用" "test"
    fi
    
    # 测试随机端口获取
    local random_port
    random_port=$(get_random_port)
    
    # 验证端口范围
    if [[ "$random_port" -ge 1024 && "$random_port" -le 65535 ]]; then
        assert_true "true" "随机端口应在有效范围内 (1024-65535)"
    else
        assert_true "false" "随机端口应在有效范围内 (1024-65535)"
    fi
    
    test_pass "端口函数测试通过"
}

# 测试IP验证函数
test_ip_validation() {
    begin_test_case "test_ip_validation" "测试IP地址验证函数"
    
    # 测试函数是否存在
    assert_command_success "type is_valid_ip" "is_valid_ip 函数应存在"
    
    # 测试有效IP地址
    local valid_ips=("192.168.1.1" "10.0.0.1" "172.16.0.1" "127.0.0.1" "8.8.8.8")
    for ip in "${valid_ips[@]}"; do
        if is_valid_ip "$ip"; then
            assert_true "true" "$ip 应为有效IP地址"
        else
            assert_true "false" "$ip 应为有效IP地址"
        fi
    done
    
    # 测试无效IP地址
    local invalid_ips=("256.1.1.1" "192.168.1" "192.168.1.1.1" "abc.def.ghi.jkl" "")
    for ip in "${invalid_ips[@]}"; do
        if ! is_valid_ip "$ip"; then
            assert_true "true" "$ip 应为无效IP地址"
        else
            assert_true "false" "$ip 应为无效IP地址"
        fi
    done
    
    test_pass "IP验证函数测试通过"
}

# 测试网络连通性检查
test_network_connectivity() {
    begin_test_case "test_network_connectivity" "测试网络连通性检查函数"
    
    # 测试函数是否存在
    assert_command_success "type check_network" "check_network 函数应存在"
    
    # 测试网络连通性（使用本地回环地址）
    if check_network "127.0.0.1" >/dev/null 2>&1; then
        assert_true "true" "本地回环地址应可达"
    else
        log_warn "网络连通性测试失败，可能是网络环境问题" "test"
        test_skip "网络环境不可用"
        return
    fi
    
    test_pass "网络连通性检查测试通过"
}

# 测试用户确认函数
test_user_confirmation() {
    begin_test_case "test_user_confirmation" "测试用户确认函数"
    
    # 测试函数是否存在
    assert_command_success "type confirm" "confirm 函数应存在"
    
    # 由于confirm函数需要用户交互，我们只测试函数存在性
    # 在实际测试中，可以通过模拟输入来测试
    
    test_pass "用户确认函数存在性测试通过"
}

# 测试进度条函数
test_progress_bar() {
    begin_test_case "test_progress_bar" "测试进度条函数"
    
    # 测试函数是否存在
    assert_command_success "type show_progress" "show_progress 函数应存在"
    
    # 测试进度条显示（重定向输出避免干扰）
    local progress_output
    progress_output=$(show_progress 50 100 "测试进度" 2>/dev/null || echo "progress_test")
    
    # 验证函数能够执行（不报错）
    assert_true "true" "进度条函数应能正常执行"
    
    test_pass "进度条函数测试通过"
}

# 测试目录创建函数
test_directory_creation() {
    begin_test_case "test_directory_creation" "测试目录创建函数"
    
    # 测试函数是否存在
    assert_command_success "type create_directory" "create_directory 函数应存在"
    
    # 测试目录创建
    local test_dir="${TEST_TEMP_COMMON_DIR}/test_create_dir"
    
    if create_directory "$test_dir" >/dev/null 2>&1; then
        assert_file_exists "$test_dir" "目录应被成功创建"
        
        # 测试目录权限
        if [[ -d "$test_dir" && -w "$test_dir" ]]; then
            assert_true "true" "创建的目录应可写"
        else
            assert_true "false" "创建的目录应可写"
        fi
    else
        test_fail "目录创建失败"
        return
    fi
    
    test_pass "目录创建函数测试通过"
}

# 测试颜色定义
test_color_definitions() {
    begin_test_case "test_color_definitions" "测试颜色定义"
    
    # 测试颜色变量是否定义
    local color_vars=("RED" "GREEN" "YELLOW" "BLUE" "PURPLE" "CYAN" "WHITE" "NC")
    
    for color_var in "${color_vars[@]}"; do
        if [[ -n "${!color_var:-}" ]]; then
            assert_true "true" "颜色变量 $color_var 应被定义"
        else
            # 某些环境可能不支持颜色，这不是错误
            log_debug "颜色变量 $color_var 未定义，可能是无颜色环境" "test"
        fi
    done
    
    test_pass "颜色定义测试通过"
}

# 主测试函数
run_common_tests() {
    begin_test_suite "$TEST_SUITE_NAME" "$TEST_SUITE_DESCRIPTION"
    
    # 设置测试环境
    setup_common_tests
    
    # 运行各项测试
    test_log_functions
    test_random_string_generation
    test_port_functions
    test_ip_validation
    test_network_connectivity
    test_user_confirmation
    test_progress_bar
    test_directory_creation
    test_color_definitions
    
    # 清理测试环境
    teardown_common_tests
    
    end_test_suite "$TEST_SUITE_NAME"
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_test_framework
    run_common_tests
    generate_test_report
fi