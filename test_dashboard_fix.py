#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
测试脚本：验证看板修复是否正确

检查项：
1. daily_limit_stats 表有数据
2. industry 字段有值
3. sector_aggregator 正确聚合到行业
4. sector_daily_stats 有多个行业记录
5. 后端 API 返回正确的板块数据
"""

import os
import sys
import psycopg2
from datetime import datetime

# 数据库配置
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': int(os.getenv('DB_PORT', '5432')),
    'database': os.getenv('DB_NAME', 'funcat'),
    'user': os.getenv('DB_USER', 'funcat_user'),
    'password': os.getenv('DB_PASSWORD', 'funcat_password_change_me')
}

def check_database():
    """检查数据库状态"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()

        today = datetime.now().strftime('%Y-%m-%d')

        print("=" * 80)
        print(f"📅 测试日期: {today}")
        print("=" * 80)

        # 1. 检查 daily_limit_stats 原始数据
        print("\n1️⃣  检查 daily_limit_stats 原始数据")
        print("-" * 80)
        cur.execute("""
            SELECT
                COUNT(*) as total,
                COUNT(DISTINCT industry) as distinct_industries,
                COUNT(CASE WHEN industry IS NOT NULL AND industry != '' THEN 1 END) as has_industry,
                COUNT(DISTINCT concept_tags) as distinct_concepts
            FROM daily_limit_stats
            WHERE trade_date = %s
        """, (today,))

        row = cur.fetchone()
        print(f"  ✓ 总记录数: {row[0]}")
        print(f"  ✓ 不同行业数: {row[1]}")
        print(f"  ✓ 有行业字段的记录: {row[2]}")
        print(f"  ✓ 不同概念数: {row[3]}")

        if row[0] == 0:
            print(f"\n❌ {today} 没有数据！请先运行数据采集。")
            return False

        if row[2] == 0:
            print(f"\n⚠️  警告：所有记录的 industry 字段都为空！")
            return False

        # 2. 显示行业分布
        print("\n2️⃣  行业分布")
        print("-" * 80)
        cur.execute("""
            SELECT industry, COUNT(*) as count
            FROM daily_limit_stats
            WHERE trade_date = %s
            AND industry IS NOT NULL
            AND industry != ''
            GROUP BY industry
            ORDER BY count DESC
            LIMIT 10
        """, (today,))

        for industry, count in cur.fetchall():
            print(f"  {industry}: {count} 只")

        # 3. 检查 sector_daily_stats 聚合结果
        print("\n3️⃣  检查 sector_daily_stats 聚合结果")
        print("-" * 80)
        cur.execute("""
            SELECT COUNT(DISTINCT sector_name)
            FROM sector_daily_stats
            WHERE trade_date = %s
        """, (today,))

        sector_count = cur.fetchone()[0]
        print(f"  ✓ 板块数量: {sector_count}")

        if sector_count == 0:
            print(f"  ⚠️  没有聚合数据！需要运行聚合。")
            print(f"\n运行聚合命令：")
            print(f"  docker compose exec -T realtime python3 -c \"")
            print(f"from services.sector_aggregator import SectorAggregator")
            print(f"agg = SectorAggregator()")
            print(f"agg.connect()")
            print(f"agg.aggregate('{today}')")
            print(f"\"")
            return False

        if sector_count == 1:
            cur.execute("""
                SELECT sector_name
                FROM sector_daily_stats
                WHERE trade_date = %s
                LIMIT 1
            """, (today,))
            sector_name = cur.fetchone()[0]

            if sector_name == '全市场':
                print(f"  ❌ 错误：只聚合到'全市场'，没有细分板块！")
                print(f"  原因：聚合逻辑未使用 industry 字段")
                return False

        # 4. 显示板块排行
        print("\n4️⃣  板块涨停排行 Top 10")
        print("-" * 80)
        cur.execute("""
            SELECT
                sds.sector_name,
                sds.limit_up_count,
                sds.limit_down_count,
                sds.total_stocks
            FROM sector_daily_stats sds
            WHERE sds.trade_date = %s
            ORDER BY sds.limit_up_count DESC
            LIMIT 10
        """, (today,))

        print(f"  {'排名':<4} {'板块名称':<15} {'涨停':<6} {'跌停':<6} {'总数':<6}")
        print(f"  {'-'*4} {'-'*15} {'-'*6} {'-'*6} {'-'*6}")

        for idx, (name, up, down, total) in enumerate(cur.fetchall(), 1):
            print(f"  #{idx:<3} {name:<15} {up:<6} {down:<6} {total:<6}")

        # 5. 测试后端 JOIN 查询（dashboard 实际使用的）
        print("\n5️⃣  测试后端 API 查询（dashboard 实际使用）")
        print("-" * 80)
        cur.execute("""
            SELECT
                sds.trade_date,
                s.sector_name,
                sds.limit_up_count,
                sds.limit_down_count
            FROM sector_daily_stats sds
            JOIN sectors s ON sds.sector_id = s.id
            WHERE sds.trade_date = %s
            ORDER BY sds.limit_up_count DESC
            LIMIT 5
        """, (today,))

        results = cur.fetchall()
        print(f"  ✓ JOIN 查询返回 {len(results)} 条记录")

        if len(results) == 0:
            print(f"  ❌ 错误：JOIN 查询返回0条记录！")
            print(f"  可能原因：sector_daily_stats.sector_id 与 sectors.id 不匹配")
            return False

        for date, name, up, down in results:
            print(f"    {name}: 涨停{up}, 跌停{down}")

        # 6. 检查 limit_reason_stats
        print("\n6️⃣  检查涨停原因统计")
        print("-" * 80)
        cur.execute("""
            SELECT reason_name, limit_up_count
            FROM limit_reason_stats
            WHERE trade_date = %s
            ORDER BY limit_up_count DESC
            LIMIT 5
        """, (today,))

        print(f"  {'原因':<25} {'涨停数'}")
        print(f"  {'-'*25} {'-'*7}")
        for reason, count in cur.fetchall():
            print(f"  {reason:<25} {count}")

        print("\n" + "=" * 80)
        print("✅ 所有检查通过！看板数据应该正常显示。")
        print("=" * 80)

        cur.close()
        conn.close()
        return True

    except psycopg2.OperationalError as e:
        print(f"\n❌ 数据库连接失败: {e}")
        print(f"\n请确保：")
        print(f"  1. PostgreSQL 服务正在运行")
        print(f"  2. 数据库连接配置正确")
        print(f"  3. 在 Docker 环境中运行此脚本")
        return False
    except Exception as e:
        print(f"\n❌ 检查失败: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == '__main__':
    success = check_database()
    sys.exit(0 if success else 1)
