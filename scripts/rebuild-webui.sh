#!/bin/bash
# 重新构建并部署 Web UI（纯 JavaScript + Bootstrap 版本）

echo "🔄 重新构建 Web UI..."
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

echo "📝 步骤 1/4: 停止旧容器..."
$DOCKER_CMD stop webui

echo ""
echo "🏗️  步骤 2/4: 重新构建镜像（包含新的 JavaScript 版本）..."
$DOCKER_CMD build --no-cache webui

if [ $? -ne 0 ]; then
    echo "❌ 构建失败"
    exit 1
fi

echo ""
echo "🚀 步骤 3/4: 启动新容器..."
$DOCKER_CMD up -d webui

echo ""
echo "⏳ 步骤 4/4: 等待服务就绪..."
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
echo "🎉 部署完成！"
echo "=========================================="
echo ""
echo "📊 新版本特性："
echo "   ✅ 纯 JavaScript（无 Vue.js）"
echo "   ✅ Bootstrap 5 UI 框架"
echo "   ✅ SRI 安全验证"
echo "   ✅ 更快的加载速度"
echo "   ✅ 更简洁的代码（360 行 vs 800+ 行）"
echo ""
echo "🌐 访问地址："
echo "   http://192.168.92.129:8080"
echo ""
echo "💡 重要提示："
echo "   请使用 Ctrl+Shift+R 强制刷新浏览器缓存！"
echo "   （或者在开发者工具中禁用缓存）"
echo ""
echo "🔍 验证步骤："
echo "   1. 打开浏览器开发者工具（F12）"
echo "   2. 切换到 Console 标签"
echo "   3. 应该看到：✅ 页面加载完成，开始获取数据"
echo "   4. 不应该再看到 Vue 相关的错误"
echo ""
