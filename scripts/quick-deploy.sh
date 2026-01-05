#!/bin/bash
# 智能部署脚本 v3.0 - 自动检测环境并按需执行

set -e

echo "🚀 开始部署实时动态板块分析 (智能模式)"
echo "=============================================="

# ==========================================
# 工具函数
# ==========================================

# 检查数据库字段是否存在
check_db_field() {
    local field=$1
    docker compose exec -T postgres psql -U funcat_user -d funcat -tAc "
        SELECT column_name FROM information_schema.columns
        WHERE table_name='daily_limit_stats' AND column_name='$field'
    " 2>/dev/null | tr -d '[:space:]'
}

# 检查表是否存在
check_table_exists() {
    local table=$1
    docker compose exec -T postgres psql -U funcat_user -d funcat -tAc "
        SELECT tablename FROM pg_tables
        WHERE tablename='$table'
    " 2>/dev/null | tr -d '[:space:]'
}

# 获取服务状态
check_service_status() {
    docker compose ps realtime | grep -q "Up" && echo "running" || echo "stopped"
}

# ==========================================
# 步骤 1: 拉取最新代码
# ==========================================
echo ""
echo "📦 步骤 1/5: 拉取最新代码"
BEFORE_COMMIT=$(git rev-parse HEAD)
git pull origin claude/debug-dashboard-akshare-9Igcv
AFTER_COMMIT=$(git rev-parse HEAD)

if [ "$BEFORE_COMMIT" = "$AFTER_COMMIT" ]; then
    echo "✅ 代码已是最新，无需更新"
    CODE_CHANGED=false
else
    echo "✅ 代码已更新: $BEFORE_COMMIT → $AFTER_COMMIT"
    CODE_CHANGED=true
fi

# ==========================================
# 步骤 2: 检测并执行数据库迁移
# ==========================================
echo ""
echo "🔍 步骤 2/5: 检测数据库状态"

NEED_MIGRATION=false

# 检查 concept_tags 等字段
if [ -z "$(check_db_field 'concept_tags')" ]; then
    echo "  ⚠️  字段 concept_tags 不存在，需要迁移"
    NEED_MIGRATION=true
else
    echo "  ✅ 字段 concept_tags 已存在"
fi

# 检查 limit_reason_stats 表
if [ -z "$(check_table_exists 'limit_reason_stats')" ]; then
    echo "  ⚠️  表 limit_reason_stats 不存在，需要创建"
    NEED_MIGRATION=true
else
    echo "  ✅ 表 limit_reason_stats 已存在"
fi

# 执行迁移
if [ "$NEED_MIGRATION" = true ]; then
    echo ""
    echo "📊 执行数据库迁移..."

    # 应用字段迁移
    if [ -z "$(check_db_field 'concept_tags')" ]; then
        echo "  → 添加板块字段..."
        docker compose exec -T postgres psql -U funcat_user -d funcat < migrations/004_add_sector_fields.sql
    fi

    # 创建涨停原因表
    if [ -z "$(check_table_exists 'limit_reason_stats')" ]; then
        echo "  → 创建涨停原因统计表..."
        docker compose exec -T postgres psql -U funcat_user -d funcat < migrations/005_create_limit_reason_stats.sql
    fi

    echo "✅ 数据库迁移完成"
else
    echo "✅ 数据库结构正常，跳过迁移"
fi

# ==========================================
# 步骤 3: 重启服务（仅在必要时）
# ==========================================
echo ""
echo "🔄 步骤 3/5: 检测服务状态"

SERVICE_STATUS=$(check_service_status)
echo "  当前状态: $SERVICE_STATUS"

NEED_RESTART=false

# 检查是否需要重启
if [ "$CODE_CHANGED" = true ] || [ "$SERVICE_STATUS" = "stopped" ]; then
    NEED_RESTART=true
    echo "  ⚠️  需要重启服务 (代码变更: $CODE_CHANGED, 服务状态: $SERVICE_STATUS)"
elif [ "$NEED_MIGRATION" = true ]; then
    NEED_RESTART=true
    echo "  ⚠️  数据库结构变更，需要重启服务"
