#!/bin/bash
# 快速部署脚本 - 适用于有 Docker 的环境

set -e

echo "🚀 开始部署实时动态板块分析..."
echo "======================================"

# 1. 拉取最新代码
echo ""
echo "📦 步骤 1/4: 拉取最新代码"
git pull origin claude/debug-dashboard-akshare-9Igcv

# 2. 重启 realtime 服务
echo ""
echo "🔄 步骤 2/4: 重启 realtime 服务"
docker compose restart realtime

# 等待服务启动
echo "⏳ 等待服务启动..."
sleep 5

# 3. 手动触发数据采集和聚合
echo ""
echo "⚡ 步骤 3/4: 立即采集和聚合数据（正常每2秒自动更新）"
docker compose exec -T realtime python3 << 'PYTHON_SCRIPT'
from services.realtime_fetcher import RealtimeFetcher
from services.sector_aggregator import SectorAggregator
import datetime

try:
    # 1. 采集今日数据
    print("🔍 开始采集实时数据...")
    fetcher = RealtimeFetcher()
    trade_date = datetime.datetime.now().strftime('%Y-%m-%d')
    stocks_count = fetcher.fetch_and_save(trade_date)
    print(f"✅ 采集完成！共 {stocks_count} 只股票")

    # 2. 重新聚合板块
    print("\n📊 开始聚合板块数据...")
    aggregator = SectorAggregator()
    sectors_count = aggregator.aggregate(trade_date)
    print(f"✅ 聚合完成！共 {sectors_count} 个板块")

    print("\n🎉 数据更新完成！")
except Exception as e:
    print(f"❌ 错误: {e}")
    import traceback
    traceback.print_exc()
    exit(1)
PYTHON_SCRIPT

# 4. 验证数据
echo ""
echo "🔍 步骤 4/4: 验证板块数据"
docker compose exec -T postgres psql -U funcat_user -d funcat << 'SQL'
-- 查看今天的板块统计
SELECT
    sector_name,
    limit_up_count,
    one_word_count,
    limit_down_count,
    broken_count,
    total_stocks
FROM sector_daily_stats
WHERE trade_date = CURRENT_DATE
ORDER BY limit_up_count DESC
LIMIT 10;
SQL

echo ""
echo "======================================"
echo "✅ 部署完成！"
echo ""
echo "📱 请打开浏览器访问: http://localhost:8080"
echo "🔄 刷新页面查看板块细分数据"
echo ""
echo "💡 提示: 如果还是显示'全市场'，请检查上面的输出日志"
