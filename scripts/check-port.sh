#!/bin/bash
# 检查端口映射

echo "🔍 检查 Web UI 端口映射..."
echo ""

if command -v docker >/dev/null 2>&1; then
    DOCKER_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    DOCKER_CMD="docker-compose"
else
    echo "❌ 未找到 docker 命令"
    exit 1
fi

cd "$(dirname "$0")/.."

echo "📊 当前容器端口映射："
$DOCKER_CMD ps --format "table {{.Names}}\t{{.Ports}}" | grep webui

echo ""
echo "📝 检查环境变量配置..."
if [ -f .env ]; then
    echo "✅ .env 文件存在"
    grep "WEBUI_PORT" .env || echo "⚠️  未设置 WEBUI_PORT（将使用默认值 8080）"
else
    echo "⚠️  .env 文件不存在（将使用 docker-compose.yml 中的默认值）"
    echo "   默认端口: 8080"
fi

echo ""
echo "💡 解决方案："
echo "   方案1: 在浏览器中访问 http://192.168.92.129:8080"
echo "   方案2: 创建 .env 文件，设置 WEBUI_PORT=8081，然后重启服务"
echo ""
