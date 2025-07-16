#!/bin/bash

# =============================================================================
# 日志系统模块
# 版本: v2.4.3
# 功能: 提供完整的日志记录、管理和轮转功能
# =============================================================================

# 日志配置
LOG_LEVEL=${LOG_LEVEL:-"INFO"}
LOG_DIR=${LOG_DIR:-"/var/log/singbox"}
LOG_FILE="${LOG_DIR}/singbox.log"
ERROR_LOG_FILE="${LOG_DIR}/error.log"
DEBUG_LOG_FILE="${LOG_DIR}/debug.log"
MAX_LOG_SIZE=${MAX_LOG_SIZE:-10485760}  # 10MB
MAX_LOG_FILES=${MAX_LOG_FILES:-5}
LOG_DATE_FORMAT=${LOG_DATE_FORMAT:-"%Y-%m-%d %H:%M:%S"}

# 日志级别定义
declare -A LOG_LEVELS=(
    ["DEBUG"]=0
    ["INFO"]=1
    ["WARN"]=2
    ["ERROR"]=3
    ["FATAL"]=4
)

# 颜色定义
declare -A LOG_COLORS=(
    ["DEBUG"]="\033[36m"   # 青色
    ["INFO"]="\033[32m"    # 绿色
    ["WARN"]="\033[33m"    # 黄色
    ["ERROR"]="\033[31m"   # 红色
    ["FATAL"]="\033[35m"   # 紫色
    ["RESET"]="\033[0m"    # 重置
)

# 初始化日志系统
init_logger() {
    # 创建日志目录
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR" 2>/dev/null || {
            echo "警告: 无法创建日志目录 $LOG_DIR，使用临时目录" >&2
            LOG_DIR="/tmp/singbox_logs"
            mkdir -p "$LOG_DIR"
            LOG_FILE="${LOG_DIR}/singbox.log"
            ERROR_LOG_FILE="${LOG_DIR}/error.log"
            DEBUG_LOG_FILE="${LOG_DIR}/debug.log"
        }
    fi
    
    # 设置日志文件权限
    touch "$LOG_FILE" "$ERROR_LOG_FILE" "$DEBUG_LOG_FILE" 2>/dev/null || true
    chmod 644 "$LOG_FILE" "$ERROR_LOG_FILE" "$DEBUG_LOG_FILE" 2>/dev/null || true
    
    # 记录日志系统启动
    log_info "日志系统已初始化" "日志目录: $LOG_DIR"
}

# 获取当前日志级别数值
get_log_level_value() {
    echo "${LOG_LEVELS[$LOG_LEVEL]:-1}"
}

# 检查日志级别是否应该输出
should_log() {
    local level="$1"
    local current_level_value=$(get_log_level_value)
    local message_level_value="${LOG_LEVELS[$level]:-1}"
    
    [[ $message_level_value -ge $current_level_value ]]
}

# 核心日志记录函数
log_with_level() {
    local level="$1"
    local message="$2"
    local context="$3"
    local timestamp=$(date "+$LOG_DATE_FORMAT")
    local pid=$$
    
    # 检查是否应该记录此级别的日志
    if ! should_log "$level"; then
        return 0
    fi
    
    # 构建日志消息
    local log_message="[$timestamp] [$level] [PID:$pid] $message"
    if [[ -n "$context" ]]; then
        log_message="$log_message - $context"
    fi
    
    # 控制台输出（带颜色）
    if [[ -t 1 ]]; then  # 检查是否为终端
        local color="${LOG_COLORS[$level]}"
        local reset="${LOG_COLORS[RESET]}"
        echo -e "${color}${log_message}${reset}"
    else
        echo "$log_message"
    fi
    
    # 文件输出
    echo "$log_message" >> "$LOG_FILE" 2>/dev/null || true
    
    # 错误日志单独记录
    if [[ "$level" == "ERROR" || "$level" == "FATAL" ]]; then
        echo "$log_message" >> "$ERROR_LOG_FILE" 2>/dev/null || true
    fi
    
    # 调试日志单独记录
    if [[ "$level" == "DEBUG" ]]; then
        echo "$log_message" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
    fi
    
    # 检查日志轮转
    check_log_rotation
}

# 各级别日志函数
log_debug() {
    log_with_level "DEBUG" "$1" "$2"
}

log_info() {
    log_with_level "INFO" "$1" "$2"
}

log_warn() {
    log_with_level "WARN" "$1" "$2"
}

log_error() {
    log_with_level "ERROR" "$1" "$2"
}

log_fatal() {
    log_with_level "FATAL" "$1" "$2"
}

# 结构化日志记录
log_structured() {
    local level="$1"
    local event="$2"
    local data="$3"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # 构建JSON格式日志
    local json_log
    json_log=$(jq -n \
        --arg timestamp "$timestamp" \
        --arg level "$level" \
        --arg event "$event" \
        --arg data "$data" \
        --arg pid "$$" \
        '{
            timestamp: $timestamp,
            level: $level,
            event: $event,
            data: $data,
            pid: ($pid | tonumber)
        }')
    
    # 输出到结构化日志文件
    local structured_log_file="${LOG_DIR}/structured.log"
    echo "$json_log" >> "$structured_log_file" 2>/dev/null || true
    
    # 同时输出到标准日志
    log_with_level "$level" "$event" "$data"
}

# 性能日志记录
log_performance() {
    local operation="$1"
    local duration="$2"
    local details="$3"
    
    log_structured "INFO" "PERFORMANCE" "operation=$operation duration=${duration}ms details=$details"
}

# 审计日志记录
log_audit() {
    local action="$1"
    local user="${2:-$(whoami)}"
    local resource="$3"
    local result="$4"
    
    local audit_message="action=$action user=$user resource=$resource result=$result"
    log_structured "INFO" "AUDIT" "$audit_message"
    
    # 单独的审计日志文件
    local audit_log_file="${LOG_DIR}/audit.log"
    local timestamp=$(date "+$LOG_DATE_FORMAT")
    echo "[$timestamp] $audit_message" >> "$audit_log_file" 2>/dev/null || true
}

# 日志轮转检查
check_log_rotation() {
    local files=("$LOG_FILE" "$ERROR_LOG_FILE" "$DEBUG_LOG_FILE")
    
    for file in "${files[@]}"; do
        if [[ -f "$file" ]] && [[ $(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0) -gt $MAX_LOG_SIZE ]]; then
            rotate_log_file "$file"
        fi
    done
}

# 日志文件轮转
rotate_log_file() {
    local log_file="$1"
    local base_name=$(basename "$log_file")
    local dir_name=$(dirname "$log_file")
    
    # 移动现有的轮转文件
    for ((i=$MAX_LOG_FILES-1; i>=1; i--)); do
        local old_file="${dir_name}/${base_name}.${i}"
        local new_file="${dir_name}/${base_name}.$((i+1))"
        
        if [[ -f "$old_file" ]]; then
            if [[ $i -eq $((MAX_LOG_FILES-1)) ]]; then
                rm -f "$old_file"  # 删除最老的文件
            else
                mv "$old_file" "$new_file" 2>/dev/null || true
            fi
        fi
    done
    
    # 轮转当前日志文件
    if [[ -f "$log_file" ]]; then
        mv "$log_file" "${log_file}.1" 2>/dev/null || true
        touch "$log_file" 2>/dev/null || true
        chmod 644 "$log_file" 2>/dev/null || true
    fi
    
    log_info "日志文件已轮转" "文件: $log_file"
}

# 清理旧日志
cleanup_old_logs() {
    local days=${1:-7}  # 默认保留7天
    
    log_info "开始清理 $days 天前的日志文件"
    
    # 查找并删除旧日志文件
    find "$LOG_DIR" -name "*.log*" -type f -mtime +$days -delete 2>/dev/null || true
    
    log_info "旧日志文件清理完成"
}

