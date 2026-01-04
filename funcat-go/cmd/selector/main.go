package main

import (
	"context"
	"database/sql"
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	_ "github.com/lib/pq"
)

// Config 配置结构
type Config struct {
	PostgresHost     string
	PostgresPort     string
	PostgresDB       string
	PostgresUser     string
	PostgresPassword string
	LogLevel         string
	SelectorInterval int // 选股执行间隔（分钟）
}

// StockLimitUpData 涨停数据结构
type StockLimitUpData struct {
	StockCode        string    `json:"stock_code"`
	StockName        string    `json:"stock_name"`
	TradeDate        time.Time `json:"trade_date"`
	ConsecutiveDays  int       `json:"consecutive_days"`
	FirstLimitTime   string    `json:"first_limit_time"`
	SealRatio        float64   `json:"seal_ratio"`
	IsOneWord        bool      `json:"is_one_word"`
	Sector           string    `json:"sector"`
	SectorLimitCount int       `json:"sector_limit_count"`
}

var (
	configFile string
	db         *sql.DB
)

func init() {
	flag.StringVar(&configFile, "config", "/app/config/selector.yaml", "配置文件路径")
}

func main() {
	flag.Parse()

	log.Println("=== Funcat 选股服务启动 ===")

	// 加载配置
	config := loadConfig()
	log.Printf("配置加载成功: DB=%s, Host=%s", config.PostgresDB, config.PostgresHost)

	// 连接数据库
	var err error
	db, err = connectDB(config)
	if err != nil {
		log.Fatalf("数据库连接失败: %v", err)
	}
	defer db.Close()

	log.Println("数据库连接成功")

	// 测试查询
	if err := testQuery(); err != nil {
		log.Printf("警告: 数据库查询测试失败: %v", err)
	}

	// 启动定时任务
	ticker := time.NewTicker(time.Duration(config.SelectorInterval) * time.Minute)
	defer ticker.Stop()

	// 立即执行一次
	log.Println("执行首次选股任务...")
	runSelectorTask()

	// 监听系统信号
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	log.Printf("选股服务运行中，每 %d 分钟执行一次...", config.SelectorInterval)

	// 主循环
	for {
		select {
		case <-ticker.C:
			log.Println("执行定时选股任务...")
			runSelectorTask()

		case sig := <-sigCh:
			log.Printf("收到信号 %v, 正在关闭服务...", sig)
			return
		}
	}
}

// loadConfig 加载配置（从环境变量）
func loadConfig() *Config {
	return &Config{
		PostgresHost:     getEnv("POSTGRES_HOST", "localhost"),
		PostgresPort:     getEnv("POSTGRES_PORT", "5432"),
		PostgresDB:       getEnv("POSTGRES_DB", "funcat"),
		PostgresUser:     getEnv("POSTGRES_USER", "funcat_user"),
		PostgresPassword: getEnv("POSTGRES_PASSWORD", "funcat_password_change_me"),
		LogLevel:         getEnv("LOG_LEVEL", "info"),
		SelectorInterval: getEnvInt("SELECTOR_INTERVAL", 60), // 默认60分钟
	}
}

// connectDB 连接PostgreSQL数据库
func connectDB(config *Config) (*sql.DB, error) {
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		config.PostgresHost,
		config.PostgresPort,
		config.PostgresUser,
		config.PostgresPassword,
		config.PostgresDB,
	)

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, fmt.Errorf("打开数据库连接失败: %w", err)
	}

	// 设置连接池参数
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(5 * time.Minute)

	// 测试连接
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := db.PingContext(ctx); err != nil {
		return nil, fmt.Errorf("数据库ping失败: %w", err)
	}

	return db, nil
}

// testQuery 测试查询数据库
func testQuery() error {
	// 查询涨停数据数量
	var count int
	query := `
		SELECT COUNT(*)
		FROM limit_up_data
		WHERE trade_date >= CURRENT_DATE - INTERVAL '7 days'
	`

	err := db.QueryRow(query).Scan(&count)
	if err != nil {
		return fmt.Errorf("查询失败: %w", err)
	}

	log.Printf("最近7天涨停数据: %d 条", count)

	// 查询最新交易日
	var latestDate time.Time
	query = `SELECT MAX(trade_date) FROM limit_up_data`
	err = db.QueryRow(query).Scan(&latestDate)
	if err != nil && err != sql.ErrNoRows {
		return fmt.Errorf("查询最新日期失败: %w", err)
	}

	if !latestDate.IsZero() {
		log.Printf("最新交易日: %s", latestDate.Format("2006-01-02"))
	}

	return nil
}

