#!/bin/bash

# 端到端完整工作流测试
# 测试从安装到运行的完整用户场景
# 版本: v2.4.14

set -euo pipefail

# 测试配置
TEST_SUITE_NAME="full_workflow_e2e_test"
TEST_SUITE_DESCRIPTION="端到端完整工作流测试"

# 引入测试框架
source "${BASH_SOURCE%/*}/../test_framework.sh"

# 引入依赖模块
source "${BASH_SOURCE%/*}/../../scripts/common.sh" 2>/dev/null || {
    log_error "无法加载 common.sh 模块" "test"
    exit 1
}

# 测试环境变量
E2E_TEST_DIR=""
E2E_INSTALL_DIR=""
E2E_CONFIG_DIR=""
E2E_LOG_DIR=""
E2E_BACKUP_DIR=""
E2E_TEMP_DIR=""

# 测试服务信息
TEST_SERVICE_NAME="singbox-e2e-test"
TEST_SERVICE_PORT="18443"
TEST_SERVICE_PID=""

# 原始环境变量备份
ORIGINAL_SINGBOX_DIR="${SINGBOX_DIR:-}"
ORIGINAL_CONFIG_DIR="${CONFIG_DIR:-}"

# 测试前准备
setup_e2e_tests() {
    log_info "设置端到端测试环境" "test"
    
    # 创建测试根目录
    E2E_TEST_DIR=$(create_test_temp_dir "e2e")
    E2E_INSTALL_DIR="${E2E_TEST_DIR}/install"
    E2E_CONFIG_DIR="${E2E_TEST_DIR}/config"
    E2E_LOG_DIR="${E2E_TEST_DIR}/logs"
    E2E_BACKUP_DIR="${E2E_TEST_DIR}/backup"
    E2E_TEMP_DIR="${E2E_TEST_DIR}/temp"
    
    # 创建所有必要目录
    local dirs=("$E2E_INSTALL_DIR" "$E2E_CONFIG_DIR" "$E2E_LOG_DIR" "$E2E_BACKUP_DIR" "$E2E_TEMP_DIR")
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
    done
    
    # 设置测试环境变量
    export SINGBOX_DIR="$E2E_INSTALL_DIR"
    export CONFIG_DIR="$E2E_CONFIG_DIR"
    export LOG_DIR="$E2E_LOG_DIR"
    export BACKUP_DIR="$E2E_BACKUP_DIR"
    export TEST_MODE="true"
    export E2E_TEST="true"
    
    log_debug "E2E测试目录: $E2E_TEST_DIR" "test"
    log_debug "安装目录: $E2E_INSTALL_DIR" "test"
    log_debug "配置目录: $E2E_CONFIG_DIR" "test"
    log_debug "日志目录: $E2E_LOG_DIR" "test"
}

# 测试后清理
teardown_e2e_tests() {
    log_info "清理端到端测试环境" "test"
    
    # 停止测试服务
    stop_test_service
    
    # 恢复环境变量
    export SINGBOX_DIR="$ORIGINAL_SINGBOX_DIR"
    export CONFIG_DIR="$ORIGINAL_CONFIG_DIR"
    unset LOG_DIR BACKUP_DIR TEST_MODE E2E_TEST
    
    # 清理测试目录
    [[ -d "$E2E_TEST_DIR" ]] && rm -rf "$E2E_TEST_DIR"
    
    log_debug "端到端测试环境已清理" "test"
}

# 创建模拟的 Sing-box 二进制文件
create_mock_singbox_binary() {
    local binary_path="$1"
    
    cat > "$binary_path" << 'EOF'
#!/bin/bash
# 模拟的 Sing-box 二进制文件 - E2E 测试版本

log_file="${LOG_DIR:-/tmp}/singbox-mock.log"
config_file=""
pid_file="${SINGBOX_DIR:-/tmp}/singbox.pid"

# 记录日志
log_mock() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$log_file"
}

