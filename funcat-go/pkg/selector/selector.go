package selector

import (
	"context"
	"fmt"
	"sync"
	"time"
)

// StockData 股票数据
type StockData struct {
	Code   string
	Symbol string
	Date   time.Time
	Open   float64
	High   float64
	Low    float64
	Close  float64
	Volume float64
}

// Condition 选股条件函数
type Condition func(data *StockData) bool

// Callback 回调函数
type Callback func(date time.Time, code, symbol string)

// DataBackend 数据后端接口
type DataBackend interface {
	GetStockList() []string
	GetTradingDates(start, end time.Time) []time.Time
	GetStockData(code string, date time.Time) (*StockData, error)
}

// Selector 选股器
type Selector struct {
	backend     DataBackend
	maxWorkers  int
	rateLimiter chan struct{}
}

// NewSelector 创建选股器
func NewSelector(backend DataBackend, maxWorkers int) *Selector {
	if maxWorkers <= 0 {
		maxWorkers = 100
	}

	return &Selector{
		backend:     backend,
		maxWorkers:  maxWorkers,
		rateLimiter: make(chan struct{}, maxWorkers),
	}
}

// Select 执行选股
func (s *Selector) Select(condition Condition, startDate, endDate time.Time, callback Callback) error {
	codes := s.backend.GetStockList()
	dates := s.backend.GetTradingDates(startDate, endDate)

	fmt.Printf("开始选股: %d 只股票, %d 个交易日\n", len(codes), len(dates))

	var wg sync.WaitGroup
	ctx := context.Background()

	// 遍历每个日期
	for _, date := range dates {
		fmt.Printf("[%s] 处理中...\n", date.Format("2006-01-02"))

		// 为每只股票创建goroutine
		for _, code := range codes {
			wg.Add(1)

			// 限流
			s.rateLimiter <- struct{}{}

			go func(d time.Time, c string) {
				defer wg.Done()
				defer func() { <-s.rateLimiter }()

				// 检查context是否取消
				select {
				case <-ctx.Done():
					return
				default:
				}

				// 获取股票数据
				data, err := s.backend.GetStockData(c, d)
				if err != nil {
					return
				}

				// 执行选股条件
				if condition(data) {
					callback(d, c, data.Symbol)
				}
			}(date, code)
		}
	}

	wg.Wait()
	fmt.Println("选股完成!")

	return nil
}

// SelectWithTimeout 带超时的选股
func (s *Selector) SelectWithTimeout(condition Condition, startDate, endDate time.Time, callback Callback, timeout time.Duration) error {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	codes := s.backend.GetStockList()
	dates := s.backend.GetTradingDates(startDate, endDate)

	fmt.Printf("开始选股: %d 只股票, %d 个交易日, 超时时间: %v\n", len(codes), len(dates), timeout)

	var wg sync.WaitGroup
	errCh := make(chan error, 1)

	// 遍历每个日期
	for _, date := range dates {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}

		fmt.Printf("[%s] 处理中...\n", date.Format("2006-01-02"))

		// 为每只股票创建goroutine
		for _, code := range codes {
			wg.Add(1)

			// 限流
			s.rateLimiter <- struct{}{}

			go func(d time.Time, c string) {
				defer wg.Done()
				defer func() { <-s.rateLimiter }()

				// 检查context是否取消
				select {
				case <-ctx.Done():
					return
				default:
				}

				// 获取股票数据
				data, err := s.backend.GetStockData(c, d)
				if err != nil {
					select {
					case errCh <- err:
					default:
					}
					return
				}

				// 执行选股条件
				if condition(data) {
					callback(d, c, data.Symbol)
				}
			}(date, code)
		}
	}

	// 等待完成或超时
	done := make(chan struct{})
	go func() {
		wg.Wait()
		close(done)
	}()

	select {
	case <-done:
		fmt.Println("选股完成!")
		return nil
	case err := <-errCh:
		return err
	case <-ctx.Done():
		return ctx.Err()
	}
}

// BatchSelect 批量选股（按日期批次）
func (s *Selector) BatchSelect(condition Condition, startDate, endDate time.Time, callback Callback, batchSize int) error {
	codes := s.backend.GetStockList()
	dates := s.backend.GetTradingDates(startDate, endDate)

	if batchSize <= 0 {
		batchSize = 10
	}

	fmt.Printf("开始批量选股: %d 只股票, %d 个交易日, 批次大小: %d\n", len(codes), len(dates), batchSize)

	// 按批次处理日期
	for i := 0; i < len(dates); i += batchSize {
		end := i + batchSize
		if end > len(dates) {
			end = len(dates)
		}

		batch := dates[i:end]
		fmt.Printf("处理批次 %d-%d (共 %d 个日期)\n", i+1, end, len(batch))

		var wg sync.WaitGroup

		for _, date := range batch {
			for _, code := range codes {
				wg.Add(1)

				// 限流
				s.rateLimiter <- struct{}{}

				go func(d time.Time, c string) {
					defer wg.Done()
					defer func() { <-s.rateLimiter }()

					data, err := s.backend.GetStockData(c, d)
					if err != nil {
						return
					}

					if condition(data) {
						callback(d, c, data.Symbol)
					}
				}(date, code)
			}
		}

		wg.Wait()
	}

	fmt.Println("批量选股完成!")
	return nil
}

// Stats 选股统计信息
type Stats struct {
	TotalStocks   int
	TotalDates    int
	ProcessedJobs int
	Duration      time.Duration
	JobsPerSecond float64
}

// SelectWithStats 带统计的选股
func (s *Selector) SelectWithStats(condition Condition, startDate, endDate time.Time, callback Callback) (*Stats, error) {
	startTime := time.Now()

	codes := s.backend.GetStockList()
	dates := s.backend.GetTradingDates(startDate, endDate)

	stats := &Stats{
		TotalStocks: len(codes),
		TotalDates:  len(dates),
	}

	fmt.Printf("开始选股: %d 只股票 x %d 个交易日 = %d 个任务\n",
		stats.TotalStocks, stats.TotalDates, stats.TotalStocks*stats.TotalDates)

	var wg sync.WaitGroup
	var mu sync.Mutex
	processedJobs := 0

	for _, date := range dates {
		for _, code := range codes {
			wg.Add(1)
			s.rateLimiter <- struct{}{}

			go func(d time.Time, c string) {
				defer wg.Done()
				defer func() { <-s.rateLimiter }()

				data, err := s.backend.GetStockData(c, d)
				if err != nil {
					return
				}

				if condition(data) {
					callback(d, c, data.Symbol)
				}

				mu.Lock()
				processedJobs++
				if processedJobs%1000 == 0 {
					fmt.Printf("已处理: %d/%d (%.2f%%)\n",
						processedJobs,
						stats.TotalStocks*stats.TotalDates,
						float64(processedJobs)/float64(stats.TotalStocks*stats.TotalDates)*100)
				}
				mu.Unlock()
			}(date, code)
		}
	}

	wg.Wait()

	stats.Duration = time.Since(startTime)
	stats.ProcessedJobs = processedJobs
	stats.JobsPerSecond = float64(processedJobs) / stats.Duration.Seconds()

	fmt.Printf("\n选股统计:\n")
	fmt.Printf("  总股票数: %d\n", stats.TotalStocks)
	fmt.Printf("  总交易日: %d\n", stats.TotalDates)
	fmt.Printf("  处理任务: %d\n", stats.ProcessedJobs)
	fmt.Printf("  总耗时: %v\n", stats.Duration)
	fmt.Printf("  处理速度: %.2f jobs/秒\n", stats.JobsPerSecond)

	return stats, nil
}
