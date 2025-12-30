-- ============================================
-- 板块强度排行功能
-- ============================================

-- 1. 板块强度计算函数
CREATE OR REPLACE FUNCTION calculate_sector_strength(
    p_limit_up_count INT,
    p_one_word_count INT,
    p_consecutive_2_count INT,
    p_consecutive_3_count INT,
    p_consecutive_4_count INT,
    p_consecutive_5_plus_count INT,
    p_broken_not_resealed_count INT,
    p_total_turnover DECIMAL,
    p_avg_change_pct DECIMAL
) RETURNS DECIMAL AS $$
DECLARE
    strength DECIMAL := 0;
BEGIN
    -- 涨停家数得分（0-100分，基础分）
    strength := strength + (p_limit_up_count * 10);

    -- 一字板加成（0-80分）
    strength := strength + (p_one_word_count * 8);

    -- 连板梯队加成
    strength := strength + (p_consecutive_2_count * 3);      -- 2连板
    strength := strength + (p_consecutive_3_count * 8);      -- 3连板
    strength := strength + (p_consecutive_4_count * 15);     -- 4连板
    strength := strength + (p_consecutive_5_plus_count * 25); -- 5连板+

    -- 炸板未封惩罚
    strength := strength - (p_broken_not_resealed_count * 5);

    -- 成交额加成（0-10分）
    IF p_total_turnover IS NOT NULL THEN
        strength := strength + LEAST(p_total_turnover / 1000000000 * 2, 10);
    END IF;

    -- 平均涨幅加成
    IF p_avg_change_pct IS NOT NULL THEN
        strength := strength + (p_avg_change_pct * 0.5);
    END IF;

    -- 确保不为负数
    RETURN GREATEST(strength, 0);
END;
$$ LANGUAGE plpgsql;

-- 2. 板块强度排行视图
CREATE OR REPLACE VIEW v_sector_strength_ranking AS
SELECT
    sds.trade_date,
    sds.sector_id,
    s.sector_code,
    sds.sector_name,
    s.sector_type,
    sds.limit_up_count,
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
    -- 计算板块强度分
    calculate_sector_strength(
        sds.limit_up_count,
        sds.one_word_count,
        sds.consecutive_2_count,
        sds.consecutive_3_count,
        sds.consecutive_4_count,
        sds.consecutive_5_plus_count,
        sds.broken_not_resealed_count,
        sds.total_turnover,
        sds.avg_change_pct
    ) AS strength_score,
    -- 板块健康度（炸板回封率）
    CASE
        WHEN sds.broken_count > 0
        THEN ROUND(CAST(sds.broken_resealed_count AS DECIMAL) / sds.broken_count * 100, 2)
        ELSE 100.0
    END AS health_rate,
    -- 连板集中度（高连板占比）
    CASE
        WHEN sds.limit_up_count > 0
        THEN ROUND(CAST(sds.consecutive_3_count + sds.consecutive_4_count + sds.consecutive_5_plus_count AS DECIMAL)
                   / sds.limit_up_count * 100, 2)
        ELSE 0
    END AS high_consecutive_rate,
    -- 强度等级
    CASE
        WHEN calculate_sector_strength(
            sds.limit_up_count, sds.one_word_count,
            sds.consecutive_2_count, sds.consecutive_3_count,
            sds.consecutive_4_count, sds.consecutive_5_plus_count,
            sds.broken_not_resealed_count, sds.total_turnover, sds.avg_change_pct
        ) >= 150 THEN 'S'
        WHEN calculate_sector_strength(
            sds.limit_up_count, sds.one_word_count,
            sds.consecutive_2_count, sds.consecutive_3_count,
            sds.consecutive_4_count, sds.consecutive_5_plus_count,
            sds.broken_not_resealed_count, sds.total_turnover, sds.avg_change_pct
        ) >= 100 THEN 'A+'
        WHEN calculate_sector_strength(
            sds.limit_up_count, sds.one_word_count,
            sds.consecutive_2_count, sds.consecutive_3_count,
            sds.consecutive_4_count, sds.consecutive_5_plus_count,
            sds.broken_not_resealed_count, sds.total_turnover, sds.avg_change_pct
        ) >= 60 THEN 'A'
        WHEN calculate_sector_strength(
            sds.limit_up_count, sds.one_word_count,
            sds.consecutive_2_count, sds.consecutive_3_count,
            sds.consecutive_4_count, sds.consecutive_5_plus_count,
            sds.broken_not_resealed_count, sds.total_turnover, sds.avg_change_pct
        ) >= 30 THEN 'B'
        ELSE 'C'
    END AS strength_grade,
    sds.created_at
FROM sector_daily_stats sds
JOIN sectors s ON sds.sector_id = s.id
WHERE sds.limit_up_count > 0  -- 只显示有涨停的板块
ORDER BY strength_score DESC, sds.limit_up_count DESC;

-- 3. 创建索引优化查询性能
CREATE INDEX IF NOT EXISTS idx_sector_strength_date
    ON sector_daily_stats(trade_date, limit_up_count DESC);

-- 完成
SELECT '✅ 板块强度排行功能创建完成！' AS message;
