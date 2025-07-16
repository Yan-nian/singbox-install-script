#!/bin/bash

# 配置管理中心模块
# 提供统一的配置加载、验证、备份、恢复功能
# 版本: v2.4.14

set -euo pipefail

# 配置管理模块信息
CONFIG_MANAGER_VERSION="v2.4.14"
CONFIG_BASE_DIR="${SINGBOX_CONFIG_DIR:-/etc/singbox}"
CONFIG_BACKUP_DIR="${CONFIG_BASE_DIR}/backup"
CONFIG_TEMPLATE_DIR="${SINGBOX_TEMPLATE_DIR:-./templates}"
CONFIG_CACHE_DIR="${CONFIG_BASE_DIR}/cache"

# 配置文件定义
MAIN_CONFIG_FILE="${CONFIG_BASE_DIR}/config.json"
BASE_CONFIG_TEMPLATE="${CONFIG_TEMPLATE_DIR}/config-base.json"
CONFIG_SCHEMA_FILE="${CONFIG_TEMPLATE_DIR}/config-schema.json"
CONFIG_METADATA_FILE="${CONFIG_BASE_DIR}/metadata.json"

# 配置缓存
declare -A CONFIG_CACHE=()
CONFIG_CACHE_ENABLED="${CONFIG_CACHE_ENABLED:-true}"
CONFIG_CACHE_TTL="${CONFIG_CACHE_TTL:-300}"  # 5分钟

# 配置验证
CONFIG_VALIDATION_ENABLED="${CONFIG_VALIDATION:-true}"
CONFIG_STRICT_MODE="${CONFIG_STRICT_MODE:-false}"

# 配置备份
CONFIG_AUTO_BACKUP="${CONFIG_AUTO_BACKUP:-true}"
CONFIG_MAX_BACKUPS="${CONFIG_MAX_BACKUPS:-10}"
CONFIG_BACKUP_COMPRESSION="${CONFIG_BACKUP_COMPRESSION:-true}"

# 配置统计
declare -A CONFIG_STATS=(
    ["loads"]="0"
    ["saves"]="0"
    ["validations"]="0"
    ["backups"]="0"
    ["restores"]="0"
    ["cache_hits"]="0"
    ["cache_misses"]="0"
)

# 引入依赖模块
source "${BASH_SOURCE%/*}/../core/logger.sh" 2>/dev/null || {
    echo "警告: 无法加载日志模块，使用简单日志"
    log_info() { echo "[INFO] $1"; }
    log_warn() { echo "[WARN] $1" >&2; }
    log_error() { echo "[ERROR] $1" >&2; }
    log_debug() { [[ "${DEBUG:-}" == "true" ]] && echo "[DEBUG] $1" >&2; }
}

# 初始化配置管理器
init_config_manager() {
    log_info "初始化配置管理器 (版本: $CONFIG_MANAGER_VERSION)" "config"
    
    # 创建必要目录
    local dirs=("$CONFIG_BASE_DIR" "$CONFIG_BACKUP_DIR" "$CONFIG_CACHE_DIR")
    for dir in "${dirs[@]}"; do
        [[ ! -d "$dir" ]] && mkdir -p "$dir"
    done
    
    # 设置目录权限
    chmod 755 "$CONFIG_BASE_DIR"
    chmod 700 "$CONFIG_BACKUP_DIR"  # 备份目录更严格的权限
    chmod 755 "$CONFIG_CACHE_DIR"
    
    # 初始化配置元数据
    init_config_metadata
    
    # 验证模板文件
    validate_templates
    
    log_info "配置管理器初始化完成" "config"
}

# 初始化配置元数据
init_config_metadata() {
    if [[ ! -f "$CONFIG_METADATA_FILE" ]]; then
        cat > "$CONFIG_METADATA_FILE" << EOF
{
  "version": "$CONFIG_MANAGER_VERSION",
  "created": "$(date -Iseconds)",
  "last_modified": "$(date -Iseconds)",
  "config_version": "1.0.0",
  "backup_count": 0,
  "validation_enabled": $CONFIG_VALIDATION_ENABLED,
  "cache_enabled": $CONFIG_CACHE_ENABLED,
  "protocols": [],
  "last_backup": null,
  "checksum": null
}
EOF
        log_info "已创建配置元数据文件" "config"
    fi
}

# 验证模板文件
validate_templates() {
    log_debug "验证配置模板文件" "config"
    
    if [[ ! -f "$BASE_CONFIG_TEMPLATE" ]]; then
        log_error "基础配置模板不存在: $BASE_CONFIG_TEMPLATE" "config"
        return 1
    fi
    
    # 验证JSON格式
    if ! jq empty "$BASE_CONFIG_TEMPLATE" 2>/dev/null; then
        log_error "基础配置模板JSON格式错误" "config"
        return 1
    fi
    
    log_debug "配置模板验证通过" "config"
    return 0
}

# 生成配置缓存键
generate_cache_key() {
    local config_file="$1"
    local context="${2:-default}"
    
    local file_hash
    if [[ -f "$config_file" ]]; then
        file_hash=$(sha256sum "$config_file" | cut -d' ' -f1)
    else
        file_hash="nofile"
    fi
    
    echo "${context}_${file_hash}"
}

# 检查缓存有效性
is_cache_valid() {
    local cache_key="$1"
    local cache_entry="${CONFIG_CACHE[$cache_key]:-}"
    
    if [[ -z "$cache_entry" ]]; then
        return 1
    fi
    
    # 解析缓存条目 (格式: timestamp:data)
    local cache_timestamp="${cache_entry%%:*}"
    local current_timestamp=$(date +%s)
    
    if [[ $((current_timestamp - cache_timestamp)) -gt $CONFIG_CACHE_TTL ]]; then
        # 缓存过期
        unset CONFIG_CACHE["$cache_key"]
        return 1
    fi
    
    return 0
}

# 从缓存获取配置
get_from_cache() {
    local cache_key="$1"
    
    if [[ "$CONFIG_CACHE_ENABLED" != "true" ]]; then
        return 1
    fi
    
    if is_cache_valid "$cache_key"; then
        local cache_entry="${CONFIG_CACHE[$cache_key]}"
        local cache_data="${cache_entry#*:}"
        echo "$cache_data"
        ((CONFIG_STATS["cache_hits"]++))
        return 0
    else
        ((CONFIG_STATS["cache_misses"]++))
        return 1
    fi
}

# 保存到缓存
save_to_cache() {
    local cache_key="$1"
    local data="$2"
    
    if [[ "$CONFIG_CACHE_ENABLED" == "true" ]]; then
        local timestamp=$(date +%s)
        CONFIG_CACHE["$cache_key"]="${timestamp}:${data}"
        log_debug "配置已缓存: $cache_key" "config"
    fi
}

# 清理缓存
clear_cache() {
    local pattern="${1:-}"
    
    if [[ -n "$pattern" ]]; then
        # 清理匹配模式的缓存
        for key in "${!CONFIG_CACHE[@]}"; do
            if [[ "$key" == *"$pattern"* ]]; then
                unset CONFIG_CACHE["$key"]
                log_debug "已清理缓存: $key" "config"
            fi
        done
    else
        # 清理所有缓存
        CONFIG_CACHE=()
        log_info "已清理所有配置缓存" "config"
    fi
}

# 加载配置文件
load_config() {
    local config_file="${1:-$MAIN_CONFIG_FILE}"
    local use_cache="${2:-true}"
    
    log_debug "加载配置文件: $config_file" "config"
    ((CONFIG_STATS["loads"]++))
    
    # 检查文件是否存在
    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在: $config_file" "config"
        return 1
    fi
    
    # 尝试从缓存获取
    local cache_key
    cache_key=$(generate_cache_key "$config_file" "load")
    
    if [[ "$use_cache" == "true" ]]; then
        local cached_config
        if cached_config=$(get_from_cache "$cache_key"); then
            log_debug "从缓存加载配置" "config"
            echo "$cached_config"
            return 0
        fi
    fi
    
    # 从文件加载
    local config_content
    if ! config_content=$(cat "$config_file"); then
        log_error "读取配置文件失败: $config_file" "config"
        return 1
    fi
    
    # 验证JSON格式
    if ! echo "$config_content" | jq empty 2>/dev/null; then
        log_error "配置文件JSON格式错误: $config_file" "config"
        return 1
    fi
    
    # 保存到缓存
    save_to_cache "$cache_key" "$config_content"
    
    echo "$config_content"
    log_debug "配置文件加载成功" "config"
    return 0
}

# 保存配置文件
save_config() {
    local config_content="$1"
    local config_file="${2:-$MAIN_CONFIG_FILE}"
    local create_backup="${3:-$CONFIG_AUTO_BACKUP}"
    
    log_info "保存配置文件: $config_file" "config"
    ((CONFIG_STATS["saves"]++))
    
    # 验证JSON格式
    if ! echo "$config_content" | jq empty 2>/dev/null; then
        log_error "配置内容JSON格式错误" "config"
        return 1
    fi
    
    # 创建备份
    if [[ "$create_backup" == "true" ]] && [[ -f "$config_file" ]]; then
        if ! backup_config "$config_file"; then
            log_warn "配置备份失败，但继续保存" "config"
        fi
    fi
    
    # 创建临时文件
    local temp_file="${config_file}.tmp.$$"
    
    # 写入临时文件
    if ! echo "$config_content" | jq '.' > "$temp_file"; then
        log_error "写入临时配置文件失败" "config"
        rm -f "$temp_file"
        return 1
    fi
    
    # 原子性替换
    if ! mv "$temp_file" "$config_file"; then
        log_error "替换配置文件失败" "config"
        rm -f "$temp_file"
        return 1
    fi
    
    # 设置权限
    chmod 644 "$config_file"
    
    # 清理相关缓存
    clear_cache "$(basename "$config_file")"
    
    # 更新元数据
    update_config_metadata "$config_file"
    
    log_info "配置文件保存成功" "config"
    return 0
}

# 验证配置
validate_config() {
    local config_content="$1"
    local strict_mode="${2:-$CONFIG_STRICT_MODE}"
    
    log_debug "验证配置" "config"
    ((CONFIG_STATS["validations"]++))
    
    if [[ "$CONFIG_VALIDATION_ENABLED" != "true" ]]; then
        log_debug "配置验证已禁用" "config"
        return 0
    fi
    
    # 基础JSON格式验证
    if ! echo "$config_content" | jq empty 2>/dev/null; then
        log_error "配置JSON格式错误" "config"
        return 1
    fi
    
    # 必需字段验证
    local required_fields=("log" "dns" "inbounds" "outbounds")
    for field in "${required_fields[@]}"; do
        if ! echo "$config_content" | jq -e ".$field" >/dev/null 2>&1; then
            if [[ "$strict_mode" == "true" ]]; then
                log_error "缺少必需字段: $field" "config"
                return 1
            else
                log_warn "缺少推荐字段: $field" "config"
            fi
        fi
    done
    
    # 入站配置验证
    local inbound_count
    inbound_count=$(echo "$config_content" | jq '.inbounds | length' 2>/dev/null || echo 0)
    
    if [[ $inbound_count -eq 0 ]]; then
        if [[ "$strict_mode" == "true" ]]; then
            log_error "至少需要一个入站配置" "config"
            return 1
        else
            log_warn "没有配置入站连接" "config"
        fi
    fi
    
    # 出站配置验证
    local outbound_count
    outbound_count=$(echo "$config_content" | jq '.outbounds | length' 2>/dev/null || echo 0)
    
    if [[ $outbound_count -eq 0 ]]; then
        log_warn "没有配置出站连接" "config"
    fi
    
    # 端口冲突检查
    if ! check_port_conflicts "$config_content"; then
        if [[ "$strict_mode" == "true" ]]; then
            log_error "检测到端口冲突" "config"
            return 1
        else
            log_warn "检测到潜在端口冲突" "config"
        fi
    fi
    
    log_debug "配置验证通过" "config"
    return 0
}

