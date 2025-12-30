# 🔧 故障排除指南

## 问题：Web UI 显示 500 错误，提示视图不存在

### 错误现象

浏览器控制台显示：
```
GET /api/v1/sector-strength?date=2025-12-30&limit=30 500 (Internal Server Error)
{code: 500, message: '查询失败: pq: relation "v_sector_strength_ranking" does not exist'}
```

### 根本原因

**PostgreSQL 的 `/docker-entrypoint-initdb.d/` 机制只在数据库首次初始化时执行 SQL 文件。**

如果您的数据库已经初始化过（数据卷已存在），即使在 `docker-compose.yml` 中添加了新的 SQL 文件挂载，这些文件也**不会自动执行**。

### 解决方案

#### ✅ 方案一：手动导入 SQL（推荐，无需删除数据）

**使用便捷脚本（推荐）：**

```bash
# 进入项目目录
cd /home/user/lianghuajy

# 执行导入脚本
./scripts/import-sector-strength.sh
```

这个脚本会自动：
1. 创建板块强度计算函数 `calculate_sector_strength()`
2. 创建视图 `v_sector_strength_ranking`
3. 询问是否导入测试数据
4. 验证数据是否成功导入

---

**手动执行（如果脚本不可用）：**

```bash
# 方法 1: 使用管道直接导入
docker compose exec -T postgres psql -U funcat_user -d funcat < deployment/sql/06-sector_strength.sql

# 方法 2: 进入容器交互式导入
docker compose exec postgres psql -U funcat_user -d funcat

# 然后在 psql 提示符下执行：
\i /docker-entrypoint-initdb.d/06-sector_strength.sql
\i /docker-entrypoint-initdb.d/07-test_data.sql
\q
```

---

#### 🔄 方案二：完全重置数据库（慎用，会删除所有数据）

⚠️ **警告：此操作会删除所有现有数据！**

```bash
# 1. 停止所有服务
docker compose down

# 2. 删除 PostgreSQL 数据卷
docker volume rm lianghuajy_postgres_data

# 3. 重新启动（会自动执行所有初始化 SQL）
docker compose up -d postgres

# 4. 等待数据库初始化完成（约 10-30 秒）
docker compose logs -f postgres

# 看到 "database system is ready to accept connections" 后按 Ctrl+C

# 5. 启动其他服务
docker compose up -d
```

---

### 验证修复是否成功

#### 1. 检查视图是否存在

```bash
docker compose exec postgres psql -U funcat_user -d funcat -c "\dv v_sector_strength_ranking"
```

预期输出：
```
                           List of relations
 Schema |           Name              | Type | Owner
--------+-----------------------------+------+-------------
 public | v_sector_strength_ranking   | view | funcat_user
```

#### 2. 检查函数是否存在

```bash
docker compose exec postgres psql -U funcat_user -d funcat -c "\df calculate_sector_strength"
```

预期输出应显示函数详情。

#### 3. 测试查询

```bash
docker compose exec postgres psql -U funcat_user -d funcat -c "
SELECT sector_name, strength_score, strength_grade
FROM v_sector_strength_ranking
WHERE trade_date = '2025-12-30'
LIMIT 5;
"
```

如果导入了测试数据，应该看到 5 行结果。

#### 4. 刷新浏览器

访问 `http://localhost:8081`，选择日期 `2025-12-30`（如果导入了测试数据），应该能看到：
- ✅ 板块强度排行表格有数据
- ✅ 连板天梯有数据
- ✅ 板块统计图表正常显示
- ✅ 控制台无 500 错误

---

## 常见问题

### Q1: 为什么添加了 SQL 文件挂载还是不执行？

**A**: PostgreSQL 官方镜像的设计是：`/docker-entrypoint-initdb.d/` 中的脚本只在数据目录为空（首次启动）时执行。这是为了防止意外覆盖生产数据。

### Q2: 如何知道数据库是否已经初始化过？

**A**: 执行以下命令：
```bash
docker volume inspect lianghuajy_postgres_data
```
如果卷存在且有数据，说明已经初始化过。

### Q3: 能否只导入新的表/视图而不影响现有数据？

**A**: 可以！使用方案一的手动导入方式。`CREATE OR REPLACE VIEW` 和 `CREATE OR REPLACE FUNCTION` 是幂等操作，可以安全地重复执行。

### Q4: 测试数据会覆盖我的真实数据吗？

**A**: `test_data.sql` 使用 `INSERT INTO ... ON CONFLICT DO NOTHING`，不会覆盖现有数据，只会插入不存在的记录。

---

## 预防措施

为了避免将来遇到类似问题：

### 1. 使用迁移脚本管理数据库变更

建议创建 `deployment/sql/migrations/` 目录，将数据库变更按版本管理：

```
deployment/sql/
├── migrations/
│   ├── v1.0.0_initial_schema.sql
│   ├── v1.1.0_webui_tables.sql
│   ├── v1.2.0_yangjia_method.sql
│   └── v1.3.0_sector_strength.sql
└── ...
```

### 2. 记录已执行的迁移

在数据库中创建迁移记录表：

```sql
CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(50) PRIMARY KEY,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 3. 使用数据库迁移工具

考虑使用专业的迁移工具（可选）：
- [golang-migrate](https://github.com/golang-migrate/migrate) (Go 项目推荐)
- [Flyway](https://flywaydb.org/)
- [Liquibase](https://www.liquibase.org/)

---

## 技术细节

### PostgreSQL 初始化流程

1. 容器启动时检查 `$PGDATA` 目录（默认 `/var/lib/postgresql/data`）
2. 如果目录为空：
   - 执行 `initdb` 初始化数据库
   - 按字母顺序执行 `/docker-entrypoint-initdb.d/*.sql`
   - 执行 `/docker-entrypoint-initdb.d/*.sh`
3. 如果目录不为空：
   - **跳过所有初始化脚本**
   - 直接启动数据库服务器

### 为什么这样设计？

防止在容器重启时意外重新执行初始化脚本，避免：
- 数据被覆盖
- 约束冲突错误
- 性能问题（重复创建索引等）

---

## 相关文档

- [PostgreSQL Docker Official Images](https://hub.docker.com/_/postgres)
- [Docker Compose 数据卷管理](https://docs.docker.com/storage/volumes/)
- [板块强度排行功能说明](./SECTOR_STRENGTH_GUIDE.md)
- [数据源配置指南](./DATA_SOURCE_GUIDE.md)

---

## 需要帮助？

如果以上方案都无法解决问题，请检查：

1. **后端日志**：
   ```bash
   docker compose logs webui
   ```

2. **数据库日志**：
   ```bash
   docker compose logs postgres
   ```

3. **网络连接**：
   ```bash
   docker compose exec webui ping postgres
   ```

4. **数据库连接**：
   ```bash
   docker compose exec webui psql -h postgres -U funcat_user -d funcat -c "SELECT version();"
   ```
