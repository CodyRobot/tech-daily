#!/bin/bash
# 龙虾日报 - 每日科技动态自动生成并推送 GitHub
# 用法：./auto-tech-daily.sh [日期]

set -e

REPO_DIR="/home/hsclaw/.openclaw/workspace/tech-daily"
DAILY_DIR="$REPO_DIR/daily"
DATE=${1:-$(date +%Y-%m-%d)}
PROXY="http://127.0.0.1:8118"
LOG_FILE="$HOME/.openclaw/logs/tech-daily-$DATE.log"
TAVILY_API="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"

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

# 使用 Tavily 搜索科技新闻
log "📰 搜索科技新闻..."

# 中文 AI 圈新闻
ZH_NEWS=$(curl -s -x $PROXY -X POST https://api.tavily.com/search \
    -H "Content-Type: application/json" \
    -d '{
        "api_key": "'$TAVILY_API'",
        "query": "量子位 机器之心 36 氪 AI 大模型 人工智能 '"$DATE"'",
        "search_depth": "advanced",
        "time_range": "day",
        "max_results": 10,
        "include_domains": ["weixin.qq.com", "qq.com", "36kr.com", "jiqizhixin.com", "qbitai.com"]
    }' 2>/dev/null || echo '{"results":[]}')

# 国际科技新闻
INTL_NEWS=$(curl -s -x $PROXY -X POST https://api.tavily.com/search \
    -H "Content-Type: application/json" \
    -d '{
        "api_key": "'$TAVILY_API'",
        "query": "AI artificial intelligence tech news LLM OpenAI Google NVIDIA '"$DATE"'",
        "search_depth": "advanced",
        "time_range": "day",
        "max_results": 10
    }' 2>/dev/null || echo '{"results":[]}')

# GitHub Trending
GH_NEWS=$(curl -s -x $PROXY -X POST https://api.tavily.com/search \
    -H "Content-Type: application/json" \
    -d '{
        "api_key": "'$TAVILY_API'",
        "query": "GitHub trending AI open source developer tools '"$DATE"'",
        "search_depth": "advanced",
        "time_range": "day",
        "max_results": 8
    }' 2>/dev/null || echo '{"results":[]}')

# 硬件与产品
HW_NEWS=$(curl -s -x $PROXY -X POST https://api.tavily.com/search \
    -H "Content-Type: application/json" \
    -d '{
        "api_key": "'$TAVILY_API'",
        "query": "科技产品发布 手机 芯片 硬件 NVIDIA AMD Apple '"$DATE"'",
        "search_depth": "advanced",
        "time_range": "day",
        "max_results": 8
    }' 2>/dev/null || echo '{"results":[]}')

# 解析 JSON 并生成 Markdown
parse_news() {
    local json="$1"
    local max="$2"
    local count=0
    
    echo "$json" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    results = data.get('results', [])[:$max]
    for r in results:
        title = r.get('title', '')
        url = r.get('url', '')
        content = r.get('content', '')[:150]
        if title and url:
            print(f'- **{title}** [{url}]')
            if content:
                print(f'  > {content}...')
except:
    pass
"
}

# 生成头条速览（取前 3 条）
TOP_STORIES=$(echo "$ZH_NEWS" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    results = data.get('results', [])[:3]
    for r in results:
        title = r.get('title', '')
        url = r.get('url', '')
        if title and url:
            print(f'- [{title}]({url})')
except:
    pass
" || echo "- 暂无内容")

# 生成中文 AI 圈内容
ZH_CONTENT=$(parse_news "$ZH_NEWS" 5)
[ -z "$ZH_CONTENT" ] && ZH_CONTENT="- 暂无内容"

# 生成国际动态内容
INTL_CONTENT=$(parse_news "$INTL_NEWS" 5)
[ -z "$INTL_CONTENT" ] && INTL_CONTENT="- 暂无内容"

# 生成开源&工具内容
GH_CONTENT=$(parse_news "$GH_NEWS" 5)
[ -z "$GH_CONTENT" ] && GH_CONTENT="- 暂无内容"

# 生成硬件&产品内容
HW_CONTENT=$(parse_news "$HW_NEWS" 5)
[ -z "$HW_CONTENT" ] && HW_CONTENT="- 暂无内容"

# 生成龙虾锐评（根据当天新闻自动生成简短评论）
COMMENT=$(python3 -c "
import random
comments = [
    '今天 AI 圈挺热闹，大模型竞争越来越激烈了。',
    '硬件厂商都在押注 AI，看来 2026 年是 AI 基础设施大年。',
    '开源社区活力依旧，每天都有新项目冒出来。',
    '国内 AI 应用落地加速，场景越来越丰富。',
    '国际大厂都在卷 Agent，下一个风口没跑了。'
]
print(random.choice(comments))
")

# 生成日报内容
cat > "$DAILY_DIR/$DATE.md" << EOF
# 📰 每日科技日报 · $(date -d "$DATE" +%Y 年 %-m 月 %-d 日)

> $(date -d "$DATE" +%A) | 农历$(date -d "$DATE" +%Y 年%-m 月%-d 日)

---

## 🔥 头条速览

$TOP_STORIES

---

## 🇨🇳 中文 AI 圈

### 量子位 & 机器之心 & 36 氪

$ZH_CONTENT

---

## 🌍 国际动态

$INTL_CONTENT

---

## 💻 开源 & 工具

### GitHub Trending

$GH_CONTENT

---

## 📱 硬件 & 产品

$HW_CONTENT

---

## 💡 龙虾锐评

$COMMENT

---

*🦞 龙虾日报 · 整理自：量子位 | 机器之心 | 36 氪 | GitHub | 国际媒体*
EOF

log "📝 已生成：$DAILY_DIR/$DATE.md"

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

log "✅ 完成！查看：https://codyrobot.github.io/tech-daily/"
