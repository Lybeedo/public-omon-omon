//+------------------------------------------------------------------+
//|                                        PriceChannel.mqh         |
//+------------------------------------------------------------------+
//| Price Channel Detection Library v1.00                            |
//|                                                                  |
//| DETEKSI CHANNEL TYPES:                                          |
//|   [1] DONCHIAN    - Highest High / Lowest Low (N periods)        |
//|   [2] LINEAR REG  - Linear regression channel (std deviation)    |
//|   [3] PITCHFORK   - Andrew's Pitchfork (median line + rays)      |
|   [4] BOLLINGER    - MA +/- std deviation                         |
//|                                                                  |
//| DETEKSI BREAKOUT:                                               |
//|   - Bullish breakout: harga menutup di atas upper channel         |
//|   - Bearish breakout: harga menutup di bawah lower channel       |
//|   - Trend strength: % distance dari mid line ke harga            |
//|                                                                  |
//| PAKAI: Copy ke MQL5/Include/ lalu #include <PriceChannel.mqh>    |
//+------------------------------------------------------------------+
#property copyright   "Price Channel Library v1.0"
#property strict

#ifndef PRICECHANNEL_MQH
#define PRICECHANNEL_MQH

//+------------------------------------------------------------------+
//| Channel Types                                                    |
//+------------------------------------------------------------------+
enum ENUM_CHANNEL_TYPE
{
    CHANNEL_DONCHIAN     = 0,   // Highest/Lowest N bars
    CHANNEL_LINEAR_REG   = 1,   // Linear regression + std dev
    CHANNEL_PITCHFORK    = 2,   // Andrew's pitchfork
    CHANNEL_BOLLINGER    = 3,   // MA +/- bands
    CHANNEL_RAFF        = 4    // Raff regression channel
};

//+------------------------------------------------------------------+
//| Channel Period                                                   |
//+------------------------------------------------------------------+
enum ENUM_CHANNEL_PERIOD
{
    PERIOD_CURRENT     = 0,     // Pakai timeframe chart aktif
    PERIOD_H1          = 1,
    PERIOD_H4          = 2,
    PERIOD_D1          = 3,
    PERIOD_W1          = 4,
    PERIOD_MN1         = 5
};

//+------------------------------------------------------------------+
//| Breakout Direction                                               |
//+------------------------------------------------------------------+
enum ENUM_CHANNEL_BREAKOUT
{
    BREAKOUT_NONE      = 0,
    BREAKOUT_BULLISH   = 1,     // Harga tembus upper channel
    BREAKOUT_BEARISH   = 2      // Harga tembus lower channel
};

//+------------------------------------------------------------------+
//| Channel Parameters (di-set via constructor atau Init)            |
//+------------------------------------------------------------------+
struct SChannelParams
{
    ENUM_CHANNEL_TYPE  type;        // Tipe channel
    int                period;      // Period (N bars)
    double             deviation;   // Std dev multiplier (linear reg / bollinger)
    ENUM_APPLIED_PRICE priceApply;  // Price type (Open/High/Low/Close)
    ENUM_MA_METHOD     maMethod;    // MA method untuk bollinger
    double             raffScale;   // Raff scale (0.5 = 50%)
    
    SChannelParams()
    {
        type       = CHANNEL_DONCHIAN;
        period     = 20;
        deviation  = 2.0;
        priceApply = PRICE_CLOSE;
        maMethod   = MODE_SMA;
        raffScale  = 1.0;
    }
};

//+------------------------------------------------------------------+
//| Channel Result (hasil deteksi per bar)                           |
//+------------------------------------------------------------------+
struct SChannelLevel
{
    double   upper;
    double   middle;
    double   lower;
    double   width;        // upper - lower
};

struct SChannelSignal
{
    ENUM_CHANNEL_BREAKOUT breakout;     // Arah breakout
    datetime              time;         // Waktu breakout
    double                price;        // Harga saat breakout
    double                targetDist;   // Jarak ke target (points)
    double                widthAtBreak; // Channel width saat breakout
    int                   barIndex;     // Index bar breakout
    bool                  isConfirmed;  // Confirmed (close candle)
    double                strength;     // 0.0 - 1.0 (normalized strength)
};

//+------------------------------------------------------------------+
//| CPriceChannel Class                                              |
//+------------------------------------------------------------------+
class CPriceChannel
{
private:
    // Parameter
    SChannelParams      m_params;
    
    // Cache untuk kalkulasi
    SChannelLevel       m_currentLevels;
    SChannelSignal      m_lastSignal;
    
    // Bar data buffer
    double              m_highs[];
    double              m_lows[];
    double              m_closes[];
    double              m_opens[];
    
