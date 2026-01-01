-- ============================================
-- 优化：增加跌停统计（一字跌停数 + 强度惩罚）
-- ============================================

-- 1. 添加一字跌停数字段到板块每日统计表
ALTER TABLE sector_daily_stats
ADD COLUMN IF NOT EXISTS one_word_limit_down_count INT DEFAULT 0;

COMMENT ON COLUMN sector_daily_stats.one_word_limit_down_count IS '一字跌停数量';

-- 2. 更新强度计算函数，增加跌停惩罚逻辑
CREATE OR REPLACE FUNCTION calculate_sector_strength(
    p_limit_up_count INT,
    p_one_word_count INT,
    p_consecutive_2_count INT,
    p_consecutive_3_count INT,
    p_consecutive_4_count INT,
    p_consecutive_5_plus_count INT,
    p_broken_not_resealed_count INT,
    p_total_turnover DECIMAL,
    p_avg_change_pct DECIMAL,
    p_limit_down_count INT DEFAULT 0,              -- 新增：跌停数
    p_one_word_limit_down_count INT DEFAULT 0      -- 新增：一字跌停数
) RETURNS DECIMAL AS $$
DECLARE
    strength DECIMAL := 0;
BEGIN
    -- ========== 正向加分 ==========

    -- 涨停家数得分（0-100分，基础分）
    strength := strength + (p_limit_up_count * 10);

    -- 一字板加成（0-80分）
    strength := strength + (p_one_word_count * 8);

    -- 连板梯队加成
    strength := strength + (p_consecutive_2_count * 3);      -- 2连板
    strength := strength + (p_consecutive_3_count * 8);      -- 3连板
    strength := strength + (p_consecutive_4_count * 15);     -- 4连板
    strength := strength + (p_consecutive_5_plus_count * 25); -- 5连板+

    -- 成交额加成（0-10分）
    IF p_total_turnover IS NOT NULL THEN
        strength := strength + LEAST(p_total_turnover / 1000000000 * 2, 10);
    END IF;

    -- 平均涨幅加成
    IF p_avg_change_pct IS NOT NULL THEN
        strength := strength + (p_avg_change_pct * 0.5);
    END IF;

    -- ========== 负向扣分 ==========

    -- 炸板未封惩罚（-5分/个）
    strength := strength - (p_broken_not_resealed_count * 5);

    -- 跌停惩罚（-8分/个）- 跌停说明板块分歧严重
    IF p_limit_down_count IS NOT NULL THEN
        strength := strength - (p_limit_down_count * 8);
    END IF;

    -- 一字跌停重罚（-15分/个）- 一字跌停说明板块恐慌性杀跌
    IF p_one_word_limit_down_count IS NOT NULL THEN
        strength := strength - (p_one_word_limit_down_count * 15);
    END IF;

    -- 确保不为负数
    RETURN GREATEST(strength, 0);
END;
$$ LANGUAGE plpgsql;

-- 3. 更新板块强度排行视图，增加跌停统计列
-- 注意：必须先删除旧视图，因为列的顺序改变了
DROP VIEW IF EXISTS v_sector_strength_ranking;

CREATE VIEW v_sector_strength_ranking AS
SELECT
    sds.trade_date,
    sds.sector_id,
    s.sector_code,
    sds.sector_name,
    s.sector_type,

    -- 涨停统计
    sds.limit_up_count,
    sds.one_word_count,
    sds.consecutive_2_count,
    sds.consecutive_3_count,
    sds.consecutive_4_count,
    sds.consecutive_5_plus_count,

    -- 跌停统计（新增）
    sds.limit_down_count,
    sds.one_word_limit_down_count,

    -- 炸板统计
    sds.broken_count,
    sds.broken_resealed_count,
    sds.broken_not_resealed_count,

    -- 其他统计
    sds.total_stocks,
    sds.avg_change_pct,
    sds.total_turnover,

    -- 计算板块强度分（含跌停惩罚）
    calculate_sector_strength(
        sds.limit_up_count,
        sds.one_word_count,
        sds.consecutive_2_count,
        sds.consecutive_3_count,
        sds.consecutive_4_count,
        sds.consecutive_5_plus_count,
        sds.broken_not_resealed_count,
        sds.total_turnover,
        sds.avg_change_pct,
        sds.limit_down_count,                    -- 新增参数
        sds.one_word_limit_down_count            -- 新增参数
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

    -- 强度等级（调整后）
    CASE
        WHEN calculate_sector_strength(
            sds.limit_up_count, sds.one_word_count,
            sds.consecutive_2_count, sds.consecutive_3_count,
            sds.consecutive_4_count, sds.consecutive_5_plus_count,
            sds.broken_not_resealed_count, sds.total_turnover, sds.avg_change_pct,
            sds.limit_down_count, sds.one_word_limit_down_count
        ) >= 150 THEN 'S'
        WHEN calculate_sector_strength(
            sds.limit_up_count, sds.one_word_count,
            sds.consecutive_2_count, sds.consecutive_3_count,
            sds.consecutive_4_count, sds.consecutive_5_plus_count,
            sds.broken_not_resealed_count, sds.total_turnover, sds.avg_change_pct,
            sds.limit_down_count, sds.one_word_limit_down_count
        ) >= 100 THEN 'A+'
        WHEN calculate_sector_strength(
            sds.limit_up_count, sds.one_word_count,
            sds.consecutive_2_count, sds.consecutive_3_count,
            sds.consecutive_4_count, sds.consecutive_5_plus_count,
            sds.broken_not_resealed_count, sds.total_turnover, sds.avg_change_pct,
            sds.limit_down_count, sds.one_word_limit_down_count
        ) >= 60 THEN 'A'
        WHEN calculate_sector_strength(
            sds.limit_up_count, sds.one_word_count,
            sds.consecutive_2_count, sds.consecutive_3_count,
            sds.consecutive_4_count, sds.consecutive_5_plus_count,
            sds.broken_not_resealed_count, sds.total_turnover, sds.avg_change_pct,
            sds.limit_down_count, sds.one_word_limit_down_count
        ) >= 30 THEN 'B'
        ELSE 'C'
    END AS strength_grade,

    sds.created_at
FROM sector_daily_stats sds
JOIN sectors s ON sds.sector_id = s.id
WHERE sds.limit_up_count > 0  -- 只显示有涨停的板块
ORDER BY strength_score DESC, sds.limit_up_count DESC;

-- 4. 创建索引优化跌停查询
CREATE INDEX IF NOT EXISTS idx_sector_limit_down
    ON sector_daily_stats(trade_date, limit_down_count DESC)
    WHERE limit_down_count > 0;

-- 完成
SELECT '✅ 跌停统计功能已添加！' AS message,
       '新增字段: one_word_limit_down_count' AS new_field,
       '强度计算已更新：跌停-8分，一字跌停-15分' AS penalty;
