# -*- coding: utf-8 -*-
"""
实时行情采集服务

功能：
1. 从配置的数据源（AkShare 或 pytdx）获取实时行情
2. 每2秒刷新一次数据
3. 将涨跌停数据写入 PostgreSQL 数据库
4. 支持动态切换数据源
"""

import os
import sys
import time
import logging
import psycopg2
from datetime import datetime
from typing import Optional
import yaml

# 添加项目根目录到路径
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.data_sources import AkShareSource, PytdxSource
from services.sector_aggregator import SectorAggregator

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)


class RealtimeFetcher:
    """实时行情采集器"""

    def __init__(self, config_path: str = 'config/realtime.yaml'):
        """
        初始化采集器

        Args:
            config_path: 配置文件路径
        """
        # 加载配置
        self.config = self._load_config(config_path)

        # 初始化数据源
        self.data_source = None
        self._init_data_source()

        # 数据库连接
        self.db_conn = None
        self._connect_database()

        # 统计信息
        self.fetch_count = 0
        self.error_count = 0

        # 板块聚合器（每次采集后聚合数据）
        self.aggregator = SectorAggregator()
        self.aggregator.db_conn = self.db_conn  # 复用数据库连接

    def _load_config(self, config_path: str) -> dict:
        """加载配置文件"""
        # 如果配置文件不存在，使用默认配置
        if not os.path.exists(config_path):
            logger.warning(f"配置文件不存在: {config_path}，使用默认配置")
            return self._default_config()

        try:
            with open(config_path, 'r', encoding='utf-8') as f:
                config = yaml.safe_load(f)
                logger.info(f"✅ 加载配置文件: {config_path}")

                # 环境变量优先：用环境变量覆盖数据库配置
                if 'database' in config:
                    config['database']['host'] = os.getenv('DB_HOST', config['database'].get('host', 'localhost'))
                    config['database']['port'] = int(os.getenv('DB_PORT', config['database'].get('port', 5432)))
                    config['database']['database'] = os.getenv('DB_NAME', config['database'].get('database', 'funcat'))
                    config['database']['user'] = os.getenv('DB_USER', config['database'].get('user', 'funcat_user'))
                    config['database']['password'] = os.getenv('DB_PASSWORD', config['database'].get('password', 'funcat_password'))

                # 环境变量优先：用环境变量覆盖数据源配置
                if 'data_source' in config:
                    config['data_source']['type'] = os.getenv('REALTIME_DATA_SOURCE', config['data_source'].get('type', 'akshare'))
                    config['data_source']['refresh_interval'] = int(os.getenv('REALTIME_REFRESH_INTERVAL', config['data_source'].get('refresh_interval', 2)))

                return config
        except Exception as e:
            logger.error(f"❌ 加载配置失败: {e}，使用默认配置")
            return self._default_config()

    def _default_config(self) -> dict:
        """默认配置"""
        return {
            'data_source': {
                'type': os.getenv('REALTIME_DATA_SOURCE', 'akshare'),  # akshare 或 pytdx
                'refresh_interval': int(os.getenv('REALTIME_REFRESH_INTERVAL', 2)),  # 刷新间隔（秒）
            },
            'database': {
                'host': os.getenv('DB_HOST', 'localhost'),
                'port': int(os.getenv('DB_PORT', 5432)),
                'database': os.getenv('DB_NAME', 'funcat'),
                'user': os.getenv('DB_USER', 'funcat_user'),
                'password': os.getenv('DB_PASSWORD', 'funcat_password'),
            },
            'filter': {
                'only_limit': True,  # 只保存涨跌停股票
                'min_price': 1.0,    # 最低价格过滤（过滤仙股）
            }
        }

    def _init_data_source(self):
        """初始化数据源"""
        source_type = self.config['data_source']['type'].lower()

        logger.info(f"初始化数据源: {source_type}")

        if source_type == 'akshare':
            self.data_source = AkShareSource(self.config.get('akshare', {}))
        elif source_type == 'pytdx':
            self.data_source = PytdxSource(self.config.get('pytdx', {}))
        else:
            raise ValueError(f"不支持的数据源类型: {source_type}")

        # 连接数据源
        if not self.data_source.connect():
            raise ConnectionError(f"数据源 {source_type} 连接失败")

        logger.info(f"✅ 数据源 {source_type} 初始化成功")

    def _connect_database(self):
        """连接数据库"""
        db_config = self.config['database']

        try:
            self.db_conn = psycopg2.connect(
                host=db_config['host'],
                port=db_config['port'],
                database=db_config['database'],
                user=db_config['user'],
                password=db_config['password']
            )
            logger.info("✅ 数据库连接成功")
        except Exception as e:
            logger.error(f"❌ 数据库连接失败: {e}")
            raise

    def fetch_and_save(self):
        """获取并保存实时行情"""
        try:
            # 获取实时行情
            df = self.data_source.get_realtime_quotes()

            if df.empty:
                logger.warning("未获取到行情数据")
                return

            # 过滤数据
            df_filtered = self._filter_stocks(df)

            # 保存到数据库
            saved_count = self._save_to_database(df_filtered)

            # 聚合板块统计
            if saved_count > 0:
                self.aggregator.aggregate()

            self.fetch_count += 1
            logger.info(f"📊 第 {self.fetch_count} 次采集: 总数={len(df)}, "
                       f"涨跌停={len(df_filtered)}, 保存={saved_count}")

        except Exception as e:
            self.error_count += 1
            logger.error(f"❌ 采集失败 (第{self.error_count}次错误): {e}")

    def _filter_stocks(self, df):
        """
        过滤股票

        Args:
            df: 原始行情数据

        Returns:
            DataFrame: 过滤后的数据
        """
        filter_config = self.config.get('filter', {})

        # 价格过滤
        min_price = filter_config.get('min_price', 1.0)
        df = df[df['price'] >= min_price]

        # 只保存涨跌停
        if filter_config.get('only_limit', True):
            df = df[
                (df['change_pct'] >= 9.9) |   # 涨停
                (df['change_pct'] <= -9.9)    # 跌停
            ]

        return df

    def _save_to_database(self, df) -> int:
        """
        保存数据到数据库

        Args:
            df: 要保存的数据

        Returns:
            int: 保存的记录数
        """
        if df.empty:
            return 0

        cursor = self.db_conn.cursor()
        saved_count = 0
        trade_date = datetime.now().strftime('%Y-%m-%d')

        for _, row in df.iterrows():
            try:
                # 判断涨跌停类型
                limit_type = 'limit_up' if row['change_pct'] >= 9.9 else 'limit_down'

                # 判断是否一字板
                is_one_word = self.data_source.is_one_word(
                    row['open_price'],
                    row['price'],
                    row['pre_close']
                )

                # 获取额外字段（板块、涨停原因等）
                limit_reason = row.get('limit_reason', '')
                industry = row.get('industry', '')
                concept_tags = row.get('concept_tags', '')
                consecutive_limit_days = row.get('consecutive_limit_days', 1)
                first_limit_time = row.get('first_limit_time', None)
                today_auction_unmatched = row.get('today_auction_unmatched', 0)

                # 插入或更新数据
                cursor.execute("""
                    INSERT INTO daily_limit_stats (
                        trade_date, stock_code, stock_name,
                        open_price, close_price, high_price, low_price, pre_close,
                        change_pct, limit_type, is_one_word,
                        volume, turnover, turnover_rate,
                        limit_reason, industry, concept_tags,
                        consecutive_limit_days, first_limit_time,
                        today_auction_unmatched,
                        created_at, updated_at
                    ) VALUES (
                        %s, %s, %s,
                        %s, %s, %s, %s, %s,
                        %s, %s, %s,
                        %s, %s, %s,
                        %s, %s, %s,
                        %s, %s,
                        %s,
                        NOW(), NOW()
                    )
                    ON CONFLICT (trade_date, stock_code)
                    DO UPDATE SET
                        close_price = EXCLUDED.close_price,
                        high_price = EXCLUDED.high_price,
                        low_price = EXCLUDED.low_price,
                        change_pct = EXCLUDED.change_pct,
                        limit_type = EXCLUDED.limit_type,
                        is_one_word = EXCLUDED.is_one_word,
                        volume = EXCLUDED.volume,
                        turnover = EXCLUDED.turnover,
                        turnover_rate = EXCLUDED.turnover_rate,
                        limit_reason = EXCLUDED.limit_reason,
                        industry = EXCLUDED.industry,
                        concept_tags = EXCLUDED.concept_tags,
                        consecutive_limit_days = EXCLUDED.consecutive_limit_days,
                        first_limit_time = EXCLUDED.first_limit_time,
                        today_auction_unmatched = EXCLUDED.today_auction_unmatched,
                        updated_at = NOW()
                """, (
                    trade_date, row['stock_code'], row['stock_name'],
                    row['open_price'], row['price'], row['high_price'], row['low_price'], row['pre_close'],
                    row['change_pct'], limit_type, is_one_word,
                    row['volume'], row['turnover'], row['turnover_rate'],
                    limit_reason, industry, concept_tags,
                    consecutive_limit_days, first_limit_time,
                    today_auction_unmatched
                ))

                saved_count += 1

            except Exception as e:
                logger.error(f"保存股票 {row['stock_code']} 失败: {e}")
                continue

        self.db_conn.commit()
        cursor.close()

        return saved_count

    def run(self):
        """运行采集服务"""
        refresh_interval = self.config['data_source'].get('refresh_interval', 2)

        logger.info("🚀 实时行情采集服务启动")
        logger.info(f"数据源: {self.config['data_source']['type']}")
        logger.info(f"刷新间隔: {refresh_interval} 秒")
        logger.info("-" * 60)

        try:
            while True:
                self.fetch_and_save()
                time.sleep(refresh_interval)

        except KeyboardInterrupt:
            logger.info("\n⏹️  服务停止")
        except Exception as e:
            logger.error(f"❌ 服务异常退出: {e}")
        finally:
            self.cleanup()

    def cleanup(self):
        """清理资源"""
        if self.data_source:
            self.data_source.disconnect()

        if self.db_conn:
            self.db_conn.close()

        logger.info(f"统计: 采集次数={self.fetch_count}, 错误次数={self.error_count}")
        logger.info("✅ 资源清理完成")


def main():
    """主函数"""
    import argparse

    parser = argparse.ArgumentParser(description='实时行情采集服务')
    parser.add_argument(
        '--config',
        default='config/realtime.yaml',
        help='配置文件路径'
    )
    parser.add_argument(
        '--source',
        choices=['akshare', 'pytdx'],
        help='数据源类型（会覆盖配置文件）'
    )

    args = parser.parse_args()

    # 创建采集器
    fetcher = RealtimeFetcher(config_path=args.config)

    # 如果命令行指定了数据源，覆盖配置
    if args.source:
        fetcher.config['data_source']['type'] = args.source
        fetcher._init_data_source()
        logger.info(f"✅ 切换数据源为: {args.source}")

    # 运行服务
    fetcher.run()


if __name__ == '__main__':
    main()
