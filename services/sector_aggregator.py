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
        # 自动连接数据库（如果未连接）
        if self.db_conn is None:
            logger.info("📡 自动连接数据库...")
            if not self.connect():
                logger.error("❌ 数据库连接失败，无法聚合")
                return 0

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

            # 4. 优先级1：检查实时数据是否包含概念板块信息
            cursor.execute("""
                SELECT COUNT(*) FROM daily_limit_stats
                WHERE trade_date = %s
                AND (concept_tags IS NOT NULL AND concept_tags != '' AND concept_tags != '-')
            """, (trade_date,))

            realtime_sector_count = cursor.fetchone()[0]

            if realtime_sector_count > 0:
                # 实时数据包含概念板块，使用动态聚合
                logger.info(f"🔥 检测到 {realtime_sector_count} 条概念板块数据，使用概念板块聚合")
                sector_count = self._aggregate_by_realtime_sectors(trade_date)
                # 同时聚合涨停原因统计
                self.aggregate_limit_reasons(trade_date)
                return sector_count

            # 5. 优先级2：检查是否有行业数据
            cursor.execute("""
                SELECT COUNT(DISTINCT industry) FROM daily_limit_stats
                WHERE trade_date = %s
                AND (industry IS NOT NULL AND industry != '' AND industry != '-')
            """, (trade_date,))

            industry_count = cursor.fetchone()[0]

            if industry_count > 0:
                # 有行业数据，按行业聚合
                logger.info(f"📊 检测到 {industry_count} 个行业，使用行业聚合")
                sector_count = self._aggregate_by_industry(trade_date)
                # 同时聚合涨停原因统计
                self.aggregate_limit_reasons(trade_date)
                return sector_count

            # 6. 优先级3：检查是否有股票-板块映射数据
            cursor.execute("SELECT COUNT(*) FROM stock_sector_mapping")
            mapping_count = cursor.fetchone()[0]

            if mapping_count == 0:
                # 没有映射，只聚合到"全市场"
                logger.info("ℹ️  没有板块数据，聚合到'全市场'板块")
                sector_count = self._aggregate_to_all_market(trade_date)
                # 同时聚合涨停原因统计
                reason_count = self.aggregate_limit_reasons(trade_date)
                logger.info(f"📊 聚合完成：全市场板块 + {reason_count} 个涨停原因")
                return sector_count
            else:
                # 有映射，按板块聚合
                logger.info(f"📊 检测到 {mapping_count} 条板块映射，按细分板块聚合")
                sector_count = self._aggregate_by_sectors(trade_date)
                # 同时聚合涨停原因统计
                self.aggregate_limit_reasons(trade_date)
                return sector_count

        except Exception as e:
            self.db_conn.rollback()
            logger.error(f"❌ 聚合失败: {e}")
            import traceback
            traceback.print_exc()
            return 0
        finally:
            cursor.close()

    def _aggregate_to_all_market(self, trade_date: str) -> int:
        """聚合到全市场板块（当没有细分板块时）"""
        cursor = self.db_conn.cursor()

        try:
            cursor.execute("SELECT id FROM sectors WHERE sector_code = 'ALL_MARKET'")
            default_sector_id = cursor.fetchone()[0]

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
                    %s, %s, '全市场',
                    SUM(CASE WHEN limit_type = 'limit_up' THEN 1 ELSE 0 END),
                    SUM(CASE WHEN limit_type = 'limit_down' THEN 1 ELSE 0 END),
                    SUM(CASE WHEN limit_type = 'limit_up' AND is_one_word = TRUE THEN 1 ELSE 0 END),
                    SUM(CASE WHEN limit_type = 'limit_down' AND is_one_word = TRUE THEN 1 ELSE 0 END),
                    SUM(CASE WHEN is_broken = TRUE THEN 1 ELSE 0 END),
                    SUM(CASE WHEN is_broken = TRUE AND is_resealed = TRUE THEN 1 ELSE 0 END),
                    SUM(CASE WHEN is_broken = TRUE AND is_resealed = FALSE THEN 1 ELSE 0 END),
                    SUM(CASE WHEN consecutive_limit_days = 2 THEN 1 ELSE 0 END),
                    SUM(CASE WHEN consecutive_limit_days = 3 THEN 1 ELSE 0 END),
                    SUM(CASE WHEN consecutive_limit_days = 4 THEN 1 ELSE 0 END),
                    SUM(CASE WHEN consecutive_limit_days >= 5 THEN 1 ELSE 0 END),
                    COUNT(*), AVG(change_pct), SUM(turnover), NOW()
                FROM daily_limit_stats
                WHERE trade_date = %s
            """, (trade_date, default_sector_id, trade_date))

            self.db_conn.commit()
            logger.info("✅ 聚合到'全市场'完成")
            return 1

        finally:
            cursor.close()

    def _aggregate_by_realtime_sectors(self, trade_date: str) -> int:
        """从实时数据动态聚合板块（基于所属概念）"""
        cursor = self.db_conn.cursor()

        try:
            # 1. 获取所有概念板块（从 concept_tags 字段提取）
            cursor.execute("""
                SELECT DISTINCT
                    UNNEST(STRING_TO_ARRAY(concept_tags, ';')) AS sector_name
                FROM daily_limit_stats
                WHERE trade_date = %s
                AND concept_tags IS NOT NULL
                AND concept_tags != ''
                AND concept_tags != '-'
            """, (trade_date,))

            # 清理板块名称（去除空格、过滤无效值）
            sectors = []
            for row in cursor.fetchall():
                sector_name = row[0].strip()
                if sector_name and sector_name != '-':
                    sectors.append(sector_name)

            # 去重并排序
            sectors = sorted(set(sectors))
            logger.info(f"📊 发现 {len(sectors)} 个概念板块: {', '.join(sectors[:10])}...")

            # 2. 确保所有板块在 sectors 表中存在
            for sector_name in sectors:
                cursor.execute("""
                    INSERT INTO sectors (sector_code, sector_name, sector_type, stock_count)
                    VALUES (%s, %s, 'realtime', 0)
                    ON CONFLICT (sector_code) DO NOTHING
                """, (f"RT_{sector_name}", sector_name))

            self.db_conn.commit()

            # 3. 按概念板块聚合涨跌停数据（一只股票可属于多个概念）
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
                    s.id AS sector_id,
                    s.sector_name,
                    SUM(CASE WHEN dls.limit_type = 'limit_up' THEN 1 ELSE 0 END) AS limit_up_count,
                    SUM(CASE WHEN dls.limit_type = 'limit_down' THEN 1 ELSE 0 END) AS limit_down_count,
                    SUM(CASE WHEN dls.limit_type = 'limit_up' AND dls.is_one_word = TRUE THEN 1 ELSE 0 END) AS one_word_count,
                    SUM(CASE WHEN dls.limit_type = 'limit_down' AND dls.is_one_word = TRUE THEN 1 ELSE 0 END) AS one_word_limit_down_count,
                    SUM(CASE WHEN dls.is_broken = TRUE THEN 1 ELSE 0 END) AS broken_count,
                    SUM(CASE WHEN dls.is_broken = TRUE AND dls.is_resealed = TRUE THEN 1 ELSE 0 END) AS broken_resealed_count,
                    SUM(CASE WHEN dls.is_broken = TRUE AND dls.is_resealed = FALSE THEN 1 ELSE 0 END) AS broken_not_resealed_count,
                    SUM(CASE WHEN dls.consecutive_limit_days = 2 THEN 1 ELSE 0 END) AS consecutive_2_count,
                    SUM(CASE WHEN dls.consecutive_limit_days = 3 THEN 1 ELSE 0 END) AS consecutive_3_count,
                    SUM(CASE WHEN dls.consecutive_limit_days = 4 THEN 1 ELSE 0 END) AS consecutive_4_count,
                    SUM(CASE WHEN dls.consecutive_limit_days >= 5 THEN 1 ELSE 0 END) AS consecutive_5_plus_count,
                    COUNT(DISTINCT dls.stock_code) AS total_stocks,
                    AVG(dls.change_pct) AS avg_change_pct,
                    SUM(dls.turnover) AS total_turnover,
                    NOW() AS created_at
                FROM daily_limit_stats dls
                CROSS JOIN LATERAL UNNEST(STRING_TO_ARRAY(dls.concept_tags, ';')) AS concept(name)
                JOIN sectors s ON TRIM(concept.name) = s.sector_name AND s.sector_type = 'realtime'
                WHERE dls.trade_date = %s
                AND dls.concept_tags IS NOT NULL
                AND dls.concept_tags != ''
                AND dls.concept_tags != '-'
                GROUP BY s.id, s.sector_name
                HAVING COUNT(DISTINCT dls.stock_code) > 0
                ORDER BY limit_up_count DESC
            """, (trade_date, trade_date))

            rows_inserted = cursor.rowcount
            self.db_conn.commit()

            logger.info(f"✅ 实时板块聚合完成！插入 {rows_inserted} 个板块统计")

            # 显示前10个热门板块的统计
            cursor.execute("""
                SELECT sector_name, limit_up_count, limit_down_count, total_stocks
                FROM sector_daily_stats
                WHERE trade_date = %s
                ORDER BY limit_up_count DESC
                LIMIT 10
            """, (trade_date,))

            logger.info("🔥 热门涨停板块Top10:")
            for row in cursor.fetchall():
                logger.info(f"  {row[0]}: 涨停{row[1]}, 跌停{row[2]}, 总数{row[3]}")

            return rows_inserted

        finally:
            cursor.close()

    def _aggregate_by_industry(self, trade_date: str) -> int:
        """按行业聚合（当concept_tags为空时使用）"""
        cursor = self.db_conn.cursor()

        try:
            # 1. 获取所有行业
            cursor.execute("""
                SELECT DISTINCT TRIM(industry) AS industry_name
                FROM daily_limit_stats
                WHERE trade_date = %s
                AND industry IS NOT NULL
                AND industry != ''
                AND industry != '-'
            """, (trade_date,))

            industries = [row[0] for row in cursor.fetchall() if row[0] and row[0].strip()]
            industries = sorted(set(industries))
            logger.info(f"📊 发现 {len(industries)} 个行业: {', '.join(industries[:10])}...")

            # 2. 确保所有行业在 sectors 表中存在
            for industry_name in industries:
                cursor.execute("""
                    INSERT INTO sectors (sector_code, sector_name, sector_type, stock_count)
                    VALUES (%s, %s, 'industry', 0)
                    ON CONFLICT (sector_code) DO NOTHING
                """, (f"IND_{industry_name}", industry_name))

            self.db_conn.commit()

            # 3. 按行业聚合涨跌停数据
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
                    s.id AS sector_id,
                    s.sector_name,
                    SUM(CASE WHEN dls.limit_type = 'limit_up' THEN 1 ELSE 0 END) AS limit_up_count,
                    SUM(CASE WHEN dls.limit_type = 'limit_down' THEN 1 ELSE 0 END) AS limit_down_count,
                    SUM(CASE WHEN dls.limit_type = 'limit_up' AND dls.is_one_word = TRUE THEN 1 ELSE 0 END) AS one_word_count,
                    SUM(CASE WHEN dls.limit_type = 'limit_down' AND dls.is_one_word = TRUE THEN 1 ELSE 0 END) AS one_word_limit_down_count,
                    SUM(CASE WHEN dls.is_broken = TRUE THEN 1 ELSE 0 END) AS broken_count,
                    SUM(CASE WHEN dls.is_broken = TRUE AND dls.is_resealed = TRUE THEN 1 ELSE 0 END) AS broken_resealed_count,
                    SUM(CASE WHEN dls.is_broken = TRUE AND dls.is_resealed = FALSE THEN 1 ELSE 0 END) AS broken_not_resealed_count,
                    SUM(CASE WHEN dls.consecutive_limit_days = 2 THEN 1 ELSE 0 END) AS consecutive_2_count,
                    SUM(CASE WHEN dls.consecutive_limit_days = 3 THEN 1 ELSE 0 END) AS consecutive_3_count,
                    SUM(CASE WHEN dls.consecutive_limit_days = 4 THEN 1 ELSE 0 END) AS consecutive_4_count,
                    SUM(CASE WHEN dls.consecutive_limit_days >= 5 THEN 1 ELSE 0 END) AS consecutive_5_plus_count,
                    COUNT(DISTINCT dls.stock_code) AS total_stocks,
                    AVG(dls.change_pct) AS avg_change_pct,
                    SUM(dls.turnover) AS total_turnover,
                    NOW() AS created_at
                FROM daily_limit_stats dls
                JOIN sectors s ON TRIM(dls.industry) = s.sector_name AND s.sector_type = 'industry'
                WHERE dls.trade_date = %s
                AND dls.industry IS NOT NULL
                AND dls.industry != ''
                AND dls.industry != '-'
                GROUP BY s.id, s.sector_name
                HAVING COUNT(DISTINCT dls.stock_code) > 0
                ORDER BY limit_up_count DESC
            """, (trade_date, trade_date))

            rows_inserted = cursor.rowcount
            self.db_conn.commit()

            logger.info(f"✅ 行业聚合完成！插入 {rows_inserted} 个行业统计")

            # 显示前10个热门行业的统计
            cursor.execute("""
                SELECT sector_name, limit_up_count, limit_down_count, total_stocks
                FROM sector_daily_stats
                WHERE trade_date = %s
                ORDER BY limit_up_count DESC
                LIMIT 10
            """, (trade_date,))

            logger.info("🔥 热门涨停行业Top10:")
            for row in cursor.fetchall():
                logger.info(f"  {row[0]}: 涨停{row[1]}, 跌停{row[2]}, 总数{row[3]}")

            return rows_inserted

        finally:
            cursor.close()

    def aggregate_limit_reasons(self, trade_date: Optional[str] = None) -> int:
        """
        聚合涨停原因分析（辅助视图）

        用途：分析涨停原因分类（板块轮动、政策利好等）
        注意：这是辅助分析，不是主板块分类
        """
        # 自动连接数据库
        if self.db_conn is None:
            if not self.connect():
                return 0

        if trade_date is None:
            trade_date = datetime.now().strftime('%Y-%m-%d')

        cursor = self.db_conn.cursor()

        try:
            # 清理旧的涨停原因统计
            cursor.execute("""
                DELETE FROM limit_reason_stats
                WHERE trade_date = %s
            """, (trade_date,))

            # 按涨停原因聚合
            cursor.execute("""
                INSERT INTO limit_reason_stats (
                    trade_date, reason_name,
                    limit_up_count, limit_down_count,
                    one_word_count, broken_count,
                    total_stocks, avg_change_pct,
                    created_at
                )
                SELECT
                    %s AS trade_date,
                    TRIM(limit_reason) AS reason_name,
                    SUM(CASE WHEN limit_type = 'limit_up' THEN 1 ELSE 0 END) AS limit_up_count,
                    SUM(CASE WHEN limit_type = 'limit_down' THEN 1 ELSE 0 END) AS limit_down_count,
                    SUM(CASE WHEN is_one_word = TRUE THEN 1 ELSE 0 END) AS one_word_count,
                    SUM(CASE WHEN is_broken = TRUE THEN 1 ELSE 0 END) AS broken_count,
                    COUNT(DISTINCT stock_code) AS total_stocks,
                    AVG(change_pct) AS avg_change_pct,
                    NOW() AS created_at
                FROM daily_limit_stats
                WHERE trade_date = %s
                AND limit_reason IS NOT NULL
                AND limit_reason != ''
                AND limit_reason != '-'
                GROUP BY reason_name
                HAVING COUNT(*) > 0
                ORDER BY limit_up_count DESC
            """, (trade_date, trade_date))

            rows_inserted = cursor.rowcount
            self.db_conn.commit()

            logger.info(f"📊 涨停原因聚合完成！插入 {rows_inserted} 条原因统计")

            return rows_inserted

        except Exception as e:
            self.db_conn.rollback()
            logger.error(f"❌ 涨停原因聚合失败: {e}")
            return 0
        finally:
            cursor.close()

    def _aggregate_by_sectors(self, trade_date: str) -> int:
        """按细分板块聚合"""
        cursor = self.db_conn.cursor()

        try:
            # 按板块聚合涨跌停数据
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
                    ssm.sector_id,
                    s.sector_name,
                    SUM(CASE WHEN dls.limit_type = 'limit_up' THEN 1 ELSE 0 END) AS limit_up_count,
                    SUM(CASE WHEN dls.limit_type = 'limit_down' THEN 1 ELSE 0 END) AS limit_down_count,
                    SUM(CASE WHEN dls.limit_type = 'limit_up' AND dls.is_one_word = TRUE THEN 1 ELSE 0 END) AS one_word_count,
                    SUM(CASE WHEN dls.limit_type = 'limit_down' AND dls.is_one_word = TRUE THEN 1 ELSE 0 END) AS one_word_limit_down_count,
                    SUM(CASE WHEN dls.is_broken = TRUE THEN 1 ELSE 0 END) AS broken_count,
                    SUM(CASE WHEN dls.is_broken = TRUE AND dls.is_resealed = TRUE THEN 1 ELSE 0 END) AS broken_resealed_count,
                    SUM(CASE WHEN dls.is_broken = TRUE AND dls.is_resealed = FALSE THEN 1 ELSE 0 END) AS broken_not_resealed_count,
                    SUM(CASE WHEN dls.consecutive_limit_days = 2 THEN 1 ELSE 0 END) AS consecutive_2_count,
                    SUM(CASE WHEN dls.consecutive_limit_days = 3 THEN 1 ELSE 0 END) AS consecutive_3_count,
                    SUM(CASE WHEN dls.consecutive_limit_days = 4 THEN 1 ELSE 0 END) AS consecutive_4_count,
                    SUM(CASE WHEN dls.consecutive_limit_days >= 5 THEN 1 ELSE 0 END) AS consecutive_5_plus_count,
                    COUNT(*) AS total_stocks,
                    AVG(dls.change_pct) AS avg_change_pct,
                    SUM(dls.turnover) AS total_turnover,
                    NOW() AS created_at
                FROM daily_limit_stats dls
                JOIN stock_sector_mapping ssm ON dls.stock_code = ssm.stock_code
                JOIN sectors s ON ssm.sector_id = s.id
                WHERE dls.trade_date = %s
                GROUP BY ssm.sector_id, s.sector_name
                HAVING COUNT(*) > 0
            """, (trade_date, trade_date))

            rows_inserted = cursor.rowcount
            self.db_conn.commit()

            logger.info(f"✅ 聚合完成！插入 {rows_inserted} 个板块统计")

            # 显示前5个板块的统计
            cursor.execute("""
                SELECT sector_name, limit_up_count, limit_down_count
                FROM sector_daily_stats
                WHERE trade_date = %s
                ORDER BY limit_up_count DESC
                LIMIT 5
            """, (trade_date,))

            logger.info("📊 涨停板块Top5:")
            for row in cursor.fetchall():
                logger.info(f"  {row[0]}: 涨停{row[1]}, 跌停{row[2]}")

            return rows_inserted

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
