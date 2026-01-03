#!/bin/bash
# ============================================
# 更新并重启实时行情采集服务
# ============================================

set -e

echo "🔄 更新实时行情采集服务"
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

# 1. 拉取最新代码
echo "📥 拉取最新代码..."
git pull origin claude/fix-docker-compose-display-o2cvA

echo ""

# 2. 停止服务
echo "🛑 停止服务..."
$DOCKER_CMD stop realtime

echo ""

# 3. 重新构建镜像
echo "🔨 重新构建镜像（无缓存）..."
$DOCKER_CMD build --no-cache realtime

echo ""

# 4. 启动服务
echo "🚀 启动服务..."
$DOCKER_CMD up -d realtime

echo ""

# 5. 等待服务启动
echo "⏳ 等待服务启动..."
sleep 5

echo ""

# 6. 显示日志
echo "📊 服务日志："
echo "============================================"
$DOCKER_CMD logs --tail=30 realtime

echo ""
echo "============================================"
echo "✅ 更新完成！"
echo "============================================"
echo ""
echo "📌 继续查看日志:"
echo "   docker compose logs -f realtime"
echo ""
echo "📌 检查服务状态:"
echo "   docker compose ps realtime"
echo ""
