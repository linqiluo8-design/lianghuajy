package indicators

import (
	"math"

	"github.com/funcat/funcat-go/pkg/series"
)

// MA 简单移动平均线
func MA(s *series.NumericSeries, period int) *series.NumericSeries {
	data := s.Values()
	if len(data) < period {
		return series.NewNumericSeries([]float64{})
	}

	result := make([]float64, len(data)-period+1)
	sum := 0.0

	// 初始化第一个窗口
	for i := 0; i < period; i++ {
		sum += data[i]
	}
	result[0] = sum / float64(period)

	// 滑动窗口计算
	for i := period; i < len(data); i++ {
		sum = sum - data[i-period] + data[i]
		result[i-period+1] = sum / float64(period)
	}

	return series.NewNumericSeries(result)
}

// EMA 指数移动平均线
func EMA(s *series.NumericSeries, period int) *series.NumericSeries {
	data := s.Values()
	if len(data) == 0 {
		return series.NewNumericSeries([]float64{})
	}

	alpha := 2.0 / float64(period+1)
	result := make([]float64, len(data))
	result[0] = data[0]

	for i := 1; i < len(data); i++ {
		result[i] = alpha*data[i] + (1-alpha)*result[i-1]
	}

	return series.NewNumericSeries(result)
}

// SMA 同花顺专用SMA (加权移动平均)
func SMA(s *series.NumericSeries, n int, m int) *series.NumericSeries {
	data := s.Values()
	if len(data) == 0 {
		return series.NewNumericSeries([]float64{})
	}

	alpha := float64(m) / float64(n)
	result := make([]float64, len(data))
	result[0] = data[0]

	for i := 1; i < len(data); i++ {
		result[i] = alpha*data[i] + (1-alpha)*result[i-1]
	}

	return series.NewNumericSeries(result)
}

// WMA 加权移动平均线
func WMA(s *series.NumericSeries, period int) *series.NumericSeries {
	data := s.Values()
	if len(data) < period {
		return series.NewNumericSeries([]float64{})
	}

	result := make([]float64, len(data)-period+1)
	weights := float64(period * (period + 1) / 2)

	for i := 0; i <= len(data)-period; i++ {
		sum := 0.0
		for j := 0; j < period; j++ {
			sum += data[i+j] * float64(j+1)
		}
		result[i] = sum / weights
	}

	return series.NewNumericSeries(result)
}

// SUM 求和
func SUM(s *series.NumericSeries, period int) *series.NumericSeries {
	data := s.Values()
	if len(data) < period {
		return series.NewNumericSeries([]float64{})
	}

	result := make([]float64, len(data)-period+1)
	sum := 0.0

	// 初始化第一个窗口
	for i := 0; i < period; i++ {
		sum += data[i]
	}
	result[0] = sum

	// 滑动窗口计算
	for i := period; i < len(data); i++ {
		sum = sum - data[i-period] + data[i]
		result[i-period+1] = sum
	}

	return series.NewNumericSeries(result)
}

// STD 标准差
func STD(s *series.NumericSeries, period int) *series.NumericSeries {
	data := s.Values()
	if len(data) < period {
		return series.NewNumericSeries([]float64{})
	}

	result := make([]float64, len(data)-period+1)

	for i := 0; i <= len(data)-period; i++ {
		window := data[i : i+period]
		mean := 0.0
		for _, v := range window {
			mean += v
		}
		mean /= float64(period)

		variance := 0.0
		for _, v := range window {
			diff := v - mean
			variance += diff * diff
		}
		variance /= float64(period)

		result[i] = math.Sqrt(variance)
	}

	return series.NewNumericSeries(result)
}

// HHV 最高价
func HHV(s *series.NumericSeries, period int) *series.NumericSeries {
	data := s.Values()
	if len(data) < period {
		return series.NewNumericSeries([]float64{})
	}

	result := make([]float64, len(data)-period+1)

	for i := 0; i <= len(data)-period; i++ {
		max := data[i]
		for j := i; j < i+period; j++ {
			if data[j] > max {
				max = data[j]
			}
		}
		result[i] = max
	}

	return series.NewNumericSeries(result)
}

// LLV 最低价
func LLV(s *series.NumericSeries, period int) *series.NumericSeries {
	data := s.Values()
	if len(data) < period {
		return series.NewNumericSeries([]float64{})
	}

	result := make([]float64, len(data)-period+1)

	for i := 0; i <= len(data)-period; i++ {
		min := data[i]
		for j := i; j < i+period; j++ {
			if data[j] < min {
				min = data[j]
			}
		}
		result[i] = min
	}

	return series.NewNumericSeries(result)
}

