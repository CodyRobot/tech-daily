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
TMP_DIR="/tmp/tech-daily-$DATE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

mkdir -p "$TMP_DIR"
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
curl -s -X POST https://api.tavily.com/search \
    -H "Content-Type: application/json" \
    -d "{
        \"api_key\": \"$TAVILY_API\",
        \"query\": \"量子位 机器之心 36 氪 AI 大模型 人工智能 $DATE\",
        \"search_depth\": \"advanced\",
        \"time_range\": \"day\",
        \"max_results\": 10,
        \"include_domains\": [\"weixin.qq.com\", \"qq.com\", \"36kr.com\", \"jiqizhixin.com\", \"qbitai.com\", \"163.com\"]
    }" > "$TMP_DIR/zh_news.json" 2>/dev/null || echo '{"results":[]}' > "$TMP_DIR/zh_news.json"

# 国际科技新闻
curl -s -X POST https://api.tavily.com/search \
    -H "Content-Type: application/json" \
    -d "{
        \"api_key\": \"$TAVILY_API\",
        \"query\": \"AI artificial intelligence tech news LLM OpenAI Google NVIDIA Microsoft $DATE\",
        \"search_depth\": \"advanced\",
        \"time_range\": \"day\",
        \"max_results\": 10
    }" > "$TMP_DIR/intl_news.json" 2>/dev/null || echo '{"results":[]}' > "$TMP_DIR/intl_news.json"

# GitHub Trending
curl -s -X POST https://api.tavily.com/search \
    -H "Content-Type: application/json" \
    -d "{
        \"api_key\": \"$TAVILY_API\",
        \"query\": \"GitHub trending AI open source developer tools programming $DATE\",
        \"search_depth\": \"advanced\",
        \"time_range\": \"day\",
        \"max_results\": 8
    }" > "$TMP_DIR/gh_news.json" 2>/dev/null || echo '{"results":[]}' > "$TMP_DIR/gh_news.json"

# 硬件与产品
curl -s -X POST https://api.tavily.com/search \
    -H "Content-Type: application/json" \
    -d "{
        \"api_key\": \"$TAVILY_API\",
        \"query\": \"科技产品发布 手机 芯片 硬件 NVIDIA AMD Apple Samsung smartphone $DATE\",
        \"search_depth\": \"advanced\",
        \"time_range\": \"day\",
        \"max_results\": 8
    }" > "$TMP_DIR/hw_news.json" 2>/dev/null || echo '{"results":[]}' > "$TMP_DIR/hw_news.json"

log "📊 搜索完成，生成日报..."

# 用 Python 解析并生成 Markdown
python3 << 'PYTHON_SCRIPT'
import json
import random
import os
from datetime import datetime

date = os.environ.get('DATE', '2026-03-14')
tmp_dir = os.environ.get('TMP_DIR', '/tmp/tech-daily')
daily_dir = os.environ.get('DAILY_DIR', '/home/hsclaw/.openclaw/workspace/tech-daily/daily')

def load_news(filename):
    try:
        with open(f"{tmp_dir}/{filename}", "r", encoding="utf-8") as f:
            return json.load(f)
    except:
        return {"results": []}

def parse_results(results, max_items=5):
    """解析搜索结果，生成 Markdown 列表"""
    items = []
    for r in results[:max_items]:
        title = r.get('title', '')
        url = r.get('url', '')
        content = r.get('content', '')[:200]
        
        # 提取来源
        source = ""
        if "量子位" in title or "qbitai" in url or "qb" in url:
            source = "量子位"
        elif "机器之心" in title or "jiqizhixin" in url or "Pro" in url:
            source = "机器之心"
        elif "36kr" in url:
            source = "36 氪"
        elif "163.com" in url:
            source = "网易"
        elif "huxiu" in url:
            source = "虎嗅"
        elif "tmtpost" in url:
            source = "钛媒体"
        
        if title and url:
            if source:
                items.append(f"- **{title}** 「{source}」[{url}]")
            else:
                items.append(f"- **{title}** [{url}]")
            if content and len(content) > 20:
                items.append(f"  > {content}...")
    
    return "\n".join(items) if items else "- 暂无内容"

# 加载新闻
zh_news = load_news('zh_news.json')
intl_news = load_news('intl_news.json')
gh_news = load_news('gh_news.json')
hw_news = load_news('hw_news.json')

# 生成头条速览（前 3 条）
top_results = zh_news.get('results', [])[:3]
top_stories = []
for r in top_results:
    title = r.get('title', '')
    url = r.get('url', '')
    if title and url:
        top_stories.append(f"- [{title}]({url})")
top_stories_str = "\n".join(top_stories) if top_stories else "- 暂无内容"

# 生成各板块内容
zh_content = parse_results(zh_news.get('results', []), 5)
intl_content = parse_results(intl_news.get('results', []), 5)
gh_content = parse_results(gh_news.get('results', []), 5)
hw_content = parse_results(hw_news.get('results', []), 5)

# 生成龙虾锐评
comments = [
    "今天 AI 圈挺热闹，大模型竞争越来越激烈了。",
    "硬件厂商都在押注 AI，看来 2026 年是 AI 基础设施大年。",
    "开源社区活力依旧，每天都有新项目冒出来。",
    "国内 AI 应用落地加速，场景越来越丰富。",
    "国际大厂都在卷 Agent，下一个风口没跑了。",
    "AI 工具越来越多，打工人得学会借力。",
]
comment = random.choice(comments)

# 生成日期格式
try:
    date_obj = datetime.strptime(date, "%Y-%m-%d")
    chinese_date = date_obj.strftime("%Y年%-m月%-d日")
    weekday_map = {
        "Monday": "星期一", "Tuesday": "星期二", "Wednesday": "星期三",
        "Thursday": "星期四", "Friday": "星期五", "Saturday": "星期六", "Sunday": "星期日"
    }
    weekday = weekday_map.get(date_obj.strftime("%A"), "")
except:
    chinese_date = date
    weekday = ""

# 写入文件
content = f"""# 📰 每日科技日报 · {chinese_date}

> {weekday}

---

## 🔥 头条速览

{top_stories_str}

---

## 🇨🇳 中文 AI 圈

### 量子位 & 机器之心 & 36 氪

{zh_content}

---

## 🌍 国际动态

{intl_content}

---

## 💻 开源 & 工具

### GitHub Trending

{gh_content}

---

## 📱 硬件 & 产品

{hw_content}

---

## 💡 龙虾锐评

{comment}

---

*🦞 龙虾日报 · 整理自：量子位 | 机器之心 | 36 氪 | GitHub | 国际媒体*
"""

output_file = f"{daily_dir}/{date}.md"
with open(output_file, "w", encoding="utf-8") as f:
    f.write(content)

print(f"✅ 已生成 {output_file}")
PYTHON_SCRIPT

log "📝 内容生成完成"

# 提交更改
cd "$REPO_DIR"
git add -A

if git diff --cached --quiet; then
    log "✅ 无变化，跳过提交"
    rm -rf "$TMP_DIR"
    exit 0
fi

git config user.email "cody@int64ago.com"
git config user.name "CodyRobot"
git commit -m "整理 $DATE 科技动态"

log "🚀 推送到 GitHub..."
# 尝试直接推送，失败则用代理
git push 2>/dev/null || http_proxy=$PROXY https_proxy=$PROXY git push

log "✅ 完成！查看：https://codyrobot.github.io/tech-daily/"

# 清理临时文件
rm -rf "$TMP_DIR"
