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

### 相关文档

- PostgreSQL 官方文档：https://www.postgresql.org/docs/current/sql-comment.html
- MySQL vs PostgreSQL 语法对比：https://wiki.postgresql.org/wiki/Things_to_find_out_about_when_moving_from_MySQL_to_PostgreSQL

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
