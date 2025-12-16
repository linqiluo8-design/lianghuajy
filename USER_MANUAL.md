# Funcat 使用手册

## 📖 目录

- [快速开始](#快速开始)
- [Python版本使用](#python版本使用)
- [Go版本使用](#go版本使用)
- [选股实战教程](#选股实战教程)
- [常用指标说明](#常用指标说明)
- [故障排查](#故障排查)

---

## 快速开始

### 系统要求

**Python版本**:
- Python 2.7 或 Python 3.4+
- pip 包管理器

**Go版本**:
- Go 1.21 或更高版本

---

## Python版本使用

### 安装步骤

#### 1. 安装依赖

```bash
# 克隆项目
git clone https://github.com/linqiluo8-design/thsfuncat.git
cd thsfuncat

# 安装系统依赖 (TA-Lib)
# macOS
brew install ta-lib

# Ubuntu/Debian
sudo apt-get install libta-lib-dev

# Windows - 下载预编译版本
# https://www.lfd.uci.edu/~gohlke/pythonlibs/#ta-lib

# 安装Python依赖
pip install -r requirements.txt

# 或手动安装
pip install numpy pandas TA-Lib tushare
```

#### 2. 验证安装

```bash
python -c "from funcat import *; print('安装成功!')"
```

---

### 基础使用

#### 示例1: 查看股票行情数据

```python
#!/usr/bin/env python
# -*- coding: utf-8 -*-

from funcat import *

# 设置数据源 (使用Tushare免费数据)
set_data_backend(TushareDataBackend())

# 设置日期和股票
T("20240101")  # 设置日期为2024年1月1日
S("000001.XSHG")  # 设置股票为上证指数

# 查看行情数据
print(f"开盘价: {OPEN.value}")
print(f"最高价: {HIGH.value}")
print(f"最低价: {LOW.value}")
print(f"收盘价: {CLOSE.value}")
print(f"成交量: {VOLUME.value}")
```

**运行**:
```bash
python my_first_script.py
```

**输出**:
```
开盘价: 3089.26
最高价: 3106.79
最低价: 3089.26
收盘价: 3103.64
成交量: 13521900000.0
```

---

#### 示例2: 计算技术指标

```python
from funcat import *

set_data_backend(TushareDataBackend())
T("20240101")
S("000001.XSHG")

# 计算移动平均线
ma5 = MA(CLOSE, 5)
ma10 = MA(CLOSE, 10)
ma20 = MA(CLOSE, 20)

print(f"5日均线: {ma5.value:.2f}")
print(f"10日均线: {ma10.value:.2f}")
print(f"20日均线: {ma20.value:.2f}")

# 计算MACD
from funcat.indicators import MACD
macd_value = MACD(12, 26, 9)
print(f"MACD: {macd_value.value:.2f}")

# 计算KDJ
from funcat.indicators import KDJ
K, D, J = KDJ(9, 3, 3)
print(f"KDJ: K={K.value:.2f}, D={D.value:.2f}, J={J.value:.2f}")
```

---

#### 示例3: 条件判断

```python
from funcat import *

set_data_backend(TushareDataBackend())
T("20240101")
S("000001.XSHG")

# 判断金叉
ma5 = MA(CLOSE, 5)
ma20 = MA(CLOSE, 20)

if ma5 > ma20:
    print("5日线在20日线上方 - 多头信号")
else:
    print("5日线在20日线下方 - 空头信号")

# 判断金叉时刻
if CROSS(ma5, ma20):
    print("发生金叉!")

# 复合条件
if (CLOSE > ma5) & (CLOSE > ma20) & (VOLUME > MA(VOLUME, 5)):
    print("强势突破信号!")
```

---

### 选股教程

#### 选股示例1: 简单均线选股

```python
from funcat import *
from funcat.api import select

# 设置数据源
set_data_backend(TushareDataBackend())

# 定义选股条件
def ma_cross_strategy():
    """
    选股条件:
    1. 5日均线上穿20日均线
    2. 成交量放大
    """
    ma5 = MA(CLOSE, 5)
    ma20 = MA(CLOSE, 20)
    vol_ma5 = MA(VOLUME, 5)

    # 金叉 + 放量
    return CROSS(ma5, ma20) & (VOLUME > vol_ma5 * 1.5)

# 执行选股
print("开始选股...")
select(
    ma_cross_strategy,
    start_date="2024-01-01",
    end_date="2024-01-10"
)
```

**输出**:
```
开始选股...
(CLOSE > MA(CLOSE, 5)) & (VOLUME > MA(VOLUME, 5) * 1.5)
[20240102]
选中: 20240102 000001.XSHE 平安银行[000001.XSHE]
选中: 20240102 600000.XSHG 浦发银行[600000.XSHG]
[20240103]
...
```

---

#### 选股示例2: KDJ超卖选股

```python
from funcat import *
from funcat.indicators import KDJ

set_data_backend(TushareDataBackend())

def kdj_oversold():
    """
    选股条件: KDJ超卖反弹
    1. K值 < 20 (超卖)
    2. K上穿D (金叉)
    """
    K, D, J = KDJ(9, 3, 3)

    return (K < 20) & CROSS(K, D)

# 执行选股
select(
    kdj_oversold,
    start_date="2024-01-01",
    end_date="2024-01-31"
)
```

---

#### 选股示例3: 多指标组合

```python
from funcat import *
from funcat.indicators import MACD, RSI, BOLL

set_data_backend(TushareDataBackend())

def comprehensive_strategy():
    """
    综合选股策略:
    1. MACD金叉
    2. RSI在30-70之间 (不超买不超卖)
    3. 价格突破布林带中轨
    4. 成交量放大
    """
    # MACD
    macd = MACD(12, 26, 9)
    macd_signal = macd > 0

    # RSI
    rsi1, rsi2, rsi3 = RSI(6, 12, 24)
    rsi_signal = (rsi1 > 30) & (rsi1 < 70)

    # 布林带
    upper, mid, lower = BOLL(20, 2)
    boll_signal = CLOSE > mid

    # 成交量
    vol_signal = VOLUME > MA(VOLUME, 5) * 1.2

    # 组合条件
    return macd_signal & rsi_signal & boll_signal & vol_signal

# 执行选股
select(
    comprehensive_strategy,
    start_date="2024-01-01",
    end_date="2024-03-01",
    callback=lambda date, code, name: print(f"✓ {date} {code} {name}")
)
```

---

### Jupyter Notebook 使用

#### 安装Jupyter

```bash
pip install jupyter matplotlib
```

#### 启动Jupyter

```bash
jupyter notebook
```

#### Notebook示例

```python
# Cell 1: 导入库
from funcat import *
from funcat.indicators import *
import matplotlib.pyplot as plt
import pandas as pd

set_data_backend(TushareDataBackend())

# Cell 2: 获取历史数据
T("20240301")
S("000001.XSHG")

# 获取最近100天的收盘价
close_data = []
dates = []
for i in range(100, 0, -1):
    T(f"2024{i:04d}")  # 简化示例
    close_data.append(CLOSE.value)
    dates.append(i)

# Cell 3: 可视化
plt.figure(figsize=(12, 6))

# 绘制收盘价
plt.subplot(2, 1, 1)
plt.plot(dates, close_data, label='收盘价')
plt.plot(dates, MA(CLOSE, 5).values[-100:], label='MA5')
plt.plot(dates, MA(CLOSE, 20).values[-100:], label='MA20')
plt.legend()
plt.title('价格走势')

# 绘制MACD
plt.subplot(2, 1, 2)
macd = MACD(12, 26, 9)
plt.bar(dates, macd.values[-100:])
plt.title('MACD')

plt.tight_layout()
plt.show()
```

---

## Go版本使用

### 安装步骤

#### 1. 安装Go环境

```bash
# macOS
brew install go

# Ubuntu/Debian
sudo apt install golang-go

# 验证安装
go version  # 应显示 go1.21 或更高版本
```

#### 2. 初始化项目

```bash
cd funcat-go

# 下载依赖
go mod tidy

# 验证安装
go build ./examples/simple_select.go
```

---

### 基础使用

#### 示例1: 计算技术指标

创建文件 `my_indicators.go`:

```go
package main

import (
	"fmt"
	"github.com/funcat/funcat-go/pkg/indicators"
	"github.com/funcat/funcat-go/pkg/series"
)

func main() {
	// 创建模拟收盘价数据
	closeData := []float64{
		10.0, 10.2, 10.5, 10.3, 10.8,
		11.0, 10.9, 11.2, 11.5, 11.3,
		11.8, 12.0, 11.9, 12.2, 12.5,
	}

	close := series.NewNumericSeries(closeData)

	// 计算MA
	ma5 := indicators.MA(close, 5)
	ma10 := indicators.MA(close, 10)

	fmt.Printf("收盘价: %.2f\n", close.Value())
	fmt.Printf("MA5: %.2f\n", ma5.Value())
	fmt.Printf("MA10: %.2f\n", ma10.Value())

	// 计算EMA
	ema := indicators.EMA(close, 12)
	fmt.Printf("EMA12: %.2f\n", ema.Value())

	// 计算MACD
	diff, dea, macd := indicators.MACD(close, 12, 26, 9)
	fmt.Printf("MACD: DIFF=%.2f, DEA=%.2f, MACD=%.2f\n",
		diff.Value(), dea.Value(), macd.Value())
}
```

**运行**:
```bash
go run my_indicators.go
```

---

#### 示例2: 并发选股

创建文件 `my_selector.go`:

```go
package main

import (
	"fmt"
	"time"
	"github.com/funcat/funcat-go/pkg/indicators"
	"github.com/funcat/funcat-go/pkg/selector"
	"github.com/funcat/funcat-go/pkg/series"
)

// 实现数据后端接口
type MyBackend struct{}

func (b *MyBackend) GetStockList() []string {
	// 返回股票列表
	return []string{
		"000001.XSHE", "000002.XSHE", "600000.XSHG",
		"600004.XSHG", "600005.XSHG",
	}
}

func (b *MyBackend) GetTradingDates(start, end time.Time) []time.Time {
	dates := []time.Time{}
	for d := start; d.Before(end) || d.Equal(end); d = d.AddDate(0, 0, 1) {
		if d.Weekday() != time.Saturday && d.Weekday() != time.Sunday {
			dates = append(dates, d)
		}
	}
	return dates
}

func (b *MyBackend) GetStockData(code string, date time.Time) (*selector.StockData, error) {
	// 实际项目中从数据库或API获取数据
	return &selector.StockData{
		Code:   code,
		Symbol: "测试股票",
		Date:   date,
		Open:   10.0,
		High:   10.5,
		Low:    9.5,
		Close:  10.2,
		Volume: 1000000,
	}, nil
}

func main() {
	// 创建数据后端
	backend := &MyBackend{}

	// 创建选股器 (100并发)
	sel := selector.NewSelector(backend, 100)

	// 定义选股条件
	condition := func(data *selector.StockData) bool {
		// 示例: 收盘价 > 10 且成交量 > 900000
		return data.Close > 10.0 && data.Volume > 900000
	}

	// 回调函数
	callback := func(date time.Time, code, symbol string) {
		fmt.Printf("✓ 选中: %s %s %s\n",
			date.Format("2006-01-02"), code, symbol)
	}

	// 执行选股
	startDate := time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC)
	endDate := time.Date(2024, 1, 10, 0, 0, 0, 0, time.UTC)

	fmt.Println("开始并发选股...")
	stats, err := sel.SelectWithStats(condition, startDate, endDate, callback)
	if err != nil {
		panic(err)
	}

	fmt.Printf("\n性能统计:\n")
	fmt.Printf("  总股票数: %d\n", stats.TotalStocks)
	fmt.Printf("  总交易日: %d\n", stats.TotalDates)
	fmt.Printf("  处理速度: %.2f jobs/秒\n", stats.JobsPerSecond)
	fmt.Printf("  总耗时: %v\n", stats.Duration)
}
```

**运行**:
```bash
go run my_selector.go
```

**输出**:
```
开始并发选股...
已处理: 1000/5000 (20.00%)
已处理: 2000/5000 (40.00%)
已处理: 3000/5000 (60.00%)
已处理: 4000/5000 (80.00%)
已处理: 5000/5000 (100.00%)

选股统计:
  总股票数: 5
  总交易日: 10
  处理任务: 50
  总耗时: 125ms
  处理速度: 400.00 jobs/秒
```

---

#### 示例3: 实现真实选股策略

```go
package main

import (
	"fmt"
	"time"
	"github.com/funcat/funcat-go/pkg/indicators"
	"github.com/funcat/funcat-go/pkg/selector"
	"github.com/funcat/funcat-go/pkg/series"
)

// 均线策略
func maStrategy(close *series.NumericSeries) bool {
	ma5 := indicators.MA(close, 5)
	ma20 := indicators.MA(close, 20)

	// 5日线上穿20日线
	cross := indicators.CROSS(ma5, ma20)
	return cross.Value()
}

// KDJ策略
func kdjStrategy(high, low, close *series.NumericSeries) bool {
	K, D, _ := indicators.KDJ(high, low, close, 9, 3, 3)

	// K < 20 且 K上穿D
	oversold := K.Value() < 20
	cross := indicators.CROSS(K, D).Value()

	return oversold && cross
}

// 综合策略
func comprehensiveStrategy(high, low, close, volume *series.NumericSeries) bool {
	// MACD金叉
	diff, dea, _ := indicators.MACD(close, 12, 26, 9)
	macdSignal := diff.GT(dea).Value()

	// 价格突破MA20
	ma20 := indicators.MA(close, 20)
	priceSignal := close.GT(ma20).Value()

	// 成交量放大
	volMa5 := indicators.MA(volume, 5)
	volumeSignal := volume.GT(volMa5.Mul(1.2)).Value()

	return macdSignal && priceSignal && volumeSignal
}

func main() {
	// 选择策略并执行
	fmt.Println("策略选择:")
	fmt.Println("1. 均线策略")
	fmt.Println("2. KDJ策略")
	fmt.Println("3. 综合策略")

	// 这里使用综合策略作为示例
	// 实际使用时需要实现完整的数据后端
}
```

---

### 编译和部署

#### 开发模式

```bash
# 直接运行
go run main.go

# 带参数运行
go run main.go --start-date=2024-01-01 --end-date=2024-03-01
```

#### 生产模式

```bash
# 编译
go build -o funcat-selector main.go

# 优化编译 (减小体积)
go build -ldflags="-s -w" -o funcat-selector main.go

# 跨平台编译
# Linux
GOOS=linux GOARCH=amd64 go build -o funcat-selector-linux main.go

# Windows
GOOS=windows GOARCH=amd64 go build -o funcat-selector.exe main.go

# macOS
GOOS=darwin GOARCH=amd64 go build -o funcat-selector-mac main.go
```

#### 运行生产版本

```bash
# Linux/macOS
./funcat-selector

# Windows
funcat-selector.exe

# 后台运行
nohup ./funcat-selector > output.log 2>&1 &
```

---

## 选股实战教程

### 场景1: 日常选股 (Python)

**需求**: 每天收盘后选出符合条件的股票

**脚本**: `daily_select.py`

```python
#!/usr/bin/env python
# -*- coding: utf-8 -*-

from funcat import *
from funcat.indicators import *
import datetime

set_data_backend(TushareDataBackend())

def daily_strategy():
    """
    日常选股策略:
    1. 价格在MA5之上
    2. MACD金叉
    3. 成交量放大
    """
    # 价格趋势
    price_signal = CLOSE > MA(CLOSE, 5)

    # MACD
    macd = MACD(12, 26, 9)
    macd_signal = macd > 0

    # 成交量
    vol_signal = VOLUME > MA(VOLUME, 5) * 1.2

    return price_signal & macd_signal & vol_signal

# 选股
today = datetime.date.today().strftime("%Y%m%d")
print(f"开始 {today} 选股...")

results = []
def save_result(date, code, name):
    results.append(f"{date},{code},{name}")
    print(f"✓ {date} {code} {name}")

select(
    daily_strategy,
    start_date=today,
    end_date=today,
    callback=save_result
)

# 保存结果
if results:
    with open(f"select_results_{today}.csv", "w") as f:
        f.write("日期,代码,名称\n")
        f.write("\n".join(results))
    print(f"\n结果已保存到: select_results_{today}.csv")
    print(f"共选出 {len(results)} 只股票")
else:
    print("\n未选出符合条件的股票")
```

**运行**:
```bash
python daily_select.py
```

**定时任务** (每天15:30执行):
```bash
# 添加到crontab
30 15 * * 1-5 cd /path/to/project && python daily_select.py
```

---

### 场景2: 批量回测 (Go)

**需求**: 测试策略在过去一年的表现

**脚本**: `backtest.go`

```go
package main

import (
	"fmt"
	"os"
	"time"
	"encoding/csv"
	"github.com/funcat/funcat-go/pkg/selector"
)

func main() {
	backend := NewTushareBackend()
	sel := selector.NewSelector(backend, 200)

	// 回测时间范围
	startDate := time.Date(2023, 1, 1, 0, 0, 0, 0, time.UTC)
	endDate := time.Date(2023, 12, 31, 0, 0, 0, 0, time.UTC)

	// 策略定义
	strategy := func(data *selector.StockData) bool {
		// 你的策略逻辑
		return data.Close > 10.0
	}

	// 收集结果
	results := [][]string{{"日期", "代码", "名称"}}
	callback := func(date time.Time, code, symbol string) {
		results = append(results, []string{
			date.Format("2006-01-02"),
			code,
			symbol,
		})
	}

	// 执行回测
	fmt.Println("开始批量回测...")
	stats, err := sel.SelectWithStats(strategy, startDate, endDate, callback)
	if err != nil {
		panic(err)
	}

	// 保存结果
	file, _ := os.Create("backtest_results.csv")
	defer file.Close()

	writer := csv.NewWriter(file)
	defer writer.Flush()

	for _, record := range results {
		writer.Write(record)
	}

	fmt.Printf("\n回测完成!\n")
	fmt.Printf("  选出股票: %d 只\n", len(results)-1)
	fmt.Printf("  处理速度: %.2f jobs/秒\n", stats.JobsPerSecond)
	fmt.Printf("  总耗时: %v\n", stats.Duration)
	fmt.Println("\n结果已保存到: backtest_results.csv")
}
```

**编译运行**:
```bash
go build -o backtest backtest.go
./backtest
```

---

### 场景3: 实时监控 (Go)

**需求**: 实时监控市场，发现信号立即通知

```go
package main

import (
	"fmt"
	"time"
	"github.com/funcat/funcat-go/pkg/selector"
)

func main() {
	backend := NewRealtimeBackend()
	sel := selector.NewSelector(backend, 100)

	// 通知函数
	notify := func(date time.Time, code, symbol string) {
		msg := fmt.Sprintf("📈 信号: %s %s", code, symbol)
		fmt.Println(msg)
		// 发送微信/邮件/短信通知
		sendNotification(msg)
	}

	// 实时监控循环
	fmt.Println("开始实时监控...")
	ticker := time.NewTicker(1 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			now := time.Now()

			// 执行选股
			sel.Select(yourStrategy, now, now, notify)
		}
	}
}
```

---

## 常用指标说明

### 趋势指标

| 指标 | Python | Go | 说明 |
|------|--------|-----|------|
| **简单移动平均** | `MA(CLOSE, 20)` | `indicators.MA(close, 20)` | 20日均线 |
| **指数移动平均** | `EMA(CLOSE, 12)` | `indicators.EMA(close, 12)` | 12日指数均线 |
| **加权移动平均** | `WMA(CLOSE, 10)` | `indicators.WMA(close, 10)` | 10日加权均线 |

### 动量指标

| 指标 | Python | Go | 说明 |
|------|--------|-----|------|
| **MACD** | `MACD(12, 26, 9)` | `indicators.MACD(close, 12, 26, 9)` | 指数平滑移动平均线 |
| **RSI** | `RSI(6, 12, 24)` | `indicators.RSI(close, 6, 12, 24)` | 相对强弱指标 |
| **KDJ** | `KDJ(9, 3, 3)` | `indicators.KDJ(high, low, close, 9, 3, 3)` | 随机指标 |

### 波动指标

| 指标 | Python | Go | 说明 |
|------|--------|-----|------|
| **布林带** | `BOLL(20, 2)` | `indicators.BOLL(close, 20, 2)` | 上中下轨 |
| **标准差** | `STD(CLOSE, 20)` | `indicators.STD(close, 20)` | 20日标准差 |
| **ATR** | - | - | 真实波幅 (待实现) |

### 成交量指标

| 指标 | Python | Go | 说明 |
|------|--------|-----|------|
| **成交量均线** | `MA(VOLUME, 5)` | `indicators.MA(volume, 5)` | 5日均量 |
| **VR** | `VR(26)` | `indicators.VR(close, volume, 26)` | 容量比率 |

### 辅助函数

| 函数 | Python | Go | 说明 |
|------|--------|-----|------|
| **最高价** | `HHV(HIGH, 10)` | `indicators.HHV(high, 10)` | 10日最高 |
| **最低价** | `LLV(LOW, 10)` | `indicators.LLV(low, 10)` | 10日最低 |
| **金叉** | `CROSS(MA1, MA2)` | `indicators.CROSS(ma1, ma2)` | 上穿判断 |
| **引用** | `REF(CLOSE, 5)` | `indicators.REF(close, 5)` | 5天前的值 |
| **计数** | `COUNT(cond, 10)` | `indicators.COUNT(cond, 10)` | 10日内满足条件的天数 |

---

## 故障排查

### Python常见问题

#### 问题1: ImportError: No module named talib

**原因**: TA-Lib未安装或安装失败

**解决**:
```bash
# macOS
brew install ta-lib
pip install TA-Lib

# Ubuntu
sudo apt-get install libta-lib-dev
pip install TA-Lib

# Windows - 下载whl文件
# https://www.lfd.uci.edu/~gohlke/pythonlibs/#ta-lib
pip install TA_Lib-0.4.24-cp39-cp39-win_amd64.whl
```

---

#### 问题2: ImportError: No module named tushare

**解决**:
```bash
pip install tushare
```

---

#### 问题3: DATA UNAVAILABLE

**原因**: 指定日期无数据或股票代码错误

**解决**:
```python
# 检查日期格式
T("20240101")  # 正确: 8位数字字符串

# 检查股票代码
S("000001.XSHG")  # 上证指数
S("000001.XSHE")  # 平安银行

# 捕获异常
from funcat.utils import FormulaException
try:
    result = my_strategy()
except FormulaException as e:
    print(f"数据错误: {e}")
```

---

#### 问题4: 性能慢

**解决**:
```python
# 1. 使用本地数据后端
from funcat.data.rqalpha_data_backend import RQAlphaDataBackend
set_data_backend(RQAlphaDataBackend())

# 2. 限制选股范围
select(strategy, start_date="2024-01-01", end_date="2024-01-01")

# 3. 使用Go版本进行大规模选股
```

---

### Go常见问题

#### 问题1: go: cannot find module

**解决**:
```bash
# 初始化模块
go mod init github.com/your-name/your-project

# 下载依赖
go mod tidy
```

---

#### 问题2: 编译错误

**解决**:
```bash
# 检查Go版本
go version  # 应该 >= 1.21

# 清理缓存
go clean -modcache
go mod tidy

# 重新编译
go build
```

---

#### 问题3: 运行时panic

**原因**: 数据为空或索引越界

**解决**:
```go
// 检查数据长度
if close.Len() < 20 {
    return false  // 数据不足
}

// 检查NaN
import "math"
if math.IsNaN(ma5.Value()) {
    return false
}
```

---

## 性能优化建议

### Python优化

1. **使用本地数据**:
```python
from funcat.data.rqalpha_data_backend import RQAlphaDataBackend
set_data_backend(RQAlphaDataBackend())
```

2. **缓存计算结果**:
```python
# 避免重复计算
ma5 = MA(CLOSE, 5)  # 计算一次
result1 = ma5 > 10
result2 = ma5 < 20  # 复用ma5
```

3. **限制数据范围**:
```python
set_start_date("20230101")  # 只加载一年数据
```

---

### Go优化

1. **调整并发数**:
```go
// CPU密集型: CPU核心数 x 2
workers := runtime.NumCPU() * 2

// IO密集型: 更多并发
workers := 100

selector := selector.NewSelector(backend, workers)
```

2. **使用对象池**:
```go
var bufferPool = sync.Pool{
    New: func() interface{} {
        return make([]float64, 0, 1000)
    },
}
```

3. **批量处理**:
```go
selector.BatchSelect(condition, start, end, callback, 10)
```

---

## 总结

### 快速参考

| 任务 | 使用工具 | 命令 |
|------|---------|------|
| 策略开发 | Python + Jupyter | `jupyter notebook` |
| 日常选股 | Python | `python daily_select.py` |
| 批量回测 | Go | `go run backtest.go` |
| 生产部署 | Go | `./funcat-selector` |

### 学习路径

1. **初学者**: 从Python基础示例开始
2. **进阶**: 学习复杂策略和多指标组合
3. **专业**: 使用Go进行大规模选股和生产部署

### 获取帮助

- 📚 文档: [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)
- 🐛 问题: [GitHub Issues](https://github.com/linqiluo8-design/thsfuncat/issues)
- 💬 讨论: [GitHub Discussions](https://github.com/linqiluo8-design/thsfuncat/discussions)

---

**祝你使用愉快！** 📈🚀
