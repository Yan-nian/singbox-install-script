#!/bin/bash

# 测试配置文件语法的脚本

echo "=== 测试配置文件语法 ==="

# 检查当前目录的config.json
if [ -f "config.json" ]; then
    echo "检查当前目录的 config.json..."
    
    # 使用jq验证JSON语法
    if command -v jq >/dev/null 2>&1; then
        if jq . config.json >/dev/null 2>&1; then
            echo "✓ JSON 语法正确"
        else
            echo "✗ JSON 语法错误"
            jq . config.json
            exit 1
        fi
    else
        echo "警告: jq 未安装，无法验证JSON语法"
    fi
    
    # 检查必要的字段
    echo "检查必要的配置字段..."
    
    # 检查VLESS Reality配置
    if grep -q '"type": "vless"' config.json; then
        echo "✓ 找到 VLESS 配置"
        
        if grep -q '"reality"' config.json; then
            echo "✓ 找到 Reality 配置"
            
            if grep -q '"max_time_difference"' config.json; then
                echo "✓ 找到 max_time_difference 字段"
            else
                echo "✗ 缺少 max_time_difference 字段"
                exit 1
            fi
        else
            echo "✗ 缺少 Reality 配置"
            exit 1
        fi
    else
        echo "- 未找到 VLESS 配置（可能是其他协议配置）"
    fi
    
    echo "✓ 配置文件检查完成"
else
    echo "✗ config.json 文件不存在"
    exit 1
fi