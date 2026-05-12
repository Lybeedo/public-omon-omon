//+------------------------------------------------------------------+
//|                                        PriceChannel.mqh         |
//+------------------------------------------------------------------+
//| Price Channel Detection Library v1.00 - MQL4 VERSION             |
//|                                                                  |
//| DETEKSI CHANNEL TYPES:                                          |
//|   [1] DONCHIAN    - Highest High / Lowest Low (N periods)        |
//|   [2] LINEAR REG  - Linear regression channel (std deviation)    |
//|   [3] PITCHFORK   - Andrew's Pitchfork (median line + rays)      |
//|   [4] BOLLINGER    - MA +/- std deviation                       |
//|   [5] BAND CHANNEL - High band / Low band (custom bands)        |
//|                                                                  |
//| DETEKSI BREAKOUT:                                               |
//|   - Bullish breakout: harga menutup di atas upper channel       |
//|   - Bearish breakout: harga menutup di bawah lower channel     |
//|   - Trend strength: % distance dari mid line ke harga          |
//|                                                                  |
//| PAKAI: Copy ke MQL4/Include/ lalu #include <PriceChannel.mqh>    |
//+------------------------------------------------------------------+
#property copyright   "Price Channel Library v1.0 - MQL4"
#property strict

#ifndef PRICECHANNEL_MQH
#define PRICECHANNEL_MQH

//+------------------------------------------------------------------+
//| Channel Types                                                    |
//+------------------------------------------------------------------+
enum ENUM_CHANNEL_TYPE
{
    CHANNEL_DONCHIAN     = 0,
    CHANNEL_LINEAR_REG   = 1,
    CHANNEL_PITCHFORK    = 2,
    CHANNEL_BOLLINGER    = 3,
    CHANNEL_RAFF         = 4
};

//+------------------------------------------------------------------+
//| Breakout Direction                                               |
//+------------------------------------------------------------------+
enum ENUM_CHANNEL_BREAKOUT
{
    BREAKOUT_NONE      = 0,
    BREAKOUT_BULLISH   = 1,
    BREAKOUT_BEARISH   = 2
};

//+------------------------------------------------------------------+
//| Channel Parameters                                               |
//+------------------------------------------------------------------+
struct SChannelParams
{
    int       type;       // ENUM_CHANNEL_TYPE
    int       period;     // N bars
    double    deviation;  // std dev multiplier
    double    raffScale;  // Raff scale (0.5 = 50%)
    
    SChannelParams()
    {
        type      = 0;
        period    = 20;
        deviation = 2.0;
        raffScale = 1.0;
    }
};

//+------------------------------------------------------------------+
//| Channel Result                                                   |
//+------------------------------------------------------------------+
struct SChannelLevel
{
    double   upper;
    double   middle;
    double   lower;
    double   width;
};

struct SChannelSignal
{
    int       breakout;     // ENUM_CHANNEL_BREAKOUT
    datetime  time;
    double    price;
    double    targetDist;
    double    widthAtBreak;
    int       barIndex;
    bool      isConfirmed;
    double    strength;
};

//+------------------------------------------------------------------+
//| CPriceChannel Class                                              |
//+------------------------------------------------------------------+
class CPriceChannel
{
private:
    SChannelParams  m_params;
    SChannelLevel   m_currentLevels;
    SChannelSignal  m_lastSignal;
    
    double          m_highs[];
    double          m_lows[];
    double          m_closes[];
    double          m_opens[];
    datetime        m_times[];
    
    int             m_maxBars;
    int             m_loadedBars;
    datetime        m_lastLoadTime;
    string          m_lastSymbol;
    int             m_lastTf;

