#!/bin/bash

# Sing-box 脚本测试
# 测试基本功能和语法

echo "正在检查 sing-box.sh 脚本语法..."

# 检查语法
if bash -n sing-box.sh; then
    echo "✓ 语法检查通过"
else
    echo "✗ 语法检查失败"
    exit 1
fi

# 检查必要的函数是否存在
echo "检查必要的函数..."

functions_to_check=(
    "print_banner"
    "show_main_menu"
    "interactive_main"
    "interactive_add_vless_reality"
    "interactive_add_vmess"
    "interactive_add_hysteria2"
    "interactive_add_shadowsocks"
    "add_vless_reality"
    "add_vmess"
    "add_hysteria2"
    "add_shadowsocks"
    "generate_vless_url"
    "generate_vmess_url"
    "generate_hy2_url"
    "generate_ss_url"
    "interactive_list_configs"
    "interactive_show_config_info"
    "interactive_delete_config"
    "interactive_change_port"
    "interactive_regenerate_uuid"
    "interactive_start_service"
    "interactive_stop_service"
    "interactive_restart_service"
    "interactive_show_status"
    "interactive_show_logs"
    "interactive_system_optimize"
    "interactive_uninstall"
    "interactive_show_all_urls"
    "interactive_show_single_url"
    "interactive_generate_qr"
    "interactive_export_config"
    "interactive_show_system_info"
    "enable_bbr"
    "optimize_system"
    "configure_firewall"
    "regenerate_uuid"
    "update_config_uuid_in_db"
)

missing_functions=()

for func in "${functions_to_check[@]}"; do
    if grep -q "^$func()" sing-box.sh; then
        echo "✓ $func"
    else
        echo "✗ $func"
        missing_functions+=("$func")
    fi
done

if [ ${#missing_functions[@]} -eq 0 ]; then
    echo "✓ 所有必要的函数都存在"
else
    echo "✗ 缺少以下函数："
    for func in "${missing_functions[@]}"; do
        echo "  - $func"
    done
fi

echo "测试完成"
