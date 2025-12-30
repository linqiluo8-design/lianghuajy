#!/bin/bash
# ============================================
# 导入板块强度排行功能到数据库
# ============================================

set -e  # 遇到错误立即退出

echo "🚀 开始导入板块强度排行功能..."
echo ""

# 检查 docker compose 命令
if command -v docker &> /dev/null; then
    DOCKER_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    DOCKER_CMD="docker-compose"
else
    echo "❌ 错误：未找到 docker 或 docker-compose 命令"
    exit 1
fi

# 进入脚本所在目录的上级目录（项目根目录）
cd "$(dirname "$0")/.."

echo "📁 当前工作目录: $(pwd)"
echo ""

# 1. 创建函数和视图
echo "📝 步骤 1/3: 创建板块强度计算函数和视图..."
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat < deployment/sql/06-sector_strength.sql

if [ $? -eq 0 ]; then
    echo "✅ 板块强度功能创建成功！"
else
    echo "❌ 创建失败！请检查错误信息"
    exit 1
fi

echo ""

# 2. 导入测试数据（可选）
echo "📝 步骤 2/3: 导入测试数据..."
read -p "是否导入测试数据？(包含 2025-12-30 的示例数据) [Y/n]: " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    $DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat < deployment/sql/test_data.sql

    if [ $? -eq 0 ]; then
        echo "✅ 测试数据导入成功！"
    else
        echo "⚠️  测试数据导入失败，但不影响功能使用"
    fi
else
    echo "⏭️  跳过测试数据导入"
fi

echo ""

# 3. 验证
echo "📝 步骤 3/3: 验证数据..."
echo "查询板块强度排行前 5 名："
$DOCKER_CMD exec -T postgres psql -U funcat_user -d funcat -c "
SELECT
    trade_date,
    sector_name,
    limit_up_count,
    strength_score,
    strength_grade
FROM v_sector_strength_ranking
WHERE trade_date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY trade_date DESC, strength_score DESC
LIMIT 5;
"

echo ""
echo "🎉 导入完成！现在可以刷新浏览器查看板块强度排行功能了"
echo ""
echo "📊 访问地址: http://localhost:8081"
echo "📅 如果导入了测试数据，请在页面上选择日期: 2025-12-30"
echo ""
