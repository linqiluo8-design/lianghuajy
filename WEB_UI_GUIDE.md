# Funcat 涨跌停数据看板使用指南

## 📊 功能概述

Funcat Web UI 是一个专业的股票涨跌停数据可视化平台，提供以下核心功能：

### ✨ 核心功能

1. **板块选择与筛选**
   - 支持按板块类型筛选（行业、概念、地域）
   - 支持多板块对比分析
   - 实时板块数据更新

2. **涨跌停统计看板**
   - 📈 涨停家数统计
   - 📉 跌停家数统计
   - 🔥 一字涨停数量
   - 💥 炸板总数统计

3. **炸板监控**
   - 炸板回封数量统计
   - 炸板未回封数量统计
   - 炸板次数详细记录
   - 炸板时间和回封时间追踪

4. **一字涨停统计**
   - 识别一字涨停个股
   - 统计各板块一字板数量
   - 一字板封单量分析

5. **连板天梯**
   - 🏆 连板排行榜（2连、3连、4连、5连以上）
   - 连板个股详细信息
   - 累计涨幅统计
   - 封单强度分析
   - 板块归属和概念标签

---

## 🚀 快速开始

### 方式一：使用 Docker Compose（推荐）

#### 1. 初始化数据库

```bash
# 进入项目目录
cd /home/user/lianghuajy

# 启动数据库服务
docker-compose up -d postgres redis

# 等待数据库启动完成（约10秒）
sleep 10

# 执行数据库扩展脚本
docker-compose exec postgres psql -U funcat_user -d funcat -f /docker-entrypoint-initdb.d/03-schema_extension.sql

# 初始化示例数据
docker-compose exec postgres psql -U funcat_user -d funcat -f /docker-entrypoint-initdb.d/04-sample_data.sql
```

#### 2. 启动 Web UI 服务

```bash
# 构建并启动 Web UI
docker-compose up -d --build webui

# 查看启动日志
docker-compose logs -f webui
```

#### 3. 访问界面

打开浏览器访问：
```
http://localhost:8080
```

**默认端口**: 8080（可通过 `.env` 中的 `WEBUI_PORT` 修改）

---

### 方式二：本地开发运行

#### 1. 安装依赖

```bash
cd web-ui/backend

# 下载 Go 依赖
go mod download
```

#### 2. 配置环境变量

创建 `.env` 文件：

```bash
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USER=funcat_user
POSTGRES_PASSWORD=your_password
POSTGRES_DB=funcat

REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=your_redis_password

API_PORT=8080
LOG_LEVEL=info
```

#### 3. 运行服务

```bash
# 运行开发服务器
go run main.go
```

#### 4. 访问界面

```
http://localhost:8080
```

---

## 📖 界面使用说明

### 1. 主界面布局

```
┌────────────────────────────────────────────────┐
│  📊 Funcat 涨跌停数据看板                        │
│  实时监控市场热点 · 板块涨停统计 · 连板天梯       │
├────────────────────────────────────────────────┤
│  [日期选择] [板块选择] [类型] [🔄刷新]          │
├────────────────────────────────────────────────┤
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐          │
│  │📈涨停 │ │📉跌停 │ │🔥一字 │ │💥炸板 │          │
│  │  125  │ │  18  │ │  32  │ │  45  │          │
│  └──────┘ └──────┘ └──────┘ └──────┘          │
├────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌───────────────────┐   │
│  │ 📊 板块涨停排行  │  │ 🏆 连板天梯        │   │
│  │                 │  │                   │   │
│  │ [柱状图]        │  │ 1. 宁德时代 (4连) │   │
│  │                 │  │ 2. 中航沈飞 (5连) │   │
│  │                 │  │ 3. 中芯国际 (3连) │   │
│  └─────────────────┘  └───────────────────┘   │
├────────────────────────────────────────────────┤
│  📋 板块详细统计表                              │
│  [表格: 板块 | 涨停 | 一字 | 炸板 | 回封...]   │
├────────────────────────────────────────────────┤
│  💎 涨跌停个股列表                              │
│  [表格: 股票 | 连板 | 时间 | 涨幅 | 标记...]   │
└────────────────────────────────────────────────┘
```

---

### 2. 筛选功能

#### 日期选择
- 选择任意交易日期
- 查看历史涨跌停数据
- 默认显示当天数据

#### 板块选择
- **全部板块**: 显示所有板块统计
- **行业板块**: 半导体、新能源汽车、医药等
- **概念板块**: ChatGPT、数字经济、储能等
- **地域板块**: 深圳本地、上海本地等

#### 涨跌停类型
- **全部**: 显示所有涨跌停个股
- **涨停**: 仅显示涨停个股
- **跌停**: 仅显示跌停个股

---

### 3. 数据统计卡片

#### 📈 涨停家数
- 显示当日涨停股票总数
- 包含所有板块的涨停个股

#### 📉 跌停家数
- 显示当日跌停股票总数
- 市场情绪指标

#### 🔥 一字涨停
- 统计一字板数量
- 反映市场强势程度