// runSelectorTask 执行选股任务
func runSelectorTask() {
	startTime := time.Now()

	// 获取今日涨停股票
	limitUpStocks, err := getTodayLimitUpStocks()
	if err != nil {
		log.Printf("获取涨停数据失败: %v", err)
		return
	}

	log.Printf("今日涨停股票: %d 只", len(limitUpStocks))

	// 分析板块效应
	sectorStats := analyzeSectorEffect(limitUpStocks)
	log.Printf("活跃板块: %d 个", len(sectorStats))

	// 输出统计信息
	for sector, count := range sectorStats {
		if count >= 3 {
			log.Printf("  %s: %d 只涨停", sector, count)
		}
	}

	// 执行炒股养家心法选股（如果表存在）
	if err := runYangjiaSelector(); err != nil {
		log.Printf("炒股养家选股执行失败: %v", err)
	}

	duration := time.Since(startTime)
	log.Printf("选股任务完成，耗时: %v", duration)
}

// getTodayLimitUpStocks 获取今日涨停股票
func getTodayLimitUpStocks() ([]StockLimitUpData, error) {
	query := `
		SELECT
			stock_code,
			stock_name,
			trade_date,
			consecutive_days,
			COALESCE(first_limit_time::text, ''),
			COALESCE(seal_ratio, 0),
			COALESCE(is_one_word, false),
			COALESCE(sector, ''),
			0 as sector_limit_count
		FROM limit_up_data
		WHERE trade_date = CURRENT_DATE
		ORDER BY consecutive_days DESC, first_limit_time ASC
		LIMIT 100
	`

	rows, err := db.Query(query)
	if err != nil {
		return nil, fmt.Errorf("查询失败: %w", err)
	}
	defer rows.Close()

	var stocks []StockLimitUpData
	for rows.Next() {
		var stock StockLimitUpData
		var firstLimitTime sql.NullString

		err := rows.Scan(
			&stock.StockCode,
			&stock.StockName,
			&stock.TradeDate,
			&stock.ConsecutiveDays,
			&firstLimitTime,
			&stock.SealRatio,
			&stock.IsOneWord,
			&stock.Sector,
			&stock.SectorLimitCount,
		)

		if err != nil {
			log.Printf("扫描行数据失败: %v", err)
			continue
		}

		if firstLimitTime.Valid {
			stock.FirstLimitTime = firstLimitTime.String
		}

		stocks = append(stocks, stock)
	}

	return stocks, nil
}

// analyzeSectorEffect 分析板块效应
func analyzeSectorEffect(stocks []StockLimitUpData) map[string]int {
	sectorCount := make(map[string]int)

	for _, stock := range stocks {
		if stock.Sector != "" {
			sectorCount[stock.Sector]++
		}
	}

	return sectorCount
}

// runYangjiaSelector 执行炒股养家心法选股
func runYangjiaSelector() error {
	// 检查表是否存在
	var exists bool
	checkQuery := `
		SELECT EXISTS (
			SELECT FROM information_schema.tables
			WHERE table_name = 'yangjia_select_results'
		)
	`
	err := db.QueryRow(checkQuery).Scan(&exists)
	if err != nil {
		return fmt.Errorf("检查表失败: %w", err)
	}

	if !exists {
		log.Println("炒股养家表不存在，跳过选股")
		return nil
	}

	// 执行选股函数
	query := `SELECT * FROM yangjia_stock_selector(CURRENT_DATE::text)`
	rows, err := db.Query(query)
	if err != nil {
		return fmt.Errorf("执行选股函数失败: %w", err)
	}
	defer rows.Close()

	count := 0
	for rows.Next() {
		count++
	}

	log.Printf("炒股养家选股完成: %d 只股票", count)
	return nil
}

// getEnv 获取环境变量
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// getEnvInt 获取整数环境变量
func getEnvInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		var intValue int
		if _, err := fmt.Sscanf(value, "%d", &intValue); err == nil {
			return intValue
		}
	}
	return defaultValue
}
