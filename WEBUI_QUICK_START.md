# 🚀 Web UI 快速启动指南

## 一键启动（推荐）

使用我们提供的自动化脚本，3分钟内完成部署：

```bash
# 进入项目目录
cd /home/user/lianghuajy

# 运行启动脚本
bash scripts/start-webui.sh
```

脚本会自动完成以下操作：
1. ✅ 检查 Docker 环境
2. 📦 启动 PostgreSQL 和 Redis
3. 📝 初始化数据库扩展表
4. 📊 导入示例数据
5. 🌐 启动 Web UI 服务

完成后访问: **http://localhost:8080**

---

## 手动启动

如果你想手动控制每一步：

### 步骤1: 配置环境变量

```bash
# 复制环境变量模板
cp .env.example .env

# 编辑配置（可选，使用默认值也可以）
vim .env
```

### 步骤2: 启动数据库服务

```bash
# 启动PostgreSQL和Redis
docker-compose up -d postgres redis

# 等待服务启动
sleep 15

# 验证数据库连接
docker-compose exec postgres pg_isready -U funcat_user -d funcat
```

### 步骤3: 初始化数据库扩展

```bash
# 执行扩展表创建脚本
docker-compose exec -T postgres psql -U funcat_user -d funcat < deployment/sql/schema_extension.sql

# 执行示例数据脚本
docker-compose exec -T postgres psql -U funcat_user -d funcat < deployment/sql/init_sample_data.sql
```

### 步骤4: 启动 Web UI

```bash
# 构建并启动Web UI服务
docker-compose up -d --build webui

# 查看启动日志
docker-compose logs -f webui
```

### 步骤5: 访问界面

打开浏览器访问: **http://localhost:8080**

---

## 界面预览

启动成功后，你将看到：

### 📊 主界面

```
┌─────────────────────────────────────────────────┐
│  📊 Funcat 涨跌停数据看板                         │
│  实时监控市场热点 · 板块涨停统计 · 连板天梯        │
└─────────────────────────────────────────────────┘

┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│ 📈 涨停   │ │ 📉 跌停   │ │ 🔥 一字   │ │ 💥 炸板   │
│   8      │ │   2      │ │   3      │ │   2      │
└──────────┘ └──────────┘ └──────────┘ └──────────┘
```

### 🏆 连板天梯

```
🥇 1. 中航沈飞 (600201.XSHG)     5连  军工
🥈 2. 宁德时代 (600002.XSHG)     4连  新能源汽车
🥉 3. 中芯国际 (000001.XSHE)     3连  半导体
   4. 科大讯飞 (300001.XSHE)     2连  ChatGPT
   5. 韦尔股份 (000002.XSHE)     2连  半导体
```

### 📊 板块涨停排行

```
半导体       ▓▓▓▓▓▓▓▓  3
新能源汽车   ▓▓▓▓▓▓    2
AI概念       ▓▓▓▓▓▓    2
军工         ▓▓▓       1
ChatGPT      ▓▓▓       1
```

---

## 核心功能展示

### 1. 板块筛选

- 选择 **半导体** 板块，查看该板块的涨停情况
- 筛选 **涨停** 类型，只显示涨停个股
- 选择 **日期**，回顾历史涨跌停数据

### 2. 涨跌停统计

#### 板块详细统计表

| 板块名称 | 涨停 | 一字板 | 炸板 | 回封 | 未回封 | 连板分布 |
|---------|------|--------|------|------|--------|----------|
| 半导体   | 3    | 1      | 1    | 1    | 0      | 2连:1 3连:1 |
| 新能源   | 2    | 1      | 1    | 0    | 1      | 4连:1 |
| AI概念   | 2    | 0      | 1    | 1    | 0      | 2连:1 |

### 3. 个股详情

#### 涨跌停个股列表

| 股票名称 | 代码 | 连板 | 时间 | 涨幅 | 标记 | 封单量 |
|---------|------|------|------|------|------|--------|
| 宁德时代 | 600002.XSHG | 4连 | 09:25 | 10.00% | 🏷️一字板 | 20万手 |
| 中航沈飞 | 600201.XSHG | 5连 | 09:31 | 10.00% | 🏷️一字板 | 18万手 |
| 中芯国际 | 000001.XSHE | 3连 | 09:30 | 10.00% | 🏷️一字板 | 10万手 |
| 比亚迪   | 600001.XSHG | - | 14:30 | 10.00% | ⚠️炸板未封 | 5万手 |

