#!/bin/bash
# 诊断 API 响应

echo "🔍 诊断 Web UI API 响应"
echo "========================================"
echo ""

# 检查端口
PORT=8081

echo "📊 测试 API 端点..."
echo ""

# 1. 健康检查
echo "1️⃣  健康检查: /api/v1/health"
curl -s "http://localhost:$PORT/api/v1/health" | head -c 200
echo -e "\n"

# 2. 板块列表
echo "2️⃣  板块列表: /api/v1/sectors"
curl -s "http://localhost:$PORT/api/v1/sectors" | head -c 300
echo -e "\n"

# 3. 板块统计
echo "3️⃣  板块统计: /api/v1/sectors/stats?date=2025-12-30"
STATS=$(curl -s "http://localhost:$PORT/api/v1/sectors/stats?date=2025-12-30")
echo "$STATS" | head -c 500
echo -e "\n"
echo "数据条数: $(echo "$STATS" | grep -o '"data":\[' | wc -l)"
echo ""

# 4. 涨停统计
echo "4️⃣  涨停统计: /api/v1/limit-stats?date=2025-12-30"
LIMIT=$(curl -s "http://localhost:$PORT/api/v1/limit-stats?date=2025-12-30")
echo "$LIMIT" | head -c 500
echo -e "\n"

# 5. 板块强度
echo "5️⃣  板块强度: /api/v1/sector-strength?date=2025-12-30&limit=5"
STRENGTH=$(curl -s "http://localhost:$PORT/api/v1/sector-strength?date=2025-12-30&limit=5")
echo "$STRENGTH" | head -c 500
echo -e "\n"

# 6. 连板天梯
echo "6️⃣  连板天梯: /api/v1/consecutive-ladder?min_days=2"
LADDER=$(curl -s "http://localhost:$PORT/api/v1/consecutive-ladder?min_days=2")
echo "$LADDER" | head -c 500
echo -e "\n"

echo ""
echo "========================================"
echo "💡 下一步："
echo "   1. 检查浏览器 Console 标签的错误信息"
echo "   2. 查看 index.html 是否正确加载"
echo "   3. 检查 Vue 应用是否挂载成功"
echo ""
