#!/bin/bash
# ============================================
# 完整更新 Web UI（确保使用最新代码）
# ============================================

set -e

echo "🚀 开始完整更新 Web UI..."
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

echo "步骤 1/5: 拉取最新代码"
echo "----------------------------------------"
git pull origin claude/fix-docker-compose-display-o2cvA
echo ""

echo "步骤 2/5: 检查当前代码版本"
echo "----------------------------------------"
echo "当前分支: $(git branch --show-current)"
echo "最新提交: $(git log -1 --oneline)"
echo ""

echo "步骤 3/5: 停止旧服务"
echo "----------------------------------------"
$DOCKER_CMD stop webui
echo ""

echo "步骤 4/5: 重新构建镜像（不使用缓存）"
echo "----------------------------------------"
$DOCKER_CMD build --no-cache webui
echo ""

echo "步骤 5/5: 启动新服务"
echo "----------------------------------------"
$DOCKER_CMD up -d webui
echo ""

echo "⏳ 等待服务就绪..."
sleep 5

# 健康检查
for i in {1..10}; do
    if curl -sf http://localhost:8080/api/v1/health > /dev/null 2>&1 || \
       curl -sf http://localhost:8081/api/v1/health > /dev/null 2>&1; then
        echo "✅ 服务已就绪"
        break
    fi
    echo "等待中... ($i/10)"
    sleep 2
done

echo ""
echo "=========================================="
echo "🎉 Web UI 更新完成！"
echo "=========================================="
echo ""
echo "📊 验证更新："
echo "   1. 检查统计卡片是否为 6 列"
echo "   2. 包含：涨停家数、一字涨停、跌停家数、一字跌停、炸板总数、交易股票"
echo ""
echo "🌐 访问地址："
echo "   http://192.168.92.129:8080"
echo "   或"
echo "   http://192.168.92.129:8081"
echo ""
echo "💡 重要提示："
echo "   请使用 Ctrl+Shift+R 强制刷新浏览器缓存！"
echo ""
echo "🔍 如果仍然只有 4 列，请执行："
echo "   docker compose exec webui cat /app/static/index.html | grep -c 'col-md-2'"
echo "   应该返回 6（表示有6列）"
echo ""
