#!/bin/bash

# Sing-box 精简安装脚本 v2.4.14
# 重构版本 - 使用新的模块化架构
# 支持 VLESS Reality、VMess WebSocket、Hysteria2 协议
# 作者: Sing-box 安装脚本项目组
# 版本: v2.4.14
# 更新时间: $(date +%Y-%m-%d)

set -euo pipefail

# 脚本信息
SCRIPT_VERSION="v2.4.14"
SCRIPT_NAME="Sing-box 精简安装脚本"
SCRIPT_DESCRIPTION="支持多协议的 Sing-box 一键安装和管理脚本"
SCRIPT_AUTHOR="Sing-box 安装脚本项目组"
SCRIPT_URL="https://github.com/your-repo/singbox"

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR"

# 核心模块路径
CORE_DIR="${BASE_DIR}/core"
CONFIG_DIR="${BASE_DIR}/config"
UTILS_DIR="${BASE_DIR}/utils"
SCRIPTS_DIR="${BASE_DIR}/scripts"
TEMPLATES_DIR="${BASE_DIR}/templates"

# 引入核心模块
source "${CORE_DIR}/bootstrap.sh" 2>/dev/null || {
    echo "[错误] 无法加载核心引导模块: ${CORE_DIR}/bootstrap.sh"
    echo "请确保项目结构完整，或使用原版安装脚本"
    exit 1
}

source "${CORE_DIR}/error_handler.sh" 2>/dev/null || {
    echo "[错误] 无法加载错误处理模块: ${CORE_DIR}/error_handler.sh"
    exit 1
}

source "${CORE_DIR}/logger.sh" 2>/dev/null || {
    echo "[错误] 无法加载日志模块: ${CORE_DIR}/logger.sh"
    exit 1
}

# 引入配置管理模块
source "${CONFIG_DIR}/config_manager.sh" 2>/dev/null || {
    log_error "无法加载配置管理模块: ${CONFIG_DIR}/config_manager.sh"
    exit 1
}

# 引入工具模块
source "${UTILS_DIR}/system_utils.sh" 2>/dev/null || {
    log_error "无法加载系统工具模块: ${UTILS_DIR}/system_utils.sh"
    exit 1
}

source "${UTILS_DIR}/network_utils.sh" 2>/dev/null || {
    log_error "无法加载网络工具模块: ${UTILS_DIR}/network_utils.sh"
    exit 1
}

# 引入传统脚本（向后兼容）
source "${SCRIPTS_DIR}/common.sh" 2>/dev/null || {
    log_warn "无法加载传统公共模块，某些功能可能不可用"
}

source "${SCRIPTS_DIR}/menu.sh" 2>/dev/null || {
    log_warn "无法加载菜单模块，将使用简化界面"
}

# 全局变量
INSTALL_MODE="interactive"  # interactive, auto, silent
SELECTED_PROTOCOL=""        # vless, vmess, hysteria2
CONFIG_NAME=""              # 配置文件名称
SERVICE_ACTION=""           # install, uninstall, restart, status
FORCE_REINSTALL="false"     # 是否强制重新安装
SKIP_CHECKS="false"         # 是否跳过环境检查
DEBUG_MODE="false"          # 调试模式

# 安装配置
SINGBOX_VERSION="latest"    # Sing-box 版本
INSTALL_PATH="/usr/local/bin/sing-box"  # 安装路径
CONFIG_PATH="/etc/sing-box"             # 配置目录
SERVICE_NAME="sing-box"                 # 服务名称
LOG_PATH="/var/log/sing-box"            # 日志目录

# 显示脚本信息
show_script_info() {
    echo ""
    echo "======================================"
    echo "  $SCRIPT_NAME"
    echo "  版本: $SCRIPT_VERSION"
    echo "  作者: $SCRIPT_AUTHOR"
    echo "  描述: $SCRIPT_DESCRIPTION"
    echo "======================================"
    echo ""
}

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项] [命令]

