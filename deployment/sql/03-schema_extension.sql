-- ============================================
-- Funcat 涨跌停统计扩展表结构
-- ============================================

-- ============================================
-- 1. 板块表
-- ============================================
CREATE TABLE IF NOT EXISTS sectors (
    id SERIAL PRIMARY KEY,
    sector_code VARCHAR(20) UNIQUE NOT NULL COMMENT '板块代码',
    sector_name VARCHAR(100) NOT NULL COMMENT '板块名称',
    sector_type VARCHAR(20) NOT NULL COMMENT '板块类型: industry, concept, region',
    parent_sector_id INT REFERENCES sectors(id) COMMENT '父板块ID',

    -- 元数据
    stock_count INT DEFAULT 0 COMMENT '成分股数量',
    description TEXT COMMENT '板块描述',
    sort_order INT DEFAULT 0 COMMENT '排序',
    is_active BOOLEAN DEFAULT TRUE COMMENT '是否激活',

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
    stock_code VARCHAR(20) NOT NULL COMMENT '股票代码',
    stock_name VARCHAR(50) COMMENT '股票名称',
    sector_id INT REFERENCES sectors(id) NOT NULL COMMENT '板块ID',

    -- 权重
    weight DECIMAL(5, 2) DEFAULT 1.0 COMMENT '在板块中的权重',

    -- 状态
    is_active BOOLEAN DEFAULT TRUE COMMENT '是否有效',

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
    trade_date DATE NOT NULL COMMENT '交易日期',
    stock_code VARCHAR(20) NOT NULL COMMENT '股票代码',
    stock_name VARCHAR(50) COMMENT '股票名称',

    -- 价格信息
    open_price DECIMAL(10, 2) COMMENT '开盘价',
    close_price DECIMAL(10, 2) COMMENT '收盘价',
    high_price DECIMAL(10, 2) COMMENT '最高价',
    low_price DECIMAL(10, 2) COMMENT '最低价',
    pre_close DECIMAL(10, 2) COMMENT '昨收价',

    -- 涨跌幅
    change_pct DECIMAL(10, 4) COMMENT '涨跌幅(%)',

    -- 涨跌停状态
    limit_type VARCHAR(20) COMMENT '类型: limit_up(涨停), limit_down(跌停), none',
    is_one_word BOOLEAN DEFAULT FALSE COMMENT '是否一字板',

    -- 炸板信息
    is_broken BOOLEAN DEFAULT FALSE COMMENT '是否炸板',
    broken_time TIME COMMENT '炸板时间',
    is_resealed BOOLEAN DEFAULT FALSE COMMENT '是否回封',
    reseal_time TIME COMMENT '回封时间',
    broken_count INT DEFAULT 0 COMMENT '炸板次数',

    -- 封单信息
    seal_amount BIGINT COMMENT '封单量(手)',
    seal_ratio DECIMAL(10, 4) COMMENT '封单比率',

    -- 连板信息
    consecutive_limit_days INT DEFAULT 0 COMMENT '连续涨停天数(0表示非连板)',

    -- 成交信息
    volume BIGINT COMMENT '成交量',
    turnover DECIMAL(20, 2) COMMENT '成交额',
    turnover_rate DECIMAL(10, 4) COMMENT '换手率(%)',

    -- 排序和标记
    first_limit_time TIME COMMENT '首次涨停时间',
    limit_order INT COMMENT '涨停排序',

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
    stock_code VARCHAR(20) NOT NULL COMMENT '股票代码',
    stock_name VARCHAR(50) COMMENT '股票名称',

    -- 连板周期
    start_date DATE NOT NULL COMMENT '开始日期',
    end_date DATE COMMENT '结束日期(NULL表示进行中)',
    consecutive_days INT NOT NULL COMMENT '连续天数',

    -- 状态
    status VARCHAR(20) DEFAULT 'active' COMMENT '状态: active(进行中), ended(已结束)',
    end_reason VARCHAR(50) COMMENT '结束原因: limit_down(跌停), normal(正常回调), broken(炸板未封)',

    -- 统计信息
    total_gain_pct DECIMAL(10, 4) COMMENT '累计涨幅(%)',
    avg_seal_ratio DECIMAL(10, 4) COMMENT '平均封单比率',
    total_turnover DECIMAL(20, 2) COMMENT '累计成交额',

    -- 板块信息
    main_sector VARCHAR(100) COMMENT '主板块',
    concept_tags TEXT[] COMMENT '概念标签数组',

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
    trade_date DATE NOT NULL COMMENT '交易日期',
    sector_id INT REFERENCES sectors(id) NOT NULL COMMENT '板块ID',

    -- 涨跌停统计
    limit_up_count INT DEFAULT 0 COMMENT '涨停数',
    limit_down_count INT DEFAULT 0 COMMENT '跌停数',
    one_word_count INT DEFAULT 0 COMMENT '一字涨停数',

    -- 炸板统计
    broken_count INT DEFAULT 0 COMMENT '炸板数',
    broken_resealed_count INT DEFAULT 0 COMMENT '炸板回封数',
    broken_not_resealed_count INT DEFAULT 0 COMMENT '炸板未回封数',

    -- 连板统计
    consecutive_2_count INT DEFAULT 0 COMMENT '2连板数',
    consecutive_3_count INT DEFAULT 0 COMMENT '3连板数',
    consecutive_4_count INT DEFAULT 0 COMMENT '4连板数',
    consecutive_5_plus_count INT DEFAULT 0 COMMENT '5连板以上数',

    -- 整体统计
    total_stocks INT DEFAULT 0 COMMENT '总股票数',
    up_count INT DEFAULT 0 COMMENT '上涨数',
    down_count INT DEFAULT 0 COMMENT '下跌数',
    avg_change_pct DECIMAL(10, 4) COMMENT '平均涨跌幅',

    -- 资金统计
    total_turnover DECIMAL(20, 2) COMMENT '总成交额',
    net_inflow DECIMAL(20, 2) COMMENT '净流入',

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
