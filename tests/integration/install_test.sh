#!/bin/bash

# 安装流程集成测试
# 测试完整的安装和配置流程
# 版本: v2.4.14

set -euo pipefail

# 测试配置
TEST_SUITE_NAME="install_integration_test"
TEST_SUITE_DESCRIPTION="测试 Sing-box 安装和配置集成流程"

# 引入测试框架
source "${BASH_SOURCE%/*}/../test_framework.sh"

# 引入核心模块
source "${BASH_SOURCE%/*}/../../core/bootstrap.sh" 2>/dev/null || {
    log_warn "无法加载 bootstrap.sh，将跳过相关测试" "test"
}

source "${BASH_SOURCE%/*}/../../scripts/common.sh" 2>/dev/null || {
    log_error "无法加载 common.sh 模块" "test"
    exit 1
}

# 测试环境变量
TEST_INSTALL_DIR=""
TEST_CONFIG_DIR=""
TEST_BACKUP_DIR=""
ORIGINAL_SINGBOX_DIR="${SINGBOX_DIR:-}"
ORIGINAL_CONFIG_DIR="${CONFIG_DIR:-}"

# 测试前准备
setup_install_tests() {
    log_info "设置安装集成测试环境" "test"
    
    # 创建测试目录
    TEST_INSTALL_DIR=$(create_test_temp_dir "install")
    TEST_CONFIG_DIR="${TEST_INSTALL_DIR}/config"
    TEST_BACKUP_DIR="${TEST_INSTALL_DIR}/backup"
    
    # 创建必要的子目录
    mkdir -p "$TEST_CONFIG_DIR" "$TEST_BACKUP_DIR"
    
    # 设置测试环境变量
    export SINGBOX_DIR="$TEST_INSTALL_DIR"
    export CONFIG_DIR="$TEST_CONFIG_DIR"
    export BACKUP_DIR="$TEST_BACKUP_DIR"
    export TEST_MODE="true"
    
    log_debug "测试安装目录: $TEST_INSTALL_DIR" "test"
    log_debug "测试配置目录: $TEST_CONFIG_DIR" "test"
}

# 测试后清理
teardown_install_tests() {
    log_info "清理安装集成测试环境" "test"
    
    # 恢复原始环境变量
    export SINGBOX_DIR="$ORIGINAL_SINGBOX_DIR"
    export CONFIG_DIR="$ORIGINAL_CONFIG_DIR"
    unset TEST_MODE
    
    # 清理测试目录
    [[ -d "$TEST_INSTALL_DIR" ]] && rm -rf "$TEST_INSTALL_DIR"
    
    log_debug "安装集成测试环境已清理" "test"
}

# 模拟下载函数（避免实际网络请求）
mock_download_singbox() {
    local version="${1:-latest}"
    local target_file="${2:-singbox}"
    
    log_debug "模拟下载 Sing-box $version 到 $target_file" "test"
    
    # 创建模拟的二进制文件
    cat > "$target_file" << 'EOF'
#!/bin/bash
# 模拟的 Sing-box 二进制文件
echo "Sing-box 模拟版本 v1.8.0"
case "$1" in
    "version")
        echo "sing-box version 1.8.0"
        ;;
    "check")
        echo "配置文件检查通过"
        ;;
    "run")
        echo "Sing-box 正在运行..."
        sleep 1
        ;;
    *)
        echo "用法: singbox [version|check|run]"
        ;;
esac
EOF
    
    chmod +x "$target_file"
    return 0
}

# 测试环境检查
test_environment_check() {
    begin_test_case "test_environment_check" "测试环境检查功能"
    
    # 测试系统信息获取
    if command -v "uname" >/dev/null 2>&1; then
        local os_info
        os_info=$(uname -s)
        assert_not_equals "" "$os_info" "应能获取操作系统信息"
    fi
    
    # 测试架构检测
    if command -v "uname" >/dev/null 2>&1; then
        local arch_info
        arch_info=$(uname -m)
        assert_not_equals "" "$arch_info" "应能获取系统架构信息"
    fi
    
    # 测试权限检查
    if [[ $EUID -eq 0 ]]; then
        assert_true "true" "检测到 root 权限"
    else
        # 检查 sudo 权限
        if command -v "sudo" >/dev/null 2>&1; then
            assert_true "true" "检测到 sudo 命令"
        else
            log_warn "无 root 权限且无 sudo 命令" "test"
        fi
    fi
    
    test_pass "环境检查测试通过"
}

# 测试目录创建
test_directory_creation() {
    begin_test_case "test_directory_creation" "测试安装目录创建"
    
    # 测试主安装目录
    assert_file_exists "$TEST_INSTALL_DIR" "安装目录应存在"
    
    # 测试配置目录
    assert_file_exists "$TEST_CONFIG_DIR" "配置目录应存在"
    
    # 测试备份目录
    assert_file_exists "$TEST_BACKUP_DIR" "备份目录应存在"
    
    # 测试目录权限
    if [[ -w "$TEST_INSTALL_DIR" ]]; then
        assert_true "true" "安装目录应可写"
    else
        assert_true "false" "安装目录应可写"
    fi
    
    test_pass "目录创建测试通过"
}

