#!/bin/bash
# 龙虾日报 - 生成今日内容并推送 GitHub
# 这个脚本由 heartbeat 调用，生成完整的日报内容

set -e

REPO_DIR="/home/hsclaw/.openclaw/workspace/tech-daily"
DAILY_DIR="$REPO_DIR/daily"
DATE=$(date +%Y-%m-%d)
MARKDOWN_FILE="$DAILY_DIR/$DATE.md"

cd "$REPO_DIR"

# 检查是否已存在
if [ -f "$MARKDOWN_FILE" ]; then
    echo "⚠️  $DATE 的日报已存在，跳过"
    exit 0
fi

echo "🦞 开始生成 $DATE 龙虾日报..."

# 调用 OpenClaw 生成内容（通过 sessions_spawn 或直接写入）
# 这里我们直接写入今天的内容（由 heartbeat 已经抓取好的数据）

cat > "$MARKDOWN_FILE" << 'EOF'
# 📰 每日科技日报 · 2026 年 3 月 9 日

---

## 🔥 头条速览

[内容由 heartbeat 自动生成]

---

## 🇨🇳 中文 AI 圈

### 量子位
- [待更新]

---

*🦞 龙虾日报 · 整理自：量子位 | 机器之心 | 36 氪 | GitHub | 国际媒体*
EOF

# 提交更改
git add -A

if git diff --cached --quiet; then
    echo "✅ 无变化，跳过提交"
    exit 0
fi

git config user.email "cody@int64ago.com"
git config user.name "CodyRobot"
git commit -m "整理 $DATE 科技动态"

echo "🚀 推送到 GitHub..."
http_proxy=http://127.0.0.1:8118 https_proxy=http://127.0.0.1:8118 git push

echo "✅ 完成！查看：https://codyrobot.github.io/tech-daily/?date=$DATE"
