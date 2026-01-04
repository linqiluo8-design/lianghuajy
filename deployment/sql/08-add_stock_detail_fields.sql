-- ============================================
-- 扩展个股涨跌停统计表 - 支持个股详情展示
-- ============================================

-- 1. 添加新字段到 daily_limit_stats 表
ALTER TABLE daily_limit_stats
ADD COLUMN IF NOT EXISTS sector_id INT REFERENCES sectors(id),
ADD COLUMN IF NOT EXISTS limit_reason TEXT,
ADD COLUMN IF NOT EXISTS industry VARCHAR(100),
ADD COLUMN IF NOT EXISTS yesterday_auction_unmatched BIGINT DEFAULT 0,
ADD COLUMN IF NOT EXISTS today_auction_unmatched BIGINT DEFAULT 0,
ADD COLUMN IF NOT EXISTS concept_tags TEXT;

-- 2. 添加注释
COMMENT ON COLUMN daily_limit_stats.sector_id IS '所属主板块ID';
COMMENT ON COLUMN daily_limit_stats.limit_reason IS '涨停/跌停原因';
COMMENT ON COLUMN daily_limit_stats.industry IS '所属行业';
COMMENT ON COLUMN daily_limit_stats.yesterday_auction_unmatched IS '昨日竞价未匹配金额（封单量）';
COMMENT ON COLUMN daily_limit_stats.today_auction_unmatched IS '今日竞价未匹配金额（封单量）';
COMMENT ON COLUMN daily_limit_stats.concept_tags IS '概念题材标签（逗号分隔）';

-- 3. 创建索引优化查询
CREATE INDEX IF NOT EXISTS idx_daily_limit_sector ON daily_limit_stats(sector_id);

-- 4. 创建视图：个股详情（包含计算字段）
CREATE OR REPLACE VIEW v_stock_limit_detail AS
SELECT
    dls.id,
    dls.trade_date,
    dls.stock_code,
    dls.stock_name,
    dls.sector_id,
    s.sector_name,

    -- 价格相关
    dls.open_price,
    dls.close_price,
    dls.high_price,
    dls.low_price,
    dls.pre_close,
    dls.change_pct AS change_pct,

    -- 开盘涨幅（计算字段）
    CASE
        WHEN dls.pre_close > 0
        THEN ROUND(((dls.open_price - dls.pre_close) / dls.pre_close * 100)::NUMERIC, 2)
        ELSE 0
    END AS open_change_pct,

    -- 涨跌停信息
    dls.limit_type,
    dls.is_one_word,
    dls.is_broken,
    dls.is_resealed,
    dls.broken_count,
    dls.consecutive_limit_days,

    -- 几天几板（描述）
    CASE
        WHEN dls.consecutive_limit_days = 1 THEN '首板'
        WHEN dls.consecutive_limit_days = 2 THEN '2板'
        WHEN dls.consecutive_limit_days = 3 THEN '3板'
        WHEN dls.consecutive_limit_days = 4 THEN '4板'
        WHEN dls.consecutive_limit_days = 5 THEN '5板'
        WHEN dls.consecutive_limit_days >= 6 THEN dls.consecutive_limit_days || '板'
        ELSE '-'
    END AS board_description,

    -- 涨停原因和行业
    dls.limit_reason,
    dls.industry,

    -- 成交数据
    dls.volume,
    dls.turnover,
    dls.turnover_rate,
    dls.seal_amount,
    dls.first_limit_time,

    -- 竞价数据
    dls.yesterday_auction_unmatched,
    dls.today_auction_unmatched,

    -- 概念题材
    dls.concept_tags,

    dls.created_at
FROM daily_limit_stats dls
LEFT JOIN sectors s ON dls.sector_id = s.id
ORDER BY dls.trade_date DESC, dls.consecutive_limit_days DESC, dls.first_limit_time ASC;

-- 完成
SELECT '✅ 个股详情展示功能字段扩展完成！' AS message,
       '新增字段: sector_id, limit_reason, industry, auction_unmatched, concept_tags' AS new_fields;
