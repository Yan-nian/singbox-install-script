#!/bin/bash

# =============================================================================
# 错误处理模块
# 版本: v2.4.3
# 功能: 提供统一的错误处理机制和错误码体系
# =============================================================================

# 错误码定义
declare -A ERROR_CODES=(
    # 配置相关错误 (1000-1099)
    ["CONFIG_NOT_FOUND"]=1001
    ["CONFIG_INVALID"]=1002
    ["CONFIG_PARSE_ERROR"]=1003
    ["CONFIG_BACKUP_FAILED"]=1004
    ["CONFIG_RESTORE_FAILED"]=1005
    
    # 网络相关错误 (1100-1199)
    ["PORT_OCCUPIED"]=1101
    ["PORT_INVALID"]=1102
    ["NETWORK_UNREACHABLE"]=1103
    ["CONNECTION_FAILED"]=1104
    ["DNS_RESOLUTION_FAILED"]=1105
    
    # 证书相关错误 (1200-1299)
    ["CERT_NOT_FOUND"]=1201
    ["CERT_INVALID"]=1202
    ["CERT_EXPIRED"]=1203
    ["CERT_GENERATION_FAILED"]=1204
    
    # 服务相关错误 (1300-1399)
    ["SERVICE_START_FAILED"]=1301
    ["SERVICE_STOP_FAILED"]=1302
    ["SERVICE_NOT_RUNNING"]=1303
    ["SERVICE_ALREADY_RUNNING"]=1304
    
    # 系统相关错误 (1400-1499)
    ["PERMISSION_DENIED"]=1401
    ["DISK_SPACE_INSUFFICIENT"]=1402
    ["DEPENDENCY_MISSING"]=1403
    ["SYSTEM_UNSUPPORTED"]=1404
    
    # 参数相关错误 (1500-1599)
    ["INVALID_PARAM"]=1501
    ["MISSING_PARAM"]=1502
    ["PARAM_OUT_OF_RANGE"]=1503
    
    # 文件操作错误 (1600-1699)
    ["FILE_NOT_FOUND"]=1601
    ["FILE_PERMISSION_DENIED"]=1602
    ["FILE_WRITE_FAILED"]=1603
    ["FILE_READ_FAILED"]=1604
    ["DIRECTORY_CREATE_FAILED"]=1605
)

# 错误消息映射
declare -A ERROR_MESSAGES=(
    [1001]="配置文件未找到"
    [1002]="配置文件格式无效"
    [1003]="配置文件解析失败"
    [1004]="配置文件备份失败"
    [1005]="配置文件恢复失败"
    
    [1101]="端口已被占用"
    [1102]="端口号无效"
    [1103]="网络不可达"
    [1104]="连接失败"
    [1105]="DNS解析失败"
    
    [1201]="证书文件未找到"
    [1202]="证书格式无效"
    [1203]="证书已过期"
    [1204]="证书生成失败"
    
    [1301]="服务启动失败"
    [1302]="服务停止失败"
    [1303]="服务未运行"
    [1304]="服务已在运行"
    
    [1401]="权限不足"
    [1402]="磁盘空间不足"
    [1403]="缺少必要依赖"
    [1404]="系统不支持"
    
    [1501]="参数无效"
    [1502]="缺少必要参数"
    [1503]="参数超出范围"
    
    [1601]="文件未找到"
    [1602]="文件权限不足"
    [1603]="文件写入失败"
    [1604]="文件读取失败"
    [1605]="目录创建失败"
)

# 错误处理函数
handle_error() {
    local error_code=$1
    local custom_msg="$2"
    local context="$3"
    local exit_flag=${4:-true}
    
    # 获取错误消息
    local error_msg="${ERROR_MESSAGES[$error_code]:-未知错误}"
    
    # 如果提供了自定义消息，则使用自定义消息
    if [[ -n "$custom_msg" ]]; then
        error_msg="$custom_msg"
    fi
    
    # 构建完整错误信息
    local full_msg="[错误码: $error_code] $error_msg"
    if [[ -n "$context" ]]; then
        full_msg="$full_msg - 上下文: $context"
    fi
    
    # 记录错误日志
    if command -v log_error >/dev/null 2>&1; then
        log_error "$full_msg"
    else
        echo -e "\033[31m[ERROR] $full_msg\033[0m" >&2
    fi
    
    # 提供解决建议
    suggest_solution "$error_code" "$context"
    
    # 是否退出程序
    if [[ "$exit_flag" == "true" ]]; then
        exit "$error_code"
    fi
    
    return "$error_code"
}

