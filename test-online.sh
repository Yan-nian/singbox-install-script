#!/bin/bash

# 测试在线执行的简化脚本
echo "脚本路径: $0"
echo "脚本目录: $(dirname "$0")"

# 检查是否为在线执行
if [[ "$(dirname "$0")" == "/dev/fd" ]]; then
    echo "✅ 检测到在线执行（curl管道）"
    echo "正在模拟下载模块..."
    
    # 创建临时目录
    temp_dir="/tmp/test-modules"
    mkdir -p "$temp_dir"
    
    # 模拟创建模块文件
    echo "# 测试模块" > "$temp_dir/test.sh"
    
    if [[ -f "$temp_dir/test.sh" ]]; then
        echo "✅ 模块下载和创建成功"
        source "$temp_dir/test.sh"
        echo "✅ 模块加载成功"
    else
        echo "❌ 模块创建失败"
    fi
    
    # 清理
    rm -rf "$temp_dir"
    echo "✅ 临时文件清理完成"
else
    echo "❌ 未检测到在线执行"
    echo "当前目录: $(pwd)"
    echo "脚本完整路径: $(readlink -f "$0")"
fi

echo "测试完成"