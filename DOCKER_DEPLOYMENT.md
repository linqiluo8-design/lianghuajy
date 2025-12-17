# Funcat Docker 部署完整指南

## 📋 目录

- [系统要求](#系统要求)
- [快速开始](#快速开始)
- [详细部署步骤](#详细部署步骤)
- [配置说明](#配置说明)
- [服务管理](#服务管理)
- [数据备份与恢复](#数据备份与恢复)
- [监控和日志](#监控和日志)
- [故障排查](#故障排查)
- [性能优化](#性能优化)

---

## 系统要求

### 硬件要求

| 配置级别 | CPU | 内存 | 磁盘 | 适用场景 |
|---------|-----|------|------|---------|
| **最小配置** | 2核 | 4GB | 20GB SSD | 测试和开发 |
| **推荐配置** | 4核 | 8GB | 50GB SSD | 小规模生产 |
| **高性能配置** | 8核+ | 16GB+ | 100GB+ SSD | 大规模生产 |

### 软件要求

- **操作系统**: Linux (Ubuntu 20.04+, CentOS 8+), macOS, Windows 10+
- **Docker**: 20.10+
- **Docker Compose**: 2.0+
- **网络**: 访问Docker Hub和数据源API

---

## 快速开始

### 10分钟快速部署

```bash
# 1. 克隆项目
git clone https://github.com/linqiluo8-design/thsfuncat.git
cd thsfuncat

# 2. 配置环境变量
cp .env.example .env
vim .env  # 填入你的Tushare Token等配置

# 3. 一键启动
docker-compose up -d

# 4. 查看状态
docker-compose ps

# 5. 查看日志
docker-compose logs -f selector
```

**就这么简单！** 🎉

---

## 详细部署步骤

### 步骤1: 安装Docker和Docker Compose

#### Ubuntu/Debian

```bash
# 安装Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 安装Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 将当前用户添加到docker组
sudo usermod -aG docker $USER
newgrp docker

# 验证安装
docker --version
docker-compose --version
```

#### macOS

```bash
# 使用Homebrew安装
brew install --cask docker

# 或下载Docker Desktop
# https://www.docker.com/products/docker-desktop
```

#### Windows

```powershell
# 下载并安装Docker Desktop
# https://www.docker.com/products/docker-desktop

# 启用WSL2 (推荐)
wsl --install
```

---

### 步骤2: 克隆项目

```bash
# 克隆项目
git clone https://github.com/linqiluo8-design/thsfuncat.git
cd thsfuncat

# 查看项目结构
tree -L 2
```

---

### 步骤3: 配置环境变量

```bash
# 复制环境变量模板
cp .env.example .env

# 编辑配置文件
vim .env  # 或使用你喜欢的编辑器
```

**关键配置项**:

```bash
# 必填项
TUSHARE_TOKEN=your_tushare_token_here  # ← 必须填写!

# 数据库密码 (建议修改)
POSTGRES_PASSWORD=your_secure_password
REDIS_PASSWORD=your_redis_password

# 可选项
LOG_LEVEL=info
SELECTOR_WORKERS=100
```

**获取Tushare Token**:
1. 访问 https://tushare.pro/register
2. 注册账号
3. 在个人中心获取Token
4. 填入 `.env` 文件

---

### 步骤4: 构建和启动服务

#### 方式1: 基础服务 (推荐开始)

仅启动必要服务: PostgreSQL, Redis, 选股服务

```bash
# 启动基础服务
docker-compose up -d

# 查看启动状态
docker-compose ps

# 输出示例:
# NAME                   STATUS              PORTS
# funcat-postgres        Up (healthy)        5432
# funcat-redis           Up (healthy)        6379
# funcat-selector        Up                  -
```

#### 方式2: 完整服务 (包含API、Nginx)

```bash
# 启动完整服务
docker-compose --profile full up -d

# 包含的服务:
# - PostgreSQL
# - Redis
# - InfluxDB
# - 选股服务
# - API服务
# - Nginx反向代理
```

#### 方式3: 带监控的完整服务

```bash
# 启动所有服务 + 监控
docker-compose --profile full --profile monitoring up -d

# 包含的服务:
# - 上述所有服务
# - Prometheus (监控)
# - Grafana (可视化)
```

---

### 步骤5: 验证部署

#### 检查容器状态

```bash
# 查看所有容器
docker-compose ps

# 查看资源使用
docker stats

# 输出示例:
# CONTAINER           CPU %   MEM USAGE / LIMIT     MEM %
# funcat-postgres     0.5%    200MiB / 8GiB         2.5%
# funcat-redis        0.2%    50MiB / 2GiB          2.5%
# funcat-selector     5.0%    500MiB / 2GiB         25%
```

#### 检查服务健康

```bash
# PostgreSQL健康检查
docker-compose exec postgres pg_isready -U funcat_user

# Redis健康检查
docker-compose exec redis redis-cli ping

# 查看选股服务日志
docker-compose logs selector
```

#### 测试数据库连接

```bash
# 连接PostgreSQL
docker-compose exec postgres psql -U funcat_user -d funcat

# 执行测试查询
SELECT * FROM strategy_configs;

# 退出
\q
```

#### 测试Redis连接

```bash
# 连接Redis
docker-compose exec redis redis-cli

# 测试命令
127.0.0.1:6379> ping
PONG

127.0.0.1:6379> set test_key "hello"
OK

127.0.0.1:6379> get test_key
"hello"

127.0.0.1:6379> exit
```

---

### 步骤6: 初始化数据 (可选)

数据库表结构会在首次启动时自动创建，也可以手动执行：

```bash
# 查看现有表
docker-compose exec postgres psql -U funcat_user -d funcat -c "\dt"

# 手动执行初始化脚本
docker-compose exec postgres psql -U funcat_user -d funcat -f /docker-entrypoint-initdb.d/01-schema.sql
```

---

## 配置说明

### 环境变量详解

#### 数据库配置

```bash
# PostgreSQL
POSTGRES_PASSWORD=your_password          # 数据库密码
POSTGRES_PORT=5432                      # 端口 (默认5432)

# Redis
REDIS_PASSWORD=your_redis_password      # Redis密码
REDIS_PORT=6379                         # 端口 (默认6379)
REDIS_MAX_MEMORY=2gb                    # 最大内存
```

#### 数据源配置

```bash
# Tushare (必填)
TUSHARE_TOKEN=your_token_here

# RQData (可选)
RQDATA_USERNAME=your_username
RQDATA_PASSWORD=your_password
```

#### 性能配置

```bash
# 选股服务并发数
SELECTOR_WORKERS=100                    # 默认100

# 数据库连接池
DB_POOL_SIZE=20                         # 默认20

# 日志级别
LOG_LEVEL=info                          # debug, info, warn, error
```

---

### 配置文件结构

```
thsfuncat/
├── docker-compose.yml              # Docker Compose主配置
├── .env                           # 环境变量 (从.env.example复制)
│
├── funcat-go/
│   └── Dockerfile                 # Go服务Dockerfile
│
├── deployment/
│   ├── config/                    # 配置文件目录
│   │   ├── postgresql.conf       # PostgreSQL配置
│   │   ├── selector.yaml         # 选股服务配置
│   │   ├── prometheus.yml        # Prometheus配置
│   │   └── nginx.conf            # Nginx配置
│   │
│   └── sql/                       # SQL脚本
│       ├── schema.sql            # 表结构
│       └── init_data.sql         # 初始数据
```

---

## 服务管理

### 启动服务

```bash
# 启动所有服务
docker-compose up -d

# 启动特定服务
docker-compose up -d postgres redis

# 重新构建并启动
docker-compose up -d --build

# 启动并查看日志
docker-compose up
```

### 停止服务

```bash
# 停止所有服务
docker-compose stop

# 停止特定服务
docker-compose stop selector

# 停止并删除容器
docker-compose down

# 停止并删除容器和数据卷 (危险!)
docker-compose down -v
```

### 重启服务

```bash
# 重启所有服务
docker-compose restart

# 重启特定服务
docker-compose restart selector

# 优雅重启 (等待当前任务完成)
docker-compose stop selector
docker-compose start selector
```

### 查看服务状态

```bash
# 查看所有容器状态
docker-compose ps

# 查看详细信息
docker-compose ps -a

# 查看资源使用
docker stats

# 查看特定服务详情
docker-compose ps selector
docker inspect funcat-selector
```

---

## 数据备份与恢复

### PostgreSQL备份

#### 手动备份

```bash
# 备份整个数据库
docker-compose exec postgres pg_dump -U funcat_user funcat > backup_$(date +%Y%m%d).sql

# 备份特定表
docker-compose exec postgres pg_dump -U funcat_user -t select_results funcat > select_results_backup.sql

# 备份为自定义格式 (压缩)
docker-compose exec postgres pg_dump -U funcat_user -Fc funcat > backup.dump
```

#### 自动备份脚本

创建文件 `scripts/backup_postgres.sh`:

```bash
#!/bin/bash
# PostgreSQL自动备份脚本

BACKUP_DIR="/backups/postgres"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/funcat_${DATE}.sql"

mkdir -p $BACKUP_DIR

# 执行备份
docker-compose exec -T postgres pg_dump -U funcat_user funcat > $BACKUP_FILE

# 压缩备份
gzip $BACKUP_FILE

# 删除7天前的备份
find $BACKUP_DIR -name "*.sql.gz" -mtime +7 -delete

echo "Backup completed: ${BACKUP_FILE}.gz"
```

添加到crontab:

```bash
# 每天凌晨2点备份
0 2 * * * /path/to/scripts/backup_postgres.sh
```

#### 恢复数据库

```bash
# 从SQL文件恢复
docker-compose exec -T postgres psql -U funcat_user funcat < backup.sql

# 从压缩文件恢复
gunzip -c backup.sql.gz | docker-compose exec -T postgres psql -U funcat_user funcat

# 从自定义格式恢复
docker-compose exec -T postgres pg_restore -U funcat_user -d funcat backup.dump
```

---

### Redis备份

#### 手动备份

```bash
# 触发保存
docker-compose exec redis redis-cli SAVE

# 复制RDB文件
docker cp funcat-redis:/data/dump.rdb ./redis_backup_$(date +%Y%m%d).rdb
```

#### 恢复Redis

```bash
# 停止Redis
docker-compose stop redis

# 复制备份文件
docker cp redis_backup.rdb funcat-redis:/data/dump.rdb

# 启动Redis
docker-compose start redis
```

---

### 数据卷备份

```bash
# 备份所有数据卷
docker run --rm \
  -v thsfuncat_postgres_data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/postgres_data_$(date +%Y%m%d).tar.gz -C /data .

# 恢复数据卷
docker run --rm \
  -v thsfuncat_postgres_data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar xzf /backup/postgres_data_20240101.tar.gz -C /data
```

---

## 监控和日志

### 查看日志

#### 实时查看所有服务日志

```bash
# 查看所有服务日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f selector

# 查看最近100行日志
docker-compose logs --tail=100 selector

# 查看特定时间段日志
docker-compose logs --since="2024-01-01T00:00:00" --until="2024-01-01T23:59:59" selector
```

#### 日志文件位置

```bash
# PostgreSQL日志
docker-compose exec postgres ls -lh /var/lib/postgresql/data/pg_log/

# 选股服务日志
docker-compose exec selector ls -lh /app/logs/

# 查看日志内容
docker-compose exec selector tail -f /app/logs/selector.log
```

---

### Prometheus监控

#### 启动监控服务

```bash
# 启动Prometheus和Grafana
docker-compose --profile monitoring up -d

# 访问Prometheus
# http://localhost:9090

# 访问Grafana
# http://localhost:3000
# 默认用户名: admin
# 默认密码: 见.env中的GRAFANA_ADMIN_PASSWORD
```

#### 常用监控指标

**Prometheus查询示例**:

```promql
# CPU使用率
rate(process_cpu_seconds_total[5m])

# 内存使用
process_resident_memory_bytes

# 选股任务数
funcat_select_tasks_total

# 数据库连接数
pg_stat_activity_count
```

---

### 健康检查

#### 自动健康检查

Docker Compose已配置健康检查，可以查看状态:

```bash
# 查看健康状态
docker-compose ps

# 健康的服务会显示: Up (healthy)
# 不健康的服务会显示: Up (unhealthy)
```

#### 手动健康检查脚本

创建文件 `scripts/health_check.sh`:

```bash
#!/bin/bash

echo "=== Funcat服务健康检查 ==="

# 检查PostgreSQL
echo -n "PostgreSQL: "
docker-compose exec -T postgres pg_isready -U funcat_user > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ OK"
else
    echo "✗ FAIL"
fi

# 检查Redis
echo -n "Redis: "
docker-compose exec -T redis redis-cli ping > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ OK"
else
    echo "✗ FAIL"
fi

# 检查选股服务
echo -n "Selector: "
docker-compose ps selector | grep "Up" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ OK"
else
    echo "✗ FAIL"
fi

echo "==========================="
```

运行:

```bash
chmod +x scripts/health_check.sh
./scripts/health_check.sh
```

---

## 故障排查

### 常见问题

#### 问题1: 容器启动失败

**症状**: `docker-compose up -d` 后容器立即退出

**排查步骤**:

```bash
# 1. 查看容器状态
docker-compose ps

# 2. 查看日志
docker-compose logs selector

# 3. 检查配置
docker-compose config

# 4. 手动启动容器查看错误
docker-compose up selector
```

**常见原因**:
- 端口被占用
- 配置文件错误
- 环境变量未设置
- 磁盘空间不足

---

#### 问题2: 数据库连接失败

**症状**: 选股服务无法连接数据库

**排查步骤**:

```bash
# 1. 检查PostgreSQL状态
docker-compose ps postgres

# 2. 测试连接
docker-compose exec postgres psql -U funcat_user -d funcat -c "SELECT 1;"

# 3. 检查网络
docker network ls
docker network inspect thsfuncat_funcat-network

# 4. 查看PostgreSQL日志
docker-compose logs postgres
```

**解决方案**:
```bash
# 重启PostgreSQL
docker-compose restart postgres

# 检查密码配置
vim .env  # 确保POSTGRES_PASSWORD正确
```

---

#### 问题3: Redis内存不足

**症状**: Redis OOM错误

**排查步骤**:

```bash
# 查看Redis内存使用
docker-compose exec redis redis-cli INFO memory

# 查看Redis配置
docker-compose exec redis redis-cli CONFIG GET maxmemory
```

**解决方案**:

修改 `.env`:
```bash
REDIS_MAX_MEMORY=4gb  # 增加内存限制
```

重启Redis:
```bash
docker-compose restart redis
```

---

#### 问题4: 磁盘空间不足

**症状**: 容器无法写入数据

**排查步骤**:

```bash
# 查看磁盘使用
df -h

# 查看Docker磁盘使用
docker system df

# 查看数据卷大小
docker volume ls
docker volume inspect thsfuncat_postgres_data
```

**解决方案**:

```bash
# 清理未使用的镜像
docker image prune -a

# 清理未使用的容器
docker container prune

# 清理未使用的数据卷 (危险!)
docker volume prune

# 查看Docker占用空间
docker system df

# 清理所有未使用资源
docker system prune -a --volumes
```

---

## 性能优化

### PostgreSQL优化

#### 调整配置参数

编辑 `deployment/config/postgresql.conf`:

```ini
# 根据服务器内存调整
shared_buffers = 4GB              # 系统内存的25%
effective_cache_size = 12GB       # 系统内存的50-75%
work_mem = 256MB                  # 增加排序和哈希内存
maintenance_work_mem = 1GB        # 增加维护操作内存
```

#### 创建索引

```sql
-- 为常用查询创建索引
CREATE INDEX idx_select_results_strategy_date_code
    ON select_results(strategy_name, select_date, stock_code);

-- 为JSON字段创建GIN索引
CREATE INDEX idx_select_results_indicators
    ON select_results USING GIN (indicators);
```

---

### Redis优化

#### 配置优化

```bash
# 在docker-compose.yml中调整Redis参数
redis:
  command: >
    redis-server
    --maxmemory 4gb                    # 增加内存
    --maxmemory-policy allkeys-lru
    --save 900 1 --save 300 10         # 调整持久化频率
    --tcp-backlog 511
    --timeout 0
    --tcp-keepalive 300
```

#### 监控Redis性能

```bash
# 查看慢查询
docker-compose exec redis redis-cli SLOWLOG GET 10

# 查看客户端连接
docker-compose exec redis redis-cli CLIENT LIST

# 实时监控
docker-compose exec redis redis-cli --stat
```

---

### Go服务优化

#### 资源限制调整

在 `docker-compose.yml` 中:

```yaml
selector:
  deploy:
    resources:
      limits:
        cpus: '4'          # 增加CPU限制
        memory: 4G         # 增加内存限制
      reservations:
        cpus: '1'
        memory: 1G
```

#### 并发数调整

在 `.env` 中:

```bash
SELECTOR_WORKERS=200      # 增加并发数 (根据CPU核心数调整)
```

---

## 生产环境部署建议

### 安全加固

#### 1. 修改默认密码

```bash
# .env文件中修改所有密码
POSTGRES_PASSWORD=your_very_secure_password_123
REDIS_PASSWORD=another_secure_password_456
GRAFANA_ADMIN_PASSWORD=yet_another_password_789
```

#### 2. 限制端口暴露

```yaml
# docker-compose.yml中
postgres:
  ports:
    - "127.0.0.1:5432:5432"  # 只允许本机访问

redis:
  ports:
    - "127.0.0.1:6379:6379"  # 只允许本机访问
```

#### 3. 启用SSL/TLS

```bash
# PostgreSQL SSL配置
# 生成证书
openssl req -new -x509 -days 365 -nodes -text \
  -out server.crt -keyout server.key \
  -subj "/CN=funcat-postgres"

# 配置PostgreSQL使用SSL
# 在postgresql.conf中添加:
ssl = on
ssl_cert_file = 'server.crt'
ssl_key_file = 'server.key'
```

---

### 高可用配置

#### PostgreSQL主从复制

创建 `docker-compose.ha.yml`:

```yaml
version: '3.8'

services:
  postgres-master:
    # ... 主库配置

  postgres-slave:
    image: postgres:13-alpine
    environment:
      POSTGRES_MASTER_SERVICE: postgres-master
      POSTGRES_REPLICATION_USER: replicator
      POSTGRES_REPLICATION_PASSWORD: replication_password
    # ... 从库配置
```

#### Redis哨兵模式

```yaml
redis-sentinel:
  image: redis:6-alpine
  command: redis-sentinel /etc/redis/sentinel.conf
  volumes:
    - ./config/sentinel.conf:/etc/redis/sentinel.conf
```

---

### 性能监控告警

#### Prometheus告警规则

创建 `deployment/config/alert_rules.yml`:

```yaml
groups:
  - name: funcat
    rules:
      - alert: HighMemoryUsage
        expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
        for: 5m
        annotations:
          summary: "容器内存使用率过高"

      - alert: DatabaseDown
        expr: up{job="postgres"} == 0
        for: 1m
        annotations:
          summary: "PostgreSQL服务停止"
```

---

## 总结

### 部署检查清单

- [ ] Docker和Docker Compose已安装
- [ ] 克隆项目代码
- [ ] 配置 `.env` 文件 (特别是TUSHARE_TOKEN)
- [ ] 修改默认密码
- [ ] 启动服务: `docker-compose up -d`
- [ ] 验证服务健康: `docker-compose ps`
- [ ] 查看日志确认无错误
- [ ] 测试数据库连接
- [ ] 配置自动备份
- [ ] 设置监控告警 (生产环境)

### 快速命令参考

```bash
# 启动
docker-compose up -d

# 停止
docker-compose stop

# 重启
docker-compose restart

# 查看状态
docker-compose ps

# 查看日志
docker-compose logs -f selector

# 进入容器
docker-compose exec selector sh

# 备份数据库
docker-compose exec postgres pg_dump -U funcat_user funcat > backup.sql

# 清理资源
docker-compose down
docker system prune -a
```

---

**部署完成！** 现在你拥有一个完整的、生产就绪的Funcat量化选股系统！🚀

如有问题，请查看[故障排查](#故障排查)章节或提交Issue。
