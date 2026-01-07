# 部署指南

本项目提供完整的自动化部署脚本，支持从 0 开始的全新环境部署和智能增量更新。

## 快速开始

### 1. 全新环境部署

适用于首次部署或磁盘清理后重新部署：

```bash
bash deploy-from-scratch.sh --clean
```

**执行流程：**
1. 检查 Docker 环境
2. 拉取最新代码
3. 清理所有数据和容器
4. 启动 PostgreSQL 和 Redis
5. 初始化数据库表结构
6. 运行数据库迁移
7. 构建并启动 realtime 和 webui 服务
8. 采集 AkShare 实时数据
9. 聚合板块统计数据
10. 验证部署结果
11. 显示访问地址

**预计时间：** 10-15 分钟

### 2. 日常更新部署（推荐）

适用于代码更新后的增量部署，**自动检测服务变更**，只重新构建有变化的服务：

```bash
bash deploy-from-scratch.sh
```

**智能检测逻辑：**
- 检测到 `services/`, `config/`, `requirements.txt` 变更 → 重新构建 realtime
- 检测到 `web-ui/backend/`, `docker-compose.yml` 变更 → 重新构建 webui
- 检测到 `migrations/`, `deployment/sql/` 变更 → 提示数据库迁移
- 无变更 → 跳过构建，仅重启服务

**性能对比：**
- **无变更：** 30 秒（跳过构建）
- **单服务变更：** 2-3 分钟（只构建 1 个服务）
- **全部变更：** 5-10 分钟（构建 2 个服务）

### 3. 强制重新构建

适用于解决缓存问题或彻底清理：

```bash
bash deploy-from-scratch.sh --force-rebuild
```

**特点：**
- 使用 `docker compose build --no-cache` 无缓存构建
- 清理所有 Docker 构建缓存
- 确保使用最新的基础镜像和依赖

**预计时间：** 10-15 分钟

### 4. 跳过代码更新

适用于使用本地修改的代码进行测试：

```bash
bash deploy-from-scratch.sh --skip-update
```

## 部署参数

| 参数 | 说明 | 适用场景 |
|------|------|---------|
| 无参数 | 智能增量部署 | 日常代码更新 |
| `--clean` | 清理所有数据重新开始 | 首次部署、磁盘清理后 |
| `--skip-update` | 跳过 git pull | 本地代码测试 |
| `--force-rebuild` | 强制重新构建所有服务 | 缓存问题、依赖更新 |

**参数组合：**

```bash
# 清理数据 + 跳过更新（使用本地代码从零开始）
bash deploy-from-scratch.sh --clean --skip-update

# 清理数据 + 强制重建（最彻底的重新部署）
bash deploy-from-scratch.sh --clean --force-rebuild
```

## 部署场景示例

### 场景 1: 修改了 AkShare 数据采集逻辑

```bash
# 修改了 services/data_sources/akshare_source.py
git add services/data_sources/akshare_source.py
git commit -m "fix: 修复 AkShare 数据采集逻辑"
git push

# 部署（自动检测到 services/ 变更，只重建 realtime）
bash deploy-from-scratch.sh
```

**输出示例：**
```
步骤 2.5: 检测服务变更
ℹ  检测到以下文件变更：
services/data_sources/akshare_source.py

ℹ  ✓ 检测到 realtime 服务相关变更

ℹ  服务构建计划：
  • realtime: 需要重新构建
  • webui: 跳过构建（无变更）
```

### 场景 2: 修改了前端 UI

```bash
# 修改了 web-ui/backend/static/index.html
git add web-ui/backend/static/index.html
git commit -m "feat: 更新看板 UI"
git push

# 部署（自动检测到 web-ui/backend/ 变更，只重建 webui）
bash deploy-from-scratch.sh
```

**输出示例：**
```
ℹ  服务构建计划：
  • realtime: 跳过构建（无变更）
  • webui: 需要重新构建
```

### 场景 3: 修改了数据库迁移

```bash
# 添加了新的迁移文件
git add migrations/007_add_new_field.sql
git commit -m "feat: 添加新字段"
git push

# 部署（检测到迁移变更，提示注意）
bash deploy-from-scratch.sh
```

**输出示例：**
```
ℹ  ✓ 检测到数据库迁移文件变更

步骤 6/11: 运行数据库迁移（扩展字段和视图）
```

### 场景 4: 磁盘满了清理后重新部署

```bash
# 1. 清理历史数据
bash cleanup-old-data.sh

# 2. 完全重新部署（清理数据卷）
bash deploy-from-scratch.sh --clean
```

### 场景 5: Docker 缓存问题导致构建失败

```bash
# 强制无缓存重新构建
bash deploy-from-scratch.sh --force-rebuild
```

## 常用运维命令

### 查看服务状态

```bash
docker compose ps
```

### 查看日志

```bash
# 查看 realtime 服务日志
docker compose logs realtime -f

# 查看 webui 服务日志
docker compose logs webui -f

# 查看所有服务日志
docker compose logs -f
```

### 重新采集数据

```bash
docker compose exec realtime python3 -c 'from services.data_sources.akshare_source import AkShareDataSource; AkShareDataSource().fetch_and_store()'
```

### 重新聚合数据

```bash
docker compose exec realtime python3 -c 'from services.sector_aggregator import SectorAggregator; a = SectorAggregator(); a.connect(); a.aggregate(); a.close()'
```

### 清理历史数据

