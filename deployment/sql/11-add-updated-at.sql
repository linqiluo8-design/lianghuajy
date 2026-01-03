-- ============================================
-- 添加 updated_at 字段到 daily_limit_stats 表
-- ============================================

-- 添加 updated_at 列（如果不存在）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'daily_limit_stats'
        AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE daily_limit_stats
        ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

        -- 为已有数据设置 updated_at = created_at
        UPDATE daily_limit_stats
        SET updated_at = created_at
        WHERE updated_at IS NULL;

        RAISE NOTICE '✅ 已添加 updated_at 列';
    ELSE
        RAISE NOTICE '⚠️ updated_at 列已存在，跳过';
    END IF;
END
$$;

-- 创建触发器函数：自动更新 updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 创建触发器（如果不存在）
DROP TRIGGER IF EXISTS update_daily_limit_stats_updated_at ON daily_limit_stats;
CREATE TRIGGER update_daily_limit_stats_updated_at
    BEFORE UPDATE ON daily_limit_stats
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 完成
SELECT '✅ daily_limit_stats 表已更新，添加 updated_at 字段和自动更新触发器' AS message;
