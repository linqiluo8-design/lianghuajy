package indicators

import (
	"github.com/funcat/funcat-go/pkg/series"
)

// MACD 指数平滑移动平均线
func MACD(close *series.NumericSeries, short, long, m int) (*series.NumericSeries, *series.NumericSeries, *series.NumericSeries) {
	emaShort := EMA(close, short)
	emaLong := EMA(close, long)
	diff := emaShort.Sub(emaLong)
	dea := EMA(diff, m)
	macd := diff.Sub(dea).Mul(2.0)

	return diff, dea, macd
}

// KDJ 随机指标
func KDJ(high, low, close *series.NumericSeries, n, m1, m2 int) (*series.NumericSeries, *series.NumericSeries, *series.NumericSeries) {
	// RSV = (CLOSE - LLV(LOW, N)) / (HHV(HIGH, N) - LLV(LOW, N)) * 100
	llvLow := LLV(low, n)
	hhvHigh := HHV(high, n)

	rsv := close.Sub(llvLow).Div(hhvHigh.Sub(llvLow)).Mul(100.0)

	// K = EMA(RSV, (M1 * 2 - 1))
	k := EMA(rsv, m1*2-1)

	// D = EMA(K, (M2 * 2 - 1))
	d := EMA(k, m2*2-1)

	// J = K * 3 - D * 2
	j := k.Mul(3.0).Sub(d.Mul(2.0))

	return k, d, j
}

// RSI 相对强弱指标
func RSI(close *series.NumericSeries, n1, n2, n3 int) (*series.NumericSeries, *series.NumericSeries, *series.NumericSeries) {
	lc := REF(close, 1)
	diff := close.Sub(lc)

	// 创建零序列用于MAX运算
	zeros := series.NewNumericSeries(make([]float64, close.Len()))

	// RSI1 = SMA(MAX(CLOSE - LC, 0), N1, 1) / SMA(ABS(CLOSE - LC), N1, 1) * 100
	rsi1Num := SMA(MAX(diff, zeros), n1, 1)
	rsi1Den := SMA(ABS(diff), n1, 1)
	rsi1 := rsi1Num.Div(rsi1Den).Mul(100.0)

	// RSI2
	rsi2Num := SMA(MAX(diff, zeros), n2, 1)
	rsi2Den := SMA(ABS(diff), n2, 1)
	rsi2 := rsi2Num.Div(rsi2Den).Mul(100.0)

	// RSI3
	rsi3Num := SMA(MAX(diff, zeros), n3, 1)
	rsi3Den := SMA(ABS(diff), n3, 1)
	rsi3 := rsi3Num.Div(rsi3Den).Mul(100.0)

	return rsi1, rsi2, rsi3
}

// BOLL 布林带
func BOLL(close *series.NumericSeries, n, p int) (*series.NumericSeries, *series.NumericSeries, *series.NumericSeries) {
	// MID = MA(CLOSE, N)
	mid := MA(close, n)

	// UPPER = MID + STD(CLOSE, N) * P
	std := STD(close, n)
	upper := mid.Add(std.Mul(float64(p)))

	// LOWER = MID - STD(CLOSE, N) * P
	lower := mid.Sub(std.Mul(float64(p)))

	return upper, mid, lower
}

// WR 威廉指标
func WR(high, low, close *series.NumericSeries, n, n1 int) (*series.NumericSeries, *series.NumericSeries) {
	// WR1 = (HHV(HIGH, N) - CLOSE) / (HHV(HIGH, N) - LLV(LOW, N)) * 100
	hhvHigh := HHV(high, n)
	llvLow := LLV(low, n)
	wr1 := hhvHigh.Sub(close).Div(hhvHigh.Sub(llvLow)).Mul(100.0)

	// WR2
	hhvHigh1 := HHV(high, n1)
	llvLow1 := LLV(low, n1)
	wr2 := hhvHigh1.Sub(close).Div(hhvHigh1.Sub(llvLow1)).Mul(100.0)

	return wr1, wr2
}

// BIAS 乖离率
func BIAS(close *series.NumericSeries, l1, l4, l5 int) (*series.NumericSeries, *series.NumericSeries, *series.NumericSeries) {
	// BIAS = (CLOSE - MA(CLOSE, L1)) / MA(CLOSE, L1) * 100
	ma1 := MA(close, l1)
	bias1 := close.Sub(ma1).Div(ma1).Mul(100.0)

	// BIAS2
	ma4 := MA(close, l4)
	bias2 := close.Sub(ma4).Div(ma4).Mul(100.0)

	// BIAS3
	ma5 := MA(close, l5)
	bias3 := close.Sub(ma5).Div(ma5).Mul(100.0)

	return bias1, bias2, bias3
}

// DMI 趋向指标
func DMI(high, low, close *series.NumericSeries, m1, m2 int) (*series.NumericSeries, *series.NumericSeries, *series.NumericSeries, *series.NumericSeries) {
	// TR = SUM(MAX(MAX(HIGH - LOW, ABS(HIGH - REF(CLOSE, 1))), ABS(LOW - REF(CLOSE, 1))), M1)
	refClose := REF(close, 1)
	tr1 := high.Sub(low)
	tr2 := ABS(high.Sub(refClose))
	tr3 := ABS(low.Sub(refClose))
	tr := SUM(MAX(MAX(tr1, tr2), tr3), m1)

	// HD = HIGH - REF(HIGH, 1)
	hd := high.Sub(REF(high, 1))

	// LD = REF(LOW, 1) - LOW
	ld := REF(low, 1).Sub(low)

	// 创建零序列
	zeros := series.NewNumericSeries(make([]float64, close.Len()))

	// DMP = SUM(IF((HD > 0) & (HD > LD), HD, 0), M1)
	condDMP := hd.GT(zeros).And(hd.GT(ld))
	dmp := SUM(IF(condDMP, hd, zeros), m1)

	// DMM = SUM(IF((LD > 0) & (LD > HD), LD, 0), M1)
	condDMM := ld.GT(zeros).And(ld.GT(hd))
	dmm := SUM(IF(condDMM, ld, zeros), m1)

	// DI1 = DMP * 100 / TR
	di1 := dmp.Mul(100.0).Div(tr)

	// DI2 = DMM * 100 / TR
	di2 := dmm.Mul(100.0).Div(tr)

	// ADX = MA(ABS(DI2 - DI1) / (DI1 + DI2) * 100, M2)
	adx := MA(ABS(di2.Sub(di1)).Div(di1.Add(di2)).Mul(100.0), m2)

	// ADXR = (ADX + REF(ADX, M2)) / 2
	adxr := adx.Add(REF(adx, m2)).Div(2.0)

	return di1, di2, adx, adxr
}

// VR 容量比率
func VR(close, volume *series.NumericSeries, m1 int) *series.NumericSeries {
	lc := REF(close, 1)
	zeros := series.NewNumericSeries(make([]float64, close.Len()))

	// VR = SUM(IF(CLOSE > LC, VOL, 0), M1) / SUM(IF(CLOSE <= LC, VOL, 0), M1) * 100
	upVol := SUM(IF(close.GT(lc), volume, zeros), m1)
	downVol := SUM(IF(close.GT(lc).Not(), volume, zeros), m1)
	vr := upVol.Div(downVol).Mul(100.0)

	return vr
}
