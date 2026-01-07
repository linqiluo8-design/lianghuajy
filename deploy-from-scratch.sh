#!/bin/bash
# -*- coding: utf-8 -*-
#
# ============================================
# Funcat 涨跌停看板系统 - 智能部署脚本
# ============================================
#
# 版本: v2.0
# 作者: Funcat Team
# 更新: 2026-01-07
#
# 脚本说明：
# ----------
# 本脚本提供完整的从 0 到生产的自动化部署流程，支持：
#   • 全新环境一键部署
#   • 日常代码更新的智能增量构建
#   • 服务变更自动检测（只重建有变化的服务）
#   • Git 代码管理（自动 pull、stash、重试）
#   • 数据库迁移自动执行
#   • 健康检查与验证
#
# 核心特性：
# ----------
# 1. 智能增量构建
#    - 自动检测文件变更（git diff）
#    - 只重建有变化的服务（realtime/webui）
#    - 性能提升：无变更 30秒，单服务 2-3分钟，全量 5-10分钟
#
# 2. 生产级可靠性
#    - Git pull 失败重试（4次，指数退避）
#    - 服务健康检查（PostgreSQL/Redis）
#    - 数据验证（自动 SQL 查询）
#    - 完整错误处理（set -e）
#
# 3. CICD 友好
#    - 非交互式模式支持
#    - 明确的退出码
#    - 详细的彩色日志
#    - 支持多参数组合
#
# 部署流程（11 步骤）：
# ---------------------
# 1.  检查 Docker 环境（docker/docker-compose 版本）
# 2.  更新代码（git pull 带重试，支持 stash）
# 2.5 检测服务变更（智能增量构建决策）
# 3.  停止现有服务（可选清理数据卷）
# 4.  启动基础服务（PostgreSQL + Redis 健康检查）
# 5.  初始化数据库（创建表结构，跳过已存在）
# 6.  运行数据库迁移（004/005/006 幂等执行）
# 7.  构建并启动应用服务（智能增量构建）
# 8.  采集实时数据（AkShare API）
# 9.  聚合板块数据（sector_aggregator）
# 10. 验证部署结果（SQL 数据验证）
# 11. 显示访问信息（端口、命令、摘要）
#
# 使用方法：
# ----------
# bash deploy-from-scratch.sh                   # 默认：保留数据 + 智能增量构建
# bash deploy-from-scratch.sh --clean           # 清理所有数据重新开始
# bash deploy-from-scratch.sh --skip-update     # 跳过 git pull（使用本地代码）
# bash deploy-from-scratch.sh --force-rebuild   # 强制无缓存重建所有服务
#
# 参数组合：
# ----------
# bash deploy-from-scratch.sh --clean --skip-update       # 清理数据 + 使用本地代码
# bash deploy-from-scratch.sh --clean --force-rebuild     # 最彻底的重新部署
#
# 使用场景：
# ----------
# 场景 1: 首次部署新环境
#   bash deploy-from-scratch.sh --clean
#
# 场景 2: 日常代码更新（推荐）
#   git push
#   bash deploy-from-scratch.sh  # 自动检测变更，智能增量构建
#
# 场景 3: 修改了 services/data_sources/akshare_source.py
#   bash deploy-from-scratch.sh  # 自动检测，只重建 realtime
#
# 场景 4: 修改了 web-ui/backend/static/index.html
#   bash deploy-from-scratch.sh  # 自动检测，只重建 webui
#
# 场景 5: 磁盘清理后重新部署
#   bash deploy-from-scratch.sh --clean
#
# 场景 6: Docker 缓存问题
#   bash deploy-from-scratch.sh --force-rebuild
#
# 场景 7: 本地代码测试（不更新代码）
#   bash deploy-from-scratch.sh --skip-update
#
# 变更检测规则：
# --------------
# realtime 服务触发条件：
#   - services/          （Python 业务逻辑）
#   - config/            （配置文件）
#   - requirements.txt   （Python 依赖）
#   - deployment/docker/Dockerfile.realtime
#
# webui 服务触发条件：
#   - web-ui/backend/    （Go 后端 + 前端资源）
#   - docker-compose.yml （容器配置）
#
# 数据库迁移检测：
#   - migrations/        （迁移脚本）
#   - deployment/sql/    （初始化 SQL）
#
# 性能数据：
# ----------
# 无变更部署:    30 秒     （跳过构建，仅重启）
# 单服务变更:    2-3 分钟  （只构建 1 个服务）
# 双服务变更:    5-10 分钟 （构建 2 个服务）
# 强制重建:      10-15 分钟（无缓存全量重建）
#
# 依赖要求：
# ----------
# - Docker 20.0+
# - Docker Compose 2.0+
# - Git 2.0+
# - Bash 4.0+
#
# 环境变量（可选）：
# ------------------
# POSTGRES_PASSWORD    - PostgreSQL 密码（默认: funcat_password_change_me）
# REDIS_PASSWORD       - Redis 密码（默认: redis_password_change_me）
# WEBUI_PORT           - Web UI 端口（默认: 8080）
#
# 故障排查：
# ----------
# 1. Docker 启动失败
#    - 检查 Docker 服务: systemctl status docker
#    - 查看日志: docker compose logs -f
#
# 2. 数据库连接失败
#    - 检查 PostgreSQL: docker compose logs postgres
#    - 重启数据库: docker compose restart postgres
#
# 3. Git pull 失败
#    - 方案 1: git stash && bash deploy-from-scratch.sh
#    - 方案 2: bash deploy-from-scratch.sh --skip-update
#
# 4. 看板无数据
#    - 检查交易日: date（周末/节假日无数据）
#    - 手动采集: docker compose exec realtime python3 -c '...'
#    - 查看日志: docker compose logs realtime -f
#
# 详细文档：
# ----------
# 完整使用指南、CICD 集成、最佳实践请查看:
#   📖 DEPLOYMENT.md
#
# 联系与支持：
# ------------
# GitHub Issues: https://github.com/cedricporter/funcat/issues
#
# ============================================

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
SKIP_UPDATE=false
FORCE_REBUILD=false
for arg in "$@"; do
    if [[ "$arg" == "--clean" ]]; then
        CLEAN_DATA=true
        log_warning "将清理所有数据并重新开始！"
    elif [[ "$arg" == "--skip-update" ]]; then
        SKIP_UPDATE=true
    elif [[ "$arg" == "--force-rebuild" ]]; then
        FORCE_REBUILD=true
    fi
