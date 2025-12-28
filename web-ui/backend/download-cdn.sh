#!/bin/sh
# ============================================
# 下载Web UI所需的CDN资源到本地
# ============================================

set -e

STATIC_DIR="./static/libs"

echo "📦 创建目录结构..."
mkdir -p "$STATIC_DIR/vue"
mkdir -p "$STATIC_DIR/element-plus"
mkdir -p "$STATIC_DIR/echarts"

echo "⬇️  下载 Vue 3..."
wget -q -O "$STATIC_DIR/vue/vue.global.prod.js" \
    "https://unpkg.com/vue@3.3.11/dist/vue.global.prod.js"

echo "⬇️  下载 Element Plus CSS..."
wget -q -O "$STATIC_DIR/element-plus/index.css" \
    "https://unpkg.com/element-plus@2.4.4/dist/index.css"

echo "⬇️  下载 Element Plus JS..."
wget -q -O "$STATIC_DIR/element-plus/index.full.js" \
    "https://unpkg.com/element-plus@2.4.4/dist/index.full.js"

echo "⬇️  下载 Element Plus Icons..."
wget -q -O "$STATIC_DIR/element-plus/icons.iife.min.js" \
    "https://unpkg.com/@element-plus/icons-vue@2.1.0/dist/index.iife.min.js"

echo "⬇️  下载 ECharts..."
wget -q -O "$STATIC_DIR/echarts/echarts.min.js" \
    "https://cdn.jsdelivr.net/npm/echarts@5.4.3/dist/echarts.min.js"

echo "✅ CDN资源下载完成！"
echo "📁 资源保存在: $STATIC_DIR"
