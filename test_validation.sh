#!/bin/bash

# 测试脚本 - 验证install.sh的修复功能

# 测试端口验证函数
test_port_validation() {
    echo "=== 测试端口验证功能 ==="
    
    # 临时禁用root检查
    check_root() { return 0; }
    
    # 导入install.sh中的函数
    source install.sh
    
    # 测试有效端口
    echo "测试有效端口..."
    if validate_port 443; then
        echo "✓ 端口443验证通过"
    else
        echo "✗ 端口443验证失败"
    fi
    
    # 测试无效端口
    echo "测试无效端口..."
    if ! validate_port 70000; then
        echo "✓ 端口70000正确被拒绝"
    else
        echo "✗ 端口70000应该被拒绝"
    fi
    
    # 测试字符串端口
    if ! validate_port "abc"; then
        echo "✓ 字符串端口正确被拒绝"
    else
        echo "✗ 字符串端口应该被拒绝"
    fi
    
    echo ""
}

# 测试UUID生成
test_uuid_generation() {
    echo "=== 测试UUID生成功能 ==="
    
    # 临时禁用root检查
    check_root() { return 0; }
    
    source install.sh
    
    uuid1=$(generate_uuid)
    uuid2=$(generate_uuid)
    
    echo "生成的UUID1: $uuid1"
    echo "生成的UUID2: $uuid2"
    
    if [[ "$uuid1" != "$uuid2" ]]; then
        echo "✓ UUID生成正常（不重复）"
    else
        echo "✗ UUID生成异常（重复）"
    fi
    
    echo ""
}

# 测试随机端口生成
test_random_port() {
    echo "=== 测试随机端口生成 ==="
    
    # 临时禁用root检查
    check_root() { return 0; }
    
    source install.sh
    
    port=$(generate_random_port)
    echo "生成的随机端口: $port"
    
    if [[ "$port" -ge 10000 && "$port" -le 65535 ]]; then
        echo "✓ 随机端口在有效范围内"
    else
        echo "✗ 随机端口超出有效范围"
    fi
    
    echo ""
}

# 测试配置文件语法
test_config_syntax() {
    echo "=== 测试配置文件语法 ==="
    
    if bash -n install.sh; then
        echo "✓ 脚本语法正确"
    else
        echo "✗ 脚本语法错误"
    fi
    
    echo ""
}

# 主测试函数
main() {
    echo "开始测试install.sh修复功能..."
    echo "================================="
    
    test_config_syntax
    test_port_validation
    test_uuid_generation
    test_random_port
    
    echo "测试完成！"
}

# 运行测试
main "$@"
