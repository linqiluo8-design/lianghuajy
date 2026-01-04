# -*- coding: utf-8 -*-
"""
pytdx (通达信) 数据源实现
"""

import pandas as pd
from typing import Optional, Dict, List
import logging

try:
    from pytdx.hq import TdxHq_API
    PYTDX_AVAILABLE = True
except ImportError:
    PYTDX_AVAILABLE = False

from .base import DataSourceBase

logger = logging.getLogger(__name__)


class PytdxSource(DataSourceBase):
    """pytdx (通达信) 数据源（免费，延迟2-3秒，稳定性好）"""

    # 通达信免费行情服务器列表
    TDX_SERVERS = [
        ('119.147.212.81', 7709),  # 深圳行情
        ('114.80.63.12', 7709),    # 上海行情1
        ('114.80.63.35', 7709),    # 上海行情2
        ('60.12.136.250', 7709),   # 备用服务器1
        ('115.238.90.165', 7709),  # 备用服务器2
    ]

    def __init__(self, config: Optional[Dict] = None):
        super().__init__(config)

        if not PYTDX_AVAILABLE:
            raise ImportError(
                "pytdx 未安装，请运行: pip install pytdx"
            )

        self.api = TdxHq_API()
        self.connected = False
        self.current_server = None

        # 从配置读取服务器，或使用默认
        self.servers = self.config.get('servers', self.TDX_SERVERS)

        logger.info("pytdx 数据源初始化成功")

    def connect(self) -> bool:
        """
        连接通达信服务器（自动选择最快的服务器）

        Returns:
            bool: 连接是否成功
        """
        for server_ip, server_port in self.servers:
            try:
                logger.info(f"尝试连接通达信服务器: {server_ip}:{server_port}")

                result = self.api.connect(server_ip, server_port)

                if result:
                    self.connected = True
                    self.current_server = (server_ip, server_port)
                    logger.info(f"✅ pytdx 连接成功: {server_ip}:{server_port}")
                    return True

            except Exception as e:
                logger.warning(f"连接 {server_ip}:{server_port} 失败: {e}")
                continue

        logger.error("❌ 所有通达信服务器连接失败")
        return False

    def disconnect(self):
        """断开连接"""
        if self.api and self.connected:
            try:
                self.api.disconnect()
                self.connected = False
                logger.info("pytdx 连接已断开")
            except Exception as e:
                logger.error(f"断开连接失败: {e}")

    def get_realtime_quotes(self) -> pd.DataFrame:
        """
        获取所有A股实时行情

        Returns:
            pd.DataFrame: 标准化的行情数据
        """
        if not self.connected:
            logger.warning("pytdx 未连接，尝试重新连接...")
            if not self.connect():
                return pd.DataFrame()

        try:
            all_stocks = []

            # 获取上海A股
            sh_stocks = self._get_market_stocks(1)  # 1 = 上海
            all_stocks.extend(sh_stocks)

            # 获取深圳A股
            sz_stocks = self._get_market_stocks(0)  # 0 = 深圳
            all_stocks.extend(sz_stocks)

            logger.info(f"✅ pytdx: 获取了 {len(all_stocks)} 只股票行情")

            # 转换为 DataFrame
            df = pd.DataFrame(all_stocks)

            return df

        except Exception as e:
            logger.error(f"❌ pytdx 获取实时行情失败: {e}")
            return pd.DataFrame()

    def _get_market_stocks(self, market: int) -> List[Dict]:
        """
        获取指定市场的股票行情

        Args:
            market: 市场代码（0=深圳，1=上海）

        Returns:
            List[Dict]: 股票行情列表
        """
        stocks = []

        try:
            # 获取股票数量
            count = self.api.get_security_count(market)

            # 批量获取（每次最多800只）
            batch_size = 800
            for start in range(0, count, batch_size):
                stock_list = self.api.get_security_list(market, start)

                # 每批次获取详细行情
                for stock in stock_list:
                    code = stock['code']

                    # 只获取A股（过滤指数、B股等）
                    if not self._is_a_stock(code, market):
                        continue

                    # 获取5档行情
                    quote = self.api.get_security_quotes([(market, code)])

                    if quote and len(quote) > 0:
                        q = quote[0]
                        stocks.append(self._normalize_quote(q, market))

        except Exception as e:
            logger.error(f"获取市场 {market} 行情失败: {e}")

        return stocks

    def get_stock_quote(self, stock_code: str) -> Optional[Dict]:
        """
        获取单只股票实时行情

        Args:
            stock_code: 股票代码（如：600000 或 000001）

        Returns:
            Dict: 股票行情字典
        """
        if not self.connected:
            if not self.connect():
                return None

        try:
            # 判断市场
            market = self._get_market(stock_code)
            code = self._clean_code(stock_code)

            # 获取5档行情
            quotes = self.api.get_security_quotes([(market, code)])

            if quotes and len(quotes) > 0:
                return self._normalize_quote(quotes[0], market)

            return None

        except Exception as e:
            logger.error(f"❌ pytdx 获取股票 {stock_code} 失败: {e}")
            return None

    def _normalize_quote(self, quote: Dict, market: int) -> Dict:
        """
        标准化行情数据格式

        Args:
            quote: 原始行情数据
            market: 市场代码

        Returns:
            Dict: 标准化的行情数据
        """
        code = quote['code']
        market_suffix = 'SH' if market == 1 else 'SZ'

        return {
            'stock_code': f"{code}.{market_suffix}",
            'stock_name': quote.get('name', ''),
            'price': float(quote.get('price', 0)),
            'open_price': float(quote.get('open', 0)),
            'high_price': float(quote.get('high', 0)),
            'low_price': float(quote.get('low', 0)),
            'pre_close': float(quote.get('last_close', 0)),
            'change_pct': self._calculate_change_pct(
                float(quote.get('price', 0)),
                float(quote.get('last_close', 0))
            ),
            'volume': int(quote.get('vol', 0)),
            'turnover': float(quote.get('amount', 0)),
            'turnover_rate': 0,  # pytdx 不提供换手率，需单独计算
            'bid1': float(quote.get('bid1', 0)),
            'bid1_volume': int(quote.get('bid_vol1', 0)),
            'ask1': float(quote.get('ask1', 0)),
            'ask1_volume': int(quote.get('ask_vol1', 0)),
        }

    def _calculate_change_pct(self, price: float, pre_close: float) -> float:
        """计算涨跌幅"""
        if pre_close <= 0:
            return 0.0
        return round((price - pre_close) / pre_close * 100, 2)

    def _get_market(self, stock_code: str) -> int:
        """
        根据股票代码判断市场

        Args:
            stock_code: 股票代码

        Returns:
            int: 0=深圳，1=上海
        """
        code = self._clean_code(stock_code)

        if code.startswith('6') or code.startswith('5'):
            return 1  # 上海
        else:
            return 0  # 深圳

    def _clean_code(self, stock_code: str) -> str:
        """清理股票代码，只保留数字"""
        return str(stock_code).replace('SH', '').replace('SZ', '').replace('.', '').strip()

    def _is_a_stock(self, code: str, market: int) -> bool:
        """
        判断是否为A股（过滤B股、指数等）

        Args:
            code: 股票代码
            market: 市场代码

        Returns:
            bool: 是否为A股
        """
        if market == 1:  # 上海
            # 6开头为A股，900开头为B股
            return code.startswith('6') and not code.startswith('900')
        else:  # 深圳
            # 0、3开头为A股，200开头为B股
            return (code.startswith('0') or code.startswith('3')) and not code.startswith('200')

    def __del__(self):
        """析构函数，确保断开连接"""
        self.disconnect()
