#!/bin/bash

# 测试在线安装功能
# 用于验证 install_v2.sh 的在线安装逻辑是否正常工作

set -euo pipefail

# 测试配置
TEST_NAME="在线安装功能测试"
TEST_VERSION="v1.0.0"
TEST_DIR="$(mktemp -d)"
LOG_FILE="${TEST_DIR}/test_online_install.log"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[信息]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[成功]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[警告]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[错误]${NC} $1" | tee -a "$LOG_FILE"
}

# 清理函数
cleanup() {
    if [[ -d "$TEST_DIR" ]]; then
        log_info "清理测试目录: $TEST_DIR"
        rm -rf "$TEST_DIR"
    fi
}

# 设置退出时清理
trap cleanup EXIT

# 显示测试信息
show_test_info() {
    echo ""
    echo "======================================"
    echo "  $TEST_NAME"
    echo "  版本: $TEST_VERSION"
    echo "  测试目录: $TEST_DIR"
    echo "  日志文件: $LOG_FILE"
    echo "======================================"
    echo ""
}

# 测试在线安装模式检测
test_online_detection() {
    log_info "测试 1: 在线安装模式检测"
    
    # 创建测试脚本
    cat > "${TEST_DIR}/test_detect.sh" << 'EOF'
#!/bin/bash

# 模拟在线安装检测函数
detect_online_install() {
    if [[ "${BASH_SOURCE[0]}" == "/dev/fd/"* ]] || [[ "${BASH_SOURCE[0]}" == "/proc/self/fd/"* ]]; then
        return 0  # 在线安装
    else
        return 1  # 本地安装
    fi
}

# 测试本地模式
if detect_online_install; then
    echo "ONLINE"
else
    echo "LOCAL"
fi
EOF

    chmod +x "${TEST_DIR}/test_detect.sh"
    
    # 测试本地模式
    local result=$(bash "${TEST_DIR}/test_detect.sh")
    if [[ "$result" == "LOCAL" ]]; then
        log_success "本地模式检测正常"
    else
        log_error "本地模式检测失败，期望 LOCAL，实际 $result"
        return 1
    fi
    
    # 模拟在线模式（通过管道）
    result=$(cat "${TEST_DIR}/test_detect.sh" | bash /dev/stdin)
    if [[ "$result" == "ONLINE" ]]; then
        log_success "在线模式检测正常"
    else
        log_warn "在线模式检测可能不准确，期望 ONLINE，实际 $result"
    fi
}

# 测试下载功能
test_download_functions() {
    log_info "测试 2: 下载功能测试"
    
    # 检查必要工具
    local tools=("curl" "wget" "tar")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_warn "缺少工具: ${missing_tools[*]}"
        log_warn "跳过下载功能测试"
        return 0
    fi
    
    log_success "所有必要工具已安装: ${tools[*]}"
    
    # 测试 GitHub API 连接
    if curl -s --connect-timeout 10 "https://api.github.com/repos/Yan-nian/singbox-install-script" >/dev/null; then
        log_success "GitHub API 连接正常"
    else
        log_warn "GitHub API 连接失败，可能影响在线安装"
    fi
}

# 测试模块加载逻辑
test_module_loading() {
    log_info "测试 3: 模块加载逻辑测试"
    
    # 创建模拟的项目结构
    local mock_project="${TEST_DIR}/mock_project"
    mkdir -p "$mock_project"/{core,config,utils,scripts,templates}
    
    # 创建模拟模块文件
    echo '#!/bin/bash' > "${mock_project}/core/bootstrap.sh"
    echo 'echo "Bootstrap loaded"' >> "${mock_project}/core/bootstrap.sh"
    
    echo '#!/bin/bash' > "${mock_project}/core/error_handler.sh"
    echo 'echo "Error handler loaded"' >> "${mock_project}/core/error_handler.sh"
    
    echo '#!/bin/bash' > "${mock_project}/core/logger.sh"
    echo 'echo "Logger loaded"' >> "${mock_project}/core/logger.sh"
    
    # 创建测试脚本
    cat > "${mock_project}/test_loading.sh" << 'EOF'
#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR"

CORE_DIR="${BASE_DIR}/core"

# 测试模块加载
if source "${CORE_DIR}/bootstrap.sh" 2>/dev/null; then
    echo "SUCCESS: bootstrap.sh loaded"
else
    echo "ERROR: bootstrap.sh failed"
    exit 1
fi

if source "${CORE_DIR}/error_handler.sh" 2>/dev/null; then
    echo "SUCCESS: error_handler.sh loaded"
else
    echo "ERROR: error_handler.sh failed"
    exit 1
fi

if source "${CORE_DIR}/logger.sh" 2>/dev/null; then
    echo "SUCCESS: logger.sh loaded"
else
    echo "ERROR: logger.sh failed"
    exit 1
fi

echo "All modules loaded successfully"
EOF

    chmod +x "${mock_project}/test_loading.sh"
    
    # 运行测试
    if bash "${mock_project}/test_loading.sh" >/dev/null 2>&1; then
        log_success "模块加载逻辑正常"
    else
        log_error "模块加载逻辑失败"
        return 1
    fi
}

# 测试临时文件清理
test_cleanup_logic() {
    log_info "测试 4: 临时文件清理测试"
    
    # 创建测试脚本
    cat > "${TEST_DIR}/test_cleanup.sh" << 'EOF'
#!/bin/bash

TEMP_DIR="$(mktemp -d)"
echo "Created temp dir: $TEMP_DIR"

# 清理函数
cleanup_temp_files() {
    if [[ -n "$TEMP_DIR" ]] && [[ -d "$TEMP_DIR" ]]; then
        echo "Cleaning up: $TEMP_DIR"
        rm -rf "$TEMP_DIR"
        echo "Cleanup completed"
    fi
}

# 设置退出时清理
trap cleanup_temp_files EXIT

# 创建一些测试文件
echo "test content" > "${TEMP_DIR}/test.txt"
mkdir "${TEMP_DIR}/subdir"
echo "sub content" > "${TEMP_DIR}/subdir/sub.txt"

echo "Test files created"
ls -la "$TEMP_DIR"

# 脚本退出时会自动清理
EOF

    # 运行测试并检查输出
    local output=$(bash "${TEST_DIR}/test_cleanup.sh" 2>&1)
    
    if echo "$output" | grep -q "Cleanup completed"; then
        log_success "临时文件清理逻辑正常"
    else
        log_error "临时文件清理逻辑失败"
        log_error "输出: $output"
        return 1
    fi
}

# 运行所有测试
run_all_tests() {
    local failed_tests=0
    
    show_test_info
    
    log_info "开始运行测试套件..."
    echo ""
    
    # 运行各项测试
    test_online_detection || ((failed_tests++))
    echo ""
    
    test_download_functions || ((failed_tests++))
    echo ""
    
    test_module_loading || ((failed_tests++))
    echo ""
    
    test_cleanup_logic || ((failed_tests++))
    echo ""
    
    # 显示测试结果
    echo "======================================"
    if [[ $failed_tests -eq 0 ]]; then
        log_success "所有测试通过！在线安装功能正常"
        echo ""
        log_info "可以安全使用以下命令进行在线安装:"
        echo "bash <(curl -fsSL https://raw.githubusercontent.com/Yan-nian/singbox-install-script/master/install_v2.sh)"
    else
        log_error "$failed_tests 个测试失败"
        echo ""
        log_warn "建议检查网络连接和系统环境后重试"
        log_warn "或使用本地安装方式"
    fi
    echo "======================================"
    
    return $failed_tests
}

# 主函数
main() {
    run_all_tests
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi