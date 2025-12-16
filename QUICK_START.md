# 快速开始指南

> 5分钟上手Funcat，开始你的量化选股之旅！

---

## 🎯 选择你的版本

| 场景 | 推荐版本 | 理由 |
|------|---------|------|
| 🔬 学习和研发 | **Python** | 交互式开发，快速验证 |
| 🚀 生产部署 | **Go** | 高性能，低资源占用 |

---

## Python版本 - 5分钟快速开始

### 1. 安装 (1分钟)

```bash
# 安装TA-Lib依赖
# macOS
brew install ta-lib

# Ubuntu
sudo apt-get install libta-lib-dev

# 安装Funcat
pip install numpy pandas TA-Lib tushare
cd thsfuncat && pip install -e .
```

### 2. 第一个程序 (2分钟)

创建文件 `my_first_stock.py`:

```python
from funcat import *

# 设置数据源
set_data_backend(TushareDataBackend())

# 查看上证指数
T("20240101")
S("000001.XSHG")

print(f"收盘价: {CLOSE.value}")
print(f"MA5: {MA(CLOSE, 5).value:.2f}")
print(f"MA20: {MA(CLOSE, 20).value:.2f}")
```

运行:
```bash
python my_first_stock.py
```

### 3. 第一次选股 (2分钟)

创建文件 `my_first_select.py`:

```python
from funcat import *
from funcat.api import select

set_data_backend(TushareDataBackend())

# 定义选股条件: 5日线上穿20日线
def my_strategy():
    ma5 = MA(CLOSE, 5)
    ma20 = MA(CLOSE, 20)
    return CROSS(ma5, ma20)

# 执行选股
select(my_strategy, "2024-01-01", "2024-01-10")
```

运行:
```bash
python my_first_select.py
```

---

## Go版本 - 5分钟快速开始

### 1. 安装 (1分钟)

```bash
# 安装Go
# macOS
brew install go

# Ubuntu
sudo apt install golang-go

# 验证
go version  # >= 1.21
```

### 2. 初始化项目 (1分钟)

```bash
cd thsfuncat/funcat-go
go mod tidy
```

### 3. 运行示例 (1分钟)

```bash
go run examples/simple_select.go
```

### 4. 编写你的第一个Go选股程序 (2分钟)

创建文件 `my_first_go_select.go`:

```go
package main

import (
	"fmt"
	"github.com/funcat/funcat-go/pkg/indicators"
	"github.com/funcat/funcat-go/pkg/series"
)

func main() {
	// 模拟收盘价数据
	closeData := []float64{10.0, 10.2, 10.5, 10.8, 11.0}
	close := series.NewNumericSeries(closeData)

	// 计算MA5
	ma5 := indicators.MA(close, 5)
	fmt.Printf("MA5: %.2f\n", ma5.Value())

	// 判断金叉
	ma20 := indicators.MA(close, 20)
	cross := indicators.CROSS(ma5, ma20)
	fmt.Printf("金叉: %v\n", cross.Value())
}
```

运行:
```bash
go run my_first_go_select.go
```

---

## 📝 常用命令速查

### Python命令

```python
# 设置数据源
set_data_backend(TushareDataBackend())

# 设置日期和股票
T("20240101")
S("000001.XSHG")

# 行情数据
OPEN.value    # 开盘价
HIGH.value    # 最高价
LOW.value     # 最低价
CLOSE.value   # 收盘价
VOLUME.value  # 成交量

# 常用指标
MA(CLOSE, 5)              # 5日均线
EMA(CLOSE, 12)            # 12日指数均线
MACD(12, 26, 9)           # MACD
KDJ(9, 3, 3)              # KDJ
BOLL(20, 2)               # 布林带
RSI(6, 12, 24)            # RSI

# 条件判断
CLOSE > MA(CLOSE, 5)      # 收盘价大于5日均线
CROSS(MA5, MA20)          # 5日线上穿20日线
COUNT(CLOSE > OPEN, 5)    # 5天内阳线天数

# 选股
select(my_strategy, "2024-01-01", "2024-12-31")
```

### Go命令

