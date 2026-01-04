# 看板数据显示问题 - 快速修复步骤

## 问题现象

1. ❌ 看板显示全是0
2. ❌ 数据日期未更新到最新
3. ❌ 旧版修复脚本失败（容器内找不到新文件）

## 快速修复（推荐）

### 方法1：使用改进版脚本

```bash
./scripts/fix-dashboard-data-v2.sh
```

### 方法2：手动执行（3步）

#### 第1步：重新构建realtime容器

```bash
cd /home/lys/lianghuajy

# 重新构建（包含新代码 sector_aggregator.py）
docker-compose build realtime

# 重启服务
docker-compose up -d realtime

# 等待启动
sleep 5

# 查看日志确认启动成功
docker logs funcat-realtime --tail 20
```

#### 第2步：聚合今天的数据

```bash
# 在容器内运行聚合脚本（正确的数据库连接）
docker exec funcat-realtime python3 /app/services/sector_aggregator.py
```

期望输出：
```
[INFO] ✅ 数据库连接成功
[INFO] 📊 2026-01-04 涨跌停个股数据: 91 条
[INFO] ✅ 聚合完成！涨停=91, 跌停=45, 一字涨停=12, 一字跌停=6
```

#### 第3步：验证数据

```bash
# 查看板块统计表
docker exec funcat-postgres psql -U funcat_user -d funcat -c "
    SELECT trade_date, sector_name,
           limit_up_count AS 涨停,
           limit_down_count AS 跌停,
           one_word_count AS 一字涨停
    FROM sector_daily_stats
    WHERE trade_date = CURRENT_DATE;
"

# 查看realtime服务日志（确认自动聚合工作）
docker logs funcat-realtime --tail 30
```

期望看到日志：
```
[INFO] 📊 第 1 次采集: 总数=5792, 涨跌停=91, 保存=91
[INFO] 📊 2026-01-04 涨跌停个股数据: 91 条
[INFO] ✅ 聚合完成！涨停=91, 跌停=45, 一字涨停=12, 一字跌停=6
```

## 数据日期问题

如果数据日期没有更新到最新（如卡在12月31日）：

### 诊断步骤

```bash
# 1. 查看数据库中的日期
docker exec funcat-postgres psql -U funcat_user -d funcat -c "
    SELECT DISTINCT trade_date
    FROM daily_limit_stats
    ORDER BY trade_date DESC
    LIMIT 5;
"

# 2. 查看容器时区
docker exec funcat-realtime date

# 3. 查看容器内环境变量
docker exec funcat-realtime env | grep TZ
```

### 解决方案

#### 方案A：清空旧数据重新采集

```bash
# 清空今天的旧数据
docker exec funcat-postgres psql -U funcat_user -d funcat -c "
    DELETE FROM daily_limit_stats WHERE trade_date = CURRENT_DATE;
    DELETE FROM sector_daily_stats WHERE trade_date = CURRENT_DATE;
"

# 重启realtime服务重新采集
docker-compose restart realtime

# 等待2秒后查看日志
sleep 2
docker logs funcat-realtime --tail 20
```

#### 方案B：手动聚合指定日期

```bash
# 聚合2026-01-04的数据
docker exec funcat-realtime python3 /app/services/sector_aggregator.py --date 2026-01-04

# 或聚合今天
docker exec funcat-realtime python3 /app/services/sector_aggregator.py
```

## 常见问题排查

### Q1: "python3: can't open file '/app/services/sector_aggregator.py'"

**原因**: 容器使用旧代码，没有新文件

**解决**:
```bash
docker-compose build realtime
docker-compose up -d realtime
```

### Q2: "password authentication failed for user 'funcat_user'"

**原因**: 在宿主机运行，数据库连接配置错误

**解决**: 在容器内运行
```bash
docker exec funcat-realtime python3 /app/services/sector_aggregator.py
```

### Q3: 看板仍然显示0

**检查清单**:
1. ✅ realtime服务是否运行？ `docker ps | grep funcat-realtime`
2. ✅ 有涨跌停数据吗？ `docker exec funcat-postgres psql -U funcat_user -d funcat -c "SELECT COUNT(*) FROM daily_limit_stats WHERE trade_date = CURRENT_DATE;"`
3. ✅ 有板块统计吗？ `docker exec funcat-postgres psql -U funcat_user -d funcat -c "SELECT * FROM sector_daily_stats WHERE trade_date = CURRENT_DATE;"`
4. ✅ Web UI端口正确吗？ 访问 http://localhost:8080 或 http://192.168.92.129:8080

### Q4: 数据日期不对

**诊断**:
```bash
# 检查系统时间
date

# 检查容器时间
docker exec funcat-realtime date

# 检查PostgreSQL时间
docker exec funcat-postgres psql -U funcat_user -d funcat -c "SELECT NOW();"
```

**修复时区**: 在 docker-compose.yml 中确认：
```yaml
realtime:
  environment:
    TZ: Asia/Shanghai
```

## 验证修复成功

### 1. 服务状态

```bash
docker ps | grep funcat
```

期望看到：
- funcat-postgres (healthy)
- funcat-redis (healthy)
- funcat-webui (healthy)
- funcat-realtime (running)

### 2. 实时日志

```bash
docker logs -f funcat-realtime
```

期望看到（每2秒一次）：
```
[INFO] 📊 第 N 次采集: 总数=5792, 涨跌停=91, 保存=91
[INFO] ✅ 聚合完成！涨停=91, 跌停=45, 一字涨停=12, 一字跌停=6
```

### 3. Web UI

访问 http://localhost:8080 或 http://192.168.92.129:8080

期望看到：
- ✅ 涨停家数：实际数字（如91）
- ✅ 跌停家数：实际数字（如45）
- ✅ 一字涨停：实际数字（如12）
- ✅ 数据日期：今天（2026-01-04）

## 获取帮助

如果问题仍未解决，请提供：

```bash
# 1. 服务状态
docker-compose ps

# 2. realtime日志
docker logs funcat-realtime --tail 100 > realtime.log

# 3. 数据库数据
docker exec funcat-postgres psql -U funcat_user -d funcat -c "
    SELECT trade_date, COUNT(*) as count
    FROM daily_limit_stats
    GROUP BY trade_date
    ORDER BY trade_date DESC
    LIMIT 10;
" > db_data.log

# 4. 系统信息
docker version
docker-compose version
date
```

然后分享这些日志文件。