# 解决方案建议
suggest_solution() {
    local error_code=$1
    local context="$2"
    
    case $error_code in
        ${ERROR_CODES["CONFIG_NOT_FOUND"]})
            echo "建议: 请检查配置文件路径是否正确，或运行初始化命令重新生成配置"
            ;;
        ${ERROR_CODES["PORT_OCCUPIED"]})
            echo "建议: 请选择其他端口，或停止占用该端口的进程"
            if [[ -n "$context" ]]; then
                echo "可以使用命令查看端口占用: netstat -tuln | grep $context"
            fi
            ;;
        ${ERROR_CODES["CERT_EXPIRED"]})
            echo "建议: 请更新证书或重新生成证书"
            ;;
        ${ERROR_CODES["SERVICE_START_FAILED"]})
            echo "建议: 请检查配置文件是否正确，查看服务日志获取详细信息"
            ;;
        ${ERROR_CODES["PERMISSION_DENIED"]})
            echo "建议: 请使用 sudo 权限运行，或检查文件权限设置"
            ;;
        ${ERROR_CODES["DEPENDENCY_MISSING"]})
            echo "建议: 请安装缺少的依赖包，或运行依赖检查命令"
            ;;
        *)
            echo "建议: 请查看日志文件获取更多信息，或联系技术支持"
            ;;
    esac
}

# 错误码查询函数
get_error_code() {
    local error_name=$1
    echo "${ERROR_CODES[$error_name]:-0}"
}

# 错误消息查询函数
get_error_message() {
    local error_code=$1
    echo "${ERROR_MESSAGES[$error_code]:-未知错误}"
}

# 验证错误码是否有效
is_valid_error_code() {
    local error_code=$1
    [[ -n "${ERROR_MESSAGES[$error_code]}" ]]
}

# 警告处理函数
handle_warning() {
    local warning_msg="$1"
    local context="$2"
    
    local full_msg="[警告] $warning_msg"
    if [[ -n "$context" ]]; then
        full_msg="$full_msg - 上下文: $context"
    fi
    
    if command -v log_warn >/dev/null 2>&1; then
        log_warn "$full_msg"
    else
        echo -e "\033[33m[WARN] $full_msg\033[0m" >&2
    fi
}

# 成功消息处理函数
handle_success() {
    local success_msg="$1"
    local context="$2"
    
    local full_msg="[成功] $success_msg"
    if [[ -n "$context" ]]; then
        full_msg="$full_msg - $context"
    fi
    
    if command -v log_info >/dev/null 2>&1; then
        log_info "$full_msg"
    else
        echo -e "\033[32m[SUCCESS] $full_msg\033[0m"
    fi
}

# 尝试执行函数，捕获错误
try_execute() {
    local command="$1"
    local error_code="$2"
    local error_msg="$3"
    local context="$4"
    
    if ! eval "$command"; then
        handle_error "$error_code" "$error_msg" "$context"
        return $?
    fi
    
    return 0
}

# 安全执行函数（不退出程序）
safe_execute() {
    local command="$1"
    local error_code="$2"
    local error_msg="$3"
    local context="$4"
    
    if ! eval "$command"; then
        handle_error "$error_code" "$error_msg" "$context" false
        return $?
    fi
    
    return 0
}

# 导出函数供其他脚本使用
export -f handle_error
export -f handle_warning
export -f handle_success
export -f suggest_solution
export -f get_error_code
export -f get_error_message
export -f is_valid_error_code
export -f try_execute
export -f safe_execute

# 初始化错误处理模块
init_error_handler() {
    # 确保日志目录存在
    local log_dir="/var/log/singbox"
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" 2>/dev/null || true
    fi
    
    # 设置错误处理钩子
    set -E
    trap 'handle_error 9999 "脚本执行异常" "行号: $LINENO"' ERR
}

# 如果直接运行此脚本，则进行测试
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "错误处理模块测试"
    echo "=================="
    
    # 测试错误码查询
    echo "测试错误码查询:"
    echo "CONFIG_NOT_FOUND: $(get_error_code "CONFIG_NOT_FOUND")"
    echo "PORT_OCCUPIED: $(get_error_code "PORT_OCCUPIED")"
    
    # 测试错误消息查询
    echo "\n测试错误消息查询:"
    echo "1001: $(get_error_message 1001)"
    echo "1101: $(get_error_message 1101)"
    
    # 测试警告处理
    echo "\n测试警告处理:"
    handle_warning "这是一个测试警告" "测试上下文"
    
    # 测试成功消息
    echo "\n测试成功消息:"
    handle_success "测试成功" "所有功能正常"
    
    echo "\n错误处理模块测试完成"
fi