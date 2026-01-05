# -*- coding: utf-8 -*-
"""
AkShare 数据源实现
"""

import pandas as pd
from typing import Optional, Dict
import logging

try:
    import akshare as ak
    AKSHARE_AVAILABLE = True
except ImportError:
    AKSHARE_AVAILABLE = False

from .base import DataSourceBase

logger = logging.getLogger(__name__)


class AkShareSource(DataSourceBase):
    """AkShare 数据源（免费，延迟3-5秒）"""

    def __init__(self, config: Optional[Dict] = None):
        super().__init__(config)

        if not AKSHARE_AVAILABLE:
            raise ImportError(
                "AkShare 未安装，请运行: pip install akshare"
            )

        self.connected = False
        logger.info("AkShare 数据源初始化成功")

    def connect(self) -> bool:
        """
        连接数据源（AkShare无需连接，直接可用）

        Returns:
            bool: 总是返回 True
        """
        self.connected = True
        logger.info("AkShare 数据源已就绪")
        return True

    def disconnect(self):
        """断开连接（AkShare无需断开）"""
        self.connected = False
        logger.info("AkShare 数据源已关闭")

    def get_realtime_quotes(self) -> pd.DataFrame:
        """
        获取所有A股实时行情（涨跌停 + 详细信息）

        Returns:
            pd.DataFrame: 标准化的行情数据，包含板块、涨停原因等信息
        """
        from datetime import datetime

        try:
            # 获取今日日期
            today = datetime.now().strftime("%Y%m%d")

            # 使用强势涨停池 API（包含所属行业和入选理由）
            try:
                df_raw = ak.stock_zt_pool_strong_em(date=today)
                df_raw['limit_type'] = 'limit_up'
                logger.info(f"✅ AkShare: 获取强势涨停池 {len(df_raw)} 只股票")
            except Exception as e:
                logger.error(f"❌ 获取强势涨停池失败: {e}")
                return pd.DataFrame()

            if df_raw.empty:
                logger.warning("⚠️ 强势涨停池为空")
                return pd.DataFrame()

            # 4. 字段映射和标准化（强势涨停池 API）
            # 辅助函数：安全获取列数据
            def safe_get_column(df, col_name, default_value=''):
                """安全获取DataFrame列，如果不存在返回默认值的Series"""
                if col_name in df.columns:
                    return df[col_name].fillna(default_value)
                else:
                    return pd.Series([default_value] * len(df))

            # 解析连板数（格式："1/1" 表示当前连板1天，历史最高1天）
            def parse_consecutive_days(zt_stats):
                """从涨停统计字段解析连板数"""
                try:
                    if pd.isna(zt_stats) or zt_stats == '':
                        return 1
                    # "1/1" -> 取第一个数字
                    return int(str(zt_stats).split('/')[0])
                except:
                    return 1

            df = pd.DataFrame({
                'stock_code': df_raw['代码'].apply(self._normalize_stock_code),
                'stock_name': df_raw['名称'].fillna(''),
                'price': pd.to_numeric(df_raw['最新价'], errors='coerce').fillna(0.0),
                'open_price': pd.to_numeric(safe_get_column(df_raw, '开盘价', '0'), errors='coerce').fillna(0.0),
                'high_price': pd.to_numeric(safe_get_column(df_raw, '最高价', '0'), errors='coerce').fillna(0.0),
                'low_price': pd.to_numeric(safe_get_column(df_raw, '最低价', '0'), errors='coerce').fillna(0.0),
                'pre_close': pd.to_numeric(df_raw['昨收'], errors='coerce').fillna(0.0),
                'change_pct': pd.to_numeric(df_raw['涨跌幅'], errors='coerce').fillna(0.0),
                'volume': pd.to_numeric(df_raw['成交量'], errors='coerce').fillna(0).astype(int),
                'turnover': pd.to_numeric(df_raw['成交额'], errors='coerce').fillna(0.0),
                'turnover_rate': pd.to_numeric(df_raw['换手率'], errors='coerce').fillna(0.0),
                'limit_type': df_raw['limit_type'],

                # 涨停详细信息（强势涨停池字段映射）
                'limit_reason': safe_get_column(df_raw, '入选理由', ''),  # 强势池字段名
                'concept_tags': pd.Series([''] * len(df_raw)),  # 暂时留空，AkShare 免费 API 不提供
                'industry': safe_get_column(df_raw, '所属行业', ''),  # 强势池包含此字段
                'consecutive_limit_days': safe_get_column(df_raw, '涨停统计', '1').apply(parse_consecutive_days).astype(int),
                'first_limit_time': safe_get_column(df_raw, '首次涨停时间', ''),

                # 封单信息
                'today_auction_unmatched': pd.to_numeric(safe_get_column(df_raw, '封单金额', '0'), errors='coerce').fillna(0).astype(int),
            })

            # 统计各市场分布
            market_stats = df.groupby(df['stock_code'].str[-2:]).size().to_dict()
            sh_count = market_stats.get('SH', 0)  # 上海（主板+科创板）
            sz_count = market_stats.get('SZ', 0)  # 深圳（主板+创业板）
            bj_count = market_stats.get('BJ', 0)  # 北交所

            logger.info(f"✅ AkShare: 获取了 {len(df)} 只强势涨停股票")
            logger.info(f"📊 市场分布: 上海{sh_count}只, 深圳{sz_count}只, 北交所{bj_count}只")

            return df

        except Exception as e:
            logger.error(f"❌ AkShare 获取实时行情失败: {e}")
            return pd.DataFrame()

    def get_stock_quote(self, stock_code: str) -> Optional[Dict]:
        """
        获取单只股票实时行情

        Args:
            stock_code: 股票代码（如：600000）

        Returns:
            Dict: 股票行情字典
        """
        try:
            # 获取所有行情并筛选
            df = self.get_realtime_quotes()

            # 标准化代码格式
            normalized_code = self._normalize_stock_code(stock_code)

            # 查找股票
            stock_data = df[df['stock_code'] == normalized_code]

            if stock_data.empty:
                logger.warning(f"未找到股票: {stock_code}")
                return None

            # 转换为字典
            return stock_data.iloc[0].to_dict()

        except Exception as e:
            logger.error(f"❌ AkShare 获取股票 {stock_code} 失败: {e}")
            return None

    def _normalize_stock_code(self, code: str) -> str:
        """
        标准化股票代码格式

        Args:
            code: 原始代码（如：600000, sh600000, 600000.SH）

        Returns:
            str: 标准化代码（如：600000.SH）
        """
        # 移除可能的前缀和后缀
        code = str(code).upper().replace('SH', '').replace('SZ', '').replace('.', '')

        # 判断市场
        if code.startswith('6') or code.startswith('5'):
            # 上海
            return f"{code}.SH"
        elif code.startswith('0') or code.startswith('3'):
            # 深圳
            return f"{code}.SZ"
        elif code.startswith('4') or code.startswith('8'):
            # 北交所
            return f"{code}.BJ"
        else:
            # 默认深圳
            return f"{code}.SZ"

    def get_limit_up_stocks(self) -> pd.DataFrame:
        """
        获取涨停股票列表

        Returns:
            pd.DataFrame: 涨停股票数据
        """
        df = self.get_realtime_quotes()
        return df[df['change_pct'] >= 9.9]

    def get_limit_down_stocks(self) -> pd.DataFrame:
        """
        获取跌停股票列表

        Returns:
            pd.DataFrame: 跌停股票数据
        """
        df = self.get_realtime_quotes()
        return df[df['change_pct'] <= -9.9]
