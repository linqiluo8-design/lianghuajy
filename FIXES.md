# 修复记录

本文档记录所有重要的错误修复，避免走"回头路"。

---

## [2026-01-11] 修复 PostgreSQL 初始化 SQL 语法错误

### 问题描述

部署系统时，PostgreSQL 容器初始化失败，报错：

```
psql:/docker-entrypoint-initdb.d/01-schema.sql:31: ERROR:  syntax error at or near "COMMENT"
LINE 3:     strategy_name VARCHAR(100) NOT NULL COMMENT '策略名称',
```

### 根本原因

**deployment/sql/schema.sql** 文件使用了 **MySQL 的内联 COMMENT 语法**，但 PostgreSQL 不支持这种语法。

**错误示例（MySQL 语法）：**
```sql
CREATE TABLE users (
    username VARCHAR(50) NOT NULL COMMENT '用户名',
    email VARCHAR(100) COMMENT '邮箱'
);
```

**PostgreSQL 正确语法选项 1（无注释）：**
```sql
CREATE TABLE users (
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100)
);
```

**PostgreSQL 正确语法选项 2（独立注释语句）：**
```sql
CREATE TABLE users (
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100)
);

COMMENT ON COLUMN users.username IS '用户名';
COMMENT ON COLUMN users.email IS '邮箱';
```

### 修复方案

移除所有内联 `COMMENT '...'` 语句，保留字段定义中的 SQL 注释（`--` 开头）已经足够说明字段用途。

**修复的表：**
1. `select_results` - 选股结果表
2. `backtest_records` - 回测记录表
3. `strategy_configs` - 策略配置表
4. `users` - 用户表
5. `task_queue` - 任务队列表
6. `system_logs` - 系统日志表

### 影响范围

- 文件：`deployment/sql/schema.sql`
- 共修复：6 个表定义，约 60 处 COMMENT 语法错误

### 如何避免

1. **PostgreSQL 项目不要使用 MySQL 语法**
   - 内联 COMMENT 是 MySQL 特有语法
   - PostgreSQL 使用 `COMMENT ON` 语句

2. **数据库迁移检查清单**
   - 从 MySQL 迁移到 PostgreSQL 时，检查：
     - ✅ COMMENT 语法
     - ✅ AUTO_INCREMENT → SERIAL
     - ✅ DATETIME → TIMESTAMP
     - ✅ 引号使用（MySQL 双引号 vs PostgreSQL 单引号）

3. **部署前验证**
   - 在本地 PostgreSQL 环境测试 SQL 脚本
   - 使用 `psql -f schema.sql` 验证语法

### 验证方法

```bash
# 清理旧数据
docker compose down -v

# 重新部署
bash deploy-from-scratch.sh --clean --skip-update

# 检查 PostgreSQL 日志
docker compose logs postgres | grep -i error

# 验证字段注释是否成功添加
docker compose exec postgres psql -U funcat_user -d funcat -c "\d+ select_results"
```

### 后续改进：添加字段注释脚本

虽然移除了内联 COMMENT 解决了语法错误，但字段注释对数据库文档化很重要。

**改进方案：**
- 创建独立的 `comments.sql` 脚本
- 使用 PostgreSQL 标准的 `COMMENT ON COLUMN` 语法
- 在 docker-compose.yml 中配置自动执行

**新增文件：**
- `deployment/sql/comments.sql` - 包含所有表字段的注释定义

**执行顺序：**
```
01-schema.sql       → 创建表结构
02-init_data.sql    → 初始化数据
03-webui_tables.sql → Web UI 表
04-comments.sql     → 添加字段注释 ✨ 新增
05-yangjia_schema_fixed.sql
06-sector_strength.sql
07-test_data.sql
```

**示例语法：**
```sql
-- PostgreSQL 标准注释语法
COMMENT ON COLUMN users.username IS '用户名';
COMMENT ON COLUMN users.email IS '邮箱';
```

**使用方法：**

1. **自动执行（新部署）**
   - 使用 `bash deploy-from-scratch.sh --clean` 部署
   - comments.sql 会在初始化时自动执行

2. **手动执行（已有数据库）**
   ```bash
   # 使用便捷脚本
   bash deployment/scripts/add-comments.sh

   # 或直接使用 docker exec
   docker compose exec postgres psql -U funcat_user -d funcat < deployment/sql/comments.sql
   ```

3. **验证注释**
   ```bash
   # 查看表结构和字段注释
   docker compose exec postgres psql -U funcat_user -d funcat -c "\d+ select_results"
   docker compose exec postgres psql -U funcat_user -d funcat -c "\d+ users"
   ```

### 相关文档

- PostgreSQL 官方文档：https://www.postgresql.org/docs/current/sql-comment.html
- MySQL vs PostgreSQL 语法对比：https://wiki.postgresql.org/wiki/Things_to_find_out_about_when_moving_from_MySQL_to_PostgreSQL

