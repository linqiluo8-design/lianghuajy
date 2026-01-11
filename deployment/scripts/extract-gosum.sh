#!/bin/bash
# ============================================
# 从容器中提取 go.sum 文件
# 用途：首次构建后提取 go.sum 并提交到 git
# ============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
echo -e "${BLUE}从 Docker 容器提取 go.sum 文件${NC}"
echo "================================================================================"
echo ""

# 检查参数
if [ "$#" -ne 1 ]; then
    log_error "用法: $0 <服务名称>"
    echo ""
    echo "示例："
    echo "  $0 webui          # 提取 Web UI 后端的 go.sum"
    echo "  $0 funcat-go      # 提取 funcat-go 的 go.sum"
    exit 1
fi

SERVICE_NAME="$1"

# 映射服务名称到目录
case "$SERVICE_NAME" in
    webui|web-ui)
        TARGET_DIR="web-ui/backend"
        CONTAINER_NAME="lianghuajy-webui-1"
        ;;
    funcat-go|funcat)
        TARGET_DIR="funcat-go"
        CONTAINER_NAME="lianghuajy-funcat-go-1"
        ;;
    *)
        log_error "未知的服务名称: $SERVICE_NAME"
        echo ""
        echo "支持的服务："
        echo "  - webui / web-ui"
        echo "  - funcat-go / funcat"
        exit 1
        ;;
esac

log_info "服务: $SERVICE_NAME"
log_info "目标目录: $TARGET_DIR"
echo ""

# 检查目录是否存在
if [ ! -d "$TARGET_DIR" ]; then
    log_error "目录不存在: $TARGET_DIR"
    exit 1
fi

# 检查 go.mod 是否存在
if [ ! -f "$TARGET_DIR/go.mod" ]; then
    log_error "go.mod 不存在: $TARGET_DIR/go.mod"
    exit 1
fi

# 检查 Docker 是否运行
if ! docker ps &> /dev/null; then
    log_error "Docker 未运行或无权限访问"
    exit 1
fi

# 查找容器（使用模糊匹配）
CONTAINER=$(docker ps --filter "name=$SERVICE_NAME" --format "{{.Names}}" | head -1)
if [ -z "$CONTAINER" ]; then
    log_warning "容器未运行，尝试构建镜像..."
    echo ""

    # 临时构建以生成 go.sum
    log_info "创建临时容器生成 go.sum..."
    TEMP_IMAGE="temp-gosum-$SERVICE_NAME"

    docker run --rm \
        -v "$(pwd)/$TARGET_DIR":/build \
        -w /build \
        golang:1.21-alpine \
        sh -c "apk add --no-cache git && \
               export GOPROXY=https://goproxy.cn,https://mirrors.aliyun.com/goproxy/,https://goproxy.io,direct && \
               export GOSUMDB=off && \
               go mod tidy && \
               go mod download && \
               ls -la go.sum"

    if [ -f "$TARGET_DIR/go.sum" ]; then
        log_success "go.sum 已生成: $TARGET_DIR/go.sum"
        echo ""
        log_info "下一步："
        echo "  1. 验证 go.sum 文件"
        echo "  2. 提交到 git: git add $TARGET_DIR/go.sum && git commit -m 'feat: 添加 go.sum 文件'"
        echo "  3. 之后构建将利用 Docker 缓存，速度大幅提升"
    else
        log_error "go.sum 生成失败"
        exit 1
    fi
else
    log_success "找到容器: $CONTAINER"
    echo ""

    # 从容器复制 go.sum
    log_info "从容器复制 go.sum..."

    # 检查容器内是否有 go.sum
    if ! docker exec "$CONTAINER" test -f /build/go.sum; then
        log_error "容器内 go.sum 不存在: /build/go.sum"
        exit 1
    fi

    # 复制文件
    docker cp "$CONTAINER:/build/go.sum" "$TARGET_DIR/go.sum"

    if [ -f "$TARGET_DIR/go.sum" ]; then
        log_success "go.sum 已提取: $TARGET_DIR/go.sum"
        echo ""

        # 显示文件信息
        log_info "文件信息:"
        ls -lh "$TARGET_DIR/go.sum"
        echo ""

        log_info "下一步："
        echo "  1. 验证 go.sum 文件"
        echo "  2. 提交到 git: git add $TARGET_DIR/go.sum && git commit -m 'feat: 添加 go.sum 文件'"
        echo "  3. 之后构建将利用 Docker 缓存，速度大幅提升"
    else
        log_error "go.sum 提取失败"
        exit 1
    fi
fi

echo ""
log_success "完成！"
echo ""
