#!/bin/bash
# ============================================
# 部署跌停统计功能升级脚本
# ============================================

echo "🚀 开始升级跌停统计功能..."
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

echo "📊 步骤 1/4: 应用数据库升级（添加一字跌停字段）..."
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat < deployment/sql/07-add_limit_down_stats.sql

if [ $? -ne 0 ]; then
    echo "❌ 数据库升级失败"
    exit 1
fi

echo ""
echo "📈 步骤 2/4: 更新测试数据（包含跌停统计）..."
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat < deployment/sql/test_data.sql

if [ $? -ne 0 ]; then
    echo "⚠️  测试数据更新失败，继续..."
fi

echo ""
echo "🏗️  步骤 3/4: 重新构建 Web UI..."
$DOCKER_CMD build --no-cache webui

if [ $? -ne 0 ]; then
    echo "❌ Web UI 构建失败"
    exit 1
fi

echo ""
echo "🚀 步骤 4/4: 重启 Web UI 服务..."
$DOCKER_CMD stop webui
$DOCKER_CMD up -d webui

echo ""
echo "⏳ 等待服务就绪..."
sleep 3

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
echo "🎉 跌停统计功能升级完成！"
echo "=========================================="
echo ""
echo "📊 新增功能："
echo "   ✅ 一字跌停数统计"
echo "   ✅ 跌停惩罚机制（跌停-8分，一字跌停-15分）"
echo "   ✅ 板块强度表格显示跌停列"
echo "   ✅ 前端标记颜色优化（更清晰）"
echo ""
echo "🌐 访问地址："
echo "   http://192.168.92.129:8080"
echo ""
echo "💡 重要提示："
echo "   请使用 Ctrl+Shift+R 强制刷新浏览器缓存！"
echo ""
echo "🔍 数据验证："
echo "   板块强度排行中应该可以看到："
echo "   - 跌停数列"
echo "   - 一字跌停列"
echo "   - 白酒板块应显示：跌停4，一字跌停2"
echo "   - 医药板块应显示：跌停2，一字跌停1"
echo ""
