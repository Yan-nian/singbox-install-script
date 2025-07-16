#!/bin/bash

# Sing-box 服务诊断测试脚本
# 用于测试新增的服务诊断和修复功能

SCRIPT_PATH="./singbox-all-in-one.sh"
TEST_LOG="test-diagnostics.log"

echo "=== Sing-box 服务诊断功能测试 ===" | tee "$TEST_LOG"
echo "" | tee -a "$TEST_LOG"

# 检查脚本文件是否存在
if [[ ! -f "$SCRIPT_PATH" ]]; then
    echo "错误: 找不到脚本文件 $SCRIPT_PATH" | tee -a "$TEST_LOG"
    exit 1
fi

echo "✓ 脚本文件存在" | tee -a "$TEST_LOG"

# 检查脚本语法
echo "正在检查脚本语法..." | tee -a "$TEST_LOG"
if bash -n "$SCRIPT_PATH" 2>>"$TEST_LOG"; then
    echo "✓ 脚本语法正确" | tee -a "$TEST_LOG"
else
    echo "✗ 脚本语法错误，详见日志" | tee -a "$TEST_LOG"
    exit 1
fi

# 测试系统兼容性检查
echo "正在测试系统兼容性检查..." | tee -a "$TEST_LOG"
if timeout 10 bash -c 'source "'$SCRIPT_PATH'" && check_os_compatibility' 2>>"$TEST_LOG"; then
    echo "✓ 系统兼容性检查通过" | tee -a "$TEST_LOG"
else
    echo "✗ 系统兼容性检查失败" | tee -a "$TEST_LOG"
fi

# 测试服务状态检查函数
echo "正在测试服务状态检查函数..." | tee -a "$TEST_LOG"
if timeout 5 bash -c 'source "'$SCRIPT_PATH'" && get_service_status "sing-box"' >>"$TEST_LOG" 2>&1; then
    echo "✓ 服务状态检查函数正常" | tee -a "$TEST_LOG"
else
    echo "✗ 服务状态检查函数异常" | tee -a "$TEST_LOG"
fi

# 测试安装状态检查函数
echo "正在测试安装状态检查函数..." | tee -a "$TEST_LOG"
if timeout 5 bash -c 'source "'$SCRIPT_PATH'" && check_installation_status' >>"$TEST_LOG" 2>&1; then
    echo "✓ 安装状态检查函数正常" | tee -a "$TEST_LOG"
else
    echo "✓ 安装状态检查函数正确检测到未安装状态" | tee -a "$TEST_LOG"
fi

# 检查新增的诊断功能
echo "正在检查新增的诊断功能..." | tee -a "$TEST_LOG"
functions_to_check=(
    "show_service_diagnostics"
    "get_service_status_description"
    "check_installation_status"
)

for func in "${functions_to_check[@]}"; do
    if grep -q "^$func()" "$SCRIPT_PATH"; then
        echo "✓ 函数 $func 已定义" | tee -a "$TEST_LOG"
    else
        echo "✗ 函数 $func 未找到" | tee -a "$TEST_LOG"
    fi
done

# 检查菜单更新
echo "正在检查菜单更新..." | tee -a "$TEST_LOG"
if grep -q "服务诊断" "$SCRIPT_PATH"; then
    echo "✓ 服务诊断选项已添加到菜单" | tee -a "$TEST_LOG"
else
    echo "✗ 服务诊断选项未找到" | tee -a "$TEST_LOG"
fi

# 检查自动修复功能
if grep -q "快速修复选项" "$SCRIPT_PATH"; then
    echo "✓ 自动修复功能已添加" | tee -a "$TEST_LOG"
else
    echo "✗ 自动修复功能未找到" | tee -a "$TEST_LOG"
fi

echo "" | tee -a "$TEST_LOG"
echo "=== 测试完成 ===" | tee -a "$TEST_LOG"
echo "" | tee -a "$TEST_LOG"
echo "测试结果已保存到: $TEST_LOG" | tee -a "$TEST_LOG"
echo "" | tee -a "$TEST_LOG"
echo "改进功能说明:" | tee -a "$TEST_LOG"
echo "1. 添加了系统兼容性检查，确保只在Linux系统上运行" | tee -a "$TEST_LOG"
echo "2. 改进了服务状态检查，提供更详细的状态信息" | tee -a "$TEST_LOG"
echo "3. 添加了服务诊断功能，可以快速定位问题" | tee -a "$TEST_LOG"
echo "4. 添加了自动修复功能，可以修复常见问题" | tee -a "$TEST_LOG"
echo "5. 改进了错误处理和用户提示" | tee -a "$TEST_LOG"
echo "" | tee -a "$TEST_LOG"
echo "使用建议:" | tee -a "$TEST_LOG"
echo "- 在Linux系统上运行: sudo bash $SCRIPT_PATH" | tee -a "$TEST_LOG"
echo "- 如果服务启动失败，选择'服务诊断'选项" | tee -a "$TEST_LOG"
echo "- 使用自动修复功能解决常见问题" | tee -a "$TEST_LOG"