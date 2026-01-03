#!/bin/bash
# ============================================
# 启动实时行情采集服务（简化版，跳过依赖检查）
# ============================================

echo "🚀 启动实时行情采集服务"
echo "============================================"

# 进入项目根目录
cd "$(dirname "$0")/.."

# 创建日志目录
mkdir -p logs

# 读取配置
DATA_SOURCE=${1:-akshare}
REFRESH_INTERVAL=${REALTIME_REFRESH_INTERVAL:-2}

echo ""
echo "配置信息:"
echo "  数据源: $DATA_SOURCE"
echo "  刷新间隔: $REFRESH_INTERVAL 秒"
echo ""

# 直接启动服务（不检查依赖）
echo "🔥 启动服务..."
python3 services/realtime_fetcher.py --source $DATA_SOURCE

echo ""
echo "✅ 服务已停止"
