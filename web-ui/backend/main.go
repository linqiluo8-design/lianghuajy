package main

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
)

// 数据库连接
var db *sql.DB

// ============================================
// 数据模型
// ============================================

// Sector 板块信息
type Sector struct {
	ID          int       `json:"id"`
	SectorCode  string    `json:"sector_code"`
	SectorName  string    `json:"sector_name"`
	SectorType  string    `json:"sector_type"`
	StockCount  int       `json:"stock_count"`
	Description *string   `json:"description"` // 使用指针处理NULL值
	IsActive    bool      `json:"is_active"`
	CreatedAt   time.Time `json:"created_at"`
}

// SectorDailyStats 板块每日统计
type SectorDailyStats struct {
	ID                      int       `json:"id"`
	TradeDate               string    `json:"trade_date"`
	SectorID                int       `json:"sector_id"`
	SectorName              string    `json:"sector_name"`
	LimitUpCount            int       `json:"limit_up_count"`
	LimitDownCount          int       `json:"limit_down_count"`
	OneWordCount            int       `json:"one_word_count"`
	OneWordLimitDownCount   int       `json:"one_word_limit_down_count"`
	BrokenCount             int       `json:"broken_count"`
	BrokenResealedCount     int       `json:"broken_resealed_count"`
	BrokenNotResealedCount  int       `json:"broken_not_resealed_count"`
	Consecutive2Count       int       `json:"consecutive_2_count"`
	Consecutive3Count       int       `json:"consecutive_3_count"`
	Consecutive4Count       int       `json:"consecutive_4_count"`
	Consecutive5PlusCount   int       `json:"consecutive_5_plus_count"`
	TotalStocks             int       `json:"total_stocks"`
	AvgChangePct            float64   `json:"avg_change_pct"`
	TotalTurnover           float64   `json:"total_turnover"`
	CreatedAt               time.Time `json:"created_at"`
}

// DailyLimitStats 涨跌停统计
type DailyLimitStats struct {
	ID                   int       `json:"id"`
	TradeDate            string    `json:"trade_date"`
	StockCode            string    `json:"stock_code"`
	StockName            string    `json:"stock_name"`
	OpenPrice            float64   `json:"open_price"`
	ClosePrice           float64   `json:"close_price"`
	HighPrice            float64   `json:"high_price"`
	LowPrice             float64   `json:"low_price"`
	PreClose             float64   `json:"pre_close"`
	ChangePct            float64   `json:"change_pct"`
	LimitType            string    `json:"limit_type"`
	IsOneWord            bool      `json:"is_one_word"`
	IsBroken             bool      `json:"is_broken"`
	IsResealed           bool      `json:"is_resealed"`
	BrokenCount          int       `json:"broken_count"`
	ConsecutiveLimitDays int       `json:"consecutive_limit_days"`
	Volume               int64     `json:"volume"`
	Turnover             float64   `json:"turnover"`
	TurnoverRate         float64   `json:"turnover_rate"`
	SealAmount           int64     `json:"seal_amount"`
	FirstLimitTime       string    `json:"first_limit_time"`
	CreatedAt            time.Time `json:"created_at"`
}

// StockLimitDetail 个股涨跌停详情（用于前端展示）
type StockLimitDetail struct {
	ID                         int     `json:"id"`
	TradeDate                  string  `json:"trade_date"`
	StockCode                  string  `json:"stock_code"`
	StockName                  string  `json:"stock_name"`
	SectorID                   *int    `json:"sector_id"`
	SectorName                 *string `json:"sector_name"`
	OpenPrice                  float64 `json:"open_price"`
	ClosePrice                 float64 `json:"close_price"`
	PreClose                   float64 `json:"pre_close"`
	ChangePct                  float64 `json:"change_pct"`
	OpenChangePct              float64 `json:"open_change_pct"`
	LimitType                  string  `json:"limit_type"`
	IsOneWord                  bool    `json:"is_one_word"`
	IsBroken                   bool    `json:"is_broken"`
	IsResealed                 bool    `json:"is_resealed"`
	ConsecutiveLimitDays       int     `json:"consecutive_limit_days"`
	BoardDescription           string  `json:"board_description"`
	LimitReason                *string `json:"limit_reason"`
	Industry                   *string `json:"industry"`
	Volume                     int64   `json:"volume"`
	Turnover                   float64 `json:"turnover"`
	TurnoverRate               float64 `json:"turnover_rate"`
	FirstLimitTime             *string `json:"first_limit_time"`
	YesterdayAuctionUnmatched  int64   `json:"yesterday_auction_unmatched"`
	TodayAuctionUnmatched      int64   `json:"today_auction_unmatched"`
	ConceptTags                *string `json:"concept_tags"`
}

