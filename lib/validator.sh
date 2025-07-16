#!/bin/bash

# =============================================================================
# 参数验证模块
# 版本: v2.4.3
# 功能: 提供全面的参数验证和输入清理功能
# =============================================================================

# 引入错误处理模块
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/error_handler.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/error_handler.sh"
fi

# 验证模式定义
readonly UUID_PATTERN='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
readonly DOMAIN_PATTERN='^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$'
readonly IPV4_PATTERN='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
readonly IPV6_PATTERN='^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$|^::$|^::1$'
readonly PORT_PATTERN='^[0-9]+$'

# 端口验证
validate_port() {
    local port="$1"
    local context="${2:-端口验证}"
    
    # 参数存在性检查
    if [[ -z "$port" ]]; then
        handle_error "$(get_error_code "MISSING_PARAM")" "端口参数为空" "$context" false
        return 1
    fi
    
    # 数值格式检查
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        handle_error "$(get_error_code "INVALID_PARAM")" "端口必须为数字: $port" "$context" false
        return 1
    fi
    
    # 数值范围检查
    if [[ $port -lt 1 || $port -gt 65535 ]]; then
        handle_error "$(get_error_code "PARAM_OUT_OF_RANGE")" "端口范围无效: $port (有效范围: 1-65535)" "$context" false
        return 1
    fi
    
    # 系统保留端口检查 (可选)
    if [[ $port -lt 1024 ]] && [[ $EUID -ne 0 ]]; then
        handle_warning "使用系统保留端口 $port 需要管理员权限" "$context"
    fi
    
    return 0
}

# 端口占用检查
check_port_available() {
    local port="$1"
    local context="${2:-端口可用性检查}"
    
    # 先验证端口格式
    if ! validate_port "$port" "$context"; then
        return 1
    fi
    
    # 检查端口占用
    if command -v netstat >/dev/null 2>&1; then
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            handle_error "$(get_error_code "PORT_OCCUPIED")" "端口 $port 已被占用" "$context" false
            return 1
        fi
    elif command -v ss >/dev/null 2>&1; then
        if ss -tuln 2>/dev/null | grep -q ":$port "; then
            handle_error "$(get_error_code "PORT_OCCUPIED")" "端口 $port 已被占用" "$context" false
            return 1
        fi
    else
        handle_warning "无法检查端口占用状态，请手动确认端口 $port 可用" "$context"
    fi
    
    return 0
}

