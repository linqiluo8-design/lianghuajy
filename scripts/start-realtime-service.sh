#!/bin/bash
# ============================================
# 启动实时行情采集服务
# ============================================

set -e

echo "🚀 启动实时行情采集服务"
echo "============================================"

# 进入项目根目录
cd "$(dirname "$0")/.."

# 检查 Python 环境
if ! command -v python3 &> /dev/null; then
    echo "❌ 错误: 未找到 Python3"
    exit 1
fi

# 检查依赖
echo "📦 检查依赖..."
missing_deps=()

python3 -c "import akshare" 2>/dev/null || missing_deps+=("akshare")
python3 -c "import pytdx" 2>/dev/null || missing_deps+=("pytdx")
python3 -c "import yaml" 2>/dev/null || missing_deps+=("pyyaml")
python3 -c "import psycopg2" 2>/dev/null || missing_deps+=("psycopg2-binary")

if [ ${#missing_deps[@]} -gt 0 ]; then
    echo "⚠️  缺少依赖: ${missing_deps[*]}"
    echo "正在安装..."
    pip3 install ${missing_deps[*]}
fi

# 创建日志目录
mkdir -p logs

# 读取配置
DATA_SOURCE=${REALTIME_DATA_SOURCE:-akshare}
REFRESH_INTERVAL=${REALTIME_REFRESH_INTERVAL:-2}

echo ""
echo "配置信息:"
echo "  数据源: $DATA_SOURCE"
echo "  刷新间隔: $REFRESH_INTERVAL 秒"
echo ""

# 启动服务
echo "🔥 启动服务..."
python3 services/realtime_fetcher.py \
    --config config/realtime.yaml \
    --source $DATA_SOURCE

echo "✅ 服务已停止"