// ConsecutiveLadder 连板天梯
type ConsecutiveLadder struct {
	StockCode        string   `json:"stock_code"`
	StockName        string   `json:"stock_name"`
	ConsecutiveDays  int      `json:"consecutive_days"`
	StartDate        string   `json:"start_date"`
	TotalGainPct     float64  `json:"total_gain_pct"`
	AvgSealRatio     float64  `json:"avg_seal_ratio"`
	MainSector       string   `json:"main_sector"`
	ConceptTags      []string `json:"concept_tags"`
	ClosePrice       float64  `json:"close_price"`
	SealAmount       int64    `json:"seal_amount"`
	FirstLimitTime   string   `json:"first_limit_time"`
	IsOneWord        bool     `json:"is_one_word"`
	IsBroken         bool     `json:"is_broken"`
	BrokenCount      int      `json:"broken_count"`
}

// SectorStrength 板块强度排行
type SectorStrength struct {
	TradeDate               string  `json:"trade_date"`
	SectorID                int     `json:"sector_id"`
	SectorCode              string  `json:"sector_code"`
	SectorName              string  `json:"sector_name"`
	SectorType              string  `json:"sector_type"`
	LimitUpCount            int     `json:"limit_up_count"`
	OneWordCount            int     `json:"one_word_count"`
	LimitDownCount          int     `json:"limit_down_count"`
	OneWordLimitDownCount   int     `json:"one_word_limit_down_count"`
	BrokenCount             int     `json:"broken_count"`
	BrokenResealedCount     int     `json:"broken_resealed_count"`
	BrokenNotResealedCount  int     `json:"broken_not_resealed_count"`
	Consecutive2Count       int     `json:"consecutive_2_count"`
	Consecutive3Count       int     `json:"consecutive_3_count"`
	Consecutive4Count       int     `json:"consecutive_4_count"`
	Consecutive5PlusCount   int     `json:"consecutive_5_plus_count"`
	TotalStocks             int     `json:"total_stocks"`
	AvgChangePct            float64 `json:"avg_change_pct"`
	TotalTurnover           float64 `json:"total_turnover"`
	StrengthScore           float64 `json:"strength_score"`
	HealthRate              float64 `json:"health_rate"`
	HighConsecutiveRate     float64 `json:"high_consecutive_rate"`
	StrengthGrade           string  `json:"strength_grade"`
}

// APIResponse 统一响应格式
type APIResponse struct {
	Code    int         `json:"code"`
	Message string      `json:"message"`
	Data    interface{} `json:"data"`
}

// DailyHighestBoard 每日最高连板数统计
type DailyHighestBoard struct {
	TradeDate         string `json:"trade_date"`
	HighestBoard      int    `json:"highest_board"`
	Board5PlusCount   int    `json:"board_5_plus_count"`
	Board4Count       int    `json:"board_4_count"`
	Board3Count       int    `json:"board_3_count"`
	Board2Count       int    `json:"board_2_count"`
	TotalLimitUpCount int    `json:"total_limit_up_count"`
	OneWordCount      int    `json:"one_word_count"`
}

// YangjiaSelectResult 炒股养家选股结果
type YangjiaSelectResult struct {
	ID              int     `json:"id"`
	TradeDate       string  `json:"trade_date"`
	StockCode       string  `json:"stock_code"`
	StockName       string  `json:"stock_name"`
	StockRole       string  `json:"stock_role"`
	RoleScore       float64 `json:"role_score"`
	IsSectorLeader  bool    `json:"is_sector_leader"`
	IsFirstLimit    bool    `json:"is_first_limit"`
	LeaderStrength  float64 `json:"leader_strength"`
	ConsecutiveDays int     `json:"consecutive_days"`
	FirstLimitTime  string  `json:"first_limit_time"`
	SealStrength    float64 `json:"seal_strength"`
	TurnoverRate    float64 `json:"turnover_rate"`
	SectorName      string  `json:"sector_name"`
	SectorLimitCount int    `json:"sector_limit_count"`
	SectorPosition  int     `json:"sector_position"`
	Turnover        float64 `json:"turnover"`
	SealAmount      int64   `json:"seal_amount"`
	TotalScore      float64 `json:"total_score"`
	RecommendLevel  string  `json:"recommend_level"`
	SelectReason    string  `json:"select_reason"`
	RiskTips        string  `json:"risk_tips"`
}

// ============================================
// 数据库初始化
// ============================================

func initDB() {
	// 加载环境变量
	godotenv.Load()

	dbHost := getEnv("POSTGRES_HOST", "localhost")
	dbPort := getEnv("POSTGRES_PORT", "5432")
	dbUser := getEnv("POSTGRES_USER", "funcat_user")
	dbPassword := getEnv("POSTGRES_PASSWORD", "funcat_password_change_me")
	dbName := getEnv("POSTGRES_DB", "funcat")

	connStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		dbHost, dbPort, dbUser, dbPassword, dbName)

	var err error
	db, err = sql.Open("postgres", connStr)
	if err != nil {
		log.Fatal("数据库连接失败:", err)
	}

	// 测试连接
	if err = db.Ping(); err != nil {
		log.Fatal("数据库ping失败:", err)
	}

	// 设置连接池
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(5 * time.Minute)

	log.Println("✅ 数据库连接成功")
}

// ============================================
// API 处理函数
// ============================================

