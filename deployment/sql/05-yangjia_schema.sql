-- ============================================
-- 炒股养家心法扩展表结构
-- ============================================

-- ============================================
-- 1. 扩展 daily_limit_stats 表，添加炒股养家分类
-- ============================================
ALTER TABLE daily_limit_stats ADD COLUMN IF NOT EXISTS stock_role VARCHAR(20) COMMENT '股票角色: leader(龙头), middle(中军), catchup(补涨), follower(跟风)';
ALTER TABLE daily_limit_stats ADD COLUMN IF NOT EXISTS role_score DECIMAL(10, 4) DEFAULT 0 COMMENT '角色评分(0-100)';
ALTER TABLE daily_limit_stats ADD COLUMN IF NOT EXISTS leader_strength DECIMAL(10, 4) DEFAULT 0 COMMENT '龙头强度(0-100)';
ALTER TABLE daily_limit_stats ADD COLUMN IF NOT EXISTS sector_position INT COMMENT '板块内排名';

CREATE INDEX IF NOT EXISTS idx_daily_limit_role ON daily_limit_stats(stock_role);
CREATE INDEX IF NOT EXISTS idx_daily_limit_role_score ON daily_limit_stats(role_score);

-- ============================================
-- 2. 创建炒股养家选股结果表
-- ============================================
CREATE TABLE IF NOT EXISTS yangj ia_select_results (
    id SERIAL PRIMARY KEY,
    trade_date DATE NOT NULL COMMENT '交易日期',
    stock_code VARCHAR(20) NOT NULL COMMENT '股票代码',
    stock_name VARCHAR(50) COMMENT '股票名称',

    -- 股票分类
    stock_role VARCHAR(20) NOT NULL COMMENT '股票角色: leader, middle, catchup, follower',
    role_score DECIMAL(10, 4) COMMENT '角色评分',

    -- 龙头指标
    is_sector_leader BOOLEAN DEFAULT FALSE COMMENT '是否板块龙头',
    is_first_limit BOOLEAN DEFAULT FALSE COMMENT '是否首板龙头',
    leader_strength DECIMAL(10, 4) COMMENT '龙头强度',

    -- 技术指标
    consecutive_days INT DEFAULT 0 COMMENT '连板天数',
    first_limit_time TIME COMMENT '首次涨停时间',
    seal_strength DECIMAL(10, 4) COMMENT '封板强度',
    turnover_rate DECIMAL(10, 4) COMMENT '换手率',

    -- 板块效应
    sector_name VARCHAR(100) COMMENT '所属板块',
    sector_limit_count INT COMMENT '板块涨停家数',
    sector_position INT COMMENT '板块内排名',

    -- 资金指标
    turnover DECIMAL(20, 2) COMMENT '成交额',
    seal_amount BIGINT COMMENT '封单量',

    -- 养家心法评分
    total_score DECIMAL(10, 4) COMMENT '总评分',
    recommend_level VARCHAR(20) COMMENT '推荐级别: A+, A, B+, B, C',

    -- 选股理由
    select_reason TEXT COMMENT '选股理由',
    risk_tips TEXT COMMENT '风险提示',

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(trade_date, stock_code)
);

CREATE INDEX idx_yangjia_date ON yangjia_select_results(trade_date);
CREATE INDEX idx_yangjia_role ON yangjia_select_results(stock_role);
CREATE INDEX idx_yangjia_score ON yangjia_select_results(total_score);
CREATE INDEX idx_yangjia_recommend ON yangjia_select_results(recommend_level);

COMMENT ON TABLE yangjia_select_results IS '炒股养家选股结果表';

-- ============================================
-- 3. 创建视图：龙头股票
-- ============================================
CREATE OR REPLACE VIEW v_yangjia_leaders AS
SELECT
    ysr.trade_date,
    ysr.stock_code,
    ysr.stock_name,
    ysr.consecutive_days,
    ysr.first_limit_time,
    ysr.sector_name,
    ysr.sector_limit_count,
    ysr.sector_position,
    ysr.leader_strength,
    ysr.seal_strength,
    ysr.turnover,
    ysr.total_score,
    ysr.recommend_level,
    ysr.select_reason,
    dls.change_pct,
    dls.is_one_word,
    dls.is_broken
FROM yangjia_select_results ysr
LEFT JOIN daily_limit_stats dls ON ysr.stock_code = dls.stock_code AND ysr.trade_date = dls.trade_date
WHERE ysr.stock_role = 'leader'
ORDER BY ysr.trade_date DESC, ysr.total_score DESC;

COMMENT ON VIEW v_yangjia_leaders IS '炒股养家龙头股视图';

