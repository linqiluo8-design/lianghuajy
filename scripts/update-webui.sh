#!/bin/bash
# 更新 Web UI 静态文件

echo "🔄 更新 Web UI..."
echo ""

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    DOCKER_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    DOCKER_CMD="docker-compose"
else
    echo "❌ 未找到 docker compose 命令"
    exit 1
fi

cd "$(dirname "$0")/.."

echo "📝 复制更新后的 index.html 到容器..."
$DOCKER_CMD cp web-ui/backend/static/index.html funcat-webui:/app/static/index.html

if [ $? -eq 0 ]; then
    echo "✅ 文件已更新"
else
    echo "❌ 更新失败"
    echo ""
    echo "💡 替代方案：重新构建镜像"
    echo "   docker compose build webui"
    echo "   docker compose up -d webui"
    exit 1
fi

echo ""
echo "🎉 更新完成！"
echo ""
echo "💡 提示："
echo "   1. 刷新浏览器（按 Ctrl+Shift+R 强制刷新）"
echo "   2. 访问: http://192.168.92.129:8081"
echo "   3. 选择日期: 2025-12-30"
echo ""
