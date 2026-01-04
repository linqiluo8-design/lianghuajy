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

            # 1. 获取涨停池数据（包含涨停原因、板块等）
            try:
                df_zt = ak.stock_zt_pool_em(date=today)
                df_zt['limit_type'] = 'limit_up'
                logger.info(f"✅ AkShare: 获取涨停池 {len(df_zt)} 只股票")
            except Exception as e:
                logger.warning(f"⚠️ 获取涨停池失败: {e}")
                df_zt = pd.DataFrame()

            # 2. 获取跌停池数据（使用 stock_zt_pool_dtgc_em 接口）
            try:
                df_dt = ak.stock_zt_pool_dtgc_em(date=today)
                df_dt['limit_type'] = 'limit_down'
                logger.info(f"✅ AkShare: 获取跌停池 {len(df_dt)} 只股票")
            except Exception as e:
                logger.warning(f"⚠️ 获取跌停池失败: {e}")
                df_dt = pd.DataFrame()

            # 3. 合并涨停和跌停数据
            if not df_zt.empty and not df_dt.empty:
                df_raw = pd.concat([df_zt, df_dt], ignore_index=True)
            elif not df_zt.empty:
                df_raw = df_zt
            elif not df_dt.empty:
                df_raw = df_dt
            else:
                logger.warning("⚠️ 涨停池和跌停池均为空")
                return pd.DataFrame()

            # 4. 字段映射和标准化
            df = pd.DataFrame({
                'stock_code': df_raw['代码'].apply(self._normalize_stock_code),
                'stock_name': df_raw['名称'].fillna(''),
                'price': pd.to_numeric(df_raw['最新价'], errors='coerce').fillna(0.0),
                'open_price': pd.to_numeric(df_raw['开盘价'], errors='coerce').fillna(0.0) if '开盘价' in df_raw.columns else pd.to_numeric(df_raw.get('今开', 0), errors='coerce').fillna(0.0),
                'high_price': pd.to_numeric(df_raw['最高价'], errors='coerce').fillna(0.0) if '最高价' in df_raw.columns else pd.to_numeric(df_raw.get('最高', 0), errors='coerce').fillna(0.0),
                'low_price': pd.to_numeric(df_raw['最低价'], errors='coerce').fillna(0.0) if '最低价' in df_raw.columns else pd.to_numeric(df_raw.get('最低', 0), errors='coerce').fillna(0.0),
                'pre_close': pd.to_numeric(df_raw['昨收'], errors='coerce').fillna(0.0),
                'change_pct': pd.to_numeric(df_raw['涨跌幅'], errors='coerce').fillna(0.0),
                'volume': pd.to_numeric(df_raw['成交量'], errors='coerce').fillna(0).astype(int),
                'turnover': pd.to_numeric(df_raw['成交额'], errors='coerce').fillna(0.0),
                'turnover_rate': pd.to_numeric(df_raw['换手率'], errors='coerce').fillna(0.0),
                'limit_type': df_raw['limit_type'],

                # 新增：涨跌停详细信息
                'limit_reason': df_raw['涨停原因分类'].fillna('') if '涨停原因分类' in df_raw.columns else df_raw.get('跌停原因分类', '').fillna(''),
                'concept_tags': df_raw['所属概念'].fillna('') if '所属概念' in df_raw.columns else '',
                'industry': df_raw['所属行业'].fillna('') if '所属行业' in df_raw.columns else '',
                'consecutive_limit_days': pd.to_numeric(df_raw.get('连板数', 1), errors='coerce').fillna(1).astype(int),
                'first_limit_time': df_raw.get('首次涨停时间', '') if '首次涨停时间' in df_raw.columns else df_raw.get('首次跌停时间', ''),

                # 封单信息
                'today_auction_unmatched': pd.to_numeric(df_raw.get('封单金额', 0), errors='coerce').fillna(0).astype(int),
            })

            # 统计各市场分布
            market_stats = df.groupby(df['stock_code'].str[-2:]).size().to_dict()
            sh_count = market_stats.get('SH', 0)  # 上海（主板+科创板）
            sz_count = market_stats.get('SZ', 0)  # 深圳（主板+创业板）
            bj_count = market_stats.get('BJ', 0)  # 北交所

            logger.info(f"✅ AkShare: 获取了 {len(df)} 只涨跌停股票（涨停={len(df_zt)}, 跌停={len(df_dt)}）")
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
