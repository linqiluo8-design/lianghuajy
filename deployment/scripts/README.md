# 部署工具脚本

本目录包含数据库维护和部署相关的工具脚本。

## 📄 脚本列表

### extract-gosum.sh

**用途：** 从 Docker 容器提取 go.sum 文件并提交到 git

**使用场景：**
- 首次构建 Go 项目，需要生成 go.sum 文件
- go.sum 丢失或需要重新生成
- 优化 Dockerfile 构建缓存（go.sum 提交后可利用 Docker 缓存）

**使用方法：**
```bash
# 提取 Web UI 后端的 go.sum
bash deployment/scripts/extract-gosum.sh webui

# 提取 funcat-go 的 go.sum
bash deployment/scripts/extract-gosum.sh funcat-go
```

**功能：**
- 自动检测服务类型和目标目录
- 支持从运行中的容器提取
- 支持创建临时容器生成（如果服务未运行）
- 自动设置 GOPROXY 加速下载
- 显示下一步操作提示

**示例输出：**
```
================================================================================
从 Docker 容器提取 go.sum 文件
================================================================================

ℹ 服务: webui
ℹ 目标目录: web-ui/backend

⚠ 容器未运行，尝试构建镜像...

ℹ 创建临时容器生成 go.sum...
[构建日志...]
✓ go.sum 已生成: web-ui/backend/go.sum

ℹ 下一步：
  1. 验证 go.sum 文件
  2. 提交到 git: git add web-ui/backend/go.sum && git commit -m 'feat: 添加 go.sum 文件'
  3. 之后构建将利用 Docker 缓存，速度大幅提升
```

**前置条件：**
- Docker 已安装并运行
- go.mod 文件存在于目标目录
- 网络可访问 Go 代理镜像

**相关文档：**
- `DOCKER_OPTIMIZATION.md` - Docker 构建优化最佳实践
- `FIXES.md` - 构建速度优化记录

---

### add-comments.sh

**用途：** 为数据库表字段添加中文注释

**使用场景：**
- 已有数据库需要添加字段注释
- 不想重新初始化数据库

**使用方法：**
```bash
bash deployment/scripts/add-comments.sh
```

**功能：**
- 自动检测 Docker 和 PostgreSQL 容器状态
- 执行 `deployment/sql/comments.sql` 脚本
- 验证注释是否添加成功
- 显示示例表的字段注释

**示例输出：**
```
================================================================================
数据库字段注释添加工具
================================================================================

✓ 找到 PostgreSQL 容器: lianghuajy-postgres-1
ℹ 准备执行注释添加脚本...

ℹ 执行 SQL 脚本: comments.sql
数据库字段注释添加完成!
✓ 字段注释添加成功！

================================================================================
示例：select_results 表字段注释
================================================================================
                           Table "public.select_results"
    Column     |            Type             | Description
---------------+-----------------------------+------------------
 id            | integer                     |
 strategy_name | character varying(100)      | 策略名称
 stock_code    | character varying(20)       | 股票代码
 stock_name    | character varying(50)       | 股票名称
 ...
```

**前置条件：**
- Docker 已安装并运行
- PostgreSQL 容器正在运行
- 数据库 `funcat` 已创建

**相关文件：**
- SQL 脚本：`deployment/sql/comments.sql`
- 文档：`FIXES.md`

## 🔧 开发新脚本指南

1. **命名规范**
   - 使用小写字母和连字符：`my-script.sh`
   - 文件名要清晰表达脚本用途

2. **脚本结构**
   ```bash
   #!/bin/bash
   set -e  # 遇到错误立即退出

   # 颜色定义
   RED='\033[0;31m'
   GREEN='\033[0;32m'
   # ...

   # 日志函数
   log_info() { ... }
   log_success() { ... }
   log_error() { ... }

   # 主逻辑
   # ...
   ```

3. **最佳实践**
   - 添加详细的注释和使用说明
   - 使用 `set -e` 确保错误时退出
   - 提供友好的彩色输出
   - 进行必要的前置检查
   - 给出清晰的错误信息和解决建议

4. **测试清单**
   - [ ] 在全新环境测试
   - [ ] 测试错误情况（容器未运行等）
   - [ ] 验证输出信息清晰易懂
   - [ ] 添加到本 README

5. **文档要求**
   - 在本 README 中添加脚本说明
   - 在 FIXES.md 或相关文档中记录使用场景
   - 提供使用示例和输出示例