    bool            loadData(int bars);
    SChannelLevel   calcDonchian(int shift, int count);
    SChannelLevel   calcLinearReg(int shift, int count);
    SChannelLevel   calcPitchfork(int shift, int count);
    SChannelLevel   calcBollinger(int shift, int count);
    SChannelLevel   calcRaff(int shift, int count);
    double          calcStdDev(double &arr[], int count);
    double          linearReg(double &y[], int count, double &slope);

public:
    CPriceChannel();
    void            Init(int type, int period, double deviation);
    void            InitEx(SChannelParams params);
    SChannelLevel   GetLevels(int shift);
    SChannelSignal  DetectBreakout(int shift);
    int             ScanBreakouts(int maxBars);
    double          GetChannelWidth(int shift);
    double          GetTrendStrength(int shift);
    int             GetType() { return m_params.type; }
    int             GetPeriod() { return m_params.period; }
    void            SetPeriod(int period) { m_params.period = period; }
    void            SetDeviation(double dev) { m_params.deviation = dev; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPriceChannel::CPriceChannel()
{
    m_maxBars    = 1000;
    m_loadedBars = 0;
    m_lastLoadTime = 0;
    m_lastSymbol = "";
    m_lastTf = 0;
    ArraySetAsSeries(m_highs, true);
    ArraySetAsSeries(m_lows, true);
    ArraySetAsSeries(m_closes, true);
    ArraySetAsSeries(m_opens, true);
    ArraySetAsSeries(m_times, true);
}

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
void CPriceChannel::Init(int type, int period, double deviation)
{
    m_params.type      = type;
    m_params.period    = period;
    m_params.deviation = deviation;
}

void CPriceChannel::InitEx(SChannelParams params)
{
    m_params = params;
}

//+------------------------------------------------------------------+
//| Load price data (MQL4 style - no MqlRates)                       |
//+------------------------------------------------------------------+
bool CPriceChannel::loadData(int bars)
{
    string sym = Symbol();
    int    tf  = Period();
    
    // Only reload if needed (cache)
    if(bars <= m_loadedBars && sym == m_lastSymbol && tf == m_lastTf)
        return true;
    
    if(bars > m_maxBars) bars = m_maxBars;
    
    ArrayResize(m_highs, bars);
    ArrayResize(m_lows, bars);
    ArrayResize(m_closes, bars);
    ArrayResize(m_opens, bars);
    ArrayResize(m_times, bars);
    
    // MQL4: CopyRates returns count
    int cnt;
    cnt = CopyHigh(sym, tf, 0, bars, m_highs);
    if(cnt <= 0) return false;
    cnt = CopyLow(sym, tf, 0, bars, m_lows);
    if(cnt <= 0) return false;
    cnt = CopyClose(sym, tf, 0, bars, m_closes);
    if(cnt <= 0) return false;
    cnt = CopyOpen(sym, tf, 0, bars, m_opens);
    if(cnt <= 0) return false;
    cnt = CopyTime(sym, tf, 0, bars, m_times);
    if(cnt <= 0) return false;
    
    m_loadedBars   = bars;
    m_lastLoadTime = TimeCurrent();
    m_lastSymbol   = sym;
    m_lastTf       = tf;
    
    return true;
}

//+------------------------------------------------------------------+
//| Get channel levels                                               |
//+------------------------------------------------------------------+
SChannelLevel CPriceChannel::GetLevels(int shift)
{
    SChannelLevel result;
    result.upper = 0;
    result.middle = 0;
    result.lower = 0;
    result.width = 0;

    int barsNeeded = m_params.period + shift + 10;
    if(!loadData(barsNeeded)) return result;

    if(m_params.type == 0)
        result = calcDonchian(shift, m_params.period);
    else if(m_params.type == 1)
        result = calcLinearReg(shift, m_params.period);
    else if(m_params.type == 2)
        result = calcPitchfork(shift, m_params.period);
    else if(m_params.type == 3)
        result = calcBollinger(shift, m_params.period);
    else if(m_params.type == 4)
        result = calcRaff(shift, m_params.period);

    m_currentLevels = result;
    return result;
}

//+------------------------------------------------------------------+
//| Detect breakout                                                  |
//+------------------------------------------------------------------+
SChannelSignal CPriceChannel::DetectBreakout(int shift)
{
    SChannelSignal signal;
    signal.breakout = 0;
    signal.isConfirmed = false;
    signal.strength = 0;
    signal.price = 0;
    signal.targetDist = 0;
    signal.widthAtBreak = 0;
    signal.barIndex = shift;

    // Get levels for previous bar (shift+1)
    SChannelLevel levels = GetLevels(shift + 1);
    if(levels.upper == 0 && levels.lower == 0) return signal;

    // Load data including current bar
    int barsNeeded = shift + 2;
    if(!loadData(barsNeeded)) return signal;

    double closePrice = m_closes[0];
    double upper = levels.upper;
    double lower = levels.lower;
    double middle = levels.middle;
    double width = levels.width;

    m_currentLevels = levels;

    if(closePrice > upper)
    {
        signal.breakout     = 1; // BREAKOUT_BULLISH
        signal.isConfirmed  = true;
        signal.price        = closePrice;
        signal.widthAtBreak = width;
        signal.barIndex     = shift;
        signal.time         = m_times[0];
        signal.targetDist   = width;
        
        if(width > 0)
            signal.strength = MathMin(MathAbs(closePrice - middle) / (width * 0.5), 1.0);
    }
    else if(closePrice < lower)
    {
        signal.breakout     = 2; // BREAKOUT_BEARISH
        signal.isConfirmed  = true;
        signal.price        = closePrice;
        signal.widthAtBreak = width;
        signal.barIndex     = shift;
        signal.time         = m_times[0];
        signal.targetDist   = width;
        
        if(width > 0)
            signal.strength = MathMin(MathAbs(closePrice - middle) / (width * 0.5), 1.0);
    }
    
    m_lastSignal = signal;
    return signal;
}

//+------------------------------------------------------------------+
//| Scan all breakouts                                               |
//+------------------------------------------------------------------+
int CPriceChannel::ScanBreakouts(int maxBars)
{
    int count = 0;
    for(int i = 0; i < maxBars; i++)
    {
        SChannelSignal s = DetectBreakout(i);
        if(s.breakout != 0)
            count++;
    }
    return count;
}

//+------------------------------------------------------------------+
//| Get channel width                                                |
//+------------------------------------------------------------------+
double CPriceChannel::GetChannelWidth(int shift)
{
    SChannelLevel lv = GetLevels(shift);
    return lv.width;
}

//+------------------------------------------------------------------+
//| Get trend strength                                               |
//+------------------------------------------------------------------+
double CPriceChannel::GetTrendStrength(int shift)
{
    SChannelLevel lv = GetLevels(shift);
    if(lv.width == 0) return 0;
    
    if(!loadData(shift + 2)) return 0;
    double closePrice = m_closes[0];
    
    double distFromMid = MathAbs(closePrice - lv.middle);
    return MathMin(distFromMid / (lv.width * 0.5), 1.0);
}

//+------------------------------------------------------------------+
//| Donchian Channel                                                  |
//+------------------------------------------------------------------+
SChannelLevel CPriceChannel::calcDonchian(int shift, int count)
{
    SChannelLevel result;
    
    if(!loadData(count + shift + 5)) return result;
    
    double hi = m_highs[shift];
    double lo = m_lows[shift];
    
    for(int i = shift; i < shift + count; i++)
    {
        if(i >= ArraySize(m_highs)) break;
        if(m_highs[i] > hi) hi = m_highs[i];
        if(m_lows[i] < lo) lo = m_lows[i];
    }
    
    result.upper  = hi;
    result.lower  = lo;
    result.middle = (hi + lo) * 0.5;
    result.width  = hi - lo;
    
    return result;
}

//+------------------------------------------------------------------+
//| Linear Regression Channel                                         |
//+------------------------------------------------------------------+
SChannelLevel CPriceChannel::calcLinearReg(int shift, int count)
{
    SChannelLevel result;
    
    if(!loadData(count + shift + 5)) return result;
    
    double midArr[];
    ArrayResize(midArr, count);
    for(int i = 0; i < count; i++)
        midArr[i] = (m_highs[shift + i] + m_lows[shift + i]) * 0.5;
    
    double slope;
    double intercept = linearReg(midArr, count, slope);
    
    // Mid line at last bar
    double midEnd = intercept + slope * (count - 1);
    
    // Residuals
    double residuals[];
    ArrayResize(residuals, count);
    for(int i = 0; i < count; i++)
    {
        double expected = intercept + slope * i;
        residuals[i] = midArr[i] - expected;
    }
    
    double stdDev = calcStdDev(residuals, count);
    
    result.upper  = midEnd + m_params.deviation * stdDev;
    result.lower  = midEnd - m_params.deviation * stdDev;
    result.middle = midEnd;
    result.width  = result.upper - result.lower;
    
    return result;
}

//+------------------------------------------------------------------+
//| Andrew's Pitchfork                                                |
//+------------------------------------------------------------------+
SChannelLevel CPriceChannel::calcPitchfork(int shift, int count)
{
    SChannelLevel result;
    
    if(count < 3 || !loadData(count + shift + 5)) return result;
    
    // Find 3 pivot points: highest high, lowest low, highest high #2
    double maxHi = m_highs[shift];
    double minLo = m_lows[shift];
    int idxMaxHi = shift;
    int idxMinLo = shift;
    
    for(int i = shift; i < shift + count; i++)
    {
        if(m_highs[i] > maxHi) { maxHi = m_highs[i]; idxMaxHi = i; }
        if(m_lows[i] < minLo) { minLo = m_lows[i]; idxMinLo = i; }
    }
    
    // Second highest high
    double maxHi2 = 0; int idxMaxHi2 = shift;
    for(int i = shift; i < shift + count; i++)
    {
        if(i != idxMaxHi && m_highs[i] > maxHi2) { maxHi2 = m_highs[i]; idxMaxHi2 = i; }
    }
    if(maxHi2 == 0) maxHi2 = maxHi;
    if(idxMaxHi2 == shift && idxMaxHi != shift) { idxMaxHi2 = shift + 1; maxHi2 = m_highs[shift + 1]; }
    
    // Sort: first=oldest, last=newest (already time-sorted via loadData)
    double pivots[3];
    int pivotIdx[3];
    
    // Sort by bar index (ascending = chronological)
    // Find lowest (median pivot)
    if(idxMinLo < idxMaxHi && idxMinLo < idxMaxHi2)
    {
        pivots[0] = minLo; pivotIdx[0] = idxMinLo;
        if(idxMaxHi < idxMaxHi2)
        {
            pivots[1] = maxHi;  pivotIdx[1] = idxMaxHi;
            pivots[2] = maxHi2; pivotIdx[2] = idxMaxHi2;
        }
        else
        {
            pivots[1] = maxHi2; pivotIdx[1] = idxMaxHi2;
            pivots[2] = maxHi;  pivotIdx[2] = idxMaxHi;
        }
    }
    else
    {
        // Median is one of the highs - pick lowest price as median
        int minIdx = idxMaxHi;
        double minPrice = maxHi;
        if(maxHi2 < minPrice) { minPrice = maxHi2; minIdx = idxMaxHi2; }
        
        pivots[0] = minPrice; pivotIdx[0] = minIdx;
        
        // Other two
        if(idxMaxHi == minIdx)
        {
            pivots[1] = maxHi2; pivotIdx[1] = idxMaxHi2;
            pivots[2] = minLo;  pivotIdx[2] = idxMinLo;
        }
        else if(idxMaxHi2 == minIdx)
        {
            pivots[1] = maxHi;  pivotIdx[1] = idxMaxHi;
            pivots[2] = minLo;  pivotIdx[2] = idxMinLo;
        }
        else
        {
            pivots[1] = maxHi;   pivotIdx[1] = idxMaxHi;
            pivots[2] = maxHi2; pivotIdx[2] = idxMaxHi2;
        }
    }
    
    // Median line: from first to last pivot
    double nRange = (double)(pivotIdx[2] - pivotIdx[0]);
    if(nRange < 1) nRange = 1;
    
    double medianSlope = (pivots[2] - pivots[0]) / nRange;
    double medianIntercept = pivots[0] - medianSlope * (double)pivotIdx[0];
    
    // Current bar = last of range
    int lastBar = shift + count - 1;
    double medianNow = medianIntercept + medianSlope * (double)lastBar;
    
    // Upper/lower: parallel rays passing through median pivot (pivot #1)
    double parallelOffset = pivots[1] - (medianIntercept + medianSlope * (double)pivotIdx[1]);
    
    result.upper  = medianNow + parallelOffset;
    result.lower  = medianNow - parallelOffset;
    result.middle = medianNow;
    result.width  = result.upper - result.lower;
    
    return result;
}

//+------------------------------------------------------------------+
//| Bollinger Bands                                                  |
//+------------------------------------------------------------------+
SChannelLevel CPriceChannel::calcBollinger(int shift, int count)
{
    SChannelLevel result;
    
    if(!loadData(count + shift + 5)) return result;
    
    // MA
    double ma = 0;
    for(int i = shift; i < shift + count; i++)
        ma += m_closes[i];
    ma /= (double)count;
    
    // Std dev
    double stdDev = 0;
    for(int i = shift; i < shift + count; i++)
    {
        double d = m_closes[i] - ma;
        stdDev += d * d;
    }
    stdDev = MathSqrt(stdDev / (double)count);
    
    result.upper  = ma + m_params.deviation * stdDev;
    result.lower  = ma - m_params.deviation * stdDev;
    result.middle = ma;
    result.width  = result.upper - result.lower;
    
    return result;
}

//+------------------------------------------------------------------+
//| Raff Regression Channel                                           |
//+------------------------------------------------------------------+
SChannelLevel CPriceChannel::calcRaff(int shift, int count)
{
    SChannelLevel result;
    
    if(!loadData(count + shift + 5)) return result;
    
    // Highest high dan lowest low
    double maxHi = m_highs[shift];
    double minLo = m_lows[shift];
    
    for(int i = shift; i < shift + count; i++)
    {
        if(m_highs[i] > maxHi) maxHi = m_highs[i];
        if(m_lows[i] < minLo) minLo = m_lows[i];
    }
    
    // Midpoint regression
    double midArr[];
    ArrayResize(midArr, count);
    for(int i = 0; i < count; i++)
        midArr[i] = (m_highs[shift + i] + m_lows[shift + i]) * 0.5;
    
    double slope;
    double intercept = linearReg(midArr, count, slope);
    double middleNow = intercept + slope * (count - 1);
    
    double halfWidth = (maxHi - minLo) * 0.5 * m_params.raffScale;
    
    result.upper  = middleNow + halfWidth;
    result.lower  = middleNow - halfWidth;
    result.middle = middleNow;
    result.width  = result.upper - result.lower;
    
    return result;
}

//+------------------------------------------------------------------+
//| Linear Regression helper                                          |
//+------------------------------------------------------------------+
double CPriceChannel::linearReg(double &y[], int count, double &slope)
{
    if(count <= 1) { slope = 0; return y[0]; }
    
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for(int i = 0; i < count; i++)
    {
        sumX  += i;
        sumY  += y[i];
        sumXY += i * y[i];
        sumX2 += i * i;
    }
    
    double n = (double)count;
    double denom = n * sumX2 - sumX * sumX;
    if(MathAbs(denom) < 0.0000001) { slope = 0; return sumY / n; }
    
    slope = (n * sumXY - sumX * sumY) / denom;
    double intercept = (sumY - slope * sumX) / n;
    
    return intercept;
}

//+------------------------------------------------------------------+
//| Standard Deviation helper                                         |
//+------------------------------------------------------------------+
double CPriceChannel::calcStdDev(double &arr[], int count)
{
    if(count <= 1) return 0;
    
    double mean = 0;
    for(int i = 0; i < count; i++)
        mean += arr[i];
    mean /= (double)count;
    
    double sumSq = 0;
    for(int i = 0; i < count; i++)
    {
        double d = arr[i] - mean;
        sumSq += d * d;
    }
    
    return MathSqrt(sumSq / (double)count);
}

//+------------------------------------------------------------------+
#endif // PRICECHANNEL_MQH
//+------------------------------------------------------------------+