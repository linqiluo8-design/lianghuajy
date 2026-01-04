# 板块细分显示功能 - 使用指南

## 功能说明

将看板从只显示"全市场"改为显示A股细分板块（如商业航天、人形机器人、新能源、半导体等），实时统计各板块内的涨停个数并按涨停数量排名。

## 实现效果

**修复前**：
```
板块涨停排行
┌─────────────────┐
│ 全市场  涨停:78 │  ← 只有一个笼统的"全市场"
└─────────────────┘
```

**修复后**：
```
板块涨停排行（按涨停数降序）
┌────────────────────────┐
│ 商业航天      涨停:12  │
│ 人形机器人    涨停:9   │
│ 新能源汽车    涨停:8   │
│ 半导体        涨停:7   │
│ 人工智能      涨停:6   │
│ ...                    │
└────────────────────────┘
```

## 使用步骤

### 第1步：导入板块数据

在服务器上执行板块数据导入脚本：

```bash
cd /home/lys/lianghuajy

# 方法1：在容器内导入（推荐）
docker exec -it funcat-realtime python3 /app/scripts/import_sector_data.py --sectors 20

# 方法2：在宿主机导入（需要配置环境变量）
python3 scripts/import_sector_data.py --sectors 20
```

**参数说明**：
- `--sectors 20`: 导入前20个板块的股票映射（默认值，避免太慢）
- `--sectors 50`: 导入前50个板块（更多板块，但需要更长时间）
- `--skip-mapping`: 只导入板块列表，跳过股票映射（快速测试）

**预期输出**：
```
========================================
  板块数据导入工具
========================================

[INFO] ✅ 数据库连接成功
[INFO] 📊 获取板块分类数据...
[INFO] 获取行业板块...
[INFO]   获取到 90 个行业板块
[INFO] 获取概念板块...
[INFO]   获取到 430 个概念板块
[INFO] ✅ 导入 90 个行业板块
[INFO] ✅ 导入 100 个概念板块

========================================
  开始导入股票-板块映射（前20个板块）
  ⚠️  这可能需要几分钟时间...
========================================

[INFO]   处理板块: 新能源汽车 (industry)
[INFO]     ✅ 导入 186 只股票
[INFO]   处理板块: 半导体 (industry)
[INFO]     ✅ 导入 243 只股票
[INFO]   处理板块: 商业航天 (concept)
[INFO]     ✅ 导入 92 只股票
...

[INFO] ✅ 总共导入 3421 条股票-板块映射

========================================
  ✅ 导入完成！
========================================
```

### 第2步：重新聚合数据

导入板块数据后，重新聚合涨跌停数据：

```bash
# 在容器内聚合
docker exec funcat-realtime python3 /app/services/sector_aggregator.py

# 查看聚合日志
docker logs funcat-realtime --tail 30
```

**预期输出**：
```
[INFO] 📊 2026-01-04 涨跌停个股数据: 78 条
[INFO] 📊 检测到 3421 条板块映射，按细分板块聚合
[INFO] ✅ 聚合完成！插入 18 个板块统计
[INFO] 📊 涨停板块Top5:
[INFO]   商业航天: 涨停12, 跌停0
[INFO]   人形机器人: 涨停9, 跌停0
[INFO]   新能源汽车: 涨停8, 跌停1
[INFO]   半导体: 涨停7, 跌停0
[INFO]   人工智能: 涨停6, 跌停0
```

### 第3步：重启realtime服务（应用自动聚合）

```bash
# 重新构建并重启服务（使用最新代码）
cd /home/lys/lianghuajy
docker-compose build realtime
docker-compose up -d realtime

# 查看日志确认自动聚合工作
docker logs -f funcat-realtime
```

**期望看到**（每2秒一次）：
```
[INFO] 📊 第 1 次采集: 总数=5792, 涨跌停=78, 保存=78
[INFO] 📊 检测到 3421 条板块映射，按细分板块聚合
[INFO] ✅ 聚合完成！插入 18 个板块统计
[INFO] 📊 涨停板块Top5:
[INFO]   商业航天: 涨停12, 跌停0
...
```

### 第4步：刷新Web UI查看效果

访问 http://localhost:8080 或 http://192.168.92.129:8080，应该看到：

**板块涨停排行**：
- ✅ 商业航天（涨停12）
- ✅ 人形机器人（涨停9）
- ✅ 新能源汽车（涨停8）
- ✅ ...按涨停数降序排列

## 高级配置

### 导入更多板块

如果想导入更多板块（如50个）：

```bash
docker exec funcat-realtime python3 /app/scripts/import_sector_data.py --sectors 50
```

**注意**：
- 板块越多，导入时间越长（每个板块需要获取成分股）
- 建议首次使用20个板块测试，满意后再扩展到50个

### 只导入板块列表（不导入映射）

快速测试，只导入板块名称：

```bash
docker exec funcat-realtime python3 /app/scripts/import_sector_data.py --skip-mapping
```

然后手动选择几个重点板块导入映射。

### 查看已导入的板块

```bash
# 查看所有板块
docker exec funcat-postgres psql -U funcat_user -d funcat -c "
    SELECT sector_code, sector_name, sector_type, stock_count
    FROM sectors
    WHERE sector_code != 'ALL_MARKET'
    ORDER BY stock_count DESC
    LIMIT 20;
"

# 查看某板块的成分股
docker exec funcat-postgres psql -U funcat_user -d funcat -c "
    SELECT s.sector_name, COUNT(*) as stock_count
    FROM stock_sector_mapping ssm
    JOIN sectors s ON ssm.sector_id = s.id
    WHERE s.sector_name = '商业航天'
    GROUP BY s.sector_name;
"
```