// getSectors 获取所有板块
func getSectors(c *gin.Context) {
	sectorType := c.Query("type") // industry, concept, region

	query := `
		SELECT id, sector_code, sector_name, sector_type, stock_count,
		       description, is_active, created_at
		FROM sectors
		WHERE is_active = true
	`

	args := []interface{}{}
	if sectorType != "" {
		query += " AND sector_type = $1"
		args = append(args, sectorType)
	}
	query += " ORDER BY sector_name"

	rows, err := db.Query(query, args...)
	if err != nil {
		c.JSON(http.StatusInternalServerError, APIResponse{
			Code:    500,
			Message: "查询失败: " + err.Error(),
			Data:    nil,
		})
		return
	}
	defer rows.Close()

	sectors := []Sector{}
	for rows.Next() {
		var s Sector
		err := rows.Scan(&s.ID, &s.SectorCode, &s.SectorName, &s.SectorType,
			&s.StockCount, &s.Description, &s.IsActive, &s.CreatedAt)
		if err != nil {
			log.Println("扫描错误:", err)
			continue
		}
		sectors = append(sectors, s)
	}

	c.JSON(http.StatusOK, APIResponse{
		Code:    200,
		Message: "success",
		Data:    sectors,
	})
}

// getSectorStats 获取板块统计
func getSectorStats(c *gin.Context) {
	date := c.Query("date")
	if date == "" {
		// 查询数据库中实际存在的最新日期
		var latestDate string
		err := db.QueryRow("SELECT MAX(trade_date) FROM sector_daily_stats").Scan(&latestDate)
		if err != nil || latestDate == "" {
			// 如果查询失败或没有数据，使用今天日期
			date = time.Now().Format("2006-01-02")
		} else {
			date = latestDate
		}
		log.Printf("📅 使用最新数据日期: %s", date)
	}

	query := `
		SELECT
			sds.id, sds.trade_date, sds.sector_id,
			s.sector_name,
			sds.limit_up_count, sds.limit_down_count, sds.one_word_count,
			sds.one_word_limit_down_count,
			sds.broken_count, sds.broken_resealed_count, sds.broken_not_resealed_count,
			sds.consecutive_2_count, sds.consecutive_3_count,
			sds.consecutive_4_count, sds.consecutive_5_plus_count,
			sds.total_stocks, sds.avg_change_pct, sds.total_turnover,
			sds.created_at
		FROM sector_daily_stats sds
		JOIN sectors s ON sds.sector_id = s.id
		WHERE sds.trade_date = $1
		ORDER BY sds.limit_up_count DESC, sds.total_turnover DESC
	`

	rows, err := db.Query(query, date)
	if err != nil {
		c.JSON(http.StatusInternalServerError, APIResponse{
			Code:    500,
			Message: "查询失败: " + err.Error(),
			Data:    nil,
		})
		return
	}
	defer rows.Close()

	stats := []SectorDailyStats{}
	for rows.Next() {
		var s SectorDailyStats
		err := rows.Scan(
			&s.ID, &s.TradeDate, &s.SectorID, &s.SectorName,
			&s.LimitUpCount, &s.LimitDownCount, &s.OneWordCount,
			&s.OneWordLimitDownCount,
			&s.BrokenCount, &s.BrokenResealedCount, &s.BrokenNotResealedCount,
			&s.Consecutive2Count, &s.Consecutive3Count,
			&s.Consecutive4Count, &s.Consecutive5PlusCount,
			&s.TotalStocks, &s.AvgChangePct, &s.TotalTurnover,
			&s.CreatedAt,
		)
		if err != nil {
			log.Println("扫描错误:", err)
			continue
		}
		stats = append(stats, s)
	}

	c.JSON(http.StatusOK, APIResponse{
		Code:    200,
		Message: "success",
		Data:    stats,
	})
}

