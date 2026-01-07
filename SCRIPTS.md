# 脚本使用手册

本文档提供项目中所有自动化脚本的快速参考。

## 📋 目录

- [部署脚本](#部署脚本)
- [数据管理脚本](#数据管理脚本)
- [脚本设计原理](#脚本设计原理)

---

## 部署脚本

### deploy-from-scratch.sh - 智能部署脚本

**功能：** 完整的从 0 到生产的自动化部署，支持智能增量构建

**位置：** `./deploy-from-scratch.sh`

#### 快速使用

```bash
# 日常代码更新（推荐）
bash deploy-from-scratch.sh

# 首次部署或磁盘清理后
bash deploy-from-scratch.sh --clean

# 强制重新构建所有服务
bash deploy-from-scratch.sh --force-rebuild

# 跳过代码更新（使用本地代码）
bash deploy-from-scratch.sh --skip-update
```

#### 参数详解

| 参数 | 说明 | 使用场景 | 执行时间 |
|------|------|---------|---------|
| 无参数 | 智能增量构建 | 日常代码更新 | 30秒 - 10分钟 |
| `--clean` | 清理所有数据重建 | 首次部署、磁盘清理后 | 10-15分钟 |
| `--skip-update` | 跳过 git pull | 本地代码测试 | 取决于其他参数 |
| `--force-rebuild` | 强制无缓存重建 | 解决缓存问题 | 10-15分钟 |

#### 参数组合示例

```bash
# 清理数据 + 使用本地代码（适合从零开始测试）
bash deploy-from-scratch.sh --clean --skip-update

# 清理数据 + 强制重建（最彻底的重新部署）
bash deploy-from-scratch.sh --clean --force-rebuild

# 跳过更新 + 强制重建（本地代码 + 清理缓存）
bash deploy-from-scratch.sh --skip-update --force-rebuild
```

#### 部署流程

脚本执行 11 个步骤：

```
1.  检查 Docker 环境
2.  更新代码（git pull）
2.5 检测服务变更（智能增量构建决策）
3.  停止现有服务
4.  启动基础服务（PostgreSQL + Redis）
5.  初始化数据库
6.  运行数据库迁移
7.  构建并启动应用服务
8.  采集实时数据（AkShare）
9.  聚合板块数据
10. 验证部署结果
11. 显示访问信息
```

#### 智能增量构建

脚本会自动检测文件变更，只重新构建有变化的服务：

**realtime 服务触发规则：**
```
services/                          → 重建 realtime
config/                            → 重建 realtime
requirements.txt                   → 重建 realtime
deployment/docker/Dockerfile.realtime → 重建 realtime
```

**webui 服务触发规则：**
```
web-ui/backend/                    → 重建 webui
docker-compose.yml                 → 重建 webui
```

**数据库迁移检测：**
```
migrations/                        → 提示迁移
deployment/sql/                    → 提示迁移
```

#### 性能数据

| 场景 | 预计时间 | 说明 |
|------|---------|------|
| 无变更 | 30 秒 | 跳过构建，仅重启服务 |
| 单服务变更 | 2-3 分钟 | 只构建一个服务 |
| 双服务变更 | 5-10 分钟 | 构建两个服务 |
| 强制重建 | 10-15 分钟 | 无缓存全量重建 |

#### 使用场景示例

##### 场景 1: 修改了数据采集逻辑

```bash
# 修改了 services/data_sources/akshare_source.py
vim services/data_sources/akshare_source.py

# 提交代码
git add services/data_sources/akshare_source.py
git commit -m "fix: 修复数据采集逻辑"
git push

# 部署（自动检测到 services/ 变更，只重建 realtime）
bash deploy-from-scratch.sh
```

**输出示例：**
```
检测服务变更...
✓ 检测到 realtime 服务相关变更

服务构建计划：
  • realtime: 需要重新构建
  • webui: 跳过构建（无变更）

预计时间：2-3 分钟
```

##### 场景 2: 修改了前端 UI

```bash
# 修改了 web-ui/backend/static/index.html
vim web-ui/backend/static/index.html

# 提交并部署
git add web-ui/backend/static/index.html
git commit -m "feat: 更新看板 UI"
git push
bash deploy-from-scratch.sh
```

**输出示例：**
```
服务构建计划：
  • realtime: 跳过构建（无变更）
  • webui: 需要重新构建

预计时间：2-3 分钟
```

##### 场景 3: 两个服务都没变

```bash
# 只是想更新数据，代码没变
bash deploy-from-scratch.sh
```

**输出示例：**
```
未检测到文件变更，跳过构建检查

服务构建计划：
  • realtime: 跳过构建（无变更）
  • webui: 跳过构建（无变更）

预计时间：30 秒
```

##### 场景 4: 磁盘满清理后重新部署

```bash
# 1. 先清理历史数据
bash cleanup-old-data.sh

# 2. 完全重新部署
bash deploy-from-scratch.sh --clean
```

##### 场景 5: Docker 缓存问题

```bash
# 强制无缓存重建所有服务
bash deploy-from-scratch.sh --force-rebuild
```

#### 环境变量

脚本支持以下环境变量配置：

```bash
# PostgreSQL 配置
export POSTGRES_PASSWORD="your_password"

# Redis 配置
export REDIS_PASSWORD="your_redis_password"

# Web UI 端口
export WEBUI_PORT=8080

# 然后运行部署
bash deploy-from-scratch.sh
```

#### 故障排查

**问题 1: Git pull 失败**

```bash
# 解决方案 1: 暂存本地更改
git stash
bash deploy-from-scratch.sh

# 解决方案 2: 跳过代码更新
bash deploy-from-scratch.sh --skip-update
```

**问题 2: Docker 构建失败**

```bash
# 清理 Docker 缓存
docker builder prune -a

# 强制重建
bash deploy-from-scratch.sh --force-rebuild
```

**问题 3: 数据库连接失败**

```bash
# 检查 PostgreSQL 日志
docker compose logs postgres

# 重启数据库
docker compose restart postgres

# 如果持续失败，清理重建
docker compose down -v
bash deploy-from-scratch.sh --clean
```

**问题 4: 看板无数据**

```bash
# 1. 检查是否为交易日
date  # 周末和节假日无数据

# 2. 手动重新采集数据
docker compose exec realtime python3 -c 'from services.data_sources.akshare_source import AkShareDataSource; AkShareDataSource().fetch_and_store()'

# 3. 手动重新聚合
docker compose exec realtime python3 -c 'from services.sector_aggregator import SectorAggregator; a = SectorAggregator(); a.connect(); a.aggregate(); a.close()'

# 4. 强制刷新浏览器
# Ctrl+Shift+R (Windows/Linux) 或 Cmd+Shift+R (Mac)
```

---

## 数据管理脚本

### cleanup-old-data.sh - 历史数据清理脚本

**功能：** 清理历史数据，只保留最新一天的数据

**位置：** `./cleanup-old-data.sh`

#### 快速使用

```bash
bash cleanup-old-data.sh
```

#### 执行流程

```
1. 显示当前数据状态
   - 每个交易日的记录数
   - 涨停/跌停统计
   - 最新数据日期

2. 确认删除操作
   - 需要输入 "YES" 确认
   - 其他输入取消操作

3. 执行清理
   - 删除 daily_limit_stats 历史数据
   - 删除 sector_daily_stats 历史数据
   - 删除 limit_reason_stats 历史数据
   - 使用事务保证一致性

4. 验证结果
   - 显示清理后的数据状态
   - 确认只剩最新一天
```

#### 清理的表

| 表名 | 说明 |
|------|------|
| `daily_limit_stats` | 个股涨跌停数据 |
| `sector_daily_stats` | 板块统计数据 |
| `limit_reason_stats` | 涨停原因统计 |

#### 使用示例

```bash
$ bash cleanup-old-data.sh

===============================================================================
📊 步骤 1/4: 当前数据状态
===============================================================================

--- daily_limit_stats 表 ---
 trade_date | record_count | limit_up | limit_down
------------+--------------+----------+------------
 2026-01-07 |          109 |      108 |          1
 2026-01-06 |          156 |      155 |          1
 2026-01-05 |          203 |      200 |          3
 2026-01-04 |          178 |      175 |          3
...

⚠️  将删除以下日期的数据：
  • 2026-01-06 之前的所有数据（共 4 个交易日）

✅ 将保留：
  • 2026-01-07 的数据（共 109 条记录）

===============================================================================
📝 步骤 2/4: 确认删除操作
===============================================================================

❓ 确定要继续吗？(输入 YES 继续，其他键取消): YES

===============================================================================
🗑️  步骤 3/4: 清理历史数据
===============================================================================

✅ 清理完成！

===============================================================================
✅ 步骤 4/4: 验证清理结果
===============================================================================

--- 清理后数据状态 ---
 trade_date | record_count
------------+--------------
 2026-01-07 |          109
```

#### 注意事项

⚠️ **此操作不可逆！** 删除后无法恢复历史数据，请谨慎使用。

建议：
- 定期清理（每周一次）
- 避免数据库膨胀
- 保持系统性能

---

## 脚本设计原理

### deploy-from-scratch.sh 设计文档

#### 架构设计

```
┌─────────────────────────────────────────┐
│         用户执行脚本                     │
│    bash deploy-from-scratch.sh          │
└─────────────────┬───────────────────────┘
                  │
        ┌─────────┴─────────┐
        │  参数解析器        │
        │  --clean           │
        │  --skip-update     │
        │  --force-rebuild   │
        └─────────┬─────────┘
                  │
        ┌─────────┴─────────┐
        │  环境检查          │
        │  Docker/Git        │
        └─────────┬─────────┘
                  │
        ┌─────────┴─────────┐
        │  代码管理          │
        │  git pull/stash    │
        └─────────┬─────────┘
                  │
        ┌─────────┴─────────┐
        │  变更检测引擎      │
        │  git diff 分析     │
        └─────────┬─────────┘
                  │
        ┌─────────┴─────────┐
        │  构建决策器        │
        │  智能增量构建      │
        └─────────┬─────────┘
                  │
    ┌─────────────┼─────────────┐
    │             │             │
┌───▼───┐   ┌────▼────┐   ┌───▼───┐
│ Skip  │   │ Build   │   │ Force │
│ Build │   │ Changed │   │ Build │
└───┬───┘   └────┬────┘   └───┬───┘
    │            │            │
    └────────────┼────────────┘
                 │
        ┌────────▼────────┐
        │  服务编排        │
        │  docker compose  │
        └────────┬────────┘
                 │
        ┌────────▼────────┐
        │  数据流水线      │
        │  采集 → 聚合     │
        └────────┬────────┘
                 │
        ┌────────▼────────┐
        │  验证与报告      │
        │  健康检查/摘要   │
        └─────────────────┘
```

#### 核心算法

**变更检测算法：**

```bash
# 1. 获取变更文件列表
CHANGED_FILES=$(git diff --name-only HEAD@{1} HEAD)

# 2. 模式匹配检测服务
if echo "$CHANGED_FILES" | grep -qE "^(services/|config/|requirements\.txt)"; then
    REBUILD_REALTIME=true
fi

if echo "$CHANGED_FILES" | grep -qE "^(web-ui/backend/|docker-compose\.yml)"; then
    REBUILD_WEBUI=true
fi

# 3. 构建决策
if [[ "$FORCE_REBUILD" == true ]]; then
    # 强制重建所有
    docker compose build --no-cache realtime webui
elif [[ "$REBUILD_REALTIME" == true ]]; then
    # 只重建 realtime
    docker compose build realtime
elif [[ "$REBUILD_WEBUI" == true ]]; then
    # 只重建 webui
    docker compose build webui
else
    # 跳过构建
    echo "跳过构建，仅重启服务"
fi
```

**Git Pull 重试机制：**

```bash
# 指数退避重试（2秒 → 4秒 → 8秒 → 16秒）
for i in {1..4}; do
    if git pull origin "$CURRENT_BRANCH" 2>&1; then
        echo "✅ 代码已更新"
        break
    else
        if [[ $i -lt 4 ]]; then
            WAIT_TIME=$((2 ** i))
            echo "⚠️  拉取失败，${WAIT_TIME}秒后重试..."
            sleep $WAIT_TIME
        else
            echo "❌ 拉取失败，使用当前代码"
        fi
    fi
done
```

#### 幂等性设计

脚本可以多次运行而不产生副作用：

1. **数据库初始化**
   ```sql
   CREATE TABLE IF NOT EXISTS ...
   ```

2. **数据库迁移**
   ```sql
   DO $$
   BEGIN
       IF NOT EXISTS (...) THEN
           ALTER TABLE ...
       END IF;
   END $$;
   ```

3. **服务启动**
   ```bash
   docker compose up -d  # 自动处理已存在的容器
   ```

#### 错误处理策略

```bash
set -e  # 遇到错误立即退出

# 关键步骤的错误处理
if [[ $? -eq 0 ]]; then
    log_success "操作成功"
else
    log_error "操作失败"
    log_info "查看日志: docker compose logs -f"
    exit 1
fi
```

#### 性能优化

1. **并行启动服务**
   ```bash
   docker compose up -d postgres redis  # 同时启动
   ```

2. **智能缓存利用**
   ```bash
   docker compose build  # 使用缓存
   docker compose build --no-cache  # 仅强制重建时
   ```

3. **增量构建**
   - 检测变更，避免不必要的构建
   - 性能提升：10-20 倍

#### 日志系统

使用彩色日志提升可读性：

```bash
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_success() {
    echo -e "${GREEN}✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠️ ${NC} $1"
}

log_error() {
    echo -e "${RED}❌${NC} $1"
}

log_info() {
    echo -e "${BLUE}ℹ ${NC} $1"
}
```

---

## 相关文档

- 📖 [完整部署指南](DEPLOYMENT.md) - 详细使用说明、CICD 集成
- 📖 [项目主文档](README.md) - 项目介绍和快速开始
- 📖 [Docker Compose 配置](docker-compose.yml) - 容器编排配置

---

## 最佳实践

### 日常工作流

```bash
# 1. 开发代码
vim services/data_sources/akshare_source.py

# 2. 测试
bash deploy-from-scratch.sh --skip-update

# 3. 提交代码
git add .
git commit -m "feat: 添加新功能"
git push

# 4. 部署到生产
bash deploy-from-scratch.sh
```

### 定时任务

```bash
# 每天 15:30 自动更新部署
30 15 * * 1-5 cd /path/to/project && bash deploy-from-scratch.sh >> /var/log/deploy.log 2>&1
```

### CI/CD 集成

**GitHub Actions:**
```yaml
- name: Deploy
  run: bash deploy-from-scratch.sh
```

**GitLab CI:**
```yaml
deploy:
  script:
    - bash deploy-from-scratch.sh
```

---

## 联系与支持

如有问题或建议，请：
- 📧 提交 [GitHub Issues](https://github.com/cedricporter/funcat/issues)
- 📖 查看 [部署指南](DEPLOYMENT.md)
- 💬 查看脚本内的详细注释