## 聚合器工作原理

修改后的 `sector_aggregator.py` 有两种聚合模式：

### 模式1：全市场聚合（无板块映射时）
```
daily_limit_stats (78条涨跌停)
        ↓
  聚合到"全市场"
        ↓
sector_daily_stats (1条: 全市场78个涨停)
```

### 模式2：细分板块聚合（有板块映射时）
```
daily_limit_stats (78条涨跌停)
        ↓
    JOIN stock_sector_mapping (股票→板块映射)
        ↓
    GROUP BY 板块
        ↓
sector_daily_stats (18条: 商业航天12个,人形机器人9个...)
```

聚合器会**自动检测**是否有板块映射数据，选择对应的聚合模式。

## 常见问题

### Q1: 导入板块数据很慢？

**A**: 正常现象。导入20个板块大约需要2-5分钟，因为需要：
1. 获取每个板块的成分股列表（调用AkShare API）
2. 写入数据库建立映射关系

**优化建议**：
- 首次使用 `--sectors 10` 快速测试
- 满意后再使用 `--sectors 50` 完整导入

### Q2: 看板仍然只显示"全市场"？

**检查步骤**：
1. 确认板块数据已导入：
   ```bash
   docker exec funcat-postgres psql -U funcat_user -d funcat -c "SELECT COUNT(*) FROM stock_sector_mapping;"
   ```

2. 确认聚合成功：
   ```bash
   docker exec funcat-postgres psql -U funcat_user -d funcat -c "
       SELECT COUNT(*), array_agg(DISTINCT sector_name)
       FROM sector_daily_stats
       WHERE trade_date = CURRENT_DATE;
   "
   ```

3. 重新聚合：
   ```bash
   docker exec funcat-realtime python3 /app/services/sector_aggregator.py
   ```

### Q3: 某些板块没有涨停数据？

**原因**: 该板块的成分股今天没有涨跌停。

**验证**：
```bash
# 查看该板块的成分股今天是否有涨跌停
docker exec funcat-postgres psql -U funcat_user -d funcat -c "
    SELECT dls.stock_name, dls.change_pct, dls.limit_type
    FROM daily_limit_stats dls
    JOIN stock_sector_mapping ssm ON dls.stock_code = ssm.stock_code
    JOIN sectors s ON ssm.sector_id = s.id
    WHERE s.sector_name = '商业航天'
      AND dls.trade_date = CURRENT_DATE;
"
```

### Q4: 如何重新导入板块数据？

```bash
# 清空旧数据并重新导入
docker exec funcat-realtime python3 /app/scripts/import_sector_data.py --sectors 20

# 重新聚合
docker exec funcat-realtime python3 /app/services/sector_aggregator.py

# 重启服务
docker-compose restart realtime
```

### Q5: 一只股票属于多个板块怎么办？

**A**: 这是正常的！一只股票可以同时属于多个板块。例如：
- 某只股票可能同时属于"新能源汽车"（行业）和"人工智能"（概念）
- 聚合时会统计到两个板块中

数据库设计支持多对多关系：
```
stock_sector_mapping 表
┌─────────┬───────────┐
│ 600XXX  │ 新能源ID  │
│ 600XXX  │ AI ID     │  ← 同一股票映射到多个板块
└─────────┴───────────┘
```

## 性能优化建议

### 1. 选择性导入板块

根据关注重点，只导入部分板块：

```python
# 修改 import_sector_data.py，自定义板块列表
FOCUS_SECTORS = [
    '商业航天', '人形机器人', '新能源汽车',
    '半导体', '人工智能', '军工', '医药'
]
```

### 2. 定期更新板块数据

板块成分股可能变化，建议每周更新一次：

```bash
# 添加到crontab
0 2 * * 0 docker exec funcat-realtime python3 /app/scripts/import_sector_data.py --sectors 20
```

### 3. 索引优化

数据库已创建必要索引：
```sql
-- 已有的索引
CREATE INDEX idx_stock_sector_code ON stock_sector_mapping(stock_code);
CREATE INDEX idx_stock_sector_id ON stock_sector_mapping(sector_id);
CREATE INDEX idx_daily_limit_code ON daily_limit_stats(stock_code);
```

## 故障排查

### 导入脚本报错

```bash
# 查看完整错误信息
docker exec funcat-realtime python3 /app/scripts/import_sector_data.py --sectors 5 2>&1 | tee import.log

# 检查AkShare是否可用
docker exec funcat-realtime python3 -c "import akshare as ak; print(ak.__version__)"
```

### 聚合器报错

```bash
# 查看详细日志
docker exec funcat-realtime python3 /app/services/sector_aggregator.py

# 检查数据库连接
docker exec funcat-realtime python3 -c "
import psycopg2
import os
conn = psycopg2.connect(
    host=os.getenv('DB_HOST', 'localhost'),
    port=5432,
    database='funcat',
    user='funcat_user',
    password=os.getenv('DB_PASSWORD')
)
print('数据库连接成功')
"
```

## 下一步

完成板块细分显示后，您可以：

1. **添加板块强度排行**（已有功能）
   - 基于涨停数、连板数、成交额等计算板块强度分数

2. **点击板块查看成分股**
   - 查看某板块内哪些股票涨停了

3. **板块轮动分析**
   - 分析不同板块的涨停数变化趋势

4. **自定义板块**
   - 创建自己关注的板块组合

详见 `WEB_UI_GUIDE.md` 和 `SECTOR_STRENGTH_GUIDE.md`。