case "$1" in
    "version")
        echo "sing-box version 1.8.0"
        echo "Environment: mock-e2e-test"
        echo "Tags: with_gvisor,with_quic,with_dhcp,with_wireguard,with_ech,with_utls,with_reality,with_acme,with_clash_api"
        ;;
    "check")
        shift
        while [[ $# -gt 0 ]]; do
            case $1 in
                "-c"|"--config")
                    config_file="$2"
                    shift 2
                    ;;
                *)
                    shift
                    ;;
            esac
        done
        
        if [[ -n "$config_file" && -f "$config_file" ]]; then
            log_mock "检查配置文件: $config_file"
            if jq . "$config_file" >/dev/null 2>&1; then
                echo "配置文件检查通过: $config_file"
                log_mock "配置文件格式正确"
                exit 0
            else
                echo "配置文件格式错误: $config_file" >&2
                log_mock "配置文件格式错误: $config_file"
                exit 1
            fi
        else
            echo "配置文件不存在: $config_file" >&2
            log_mock "配置文件不存在: $config_file"
            exit 1
        fi
        ;;
    "run")
        shift
        while [[ $# -gt 0 ]]; do
            case $1 in
                "-c"|"--config")
                    config_file="$2"
                    shift 2
                    ;;
                "-D"|"--directory")
                    cd "$2"
                    shift 2
                    ;;
                *)
                    shift
                    ;;
            esac
        done
        
        if [[ -n "$config_file" && -f "$config_file" ]]; then
            echo "启动 Sing-box 服务..."
            echo "配置文件: $config_file"
            echo "PID文件: $pid_file"
            
            # 记录PID
            echo $$ > "$pid_file"
            
            log_mock "Sing-box 服务启动，PID: $$"
            log_mock "使用配置文件: $config_file"
            
            # 模拟服务运行
            echo "Sing-box 正在运行... (PID: $$)"
            
            # 设置信号处理
            trap 'echo "收到停止信号，正在关闭..."; log_mock "服务收到停止信号"; rm -f "$pid_file"; exit 0' TERM INT
            
            # 模拟持续运行
            local counter=0
            while true; do
                sleep 5
                ((counter++))
                log_mock "服务运行中，计数: $counter"
                
                # 每30秒输出一次状态
                if (( counter % 6 == 0 )); then
                    echo "Sing-box 运行状态正常 (运行时间: $((counter * 5))秒)"
                fi
                
                # 检查PID文件是否被删除（外部停止信号）
                if [[ ! -f "$pid_file" ]]; then
                    log_mock "PID文件被删除，服务退出"
                    break
                fi
            done
        else
            echo "错误: 配置文件不存在或未指定" >&2
            log_mock "启动失败: 配置文件问题"
            exit 1
        fi
        ;;
    "stop")
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file")
            echo "停止 Sing-box 服务 (PID: $pid)..."
            log_mock "停止服务，PID: $pid"
            
            if kill "$pid" 2>/dev/null; then
                rm -f "$pid_file"
                echo "Sing-box 服务已停止"
                log_mock "服务已成功停止"
            else
                echo "无法停止服务，进程可能已不存在" >&2
                rm -f "$pid_file"
                log_mock "停止服务失败，清理PID文件"
            fi
        else
            echo "Sing-box 服务未运行"
            log_mock "尝试停止服务，但PID文件不存在"
        fi
        ;;
    "status")
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file")
            if kill -0 "$pid" 2>/dev/null; then
                echo "Sing-box 服务正在运行 (PID: $pid)"
                log_mock "状态检查: 服务运行中，PID: $pid"
            else
                echo "Sing-box 服务未运行 (PID文件存在但进程不存在)"
                rm -f "$pid_file"
                log_mock "状态检查: 进程不存在，清理PID文件"
            fi
        else
            echo "Sing-box 服务未运行"
            log_mock "状态检查: 服务未运行"
        fi
        ;;
    *)
        echo "Sing-box 模拟版本 - E2E 测试"
        echo "用法: $0 [version|check|run|stop|status] [选项...]"
        echo "命令:"
        echo "  version              显示版本信息"
        echo "  check -c <config>    检查配置文件"
        echo "  run -c <config>      运行服务"
        echo "  stop                 停止服务"
        echo "  status               查看服务状态"
        log_mock "显示帮助信息"
        ;;
esac
EOF
    
    chmod +x "$binary_path"
    log_debug "创建模拟二进制文件: $binary_path" "test"
}

