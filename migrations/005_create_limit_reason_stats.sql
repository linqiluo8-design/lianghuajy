-- 创建涨停原因统计表（辅助视图）
-- 用途：分析涨停原因分类（板块轮动、政策利好等）

CREATE TABLE IF NOT EXISTS limit_reason_stats (
    id SERIAL PRIMARY KEY,
    trade_date DATE NOT NULL,
    reason_name VARCHAR(200) NOT NULL,

    -- 涨跌停统计
    limit_up_count INTEGER DEFAULT 0,
    limit_down_count INTEGER DEFAULT 0,
    one_word_count INTEGER DEFAULT 0,
    broken_count INTEGER DEFAULT 0,

    -- 汇总数据
    total_stocks INTEGER DEFAULT 0,
    avg_change_pct DECIMAL(10, 2),

    -- 元数据
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- 唯一约束：每个日期的每个原因只有一条记录
    UNIQUE(trade_date, reason_name)
);

-- 创建索引加速查询
CREATE INDEX IF NOT EXISTS idx_limit_reason_stats_trade_date
ON limit_reason_stats(trade_date);

CREATE INDEX IF NOT EXISTS idx_limit_reason_stats_limit_up_count
ON limit_reason_stats(limit_up_count DESC);

-- 添加注释
COMMENT ON TABLE limit_reason_stats IS '涨停原因统计表（辅助分析视图）';
COMMENT ON COLUMN limit_reason_stats.reason_name IS '涨停原因分类（如：板块轮动、政策利好）';
COMMENT ON COLUMN limit_reason_stats.limit_up_count IS '该原因的涨停股票数量';
