# 数据源配置指南

Funcat 支持**多种数据源**，您可以根据需求选择合适的数据源。

---

## 📊 支持的数据源

### 1. RQAlpha 本地数据包（推荐）

**优势**：
- ✅ **完全离线** - 无需网络和Token
- ✅ **速度快** - 本地读取，无网络延迟
- ✅ **免费** - 完全开源，无需付费
- ✅ **稳定** - 不受API限流影响

**适用场景**：
- 策略回测
- 历史数据分析
- 本地开发测试

---

### 2. Tushare 在线数据源

**优势**：
- ✅ **实时数据** - 获取最新行情
- ✅ **数据全面** - 财务数据、指数、基金等
- ✅ **自动更新** - 无需手动维护

**劣势**：
- ❌ **需要Token** - 需要注册获取
- ❌ **网络依赖** - 需要网络连接
- ❌ **API限流** - 免费版有调用限制

**适用场景**：
- 实时行情监控
- 生产环境部署
- 需要最新数据

---

## 🚀 快速配置

### 方案A：使用 RQAlpha 本地数据（推荐新手）

#### 1. 安装 RQAlpha
```bash
pip install rqalpha
```

#### 2. 下载历史数据
```bash
# 下载A股日线数据（约500MB）
rqalpha update_bundle

# 数据会保存到 ~/.rqalpha/bundle/
```

#### 3. Python 代码中使用
```python
from funcat import *
from funcat.data.rqalpha_data_backend import RQAlphaDataBackend

# 设置数据源为RQAlpha本地数据
set_data_backend(RQAlphaDataBackend("~/.rqalpha/bundle"))

# 开始使用
set_start_date("2024-01-01")
S("000001.XSHG")  # 设置当前股票

print(C)  # 打印收盘价
```

#### 4. Docker 中使用
```yaml
# docker-compose.yml
selector:
  volumes:
    - ~/.rqalpha/bundle:/root/.rqalpha/bundle  # 挂载本地数据
  environment:
    - DATA_BACKEND=rqalpha  # 使用RQAlpha后端
```

**✅ 完成！无需配置 TUSHARE_TOKEN**

---

### 方案B：使用 Tushare 在线数据

#### 1. 注册 Tushare 账号
访问：https://tushare.pro/register

#### 2. 获取 Token
登录后访问：https://tushare.pro/user/token

#### 3. 配置环境变量
```bash
# 复制配置模板
cp .env.example .env

# 编辑 .env 文件，设置Token
TUSHARE_TOKEN=your_actual_token_here
```

#### 4. Python 代码中使用
```python
from funcat import *
from funcat.data.tushare_backend import TushareDataBackend
import os

# 从环境变量读取Token
token = os.getenv('TUSHARE_TOKEN')
set_data_backend(TushareDataBackend(token))

# 开始使用
set_start_date("2024-01-01")
S("000001.SZ")  # 设置当前股票

print(C)  # 打印收盘价（实时数据）
```

---

## 🔄 数据源对比

| 特性 | RQAlpha 本地 | Tushare 在线 |
|------|-------------|-------------|
| **是否需要Token** | ❌ 不需要 | ✅ 需要 |
| **网络要求** | ❌ 离线可用 | ✅ 需要联网 |
| **数据更新** | 手动更新 | 自动最新 |
| **速度** | 🚀 极快 | 🐌 受网络影响 |
| **数据范围** | 历史数据 | 历史+实时 |
| **成本** | 💰 免费 | 💰 免费版有限制 |
| **稳定性** | ✅ 本地稳定 | ⚠️ 受限流影响 |

---

## 💡 推荐方案

### 新手入门
```bash
# 使用 RQAlpha 本地数据
pip install rqalpha
rqalpha update_bundle
```
✅ 简单、快速、无需注册

---

### 策略研发
```python
# 研发阶段：使用本地数据（快速迭代）
from funcat.data.rqalpha_data_backend import RQAlphaDataBackend
set_data_backend(RQAlphaDataBackend())
```

---

