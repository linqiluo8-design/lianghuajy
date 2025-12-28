#!/bin/sh
# ============================================
# 下载Web UI所需的CDN资源到本地
# ============================================

STATIC_DIR="./static/libs"

echo "📦 创建目录结构..."
mkdir -p "$STATIC_DIR/vue"
mkdir -p "$STATIC_DIR/element-plus"
mkdir -p "$STATIC_DIR/echarts"

# 带重试的下载函数
download_with_retry() {
    local url="$1"
    local output="$2"
    local max_retries=3
    local retry=0

    while [ $retry -lt $max_retries ]; do
        echo "  尝试下载 $(basename $output) (尝试 $((retry + 1))/$max_retries)..."
        if wget --timeout=30 --tries=2 -O "$output" "$url" 2>&1; then
            echo "  ✓ 下载成功: $(basename $output)"
            return 0
        fi
        retry=$((retry + 1))
        [ $retry -lt $max_retries ] && sleep 2
    done

    echo "  ✗ 下载失败: $(basename $output)"
    return 1
}

echo ""
echo "⬇️  下载 Vue 3..."
download_with_retry \
    "https://unpkg.com/vue@3.3.11/dist/vue.global.prod.js" \
    "$STATIC_DIR/vue/vue.global.prod.js" || exit 1

echo ""
echo "⬇️  下载 Element Plus CSS..."
download_with_retry \
    "https://unpkg.com/element-plus@2.4.4/dist/index.css" \
    "$STATIC_DIR/element-plus/index.css" || exit 1

echo ""
echo "⬇️  下载 Element Plus JS..."
download_with_retry \
    "https://unpkg.com/element-plus@2.4.4/dist/index.full.js" \
    "$STATIC_DIR/element-plus/index.full.js" || exit 1

echo ""
echo "⬇️  下载 Element Plus Icons..."
download_with_retry \
    "https://unpkg.com/@element-plus/icons-vue@2.1.0/dist/index.iife.min.js" \
    "$STATIC_DIR/element-plus/icons.iife.min.js" || exit 1

echo ""
echo "⬇️  下载 ECharts..."
download_with_retry \
    "https://cdn.jsdelivr.net/npm/echarts@5.4.3/dist/echarts.min.js" \
    "$STATIC_DIR/echarts/echarts.min.js" || exit 1

echo ""
echo "✅ CDN资源下载完成！"
echo "📁 资源保存在: $STATIC_DIR"
ls -lh "$STATIC_DIR/vue/"
ls -lh "$STATIC_DIR/element-plus/"
ls -lh "$STATIC_DIR/echarts/"
