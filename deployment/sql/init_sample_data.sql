-- ============================================
-- Funcat 示例数据初始化
-- 用于演示涨跌停数据看板功能
-- ============================================

-- ============================================
-- 1. 插入板块数据
-- ============================================

INSERT INTO sectors (sector_code, sector_name, sector_type, stock_count, description, sort_order) VALUES
-- 行业板块
('BK001', '半导体', 'industry', 45, '集成电路、芯片制造', 1),
('BK002', '新能源汽车', 'industry', 38, '电动汽车、充电桩', 2),
('BK003', '医药生物', 'industry', 52, '制药、生物科技', 3),
('BK004', '人工智能', 'concept', 67, 'AI芯片、算法', 4),
('BK005', '军工', 'industry', 34, '国防军工', 5),

-- 概念板块
('BK101', 'ChatGPT', 'concept', 28, '大语言模型相关', 10),
('BK102', '数字经济', 'concept', 55, '数字化转型', 11),
('BK103', '储能', 'concept', 31, '电池储能', 12),
('BK104', '工业母机', 'concept', 19, '数控机床', 13),
('BK105', '华为概念', 'concept', 42, '华为产业链', 14),

-- 地域板块
('BK201', '深圳本地', 'region', 89, '深圳地区股票', 20),
('BK202', '上海本地', 'region', 76, '上海地区股票', 21),
('BK203', '北京本地', 'region', 54, '北京地区股票', 22)
ON CONFLICT (sector_code) DO NOTHING;

-- ============================================
-- 2. 插入股票-板块映射数据
-- ============================================

INSERT INTO stock_sector_mapping (stock_code, stock_name, sector_id, weight) VALUES
-- 半导体板块
('000001.XSHE', '中芯国际', (SELECT id FROM sectors WHERE sector_code = 'BK001'), 1.5),
('000002.XSHE', '韦尔股份', (SELECT id FROM sectors WHERE sector_code = 'BK001'), 1.2),
('000003.XSHE', '北方华创', (SELECT id FROM sectors WHERE sector_code = 'BK001'), 1.3),

-- 新能源汽车
('600001.XSHG', '比亚迪', (SELECT id FROM sectors WHERE sector_code = 'BK002'), 2.0),
('600002.XSHG', '宁德时代', (SELECT id FROM sectors WHERE sector_code = 'BK002'), 1.8),
('600003.XSHG', '亿纬锂能', (SELECT id FROM sectors WHERE sector_code = 'BK002'), 1.1),

-- 医药生物
('600101.XSHG', '恒瑞医药', (SELECT id FROM sectors WHERE sector_code = 'BK003'), 1.5),
('600102.XSHG', '药明康德', (SELECT id FROM sectors WHERE sector_code = 'BK003'), 1.3),

-- AI概念
('300001.XSHE', '科大讯飞', (SELECT id FROM sectors WHERE sector_code = 'BK004'), 1.6),
('300002.XSHE', '寒武纪', (SELECT id FROM sectors WHERE sector_code = 'BK004'), 1.4),
('300003.XSHE', '海康威视', (SELECT id FROM sectors WHERE sector_code = 'BK004'), 1.2),

-- ChatGPT
('300001.XSHE', '科大讯飞', (SELECT id FROM sectors WHERE sector_code = 'BK101'), 1.8),
('300011.XSHE', '汉王科技', (SELECT id FROM sectors WHERE sector_code = 'BK101'), 1.3),

-- 军工
('600201.XSHG', '中航沈飞', (SELECT id FROM sectors WHERE sector_code = 'BK005'), 1.5),
('600202.XSHG', '航发动力', (SELECT id FROM sectors WHERE sector_code = 'BK005'), 1.4)
ON CONFLICT (stock_code, sector_id) DO NOTHING;

-- ============================================
-- 3. 插入今日涨跌停数据
-- ============================================

INSERT INTO daily_limit_stats (
    trade_date, stock_code, stock_name,
    open_price, close_price, high_price, low_price, pre_close,
    change_pct, limit_type, is_one_word, is_broken, is_resealed, broken_count,
    consecutive_limit_days, volume, turnover, turnover_rate, seal_amount, first_limit_time
) VALUES
-- 半导体板块涨停
(CURRENT_DATE, '000001.XSHE', '中芯国际', 45.50, 50.05, 50.05, 45.50, 45.50, 10.0, 'limit_up', true, false, false, 0, 3, 50000000, 2500000000, 5.2, 100000, '09:30:00'),
(CURRENT_DATE, '000002.XSHE', '韦尔股份', 128.00, 140.80, 140.80, 128.00, 128.00, 10.0, 'limit_up', false, true, true, 1, 2, 80000000, 11200000000, 8.5, 80000, '10:15:00'),
(CURRENT_DATE, '000003.XSHE', '北方华创', 285.00, 313.50, 313.50, 280.00, 285.00, 10.0, 'limit_up', false, false, false, 0, 1, 120000000, 37000000000, 12.3, 150000, '13:45:00'),

-- 新能源汽车涨停
(CURRENT_DATE, '600001.XSHG', '比亚迪', 255.00, 280.50, 280.50, 255.00, 255.00, 10.0, 'limit_up', false, true, false, 2, 0, 200000000, 55000000000, 15.6, 50000, '14:30:00'),
(CURRENT_DATE, '600002.XSHG', '宁德时代', 380.00, 418.00, 418.00, 380.00, 380.00, 10.0, 'limit_up', true, false, false, 0, 4, 180000000, 75000000000, 9.8, 200000, '09:25:00'),