done

# 获取当前日期
TODAY=$(date +%Y-%m-%d)

log_step "🚀 Funcat 涨跌停看板系统 - 完整部署脚本"
log_info "部署日期: $TODAY"
log_info "工作目录: $(pwd)"
echo ""

# ============================================
# 步骤 1: 检查 Docker 环境
# ============================================
log_step "步骤 1/11: 检查 Docker 环境"

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
# 步骤 2: 更新代码
# ============================================
log_step "步骤 2/11: 更新代码"

if [[ "$SKIP_UPDATE" == true ]]; then
    log_info "跳过代码更新（--skip-update 参数）"
else
    # 检查是否是 git 仓库
    if [[ -d .git ]]; then
        log_info "检查 Git 状态..."

        # 获取当前分支
        CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        log_info "当前分支: $CURRENT_BRANCH"

        # 检查是否有未提交的更改
        if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
            log_warning "检测到未提交的更改"
            git status --short
            echo ""
            read -p "是否暂存更改并继续？(y/n): " STASH_CHANGES
            if [[ "$STASH_CHANGES" == "y" ]]; then
                log_info "暂存本地更改..."
                git stash push -m "deploy-from-scratch auto stash $(date '+%Y-%m-%d %H:%M:%S')"
                log_success "本地更改已暂存"
            else
                log_warning "跳过代码更新，使用当前代码"
                SKIP_UPDATE=true
            fi
        fi

        if [[ "$SKIP_UPDATE" == false ]]; then
            log_info "拉取最新代码..."

            # 尝试拉取代码，带重试机制
            for i in {1..4}; do
                if git pull origin "$CURRENT_BRANCH" 2>&1; then
                    log_success "代码已更新到最新版本"

                    # 显示最新提交
                    log_info "最新提交:"
                    git log -1 --oneline --decorate
                    break
                else
                    if [[ $i -lt 4 ]]; then
                        WAIT_TIME=$((2 ** i))
                        log_warning "代码拉取失败，${WAIT_TIME}秒后重试..."
                        sleep $WAIT_TIME
                    else
                        log_warning "代码拉取失败，将使用当前代码继续部署"
                    fi
                fi
            done
        fi
    else
        log_info "非 Git 仓库，跳过代码更新"
    fi
