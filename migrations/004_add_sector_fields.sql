-- 添加板块相关字段到 daily_limit_stats 表
-- 用于支持实时动态板块分析

-- 检查并添加字段（如果不存在）
DO $$
BEGIN
    -- 涨停原因分类
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'daily_limit_stats' AND column_name = 'limit_reason'
    ) THEN
        ALTER TABLE daily_limit_stats ADD COLUMN limit_reason VARCHAR(200);
        RAISE NOTICE '✅ 添加字段: limit_reason';
    END IF;

    -- 所属行业
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'daily_limit_stats' AND column_name = 'industry'
    ) THEN
        ALTER TABLE daily_limit_stats ADD COLUMN industry VARCHAR(200);
        RAISE NOTICE '✅ 添加字段: industry';
    END IF;

    -- 所属概念（多个概念用分号分隔）
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'daily_limit_stats' AND column_name = 'concept_tags'
    ) THEN
        ALTER TABLE daily_limit_stats ADD COLUMN concept_tags TEXT;
        RAISE NOTICE '✅ 添加字段: concept_tags';
    END IF;

    -- 连板数（连续涨停天数）
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'daily_limit_stats' AND column_name = 'consecutive_limit_days'
    ) THEN
        ALTER TABLE daily_limit_stats ADD COLUMN consecutive_limit_days INTEGER DEFAULT 1;
        RAISE NOTICE '✅ 添加字段: consecutive_limit_days';
    END IF;

    -- 首次封板时间
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'daily_limit_stats' AND column_name = 'first_limit_time'
    ) THEN
        ALTER TABLE daily_limit_stats ADD COLUMN first_limit_time TIME;
        RAISE NOTICE '✅ 添加字段: first_limit_time';
    END IF;

    -- 竞价未匹配额标志
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'daily_limit_stats' AND column_name = 'today_auction_unmatched'
    ) THEN
        ALTER TABLE daily_limit_stats ADD COLUMN today_auction_unmatched BOOLEAN DEFAULT FALSE;
        RAISE NOTICE '✅ 添加字段: today_auction_unmatched';
    END IF;
END $$;

-- 创建索引以优化查询性能
CREATE INDEX IF NOT EXISTS idx_daily_limit_stats_concept_tags
ON daily_limit_stats USING gin (string_to_array(concept_tags, ';'));

CREATE INDEX IF NOT EXISTS idx_daily_limit_stats_limit_reason
ON daily_limit_stats(limit_reason)
WHERE limit_reason IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_daily_limit_stats_industry
ON daily_limit_stats(industry)
WHERE industry IS NOT NULL;

COMMENT ON COLUMN daily_limit_stats.limit_reason IS '涨停/跌停原因分类（用于辅助视图）';
COMMENT ON COLUMN daily_limit_stats.industry IS '所属行业';
COMMENT ON COLUMN daily_limit_stats.concept_tags IS '所属概念（多个概念用分号分隔，用于主视图板块分析）';
COMMENT ON COLUMN daily_limit_stats.consecutive_limit_days IS '连续涨停天数（连板数）';
COMMENT ON COLUMN daily_limit_stats.first_limit_time IS '首次封板时间';
COMMENT ON COLUMN daily_limit_stats.today_auction_unmatched IS '竞价是否有未匹配额';
