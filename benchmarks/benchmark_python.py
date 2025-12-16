#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Python性能基准测试
测试优化前后的性能差异
"""

import time
import numpy as np
from funcat.func import SMASeries, count
from funcat.time_series import NumericSeries, BoolSeries
from funcat import indicators


def benchmark_sma(size=1000, iterations=100):
    """测试SMA性能"""
    print(f"\n{'='*60}")
    print(f"测试 SMA 函数 (数据量: {size}, 迭代: {iterations})")
    print(f"{'='*60}")

    # 生成随机数据
    data = np.random.rand(size)
    series = NumericSeries(data)

    # 测试
    start = time.time()
    for _ in range(iterations):
        result = SMASeries(series, 20, 1)
    elapsed = time.time() - start

    avg_time = elapsed / iterations * 1000  # 毫秒
    print(f"平均耗时: {avg_time:.2f} ms")
    print(f"总耗时: {elapsed:.2f} 秒")
    print(f"吞吐量: {iterations/elapsed:.2f} ops/秒")

    return avg_time


def benchmark_count(size=1000, iterations=100):
    """测试COUNT性能"""
    print(f"\n{'='*60}")
    print(f"测试 COUNT 函数 (数据量: {size}, 迭代: {iterations})")
    print(f"{'='*60}")

    # 生成随机布尔数据
    data = np.random.rand(size) > 0.5
    series = BoolSeries(data)

    # 测试
    start = time.time()
    for _ in range(iterations):
        result = count(series, 10)
    elapsed = time.time() - start

    avg_time = elapsed / iterations * 1000  # 毫秒
    print(f"平均耗时: {avg_time:.2f} ms")
    print(f"总耗时: {elapsed:.2f} 秒")
    print(f"吞吐量: {iterations/elapsed:.2f} ops/秒")

    return avg_time


def benchmark_ma(size=1000, iterations=100):
    """测试MA性能"""
    print(f"\n{'='*60}")
    print(f"测试 MA 函数 (数据量: {size}, 迭代: {iterations})")
    print(f"{'='*60}")

    # 生成随机数据
    data = np.random.rand(size)
    series = NumericSeries(data)

    # 测试
    start = time.time()
    for _ in range(iterations):
        from funcat.func import MovingAverageSeries
        result = MovingAverageSeries(series, 20)
    elapsed = time.time() - start

    avg_time = elapsed / iterations * 1000  # 毫秒
    print(f"平均耗时: {avg_time:.2f} ms")
    print(f"总耗时: {elapsed:.2f} 秒")
    print(f"吞吐量: {iterations/elapsed:.2f} ops/秒")

    return avg_time


def benchmark_ema(size=1000, iterations=100):
    """测试EMA性能"""
    print(f"\n{'='*60}")
    print(f"测试 EMA 函数 (数据量: {size}, 迭代: {iterations})")
    print(f"{'='*60}")

    # 生成随机数据
    data = np.random.rand(size)
    series = NumericSeries(data)

    # 测试
    start = time.time()
    for _ in range(iterations):
        from funcat.func import ExponentialMovingAverageSeries
        result = ExponentialMovingAverageSeries(series, 12)
    elapsed = time.time() - start

    avg_time = elapsed / iterations * 1000  # 毫秒
    print(f"平均耗时: {avg_time:.2f} ms")
    print(f"总耗时: {elapsed:.2f} 秒")
    print(f"吞吐量: {iterations/elapsed:.2f} ops/秒")

    return avg_time


def benchmark_macd(size=1000, iterations=50):
    """测试MACD性能"""
    print(f"\n{'='*60}")
    print(f"测试 MACD 指标 (数据量: {size}, 迭代: {iterations})")
    print(f"{'='*60}")

    # 生成随机数据
    data = np.random.rand(size) * 100 + 10
    series = NumericSeries(data)

    # 测试
    start = time.time()
    for _ in range(iterations):
        from funcat.indicators import MACD
        result = MACD(12, 26, 9)
    elapsed = time.time() - start

    avg_time = elapsed / iterations * 1000  # 毫秒
    print(f"平均耗时: {avg_time:.2f} ms")
    print(f"总耗时: {elapsed:.2f} 秒")
    print(f"吞吐量: {iterations/elapsed:.2f} ops/秒")

    return avg_time


def main():
    print("=" * 60)
    print("Funcat Python 性能基准测试")
    print("=" * 60)
    print(f"NumPy版本: {np.__version__}")
    print(f"测试时间: {time.strftime('%Y-%m-%d %H:%M:%S')}")

    results = {}

    # 测试不同规模的数据
    sizes = [100, 500, 1000, 5000]

    for size in sizes:
        print(f"\n\n{'#'*60}")
        print(f"# 数据规模: {size} 个数据点")
        print(f"{'#'*60}")

        results[f'SMA_{size}'] = benchmark_sma(size, 100)
        results[f'COUNT_{size}'] = benchmark_count(size, 100)
        results[f'MA_{size}'] = benchmark_ma(size, 100)
        results[f'EMA_{size}'] = benchmark_ema(size, 100)

        if size <= 1000:  # MACD较慢，只测试小规模
            results[f'MACD_{size}'] = benchmark_macd(size, 50)

    # 汇总报告
    print("\n\n" + "=" * 60)
    print("性能汇总报告")
    print("=" * 60)
    print(f"{'操作':<20} {'平均耗时 (ms)':<20}")
    print("-" * 60)
    for key, value in sorted(results.items()):
        print(f"{key:<20} {value:<20.2f}")

    # 保存结果
    import json
    with open('benchmark_results_python.json', 'w') as f:
        json.dump(results, f, indent=2)

    print("\n结果已保存到: benchmark_results_python.json")


if __name__ == '__main__':
    main()
