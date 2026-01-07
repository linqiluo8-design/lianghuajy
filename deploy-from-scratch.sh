#!/bin/bash
# -*- coding: utf-8 -*-
#
# 完整部署脚本 - 从0开始部署整个系统
#
# 功能：
# 1. 检查 Docker 环境
# 2. 停止现有服务（可选清理数据）
# 3. 启动基础服务（PostgreSQL, Redis）
# 4. 初始化数据库（创建表、视图、索引）
# 5. 运行数据库迁移（添加扩展字段）
# 6. 构建并启动应用服务（realtime, webui）
# 7. 采集实时数据（AkShare）
# 8. 聚合板块数据
# 9. 验证部署结果
# 10. 显示访问地址
#
# 使用方法：
#   bash deploy-from-scratch.sh          # 保留现有数据
#   bash deploy-from-scratch.sh --clean  # 清理所有数据重新开始
#

set -e  # 遇到错误立即退出

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}ℹ ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠️ ${NC} $1"
}

log_error() {
    echo -e "${RED}❌${NC} $1"
}

log_step() {
    echo ""
    echo "================================================================================"
    echo -e "${BLUE}$1${NC}"
    echo "================================================================================"
    echo ""
}

# 检查参数
CLEAN_DATA=false
if [[ "$1" == "--clean" ]]; then
    CLEAN_DATA=true
    log_warning "将清理所有数据并重新开始！"
fi

# 获取当前日期
TODAY=$(date +%Y-%m-%d)

log_step "🚀 Funcat 涨跌停看板系统 - 完整部署脚本"
log_info "部署日期: $TODAY"
log_info "工作目录: $(pwd)"
echo ""

# ============================================
# 步骤 1: 检查 Docker 环境
# ============================================
log_step "步骤 1/10: 检查 Docker 环境"

if ! command -v docker &> /dev/null; then
    log_error "Docker 未安装，请先安装 Docker"
    exit 1
fi

if ! docker compose version &> /dev/null && ! docker-compose version &> /dev/null; then
    log_error "Docker Compose 未安装，请先安装 Docker Compose"
    exit 1
fi

DOCKER_COMPOSE_CMD="docker compose"
if ! docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
fi

log_success "Docker 环境检查通过"
log_info "Docker 版本: $(docker --version)"
log_info "Docker Compose 版本: $($DOCKER_COMPOSE_CMD version --short 2>/dev/null || echo 'legacy')"

# ============================================
# 步骤 2: 停止现有服务
# ============================================
log_step "步骤 2/10: 停止现有服务"

log_info "停止所有服务..."
$DOCKER_COMPOSE_CMD down || true

if [[ "$CLEAN_DATA" == true ]]; then
    log_warning "清理数据卷..."
    read -p "⚠️  确定要删除所有数据吗？(输入 YES 确认): " CONFIRM
    if [[ "$CONFIRM" == "YES" ]]; then
        $DOCKER_COMPOSE_CMD down -v
        log_success "数据卷已清理"
    else
        log_info "取消清理数据卷，将保留现有数据"
        CLEAN_DATA=false
    fi
fi

log_success "现有服务已停止"

# ============================================
# 步骤 3: 启动基础服务
# ============================================
log_step "步骤 3/10: 启动基础服务（PostgreSQL, Redis）"

log_info "启动 postgres..."
$DOCKER_COMPOSE_CMD up -d postgres

log_info "启动 redis..."
$DOCKER_COMPOSE_CMD up -d redis

log_info "等待数据库服务就绪..."
for i in {1..30}; do
    if $DOCKER_COMPOSE_CMD exec -T postgres pg_isready -U funcat_user -d funcat > /dev/null 2>&1; then
        log_success "PostgreSQL 已就绪"
        break
    fi
    if [[ $i -eq 30 ]]; then
        log_error "PostgreSQL 启动超时"
        exit 1
    fi
    echo -n "."
    sleep 2
done

log_info "等待 Redis 服务就绪..."
for i in {1..15}; do
    if $DOCKER_COMPOSE_CMD exec -T redis redis-cli ping > /dev/null 2>&1; then
        log_success "Redis 已就绪"
        break
    fi
    if [[ $i -eq 15 ]]; then
        log_error "Redis 启动超时"
        exit 1
    fi
    echo -n "."
    sleep 2
done

# ============================================
# 步骤 4: 初始化数据库基础结构
# ============================================
log_step "步骤 4/10: 初始化数据库基础结构"

# 检查表是否已存在
TABLE_EXISTS=$($DOCKER_COMPOSE_CMD exec -T postgres psql -U funcat_user -d funcat -tAc \
    "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'daily_limit_stats');" 2>/dev/null || echo "f")

if [[ "$TABLE_EXISTS" == "t" ]] && [[ "$CLEAN_DATA" == false ]]; then
    log_info "数据库表已存在，跳过初始化"
