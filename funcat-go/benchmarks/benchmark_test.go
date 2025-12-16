package benchmarks

import (
	"math/rand"
	"testing"

	"github.com/funcat/funcat-go/pkg/indicators"
	"github.com/funcat/funcat-go/pkg/series"
)

// generateRandomSeries 生成随机数据序列
func generateRandomSeries(size int) *series.NumericSeries {
	data := make([]float64, size)
	for i := 0; i < size; i++ {
		data[i] = rand.Float64()*100 + 10
	}
	return series.NewNumericSeries(data)
}

// generateRandomBoolSeries 生成随机布尔序列
func generateRandomBoolSeries(size int) *series.BoolSeries {
	data := make([]bool, size)
	for i := 0; i < size; i++ {
		data[i] = rand.Float64() > 0.5
	}
	return series.NewBoolSeries(data)
}

// BenchmarkMA 测试MA性能
func BenchmarkMA100(b *testing.B) {
	s := generateRandomSeries(100)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.MA(s, 20)
	}
}

func BenchmarkMA500(b *testing.B) {
	s := generateRandomSeries(500)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.MA(s, 20)
	}
}

func BenchmarkMA1000(b *testing.B) {
	s := generateRandomSeries(1000)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.MA(s, 20)
	}
}

func BenchmarkMA5000(b *testing.B) {
	s := generateRandomSeries(5000)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.MA(s, 20)
	}
}

// BenchmarkEMA 测试EMA性能
func BenchmarkEMA100(b *testing.B) {
	s := generateRandomSeries(100)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.EMA(s, 12)
	}
}

func BenchmarkEMA500(b *testing.B) {
	s := generateRandomSeries(500)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.EMA(s, 12)
	}
}

func BenchmarkEMA1000(b *testing.B) {
	s := generateRandomSeries(1000)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.EMA(s, 12)
	}
}

func BenchmarkEMA5000(b *testing.B) {
	s := generateRandomSeries(5000)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.EMA(s, 12)
	}
}

// BenchmarkSMA 测试SMA性能
func BenchmarkSMA100(b *testing.B) {
	s := generateRandomSeries(100)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.SMA(s, 20, 1)
	}
}

func BenchmarkSMA500(b *testing.B) {
	s := generateRandomSeries(500)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.SMA(s, 20, 1)
	}
}

func BenchmarkSMA1000(b *testing.B) {
	s := generateRandomSeries(1000)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.SMA(s, 20, 1)
	}
}

func BenchmarkSMA5000(b *testing.B) {
	s := generateRandomSeries(5000)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.SMA(s, 20, 1)
	}
}

// BenchmarkCOUNT 测试COUNT性能
func BenchmarkCOUNT100(b *testing.B) {
	s := generateRandomBoolSeries(100)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.COUNT(s, 10)
	}
}

func BenchmarkCOUNT500(b *testing.B) {
	s := generateRandomBoolSeries(500)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.COUNT(s, 10)
	}
}

func BenchmarkCOUNT1000(b *testing.B) {
	s := generateRandomBoolSeries(1000)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.COUNT(s, 10)
	}
}

func BenchmarkCOUNT5000(b *testing.B) {
	s := generateRandomBoolSeries(5000)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.COUNT(s, 10)
	}
}

// BenchmarkMACD 测试MACD性能
func BenchmarkMACD100(b *testing.B) {
	s := generateRandomSeries(100)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.MACD(s, 12, 26, 9)
	}
}

func BenchmarkMACD500(b *testing.B) {
	s := generateRandomSeries(500)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.MACD(s, 12, 26, 9)
	}
}

func BenchmarkMACD1000(b *testing.B) {
	s := generateRandomSeries(1000)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.MACD(s, 12, 26, 9)
	}
}

// BenchmarkKDJ 测试KDJ性能
func BenchmarkKDJ100(b *testing.B) {
	high := generateRandomSeries(100)
	low := generateRandomSeries(100)
	close := generateRandomSeries(100)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.KDJ(high, low, close, 9, 3, 3)
	}
}

func BenchmarkKDJ500(b *testing.B) {
	high := generateRandomSeries(500)
	low := generateRandomSeries(500)
	close := generateRandomSeries(500)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.KDJ(high, low, close, 9, 3, 3)
	}
}

func BenchmarkKDJ1000(b *testing.B) {
	high := generateRandomSeries(1000)
	low := generateRandomSeries(1000)
	close := generateRandomSeries(1000)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.KDJ(high, low, close, 9, 3, 3)
	}
}

// BenchmarkHHV 测试HHV性能
func BenchmarkHHV100(b *testing.B) {
	s := generateRandomSeries(100)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.HHV(s, 10)
	}
}

func BenchmarkHHV1000(b *testing.B) {
	s := generateRandomSeries(1000)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.HHV(s, 10)
	}
}

// BenchmarkLLV 测试LLV性能
func BenchmarkLLV100(b *testing.B) {
	s := generateRandomSeries(100)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.LLV(s, 10)
	}
}

func BenchmarkLLV1000(b *testing.B) {
	s := generateRandomSeries(1000)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.LLV(s, 10)
	}
}

// BenchmarkSTD 测试STD性能
func BenchmarkSTD100(b *testing.B) {
	s := generateRandomSeries(100)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.STD(s, 20)
	}
}

func BenchmarkSTD1000(b *testing.B) {
	s := generateRandomSeries(1000)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.STD(s, 20)
	}
}

// BenchmarkCROSS 测试CROSS性能
func BenchmarkCROSS100(b *testing.B) {
	s1 := generateRandomSeries(100)
	s2 := generateRandomSeries(100)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.CROSS(s1, s2)
	}
}

func BenchmarkCROSS1000(b *testing.B) {
	s1 := generateRandomSeries(1000)
	s2 := generateRandomSeries(1000)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		indicators.CROSS(s1, s2)
	}
}