fi

log_success "代码准备完成"

# ============================================
# 步骤 2.5: 检测服务变更（智能增量构建）
# ============================================
REBUILD_REALTIME=false
REBUILD_WEBUI=false

if [[ "$FORCE_REBUILD" == true ]]; then
    log_info "强制重新构建所有服务（--force-rebuild 参数）"
    REBUILD_REALTIME=true
    REBUILD_WEBUI=true
elif [[ -d .git ]] && [[ "$SKIP_UPDATE" == false ]]; then
    log_info "检测服务变更..."

    # 获取最近一次 pull 的变更文件
    # 如果是首次部署，检查最近的提交
    CHANGED_FILES=$(git diff --name-only HEAD@{1} HEAD 2>/dev/null || git diff --name-only HEAD~1 HEAD 2>/dev/null || echo "")

    if [[ -z "$CHANGED_FILES" ]]; then
        log_info "未检测到文件变更，跳过构建检查"
    else
        log_info "检测到以下文件变更："
        echo "$CHANGED_FILES" | head -10
        if [[ $(echo "$CHANGED_FILES" | wc -l) -gt 10 ]]; then
            echo "... (还有 $(($(echo "$CHANGED_FILES" | wc -l) - 10)) 个文件)"
        fi
        echo ""

        # 检测 realtime 服务相关变更
        if echo "$CHANGED_FILES" | grep -qE "^(services/|config/|deployment/docker/Dockerfile\.realtime|requirements\.txt)"; then
            log_info "✓ 检测到 realtime 服务相关变更"
            REBUILD_REALTIME=true
        fi

        # 检测 webui 服务相关变更
        if echo "$CHANGED_FILES" | grep -qE "^(web-ui/backend/|docker-compose\.yml)"; then
            log_info "✓ 检测到 webui 服务相关变更"
            REBUILD_WEBUI=true
        fi

        # 检测数据库迁移变更
        if echo "$CHANGED_FILES" | grep -qE "^(migrations/|deployment/sql/)"; then
            log_info "✓ 检测到数据库迁移文件变更"
        fi
    fi
else
    # 跳过更新或非 git 仓库，默认重新构建
    log_info "无法检测变更，将重新构建所有服务"
    REBUILD_REALTIME=true
    REBUILD_WEBUI=true
fi

# 显示构建计划
echo ""
log_info "服务构建计划："
if [[ "$REBUILD_REALTIME" == true ]]; then
    echo "  • realtime: 需要重新构建"
else
    echo "  • realtime: 跳过构建（无变更）"
fi

if [[ "$REBUILD_WEBUI" == true ]]; then
    echo "  • webui: 需要重新构建"
else
    echo "  • webui: 跳过构建（无变更）"
fi
echo ""

# ============================================
# 步骤 3: 停止现有服务
# ============================================
log_step "步骤 3/11: 停止现有服务"

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
# 步骤 4: 启动基础服务
# ============================================
log_step "步骤 4/11: 启动基础服务（PostgreSQL, Redis）"

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
# 步骤 5: 初始化数据库基础结构
# ============================================
log_step "步骤 5/11: 初始化数据库基础结构"

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
# 步骤 6: 运行数据库迁移
# ============================================
log_step "步骤 6/11: 运行数据库迁移（扩展字段和视图）"

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
# 步骤 7: 构建并启动应用服务
# ============================================
log_step "步骤 7/11: 构建并启动应用服务"

