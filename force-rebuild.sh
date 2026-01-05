#!/bin/bash
# 强制重建并重启服务

echo "🔨 强制重新构建 realtime 服务..."
docker compose build --no-cache realtime

echo "🔄 重启服务..."
docker compose up -d realtime

echo "⏳ 等待服务启动..."
sleep 5

echo "✅ 重建完成！现在运行数据采集测试..."
docker compose exec -T realtime python3 << 'PYTHON_SCRIPT'
from services.realtime_fetcher import RealtimeFetcher
import datetime

print("🔍 测试数据采集...")
fetcher = RealtimeFetcher()
fetcher.fetch_and_save()
print("✅ 采集测试完成！")
PYTHON_SCRIPT

echo ""
echo "📊 检查数据库数据..."
docker compose exec postgres psql -U funcat_user -d funcat -c "
SELECT trade_date, COUNT(*) as count
FROM daily_limit_stats
WHERE trade_date = CURRENT_DATE
GROUP BY trade_date;
"
