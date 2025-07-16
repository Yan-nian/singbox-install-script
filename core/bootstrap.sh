#!/bin/bash

# 启动引导模块
# 负责环境检查、权限验证、系统兼容性检测
# 版本: v2.4.14

set -euo pipefail

# 引导模块信息
BOOTSTRAP_VERSION="v2.4.14"
MIN_BASH_VERSION="4.0"
REQUIRED_COMMANDS=("curl" "wget" "systemctl" "jq")

# 系统信息
SYSTEM_INFO=()
ENVIRONMENT_CHECKS=()
PERMISSION_CHECKS=()

# 引导日志函数（独立于主日志系统）
bootstrap_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "\033[32m[$timestamp] [BOOTSTRAP] [INFO] $message\033[0m"
            ;;
        "WARN")
            echo -e "\033[33m[$timestamp] [BOOTSTRAP] [WARN] $message\033[0m" >&2
            ;;
        "ERROR")
            echo -e "\033[31m[$timestamp] [BOOTSTRAP] [ERROR] $message\033[0m" >&2
            ;;
        "DEBUG")
            [[ "${DEBUG:-}" == "true" ]] && echo -e "\033[36m[$timestamp] [BOOTSTRAP] [DEBUG] $message\033[0m" >&2
            ;;
    esac
}

# 检查Bash版本
check_bash_version() {
    local current_version="${BASH_VERSION%%.*}"
    local min_version="${MIN_BASH_VERSION%%.*}"
    
    if [[ "$current_version" -lt "$min_version" ]]; then
        bootstrap_log "ERROR" "需要 Bash $MIN_BASH_VERSION 或更高版本，当前版本: $BASH_VERSION"
        return 1
    fi
    
    bootstrap_log "INFO" "Bash版本检查通过: $BASH_VERSION"
    ENVIRONMENT_CHECKS+=("bash_version:pass")
    return 0
}

# 检查系统兼容性
check_system_compatibility() {
    bootstrap_log "INFO" "检查系统兼容性..."
    
    # 检测操作系统
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        SYSTEM_INFO+=("os_name:$NAME")
        SYSTEM_INFO+=("os_version:$VERSION_ID")
        bootstrap_log "INFO" "检测到系统: $NAME $VERSION_ID"
    else
        bootstrap_log "WARN" "无法检测操作系统信息"
        SYSTEM_INFO+=("os_name:unknown")
    fi
    
    # 检测架构
    local arch=$(uname -m)
    SYSTEM_INFO+=("arch:$arch")
    
    case "$arch" in
        x86_64|amd64)
            bootstrap_log "INFO" "支持的架构: $arch"
            ENVIRONMENT_CHECKS+=("arch:pass")
            ;;
        aarch64|arm64)
            bootstrap_log "INFO" "支持的架构: $arch"
            ENVIRONMENT_CHECKS+=("arch:pass")
            ;;
        *)
            bootstrap_log "WARN" "未测试的架构: $arch"
            ENVIRONMENT_CHECKS+=("arch:warn")
            ;;
    esac
    
    # 检查内核版本
    local kernel_version=$(uname -r)
    SYSTEM_INFO+=("kernel:$kernel_version")
    bootstrap_log "INFO" "内核版本: $kernel_version"
    
    return 0
}

# 检查权限
check_permissions() {
    bootstrap_log "INFO" "检查权限..."
    
    # 检查root权限
    if [[ $EUID -eq 0 ]]; then
        bootstrap_log "INFO" "以root权限运行"
        PERMISSION_CHECKS+=("root:pass")
    else
        bootstrap_log "WARN" "非root权限运行，某些功能可能受限"
        PERMISSION_CHECKS+=("root:warn")
        
        # 检查sudo权限
        if sudo -n true 2>/dev/null; then
            bootstrap_log "INFO" "检测到sudo权限"
            PERMISSION_CHECKS+=("sudo:pass")
        else
            bootstrap_log "ERROR" "需要root或sudo权限"
            PERMISSION_CHECKS+=("sudo:fail")
            return 1
        fi
    fi
    
    # 检查关键目录权限
    local dirs=("/usr/local/bin" "/etc" "/var/lib" "/var/log")
    for dir in "${dirs[@]}"; do
        if [[ -w "$dir" ]] || sudo test -w "$dir" 2>/dev/null; then
            bootstrap_log "DEBUG" "目录 $dir 可写"
        else
            bootstrap_log "WARN" "目录 $dir 不可写"
        fi
    done
    
    return 0
}

