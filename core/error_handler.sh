#!/bin/bash

# 错误处理模块
# 提供统一的错误码体系、异常处理和错误恢复机制
# 版本: v2.4.14

set -euo pipefail

# 错误处理模块信息
ERROR_HANDLER_VERSION="v2.4.14"
ERROR_LOG_FILE="${SINGBOX_LOG_DIR:-/var/log/singbox}/error.log"
ERROR_RECOVERY_ENABLED="${ERROR_RECOVERY:-true}"

# 错误码定义
declare -A ERROR_CODES=(
    # 系统错误 (1-99)
    ["SYSTEM_PERMISSION_DENIED"]="1"
    ["SYSTEM_COMMAND_NOT_FOUND"]="2"
    ["SYSTEM_NETWORK_ERROR"]="3"
    ["SYSTEM_DISK_FULL"]="4"
    ["SYSTEM_MEMORY_ERROR"]="5"
    ["SYSTEM_ARCH_UNSUPPORTED"]="6"
    ["SYSTEM_OS_UNSUPPORTED"]="7"
    
    # 配置错误 (100-199)
    ["CONFIG_FILE_NOT_FOUND"]="100"
    ["CONFIG_SYNTAX_ERROR"]="101"
    ["CONFIG_VALIDATION_FAILED"]="102"
    ["CONFIG_BACKUP_FAILED"]="103"
    ["CONFIG_RESTORE_FAILED"]="104"
    ["CONFIG_TEMPLATE_ERROR"]="105"
    ["CONFIG_PERMISSION_ERROR"]="106"
    
    # 安装错误 (200-299)
    ["INSTALL_DOWNLOAD_FAILED"]="200"
    ["INSTALL_CHECKSUM_FAILED"]="201"
    ["INSTALL_EXTRACT_FAILED"]="202"
    ["INSTALL_BINARY_FAILED"]="203"
    ["INSTALL_SERVICE_FAILED"]="204"
    ["INSTALL_DEPENDENCY_FAILED"]="205"
    ["INSTALL_ALREADY_EXISTS"]="206"
    
    # 服务错误 (300-399)
    ["SERVICE_START_FAILED"]="300"
    ["SERVICE_STOP_FAILED"]="301"
    ["SERVICE_RESTART_FAILED"]="302"
    ["SERVICE_STATUS_ERROR"]="303"
    ["SERVICE_NOT_FOUND"]="304"
    ["SERVICE_TIMEOUT"]="305"
    ["SERVICE_CONFIG_ERROR"]="306"
    
    # 协议错误 (400-499)
    ["PROTOCOL_INVALID_TYPE"]="400"
    ["PROTOCOL_CONFIG_ERROR"]="401"
    ["PROTOCOL_CERT_ERROR"]="402"
    ["PROTOCOL_KEY_ERROR"]="403"
    ["PROTOCOL_PORT_ERROR"]="404"
    ["PROTOCOL_VALIDATION_FAILED"]="405"
    
    # 网络错误 (500-599)
    ["NETWORK_CONNECTION_FAILED"]="500"
    ["NETWORK_DNS_ERROR"]="501"
    ["NETWORK_TIMEOUT"]="502"
    ["NETWORK_PORT_OCCUPIED"]="503"
    ["NETWORK_FIREWALL_BLOCKED"]="504"
    ["NETWORK_PROXY_ERROR"]="505"
    
    # 用户错误 (600-699)
    ["USER_INPUT_INVALID"]="600"
    ["USER_CANCELLED"]="601"
    ["USER_PERMISSION_DENIED"]="602"
    ["USER_OPERATION_FAILED"]="603"
    
    # 内部错误 (700-799)
    ["INTERNAL_FUNCTION_ERROR"]="700"
    ["INTERNAL_VARIABLE_ERROR"]="701"
    ["INTERNAL_LOGIC_ERROR"]="702"
    ["INTERNAL_RESOURCE_ERROR"]="703"
    ["INTERNAL_STATE_ERROR"]="704"
)