```bash
bash cleanup-old-data.sh
```

### 停止所有服务

```bash
docker compose down
```

### 完全清理（包括数据卷）

```bash
docker compose down -v
```

## 部署验证

部署完成后，访问以下地址验证：

**Web UI:** http://localhost:8080

**验证项目：**
- ✅ 数据日期显示为今天
- ✅ 涨停数量、跌停数量、一字板数量显示正确
- ✅ 板块涨停排行显示多个行业（非"全市场"）
- ✅ 点击涨停数量可查看个股详情弹窗
- ✅ 连板天梯显示连板股票

## CICD 集成

### GitHub Actions 示例

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Deploy to production
        run: |
          ssh user@server 'cd /path/to/project && bash deploy-from-scratch.sh'
```

### GitLab CI 示例

```yaml
deploy:
  stage: deploy
  script:
    - bash deploy-from-scratch.sh
  only:
    - main
```

### Cron Job 定时部署

```bash
# 每天 15:30 自动更新部署
30 15 * * 1-5 cd /path/to/project && bash deploy-from-scratch.sh >> /var/log/deploy.log 2>&1
```

## 故障排查

### 问题 1: 数据库连接失败

**症状：** PostgreSQL 启动超时

**解决：**
```bash
# 检查 PostgreSQL 容器状态
docker compose logs postgres

# 重启数据库
docker compose restart postgres

# 如果持续失败，清理数据卷重新初始化
docker compose down -v
bash deploy-from-scratch.sh --clean
```

### 问题 2: 服务构建失败

**症状：** Docker build 出错

**解决：**
```bash
# 清理 Docker 缓存
docker builder prune -a

# 强制重新构建
bash deploy-from-scratch.sh --force-rebuild
```

### 问题 3: 看板无数据

**症状：** 访问看板显示"暂无数据"

**原因：** 可能是非交易日或数据采集失败

**解决：**
```bash
# 1. 检查是否为交易日（周末/节假日无数据）
date

# 2. 手动重新采集数据
docker compose exec realtime python3 -c 'from services.data_sources.akshare_source import AkShareDataSource; AkShareDataSource().fetch_and_store()'

# 3. 手动重新聚合数据
docker compose exec realtime python3 -c 'from services.sector_aggregator import SectorAggregator; a = SectorAggregator(); a.connect(); a.aggregate(); a.close()'

# 4. 刷新浏览器（Ctrl+Shift+R）
```

### 问题 4: Git pull 失败

**症状：** 代码更新失败

**解决：**
```bash
# 方案 1: 暂存本地更改
git stash
bash deploy-from-scratch.sh

# 方案 2: 跳过代码更新
bash deploy-from-scratch.sh --skip-update

# 方案 3: 手动解决冲突后再部署
git pull
# 解决冲突...
bash deploy-from-scratch.sh --skip-update
```

## 性能优化建议

### 1. 定期清理历史数据

```bash
# 每周清理一次历史数据（只保留最新一天）
bash cleanup-old-data.sh
```

### 2. 定期清理 Docker 资源

```bash
# 清理未使用的镜像
docker image prune -a

# 清理未使用的容器
docker container prune

# 清理未使用的卷
docker volume prune

# 一键清理所有未使用资源
docker system prune -a
```

### 3. 监控磁盘空间

```bash
# 检查磁盘使用情况
df -h

# 检查 Docker 占用空间
docker system df
```

## 最佳实践

1. **日常更新使用增量部署**
   ```bash
   bash deploy-from-scratch.sh
   ```
   自动检测变更，只重建必要的服务，节省时间。

2. **重大更新使用强制重建**
   ```bash
   bash deploy-from-scratch.sh --force-rebuild
   ```
   确保所有依赖和缓存都是最新的。

3. **定期清理历史数据**
   ```bash
   bash cleanup-old-data.sh
   ```
   避免数据库膨胀，保持系统性能。

4. **监控服务日志**
   ```bash
   docker compose logs -f --tail=100
   ```
   及时发现和解决问题。

5. **备份重要数据**
   ```bash
   # 导出数据库
   docker compose exec -T postgres pg_dump -U funcat_user funcat > backup.sql

   # 恢复数据库
   docker compose exec -T postgres psql -U funcat_user -d funcat < backup.sql
   ```

## 技术架构

```
┌─────────────────────────────────────────────┐
│         deploy-from-scratch.sh              │
│         (智能部署编排)                       │
└─────────────────────────────────────────────┘
                    │
    ┌───────────────┼───────────────┐
    │               │               │
    ▼               ▼               ▼
┌─────────┐   ┌──────────┐   ┌──────────┐
│ Git 管理 │   │ 变更检测  │   │ 构建优化 │
│ (pull)  │   │ (diff)   │   │ (cache)  │
└─────────┘   └──────────┘   └──────────┘
                    │
    ┌───────────────┼───────────────┐
    │               │               │
    ▼               ▼               ▼
┌─────────┐   ┌──────────┐   ┌──────────┐
│PostgreSQL│   │ realtime │   │  webui   │
│  Redis   │   │ (Python) │   │   (Go)   │
└─────────┘   └──────────┘   └──────────┘
                    │               │
                    └───────┬───────┘
                            │
                            ▼
                    ┌──────────────┐
                    │   AkShare    │
                    │  (数据源)     │
                    └──────────────┘
```

## 联系与支持

如有问题或建议，请提交 Issue 或 Pull Request。
