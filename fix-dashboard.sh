#!/bin/bash
# -*- coding: utf-8 -*-
#
# 看板数据修复脚本 v1.0
#
# 功能：
# 1. 重新聚合数据，使用行业字段
# 2. 验证看板数据是否正确
# 3. 重启 web-ui 以加载最新数据
#
# 使用方法：
#   bash fix-dashboard.sh

set -e  # 遇到错误立即退出

echo "================================================================================"
echo "🔧 看板数据修复脚本"
echo "================================================================================"
echo ""

# 获取当前日期
TODAY=$(date +%Y-%m-%d)
echo "📅 当前日期: $TODAY"
echo ""

# ============================================
# 步骤 1: 重新构建 realtime 服务
# ============================================
echo "================================================================================"
echo "步骤 1/5: 重新构建 realtime 服务（加载新代码）"
echo "================================================================================"
echo ""

echo "🔨 构建 realtime 服务..."
docker compose build --no-cache realtime

echo ""
echo "🔄 重启 realtime 服务..."
docker compose up -d realtime

echo ""
echo "⏳ 等待服务启动..."
sleep 5

echo "✅ realtime 服务已更新"
echo ""

# ============================================
# 步骤 2: 重新运行数据聚合
# ============================================
echo "================================================================================"
echo "步骤 2/5: 重新聚合数据（使用行业字段）"
echo "================================================================================"
echo ""

echo "🔄 运行 sector_aggregator..."
docker compose exec -T realtime python3 << 'PYTHON_SCRIPT'
from services.sector_aggregator import SectorAggregator
import sys

aggregator = SectorAggregator()

if not aggregator.connect():
    print("❌ 数据库连接失败")
    sys.exit(1)

try:
    print("📊 开始聚合...")
    sector_count = aggregator.aggregate()

    if sector_count > 0:
        print(f"✅ 聚合成功！生成 {sector_count} 个板块统计")
    else:
        print("⚠️  未聚合任何数据")
        sys.exit(1)
except Exception as e:
    print(f"❌ 聚合失败: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
finally:
    aggregator.close()
PYTHON_SCRIPT

echo ""

# ============================================
# 步骤 3: 验证数据正确性
# ============================================
echo "================================================================================"
echo "步骤 3/5: 验证数据正确性"
echo "================================================================================"
echo ""

echo "📊 检查数据库聚合结果..."
docker compose exec -T postgres psql -U funcat_user -d funcat << 'SQL'
\echo '----------------------------------------'
\echo '1. 板块统计数据'
\echo '----------------------------------------'
SELECT
    COUNT(*) as sector_count,
    SUM(limit_up_count) as total_limit_up,
    SUM(limit_down_count) as total_limit_down,
    SUM(one_word_count) as total_one_word,
    MAX(trade_date) as latest_date
FROM sector_daily_stats
WHERE trade_date = CURRENT_DATE;

\echo ''
\echo '----------------------------------------'
\echo '2. 热门板块 Top5'
\echo '----------------------------------------'
SELECT
    sector_name,
    limit_up_count,
    one_word_count,
    limit_down_count
FROM sector_daily_stats
WHERE trade_date = CURRENT_DATE
ORDER BY limit_up_count DESC
LIMIT 5;

\echo ''
\echo '----------------------------------------'
\echo '3. 涨停原因统计'
\echo '----------------------------------------'
SELECT
    reason_name,
    limit_up_count
FROM limit_reason_stats
WHERE trade_date = CURRENT_DATE
ORDER BY limit_up_count DESC
LIMIT 5;
SQL

echo ""

# ============================================
# 步骤 4: 重启 web-ui
# ============================================
echo "================================================================================"
echo "步骤 4/5: 重启 web-ui 服务"
echo "================================================================================"
echo ""

echo "🔄 重启 webui..."
docker compose restart webui

echo "⏳ 等待服务启动..."
sleep 3

echo "✅ web-ui 已重启"
echo ""

# ============================================
# 步骤 5: 显示访问信息
# ============================================
echo "================================================================================"
echo "步骤 5/5: 访问看板"
echo "================================================================================"
echo ""

WEB_PORT=$(docker compose port webui 8080 2>/dev/null | cut -d: -f2 || echo "8080")

echo "📊 看板访问地址："
echo "  http://localhost:${WEB_PORT}"
echo ""
echo "🔍 验证项："
echo "  1. 板块涨停排行 显示多个行业（非'全市场'）"
echo "  2. 数据日期显示 ${TODAY}"
echo "  3. 点击涨停数量可查看个股详情"
echo "  4. 板块强度排行 显示实际行业名称"
echo ""
echo "💡 提示："
echo "  - 如果浏览器显示旧数据，请强制刷新（Ctrl+Shift+R 或 Cmd+Shift+R）"
echo "  - 如果仍有问题，请检查浏览器控制台（F12）查看API错误"
echo ""

echo "================================================================================"
echo "✅ 修复完成！"
echo "================================================================================"
echo ""
echo "如果看板仍不正常，请运行："
echo "  docker compose logs webui -f    # 查看 web-ui 日志"
echo "  docker compose logs realtime -f  # 查看 realtime 日志"
echo ""
