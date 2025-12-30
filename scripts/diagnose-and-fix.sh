#!/bin/bash
# ============================================
# 诊断并修复数据库问题
# ============================================

set -e

echo "🔍 诊断并修复 Funcat 数据库问题"
echo "============================================"
echo ""

# 检查 docker compose 命令
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    DOCKER_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    DOCKER_CMD="docker-compose"
else
    echo "❌ 错误：未找到 docker compose 命令"
    exit 1
fi

cd "$(dirname "$0")/.."

echo "📊 步骤 1/4: 检查数据库表结构..."
echo "--------------------------------------"

# 检查表是否存在
echo "检查关键表..."
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat -c "
SELECT
    tablename,
    CASE
        WHEN tablename IN ('sectors', 'sector_daily_stats', 'daily_limit_stats') THEN '✅ 关键表'
        ELSE '📋 其他表'
    END AS status
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
" || echo "⚠️  查询表失败"

echo ""
echo "检查关键视图..."
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat -c "
SELECT
    viewname,
    CASE
        WHEN viewname IN ('v_sector_strength_ranking', 'v_consecutive_ladder') THEN '✅ 关键视图'
        ELSE '📋 其他视图'
    END AS status
FROM pg_views
WHERE schemaname = 'public'
ORDER BY viewname;
" || echo "⚠️  查询视图失败"

echo ""
echo "检查关键函数..."
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat -c "
SELECT
    proname AS function_name,
    '✅ 已创建' AS status
FROM pg_proc
WHERE proname = 'calculate_sector_strength';
" || echo "⚠️  查询函数失败"

echo ""
echo "📝 步骤 2/4: 诊断问题..."
echo "--------------------------------------"

# 检测缺失的表
MISSING_TABLES=()

# 检查 sectors 表
if ! $DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat -c "SELECT 1 FROM sectors LIMIT 1;" &> /dev/null; then
    MISSING_TABLES+=("sectors")
fi

# 检查 sector_daily_stats 表
if ! $DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat -c "SELECT 1 FROM sector_daily_stats LIMIT 1;" &> /dev/null; then
    MISSING_TABLES+=("sector_daily_stats")
fi

# 检查 daily_limit_stats 表
if ! $DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat -c "SELECT 1 FROM daily_limit_stats LIMIT 1;" &> /dev/null; then
    MISSING_TABLES+=("daily_limit_stats")
fi

if [ ${#MISSING_TABLES[@]} -eq 0 ]; then
    echo "✅ 所有关键表都存在"
else
    echo "⚠️  缺失的表: ${MISSING_TABLES[*]}"
    echo ""
    echo "🔧 步骤 3/4: 修复缺失的表..."
    echo "--------------------------------------"
    echo "正在执行 webui_tables.sql..."
    $DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat < deployment/sql/webui_tables.sql
    echo "✅ Web UI 表结构已创建"
fi

echo ""
echo "🔧 步骤 4/4: 确保所有功能完整..."
echo "--------------------------------------"

# 重新导入板块强度功能（幂等操作）
echo "导入板块强度功能..."
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat < deployment/sql/06-sector_strength.sql
echo "✅ 板块强度功能已就绪"

echo ""

# 导入测试数据
echo "导入测试数据..."
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat < deployment/sql/test_data.sql 2>&1 | grep -v "重复键违反唯一约束" || true
echo "✅ 测试数据已导入"

echo ""
echo "📊 最终验证..."
echo "--------------------------------------"

# 验证板块强度排行
echo "查询板块强度排行前3名："
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat -c "
SELECT
    trade_date,
    sector_name,
    limit_up_count AS 涨停数,
    strength_score AS 强度分数,
    strength_grade AS 等级
FROM v_sector_strength_ranking
WHERE trade_date = '2025-12-30'
ORDER BY strength_score DESC
LIMIT 3;
" || echo "⚠️  暂无数据"

echo ""

# 验证连板天梯
echo "查询连板天梯前3名："
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat -c "
SELECT
    stock_name AS 股票名称,
    consecutive_days AS 连板天数,
    start_date AS 日期,
    total_gain_pct AS 涨幅
FROM v_consecutive_ladder
ORDER BY consecutive_days DESC
LIMIT 3;
" || echo "⚠️  暂无数据"

echo ""
echo "🎉 诊断和修复完成！"
echo ""
echo "📊 访问地址："
echo "   Web UI: http://localhost:8081"
echo "   测试数据日期: 2025-12-30"
echo ""