选项:
  -h, --help              显示此帮助信息
  -v, --version           显示版本信息
  -d, --debug             启用调试模式
  -f, --force             强制重新安装
  -s, --silent            静默模式（非交互）
  -c, --config <name>     指定配置名称
  -p, --protocol <type>   指定协议类型 (vless|vmess|hysteria2)
  --skip-checks           跳过环境检查
  --install-path <path>   指定安装路径
  --config-path <path>    指定配置目录

命令:
  install                 安装 Sing-box
  uninstall              卸载 Sing-box
  update                 更新 Sing-box
  restart                重启服务
  status                 查看服务状态
  config                 配置管理
  menu                   显示交互菜单
  test                   运行测试

协议类型:
  vless                  VLESS Reality 协议
  vmess                  VMess WebSocket 协议
  hysteria2              Hysteria2 协议

示例:
  $0                     # 交互式安装
  $0 install             # 自动安装
  $0 -p vless install    # 安装 VLESS 协议
  $0 -c myconfig config  # 管理指定配置
  $0 --silent install    # 静默安装
  $0 status              # 查看服务状态
  $0 test                # 运行测试

更多信息请访问: $SCRIPT_URL
EOF
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "$SCRIPT_NAME $SCRIPT_VERSION"
                exit 0
                ;;
            -d|--debug)
                DEBUG_MODE="true"
                export DEBUG="true"
                log_set_level "DEBUG"
                shift
                ;;
            -f|--force)
                FORCE_REINSTALL="true"
                shift
                ;;
            -s|--silent)
                INSTALL_MODE="silent"
                shift
                ;;
            -c|--config)
                CONFIG_NAME="$2"
                shift 2
                ;;
            -p|--protocol)
                SELECTED_PROTOCOL="$2"
                case "$SELECTED_PROTOCOL" in
                    vless|vmess|hysteria2)
                        ;;
                    *)
                        log_error "不支持的协议类型: $SELECTED_PROTOCOL"
                        log_info "支持的协议: vless, vmess, hysteria2"
                        exit 1
                        ;;
                esac
                shift 2
                ;;
            --skip-checks)
                SKIP_CHECKS="true"
                shift
                ;;
            --install-path)
                INSTALL_PATH="$2"
                shift 2
                ;;
            --config-path)
                CONFIG_PATH="$2"
                shift 2
                ;;
            install|uninstall|update|restart|status|config|menu|test)
                SERVICE_ACTION="$1"
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 如果没有指定命令，默认为交互模式
    if [[ -z "$SERVICE_ACTION" ]]; then
        if [[ "$INSTALL_MODE" == "silent" ]]; then
            SERVICE_ACTION="install"
        else
            SERVICE_ACTION="menu"
        fi
    fi
}

# 环境检查
perform_environment_check() {
    if [[ "$SKIP_CHECKS" == "true" ]]; then
        log_info "跳过环境检查"
        return 0
    fi
    
    log_info "开始环境检查..."
    
    # 使用新的引导模块进行环境检查
    if ! check_environment; then
        log_error "环境检查失败"
        return 1
    fi
    
    log_success "环境检查通过"
    return 0
}

# 协议选择
select_protocol() {
    if [[ -n "$SELECTED_PROTOCOL" ]]; then
        log_info "使用指定协议: $SELECTED_PROTOCOL"
        return 0
    fi
    
    if [[ "$INSTALL_MODE" == "silent" ]]; then
        SELECTED_PROTOCOL="vless"  # 默认协议
        log_info "静默模式，使用默认协议: $SELECTED_PROTOCOL"
        return 0
    fi
    
    echo ""
    echo "请选择要安装的协议:"
    echo "1) VLESS Reality (推荐)"
    echo "2) VMess WebSocket"
    echo "3) Hysteria2"
    echo ""
    
    while true; do
        read -p "请输入选择 [1-3]: " choice
        case $choice in
            1)
                SELECTED_PROTOCOL="vless"
                break
                ;;
            2)
                SELECTED_PROTOCOL="vmess"
                break
                ;;
            3)
                SELECTED_PROTOCOL="hysteria2"
                break
                ;;
            *)
                echo "无效选择，请重新输入"
                ;;
        esac
    done
    
    log_info "选择的协议: $SELECTED_PROTOCOL"
}

