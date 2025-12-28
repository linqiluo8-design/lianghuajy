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
	Description string    `json:"description"`
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

// APIResponse 统一响应格式
type APIResponse struct {
	Code    int         `json:"code"`
	Message string      `json:"message"`
	Data    interface{} `json:"data"`
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
		// 默认使用最新日期
		date = time.Now().Format("2006-01-02")
	}

	query := `
		SELECT
			sds.id, sds.trade_date, sds.sector_id,
			s.sector_name,
			sds.limit_up_count, sds.limit_down_count, sds.one_word_count,
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

// healthCheck 健康检查
func healthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":  "ok",
		"service": "funcat-web-ui",
		"time":    time.Now().Format("2006-01-02 15:04:05"),
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