-- ============================================
-- 4. 创建视图：中军股票
-- ============================================
CREATE OR REPLACE VIEW v_yangjia_middle AS
SELECT
    ysr.trade_date,
    ysr.stock_code,
    ysr.stock_name,
    ysr.sector_name,
    ysr.turnover,
    ysr.turnover_rate,
    ysr.seal_amount,
    ysr.total_score,
    ysr.recommend_level,
    dls.change_pct,
    dls.consecutive_limit_days
FROM yangjia_select_results ysr
LEFT JOIN daily_limit_stats dls ON ysr.stock_code = dls.stock_code AND ysr.trade_date = dls.trade_date
WHERE ysr.stock_role = 'middle'
ORDER BY ysr.trade_date DESC, ysr.turnover DESC;

COMMENT ON VIEW v_yangjia_middle IS '炒股养家中军股视图';

-- ============================================
-- 5. 创建视图：补涨股票
-- ============================================
CREATE OR REPLACE VIEW v_yangjia_catchup AS
SELECT
    ysr.trade_date,
    ysr.stock_code,
    ysr.stock_name,
    ysr.sector_name,
    ysr.sector_limit_count,
    ysr.total_score,
    ysr.recommend_level,
    ysr.select_reason,
    dls.change_pct,
    dls.consecutive_limit_days,
    dls.first_limit_time
FROM yangjia_select_results ysr
LEFT JOIN daily_limit_stats dls ON ysr.stock_code = dls.stock_code AND ysr.trade_date = dls.trade_date
WHERE ysr.stock_role = 'catchup'
ORDER BY ysr.trade_date DESC, ysr.total_score DESC;

COMMENT ON VIEW v_yangjia_catchup IS '炒股养家补涨股视图';

-- ============================================
-- 6. 创建函数：计算龙头强度
-- ============================================
CREATE OR REPLACE FUNCTION calculate_leader_strength(
    p_consecutive_days INT,
    p_first_limit_time TIME,
    p_seal_ratio DECIMAL,
    p_is_one_word BOOLEAN,
    p_sector_position INT
) RETURNS DECIMAL AS $$
DECLARE
    strength DECIMAL := 0;
BEGIN
    -- 连板天数得分 (0-40分)
    strength := strength + LEAST(p_consecutive_days * 8, 40);

    -- 封板时间得分 (0-30分)
    IF p_first_limit_time IS NOT NULL THEN
        IF p_first_limit_time < '09:35:00' THEN
            strength := strength + 30;  -- 开盘5分钟内封板
        ELSIF p_first_limit_time < '10:00:00' THEN
            strength := strength + 25;  -- 开盘半小时内封板
        ELSIF p_first_limit_time < '11:00:00' THEN
            strength := strength + 20;  -- 上午封板
        ELSIF p_first_limit_time < '14:00:00' THEN
            strength := strength + 15;  -- 下午早盘封板
        ELSE
            strength := strength + 10;  -- 尾盘封板
        END IF;
    END IF;

    -- 封单强度得分 (0-20分)
    IF p_seal_ratio IS NOT NULL THEN
        strength := strength + LEAST(p_seal_ratio / 5, 20);
    END IF;

    -- 一字板加分 (0-5分)
    IF p_is_one_word THEN
        strength := strength + 5;
    END IF;

    -- 板块排名得分 (0-5分)
    IF p_sector_position = 1 THEN
        strength := strength + 5;
    ELSIF p_sector_position = 2 THEN
        strength := strength + 3;
    ELSIF p_sector_position = 3 THEN
        strength := strength + 1;
    END IF;

    RETURN LEAST(strength, 100);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION calculate_leader_strength IS '计算龙头强度评分';

