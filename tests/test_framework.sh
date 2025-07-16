#!/bin/bash

# 测试框架模块
# 提供单元测试、集成测试、端到端测试的基础框架
# 版本: v2.4.14

set -euo pipefail

# 测试框架信息
TEST_FRAMEWORK_VERSION="v2.4.14"
TEST_BASE_DIR="${BASH_SOURCE%/*}"
TEST_RESULTS_DIR="${TEST_BASE_DIR}/results"
TEST_REPORTS_DIR="${TEST_BASE_DIR}/reports"
TEST_TEMP_DIR="${TEST_BASE_DIR}/temp"

# 测试配置
TEST_TIMEOUT="${TEST_TIMEOUT:-300}"  # 5分钟
TEST_PARALLEL="${TEST_PARALLEL:-false}"
TEST_VERBOSE="${TEST_VERBOSE:-false}"
TEST_COVERAGE="${TEST_COVERAGE:-false}"
TEST_CLEANUP="${TEST_CLEANUP:-true}"

# 测试统计
declare -A TEST_STATS=(
    ["total"]="0"
    ["passed"]="0"
    ["failed"]="0"
    ["skipped"]="0"
    ["errors"]="0"
    ["start_time"]="0"
    ["end_time"]="0"
)

# 测试结果
declare -a TEST_RESULTS=()
declare -a FAILED_TESTS=()
declare -a ERROR_TESTS=()

# 当前测试信息
CURRENT_TEST_SUITE=""
CURRENT_TEST_CASE=""
CURRENT_TEST_START_TIME="0"

# 引入依赖模块
source "${BASH_SOURCE%/*}/../core/logger.sh" 2>/dev/null || {
    log_info() { echo "[INFO] $1"; }
    log_warn() { echo "[WARN] $1" >&2; }
    log_error() { echo "[ERROR] $1" >&2; }
    log_debug() { [[ "${DEBUG:-}" == "true" ]] && echo "[DEBUG] $1" >&2; }
}

# 初始化测试框架
init_test_framework() {
    log_info "初始化测试框架 (版本: $TEST_FRAMEWORK_VERSION)" "test"
    
    # 创建测试目录
    local dirs=("$TEST_RESULTS_DIR" "$TEST_REPORTS_DIR" "$TEST_TEMP_DIR")
    for dir in "${dirs[@]}"; do
        [[ ! -d "$dir" ]] && mkdir -p "$dir"
    done
    
    # 设置测试环境
    export TEST_ENV="true"
    export TEST_MODE="framework"
    
    # 记录测试开始时间
    TEST_STATS["start_time"]="$(date +%s)"
    
    # 设置信号处理
    trap 'cleanup_test_framework' EXIT
    trap 'handle_test_interrupt' INT TERM
    
    log_debug "测试框架初始化完成" "test"
}