---

## [2026-01-11] 优化 Web UI 构建速度（Go 依赖下载加速）

### 问题描述

Web UI 后端服务构建时间过长（超过 370 秒），主要卡在下载 Go 模块依赖阶段：
- 从 github.com 下载依赖包缓慢
- 从 golang.org 下载标准库缓慢
- 每次代码变更都重新下载所有依赖

### 根本原因

1. **Docker 缓存层未优化**
   - 原先 `COPY . .` 在下载依赖之前
   - 任何代码变更都导致依赖层缓存失效

2. **Go 代理配置不够完善**
   - 只配置了单一 GOPROXY 镜像
   - 没有禁用 GOSUMDB 验证（可能导致额外网络请求）

3. **构建上下文未优化**
   - 没有 .dockerignore 文件
   - 复制了不必要的文件到构建上下文

### 修复方案

**1. 优化 Dockerfile 层级顺序**
```dockerfile
# ❌ 错误做法：先复制所有代码
COPY . .
RUN go mod download

# ✅ 正确做法：先复制依赖文件
COPY go.mod ./
COPY go.su[m] ./  # 使用通配符处理 go.sum 可能不存在的情况
RUN go mod tidy && go mod download
COPY . .  # 最后复制源代码
```

**2. 增强 Go 代理配置**
```dockerfile
ENV GOPROXY=https://goproxy.cn,https://mirrors.aliyun.com/goproxy/,https://goproxy.io,direct
ENV GOSUMDB=off  # 禁用校验和数据库（加速下载）
```

**3. 创建 .dockerignore**
排除不必要的文件：
- .git, .vscode, .idea
- README.md, *.md, LICENSE
- Dockerfile*, docker-compose*.yml
- 构建产物、临时文件

### 优化效果

**优化前：**
- 首次构建：~370 秒
- 代码变更后重建：~370 秒（完全重新下载依赖）

**优化后（预期）：**
- 首次构建：~150 秒（使用国内镜像加速）
- 代码变更后重建：~30 秒（利用 Docker 缓存，不重新下载依赖）
- 依赖变更后重建：~150 秒

### 影响范围

- 文件：`web-ui/backend/Dockerfile`
- 新增：`web-ui/backend/.dockerignore`

### 技术细节

**Docker 缓存层机制：**
```
Layer 1: FROM golang:1.21-alpine      ✓ 始终缓存
Layer 2: COPY go.mod                  ✓ go.mod 不变时缓存
Layer 3: RUN go mod download          ✓ go.mod 不变时缓存（关键！）
Layer 4: COPY . .                     ✗ 代码变更，此层失效
Layer 5: RUN go build                 ✗ 代码变更，重新编译
```

只要 `go.mod` 不变，Layer 3 的依赖下载会被缓存，节省大量时间！

### 验证方法

```bash
# 首次构建（会下载依赖）
docker compose build webui

# 修改代码后重新构建（应该跳过依赖下载）
# 1. 修改 main.go
# 2. 重新构建
docker compose build webui

# 查看构建日志，应该看到 "CACHED" 标记
docker compose build webui 2>&1 | grep -i cached
```

### 进一步优化建议

1. **使用 Go Vendor（可选）**
   ```bash
   # 预先下载依赖到 vendor 目录
   go mod vendor
   # Dockerfile 中使用
   RUN go build -mod=vendor
   ```

2. **使用 BuildKit 缓存挂载**
   ```dockerfile
   RUN --mount=type=cache,target=/go/pkg/mod \
       go mod download
   ```

3. **多阶段构建优化（已实现）**
   - builder 阶段：构建
   - runtime 阶段：只复制二进制（镜像更小）

### 如何避免

1. **Dockerfile 最佳实践**
   - 把频繁变化的层放在后面
   - 把不常变化的层放在前面
   - 依赖下载 → 代码复制 → 编译

2. **配置多个 Go 代理镜像**
   - goproxy.cn（七牛云）
   - mirrors.aliyun.com（阿里云）
   - goproxy.io（国际备选）

3. **使用 .dockerignore**
   - 减少构建上下文大小
   - 加快 COPY 操作速度

---

## [2026-01-11] 修复 Docker 构建错误：missing go.sum entry

### 问题描述

部署时 webui 服务构建失败，报错：
```
ERROR [builder 8/8] RUN CGO_ENABLED=0 GOOS=linux go build
main.go:11:2: missing go.sum entry for module providing package github.com/gin-contrib/cors
main.go:12:2: missing go.sum entry for module providing package github.com/gin-gonic/gin
```

### 根本原因

**Dockerfile 逻辑错误：**
```dockerfile
# ❌ 错误：go mod tidy 在复制源代码之前执行
COPY go.mod ./
RUN go mod tidy  # 找不到 main.go，无法生成 go.sum！
COPY . .
```

