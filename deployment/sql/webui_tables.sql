-- ============================================
-- Funcat Web UI 所需表结构
-- 基于 web-ui/backend/main.go 数据模型
-- ============================================

SET client_encoding = 'UTF8';

-- ============================================
-- 1. 板块表
-- ============================================
CREATE TABLE IF NOT EXISTS sectors (
    id SERIAL PRIMARY KEY,
    sector_code VARCHAR(50) NOT NULL UNIQUE,
    sector_name VARCHAR(100) NOT NULL,
    sector_type VARCHAR(50),
    stock_count INT DEFAULT 0,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sectors_code ON sectors(sector_code);
CREATE INDEX IF NOT EXISTS idx_sectors_active ON sectors(is_active);

-- ============================================
-- 2. 股票板块映射表
-- ============================================
CREATE TABLE IF NOT EXISTS stock_sector_mapping (
    id SERIAL PRIMARY KEY,
    stock_code VARCHAR(20) NOT NULL,
    sector_id INT NOT NULL,
    weight DECIMAL(5, 2) DEFAULT 100.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sector_id) REFERENCES sectors(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_stock_sector_code ON stock_sector_mapping(stock_code);
CREATE INDEX IF NOT EXISTS idx_stock_sector_id ON stock_sector_mapping(sector_id);

-- ============================================
-- 3. 板块每日统计表
-- ============================================
CREATE TABLE IF NOT EXISTS sector_daily_stats (
    id SERIAL PRIMARY KEY,
    trade_date DATE NOT NULL,
    sector_id INT NOT NULL,
    sector_name VARCHAR(100),
    limit_up_count INT DEFAULT 0,
    limit_down_count INT DEFAULT 0,
    one_word_count INT DEFAULT 0,
    broken_count INT DEFAULT 0,
    broken_resealed_count INT DEFAULT 0,
    broken_not_resealed_count INT DEFAULT 0,
    consecutive_2_count INT DEFAULT 0,
    consecutive_3_count INT DEFAULT 0,
    consecutive_4_count INT DEFAULT 0,
    consecutive_5_plus_count INT DEFAULT 0,
    total_stocks INT DEFAULT 0,
    avg_change_pct DECIMAL(10, 4),
    total_turnover DECIMAL(20, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sector_id) REFERENCES sectors(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_sector_daily_date ON sector_daily_stats(trade_date);
CREATE INDEX IF NOT EXISTS idx_sector_daily_sector ON sector_daily_stats(sector_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_sector_daily_unique ON sector_daily_stats(trade_date, sector_id);

-- ============================================
-- 4. 每日涨跌停统计表
-- ============================================
CREATE TABLE IF NOT EXISTS daily_limit_stats (
    id SERIAL PRIMARY KEY,
    trade_date DATE NOT NULL,
    stock_code VARCHAR(20) NOT NULL,
    stock_name VARCHAR(50),
    open_price DECIMAL(10, 2),
    close_price DECIMAL(10, 2),
    high_price DECIMAL(10, 2),
    low_price DECIMAL(10, 2),
    pre_close DECIMAL(10, 2),
    change_pct DECIMAL(10, 4),
    limit_type VARCHAR(20),
    is_one_word BOOLEAN DEFAULT FALSE,
    is_broken BOOLEAN DEFAULT FALSE,
    is_resealed BOOLEAN DEFAULT FALSE,
    broken_count INT DEFAULT 0,
    consecutive_limit_days INT DEFAULT 1,
    volume BIGINT,
    turnover DECIMAL(20, 2),
    turnover_rate DECIMAL(10, 4),
    seal_amount BIGINT,
    first_limit_time TIME,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_daily_limit_date ON daily_limit_stats(trade_date);
CREATE INDEX IF NOT EXISTS idx_daily_limit_code ON daily_limit_stats(stock_code);
CREATE INDEX IF NOT EXISTS idx_daily_limit_type ON daily_limit_stats(limit_type);
CREATE INDEX IF NOT EXISTS idx_daily_limit_consecutive ON daily_limit_stats(consecutive_limit_days);
CREATE UNIQUE INDEX IF NOT EXISTS idx_daily_limit_unique ON daily_limit_stats(trade_date, stock_code);

-- ============================================
-- 5. 连板天梯视图
-- ============================================
CREATE OR REPLACE VIEW v_consecutive_ladder AS
SELECT
    stock_code,
    stock_name,
    consecutive_limit_days AS consecutive_days,
    trade_date::TEXT AS start_date,
    change_pct AS total_gain_pct,
    CASE
        WHEN seal_amount > 0 AND volume > 0
        THEN CAST(seal_amount AS DECIMAL) / NULLIF(volume, 0)
        ELSE 0
    END AS avg_seal_ratio,
    '' AS main_sector,
    close_price,
    seal_amount,
    first_limit_time::TEXT,
    is_one_word,
    is_broken,
    broken_count
FROM daily_limit_stats
WHERE limit_type = 'limit_up'
  AND consecutive_limit_days >= 2
ORDER BY consecutive_limit_days DESC, first_limit_time ASC;

-- ============================================
-- 6. 插入示例板块数据
-- ============================================
INSERT INTO sectors (sector_code, sector_name, sector_type, stock_count) VALUES
    ('BK0001', '新能源', 'industry', 0),
    ('BK0002', '半导体', 'industry', 0),
    ('BK0003', '军工', 'industry', 0),
    ('BK0004', '医药', 'industry', 0),
    ('BK0005', '白酒', 'industry', 0),
    ('BK0006', '消费电子', 'industry', 0),
    ('BK0007', '人工智能', 'concept', 0),
    ('BK0008', '数字经济', 'concept', 0)
ON CONFLICT (sector_code) DO NOTHING;

-- 完成
SELECT 'Web UI 表结构创建完成！' AS message,
       (SELECT COUNT(*) FROM sectors) AS sectors_count,
       '已插入示例板块数据' AS note;
