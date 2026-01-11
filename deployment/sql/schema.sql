-- ============================================
-- Funcat 数据库表结构
-- PostgreSQL 13+
-- ============================================

-- 设置客户端编码
SET client_encoding = 'UTF8';

-- ============================================
-- 1. 选股结果表
-- ============================================
CREATE TABLE IF NOT EXISTS select_results (
    id SERIAL PRIMARY KEY,
    strategy_name VARCHAR(100) NOT NULL,
    stock_code VARCHAR(20) NOT NULL,
    stock_name VARCHAR(50),
    select_date DATE NOT NULL,

    -- 指标数据 (JSON格式)
    indicators JSONB,

    -- 行情数据
    open_price DECIMAL(10, 2),
    close_price DECIMAL(10, 2),
    high_price DECIMAL(10, 2),
    low_price DECIMAL(10, 2),
    volume BIGINT,

    -- 元数据
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 创建索引
CREATE INDEX idx_select_results_strategy_date ON select_results(strategy_name, select_date);
CREATE INDEX idx_select_results_stock_code ON select_results(stock_code);
CREATE INDEX idx_select_results_date ON select_results(select_date);

-- 添加注释
COMMENT ON TABLE select_results IS '选股结果表';

-- ============================================
-- 2. 回测记录表
-- ============================================
CREATE TABLE IF NOT EXISTS backtest_records (
    id SERIAL PRIMARY KEY,
    strategy_name VARCHAR(100) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,

    -- 回测结果
    total_stocks INT,
    total_trades INT,
    win_rate DECIMAL(5, 2),
    avg_return DECIMAL(10, 4),
    total_return DECIMAL(10, 4),

    -- 风险指标
    sharpe_ratio DECIMAL(10, 4),
    max_drawdown DECIMAL(10, 4),
    volatility DECIMAL(10, 4),

    -- 配置和详细数据
    config JSONB,
    details JSONB,

    -- 元数据
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 创建索引
CREATE INDEX idx_backtest_records_strategy ON backtest_records(strategy_name);
CREATE INDEX idx_backtest_records_date_range ON backtest_records(start_date, end_date);

-- 添加注释
COMMENT ON TABLE backtest_records IS '回测记录表';

-- ============================================
-- 3. 策略配置表
-- ============================================
CREATE TABLE IF NOT EXISTS strategy_configs (
    id SERIAL PRIMARY KEY,
    strategy_name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,

    -- 策略参数
    parameters JSONB,

    -- 状态
    enabled BOOLEAN DEFAULT TRUE,
    version VARCHAR(20) DEFAULT '1.0.0',

    -- 统计信息
    total_runs INT DEFAULT 0,
    last_run_at TIMESTAMP,

    -- 元数据
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(50)
);

-- 创建索引
CREATE INDEX idx_strategy_configs_enabled ON strategy_configs(enabled);
CREATE INDEX idx_strategy_configs_name ON strategy_configs(strategy_name);

-- 添加注释
COMMENT ON TABLE strategy_configs IS '策略配置表';

-- ============================================
-- 4. 用户表
-- ============================================
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE,
    password_hash VARCHAR(255),

    -- API密钥配置
    api_keys JSONB,

    -- 用户状态
    is_active BOOLEAN DEFAULT TRUE,
    is_admin BOOLEAN DEFAULT FALSE,

    -- 配额
    daily_quota INT DEFAULT 100,
    used_quota INT DEFAULT 0,
    quota_reset_at TIMESTAMP,

    -- 元数据
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP
);

-- 创建索引
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_active ON users(is_active);

-- 添加注释
COMMENT ON TABLE users IS '用户表';

-- ============================================
-- 5. 任务队列表
-- ============================================
CREATE TABLE IF NOT EXISTS task_queue (
    id SERIAL PRIMARY KEY,
    task_type VARCHAR(50) NOT NULL,
    task_name VARCHAR(100),

    -- 任务参数
    parameters JSONB,

    -- 任务状态
    status VARCHAR(20) DEFAULT 'pending',
    progress INT DEFAULT 0,

    -- 结果
    result JSONB,
    error_message TEXT,

    -- 时间信息
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,

    -- 优先级
    priority INT DEFAULT 0,

    -- 关联用户
    user_id INT REFERENCES users(id)
);

-- 创建索引
CREATE INDEX idx_task_queue_status ON task_queue(status);
CREATE INDEX idx_task_queue_type ON task_queue(task_type);
CREATE INDEX idx_task_queue_user ON task_queue(user_id);
CREATE INDEX idx_task_queue_created ON task_queue(created_at);

-- 添加注释
COMMENT ON TABLE task_queue IS '任务队列表';

-- ============================================
-- 6. 系统日志表
-- ============================================
CREATE TABLE IF NOT EXISTS system_logs (
    id SERIAL PRIMARY KEY,
    log_level VARCHAR(20) NOT NULL,
    service_name VARCHAR(50),
    message TEXT,

    -- 详细信息
    details JSONB,
    stack_trace TEXT,

    -- 上下文
    user_id INT,
    request_id VARCHAR(100),

    -- 时间
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 创建索引
CREATE INDEX idx_system_logs_level ON system_logs(log_level);
CREATE INDEX idx_system_logs_service ON system_logs(service_name);
CREATE INDEX idx_system_logs_created ON system_logs(created_at);

-- 添加注释
COMMENT ON TABLE system_logs IS '系统日志表';

-- ============================================
-- 7. 创建更新时间触发器函数
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 为需要的表添加触发器
CREATE TRIGGER update_backtest_records_updated_at
    BEFORE UPDATE ON backtest_records
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_strategy_configs_updated_at
    BEFORE UPDATE ON strategy_configs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 8. 创建视图
-- ============================================

-- 选股统计视图
CREATE OR REPLACE VIEW v_select_statistics AS
SELECT
    strategy_name,
    select_date,
    COUNT(*) as stock_count,
    AVG(close_price) as avg_price,
    MAX(close_price) as max_price,
    MIN(close_price) as min_price,
    SUM(volume) as total_volume
FROM select_results
GROUP BY strategy_name, select_date
ORDER BY select_date DESC;

-- 策略性能视图
CREATE OR REPLACE VIEW v_strategy_performance AS
SELECT
    sc.strategy_name,
    sc.description,
    sc.enabled,
    sc.total_runs,
    sc.last_run_at,
    AVG(br.avg_return) as avg_return,
    AVG(br.sharpe_ratio) as avg_sharpe,
    AVG(br.max_drawdown) as avg_drawdown
FROM strategy_configs sc
LEFT JOIN backtest_records br ON sc.strategy_name = br.strategy_name
GROUP BY sc.id, sc.strategy_name, sc.description, sc.enabled, sc.total_runs, sc.last_run_at;

-- ============================================
-- 完成
-- ============================================
\echo '数据库表结构创建完成!'
