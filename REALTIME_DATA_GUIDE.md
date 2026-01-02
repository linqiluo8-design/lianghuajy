# 实时行情采集系统使用指南

## 📋 系统简介

本系统支持从多个数据源获取 **2-5秒延迟** 的实时行情数据，并自动写入数据库供 Web UI 展示。

### 🎯 核心特性

- ✅ **双数据源支持**：AkShare + pytdx（通达信）
- ✅ **2秒刷新**：每2秒自动拉取最新行情
- ✅ **自动入库**：涨跌停数据自动写入 PostgreSQL
- ✅ **Web 切换**：页面上可动态切换数据源
- ✅ **完全免费**：两个数据源都免费使用

---

## 🚀 快速开始

### 1. 安装依赖

```bash
# 安装 Python 依赖
pip install akshare pytdx pyyaml psycopg2-binary

# 或使用 requirements.txt
pip install -r requirements-realtime.txt
```

### 2. 配置数据源

编辑 `config/realtime.yaml`：

```yaml
# 数据源类型: akshare 或 pytdx
data_source:
  type: akshare  # 默认使用 AkShare
  refresh_interval: 2  # 刷新间隔（秒）
```

或通过环境变量配置（`.env` 文件）：

```bash
# 数据源选择
REALTIME_DATA_SOURCE=akshare  # 或 pytdx

# 刷新间隔
REALTIME_REFRESH_INTERVAL=2
```

### 3. 启动实时采集服务

```bash
# 方式1：使用启动脚本（推荐）
./scripts/start-realtime-service.sh

# 方式2：直接运行 Python
python3 services/realtime_fetcher.py

# 方式3：指定数据源
python3 services/realtime_fetcher.py --source akshare
python3 services/realtime_fetcher.py --source pytdx
```

### 4. 访问 Web UI

打开浏览器访问：http://localhost:8080

在页面顶部可以看到：
- **数据源选择器**：下拉框切换 AkShare / pytdx
- **服务状态**：显示当前运行状态和数据源

---

## 📊 数据源对比

| 数据源 | 延迟 | 稳定性 | 安装难度 | 推荐指数 |
|--------|------|--------|----------|----------|
| **AkShare** | 3-5秒 | ⭐⭐⭐⭐ | 简单 | ⭐⭐⭐⭐⭐ |
| **pytdx** | 2-3秒 | ⭐⭐⭐⭐⭐ | 简单 | ⭐⭐⭐⭐⭐ |

### AkShare（推荐新手）

**优点**：
- ✅ 安装即用，无需配置
- ✅ 数据源稳定（东方财富）
- ✅ 支持多市场（股票、基金、期货等）
- ✅ 文档完善，社区活跃

**缺点**：
- ❌ 延迟稍大（3-5秒）

**适用场景**：
- 个人实时监控
- 盘中选股
- 板块分析

---

### pytdx（推荐追求稳定性）

**优点**：
- ✅ 延迟最低（2-3秒）
- ✅ 稳定性最好
- ✅ 基于通达信，数据质量高
- ✅ 支持5档行情

**缺点**：
- ❌ 需要连接通达信服务器
- ❌ 偶尔需要切换服务器

**适用场景**：
- 专业量化交易
- 日内T+0操作
- 对延迟敏感的场景

---

## 🔧 详细配置

### config/realtime.yaml

完整配置示例：

```yaml
# 数据源配置
data_source:
  type: akshare  # akshare 或 pytdx
  refresh_interval: 2  # 刷新间隔（秒）

# AkShare 配置
akshare:
  timeout: 10

# pytdx 配置
pytdx:
  # 通达信服务器列表
  servers:
    - ['119.147.212.81', 7709]
    - ['114.80.63.12', 7709]
    - ['114.80.63.35', 7709]
  timeout: 5

# 数据库配置
database:
  host: localhost
  port: 5432
  database: funcat
  user: funcat_user
  password: funcat_password

# 数据过滤
filter:
  only_limit: true  # 只保存涨跌停
  min_price: 1.0    # 最低价格（元）
  exclude_st: false  # 排除ST股票

# 日志配置
logging:
  level: INFO
  file: logs/realtime_fetcher.log
```

---

## 💻 在 Web UI 中使用

### 1. 查看服务状态

页面顶部显示：
- 🟢 **运行中 (akshare)** - 服务正常
- 🔴 **未启动** - 服务未运行
- 🟡 **切换中...** - 正在切换数据源

### 2. 切换数据源

1. 点击数据源下拉框
2. 选择 "AkShare" 或 "通达信"
3. 系统自动切换并重新连接
4. 状态栏显示切换结果

### 3. 查看实时数据

- **涨停数**：实时更新
- **板块强度**：每2秒刷新
- **个股详情**：点击查看最新数据

---

## 🔥 进阶使用

### 后台运行服务

```bash
# 使用 nohup 后台运行
nohup python3 services/realtime_fetcher.py --source akshare > logs/realtime.log 2>&1 &

# 查看进程
ps aux | grep realtime_fetcher

# 停止服务
pkill -f realtime_fetcher
```

### 使用 systemd 管理（推荐生产环境）

