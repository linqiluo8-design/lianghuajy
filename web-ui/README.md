# Funcat Web UI - 涨跌停数据看板

> 专业的股票涨跌停数据可视化平台

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/linqiluo8-design/thsfuncat)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](../LICENSE)
[![Go](https://img.shields.io/badge/Go-1.21+-00ADD8.svg)](https://golang.org/)
[![Vue](https://img.shields.io/badge/Vue-3.0-4FC08D.svg)](https://vuejs.org/)

## 🌟 特性

- ✅ **板块选择** - 支持行业、概念、地域板块筛选
- 📊 **涨跌停统计** - 实时统计各板块涨停、跌停数据
- 🔥 **一字涨停** - 识别和统计一字板个股
- 💥 **炸板监控** - 跟踪炸板回封和未回封情况
- 🏆 **连板天梯** - 可视化连续涨停排行榜
- 📈 **ECharts图表** - 美观的数据可视化
- 🚀 **高性能** - Go语言后端，响应迅速
- 🐳 **Docker部署** - 一键启动，开箱即用

## 📸 界面预览

### 主界面
![主界面](docs/images/dashboard.png)

### 连板天梯
![连板天梯](docs/images/ladder.png)

### 板块统计
![板块统计](docs/images/sectors.png)

## 🚀 快速开始

### 使用一键启动脚本（推荐）

```bash
# 克隆项目
git clone https://github.com/linqiluo8-design/thsfuncat.git
cd thsfuncat

# 运行启动脚本
bash scripts/start-webui.sh
```

3分钟内完成部署！访问 http://localhost:8080

### 手动启动

```bash
# 1. 启动数据库
docker-compose up -d postgres redis

# 2. 初始化数据库
docker-compose exec -T postgres psql -U funcat_user -d funcat < deployment/sql/schema_extension.sql
docker-compose exec -T postgres psql -U funcat_user -d funcat < deployment/sql/init_sample_data.sql

# 3. 启动Web UI
docker-compose up -d --build webui

# 4. 访问界面
open http://localhost:8080
```

## 📚 文档

- [快速启动指南](../WEBUI_QUICK_START.md) - 3分钟上手
- [详细使用手册](../WEB_UI_GUIDE.md) - 完整功能说明
- [API接口文档](../WEB_UI_GUIDE.md#api-接口文档) - RESTful API

## 🎯 核心功能

### 1. 板块涨停统计

查看各板块的涨停、跌停、一字板等统计数据：

```
半导体板块:
  涨停: 3只
  一字板: 1只
  炸板: 1只 (回封: 1, 未封: 0)
  连板分布: 2连×1, 3连×1
```

### 2. 炸板监控

实时跟踪炸板情况：

- **炸板总数**: 盘中打开涨停的次数
- **回封数量**: 炸板后重新封住
- **未回封数量**: 炸板后未能封住
- **炸板时间**: 记录炸板发生时间

### 3. 连板天梯

可视化展示连续涨停个股：

```
🥇 1. 中航沈飞  5连  军工  封单18万手  +61.05%
🥈 2. 宁德时代  4连  储能  封单20万手  +46.41%
🥉 3. 中芯国际  3连  芯片  封单10万手  +33.10%
```

### 4. 一字涨停识别

自动识别一字涨停个股：
- 开盘价 = 收盘价 = 最高价
- 全天封单不开板
- 强势信号

## 🔌 API示例

### 获取板块列表

```bash
curl http://localhost:8080/api/v1/sectors?type=industry
```

### 获取涨停列表

```bash
curl "http://localhost:8080/api/v1/limit-stats?date=2024-12-19&type=limit_up"
```

### 获取连板天梯

```bash
curl "http://localhost:8080/api/v1/consecutive-ladder?min_days=2"
```

## 🛠️ 技术栈

### 后端
- **语言**: Go 1.21+
- **框架**: Gin (RESTful API)
- **数据库**: PostgreSQL 13
- **缓存**: Redis 6

### 前端
- **框架**: Vue 3
- **UI库**: Element Plus
- **图表**: ECharts 5
- **构建**: CDN (无需编译)

### 部署
- **容器化**: Docker + Docker Compose
- **反向代理**: Nginx (可选)
- **监控**: Prometheus + Grafana (可选)

## 📊 数据库结构

### 核心表

1. **sectors** - 板块信息表
2. **stock_sector_mapping** - 股票-板块映射
3. **daily_limit_stats** - 每日涨跌停统计
4. **consecutive_limits** - 连板记录
5. **sector_daily_stats** - 板块每日统计

详见 [schema_extension.sql](backend/schema_extension.sql)

## 🔧 配置说明

### 环境变量

在 `.env` 文件中配置：

```bash
# Web UI端口
WEBUI_PORT=8080

# 数据库配置
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_USER=funcat_user
POSTGRES_PASSWORD=your_password

# Redis配置
REDIS_HOST=redis
REDIS_PORT=6379
```

## 📈 性能指标

- **响应时间**: < 100ms (API)
- **并发支持**: 1000+ QPS
- **内存占用**: ~512MB
- **CPU占用**: < 0.5核 (空闲时)

## 🐛 故障排查

### 问题1: 页面无法访问

```bash
# 检查服务状态
docker-compose ps webui

# 查看日志
docker-compose logs webui
```

### 问题2: 数据为空

```bash
# 重新导入示例数据
docker-compose exec -T postgres psql -U funcat_user -d funcat < deployment/sql/init_sample_data.sql
```

更多问题请查看 [故障排查文档](../WEB_UI_GUIDE.md#故障排查)

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

### 开发环境

```bash
cd backend
go mod download
go run main.go
```

## 📄 许可证

[MIT License](../LICENSE)

## 🔗 相关链接

- [Funcat 主项目](https://github.com/linqiluo8-design/thsfuncat)
- [问题反馈](https://github.com/linqiluo8-design/thsfuncat/issues)
- [功能建议](https://github.com/linqiluo8-design/thsfuncat/discussions)

## 💬 联系方式

- 📧 Email: support@funcat.com
- 💬 微信群: 见 README
- 🌐 官网: https://funcat.com

---

**开始你的量化分析之旅！** 📊🚀
