#!/bin/bash
# ============================================
# 诊断最高连板趋势图数据问题
# ============================================

echo "🔍 诊断最高连板趋势图数据..."
echo ""

cd "$(dirname "$0")/.."

# 检测 docker compose 命令
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    DOCKER_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    DOCKER_CMD="docker-compose"
else
    echo "❌ 未找到 docker compose 命令"
    exit 1
fi

echo "步骤 1: 检查 daily_limit_stats 表中的数据量"
echo "----------------------------------------"
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat -c "
SELECT
    COUNT(DISTINCT trade_date) AS 天数,
    MIN(trade_date) AS 最早日期,
    MAX(trade_date) AS 最晚日期,
    COUNT(*) AS 总记录数
FROM daily_limit_stats;
"

echo ""
echo "步骤 2: 检查最近30天的数据分布"
echo "----------------------------------------"
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat -c "
SELECT
    trade_date AS 日期,
    COUNT(*) AS 记录数,
    COUNT(CASE WHEN limit_type = 'limit_up' THEN 1 END) AS 涨停数
FROM daily_limit_stats
WHERE trade_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY trade_date
ORDER BY trade_date DESC
LIMIT 10;
"

echo ""
echo "步骤 3: 检查 v_daily_highest_board 视图"
echo "----------------------------------------"
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat -c "
SELECT
    trade_date AS 日期,
    highest_board AS 最高连板,
    total_limit_up_count AS 涨停总数
FROM v_daily_highest_board
ORDER BY trade_date DESC
LIMIT 10;
"

echo ""
echo "步骤 4: 检查是否有数据"
echo "----------------------------------------"
COUNT=$($DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat -t -c "SELECT COUNT(*) FROM v_daily_highest_board;")

if [ $COUNT -gt 0 ]; then
    echo "✅ v_daily_highest_board 视图有 $COUNT 条记录"
else
    echo "❌ v_daily_highest_board 视图没有数据！"
    echo ""
    echo "原因分析："
    echo "  1. daily_limit_stats 表可能没有数据"
    echo "  2. 或者数据的 limit_type 不是 'limit_up'"
    echo ""
    echo "解决方案："
    echo "  执行 30 天测试数据生成："
    echo "  $DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat < deployment/sql/10-test_data_30days.sql"
fi

echo ""
echo "步骤 5: 测试 API 响应"
echo "----------------------------------------"
API_RESPONSE=$(curl -s http://localhost:8080/api/v1/daily-highest-board?days=30)
echo "API 返回数据："
echo $API_RESPONSE | python3 -m json.tool 2>/dev/null || echo $API_RESPONSE

echo ""
echo "=========================================="
echo "🔍 诊断完成"
echo "=========================================="