```bash
# 开发
go run main.go

# 编译
go build -o funcat-selector

# 测试
go test ./...

# 基准测试
go test -bench=. -benchmem

# 跨平台编译
GOOS=linux go build -o funcat-linux
GOOS=windows go build -o funcat.exe
```

---

## 🔥 实用代码片段

### Python: 均线多头排列

```python
def ma_bull_strategy():
    """均线多头排列"""
    ma5 = MA(CLOSE, 5)
    ma10 = MA(CLOSE, 10)
    ma20 = MA(CLOSE, 20)
    return (ma5 > ma10) & (ma10 > ma20)
```

### Python: MACD金叉 + 放量

```python
def macd_volume_strategy():
    """MACD金叉且放量"""
    macd = MACD(12, 26, 9)
    vol_ma = MA(VOLUME, 5)
    return (macd > 0) & (VOLUME > vol_ma * 1.5)
```

### Python: KDJ超卖反弹

```python
def kdj_oversold():
    """KDJ超卖反弹"""
    K, D, J = KDJ(9, 3, 3)
    return (K < 20) & CROSS(K, D)
```

### Go: 并发选股模板

```go
package main

import (
	"fmt"
	"time"
	"github.com/funcat/funcat-go/pkg/selector"
)

func main() {
	backend := NewMyBackend()
	sel := selector.NewSelector(backend, 100)

	condition := func(data *selector.StockData) bool {
		// 你的选股逻辑
		return data.Close > 10.0
	}

	callback := func(date time.Time, code, symbol string) {
		fmt.Printf("✓ %s %s\n", code, symbol)
	}

	start := time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC)
	end := time.Date(2024, 12, 31, 0, 0, 0, 0, time.UTC)

	stats, _ := sel.SelectWithStats(condition, start, end, callback)
	fmt.Printf("速度: %.2f jobs/秒\n", stats.JobsPerSecond)
}
```

---

## 🆘 遇到问题？

### Python常见错误

❌ **ImportError: No module named talib**
```bash
# macOS
brew install ta-lib && pip install TA-Lib

# Ubuntu
sudo apt-get install libta-lib-dev && pip install TA-Lib
```

❌ **DATA UNAVAILABLE**
```python
# 检查日期格式: YYYYMMDD
T("20240101")  # ✅ 正确
T("2024-01-01")  # ❌ 错误

# 检查股票代码
S("000001.XSHG")  # ✅ 上证指数
S("000001.XSHE")  # ✅ 平安银行
```

### Go常见错误

❌ **cannot find module**
```bash
go mod init your-project
go mod tidy
```

❌ **编译错误**
```bash
go clean -modcache
go mod tidy
go build
```

---

## 📚 下一步

### 深入学习

1. 阅读 [📖 使用手册](USER_MANUAL.md) - 完整教程
2. 学习 [🔄 迁移指南](MIGRATION_GUIDE.md) - Python到Go
3. 查看 [📊 性能对比](OPTIMIZATION_SUMMARY.md) - 性能数据

### 实战项目

1. **日常选股机器人** (Python)
   - 每天自动选股
   - 结果发送到微信/邮件
   - 参考: [USER_MANUAL.md#场景1](USER_MANUAL.md)

2. **批量回测系统** (Go)
   - 测试策略历史表现
   - 生成详细报告
   - 参考: [USER_MANUAL.md#场景2](USER_MANUAL.md)

3. **实时监控系统** (Go)
   - 实时监控市场信号
   - 即时推送通知
   - 参考: [USER_MANUAL.md#场景3](USER_MANUAL.md)

---

## 💬 获取帮助

- 📖 文档: [完整文档列表](README.md)
- 🐛 问题: [GitHub Issues](https://github.com/linqiluo8-design/thsfuncat/issues)
- 💬 讨论: [GitHub Discussions](https://github.com/linqiluo8-design/thsfuncat/discussions)

---

## 🎉 开始你的量化之旅！

现在你已经掌握了Funcat的基础，开始编写你的第一个选股策略吧！

**记住**:
- ✅ 策略开发用Python (快速迭代)
- ✅ 生产部署用Go (高性能)
- ✅ 多看文档，多写代码，多测试

**祝你好运！** 📈🚀
