-- ============================================
-- Web UI 测试数据生成脚本
-- ============================================
-- 用途：快速生成一些示例数据用于测试 Web UI 页面
-- 使用方法：
--   docker compose exec postgres psql -U funcat_user -d funcat -f /docker-entrypoint-initdb.d/test_data.sql
-- ============================================

\echo '🚀 开始生成测试数据...'

-- 1. 清空现有测试数据（可选）
-- DELETE FROM sector_daily_stats;
-- DELETE FROM daily_limit_stats;

-- 2. 插入板块每日统计数据
\echo '📊 插入板块每日统计数据...'
INSERT INTO sector_daily_stats (
    trade_date, sector_id, sector_name,
    limit_up_count, limit_down_count, one_word_count,
    broken_count, broken_resealed_count, broken_not_resealed_count,
    consecutive_2_count, consecutive_3_count, consecutive_4_count, consecutive_5_plus_count,
    total_stocks, avg_change_pct, total_turnover
) VALUES
    -- 新能源板块（强势）
    ('2025-12-30', 1, '新能源', 8, 0, 2, 1, 1, 0, 3, 2, 1, 0, 150, 5.50, 5000000000),

    -- 半导体板块（中等）
    ('2025-12-30', 2, '半导体', 5, 1, 1, 2, 1, 1, 2, 1, 0, 0, 120, 3.20, 3500000000),

    -- 军工板块（一般）
    ('2025-12-30', 3, '军工', 3, 0, 0, 1, 0, 1, 2, 0, 0, 0, 80, 2.10, 1500000000),

    -- 医药板块（弱势）
    ('2025-12-30', 4, '医药', 2, 2, 0, 3, 1, 2, 1, 0, 0, 0, 100, -0.50, 2000000000),

    -- 白酒板块（跌停）
    ('2025-12-30', 5, '白酒', 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 60, -3.80, 1800000000),

    -- 消费电子（中等）
    ('2025-12-30', 6, '消费电子', 4, 0, 1, 1, 1, 0, 1, 1, 0, 0, 90, 4.20, 2800000000),

    -- 人工智能（强势）
    ('2025-12-30', 7, '人工智能', 7, 0, 3, 0, 0, 0, 2, 2, 1, 1, 110, 6.80, 4500000000),

    -- 数字经济（一般）
    ('2025-12-30', 8, '数字经济', 3, 1, 0, 2, 1, 1, 1, 1, 0, 0, 95, 2.50, 2200000000)

ON CONFLICT (trade_date, sector_id) DO UPDATE SET
    limit_up_count = EXCLUDED.limit_up_count,
    limit_down_count = EXCLUDED.limit_down_count,
    one_word_count = EXCLUDED.one_word_count,
    broken_count = EXCLUDED.broken_count,
    broken_resealed_count = EXCLUDED.broken_resealed_count,
    broken_not_resealed_count = EXCLUDED.broken_not_resealed_count,
    consecutive_2_count = EXCLUDED.consecutive_2_count,
    consecutive_3_count = EXCLUDED.consecutive_3_count,
    consecutive_4_count = EXCLUDED.consecutive_4_count,
    consecutive_5_plus_count = EXCLUDED.consecutive_5_plus_count,
    total_stocks = EXCLUDED.total_stocks,
    avg_change_pct = EXCLUDED.avg_change_pct,
    total_turnover = EXCLUDED.total_turnover;

