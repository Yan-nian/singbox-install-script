#!/bin/bash

# 日志系统模块
# 提供统一的日志记录、日志轮转、日志分析功能
# 版本: v2.4.14

set -euo pipefail

# 日志系统信息
LOGGER_VERSION="v2.4.14"
LOG_BASE_DIR="${SINGBOX_LOG_DIR:-/var/log/singbox}"
LOG_CONFIG_FILE="${LOG_BASE_DIR}/logger.conf"
LOG_ROTATION_ENABLED="${LOG_ROTATION:-true}"
LOG_COMPRESSION_ENABLED="${LOG_COMPRESSION:-true}"

# 日志级别定义
declare -A LOG_LEVELS=(
    ["TRACE"]="0"
    ["DEBUG"]="1"
    ["INFO"]="2"
    ["WARN"]="3"
    ["ERROR"]="4"
    ["FATAL"]="5"
)

# 日志级别颜色
declare -A LOG_COLORS=(
    ["TRACE"]="\033[90m"    # 灰色
    ["DEBUG"]="\033[36m"    # 青色
    ["INFO"]="\033[32m"     # 绿色
    ["WARN"]="\033[33m"     # 黄色
    ["ERROR"]="\033[31m"    # 红色
    ["FATAL"]="\033[35m"    # 紫色
    ["RESET"]="\033[0m"     # 重置
)

# 日志配置
LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_FORMAT="${LOG_FORMAT:-detailed}"
LOG_OUTPUT="${LOG_OUTPUT:-both}"  # file, console, both
LOG_MAX_SIZE="${LOG_MAX_SIZE:-10M}"
LOG_MAX_FILES="${LOG_MAX_FILES:-5}"
LOG_BUFFER_SIZE="${LOG_BUFFER_SIZE:-1000}"

# 日志文件定义
MAIN_LOG_FILE="${LOG_BASE_DIR}/singbox.log"
ERROR_LOG_FILE="${LOG_BASE_DIR}/error.log"
ACCESS_LOG_FILE="${LOG_BASE_DIR}/access.log"
AUDIT_LOG_FILE="${LOG_BASE_DIR}/audit.log"
DEBUG_LOG_FILE="${LOG_BASE_DIR}/debug.log"

# 日志缓冲区
declare -a LOG_BUFFER=()
LOG_BUFFER_COUNT=0

# 日志统计
declare -A LOG_STATS=(
    ["total_logs"]="0"
    ["trace_logs"]="0"
    ["debug_logs"]="0"
    ["info_logs"]="0"
    ["warn_logs"]="0"
    ["error_logs"]="0"
    ["fatal_logs"]="0"
)

# 初始化日志系统
init_logger() {
    # 创建日志目录
    [[ ! -d "$LOG_BASE_DIR" ]] && mkdir -p "$LOG_BASE_DIR"
    
    # 创建日志文件
    local log_files=("$MAIN_LOG_FILE" "$ERROR_LOG_FILE" "$ACCESS_LOG_FILE" "$AUDIT_LOG_FILE" "$DEBUG_LOG_FILE")
    for log_file in "${log_files[@]}"; do
        [[ ! -f "$log_file" ]] && touch "$log_file"
    done
    
    # 设置日志文件权限
    chmod 644 "${log_files[@]}"
    
    # 加载配置
    load_log_config
    
    # 设置信号处理
    trap 'flush_log_buffer' EXIT
    trap 'rotate_logs_signal' USR1
    
    # 记录初始化
    log_message "INFO" "日志系统已初始化 (版本: $LOGGER_VERSION)"
    log_message "DEBUG" "日志配置: 级别=$LOG_LEVEL, 格式=$LOG_FORMAT, 输出=$LOG_OUTPUT"
}

# 加载日志配置
load_log_config() {
    if [[ -f "$LOG_CONFIG_FILE" ]]; then
        source "$LOG_CONFIG_FILE"
        log_message "DEBUG" "已加载日志配置文件: $LOG_CONFIG_FILE"
    else
        create_default_log_config
    fi
}

# 创建默认日志配置
create_default_log_config() {
    cat > "$LOG_CONFIG_FILE" << EOF
# Sing-box 日志系统配置
# 版本: $LOGGER_VERSION

# 日志级别: TRACE, DEBUG, INFO, WARN, ERROR, FATAL
LOG_LEVEL="INFO"

# 日志格式: simple, detailed, json
LOG_FORMAT="detailed"

# 日志输出: file, console, both
LOG_OUTPUT="both"

# 日志轮转配置
LOG_ROTATION_ENABLED="true"
LOG_MAX_SIZE="10M"
LOG_MAX_FILES="5"
LOG_COMPRESSION_ENABLED="true"

# 日志缓冲配置
LOG_BUFFER_SIZE="1000"

# 特殊日志配置
ACCESS_LOG_ENABLED="true"
AUDIT_LOG_ENABLED="true"
DEBUG_LOG_ENABLED="false"

# 日志过滤配置
LOG_FILTER_PATTERNS=()
LOG_EXCLUDE_PATTERNS=()
EOF
    
    log_message "INFO" "已创建默认日志配置: $LOG_CONFIG_FILE"
}

