#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
调试脚本：查看 AkShare 强势涨停池 API 实际返回的列名和数据
"""

import akshare as ak
from datetime import datetime

def debug_strong_pool_api():
    """测试强势涨停池API的实际返回结构"""

    today = datetime.now().strftime('%Y%m%d')
    print(f"📅 测试日期: {today}")
    print("=" * 80)

    try:
        # 调用强势涨停池API
        print("\n🔍 调用 stock_zt_pool_strong_em()...")
        df = ak.stock_zt_pool_strong_em(date=today)

        print(f"\n✅ 获取成功！共 {len(df)} 只股票")
        print("=" * 80)

        # 1. 显示所有列名
        print("\n📋 API返回的所有列名:")
        for i, col in enumerate(df.columns, 1):
            print(f"  {i:2d}. '{col}'")

        # 2. 显示前3条数据
        print("\n📊 前3条数据样例:")
        print(df.head(3).to_string())

        # 3. 检查关键字段是否存在
        print("\n🔎 关键字段检查:")
        key_fields = ['序号', '代码', '名称', '最新价', '涨跌幅', '成交额',
                      '所属行业', '入选理由', '涨停统计', '首次涨停时间', '封单金额']

        for field in key_fields:
            exists = field in df.columns
            symbol = "✅" if exists else "❌"
            print(f"  {symbol} {field}")

        # 4. 显示数据类型
        print("\n📈 数据类型:")
        print(df.dtypes)

        return df

    except Exception as e:
        print(f"\n❌ 调用失败: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == '__main__':
    df = debug_strong_pool_api()

    if df is not None:
        print("\n" + "=" * 80)
        print("✅ 调试完成！请检查上面的列名，确认字段映射是否正确。")
    else:
        print("\n" + "=" * 80)
        print("❌ 调试失败！请检查网络连接和AkShare版本。")