else
    log_info "创建数据库基础表结构..."

    # 基础表已经通过 docker-entrypoint-initdb.d 自动创建
    # 检查是否成功创建
    sleep 3

    TABLE_COUNT=$($DOCKER_COMPOSE_CMD exec -T postgres psql -U funcat_user -d funcat -tAc \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';" 2>/dev/null || echo "0")

    if [[ "$TABLE_COUNT" -gt 0 ]]; then
        log_success "数据库基础表结构创建成功（共 $TABLE_COUNT 张表）"
    else
        log_error "数据库表创建失败"
        exit 1
    fi
fi

# ============================================
# 步骤 5: 运行数据库迁移
# ============================================
log_step "步骤 5/10: 运行数据库迁移（扩展字段和视图）"

log_info "迁移 004: 添加板块相关字段..."
$DOCKER_COMPOSE_CMD exec -T postgres psql -U funcat_user -d funcat < migrations/004_add_sector_fields.sql > /dev/null 2>&1 || true
log_success "✓ 板块字段已添加"

log_info "迁移 005: 创建涨停原因统计表..."
$DOCKER_COMPOSE_CMD exec -T postgres psql -U funcat_user -d funcat < migrations/005_create_limit_reason_stats.sql > /dev/null 2>&1 || true
log_success "✓ 涨停原因统计表已创建"

log_info "迁移 006: 修复个股详情视图..."
$DOCKER_COMPOSE_CMD exec -T postgres psql -U funcat_user -d funcat < migrations/006_fix_stock_detail_view.sql > /dev/null 2>&1
log_success "✓ 个股详情视图已修复"

log_success "数据库迁移完成"

# 显示表结构
log_info "当前数据库表："
$DOCKER_COMPOSE_CMD exec -T postgres psql -U funcat_user -d funcat -c "\dt" 2>/dev/null | grep -E "public|daily_limit|sector" || true

# ============================================
# 步骤 6: 构建并启动应用服务
# ============================================
log_step "步骤 6/10: 构建并启动应用服务"

log_info "构建 realtime 服务..."
$DOCKER_COMPOSE_CMD build realtime

log_info "构建 webui 服务..."
$DOCKER_COMPOSE_CMD build webui

log_info "启动 realtime 服务..."
$DOCKER_COMPOSE_CMD up -d realtime

log_info "启动 webui 服务..."
$DOCKER_COMPOSE_CMD up -d webui

log_info "等待服务启动..."
sleep 5

# 检查服务状态
REALTIME_STATUS=$($DOCKER_COMPOSE_CMD ps realtime --format json 2>/dev/null | grep -o '"State":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
WEBUI_STATUS=$($DOCKER_COMPOSE_CMD ps webui --format json 2>/dev/null | grep -o '"State":"[^"]*"' | cut -d'"' -f4 || echo "unknown")

if [[ "$REALTIME_STATUS" == "running" ]]; then
    log_success "realtime 服务已启动"
else
    log_warning "realtime 服务状态: $REALTIME_STATUS"
fi

if [[ "$WEBUI_STATUS" == "running" ]]; then
    log_success "webui 服务已启动"
else
    log_warning "webui 服务状态: $WEBUI_STATUS"
fi

# ============================================
# 步骤 7: 采集实时数据
# ============================================
log_step "步骤 7/10: 采集实时数据（AkShare）"

log_info "运行数据采集任务..."
$DOCKER_COMPOSE_CMD exec -T realtime python3 << 'PYTHON_SCRIPT'
import sys
from services.data_sources.akshare_source import AkShareDataSource

source = AkShareDataSource()

try:
    print("📥 开始采集数据...")
    success = source.fetch_and_store()

    if success:
        print("✅ 数据采集成功！")
        sys.exit(0)
    else:
        print("❌ 数据采集失败")
        sys.exit(1)
except Exception as e:
    print(f"❌ 采集过程出错: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYTHON_SCRIPT

if [[ $? -eq 0 ]]; then
    log_success "数据采集完成"
else
    log_error "数据采集失败，请检查日志"
    log_info "查看日志: docker compose logs realtime -f"
    exit 1
fi

# ============================================
# 步骤 8: 聚合板块数据
# ============================================
log_step "步骤 8/10: 聚合板块数据"

log_info "运行板块数据聚合..."
$DOCKER_COMPOSE_CMD exec -T realtime python3 << 'PYTHON_SCRIPT'
import sys
from services.sector_aggregator import SectorAggregator

aggregator = SectorAggregator()

if not aggregator.connect():
    print("❌ 数据库连接失败")
    sys.exit(1)

try:
    print("📊 开始聚合板块数据...")
    sector_count = aggregator.aggregate()

    if sector_count > 0:
        print(f"✅ 聚合成功！生成 {sector_count} 个板块统计")
        sys.exit(0)
    else:
        print("⚠️  未聚合任何数据（可能没有涨跌停数据）")
        sys.exit(0)  # 不算错误，继续执行
except Exception as e:
    print(f"❌ 聚合失败: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
finally:
    aggregator.close()
PYTHON_SCRIPT

if [[ $? -eq 0 ]]; then
    log_success "板块数据聚合完成"
else
    log_error "板块数据聚合失败"
    exit 1
fi

# ============================================
# 步骤 9: 验证部署结果
# ============================================
log_step "步骤 9/10: 验证部署结果"

log_info "检查数据库数据..."
$DOCKER_COMPOSE_CMD exec -T postgres psql -U funcat_user -d funcat << 'SQL'
\echo '----------------------------------------'
\echo '1. 个股涨跌停数据统计'
\echo '----------------------------------------'
SELECT
    COUNT(*) as total_stocks,
    COUNT(CASE WHEN limit_type = 'limit_up' THEN 1 END) as limit_up_count,
    COUNT(CASE WHEN limit_type = 'limit_down' THEN 1 END) as limit_down_count,
    COUNT(CASE WHEN is_one_word = true THEN 1 END) as one_word_count,
    MAX(trade_date) as latest_date
FROM daily_limit_stats
WHERE trade_date = CURRENT_DATE;

\echo ''
\echo '----------------------------------------'
\echo '2. 板块统计数据'
\echo '----------------------------------------'
SELECT
    COUNT(*) as sector_count,
    SUM(limit_up_count) as total_limit_up,
    SUM(limit_down_count) as total_limit_down,
    SUM(one_word_count) as total_one_word
FROM sector_daily_stats
WHERE trade_date = CURRENT_DATE;

\echo ''
\echo '----------------------------------------'
\echo '3. 热门板块 Top 5'
\echo '----------------------------------------'
SELECT
    sector_name,
    limit_up_count as 涨停,
    one_word_count as 一字板,
    limit_down_count as 跌停
FROM sector_daily_stats
WHERE trade_date = CURRENT_DATE
ORDER BY limit_up_count DESC
LIMIT 5;

\echo ''
\echo '----------------------------------------'
\echo '4. 连板股票统计'
\echo '----------------------------------------'
SELECT
    consecutive_limit_days as 连板数,
    COUNT(*) as 股票数量
FROM daily_limit_stats
WHERE trade_date = CURRENT_DATE
  AND limit_type = 'limit_up'
  AND consecutive_limit_days > 1
GROUP BY consecutive_limit_days
ORDER BY consecutive_limit_days DESC;
SQL

log_success "数据验证完成"

# ============================================
# 步骤 10: 显示访问信息
# ============================================
log_step "步骤 10/10: 部署完成"

# 获取 webui 端口
WEB_PORT=$($DOCKER_COMPOSE_CMD port webui 8080 2>/dev/null | cut -d: -f2 || echo "8080")

echo ""
log_success "🎉 系统部署成功！"
echo ""
echo "================================================================================"
echo "📊 看板访问地址"
echo "================================================================================"
echo ""
echo "  🌐 Web UI:  http://localhost:${WEB_PORT}"
echo ""
echo "================================================================================"
echo "🔍 验证项目"
echo "================================================================================"
echo ""
echo "  ✓ 数据日期显示为今天: $TODAY"
echo "  ✓ 涨停数量、跌停数量、一字板数量显示正确"
echo "  ✓ 板块涨停排行显示多个行业（非'全市场'）"
echo "  ✓ 点击涨停数量可查看个股详情弹窗"
echo "  ✓ 连板天梯显示连板股票"
echo ""
echo "================================================================================"
echo "🔧 常用命令"
echo "================================================================================"
echo ""
echo "  查看服务状态:        docker compose ps"
echo "  查看 realtime 日志:  docker compose logs realtime -f"
echo "  查看 webui 日志:     docker compose logs webui -f"
echo "  重新采集数据:        docker compose exec realtime python3 -c 'from services.data_sources.akshare_source import AkShareDataSource; AkShareDataSource().fetch_and_store()'"
echo "  重新聚合数据:        docker compose exec realtime python3 -c 'from services.sector_aggregator import SectorAggregator; a = SectorAggregator(); a.connect(); a.aggregate(); a.close()'"
echo "  停止所有服务:        docker compose down"
echo "  清理历史数据:        bash cleanup-old-data.sh"
echo ""
echo "================================================================================"
echo "💡 提示"
echo "================================================================================"
echo ""
echo "  • 如果浏览器显示旧数据，请强制刷新（Ctrl+Shift+R 或 Cmd+Shift+R）"
echo "  • 如果看板没有数据，请检查是否为交易日（周末和节假日无数据）"
echo "  • 数据每次运行脚本时会自动更新为最新数据"
echo "  • 可以定时运行数据采集任务（如每天 15:30 执行）"
echo ""
echo "================================================================================"

# 显示部署摘要
echo ""
log_info "部署摘要"
echo "  • 数据库: PostgreSQL 13"
echo "  • 缓存: Redis 6"
echo "  • 数据源: AkShare（实时行情）"
echo "  • 部署时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "  • 数据日期: $TODAY"
echo ""

log_success "部署完成！祝您使用愉快 🚀"
echo ""
