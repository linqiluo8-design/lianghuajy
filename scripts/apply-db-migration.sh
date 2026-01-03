#!/bin/bash
# ============================================
# 应用数据库迁移 - 添加 updated_at 字段
# ============================================

set -e

echo "🔄 应用数据库迁移"
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

echo "📋 迁移内容: 添加 updated_at 字段到 daily_limit_stats 表"
echo ""

# 应用迁移
echo "🔨 执行 SQL 迁移..."
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat < deployment/sql/11-add-updated-at.sql

echo ""
echo "============================================"
echo "✅ 迁移完成！"
echo "============================================"
echo ""

# 验证迁移
echo "🔍 验证 updated_at 列是否存在..."
$DOCKER_CMD exec postgres psql -U funcat_user -d funcat -c "
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'daily_limit_stats'
AND column_name IN ('created_at', 'updated_at')
ORDER BY column_name;
"

echo ""
echo "✅ 数据库迁移成功应用！"
echo ""
echo "💡 下一步: 重启实时服务以应用修复"
echo "   docker compose restart realtime"
echo ""
