#!/bin/bash
# 龙虾日报 - 每日科技动态自动生成并推送 GitHub
# 用法：./auto-tech-daily.sh [日期]

set -e

REPO_DIR="/home/hsclaw/.openclaw/workspace/tech-daily"
DAILY_DIR="$REPO_DIR/daily"
DATE=${1:-$(date +%Y-%m-%d)}
PROXY="http://127.0.0.1:8118"
LOG_FILE="$HOME/.openclaw/logs/tech-daily-$DATE.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

cd "$REPO_DIR"

# 检查是否已存在
if [ -f "$DAILY_DIR/$DATE.md" ]; then
    log "⚠️  $DATE 的日报已存在，跳过"
    exit 0
fi

log "🦞 开始生成 $DATE 龙虾日报..."

# 使用 Tavily 搜索今日科技新闻
log "📰 搜索科技新闻..."

NEWS=$(tavily_search -q "科技新闻 AI 大模型 GitHub $DATE" -c 15 --time_range day 2>/dev/null || echo "")

# 如果 tavily_search 不可用，用 curl 调用 Tavily API
if [ -z "$NEWS" ]; then
    NEWS=$(curl -s -x $PROXY -X POST https://api.tavily.com/search \
        -H "Content-Type: application/json" \
        -d '{
            "api_key": "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",
            "query": "科技新闻 AI 大模型 GitHub 量子位 机器之心 '"$DATE"'",
            "search_depth": "advanced",
            "time_range": "day",
            "max_results": 15
        }' 2>/dev/null || echo "")
fi

# 生成日报内容
cat > "$DAILY_DIR/$DATE.md" << EOF
# 📰 每日科技日报 · $(date -d "$DATE" +%Y 年 %-m 月 %-d 日)

---

## 🔥 头条速览

[待整理 - 自动抓取的内容]

---

## 🇨🇳 中文 AI 圈

### 量子位
- [待更新]

### 机器之心
- [待更新]

### 36 氪
- [待更新]

---

## 🌍 国际动态

- [待更新]

---

## 💻 开源 & 工具

### GitHub Trending
- [待更新]

---

## 📱 硬件 & 产品

- [待更新]

---

## 💡 龙虾锐评

[待整理]

---

*🦞 龙虾日报 · 整理自：量子位 | 机器之心 | 36 氪 | GitHub | 国际媒体*
EOF

log "📝 已生成框架：$DAILY_DIR/$DATE.md"

# 提交更改
cd "$REPO_DIR"
git add -A

if git diff --cached --quiet; then
    log "✅ 无变化，跳过提交"
    exit 0
fi

git config user.email "cody@int64ago.com"
git config user.name "CodyRobot"
git commit -m "整理 $DATE 科技动态"

log "🚀 推送到 GitHub..."
http_proxy=$PROXY https_proxy=$PROXY git push

log "✅ 完成！查看：https://codyrobot.github.io/tech-daily/?date=$DATE"