// getLimitStats 获取涨跌停详细列表
func getLimitStats(c *gin.Context) {
	date := c.Query("date")
	limitType := c.Query("type") // limit_up, limit_down
	sectorID := c.Query("sector_id")

	if date == "" {
		date = time.Now().Format("2006-01-02")
	}

	query := `
		SELECT
			dls.id, dls.trade_date, dls.stock_code, dls.stock_name,
			dls.open_price, dls.close_price, dls.high_price, dls.low_price,
			dls.pre_close, dls.change_pct, dls.limit_type, dls.is_one_word,
			dls.is_broken, dls.is_resealed, dls.broken_count,
			dls.consecutive_limit_days, dls.volume, dls.turnover, dls.turnover_rate,
			dls.seal_amount, COALESCE(dls.first_limit_time::text, ''), dls.created_at
		FROM daily_limit_stats dls
	`

	conditions := []string{"dls.trade_date = $1"}
	args := []interface{}{date}
	argCount := 1

	if limitType != "" {
		argCount++
		conditions = append(conditions, fmt.Sprintf("dls.limit_type = $%d", argCount))
		args = append(args, limitType)
	}

	if sectorID != "" {
		argCount++
		conditions = append(conditions, fmt.Sprintf(`
			dls.stock_code IN (
				SELECT stock_code FROM stock_sector_mapping WHERE sector_id = $%d
			)
		`, argCount))
		args = append(args, sectorID)
	}

	if len(conditions) > 0 {
		query += " WHERE " + conditions[0]
		for i := 1; i < len(conditions); i++ {
			query += " AND " + conditions[i]
		}
	}

	query += " ORDER BY dls.consecutive_limit_days DESC, dls.first_limit_time ASC"

	rows, err := db.Query(query, args...)
	if err != nil {
		c.JSON(http.StatusInternalServerError, APIResponse{
			Code:    500,
			Message: "查询失败: " + err.Error(),
			Data:    nil,
		})
		return
	}
	defer rows.Close()

	stats := []DailyLimitStats{}
	for rows.Next() {
		var s DailyLimitStats
		err := rows.Scan(
			&s.ID, &s.TradeDate, &s.StockCode, &s.StockName,
			&s.OpenPrice, &s.ClosePrice, &s.HighPrice, &s.LowPrice,
			&s.PreClose, &s.ChangePct, &s.LimitType, &s.IsOneWord,
			&s.IsBroken, &s.IsResealed, &s.BrokenCount,
			&s.ConsecutiveLimitDays, &s.Volume, &s.Turnover, &s.TurnoverRate,
			&s.SealAmount, &s.FirstLimitTime, &s.CreatedAt,
		)
		if err != nil {
			log.Println("扫描错误:", err)
			continue
		}
		stats = append(stats, s)
	}

	c.JSON(http.StatusOK, APIResponse{
		Code:    200,
		Message: "success",
		Data:    stats,
	})
}

// getConsecutiveLadder 获取连板天梯
func getConsecutiveLadder(c *gin.Context) {
	minDays := c.DefaultQuery("min_days", "2") // 最小连板天数

	query := `
		SELECT
			stock_code, stock_name, consecutive_days, start_date,
			COALESCE(total_gain_pct, 0), COALESCE(avg_seal_ratio, 0),
			COALESCE(main_sector, ''),
			COALESCE(close_price, 0), COALESCE(seal_amount, 0),
			COALESCE(first_limit_time, ''), COALESCE(is_one_word, false),
			COALESCE(is_broken, false), COALESCE(broken_count, 0)
		FROM v_consecutive_ladder
		WHERE consecutive_days >= $1
		ORDER BY consecutive_days DESC, start_date ASC
		LIMIT 100
	`

	rows, err := db.Query(query, minDays)
	if err != nil {
		c.JSON(http.StatusInternalServerError, APIResponse{
			Code:    500,
			Message: "查询失败: " + err.Error(),
			Data:    nil,
		})
		return
	}
	defer rows.Close()

	ladder := []ConsecutiveLadder{}
	for rows.Next() {
		var l ConsecutiveLadder
		err := rows.Scan(
			&l.StockCode, &l.StockName, &l.ConsecutiveDays, &l.StartDate,
			&l.TotalGainPct, &l.AvgSealRatio, &l.MainSector,
			&l.ClosePrice, &l.SealAmount, &l.FirstLimitTime,
			&l.IsOneWord, &l.IsBroken, &l.BrokenCount,
		)
		if err != nil {
			log.Println("扫描错误:", err)
			continue
		}

		// 初始化空的概念标签数组
		l.ConceptTags = []string{}

		ladder = append(ladder, l)
	}

	c.JSON(http.StatusOK, APIResponse{
		Code:    200,
		Message: "success",
		Data:    ladder,
	})
}

// getSectorStrength 获取板块强度排行
func getSectorStrength(c *gin.Context) {
	date := c.Query("date")
	if date == "" {
		date = time.Now().Format("2006-01-02")
	}

	minStrength := c.DefaultQuery("min_strength", "0")
	limit := c.DefaultQuery("limit", "50")

	query := `
		SELECT
			trade_date, sector_id, sector_code, sector_name, sector_type,
			limit_up_count, one_word_count,
			limit_down_count, one_word_limit_down_count,
			broken_count, broken_resealed_count, broken_not_resealed_count,
			consecutive_2_count, consecutive_3_count,
			consecutive_4_count, consecutive_5_plus_count,
			total_stocks, avg_change_pct, total_turnover,
			strength_score, health_rate, high_consecutive_rate, strength_grade
		FROM v_sector_strength_ranking
		WHERE trade_date = $1
		  AND strength_score >= $2
		ORDER BY strength_score DESC, limit_up_count DESC
		LIMIT $3
	`

	rows, err := db.Query(query, date, minStrength, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, APIResponse{
			Code:    500,
			Message: "查询失败: " + err.Error(),
			Data:    nil,
		})
		return
	}
	defer rows.Close()

	strengths := []SectorStrength{}
	for rows.Next() {
		var s SectorStrength
		err := rows.Scan(
			&s.TradeDate, &s.SectorID, &s.SectorCode, &s.SectorName, &s.SectorType,
			&s.LimitUpCount, &s.OneWordCount,
			&s.LimitDownCount, &s.OneWordLimitDownCount,
			&s.BrokenCount, &s.BrokenResealedCount, &s.BrokenNotResealedCount,
			&s.Consecutive2Count, &s.Consecutive3Count,
			&s.Consecutive4Count, &s.Consecutive5PlusCount,
			&s.TotalStocks, &s.AvgChangePct, &s.TotalTurnover,
			&s.StrengthScore, &s.HealthRate, &s.HighConsecutiveRate, &s.StrengthGrade,
		)
		if err != nil {
			log.Println("扫描错误:", err)
			continue
		}
		strengths = append(strengths, s)
	}

	c.JSON(http.StatusOK, APIResponse{
		Code:    200,
		Message: "success",
		Data:    strengths,
	})
}