# 安装 Sing-box
install_singbox() {
    log_info "开始安装 Sing-box..."
    
    # 检查是否已安装
    if [[ -f "$INSTALL_PATH" && "$FORCE_REINSTALL" != "true" ]]; then
        log_warn "Sing-box 已安装，使用 --force 强制重新安装"
        return 1
    fi
    
    # 创建必要目录
    log_info "创建安装目录..."
    create_directory "$(dirname "$INSTALL_PATH")"
    create_directory "$CONFIG_PATH"
    create_directory "$LOG_PATH"
    
    # 下载 Sing-box
    log_info "下载 Sing-box $SINGBOX_VERSION..."
    if ! download_singbox "$SINGBOX_VERSION" "$INSTALL_PATH"; then
        log_error "下载 Sing-box 失败"
        return 1
    fi
    
    # 设置权限
    chmod +x "$INSTALL_PATH"
    
    # 验证安装
    if "$INSTALL_PATH" version >/dev/null 2>&1; then
        log_success "Sing-box 安装成功"
        local version
        version=$("$INSTALL_PATH" version | head -n1)
        log_info "安装版本: $version"
    else
        log_error "Sing-box 安装验证失败"
        return 1
    fi
    
    return 0
}

# 生成配置文件
generate_config() {
    log_info "生成 $SELECTED_PROTOCOL 协议配置..."
    
    local config_file="${CONFIG_PATH}/config.json"
    local template_file="${TEMPLATES_DIR}/${SELECTED_PROTOCOL}.json"
    
    # 检查模板文件
    if [[ ! -f "$template_file" ]]; then
        log_error "协议模板文件不存在: $template_file"
        return 1
    fi
    
    # 使用配置管理器生成配置
    if ! config_generate_from_template "$template_file" "$config_file" "$SELECTED_PROTOCOL"; then
        log_error "配置文件生成失败"
        return 1
    fi
    
    # 验证配置文件
    if "$INSTALL_PATH" check -c "$config_file" >/dev/null 2>&1; then
        log_success "配置文件生成并验证成功"
    else
        log_error "配置文件验证失败"
        return 1
    fi
    
    return 0
}

# 创建系统服务
create_service() {
    log_info "创建系统服务..."
    
    local service_file="/etc/systemd/system/${SERVICE_NAME}.service"
    
    cat > "$service_file" << EOF
[Unit]
Description=Sing-box Service
Documentation=https://sing-box.sagernet.org/
After=network.target nss-lookup.target
Wants=network.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true
ExecStart=$INSTALL_PATH run -c ${CONFIG_PATH}/config.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
    
    # 重新加载 systemd
    systemctl daemon-reload
    
    # 启用服务
    systemctl enable "$SERVICE_NAME"
    
    log_success "系统服务创建成功"
    return 0
}

# 启动服务
start_service() {
    log_info "启动 Sing-box 服务..."
    
    if systemctl start "$SERVICE_NAME"; then
        sleep 2
        if systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
            log_success "Sing-box 服务启动成功"
            return 0
        else
            log_error "Sing-box 服务启动失败"
            systemctl status "$SERVICE_NAME" --no-pager
            return 1
        fi
    else
        log_error "无法启动 Sing-box 服务"
        return 1
    fi
}

# 显示配置信息
show_config_info() {
    log_info "显示配置信息..."
    
    local config_file="${CONFIG_PATH}/config.json"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    # 使用配置管理器显示配置信息
    config_show_info "$config_file" "$SELECTED_PROTOCOL"
    
    return 0
}