创建服务文件 `/etc/systemd/system/funcat-realtime.service`：

```ini
[Unit]
Description=Funcat Realtime Data Fetcher
After=network.target postgresql.service

[Service]
Type=simple
User=your_user
WorkingDirectory=/path/to/lianghuajy
ExecStart=/usr/bin/python3 services/realtime_fetcher.py --source akshare
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

启动服务：

```bash
sudo systemctl enable funcat-realtime
sudo systemctl start funcat-realtime
sudo systemctl status funcat-realtime
```

### Docker 部署

添加到 `docker-compose.yml`：

```yaml
services:
  realtime-fetcher:
    build: .
    command: python3 services/realtime_fetcher.py --source akshare
    environment:
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_NAME=funcat
      - DB_USER=funcat_user
      - DB_PASSWORD=${POSTGRES_PASSWORD}
      - REALTIME_DATA_SOURCE=akshare
    depends_on:
      - postgres
    restart: unless-stopped
    volumes:
      - ./config:/app/config
      - ./logs:/app/logs
```

启动：

```bash
docker-compose up -d realtime-fetcher
```

---

## 📈 性能优化

### 1. 调整刷新间隔

```yaml
# config/realtime.yaml
data_source:
  refresh_interval: 3  # 改为3秒，降低服务器压力
```

### 2. 过滤仙股

```yaml
filter:
  min_price: 2.0  # 只保存价格 >= 2元的股票
```

### 3. 只保存涨跌停

```yaml
filter:
  only_limit: true  # 只保存涨停和跌停股票
```

---

## 🐛 故障排查

### 问题1：AkShare 获取数据失败

```
❌ AkShare 获取实时行情失败: ...
```

**解决方案**：
1. 检查网络连接
2. 更新 AkShare：`pip install --upgrade akshare`
3. 尝试切换到 pytdx

### 问题2：pytdx 连接超时

```
❌ 所有通达信服务器连接失败
```

**解决方案**：
1. 检查防火墙设置
2. 尝试其他服务器（编辑 `config/realtime.yaml`）
3. 切换回 AkShare

### 问题3：数据库连接失败

```
❌ 数据库连接失败: ...
```

**解决方案**：
1. 检查 PostgreSQL 是否运行
2. 确认数据库配置正确
3. 检查数据库用户权限

### 问题4：Web UI 显示"未启动"

**解决方案**：
1. 确认实时服务已启动
2. 检查服务日志：`tail -f logs/realtime_fetcher.log`
3. 刷新浏览器页面

---

## 📝 常见问题

### Q1：两个数据源有什么区别？

| 对比项 | AkShare | pytdx |
|--------|---------|-------|
| 延迟 | 3-5秒 | 2-3秒 |
| 稳定性 | 较好 | 最好 |
| 安装 | pip install | pip install |
| 配置 | 无需配置 | 无需配置 |
| 推荐场景 | 日常监控 | 专业交易 |

### Q2：可以同时运行两个数据源吗？

不建议。两个服务会互相覆盖数据，建议选择一个使用。

### Q3：数据会自动保存到数据库吗？

是的。服务每2秒拉取数据后，会自动将涨跌停股票保存到 `daily_limit_stats` 表。

### Q4：如何查看采集日志？

```bash
# 查看实时日志
tail -f logs/realtime_fetcher.log

# 查看最近100行
tail -n 100 logs/realtime_fetcher.log
```

### Q5：服务占用多少资源？

- **CPU**：<5%
- **内存**：约 100-200 MB
- **网络**：每次请求约 50-100 KB

### Q6：可以只在交易时间运行吗？

可以。使用 crontab 定时启动和停止：

```bash
# 9:25 启动
25 9 * * 1-5 /path/to/scripts/start-realtime-service.sh &

# 15:05 停止
5 15 * * 1-5 pkill -f realtime_fetcher
```

---

## 🎯 最佳实践

### 开发/测试环境

```bash
# 使用 AkShare，简单方便
export REALTIME_DATA_SOURCE=akshare
./scripts/start-realtime-service.sh
```

### 生产环境

```bash
# 使用 pytdx，更稳定
export REALTIME_DATA_SOURCE=pytdx

# 使用 systemd 管理
sudo systemctl start funcat-realtime

# 配置监控告警
# ...
```

### 日内交易

```bash
# 使用 pytdx，延迟最低
python3 services/realtime_fetcher.py --source pytdx

# 降低刷新间隔到1秒
# 编辑 config/realtime.yaml: refresh_interval: 1
```

---

## 📚 相关文档

- [AkShare 官方文档](https://akshare.akfamily.xyz/)
- [pytdx GitHub](https://github.com/rainx/pytdx)
- [数据源配置指南](DATA_SOURCE_GUIDE.md)
- [系统架构文档](SYSTEM_ARCHITECTURE.md)

---

## 💡 总结

- **新手推荐**：使用 **AkShare**，简单稳定
- **专业用户**：使用 **pytdx**，延迟更低
- **生产环境**：配合 systemd + 监控告警
- **随时切换**：Web UI 一键切换数据源

开始享受 **2秒刷新** 的实时行情吧！🚀
