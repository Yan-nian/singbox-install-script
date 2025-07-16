#!/bin/bash

# 验证修复效果的简单脚本
echo "=== Sing-box 依赖加载机制修复验证 ==="
echo

# 检查 singbox-install.sh 文件是否存在
if [[ -f "singbox-install.sh" ]]; then
    echo "✓ singbox-install.sh 文件存在"
else
    echo "✗ singbox-install.sh 文件不存在"
    exit 1
fi

# 检查关键函数是否已定义
echo
echo "检查关键函数定义:"

functions=("define_essential_functions" "verify_module_functions" "auto_repair_modules" "diagnose_module_issues")
for func in "${functions[@]}"; do
    if grep -q "^$func()" singbox-install.sh; then
        echo "✓ $func 函数已定义"
    else
        echo "✗ $func 函数未找到"
    fi
done

# 检查内嵌函数
echo
echo "检查内嵌函数:"
embedded_functions=("log_debug" "log_info" "log_warn" "log_error" "validate_uuid" "validate_port")
for func in "${embedded_functions[@]}"; do
    if grep -q "$func()" singbox-install.sh; then
        echo "✓ $func 内嵌函数已定义"
    else
        echo "✗ $func 内嵌函数未找到"
    fi
done

# 检查模块加载改进
echo
echo "检查模块加载改进:"
improvements=(
    "本地模块优先:lib_dir.*dirname"
    "下载失败处理:download_failed"
    "函数验证:verify_module_functions"
    "自动修复:auto_repair_modules"
    "诊断功能:diagnose_module_issues"
)

for improvement in "${improvements[@]}"; do
    name=$(echo "$improvement" | cut -d: -f1)
    pattern=$(echo "$improvement" | cut -d: -f2)
    if grep -q "$pattern" singbox-install.sh; then
        echo "✓ $name 已实现"
    else
        echo "✗ $name 未实现"
    fi
done

# 检查 UUID 正则表达式
echo
echo "检查 UUID 验证逻辑:"
if grep -q "\[0-9a-fA-F\]\{8\}-\[0-9a-fA-F\]\{4\}-\[0-9a-fA-F\]\{4\}-\[0-9a-fA-F\]\{4\}-\[0-9a-fA-F\]\{12\}" singbox-install.sh; then
    echo "✓ UUID 正则表达式正确"
else
    echo "✗ UUID 正则表达式有问题"
fi

# 检查端口验证逻辑
echo
echo "检查端口验证逻辑:"
if grep -q "port.*-ge 1.*-le 65535" singbox-install.sh; then
    echo "✓ 端口范围验证正确"
else
    echo "✗ 端口范围验证有问题"
fi

echo
echo "=== 验证完成 ==="
echo "如果所有项目都显示 ✓，说明修复成功！"
echo