#!/bin/bash
# ============================================
# 启动实时行情采集服务（Docker版本）
# ============================================

set -e

echo "🚀 启动实时行情采集服务 (Docker)"
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

# 显示配置
echo "📋 当前配置："
echo "   数据源: ${REALTIME_DATA_SOURCE:-akshare}"
echo "   刷新间隔: ${REALTIME_REFRESH_INTERVAL:-2} 秒"
echo ""

# 构建镜像
echo "🔨 构建实时服务镜像..."
$DOCKER_CMD build realtime

echo ""
echo "🔥 启动服务..."
$DOCKER_CMD up -d realtime

echo ""
echo "⏳ 等待服务启动..."
sleep 3

# 显示日志
echo ""
echo "📊 服务日志："
echo "============================================"
$DOCKER_CMD logs --tail=20 realtime

echo ""
echo "============================================"
echo "✅ 服务已启动！"
echo "============================================"
echo ""
echo "📌 常用命令："
echo "   查看日志: docker compose logs -f realtime"
echo "   停止服务: docker compose stop realtime"
echo "   重启服务: docker compose restart realtime"
echo "   查看状态: docker compose ps realtime"
echo ""
echo "💡 切换数据源："
echo "   1. 编辑 .env 文件，修改 REALTIME_DATA_SOURCE=pytdx"
echo "   2. 重启服务: docker compose restart realtime"
echo ""
