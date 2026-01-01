#!/bin/bash
# ============================================
# 一键部署所有新功能
# ============================================

echo "🚀 开始部署所有新功能..."
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

echo "📊 步骤 1/6: 应用数据库升级..."
echo "  - 添加跌停统计字段和视图"
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat < deployment/sql/07-add_limit_down_stats.sql

echo "  - 添加个股详情字段"
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat < deployment/sql/08-add_stock_detail_fields.sql

echo "  - 添加每日最高连板数统计视图"
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat < deployment/sql/09-daily_highest_board.sql

if [ $? -ne 0 ]; then
    echo "❌ 数据库升级失败"
    exit 1
fi

echo ""
echo "📈 步骤 2/6: 更新测试数据..."
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat < deployment/sql/test_data.sql

echo ""
echo "📅 步骤 3/6: 生成30天历史数据（用于趋势图）..."
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat < deployment/sql/10-test_data_30days.sql

echo ""
echo "🏗️  步骤 4/6: 重新构建 Web UI..."
$DOCKER_CMD build --no-cache webui

if [ $? -ne 0 ]; then
    echo "❌ Web UI 构建失败"
    exit 1
fi

echo ""
echo "🛑 步骤 5/6: 停止旧服务..."
$DOCKER_CMD stop webui

echo ""
echo "🚀 步骤 6/6: 启动新服务..."
$DOCKER_CMD up -d webui

echo ""
echo "⏳ 等待服务就绪..."
sleep 5

# 健康检查
for i in {1..10}; do
    if curl -sf http://localhost:8080/api/v1/health > /dev/null 2>&1; then
        echo "✅ 服务已就绪"
        break
    fi
    echo "等待中... ($i/10)"
    sleep 2
done

echo ""
echo "=========================================="
echo "🎉 所有新功能部署完成！"
echo "=========================================="
echo ""
echo "✨ 新增功能列表："
echo ""
echo "1. 跌停统计功能"
echo "   - 板块强度排行表格新增：跌停数、一字跌停数"
echo "   - 强度计算考虑跌停惩罚（-8分/个，一字跌停-15分/个）"
echo ""
echo "2. 点击查看个股详情"
echo "   - 点击涨停数/跌停数查看该板块所有个股"
echo "   - 15列详细信息：代码、名称、涨幅、开盘涨幅、类型、"
echo "     连板天数、几天几板、涨停原因、所属行业、换手、"
echo "     首次涨停时间、成交额、昨日封单、今日封单、概念题材"
echo ""
echo "3. 最高连板数趋势图"
echo "   - 近30天最高连板数折线图"
echo "   - 双轴显示：连板高度 + 涨停总数"
echo "   - 帮助识别市场周期变化"
echo ""
echo "🌐 访问地址："
echo "   http://192.168.92.129:8080"
echo ""
echo "💡 重要提示："
echo "   请使用 Ctrl+Shift+R 强制刷新浏览器缓存！"
echo ""
echo "🔍 功能验证："
echo "   1. 查看板块强度表格，应显示跌停数和一字跌停数"
echo "   2. 点击涨停数/跌停数徽章，应弹出个股详情"
echo "   3. 查看最高连板数趋势图，应显示近30天折线"
echo ""
