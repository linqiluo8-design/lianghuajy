#!/bin/bash
# -*- coding: utf-8 -*-
#
# 历史数据清理脚本 v1.0
#
# 功能：
# 1. 显示当前数据状态
# 2. 只保留最新日期的数据
# 3. 删除所有历史数据
# 4. 支持安全确认机制
#
# 使用方法：
#   bash cleanup-old-data.sh
#
# 危险操作：此脚本会删除历史数据，请谨慎使用！

set -e  # 遇到错误立即退出

echo "================================================================================"
echo "🧹 历史数据清理脚本"
echo "================================================================================"
echo ""
echo "⚠️  警告：此脚本会删除历史数据，只保留最新日期的数据！"
echo ""

# ============================================
# 步骤 1: 显示当前数据状态
# ============================================
echo "================================================================================"
echo "步骤 1/4: 检查当前数据状态"
echo "================================================================================"
echo ""

echo "📊 查询数据库状态..."
docker compose exec -T postgres psql -U funcat_user -d funcat << 'SQL'
\echo '----------------------------------------'
\echo '1. daily_limit_stats 表'
\echo '----------------------------------------'
SELECT
    trade_date,
    COUNT(*) as record_count,
    SUM(CASE WHEN limit_type = 'limit_up' THEN 1 ELSE 0 END) as limit_up,
    SUM(CASE WHEN limit_type = 'limit_down' THEN 1 ELSE 0 END) as limit_down
FROM daily_limit_stats
GROUP BY trade_date
ORDER BY trade_date DESC
LIMIT 10;

\echo ''
\echo '----------------------------------------'
\echo '2. sector_daily_stats 表'
\echo '----------------------------------------'
SELECT
    trade_date,
    COUNT(*) as sector_count,
    SUM(limit_up_count) as total_limit_up
FROM sector_daily_stats
GROUP BY trade_date
ORDER BY trade_date DESC
LIMIT 10;

\echo ''
\echo '----------------------------------------'
\echo '3. limit_reason_stats 表'
\echo '----------------------------------------'
SELECT
    trade_date,
    COUNT(*) as reason_count,
    SUM(limit_up_count) as total_limit_up
FROM limit_reason_stats
GROUP BY trade_date
ORDER BY trade_date DESC
LIMIT 10;

\echo ''
\echo '----------------------------------------'
\echo '4. 最新数据日期'
\echo '----------------------------------------'
SELECT
    '最新日期' as label,
    MAX(trade_date) as latest_date
FROM daily_limit_stats;
SQL

echo ""

# ============================================
# 步骤 2: 用户确认
# ============================================
echo "================================================================================"
echo "步骤 2/4: 确认删除操作"
echo "================================================================================"
echo ""

# 获取最新日期
LATEST_DATE=$(docker compose exec -T postgres psql -U funcat_user -d funcat -t -c "SELECT MAX(trade_date) FROM daily_limit_stats;" | xargs)

echo "📅 最新数据日期: ${LATEST_DATE}"
echo ""
echo "⚠️  即将执行以下操作："
echo "  ✅ 保留：${LATEST_DATE} 的数据"
echo "  ❌ 删除：${LATEST_DATE} 之前的所有历史数据"
echo ""
echo "🔴 此操作不可逆！删除后无法恢复！"
echo ""

read -p "❓ 确定要继续吗？(输入 YES 继续，其他键取消): " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    echo ""
    echo "❌ 操作已取消"
    echo ""
    exit 0
fi

echo ""
echo "✅ 用户已确认，开始清理..."
echo ""

# ============================================
# 步骤 3: 执行清理
# ============================================
echo "================================================================================"
echo "步骤 3/4: 清理历史数据"
echo "================================================================================"
echo ""

echo "🧹 正在删除历史数据..."
docker compose exec -T postgres psql -U funcat_user -d funcat << SQL
-- 开始事务
BEGIN;

-- 1. 删除 daily_limit_stats 历史数据
DELETE FROM daily_limit_stats
WHERE trade_date < (SELECT MAX(trade_date) FROM daily_limit_stats);

-- 2. 删除 sector_daily_stats 历史数据
DELETE FROM sector_daily_stats
WHERE trade_date < (SELECT MAX(trade_date) FROM sector_daily_stats);

-- 3. 删除 limit_reason_stats 历史数据
DELETE FROM limit_reason_stats
WHERE trade_date < (SELECT MAX(trade_date) FROM limit_reason_stats);

-- 提交事务
COMMIT;

-- 显示删除结果
\echo ''
\echo '✅ 清理完成！'
\echo ''
SQL

echo ""

# ============================================
# 步骤 4: 验证清理结果
# ============================================
echo "================================================================================"
echo "步骤 4/4: 验证清理结果"
echo "================================================================================"
echo ""

echo "📊 清理后的数据状态..."
docker compose exec -T postgres psql -U funcat_user -d funcat << 'SQL'
\echo '----------------------------------------'
\echo '1. daily_limit_stats 表'
\echo '----------------------------------------'
SELECT
    trade_date,
    COUNT(*) as record_count,
    SUM(CASE WHEN limit_type = 'limit_up' THEN 1 ELSE 0 END) as limit_up,
    SUM(CASE WHEN limit_type = 'limit_down' THEN 1 ELSE 0 END) as limit_down
FROM daily_limit_stats
GROUP BY trade_date
ORDER BY trade_date DESC;

\echo ''
\echo '----------------------------------------'
\echo '2. sector_daily_stats 表'
\echo '----------------------------------------'
SELECT
    trade_date,
    COUNT(*) as sector_count,
    SUM(limit_up_count) as total_limit_up
FROM sector_daily_stats
GROUP BY trade_date
ORDER BY trade_date DESC;

\echo ''
\echo '----------------------------------------'
\echo '3. limit_reason_stats 表'
\echo '----------------------------------------'
SELECT
    trade_date,
    COUNT(*) as reason_count,
    SUM(limit_up_count) as total_limit_up
FROM limit_reason_stats
GROUP BY trade_date
ORDER BY trade_date DESC;

\echo ''
\echo '----------------------------------------'
\echo '4. 数据日期统计'
\echo '----------------------------------------'
SELECT
    '数据日期数' as label,
    COUNT(DISTINCT trade_date) as date_count
FROM daily_limit_stats;
SQL

echo ""

# ============================================
# 完成
# ============================================
echo "================================================================================"
echo "✅ 清理完成！"
echo "================================================================================"
echo ""
echo "📊 清理结果："
echo "  • 只保留了 ${LATEST_DATE} 的数据"
echo "  • 所有历史数据已删除"
echo ""
echo "💡 提示："
echo "  • 数据库已清理完成"
echo "  • 可以运行 bash fix-dashboard.sh 重新采集数据"
echo "  • 看板将只显示最新一天的数据"
echo ""
