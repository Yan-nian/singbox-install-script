# 修复menu.sh语法错误 - v2.4.9

## 问题描述

在脚本执行过程中出现语法错误：
```
/tmp/singbox-modules/menu.sh: line 348: syntax error near unexpected token `else'
```

## 问题分析

在 `configure_single_protocol()` 函数中存在不匹配的 if-else 结构：
- 第340-350行的代码结构混乱
- 存在多余的 else 分支和不匹配的 fi 语句
- 缩进不一致导致逻辑混乱

## 解决方案

### 修复内容
1. **重构 configure_single_protocol 函数**
   - 移除多余的 else 分支
   - 修正 if-else 结构匹配
   - 统一代码缩进

### 具体修改
```bash
# 修复前（存在语法错误）
if generate_config "$protocol"; then
    # ... 正常逻辑
    # 询问是否启动服务
         echo ""
         if confirm_action "是否立即启动服务?"; then
             restart_service "$SERVICE_NAME"
         fi
     else  # 这里的else不匹配
         echo -e "${RED}多协议配置生成失败！${NC}"
     fi
 else   # 多余的else
     echo -e "${YELLOW}已取消多协议配置${NC}"
 fi
 
 wait_for_input
else    # 语法错误：unexpected token 'else'
    echo -e "${RED}配置生成失败！${NC}"
fi

# 修复后（语法正确）
if generate_config "$protocol"; then
    echo -e "${GREEN}配置生成成功！${NC}"
    
    # 显示配置信息
    case "$protocol" in
        "vless") show_protocol_info "VLESS Reality" ;;
        "vmess") show_protocol_info "VMess WebSocket" ;;
        "hysteria2") show_protocol_info "Hysteria2" ;;
    esac
    
    # 询问是否启动服务
    echo ""
    if confirm_action "是否立即启动服务?"; then
        restart_service "$SERVICE_NAME"
    fi
else
    echo -e "${RED}配置生成失败！${NC}"
fi

wait_for_input
```

## 测试验证

- ✅ 语法检查通过
- ✅ 函数逻辑正确
- ✅ 代码结构清晰

## 影响范围

- **文件**: `lib/menu.sh`
- **函数**: `configure_single_protocol()`
- **影响**: 修复脚本加载时的语法错误

## 版本更新

- 版本号: v2.4.8 → v2.4.9
- 修复类型: 语法错误修复
- 兼容性: 完全向后兼容

## 提交信息

```
fix: 修复menu.sh中configure_single_protocol函数的语法错误

- 移除不匹配的else分支
- 修正if-else结构
- 统一代码缩进
- 版本号更新至v2.4.9

Fixes: syntax error near unexpected token 'else' at line 348
```