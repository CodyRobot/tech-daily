#!/bin/bash
# 每日科技日报自动生成脚本
# 用法：./generate-daily-news.sh [日期]
# 日期格式：YYYY-MM-DD，默认为今天

set -e

REPO_DIR="/home/hsclaw/.openclaw/workspace/tech-daily"
DAILY_DIR="$REPO_DIR/daily"
INDEX_FILE="$REPO_DIR/index.html"
DATE=${1:-$(date +%Y-%m-%d)}
WEEKDAY=$(date -d "$DATE" +%A)

# 中文星期转换
case $WEEKDAY in
    Sunday) WEEKDAY_CN="星期日" ;;
    Monday) WEEKDAY_CN="星期一" ;;
    Tuesday) WEEKDAY_CN="星期二" ;;
    Wednesday) WEEKDAY_CN="星期三" ;;
    Thursday) WEEKDAY_CN="星期四" ;;
    Friday) WEEKDAY_CN="星期五" ;;
    Saturday) WEEKDAY_CN="星期六" ;;
esac

cd "$REPO_DIR"

# 检查是否已存在该日期的日报
if [ -f "$DAILY_DIR/$DATE.md" ]; then
    echo "⚠️  $DATE 的日报已存在"
    exit 0
fi

# 生成日报内容
cat > "$DAILY_DIR/$DATE.md" << EOF
# 📰 每日科技日报

**日期**: $(date -d "$DATE" +%Y 年 %-m 月 %-d 日)  
**星期**: $WEEKDAY_CN

---

## 🔥 今日热点

### AI 与大模型
- [待更新]

### 开发者工具
- [待更新]

### 开源动态
- [待更新]

---

## 💻 技术前沿

### 前端开发
- [待更新]

### 后端技术
- [待更新]

### DevOps
- [待更新]

---

## 📱 产品发布

### 硬件
- [待更新]

### 软件
- [待更新]

---

## 🔬 科研进展

- [待更新]

---

## 📊 数据看板

| 指标 | 数值 |
|------|------|
| GitHub Star 项目 | 待更新 |
| NPM 包数量 | 待更新 |
| AI 模型参数量 | 待更新 |

---

## 💡 今日思考

> 技术的价值在于解决实际问题，而非追逐热点。

---

## 📝 明日预告

- [待更新]

---

*本报由 OpenClaw 🦞 自动整理生成*
EOF

echo "✅ 生成 $DATE 的日报"

# 更新 index.html 中的日期列表
# 这里简单处理，实际应该用更智能的方式更新 JavaScript 数组

# 提交更改
git add -A
git commit -m "Add daily tech news for $DATE" || echo "No changes to commit"
http_proxy=http://127.0.0.1:8118 https_proxy=http://127.0.0.1:8118 git push

echo "🚀 已推送到 GitHub"
echo "📄 查看：https://codyrobot.github.io/tech-daily/?date=$DATE"
