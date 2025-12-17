-- ============================================
-- Funcat 初始化数据
-- ============================================

-- 设置客户端编码
SET client_encoding = 'UTF8';

-- ============================================
-- 1. 插入默认策略配置
-- ============================================

INSERT INTO strategy_configs (strategy_name, description, parameters, enabled) VALUES
('ma_cross', '均线金叉策略', '{"short_period": 5, "long_period": 20, "volume_factor": 1.5}'::jsonb, true),
('kdj_oversold', 'KDJ超卖策略', '{"k_period": 9, "d_period": 3, "j_period": 3, "oversold_threshold": 20}'::jsonb, true),
('macd_golden', 'MACD金叉策略', '{"short": 12, "long": 26, "signal": 9}'::jsonb, true),
('boll_breakthrough', '布林带突破策略', '{"period": 20, "std_multiplier": 2}'::jsonb, true),
('comprehensive', '综合多指标策略', '{"ma_period": 20, "rsi_period": 14, "volume_factor": 1.2}'::jsonb, true)
ON CONFLICT (strategy_name) DO NOTHING;

-- ============================================
-- 2. 插入默认用户 (仅开发环境)
-- ============================================

-- 默认密码: admin123 (请在生产环境中修改!)
INSERT INTO users (username, email, password_hash, is_admin, is_active, daily_quota) VALUES
('admin', 'admin@funcat.local', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', true, true, 10000),
('demo', 'demo@funcat.local', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', false, true, 100)
ON CONFLICT (username) DO NOTHING;

-- ============================================
-- 3. 插入示例选股结果 (用于演示)
-- ============================================

INSERT INTO select_results (strategy_name, stock_code, stock_name, select_date, open_price, close_price, high_price, low_price, volume, indicators) VALUES
('ma_cross', '000001.XSHE', '平安银行', '2024-01-02', 10.50, 10.80, 11.00, 10.40, 1500000, '{"ma5": 10.75, "ma20": 10.50, "volume_ma5": 1200000}'::jsonb),
('ma_cross', '600000.XSHG', '浦发银行', '2024-01-02', 8.50, 8.65, 8.70, 8.45, 2000000, '{"ma5": 8.60, "ma20": 8.40, "volume_ma5": 1800000}'::jsonb),
('kdj_oversold', '000002.XSHE', '万科A', '2024-01-03', 12.30, 12.50, 12.60, 12.20, 3000000, '{"k": 18.5, "d": 15.2, "j": 25.1}'::jsonb)
ON CONFLICT DO NOTHING;

-- ============================================
-- 4. 插入示例回测记录
-- ============================================

INSERT INTO backtest_records (
    strategy_name, start_date, end_date,
    total_stocks, total_trades, win_rate, avg_return, total_return,
    sharpe_ratio, max_drawdown, volatility,
    config, details
) VALUES (
    'ma_cross',
    '2023-01-01',
    '2023-12-31',
    5000,
    1200,
    55.50,
    0.0250,
    0.3500,
    1.25,
    -0.1200,
    0.1800,
    '{"short_period": 5, "long_period": 20}'::jsonb,
    '{"trades": [], "monthly_returns": []}'::jsonb
);

-- ============================================
-- 5. 更新策略统计信息
-- ============================================

UPDATE strategy_configs
SET total_runs = 1,
    last_run_at = CURRENT_TIMESTAMP
WHERE strategy_name = 'ma_cross';

-- ============================================
-- 完成
-- ============================================
\echo '初始化数据插入完成!'