// getSectorStocks 获取指定板块的个股列表
func getSectorStocks(c *gin.Context) {
	date := c.Query("date")
	if date == "" {
		date = time.Now().Format("2006-01-02")
	}

	sectorName := c.Query("sector_name")
	limitType := c.Query("limit_type")   // limit_up, limit_down
	isOneWord := c.Query("is_one_word")  // true, false

	if sectorName == "" {
		c.JSON(http.StatusBadRequest, APIResponse{
			Code:    400,
			Message: "缺少板块名称参数",
			Data:    nil,
		})
		return
	}

	// 使用视图查询个股详情
	query := `
		SELECT
			id, trade_date, stock_code, stock_name,
			sector_id, sector_name,
			open_price, close_price, pre_close,
			change_pct, open_change_pct,
			limit_type, is_one_word, is_broken, is_resealed,
			consecutive_limit_days, board_description,
			limit_reason, industry,
			volume, turnover, turnover_rate,
			first_limit_time,
			yesterday_auction_unmatched, today_auction_unmatched,
			concept_tags
		FROM v_stock_limit_detail
		WHERE trade_date = $1
		  AND sector_name = $2
	`

	args := []interface{}{date, sectorName}

	// 如果指定了涨跌停类型，添加过滤条件
	if limitType != "" {
		query += fmt.Sprintf(" AND limit_type = $%d", len(args)+1)
		args = append(args, limitType)
	}

	// 如果指定了一字涨停过滤，添加过滤条件
	if isOneWord == "true" {
		query += fmt.Sprintf(" AND is_one_word = $%d", len(args)+1)
		args = append(args, true)
	}

	query += " ORDER BY consecutive_limit_days DESC, first_limit_time ASC"

	rows, err := db.Query(query, args...)
	if err != nil {
		c.JSON(http.StatusInternalServerError, APIResponse{
			Code:    500,
			Message: "查询失败: " + err.Error(),
			Data:    nil,
		})
		return
	}
	defer rows.Close()

	stocks := []StockLimitDetail{}
	for rows.Next() {
		var s StockLimitDetail
		err := rows.Scan(
			&s.ID, &s.TradeDate, &s.StockCode, &s.StockName,
			&s.SectorID, &s.SectorName,
			&s.OpenPrice, &s.ClosePrice, &s.PreClose,
			&s.ChangePct, &s.OpenChangePct,
			&s.LimitType, &s.IsOneWord, &s.IsBroken, &s.IsResealed,
			&s.ConsecutiveLimitDays, &s.BoardDescription,
			&s.LimitReason, &s.Industry,
			&s.Volume, &s.Turnover, &s.TurnoverRate,
			&s.FirstLimitTime,
			&s.YesterdayAuctionUnmatched, &s.TodayAuctionUnmatched,
			&s.ConceptTags,
		)
		if err != nil {
			log.Println("扫描错误:", err)
			continue
		}
		stocks = append(stocks, s)
	}

	c.JSON(http.StatusOK, APIResponse{
		Code:    200,
		Message: fmt.Sprintf("查询到%d只股票", len(stocks)),
		Data:    stocks,
	})
}

// getDailyHighestBoard 获取每日最高连板数统计
func getDailyHighestBoard(c *gin.Context) {
	// 获取查询天数，默认30天
	days := c.DefaultQuery("days", "30")

	query := `
		SELECT
			trade_date,
			highest_board,
			board_5_plus_count,
			board_4_count,
			board_3_count,
			board_2_count,
			total_limit_up_count,
			one_word_count
		FROM v_daily_highest_board
		ORDER BY trade_date DESC
		LIMIT $1
	`

	rows, err := db.Query(query, days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, APIResponse{
			Code:    500,
			Message: "查询失败: " + err.Error(),
			Data:    nil,
		})
		return
	}
	defer rows.Close()

	boards := []DailyHighestBoard{}
	for rows.Next() {
		var b DailyHighestBoard
		err := rows.Scan(
			&b.TradeDate,
			&b.HighestBoard,
			&b.Board5PlusCount,
			&b.Board4Count,
			&b.Board3Count,
			&b.Board2Count,
			&b.TotalLimitUpCount,
			&b.OneWordCount,
		)
		if err != nil {
			log.Println("扫描错误:", err)
			continue
		}
		boards = append(boards, b)
	}

	// 反转数组，使时间从旧到新排列（方便前端图表展示）
	for i, j := 0, len(boards)-1; i < j; i, j = i+1, j-1 {
		boards[i], boards[j] = boards[j], boards[i]
	}

	c.JSON(http.StatusOK, APIResponse{
		Code:    200,
		Message: fmt.Sprintf("查询到%d天数据", len(boards)),
		Data:    boards,
	})
}

