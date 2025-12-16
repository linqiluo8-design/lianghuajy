package main

import (
	"fmt"
	"time"

	"github.com/funcat/funcat-go/pkg/indicators"
	"github.com/funcat/funcat-go/pkg/selector"
	"github.com/funcat/funcat-go/pkg/series"
)

// MockBackend 模拟数据后端
type MockBackend struct{}

func (m *MockBackend) GetStockList() []string {
	// 返回10只股票作为示例
	return []string{
		"000001.XSHE", "000002.XSHE", "000004.XSHE",
		"600000.XSHG", "600004.XSHG", "600005.XSHG",
		"600006.XSHG", "600007.XSHG", "600008.XSHG",
		"600009.XSHG",
	}
}

func (m *MockBackend) GetTradingDates(start, end time.Time) []time.Time {
	dates := []time.Time{}
	for d := start; d.Before(end) || d.Equal(end); d = d.AddDate(0, 0, 1) {
		// 跳过周末
		if d.Weekday() != time.Saturday && d.Weekday() != time.Sunday {
			dates = append(dates, d)
		}
	}
	return dates
}

func (m *MockBackend) GetStockData(code string, date time.Time) (*selector.StockData, error) {
	// 生成模拟数据
	return &selector.StockData{
		Code:   code,
		Symbol: "测试股票",
		Date:   date,
		Open:   10.0 + float64(date.Day())*0.1,
		High:   10.5 + float64(date.Day())*0.1,
		Low:    9.5 + float64(date.Day())*0.1,
		Close:  10.2 + float64(date.Day())*0.1,
		Volume: 1000000,
	}, nil
}

func main() {
	fmt.Println("=== Funcat Go 示例 ===\n")

	// 1. 基础技术指标计算示例
	fmt.Println("1. 技术指标计算示例:")
	demoIndicators()

	fmt.Println("\n==================================================\n")

	// 2. 并发选股示例
	fmt.Println("2. 并发选股示例:")
	demoSelector()
}

func demoIndicators() {
	// 创建模拟收盘价数据
	closeData := []float64{
		10.0, 10.2, 10.5, 10.3, 10.8,
		11.0, 10.9, 11.2, 11.5, 11.3,
		11.8, 12.0, 11.9, 12.2, 12.5,
		12.3, 12.8, 13.0, 12.9, 13.2,
	}

	close := series.NewNumericSeries(closeData)

	// 计算MA5和MA10
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

	// 判断金叉
	cross := indicators.CROSS(ma5, ma10)
	fmt.Printf("MA5金叉MA10: %v\n", cross.Value())

	// 条件判断
	condition := ma5.GT(ma10)
	fmt.Printf("MA5 > MA10: %v\n", condition.Value())
}

func demoSelector() {
	backend := &MockBackend{}
	selector := selector.NewSelector(backend, 100)

	startDate := time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC)
	endDate := time.Date(2024, 1, 10, 0, 0, 0, 0, time.UTC)

	// 定义选股条件：收盘价 > 10.5 且成交量 > 1000000
	condition := func(data *selector.StockData) bool {
		return data.Close > 10.5 && data.Volume > 1000000
	}

	// 回调函数
	callback := func(date time.Time, code, symbol string) {
		fmt.Printf("选中: %s %s %s\n",
			date.Format("2006-01-02"), code, symbol)
	}

	// 执行选股
	stats, err := selector.SelectWithStats(condition, startDate, endDate, callback)
	if err != nil {
		fmt.Printf("选股错误: %v\n", err)
		return
	}

	fmt.Printf("\n性能统计: %.2f jobs/秒\n", stats.JobsPerSecond)
}