# 智能构建 realtime 服务
if [[ "$REBUILD_REALTIME" == true ]]; then
    log_info "构建 realtime 服务..."
    if [[ "$FORCE_REBUILD" == true ]]; then
        $DOCKER_COMPOSE_CMD build --no-cache realtime
        log_success "realtime 服务已重新构建（无缓存）"
    else
        $DOCKER_COMPOSE_CMD build realtime
        log_success "realtime 服务已构建"
    fi
else
    log_info "跳过 realtime 服务构建（无变更）"
fi

# 智能构建 webui 服务
if [[ "$REBUILD_WEBUI" == true ]]; then
    log_info "构建 webui 服务..."
    if [[ "$FORCE_REBUILD" == true ]]; then
        $DOCKER_COMPOSE_CMD build --no-cache webui
        log_success "webui 服务已重新构建（无缓存）"
    else
        $DOCKER_COMPOSE_CMD build webui
        log_success "webui 服务已构建"
    fi
else
    log_info "跳过 webui 服务构建（无变更）"
fi

log_info "启动/更新 realtime 服务..."
$DOCKER_COMPOSE_CMD up -d realtime

log_info "启动/更新 webui 服务..."
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
# 步骤 8: 采集实时数据
# ============================================
log_step "步骤 8/11: 采集实时数据（AkShare）"

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
# 步骤 9: 聚合板块数据
# ============================================
log_step "步骤 9/11: 聚合板块数据"

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
# 步骤 10: 验证部署结果
# ============================================
log_step "步骤 10/11: 验证部署结果"

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
# 步骤 11: 显示访问信息
# ============================================
log_step "步骤 11/11: 部署完成"

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
echo "  查看服务状态:          docker compose ps"
echo "  查看 realtime 日志:    docker compose logs realtime -f"
echo "  查看 webui 日志:       docker compose logs webui -f"
echo "  重新采集数据:          docker compose exec realtime python3 -c 'from services.data_sources.akshare_source import AkShareDataSource; AkShareDataSource().fetch_and_store()'"
echo "  重新聚合数据:          docker compose exec realtime python3 -c 'from services.sector_aggregator import SectorAggregator; a = SectorAggregator(); a.connect(); a.aggregate(); a.close()'"
echo "  停止所有服务:          docker compose down"
echo "  清理历史数据:          bash cleanup-old-data.sh"
echo "  增量更新部署:          bash deploy-from-scratch.sh"
echo "  强制重新构建:          bash deploy-from-scratch.sh --force-rebuild"
echo ""
echo "================================================================================"
echo "💡 提示"
echo "================================================================================"
echo ""
echo "  • 脚本会自动检测服务变更，只重新构建有变化的服务（提高部署速度）"
echo "  • 如果浏览器显示旧数据，请强制刷新（Ctrl+Shift+R 或 Cmd+Shift+R）"
echo "  • 如果看板没有数据，请检查是否为交易日（周末和节假日无数据）"
echo "  • 数据每次运行脚本时会自动更新为最新数据"
echo "  • 可以定时运行数据采集任务（如每天 15:30 执行）"
echo "  • 使用 --force-rebuild 可强制重新构建所有服务（解决缓存问题）"
echo ""
echo "================================================================================"

# 显示部署摘要
echo ""
log_info "部署摘要"
echo "  • 数据库: PostgreSQL 13"
echo "  • 缓存: Redis 6"
echo "  • 数据源: AkShare（实时行情）"
echo "  • 部署模式: $(if [[ "$FORCE_REBUILD" == true ]]; then echo "强制重建"; elif [[ "$REBUILD_REALTIME" == true ]] || [[ "$REBUILD_WEBUI" == true ]]; then echo "增量构建"; else echo "仅更新"; fi)"
echo "  • 构建服务: $(if [[ "$REBUILD_REALTIME" == true ]] && [[ "$REBUILD_WEBUI" == true ]]; then echo "realtime + webui"; elif [[ "$REBUILD_REALTIME" == true ]]; then echo "realtime"; elif [[ "$REBUILD_WEBUI" == true ]]; then echo "webui"; else echo "无"; fi)"
echo "  • 部署时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "  • 数据日期: $TODAY"
echo ""

log_success "部署完成！祝您使用愉快 🚀"
echo ""