// healthCheck 健康检查
func healthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":  "ok",
		"service": "funcat-web-ui",
		"time":    time.Now().Format("2006-01-02 15:04:05"),
	})
}

// getRealtimeStatus 获取实时数据源状态
func getRealtimeStatus(c *gin.Context) {
	// 检查今天是否有数据，且最近5分钟内有更新
	var count int
	var lastUpdate time.Time
	query := `
		SELECT COUNT(*), COALESCE(MAX(updated_at), NOW())
		FROM daily_limit_stats
		WHERE trade_date = CURRENT_DATE
		AND updated_at >= NOW() - INTERVAL '5 minutes'
	`
	err := db.QueryRow(query).Scan(&count, &lastUpdate)

	if err != nil {
		log.Printf("查询实时状态失败: %v", err)
		c.JSON(http.StatusOK, APIResponse{
			Code:    200,
			Message: "success",
			Data: gin.H{
				"running":     false,
				"source":      "unknown",
				"fetch_count": 0,
				"last_update": "",
			},
		})
		return
	}

	// 如果有最近5分钟内的数据，认为服务在线
	running := count > 0

	// 获取数据源类型（从环境变量）
	dataSource := getEnv("REALTIME_DATA_SOURCE", "akshare")

	c.JSON(http.StatusOK, APIResponse{
		Code:    200,
		Message: "success",
		Data: gin.H{
			"running":     running,
			"source":      dataSource,
			"fetch_count": count,
			"last_update": lastUpdate.Format("2006-01-02 15:04:05"),
		},
	})
}

// ============================================
// 炒股养家心法 API 处理函数
// ============================================

// runYangjiaSelector 运行炒股养家选股
func runYangjiaSelector(c *gin.Context) {
	date := c.DefaultQuery("date", time.Now().Format("2006-01-02"))

	// 调用选股函数
	query := `SELECT * FROM yangjia_stock_selector($1)`
	rows, err := db.Query(query, date)
	if err != nil {
		c.JSON(http.StatusInternalServerError, APIResponse{
			Code:    500,
			Message: "选股执行失败: " + err.Error(),
			Data:    nil,
		})
		return
	}
	defer rows.Close()

	results := []map[string]interface{}{}
	for rows.Next() {
		var stockCode, stockName, stockRole, recommendLevel, selectReason string
		var totalScore float64

		err := rows.Scan(&stockCode, &stockName, &stockRole, &totalScore, &recommendLevel, &selectReason)
		if err != nil {
			log.Println("扫描错误:", err)
			continue
		}

		results = append(results, map[string]interface{}{
			"stock_code":       stockCode,
			"stock_name":       stockName,
			"stock_role":       stockRole,
			"total_score":      totalScore,
			"recommend_level":  recommendLevel,
			"select_reason":    selectReason,
		})
	}

	c.JSON(http.StatusOK, APIResponse{
		Code:    200,
		Message: fmt.Sprintf("选股完成，共选出%d只股票", len(results)),
		Data:    results,
	})
}

// getYangjiaResults 获取炒股养家选股结果
func getYangjiaResults(c *gin.Context) {
	date := c.DefaultQuery("date", time.Now().Format("2006-01-02"))
	role := c.Query("role") // leader, middle, catchup, follower

	query := `
		SELECT
			stock_code, stock_name, stock_role, leader_strength,
			consecutive_days, first_limit_time, sector_name,
			sector_limit_count, sector_position, turnover,
			seal_amount, total_score, recommend_level, select_reason,
			COALESCE(risk_tips, '') as risk_tips
		FROM yangjia_select_results
		WHERE trade_date = $1
	`

	args := []interface{}{date}
	if role != "" {
		query += " AND stock_role = $2"
		args = append(args, role)
	}

	query += " ORDER BY total_score DESC"

	rows, err := db.Query(query, args...)
	if err != nil {
		c.JSON(http.StatusInternalServerError, APIResponse{
			Code:    500,
			Message: "查询失败: " + err.Error(),
			Data:    nil,
		})
		return
	}
	defer rows.Close()

	results := []YangjiaSelectResult{}
	for rows.Next() {
		var r YangjiaSelectResult
		err := rows.Scan(
			&r.StockCode, &r.StockName, &r.StockRole, &r.LeaderStrength,
			&r.ConsecutiveDays, &r.FirstLimitTime, &r.SectorName,
			&r.SectorLimitCount, &r.SectorPosition, &r.Turnover,
			&r.SealAmount, &r.TotalScore, &r.RecommendLevel, &r.SelectReason,
			&r.RiskTips,
		)
		if err != nil {
			log.Println("扫描错误:", err)
			continue
		}
		results = append(results, r)
	}

	c.JSON(http.StatusOK, APIResponse{
		Code:    200,
		Message: "success",
		Data:    results,
	})
}

