#!/bin/bash

# 简单的语法测试脚本
echo "Testing syntax around line 306..."

# 从原脚本中提取第300-320行进行测试
sed -n '300,320p' singbox-all-in-one.sh > temp_test.sh

# 添加必要的头部
echo '#!/bin/bash' > test_fragment.sh
echo 'NC="\033[0m"' >> test_fragment.sh
echo 'GREEN="\033[32m"' >> test_fragment.sh
echo 'YELLOW="\033[33m"' >> test_fragment.sh
echo 'RED="\033[31m"' >> test_fragment.sh
echo 'CYAN="\033[36m"' >> test_fragment.sh
echo 'wait_for_input() { read -p "Press Enter to continue..."; }' >> test_fragment.sh
echo '' >> test_fragment.sh
cat temp_test.sh >> test_fragment.sh

echo "Testing syntax of extracted fragment..."
bash -n test_fragment.sh
if [ $? -eq 0 ]; then
    echo "✓ Fragment syntax is OK"
else
    echo "✗ Fragment has syntax errors"
fi

# 清理临时文件
rm -f temp_test.sh test_fragment.sh

echo "Done."