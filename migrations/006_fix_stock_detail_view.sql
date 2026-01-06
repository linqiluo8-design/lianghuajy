-- ============================================
-- 修复个股详情视图 - 支持基于 industry 字段查询
-- ============================================

-- 重新创建视图：个股详情（支持 industry 字段）
CREATE OR REPLACE VIEW v_stock_limit_detail AS
SELECT
    dls.id,
    dls.trade_date,
    dls.stock_code,
    dls.stock_name,
    dls.sector_id,

    -- sector_name 优先使用 industry，如果没有则从 sectors 表获取
    COALESCE(dls.industry, s.sector_name) AS sector_name,

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
SELECT '✅ 个股详情视图已修复！现在支持 industry 字段查询' AS message;