#### 💥 炸板总数
- 统计炸板次数
- 包含回封和未回封

---

### 4. 板块涨停排行榜

- **可视化图表**: 横向柱状图展示
- **多维度对比**:
  - 🔴 红色: 涨停数量
  - 🟠 橙色: 一字板数量
  - ⚪ 灰色: 炸板数量
  - 🟢 绿色: 回封数量

- **交互功能**: 鼠标悬停查看详细数值

---

### 5. 连板天梯

#### 排行榜功能
- **排名显示**: 🥇🥈🥉 金银铜牌标识
- **连板天数**: 醒目的红色标签
- **股票信息**: 名称 + 代码
- **板块归属**: 主板块显示
- **封单量**: 实时封单数据
- **累计涨幅**: 连板周期内总涨幅

#### 特殊标记
- 🏷️ **一字**: 一字涨停标记
- ⚠️ **炸板Nx**: 炸板次数标记

#### 数据更新
- 自动刷新连板数据
- 最多显示前100名
- 默认显示2连以上

---

### 6. 板块详细统计表

#### 表格列说明

| 列名 | 说明 | 颜色标识 |
|------|------|---------|
| **板块名称** | 板块中文名称 | - |
| **涨停** | 该板块涨停数量 | 🔴 红色标签 |
| **一字板** | 一字涨停数量 | - |
| **炸板** | 炸板总数 | 🟠 橙色标签 |
| **回封** | 炸板后回封数量 | 🟢 绿色标签 |
| **未回封** | 炸板未回封数量 | ⚪ 灰色标签 |
| **连板分布** | 2连、3连、4连、5+连板统计 | - |
| **平均涨幅** | 板块平均涨跌幅 | 红涨绿跌 |
| **总成交额** | 板块总成交金额 | - |
| **跌停** | 跌停数量 | 🟢 绿色标签 |

#### 排序功能
- 点击列标题进行排序
- 支持升序/降序切换
- 默认按涨停数量降序

---

### 7. 涨跌停个股列表

#### 表格列说明

| 列名 | 说明 |
|------|------|
| **股票名称** | 股票中文名称 |
| **代码** | 股票代码（如000001.XSHE） |
| **连板** | 连续涨停天数（0表示非连板） |
| **封板时间** | 首次涨停时间 |
| **涨跌幅** | 当日涨跌幅百分比 |
| **标记** | 一字板、炸板回封、炸板未封等标签 |
| **封单量** | 涨停封单数量（手） |
| **换手率** | 成交换手率 |
| **成交额** | 总成交金额 |

#### 特殊标记说明
- 🏷️ **一字板**: 开盘即涨停，全天一字板
- ⚠️ **炸板回封**: 盘中打开涨停后重新封板
- ℹ️ **炸板未封**: 盘中打开涨停且未回封

---

## 🔌 API 接口文档

### 基础信息

- **Base URL**: `http://localhost:8080/api/v1`
- **返回格式**: JSON
- **字符编码**: UTF-8

### 统一响应格式

```json
{
  "code": 200,
  "message": "success",
  "data": {}
}
```

---

### 1. 获取板块列表

**接口**: `GET /api/v1/sectors`

**参数**:
- `type` (可选): 板块类型（industry/concept/region）

**示例请求**:
```bash
curl http://localhost:8080/api/v1/sectors?type=industry
```

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": [
    {
      "id": 1,
      "sector_code": "BK001",
      "sector_name": "半导体",
      "sector_type": "industry",
      "stock_count": 45,
      "description": "集成电路、芯片制造",
      "is_active": true
    }
  ]
}
```

---

### 2. 获取板块统计

**接口**: `GET /api/v1/sectors/stats`

**参数**:
- `date` (可选): 日期（YYYY-MM-DD格式，默认今天）

**示例请求**:
```bash
curl "http://localhost:8080/api/v1/sectors/stats?date=2024-12-19"
```

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": [
    {
      "sector_id": 1,
      "sector_name": "半导体",
      "limit_up_count": 3,
      "limit_down_count": 0,
      "one_word_count": 1,
      "broken_count": 1,
      "broken_resealed_count": 1,
      "broken_not_resealed_count": 0,
      "consecutive_2_count": 1,
      "consecutive_3_count": 1,
      "avg_change_pct": 6.8,
      "total_turnover": 50700000000
    }
  ]
}
```

---

### 3. 获取涨跌停列表

**接口**: `GET /api/v1/limit-stats`

**参数**:
- `date` (可选): 日期
- `type` (可选): 类型（limit_up/limit_down）
- `sector_id` (可选): 板块ID