    int                 m_maxBars;
    
    // Helper methods
    void                resizeBuffers(int size);
    bool                loadData(int bars, ENUM_TIMEFRAMES tf);
    
    // Kalkulasi per channel type
    SChannelLevel       calcDonchian(int shift, int count);
    SChannelLevel       calcLinearReg(int shift, int count);
    SChannelLevel       calcPitchfork(int shift, int count);
    SChannelLevel       calcBollinger(int shift, int count);
    SChannelLevel       calcRaff(int shift, int count);
    
    // Stat helper
    double              calcStdDev(const double &arr[], int count);
    double              linearReg(const double &y[], int count, double &slope);
    double              highest(const double &arr[], int count);
    double              lowest(const double &arr[], int count);
    
public:
    // Constructor
    CPriceChannel();
    CPriceChannel(SChannelParams params);
    
    // Init / Config
    void                Init(ENUM_CHANNEL_TYPE type, int period, double deviation = 2.0);
    void                InitEx(SChannelParams params);
    
    // Deteksi - single point
    SChannelLevel       GetLevels(int shift = 0, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
    SChannelSignal      DetectBreakout(int shift = 0, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
    
    // Deteksi - scan semua bar yang belum
    int                 ScanBreakouts(int maxBars = 500, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
    
    // Utility
    double              GetChannelWidth(int shift = 0, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
    double              GetTrendStrength(int shift = 0, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
    ENUM_CHANNEL_TYPE   GetType() { return m_params.type; }
    int                 GetPeriod() { return m_params.period; }
    void                SetPeriod(int period) { m_params.period = period; }
    void                SetDeviation(double dev) { m_params.deviation = dev; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPriceChannel::CPriceChannel()
{
    m_maxBars = 1000;
    ArraySetAsSeries(m_highs, true);
    ArraySetAsSeries(m_lows, true);
    ArraySetAsSeries(m_closes, true);
    ArraySetAsSeries(m_opens, true);
}

CPriceChannel::CPriceChannel(SChannelParams params)
{
    m_params = params;
    m_maxBars = 1000;
    ArraySetAsSeries(m_highs, true);
    ArraySetAsSeries(m_lows, true);
    ArraySetAsSeries(m_closes, true);
    ArraySetAsSeries(m_opens, true);
}

//+------------------------------------------------------------------+
//| Init simplified                                                  |
//+------------------------------------------------------------------+
void CPriceChannel::Init(ENUM_CHANNEL_TYPE type, int period, double deviation = 2.0)
{
    m_params.type      = type;
    m_params.period    = period;
    m_params.deviation = deviation;
}

//+------------------------------------------------------------------+
//| Init extended                                                    |
//+------------------------------------------------------------------+
void CPriceChannel::InitEx(SChannelParams params)
{
    m_params = params;
}

//+------------------------------------------------------------------+
//| Load price data                                                  |
//+------------------------------------------------------------------+
bool CPriceChannel::loadData(int bars, ENUM_TIMEFRAMES tf)
{
    if(bars <= 0) bars = m_params.period;
    
    // Resize buffers
    resizeBuffers(bars);
    
    // Copy rate dari buffer
    MqlRates rates[];
    int count = CopyRates(_Symbol, tf, 0, bars, rates);
    
    if(count <= 0) return false;
    
    // Resize ke actual count
    ArrayResize(m_highs, count);
    ArrayResize(m_lows, count);
    ArrayResize(m_closes, count);
    ArrayResize(m_opens, count);
    
    for(int i = 0; i < count; i++)
    {
        m_highs[i]  = rates[count - 1 - i].high;
        m_lows[i]   = rates[count - 1 - i].low;
        m_closes[i] = rates[count - 1 - i].close;
        m_opens[i]  = rates[count - 1 - i].open;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Resize buffers dengan alignment                                  |
//+------------------------------------------------------------------+
void CPriceChannel::resizeBuffers(int size)
{
    if(ArraySize(m_highs) < size)
    {
        ArrayResize(m_highs, size);
        ArrayResize(m_lows, size);
        ArrayResize(m_closes, size);
        ArrayResize(m_opens, size);
    }
}

//+------------------------------------------------------------------+
//| Get channel levels untuk shift tertentu                          |
//+------------------------------------------------------------------+
SChannelLevel CPriceChannel::GetLevels(int shift = 0, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
    SChannelLevel result;
    
    int barsNeeded = m_params.period + shift + 1;
    if(!loadData(barsNeeded, tf)) return result;
    
    switch(m_params.type)
    {
        case CHANNEL_DONCHIAN:
            result = calcDonchian(shift, m_params.period);
            break;
        case CHANNEL_LINEAR_REG:
            result = calcLinearReg(shift, m_params.period);
            break;
        case CHANNEL_PITCHFORK:
            result = calcPitchfork(shift, m_params.period);
            break;
        case CHANNEL_BOLLINGER:
            result = calcBollinger(shift, m_params.period);
            break;
        case CHANNEL_RAFF:
            result = calcRaff(shift, m_params.period);
            break;
    }
    
    m_currentLevels = result;
    return result;
}

//+------------------------------------------------------------------+
//| Detect breakout pada shift tertentu                              |
//+------------------------------------------------------------------+
SChannelSignal CPriceChannel::DetectBreakout(int shift = 0, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
    SChannelSignal signal;
    signal.breakout = BREAKOUT_NONE;
    signal.isConfirmed = false;
    signal.strength = 0.0;
    
    // Ambil levels untuk [shift+1] (current bar)
    SChannelLevel levels = GetLevels(shift + 1, tf);
    if(levels.upper == 0.0 && levels.lower == 0.0) return signal;
    
    // Ambil harga close + open untuk [shift]
    int barsNeeded = shift + 2;
    if(!loadData(barsNeeded, tf)) return signal;
    
    double closePrice = m_closes[0];
    double openPrice  = m_opens[0];
    
    double upper = levels.upper;
    double lower = levels.lower;
    double middle = levels.middle;
    double width = levels.width;
    
    // Update current levels
    m_currentLevels = levels;
    
    // Bullish breakout: close di atas upper channel
    if(closePrice > upper)
    {
        signal.breakout     = BREAKOUT_BULLISH;
        signal.isConfirmed  = true;
        signal.price        = closePrice;
        signal.widthAtBreak = width;
        signal.barIndex     = shift;
        
        // Trend strength: jarak dari middle ke close, normalized
        double distFromMid = MathAbs(closePrice - middle);
        signal.strength = MathMin(distFromMid / (width * 0.5), 1.0);
        
        // Target: channel width dari breakout point
        signal.targetDist = width;
    }
    // Bearish breakout: close di bawah lower channel
    else if(closePrice < lower)
    {
        signal.breakout     = BREAKOUT_BEARISH;
        signal.isConfirmed  = true;
        signal.price        = closePrice;
        signal.widthAtBreak = width;
        signal.barIndex     = shift;
        
        double distFromMid = MathAbs(closePrice - middle);
        signal.strength = MathMin(distFromMid / (width * 0.5), 1.0);
        
        signal.targetDist = width;
    }
    
    m_lastSignal = signal;
    return signal;
}

//+------------------------------------------------------------------+
//| Scan semua breakout dalam N bars terakhir                         |
//+------------------------------------------------------------------+
int CPriceChannel::ScanBreakouts(int maxBars, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
    int count = 0;
    for(int i = 0; i < maxBars; i++)
    {
        SChannelSignal s = DetectBreakout(i, tf);
        if(s.breakout != BREAKOUT_NONE)
            count++;
    }
    return count;
}

//+------------------------------------------------------------------+
//| Get channel width                                                |
//+------------------------------------------------------------------+
double CPriceChannel::GetChannelWidth(int shift, ENUM_TIMEFRAMES tf)
{
    SChannelLevel lv = GetLevels(shift, tf);
    return lv.width;
}

//+------------------------------------------------------------------+
//| Get trend strength (0 = midline, 1 = at edge)                    |
//+------------------------------------------------------------------+
double CPriceChannel::GetTrendStrength(int shift, ENUM_TIMEFRAMES tf)
{
    SChannelLevel lv = GetLevels(shift, tf);
    if(lv.width == 0) return 0.0;
    
    if(!loadData(shift + 2, tf)) return 0.0;
    double closePrice = m_closes[0];
    
    double distFromMid = MathAbs(closePrice - lv.middle);
    return MathMin(distFromMid / (lv.width * 0.5), 1.0);
}

//+------------------------------------------------------------------+
//| KALKULASI: Donchian Channel                                      |
//+------------------------------------------------------------------+
SChannelLevel CPriceChannel::calcDonchian(int shift, int count)
{
    SChannelLevel result;
    
    if(!loadData(count + shift, PERIOD_CURRENT)) return result;
    
    double hi = m_highs[shift];
    double lo = m_lows[shift];
    
    for(int i = shift; i < shift + count; i++)
    {
        if(i >= ArraySize(m_highs)) break;
        hi = MathMax(hi, m_highs[i]);
        lo = MathMin(lo, m_lows[i]);
    }
    
    result.upper  = hi;
    result.lower  = lo;
    result.middle = (hi + lo) * 0.5;
    result.width  = hi - lo;
    
    return result;
}

//+------------------------------------------------------------------+
//| KALKULASI: Linear Regression Channel                             |
//+------------------------------------------------------------------+
SChannelLevel CPriceChannel::calcLinearReg(int shift, int count)
{
    SChannelLevel result;
    
    if(!loadData(count + shift, PERIOD_CURRENT)) return result;
    
    // Copy price array sesuai period
    double priceArr[];
    ArrayResize(priceArr, count);
    for(int i = 0; i < count; i++)
        priceArr[i] = (m_highs[shift + i] + m_lows[shift + i]) * 0.5;
    
    // Linear regression
    double slope;
    double intercept = linearReg(priceArr, count, slope);
    
    // Middle line values
    double midStart = intercept;
    double midEnd   = intercept + slope * (count - 1);
    
    // Calculate upper/lower bands menggunakan std deviation
    double residuals[];
    ArrayResize(residuals, count);
    for(int i = 0; i < count; i++)
    {
        double expected = intercept + slope * i;
        residuals[i] = priceArr[i] - expected;
    }
    
    double stdDev = calcStdDev(residuals, count);
    
    result.upper  = midEnd + m_params.deviation * stdDev;
    result.lower  = midEnd - m_params.deviation * stdDev;
    result.middle = midEnd;
    result.width  = result.upper - result.lower;
    
    return result;
}

//+------------------------------------------------------------------+
//| KALKULASI: Andrew's Pitchfork                                    |
//+------------------------------------------------------------------+
SChannelLevel CPriceChannel::calcPitchfork(int shift, int count)
{
    SChannelLevel result;
    
    if(count < 3 || !loadData(count + shift, PERIOD_CURRENT)) return result;
    
    // Find 3 pivot points: high, low, high (or reverse)
    double high1 = m_highs[shift];
    double low1  = m_lows[shift];
    double high2 = m_highs[shift];
    
    int idxHigh1 = shift;
    int idxLow  = shift;
    int idxHigh2 = shift;
    
    for(int i = shift; i < shift + count; i++)
    {
        if(m_highs[i] > high1)
        {
            high1 = m_highs[i];
            idxHigh1 = i;
        }
        if(m_lows[i] < low1)
        {
            low1 = m_lows[i];
            idxLow = i;
        }
    }
    
    // Find second high
    high2 = m_highs[shift];
    idxHigh2 = shift;
    for(int i = shift; i < shift + count; i++)
    {
        if(i != idxHigh1 && m_highs[i] > high2)
        {
            high2 = m_highs[i];
            idxHigh2 = i;
        }
    }
    
    // Sort by time
    double pivots[3];
    int pivotTimes[3];
    
    // Determine median (lowest pivot = median line)
    if(idxLow < idxHigh1 && idxLow < idxHigh2)
    {
        // low = pivot 0, sort remaining
        pivots[0] = low1;
        pivotTimes[0] = idxLow;
        if(idxHigh1 < idxHigh2)
        {
            pivots[1] = high1; pivotTimes[1] = idxHigh1;
            pivots[2] = high2; pivotTimes[2] = idxHigh2;
        }
        else
        {
            pivots[1] = high2; pivotTimes[1] = idxHigh2;
            pivots[2] = high1; pivotTimes[2] = idxHigh1;
        }
    }
    else
    {
        // Find lowest as median
        double lo = MathMin(MathMin(high1, high2), low1);
        pivots[0] = lo;
        pivotTimes[0] = 0;
        
        double midVal = MathMax(MathMax(high1, high2), low1);
        double hi = midVal;
        if(high1 == lo) { pivots[1] = high2; pivotTimes[1] = idxHigh2; pivots[2] = high1; pivotTimes[2] = idxHigh1; }
        else if(high2 == lo) { pivots[1] = high1; pivotTimes[1] = idxHigh1; pivots[2] = high2; pivotTimes[2] = idxHigh2; }
        else { pivots[1] = high1; pivotTimes[1] = idxHigh1; pivots[2] = high2; pivotTimes[2] = idxHigh2; }
    }
    
    // Median line through first and last pivot
    double medianSlope = (pivots[2] - pivots[0]) / (double)(pivotTimes[2] - pivotTimes[0] + 1);
    double medianIntercept = pivots[0] - medianSlope * pivotTimes[0];
    
    // Current bar = last bar of range
    int lastBar = shift + count - 1;
    double medianNow = medianIntercept + medianSlope * lastBar;
    
    // Outer rays parallel to median, passing through other pivot
    double raySlope = medianSlope;
    double upperRay = pivots[1] - raySlope * pivotTimes[1];
    double lowerRay = pivots[1] - raySlope * pivotTimes[1];
    
    double upperNow = medianNow + (pivots[1] - pivots[0]);
    double lowerNow = medianNow - (pivots[1] - pivots[0]);
    
    result.upper  = upperNow;
    result.lower  = lowerNow;
    result.middle = medianNow;
    result.width  = upperNow - lowerNow;
    
    return result;
}

//+------------------------------------------------------------------+
//| KALKULASI: Bollinger Bands (MA +/- N * std)                      |
//+------------------------------------------------------------------+
SChannelLevel CPriceChannel::calcBollinger(int shift, int count)
{
    SChannelLevel result;
    
    if(!loadData(count + shift, PERIOD_CURRENT)) return result;
    
    // Calculate MA
    double ma = 0.0;
    for(int i = shift; i < shift + count; i++)
    {
        ma += m_closes[i];
    }
    ma /= (double)count;
    
    // Calculate std dev
    double stdDev = 0.0;
    for(int i = shift; i < shift + count; i++)
    {
        double diff = m_closes[i] - ma;
        stdDev += diff * diff;
    }
    stdDev = MathSqrt(stdDev / (double)count);
    
    result.upper  = ma + m_params.deviation * stdDev;
    result.lower  = ma - m_params.deviation * stdDev;
    result.middle = ma;
    result.width  = result.upper - result.lower;
    
    return result;
}

//+------------------------------------------------------------------+
//| KALKULASI: Raff Regression Channel                               |
//+------------------------------------------------------------------+
SChannelLevel CPriceChannel::calcRaff(int shift, int count)
{
    SChannelLevel result;
    
    if(!loadData(count + shift, PERIOD_CURRENT)) return result;
    
    // Find highest high dan lowest low dalam range
    double maxHi = m_highs[shift];
    double minLo = m_lows[shift];
    
    for(int i = shift; i < shift + count; i++)
    {
        if(m_highs[i] > maxHi) maxHi = m_highs[i];
        if(m_lows[i] < minLo) minLo = m_lows[i];
    }
    
    // Linear regression pada midpoint
    double midArr[];
    ArrayResize(midArr, count);
    for(int i = 0; i < count; i++)
        midArr[i] = (m_highs[shift + i] + m_lows[shift + i]) * 0.5;
    
    double slope;
    double intercept = linearReg(midArr, count, slope);
    
    // Middle line at last bar
    double middleNow = intercept + slope * (count - 1);
    
    // Upper/lower = max range / 2
    double halfWidth = (maxHi - minLo) * 0.5 * m_params.raffScale;
    
    result.upper  = middleNow + halfWidth;
    result.lower  = middleNow - halfWidth;
    result.middle = middleNow;
    result.width  = result.upper - result.lower;
    
    return result;
}

//+------------------------------------------------------------------+
//| Helper: Linear Regression (return intercept)                      |
//+------------------------------------------------------------------+
double CPriceChannel::linearReg(const double &y[], int count, double &slope)
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
    slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    double intercept = (sumY - slope * sumX) / n;
    
    return intercept;
}

//+------------------------------------------------------------------+
//| Helper: Standard Deviation                                        |
//+------------------------------------------------------------------+
double CPriceChannel::calcStdDev(const double &arr[], int count)
{
    if(count <= 1) return 0.0;
    
    double mean = 0.0;
    for(int i = 0; i < count; i++)
        mean += arr[i];
    mean /= (double)count;
    
    double sumSq = 0.0;
    for(int i = 0; i < count; i++)
    {
        double d = arr[i] - mean;
        sumSq += d * d;
    }
    
    return MathSqrt(sumSq / (double)count);
}

//+------------------------------------------------------------------+
//| Helper: Highest dalam array                                      |
//+------------------------------------------------------------------+
double CPriceChannel::highest(const double &arr[], int count)
{
    double hi = arr[0];
    for(int i = 1; i < count; i++)
        if(arr[i] > hi) hi = arr[i];
    return hi;
}

//+------------------------------------------------------------------+
//| Helper: Lowest dalam array                                       |
//+------------------------------------------------------------------+
double CPriceChannel::lowest(const double &arr[], int count)
{
    double lo = arr[0];
    for(int i = 1; i < count; i++)
        if(arr[i] < lo) lo = arr[i];
    return lo;
}

//+------------------------------------------------------------------+
//| END OF FILE                                                      |
//+------------------------------------------------------------------+
#endif // PRICECHANNEL_MQH