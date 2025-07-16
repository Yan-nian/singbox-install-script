#!/bin/bash

# 安装脚本测试工具

echo "=== Sing-box 安装脚本测试 ==="
echo

# 检查所有脚本文件
echo "1. 检查脚本文件:"
scripts=("install.sh" "upgrade.sh" "update.sh" "sing-box.sh")

for script in "${scripts[@]}"; do
    if [[ -f "$script" ]]; then
        echo "  ✅ $script 存在"
        if [[ -x "$script" ]]; then
            echo "     ✅ 可执行"
        else
            echo "     ❌ 不可执行"
        fi
        
        # 语法检查
        if bash -n "$script"; then
            echo "     ✅ 语法正确"
        else
            echo "     ❌ 语法错误"
        fi
    else
        echo "  ❌ $script 不存在"
    fi
    echo
done

# 检查关键函数
echo "2. 检查关键函数:"
key_functions=(
    "check_system"
    "install_dependencies"
    "download_singbox"
    "create_directories"
    "download_script"
    "create_service"
    "interactive_main"
    "show_main_menu"
)

for func in "${key_functions[@]}"; do
    if grep -q "^$func()" install.sh sing-box.sh 2>/dev/null; then
        echo "  ✅ $func"
    else
        echo "  ❌ $func"
    fi
done

echo
echo "3. 检查配置文件:"
if [[ -f "README.md" ]]; then
    echo "  ✅ README.md"
else
    echo "  ❌ README.md"
fi

if [[ -f "USAGE.md" ]]; then
    echo "  ✅ USAGE.md"
else
    echo "  ❌ USAGE.md"
fi

if [[ -f "INSTALL.md" ]]; then
    echo "  ✅ INSTALL.md"
else
    echo "  ❌ INSTALL.md"
fi

echo
echo "4. 安装方式测试:"
echo "  全新安装: sudo bash install.sh"
echo "  覆盖升级: sudo bash upgrade.sh"
echo "  脚本更新: sudo bash update.sh"

echo
echo "5. 使用方式测试:"
echo "  交互式界面: sing-box"
echo "  命令行模式: sing-box add vless"
echo "  快捷命令: sb"

echo
echo "=== 测试完成 ==="
echo "建议按照 INSTALL.md 的说明进行安装"
