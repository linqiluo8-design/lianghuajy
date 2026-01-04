# 看板数据显示修复指南

## 问题现象

根据您提供的截图和日志，问题表现为：

1. **AKShare服务运行正常** ✅
   - Docker日志显示："AkShare 数据源初始化成功"
   - 每2秒获取一次实时行情数据

2. **看板全部显示0** ❌
   - 涨停家数: 0
   - 一字涨停: 0
   - 跌停家数: 0
   - 一字跌停: 0
   - 炸板总数: 0
   - 交易股票: 0

## 问题根源

经过代码分析，发现数据流存在断裂：

### 完整数据流

```
AkShare API
    ↓
realtime_fetcher.py (获取实时行情)
    ↓
daily_limit_stats 表 (个股涨跌停数据) ✅ 有数据
    ↓
❌ 缺失：数据聚合步骤
    ↓
sector_daily_stats 表 (板块统计数据) ❌ 空表
    ↓
Web UI API (读取板块统计)
    ↓
前端看板 (显示统计数据) ❌ 全是0
```

### 问题原因

**`realtime_fetcher.py` 只将个股数据写入 `daily_limit_stats` 表，但 Web UI 从 `sector_daily_stats` 表读取数据。缺少将个股数据聚合成板块统计的中间步骤。**

相关代码位置：
- `services/realtime_fetcher.py:225-256` - 写入 daily_limit_stats
- `web-ui/backend/main.go:294-339` - 读取 sector_daily_stats

## 解决方案

### 方案1：一键修复脚本（推荐）

运行修复脚本：

```bash
./scripts/fix-dashboard-data.sh
```

此脚本会：
1. 聚合今天的涨跌停数据到板块统计表
2. 重启 realtime 服务（使用更新后的代码）
3. 验证数据是否正确

### 方案2：手动修复

#### 步骤1：聚合历史数据

```bash
# 进入容器执行聚合脚本
docker exec funcat-realtime python3 /app/services/sector_aggregator.py

# 或者在宿主机执行
python3 services/sector_aggregator.py
```

#### 步骤2：重启 realtime 服务

```bash
docker-compose down realtime
docker-compose up -d --build realtime
```

#### 步骤3：验证数据

```bash
# 查看板块统计表
docker exec funcat-postgres psql -U funcat_user -d funcat -c "
    SELECT * FROM sector_daily_stats
    WHERE trade_date = CURRENT_DATE;
"

# 查看realtime服务日志
docker logs -f funcat-realtime
```

## 修复内容

### 1. 新增文件：`services/sector_aggregator.py`

**功能**：
- 从 `daily_limit_stats` 表聚合个股数据
- 生成板块级别的统计（涨停数、跌停数、一字板等）
- 写入 `sector_daily_stats` 表

**使用**：
```bash
# 聚合今天的数据
python3 services/sector_aggregator.py

# 聚合指定日期的数据
python3 services/sector_aggregator.py --date 2026-01-04
```

### 2. 修改文件：`services/realtime_fetcher.py`

**修改内容**：
- 导入 `SectorAggregator` 类
- 在每次保存数据后自动调用聚合器
- 实时更新板块统计

**修改位置**：
- 第25行：导入聚合器
- 第62-63行：初始化聚合器
- 第168-169行：每次采集后自动聚合

### 3. 新增脚本：`scripts/fix-dashboard-data.sh`

**功能**：
- 一键修复看板数据显示问题
- 聚合历史数据
- 重启服务并验证

## 验证修复

### 1. 检查服务日志

```bash
docker logs -f funcat-realtime
```

期望看到：
```
[INFO] AkShare 数据源初始化成功
[INFO] 📊 第 1 次采集: 总数=5792, 涨跌停=91, 保存=91
[INFO] ✅ 聚合完成！涨停=91, 跌停=45, 一字涨停=12, 一字跌停=6
```

### 2. 检查数据库

```bash
# 检查个股数据
docker exec funcat-postgres psql -U funcat_user -d funcat -c "
    SELECT COUNT(*) FROM daily_limit_stats WHERE trade_date = CURRENT_DATE;
"

# 检查板块统计
docker exec funcat-postgres psql -U funcat_user -d funcat -c "
    SELECT * FROM sector_daily_stats WHERE trade_date = CURRENT_DATE;
"
```

### 3. 检查Web UI

访问 http://localhost:8080，应该看到：
- ✅ 涨停家数显示实际数字（如：91）
- ✅ 跌停家数显示实际数字（如：45）
- ✅ 一字涨停显示实际数字（如：12）
- ✅ 板块涨停排行有数据

## 常见问题

### Q1: 运行修复脚本后，看板仍然显示0？

**A**: 请等待下一次数据采集（2秒），或者：
1. 检查服务是否正常运行：`docker ps | grep funcat`
2. 查看实时日志：`docker logs -f funcat-realtime`
3. 手动刷新浏览器（Ctrl+F5）

### Q2: sector_aggregator.py 报错"数据库连接失败"？

**A**: 检查数据库环境变量：
```bash
docker exec funcat-realtime env | grep DB_
```

应该看到：
```
DB_HOST=postgres
DB_PORT=5432
DB_NAME=funcat
DB_USER=funcat_user
DB_PASSWORD=funcat_password_change_me
```

### Q3: 如何查看历史数据？

**A**: 聚合历史某一天的数据：
```bash
python3 services/sector_aggregator.py --date 2026-01-03
```

### Q4: 为什么只有"全市场"板块，没有其他板块？

**A**: 当前版本使用默认的"全市场"板块聚合所有涨跌停数据。如需按行业/概念板块分类，需要：
1. 在 `stock_sector_mapping` 表中添加股票-板块映射
2. 修改 `sector_aggregator.py` 以支持多板块聚合

## 技术细节

### 数据库表结构

**daily_limit_stats** (个股数据)
- trade_date: 交易日期
- stock_code: 股票代码
- stock_name: 股票名称
- limit_type: 涨停/跌停类型
- is_one_word: 是否一字板
- ... (其他字段)

**sector_daily_stats** (板块统计)
- trade_date: 交易日期
- sector_id: 板块ID
- sector_name: 板块名称
- limit_up_count: 涨停家数
- limit_down_count: 跌停家数
- one_word_count: 一字涨停数
- one_word_limit_down_count: 一字跌停数
- ... (其他统计字段)

### 聚合逻辑

```sql
-- 简化版聚合查询
INSERT INTO sector_daily_stats (...)
SELECT
    trade_date,
    sector_id,
    SUM(CASE WHEN limit_type = 'limit_up' THEN 1 ELSE 0 END) AS limit_up_count,
    SUM(CASE WHEN limit_type = 'limit_down' THEN 1 ELSE 0 END) AS limit_down_count,
    SUM(CASE WHEN limit_type = 'limit_up' AND is_one_word = TRUE THEN 1 ELSE 0 END) AS one_word_count,
    ...
FROM daily_limit_stats
WHERE trade_date = '2026-01-04'
GROUP BY trade_date, sector_id
```

## 后续优化建议

1. **增加更多板块**
   - 导入行业板块数据
   - 导入概念板块数据
   - 建立股票-板块映射关系

2. **优化聚合性能**
   - 使用数据库触发器自动聚合
   - 使用物化视图加速查询
   - 添加增量聚合逻辑

3. **增强监控**
   - 添加聚合失败告警
   - 统计聚合耗时
   - 记录聚合历史

## 支持

如果问题仍未解决，请提供：
1. `docker-compose ps` 输出
2. `docker logs funcat-realtime --tail 200` 输出
3. 数据库查询结果（上述验证部分的SQL）

这将帮助进一步诊断问题。
