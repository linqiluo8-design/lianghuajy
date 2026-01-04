# 实时行情采集服务 - Docker 部署指南

## 📋 概述

实时行情采集服务通过 Docker 容器运行，自动从配置的数据源（AkShare 或 pytdx）采集股票实时行情，并将涨跌停数据保存到 PostgreSQL 数据库。

## 🚀 快速开始

### 1. 启动服务

```bash
# 方法一：使用启动脚本（推荐）
./scripts/start-realtime-docker.sh

# 方法二：使用 docker compose 命令
docker compose up -d realtime
```

### 2. 查看服务状态

```bash
# 查看运行状态
docker compose ps realtime

# 查看实时日志
docker compose logs -f realtime
```

### 3. 验证服务

打开 Web UI (http://192.168.92.129:8081)，数据源状态应该从 🔴 **离线** 变为 🟢 **运行中 (akshare)**。

## ⚙️ 配置说明

### 环境变量配置（.env 文件）

```bash
# 数据源类型
REALTIME_DATA_SOURCE=akshare  # 或 pytdx

# 刷新间隔（秒）
REALTIME_REFRESH_INTERVAL=2

# 数据库配置（自动从 docker-compose.yml 注入）
POSTGRES_PASSWORD=funcat_password_change_me
```

### 数据源对比

| 数据源 | 延迟 | 稳定性 | 推荐度 | 说明 |
|--------|------|--------|--------|------|
| **akshare** | 3-5秒 | ⭐⭐⭐⭐ | 推荐 | 免费，无需安装其他软件，默认选项 |
| **pytdx** | 2-3秒 | ⭐⭐⭐⭐⭐ | 推荐 | 免费，最低延迟，基于通达信 |

### 切换数据源

#### 方法一：修改 .env 文件（推荐）

```bash
# 1. 编辑 .env 文件
vi .env

# 2. 修改配置
REALTIME_DATA_SOURCE=pytdx

# 3. 重启服务
docker compose restart realtime
```

#### 方法二：临时切换

```bash
# 临时使用 pytdx
REALTIME_DATA_SOURCE=pytdx docker compose up -d realtime
```

## 🔧 常用操作

### 查看日志

```bash
# 查看最新 50 行日志
docker compose logs --tail=50 realtime

# 实时跟踪日志
docker compose logs -f realtime

# 查看完整日志
docker compose logs realtime
```

### 重启服务

```bash
# 重启服务（不重新构建）
docker compose restart realtime

# 完全重启（包括重新构建）
docker compose stop realtime
docker compose build realtime
docker compose up -d realtime
```

### 停止服务

```bash
# 停止服务
docker compose stop realtime

# 停止并删除容器
docker compose down realtime
```

### 进入容器调试

```bash
# 进入容器 shell
docker compose exec realtime /bin/bash

# 查看配置
docker compose exec realtime cat config/realtime.yaml

# 测试数据源连接
docker compose exec realtime python3 -c "
from services.data_sources import AkShareSource
source = AkShareSource({})
print('连接结果:', source.connect())
"
```

## 📊 服务监控

### 查看采集统计

```bash
# 实时日志会显示采集统计
docker compose logs -f realtime

# 输出示例：
# 📊 第 123 次采集: 总数=5123, 涨跌停=45, 保存=45
```

### 数据库验证

```bash
# 查看今日涨跌停数据
docker compose exec postgres psql -U funcat_user -d funcat -c "
SELECT
    COUNT(*) as 总数,
    COUNT(*) FILTER (WHERE limit_type='limit_up') as 涨停,
    COUNT(*) FILTER (WHERE limit_type='limit_down') as 跌停,
    COUNT(*) FILTER (WHERE is_one_word=true) as 一字板
FROM daily_limit_stats
WHERE trade_date = CURRENT_DATE;
"
```

### Web UI 状态指示器

在 Web UI 首页顶部，数据源选择器旁边会显示服务状态：

- 🔴 **离线** - 服务未运行或无法连接数据库
- 🟢 **运行中 (akshare)** - AkShare 数据源正常工作
- 🟢 **运行中 (pytdx)** - 通达信数据源正常工作

## 🐛 故障排查

### 问题1：服务无法启动

**症状**：`docker compose up -d realtime` 失败

**解决方案**：
```bash
# 1. 查看详细错误
docker compose logs realtime

# 2. 检查镜像是否构建成功
docker compose build realtime

# 3. 检查依赖服务
docker compose ps postgres
```

### 问题2：数据库连接失败

**症状**：日志显示 "❌ 数据库连接失败"

**解决方案**：
```bash
# 1. 确认 PostgreSQL 服务运行正常
docker compose ps postgres

# 2. 测试数据库连接
docker compose exec postgres psql -U funcat_user -d funcat -c "SELECT 1"

# 3. 检查环境变量
docker compose exec realtime env | grep DB_
```

### 问题3：数据源连接失败

**症状**：日志显示 "❌ 数据源 xxx 连接失败"

**解决方案**：
```bash
# AkShare 数据源
# 1. 检查网络连接
docker compose exec realtime ping -c 3 www.baidu.com

# 2. 测试 AkShare
docker compose exec realtime python3 -c "import akshare as ak; print(ak.__version__)"

# pytdx 数据源
# 1. 测试通达信服务器连接
docker compose exec realtime python3 -c "
from pytdx.hq import TdxHq_API
api = TdxHq_API()
result = api.connect('119.147.212.81', 7709)
print('连接结果:', result)
api.disconnect()
"
```

### 问题4：Web UI 显示"离线"

**可能原因**：
1. 实时服务未启动
2. 数据库连接异常
3. 服务刚启动，还未完成第一次采集

**解决方案**：
```bash
# 1. 检查服务状态
docker compose ps realtime

# 2. 查看最新日志
docker compose logs --tail=30 realtime

# 3. 等待几秒后刷新页面（强制刷新：Ctrl+Shift+R）
```

## 📈 性能优化

### 资源限制调整

编辑 `docker-compose.yml` 中的资源限制：

```yaml
realtime:
  deploy:
    resources:
      limits:
        cpus: '2'      # 增加到 2 核
        memory: 1G     # 增加到 1GB
```

### 刷新间隔调整

```bash
# 编辑 .env 文件
REALTIME_REFRESH_INTERVAL=5  # 改为 5 秒刷新一次

# 重启服务
docker compose restart realtime
```

## 🔄 更新服务

### 拉取最新代码

```bash
# 1. 停止服务
docker compose stop realtime

# 2. 拉取代码
git pull origin <branch-name>

# 3. 重新构建镜像
docker compose build --no-cache realtime

# 4. 启动服务
docker compose up -d realtime
```

### 自动更新脚本

```bash
#!/bin/bash
# scripts/update-realtime.sh

docker compose stop realtime
git pull
docker compose build --no-cache realtime
docker compose up -d realtime
docker compose logs --tail=20 -f realtime
```

## 📝 日志管理

### 日志配置

日志存储在 Docker 卷 `realtime_logs` 中：

```bash
# 查看日志卷位置
docker volume inspect funcat_realtime_logs

# 日志轮转配置（docker-compose.yml）
logging:
  driver: "json-file"
  options:
    max-size: "50m"  # 单个文件最大 50MB
    max-file: "5"    # 最多保留 5 个文件
```

### 清理日志

```bash
# 方法一：重启容器（会重置 JSON 日志）
docker compose restart realtime

# 方法二：删除并重建（会清空所有日志）
docker compose rm -f realtime
docker compose up -d realtime
```

## 🎯 最佳实践

1. **监控日志**：定期查看日志确保服务正常运行
   ```bash
   docker compose logs --tail=100 realtime
   ```

2. **数据验证**：定期验证数据库中的数据
   ```bash
   docker compose exec postgres psql -U funcat_user -d funcat -c "
   SELECT trade_date, COUNT(*) FROM daily_limit_stats
   GROUP BY trade_date ORDER BY trade_date DESC LIMIT 5;
   "
   ```

3. **资源监控**：关注容器资源使用
   ```bash
   docker stats funcat-realtime
   ```

4. **定期更新**：保持代码和依赖项最新
   ```bash
   git pull && docker compose build realtime && docker compose up -d realtime
   ```

5. **备份配置**：备份 .env 和 config/realtime.yaml
   ```bash
   cp .env .env.backup
   cp config/realtime.yaml config/realtime.yaml.backup
   ```

## 🔗 相关文档

- [实时数据源对比](../REALTIME_DATA_GUIDE.md)
- [Docker Compose 完整配置](../docker-compose.yml)
- [故障排查完整手册](../deployment/docs/troubleshooting.md)

## 📞 获取帮助

如遇到问题，请：
1. 查看日志：`docker compose logs realtime`
2. 检查服务状态：`docker compose ps realtime`
3. 参考本文档的故障排查部分
4. 提交 Issue 并附上完整日志
