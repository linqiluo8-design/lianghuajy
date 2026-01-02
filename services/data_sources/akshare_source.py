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
        获取所有A股实时行情

        Returns:
            pd.DataFrame: 标准化的行情数据
        """
        try:
            # 从东方财富获取实时行情
            df_raw = ak.stock_zh_a_spot_em()

            # 字段映射和标准化
            df = pd.DataFrame({
                'stock_code': df_raw['代码'].apply(self._normalize_stock_code),
                'stock_name': df_raw['名称'],
                'price': df_raw['最新价'].astype(float),
                'open_price': df_raw['今开'].astype(float),
                'high_price': df_raw['最高'].astype(float),
                'low_price': df_raw['最低'].astype(float),
                'pre_close': df_raw['昨收'].astype(float),
                'change_pct': df_raw['涨跌幅'].astype(float),
                'volume': df_raw['成交量'].astype(int),
                'turnover': df_raw['成交额'].astype(float),
                'turnover_rate': df_raw['换手率'].astype(float),
                'bid1': df_raw.get('买一', 0).astype(float) if '买一' in df_raw.columns else 0,
                'bid1_volume': df_raw.get('买一量', 0).astype(int) if '买一量' in df_raw.columns else 0,
                'ask1': df_raw.get('卖一', 0).astype(float) if '卖一' in df_raw.columns else 0,
                'ask1_volume': df_raw.get('卖一量', 0).astype(int) if '卖一量' in df_raw.columns else 0,
            })

            logger.info(f"✅ AkShare: 获取了 {len(df)} 只股票行情")
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