# 获取时间戳
get_timestamp() {
    local format="${1:-iso}"
    
    case "$format" in
        "iso")
            date '+%Y-%m-%dT%H:%M:%S%z'
            ;;
        "simple")
            date '+%Y-%m-%d %H:%M:%S'
            ;;
        "epoch")
            date '+%s'
            ;;
        "nano")
            date '+%Y-%m-%dT%H:%M:%S.%N%z'
            ;;
        *)
            date '+%Y-%m-%d %H:%M:%S'
            ;;
    esac
}

# 获取调用者信息
get_caller_info() {
    local depth="${1:-2}"
    local caller_info="${BASH_SOURCE[$depth]:-unknown}:${BASH_LINENO[$((depth-1))]:-0}:${FUNCNAME[$depth]:-main}"
    echo "$caller_info"
}

# 格式化日志消息
format_log_message() {
    local level="$1"
    local message="$2"
    local component="${3:-main}"
    local context="${4:-}"
    
    local timestamp=$(get_timestamp)
    local caller_info=$(get_caller_info 3)
    local pid=$$
    local tid="${BASH_SUBSHELL:-0}"
    
    case "$LOG_FORMAT" in
        "simple")
            echo "[$timestamp] [$level] $message"
            ;;
        "detailed")
            local formatted="[$timestamp] [$level] [$component] [PID:$pid]"
            [[ -n "$context" ]] && formatted+=" [$context]"
            formatted+=" $message"
            [[ "$level" == "DEBUG" || "$level" == "TRACE" ]] && formatted+=" ($caller_info)"
            echo "$formatted"
            ;;
        "json")
            local json_msg="{"
            json_msg+="\"timestamp\":\"$timestamp\","
            json_msg+="\"level\":\"$level\","
            json_msg+="\"component\":\"$component\","
            json_msg+="\"pid\":$pid,"
            json_msg+="\"tid\":$tid,"
            json_msg+="\"message\":\"$(echo "$message" | sed 's/"/\\"/g')\","
            [[ -n "$context" ]] && json_msg+="\"context\":\"$context\","
            json_msg+="\"caller\":\"$caller_info\""
            json_msg+="}"
            echo "$json_msg"
            ;;
        *)
            echo "[$timestamp] [$level] $message"
            ;;
    esac
}

# 检查日志级别
should_log() {
    local level="$1"
    local current_level_num="${LOG_LEVELS[$LOG_LEVEL]:-2}"
    local message_level_num="${LOG_LEVELS[$level]:-2}"
    
    [[ $message_level_num -ge $current_level_num ]]
}

# 写入日志文件
write_to_log_file() {
    local level="$1"
    local formatted_message="$2"
    local log_file="$3"
    
    # 检查文件大小并轮转
    if [[ "$LOG_ROTATION_ENABLED" == "true" ]]; then
        check_and_rotate_log "$log_file"
    fi
    
    # 写入日志
    echo "$formatted_message" >> "$log_file"
    
    # 特殊级别的额外处理
    case "$level" in
        "ERROR"|"FATAL")
            echo "$formatted_message" >> "$ERROR_LOG_FILE"
            ;;
        "DEBUG"|"TRACE")
            [[ "${DEBUG_LOG_ENABLED:-false}" == "true" ]] && echo "$formatted_message" >> "$DEBUG_LOG_FILE"
            ;;
    esac
}

# 输出到控制台
write_to_console() {
    local level="$1"
    local message="$2"
    local formatted_message="$3"
    
    local color="${LOG_COLORS[$level]:-}"
    local reset="${LOG_COLORS[RESET]}"
    
    case "$level" in
        "ERROR"|"FATAL")
            echo -e "${color}${formatted_message}${reset}" >&2
            ;;
        *)
            echo -e "${color}${formatted_message}${reset}"
            ;;
    esac
}

# 添加到缓冲区
add_to_buffer() {
    local formatted_message="$1"
    
    LOG_BUFFER+=("$formatted_message")
    ((LOG_BUFFER_COUNT++))
    
    # 检查缓冲区大小
    if [[ $LOG_BUFFER_COUNT -ge $LOG_BUFFER_SIZE ]]; then
        flush_log_buffer
    fi
}