# 检查端口冲突
check_port_conflicts() {
    local config_content="$1"
    
    # 提取所有监听端口
    local ports
    ports=$(echo "$config_content" | jq -r '.inbounds[]?.listen_port // empty' 2>/dev/null | sort -n)
    
    # 检查重复端口
    local prev_port=""
    while IFS= read -r port; do
        if [[ "$port" == "$prev_port" ]]; then
            log_error "端口冲突: $port" "config"
            return 1
        fi
        prev_port="$port"
    done <<< "$ports"
    
    return 0
}

# 备份配置
backup_config() {
    local config_file="${1:-$MAIN_CONFIG_FILE}"
    local backup_name="${2:-}"
    
    log_info "备份配置文件: $config_file" "config"
    ((CONFIG_STATS["backups"]++))
    
    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在，无法备份: $config_file" "config"
        return 1
    fi
    
    # 生成备份文件名
    if [[ -z "$backup_name" ]]; then
        backup_name="config_$(date +%Y%m%d_%H%M%S)"
    fi
    
    local backup_file="${CONFIG_BACKUP_DIR}/${backup_name}.json"
    
    # 复制文件
    if ! cp "$config_file" "$backup_file"; then
        log_error "创建备份失败" "config"
        return 1
    fi
    
    # 压缩备份
    if [[ "$CONFIG_BACKUP_COMPRESSION" == "true" ]] && command -v gzip >/dev/null 2>&1; then
        gzip "$backup_file"
        backup_file="${backup_file}.gz"
        log_debug "备份文件已压缩" "config"
    fi
    
    # 清理旧备份
    cleanup_old_backups
    
    # 更新元数据
    update_backup_metadata "$backup_file"
    
    log_info "配置备份完成: $backup_file" "config"
    return 0
}

# 恢复配置
restore_config() {
    local backup_file="$1"
    local target_file="${2:-$MAIN_CONFIG_FILE}"
    
    log_info "恢复配置: $backup_file -> $target_file" "config"
    ((CONFIG_STATS["restores"]++))
    
    # 检查备份文件
    if [[ ! -f "$backup_file" ]]; then
        # 尝试查找压缩文件
        if [[ -f "${backup_file}.gz" ]]; then
            backup_file="${backup_file}.gz"
        else
            log_error "备份文件不存在: $backup_file" "config"
            return 1
        fi
    fi
    
    # 创建当前配置的备份
    if [[ -f "$target_file" ]]; then
        backup_config "$target_file" "restore_backup_$(date +%Y%m%d_%H%M%S)"
    fi
    
    # 解压并恢复
    if [[ "$backup_file" == *.gz ]]; then
        if ! gunzip -c "$backup_file" > "$target_file"; then
            log_error "解压恢复失败" "config"
            return 1
        fi
    else
        if ! cp "$backup_file" "$target_file"; then
            log_error "恢复失败" "config"
            return 1
        fi
    fi
    
    # 验证恢复的配置
    local restored_config
    if ! restored_config=$(load_config "$target_file" false); then
        log_error "恢复的配置无效" "config"
        return 1
    fi
    
    if ! validate_config "$restored_config"; then
        log_error "恢复的配置验证失败" "config"
        return 1
    fi
    
    # 清理缓存
    clear_cache
    
    log_info "配置恢复成功" "config"
    return 0
}

# 清理旧备份
cleanup_old_backups() {
    local backup_count
    backup_count=$(find "$CONFIG_BACKUP_DIR" -name "config_*.json*" | wc -l)
    
    if [[ $backup_count -gt $CONFIG_MAX_BACKUPS ]]; then
        local files_to_delete=$((backup_count - CONFIG_MAX_BACKUPS))
        
        find "$CONFIG_BACKUP_DIR" -name "config_*.json*" -type f -printf '%T@ %p\n' | \
            sort -n | head -n "$files_to_delete" | cut -d' ' -f2- | \
            xargs rm -f
        
        log_info "已清理 $files_to_delete 个旧备份文件" "config"
    fi
}

