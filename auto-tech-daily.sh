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

# ========== 1. RSS 抓取 ==========
log "📡 抓取 RSS（完整版）..."

# 中文 RSS
CN_FEEDS=(
    "https://www.qbitai.com/feed"                    # 量子位
    "https://www.jiqizhixin.com/feed"                # 机器之心
    "https://www.huxiu.com/rss/0.xml"                # 虎嗅
    "https://www.tmtpost.com/feed"                   # 钛媒体
    "https://www.solidot.org/index.rss"              # Solidot
    "https://www.oschina.net/news/rss"               # 开源中国
    "https://sspai.com/feed"                         # 少数派
)

# 英文 RSS
EN_FEEDS=(
    "https://techcrunch.com/feed/"                   # TechCrunch
    "https://www.theverge.com/rss/index.xml"         # The Verge
    "https://hnrss.org/frontpage"                    # Hacker News
    "https://www.technologyreview.com/feed/"         # MIT Tech Review
    "https://www.anthropic.com/rss.xml"              # Anthropic
    "https://openai.com/blog/rss.xml"                # OpenAI
    "https://blogs.nvidia.com/feed/"                 # NVIDIA
)

# 合并抓取
python3 "$RSS_SCRIPT" fetch \
    --feeds "${CN_FEEDS[@]}" "${EN_FEEDS[@]}" \
    --hours 48 \
    --limit 100 \
    --format markdown \
    > "$TMP_DIR/rss_digest.md" 2>/dev/null || echo "# RSS 抓取失败" > "$TMP_DIR/rss_digest.md"

# ========== 2. Tavily 搜索 ==========
log "🌐 搜索国际科技新闻..."

curl -s -X POST https://api.tavily.com/search \
    -H "Content-Type: application/json" \
    -d "{
        \"api_key\": \"$TAVILY_API\",
        \"query\": \"AI artificial intelligence LLM OpenAI Google NVIDIA Microsoft Anthropic Claude $DATE\",
        \"search_depth\": \"advanced\",
        \"time_range\": \"day\",
        \"max_results\": 15,
        \"topic\": \"news\"
    }" > "$TMP_DIR/intl_news.json" 2>/dev/null || echo '{"results":[]}' > "$TMP_DIR/intl_news.json"

log "💻 搜索 GitHub Trending..."

curl -s -X POST https://api.tavily.com/search \
    -H "Content-Type: application/json" \
    -d "{
        \"api_key\": \"$TAVILY_API\",
        \"query\": \"GitHub trending AI open source developer tools programming $DATE\",
        \"search_depth\": \"advanced\",
        \"time_range\": \"day\",
        \"max_results\": 10
    }" > "$TMP_DIR/gh_news.json" 2>/dev/null || echo '{"results":[]}' > "$TMP_DIR/gh_news.json"

log "📱 搜索硬件 & 产品新闻..."

curl -s -X POST https://api.tavily.com/search \
    -H "Content-Type: application/json" \
    -d "{
        \"api_key\": \"$TAVILY_API\",
        \"query\": \"科技产品 手机 芯片 硬件 NVIDIA AMD Apple Samsung smartphone GPU AI chip $DATE\",
        \"search_depth\": \"advanced\",
        \"time_range\": \"day\",
        \"max_results\": 10
    }" > "$TMP_DIR/hw_news.json" 2>/dev/null || echo '{"results":[]}' > "$TMP_DIR/hw_news.json"

log "🧠 智能筛选去重..."

# ========== 3. Python 智能筛选 + 生成 ==========
python3 << 'PYTHON_SCRIPT'
import json
import random
import os
import re
from datetime import datetime
from difflib import SequenceMatcher

date = os.environ.get('DATE', '2026-03-14')
tmp_dir = os.environ.get('TMP_DIR', '/tmp/tech-daily')
daily_dir = os.environ.get('DAILY_DIR', '/home/hsclaw/.openclaw/workspace/tech-daily/daily')

