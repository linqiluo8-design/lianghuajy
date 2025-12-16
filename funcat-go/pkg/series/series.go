package series

import (
	"fmt"
	"math"
)

// Series 时间序列接口
type Series interface {
	Value() float64        // 获取最新值
	Values() []float64     // 获取所有值
	Len() int              // 序列长度
	At(i int) float64      // 获取指定位置的值
}

// NumericSeries 数值时间序列
type NumericSeries struct {
	data []float64
}

// NewNumericSeries 创建数值序列
func NewNumericSeries(data []float64) *NumericSeries {
	return &NumericSeries{data: data}
}

// Value 返回最新值
func (s *NumericSeries) Value() float64 {
	if len(s.data) == 0 {
		return math.NaN()
	}
	return s.data[len(s.data)-1]
}

// Values 返回所有值
func (s *NumericSeries) Values() []float64 {
	return s.data
}

// Len 返回序列长度
func (s *NumericSeries) Len() int {
	return len(s.data)
}

// At 返回指定位置的值
func (s *NumericSeries) At(i int) float64 {
	if i < 0 || i >= len(s.data) {
		return math.NaN()
	}
	return s.data[i]
}

// Ref 获取n天前的数据
func (s *NumericSeries) Ref(n int) *NumericSeries {
	if n >= len(s.data) {
		return NewNumericSeries([]float64{})
	}
	return NewNumericSeries(s.data[:len(s.data)-n])
}

// GT 大于运算符
func (s *NumericSeries) GT(other interface{}) *BoolSeries {
	switch v := other.(type) {
	case *NumericSeries:
		return s.compareWith(v, func(a, b float64) bool { return a > b })
	case float64:
		return s.compareValue(v, func(a, b float64) bool { return a > b })
	default:
		panic(fmt.Sprintf("unsupported type: %T", other))
	}
}

// LT 小于运算符
func (s *NumericSeries) LT(other interface{}) *BoolSeries {
	switch v := other.(type) {
	case *NumericSeries:
		return s.compareWith(v, func(a, b float64) bool { return a < b })
	case float64:
		return s.compareValue(v, func(a, b float64) bool { return a < b })
	default:
		panic(fmt.Sprintf("unsupported type: %T", other))
	}
}

// Add 加法运算
func (s *NumericSeries) Add(other interface{}) *NumericSeries {
	switch v := other.(type) {
	case *NumericSeries:
		return s.operateWith(v, func(a, b float64) float64 { return a + b })
	case float64:
		return s.operateValue(v, func(a, b float64) float64 { return a + b })
	default:
		panic(fmt.Sprintf("unsupported type: %T", other))
	}
}

// Sub 减法运算
func (s *NumericSeries) Sub(other interface{}) *NumericSeries {
	switch v := other.(type) {
	case *NumericSeries:
		return s.operateWith(v, func(a, b float64) float64 { return a - b })
	case float64:
		return s.operateValue(v, func(a, b float64) float64 { return a - b })
	default:
		panic(fmt.Sprintf("unsupported type: %T", other))
	}
}

// Mul 乘法运算
func (s *NumericSeries) Mul(other interface{}) *NumericSeries {
	switch v := other.(type) {
	case *NumericSeries:
		return s.operateWith(v, func(a, b float64) float64 { return a * b })
	case float64:
		return s.operateValue(v, func(a, b float64) float64 { return a * b })
	default:
		panic(fmt.Sprintf("unsupported type: %T", other))
	}
}

// Div 除法运算
func (s *NumericSeries) Div(other interface{}) *NumericSeries {
	switch v := other.(type) {
	case *NumericSeries:
		return s.operateWith(v, func(a, b float64) float64 { return a / b })
	case float64:
		return s.operateValue(v, func(a, b float64) float64 { return a / b })
	default:
		panic(fmt.Sprintf("unsupported type: %T", other))
	}
}

// 辅助函数：比较两个序列
func (s *NumericSeries) compareWith(other *NumericSeries, op func(float64, float64) bool) *BoolSeries {
	minLen := min(len(s.data), len(other.data))
	result := make([]bool, minLen)

	for i := 0; i < minLen; i++ {
		idx1 := len(s.data) - minLen + i
		idx2 := len(other.data) - minLen + i
		result[i] = op(s.data[idx1], other.data[idx2])
	}

	return NewBoolSeries(result)
}

// 辅助函数：与标量比较
func (s *NumericSeries) compareValue(value float64, op func(float64, float64) bool) *BoolSeries {
	result := make([]bool, len(s.data))
	for i, v := range s.data {
		result[i] = op(v, value)
	}
	return NewBoolSeries(result)
}

// 辅助函数：两个序列运算
func (s *NumericSeries) operateWith(other *NumericSeries, op func(float64, float64) float64) *NumericSeries {
	minLen := min(len(s.data), len(other.data))
	result := make([]float64, minLen)

	for i := 0; i < minLen; i++ {
		idx1 := len(s.data) - minLen + i
		idx2 := len(other.data) - minLen + i
		result[i] = op(s.data[idx1], other.data[idx2])
	}

	return NewNumericSeries(result)
}

// 辅助函数：与标量运算
func (s *NumericSeries) operateValue(value float64, op func(float64, float64) float64) *NumericSeries {
	result := make([]float64, len(s.data))
	for i, v := range s.data {
		result[i] = op(v, value)
	}
	return NewNumericSeries(result)
}

// BoolSeries 布尔时间序列
type BoolSeries struct {
	data []bool
}

// NewBoolSeries 创建布尔序列
func NewBoolSeries(data []bool) *BoolSeries {
	return &BoolSeries{data: data}
}

// Value 返回最新值
func (s *BoolSeries) Value() bool {
	if len(s.data) == 0 {
		return false
	}
	return s.data[len(s.data)-1]
}

// Values 返回所有值
func (s *BoolSeries) Values() []bool {
	return s.data
}

// Len 返回序列长度
func (s *BoolSeries) Len() int {
	return len(s.data)
}

// And 逻辑与运算
func (s *BoolSeries) And(other *BoolSeries) *BoolSeries {
	minLen := min(len(s.data), len(other.data))
	result := make([]bool, minLen)

	for i := 0; i < minLen; i++ {
		idx1 := len(s.data) - minLen + i
		idx2 := len(other.data) - minLen + i
		result[i] = s.data[idx1] && other.data[idx2]
	}

	return NewBoolSeries(result)
}

// Or 逻辑或运算
func (s *BoolSeries) Or(other *BoolSeries) *BoolSeries {
	minLen := min(len(s.data), len(other.data))
	result := make([]bool, minLen)

	for i := 0; i < minLen; i++ {
		idx1 := len(s.data) - minLen + i
		idx2 := len(other.data) - minLen + i
		result[i] = s.data[idx1] || other.data[idx2]
	}

	return NewBoolSeries(result)
}

// Not 逻辑非运算
func (s *BoolSeries) Not() *BoolSeries {
	result := make([]bool, len(s.data))
	for i, v := range s.data {
		result[i] = !v
	}
	return NewBoolSeries(result)
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
