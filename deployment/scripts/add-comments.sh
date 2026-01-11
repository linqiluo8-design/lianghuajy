#!/bin/bash
# ============================================
# 数据库字段注释添加脚本
# 用途：在已有数据库上添加字段注释（无需重建）
# ============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函数：打印带颜色的消息
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

echo ""
echo "================================================================================"
echo -e "${BLUE}数据库字段注释添加工具${NC}"
echo "================================================================================"
echo ""

# 检查 Docker 是否运行
if ! docker ps &> /dev/null; then
    log_error "Docker 未运行或无权限访问"
    exit 1
fi

# 检查 PostgreSQL 容器是否运行
POSTGRES_CONTAINER=$(docker ps --filter "name=postgres" --format "{{.Names}}" | head -1)
if [ -z "$POSTGRES_CONTAINER" ]; then
    log_error "PostgreSQL 容器未运行"
    log_info "请先启动系统: docker compose up -d"
    exit 1
fi

log_success "找到 PostgreSQL 容器: $POSTGRES_CONTAINER"

# 获取脚本所在目录的父目录（deployment）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_DIR="$(dirname "$SCRIPT_DIR")"
SQL_FILE="$DEPLOYMENT_DIR/sql/comments.sql"

# 检查 SQL 文件是否存在
if [ ! -f "$SQL_FILE" ]; then
    log_error "SQL 文件不存在: $SQL_FILE"
    exit 1
fi

log_info "准备执行注释添加脚本..."
echo ""

# 执行 SQL 脚本
log_info "执行 SQL 脚本: comments.sql"
if docker exec -i "$POSTGRES_CONTAINER" psql -U funcat_user -d funcat < "$SQL_FILE"; then
    log_success "字段注释添加成功！"
else
    log_error "字段注释添加失败"
    exit 1
fi

echo ""
log_info "验证注释是否添加成功..."
echo ""

# 验证：显示 select_results 表的字段注释
echo "================================================================================"
echo "示例：select_results 表字段注释"
echo "================================================================================"
docker exec -i "$POSTGRES_CONTAINER" psql -U funcat_user -d funcat -c "\d+ select_results" | head -20

echo ""
log_success "所有操作完成！"
echo ""
log_info "查看其他表的注释："
echo "  docker compose exec postgres psql -U funcat_user -d funcat -c \"\\d+ users\""
echo "  docker compose exec postgres psql -U funcat_user -d funcat -c \"\\d+ backtest_records\""
echo ""