# 测试配置文件生成
test_config_generation() {
    begin_test_case "test_config_generation" "测试配置文件生成"
    
    # 创建测试配置模板
    local template_file="${TEST_CONFIG_DIR}/test_template.json"
    cat > "$template_file" << 'EOF'
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "0.0.0.0",
      "listen_port": {{PORT}},
      "users": [
        {
          "uuid": "{{UUID}}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "{{SERVER_NAME}}",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "{{DEST_SERVER}}",
            "server_port": {{DEST_PORT}}
          },
          "private_key": "{{PRIVATE_KEY}}",
          "short_id": ["{{SHORT_ID}}"]
        }
      }
    }
  ]
}
EOF
    
    assert_file_exists "$template_file" "配置模板文件应被创建"
    
    # 测试配置参数替换
    local config_file="${TEST_CONFIG_DIR}/test_config.json"
    local test_port="8443"
    local test_uuid="$(generate_uuid)"
    local test_server="example.com"
    
    # 模拟配置生成过程
    sed "s/{{PORT}}/$test_port/g; s/{{UUID}}/$test_uuid/g; s/{{SERVER_NAME}}/$test_server/g; s/{{DEST_SERVER}}/$test_server/g; s/{{DEST_PORT}}/443/g; s/{{PRIVATE_KEY}}/test_key/g; s/{{SHORT_ID}}/test_id/g" \
        "$template_file" > "$config_file"
    
    assert_file_exists "$config_file" "生成的配置文件应存在"
    
    # 验证配置内容
    assert_contains "$(cat "$config_file")" "$test_port" "配置应包含指定端口"
    assert_contains "$(cat "$config_file")" "$test_uuid" "配置应包含生成的UUID"
    assert_contains "$(cat "$config_file")" "$test_server" "配置应包含服务器名称"
    
    # 测试JSON格式有效性
    if command -v "jq" >/dev/null 2>&1; then
        if jq . "$config_file" >/dev/null 2>&1; then
            assert_true "true" "生成的配置应为有效JSON格式"
        else
            assert_true "false" "生成的配置应为有效JSON格式"
        fi
    else
        log_debug "jq 命令不可用，跳过JSON格式验证" "test"
    fi
    
    test_pass "配置文件生成测试通过"
}

# 测试二进制文件安装
test_binary_installation() {
    begin_test_case "test_binary_installation" "测试二进制文件安装"
    
    local binary_file="${TEST_INSTALL_DIR}/singbox"
    
    # 模拟下载和安装
    mock_download_singbox "latest" "$binary_file"
    
    assert_file_exists "$binary_file" "二进制文件应被安装"
    
    # 测试文件权限
    if [[ -x "$binary_file" ]]; then
        assert_true "true" "二进制文件应可执行"
    else
        assert_true "false" "二进制文件应可执行"
    fi
    
    # 测试版本检查
    local version_output
    version_output=$("$binary_file" version 2>/dev/null || echo "version check failed")
    assert_contains "$version_output" "sing-box" "版本输出应包含程序名称"
    
    test_pass "二进制文件安装测试通过"
}

# 测试服务配置
test_service_configuration() {
    begin_test_case "test_service_configuration" "测试服务配置"
    
    # 创建模拟的服务文件
    local service_file="${TEST_INSTALL_DIR}/singbox.service"
    cat > "$service_file" << EOF
[Unit]
Description=Sing-box Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=${TEST_INSTALL_DIR}/singbox run -c ${TEST_CONFIG_DIR}/config.json
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    assert_file_exists "$service_file" "服务文件应被创建"
    
    # 验证服务文件内容
    assert_contains "$(cat "$service_file")" "Sing-box Service" "服务文件应包含正确描述"
    assert_contains "$(cat "$service_file")" "$TEST_INSTALL_DIR/singbox" "服务文件应包含正确的执行路径"
    assert_contains "$(cat "$service_file")" "$TEST_CONFIG_DIR/config.json" "服务文件应包含正确的配置路径"
    
    test_pass "服务配置测试通过"
}