### 生产部署
```python
# 生产环境：使用Tushare获取实时数据
from funcat.data.tushare_backend import TushareDataBackend
set_data_backend(TushareDataBackend(token))
```

---

## 🔧 常见问题

### Q1: RQAlpha 数据如何更新？
```bash
# 定期更新（每天收盘后执行）
rqalpha update_bundle
```

或设置自动更新：
```bash
# 添加到 crontab
0 17 * * 1-5 rqalpha update_bundle
```

---

### Q2: 如何切换数据源？
```python
# 方法1：在代码中切换
from funcat import *

# 使用本地数据
from funcat.data.rqalpha_data_backend import RQAlphaDataBackend
set_data_backend(RQAlphaDataBackend())

# 切换到Tushare
from funcat.data.tushare_backend import TushareDataBackend
set_data_backend(TushareDataBackend(token))
```

---

### Q3: 两种数据源可以同时使用吗？
**可以！** 建议方案：
```python
from funcat import *
from funcat.data.rqalpha_data_backend import RQAlphaDataBackend
from funcat.data.tushare_backend import TushareDataBackend
import os

# 根据环境变量选择
if os.getenv('TUSHARE_TOKEN'):
    # 生产环境：使用Tushare实时数据
    backend = TushareDataBackend(os.getenv('TUSHARE_TOKEN'))
else:
    # 开发环境：使用本地数据
    backend = RQAlphaDataBackend()

set_data_backend(backend)
```

---

### Q4: Docker 部署时如何配置？

**使用 RQAlpha 本地数据**：
```yaml
# docker-compose.yml
services:
  selector:
    volumes:
      - ~/.rqalpha/bundle:/root/.rqalpha/bundle
    environment:
      - DATA_BACKEND=rqalpha
```

**使用 Tushare**：
```bash
# .env 文件
TUSHARE_TOKEN=your_token_here
```

```yaml
# docker-compose.yml
services:
  selector:
    environment:
      - TUSHARE_TOKEN=${TUSHARE_TOKEN}
      - DATA_BACKEND=tushare
```

---

### Q5: 本地数据占用多少空间？
```bash
# A股日线数据
~/.rqalpha/bundle/  # 约 500 MB

# 包含分钟数据
~/.rqalpha/bundle/  # 约 5-10 GB
```

---

## 📦 当前项目配置

### Web UI
**当前项目的 Web UI 不依赖任何外部数据源**，它只是展示数据库中已有的数据。

数据来源：
- PostgreSQL 数据库（`daily_limit_stats` 表）
- 手动导入的历史数据
- 选股服务计算的结果

**✅ 因此，您完全不需要配置 TUSHARE_TOKEN 就可以使用 Web UI！**

---

### 选股服务 (Selector)
如果您要运行选股服务，建议：

1. **开发/测试环境**：
   ```bash
   # 使用 RQAlpha 本地数据
   pip install rqalpha
   rqalpha update_bundle
   ```

2. **生产环境（需要实时数据）**：
   ```bash
   # 配置 Tushare Token
   echo "TUSHARE_TOKEN=your_token" >> .env
   ```

---

## 🎯 总结

| 使用场景 | 推荐方案 | 配置复杂度 |
|---------|---------|----------|
| 🔥 **只使用 Web UI** | 无需配置数据源 | ⭐ 最简单 |
| 📊 **策略回测** | RQAlpha 本地数据 | ⭐⭐ 简单 |
| 📈 **实时选股** | Tushare 在线数据 | ⭐⭐⭐ 中等 |
| 🚀 **生产部署** | Tushare + 本地缓存 | ⭐⭐⭐⭐ 复杂 |

**推荐新手**：直接使用 Web UI，无需配置任何数据源！

---

## 📚 相关文档

- [RQAlpha 官方文档](https://rqalpha.readthedocs.io/)
- [Tushare 官方文档](https://tushare.pro/document/2)
- [Funcat 使用手册](USER_MANUAL.md)
- [Docker 部署指南](DOCKER_DEPLOYMENT.md)