# 卸载 Sing-box
uninstall_singbox() {
    log_info "开始卸载 Sing-box..."
    
    # 停止服务
    if systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
        log_info "停止 Sing-box 服务..."
        systemctl stop "$SERVICE_NAME"
    fi
    
    # 禁用服务
    if systemctl is-enabled "$SERVICE_NAME" >/dev/null 2>&1; then
        log_info "禁用 Sing-box 服务..."
        systemctl disable "$SERVICE_NAME"
    fi
    
    # 删除服务文件
    local service_file="/etc/systemd/system/${SERVICE_NAME}.service"
    if [[ -f "$service_file" ]]; then
        rm -f "$service_file"
        systemctl daemon-reload
    fi
    
    # 删除二进制文件
    if [[ -f "$INSTALL_PATH" ]]; then
        rm -f "$INSTALL_PATH"
    fi
    
    # 询问是否删除配置文件
    if [[ "$INSTALL_MODE" != "silent" ]]; then
        if confirm "是否删除配置文件和日志?"; then
            rm -rf "$CONFIG_PATH"
            rm -rf "$LOG_PATH"
            log_info "配置文件和日志已删除"
        else
            log_info "保留配置文件和日志"
        fi
    fi
    
    log_success "Sing-box 卸载完成"
    return 0
}

# 更新 Sing-box
update_singbox() {
    log_info "开始更新 Sing-box..."
    
    # 检查当前版本
    if [[ -f "$INSTALL_PATH" ]]; then
        local current_version
        current_version=$("$INSTALL_PATH" version 2>/dev/null | head -n1 || echo "未知版本")
        log_info "当前版本: $current_version"
    fi
    
    # 备份当前配置
    if [[ -f "${CONFIG_PATH}/config.json" ]]; then
        config_backup "${CONFIG_PATH}/config.json"
    fi
    
    # 停止服务
    if systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
        log_info "停止服务进行更新..."
        systemctl stop "$SERVICE_NAME"
    fi
    
    # 下载新版本
    FORCE_REINSTALL="true"
    if install_singbox; then
        # 重启服务
        if systemctl is-enabled "$SERVICE_NAME" >/dev/null 2>&1; then
            start_service
        fi
        log_success "Sing-box 更新完成"
    else
        log_error "Sing-box 更新失败"
        return 1
    fi
    
    return 0
}

# 查看服务状态
show_status() {
    log_info "Sing-box 服务状态:"
    
    if command -v systemctl >/dev/null 2>&1; then
        systemctl status "$SERVICE_NAME" --no-pager
    else
        log_warn "systemctl 不可用，无法查看服务状态"
    fi
    
    # 显示端口监听情况
    log_info "端口监听情况:"
    if command -v ss >/dev/null 2>&1; then
        ss -tlnp | grep sing-box || echo "未发现 sing-box 监听端口"
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tlnp | grep sing-box || echo "未发现 sing-box 监听端口"
    else
        log_warn "缺少网络检查工具"
    fi
}

# 配置管理
manage_config() {
    log_info "配置管理功能"
    
    if [[ "$INSTALL_MODE" == "silent" ]]; then
        log_error "静默模式不支持配置管理"
        return 1
    fi
    
    echo ""
    echo "配置管理选项:"
    echo "1) 查看当前配置"
    echo "2) 备份配置"
    echo "3) 恢复配置"
    echo "4) 重新生成配置"
    echo "5) 验证配置"
    echo "0) 返回"
    echo ""
    
    while true; do
        read -p "请选择操作 [0-5]: " choice
        case $choice in
            1)
                show_config_info
                break
                ;;
            2)
                config_backup "${CONFIG_PATH}/config.json"
                break
                ;;
            3)
                config_restore_interactive
                break
                ;;
            4)
                if confirm "重新生成配置将覆盖当前配置，是否继续?"; then
                    select_protocol
                    generate_config
                fi
                break
                ;;
            5)
                if "$INSTALL_PATH" check -c "${CONFIG_PATH}/config.json"; then
                    log_success "配置文件验证通过"
                else
                    log_error "配置文件验证失败"
                fi
                break
                ;;
            0)
                return 0
                ;;
            *)
                echo "无效选择，请重新输入"
                ;;
        esac
    done
}

