#!/bin/bash
# 龙虾日报 - 每日科技动态自动生成并推送 GitHub
# 用法：./auto-tech-daily.sh [日期]

set -e

REPO_DIR="/home/hsclaw/.openclaw/workspace/tech-daily"
DAILY_DIR="$REPO_DIR/daily"
DATE=${1:-$(date +%Y-%m-%d)}
LOG_FILE="$HOME/.openclaw/logs/tech-daily-$DATE.log"
TAVILY_API="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"
TMP_DIR="/tmp/tech-daily-$DATE"
RSS_SCRIPT="/home/hsclaw/.openclaw/workspace/skills/rss-feed-digest/scripts/rss_digest.py"

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

# ========== 1. RSS 抓取中文 AI 圈 ==========
log "📡 抓取 RSS（量子位、机器之心、36 氪）..."

python3 "$RSS_SCRIPT" fetch \
    --feeds \
        "https://www.qbitai.com/feed" \
        "https://www.jiqizhixin.com/feed" \
        "https://36kr.com/feed" \
    --hours 48 \
    --limit 15 \
    --format markdown \
    > "$TMP_DIR/rss_digest.md" 2>/dev/null || echo "# RSS 抓取失败" > "$TMP_DIR/rss_digest.md"

# ========== 2. Tavily 抓取国际新闻 ==========
log "🌐 搜索国际科技新闻..."

curl -s -X POST https://api.tavily.com/search \
    -H "Content-Type: application/json" \
    -d "{
        \"api_key\": \"$TAVILY_API\",
        \"query\": \"AI artificial intelligence LLM OpenAI Google NVIDIA Microsoft Anthropic $DATE\",
        \"search_depth\": \"advanced\",
        \"time_range\": \"day\",
        \"max_results\": 10,
        \"topic\": \"news\"
    }" > "$TMP_DIR/intl_news.json" 2>/dev/null || echo '{"results":[]}' > "$TMP_DIR/intl_news.json"

# ========== 3. Tavily 抓取 GitHub/开源 ==========
log "💻 搜索 GitHub Trending..."

curl -s -X POST https://api.tavily.com/search \
    -H "Content-Type: application/json" \
    -d "{
        \"api_key\": \"$TAVILY_API\",
        \"query\": \"GitHub trending AI open source developer tools programming $DATE\",
        \"search_depth\": \"advanced\",
        \"time_range\": \"day\",
        \"max_results\": 8
    }" > "$TMP_DIR/gh_news.json" 2>/dev/null || echo '{"results":[]}' > "$TMP_DIR/gh_news.json"

# ========== 4. Tavily 抓取硬件产品 ==========
log "📱 搜索硬件 & 产品新闻..."

curl -s -X POST https://api.tavily.com/search \
    -H "Content-Type: application/json" \
    -d "{
        \"api_key\": \"$TAVILY_API\",
        \"query\": \"科技产品 手机 芯片 硬件 NVIDIA AMD Apple Samsung smartphone GPU $DATE\",
        \"search_depth\": \"advanced\",
        \"time_range\": \"day\",
        \"max_results\": 8
    }" > "$TMP_DIR/hw_news.json" 2>/dev/null || echo '{"results":[]}' > "$TMP_DIR/hw_news.json"

log "📊 生成日报..."

# ========== 5. Python 整合生成 Markdown ==========
python3 << 'PYTHON_SCRIPT'
import json
import random
import os
import re
from datetime import datetime

date = os.environ.get('DATE', '2026-03-14')
tmp_dir = os.environ.get('TMP_DIR', '/tmp/tech-daily')
daily_dir = os.environ.get('DAILY_DIR', '/home/hsclaw/.openclaw/workspace/tech-daily/daily')

def parse_rss_digest(filepath):
    """解析 RSS digest Markdown"""
    items = []
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # 提取每个条目
        pattern = r'### \d+\. \[(.+?)\]\((.+?)\)\n\*\*(.+?)\*\* · (.+?)(?:\n\n> (.+?))?'
        matches = re.findall(pattern, content, re.DOTALL)
        
        for m in matches[:10]:  # 最多 10 条
            title, url, source, time, summary = m
            line = f"- **{title.strip()}** 「{source.strip()}」[{url}]"
            if summary and summary.strip():
                line += f"\n  > {summary.strip()}"
            items.append(line)
    except Exception as e:
        pass
    
    return "\n".join(items) if items else "- 暂无内容"

def load_and_parse_tavily(filename, max_items=5):
    """加载并解析 Tavily JSON"""
    items = []
    try:
        with open(f"{tmp_dir}/{filename}", "r", encoding="utf-8") as f:
            data = json.load(f)
        
        results = data.get('results', [])[:max_items]
        for r in results:
            title = r.get('title', '')
            url = r.get('url', '')
            content = r.get('content', '')[:200]
            
            if title and url:
                items.append(f"- **{title}** [{url}]")
                if content and len(content) > 30:
                    items.append(f"  > {content}...")
    except:
        pass
    
    return "\n".join(items) if items else "- 暂无内容"

def get_top_stories(rss_items, max=3):
    """提取头条（前 3 条）"""
    lines = rss_items.split('\n')
    stories = []
    for line in lines[:max]:
        match = re.search(r'\*\*(.+?)\*\*.*?\[(.+?)\]\((.+?)\)', line)
        if match:
            title, _, url = match.groups()
            stories.append(f"- [{title.strip()}]({url})")
    return "\n".join(stories) if stories else "- 暂无内容"

# 加载各板块内容
rss_content = parse_rss_digest(f"{tmp_dir}/rss_digest.md")
intl_content = load_and_parse_tavily('intl_news.json', 5)
gh_content = load_and_parse_tavily('gh_news.json', 5)
hw_content = load_and_parse_tavily('hw_news.json', 5)

# 头条速览
top_stories = get_top_stories(rss_content, 3)

# 龙虾锐评
comments = [
    "今天 AI 圈挺热闹，大模型竞争越来越激烈了。",
    "硬件厂商都在押注 AI，看来 2026 年是 AI 基础设施大年。",
    "开源社区活力依旧，每天都有新项目冒出来。",
    "国内 AI 应用落地加速，场景越来越丰富。",
    "国际大厂都在卷 Agent，下一个风口没跑了。",
    "AI 工具越来越多，打工人得学会借力。",
]
comment = random.choice(comments)

# 日期格式
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

# 生成 Markdown
content = f"""# 📰 每日科技日报 · {chinese_date}

> {weekday}

---

## 🔥 头条速览

{top_stories}

---

## 🇨🇳 中文 AI 圈

### 量子位 | 机器之心 | 36 氪

{rss_content}

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

# ========== 6. Git 提交推送 ==========
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
git push

log "✅ 完成！查看：https://codyrobot.github.io/tech-daily/"

# 清理
rm -rf "$TMP_DIR"
