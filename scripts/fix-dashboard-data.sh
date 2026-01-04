#!/bin/bash
# ============================================
# 修复看板数据显示问题
# ============================================
#
# 问题：AKShare运行正常，但看板显示全是0
# 原因：缺少将个股数据聚合成板块统计的步骤
# 解决：运行此脚本聚合历史数据并重启realtime服务
#
# ============================================

set -e  # 遇到错误立即退出

echo "=========================================="
echo "  修复看板数据显示问题"
echo "=========================================="
echo ""

# 进入项目根目录
cd "$(dirname "$0")/.."
echo "📁 当前目录: $(pwd)"
echo ""

# 1. 聚合今天的数据
echo "步骤 1/3: 聚合今天的涨跌停数据..."
echo "----------------------------------------"

if [ -f "services/sector_aggregator.py" ]; then
    docker exec funcat-realtime python3 /app/services/sector_aggregator.py || {
        echo "⚠️  容器内聚合失败，尝试宿主机执行..."
        python3 services/sector_aggregator.py
    }
    echo "✅ 数据聚合完成！"
else
    echo "❌ 找不到 services/sector_aggregator.py"
    exit 1
fi

echo ""

# 2. 重启 realtime 服务（使用更新后的代码）
echo "步骤 2/3: 重启 realtime 服务..."
echo "----------------------------------------"

if command -v docker &> /dev/null; then
    # 重新构建并启动服务
    docker-compose up -d --build realtime

    # 等待服务启动
    sleep 3

    # 检查服务状态
    if docker ps | grep -q funcat-realtime; then
        echo "✅ realtime 服务已重启"

        # 显示日志
        echo ""
        echo "实时日志（最后20行）："
        docker logs funcat-realtime --tail 20
    else
        echo "❌ realtime 服务启动失败"
        docker logs funcat-realtime --tail 50
        exit 1
    fi
else
    echo "⚠️  未找到 docker 命令，跳过重启"
fi

echo ""

# 3. 验证数据
echo "步骤 3/3: 验证数据..."
echo "----------------------------------------"

if command -v docker &> /dev/null; then
    echo "查询 sector_daily_stats 表中的今日数据："
    docker exec funcat-postgres psql -U funcat_user -d funcat -c "
        SELECT trade_date, sector_name, limit_up_count, limit_down_count,
               one_word_count, one_word_limit_down_count
        FROM sector_daily_stats
        WHERE trade_date = CURRENT_DATE
        ORDER BY limit_up_count DESC;
    "

    echo ""
    echo "查询 daily_limit_stats 表中的今日数据条数："
    docker exec funcat-postgres psql -U funcat_user -d funcat -t -c "
        SELECT COUNT(*) FROM daily_limit_stats WHERE trade_date = CURRENT_DATE;
    "
fi

echo ""
echo "=========================================="
echo "  ✅ 修复完成！"
echo "=========================================="
echo ""
echo "📊 请刷新浏览器查看看板"
echo "🌐 访问地址: http://localhost:8080"
echo ""
echo "💡 说明："
echo "  - realtime 服务现在会自动聚合数据"
echo "  - 每次采集后自动更新板块统计"
echo "  - 如果看板仍显示0，请等待下一次采集（2秒）"
echo ""