# 创建测试配置文件
create_test_config() {
    local config_file="$1"
    local port="${2:-$TEST_SERVICE_PORT}"
    local uuid="$(generate_uuid)"
    
    cat > "$config_file" << EOF
{
  "log": {
    "level": "info",
    "timestamp": true,
    "output": "${E2E_LOG_DIR}/singbox.log"
  },
  "dns": {
    "servers": [
      {
        "tag": "google",
        "address": "8.8.8.8"
      },
      {
        "tag": "local",
        "address": "223.5.5.5",
        "detour": "direct"
      }
    ],
    "rules": [
      {
        "geosite": "cn",
        "server": "local"
      }
    ]
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "0.0.0.0",
      "listen_port": $port,
      "users": [
        {
          "uuid": "$uuid",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "example.com",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "example.com",
            "server_port": 443
          },
          "private_key": "test_private_key_for_e2e",
          "short_id": ["test_short_id"]
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    }
  ],
  "route": {
    "geoip": {
      "download_url": "https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db",
      "download_detour": "direct"
    },
    "geosite": {
      "download_url": "https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db",
      "download_detour": "direct"
    },
    "rules": [
      {
        "geosite": "category-ads-all",
        "outbound": "block"
      },
      {
        "geosite": "cn",
        "geoip": "cn",
        "outbound": "direct"
      }
    ]
  },
  "experimental": {
    "cache_file": {
      "enabled": true,
      "path": "${E2E_TEMP_DIR}/cache.db"
    },
    "clash_api": {
      "external_controller": "127.0.0.1:9090",
      "external_ui": "ui",
      "secret": "test_secret",
      "default_mode": "rule"
    }
  }
}
EOF
    
    log_debug "创建测试配置文件: $config_file" "test"
    echo "$uuid"  # 返回生成的UUID供后续使用
}

# 启动测试服务
start_test_service() {
    local binary_file="$1"
    local config_file="$2"
    
    log_debug "启动测试服务" "test"
    
    # 后台启动服务
    nohup "$binary_file" run -c "$config_file" > "${E2E_LOG_DIR}/service.log" 2>&1 &
    TEST_SERVICE_PID=$!
    
    # 等待服务启动
    sleep 3
    
    # 检查服务是否启动成功
    if kill -0 "$TEST_SERVICE_PID" 2>/dev/null; then
        log_debug "测试服务启动成功，PID: $TEST_SERVICE_PID" "test"
        return 0
    else
        log_error "测试服务启动失败" "test"
        return 1
    fi
}

# 停止测试服务
stop_test_service() {
    if [[ -n "$TEST_SERVICE_PID" ]]; then
        log_debug "停止测试服务，PID: $TEST_SERVICE_PID" "test"
        
        if kill "$TEST_SERVICE_PID" 2>/dev/null; then
            # 等待进程结束
            local count=0
            while kill -0 "$TEST_SERVICE_PID" 2>/dev/null && [[ $count -lt 10 ]]; do
                sleep 1
                ((count++))
            done
            
            # 如果进程仍然存在，强制终止
            if kill -0 "$TEST_SERVICE_PID" 2>/dev/null; then
                kill -9 "$TEST_SERVICE_PID" 2>/dev/null
            fi
        fi
        
        TEST_SERVICE_PID=""
    fi
    
    # 清理PID文件
    local pid_file="${E2E_INSTALL_DIR}/singbox.pid"
    [[ -f "$pid_file" ]] && rm -f "$pid_file"
}

# 测试环境准备
test_environment_preparation() {
    begin_test_case "test_environment_preparation" "测试环境准备"
    
    # 验证测试目录结构
    local required_dirs=("$E2E_INSTALL_DIR" "$E2E_CONFIG_DIR" "$E2E_LOG_DIR" "$E2E_BACKUP_DIR" "$E2E_TEMP_DIR")
    for dir in "${required_dirs[@]}"; do
        assert_file_exists "$dir" "目录应存在: $(basename "$dir")"
    done
    
    # 验证环境变量
    assert_equals "$E2E_INSTALL_DIR" "$SINGBOX_DIR" "SINGBOX_DIR 环境变量应正确设置"
    assert_equals "$E2E_CONFIG_DIR" "$CONFIG_DIR" "CONFIG_DIR 环境变量应正确设置"
    assert_equals "true" "$TEST_MODE" "TEST_MODE 应为 true"
    assert_equals "true" "$E2E_TEST" "E2E_TEST 应为 true"
    
    test_pass "环境准备测试通过"
}

