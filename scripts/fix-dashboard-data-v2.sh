#!/bin/bash
# ============================================
# 修复看板数据显示问题 - 改进版
# ============================================

set -e

echo "=========================================="
echo "  修复看板数据显示问题"
echo "=========================================="
echo ""

cd "$(dirname "$0")/.."
echo "📁 当前目录: $(pwd)"
echo ""

# 步骤 1: 重新构建并启动 realtime 服务
echo "步骤 1/3: 重新构建 realtime 服务..."
echo "----------------------------------------"

if command -v docker-compose &> /dev/null; then
    echo "🔨 重新构建 realtime 容器（包含新代码）..."
    docker-compose build realtime

    echo "🚀 重启 realtime 服务..."
    docker-compose up -d realtime

    echo "⏳ 等待服务启动（5秒）..."
    sleep 5

    if docker ps | grep -q funcat-realtime; then
        echo "✅ realtime 服务已启动"
    else
        echo "❌ realtime 服务启动失败"
        docker logs funcat-realtime --tail 50
        exit 1
    fi
else
    echo "❌ 未找到 docker-compose 命令"
    exit 1
fi

echo ""

# 步骤 2: 在容器内运行聚合脚本
echo "步骤 2/3: 聚合今天的涨跌停数据..."
echo "----------------------------------------"

docker exec funcat-realtime python3 /app/services/sector_aggregator.py
echo "✅ 数据聚合完成！"

echo ""

# 步骤 3: 验证数据
echo "步骤 3/3: 验证数据..."
echo "----------------------------------------"

echo "📊 查询 sector_daily_stats 表中的今日数据："
docker exec funcat-postgres psql -U funcat_user -d funcat -c "
    SELECT trade_date, sector_name,
           limit_up_count AS 涨停,
           limit_down_count AS 跌停,
           one_word_count AS 一字涨停,
           one_word_limit_down_count AS 一字跌停
    FROM sector_daily_stats
    WHERE trade_date = CURRENT_DATE
    ORDER BY limit_up_count DESC;
" 2>/dev/null || echo "⚠️  查询失败，可能还没有今日数据"

echo ""
echo "📊 查询 daily_limit_stats 表中的今日数据条数："
count=$(docker exec funcat-postgres psql -U funcat_user -d funcat -t -c "
    SELECT COUNT(*) FROM daily_limit_stats WHERE trade_date = CURRENT_DATE;
" 2>/dev/null | tr -d ' ')

echo "今日涨跌停个股数据: ${count} 条"

echo ""

# 显示 realtime 服务最新日志
echo "📝 realtime 服务日志（最后15行）："
echo "----------------------------------------"
docker logs funcat-realtime --tail 15

echo ""
echo "=========================================="
echo "  ✅ 修复完成！"
echo "=========================================="
echo ""
echo "📊 请刷新浏览器查看看板"
echo "🌐 访问地址: http://localhost:8080"
echo ""
echo "💡 说明："
echo "  - realtime 服务已使用最新代码重启"
echo "  - 每次采集后会自动聚合数据到板块统计"
echo "  - 数据每2秒自动更新"
echo ""
echo "🔍 如果看板仍显示0："
echo "  1. 等待下一次采集（2秒）"
echo "  2. 检查是否是交易时间（有涨跌停数据）"
echo "  3. 查看日志: docker logs -f funcat-realtime"
echo ""