# 刷新日志缓冲区
flush_log_buffer() {
    if [[ $LOG_BUFFER_COUNT -gt 0 ]]; then
        for log_entry in "${LOG_BUFFER[@]}"; do
            echo "$log_entry" >> "$MAIN_LOG_FILE"
        done
        
        LOG_BUFFER=()
        LOG_BUFFER_COUNT=0
    fi
}

# 主日志函数
log_message() {
    local level="$1"
    local message="$2"
    local component="${3:-main}"
    local context="${4:-}"
    
    # 检查日志级别
    if ! should_log "$level"; then
        return 0
    fi
    
    # 更新统计
    ((LOG_STATS["total_logs"]++))
    local level_key="$(echo "$level" | tr '[:upper:]' '[:lower:]')_logs"
    [[ -n "${LOG_STATS[$level_key]:-}" ]] && ((LOG_STATS[$level_key]++))
    
    # 格式化消息
    local formatted_message
    formatted_message=$(format_log_message "$level" "$message" "$component" "$context")
    
    # 输出日志
    case "$LOG_OUTPUT" in
        "file")
            write_to_log_file "$level" "$formatted_message" "$MAIN_LOG_FILE"
            ;;
        "console")
            write_to_console "$level" "$message" "$formatted_message"
            ;;
        "both")
            write_to_log_file "$level" "$formatted_message" "$MAIN_LOG_FILE"
            write_to_console "$level" "$message" "$formatted_message"
            ;;
        "buffer")
            add_to_buffer "$formatted_message"
            ;;
    esac
}

# 便捷日志函数
log_trace() { log_message "TRACE" "$1" "${2:-main}" "${3:-}"; }
log_debug() { log_message "DEBUG" "$1" "${2:-main}" "${3:-}"; }
log_info() { log_message "INFO" "$1" "${2:-main}" "${3:-}"; }
log_warn() { log_message "WARN" "$1" "${2:-main}" "${3:-}"; }
log_error() { log_message "ERROR" "$1" "${2:-main}" "${3:-}"; }
log_fatal() { log_message "FATAL" "$1" "${2:-main}" "${3:-}"; }

# 特殊日志函数
log_access() {
    local method="$1"
    local url="$2"
    local status="$3"
    local size="${4:-0}"
    local user_agent="${5:-unknown}"
    local ip="${6:-unknown}"
    
    if [[ "${ACCESS_LOG_ENABLED:-true}" == "true" ]]; then
        local access_message="$ip - [$method] $url $status $size \"$user_agent\""
        local formatted_message
        formatted_message=$(format_log_message "INFO" "$access_message" "access")
        write_to_log_file "INFO" "$formatted_message" "$ACCESS_LOG_FILE"
    fi
}

log_audit() {
    local action="$1"
    local user="$2"
    local resource="$3"
    local result="$4"
    local details="${5:-}"
    
    if [[ "${AUDIT_LOG_ENABLED:-true}" == "true" ]]; then
        local audit_message="用户:$user 操作:$action 资源:$resource 结果:$result"
        [[ -n "$details" ]] && audit_message+=" 详情:$details"
        
        local formatted_message
        formatted_message=$(format_log_message "INFO" "$audit_message" "audit")
        write_to_log_file "INFO" "$formatted_message" "$AUDIT_LOG_FILE"
    fi
}

# 检查并轮转日志
check_and_rotate_log() {
    local log_file="$1"
    
    if [[ ! -f "$log_file" ]]; then
        return 0
    fi
    
    local file_size
    file_size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo 0)
    local max_size_bytes
    
    # 转换大小单位
    case "$LOG_MAX_SIZE" in
        *K|*k) max_size_bytes=$((${LOG_MAX_SIZE%[Kk]} * 1024)) ;;
        *M|*m) max_size_bytes=$((${LOG_MAX_SIZE%[Mm]} * 1024 * 1024)) ;;
        *G|*g) max_size_bytes=$((${LOG_MAX_SIZE%[Gg]} * 1024 * 1024 * 1024)) ;;
        *) max_size_bytes="$LOG_MAX_SIZE" ;;
    esac
    
    if [[ $file_size -gt $max_size_bytes ]]; then
        rotate_log_file "$log_file"
    fi
}