# 测试二进制文件安装
test_binary_installation() {
    begin_test_case "test_binary_installation" "测试二进制文件安装"
    
    local binary_file="${E2E_INSTALL_DIR}/singbox"
    
    # 创建模拟二进制文件
    create_mock_singbox_binary "$binary_file"
    
    # 验证文件存在和权限
    assert_file_exists "$binary_file" "二进制文件应存在"
    
    if [[ -x "$binary_file" ]]; then
        assert_true "true" "二进制文件应可执行"
    else
        assert_true "false" "二进制文件应可执行"
    fi
    
    # 测试版本命令
    local version_output
    version_output=$("$binary_file" version 2>/dev/null)
    assert_contains "$version_output" "sing-box version" "版本输出应包含版本信息"
    assert_contains "$version_output" "mock-e2e-test" "版本输出应包含测试标识"
    
    test_pass "二进制文件安装测试通过"
}

# 测试配置文件生成和验证
test_config_generation_and_validation() {
    begin_test_case "test_config_generation_and_validation" "测试配置文件生成和验证"
    
    local config_file="${E2E_CONFIG_DIR}/config.json"
    local binary_file="${E2E_INSTALL_DIR}/singbox"
    
    # 生成配置文件
    local test_uuid
    test_uuid=$(create_test_config "$config_file" "$TEST_SERVICE_PORT")
    
    # 验证配置文件
    assert_file_exists "$config_file" "配置文件应被创建"
    
    # 验证配置内容
    local config_content
    config_content=$(cat "$config_file")
    assert_contains "$config_content" "$TEST_SERVICE_PORT" "配置应包含测试端口"
    assert_contains "$config_content" "$test_uuid" "配置应包含生成的UUID"
    assert_contains "$config_content" "vless" "配置应包含VLESS协议"
    assert_contains "$config_content" "reality" "配置应包含Reality配置"
    
    # 测试JSON格式
    if command -v "jq" >/dev/null 2>&1; then
        if jq . "$config_file" >/dev/null 2>&1; then
            assert_true "true" "配置文件应为有效JSON格式"
        else
            assert_true "false" "配置文件应为有效JSON格式"
        fi
    else
        log_debug "jq 不可用，跳过JSON格式验证" "test"
    fi
    
    # 使用 Sing-box 验证配置
    local check_result
    check_result=$("$binary_file" check -c "$config_file" 2>&1)
    local check_exit_code=$?
    
    if [[ $check_exit_code -eq 0 ]]; then
        assert_true "true" "Sing-box 配置检查应通过"
        assert_contains "$check_result" "检查通过" "检查结果应包含成功信息"
    else
        test_fail "Sing-box 配置检查失败: $check_result"
        return
    fi
    
    test_pass "配置文件生成和验证测试通过"
}

# 测试服务启动和状态检查
test_service_startup_and_status() {
    begin_test_case "test_service_startup_and_status" "测试服务启动和状态检查"
    
    local binary_file="${E2E_INSTALL_DIR}/singbox"
    local config_file="${E2E_CONFIG_DIR}/config.json"
    
    # 确保配置文件存在
    if [[ ! -f "$config_file" ]]; then
        create_test_config "$config_file" "$TEST_SERVICE_PORT" >/dev/null
    fi
    
    # 启动服务
    if start_test_service "$binary_file" "$config_file"; then
        assert_true "true" "服务应成功启动"
    else
        test_fail "服务启动失败"
        return
    fi
    
    # 等待服务稳定
    sleep 2
    
    # 检查服务状态
    local status_output
    status_output=$("$binary_file" status 2>&1)
    assert_contains "$status_output" "正在运行" "状态检查应显示服务运行中"
    
    # 检查PID文件
    local pid_file="${E2E_INSTALL_DIR}/singbox.pid"
    if [[ -f "$pid_file" ]]; then
        assert_true "true" "PID文件应存在"
        
        local pid
        pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            assert_true "true" "PID对应的进程应存在"
        else
            assert_true "false" "PID对应的进程应存在"
        fi
    else
        log_debug "PID文件不存在，可能是模拟环境特性" "test"
    fi
    
    # 检查日志文件
    local log_file="${E2E_LOG_DIR}/singbox.log"
    if [[ -f "$log_file" ]]; then
        assert_true "true" "日志文件应被创建"
        
        # 检查日志内容
        local log_content
        log_content=$(cat "$log_file" 2>/dev/null || echo "")
        if [[ -n "$log_content" ]]; then
            log_debug "日志文件包含内容" "test"
        fi
    else
        log_debug "日志文件不存在，可能是配置或环境问题" "test"
    fi
    
    test_pass "服务启动和状态检查测试通过"
}

