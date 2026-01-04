# 实时数据采集配置指南

## ⚡ 极致实时性原则

**数据越实时，对交易分析越有利。** 本系统支持最快 **1 秒** 采集一次数据。

---

## 🚀 推荐配置

### 方案 1: 极速模式（推荐交易时段）

```bash
# .env 文件
REALTIME_REFRESH_INTERVAL=1
```

**特点**:
- ✅ 数据延迟 < 2 秒
- ✅ 最适合盘中交易分析
- ✅ 捕捉最快的涨停板机会
- ⚠️  AkShare API 调用频率较高

**适用场景**:
- 短线交易
- 打板策略
- 盘中监控

---

### 方案 2: 标准模式（默认）

```bash
# .env 文件
REALTIME_REFRESH_INTERVAL=2
```

**特点**:
- ✅ 数据延迟 < 3 秒
- ✅ 平衡性能与实时性
- ✅ API 调用频率适中

**适用场景**:
- 日常监控
- 中短线交易
- 板块分析

---

### 方案 3: 节能模式

```bash
# .env 文件
REALTIME_REFRESH_INTERVAL=5
```

**特点**:
- ✅ 降低服务器负载
- ✅ 减少 API 调用
- ⚠️  数据延迟 ~6 秒

**适用场景**:
- 盘后复盘
- 趋势分析
- 资源受限环境

---

## 📊 性能对比

| 配置 | 采集间隔 | 数据延迟 | API 调用/小时 | 适用场景 |
|------|---------|---------|--------------|---------|
| **极速模式** | 1 秒 | < 2 秒 | ~3,600 | 短线交易 |
| **标准模式** | 2 秒 | < 3 秒 | ~1,800 | 日常监控 |
| **节能模式** | 5 秒 | ~6 秒 | ~720 | 盘后分析 |
| 保守模式 | 10 秒 | ~12 秒 | ~360 | 低频监控 |

---

## 🔧 配置方法

### 方法 1: 环境变量（推荐）

创建或编辑 `.env` 文件：

```bash
cd /path/to/lianghuajy

# 编辑 .env 文件
cat >> .env << 'EOF'
# 实时数据采集间隔（秒）
REALTIME_REFRESH_INTERVAL=1
EOF

# 重启服务
docker compose restart realtime
```

---

### 方法 2: docker-compose.yml

直接修改 `docker-compose.yml`：

```yaml
services:
  realtime:
    environment:
      REALTIME_REFRESH_INTERVAL: 1  # 设置为 1 秒
```

然后重启：
```bash
docker compose up -d realtime
```

---

### 方法 3: Docker 命令行

```bash
docker compose stop realtime

docker compose run -d \
  --name funcat-realtime \
  -e REALTIME_REFRESH_INTERVAL=1 \
  realtime
```

---

## 🎯 交易时段动态调整（高级）

根据交易时段自动调整采集频率：

```bash
#!/bin/bash
# scripts/dynamic-interval.sh

HOUR=$(date +%H)
MINUTE=$(date +%M)

# 9:25-9:35 集合竞价 + 开盘（极速模式）
if [ $HOUR -eq 9 ] && [ $MINUTE -ge 25 ] && [ $MINUTE -le 35 ]; then
    INTERVAL=1

# 9:35-11:30 + 13:00-15:00 交易时段（标准模式）
elif ([ $HOUR -eq 9 ] && [ $MINUTE -ge 35 ]) || \
     ([ $HOUR -eq 10 ] || [ $HOUR -eq 11 ] && [ $MINUTE -lt 30 ]) || \
     ([ $HOUR -eq 13 ]) || \
     ([ $HOUR -eq 14 ]); then
    INTERVAL=2

# 盘后时段（节能模式）
else
    INTERVAL=10
fi

# 更新配置
docker compose stop realtime
docker compose run -d \
  -e REALTIME_REFRESH_INTERVAL=$INTERVAL \
  realtime

echo "✅ 当前时段: $(date '+%H:%M'), 采集间隔: ${INTERVAL}秒"
```

**使用 cron 每 5 分钟调整一次：**
```bash
# crontab -e
*/5 * * * * /path/to/scripts/dynamic-interval.sh >> /var/log/realtime-interval.log 2>&1
```

---

## 📈 实时性验证

检查数据新鲜度：

```bash
# 查看最新采集时间
docker compose exec postgres psql -U funcat_user -d funcat -c "
SELECT
    MAX(created_at) AS last_update,
    NOW() - MAX(created_at) AS delay,
    COUNT(*) AS total_records
FROM daily_limit_stats
WHERE trade_date = CURRENT_DATE;
"
```

**预期输出**:
```
     last_update         |   delay   | total_records
-------------------------+-----------+---------------
 2025-12-31 14:35:23.456 | 00:00:02  |    1,523
```

如果 `delay` > 10 秒，说明采集服务可能异常。

---

## 🔍 监控与日志

### 实时查看采集日志

```bash
# 查看采集日志
docker compose logs -f realtime

# 筛选关键信息
docker compose logs -f realtime | grep -E "采集成功|聚合完成|涨停|ERROR"
```

**正常日志示例**:
```
[INFO] 🚀 实时行情采集服务启动
[INFO] 数据源: akshare
[INFO] 刷新间隔: 1 秒
[INFO] ✅ 采集成功！共 1,523 只股票
[INFO] 📊 发现 28 个实时板块: 商业航天, 人形机器人, AI概念...
[INFO] ✅ 实时板块聚合完成！插入 28 个板块统计
[INFO] 📊 第 1,234 次采集: 总数=1,523, 涨停=152, 跌停=8
```

