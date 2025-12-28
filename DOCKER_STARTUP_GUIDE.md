# Docker 容器启动指南

本文档详细说明如何使用 Docker Compose 启动 Funcat 股票分析系统的所有服务。

## 📋 目录

- [系统架构](#系统架构)
- [服务依赖关系](#服务依赖关系)
- [前置准备](#前置准备)
- [配置文件说明](#配置文件说明)
- [启动步骤](#启动步骤)
- [验证服务](#验证服务)
- [常见问题](#常见问题)

---

## 系统架构

Funcat 系统采用微服务架构，包含以下组件：

```
┌─────────────────────────────────────────────────────────┐
│                    用户浏览器                              │
│                 http://localhost:8080                    │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              Web UI Service (Go + Vue3)                 │
│              端口: 8080                                  │
│              - 涨跌停数据看板                             │
│              - 炒股养家心法选股                            │
└─────────┬───────────────────────┬───────────────────────┘
          │                       │
          ▼                       ▼
┌──────────────────┐    ┌──────────────────┐
│  PostgreSQL      │    │  Redis Cache     │
│  端口: 5432      │    │  端口: 6379      │
│  - 股票数据      │    │  - 查询缓存      │
│  - 选股结果      │    │  - 会话存储      │
└──────────────────┘    └──────────────────┘
          ▲                       ▲
          │                       │
┌─────────┴───────────────────────┴───────────────────────┐
│           Selector Service (Go)                         │
│           - 定时选股任务（60分钟）                        │
│           - 涨停数据分析                                 │
│           - 板块效应统计                                 │
│           - 炒股养家心法选股                              │
└─────────────────────────────────────────────────────────┘
```

---

## 服务依赖关系

### 核心服务

| 服务名 | 容器名 | 端口 | 依赖 | 说明 |
|--------|--------|------|------|------|
| **postgres** | funcat-postgres | 5432 | 无 | PostgreSQL 13 数据库 |
| **redis** | funcat-redis | 6379 | 无 | Redis 6 缓存 |
| **webui** | funcat-webui | 8080 | postgres, redis | Web 前端界面 |
| **selector** | funcat-selector | - | postgres, redis | 后台选股服务 |

### 依赖说明

```yaml
webui → postgres (必需，等待健康检查)
webui → redis (必需，等待健康检查)

selector → postgres (必需，等待健康检查)
selector → redis (必需，等待健康检查)
```

**重要**: 由于 `depends_on` 配置了健康检查条件，启动 `webui` 或 `selector` 时会自动启动并等待 `postgres` 和 `redis` 准备就绪。

### 可选服务

| 服务名 | 容器名 | 端口 | Profile | 说明 |
|--------|--------|------|---------|------|
| **influxdb** | funcat-influxdb | 8181 | full | InfluxDB 3.5.0 时序数据库 |
| **nginx** | funcat-nginx | 80, 443 | full | Nginx 反向代理 |
| **prometheus** | funcat-prometheus | 9090 | monitoring | Prometheus 监控 |
| **grafana** | funcat-grafana | 3000 | monitoring | Grafana 可视化 |

---

## 前置准备

### 1. 环境要求

- Docker Engine 20.10+
- Docker Compose v2.0+
- 至少 4GB 可用内存
- 至少 10GB 可用磁盘空间

### 2. 检查 Docker 环境

```bash
# 检查 Docker 版本
docker --version
# 期望输出: Docker version 20.10+

# 检查 Docker Compose 版本
docker compose version
# 期望输出: Docker Compose version v2.0+

# 检查 Docker 服务状态
docker info
```

### 3. 克隆项目

```bash
# 克隆项目（如果还没有）
git clone <repository-url> lianghuajy
cd lianghuajy
```

---

## 配置文件说明

### 1. 环境变量配置（.env 文件）

在项目根目录创建 `.env` 文件（可选，使用默认值则跳过）：

```bash
# PostgreSQL 配置
POSTGRES_PASSWORD=funcat_secure_password_2024
POSTGRES_PORT=5432

# Redis 配置
REDIS_PASSWORD=redis_secure_password_2024
REDIS_PORT=6379
REDIS_MAX_MEMORY=2gb

# InfluxDB 配置（可选）
INFLUXDB_ADMIN_USER=admin
INFLUXDB_ADMIN_PASSWORD=influxdb_password_2024
INFLUXDB_ADMIN_TOKEN=my-super-secret-auth-token
INFLUXDB_PORT=8181

# Tushare 数据源（如果需要）
TUSHARE_TOKEN=your_tushare_token_here

# Web UI 配置
WEBUI_PORT=8080

# 日志配置
LOG_LEVEL=info

# 选股服务配置
SELECTOR_INTERVAL=60  # 选股间隔（分钟）
```

### 2. 选股服务配置文件

配置文件路径：`deployment/config/selector.yaml`

如果不存在，服务会使用环境变量配置，无需手动创建。

### 3. 数据库初始化脚本

已包含的SQL脚本：

```
deployment/sql/
├── schema.sql                 # 基础表结构（涨跌停数据等）
├── init_data.sql             # 初始化数据
└── 05-yangjia_schema.sql     # 炒股养家心法表结构
```

---

## 启动步骤

### 方式一：快速启动（推荐）

适用于首次部署或测试环境。

```bash
# 进入项目目录
cd /home/user/lianghuajy

# 一键启动所有核心服务
docker-compose up -d postgres redis webui selector

# 查看启动日志
docker-compose logs -f
```

Docker Compose 会自动：
1. 拉取/构建所需镜像
2. 创建网络和数据卷
3. 按依赖顺序启动服务
4. 等待健康检查通过

### 方式二：分步启动（生产环境推荐）

提供更好的控制和错误排查。

#### 步骤 1: 启动数据库服务

```bash
# 启动 PostgreSQL
docker-compose up -d postgres

# 等待数据库准备就绪（约10-30秒）
docker-compose logs -f postgres

# 看到以下日志表示成功：
# database system is ready to accept connections
```

#### 步骤 2: 初始化数据库表结构

```bash
# 导入基础表结构
docker-compose exec -T postgres psql -U funcat_user -d funcat < deployment/sql/schema.sql

# 导入炒股养家心法表结构
docker-compose exec -T postgres psql -U funcat_user -d funcat < deployment/sql/05-yangjia_schema.sql

# 验证表创建成功
docker-compose exec postgres psql -U funcat_user -d funcat -c "\dt"
```

预期输出应包含以下表：
- `limit_up_data` - 涨停数据
- `limit_down_data` - 跌停数据
- `sector_stats` - 板块统计
- `yangjia_select_results` - 炒股养家选股结果
- 等等...

#### 步骤 3: 启动 Redis 缓存

```bash
# 启动 Redis
docker-compose up -d redis

# 验证 Redis 运行状态
docker-compose exec redis redis-cli ping
# 期望输出: PONG
```

#### 步骤 4: 启动 Web UI 服务

```bash
# 启动 Web UI（会自动等待 postgres 和 redis 健康）
docker-compose up -d webui

# 查看启动日志
docker-compose logs -f webui

# 看到以下日志表示成功：
# Server started on :8080
```

#### 步骤 5: 启动选股服务

```bash
# 启动选股服务
docker-compose up -d selector

# 查看选股服务日志
docker-compose logs -f selector

# 看到以下日志表示成功：
# === Funcat 选股服务启动 ===
# 数据库连接成功
# 执行首次选股任务...
```

### 方式三：启动可选服务

#### 启动 InfluxDB 时序数据库

```bash
# 使用 --profile full 启动
docker-compose --profile full up -d influxdb

# 访问 InfluxDB UI
# http://localhost:8181
```

#### 启动监控服务

```bash
# 启动 Prometheus + Grafana
docker-compose --profile monitoring up -d prometheus grafana

# 访问 Prometheus: http://localhost:9090
# 访问 Grafana: http://localhost:3000
#   默认用户名: admin
#   默认密码: grafana_password_change_me (可在.env中修改)
```

---

## 验证服务

### 1. 检查服务状态

```bash
# 查看所有运行的容器
docker-compose ps

# 期望输出（健康的服务）：
# NAME                STATUS              PORTS
# funcat-postgres     Up (healthy)        0.0.0.0:5432->5432/tcp
# funcat-redis        Up (healthy)        0.0.0.0:6379->6379/tcp
# funcat-webui        Up (healthy)        0.0.0.0:8080->8080/tcp
# funcat-selector     Up
```

### 2. 测试数据库连接

```bash
# 测试 PostgreSQL
docker-compose exec postgres psql -U funcat_user -d funcat -c "SELECT version();"

# 测试 Redis
docker-compose exec redis redis-cli -a ${REDIS_PASSWORD} ping
```

### 3. 测试 Web UI

```bash
# 测试健康检查端点
curl http://localhost:8080/api/v1/health

# 期望输出：
# {"status":"ok","timestamp":"2024-12-22T10:00:00Z"}

# 在浏览器中访问
# http://localhost:8080
```

应该能看到：
- 📊 涨跌停数据看板
- 🔥 炒股养家心法选股入口
- 📈 连板天梯

### 4. 查看选股服务日志

```bash
# 实时查看选股服务日志
docker-compose logs -f selector

# 正常日志示例：
# === Funcat 选股服务启动 ===
# 配置加载成功: DB=funcat, Host=postgres
# 数据库连接成功
# 最近7天涨停数据: 156 条
# 最新交易日: 2024-12-22
# 执行首次选股任务...
# 今日涨停股票: 43 只
# 活跃板块: 5 个
#   新能源: 8 只涨停
#   半导体: 5 只涨停
# 炒股养家选股完成: 15 只股票
# 选股任务完成，耗时: 1.23s
# 选股服务运行中，每 60 分钟执行一次...
```

---

## 服务管理

### 停止服务

```bash
# 停止所有服务
docker-compose down

# 停止特定服务
docker-compose stop webui selector

# 停止并删除数据卷（危险！会删除所有数据）
docker-compose down -v
```

### 重启服务

```bash
# 重启所有服务
docker-compose restart

# 重启特定服务
docker-compose restart webui

# 重新构建并启动（代码更新后）
docker-compose up -d --build webui selector
```

### 查看日志

```bash
# 查看所有服务日志
docker-compose logs

# 实时跟踪日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f selector

# 查看最近100行日志
docker-compose logs --tail=100 selector
```

### 进入容器调试

```bash
# 进入 PostgreSQL 容器
docker-compose exec postgres bash
docker-compose exec postgres psql -U funcat_user -d funcat

# 进入 Redis 容器
docker-compose exec redis sh
docker-compose exec redis redis-cli

# 进入 Web UI 容器
docker-compose exec webui sh

# 进入选股服务容器
docker-compose exec selector sh
```

---

## 常见问题

### Q1: 服务启动失败，提示端口被占用

```bash
# 错误信息：
# Error: bind: address already in use

# 解决方案：
# 1. 检查端口占用
netstat -tlnp | grep 8080
lsof -i :8080

# 2. 修改 .env 文件中的端口
WEBUI_PORT=8081

# 3. 重新启动
docker-compose up -d
```

### Q2: PostgreSQL 健康检查失败

```bash
# 查看详细日志
docker-compose logs postgres

# 常见原因：
# 1. 数据库初始化需要时间（等待30秒）
# 2. 密码配置错误（检查 .env 文件）
# 3. 数据卷权限问题

# 解决方案：
# 删除数据卷重新初始化
docker-compose down -v
docker-compose up -d postgres
```

### Q3: 选股服务无法连接数据库

```bash
# 查看选股服务日志
docker-compose logs selector

# 错误示例：
# dial tcp: lookup postgres: no such host

# 解决方案：
# 确保 postgres 服务已启动且健康
docker-compose ps postgres

# 检查网络连接
docker-compose exec selector ping -c 3 postgres

# 重启选股服务
docker-compose restart selector
```

### Q4: Web UI 显示 "数据库连接失败"

```bash
# 检查步骤：
# 1. 确认 PostgreSQL 正在运行
docker-compose ps postgres

# 2. 验证数据库表是否创建
docker-compose exec postgres psql -U funcat_user -d funcat -c "\dt"

# 3. 检查环境变量配置
docker-compose exec webui env | grep POSTGRES

# 4. 重新导入数据库表结构
docker-compose exec -T postgres psql -U funcat_user -d funcat < deployment/sql/schema.sql
```

### Q5: 镜像构建失败（网络问题）

```bash
# Go 依赖下载失败
# 错误: dial tcp: connect: connection refused

# 解决方案：
# 1. Dockerfile 已配置国内镜像源（GOPROXY=https://goproxy.cn）
# 2. 清理构建缓存重试
docker-compose build --no-cache selector

# 3. 检查网络连接
curl -I https://goproxy.cn
```

### Q6: 数据持久化问题

```bash
# 查看数据卷
docker volume ls | grep funcat

# 查看数据卷详情
docker volume inspect lianghuajy_postgres_data

# 备份数据卷
docker run --rm -v lianghuajy_postgres_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/postgres-backup.tar.gz /data

# 恢复数据卷
docker run --rm -v lianghuajy_postgres_data:/data -v $(pwd):/backup \
  alpine tar xzf /backup/postgres-backup.tar.gz -C /
```

---

## 性能优化建议

### 1. PostgreSQL 优化

编辑 `deployment/config/postgresql.conf`：

```ini
# 连接数
max_connections = 100

# 内存配置（根据服务器资源调整）
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 16MB

# 日志
log_min_duration_statement = 1000  # 记录慢查询（>1秒）
```

### 2. Redis 优化

在 docker-compose.yml 中调整：

```yaml
redis:
  command: >
    redis-server
    --maxmemory 2gb
    --maxmemory-policy allkeys-lru
```

### 3. 资源限制

在 docker-compose.yml 中配置：

```yaml
selector:
  deploy:
    resources:
      limits:
        cpus: '2'
        memory: 2G
      reservations:
        cpus: '0.5'
        memory: 512M
```

---

## 生产环境部署建议

### 1. 安全配置

- ✅ 修改所有默认密码
- ✅ 使用环境变量管理敏感信息
- ✅ 启用 SSL/TLS 加密
- ✅ 配置防火墙规则
- ✅ 定期更新镜像和依赖

### 2. 备份策略

```bash
# 每日备份 PostgreSQL
0 2 * * * docker-compose exec -T postgres pg_dump -U funcat_user funcat > /backup/funcat_$(date +\%Y\%m\%d).sql

# 每周备份数据卷
0 3 * * 0 docker run --rm -v lianghuajy_postgres_data:/data -v /backup:/backup alpine tar czf /backup/data_$(date +\%Y\%m\%d).tar.gz /data
```

### 3. 监控告警

使用 Prometheus + Grafana：

```bash
# 启动监控栈
docker-compose --profile monitoring up -d prometheus grafana

# 配置告警规则
# 编辑 deployment/config/prometheus.yml
```

### 4. 日志管理

```yaml
# docker-compose.yml 中已配置日志轮转
logging:
  driver: "json-file"
  options:
    max-size: "50m"
    max-file: "5"
```

---

## 附录

### A. 完整服务列表

| 服务 | 镜像 | 说明 |
|------|------|------|
| postgres | postgres:13-alpine | PostgreSQL 数据库 |
| redis | redis:6-alpine | Redis 缓存 |
| influxdb | influxdb:3.5.0-core | InfluxDB 时序数据库 |
| selector | funcat/selector:2.0.0 | Go 选股服务 |
| webui | funcat/webui:2.0.0 | Go + Vue3 Web界面 |
| nginx | nginx:alpine | 反向代理 |
| prometheus | prom/prometheus:latest | 监控服务 |
| grafana | grafana/grafana:latest | 可视化面板 |

### B. 端口映射

| 服务 | 内部端口 | 外部端口 | 说明 |
|------|---------|---------|------|
| postgres | 5432 | 5432 | PostgreSQL |
| redis | 6379 | 6379 | Redis |
| influxdb | 8181 | 8181 | InfluxDB 3.x |
| webui | 8080 | 8080 | Web UI |
| nginx | 80, 443 | 80, 443 | HTTP/HTTPS |
| prometheus | 9090 | 9090 | Prometheus |
| grafana | 3000 | 3000 | Grafana |

### C. 数据卷列表

```bash
# PostgreSQL 数据
postgres_data

# Redis 数据
redis_data

# InfluxDB 数据
influxdb_data
influxdb_home

# 选股服务
selector_logs
selector_data

# Web UI
webui_logs

# 监控数据
prometheus_data
grafana_data
```

---

## 总结

本指南涵盖了 Funcat 系统的完整 Docker 部署流程。遵循以下最佳实践：

1. ✅ **分步启动** - 先数据库，后应用
2. ✅ **验证每步** - 确保每个服务健康再继续
3. ✅ **查看日志** - 出问题立即检查日志
4. ✅ **备份数据** - 定期备份重要数据
5. ✅ **监控服务** - 使用监控工具跟踪状态

更多帮助请参考：
- [WEB_UI_GUIDE.md](./WEB_UI_GUIDE.md) - Web UI 使用指南
- [YANGJIA_GUIDE.md](./YANGJIA_GUIDE.md) - 炒股养家心法说明
- [DOCKER_DEPLOYMENT.md](./DOCKER_DEPLOYMENT.md) - Docker 部署详细文档

---

**文档版本**: v2.0.0
**最后更新**: 2024-12-22
**维护者**: Funcat Team