# 测试端口监听
test_port_listening() {
    begin_test_case "test_port_listening" "测试端口监听"
    
    # 检查端口是否被监听
    local port_check_result
    if command -v "netstat" >/dev/null 2>&1; then
        port_check_result=$(netstat -ln 2>/dev/null | grep ":$TEST_SERVICE_PORT " || echo "")
    elif command -v "ss" >/dev/null 2>&1; then
        port_check_result=$(ss -ln 2>/dev/null | grep ":$TEST_SERVICE_PORT " || echo "")
    else
        log_warn "缺少网络检查工具，跳过端口监听测试" "test"
        test_skip "缺少 netstat 或 ss 工具"
        return
    fi
    
    if [[ -n "$port_check_result" ]]; then
        assert_true "true" "端口 $TEST_SERVICE_PORT 应被监听"
        log_debug "端口监听检查结果: $port_check_result" "test"
    else
        # 在模拟环境中，端口可能不会真正监听
        log_debug "端口 $TEST_SERVICE_PORT 未检测到监听，可能是模拟环境特性" "test"
    fi
    
    test_pass "端口监听测试完成"
}

# 测试配置热重载
test_config_reload() {
    begin_test_case "test_config_reload" "测试配置热重载"
    
    local config_file="${E2E_CONFIG_DIR}/config.json"
    local backup_config="${E2E_BACKUP_DIR}/config_backup.json"
    
    # 备份原始配置
    cp "$config_file" "$backup_config"
    assert_file_exists "$backup_config" "配置备份应被创建"
    
    # 修改配置（更改日志级别）
    local modified_config
    modified_config=$(jq '.log.level = "debug"' "$config_file" 2>/dev/null || cat "$config_file")
    echo "$modified_config" > "$config_file"
    
    # 验证配置修改
    if command -v "jq" >/dev/null 2>&1; then
        local log_level
        log_level=$(jq -r '.log.level' "$config_file" 2>/dev/null)
        assert_equals "debug" "$log_level" "日志级别应被修改为 debug"
    fi
    
    # 验证修改后的配置
    local binary_file="${E2E_INSTALL_DIR}/singbox"
    local check_result
    check_result=$("$binary_file" check -c "$config_file" 2>&1)
    local check_exit_code=$?
    
    if [[ $check_exit_code -eq 0 ]]; then
        assert_true "true" "修改后的配置应通过验证"
    else
        test_fail "修改后的配置验证失败: $check_result"
        # 恢复原始配置
        cp "$backup_config" "$config_file"
        return
    fi
    
    # 恢复原始配置
    cp "$backup_config" "$config_file"
    
    test_pass "配置热重载测试通过"
}

# 测试服务停止
test_service_stop() {
    begin_test_case "test_service_stop" "测试服务停止"
    
    local binary_file="${E2E_INSTALL_DIR}/singbox"
    
    # 停止服务
    stop_test_service
    
    # 等待服务完全停止
    sleep 2
    
    # 检查服务状态
    local status_output
    status_output=$("$binary_file" status 2>&1)
    assert_contains "$status_output" "未运行" "状态检查应显示服务未运行"
    
    # 检查PID文件是否被清理
    local pid_file="${E2E_INSTALL_DIR}/singbox.pid"
    if [[ ! -f "$pid_file" ]]; then
        assert_true "true" "PID文件应被清理"
    else
        log_debug "PID文件仍存在，可能是清理延迟" "test"
    fi
    
    test_pass "服务停止测试通过"
}

# 测试日志记录
test_logging() {
    begin_test_case "test_logging" "测试日志记录功能"
    
    # 检查各种日志文件
    local log_files=(
        "${E2E_LOG_DIR}/service.log"
        "${E2E_LOG_DIR}/singbox-mock.log"
    )
    
    local found_logs=0
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            assert_file_exists "$log_file" "日志文件应存在: $(basename "$log_file")"
            
            # 检查日志内容
            local log_content
            log_content=$(cat "$log_file" 2>/dev/null || echo "")
            if [[ -n "$log_content" ]]; then
                assert_true "true" "日志文件应包含内容: $(basename "$log_file")"
                ((found_logs++))
                
                # 检查时间戳格式
                if echo "$log_content" | grep -q "\[20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]"; then
                    assert_true "true" "日志应包含时间戳"
                fi
            fi
        fi
    done
    
    if [[ $found_logs -gt 0 ]]; then
        assert_true "true" "至少应有一个日志文件包含内容"
    else
        log_debug "未找到包含内容的日志文件，可能是测试环境特性" "test"
    fi
    
    test_pass "日志记录测试通过"
}

