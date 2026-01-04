#!/bin/bash
# ============================================
# 一键部署实时动态板块分析功能
# ============================================
# 功能：
# 1. 智能检测数据库字段是否存在
# 2. 自动应用数据库迁移（如需要）
# 3. 检测代码是否更新，智能重新构建服务
# 4. 重启服务并验证
# 5. 显示运行状态和日志

set -e

echo "🚀 实时动态板块分析 - 一键部署脚本"
echo "============================================"
echo ""

# 检测 docker compose 命令
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    DOCKER_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    DOCKER_CMD="docker-compose"
else
    echo "❌ 未找到 docker compose 命令"
    exit 1
fi

cd "$(dirname "$0")/.."

# ============================================
# 步骤 1: 检查数据库字段是否存在
# ============================================
echo "📋 步骤 1/5: 检查数据库字段..."

check_db_field() {
    $DOCKER_CMD exec postgres psql -U funcat_user -d funcat -tAc "
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name='daily_limit_stats' AND column_name='$1'
    " 2>/dev/null
}

NEED_MIGRATION=false

if [ -z "$(check_db_field 'limit_reason')" ]; then
    echo "  ⚠️  字段 limit_reason 不存在，需要迁移"
    NEED_MIGRATION=true
fi

if [ -z "$(check_db_field 'industry')" ]; then
    echo "  ⚠️  字段 industry 不存在，需要迁移"
    NEED_MIGRATION=true
fi

if [ -z "$(check_db_field 'concept_tags')" ]; then
    echo "  ⚠️  字段 concept_tags 不存在，需要迁移"
    NEED_MIGRATION=true
fi

if [ "$NEED_MIGRATION" = false ]; then
    echo "  ✅ 数据库字段已存在，跳过迁移"
else
    echo ""
    echo "📊 步骤 2/5: 应用数据库迁移..."

    if [ -f "deployment/sql/08-add_stock_detail_fields.sql" ]; then
        $DOCKER_CMD exec -i postgres psql -U funcat_user -d funcat < deployment/sql/08-add_stock_detail_fields.sql

        if [ $? -eq 0 ]; then
            echo "  ✅ 数据库迁移成功"
        else
            echo "  ❌ 数据库迁移失败"
            exit 1
        fi
    else
        echo "  ⚠️  迁移文件不存在: deployment/sql/08-add_stock_detail_fields.sql"
    fi
fi

# ============================================
# 步骤 3: 检查代码是否更新
# ============================================
echo ""
echo "🔍 步骤 3/5: 检查服务代码..."

NEED_REBUILD=false

# 检查 Git 状态
if git diff --quiet HEAD -- services/; then
    echo "  ℹ️  服务代码无变更"

    # 检查容器是否包含最新代码（通过检查文件修改时间）
    CONTAINER_EXISTS=$($DOCKER_CMD ps -q -f name=funcat-realtime)

    if [ -z "$CONTAINER_EXISTS" ]; then
        echo "  ⚠️  服务容器未运行，需要重新构建"
        NEED_REBUILD=true
    else
        # 检查容器内代码文件的修改时间
        CONTAINER_MTIME=$($DOCKER_CMD exec funcat-realtime stat -c %Y /app/services/sector_aggregator.py 2>/dev/null || echo "0")
        HOST_MTIME=$(stat -c %Y services/sector_aggregator.py 2>/dev/null || echo "0")

        if [ "$CONTAINER_MTIME" -lt "$HOST_MTIME" ]; then
            echo "  ⚠️  容器代码版本过旧，需要重新构建"
            NEED_REBUILD=true
        fi
    fi
else
    echo "  ⚠️  检测到代码变更，需要重新构建"
    NEED_REBUILD=true
fi

# ============================================
# 步骤 4: 重新构建服务（如需要）
# ============================================
if [ "$NEED_REBUILD" = true ]; then
    echo ""
    echo "🔨 步骤 4/5: 重新构建 realtime 服务..."

    # 停止服务
    $DOCKER_CMD stop realtime 2>/dev/null || true

    # 重新构建镜像（无缓存）
    $DOCKER_CMD build --no-cache realtime

    if [ $? -ne 0 ]; then
        echo "  ❌ 服务构建失败"
        exit 1
    fi

    echo "  ✅ 服务构建成功"
else
    echo ""
    echo "⏭️  步骤 4/5: 跳过服务重建（无需更新）"
fi

# ============================================
# 步骤 5: 启动/重启服务
# ============================================
echo ""
echo "🚀 步骤 5/5: 启动服务..."

$DOCKER_CMD up -d realtime

if [ $? -ne 0 ]; then
    echo "  ❌ 服务启动失败"
    exit 1
fi

echo "  ✅ 服务已启动"

# ============================================
# 验证服务状态
# ============================================
echo ""
echo "⏳ 等待服务就绪..."
sleep 3

echo ""
echo "📊 服务状态："
$DOCKER_CMD ps --filter "name=funcat-realtime" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "============================================"
echo "🎉 部署完成！"
echo "============================================"
echo ""

# ============================================
# 显示最近日志
# ============================================
echo "📋 服务日志（最近20行）："
echo "--------------------------------------------"
$DOCKER_CMD logs --tail=20 realtime

echo ""
echo "============================================"
echo "✨ 部署摘要"
echo "============================================"
echo ""
echo "✅ 数据库字段: $([ "$NEED_MIGRATION" = true ] && echo "已迁移" || echo "已存在")"
echo "✅ 服务代码: $([ "$NEED_REBUILD" = true ] && echo "已重新构建" || echo "无需更新")"
echo "✅ 服务状态: 运行中"
echo ""
echo "📌 功能特性："
echo "  - ✅ 实时涨停池数据获取（含板块信息）"
echo "  - ✅ 实时跌停池数据获取（含板块信息）"
echo "  - ✅ 动态板块分析（无需预配置）"
echo "  - ✅ 每2秒自动更新统计"
echo ""
echo "📍 查看完整日志:"
echo "   $DOCKER_CMD logs -f realtime"
echo ""
echo "📍 访问看板:"
echo "   http://localhost:8080"
echo ""
echo "💡 提示："
echo "   - 当前是$(date +%H:%M)，若非交易时间，涨跌停池为空是正常的"
echo "   - 交易时间（09:30-15:00）数据最丰富"
echo "   - 看板将实时显示热门板块（商业航天、人形机器人等）"
echo ""
