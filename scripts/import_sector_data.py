#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
板块数据导入脚本

功能：
1. 从 AkShare 获取行业板块和概念板块数据
2. 获取股票-板块映射关系
3. 写入数据库

使用：
    python3 scripts/import_sector_data.py
"""

import os
import sys
import logging
import psycopg2
from datetime import datetime

# 添加项目根目录到路径
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

try:
    import akshare as ak
    import pandas as pd
    AKSHARE_AVAILABLE = True
except ImportError:
    AKSHARE_AVAILABLE = False
    print("❌ AkShare 未安装，请运行: pip install akshare")
    sys.exit(1)

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)


class SectorDataImporter:
    """板块数据导入器"""

    def __init__(self):
        """初始化"""
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

    def import_sectors(self):
        """导入板块数据"""
        cursor = self.db_conn.cursor()

        try:
            logger.info("📊 获取板块分类数据...")

            # 1. 获取行业板块（东方财富行业板块）
            logger.info("获取行业板块...")
            df_industry = ak.stock_board_industry_name_em()
            logger.info(f"  获取到 {len(df_industry)} 个行业板块")

            # 2. 获取概念板块
            logger.info("获取概念板块...")
            df_concept = ak.stock_board_concept_name_em()
            logger.info(f"  获取到 {len(df_concept)} 个概念板块")

            # 3. 清空旧数据（保留全市场板块）
            cursor.execute("""
                DELETE FROM stock_sector_mapping;
                DELETE FROM sector_daily_stats WHERE sector_id != (
                    SELECT id FROM sectors WHERE sector_code = 'ALL_MARKET'
                );
                DELETE FROM sectors WHERE sector_code != 'ALL_MARKET';
            """)
            logger.info("🗑️  清空旧板块数据")

            # 4. 插入行业板块
            logger.info("📝 导入行业板块...")
            industry_count = 0
            for _, row in df_industry.iterrows():
                try:
                    cursor.execute("""
                        INSERT INTO sectors (sector_code, sector_name, sector_type, stock_count)
                        VALUES (%s, %s, %s, %s)
                        ON CONFLICT (sector_code) DO UPDATE
                        SET sector_name = EXCLUDED.sector_name,
                            stock_count = EXCLUDED.stock_count
                    """, (
                        row['板块代码'],
                        row['板块名称'],
                        'industry',
                        0  # 先设为0，后续更新
                    ))
                    industry_count += 1
                except Exception as e:
                    logger.warning(f"  跳过板块 {row.get('板块名称', 'unknown')}: {e}")
                    continue

            logger.info(f"✅ 导入 {industry_count} 个行业板块")

            # 5. 插入概念板块（限制数量，避免太多）
            logger.info("📝 导入概念板块（前100个）...")
            concept_count = 0
            for _, row in df_concept.head(100).iterrows():
                try:
                    cursor.execute("""
                        INSERT INTO sectors (sector_code, sector_name, sector_type, stock_count)
                        VALUES (%s, %s, %s, %s)
                        ON CONFLICT (sector_code) DO UPDATE
                        SET sector_name = EXCLUDED.sector_name,
                            stock_count = EXCLUDED.stock_count
                    """, (
                        row['板块代码'],
                        row['板块名称'],
                        'concept',
                        0
                    ))
                    concept_count += 1
                except Exception as e:
                    logger.warning(f"  跳过板块 {row.get('板块名称', 'unknown')}: {e}")
                    continue

            logger.info(f"✅ 导入 {concept_count} 个概念板块")

            self.db_conn.commit()
            return industry_count + concept_count

        except Exception as e:
            self.db_conn.rollback()
            logger.error(f"❌ 导入板块失败: {e}")
            import traceback
            traceback.print_exc()
            return 0
        finally:
            cursor.close()

    def import_stock_sector_mapping(self, limit_sectors=20):
        """
        导入股票-板块映射关系

        Args:
            limit_sectors: 限制处理的板块数量（避免太慢）
        """
        cursor = self.db_conn.cursor()

        try:
            # 获取需要导入映射的板块（行业板块优先）
            cursor.execute("""
                SELECT id, sector_code, sector_name, sector_type
                FROM sectors
                WHERE sector_code != 'ALL_MARKET'
                ORDER BY
                    CASE sector_type
                        WHEN 'industry' THEN 1
                        WHEN 'concept' THEN 2
                        ELSE 3
                    END,
                    id
                LIMIT %s
            """, (limit_sectors,))

            sectors = cursor.fetchall()
            logger.info(f"📊 准备导入 {len(sectors)} 个板块的股票映射...")

            total_mappings = 0

            for sector_id, sector_code, sector_name, sector_type in sectors:
                try:
                    logger.info(f"  处理板块: {sector_name} ({sector_type})")

                    # 获取该板块的成分股
                    if sector_type == 'industry':
                        df_stocks = ak.stock_board_industry_cons_em(symbol=sector_name)
                    elif sector_type == 'concept':
                        df_stocks = ak.stock_board_concept_cons_em(symbol=sector_name)
                    else:
                        continue

                    if df_stocks.empty:
                        logger.warning(f"    板块 {sector_name} 没有成分股")
                        continue

                    # 插入映射关系
                    mapping_count = 0
                    for _, stock in df_stocks.iterrows():
                        try:
                            stock_code = stock['代码']

                            cursor.execute("""
                                INSERT INTO stock_sector_mapping (stock_code, sector_id, weight)
                                VALUES (%s, %s, %s)
                                ON CONFLICT DO NOTHING
                            """, (stock_code, sector_id, 100.0))

                            mapping_count += 1
                        except Exception as e:
                            continue

                    # 更新板块股票数量
                    cursor.execute("""
                        UPDATE sectors
                        SET stock_count = %s
                        WHERE id = %s
                    """, (mapping_count, sector_id))

                    self.db_conn.commit()
                    total_mappings += mapping_count
                    logger.info(f"    ✅ 导入 {mapping_count} 只股票")

                except Exception as e:
                    logger.warning(f"    ⚠️  板块 {sector_name} 导入失败: {e}")
                    self.db_conn.rollback()
                    continue

            logger.info(f"✅ 总共导入 {total_mappings} 条股票-板块映射")
            return total_mappings

        except Exception as e:
            self.db_conn.rollback()
            logger.error(f"❌ 导入映射失败: {e}")
            import traceback
            traceback.print_exc()
            return 0
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

    parser = argparse.ArgumentParser(description='导入板块数据和股票映射')
    parser.add_argument(
        '--sectors',
        type=int,
        default=20,
        help='导入的板块数量（默认20个，避免太慢）'
    )
    parser.add_argument(
        '--skip-mapping',
        action='store_true',
        help='跳过股票映射导入（只导入板块列表）'
    )

    args = parser.parse_args()

    logger.info("========================================")
    logger.info("  板块数据导入工具")
    logger.info("========================================")
    logger.info("")

    importer = SectorDataImporter()

    if not importer.connect():
        sys.exit(1)

    try:
        # 1. 导入板块
        sector_count = importer.import_sectors()
        logger.info("")
        logger.info(f"📊 导入了 {sector_count} 个板块")

        if args.skip_mapping:
            logger.info("⏭️  跳过股票映射导入")
        else:
            # 2. 导入股票映射
            logger.info("")
            logger.info("========================================")
            logger.info(f"  开始导入股票-板块映射（前{args.sectors}个板块）")
            logger.info("  ⚠️  这可能需要几分钟时间...")
            logger.info("========================================")
            logger.info("")

            mapping_count = importer.import_stock_sector_mapping(args.sectors)
            logger.info("")
            logger.info(f"📊 导入了 {mapping_count} 条映射关系")

        logger.info("")
        logger.info("========================================")
        logger.info("  ✅ 导入完成！")
        logger.info("========================================")
        logger.info("")
        logger.info("💡 下一步:")
        logger.info("  1. 重新运行聚合脚本:")
        logger.info("     python3 services/sector_aggregator.py")
        logger.info("")
        logger.info("  2. 或重启 realtime 服务:")
        logger.info("     docker-compose restart realtime")
        logger.info("")

    except Exception as e:
        logger.error(f"❌ 导入异常: {e}")
        sys.exit(1)
    finally:
        importer.close()


if __name__ == '__main__':
    main()