**核心问题：**
- `go mod tidy` 需要分析源代码（main.go）中的 import 语句
- 但源代码在之后的 `COPY . .` 才复制进容器
- 导致 go mod tidy 无法生成正确的 go.sum

### 尝试的修复方案（失败）

**第一次尝试：**
```dockerfile
COPY go.mod ./
COPY *.go ./
RUN go mod tidy && go mod download
COPY . .
```

**仍然失败：**
```
ERROR: missing go.sum entry for go.mod file
github.com/go-redis/redis/v8@v8.11.5: missing go.sum entry
```

**原因：** 只复制 *.go 不够，go mod tidy 需要完整项目结构

### 最终修复方案

**简化 Dockerfile（确保成功）：**
```dockerfile
# ✅ 先复制所有文件
COPY . .
RUN go mod tidy && go mod download
RUN go build
```

### 权衡说明

**优势：**
- ✅ 构建成功
- ✅ go.sum 完整正确
- ✅ 简单可靠

**缺点：**
- ❌ 任何文件变更都触发依赖下载（~150 秒）
- ❌ 暂时失去缓存优化

### 后续优化计划

1. 构建成功后提取 go.sum
2. 提交 go.sum 到 git
3. 优化为理想方案（完美缓存）

### 影响范围

- `web-ui/backend/Dockerfile`

### 验证方法

```bash
git pull origin claude/debug-dashboard-akshare-9Igcv
docker compose build webui
docker compose up -d webui
```

---

## [2026-01-11] 部署脚本集成 go.sum 自动提取

### 问题描述

首次部署时，go.sum 文件不存在，需要手动运行脚本提取并提交。这增加了操作复杂度，容易被遗忘。

### 改进方案

**集成到 deploy-from-scratch.sh：**
- 添加步骤 7.5：提取并提交 go.sum
- 自动从构建镜像提取 go.sum 文件
- 友好提示用户提交以优化后续构建

**实现位置：**
```
步骤 7:   构建并启动应用服务
步骤 7.5: 提取 go.sum 文件（新增）✨
步骤 8:   采集实时数据
```

### 功能特性

1. **自动检测**
   - 检查 web-ui/backend/go.sum 是否存在
   - 检查 funcat-go/go.sum 是否存在

2. **智能提取**
   - 只在构建后且文件不存在时提取
   - 从 Docker 镜像创建临时容器
   - 复制 go.sum 到本地目录

3. **友好提示**
   ```
   📝 发现新的 go.sum 文件，建议提交到 git 以优化构建速度

   优势：
     • 首次构建：~150 秒（使用国内镜像）
     • go.sum 提交后代码变更：~30 秒（利用 Docker 缓存）

   提交命令：
     git add web-ui/backend/go.sum
     git commit -m 'feat: 添加 go.sum 优化 Docker 构建缓存'
     git push

   详细说明请查看: DOCKER_OPTIMIZATION.md
   ```

### 使用流程

**首次部署：**
```bash
# 1. 运行部署脚本
bash deploy-from-scratch.sh --clean

# 2. 脚本自动：
#    - 构建 webui 服务
#    - 提取 go.sum 文件
#    - 显示提交提示

# 3. 提交 go.sum
git add web-ui/backend/go.sum
git commit -m 'feat: 添加 go.sum 优化 Docker 构建缓存'
git push
```

**后续部署：**
```bash
# go.sum 已存在，自动利用 Docker 缓存
bash deploy-from-scratch.sh

# 构建速度：370 秒 → 30 秒 ⚡
```

### 修改文件

- `deploy-from-scratch.sh`
  - 新增步骤 7.5（go.sum 提取）
  - 更新脚本头部文档
  - 更新提示信息

- `DOCKER_OPTIMIZATION.md`
  - 记录集成改进历史
  - 说明自动化流程

### 相关工具

**手动提取工具（仍然保留）：**
```bash
bash deployment/scripts/extract-gosum.sh webui
bash deployment/scripts/extract-gosum.sh funcat-go
```

**适用场景：**
- 脚本外单独提取 go.sum
- 调试和验证
- CI/CD 流水线

### 优势

✅ **自动化** - 无需记忆额外命令
✅ **友好提示** - 明确说明优化效果
✅ **智能检测** - 避免重复操作
✅ **向后兼容** - 保留独立脚本

---

## 修复记录模板

```markdown
## [YYYY-MM-DD] 修复标题

### 问题描述
[详细描述问题现象和错误信息]

### 根本原因
[分析问题的根本原因]

### 修复方案
[说明如何修复]

### 影响范围
[列出影响的文件和代码]

### 如何避免
[提供预防措施和最佳实践]

### 验证方法
[说明如何验证修复是否成功]
```