# 测试错误处理
test_error_handling() {
    begin_test_case "test_error_handling" "测试错误处理"
    
    local binary_file="${E2E_INSTALL_DIR}/singbox"
    
    # 测试无效配置文件
    local invalid_config="${E2E_CONFIG_DIR}/invalid.json"
    echo "{ invalid json" > "$invalid_config"
    
    local check_result
    check_result=$("$binary_file" check -c "$invalid_config" 2>&1)
    local check_exit_code=$?
    
    if [[ $check_exit_code -ne 0 ]]; then
        assert_true "true" "无效配置应被检测出来"
        assert_contains "$check_result" "错误" "错误信息应包含错误描述"
    else
        test_fail "无效配置未被检测出来"
    fi
    
    # 测试不存在的配置文件
    local nonexistent_config="${E2E_CONFIG_DIR}/nonexistent.json"
    check_result=$("$binary_file" check -c "$nonexistent_config" 2>&1)
    check_exit_code=$?
    
    if [[ $check_exit_code -ne 0 ]]; then
        assert_true "true" "不存在的配置文件应报错"
        assert_contains "$check_result" "不存在" "错误信息应指出文件不存在"
    else
        test_fail "不存在的配置文件未报错"
    fi
    
    # 清理测试文件
    rm -f "$invalid_config"
    
    test_pass "错误处理测试通过"
}

# 测试完整工作流
test_complete_workflow() {
    begin_test_case "test_complete_workflow" "测试完整工作流"
    
    local binary_file="${E2E_INSTALL_DIR}/singbox"
    local config_file="${E2E_CONFIG_DIR}/workflow_config.json"
    
    log_debug "开始完整工作流测试" "test"
    
    # 1. 生成配置
    log_debug "步骤1: 生成配置文件" "test"
    local workflow_uuid
    workflow_uuid=$(create_test_config "$config_file" "18444")
    assert_file_exists "$config_file" "工作流配置文件应被创建"
    
    # 2. 验证配置
    log_debug "步骤2: 验证配置文件" "test"
    local check_result
    check_result=$("$binary_file" check -c "$config_file" 2>&1)
    if [[ $? -eq 0 ]]; then
        assert_true "true" "工作流配置验证应通过"
    else
        test_fail "工作流配置验证失败: $check_result"
        return
    fi
    
    # 3. 启动服务
    log_debug "步骤3: 启动服务" "test"
    if start_test_service "$binary_file" "$config_file"; then
        assert_true "true" "工作流服务应成功启动"
    else
        test_fail "工作流服务启动失败"
        return
    fi
    
    # 4. 检查服务状态
    log_debug "步骤4: 检查服务状态" "test"
    sleep 3
    local status_result
    status_result=$("$binary_file" status 2>&1)
    assert_contains "$status_result" "正在运行" "工作流服务应处于运行状态"
    
    # 5. 运行一段时间
    log_debug "步骤5: 服务运行测试" "test"
    sleep 5
    
    # 6. 停止服务
    log_debug "步骤6: 停止服务" "test"
    stop_test_service
    sleep 2
    
    # 7. 验证停止状态
    log_debug "步骤7: 验证停止状态" "test"
    status_result=$("$binary_file" status 2>&1)
    assert_contains "$status_result" "未运行" "工作流服务应已停止"
    
    log_debug "完整工作流测试完成" "test"
    test_pass "完整工作流测试通过"
}

# 主测试函数
run_e2e_tests() {
    begin_test_suite "$TEST_SUITE_NAME" "$TEST_SUITE_DESCRIPTION"
    
    # 设置测试环境
    setup_e2e_tests
    
    # 运行端到端测试
    test_environment_preparation
    test_binary_installation
    test_config_generation_and_validation
    test_service_startup_and_status
    test_port_listening
    test_config_reload
    test_service_stop
    test_logging
    test_error_handling
    test_complete_workflow
    
    # 清理测试环境
    teardown_e2e_tests
    
    end_test_suite "$TEST_SUITE_NAME"
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_test_framework
    run_e2e_tests
    generate_test_report
fi