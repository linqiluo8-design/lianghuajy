#!/bin/bash
# ============================================
# 重置并启动 Funcat 系统
# ============================================
# 此脚本用于解决：删除代码重新拉取后，Docker 数据卷密码不匹配的问题

set -e

echo "🔧 Funcat 系统重置与启动脚本"
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

# 进入项目根目录
cd "$(dirname "$0")/.."
echo "📁 工作目录: $(pwd)"
echo ""

# 步骤 1: 停止所有服务
echo "🛑 步骤 1/6: 停止所有服务..."
$DOCKER_CMD down
echo "✅ 服务已停止"
echo ""

# 步骤 2: 删除 PostgreSQL 数据卷
echo "🗑️  步骤 2/6: 删除旧的 PostgreSQL 数据卷..."
PROJECT_NAME=$(basename $(pwd))
VOLUME_NAME="${PROJECT_NAME}_postgres_data"

# 尝试删除数据卷（可能不存在）
if docker volume ls | grep -q "$VOLUME_NAME"; then
    docker volume rm "$VOLUME_NAME" || {
        echo "⚠️  无法删除数据卷，可能正在使用中"
        echo "   尝试强制停止容器..."
        docker ps -a --filter "volume=$VOLUME_NAME" -q | xargs -r docker rm -f
        docker volume rm "$VOLUME_NAME"
    }
    echo "✅ 旧数据卷已删除"
else
    echo "ℹ️  数据卷不存在，跳过删除"
fi
echo ""

# 步骤 3: 启动 PostgreSQL（会自动初始化）
echo "🚀 步骤 3/6: 启动 PostgreSQL 服务..."
$DOCKER_CMD up -d postgres
echo "✅ PostgreSQL 启动中..."
echo ""

# 步骤 4: 等待数据库初始化完成
echo "⏳ 步骤 4/6: 等待数据库初始化完成（约 15-30 秒）..."
for i in {1..60}; do
    if $DOCKER_CMD exec postgres pg_isready -U funcat_user -d funcat &> /dev/null; then
        echo "✅ 数据库初始化完成！"
        break
    fi
    echo -n "."
    sleep 1
    if [ $i -eq 60 ]; then
        echo ""
        echo "❌ 数据库初始化超时，请查看日志："
        echo "   $DOCKER_CMD logs postgres"
        exit 1
    fi
done
echo ""

# 等待额外 5 秒确保初始化脚本全部执行完
echo "⏳ 等待初始化脚本执行完成..."
sleep 5
echo ""

# 步骤 5: 导入板块强度功能
echo "📝 步骤 5/6: 导入板块强度功能和测试数据..."
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat < deployment/sql/06-sector_strength.sql
if [ $? -eq 0 ]; then
    echo "✅ 板块强度功能导入成功"
else
    echo "❌ 板块强度功能导入失败"
    exit 1
fi

# 导入测试数据
echo "📊 导入测试数据..."
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat < deployment/sql/test_data.sql
if [ $? -eq 0 ]; then
    echo "✅ 测试数据导入成功"
else
    echo "⚠️  测试数据导入失败（不影响正常使用）"
fi
echo ""

# 步骤 6: 启动所有服务
echo "🚀 步骤 6/6: 启动所有服务..."
$DOCKER_CMD up -d
echo "✅ 所有服务已启动"
echo ""

# 验证服务状态
echo "📊 服务状态："
$DOCKER_CMD ps
echo ""

# 验证数据
echo "✅ 验证数据..."
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat -c "
SELECT
    trade_date,
    sector_name,
    limit_up_count,
    strength_score,
    strength_grade
FROM v_sector_strength_ranking
WHERE trade_date = '2025-12-30'
ORDER BY strength_score DESC
LIMIT 5;
" 2>/dev/null || echo "⚠️  暂无数据（需要运行选股服务生成数据）"

echo ""
echo "🎉 系统重置完成！"
echo ""
echo "📊 访问地址："
echo "   Web UI: http://localhost:8081"
echo "   (如果导入了测试数据，请选择日期: 2025-12-30)"
echo ""
echo "💡 提示："
echo "   - 查看日志: $DOCKER_CMD logs -f webui"
echo "   - 进入数据库: $DOCKER_CMD exec -it postgres psql -U funcat_user -d funcat"
echo ""
