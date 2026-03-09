#!/bin/bash
# 更新 index.html 的日期列表

set -e

REPO_DIR="/home/hsclaw/.openclaw/workspace/tech-daily"
DAILY_DIR="$REPO_DIR/daily"
INDEX_FILE="$REPO_DIR/index.html"

cd "$REPO_DIR"

# 获取所有日报文件（按日期倒序）
DAYS=$(ls -1 "$DAILY_DIR" | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}\.md$' | sed 's/\.md$//' | sort -r)

# 生成 JavaScript 数组内容
JS_ARRAY=""
for day in $DAYS; do
    if [ -n "$JS_ARRAY" ]; then
        JS_ARRAY="$JS_ARRAY,"$'\n'
    fi
    JS_ARRAY="$JS_ARRAY            { date: '$day', title: '$day' }"
done

# 创建临时文件
TMP_FILE=$(mktemp)

# 读取 index.html 并替换 dailyFiles 数组
in_array=0
while IFS= read -r line; do
    if [[ "$line" == *"const dailyFiles = ["* ]]; then
        echo "        const dailyFiles = ["
        echo "$JS_ARRAY"
        echo "        ];"
        in_array=1
    elif [[ "$line" == *"        ];"* ]] && [[ $in_array -eq 1 ]]; then
        in_array=0
    elif [[ $in_array -eq 0 ]]; then
        echo "$line"
    fi
done < "$INDEX_FILE" > "$TMP_FILE"

mv "$TMP_FILE" "$INDEX_FILE"

echo "✅ 已更新 index.html 日期列表"
echo "包含日期："
echo "$DAYS" | head -10