-- 3. 插入涨停个股数据
\echo '📈 插入涨停个股数据...'
INSERT INTO daily_limit_stats (
    trade_date, stock_code, stock_name,
    open_price, close_price, high_price, low_price, pre_close,
    change_pct, limit_type, is_one_word, is_broken, is_resealed,
    broken_count, consecutive_limit_days,
    volume, turnover, turnover_rate, seal_amount, first_limit_time
) VALUES
    -- 新能源板块龙头（4连板）
    ('2025-12-30', '600001.SH', '宁德时代', 500.00, 550.00, 550.00, 495.00, 500.00,
     10.00, 'limit_up', TRUE, FALSE, FALSE, 0, 4,
     5000000, 2750000000, 5.2, 800000, '09:25:00'),

    -- 新能源2连板
    ('2025-12-30', '600002.SH', '比亚迪', 250.00, 275.00, 275.00, 248.00, 250.00,
     10.00, 'limit_up', FALSE, FALSE, FALSE, 0, 2,
     8000000, 2200000000, 8.5, 500000, '09:45:00'),

    -- 新能源首板
    ('2025-12-30', '600003.SH', '隆基绿能', 30.00, 33.00, 33.00, 29.50, 30.00,
     10.00, 'limit_up', FALSE, TRUE, TRUE, 1, 1,
     12000000, 390000000, 15.2, 200000, '13:25:00'),

    -- 人工智能板块龙头（5连板）
    ('2025-12-30', '300001.SZ', '科大讯飞', 60.00, 66.00, 66.00, 59.50, 60.00,
     10.00, 'limit_up', TRUE, FALSE, FALSE, 0, 5,
     6000000, 3960000000, 6.8, 1000000, '09:30:00'),

    -- 人工智能3连板
    ('2025-12-30', '300002.SZ', '中科曙光', 40.00, 44.00, 44.00, 39.80, 40.00,
     10.00, 'limit_up', FALSE, FALSE, FALSE, 0, 3,
     4500000, 1980000000, 9.2, 350000, '10:15:00'),

    -- 半导体板块
    ('2025-12-30', '688001.SH', '中芯国际', 50.00, 55.00, 55.00, 49.50, 50.00,
     10.00, 'limit_up', TRUE, FALSE, FALSE, 0, 2,
     7000000, 3850000000, 7.5, 600000, '09:35:00'),

    -- 半导体首板（炸板回封）
    ('2025-12-30', '688002.SH', '华虹半导体', 35.00, 38.50, 38.50, 34.20, 35.00,
     10.00, 'limit_up', FALSE, TRUE, TRUE, 2, 1,
     9000000, 3465000000, 12.5, 150000, '14:35:00'),

    -- 消费电子
    ('2025-12-30', '002001.SZ', '立讯精密', 28.00, 30.80, 30.80, 27.50, 28.00,
     10.00, 'limit_up', FALSE, FALSE, FALSE, 0, 2,
     5500000, 1694000000, 8.8, 400000, '10:45:00'),

    -- 军工板块
    ('2025-12-30', '002002.SZ', '中航光电', 45.00, 49.50, 49.50, 44.50, 45.00,
     10.00, 'limit_up', FALSE, FALSE, FALSE, 0, 1,
     3000000, 1485000000, 6.2, 250000, '13:45:00'),

    -- 医药板块（弱势，炸板未封）
    ('2025-12-30', '600004.SH', '恒瑞医药', 50.00, 48.50, 55.00, 48.00, 50.00,
     -3.00, 'limit_down', FALSE, TRUE, FALSE, 1, 0,
     8000000, 4000000000, 10.5, 0, NULL)

ON CONFLICT (trade_date, stock_code) DO UPDATE SET
    close_price = EXCLUDED.close_price,
    change_pct = EXCLUDED.change_pct,
    consecutive_limit_days = EXCLUDED.consecutive_limit_days,
    seal_amount = EXCLUDED.seal_amount;

-- 4. 验证数据
\echo ''
\echo '✅ 测试数据生成完成！'
\echo ''
\echo '📊 数据统计：'

SELECT
    '板块每日统计' AS 表名,
    COUNT(*) AS 记录数,
    MIN(trade_date) || ' ~ ' || MAX(trade_date) AS 日期范围
FROM sector_daily_stats
WHERE trade_date = '2025-12-30'

UNION ALL

SELECT
    '涨跌停个股' AS 表名,
    COUNT(*) AS 记录数,
    MIN(trade_date) || ' ~ ' || MAX(trade_date) AS 日期范围
FROM daily_limit_stats
WHERE trade_date = '2025-12-30';

\echo ''
\echo '🔍 板块强度排行（前5名）：'
SELECT
    sector_name AS 板块,
    limit_up_count AS 涨停数,
    strength_score AS 强度分,
    strength_grade AS 等级
FROM v_sector_strength_ranking
WHERE trade_date = '2025-12-30'
ORDER BY strength_score DESC
LIMIT 5;

\echo ''
\echo '🏆 连板天梯（前5名）：'
SELECT
    stock_name AS 股票,
    consecutive_days AS 连板天数,
    main_sector AS 板块
FROM v_consecutive_ladder
LIMIT 5;

\echo ''
\echo '💡 提示：'
\echo '   1. 访问 Web UI: http://localhost:8081'
\echo '   2. 选择日期: 2025-12-30'
\echo '   3. 刷新数据查看效果'
\echo ''
