-- ============================================
-- 数据库表字段注释
-- PostgreSQL 标准 COMMENT ON COLUMN 语法
-- ============================================

-- 设置客户端编码
SET client_encoding = 'UTF8';

-- ============================================
-- 1. select_results 表字段注释
-- ============================================
COMMENT ON COLUMN select_results.strategy_name IS '策略名称';
COMMENT ON COLUMN select_results.stock_code IS '股票代码';
COMMENT ON COLUMN select_results.stock_name IS '股票名称';
COMMENT ON COLUMN select_results.select_date IS '选股日期';
COMMENT ON COLUMN select_results.indicators IS '技术指标数据';
COMMENT ON COLUMN select_results.open_price IS '开盘价';
COMMENT ON COLUMN select_results.close_price IS '收盘价';
COMMENT ON COLUMN select_results.high_price IS '最高价';
COMMENT ON COLUMN select_results.low_price IS '最低价';
COMMENT ON COLUMN select_results.volume IS '成交量';
COMMENT ON COLUMN select_results.created_at IS '创建时间';

-- ============================================
-- 2. backtest_records 表字段注释
-- ============================================
COMMENT ON COLUMN backtest_records.strategy_name IS '策略名称';
COMMENT ON COLUMN backtest_records.start_date IS '回测开始日期';
COMMENT ON COLUMN backtest_records.end_date IS '回测结束日期';
COMMENT ON COLUMN backtest_records.total_stocks IS '总股票数';
COMMENT ON COLUMN backtest_records.total_trades IS '总交易次数';
COMMENT ON COLUMN backtest_records.win_rate IS '胜率(%)';
COMMENT ON COLUMN backtest_records.avg_return IS '平均收益率';
COMMENT ON COLUMN backtest_records.total_return IS '总收益率';
COMMENT ON COLUMN backtest_records.sharpe_ratio IS '夏普比率';
COMMENT ON COLUMN backtest_records.max_drawdown IS '最大回撤';
COMMENT ON COLUMN backtest_records.volatility IS '波动率';
COMMENT ON COLUMN backtest_records.config IS '策略配置';
COMMENT ON COLUMN backtest_records.details IS '详细交易记录';
COMMENT ON COLUMN backtest_records.created_at IS '创建时间';
COMMENT ON COLUMN backtest_records.updated_at IS '更新时间';

-- ============================================
-- 3. strategy_configs 表字段注释
-- ============================================
COMMENT ON COLUMN strategy_configs.strategy_name IS '策略名称';
COMMENT ON COLUMN strategy_configs.description IS '策略描述';
COMMENT ON COLUMN strategy_configs.parameters IS '策略参数 (JSON)';
COMMENT ON COLUMN strategy_configs.enabled IS '是否启用';
COMMENT ON COLUMN strategy_configs.version IS '版本号';
COMMENT ON COLUMN strategy_configs.total_runs IS '总运行次数';
COMMENT ON COLUMN strategy_configs.last_run_at IS '最后运行时间';
COMMENT ON COLUMN strategy_configs.created_at IS '创建时间';
COMMENT ON COLUMN strategy_configs.updated_at IS '更新时间';
COMMENT ON COLUMN strategy_configs.created_by IS '创建人';

-- ============================================
-- 4. users 表字段注释
-- ============================================
COMMENT ON COLUMN users.username IS '用户名';
COMMENT ON COLUMN users.email IS '邮箱';
COMMENT ON COLUMN users.password_hash IS '密码哈希';
COMMENT ON COLUMN users.api_keys IS 'API密钥配置 (JSON)';
COMMENT ON COLUMN users.is_active IS '是否激活';
COMMENT ON COLUMN users.is_admin IS '是否管理员';
COMMENT ON COLUMN users.daily_quota IS '每日配额';
COMMENT ON COLUMN users.used_quota IS '已使用配额';
COMMENT ON COLUMN users.quota_reset_at IS '配额重置时间';
COMMENT ON COLUMN users.created_at IS '创建时间';
COMMENT ON COLUMN users.updated_at IS '更新时间';
COMMENT ON COLUMN users.last_login_at IS '最后登录时间';

-- ============================================
-- 5. task_queue 表字段注释
-- ============================================
COMMENT ON COLUMN task_queue.task_type IS '任务类型: select, backtest';
COMMENT ON COLUMN task_queue.task_name IS '任务名称';
COMMENT ON COLUMN task_queue.parameters IS '任务参数';
COMMENT ON COLUMN task_queue.status IS '状态: pending, running, completed, failed';
COMMENT ON COLUMN task_queue.progress IS '进度 (0-100)';
COMMENT ON COLUMN task_queue.result IS '任务结果';
COMMENT ON COLUMN task_queue.error_message IS '错误信息';
COMMENT ON COLUMN task_queue.created_at IS '创建时间';
COMMENT ON COLUMN task_queue.started_at IS '开始时间';
COMMENT ON COLUMN task_queue.completed_at IS '完成时间';
COMMENT ON COLUMN task_queue.priority IS '优先级 (数字越大优先级越高)';
COMMENT ON COLUMN task_queue.user_id IS '用户ID';

-- ============================================
-- 6. system_logs 表字段注释
-- ============================================
COMMENT ON COLUMN system_logs.log_level IS '日志级别: debug, info, warn, error';
COMMENT ON COLUMN system_logs.service_name IS '服务名称';
COMMENT ON COLUMN system_logs.message IS '日志消息';
COMMENT ON COLUMN system_logs.details IS '详细信息 (JSON)';
COMMENT ON COLUMN system_logs.stack_trace IS '堆栈跟踪';
COMMENT ON COLUMN system_logs.user_id IS '用户ID';
COMMENT ON COLUMN system_logs.request_id IS '请求ID';
COMMENT ON COLUMN system_logs.created_at IS '创建时间';

-- ============================================
-- 完成
-- ============================================
\echo '数据库字段注释添加完成!'