// ABS 绝对值
func ABS(s *series.NumericSeries) *series.NumericSeries {
	data := s.Values()
	result := make([]float64, len(data))

	for i, v := range data {
		result[i] = math.Abs(v)
	}

	return series.NewNumericSeries(result)
}

// MAX 两个序列取最大值
func MAX(s1, s2 *series.NumericSeries) *series.NumericSeries {
	data1 := s1.Values()
	data2 := s2.Values()
	minLen := len(data1)
	if len(data2) < minLen {
		minLen = len(data2)
	}

	result := make([]float64, minLen)
	for i := 0; i < minLen; i++ {
		idx1 := len(data1) - minLen + i
		idx2 := len(data2) - minLen + i
		result[i] = math.Max(data1[idx1], data2[idx2])
	}

	return series.NewNumericSeries(result)
}

// MIN 两个序列取最小值
func MIN(s1, s2 *series.NumericSeries) *series.NumericSeries {
	data1 := s1.Values()
	data2 := s2.Values()
	minLen := len(data1)
	if len(data2) < minLen {
		minLen = len(data2)
	}

	result := make([]float64, minLen)
	for i := 0; i < minLen; i++ {
		idx1 := len(data1) - minLen + i
		idx2 := len(data2) - minLen + i
		result[i] = math.Min(data1[idx1], data2[idx2])
	}

	return series.NewNumericSeries(result)
}

// COUNT 统计n日内满足条件的天数
func COUNT(cond *series.BoolSeries, period int) *series.NumericSeries {
	data := cond.Values()
	if len(data) < period {
		return series.NewNumericSeries([]float64{})
	}

	result := make([]float64, len(data)-period+1)

	for i := 0; i <= len(data)-period; i++ {
		count := 0
		for j := i; j < i+period; j++ {
			if data[j] {
				count++
			}
		}
		result[i] = float64(count)
	}

	return series.NewNumericSeries(result)
}

// EVERY 判断n日内是否每天都满足条件
func EVERY(cond *series.BoolSeries, period int) *series.BoolSeries {
	data := cond.Values()
	if len(data) < period {
		return series.NewBoolSeries([]bool{})
	}

	result := make([]bool, len(data)-period+1)

	for i := 0; i <= len(data)-period; i++ {
		every := true
		for j := i; j < i+period; j++ {
			if !data[j] {
				every = false
				break
			}
		}
		result[i] = every
	}

	return series.NewBoolSeries(result)
}

// CROSS 金叉判断
func CROSS(s1, s2 *series.NumericSeries) *series.BoolSeries {
	data1 := s1.Values()
	data2 := s2.Values()
	minLen := len(data1)
	if len(data2) < minLen {
		minLen = len(data2)
	}

	if minLen < 2 {
		return series.NewBoolSeries([]bool{})
	}

	result := make([]bool, minLen)
	result[0] = false

	for i := 1; i < minLen; i++ {
		idx1 := len(data1) - minLen + i
		idx2 := len(data2) - minLen + i
		prevIdx1 := len(data1) - minLen + i - 1
		prevIdx2 := len(data2) - minLen + i - 1

		// 当前值 s1 > s2 且 前一个值 s1 <= s2
		result[i] = data1[idx1] > data2[idx2] && data1[prevIdx1] <= data2[prevIdx2]
	}

	return series.NewBoolSeries(result)
}

// IF 条件选择
func IF(condition *series.BoolSeries, trueVal, falseVal *series.NumericSeries) *series.NumericSeries {
	condData := condition.Values()
	trueData := trueVal.Values()
	falseData := falseVal.Values()

	minLen := len(condData)
	if len(trueData) < minLen {
		minLen = len(trueData)
	}
	if len(falseData) < minLen {
		minLen = len(falseData)
	}

	result := make([]float64, minLen)
	for i := 0; i < minLen; i++ {
		condIdx := len(condData) - minLen + i
		trueIdx := len(trueData) - minLen + i
		falseIdx := len(falseData) - minLen + i

		if condData[condIdx] {
			result[i] = trueData[trueIdx]
		} else {
			result[i] = falseData[falseIdx]
		}
	}

	return series.NewNumericSeries(result)
}

// REF 获取n天前的数据
func REF(s *series.NumericSeries, n int) *series.NumericSeries {
	return s.Ref(n)
}