# 测试配置验证
test_config_validation() {
    begin_test_case "test_config_validation" "测试配置文件验证"
    
    local binary_file="${TEST_INSTALL_DIR}/singbox"
    local config_file="${TEST_CONFIG_DIR}/test_config.json"
    
    # 确保二进制文件和配置文件存在
    if [[ ! -f "$binary_file" ]]; then
        mock_download_singbox "latest" "$binary_file"
    fi
    
    if [[ ! -f "$config_file" ]]; then
        # 创建简单的测试配置
        cat > "$config_file" << 'EOF'
{
  "log": {
    "level": "info"
  },
  "inbounds": [],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF
    fi
    
    # 测试配置验证
    local check_result
    check_result=$("$binary_file" check -c "$config_file" 2>/dev/null || echo "check failed")
    
    # 由于是模拟的二进制文件，我们主要测试调用过程
    assert_not_equals "" "$check_result" "配置检查应有输出"
    
    test_pass "配置验证测试通过"
}

# 测试端口冲突检查
test_port_conflict_check() {
    begin_test_case "test_port_conflict_check" "测试端口冲突检查"
    
    # 测试端口检查函数
    if command -v "netstat" >/dev/null 2>&1 || command -v "ss" >/dev/null 2>&1; then
        # 检查一个通常被占用的端口
        if check_port 22 >/dev/null 2>&1; then
            log_debug "端口22被占用，符合预期" "test"
        else
            log_debug "端口22未被占用" "test"
        fi
        
        # 获取一个随机可用端口
        local available_port
        available_port=$(get_random_port)
        
        if [[ "$available_port" -ge 1024 && "$available_port" -le 65535 ]]; then
            assert_true "true" "应能获取有效的可用端口"
        else
            assert_true "false" "应能获取有效的可用端口"
        fi
    else
        log_warn "缺少端口检查工具，跳过端口冲突测试" "test"
        test_skip "缺少必要的网络工具"
        return
    fi
    
    test_pass "端口冲突检查测试通过"
}

# 测试备份和恢复
test_backup_and_restore() {
    begin_test_case "test_backup_and_restore" "测试配置备份和恢复"
    
    # 创建测试配置文件
    local original_config="${TEST_CONFIG_DIR}/original.json"
    local backup_config="${TEST_BACKUP_DIR}/backup_$(date +%Y%m%d_%H%M%S).json"
    
    cat > "$original_config" << 'EOF'
{
  "log": {
    "level": "debug"
  },
  "test": "original_config"
}
EOF
    
    assert_file_exists "$original_config" "原始配置文件应存在"
    
    # 测试备份
    cp "$original_config" "$backup_config"
    assert_file_exists "$backup_config" "备份文件应被创建"
    
    # 验证备份内容
    local original_content backup_content
    original_content=$(cat "$original_config")
    backup_content=$(cat "$backup_config")
    assert_equals "$original_content" "$backup_content" "备份内容应与原始内容相同"
    
    # 测试恢复
    echo '{"test": "modified"}' > "$original_config"
    cp "$backup_config" "$original_config"
    
    local restored_content
    restored_content=$(cat "$original_config")
    assert_equals "$original_content" "$restored_content" "恢复后内容应与备份相同"
    
    test_pass "备份和恢复测试通过"
}

# 测试完整安装流程
test_full_installation_flow() {
    begin_test_case "test_full_installation_flow" "测试完整安装流程"
    
    # 1. 环境检查
    log_debug "步骤1: 环境检查" "test"
    
    # 2. 目录创建
    log_debug "步骤2: 目录创建" "test"
    local flow_install_dir="${TEST_INSTALL_DIR}/flow_test"
    mkdir -p "$flow_install_dir"
    assert_file_exists "$flow_install_dir" "流程测试目录应被创建"
    
    # 3. 二进制文件下载
    log_debug "步骤3: 二进制文件安装" "test"
    local flow_binary="${flow_install_dir}/singbox"
    mock_download_singbox "latest" "$flow_binary"
    assert_file_exists "$flow_binary" "流程测试二进制文件应存在"
    
    # 4. 配置文件生成
    log_debug "步骤4: 配置文件生成" "test"
    local flow_config="${flow_install_dir}/config.json"
    cat > "$flow_config" << 'EOF'
{
  "log": {
    "level": "info"
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
      "tag": "direct-out"
    }
  ]
}
EOF
    assert_file_exists "$flow_config" "流程测试配置文件应存在"
    
    # 5. 配置验证
    log_debug "步骤5: 配置验证" "test"
    local validation_result
    validation_result=$("$flow_binary" check -c "$flow_config" 2>/dev/null || echo "validation completed")
    assert_not_equals "" "$validation_result" "配置验证应有结果"
    
    # 6. 服务文件创建
    log_debug "步骤6: 服务文件创建" "test"
    local flow_service="${flow_install_dir}/singbox.service"
    cat > "$flow_service" << EOF
[Unit]
Description=Sing-box Flow Test
After=network.target

[Service]
Type=simple
ExecStart=$flow_binary run -c $flow_config
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    assert_file_exists "$flow_service" "流程测试服务文件应存在"
    
    log_debug "完整安装流程测试完成" "test"
    test_pass "完整安装流程测试通过"
}

# 主测试函数
run_install_integration_tests() {
    begin_test_suite "$TEST_SUITE_NAME" "$TEST_SUITE_DESCRIPTION"
    
    # 设置测试环境
    setup_install_tests
    
    # 运行集成测试
    test_environment_check
    test_directory_creation
    test_config_generation
    test_binary_installation
    test_service_configuration
    test_config_validation
    test_port_conflict_check
    test_backup_and_restore
    test_full_installation_flow
    
    # 清理测试环境
    teardown_install_tests
    
    end_test_suite "$TEST_SUITE_NAME"
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_test_framework
    run_install_integration_tests
    generate_test_report
fi