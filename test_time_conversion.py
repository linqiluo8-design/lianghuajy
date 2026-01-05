#!/usr/bin/env python3
"""测试 first_limit_time 字段转换"""

import pandas as pd
import akshare as ak
from datetime import datetime

# 模拟 safe_get_column
def safe_get_column(df, col_name, default_value=''):
    if col_name in df.columns:
        return df[col_name].fillna(default_value)
    else:
        return pd.Series([default_value] * len(df))

try:
    today = datetime.now().strftime('%Y%m%d')
    print(f"📅 测试日期: {today}\n")

    # 获取数据
    df_raw = ak.stock_zt_pool_strong_em(date=today)
    print(f"✅ 获取了 {len(df_raw)} 只股票\n")

    # 测试 first_limit_time 转换
    print("🔍 测试 first_limit_time 字段转换:")

    first_limit_col = safe_get_column(df_raw, '首次涨停时间', '')
    print(f"1. 原始列类型: {type(first_limit_col)}")
    print(f"2. 原始列前3个值: {list(first_limit_col.head(3))}")

    # 应用 lambda 转换
    converted = first_limit_col.apply(lambda x: None if (x == '' or pd.isna(x)) else x)
    print(f"3. 转换后类型: {type(converted)}")
    print(f"4. 转换后前3个值: {list(converted.head(3))}")

    # 检查空值情况
    empty_count = (first_limit_col == '').sum()
    na_count = first_limit_col.isna().sum()
    valid_count = len(first_limit_col) - empty_count - na_count

    print(f"\n📊 统计:")
    print(f"  - 空字符串数量: {empty_count}")
    print(f"  - NaN数量: {na_count}")
    print(f"  - 有效值数量: {valid_count}")

    # 检查转换后的None数量
    none_count = converted.isna().sum()
    print(f"  - 转换后None数量: {none_count}")

    if none_count == (empty_count + na_count):
        print("\n✅ 转换正确！")
    else:
        print("\n❌ 转换有问题！")

except Exception as e:
    print(f"❌ 错误: {e}")
    import traceback
    traceback.print_exc()