-- AI概念涨停
(CURRENT_DATE, '300001.XSHE', '科大讯飞', 52.00, 57.20, 57.20, 52.00, 52.00, 10.0, 'limit_up', false, false, false, 0, 2, 95000000, 5400000000, 11.2, 120000, '11:20:00'),
(CURRENT_DATE, '300002.XSHE', '寒武纪', 168.00, 184.80, 184.80, 165.00, 168.00, 10.0, 'limit_up', false, true, true, 1, 1, 75000000, 13800000000, 18.5, 60000, '14:00:00'),

-- 军工涨停
(CURRENT_DATE, '600201.XSHG', '中航沈飞', 88.00, 96.80, 96.80, 88.00, 88.00, 10.0, 'limit_up', true, false, false, 0, 5, 60000000, 5800000000, 7.2, 180000, '09:31:00'),

-- 普通上涨
(CURRENT_DATE, '600101.XSHG', '恒瑞医药', 45.20, 48.50, 49.00, 45.00, 45.20, 7.3, 'none', false, false, false, 0, 0, 45000000, 2100000000, 6.5, 0, NULL),

-- 跌停
(CURRENT_DATE, '600301.XSHG', 'ST某股', 3.20, 2.88, 3.20, 2.88, 3.20, -10.0, 'limit_down', true, false, false, 0, 0, 25000000, 72000000, 8.9, 0, NULL)
ON CONFLICT (trade_date, stock_code) DO UPDATE SET
    close_price = EXCLUDED.close_price,
    change_pct = EXCLUDED.change_pct,
    limit_type = EXCLUDED.limit_type;

-- ============================================
-- 4. 插入连板记录
-- ============================================

INSERT INTO consecutive_limits (
    stock_code, stock_name, start_date, end_date, consecutive_days,
    status, total_gain_pct, avg_seal_ratio, main_sector, concept_tags
) VALUES
('600002.XSHG', '宁德时代', CURRENT_DATE - INTERVAL '3 days', NULL, 4, 'active', 46.41, 85.5, '新能源汽车', ARRAY['储能', '新能源']),
('600201.XSHG', '中航沈飞', CURRENT_DATE - INTERVAL '4 days', NULL, 5, 'active', 61.05, 92.3, '军工', ARRAY['军工', '航空']),
('000001.XSHE', '中芯国际', CURRENT_DATE - INTERVAL '2 days', NULL, 3, 'active', 33.10, 78.2, '半导体', ARRAY['芯片', '集成电路']),
('300001.XSHE', '科大讯飞', CURRENT_DATE - INTERVAL '1 day', NULL, 2, 'active', 21.00, 68.9, 'ChatGPT', ARRAY['AI', '语音识别']),
('000002.XSHE', '韦尔股份', CURRENT_DATE - INTERVAL '1 day', NULL, 2, 'active', 21.00, 65.4, '半导体', ARRAY['CMOS', '芯片设计']),
('300002.XSHE', '寒武纪', CURRENT_DATE, NULL, 1, 'active', 10.00, 55.2, 'AI芯片', ARRAY['AI', '芯片'])
ON CONFLICT DO NOTHING;

-- ============================================
-- 5. 插入板块每日统计
-- ============================================

INSERT INTO sector_daily_stats (
    trade_date, sector_id,
    limit_up_count, limit_down_count, one_word_count,
    broken_count, broken_resealed_count, broken_not_resealed_count,
    consecutive_2_count, consecutive_3_count, consecutive_4_count, consecutive_5_plus_count,
    total_stocks, up_count, down_count, avg_change_pct, total_turnover
) VALUES
-- 半导体
(CURRENT_DATE, (SELECT id FROM sectors WHERE sector_code = 'BK001'), 3, 0, 1, 1, 1, 0, 1, 1, 0, 0, 45, 38, 5, 6.8, 50700000000),

-- 新能源汽车
(CURRENT_DATE, (SELECT id FROM sectors WHERE sector_code = 'BK002'), 2, 0, 1, 1, 0, 1, 0, 0, 1, 0, 38, 32, 4, 7.2, 130000000000),

-- 医药生物
(CURRENT_DATE, (SELECT id FROM sectors WHERE sector_code = 'BK003'), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 52, 28, 18, 1.5, 8500000000),

-- AI概念
(CURRENT_DATE, (SELECT id FROM sectors WHERE sector_code = 'BK004'), 2, 0, 0, 1, 1, 0, 1, 0, 0, 0, 67, 52, 12, 5.3, 19200000000),

-- 军工
(CURRENT_DATE, (SELECT id FROM sectors WHERE sector_code = 'BK005'), 1, 0, 1, 0, 0, 0, 0, 0, 0, 1, 34, 25, 6, 4.2, 5800000000),

-- ChatGPT
(CURRENT_DATE, (SELECT id FROM sectors WHERE sector_code = 'BK101'), 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 28, 22, 4, 6.5, 5400000000),

-- 储能
(CURRENT_DATE, (SELECT id FROM sectors WHERE sector_code = 'BK103'), 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 31, 26, 3, 8.1, 75000000000)
ON CONFLICT (trade_date, sector_id) DO UPDATE SET
    limit_up_count = EXCLUDED.limit_up_count,
    total_turnover = EXCLUDED.total_turnover;

-- ============================================
-- 完成
-- ============================================
\echo '示例数据初始化完成!'
\echo '提示: 访问 http://localhost:8080 查看涨跌停数据看板'