# 轮转日志文件
rotate_log_file() {
    local log_file="$1"
    local base_name="${log_file%.*}"
    local extension="${log_file##*.}"
    
    log_message "INFO" "轮转日志文件: $log_file"
    
    # 移动现有的轮转文件
    for ((i=$((LOG_MAX_FILES-1)); i>=1; i--)); do
        local old_file="${base_name}.${i}.${extension}"
        local new_file="${base_name}.$((i+1)).${extension}"
        
        if [[ -f "$old_file" ]]; then
            if [[ $i -eq $((LOG_MAX_FILES-1)) ]]; then
                rm -f "$old_file"
            else
                mv "$old_file" "$new_file"
            fi
        fi
    done
    
    # 轮转当前文件
    local rotated_file="${base_name}.1.${extension}"
    mv "$log_file" "$rotated_file"
    touch "$log_file"
    chmod 644 "$log_file"
    
    # 压缩轮转的文件
    if [[ "$LOG_COMPRESSION_ENABLED" == "true" ]] && command -v gzip >/dev/null 2>&1; then
        gzip "$rotated_file"
        log_message "DEBUG" "已压缩轮转文件: ${rotated_file}.gz"
    fi
}

# 信号处理：手动轮转日志
rotate_logs_signal() {
    log_message "INFO" "收到日志轮转信号，开始轮转所有日志文件"
    
    local log_files=("$MAIN_LOG_FILE" "$ERROR_LOG_FILE" "$ACCESS_LOG_FILE" "$AUDIT_LOG_FILE" "$DEBUG_LOG_FILE")
    for log_file in "${log_files[@]}"; do
        [[ -f "$log_file" ]] && rotate_log_file "$log_file"
    done
    
    log_message "INFO" "日志轮转完成"
}

# 清理旧日志
cleanup_old_logs() {
    local days="${1:-30}"
    
    log_message "INFO" "清理 $days 天前的日志文件"
    
    find "$LOG_BASE_DIR" -name "*.log.*" -mtime +"$days" -delete 2>/dev/null || true
    find "$LOG_BASE_DIR" -name "*.log.*.gz" -mtime +"$days" -delete 2>/dev/null || true
    
    log_message "INFO" "旧日志清理完成"
}

# 分析日志
analyze_logs() {
    local log_file="${1:-$MAIN_LOG_FILE}"
    local hours="${2:-24}"
    
    if [[ ! -f "$log_file" ]]; then
        log_error "日志文件不存在: $log_file"
        return 1
    fi
    
    log_message "INFO" "分析最近 $hours 小时的日志"
    
    # 计算时间范围
    local start_time
    start_time=$(date -d "$hours hours ago" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -v-"${hours}H" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
    
    echo "=== 日志分析报告 ==="
    echo "文件: $log_file"
    echo "时间范围: $start_time 至 $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # 统计各级别日志数量
    echo "日志级别统计:"
    for level in "ERROR" "WARN" "INFO" "DEBUG" "TRACE"; do
        local count
        count=$(grep -c "\[$level\]" "$log_file" 2>/dev/null || echo 0)
        printf "  %-8s: %d\n" "$level" "$count"
    done
    echo ""
    
    # 显示最近的错误
    echo "最近的错误 (最多10条):"
    grep "\[ERROR\]" "$log_file" | tail -10 || echo "  无错误记录"
    echo ""
    
    # 显示最近的警告
    echo "最近的警告 (最多5条):"
    grep "\[WARN\]" "$log_file" | tail -5 || echo "  无警告记录"
}

# 显示日志统计
show_log_stats() {
    echo "=== 日志统计 ==="
    echo "总日志数: ${LOG_STATS["total_logs"]}"
    echo "TRACE: ${LOG_STATS["trace_logs"]}"
    echo "DEBUG: ${LOG_STATS["debug_logs"]}"
    echo "INFO: ${LOG_STATS["info_logs"]}"
    echo "WARN: ${LOG_STATS["warn_logs"]}"
    echo "ERROR: ${LOG_STATS["error_logs"]}"
    echo "FATAL: ${LOG_STATS["fatal_logs"]}"
    echo ""
    echo "日志文件:"
    echo "  主日志: $MAIN_LOG_FILE"
    echo "  错误日志: $ERROR_LOG_FILE"
    echo "  访问日志: $ACCESS_LOG_FILE"
    echo "  审计日志: $AUDIT_LOG_FILE"
    echo "  调试日志: $DEBUG_LOG_FILE"
}

# 设置日志级别
set_log_level() {
    local new_level="$1"
    
    if [[ -n "${LOG_LEVELS[$new_level]:-}" ]]; then
        LOG_LEVEL="$new_level"
        log_message "INFO" "日志级别已设置为: $new_level"
    else
        log_error "无效的日志级别: $new_level"
        return 1
    fi
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_logger
    
    # 测试日志功能
    log_trace "这是一条TRACE日志"
    log_debug "这是一条DEBUG日志"
    log_info "这是一条INFO日志"
    log_warn "这是一条WARN日志"
    log_error "这是一条ERROR日志"
    
    show_log_stats
fi