# ============ 去重函数 ============
def similarity(a, b):
    """计算两个字符串的相似度"""
    return SequenceMatcher(None, a.lower(), b.lower()).ratio()

def deduplicate(items, threshold=0.7):
    """去重：相似度超过阈值的只保留第一个"""
    result = []
    seen_titles = []
    
    for item in items:
        title = item.get('title', '')
        is_dup = False
        
        for seen in seen_titles:
            if similarity(title, seen) > threshold:
                is_dup = True
                break
        
        if not is_dup:
            result.append(item)
            seen_titles.append(title)
    
    return result

# ============ 重要性评分 ============
def score_item(item):
    """给新闻打分，越高越重要"""
    title = item.get('title', '').lower()
    source = item.get('source', '').lower()
    url = item.get('url', '').lower()
    score = 0
    
    # 来源权重
    if any(s in source for s in ['量子位', '机器之心', 'openai', 'anthropic', 'nvidia']):
        score += 30
    elif any(s in source for s in ['虎嗅', '钛媒体', 'techcrunch', 'verge']):
        score += 20
    elif any(s in source for s in ['solidot', 'hacker news', 'MIT']):
        score += 15
    else:
        score += 10
    
    # 关键词权重
    ai_keywords = ['gpt', 'claude', 'llm', '大模型', 'AI', '人工智能', 'agent', 'openai', 'anthropic', 'deepseek']
    for kw in ai_keywords:
        if kw in title:
            score += 5
    
    # 头条/重磅关键词
    breaking_keywords = ['发布', '上线', '重磅', '首次', '突破', '融资', '收购', '裁员', '发布']
    for kw in breaking_keywords:
        if kw in title:
            score += 10
    
    # 短标题加分（通常是重磅）
    if 10 < len(title) < 40:
        score += 5
    
    item['score'] = score
    return item

# ============ 解析 RSS ============
def parse_rss_digest(filepath):
    """解析 RSS digest Markdown"""
    items = []
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        pattern = r'### \d+\. \[(.+?)\]\((.+?)\)\n\*\*(.+?)\*\* · (.+?)(?:\n\n> (.+?))?'
        matches = re.findall(pattern, content, re.DOTALL)
        
        for m in matches:
            title, url, source, time, summary = m
            items.append({
                'title': title.strip(),
                'url': url.strip(),
                'source': source.strip(),
                'time': time.strip(),
                'summary': summary.strip() if summary else '',
                'type': 'rss'
            })
    except Exception as e:
        pass
    
    return items

# ============ 解析 Tavily ============
def load_and_parse_tavily(filename, source_prefix=''):
    """加载并解析 Tavily JSON"""
    items = []
    
    try:
        with open(f"{tmp_dir}/{filename}", "r", encoding="utf-8") as f:
            data = json.load(f)
        
        results = data.get('results', [])
        for r in results:
            title = r.get('title', '')
            url = r.get('url', '')
            content = r.get('content', '')[:200]
            
            if title and url:
                items.append({
                    'title': title,
                    'url': url,
                    'source': source_prefix,
                    'summary': content,
                    'type': 'tavily'
                })
    except:
        pass
    
    return items

# ============ 加载所有新闻 ============
rss_items = parse_rss_digest(f"{tmp_dir}/rss_digest.md")
intl_items = load_and_parse_tavily('intl_news.json', '国际媒体')
gh_items = load_and_parse_tavily('gh_news.json', 'GitHub')
hw_items = load_and_parse_tavily('hw_news.json', '硬件')

# ============ 分类 + 去重 + 评分 ============

# 中文新闻（RSS）
cn_items = [item for item in rss_items if any(s in item.get('source', '') for s in ['量子位', '机器之心', '虎嗅', '钛媒体', 'Solidot', '开源中国', '少数派'])]
cn_items = deduplicate(cn_items, 0.6)
cn_items = [score_item(item) for item in cn_items]
cn_items.sort(key=lambda x: x['score'], reverse=True)