### 4. 炸板监控

**半导体板块炸板情况**:
- 炸板总数: 1
- 回封数量: 1 ✅
- 未回封数量: 0

**新能源板块炸板情况**:
- 炸板总数: 1
- 回封数量: 0
- 未回封数量: 1 ⚠️

---

## 示例数据说明

启动脚本会自动导入以下示例数据：

### 📁 板块数据

- **行业板块**: 半导体、新能源汽车、医药生物、军工
- **概念板块**: ChatGPT、数字经济、储能、华为概念
- **地域板块**: 深圳本地、上海本地、北京本地

### 📈 涨停数据（当日）

- **8只涨停股票**
  - 3连板: 中芯国际
  - 4连板: 宁德时代
  - 5连板: 中航沈飞
  - 2连板: 科大讯飞、韦尔股份
  - 首板: 北方华创、寒武纪、海康威视

### 💥 炸板数据

- **炸板回封**: 韦尔股份、寒武纪
- **炸板未回封**: 比亚迪

### 🔥 一字板

- 中芯国际、宁德时代、中航沈飞

---

## 常见问题

### Q1: 端口8080被占用怎么办？

修改 `.env` 文件中的端口：

```bash
WEBUI_PORT=8888  # 改为其他端口
```

然后重启服务：

```bash
docker-compose restart webui
```

访问: `http://localhost:8888`

---

### Q2: 如何查看实时日志？

```bash
# 查看Web UI日志
docker-compose logs -f webui

# 查看所有服务日志
docker-compose logs -f
```

---

### Q3: 如何停止服务？

```bash
# 停止Web UI
docker-compose stop webui

# 停止所有服务
docker-compose stop

# 完全停止并删除容器
docker-compose down
```

---

### Q4: 如何重置数据？

```bash
# 重新导入示例数据
docker-compose exec -T postgres psql -U funcat_user -d funcat < deployment/sql/init_sample_data.sql

# 或使用SQL清空数据
docker-compose exec postgres psql -U funcat_user -d funcat -c "TRUNCATE daily_limit_stats, sector_daily_stats, consecutive_limits CASCADE;"
```

---

### Q5: 如何导入真实数据？

参考 [WEB_UI_GUIDE.md](WEB_UI_GUIDE.md) 的 API 接口文档，通过 API 导入数据：

```python
# Python示例
import requests

data = {
    "trade_date": "2024-12-19",
    "stock_code": "000001.XSHE",
    "stock_name": "平安银行",
    "limit_type": "limit_up",
    "consecutive_limit_days": 2,
    # ... 其他字段
}

response = requests.post('http://localhost:8080/api/v1/limit-stats', json=data)
```

---

## 性能说明

### 资源占用

- **CPU**: ~0.5核（空闲时）
- **内存**: ~512MB
- **磁盘**: ~100MB（不含数据库数据）

### 支持规模

- **板块数量**: 不限
- **个股数量**: 建议 < 5000只/天
- **历史数据**: 建议保留1年以内

---

## 下一步

### 1. 深入了解

- 阅读 [WEB_UI_GUIDE.md](WEB_UI_GUIDE.md) 详细使用指南
- 查看 [API 接口文档](WEB_UI_GUIDE.md#api-接口文档)

### 2. 集成真实数据

- 对接 Tushare Pro 获取实时行情
- 接入自己的数据源
- 编写数据导入脚本

### 3. 定制开发

- 修改前端界面样式
- 添加新的统计指标
- 集成告警通知功能

---

## 技术支持

遇到问题？

1. 📖 查看 [WEB_UI_GUIDE.md](WEB_UI_GUIDE.md) 故障排查章节
2. 🐛 提交 [GitHub Issue](https://github.com/linqiluo8-design/thsfuncat/issues)
3. 💬 参与 [GitHub Discussions](https://github.com/linqiluo8-design/thsfuncat/discussions)

---

**开始你的量化分析之旅吧！** 📊🚀
