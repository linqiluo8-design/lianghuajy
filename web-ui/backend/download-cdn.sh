#!/bin/sh
# ============================================
# 下载Web UI所需的CDN资源到本地
# ============================================

STATIC_DIR="./static/libs"
FAILED_COUNT=0

echo "📦 创建目录结构..."
mkdir -p "$STATIC_DIR/vue"
mkdir -p "$STATIC_DIR/element-plus"
mkdir -p "$STATIC_DIR/echarts"

# 带重试和多源的下载函数
download_with_retry() {
    local output="$2"
    local max_retries=2
    local retry=0

    # 支持多个URL作为备用源
    shift

    while [ $retry -lt $max_retries ]; do
        for url in "$@"; do
            echo "  尝试下载 $(basename $output) 从 $(echo $url | cut -d'/' -f3) (尝试 $((retry + 1))/$max_retries)..."
            if wget --timeout=20 --tries=1 -O "$output" "$url" 2>&1 | grep -q "saved"; then
                echo "  ✓ 下载成功: $(basename $output) ($(du -h $output | cut -f1))"
                return 0
            fi
        done
        retry=$((retry + 1))
        [ $retry -lt $max_retries ] && sleep 1
    done

    echo "  ✗ 下载失败: $(basename $output)"
    FAILED_COUNT=$((FAILED_COUNT + 1))
    return 1
}

echo ""
echo "⬇️  下载 Vue 3..."
download_with_retry \
    "$STATIC_DIR/vue/vue.global.prod.js" \
    "https://unpkg.com/vue@3.3.11/dist/vue.global.prod.js" \
    "https://cdn.jsdelivr.net/npm/vue@3.3.11/dist/vue.global.prod.js"

echo ""
echo "⬇️  下载 Element Plus CSS..."
download_with_retry \
    "$STATIC_DIR/element-plus/index.css" \
    "https://unpkg.com/element-plus@2.4.4/dist/index.css" \
    "https://cdn.jsdelivr.net/npm/element-plus@2.4.4/dist/index.css"

echo ""
echo "⬇️  下载 Element Plus JS..."
download_with_retry \
    "$STATIC_DIR/element-plus/index.full.js" \
    "https://unpkg.com/element-plus@2.4.4/dist/index.full.js" \
    "https://cdn.jsdelivr.net/npm/element-plus@2.4.4/dist/index.full.js"

echo ""
echo "⬇️  下载 Element Plus Icons..."
download_with_retry \
    "$STATIC_DIR/element-plus/icons.iife.min.js" \
    "https://unpkg.com/@element-plus/icons-vue@2.1.0/dist/index.iife.min.js" \
    "https://cdn.jsdelivr.net/npm/@element-plus/icons-vue@2.1.0/dist/index.iife.min.js"

echo ""
echo "⬇️  下载 ECharts..."
download_with_retry \
    "$STATIC_DIR/echarts/echarts.min.js" \
    "https://unpkg.com/echarts@5.4.3/dist/echarts.min.js" \
    "https://cdn.jsdelivr.net/npm/echarts@5.4.3/dist/echarts.min.js"

echo ""
if [ $FAILED_COUNT -eq 0 ]; then
    echo "✅ 所有CDN资源下载成功！"
else
    echo "⚠️  警告: $FAILED_COUNT 个资源下载失败"
    echo "   页面将回退使用在线CDN资源"
fi

echo "📁 资源保存在: $STATIC_DIR"
ls -lh "$STATIC_DIR/vue/" 2>/dev/null || echo "  Vue: 未下载"
ls -lh "$STATIC_DIR/element-plus/" 2>/dev/null || echo "  Element Plus: 未下载"
ls -lh "$STATIC_DIR/echarts/" 2>/dev/null || echo "  ECharts: 未下载"

# 即使部分失败也继续构建（页面会回退到CDN）
exit 0
