-- ============================================
-- 炒股养家心法选股结果表（独立版本）
-- ============================================

-- 创建limit_up_data涨停数据表
CREATE TABLE IF NOT EXISTS limit_up_data (
    id SERIAL PRIMARY KEY,
    stock_code VARCHAR(20) NOT NULL,
    stock_name VARCHAR(50),
    trade_date DATE NOT NULL,
    consecutive_days INT DEFAULT 1,
    first_limit_time TIME,
    seal_ratio DECIMAL(10, 4),
    is_one_word BOOLEAN DEFAULT FALSE,
    sector VARCHAR(100),
    turnover DECIMAL(20, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_limit_up_date ON limit_up_data(trade_date);
CREATE INDEX IF NOT EXISTS idx_limit_up_code ON limit_up_data(stock_code);

-- 创建炒股养家选股结果表
CREATE TABLE IF NOT EXISTS yangjia_select_results (
    id SERIAL PRIMARY KEY,
    trade_date DATE NOT NULL,
    stock_code VARCHAR(20) NOT NULL,
    stock_name VARCHAR(50),
    
    stock_role VARCHAR(20) NOT NULL,
    role_score DECIMAL(10, 4),
    
    is_sector_leader BOOLEAN DEFAULT FALSE,
    is_first_limit BOOLEAN DEFAULT FALSE,
    leader_strength DECIMAL(10, 4),
    
    consecutive_days INT DEFAULT 0,
    first_limit_time TIME,
    seal_strength DECIMAL(10, 4),
    turnover_rate DECIMAL(10, 4),
    
    sector_name VARCHAR(100),
    sector_limit_count INT,
    sector_position INT,
    
    turnover DECIMAL(20, 2),
    seal_amount BIGINT,
    
    total_score DECIMAL(10, 4),
    recommend_level VARCHAR(10),
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_yangjia_date ON yangjia_select_results(trade_date);
CREATE INDEX IF NOT EXISTS idx_yangjia_code ON yangjia_select_results(stock_code);
CREATE INDEX IF NOT EXISTS idx_yangjia_role ON yangjia_select_results(stock_role);
CREATE INDEX IF NOT EXISTS idx_yangjia_score ON yangjia_select_results(total_score);

-- 创建龙头强度计算函数
CREATE OR REPLACE FUNCTION calculate_leader_strength(
    p_consecutive_days INT,
    p_first_limit_time TIME,
    p_seal_ratio DECIMAL,
    p_is_one_word BOOLEAN,
    p_sector_position INT
) RETURNS DECIMAL AS $$
DECLARE
    strength DECIMAL := 0;
BEGIN
    strength := strength + LEAST(p_consecutive_days * 8, 40);
    
    IF p_first_limit_time < '09:35:00' THEN
        strength := strength + 30;
    ELSIF p_first_limit_time < '10:00:00' THEN
        strength := strength + 20;
    ELSIF p_first_limit_time < '14:00:00' THEN
        strength := strength + 10;
    END IF;
    
    IF p_seal_ratio >= 10 THEN
        strength := strength + 20;
    ELSIF p_seal_ratio >= 5 THEN
        strength := strength + 15;
    ELSIF p_seal_ratio >= 2 THEN
        strength := strength + 10;
    END IF;
    
    IF p_is_one_word THEN
        strength := strength + 5;
    END IF;
    
    IF p_sector_position = 1 THEN
        strength := strength + 5;
    END IF;
    
    RETURN LEAST(strength, 100);
END;
$$ LANGUAGE plpgsql;

-- 炒股养家选股函数
CREATE OR REPLACE FUNCTION yangjia_stock_selector(p_date TEXT DEFAULT NULL)
RETURNS TABLE (
    stock_code VARCHAR,
    stock_name VARCHAR,
    stock_role VARCHAR,
    leader_strength DECIMAL,
    total_score DECIMAL,
    recommend_level VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        l.stock_code,
        l.stock_name,
        'leader'::VARCHAR AS stock_role,
        calculate_leader_strength(
            l.consecutive_days,
            l.first_limit_time,
            l.seal_ratio,
            l.is_one_word,
            1
        ) AS leader_strength,
        CAST(50.0 AS DECIMAL) AS total_score,
        'A'::VARCHAR AS recommend_level
    FROM limit_up_data l
    WHERE l.trade_date = COALESCE(p_date::DATE, CURRENT_DATE)
    ORDER BY consecutive_days DESC, first_limit_time ASC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;

-- 龙头股视图
CREATE OR REPLACE VIEW v_yangjia_leaders AS
SELECT * FROM yangjia_select_results
WHERE stock_role = 'leader'
ORDER BY trade_date DESC, total_score DESC;

-- 中军股视图
CREATE OR REPLACE VIEW v_yangjia_middle AS
SELECT * FROM yangjia_select_results
WHERE stock_role = 'middle'
ORDER BY trade_date DESC, total_score DESC;

-- 补涨股视图
CREATE OR REPLACE VIEW v_yangjia_catchup AS
SELECT * FROM yangjia_select_results
WHERE stock_role = 'catchup'
ORDER BY trade_date DESC, total_score DESC;

-- 完成
SELECT '炒股养家心法表结构创建完成！' AS message;