# 清理测试框架
cleanup_test_framework() {
    if [[ "$TEST_CLEANUP" == "true" ]]; then
        log_debug "清理测试环境" "test"
        
        # 清理临时文件
        [[ -d "$TEST_TEMP_DIR" ]] && rm -rf "${TEST_TEMP_DIR:?}"/*
        
        # 恢复环境变量
        unset TEST_ENV TEST_MODE
    fi
}

# 处理测试中断
handle_test_interrupt() {
    log_warn "测试被中断" "test"
    
    # 记录中断的测试
    if [[ -n "$CURRENT_TEST_CASE" ]]; then
        test_error "测试被用户中断"
    fi
    
    # 生成报告
    generate_test_report
    
    exit 130
}

# 开始测试套件
begin_test_suite() {
    local suite_name="$1"
    local description="${2:-}"
    
    CURRENT_TEST_SUITE="$suite_name"
    
    log_info "开始测试套件: $suite_name" "test"
    [[ -n "$description" ]] && log_info "描述: $description" "test"
    
    # 创建套件结果目录
    local suite_dir="${TEST_RESULTS_DIR}/${suite_name}"
    [[ ! -d "$suite_dir" ]] && mkdir -p "$suite_dir"
}

# 结束测试套件
end_test_suite() {
    local suite_name="${1:-$CURRENT_TEST_SUITE}"
    
    log_info "结束测试套件: $suite_name" "test"
    
    CURRENT_TEST_SUITE=""
}

# 开始测试用例
begin_test_case() {
    local test_name="$1"
    local description="${2:-}"
    
    CURRENT_TEST_CASE="$test_name"
    CURRENT_TEST_START_TIME="$(date +%s%3N)"
    
    ((TEST_STATS["total"]++))
    
    if [[ "$TEST_VERBOSE" == "true" ]]; then
        log_info "开始测试: $test_name" "test"
        [[ -n "$description" ]] && log_info "描述: $description" "test"
    fi
}

# 结束测试用例
end_test_case() {
    local status="${1:-passed}"
    local message="${2:-}"
    
    local end_time="$(date +%s%3N)"
    local duration=$((end_time - CURRENT_TEST_START_TIME))
    
    # 记录测试结果
    local result="${CURRENT_TEST_SUITE}::${CURRENT_TEST_CASE}:${status}:${duration}ms"
    [[ -n "$message" ]] && result+=":$message"
    
    TEST_RESULTS+=("$result")
    
    # 更新统计
    case "$status" in
        "passed")
            ((TEST_STATS["passed"]++))
            if [[ "$TEST_VERBOSE" == "true" ]]; then
                echo "✓ $CURRENT_TEST_CASE (${duration}ms)"
            else
                echo -n "."
            fi
            ;;
        "failed")
            ((TEST_STATS["failed"]++))
            FAILED_TESTS+=("${CURRENT_TEST_SUITE}::${CURRENT_TEST_CASE}: $message")
            if [[ "$TEST_VERBOSE" == "true" ]]; then
                echo "✗ $CURRENT_TEST_CASE (${duration}ms) - $message"
            else
                echo -n "F"
            fi
            ;;
        "skipped")
            ((TEST_STATS["skipped"]++))
            if [[ "$TEST_VERBOSE" == "true" ]]; then
                echo "- $CURRENT_TEST_CASE (跳过) - $message"
            else
                echo -n "S"
            fi
            ;;
        "error")
            ((TEST_STATS["errors"]++))
            ERROR_TESTS+=("${CURRENT_TEST_SUITE}::${CURRENT_TEST_CASE}: $message")
            if [[ "$TEST_VERBOSE" == "true" ]]; then
                echo "E $CURRENT_TEST_CASE (${duration}ms) - $message"
            else
                echo -n "E"
            fi
            ;;
    esac
    
    CURRENT_TEST_CASE=""
    CURRENT_TEST_START_TIME="0"
}

# 测试断言函数
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-断言失败: 期望 '$expected', 实际 '$actual'}"
    
    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        test_fail "$message"
        return 1
    fi
}

assert_not_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-断言失败: 不应该等于 '$expected'}"
    
    if [[ "$expected" != "$actual" ]]; then
        return 0
    else
        test_fail "$message"
        return 1
    fi
}

assert_true() {
    local condition="$1"
    local message="${2:-断言失败: 条件应为真}"
    
    if [[ "$condition" == "true" ]] || [[ "$condition" == "0" ]]; then
        return 0
    else
        test_fail "$message"
        return 1
    fi
}

assert_false() {
    local condition="$1"
    local message="${2:-断言失败: 条件应为假}"
    
    if [[ "$condition" == "false" ]] || [[ "$condition" != "0" ]]; then
        return 0
    else
        test_fail "$message"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-断言失败: '$haystack' 应包含 '$needle'}"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        return 0
    else
        test_fail "$message"
        return 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-断言失败: '$haystack' 不应包含 '$needle'}"
    
    if [[ "$haystack" != *"$needle"* ]]; then
        return 0
    else
        test_fail "$message"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-断言失败: 文件 '$file' 应存在}"
    
    if [[ -f "$file" ]]; then
        return 0
    else
        test_fail "$message"
        return 1
    fi
}

assert_file_not_exists() {
    local file="$1"
    local message="${2:-断言失败: 文件 '$file' 不应存在}"
    
    if [[ ! -f "$file" ]]; then
        return 0
    else
        test_fail "$message"
        return 1
    fi
}

assert_command_success() {
    local command="$1"
    local message="${2:-断言失败: 命令应成功执行: $command}"
    
    if eval "$command" >/dev/null 2>&1; then
        return 0
    else
        test_fail "$message"
        return 1
    fi
}

assert_command_failure() {
    local command="$1"
    local message="${2:-断言失败: 命令应执行失败: $command}"
    
    if ! eval "$command" >/dev/null 2>&1; then
        return 0
    else
        test_fail "$message"
        return 1
    fi
}

# 测试结果函数
test_pass() {
    local message="${1:-}"
    end_test_case "passed" "$message"
}

test_fail() {
    local message="${1:-测试失败}"
    end_test_case "failed" "$message"
}

test_skip() {
    local message="${1:-测试跳过}"
    end_test_case "skipped" "$message"
}

test_error() {
    local message="${1:-测试错误}"
    end_test_case "error" "$message"
}

# 创建测试临时文件
create_test_temp_file() {
    local prefix="${1:-test}"
    local suffix="${2:-tmp}"
    
    local temp_file
    temp_file=$(mktemp "${TEST_TEMP_DIR}/${prefix}.XXXXXX.${suffix}")
    
    echo "$temp_file"
}

# 创建测试临时目录
create_test_temp_dir() {
    local prefix="${1:-test}"
    
    local temp_dir
    temp_dir=$(mktemp -d "${TEST_TEMP_DIR}/${prefix}.XXXXXX")
    
    echo "$temp_dir"
}

# 运行测试函数
run_test() {
    local test_function="$1"
    local test_name="${2:-$test_function}"
    local description="${3:-}"
    
    begin_test_case "$test_name" "$description"
    
    # 设置测试超时
    if command -v "timeout" >/dev/null 2>&1; then
        if timeout "$TEST_TIMEOUT" "$test_function" 2>/dev/null; then
            test_pass
        else
            local exit_code=$?
            if [[ $exit_code -eq 124 ]]; then
                test_error "测试超时 (${TEST_TIMEOUT}s)"
            else
                test_error "测试函数执行失败 (退出码: $exit_code)"
            fi
        fi
    else
        if "$test_function" 2>/dev/null; then
            test_pass
        else
            test_error "测试函数执行失败"
        fi
    fi
}

# 运行测试套件
run_test_suite() {
    local suite_file="$1"
    local suite_name="${2:-$(basename "$suite_file" .sh)}"
    
    if [[ ! -f "$suite_file" ]]; then
        log_error "测试套件文件不存在: $suite_file" "test"
        return 1
    fi
    
    log_info "运行测试套件: $suite_name" "test"
    
    begin_test_suite "$suite_name"
    
    # 执行测试套件
    if source "$suite_file"; then
        log_debug "测试套件执行完成: $suite_name" "test"
    else
        log_error "测试套件执行失败: $suite_name" "test"
    fi
    
    end_test_suite "$suite_name"
}

# 发现并运行测试
discover_and_run_tests() {
    local test_dir="${1:-$TEST_BASE_DIR}"
    local pattern="${2:-*_test.sh}"
    
    log_info "发现测试文件: $test_dir/$pattern" "test"
    
    local test_files
    test_files=$(find "$test_dir" -name "$pattern" -type f | sort)
    
    if [[ -z "$test_files" ]]; then
        log_warn "没有找到测试文件" "test"
        return 1
    fi
    
    local test_count
    test_count=$(echo "$test_files" | wc -l)
    log_info "找到 $test_count 个测试文件" "test"
    
    while IFS= read -r test_file; do
        run_test_suite "$test_file"
    done <<< "$test_files"
}

# 生成测试报告
generate_test_report() {
    TEST_STATS["end_time"]="$(date +%s)"
    local total_duration=$((TEST_STATS["end_time"] - TEST_STATS["start_time"]))
    
    local report_file="${TEST_REPORTS_DIR}/test_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== Sing-box 测试报告 ==="
        echo "生成时间: $(date)"
        echo "测试框架版本: $TEST_FRAMEWORK_VERSION"
        echo ""
        
        echo "=== 测试统计 ==="
        echo "总测试数: ${TEST_STATS["total"]}"
        echo "通过: ${TEST_STATS["passed"]}"
        echo "失败: ${TEST_STATS["failed"]}"
        echo "跳过: ${TEST_STATS["skipped"]}"
        echo "错误: ${TEST_STATS["errors"]}"
        echo "总耗时: ${total_duration}s"
        echo ""
        
        # 成功率计算
        if [[ ${TEST_STATS["total"]} -gt 0 ]]; then
            local success_rate=$(( (TEST_STATS["passed"] * 100) / TEST_STATS["total"] ))
            echo "成功率: ${success_rate}%"
        else
            echo "成功率: N/A"
        fi
        echo ""
        
        # 失败的测试
        if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
            echo "=== 失败的测试 ==="
            for failed_test in "${FAILED_TESTS[@]}"; do
                echo "✗ $failed_test"
            done
            echo ""
        fi
        
        # 错误的测试
        if [[ ${#ERROR_TESTS[@]} -gt 0 ]]; then
            echo "=== 错误的测试 ==="
            for error_test in "${ERROR_TESTS[@]}"; do
                echo "E $error_test"
            done
            echo ""
        fi
        
        # 详细结果
        echo "=== 详细结果 ==="
        for result in "${TEST_RESULTS[@]}"; do
            echo "$result"
        done
        
    } > "$report_file"
    
    log_info "测试报告已生成: $report_file" "test"
    
    # 控制台输出摘要
    echo ""
    echo "=== 测试摘要 ==="
    echo "总测试数: ${TEST_STATS["total"]}"
    echo "通过: ${TEST_STATS["passed"]}"
    echo "失败: ${TEST_STATS["failed"]}"
    echo "跳过: ${TEST_STATS["skipped"]}"
    echo "错误: ${TEST_STATS["errors"]}"
    echo "总耗时: ${total_duration}s"
    
    if [[ ${TEST_STATS["total"]} -gt 0 ]]; then
        local success_rate=$(( (TEST_STATS["passed"] * 100) / TEST_STATS["total"] ))
        echo "成功率: ${success_rate}%"
    fi
    
    echo "报告文件: $report_file"
}

# 显示测试统计
show_test_stats() {
    echo "=== 当前测试统计 ==="
    echo "总测试数: ${TEST_STATS["total"]}"
    echo "通过: ${TEST_STATS["passed"]}"
    echo "失败: ${TEST_STATS["failed"]}"
    echo "跳过: ${TEST_STATS["skipped"]}"
    echo "错误: ${TEST_STATS["errors"]}"
    
    if [[ ${TEST_STATS["start_time"]} -gt 0 ]]; then
        local current_time="$(date +%s)"
        local elapsed=$((current_time - TEST_STATS["start_time"]))
        echo "已用时间: ${elapsed}s"
    fi
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_test_framework
    
    case "${1:-discover}" in
        "discover")
            discover_and_run_tests "${2:-$TEST_BASE_DIR}" "${3:-*_test.sh}"
            ;;
        "run")
            run_test_suite "$2" "${3:-}"
            ;;
        "stats")
            show_test_stats
            ;;
        "report")
            generate_test_report
            ;;
        *)
            echo "用法: $0 [discover|run|stats|report] [参数...]"
            echo "  discover [目录] [模式] - 发现并运行测试"
            echo "  run <文件> [名称]     - 运行指定测试套件"
            echo "  stats                 - 显示测试统计"
            echo "  report                - 生成测试报告"
            exit 1
            ;;
    esac
    
    generate_test_report
fi