---

## ⚠️ 注意事项

### 1. AkShare API 限流

AkShare 可能有请求频率限制：

```python
# services/data_sources/akshare_source.py
import time
import random

def fetch_realtime_data(self, trade_date: str) -> List[Dict]:
    try:
        df = ak.stock_zt_pool_em(date=date_str)
    except Exception as e:
        if "频繁" in str(e) or "限制" in str(e):
            # 遇到限流，随机等待 5-10 秒
            wait_time = random.randint(5, 10)
            logger.warning(f"⚠️  API 限流，等待 {wait_time} 秒...")
            time.sleep(wait_time)
            # 重试
            df = ak.stock_zt_pool_em(date=date_str)
```

### 2. 数据库性能

高频采集可能导致数据库压力：

```sql
-- 优化：创建索引
CREATE INDEX IF NOT EXISTS idx_daily_limit_stats_created_at
ON daily_limit_stats(created_at DESC);

-- 优化：定期清理旧数据（保留 30 天）
DELETE FROM daily_limit_stats
WHERE trade_date < CURRENT_DATE - INTERVAL '30 days';
```

### 3. 磁盘空间

```bash
# 每天数据量估算
# 假设每次采集 1,500 只股票，每条记录 ~500 字节
# 1 秒间隔：1,500 * 500B * 3,600次/小时 * 6.5小时 = ~17GB/天

# 定期清理日志
docker compose exec realtime sh -c "
    find /app/logs -name '*.log' -mtime +7 -delete
"
```

### 4. 休市时段

```python
# services/realtime_fetcher.py
import datetime

def is_trading_time() -> bool:
    """判断是否交易时段"""
    now = datetime.datetime.now()
    hour, minute = now.hour, now.minute
    weekday = now.weekday()

    # 周末休市
    if weekday >= 5:
        return False

    # 交易时段: 9:25-11:30, 13:00-15:05
    if (9 <= hour < 11) or (hour == 11 and minute < 30):
        return True
    if (13 <= hour < 15) or (hour == 15 and minute < 5):
        return True

    return False

def run(self):
    """运行采集服务（智能模式）"""
    while True:
        if is_trading_time():
            refresh_interval = 1  # 交易时段：1 秒
        else:
            refresh_interval = 60  # 休市时段：1 分钟

        self.fetch_and_save()
        time.sleep(refresh_interval)
```

---

## 🎯 最佳实践

### ✅ 推荐做法

1. **交易时段使用 1 秒间隔**
   ```bash
   REALTIME_REFRESH_INTERVAL=1
   ```

2. **启用智能时段调整**
   - 开盘前 5 分钟：1 秒（捕捉集合竞价）
   - 交易时段：1-2 秒
   - 盘后时段：5-10 秒
   - 休市时段：60 秒或停止采集

3. **监控数据新鲜度**
   ```bash
   # 每分钟检查一次
   watch -n 60 "docker compose exec postgres psql -U funcat_user -d funcat \
       -c 'SELECT NOW() - MAX(created_at) FROM daily_limit_stats'"
   ```

4. **定期清理历史数据**
   ```sql
   -- 保留 30 天数据
   DELETE FROM daily_limit_stats WHERE trade_date < CURRENT_DATE - 30;
   ```

### ❌ 避免的做法

1. ❌ 设置过长间隔（> 10 秒）
   - 错失涨停板机会
   - 数据滞后影响决策

2. ❌ 交易时段停止采集
   - 无法实时监控市场

3. ❌ 不检查数据新鲜度
   - 服务异常无法及时发现

4. ❌ 无限累积历史数据
   - 磁盘空间耗尽
   - 查询性能下降

---

## 🚀 快速设置（1 秒极速模式）

```bash
# 一键设置为 1 秒采集
cd /path/to/lianghuajy

# 创建 .env 文件
echo "REALTIME_REFRESH_INTERVAL=1" >> .env

# 重启服务
docker compose restart realtime

# 验证配置
docker compose logs realtime | grep "刷新间隔"
# 输出应该显示: 刷新间隔: 1 秒

# 监控实时采集
docker compose logs -f realtime | grep "采集成功"
```

**预期效果**:
- ✅ 每 1 秒采集一次涨跌停数据
- ✅ 每次采集后立即聚合板块统计
- ✅ 看板数据延迟 < 2 秒

---

## 📞 故障排查

### 问题 1: 数据不更新

```bash
# 检查服务状态
docker compose ps realtime

# 查看错误日志
docker compose logs realtime --tail=100 | grep ERROR

# 重启服务
docker compose restart realtime
```

### 问题 2: 采集频率不正确

```bash
# 检查环境变量
docker compose exec realtime env | grep REFRESH_INTERVAL

# 检查配置加载
docker compose logs realtime | grep "刷新间隔"
```

### 问题 3: API 频繁报错

```bash
# 查看 AkShare 错误
docker compose logs realtime | grep "AkShare.*失败"

# 临时增加间隔
docker compose stop realtime
docker compose run -d -e REALTIME_REFRESH_INTERVAL=5 realtime
```

---

**最后更新**: 2025-12-31
**维护者**: Claude AI Assistant