# 错误消息定义
declare -A ERROR_MESSAGES=(
    # 系统错误消息
    ["1"]="权限不足，请使用root权限或sudo运行"
    ["2"]="系统命令未找到，请检查依赖安装"
    ["3"]="网络连接失败，请检查网络设置"
    ["4"]="磁盘空间不足，请清理磁盘空间"
    ["5"]="内存不足，请释放内存或增加交换空间"
    ["6"]="不支持的系统架构"
    ["7"]="不支持的操作系统"
    
    # 配置错误消息
    ["100"]="配置文件未找到"
    ["101"]="配置文件语法错误"
    ["102"]="配置验证失败"
    ["103"]="配置备份失败"
    ["104"]="配置恢复失败"
    ["105"]="配置模板错误"
    ["106"]="配置文件权限错误"
    
    # 安装错误消息
    ["200"]="下载失败，请检查网络连接"
    ["201"]="文件校验失败，可能文件已损坏"
    ["202"]="文件解压失败"
    ["203"]="二进制文件安装失败"
    ["204"]="系统服务创建失败"
    ["205"]="依赖安装失败"
    ["206"]="程序已存在，请先卸载"
    
    # 服务错误消息
    ["300"]="服务启动失败"
    ["301"]="服务停止失败"
    ["302"]="服务重启失败"
    ["303"]="获取服务状态失败"
    ["304"]="服务未找到"
    ["305"]="服务操作超时"
    ["306"]="服务配置错误"
    
    # 协议错误消息
    ["400"]="无效的协议类型"
    ["401"]="协议配置错误"
    ["402"]="证书错误"
    ["403"]="密钥错误"
    ["404"]="端口配置错误"
    ["405"]="协议验证失败"
    
    # 网络错误消息
    ["500"]="网络连接失败"
    ["501"]="DNS解析错误"
    ["502"]="网络超时"
    ["503"]="端口已被占用"
    ["504"]="防火墙阻止连接"
    ["505"]="代理配置错误"
    
    # 用户错误消息
    ["600"]="用户输入无效"
    ["601"]="用户取消操作"
    ["602"]="用户权限不足"
    ["603"]="用户操作失败"
    
    # 内部错误消息
    ["700"]="内部函数错误"
    ["701"]="内部变量错误"
    ["702"]="内部逻辑错误"
    ["703"]="内部资源错误"
    ["704"]="内部状态错误"
)

# 错误恢复策略
declare -A ERROR_RECOVERY_STRATEGIES=(
    ["1"]="check_sudo_permissions"
    ["2"]="install_missing_dependencies"
    ["3"]="retry_network_operation"
    ["4"]="cleanup_disk_space"
    ["100"]="create_default_config"
    ["101"]="restore_config_backup"
    ["200"]="retry_download_with_mirror"
    ["300"]="restart_service_with_delay"
    ["503"]="find_alternative_port"
)

# 错误统计
declare -A ERROR_STATS=(
    ["total_errors"]="0"
    ["recovered_errors"]="0"
    ["fatal_errors"]="0"
)

# 初始化错误处理
init_error_handler() {
    # 创建错误日志目录
    local log_dir="$(dirname "$ERROR_LOG_FILE")"
    [[ ! -d "$log_dir" ]] && mkdir -p "$log_dir"
    
    # 设置错误陷阱
    trap 'handle_unexpected_error $? $LINENO $BASH_LINENO "$BASH_COMMAND" "${FUNCNAME[*]}"' ERR
    trap 'handle_exit_cleanup' EXIT
    
    # 记录初始化
    log_error "INFO" "错误处理模块已初始化 (版本: $ERROR_HANDLER_VERSION)"
}

# 记录错误日志
log_error() {
    local level="$1"
    local message="$2"
    local error_code="${3:-}"
    local context="${4:-}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 构建日志条目
    local log_entry="[$timestamp] [$level]"
    [[ -n "$error_code" ]] && log_entry+=" [CODE:$error_code]"
    [[ -n "$context" ]] && log_entry+=" [CONTEXT:$context]"
    log_entry+=" $message"
    
    # 写入日志文件
    echo "$log_entry" >> "$ERROR_LOG_FILE"
    
    # 控制台输出
    case "$level" in
        "ERROR")
            echo -e "\033[31m[ERROR] $message\033[0m" >&2
            ;;
        "WARN")
            echo -e "\033[33m[WARN] $message\033[0m" >&2
            ;;
        "INFO")
            echo -e "\033[32m[INFO] $message\033[0m"
            ;;
        "DEBUG")
            [[ "${DEBUG:-}" == "true" ]] && echo -e "\033[36m[DEBUG] $message\033[0m" >&2
            ;;
    esac
}

# 抛出错误
throw_error() {
    local error_name="$1"
    local context="${2:-}"
    local additional_info="${3:-}"
    
    local error_code="${ERROR_CODES[$error_name]:-999}"
    local error_message="${ERROR_MESSAGES[$error_code]:-未知错误}"
    
    # 添加附加信息
    [[ -n "$additional_info" ]] && error_message+=" ($additional_info)"
    
    # 更新错误统计
    ((ERROR_STATS["total_errors"]++))
    
    # 记录错误
    log_error "ERROR" "$error_message" "$error_code" "$context"
    
    # 尝试错误恢复
    if [[ "$ERROR_RECOVERY_ENABLED" == "true" ]] && [[ -n "${ERROR_RECOVERY_STRATEGIES[$error_code]:-}" ]]; then
        local recovery_function="${ERROR_RECOVERY_STRATEGIES[$error_code]}"
        log_error "INFO" "尝试错误恢复: $recovery_function"
        
        if "$recovery_function" "$error_code" "$context" "$additional_info"; then
            ((ERROR_STATS["recovered_errors"]++))
            log_error "INFO" "错误恢复成功"
            return 0
        else
            log_error "WARN" "错误恢复失败"
        fi
    fi
    
    # 检查是否为致命错误
    if [[ "$error_code" -lt 100 ]] || [[ "$error_code" -ge 700 ]]; then
        ((ERROR_STATS["fatal_errors"]++))
        log_error "ERROR" "致命错误，程序退出"
        exit "$error_code"
    fi
    
    return "$error_code"
}

