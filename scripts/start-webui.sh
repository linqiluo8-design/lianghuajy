#!/bin/bash

# ============================================
# Funcat Web UI 一键启动脚本
# ============================================

set -e

echo "🚀 Funcat 涨跌停数据看板启动脚本"
echo "=================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker 未安装，请先安装 Docker${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose 未安装，请先安装 Docker Compose${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker 环境检查通过${NC}"
echo ""

# 检查.env文件
if [ ! -f .env ]; then
    echo -e "${YELLOW}⚠️  未找到 .env 文件，正在从 .env.example 复制...${NC}"
    cp .env.example .env
    echo -e "${YELLOW}📝 请编辑 .env 文件配置数据库密码等信息${NC}"
    echo -e "${YELLOW}   特别是 POSTGRES_PASSWORD 和 REDIS_PASSWORD${NC}"
    echo ""
    read -p "按回车键继续..."
fi

# 步骤1: 启动基础服务
echo "📦 步骤 1/5: 启动PostgreSQL和Redis服务..."
docker-compose up -d postgres redis

echo -e "${GREEN}✅ 数据库服务已启动${NC}"
echo "⏳ 等待数据库初始化完成（约15秒）..."
sleep 15

# 步骤2: 检查数据库健康状态
echo ""
echo "🔍 步骤 2/5: 检查数据库连接..."
MAX_RETRIES=10
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker-compose exec -T postgres pg_isready -U funcat_user -d funcat > /dev/null 2>&1; then
        echo -e "${GREEN}✅ 数据库连接成功${NC}"
        break
    fi

    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo -e "${RED}❌ 数据库连接失败，请检查配置${NC}"
        exit 1
    fi

    echo "   重试 $RETRY_COUNT/$MAX_RETRIES..."
    sleep 2
done

# 步骤3: 初始化数据库扩展表
echo ""
echo "📝 步骤 3/5: 初始化数据库扩展表..."

# 检查扩展表是否已存在
TABLE_EXISTS=$(docker-compose exec -T postgres psql -U funcat_user -d funcat -tAc "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='sectors');")

if [ "$TABLE_EXISTS" = "t" ]; then
    echo -e "${YELLOW}⚠️  扩展表已存在，跳过初始化${NC}"
else
    docker-compose exec -T postgres psql -U funcat_user -d funcat < deployment/sql/schema_extension.sql
    echo -e "${GREEN}✅ 数据库扩展表创建成功${NC}"
fi

# 步骤4: 初始化示例数据
echo ""
echo "📊 步骤 4/5: 初始化示例数据..."
read -p "是否初始化示例数据? (y/n, 默认y): " INIT_DATA
INIT_DATA=${INIT_DATA:-y}

if [ "$INIT_DATA" = "y" ] || [ "$INIT_DATA" = "Y" ]; then
    docker-compose exec -T postgres psql -U funcat_user -d funcat < deployment/sql/init_sample_data.sql
    echo -e "${GREEN}✅ 示例数据初始化完成${NC}"
else
    echo -e "${YELLOW}⏭️  跳过示例数据初始化${NC}"
fi

# 步骤5: 启动Web UI服务
echo ""
echo "🌐 步骤 5/5: 启动Web UI服务..."
docker-compose up -d --build webui

echo ""
echo "⏳ 等待Web UI服务启动（约10秒）..."
sleep 10

# 检查Web UI健康状态
echo "🔍 检查Web UI服务状态..."
if curl -f http://localhost:8080/api/v1/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Web UI服务启动成功！${NC}"
else
    echo -e "${YELLOW}⚠️  Web UI可能需要更多时间启动，请稍后访问${NC}"
fi

# 显示服务状态
echo ""
echo "=================================="
echo "📊 服务状态:"
echo "=================================="
docker-compose ps postgres redis webui

echo ""
echo "=================================="
echo "✨ 启动完成！"
echo "=================================="
echo ""
echo -e "${GREEN}🌐 请访问以下地址查看涨跌停数据看板:${NC}"
echo -e "   ${GREEN}http://localhost:8080${NC}"
echo ""
echo "📚 使用文档:"
echo "   - 查看 WEB_UI_GUIDE.md 了解详细使用方法"
echo ""
echo "🔧 常用命令:"
echo "   - 查看日志: docker-compose logs -f webui"
echo "   - 停止服务: docker-compose stop webui"
echo "   - 重启服务: docker-compose restart webui"
echo "   - 完全停止: docker-compose down"
echo ""
echo "💡 提示:"
echo "   - 示例数据包含半导体、新能源、AI等热门板块"
echo "   - 包含涨停、连板、炸板等各类数据"
echo "   - 支持板块筛选、日期选择等功能"
echo ""
echo -e "${GREEN}祝使用愉快！ 📈🚀${NC}"
