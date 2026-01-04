#!/bin/bash
# ============================================
# 修复数据库 - 简化版
# ============================================

echo "🔧 修复 Funcat 数据库"
echo "========================================"
echo ""

# 检查 docker compose 命令
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    DOCKER_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    DOCKER_CMD="docker-compose"
else
    echo "❌ 错误：未找到 docker compose 命令"
    exit 1
fi

cd "$(dirname "$0")/.."
echo "📁 工作目录: $(pwd)"
echo ""

# 步骤 1: 创建基础表结构
echo "📝 步骤 1/5: 创建基础表结构..."
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat < deployment/sql/schema.sql
if [ $? -eq 0 ]; then
    echo "✅ 基础表结构创建成功"
else
    echo "❌ 失败"
    exit 1
fi
echo ""

# 步骤 2: 创建 Web UI 表
echo "📝 步骤 2/5: 创建 Web UI 表..."
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat < deployment/sql/webui_tables.sql
if [ $? -eq 0 ]; then
    echo "✅ Web UI 表创建成功"
else
    echo "❌ 失败"
    exit 1
fi
echo ""

# 步骤 3: 创建炒股养家心法功能
echo "📝 步骤 3/5: 创建炒股养家心法功能..."
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat < deployment/sql/05-yangjia_schema_fixed.sql
if [ $? -eq 0 ]; then
    echo "✅ 炒股养家心法功能创建成功"
else
    echo "⚠️  警告：创建失败（可能已存在）"
fi
echo ""

# 步骤 4: 创建板块强度排行功能
echo "📝 步骤 4/5: 创建板块强度排行功能..."
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat < deployment/sql/06-sector_strength.sql
if [ $? -eq 0 ]; then
    echo "✅ 板块强度排行功能创建成功"
else
    echo "❌ 失败"
    exit 1
fi
echo ""

# 步骤 5: 导入测试数据
echo "📝 步骤 5/5: 导入测试数据..."
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat < deployment/sql/test_data.sql
if [ $? -eq 0 ]; then
    echo "✅ 测试数据导入成功"
else
    echo "⚠️  警告：部分数据可能已存在"
fi
echo ""

# 验证
echo "========================================"
echo "✅ 验证数据库..."
echo "========================================"
echo ""

echo "📊 表统计："
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat -c "
SELECT
    schemaname,
    COUNT(*) AS table_count
FROM pg_tables
WHERE schemaname = 'public'
GROUP BY schemaname;
"

echo ""
echo "📊 数据统计："
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat -c "
SELECT
    '板块数' AS 项目,
    COUNT(*)::TEXT AS 数量
FROM sectors
UNION ALL
SELECT
    '板块统计数据' AS 项目,
    COUNT(*)::TEXT AS 数量
FROM sector_daily_stats
UNION ALL
SELECT
    '涨停统计数据' AS 项目,
    COUNT(*)::TEXT AS 数量
FROM daily_limit_stats;
"

echo ""
echo "🔥 板块强度排行（前3名）："
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat -c "
SELECT
    trade_date AS 日期,
    sector_name AS 板块,
    limit_up_count AS 涨停数,
    ROUND(strength_score, 2) AS 强度分,
    strength_grade AS 等级
FROM v_sector_strength_ranking
WHERE trade_date = '2025-12-30'
ORDER BY strength_score DESC
LIMIT 3;
"

echo ""
echo "🏆 连板天梯（前3名）："
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat -c "
SELECT
    stock_name AS 股票,
    consecutive_days AS 连板天数,
    start_date AS 日期,
    ROUND(total_gain_pct::NUMERIC, 2) AS 涨幅
FROM v_consecutive_ladder
ORDER BY consecutive_days DESC
LIMIT 3;
"

echo ""
echo "========================================"
echo "🎉 修复完成！"
echo "========================================"
echo ""
echo "📊 访问地址："
echo "   Web UI: http://localhost:8081"
echo "   测试数据日期: 2025-12-30"
echo ""