# 处理意外错误
handle_unexpected_error() {
    local exit_code="$1"
    local line_number="$2"
    local bash_lineno="$3"
    local command="$4"
    local function_stack="$5"
    
    log_error "ERROR" "意外错误" "$exit_code" "行号:$line_number 命令:'$command' 函数栈:$function_stack"
    
    # 生成错误报告
    generate_error_report "$exit_code" "$line_number" "$command" "$function_stack"
    
    exit "$exit_code"
}

# 退出清理
handle_exit_cleanup() {
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "INFO" "程序异常退出 (退出码: $exit_code)"
        show_error_summary
    fi
}

# 生成错误报告
generate_error_report() {
    local exit_code="$1"
    local line_number="$2"
    local command="$3"
    local function_stack="$4"
    
    local report_file="${ERROR_LOG_FILE%.log}_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
=== Sing-box 错误报告 ===
生成时间: $(date)
错误处理模块版本: $ERROR_HANDLER_VERSION

错误信息:
  退出码: $exit_code
  行号: $line_number
  命令: $command
  函数栈: $function_stack

系统信息:
  操作系统: $(uname -s)
  架构: $(uname -m)
  内核版本: $(uname -r)
  Bash版本: $BASH_VERSION

错误统计:
  总错误数: ${ERROR_STATS["total_errors"]}
  已恢复错误: ${ERROR_STATS["recovered_errors"]}
  致命错误: ${ERROR_STATS["fatal_errors"]}

最近错误日志:
EOF
    
    # 添加最近的错误日志
    if [[ -f "$ERROR_LOG_FILE" ]]; then
        tail -20 "$ERROR_LOG_FILE" >> "$report_file"
    fi
    
    log_error "INFO" "错误报告已生成: $report_file"
}

# 显示错误摘要
show_error_summary() {
    echo -e "\n\033[31m=== 错误摘要 ===\033[0m"
    echo "总错误数: ${ERROR_STATS["total_errors"]}"
    echo "已恢复错误: ${ERROR_STATS["recovered_errors"]}"
    echo "致命错误: ${ERROR_STATS["fatal_errors"]}"
    echo "错误日志: $ERROR_LOG_FILE"
    echo -e "\033[33m建议查看错误日志获取详细信息\033[0m"
}

# 错误恢复函数
check_sudo_permissions() {
    if sudo -n true 2>/dev/null; then
        return 0
    else
        log_error "WARN" "需要sudo权限，请手动输入密码"
        return 1
    fi
}

install_missing_dependencies() {
    local error_code="$1"
    log_error "INFO" "尝试安装缺失的依赖"
    
    # 这里应该调用依赖安装函数
    # install_dependencies
    return 1  # 暂时返回失败
}

retry_network_operation() {
    local error_code="$1"
    local context="$2"
    local max_retries=3
    local retry_delay=5
    
    log_error "INFO" "网络操作重试 (最多 $max_retries 次)"
    
    for ((i=1; i<=max_retries; i++)); do
        log_error "INFO" "第 $i 次重试..."
        sleep "$retry_delay"
        
        # 这里应该重新执行失败的网络操作
        # 暂时返回失败
        if [[ $i -eq $max_retries ]]; then
            return 1
        fi
    done
}

cleanup_disk_space() {
    log_error "INFO" "尝试清理磁盘空间"
    
    # 清理临时文件
    rm -rf /tmp/singbox_* 2>/dev/null || true
    
    # 清理日志文件
    find "$(dirname "$ERROR_LOG_FILE")" -name "*.log" -mtime +7 -delete 2>/dev/null || true
    
    return 0
}

create_default_config() {
    log_error "INFO" "创建默认配置文件"
    # 这里应该调用配置创建函数
    return 1  # 暂时返回失败
}

restore_config_backup() {
    log_error "INFO" "尝试恢复配置备份"
    # 这里应该调用配置恢复函数
    return 1  # 暂时返回失败
}

retry_download_with_mirror() {
    log_error "INFO" "尝试使用镜像源重新下载"
    # 这里应该调用镜像下载函数
    return 1  # 暂时返回失败
}

restart_service_with_delay() {
    local error_code="$1"
    log_error "INFO" "延迟重启服务"
    
    sleep 5
    # 这里应该调用服务重启函数
    return 1  # 暂时返回失败
}

find_alternative_port() {
    log_error "INFO" "寻找可用端口"
    # 这里应该调用端口查找函数
    return 1  # 暂时返回失败
}

# 验证错误处理模块
validate_error_handler() {
    log_error "INFO" "验证错误处理模块"
    
    # 检查错误码完整性
    local missing_codes=()
    for code in "${!ERROR_CODES[@]}"; do
        local error_code="${ERROR_CODES[$code]}"
        if [[ -z "${ERROR_MESSAGES[$error_code]:-}" ]]; then
            missing_codes+=("$error_code")
        fi
    done
    
    if [[ ${#missing_codes[@]} -gt 0 ]]; then
        log_error "WARN" "缺少错误消息定义: ${missing_codes[*]}"
    fi
    
    log_error "INFO" "错误处理模块验证完成"
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_error_handler
    validate_error_handler
fi