-- ============================================
-- 每日最高连板数统计
-- ============================================

-- 1. 创建视图：每日最高连板数统计
CREATE OR REPLACE VIEW v_daily_highest_board AS
SELECT
    trade_date,
    MAX(consecutive_limit_days) AS highest_board,
    COUNT(DISTINCT CASE WHEN consecutive_limit_days >= 5 THEN stock_code END) AS board_5_plus_count,
    COUNT(DISTINCT CASE WHEN consecutive_limit_days = 4 THEN stock_code END) AS board_4_count,
    COUNT(DISTINCT CASE WHEN consecutive_limit_days = 3 THEN stock_code END) AS board_3_count,
    COUNT(DISTINCT CASE WHEN consecutive_limit_days = 2 THEN stock_code END) AS board_2_count,
    COUNT(DISTINCT CASE WHEN limit_type = 'limit_up' THEN stock_code END) AS total_limit_up_count,
    COUNT(DISTINCT CASE WHEN is_one_word = TRUE AND limit_type = 'limit_up' THEN stock_code END) AS one_word_count
FROM daily_limit_stats
WHERE limit_type = 'limit_up'
GROUP BY trade_date
ORDER BY trade_date DESC;

-- 2. 创建索引优化查询
CREATE INDEX IF NOT EXISTS idx_daily_limit_stats_date_consecutive
    ON daily_limit_stats(trade_date, consecutive_limit_days DESC)
    WHERE limit_type = 'limit_up';

-- 完成
SELECT '✅ 每日最高连板数统计视图创建完成！' AS message,
       '视图名称: v_daily_highest_board' AS view_name;