// getYangjiaLeaders 获取龙头股
func getYangjiaLeaders(c *gin.Context) {
	date := c.DefaultQuery("date", time.Now().Format("2006-01-02"))

	query := `
		SELECT
			trade_date, stock_code, stock_name, consecutive_days,
			first_limit_time, sector_name, sector_limit_count,
			sector_position, leader_strength, seal_strength,
			turnover, total_score, recommend_level, select_reason,
			change_pct, is_one_word, is_broken
		FROM v_yangjia_leaders
		WHERE trade_date = $1
		ORDER BY total_score DESC
	`

	rows, err := db.Query(query, date)
	if err != nil {
		c.JSON(http.StatusInternalServerError, APIResponse{
			Code:    500,
			Message: "查询失败: " + err.Error(),
			Data:    nil,
		})
		return
	}
	defer rows.Close()

	results := []map[string]interface{}{}
	for rows.Next() {
		var tradeDate, stockCode, stockName, firstLimitTime, sectorName, recommendLevel, selectReason string
		var consecutiveDays, sectorLimitCount, sectorPosition int
		var leaderStrength, sealStrength, turnover, totalScore, changePct float64
		var isOneWord, isBroken bool

		err := rows.Scan(
			&tradeDate, &stockCode, &stockName, &consecutiveDays,
			&firstLimitTime, &sectorName, &sectorLimitCount,
			&sectorPosition, &leaderStrength, &sealStrength,
			&turnover, &totalScore, &recommendLevel, &selectReason,
			&changePct, &isOneWord, &isBroken,
		)
		if err != nil {
			log.Println("扫描错误:", err)
			continue
		}

		results = append(results, map[string]interface{}{
			"trade_date":         tradeDate,
			"stock_code":         stockCode,
			"stock_name":         stockName,
			"consecutive_days":   consecutiveDays,
			"first_limit_time":   firstLimitTime,
			"sector_name":        sectorName,
			"sector_limit_count": sectorLimitCount,
			"sector_position":    sectorPosition,
			"leader_strength":    leaderStrength,
			"seal_strength":      sealStrength,
			"turnover":           turnover,
			"total_score":        totalScore,
			"recommend_level":    recommendLevel,
			"select_reason":      selectReason,
			"change_pct":         changePct,
			"is_one_word":        isOneWord,
			"is_broken":          isBroken,
		})
	}

	c.JSON(http.StatusOK, APIResponse{
		Code:    200,
		Message: "success",
		Data:    results,
	})
}

// getYangjiaMiddle 获取中军股
func getYangjiaMiddle(c *gin.Context) {
	date := c.DefaultQuery("date", time.Now().Format("2006-01-02"))

	query := `
		SELECT
			trade_date, stock_code, stock_name, sector_name,
			turnover, turnover_rate, seal_amount, total_score,
			recommend_level, change_pct, consecutive_limit_days
		FROM v_yangjia_middle
		WHERE trade_date = $1
		ORDER BY total_score DESC
	`

	rows, err := db.Query(query, date)
	if err != nil {
		c.JSON(http.StatusInternalServerError, APIResponse{
			Code:    500,
			Message: "查询失败: " + err.Error(),
			Data:    nil,
		})
		return
	}
	defer rows.Close()

	results := []map[string]interface{}{}
	for rows.Next() {
		var tradeDate, stockCode, stockName, sectorName, recommendLevel string
		var consecutiveDays int
		var turnover, turnoverRate, totalScore, changePct float64
		var sealAmount int64

		err := rows.Scan(
			&tradeDate, &stockCode, &stockName, &sectorName,
			&turnover, &turnoverRate, &sealAmount, &totalScore,
			&recommendLevel, &changePct, &consecutiveDays,
		)
		if err != nil {
			log.Println("扫描错误:", err)
			continue
		}

		results = append(results, map[string]interface{}{
			"trade_date":        tradeDate,
			"stock_code":        stockCode,
			"stock_name":        stockName,
			"sector_name":       sectorName,
			"turnover":          turnover,
			"turnover_rate":     turnoverRate,
			"seal_amount":       sealAmount,
			"total_score":       totalScore,
			"recommend_level":   recommendLevel,
			"change_pct":        changePct,
			"consecutive_days":  consecutiveDays,
		})
	}

	c.JSON(http.StatusOK, APIResponse{
		Code:    200,
		Message: "success",
		Data:    results,
	})
}

