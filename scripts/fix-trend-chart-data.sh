#!/bin/bash
# ============================================
# 修复最高连板趋势图数据问题
# ============================================

echo "🔧 修复最高连板趋势图数据..."
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

echo "步骤 1: 清理旧的测试数据（2025-12-01 到 2025-12-29）"
echo "----------------------------------------"
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat -c "
DELETE FROM daily_limit_stats
WHERE trade_date >= '2025-12-01' AND trade_date < '2025-12-30';
"

echo ""
echo "步骤 2: 重新生成 30 天测试数据"
echo "----------------------------------------"
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat < deployment/sql/10-test_data_30days.sql

echo ""
echo "步骤 3: 验证数据"
echo "----------------------------------------"
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat -c "
SELECT
    COUNT(DISTINCT trade_date) AS 总天数,
    MIN(trade_date) AS 最早日期,
    MAX(trade_date) AS 最晚日期
FROM daily_limit_stats
WHERE trade_date >= '2025-12-01';
"

echo ""
echo "步骤 4: 检查趋势图视图数据"
echo "----------------------------------------"
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat -c "
SELECT
    COUNT(*) AS 记录数,
    MIN(trade_date) AS 最早,
    MAX(trade_date) AS 最晚,
    MAX(highest_board) AS 最高连板
FROM v_daily_highest_board
WHERE trade_date >= '2025-12-01';
"

echo ""
echo "=========================================="
echo "✅ 数据修复完成！"
echo "=========================================="
echo ""
echo "💡 下一步操作："
echo "  1. 刷新浏览器页面（Ctrl+Shift+R 强制刷新）"
echo "  2. 查看最高连板趋势图，应该显示 30 天折线"
echo ""