**示例请求**:
```bash
curl "http://localhost:8080/api/v1/limit-stats?date=2024-12-19&type=limit_up"
```

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": [
    {
      "stock_code": "600002.XSHG",
      "stock_name": "宁德时代",
      "consecutive_limit_days": 4,
      "first_limit_time": "09:25:00",
      "change_pct": 10.0,
      "is_one_word": true,
      "is_broken": false,
      "seal_amount": 200000,
      "turnover_rate": 9.8
    }
  ]
}
```

---

### 4. 获取连板天梯

**接口**: `GET /api/v1/consecutive-ladder`

**参数**:
- `min_days` (可选): 最小连板天数（默认2）

**示例请求**:
```bash
curl "http://localhost:8080/api/v1/consecutive-ladder?min_days=3"
```

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": [
    {
      "stock_code": "600201.XSHG",
      "stock_name": "中航沈飞",
      "consecutive_days": 5,
      "start_date": "2024-12-15",
      "total_gain_pct": 61.05,
      "avg_seal_ratio": 92.3,
      "main_sector": "军工",
      "seal_amount": 180000,
      "is_one_word": true,
      "broken_count": 0
    }
  ]
}
```

---

## 📊 数据说明

### 1. 涨跌停判定标准

- **涨停**: `change_pct >= 9.9%` (考虑精度误差)
- **跌停**: `change_pct <= -9.9%`
- **一字涨停**: `open_price == close_price == high_price` 且为涨停

### 2. 炸板定义

- **炸板**: 盘中达到涨停后打开
- **回封**: 炸板后重新封住涨停
- **未回封**: 炸板后未能重新封住

### 3. 连板计算

- **连板天数**: 连续涨停的交易日数量
- **累计涨幅**: 连板周期内的总涨幅
- **封单比率**: 封单量占流通盘的比例

---

## 🛠️ 故障排查

### 问题1: 页面无法访问

**症状**: 浏览器无法打开 `http://localhost:8080`

**解决方案**:
```bash
# 1. 检查服务状态
docker-compose ps webui

# 2. 查看日志
docker-compose logs webui

# 3. 检查端口占用
lsof -i :8080

# 4. 重启服务
docker-compose restart webui
```

---

### 问题2: 数据为空

**症状**: 页面显示但没有数据

**解决方案**:
```bash
# 1. 检查数据库连接
docker-compose exec webui curl http://localhost:8080/api/v1/health

# 2. 查看数据库数据
docker-compose exec postgres psql -U funcat_user -d funcat -c "SELECT COUNT(*) FROM sectors;"

# 3. 重新初始化示例数据
docker-compose exec postgres psql -U funcat_user -d funcat -f /docker-entrypoint-initdb.d/04-sample_data.sql
```

---

### 问题3: API 请求失败

**症状**: 前端控制台显示 API 错误

**解决方案**:
```bash
# 1. 测试 API
curl http://localhost:8080/api/v1/health

# 2. 检查数据库扩展表是否创建
docker-compose exec postgres psql -U funcat_user -d funcat -c "\dt"

# 3. 执行扩展脚本
docker-compose exec postgres psql -U funcat_user -d funcat -f /docker-entrypoint-initdb.d/03-schema_extension.sql
```

---

## 🔧 配置说明

### 环境变量配置

在 `.env` 文件中可以配置以下参数：

```bash
# Web UI 端口
WEBUI_PORT=8080

# 数据库配置
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DB=funcat
POSTGRES_USER=funcat_user
POSTGRES_PASSWORD=your_password

# Redis配置
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=your_redis_password

# 日志级别
LOG_LEVEL=info  # debug, info, warn, error
```

---

## 📈 性能优化

### 1. 数据库索引

已自动创建的索引：
- 交易日期索引
- 股票代码索引
- 涨跌停类型索引
- 连板天数索引

### 2. 缓存策略

- 板块列表缓存（1小时）
- 历史数据缓存（永久）
- 当日数据实时更新

### 3. 分页加载

- 连板天梯: 最多100条
- 个股列表: 支持虚拟滚动

---

## 🎨 界面定制

### 修改主题颜色

编辑 `static/index.html` 中的 CSS 变量：

```css
.stat-card.red .value { color: #F56C6C; }  /* 涨停红色 */
.stat-card.green .value { color: #67C23A; } /* 跌停绿色 */
.stat-card.blue .value { color: #409EFF; }  /* 蓝色 */
```

### 修改图表样式

修改 ECharts 配置：

```javascript
const option = {
  color: ['#F56C6C', '#E6A23C', '#909399', '#67C23A'],
  // ...其他配置
};
```

---

## 📝 更新日志

### v2.0.0 (2024-12-19)
- ✨ 首次发布涨跌停数据看板
- 🎨 现代化UI设计
- 📊 支持板块统计和筛选
- 🏆 连板天梯可视化
- 💥 炸板监控功能
- 📈 ECharts图表集成

---

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

### 开发环境搭建

```bash
# 克隆项目
git clone https://github.com/your-repo/funcat.git

# 进入 Web UI 目录
cd web-ui/backend

# 安装依赖
go mod download

# 运行开发服务器
go run main.go
```

---

## 📄 许可证

本项目采用 MIT 许可证。详见 [LICENSE](../LICENSE) 文件。

---

## 💬 联系方式

- 📧 Email: support@funcat.com
- 🐛 Issues: [GitHub Issues](https://github.com/your-repo/funcat/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/your-repo/funcat/discussions)

---

**祝使用愉快！** 📊🚀