# 域名验证
validate_domain() {
    local domain="$1"
    local context="${2:-域名验证}"
    
    # 参数存在性检查
    if [[ -z "$domain" ]]; then
        handle_error "$(get_error_code "MISSING_PARAM")" "域名参数为空" "$context" false
        return 1
    fi
    
    # 长度检查
    if [[ ${#domain} -gt 253 ]]; then
        handle_error "$(get_error_code "PARAM_OUT_OF_RANGE")" "域名长度超过限制: ${#domain} > 253" "$context" false
        return 1
    fi
    
    # 格式检查
    local domain_regex='^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$'
    if [[ ! "$domain" =~ $domain_regex ]]; then
        handle_error "$(get_error_code "INVALID_PARAM")" "域名格式无效: $domain" "$context" false
        return 1
    fi
    
    # 检查是否为IP地址（域名验证中不应该是IP）
    if [[ "$domain" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        handle_error "$(get_error_code "INVALID_PARAM")" "期望域名但收到IP地址: $domain" "$context" false
        return 1
    fi
    
    return 0
}

# IP地址验证
validate_ip() {
    local ip="$1"
    local version="${2:-4}"  # 4 for IPv4, 6 for IPv6, auto for auto-detect
    local context="${3:-IP地址验证}"
    
    # 参数存在性检查
    if [[ -z "$ip" ]]; then
        handle_error "$(get_error_code "MISSING_PARAM")" "IP地址参数为空" "$context" false
        return 1
    fi
    
    case "$version" in
        "4")
            validate_ipv4 "$ip" "$context"
            ;;
        "6")
            validate_ipv6 "$ip" "$context"
            ;;
        "auto")
            if validate_ipv4 "$ip" "$context" 2>/dev/null; then
                return 0
            elif validate_ipv6 "$ip" "$context" 2>/dev/null; then
                return 0
            else
                handle_error "$(get_error_code "INVALID_PARAM")" "IP地址格式无效: $ip" "$context" false
                return 1
            fi
            ;;
        *)
            handle_error "$(get_error_code "INVALID_PARAM")" "不支持的IP版本: $version" "$context" false
            return 1
            ;;
    esac
}

# IPv4地址验证
validate_ipv4() {
    local ip="$1"
    local context="${2:-IPv4地址验证}"
    
    # IPv4格式检查
    local ipv4_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    if [[ ! "$ip" =~ $ipv4_regex ]]; then
        handle_error "$(get_error_code "INVALID_PARAM")" "IPv4地址格式无效: $ip" "$context" false
        return 1
    fi
    
    # 检查每个八位组的范围
    IFS='.' read -ra octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if [[ $octet -lt 0 || $octet -gt 255 ]]; then
            handle_error "$(get_error_code "PARAM_OUT_OF_RANGE")" "IPv4地址八位组超出范围: $octet (有效范围: 0-255)" "$context" false
            return 1
        fi
        
        # 检查前导零（除了单独的0）
        if [[ ${#octet} -gt 1 && $octet =~ ^0 ]]; then
            handle_error "$(get_error_code "INVALID_PARAM")" "IPv4地址不能包含前导零: $octet" "$context" false
            return 1
        fi
    done
    
    return 0
}

# IPv6地址验证
validate_ipv6() {
    local ip="$1"
    local context="${2:-IPv6地址验证}"
    
    # 简化的IPv6验证（完整验证较复杂）
    local ipv6_regex='^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$|^::$|^::1$'
    if [[ ! "$ip" =~ $ipv6_regex ]]; then
        handle_error "$(get_error_code "INVALID_PARAM")" "IPv6地址格式无效: $ip" "$context" false
        return 1
    fi
    
    return 0
}

# UUID验证
validate_uuid() {
    local uuid="$1"
    local context="${2:-UUID验证}"
    
    # 参数存在性检查
    if [[ -z "$uuid" ]]; then
        handle_error "$(get_error_code "MISSING_PARAM")" "UUID参数为空" "$context" false
        return 1
    fi
    
    # UUID格式检查
    local uuid_regex='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    if [[ ! "$uuid" =~ $uuid_regex ]]; then
        handle_error "$(get_error_code "INVALID_PARAM")" "UUID格式无效: $uuid" "$context" false
        return 1
    fi
    
    return 0
}

# 路径验证
validate_path() {
    local path="$1"
    local type="${2:-file}"  # file, directory, any
    local context="${3:-路径验证}"
    
    # 参数存在性检查
    if [[ -z "$path" ]]; then
        handle_error "$(get_error_code "MISSING_PARAM")" "路径参数为空" "$context" false
        return 1
    fi
    
    # 安全检查：防止路径遍历攻击
    if [[ "$path" =~ \.\. ]]; then
        handle_error "$(get_error_code "INVALID_PARAM")" "路径包含危险字符 '..': $path" "$context" false
        return 1
    fi
    
    # 检查路径是否为绝对路径（推荐）
    if [[ ! "$path" =~ ^/ ]]; then
        handle_warning "建议使用绝对路径: $path" "$context"
    fi
    
    # 根据类型进行验证
    case "$type" in
        "file")
            if [[ ! -f "$path" ]]; then
                handle_error "$(get_error_code "FILE_NOT_FOUND")" "文件不存在: $path" "$context" false
                return 1
            fi
            ;;
        "directory")
            if [[ ! -d "$path" ]]; then
                handle_error "$(get_error_code "FILE_NOT_FOUND")" "目录不存在: $path" "$context" false
                return 1
            fi
            ;;
        "any")
            if [[ ! -e "$path" ]]; then
                handle_error "$(get_error_code "FILE_NOT_FOUND")" "路径不存在: $path" "$context" false
                return 1
            fi
            ;;
        "writable")
            local dir_path="$(dirname "$path")"
            if [[ ! -d "$dir_path" ]]; then
                handle_error "$(get_error_code "FILE_NOT_FOUND")" "目标目录不存在: $dir_path" "$context" false
                return 1
            fi
            if [[ ! -w "$dir_path" ]]; then
                handle_error "$(get_error_code "FILE_PERMISSION_DENIED")" "目录不可写: $dir_path" "$context" false
                return 1
            fi
            ;;
    esac
    
    return 0
}

# 输入清理函数
sanitize_input() {
    local input="$1"
    local type="${2:-general}"
    
    case "$type" in
        "port")
            # 只保留数字
            echo "$input" | sed 's/[^0-9]//g'
            ;;
        "domain")
            # 只保留域名有效字符
            echo "$input" | sed 's/[^a-zA-Z0-9.-]//g' | tr '[:upper:]' '[:lower:]'
            ;;
        "uuid")
            # 只保留UUID有效字符
            echo "$input" | sed 's/[^0-9a-f-]//g' | tr '[:upper:]' '[:lower:]'
            ;;
        "path")
            # 移除危险字符，保留路径有效字符
            echo "$input" | sed 's/[;&|`$(){}\[\]<>]//g'
            ;;
        "alphanumeric")
            # 只保留字母和数字
            echo "$input" | sed 's/[^a-zA-Z0-9]//g'
            ;;
        "filename")
            # 只保留文件名有效字符
            echo "$input" | sed 's/[^a-zA-Z0-9._-]//g'
            ;;
        *)
            # 通用清理：移除特殊字符
            echo "$input" | sed 's/[;&|`$(){}\[\]<>]//g'
            ;;
    esac
}

