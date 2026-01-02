-- ============================================
-- 30天测试数据生成脚本（用于测试最高连板数趋势图）
-- ============================================

\echo '🚀 开始生成近30天测试数据...'

-- 插入近30天的涨停数据（模拟真实市场走势）
DO $$
DECLARE
    base_date DATE := '2025-12-01';
    current_date DATE;
    day_offset INT;
    max_board INT;
    limit_up_total INT;
BEGIN
    FOR day_offset IN 0..29 LOOP
        current_date := base_date + day_offset;

        -- 模拟不同的市场状态
        IF day_offset <= 5 THEN
            -- 前5天：市场较弱，最高2-3板
            max_board := 2 + (day_offset % 2);
            limit_up_total := 15 + (day_offset * 2);
        ELSIF day_offset <= 15 THEN
            -- 中间10天：市场升温，最高4-6板
            max_board := 4 + (day_offset % 3);
            limit_up_total := 25 + (day_offset * 3);
        ELSIF day_offset <= 23 THEN
            -- 接下来8天：市场火爆，最高7-9板
            max_board := 7 + (day_offset % 3);
            limit_up_total := 45 + (day_offset * 2);
        ELSE
            -- 最后几天：市场降温，最高3-5板
            max_board := 3 + (day_offset % 3);
            limit_up_total := 30 + (day_offset);
        END IF;

        -- 插入最高连板的股票（龙头）
        INSERT INTO daily_limit_stats (
            trade_date, stock_code, stock_name,
            sector_id, limit_reason, industry,
            open_price, close_price, high_price, low_price, pre_close,
            change_pct, limit_type, is_one_word, is_broken, is_resealed,
            broken_count, consecutive_limit_days,
            volume, turnover, turnover_rate, seal_amount, first_limit_time,
            yesterday_auction_unmatched, today_auction_unmatched, concept_tags
        ) VALUES (
            current_date,
            '300' || LPAD(day_offset::TEXT, 3, '0') || '.SZ',
            '龙头股' || day_offset,
            7, 'AI概念持续发酵', '软件开发',
            50.00, 55.00, 55.00, 49.50, 50.00,
            10.00, 'limit_up', FALSE, FALSE, FALSE, 0, max_board,
            5000000, 2750000000, 6.5, 800000, '09:30:00',
            7000000, 8000000, '人工智能,大数据,云计算'
        ) ON CONFLICT (trade_date, stock_code) DO NOTHING;

        -- 插入其他不同连板数的股票
        FOR i IN 1..LEAST(limit_up_total, 50) LOOP
            DECLARE
                time_minutes INT := 30 + (i % 30);  -- 限制在30-59分钟范围内
                time_str TEXT := '09:' || LPAD(time_minutes::TEXT, 2, '0') || ':00';
            BEGIN
                INSERT INTO daily_limit_stats (
                    trade_date, stock_code, stock_name,
                    sector_id, limit_reason, industry,
                    open_price, close_price, high_price, low_price, pre_close,
                    change_pct, limit_type, is_one_word, is_broken, is_resealed,
                    broken_count, consecutive_limit_days,
                    volume, turnover, turnover_rate, seal_amount, first_limit_time,
                    yesterday_auction_unmatched, today_auction_unmatched, concept_tags
                ) VALUES (
                    current_date,
                    '6' || LPAD((day_offset * 100 + i)::TEXT, 5, '0') || '.SH',
                    '测试股' || i,
                    (i % 8) + 1,
                    '板块轮动',
                    '电子信息',
                    30.00, 33.00, 33.00, 29.50, 30.00,
                    10.00, 'limit_up', (i % 10 = 0), (i % 5 = 0), (i % 5 = 0),
                    0, 1 + (i % GREATEST(max_board - 1, 1)),
                    3000000 + (i * 10000), 990000000 + (i * 1000000), 8.5,
                    200000 + (i * 1000), time_str::TIME,
                    1500000 + (i * 10000), 2000000 + (i * 10000), '热门题材'
                ) ON CONFLICT (trade_date, stock_code) DO NOTHING;
            END;
        END LOOP;

    END LOOP;

    RAISE NOTICE '✅ 已生成30天测试数据';
END $$;

\echo ''
\echo '✅ 30天测试数据生成完成！'
\echo ''
\echo '📊 数据统计：'

SELECT
    COUNT(DISTINCT trade_date) AS 天数,
    MIN(trade_date) AS 开始日期,
    MAX(trade_date) AS 结束日期,
    COUNT(*) AS 总记录数
FROM daily_limit_stats
WHERE trade_date >= '2025-12-01';

\echo ''
\echo '📈 每日最高连板数预览（前10天）：'

SELECT
    trade_date AS 日期,
    highest_board AS 最高连板,
    total_limit_up_count AS 涨停总数
FROM v_daily_highest_board
WHERE trade_date >= '2025-12-01'
ORDER BY trade_date
LIMIT 10;

\echo ''
\echo '💡 提示：'
\echo '   访问 Web UI 查看"最高连板数趋势（近30天）"折线图'
\echo ''
