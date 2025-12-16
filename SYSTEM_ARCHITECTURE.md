# Funcat 系统架构设计文档

## 📋 目录

- [系统架构概述](#系统架构概述)
- [接口和API](#接口和api)
- [数据存储](#数据存储)
- [服务部署](#服务部署)
- [中间件](#中间件)
- [配置文件](#配置文件)
- [启动流程](#启动流程)
- [系统集成](#系统集成)

---

## 系统架构概述

### 整体架构图

```
┌─────────────────────────────────────────────────────────────┐
│                      用户层                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Jupyter      │  │ Web界面      │  │ CLI工具       │     │
│  │ Notebook     │  │ (可选)       │  │              │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   应用层 (Python/Go)                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ 策略研发     │  │ 选股服务     │  │ 回测服务      │     │
│  │ (Python)     │  │ (Go)         │  │ (Go)         │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   数据访问层                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Funcat Core  │  │ 缓存服务     │  │ 数据API      │     │
│  │ (Python/Go)  │  │ (Redis)      │  │ 适配器        │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   存储层                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ PostgreSQL/  │  │ Redis        │  │ 时序数据库    │     │
│  │ MySQL        │  │ (缓存)       │  │ (可选)        │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   外部数据源                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Tushare      │  │ RQData       │  │ 其他数据源    │     │
│  │ (免费/付费)  │  │ (付费)       │  │              │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

### 技术栈

| 层级 | 技术 | 说明 |
|------|------|------|
| **前端** | Jupyter Notebook | 策略研发 |
| **应用层** | Python 3.7+ | 策略开发 |
| **应用层** | Go 1.21+ | 生产服务 |
| **缓存** | Redis 6.0+ | 数据缓存 |
| **数据库** | PostgreSQL 13+ / MySQL 8.0+ | 数据存储 |
| **时序DB** | InfluxDB 2.0+ (可选) | 高频数据 |
| **消息队列** | Redis Pub/Sub / RabbitMQ (可选) | 异步任务 |
| **监控** | Prometheus + Grafana (可选) | 系统监控 |

---

## 接口和API

### 1. 数据源接口

#### Tushare (免费 + 付费)

**类型**: REST API
**官网**: https://tushare.pro/
**费用**:
- 免费版: 基础日K线数据 (有限流)
- 积分版: 更多数据和更高频率 (需购买积分)

**使用方式**:
```python
# Python接口
import tushare as ts

# 设置token
ts.set_token('your_token_here')

# 获取数据
pro = ts.pro_api()
df = pro.daily(ts_code='000001.SZ', start_date='20240101', end_date='20241231')
```

**配置文件**: `config/tushare.yaml`
```yaml
tushare:
  token: "your_token_here"
  timeout: 10
  retry: 3
  cache_ttl: 3600  # 1小时
```

**限流规则**:
- 免费版: 120次/分钟
- 付费版: 根据积分等级

---

#### RQData (付费)

**类型**: Python SDK
**官网**: https://www.ricequant.com/
**费用**: 按年订阅，价格约 ¥10,000+/年

**使用方式**:
```python
# Python接口
import rqdatac

# 初始化
rqdatac.init('username', 'password')

# 获取数据
df = rqdatac.get_price(
    '000001.XSHE',
    start_date='2024-01-01',
    end_date='2024-12-31',
    frequency='1d'
)
```

**配置文件**: `config/rqdata.yaml`
```yaml
rqdata:
  username: "your_username"
  password: "your_password"
  uri: "tcp://data.ricequant.com:16011"
```

---

#### 本地数据 (免费)

**类型**: 本地文件
**来源**: RQAlpha数据包或自行采集

**使用方式**:
```python
# Python接口
from funcat.data.rqalpha_data_backend import RQAlphaDataBackend

# 设置数据路径
set_data_backend(RQAlphaDataBackend('/path/to/data'))
```

**配置文件**: `config/local_data.yaml`
```yaml
local_data:
  path: "/data/rqalpha_data"
  cache_size: 1000
```

---

### 2. 内部API接口

#### Python API (策略开发)

**接口类型**: Python Library
**开源**: 是
**用途**: 策略研发和原型验证

**主要接口**:
```python
# 行情数据
OPEN, HIGH, LOW, CLOSE, VOLUME

# 技术指标
MA(series, period)
EMA(series, period)
MACD(short, long, m)
KDJ(n, m1, m2)

# 选股
select(strategy, start_date, end_date, callback)
```

---

#### Go API (生产部署)

**接口类型**: Go Library
**开源**: 是
**用途**: 高性能生产环境

**主要接口**:
```go
// 技术指标
indicators.MA(series, period)
indicators.EMA(series, period)
indicators.MACD(close, short, long, m)

// 并发选股
selector.Select(condition, start, end, callback)
selector.SelectWithStats(condition, start, end, callback)
```

---

#### REST API (可选 - Web服务)

**接口类型**: HTTP REST
**开源**: 待实现
**端口**: 8080

**示例接口**:
```
GET  /api/v1/indicators/ma?code=000001.XSHE&period=5
POST /api/v1/select
GET  /api/v1/backtest/{id}
```

**配置文件**: `config/api_server.yaml`
```yaml
api_server:
  host: "0.0.0.0"
  port: 8080
  timeout: 30
  max_concurrent: 100
```

---

## 数据存储

### 1. PostgreSQL (主数据库)

**用途**: 存储选股结果、回测记录、用户配置

**版本**: PostgreSQL 13+
**开源**: 是
**费用**: 免费

#### 数据表设计

```sql
-- 选股结果表
CREATE TABLE select_results (
    id SERIAL PRIMARY KEY,
    strategy_name VARCHAR(100) NOT NULL,
    stock_code VARCHAR(20) NOT NULL,
    stock_name VARCHAR(50),
    select_date DATE NOT NULL,
    indicators JSONB,  -- 指标数据
    created_at TIMESTAMP DEFAULT NOW(),
    INDEX idx_strategy_date (strategy_name, select_date),
    INDEX idx_stock_code (stock_code)
);

-- 回测记录表
CREATE TABLE backtest_records (
    id SERIAL PRIMARY KEY,
    strategy_name VARCHAR(100) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    total_stocks INT,
    avg_return DECIMAL(10, 4),
    sharpe_ratio DECIMAL(10, 4),
    max_drawdown DECIMAL(10, 4),
    config JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 策略配置表
CREATE TABLE strategy_configs (
    id SERIAL PRIMARY KEY,
    strategy_name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    parameters JSONB,
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 用户表
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100),
    api_keys JSONB,  -- 各数据源API密钥
    created_at TIMESTAMP DEFAULT NOW()
);
```

#### 配置文件

**文件**: `config/postgres.yaml`
```yaml
postgres:
  host: "localhost"
  port: 5432
  database: "funcat"
  username: "funcat_user"
  password: "your_secure_password"
  pool_size: 10
  max_overflow: 20
  echo: false  # SQL日志
```

#### 连接示例

**Python**:
```python
import psycopg2
from psycopg2 import pool

# 创建连接池
connection_pool = pool.SimpleConnectionPool(
    1, 20,
    host='localhost',
    database='funcat',
    user='funcat_user',
    password='your_secure_password'
)

# 使用连接
conn = connection_pool.getconn()
cursor = conn.cursor()
cursor.execute("SELECT * FROM select_results WHERE select_date = %s", ('2024-01-01',))
```

**Go**:
```go
import (
    "database/sql"
    _ "github.com/lib/pq"
)

// 连接数据库
db, err := sql.Open("postgres",
    "host=localhost port=5432 user=funcat_user password=your_secure_password dbname=funcat sslmode=disable")

// 查询
rows, err := db.Query("SELECT * FROM select_results WHERE select_date = $1", "2024-01-01")
```

---

### 2. Redis (缓存)

**用途**:
- 行情数据缓存
- 指标计算结果缓存
- 分布式锁
- 消息队列 (可选)

**版本**: Redis 6.0+
**开源**: 是
**费用**: 免费

#### 数据结构设计

```
# 行情数据缓存 (Hash)
Key: stock:000001.XSHE:20240101
Fields: {
    open: "10.5",
    high: "11.0",
    low: "10.2",
    close: "10.8",
    volume: "1000000"
}
TTL: 3600 (1小时)

# 指标缓存 (String)
Key: indicator:MA:000001.XSHE:5:20240101
Value: "10.65"
TTL: 1800 (30分钟)

# 选股任务队列 (List)
Key: select_tasks
Values: ["task_id_1", "task_id_2", ...]

# 分布式锁 (String)
Key: lock:select:20240101
Value: "node_id_1"
TTL: 300 (5分钟)
```

#### 配置文件

**文件**: `config/redis.yaml`
```yaml
redis:
  host: "localhost"
  port: 6379
  password: ""
  db: 0
  pool_size: 10
  timeout: 5

  # 缓存策略
  cache:
    stock_data_ttl: 3600     # 行情数据1小时
    indicator_ttl: 1800      # 指标30分钟
    max_memory: "2gb"
    eviction_policy: "allkeys-lru"
```

#### 连接示例

**Python**:
```python
import redis

# 创建连接
r = redis.Redis(
    host='localhost',
    port=6379,
    db=0,
    decode_responses=True
)

# 缓存行情数据
r.hset('stock:000001.XSHE:20240101', mapping={
    'open': '10.5',
    'close': '10.8'
})
r.expire('stock:000001.XSHE:20240101', 3600)

# 获取缓存
data = r.hgetall('stock:000001.XSHE:20240101')
```

**Go**:
```go
import (
    "github.com/go-redis/redis/v8"
    "context"
)

// 创建客户端
rdb := redis.NewClient(&redis.Options{
    Addr: "localhost:6379",
    DB: 0,
})

ctx := context.Background()

// 设置缓存
rdb.HSet(ctx, "stock:000001.XSHE:20240101", "open", "10.5")
rdb.Expire(ctx, "stock:000001.XSHE:20240101", time.Hour)

// 获取缓存
data, err := rdb.HGetAll(ctx, "stock:000001.XSHE:20240101").Result()
```

---

### 3. InfluxDB (可选 - 时序数据)

**用途**: 高频tick数据、分钟级K线

**版本**: InfluxDB 2.0+
**开源**: 是 (OSS版本)
**费用**: 免费 (云版本付费)

#### 配置文件

**文件**: `config/influxdb.yaml`
```yaml
influxdb:
  url: "http://localhost:8086"
  token: "your_token"
  org: "funcat"
  bucket: "stock_data"

  # 数据保留策略
  retention:
    tick_data: "7d"      # tick数据保留7天
    minute_data: "30d"   # 分钟数据保留30天
    daily_data: "forever" # 日线永久保留
```

---

## 服务部署

### 服务列表

| 服务名称 | 类型 | 端口 | 用途 |
|---------|------|------|------|
| **funcat-selector** | Go | - | 选股服务 |
| **funcat-backtest** | Go | - | 回测服务 |
| **funcat-api** | Go/Python | 8080 | REST API (可选) |
| **postgresql** | Database | 5432 | 主数据库 |
| **redis** | Cache | 6379 | 缓存服务 |
| **influxdb** | Database | 8086 | 时序数据 (可选) |

---

### 1. PostgreSQL 部署

#### Docker部署 (推荐)

```bash
# 创建数据目录
mkdir -p /data/postgres

# 启动容器
docker run -d \
  --name funcat-postgres \
  --restart=always \
  -e POSTGRES_DB=funcat \
  -e POSTGRES_USER=funcat_user \
  -e POSTGRES_PASSWORD=your_secure_password \
  -v /data/postgres:/var/lib/postgresql/data \
  -p 5432:5432 \
  postgres:13
```

#### 初始化数据库

```bash
# 创建数据库
docker exec -it funcat-postgres psql -U funcat_user -d funcat

# 执行SQL
\i /path/to/schema.sql
```

#### 验证部署

```bash
# 测试连接
docker exec -it funcat-postgres psql -U funcat_user -d funcat -c "SELECT version();"
```

---

### 2. Redis 部署

#### Docker部署 (推荐)

```bash
# 创建配置文件
cat > /etc/redis/redis.conf <<EOF
bind 0.0.0.0
protected-mode yes
port 6379
maxmemory 2gb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
EOF

# 启动容器
docker run -d \
  --name funcat-redis \
  --restart=always \
  -v /etc/redis/redis.conf:/usr/local/etc/redis/redis.conf \
  -v /data/redis:/data \
  -p 6379:6379 \
  redis:6 redis-server /usr/local/etc/redis/redis.conf
```

#### 验证部署

```bash
# 测试连接
docker exec -it funcat-redis redis-cli ping
# 应返回: PONG
```

---

### 3. Funcat选股服务部署 (Go)

#### 编译服务

```bash
cd funcat-go

# 编译
go build -ldflags="-s -w" -o funcat-selector cmd/selector/main.go

# 或交叉编译
GOOS=linux GOARCH=amd64 go build -o funcat-selector-linux cmd/selector/main.go
```

#### 创建配置文件

**文件**: `config/selector.yaml`
```yaml
selector:
  # 数据源配置
  data_backend: "tushare"  # tushare, rqdata, local

  # 并发配置
  workers: 100
  batch_size: 10

  # Redis配置
  redis:
    host: "localhost"
    port: 6379
    db: 0

  # PostgreSQL配置
  postgres:
    host: "localhost"
    port: 5432
    database: "funcat"
    username: "funcat_user"
    password: "your_secure_password"

  # 日志配置
  log:
    level: "info"
    file: "/var/log/funcat/selector.log"
    max_size: 100  # MB
    max_backups: 10
```

#### 创建systemd服务

**文件**: `/etc/systemd/system/funcat-selector.service`
```ini
[Unit]
Description=Funcat Selector Service
After=network.target postgresql.service redis.service

[Service]
Type=simple
User=funcat
WorkingDirectory=/opt/funcat
ExecStart=/opt/funcat/funcat-selector --config=/opt/funcat/config/selector.yaml
Restart=always
RestartSec=10

# 日志
StandardOutput=append:/var/log/funcat/selector.log
StandardError=append:/var/log/funcat/selector-error.log

# 资源限制
LimitNOFILE=65536
MemoryMax=2G

[Install]
WantedBy=multi-user.target
```

#### 启动服务

```bash
# 创建用户
sudo useradd -r -s /bin/false funcat

# 创建目录
sudo mkdir -p /opt/funcat /var/log/funcat
sudo chown funcat:funcat /opt/funcat /var/log/funcat

# 复制文件
sudo cp funcat-selector /opt/funcat/
sudo cp -r config /opt/funcat/

# 重载systemd
sudo systemctl daemon-reload

# 启动服务
sudo systemctl start funcat-selector

# 开机自启
sudo systemctl enable funcat-selector

# 查看状态
sudo systemctl status funcat-selector

# 查看日志
sudo journalctl -u funcat-selector -f
```

---

### 4. Docker Compose 一键部署 (推荐)

#### 创建docker-compose.yml

**文件**: `docker-compose.yml`
```yaml
version: '3.8'

services:
  # PostgreSQL数据库
  postgres:
    image: postgres:13
    container_name: funcat-postgres
    restart: always
    environment:
      POSTGRES_DB: funcat
      POSTGRES_USER: funcat_user
      POSTGRES_PASSWORD: your_secure_password
    ports:
      - "5432:5432"
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
      - ./sql/schema.sql:/docker-entrypoint-initdb.d/schema.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U funcat_user"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Redis缓存
  redis:
    image: redis:6-alpine
    container_name: funcat-redis
    restart: always
    ports:
      - "6379:6379"
    volumes:
      - ./data/redis:/data
      - ./config/redis.conf:/usr/local/etc/redis/redis.conf
    command: redis-server /usr/local/etc/redis/redis.conf
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  # InfluxDB (可选)
  influxdb:
    image: influxdb:2.0
    container_name: funcat-influxdb
    restart: always
    ports:
      - "8086:8086"
    volumes:
      - ./data/influxdb:/var/lib/influxdb2
    environment:
      INFLUXDB_DB: funcat
      INFLUXDB_ADMIN_USER: admin
      INFLUXDB_ADMIN_PASSWORD: your_password

  # Funcat选股服务
  selector:
    build:
      context: ./funcat-go
      dockerfile: Dockerfile
    container_name: funcat-selector
    restart: always
    depends_on:
      - postgres
      - redis
    volumes:
      - ./config:/app/config
      - ./logs:/app/logs
    environment:
      - POSTGRES_HOST=postgres
      - REDIS_HOST=redis
    command: /app/funcat-selector --config=/app/config/selector.yaml

  # API服务 (可选)
  api:
    build:
      context: ./api
      dockerfile: Dockerfile
    container_name: funcat-api
    restart: always
    ports:
      - "8080:8080"
    depends_on:
      - postgres
      - redis
    environment:
      - POSTGRES_HOST=postgres
      - REDIS_HOST=redis
```

#### 启动所有服务

```bash
# 启动
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止
docker-compose down

# 重启
docker-compose restart
```

---

## 中间件

### 1. 消息队列 (可选)

#### Redis Pub/Sub (轻量级)

**用途**: 实时信号通知

```python
# 发布者
import redis
r = redis.Redis()
r.publish('stock_signals', json.dumps({
    'code': '000001.XSHE',
    'signal': 'BUY',
    'time': '2024-01-01 09:30:00'
}))

# 订阅者
p = r.pubsub()
p.subscribe('stock_signals')
for message in p.listen():
    if message['type'] == 'message':
        data = json.loads(message['data'])
        handle_signal(data)
```

#### RabbitMQ (高级)

**用途**: 异步任务队列、可靠消息传递

**配置文件**: `config/rabbitmq.yaml`
```yaml
rabbitmq:
  host: "localhost"
  port: 5672
  username: "funcat"
  password: "your_password"
  vhost: "/"

  queues:
    - name: "select_tasks"
      durable: true
      auto_delete: false
    - name: "backtest_tasks"
      durable: true
      auto_delete: false
```

---

### 2. 监控系统 (可选)

#### Prometheus + Grafana

**Prometheus配置**: `config/prometheus.yml`
```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'funcat-selector'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']

  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']
```

---

## 配置文件

### 配置文件结构

```
config/
├── main.yaml              # 主配置文件
├── tushare.yaml          # Tushare配置
├── rqdata.yaml           # RQData配置
├── local_data.yaml       # 本地数据配置
├── postgres.yaml         # PostgreSQL配置
├── redis.yaml            # Redis配置
├── influxdb.yaml         # InfluxDB配置
├── selector.yaml         # 选股服务配置
├── backtest.yaml         # 回测服务配置
├── api_server.yaml       # API服务配置
└── logging.yaml          # 日志配置
```

---

### 主配置文件

**文件**: `config/main.yaml`
```yaml
# Funcat主配置文件
version: "2.0"

# 环境: development, production
environment: "production"

# 数据源配置
data_sources:
  primary: "tushare"      # 主数据源
  fallback: "local"       # 备用数据源

  # 各数据源配置
  tushare:
    enabled: true
    config_file: "config/tushare.yaml"

  rqdata:
    enabled: false
    config_file: "config/rqdata.yaml"

  local:
    enabled: true
    config_file: "config/local_data.yaml"

# 数据库配置
databases:
  postgres:
    enabled: true
    config_file: "config/postgres.yaml"

  redis:
    enabled: true
    config_file: "config/redis.yaml"

  influxdb:
    enabled: false
    config_file: "config/influxdb.yaml"

# 服务配置
services:
  selector:
    enabled: true
    config_file: "config/selector.yaml"

  backtest:
    enabled: false
    config_file: "config/backtest.yaml"

  api_server:
    enabled: false
    config_file: "config/api_server.yaml"

# 日志配置
logging:
  config_file: "config/logging.yaml"

# 性能配置
performance:
  cache_enabled: true
  cache_ttl: 3600
  max_workers: 100
  connection_pool_size: 20
```

---

### 日志配置

**文件**: `config/logging.yaml`
```yaml
logging:
  version: 1

  # 格式化器
  formatters:
    standard:
      format: '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    detailed:
      format: '%(asctime)s - %(name)s - %(levelname)s - %(filename)s:%(lineno)d - %(message)s'

  # 处理器
  handlers:
    console:
      class: logging.StreamHandler
      level: INFO
      formatter: standard
      stream: ext://sys.stdout

    file:
      class: logging.handlers.RotatingFileHandler
      level: DEBUG
      formatter: detailed
      filename: /var/log/funcat/funcat.log
      maxBytes: 104857600  # 100MB
      backupCount: 10

    error_file:
      class: logging.handlers.RotatingFileHandler
      level: ERROR
      formatter: detailed
      filename: /var/log/funcat/error.log
      maxBytes: 104857600
      backupCount: 10

  # 日志记录器
  loggers:
    funcat:
      level: DEBUG
      handlers: [console, file, error_file]
      propagate: false

    funcat.selector:
      level: INFO
      handlers: [console, file]
      propagate: false

  # 根日志记录器
  root:
    level: INFO
    handlers: [console, file]
```

---

## 启动流程

### 完整启动流程

#### 方式1: Docker Compose (推荐)

```bash
# 1. 克隆项目
git clone https://github.com/linqiluo8-design/thsfuncat.git
cd thsfuncat

# 2. 配置环境变量
cp .env.example .env
# 编辑.env文件,填入API密钥等

# 3. 修改配置文件
vim config/main.yaml
# 修改数据源、数据库等配置

# 4. 初始化数据库
docker-compose up -d postgres
sleep 10
docker-compose exec postgres psql -U funcat_user -d funcat -f /docker-entrypoint-initdb.d/schema.sql

# 5. 启动所有服务
docker-compose up -d

# 6. 验证服务
docker-compose ps
docker-compose logs -f

# 7. 测试选股
docker-compose exec selector /app/funcat-selector --test
```

---

#### 方式2: 手动部署

```bash
# === 步骤1: 安装依赖 ===
# PostgreSQL
sudo apt-get install postgresql-13

# Redis
sudo apt-get install redis-server

# Go
wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin

# Python
sudo apt-get install python3 python3-pip
pip3 install -r requirements.txt

# === 步骤2: 初始化数据库 ===
sudo -u postgres createdb funcat
sudo -u postgres createuser funcat_user
sudo -u postgres psql -c "ALTER USER funcat_user WITH PASSWORD 'your_password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE funcat TO funcat_user;"
psql -U funcat_user -d funcat -f sql/schema.sql

# === 步骤3: 配置Redis ===
sudo vim /etc/redis/redis.conf
# 修改: bind 0.0.0.0
# 修改: maxmemory 2gb
sudo systemctl restart redis

# === 步骤4: 配置文件 ===
mkdir -p /opt/funcat/config /var/log/funcat
cp config/*.yaml /opt/funcat/config/
vim /opt/funcat/config/main.yaml
# 填入API密钥、数据库密码等

# === 步骤5: 编译Go服务 ===
cd funcat-go
go build -o /opt/funcat/funcat-selector cmd/selector/main.go

# === 步骤6: 创建systemd服务 ===
sudo cp deployment/funcat-selector.service /etc/systemd/system/
sudo systemctl daemon-reload

# === 步骤7: 启动服务 ===
# PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Redis
sudo systemctl start redis
sudo systemctl enable redis

# Funcat选股服务
sudo systemctl start funcat-selector
sudo systemctl enable funcat-selector

# === 步骤8: 验证服务 ===
sudo systemctl status postgresql
sudo systemctl status redis
sudo systemctl status funcat-selector

# === 步骤9: 查看日志 ===
tail -f /var/log/funcat/selector.log

# === 步骤10: 测试 ===
/opt/funcat/funcat-selector --test
```

---

### 服务健康检查

**检查脚本**: `scripts/health_check.sh`
```bash
#!/bin/bash

echo "=== Funcat服务健康检查 ==="

# 检查PostgreSQL
echo -n "PostgreSQL: "
pg_isready -h localhost -p 5432 && echo "✓ OK" || echo "✗ FAIL"

# 检查Redis
echo -n "Redis: "
redis-cli ping > /dev/null 2>&1 && echo "✓ OK" || echo "✗ FAIL"

# 检查选股服务
echo -n "Selector Service: "
systemctl is-active funcat-selector > /dev/null 2>&1 && echo "✓ OK" || echo "✗ FAIL"

# 检查磁盘空间
echo -n "Disk Space: "
USAGE=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $USAGE -lt 90 ]; then
    echo "✓ OK ($USAGE%)"
else
    echo "⚠ WARNING ($USAGE%)"
fi

# 检查内存
echo -n "Memory: "
MEM_USAGE=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100.0)}')
if [ $MEM_USAGE -lt 90 ]; then
    echo "✓ OK ($MEM_USAGE%)"
else
    echo "⚠ WARNING ($MEM_USAGE%)"
fi

echo "==========================="
```

---

## 系统集成

### 整体启动顺序

```
1. PostgreSQL     (数据库)
   ↓
2. Redis          (缓存)
   ↓
3. InfluxDB       (可选 - 时序数据)
   ↓
4. Funcat Selector (选股服务)
   ↓
5. Funcat Backtest (回测服务 - 可选)
   ↓
6. API Server     (Web服务 - 可选)
   ↓
7. 监控系统       (Prometheus/Grafana - 可选)
```

### 系统停止顺序

```bash
# 逆序停止
sudo systemctl stop funcat-api
sudo systemctl stop funcat-backtest
sudo systemctl stop funcat-selector
sudo systemctl stop influxdb
sudo systemctl stop redis
sudo systemctl stop postgresql
```

---

## 故障排查

### 常见问题

#### 问题1: 数据库连接失败

**错误**: `could not connect to server: Connection refused`

**排查步骤**:
```bash
# 1. 检查服务状态
sudo systemctl status postgresql

# 2. 检查端口
netstat -tuln | grep 5432

# 3. 检查配置
psql -U funcat_user -d funcat -c "SELECT 1;"

# 4. 查看日志
sudo journalctl -u postgresql -n 50
```

---

#### 问题2: Redis连接失败

**排查步骤**:
```bash
# 1. 检查服务
sudo systemctl status redis

# 2. 测试连接
redis-cli ping

# 3. 检查配置
cat /etc/redis/redis.conf | grep bind

# 4. 查看日志
tail -f /var/log/redis/redis-server.log
```

---

#### 问题3: 选股服务异常

**排查步骤**:
```bash
# 1. 查看服务状态
sudo systemctl status funcat-selector

# 2. 查看日志
tail -f /var/log/funcat/selector.log

# 3. 手动运行测试
/opt/funcat/funcat-selector --config=/opt/funcat/config/selector.yaml --debug

# 4. 检查资源占用
top -p $(pgrep funcat-selector)
```

---

## 性能优化配置

### PostgreSQL优化

**文件**: `/etc/postgresql/13/main/postgresql.conf`
```ini
# 内存配置
shared_buffers = 2GB
effective_cache_size = 6GB
maintenance_work_mem = 512MB
work_mem = 128MB

# 连接配置
max_connections = 200

# 检查点配置
checkpoint_completion_target = 0.9
wal_buffers = 16MB

# 查询优化
random_page_cost = 1.1  # SSD
effective_io_concurrency = 200  # SSD
```

### Redis优化

**文件**: `/etc/redis/redis.conf`
```ini
# 内存配置
maxmemory 2gb
maxmemory-policy allkeys-lru

# 持久化
save 900 1
save 300 10
save 60 10000
rdbcompression yes
rdbchecksum yes

# 复制 (主从)
repl-diskless-sync yes
repl-diskless-sync-delay 5

# 慢查询日志
slowlog-log-slower-than 10000
slowlog-max-len 128
```

---

## 总结

本文档详细描述了Funcat系统的完整架构,包括:

✅ **接口**: Tushare(免费/付费)、RQData(付费)、本地数据(免费)
✅ **数据库**: PostgreSQL(主库)、Redis(缓存)、InfluxDB(可选)
✅ **服务**: 选股服务、回测服务、API服务
✅ **中间件**: Redis Pub/Sub、RabbitMQ(可选)、Prometheus(可选)
✅ **配置**: 完整的配置文件结构和说明
✅ **部署**: Docker Compose一键部署和手动部署流程
✅ **监控**: 健康检查和性能监控

按照本文档的指导,可以快速搭建一个完整的生产级量化选股系统! 🚀