# 批量验证函数
batch_validate() {
    local validation_rules="$1"  # 格式: "type1:value1,type2:value2,..."
    local context="${2:-批量验证}"
    local errors=()
    local success_count=0
    local total_count=0
    
    IFS=',' read -ra rules <<< "$validation_rules"
    for rule in "${rules[@]}"; do
        IFS=':' read -ra parts <<< "$rule"
        local type="${parts[0]}"
        local value="${parts[1]}"
        ((total_count++))
        
        case "$type" in
            "port")
                if validate_port "$value" "$context"; then
                    ((success_count++))
                else
                    errors+=("端口验证失败: $value")
                fi
                ;;
            "domain")
                if validate_domain "$value" "$context"; then
                    ((success_count++))
                else
                    errors+=("域名验证失败: $value")
                fi
                ;;
            "uuid")
                if validate_uuid "$value" "$context"; then
                    ((success_count++))
                else
                    errors+=("UUID验证失败: $value")
                fi
                ;;
            "ipv4")
                if validate_ipv4 "$value" "$context"; then
                    ((success_count++))
                else
                    errors+=("IPv4验证失败: $value")
                fi
                ;;
            "ipv6")
                if validate_ipv6 "$value" "$context"; then
                    ((success_count++))
                else
                    errors+=("IPv6验证失败: $value")
                fi
                ;;
            *)
                errors+=("未知验证类型: $type")
                ;;
        esac
    done
    
    # 输出批量验证结果
    if [[ ${#errors[@]} -gt 0 ]]; then
        handle_error "$(get_error_code "INVALID_PARAM")" "批量验证失败 ($success_count/$total_count 成功)" "$context" false
        for error in "${errors[@]}"; do
            echo "  - $error" >&2
        done
        return 1
    else
        handle_success "批量验证成功 ($success_count/$total_count)" "$context"
        return 0
    fi
}

# 兼容性别名
validate_multiple() {
    local validation_rules="$1"  # 格式: "type1:value1,type2:value2,..."
    local context="${2:-批量验证}"
    local errors=()
    
    IFS=',' read -ra rules <<< "$validation_rules"
    for rule in "${rules[@]}"; do
        IFS=':' read -ra parts <<< "$rule"
        local type="${parts[0]}"
        local value="${parts[1]}"
        
        case "$type" in
            "port")
                if ! validate_port "$value" "$context"; then
                    errors+=("端口验证失败: $value")
                fi
                ;;
            "domain")
                if ! validate_domain "$value" "$context"; then
                    errors+=("域名验证失败: $value")
                fi
                ;;
            "uuid")
                if ! validate_uuid "$value" "$context"; then
                    errors+=("UUID验证失败: $value")
                fi
                ;;
            "ipv4")
                if ! validate_ipv4 "$value" "$context"; then
                    errors+=("IPv4验证失败: $value")
                fi
                ;;
            *)
                errors+=("未知验证类型: $type")
                ;;
        esac
    done
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        for error in "${errors[@]}"; do
            handle_error "$(get_error_code "INVALID_PARAM")" "$error" "$context" false
        done
        return 1
    fi
    
    return 0
}

# 导出函数
export -f validate_port
export -f check_port_available
export -f validate_domain
export -f validate_ip
export -f validate_ipv4
export -f validate_ipv6
export -f validate_uuid
export -f validate_path
export -f sanitize_input
export -f batch_validate
export -f validate_multiple

# 如果直接运行此脚本，则进行测试
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "参数验证模块测试"
    echo "=================="
    
    # 测试端口验证
    echo "测试端口验证:"
    validate_port "8080" && echo "✓ 8080 - 有效"
    validate_port "abc" && echo "✓ abc - 有效" || echo "✗ abc - 无效"
    validate_port "70000" && echo "✓ 70000 - 有效" || echo "✗ 70000 - 无效"
    
    # 测试域名验证
    echo "\n测试域名验证:"
    validate_domain "example.com" && echo "✓ example.com - 有效"
    validate_domain "sub.example.com" && echo "✓ sub.example.com - 有效"
    validate_domain "192.168.1.1" && echo "✓ 192.168.1.1 - 有效" || echo "✗ 192.168.1.1 - 无效"
    
    # 测试UUID验证
    echo "\n测试UUID验证:"
    validate_uuid "550e8400-e29b-41d4-a716-446655440000" && echo "✓ UUID - 有效"
    validate_uuid "invalid-uuid" && echo "✓ invalid-uuid - 有效" || echo "✗ invalid-uuid - 无效"
    
    # 测试输入清理
    echo "\n测试输入清理:"
    echo "原始: 'test;rm -rf /' -> 清理后: '$(sanitize_input "test;rm -rf /" "general")'"
    echo "原始: 'ABC123def' -> 域名清理: '$(sanitize_input "ABC123def" "domain")'"
    
    echo "\n参数验证模块测试完成"
fi