# 获取日志统计信息
get_log_stats() {
    local stats_file="${LOG_DIR}/stats.json"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # 统计各级别日志数量
    local debug_count=0
    local info_count=0
    local warn_count=0
    local error_count=0
    local fatal_count=0
    
    if [[ -f "$LOG_FILE" ]]; then
        debug_count=$(grep -c "\[DEBUG\]" "$LOG_FILE" 2>/dev/null || echo 0)
        info_count=$(grep -c "\[INFO\]" "$LOG_FILE" 2>/dev/null || echo 0)
        warn_count=$(grep -c "\[WARN\]" "$LOG_FILE" 2>/dev/null || echo 0)
        error_count=$(grep -c "\[ERROR\]" "$LOG_FILE" 2>/dev/null || echo 0)
        fatal_count=$(grep -c "\[FATAL\]" "$LOG_FILE" 2>/dev/null || echo 0)
    fi
    
    # 获取日志文件大小
    local log_size=0
    if [[ -f "$LOG_FILE" ]]; then
        log_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
    fi
    
    # 生成统计JSON
    local stats_json
    stats_json=$(jq -n \
        --arg timestamp "$timestamp" \
        --arg debug "$debug_count" \
        --arg info "$info_count" \
        --arg warn "$warn_count" \
        --arg error "$error_count" \
        --arg fatal "$fatal_count" \
        --arg size "$log_size" \
        '{
            timestamp: $timestamp,
            counts: {
                debug: ($debug | tonumber),
                info: ($info | tonumber),
                warn: ($warn | tonumber),
                error: ($error | tonumber),
                fatal: ($fatal | tonumber)
            },
            log_file_size: ($size | tonumber)
        }')
    
    echo "$stats_json" > "$stats_file"
    echo "$stats_json"
}

# 设置日志级别
set_log_level() {
    local new_level="$1"
    
    if [[ -n "${LOG_LEVELS[$new_level]}" ]]; then
        LOG_LEVEL="$new_level"
        log_info "日志级别已设置为: $new_level"
    else
        log_error "无效的日志级别: $new_level" "有效级别: ${!LOG_LEVELS[*]}"
        return 1
    fi
}

# 监控日志文件变化
monitor_logs() {
    local follow_file="${1:-$LOG_FILE}"
    
    if [[ ! -f "$follow_file" ]]; then
        log_error "日志文件不存在: $follow_file"
        return 1
    fi
    
    log_info "开始监控日志文件: $follow_file"
    log_info "按 Ctrl+C 停止监控"
    
    tail -f "$follow_file"
}

# 搜索日志
search_logs() {
    local pattern="$1"
    local log_file="${2:-$LOG_FILE}"
    local lines="${3:-10}"
    
    if [[ ! -f "$log_file" ]]; then
        log_error "日志文件不存在: $log_file"
        return 1
    fi
    
    log_info "搜索模式: $pattern" "文件: $log_file"
    
    grep -n "$pattern" "$log_file" | tail -n "$lines"
}

# 导出函数
export -f init_logger
export -f log_debug
export -f log_info
export -f log_warn
export -f log_error
export -f log_fatal
export -f log_structured
export -f log_performance
export -f log_audit
export -f set_log_level
export -f get_log_stats
export -f cleanup_old_logs
export -f monitor_logs
export -f search_logs
export -f rotate_log_file

# 自动初始化（如果不是在测试模式）
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    init_logger
fi

# 如果直接运行此脚本，则进行测试
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "日志系统模块测试"
    echo "=================="
    
    # 初始化日志系统
    init_logger
    
    # 测试各级别日志
    echo "测试各级别日志记录:"
    log_debug "这是一条调试信息" "测试上下文"
    log_info "这是一条信息" "测试上下文"
    log_warn "这是一条警告" "测试上下文"
    log_error "这是一条错误" "测试上下文"
    
    # 测试结构化日志
    echo "\n测试结构化日志:"
    log_structured "INFO" "USER_LOGIN" "user=admin ip=192.168.1.1"
    
    # 测试性能日志
    echo "\n测试性能日志:"
    log_performance "config_load" "150" "file=/etc/singbox/config.json"
    
    # 测试审计日志
    echo "\n测试审计日志:"
    log_audit "CONFIG_UPDATE" "admin" "/etc/singbox/config.json" "SUCCESS"
    
    # 显示日志统计
    echo "\n日志统计信息:"
    get_log_stats | jq .
    
    echo "\n日志系统模块测试完成"
    echo "日志文件位置: $LOG_FILE"
fi