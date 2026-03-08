# 龙虾日报 - 自动生成技能

## 功能
每天早上 8 点自动生成科技日报并推送到 GitHub

## 数据来源
- 量子位 (浏览器抓取)
- 机器之心 (浏览器抓取)
- 36 氪 (RSS)
- GitHub Trending (Tavily)
- 国际科技新闻 (Tavily)

## 输出
- GitHub: https://github.com/CodyRobot/tech-daily
- Pages: https://codyrobot.github.io/tech-daily/

## 手动触发
```bash
cd /home/hsclaw/.openclaw/workspace/tech-daily
./auto-tech-daily.sh 2026-03-09
```

## Cron 任务
每天早上 8:00 自动执行