else
    # 验证容器内代码是否包含必需的方法
    echo "  🔍 验证容器内代码版本..."
    CODE_CHECK=$(docker compose exec -T realtime python3 -c "
from services.sector_aggregator import SectorAggregator
import inspect
has_method = hasattr(SectorAggregator, 'aggregate_limit_reasons')
print('ok' if has_method else 'missing')
" 2>/dev/null || echo "error")

    if [ "$CODE_CHECK" != "ok" ]; then
        NEED_RESTART=true
        echo "  ⚠️  容器内代码版本过旧，需要重启服务"
    else
        echo "  ✅ 代码版本正常"
    fi
fi

# 执行重启或重新构建
if [ "$NEED_RESTART" = true ]; then
    # 如果是代码版本问题，需要重新构建镜像
    if [ "$CODE_CHECK" = "error" ] || [ "$CODE_CHECK" = "missing" ]; then
        echo "  🔨 重新构建 realtime 镜像（代码已更新）..."
        docker compose build --no-cache realtime
        echo "  🔄 启动新镜像..."
        docker compose up -d realtime
    else
        # 其他情况只需重启
        docker compose restart realtime
    fi
    echo "  ✅ 服务已更新"
else
    echo "  ✅ 无需重启服务"
fi

# 等待服务启动
echo "⏳ 等待服务启动..."
sleep 5

# ==========================================
# 步骤 3.5: 调试 AkShare API（可选）
# ==========================================
if [ "${DEBUG_AKSHARE:-false}" = "true" ]; then
    echo ""
    echo "🔍 步骤 3.5/5: 调试 AkShare API 返回结构"
    docker compose exec -T realtime python3 << 'DEBUG_SCRIPT'
import akshare as ak
from datetime import datetime

today = datetime.now().strftime('%Y%m%d')
print(f"📅 测试日期: {today}")

try:
    print("🔍 调用 stock_zt_pool_strong_em()...")
    df = ak.stock_zt_pool_strong_em(date=today)

    print(f"✅ 获取成功！共 {len(df)} 只股票")
    print("\n📋 API返回的列名:")
    for i, col in enumerate(df.columns, 1):
        print(f"  {i:2d}. '{col}'")

    print("\n📊 前2条数据样例:")
    print(df.head(2).to_string())

except Exception as e:
    print(f"❌ 调用失败: {e}")
DEBUG_SCRIPT

    echo ""
    echo "⏸️  调试完成，按回车继续..."
    read dummy
fi

# ==========================================
# 步骤 4: 手动触发数据采集和聚合
# ==========================================
echo ""
echo "⚡ 步骤 4/5: 立即采集和聚合数据（正常每2秒自动更新）"
docker compose exec -T realtime python3 << 'PYTHON_SCRIPT'
from services.realtime_fetcher import RealtimeFetcher
from services.sector_aggregator import SectorAggregator
import datetime

try:
    # 1. 采集今日数据
    print("🔍 开始采集实时数据...")
    fetcher = RealtimeFetcher()

    # fetch_and_save() 不接受参数，内部自动使用当前日期
    fetcher.fetch_and_save()
    print("✅ 采集完成！")

    # 2. 重新聚合板块（可选指定日期，默认今天）
    print("\n📊 开始聚合板块数据...")
    trade_date = datetime.datetime.now().strftime('%Y-%m-%d')
    aggregator = SectorAggregator()

    # 必须先连接数据库
    if not aggregator.connect():
        raise Exception("数据库连接失败")

    # 2.1 聚合概念板块（主视图）
    sectors_count = aggregator.aggregate(trade_date)
    print(f"✅ 概念板块聚合完成！共 {sectors_count} 个板块")

    # 2.2 聚合涨停原因（辅助视图）
    reasons_count = aggregator.aggregate_limit_reasons(trade_date)
    print(f"✅ 涨停原因聚合完成！共 {reasons_count} 个原因分类")

    print("\n🎉 数据更新完成！")
except Exception as e:
    print(f"❌ 错误: {e}")
    import traceback
    traceback.print_exc()
    exit(1)
PYTHON_SCRIPT

# ==========================================
# 步骤 5: 验证数据
# ==========================================
echo ""
echo "🔍 步骤 5/5: 验证板块数据"

echo ""
echo "📊 主视图：概念板块排行（concept_tags）"
docker compose exec -T postgres psql -U funcat_user -d funcat << 'SQL'
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
echo "📋 辅助视图：涨停原因分析（limit_reason）"
docker compose exec -T postgres psql -U funcat_user -d funcat << 'SQL'
SELECT
    reason_name,
    limit_up_count,
    one_word_count,
    limit_down_count,
    broken_count,
    total_stocks
FROM limit_reason_stats
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
