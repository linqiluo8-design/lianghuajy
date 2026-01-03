#!/bin/bash
# ============================================
# 一键修复所有问题
# ============================================

set -e

echo "🔧 开始修复所有问题"
echo "============================================"
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

# 步骤1: 拉取最新代码
echo "📥 步骤1/5: 拉取最新代码..."
git pull origin claude/fix-docker-compose-display-o2cvA

echo ""

# 步骤2: 应用数据库迁移
echo "🗄️  步骤2/5: 应用数据库迁移（添加 updated_at 字段）..."
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat < deployment/sql/11-add-updated-at.sql

echo ""

# 步骤3: 更新 Web UI
echo "🌐 步骤3/5: 更新 Web UI（修复CDN问题）..."
$DOCKER_CMD stop webui
$DOCKER_CMD build --no-cache webui
$DOCKER_CMD up -d webui

echo ""

# 步骤4: 更新实时服务
echo "📊 步骤4/5: 更新实时服务（修复数据保存问题）..."
$DOCKER_CMD stop realtime
$DOCKER_CMD build --no-cache realtime
$DOCKER_CMD up -d realtime

echo ""

# 步骤5: 等待服务启动
echo "⏳ 步骤5/5: 等待服务启动..."
sleep 5

echo ""

# 显示服务状态
echo "📋 服务状态："
echo "============================================"
$DOCKER_CMD ps --filter "name=webui" --filter "name=realtime"

echo ""

# 显示实时服务日志
echo "📊 实时服务日志（最近20行）："
echo "============================================"
$DOCKER_CMD logs --tail=20 realtime

echo ""

# 验证数据库
echo "🔍 验证数据库（updated_at 列）："
echo "============================================"
$DOCKER_CMD exec postgres psql -U funcat_user -d funcat -c "
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'daily_limit_stats'
AND column_name IN ('created_at', 'updated_at')
ORDER BY column_name;
"

echo ""
echo "============================================"
echo "✅ 所有修复已完成！"
echo "============================================"
echo ""
echo "📌 下一步操作："
echo "   1. 打开浏览器访问: http://192.168.92.129:8081"
echo "   2. 强制刷新（Ctrl+Shift+R）清除浏览器缓存"
echo "   3. 检查数据源状态是否为 🟢 运行中 (akshare)"
echo "   4. 查看统计卡片是否显示实时数据"
echo ""
echo "📌 查看实时日志:"
echo "   docker compose logs -f realtime"
echo ""
echo "📌 验证数据库数据:"
echo "   docker compose exec postgres psql -U funcat_user -d funcat -c \\"
echo "   SELECT COUNT(*) FROM daily_limit_stats WHERE trade_date = CURRENT_DATE;"
echo ""
