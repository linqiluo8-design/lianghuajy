# -*- coding: utf-8 -*-
"""
数据源抽象基类
"""

from abc import ABC, abstractmethod
from typing import List, Dict, Optional
import pandas as pd


class DataSourceBase(ABC):
    """数据源抽象基类"""

    def __init__(self, config: Optional[Dict] = None):
        """
        初始化数据源

        Args:
            config: 配置字典
        """
        self.config = config or {}
        self.name = self.__class__.__name__

    @abstractmethod
    def connect(self) -> bool:
        """
        连接数据源

        Returns:
            bool: 连接是否成功
        """
        pass

    @abstractmethod
    def disconnect(self):
        """断开连接"""
        pass

    @abstractmethod
    def get_realtime_quotes(self) -> pd.DataFrame:
        """
        获取所有A股实时行情

        Returns:
            pd.DataFrame: 包含以下字段的DataFrame
                - stock_code: 股票代码 (str)
                - stock_name: 股票名称 (str)
                - price: 最新价 (float)
                - open_price: 开盘价 (float)
                - high_price: 最高价 (float)
                - low_price: 最低价 (float)
                - pre_close: 昨收价 (float)
                - change_pct: 涨跌幅 (float)
                - volume: 成交量 (int)
                - turnover: 成交额 (float)
                - turnover_rate: 换手率 (float)
                - bid1: 买一价 (float)
                - bid1_volume: 买一量 (int)
                - ask1: 卖一价 (float)
                - ask1_volume: 卖一量 (int)
        """
        pass

    @abstractmethod
    def get_stock_quote(self, stock_code: str) -> Optional[Dict]:
        """
        获取单只股票实时行情

        Args:
            stock_code: 股票代码（如：600000 或 000001）

        Returns:
            Dict: 股票行情字典，字段同 get_realtime_quotes
        """
        pass

    def is_limit_up(self, price: float, pre_close: float, stock_code: str = None) -> bool:
        """
        判断是否涨停

        Args:
            price: 当前价格
            pre_close: 昨收价
            stock_code: 股票代码（用于区分ST等特殊股票）

        Returns:
            bool: 是否涨停
        """
        if pre_close <= 0:
            return False

        change_pct = (price - pre_close) / pre_close * 100

        # ST股票涨停5%，其他10%
        limit_pct = 5.0 if stock_code and 'ST' in stock_code else 10.0

        return change_pct >= limit_pct - 0.01  # 允许0.01%的误差

    def is_limit_down(self, price: float, pre_close: float, stock_code: str = None) -> bool:
        """
        判断是否跌停

        Args:
            price: 当前价格
            pre_close: 昨收价
            stock_code: 股票代码

        Returns:
            bool: 是否跌停
        """
        if pre_close <= 0:
            return False

        change_pct = (price - pre_close) / pre_close * 100

        # ST股票跌停-5%，其他-10%
        limit_pct = -5.0 if stock_code and 'ST' in stock_code else -10.0

        return change_pct <= limit_pct + 0.01  # 允许0.01%的误差

    def is_one_word(self, open_price: float, price: float, pre_close: float) -> bool:
        """
        判断是否一字板（开盘即涨停/跌停）

        Args:
            open_price: 开盘价
            price: 当前价格
            pre_close: 昨收价

        Returns:
            bool: 是否一字板
        """
        if pre_close <= 0:
            return False

        open_change = abs((open_price - pre_close) / pre_close * 100)
        current_change = abs((price - pre_close) / pre_close * 100)

        # 开盘和当前都接近涨跌停幅度
        return open_change >= 9.9 and current_change >= 9.9

    def __str__(self) -> str:
        return f"<{self.name}>"

    def __repr__(self) -> str:
        return self.__str__()