# 运行测试
run_tests() {
    log_info "运行测试套件..."
    
    local test_framework="${BASE_DIR}/tests/test_framework.sh"
    
    if [[ -f "$test_framework" ]]; then
        log_info "发现测试框架，开始运行测试..."
        bash "$test_framework" discover "${BASE_DIR}/tests"
    else
        log_warn "测试框架不存在，跳过测试"
        log_info "要运行测试，请确保项目结构完整"
    fi
}

# 显示交互菜单
show_interactive_menu() {
    # 尝试使用新的菜单系统
    if command -v show_main_menu >/dev/null 2>&1; then
        show_main_menu
    else
        # 简化菜单
        while true; do
            echo ""
            echo "======================================"
            echo "  $SCRIPT_NAME $SCRIPT_VERSION"
            echo "======================================"
            echo "1) 安装 Sing-box"
            echo "2) 卸载 Sing-box"
            echo "3) 更新 Sing-box"
            echo "4) 重启服务"
            echo "5) 查看状态"
            echo "6) 配置管理"
            echo "7) 运行测试"
            echo "0) 退出"
            echo ""
            
            read -p "请选择操作 [0-7]: " choice
            case $choice in
                1)
                    select_protocol
                    perform_environment_check && \
                    install_singbox && \
                    generate_config && \
                    create_service && \
                    start_service && \
                    show_config_info
                    ;;
                2)
                    uninstall_singbox
                    ;;
                3)
                    update_singbox
                    ;;
                4)
                    systemctl restart "$SERVICE_NAME"
                    log_info "服务重启完成"
                    ;;
                5)
                    show_status
                    ;;
                6)
                    manage_config
                    ;;
                7)
                    run_tests
                    ;;
                0)
                    log_info "感谢使用 $SCRIPT_NAME"
                    exit 0
                    ;;
                *)
                    echo "无效选择，请重新输入"
                    ;;
            esac
            
            echo ""
            read -p "按回车键继续..."
        done
    fi
}

# 主函数
main() {
    # 初始化日志系统
    init_logger
    
    # 显示脚本信息
    if [[ "$INSTALL_MODE" != "silent" ]]; then
        show_script_info
    fi
    
    # 解析命令行参数
    parse_arguments "$@"
    
    # 设置错误处理
    init_error_handler
    
    # 根据操作执行相应功能
    case "$SERVICE_ACTION" in
        "install")
            perform_environment_check && \
            select_protocol && \
            install_singbox && \
            generate_config && \
            create_service && \
            start_service && \
            show_config_info
            ;;
        "uninstall")
            uninstall_singbox
            ;;
        "update")
            update_singbox
            ;;
        "restart")
            systemctl restart "$SERVICE_NAME"
            log_info "服务重启完成"
            ;;
        "status")
            show_status
            ;;
        "config")
            manage_config
            ;;
        "test")
            run_tests
            ;;
        "menu")
            show_interactive_menu
            ;;
        *)
            log_error "未知操作: $SERVICE_ACTION"
            show_help
            exit 1
            ;;
    esac
}

# 模拟下载函数（临时实现）
download_singbox() {
    local version="$1"
    local target_path="$2"
    
    log_info "模拟下载 Sing-box $version 到 $target_path"
    
    # 创建模拟的二进制文件
    cat > "$target_path" << 'EOF'
#!/bin/bash
echo "sing-box version 1.8.0"
case "$1" in
    "version")
        echo "sing-box version 1.8.0"
        echo "Environment: production"
        ;;
    "check")
        echo "配置文件检查通过"
        ;;
    "run")
        echo "Sing-box 正在运行..."
        ;;
    *)
        echo "用法: sing-box [version|check|run]"
        ;;
esac
EOF
    
    chmod +x "$target_path"
    return 0
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi