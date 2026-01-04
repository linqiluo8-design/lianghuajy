#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
板块统计数据聚合器

功能：
1. 从 daily_limit_stats 表聚合个股数据
2. 生成板块级别的统计数据
3. 写入 sector_daily_stats 表
4. 可以作为独立脚本运行，也可以被其他服务调用
"""

import os
import sys
import logging
import psycopg2
from datetime import datetime
from typing import Optional

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)


class SectorAggregator:
    """板块数据聚合器"""

    def __init__(self):
        """初始化聚合器"""
        # 从环境变量读取数据库配置
        self.db_config = {
            'host': os.getenv('DB_HOST', 'localhost'),
            'port': int(os.getenv('DB_PORT', '5432')),
            'database': os.getenv('DB_NAME', 'funcat'),
            'user': os.getenv('DB_USER', 'funcat_user'),
            'password': os.getenv('DB_PASSWORD', 'funcat_password')
        }
        self.db_conn = None

    def connect(self) -> bool:
        """连接数据库"""
        try:
            self.db_conn = psycopg2.connect(**self.db_config)
            logger.info("✅ 数据库连接成功")
            return True
        except Exception as e:
            logger.error(f"❌ 数据库连接失败: {e}")
            return False

    def aggregate(self, trade_date: Optional[str] = None) -> int:
        """
        聚合指定日期的板块统计

        Args:
            trade_date: 交易日期（格式: YYYY-MM-DD），默认为今天

        Returns:
            int: 聚合的板块数量
        """
        if trade_date is None:
            trade_date = datetime.now().strftime('%Y-%m-%d')

        cursor = self.db_conn.cursor()

        try:
            # 1. 检查 daily_limit_stats 中是否有数据
            cursor.execute("""
                SELECT COUNT(*) FROM daily_limit_stats
                WHERE trade_date = %s
            """, (trade_date,))

            limit_stats_count = cursor.fetchone()[0]
            logger.info(f"📊 {trade_date} 涨跌停个股数据: {limit_stats_count} 条")

            if limit_stats_count == 0:
                logger.warning(f"⚠️  {trade_date} 没有涨跌停数据，跳过聚合")
                return 0

            # 2. 确保有默认板块
            self._ensure_default_sector()

            # 3. 删除今天的旧数据
            cursor.execute("""
                DELETE FROM sector_daily_stats
                WHERE trade_date = %s
            """, (trade_date,))
            deleted_count = cursor.rowcount
            if deleted_count > 0:
                logger.info(f"🗑️  删除旧数据: {deleted_count} 条")

            # 4. 聚合数据到默认板块"全市场"
            cursor.execute("""
                SELECT id FROM sectors WHERE sector_code = 'ALL_MARKET'
            """)
            default_sector_id = cursor.fetchone()[0]

            # 5. 聚合插入新数据
            cursor.execute("""
                INSERT INTO sector_daily_stats (
                    trade_date, sector_id, sector_name,
                    limit_up_count, limit_down_count,
                    one_word_count, one_word_limit_down_count,
                    broken_count, broken_resealed_count, broken_not_resealed_count,
                    consecutive_2_count, consecutive_3_count,
                    consecutive_4_count, consecutive_5_plus_count,
                    total_stocks, avg_change_pct, total_turnover,
                    created_at
                )
                SELECT
                    %s AS trade_date,
                    %s AS sector_id,
                    '全市场' AS sector_name,

                    -- 涨停家数
                    SUM(CASE WHEN limit_type = 'limit_up' THEN 1 ELSE 0 END) AS limit_up_count,

                    -- 跌停家数
                    SUM(CASE WHEN limit_type = 'limit_down' THEN 1 ELSE 0 END) AS limit_down_count,

                    -- 一字涨停
                    SUM(CASE WHEN limit_type = 'limit_up' AND is_one_word = TRUE THEN 1 ELSE 0 END) AS one_word_count,

                    -- 一字跌停
                    SUM(CASE WHEN limit_type = 'limit_down' AND is_one_word = TRUE THEN 1 ELSE 0 END) AS one_word_limit_down_count,

                    -- 炸板总数
                    SUM(CASE WHEN is_broken = TRUE THEN 1 ELSE 0 END) AS broken_count,

                    -- 炸板回封
                    SUM(CASE WHEN is_broken = TRUE AND is_resealed = TRUE THEN 1 ELSE 0 END) AS broken_resealed_count,

                    -- 炸板未封
                    SUM(CASE WHEN is_broken = TRUE AND is_resealed = FALSE THEN 1 ELSE 0 END) AS broken_not_resealed_count,

                    -- 连板梯队
                    SUM(CASE WHEN consecutive_limit_days = 2 THEN 1 ELSE 0 END) AS consecutive_2_count,
                    SUM(CASE WHEN consecutive_limit_days = 3 THEN 1 ELSE 0 END) AS consecutive_3_count,
                    SUM(CASE WHEN consecutive_limit_days = 4 THEN 1 ELSE 0 END) AS consecutive_4_count,
                    SUM(CASE WHEN consecutive_limit_days >= 5 THEN 1 ELSE 0 END) AS consecutive_5_plus_count,

                    -- 统计
                    COUNT(*) AS total_stocks,
                    AVG(change_pct) AS avg_change_pct,
                    SUM(turnover) AS total_turnover,

                    NOW() AS created_at

                FROM daily_limit_stats
                WHERE trade_date = %s
            """, (trade_date, default_sector_id, trade_date))

            self.db_conn.commit()

            # 6. 查询聚合结果以便输出日志
            cursor.execute("""
                SELECT limit_up_count, limit_down_count, one_word_count, one_word_limit_down_count
                FROM sector_daily_stats
                WHERE trade_date = %s AND sector_id = %s
            """, (trade_date, default_sector_id))

            result = cursor.fetchone()
            if result:
                limit_up, limit_down, one_word, one_word_down = result
                logger.info(f"✅ 聚合完成！涨停={limit_up}, 跌停={limit_down}, "
                           f"一字涨停={one_word}, 一字跌停={one_word_down}")
            else:
                logger.info("✅ 聚合完成！")

            return 1

        except Exception as e:
            self.db_conn.rollback()
            logger.error(f"❌ 聚合失败: {e}")
            import traceback
            traceback.print_exc()
            return 0
        finally:
            cursor.close()

    def _ensure_default_sector(self):
        """确保默认板块存在"""
        cursor = self.db_conn.cursor()

        try:
            cursor.execute("""
                INSERT INTO sectors (sector_code, sector_name, sector_type, stock_count)
                VALUES ('ALL_MARKET', '全市场', 'market', 0)
                ON CONFLICT (sector_code) DO NOTHING
            """)
            self.db_conn.commit()
        except Exception as e:
            logger.error(f"❌ 创建默认板块失败: {e}")
            self.db_conn.rollback()
        finally:
            cursor.close()

    def close(self):
        """关闭数据库连接"""
        if self.db_conn:
            self.db_conn.close()
            logger.info("📴 数据库连接已关闭")


def main():
    """主函数"""
    import argparse

    parser = argparse.ArgumentParser(description='板块统计数据聚合')
    parser.add_argument(
        '--date',
        default=None,
        help='交易日期 (格式: YYYY-MM-DD)，默认为今天'
    )

    args = parser.parse_args()

    aggregator = SectorAggregator()

    if not aggregator.connect():
        sys.exit(1)

    try:
        count = aggregator.aggregate(args.date)
        if count > 0:
            logger.info("🎉 聚合成功！")
            sys.exit(0)
        else:
            logger.warning("⚠️  未聚合任何数据")
            sys.exit(1)
    except Exception as e:
        logger.error(f"❌ 聚合异常: {e}")
        sys.exit(1)
    finally:
        aggregator.close()


if __name__ == '__main__':
    main()