-- ============================================
-- 7. 创建函数：炒股养家选股
-- ============================================
CREATE OR REPLACE FUNCTION yangjia_stock_selector(p_trade_date DATE)
RETURNS TABLE(
    stock_code VARCHAR,
    stock_name VARCHAR,
    stock_role VARCHAR,
    total_score DECIMAL,
    recommend_level VARCHAR,
    select_reason TEXT
) AS $$
BEGIN
    -- 清空当日结果
    DELETE FROM yangjia_select_results WHERE trade_date = p_trade_date;

    -- 1. 识别龙头股
    INSERT INTO yangjia_select_results (
        trade_date, stock_code, stock_name, stock_role,
        is_sector_leader, leader_strength, consecutive_days,
        first_limit_time, sector_name, sector_limit_count,
        sector_position, turnover, seal_amount, seal_strength,
        turnover_rate, total_score, recommend_level, select_reason
    )
    SELECT
        dls.trade_date,
        dls.stock_code,
        dls.stock_name,
        'leader' as stock_role,
        TRUE as is_sector_leader,
        calculate_leader_strength(
            dls.consecutive_limit_days,
            dls.first_limit_time,
            dls.seal_ratio,
            dls.is_one_word,
            ROW_NUMBER() OVER (
                PARTITION BY ssm.sector_id
                ORDER BY dls.consecutive_limit_days DESC, dls.first_limit_time ASC
            )::INT
        ) as leader_strength,
        dls.consecutive_limit_days,
        dls.first_limit_time,
        s.sector_name,
        sds.limit_up_count as sector_limit_count,
        ROW_NUMBER() OVER (
            PARTITION BY ssm.sector_id
            ORDER BY dls.consecutive_limit_days DESC, dls.first_limit_time ASC
        )::INT as sector_position,
        dls.turnover,
        dls.seal_amount,
        dls.seal_ratio as seal_strength,
        dls.turnover_rate,
        -- 总评分 = 龙头强度 * 0.6 + 板块效应 * 0.3 + 成交额权重 * 0.1
        calculate_leader_strength(
            dls.consecutive_limit_days,
            dls.first_limit_time,
            dls.seal_ratio,
            dls.is_one_word,
            ROW_NUMBER() OVER (
                PARTITION BY ssm.sector_id
                ORDER BY dls.consecutive_limit_days DESC, dls.first_limit_time ASC
            )::INT
        ) * 0.6 +
        LEAST(sds.limit_up_count * 10, 30) +
        LEAST(dls.turnover / 1000000000 * 2, 10) as total_score,
        CASE
            WHEN calculate_leader_strength(
                dls.consecutive_limit_days,
                dls.first_limit_time,
                dls.seal_ratio,
                dls.is_one_word,
                ROW_NUMBER() OVER (
                    PARTITION BY ssm.sector_id
                    ORDER BY dls.consecutive_limit_days DESC, dls.first_limit_time ASC
                )::INT
            ) >= 80 THEN 'A+'
            WHEN calculate_leader_strength(
                dls.consecutive_limit_days,
                dls.first_limit_time,
                dls.seal_ratio,
                dls.is_one_word,
                ROW_NUMBER() OVER (
                    PARTITION BY ssm.sector_id
                    ORDER BY dls.consecutive_limit_days DESC, dls.first_limit_time ASC
                )::INT
            ) >= 60 THEN 'A'
            WHEN calculate_leader_strength(
                dls.consecutive_limit_days,
                dls.first_limit_time,
                dls.seal_ratio,
                dls.is_one_word,
                ROW_NUMBER() OVER (
                    PARTITION BY ssm.sector_id
                    ORDER BY dls.consecutive_limit_days DESC, dls.first_limit_time ASC
                )::INT
            ) >= 40 THEN 'B+'
            ELSE 'B'
        END as recommend_level,
        format('龙头股 | %s连板 | 封板时间%s | 板块%s家涨停',
            dls.consecutive_limit_days,
            dls.first_limit_time,
            sds.limit_up_count
        ) as select_reason
    FROM daily_limit_stats dls
    JOIN stock_sector_mapping ssm ON dls.stock_code = ssm.stock_code
    JOIN sectors s ON ssm.sector_id = s.id
    LEFT JOIN sector_daily_stats sds ON s.id = sds.sector_id AND dls.trade_date = sds.trade_date
    WHERE dls.trade_date = p_trade_date
        AND dls.limit_type = 'limit_up'
        AND sds.limit_up_count >= 3  -- 板块至少3家涨停
        AND ROW_NUMBER() OVER (
            PARTITION BY ssm.sector_id
            ORDER BY dls.consecutive_limit_days DESC, dls.first_limit_time ASC
        ) = 1;  -- 每个板块选最强龙头

    -- 2. 识别中军股 (成交额大，承接能力强)
    INSERT INTO yangjia_select_results (
        trade_date, stock_code, stock_name, stock_role,
        sector_name, turnover, seal_amount, turnover_rate,
        total_score, recommend_level, select_reason
    )
    SELECT
        dls.trade_date,
        dls.stock_code,
        dls.stock_name,
        'middle' as stock_role,
        s.sector_name,
        dls.turnover,
        dls.seal_amount,
        dls.turnover_rate,
        -- 中军评分 = 成交额权重 * 0.5 + 换手率 * 0.3 + 板块效应 * 0.2
        LEAST(dls.turnover / 1000000000 * 5, 50) +
        LEAST(dls.turnover_rate * 1.5, 30) +
        LEAST(sds.limit_up_count * 2, 20) as total_score,
        CASE
            WHEN dls.turnover >= 5000000000 THEN 'A'
            WHEN dls.turnover >= 2000000000 THEN 'B+'
            ELSE 'B'
        END as recommend_level,
        format('中军股 | 成交额%.2f亿 | 换手率%.2f%% | 承接力强',
            dls.turnover / 100000000,
            dls.turnover_rate
        ) as select_reason
    FROM daily_limit_stats dls
    JOIN stock_sector_mapping ssm ON dls.stock_code = ssm.stock_code
    JOIN sectors s ON ssm.sector_id = s.id
    LEFT JOIN sector_daily_stats sds ON s.id = sds.sector_id AND dls.trade_date = sds.trade_date
    WHERE dls.trade_date = p_trade_date
        AND dls.limit_type = 'limit_up'
        AND dls.turnover >= 1000000000  -- 成交额至少10亿
        AND dls.turnover_rate BETWEEN 5 AND 25  -- 换手率适中
        AND dls.stock_code NOT IN (
            SELECT stock_code FROM yangjia_select_results
            WHERE trade_date = p_trade_date AND stock_role = 'leader'
        );

    -- 3. 识别补涨股 (同板块滞涨，有补涨空间)
    INSERT INTO yangjia_select_results (
        trade_date, stock_code, stock_name, stock_role,
        sector_name, sector_limit_count, consecutive_days,
        first_limit_time, total_score, recommend_level, select_reason
    )
    SELECT
        dls.trade_date,
        dls.stock_code,
        dls.stock_name,
        'catchup' as stock_role,
        s.sector_name,
        sds.limit_up_count,
        dls.consecutive_limit_days,
        dls.first_limit_time,
        -- 补涨评分 = 板块效应 * 0.6 + 首板时机 * 0.4
        LEAST(sds.limit_up_count * 6, 60) +
        CASE
            WHEN dls.first_limit_time < '10:00:00' THEN 40
            WHEN dls.first_limit_time < '13:00:00' THEN 30
            ELSE 20
        END as total_score,
        CASE
            WHEN sds.limit_up_count >= 5 THEN 'A'
            WHEN sds.limit_up_count >= 3 THEN 'B+'
            ELSE 'B'
        END as recommend_level,
        format('补涨股 | 板块%s家涨停 | 首板 | 有补涨空间',
            sds.limit_up_count
        ) as select_reason
    FROM daily_limit_stats dls
    JOIN stock_sector_mapping ssm ON dls.stock_code = ssm.stock_code
    JOIN sectors s ON ssm.sector_id = s.id
    LEFT JOIN sector_daily_stats sds ON s.id = sds.sector_id AND dls.trade_date = sds.trade_date
    WHERE dls.trade_date = p_trade_date
        AND dls.limit_type = 'limit_up'
        AND dls.consecutive_limit_days = 0  -- 首板
        AND sds.limit_up_count >= 3  -- 板块效应好
        AND dls.stock_code NOT IN (
            SELECT stock_code FROM yangjia_select_results
            WHERE trade_date = p_trade_date AND stock_role IN ('leader', 'middle')
        );

    -- 4. 识别跟风股 (跟随龙头，力度较弱)
    INSERT INTO yangjia_select_results (
        trade_date, stock_code, stock_name, stock_role,
        sector_name, sector_limit_count, total_score,
        recommend_level, select_reason, risk_tips
    )
    SELECT
        dls.trade_date,
        dls.stock_code,
        dls.stock_name,
        'follower' as stock_role,
        s.sector_name,
        sds.limit_up_count,
        -- 跟风评分较低
        LEAST(sds.limit_up_count * 3, 30) +
        CASE WHEN dls.is_broken = FALSE THEN 20 ELSE 10 END as total_score,
        'C' as recommend_level,
        format('跟风股 | 板块%s家涨停 | 跟随龙头',
            sds.limit_up_count
        ) as select_reason,
        '跟风股风险较高，注意止损' as risk_tips
    FROM daily_limit_stats dls
    JOIN stock_sector_mapping ssm ON dls.stock_code = ssm.stock_code
    JOIN sectors s ON ssm.sector_id = s.id
    LEFT JOIN sector_daily_stats sds ON s.id = sds.sector_id AND dls.trade_date = sds.trade_date
    WHERE dls.trade_date = p_trade_date
        AND dls.limit_type = 'limit_up'
        AND dls.stock_code NOT IN (
            SELECT stock_code FROM yangjia_select_results
            WHERE trade_date = p_trade_date
        )
    LIMIT 20;  -- 限制跟风股数量

    -- 返回结果
    RETURN QUERY
    SELECT
        ysr.stock_code,
        ysr.stock_name,
        ysr.stock_role,
        ysr.total_score,
        ysr.recommend_level,
        ysr.select_reason
    FROM yangjia_select_results ysr
    WHERE ysr.trade_date = p_trade_date
    ORDER BY
        CASE ysr.stock_role
            WHEN 'leader' THEN 1
            WHEN 'middle' THEN 2
            WHEN 'catchup' THEN 3
            WHEN 'follower' THEN 4
        END,
        ysr.total_score DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION yangjia_stock_selector IS '炒股养家选股函数';

-- ============================================
-- 完成
-- ============================================
\echo '炒股养家心法扩展表结构创建完成!'