# 检查必需命令
check_required_commands() {
    bootstrap_log "INFO" "检查必需命令..."
    
    local missing_commands=()
    
    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            bootstrap_log "DEBUG" "命令 $cmd 可用"
            ENVIRONMENT_CHECKS+=("cmd_$cmd:pass")
        else
            bootstrap_log "WARN" "命令 $cmd 不可用"
            missing_commands+=("$cmd")
            ENVIRONMENT_CHECKS+=("cmd_$cmd:fail")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        bootstrap_log "WARN" "缺少命令: ${missing_commands[*]}"
        bootstrap_log "INFO" "将尝试自动安装缺少的依赖"
        return 1
    fi
    
    return 0
}

# 检查网络连接
check_network_connectivity() {
    bootstrap_log "INFO" "检查网络连接..."
    
    local test_hosts=("8.8.8.8" "1.1.1.1" "github.com")
    local connected=false
    
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 3 "$host" >/dev/null 2>&1; then
            bootstrap_log "INFO" "网络连接正常 ($host)"
            ENVIRONMENT_CHECKS+=("network:pass")
            connected=true
            break
        fi
    done
    
    if [[ "$connected" == "false" ]]; then
        bootstrap_log "WARN" "网络连接异常，某些功能可能受限"
        ENVIRONMENT_CHECKS+=("network:fail")
        return 1
    fi
    
    return 0
}

# 检查磁盘空间
check_disk_space() {
    bootstrap_log "INFO" "检查磁盘空间..."
    
    local required_space=1048576  # 1GB in KB
    local available_space
    
    available_space=$(df /tmp | awk 'NR==2 {print $4}')
    
    if [[ "$available_space" -gt "$required_space" ]]; then
        bootstrap_log "INFO" "磁盘空间充足: $(($available_space / 1024))MB 可用"
        ENVIRONMENT_CHECKS+=("disk_space:pass")
    else
        bootstrap_log "WARN" "磁盘空间不足: $(($available_space / 1024))MB 可用，建议至少1GB"
        ENVIRONMENT_CHECKS+=("disk_space:warn")
    fi
    
    return 0
}

# 生成环境报告
generate_environment_report() {
    bootstrap_log "INFO" "生成环境报告..."
    
    echo "=== 系统环境报告 ==="
    echo "引导模块版本: $BOOTSTRAP_VERSION"
    echo "检查时间: $(date)"
    echo ""
    
    echo "系统信息:"
    for info in "${SYSTEM_INFO[@]}"; do
        echo "  ${info//:/ = }"
    done
    echo ""
    
    echo "环境检查:"
    local pass_count=0
    local warn_count=0
    local fail_count=0
    
    for check in "${ENVIRONMENT_CHECKS[@]}"; do
        local name="${check%%:*}"
        local status="${check##*:}"
        
        case "$status" in
            "pass")
                echo -e "  \033[32m✓\033[0m $name"
                ((pass_count++))
                ;;
            "warn")
                echo -e "  \033[33m⚠\033[0m $name"
                ((warn_count++))
                ;;
            "fail")
                echo -e "  \033[31m✗\033[0m $name"
                ((fail_count++))
                ;;
        esac
    done
    
    echo ""
    echo "权限检查:"
    for check in "${PERMISSION_CHECKS[@]}"; do
        local name="${check%%:*}"
        local status="${check##*:}"
        
        case "$status" in
            "pass")
                echo -e "  \033[32m✓\033[0m $name"
                ;;
            "warn")
                echo -e "  \033[33m⚠\033[0m $name"
                ;;
            "fail")
                echo -e "  \033[31m✗\033[0m $name"
                ;;
        esac
    done
    
    echo ""
    echo "检查总结: $pass_count 通过, $warn_count 警告, $fail_count 失败"
    
    # 返回状态码
    if [[ $fail_count -gt 0 ]]; then
        return 1
    elif [[ $warn_count -gt 0 ]]; then
        return 2
    else
        return 0
    fi
}

# 主引导函数
bootstrap_system() {
    bootstrap_log "INFO" "开始系统引导检查..."
    
    local checks_passed=true
    
    # 执行所有检查
    check_bash_version || checks_passed=false
    check_system_compatibility || true  # 系统兼容性检查不阻断
    check_permissions || checks_passed=false
    check_required_commands || true  # 命令检查不阻断，后续会尝试安装
    check_network_connectivity || true  # 网络检查不阻断
    check_disk_space || true  # 磁盘空间检查不阻断
    
    # 生成报告
    local report_status
    generate_environment_report
    report_status=$?
    
    if [[ "$checks_passed" == "false" ]]; then
        bootstrap_log "ERROR" "关键检查失败，无法继续"
        return 1
    elif [[ $report_status -eq 2 ]]; then
        bootstrap_log "WARN" "存在警告，但可以继续"
        return 0
    else
        bootstrap_log "INFO" "所有检查通过，系统就绪"
        return 0
    fi
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    bootstrap_system
fi