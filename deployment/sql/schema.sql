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
    strategy_name VARCHAR(100) NOT NULL COMMENT '策略名称',
    stock_code VARCHAR(20) NOT NULL COMMENT '股票代码',
    stock_name VARCHAR(50) COMMENT '股票名称',
    select_date DATE NOT NULL COMMENT '选股日期',

    -- 指标数据 (JSON格式)
    indicators JSONB COMMENT '技术指标数据',

    -- 行情数据
    open_price DECIMAL(10, 2) COMMENT '开盘价',
    close_price DECIMAL(10, 2) COMMENT '收盘价',
    high_price DECIMAL(10, 2) COMMENT '最高价',
    low_price DECIMAL(10, 2) COMMENT '最低价',
    volume BIGINT COMMENT '成交量',

    -- 元数据
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间'
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
    strategy_name VARCHAR(100) NOT NULL COMMENT '策略名称',
    start_date DATE NOT NULL COMMENT '回测开始日期',
    end_date DATE NOT NULL COMMENT '回测结束日期',

    -- 回测结果
    total_stocks INT COMMENT '总股票数',
    total_trades INT COMMENT '总交易次数',
    win_rate DECIMAL(5, 2) COMMENT '胜率(%)',
    avg_return DECIMAL(10, 4) COMMENT '平均收益率',
    total_return DECIMAL(10, 4) COMMENT '总收益率',

    -- 风险指标
    sharpe_ratio DECIMAL(10, 4) COMMENT '夏普比率',
    max_drawdown DECIMAL(10, 4) COMMENT '最大回撤',
    volatility DECIMAL(10, 4) COMMENT '波动率',

    -- 配置和详细数据
    config JSONB COMMENT '策略配置',
    details JSONB COMMENT '详细交易记录',

    -- 元数据
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间'
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
    strategy_name VARCHAR(100) UNIQUE NOT NULL COMMENT '策略名称',
    description TEXT COMMENT '策略描述',

    -- 策略参数
    parameters JSONB COMMENT '策略参数 (JSON)',

    -- 状态
    enabled BOOLEAN DEFAULT TRUE COMMENT '是否启用',
    version VARCHAR(20) DEFAULT '1.0.0' COMMENT '版本号',

    -- 统计信息
    total_runs INT DEFAULT 0 COMMENT '总运行次数',
    last_run_at TIMESTAMP COMMENT '最后运行时间',

    -- 元数据
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
    created_by VARCHAR(50) COMMENT '创建人'
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
    username VARCHAR(50) UNIQUE NOT NULL COMMENT '用户名',
    email VARCHAR(100) UNIQUE COMMENT '邮箱',
    password_hash VARCHAR(255) COMMENT '密码哈希',

    -- API密钥配置
    api_keys JSONB COMMENT 'API密钥配置 (JSON)',

    -- 用户状态
    is_active BOOLEAN DEFAULT TRUE COMMENT '是否激活',
    is_admin BOOLEAN DEFAULT FALSE COMMENT '是否管理员',

    -- 配额
    daily_quota INT DEFAULT 100 COMMENT '每日配额',
    used_quota INT DEFAULT 0 COMMENT '已使用配额',
    quota_reset_at TIMESTAMP COMMENT '配额重置时间',

    -- 元数据
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
    last_login_at TIMESTAMP COMMENT '最后登录时间'
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
    task_type VARCHAR(50) NOT NULL COMMENT '任务类型: select, backtest',
    task_name VARCHAR(100) COMMENT '任务名称',

    -- 任务参数
    parameters JSONB COMMENT '任务参数',

    -- 任务状态
    status VARCHAR(20) DEFAULT 'pending' COMMENT '状态: pending, running, completed, failed',
    progress INT DEFAULT 0 COMMENT '进度 (0-100)',

    -- 结果
    result JSONB COMMENT '任务结果',
    error_message TEXT COMMENT '错误信息',

    -- 时间信息
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    started_at TIMESTAMP COMMENT '开始时间',
    completed_at TIMESTAMP COMMENT '完成时间',

    -- 优先级
    priority INT DEFAULT 0 COMMENT '优先级 (数字越大优先级越高)',

    -- 关联用户
    user_id INT REFERENCES users(id) COMMENT '用户ID'
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
    log_level VARCHAR(20) NOT NULL COMMENT '日志级别: debug, info, warn, error',
    service_name VARCHAR(50) COMMENT '服务名称',
    message TEXT COMMENT '日志消息',

    -- 详细信息
    details JSONB COMMENT '详细信息 (JSON)',
    stack_trace TEXT COMMENT '堆栈跟踪',

    -- 上下文
    user_id INT COMMENT '用户ID',
    request_id VARCHAR(100) COMMENT '请求ID',

    -- 时间
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间'
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