// getYangjiaCatchup 获取补涨股
func getYangjiaCatchup(c *gin.Context) {
	date := c.DefaultQuery("date", time.Now().Format("2006-01-02"))

	query := `
		SELECT
			trade_date, stock_code, stock_name, sector_name,
			sector_limit_count, total_score, recommend_level,
			select_reason, change_pct, consecutive_limit_days, first_limit_time
		FROM v_yangjia_catchup
		WHERE trade_date = $1
		ORDER BY total_score DESC
	`

	rows, err := db.Query(query, date)
	if err != nil {
		c.JSON(http.StatusInternalServerError, APIResponse{
			Code:    500,
			Message: "查询失败: " + err.Error(),
			Data:    nil,
		})
		return
	}
	defer rows.Close()

	results := []map[string]interface{}{}
	for rows.Next() {
		var tradeDate, stockCode, stockName, sectorName, recommendLevel, selectReason, firstLimitTime string
		var sectorLimitCount, consecutiveDays int
		var totalScore, changePct float64

		err := rows.Scan(
			&tradeDate, &stockCode, &stockName, &sectorName,
			&sectorLimitCount, &totalScore, &recommendLevel,
			&selectReason, &changePct, &consecutiveDays, &firstLimitTime,
		)
		if err != nil {
			log.Println("扫描错误:", err)
			continue
		}

		results = append(results, map[string]interface{}{
			"trade_date":         tradeDate,
			"stock_code":         stockCode,
			"stock_name":         stockName,
			"sector_name":        sectorName,
			"sector_limit_count": sectorLimitCount,
			"total_score":        totalScore,
			"recommend_level":    recommendLevel,
			"select_reason":      selectReason,
			"change_pct":         changePct,
			"consecutive_days":   consecutiveDays,
			"first_limit_time":   firstLimitTime,
		})
	}

	c.JSON(http.StatusOK, APIResponse{
		Code:    200,
		Message: "success",
		Data:    results,
	})
}

// getYangjiaFollowers 获取跟风股
func getYangjiaFollowers(c *gin.Context) {
	date := c.DefaultQuery("date", time.Now().Format("2006-01-02"))

	query := `
		SELECT
			stock_code, stock_name, sector_name, sector_limit_count,
			total_score, recommend_level, select_reason,
			COALESCE(risk_tips, '') as risk_tips
		FROM yangjia_select_results
		WHERE trade_date = $1 AND stock_role = 'follower'
		ORDER BY total_score DESC
	`

	rows, err := db.Query(query, date)
	if err != nil {
		c.JSON(http.StatusInternalServerError, APIResponse{
			Code:    500,
			Message: "查询失败: " + err.Error(),
			Data:    nil,
		})
		return
	}
	defer rows.Close()

	results := []map[string]interface{}{}
	for rows.Next() {
		var stockCode, stockName, sectorName, recommendLevel, selectReason, riskTips string
		var sectorLimitCount int
		var totalScore float64

		err := rows.Scan(
			&stockCode, &stockName, &sectorName, &sectorLimitCount,
			&totalScore, &recommendLevel, &selectReason, &riskTips,
		)
		if err != nil {
			log.Println("扫描错误:", err)
			continue
		}

		results = append(results, map[string]interface{}{
			"stock_code":         stockCode,
			"stock_name":         stockName,
			"sector_name":        sectorName,
			"sector_limit_count": sectorLimitCount,
			"total_score":        totalScore,
			"recommend_level":    recommendLevel,
			"select_reason":      selectReason,
			"risk_tips":          riskTips,
		})
	}

	c.JSON(http.StatusOK, APIResponse{
		Code:    200,
		Message: "success",
		Data:    results,
	})
}

// ============================================
// 工具函数
// ============================================

func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}

// ============================================
// 主函数
// ============================================

func main() {
	// 初始化数据库
	initDB()
	defer db.Close()

	// 创建Gin路由
	router := gin.Default()

	// CORS配置
	config := cors.DefaultConfig()
	config.AllowAllOrigins = true
	config.AllowMethods = []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"}
	config.AllowHeaders = []string{"Origin", "Content-Type", "Authorization"}
	router.Use(cors.New(config))

	// API路由
	api := router.Group("/api/v1")
	{
		// 健康检查
		api.GET("/health", healthCheck)

		// 板块相关
		api.GET("/sectors", getSectors)
		api.GET("/sectors/stats", getSectorStats)

		// 涨跌停统计
		api.GET("/limit-stats", getLimitStats)

		// 连板天梯
		api.GET("/consecutive-ladder", getConsecutiveLadder)

		// 板块强度排行
		api.GET("/sector-strength", getSectorStrength)

		// 板块个股详情
		api.GET("/sector-stocks", getSectorStocks)

		// 每日最高连板数统计
		api.GET("/daily-highest-board", getDailyHighestBoard)

		// 实时数据源状态
		api.GET("/realtime/status", getRealtimeStatus)

		// 炒股养家心法
		api.POST("/yangjia/run-selector", runYangjiaSelector)
		api.GET("/yangjia/results", getYangjiaResults)
		api.GET("/yangjia/leaders", getYangjiaLeaders)
		api.GET("/yangjia/middle", getYangjiaMiddle)
		api.GET("/yangjia/catchup", getYangjiaCatchup)
		api.GET("/yangjia/followers", getYangjiaFollowers)
	}

	// 静态文件服务（前端页面）
	router.Static("/static", "./static")
	router.StaticFile("/", "./static/index.html")

	// 启动服务器
	port := getEnv("API_PORT", "8080")
	log.Printf("🚀 服务器启动在端口 %s\n", port)
	log.Printf("📊 访问 http://localhost:%s 查看Web UI\n", port)
	log.Printf("🔌 API文档: http://localhost:%s/api/v1/health\n", port)

	if err := router.Run(":" + port); err != nil {
		log.Fatal("服务器启动失败:", err)
	}
}