# 更新配置元数据
update_config_metadata() {
    local config_file="$1"
    
    if [[ ! -f "$CONFIG_METADATA_FILE" ]]; then
        init_config_metadata
    fi
    
    # 计算配置文件校验和
    local checksum
    checksum=$(sha256sum "$config_file" | cut -d' ' -f1)
    
    # 更新元数据
    local temp_metadata="${CONFIG_METADATA_FILE}.tmp"
    jq --arg timestamp "$(date -Iseconds)" \
       --arg checksum "$checksum" \
       '.last_modified = $timestamp | .checksum = $checksum' \
       "$CONFIG_METADATA_FILE" > "$temp_metadata"
    
    mv "$temp_metadata" "$CONFIG_METADATA_FILE"
    
    log_debug "配置元数据已更新" "config"
}

# 更新备份元数据
update_backup_metadata() {
    local backup_file="$1"
    
    if [[ ! -f "$CONFIG_METADATA_FILE" ]]; then
        init_config_metadata
    fi
    
    # 更新备份计数和时间
    local temp_metadata="${CONFIG_METADATA_FILE}.tmp"
    jq --arg timestamp "$(date -Iseconds)" \
       '.backup_count += 1 | .last_backup = $timestamp' \
       "$CONFIG_METADATA_FILE" > "$temp_metadata"
    
    mv "$temp_metadata" "$CONFIG_METADATA_FILE"
    
    log_debug "备份元数据已更新" "config"
}

# 列出备份文件
list_backups() {
    echo "=== 配置备份列表 ==="
    
    if [[ ! -d "$CONFIG_BACKUP_DIR" ]]; then
        echo "备份目录不存在"
        return 1
    fi
    
    local backup_files
    backup_files=$(find "$CONFIG_BACKUP_DIR" -name "config_*.json*" -type f | sort -r)
    
    if [[ -z "$backup_files" ]]; then
        echo "没有找到备份文件"
        return 0
    fi
    
    printf "%-30s %-15s %-10s\n" "文件名" "修改时间" "大小"
    echo "--------------------------------------------------------"
    
    while IFS= read -r backup_file; do
        local filename=$(basename "$backup_file")
        local mtime=$(stat -c %y "$backup_file" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1)
        local size=$(stat -c %s "$backup_file" 2>/dev/null)
        local size_human
        
        if [[ $size -gt 1048576 ]]; then
            size_human="$((size / 1048576))M"
        elif [[ $size -gt 1024 ]]; then
            size_human="$((size / 1024))K"
        else
            size_human="${size}B"
        fi
        
        printf "%-30s %-15s %-10s\n" "$filename" "$mtime" "$size_human"
    done <<< "$backup_files"
}

# 显示配置统计
show_config_stats() {
    echo "=== 配置管理统计 ==="
    echo "加载次数: ${CONFIG_STATS["loads"]}"
    echo "保存次数: ${CONFIG_STATS["saves"]}"
    echo "验证次数: ${CONFIG_STATS["validations"]}"
    echo "备份次数: ${CONFIG_STATS["backups"]}"
    echo "恢复次数: ${CONFIG_STATS["restores"]}"
    echo "缓存命中: ${CONFIG_STATS["cache_hits"]}"
    echo "缓存未命中: ${CONFIG_STATS["cache_misses"]}"
    echo ""
    echo "配置文件: $MAIN_CONFIG_FILE"
    echo "备份目录: $CONFIG_BACKUP_DIR"
    echo "模板目录: $CONFIG_TEMPLATE_DIR"
    echo "缓存状态: $([ "$CONFIG_CACHE_ENABLED" == "true" ] && echo "启用" || echo "禁用")"
    echo "验证状态: $([ "$CONFIG_VALIDATION_ENABLED" == "true" ] && echo "启用" || echo "禁用")"
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_config_manager
    show_config_stats
fi