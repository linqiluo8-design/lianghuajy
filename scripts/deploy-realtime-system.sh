#!/bin/bash
# ============================================
# 部署实时行情采集系统
# ============================================

set -e

echo "🚀 部署实时行情采集系统"
echo "============================================"
echo ""

# 进入项目根目录
cd "$(dirname "$0")/.."
PROJECT_ROOT=$(pwd)

# 检查 Python
if ! command -v python3 &> /dev/null; then
    echo "❌ 错误: 未找到 Python3"
    echo "请先安装 Python 3.7+"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | awk '{print $2}')
echo "✅ Python 版本: $PYTHON_VERSION"
echo ""

# 步骤1：安装依赖
echo "📦 步骤 1/5: 安装 Python 依赖..."
echo "----------------------------------------"

if [ -f "requirements-realtime.txt" ]; then
    pip3 install -r requirements-realtime.txt
    echo "✅ 依赖安装完成"
else
    echo "⚠️  未找到 requirements-realtime.txt，手动安装..."
    pip3 install akshare pytdx pyyaml psycopg2-binary pandas
fi

echo ""

# 步骤2：创建必要目录
echo "📁 步骤 2/5: 创建目录结构..."
echo "----------------------------------------"

mkdir -p config
mkdir -p logs
mkdir -p services/data_sources

echo "✅ 目录创建完成"
echo ""

# 步骤3：生成配置文件（如果不存在）
echo "⚙️  步骤 3/5: 检查配置文件..."
echo "----------------------------------------"

if [ ! -f "config/realtime.yaml" ]; then
    echo "⚠️  配置文件不存在，使用默认配置"
    echo "请编辑 config/realtime.yaml 以自定义配置"
fi

if [ ! -f ".env" ] && [ -f ".env.example" ]; then
    echo "⚠️  .env 文件不存在"
    echo "建议复制 .env.example 并修改配置："
    echo "  cp .env.example .env"
fi

echo "✅ 配置检查完成"
echo ""

# 步骤4：测试数据源连接
echo "🔌 步骤 4/5: 测试数据源连接..."
echo "----------------------------------------"

# 测试 AkShare
echo "测试 AkShare..."
python3 -c "
import akshare as ak
try:
    df = ak.stock_zh_a_spot_em()
    print(f'✅ AkShare 连接成功，获取到 {len(df)} 只股票')
except Exception as e:
    print(f'❌ AkShare 连接失败: {e}')
" || echo "⚠️  AkShare 测试失败，请检查网络"

echo ""

# 测试 pytdx
echo "测试 pytdx..."
python3 -c "
from pytdx.hq import TdxHq_API
try:
    api = TdxHq_API()
    result = api.connect('119.147.212.81', 7709)
    if result:
        print('✅ pytdx 连接成功')
        api.disconnect()
    else:
        print('❌ pytdx 连接失败')
except Exception as e:
    print(f'❌ pytdx 测试失败: {e}')
" || echo "⚠️  pytdx 测试失败，请检查网络或防火墙"

echo ""

# 步骤5：显示使用说明
echo "📖 步骤 5/5: 部署完成！"
echo "============================================"
echo ""
echo "✅ 实时行情采集系统部署成功！"
echo ""
echo "📋 后续步骤："
echo ""
echo "1️⃣  启动实时采集服务（选择一个数据源）："
echo "   # 使用 AkShare（推荐新手）"
echo "   ./scripts/start-realtime-service.sh"
echo ""
echo "   # 或使用 pytdx（更稳定）"
echo "   python3 services/realtime_fetcher.py --source pytdx"
echo ""
echo "2️⃣  访问 Web UI："
echo "   http://localhost:8080"
echo ""
echo "3️⃣  在页面上切换数据源："
echo "   页面顶部 -> 数据源下拉框 -> 选择 AkShare 或 通达信"
echo ""
echo "📚 更多信息："
echo "   查看文档: cat REALTIME_DATA_GUIDE.md"
echo "   查看日志: tail -f logs/realtime_fetcher.log"
echo ""
echo "============================================"
echo "🎉 祝您使用愉快！"
echo ""
