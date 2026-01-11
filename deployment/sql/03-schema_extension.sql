-- ============================================
-- Funcat 涨跌停统计扩展表结构
-- ============================================

-- ============================================
-- 1. 板块表
-- ============================================
CREATE TABLE IF NOT EXISTS sectors (
    id SERIAL PRIMARY KEY,
    sector_code VARCHAR(20) UNIQUE NOT NULL,
    sector_name VARCHAR(100) NOT NULL,
    sector_type VARCHAR(20) NOT NULL,
    parent_sector_id INT REFERENCES sectors(id),

    -- 元数据
    stock_count INT DEFAULT 0,
    description TEXT,
    sort_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_sectors_code ON sectors(sector_code);
CREATE INDEX idx_sectors_type ON sectors(sector_type);
CREATE INDEX idx_sectors_active ON sectors(is_active);

COMMENT ON TABLE sectors IS '板块信息表';

-- ============================================
-- 2. 股票-板块映射表
-- ============================================
CREATE TABLE IF NOT EXISTS stock_sector_mapping (
    id SERIAL PRIMARY KEY,
    stock_code VARCHAR(20) NOT NULL,
    stock_name VARCHAR(50),
    sector_id INT REFERENCES sectors(id) NOT NULL,

    -- 权重
    weight DECIMAL(5, 2) DEFAULT 1.0,

    -- 状态
    is_active BOOLEAN DEFAULT TRUE,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(stock_code, sector_id)
);

CREATE INDEX idx_stock_sector_stock ON stock_sector_mapping(stock_code);
CREATE INDEX idx_stock_sector_sector ON stock_sector_mapping(sector_id);

COMMENT ON TABLE stock_sector_mapping IS '股票-板块映射表';

-- ============================================
-- 3. 每日涨跌停统计表
-- ============================================
CREATE TABLE IF NOT EXISTS daily_limit_stats (
    id SERIAL PRIMARY KEY,
    trade_date DATE NOT NULL,
    stock_code VARCHAR(20) NOT NULL,
    stock_name VARCHAR(50),

    -- 价格信息
    open_price DECIMAL(10, 2),
    close_price DECIMAL(10, 2),
    high_price DECIMAL(10, 2),
    low_price DECIMAL(10, 2),
    pre_close DECIMAL(10, 2),

    -- 涨跌幅
    change_pct DECIMAL(10, 4),

    -- 涨跌停状态
    limit_type VARCHAR(20),
    is_one_word BOOLEAN DEFAULT FALSE,

    -- 炸板信息
    is_broken BOOLEAN DEFAULT FALSE,
    broken_time TIME,
    is_resealed BOOLEAN DEFAULT FALSE,
    reseal_time TIME,
    broken_count INT DEFAULT 0,

    -- 封单信息
    seal_amount BIGINT,
    seal_ratio DECIMAL(10, 4),

    -- 连板信息
    consecutive_limit_days INT DEFAULT 0,

    -- 成交信息
    volume BIGINT,
    turnover DECIMAL(20, 2),
    turnover_rate DECIMAL(10, 4),

    -- 排序和标记
    first_limit_time TIME,
    limit_order INT,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(trade_date, stock_code)
);

CREATE INDEX idx_daily_limit_date ON daily_limit_stats(trade_date);
CREATE INDEX idx_daily_limit_stock ON daily_limit_stats(stock_code);
CREATE INDEX idx_daily_limit_type ON daily_limit_stats(limit_type);
CREATE INDEX idx_daily_limit_consecutive ON daily_limit_stats(consecutive_limit_days);
CREATE INDEX idx_daily_limit_date_type ON daily_limit_stats(trade_date, limit_type);

COMMENT ON TABLE daily_limit_stats IS '每日涨跌停统计表';

-- ============================================
-- 4. 连板记录表
-- ============================================
CREATE TABLE IF NOT EXISTS consecutive_limits (
    id SERIAL PRIMARY KEY,
    stock_code VARCHAR(20) NOT NULL,
    stock_name VARCHAR(50),

    -- 连板周期
    start_date DATE NOT NULL,
    end_date DATE,
    consecutive_days INT NOT NULL,

    -- 状态
    status VARCHAR(20) DEFAULT 'active',
    end_reason VARCHAR(50),

    -- 统计信息
    total_gain_pct DECIMAL(10, 4),
    avg_seal_ratio DECIMAL(10, 4),
    total_turnover DECIMAL(20, 2),

    -- 板块信息
    main_sector VARCHAR(100),
    concept_tags TEXT[],

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_consecutive_limits_stock ON consecutive_limits(stock_code);
CREATE INDEX idx_consecutive_limits_status ON consecutive_limits(status);
CREATE INDEX idx_consecutive_limits_days ON consecutive_limits(consecutive_days);
CREATE INDEX idx_consecutive_limits_start_date ON consecutive_limits(start_date);

COMMENT ON TABLE consecutive_limits IS '连板记录表';

-- ============================================
-- 5. 板块每日统计表
-- ============================================
CREATE TABLE IF NOT EXISTS sector_daily_stats (
    id SERIAL PRIMARY KEY,
    trade_date DATE NOT NULL,
    sector_id INT REFERENCES sectors(id) NOT NULL,

    -- 涨跌停统计
    limit_up_count INT DEFAULT 0,
    limit_down_count INT DEFAULT 0,
    one_word_count INT DEFAULT 0,

    -- 炸板统计
    broken_count INT DEFAULT 0,
    broken_resealed_count INT DEFAULT 0,
    broken_not_resealed_count INT DEFAULT 0,

    -- 连板统计
    consecutive_2_count INT DEFAULT 0,
    consecutive_3_count INT DEFAULT 0,
    consecutive_4_count INT DEFAULT 0,
    consecutive_5_plus_count INT DEFAULT 0,

    -- 整体统计
    total_stocks INT DEFAULT 0,
    up_count INT DEFAULT 0,
    down_count INT DEFAULT 0,
    avg_change_pct DECIMAL(10, 4),

    -- 资金统计
    total_turnover DECIMAL(20, 2),
    net_inflow DECIMAL(20, 2),

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(trade_date, sector_id)
);

CREATE INDEX idx_sector_daily_stats_date ON sector_daily_stats(trade_date);
CREATE INDEX idx_sector_daily_stats_sector ON sector_daily_stats(sector_id);

COMMENT ON TABLE sector_daily_stats IS '板块每日统计表';

-- ============================================
-- 6. 创建视图：连板天梯
-- ============================================
CREATE OR REPLACE VIEW v_consecutive_ladder AS
SELECT
    cl.stock_code,
    cl.stock_name,
    cl.consecutive_days,
    cl.start_date,
    cl.total_gain_pct,
    cl.avg_seal_ratio,
    cl.main_sector,
    cl.concept_tags,
    dls.close_price,
    dls.seal_amount,
    dls.first_limit_time,
    dls.is_one_word,
    dls.is_broken,
    dls.broken_count
FROM consecutive_limits cl
LEFT JOIN daily_limit_stats dls ON cl.stock_code = dls.stock_code
    AND dls.trade_date = (SELECT MAX(trade_date) FROM daily_limit_stats WHERE stock_code = cl.stock_code)
WHERE cl.status = 'active'
ORDER BY cl.consecutive_days DESC, cl.start_date ASC;

COMMENT ON VIEW v_consecutive_ladder IS '连板天梯视图';

-- ============================================
-- 7. 创建视图：板块涨停统计
-- ============================================
CREATE OR REPLACE VIEW v_sector_limit_stats AS
SELECT
    s.id as sector_id,
    s.sector_code,
    s.sector_name,
    s.sector_type,
    sds.trade_date,
    sds.limit_up_count,
    sds.limit_down_count,
    sds.one_word_count,
    sds.broken_count,
    sds.broken_resealed_count,
    sds.broken_not_resealed_count,
    sds.consecutive_2_count,
    sds.consecutive_3_count,
    sds.consecutive_4_count,
    sds.consecutive_5_plus_count,
    sds.total_stocks,
    sds.avg_change_pct,
    sds.total_turnover,
    sds.net_inflow
FROM sectors s
LEFT JOIN sector_daily_stats sds ON s.id = sds.sector_id
ORDER BY sds.trade_date DESC, sds.limit_up_count DESC;

COMMENT ON VIEW v_sector_limit_stats IS '板块涨停统计视图';

-- ============================================
-- 8. 创建触发器
-- ============================================
CREATE TRIGGER update_sectors_updated_at
    BEFORE UPDATE ON sectors
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_stock_sector_mapping_updated_at
    BEFORE UPDATE ON stock_sector_mapping
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_consecutive_limits_updated_at
    BEFORE UPDATE ON consecutive_limits
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 完成
-- ============================================
\echo '涨跌停统计扩展表结构创建完成!'