# 英文新闻（RSS + Tavily）
en_items_rss = [item for item in rss_items if item not in cn_items]
en_items_tavily = intl_items
en_items = deduplicate(en_items_rss + en_items_tavily, 0.6)
en_items = [score_item(item) for item in en_items]
en_items.sort(key=lambda x: x['score'], reverse=True)

# GitHub
gh_items = deduplicate(gh_items, 0.6)
gh_items = [score_item(item) for item in gh_items]
gh_items.sort(key=lambda x: x['score'], reverse=True)

# 硬件
hw_items = deduplicate(hw_items, 0.6)
hw_items = [score_item(item) for item in hw_items]
hw_items.sort(key=lambda x: x['score'], reverse=True)

# ============ 生成 Markdown ============
def format_item(item):
    """格式化单个条目"""
    title = item.get('title', '')
    url = item.get('url', '')
    source = item.get('source', '')
    summary = item.get('summary', '')
    
    line = f"- **{title}** [{url}]"
    if source:
        line = f"- **{title}** 「{source}」[{url}]"
    if summary and len(summary) > 30:
        line += f"\n  > {summary}..."
    
    return line

# 头条速览（Top 5，综合评分最高）
all_items = cn_items[:10] + en_items[:10]
all_items.sort(key=lambda x: x['score'], reverse=True)
top_stories = []
for item in all_items[:5]:
    title = item.get('title', '')
    url = item.get('url', '')
    if title and url:
        top_stories.append(f"- [{title}]({url})")
top_stories_str = "\n".join(top_stories) if top_stories else "- 暂无内容"

# 各板块内容（限制数量）
cn_content = "\n".join([format_item(item) for item in cn_items[:12]]) if cn_items else "- 暂无内容"
en_content = "\n".join([format_item(item) for item in en_items[:10]]) if en_items else "- 暂无内容"
gh_content = "\n".join([format_item(item) for item in gh_items[:5]]) if gh_items else "- 暂无内容"
hw_content = "\n".join([format_item(item) for item in hw_items[:5]]) if hw_items else "- 暂无内容"

# 龙虾锐评
comments = [
    "今天 AI 圈挺热闹，大模型竞争越来越激烈了。",
    "硬件厂商都在押注 AI，看来 2026 年是 AI 基础设施大年。",
    "开源社区活力依旧，每天都有新项目冒出来。",
    "国内 AI 应用落地加速，场景越来越丰富。",
    "国际大厂都在卷 Agent，下一个风口没跑了。",
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

# 写入文件
content = f"""# 📰 每日科技日报 · {chinese_date}

> {weekday}

---

## 🔥 头条速览（精选 Top 5）

{top_stories_str}

---

## 🇨🇳 中文 AI 圈（精选 12 条）

### 量子位 | 机器之心 | 虎嗅 | 钛媒体 | Solidot

{cn_content}

---

## 🌍 国际动态（精选 10 条）

### TechCrunch | The Verge | MIT Tech Review | Hacker News

{en_content}

---

## 💻 开源 & 工具（精选 5 条）

### GitHub Trending

{gh_content}

---

## 📱 硬件 & 产品（精选 5 条）

{hw_content}

---

## 💡 龙虾锐评

{comment}

---

*🦞 龙虾日报 · 智能筛选去重 · 整理自：14+ 全球科技媒体*
"""

output_file = f"{daily_dir}/{date}.md"
with open(output_file, "w", encoding="utf-8") as f:
    f.write(content)

print(f"✅ 已生成 {output_file}")
print(f"📊 统计：中文{len(cn_items)}条 → 精选 12 条 | 国际{len(en_items)}条 → 精选 10 条 | GitHub {len(gh_items)}条 | 硬件{len(hw_items)}条")
PYTHON_SCRIPT

log "📝 内容生成完成"

# ========== 4. Git 提交推送 ==========
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
