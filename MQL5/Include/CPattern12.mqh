//+------------------------------------------------------------------+
//|                                            CPattern12.mqh       |
//+------------------------------------------------------------------+
//| Library: 12 Chart Patterns Detector                               |
//| Version : 1.00                                                    |
//|                                                                      |
//| 12 PATTERNS:                                                      |
//|                                                                      |
//| KATEGORI 1 - BAR OVERLAP (Flag, Pennant, Wedge)                    |
//|   [1] Bull Flag     - Flagpole UP + konsolidasi rectangular       |
//|   [2] Bear Flag     - Flagpole DOWN + konsolidasi rectangular     |
//|   [3] Bullish Pennant - Flagpole UP + konsolidasi tapered         |
//|   [4] Bearish Pennant - Flagpole DOWN + konsolidasi tapered       |
//|   [5] Rising Wedge  - Flagpole UP + konsolidasi expanding         |
//|   [6] Falling Wedge - Flagpole DOWN + konsolidasi expanding       |
//|                                                                      |
//| KATEGORI 2 - ZIGZAG-BASED (Rectangle, Triangle)                   |
//|   [7]  Horizontal Rect  - Edges datar & sejajar                   |
//|   [8]  Ascending Rect   - Edges naik (along trend)               |
//|   [9]  Descending Rect  - Edges turun (against trend)           |
//|   [10] Ascending Triangle - Tops flat, bottoms rising           |
//|   [11] Descending Triangle - Tops falling, bottoms flat          |
//|   [12] Symmetrical Triangle - Tops falling, bottoms rising       |
//|                                                                      |
//| OUTPUT:                                                           |
//|   - Arrow pada breakout bar                                       |
//|   - Label jarak (dalam points) pada breakout                     |
//|   - Garis boundary pattern (optional)                             |
//|                                                                      |
//| PAKAI: Copy ke MQL5/Include/ lalu #include <CPattern12.mqh>     |
//+------------------------------------------------------------------+
#property copyright   "12 Chart Patterns Library v1.0"
#property strict

#ifndef CPATTERN12_MQH
#define CPATTERN12_MQH

//+------------------------------------------------------------------+
//| Pattern IDs (gunakan di EA untuk filter signal)                   |
//+------------------------------------------------------------------+
#define PATTERN_BULL_FLAG         1
#define PATTERN_BEAR_FLAG         2
#define PATTERN_BULL_PENNANT      3
#define PATTERN_BEAR_PENNANT      4
#define PATTERN_RISING_WEDGE      5
#define PATTERN_FALLING_WEDGE     6
#define PATTERN_HORIZONTAL_RECT   7
#define PATTERN_ASCEND_RECT       8
#define PATTERN_DESCEND_RECT      9
#define PATTERN_ASCEND_TRI        10
#define PATTERN_DESCEND_TRI       11
#define PATTERN_SYMMETRICAL_TRI   12

//+------------------------------------------------------------------+
//| Signal structure - hasil deteksi pattern                        |
//+------------------------------------------------------------------+
struct CPatternSignal
{
    int         patternID;     // 1-12
    string      patternName;   // nama pattern
    datetime    time;          // waktu breakout
    double      price;         // harga breakout
    double      target;        // target jarak (points)
    double      flagpoleSize;  // tinggi flagpole (points)
    double      width;         // lebar pattern (points) - jarak terlebar
    bool        isBullish;    // true=BUY, false=SELL
    bool        isConfirmed;   // breakout confirmed
    int         startBar;      // bar mulai pattern
    int         endBar;        // bar akhir pattern (breakout)
};

//+------------------------------------------------------------------+
//| ZigZag Point                                                     |
//+------------------------------------------------------------------+
struct CZZPoint
{
    datetime    time;
    double      price;
    int         type;       // 1=peak, -1=trough, 0=none
};

//+------------------------------------------------------------------+
//| CPatternDetector - Main class                                    |
//+------------------------------------------------------------------+
class CPatternDetector
{
private:
    string      m_symbol;
    ENUM_TIMEFRAMES m_tf;
    
    // Bar overlap state (Flag/Pennant/Wedge)
    int         m_ovCount;
    int         m_ovStartBar;
    double      m_ovMaxSize;
    double      m_ovFlagpoleHigh;
    double      m_ovFlagpoleLow;
    int         m_ovFlagpoleBar;
    
    // ZigZag points
    CZZPoint    m_zzPoints[];
    int         m_zzCount;
    int         m_zzHandle;
    
    // Parameters
    double      m_minOverlap;
    int         m_minBars;
    double      m_rectK;
    double      m_taperK;
    double      m_expandK;
    double      m_slopeK;
    double      m_minPole;
    int         m_zzDepth;
    int         m_zzDev;
    int         m_zzBack;
    int         m_minVert;
    double      m_zzK1;
    double      m_zzK2;
    double      m_zzK3;
    
    // Drawing
    bool        m_drawArrow;
    bool        m_drawLabel;
    bool        m_drawLine;
    color       m_colorBuy;
    color       m_colorSell;
    color       m_colorLabel;
    color       m_colorLine;
    int         m_fontSize;
    int         m_arrowCodeBuy;
    int         m_arrowCodeSell;
    
    // Alert
    datetime    m_lastAlert;
    int         m_alertCooldown; // seconds
    bool        m_alertOn;
    bool        m_soundOn;
    
    // Internal functions
    void        ResetOverlapState();
    void        UpdateZZ(const double &high[], const double &low[], 
                         const datetime &time[], int totalBars);
    int         DetectBarOverlapPattern(int bar, const double &high[],
                         const double &low[], const double &close[],
                         const double &open[], CPatternSignal &sig);
    int         DetectZZPattern(int startIdx, const double &high[],
                         const double &low[], const datetime &time[],
                         CPatternSignal &sig);
    double      CalcAverSize(const double &high[], const double &low[],
                         int start, int count, double &averBias, 
                         double &averSizeDif);
    double      CheckZZSlope(int li, int vertices);
    int         DetermineRectType(int li, int vertices);
    int         DetermineTriangleType(int li, int vertices);
    void        CreateArrowLabel(datetime t, double price, string txt,
                         color c, bool above);
    void        CreatePatternLine(int li, int vertices, bool bullish);
    void        DoAlert(CPatternSignal &sig);
    
public:
    CPatternDetector();
    ~CPatternDetector();
    
    // Initialize - panggil di OnInit EA/Indicator
    void        Init(string symbol, ENUM_TIMEFRAMES tf);
    
    // Set parameters
    void        SetOverlapParams(double minOverlap, int minBars,
                         double rectK, double taperK, double expandK,
                         double slopeK, double minPole)
    {
        m_minOverlap = minOverlap;
        m_minBars = minBars;
        m_rectK = rectK;
        m_taperK = taperK;
        m_expandK = expandK;
        m_slopeK = slopeK;
        m_minPole = minPole;
    }
    
    void        SetZZParams(int depth, int dev, int back, 
                             int minVert, double k1, double k2, double k3)
    {
        m_zzDepth = depth; m_zzDev = dev; m_zzBack = back;
        m_minVert = minVert;
        m_zzK1 = k1; m_zzK2 = k2; m_zzK3 = k3;
    }
    
    void        SetDrawParams(bool arrow, bool label, bool line,
                         color colBuy, color colSell, color colLabel,
                         color colLine, int fontSize,
                         int arrowBuy, int arrowSell)
    {
        m_drawArrow = arrow; m_drawLabel = label; m_drawLine = line;
        m_colorBuy = colBuy; m_colorSell = colSell;
        m_colorLabel = colLabel; m_colorLine = colLine;
        m_fontSize = fontSize;
        m_arrowCodeBuy = arrowBuy; m_arrowCodeSell = arrowSell;
    }
    
    void        SetAlertParams(bool on, bool sound, int cooldownSec)
    {
        m_alertOn = on; m_soundOn = sound; m_alertCooldown = cooldownSec;
    }
    
    // Main scan - panggil di OnCalculate
    // Returns: jumlah pattern ditemukan
    // Signals array di-pass by reference untuk dibaca EA
    int         Scan(int startBar, int endBar,
                     const double &open[], const double &high[],
                     const double &low[], const double &close[],
                     const datetime &time[],
                     CPatternSignal &signals[],   // output array
                     int &signalCount);           // max signals
    
    // Quick check - apakah ada pattern yang sedang формируется
    bool        IsPatternForming(int patternID);
    
    // Get pattern name dari ID
    string      PatternName(int id);
    
    // Cleanup
    void        Release();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CPatternDetector::CPatternDetector()
{
    m_symbol = _Symbol;
    m_tf = PERIOD_CURRENT;
    m_zzHandle = INVALID_HANDLE;
    m_zzCount = 0;
    
    ResetOverlapState();
    
    // Default parameters
    m_minOverlap = 0.40;
    m_minBars    = 5;
    m_rectK      = 0.33;
    m_taperK     = 0.05;
    m_expandK    = 0.05;
    m_slopeK     = 0.10;
    m_minPole    = 1.5;
    m_zzDepth    = 12;
    m_zzDev      = 5;
    m_zzBack     = 3;
    m_minVert    = 2;
    m_zzK1       = 1.5;
    m_zzK2       = 0.25;
    m_zzK3       = 0.25;
    
    m_drawArrow  = true;
    m_drawLabel  = true;
    m_drawLine   = false;
    m_colorBuy   = clrLime;
    m_colorSell  = clrRed;
    m_colorLabel = clrYellow;
    m_colorLine  = clrDeepSkyBlue;
    m_fontSize   = 9;
    m_arrowCodeBuy = 233;
    m_arrowCodeSell = 234;
    
    m_alertOn    = false;
    m_soundOn    = false;
    m_alertCooldown = 60;
    m_lastAlert  = 0;
    
    ArrayResize(m_zzPoints, 200);
}

//+------------------------------------------------------------------+
CPatternDetector::~CPatternDetector()
{
    Release();
}

//+------------------------------------------------------------------+
void CPatternDetector::Init(string symbol, ENUM_TIMEFRAMES tf)
{
    m_symbol = symbol;
    m_tf = tf;
    
    if(m_zzHandle != INVALID_HANDLE)
        IndicatorRelease(m_zzHandle);
    
    m_zzHandle = iCustom(symbol, tf, "ZigZag", m_zzDepth, m_zzDev, m_zzBack);
    if(m_zzHandle == INVALID_HANDLE)
        Print("[CPattern12] Failed to create ZigZag for ", symbol);
    
    ResetOverlapState();
    Print("[CPattern12] Initialized for ", symbol, " TF=", tf);
}

//+------------------------------------------------------------------+
void CPatternDetector::Release()
{
    if(m_zzHandle != INVALID_HANDLE)
    {
        IndicatorRelease(m_zzHandle);
        m_zzHandle = INVALID_HANDLE;
    }
    
    // Delete all pattern objects
    string name;
    long total = ObjectsTotal(0);
    for(long i = total - 1; i >= 0; i--)
    {
        name = ObjectName(0, i);
        if(StringFind(name, "CP12_") == 0)
            ObjectDelete(0, name);
    }
}

//+------------------------------------------------------------------+
void CPatternDetector::ResetOverlapState()
{
    m_ovCount = 0;
    m_ovStartBar = 0;
    m_ovMaxSize = 0;
    m_ovFlagpoleHigh = 0;
    m_ovFlagpoleLow = 0;
    m_ovFlagpoleBar = 0;
}

//+------------------------------------------------------------------+
string CPatternDetector::PatternName(int id)
{
    switch(id)
    {
        case PATTERN_BULL_FLAG:        return "Bull Flag";
        case PATTERN_BEAR_FLAG:        return "Bear Flag";
        case PATTERN_BULL_PENNANT:     return "Bullish Pennant";
        case PATTERN_BEAR_PENNANT:     return "Bearish Pennant";
        case PATTERN_RISING_WEDGE:     return "Rising Wedge";
        case PATTERN_FALLING_WEDGE:    return "Falling Wedge";
        case PATTERN_HORIZONTAL_RECT:   return "Horizontal Rectangle";
        case PATTERN_ASCEND_RECT:       return "Ascending Rectangle";
        case PATTERN_DESCEND_RECT:      return "Descending Rectangle";
        case PATTERN_ASCEND_TRI:        return "Ascending Triangle";
        case PATTERN_DESCEND_TRI:        return "Descending Triangle";
        case PATTERN_SYMMETRICAL_TRI:   return "Symmetrical Triangle";
        default: return "Unknown";
    }
}

//+------------------------------------------------------------------+
int CPatternDetector::Scan(int startBar, int endBar,
                           const double &open[], const double &high[],
                           const double &low[], const double &close[],
                           const datetime &time[],
                           CPatternSignal &signals[],
                           int &signalCount)
{
    signalCount = 0;
    if(startBar >= endBar || m_zzHandle == INVALID_HANDLE) return 0;
    
    // Update ZigZag
    UpdateZZ(high, low, time, ArraySize(close));
    
    // === SCAN BAR OVERLAP PATTERNS ===
    for(int i = startBar; i < endBar - 1 && signalCount < 50; i++)
    {
        CPatternSignal sig;
        int pid = DetectBarOverlapPattern(i, high, low, close, open, sig);
        if(pid > 0)
        {
            sig.patternID = pid;
            sig.patternName = PatternName(pid);
            signals[signalCount] = sig;
            signalCount++;
        }
    }
    
    // === SCAN ZIGZAG PATTERNS ===
    for(int li = 0; li < m_zzCount - (m_minVert * 2 + 2) && signalCount < 50; li++)
    {
        CPatternSignal sig;
        int pid = DetectZZPattern(li, high, low, time, sig);
        if(pid > 0)
        {
            sig.patternID = pid;
            sig.patternName = PatternName(pid);
            signals[signalCount] = sig;
            signalCount++;
        }
    }
    
    return signalCount;
}

//+------------------------------------------------------------------+
void CPatternDetector::UpdateZZ(const double &high[], const double &low[],
                                const datetime &time[], int totalBars)
{
    if(m_zzHandle == INVALID_HANDLE) return;
    
    double zzH[], zzL[];
    ArraySetAsSeries(zzH, true);
    ArraySetAsSeries(zzL, true);
    
    int copied = CopyBuffer(m_zzHandle, 0, 0, totalBars, zzH);
    if(copied <= 0) return;
    copied = CopyBuffer(m_zzHandle, 1, 0, totalBars, zzL);
    if(copied <= 0) return;
    
    m_zzCount = 0;
    
    // Collect all zigzag points
    for(int i = 0; i < MathMin(totalBars, 300); i++)
    {
        if(zzH[i] > 0)
        {
            if(m_zzCount >= ArraySize(m_zzPoints))
                ArrayResize(m_zzPoints, m_zzCount + 100);
            m_zzPoints[m_zzCount].time = time[totalBars - 1 - i];
            m_zzPoints[m_zzCount].price = zzH[i];
            m_zzPoints[m_zzCount].type = 1;
            m_zzCount++;
        }
        if(zzL[i] > 0)
        {
            if(m_zzCount >= ArraySize(m_zzPoints))
                ArrayResize(m_zzPoints, m_zzCount + 100);
            m_zzPoints[m_zzCount].time = time[totalBars - 1 - i];
            m_zzPoints[m_zzCount].price = zzL[i];
            m_zzPoints[m_zzCount].type = -1;
            m_zzCount++;
        }
    }
    
    // Sort by time
    for(int i = 0; i < m_zzCount - 1; i++)
    {
        for(int j = i + 1; j < m_zzCount; j++)
        {
            if(m_zzPoints[j].time < m_zzPoints[i].time)
            {
                CZZPoint tmp = m_zzPoints[i];
                m_zzPoints[i] = m_zzPoints[j];
                m_zzPoints[j] = tmp;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Detect Bar Overlap Pattern (Flag/Pennant/Wedge)                  |
//+------------------------------------------------------------------+
int CPatternDetector::DetectBarOverlapPattern(int bar,
    const double &high[], const double &low[],
    const double &close[], const double &open[],
    CPatternSignal &sig)
{
    // Initialize signal
    ZeroMemory(sig);
    sig.startBar = bar;
    
    if(bar < 1) return 0;
    
    double currSize = high[bar] - low[bar];
    double prevSize = high[bar - 1] - low[bar - 1];
    if(currSize <= 0 || prevSize <= 0) return 0;
    
    // Calculate overlap
    double overlap = MathMin(high[bar], high[bar - 1]) 
                   - MathMax(low[bar], low[bar - 1]);
    bool hasOverlap = (overlap >= MathMin(currSize, prevSize) * m_minOverlap);
    
    if(hasOverlap)
    {
        if(m_ovCount == 0)
        {
            // Find flagpole (long bar before consolidation)
            m_ovStartBar = bar - 1;
            m_ovFlagpoleBar = bar - 1;
            m_ovMaxSize = high[bar - 1] - low[bar - 1];
            m_ovFlagpoleHigh = high[bar - 1];
            m_ovFlagpoleLow = low[bar - 1];
            
            // Scan back for bigger bar (flagpole)
            for(int k = bar - 2; k >= MathMax(0, bar - 15); k--)
            {
                double sz = high[k] - low[k];
                if(sz > m_ovMaxSize * 1.5)
                {
                    m_ovFlagpoleBar = k;
                    m_ovFlagpoleHigh = high[k];
                    m_ovFlagpoleLow = low[k];
                    m_ovMaxSize = sz;
                    m_ovStartBar = k;
                }
            }
        }
        
        m_ovCount++;
    }
    else
    {
        // Check if we had a complete pattern before this gap
        int detectedPID = 0;
        if(m_ovCount >= m_minBars && m_ovMaxSize > 0)
        {
            detectedPID = ClassifyOverlapPattern(high, low, close, open, bar - 1);
        }
        
        ResetOverlapState();
        return detectedPID;
    }
    
    // Check if consolidation is complete
    if(m_ovCount >= m_minBars && m_ovMaxSize > 0)
    {
        // Next bar after consolidation = breakout candidate
        if(bar + 1 < ArraySize(close))
        {
            // Classification happens at the breakout bar
        }
    }
    
    return 0; // Pattern still forming
}

//+------------------------------------------------------------------+
//| Classify overlap pattern at breakout                             |
//+------------------------------------------------------------------+
int CPatternDetector::ClassifyOverlapPattern(
    const double &high[], const double &low[],
    const double &close[], const double &open[], int endBar)
{
    double averSize, averBias, averSizeDif;
    averSize = CalcAverSize(high, low, m_ovStartBar, m_ovCount, averBias, averSizeDif);
    
    if(averSize <= 0) return 0;
    
    double relBias = averBias / averSize;
    
    // Classify shape
    bool isRect   = MathAbs(averSizeDif) < m_rectK * averSize;
    bool isTaper  = averSizeDif < -m_taperK * averSize;
    bool isExpand = averSizeDif > m_expandK * averSize;
    
    // Slope
    bool slopeHoriz = MathAbs(relBias) < m_slopeK;
    bool slopeUp    = relBias > m_slopeK;
    bool slopeDown  = relBias < -m_slopeK;
    
    // Flagpole direction
    double poleSize = m_ovMaxSize;
    bool poleUp = (m_ovFlagpoleHigh - m_ovFlagpoleLow > 0);
    
    if(poleUp && isRect && slopeHoriz) return PATTERN_BULL_FLAG;
    if(!poleUp && isRect && slopeHoriz) return PATTERN_BEAR_FLAG;
    if(poleUp && isTaper) return PATTERN_BULL_PENNANT;
    if(!poleUp && isTaper) return PATTERN_BEAR_PENNANT;
    if(poleUp && isExpand && slopeUp) return PATTERN_RISING_WEDGE;
    if(!poleUp && isExpand && slopeDown) return PATTERN_FALLING_WEDGE;
    
    return 0;
}

//+------------------------------------------------------------------+
//| Detect ZigZag-Based Pattern                                       |
//+------------------------------------------------------------------+
int CPatternDetector::DetectZZPattern(int startIdx,
    const double &high[], const double &low[],
    const datetime &time[], CPatternSignal &sig)
{
    ZeroMemory(sig);
    
    int reqCount = m_minVert * 2 + 2; // N tops + N bottoms + prev + last
    if(startIdx + reqCount >= m_zzCount) return 0;
    
    // Index of first pattern point
    int li = startIdx;
    
    // Base value = height of segment 1-2
    double base = MathAbs(m_zzPoints[li + 1].price - m_zzPoints[li + 2].price);
    if(base <= 0) return 0;
    
    // Flagpole: segment 0-1 should be >= K1 * base
    double l1 = MathAbs(m_zzPoints[li + 1].price - m_zzPoints[li].price);
    if(l1 < base * m_zzK1) return 0;
    
    // Calculate all segment heights
    double seg[];
    ArrayResize(seg, m_minVert);
    for(int i = 0; i < m_minVert; i++)
    {
        int j = li + 1 + i * 2;
        if(j + 1 < m_zzCount)
            seg[i] = MathAbs(m_zzPoints[j].price - m_zzPoints[j + 1].price);
        else
            seg[i] = 0;
    }
    
    // Determine direction from last segment
    int lastIdx = li + reqCount - 1;
    bool isBull = (m_zzPoints[lastIdx].price > m_zzPoints[lastIdx - 1].price);
    
    // Slope check
    double slope = CheckZZSlope(li, m_minVert);
    bool slopeHoriz = MathAbs(slope) < m_zzK3;
    bool slopeUp    = slope > m_zzK3;
    bool slopeDown  = slope < -m_zzK3;
    
    // === CHECK PATTERN FORMS ===
    
    // 1. RECTANGULAR PATTERNS (7, 8, 9)
    bool allRect = true;
    for(int i = 0; i < m_minVert - 1; i++)
    {
        if(MathAbs(seg[i] - base) > m_zzK2 * base)
        { allRect = false; break; }
    }
    
    if(allRect && (slopeHoriz || slopeUp || slopeDown))
    {
        sig.flagpoleSize = l1 / _Point;
        sig.target = l1 / _Point;
        sig.width = base / _Point;
        sig.isBullish = isBull;
        sig.time = m_zzPoints[lastIdx].time;
        sig.price = m_zzPoints[lastIdx].price;
        sig.startBar = 0;
        sig.endBar = 0;
        sig.isConfirmed = true;
        
        if(slopeHoriz) return PATTERN_HORIZONTAL_RECT;
        if(slopeUp) return PATTERN_ASCEND_RECT;
        if(slopeDown) return PATTERN_DESCEND_RECT;
    }
    
    // 2. CONTRACTING TRIANGLES (10, 11, 12)
    bool allContracting = true;
    for(int i = 0; i < m_minVert - 1; i++)
    {
        if(!(seg[i] - seg[i + 1] > m_zzK2 * base))
        { allContracting = false; break; }
    }
    
    if(allContracting)
    {
        sig.flagpoleSize = l1 / _Point;
        sig.target = l1 / _Point;
        sig.width = base / _Point;
        sig.isBullish = isBull;
        sig.time = m_zzPoints[lastIdx].time;
        sig.price = m_zzPoints[lastIdx].price;
        sig.isConfirmed = true;
        
        int triType = DetermineTriangleType(li, m_minVert);
        if(triType > 0) return triType;
    }
    
    // 3. EXPANDING TRIANGLE - all segments expand
    bool allExpanding = true;
    for(int i = 0; i < m_minVert - 1; i++)
    {
        if(!(seg[i + 1] - seg[i] > m_zzK2 * base))
        { allExpanding = false; break; }
    }
    
    if(allExpanding && MathAbs(slope) < m_zzK3 * 3)
    {
        sig.flagpoleSize = l1 / _Point;
        sig.target = l1 / _Point;
        sig.width = base / _Point;
        sig.isBullish = isBull;
        sig.time = m_zzPoints[lastIdx].time;
        sig.price = m_zzPoints[lastIdx].price;
        sig.isConfirmed = true;
        
        return PATTERN_SYMMETRICAL_TRI; // treating expanding as symm variant
    }
    
    return 0;
}

//+------------------------------------------------------------------+
double CPatternDetector::CalcAverSize(const double &high[], 
    const double &low[], int start, int count,
    double &averBias, double &averSizeDif)
{
    if(count <= 0 || start < 0) return 0;
    
    double sum = high[start] - low[start];
    averBias = 0;
    averSizeDif = 0;
    
    for(int k = start + 1; k < start + count && k < ArraySize(high); k++)
    {
        double sc = high[k] - low[k];
        double sp = high[k - 1] - low[k - 1];
        sum += sc;
        
        double mc = (high[k] + low[k]) / 2.0;
        double mp = (high[k - 1] + low[k - 1]) / 2.0;
        averBias += (mc - mp);
        averSizeDif += (sc - sp);
    }
    
    double averSize = sum / count;
    if(count > 1) averBias /= (count - 1);
    if(count > 1) averSizeDif /= (count - 1);
    
    return averSize;
}

//+------------------------------------------------------------------+
double CPatternDetector::CheckZZSlope(int li, int vertices)
{
    if(vertices < 2) return 0;
    
    double upSum = 0, dnSum = 0;
    int upCnt = 0, dnCnt = 0;
    
    for(int v = 1; v < vertices; v++)
    {
        int vi = li + 1 + v * 2;
        if(vi + 1 >= m_zzCount) continue;
        
        double mc = (m_zzPoints[vi].price + m_zzPoints[vi + 1].price) / 2.0;
        double mp = (m_zzPoints[vi - 2].price + m_zzPoints[vi - 1].price) / 2.0;
        
        if(mc > mp) { upSum += (mc - mp); upCnt++; }
        else        { dnSum += (mp - mc); dnCnt++; }
    }
    
    if(upCnt > 0) upSum /= upCnt;
    if(dnCnt > 0) dnSum /= dnCnt;
    
    return upSum - dnSum;
}

//+------------------------------------------------------------------+
int CPatternDetector::DetermineTriangleType(int li, int vertices)
{
    if(vertices < 2) return PATTERN_SYMMETRICAL_TRI;
    
    int lastTop = li + 1 + (vertices - 1) * 2;
    int lastBot = lastTop + 1;
    int prevTop = lastTop - 2;
    int prevBot = lastBot - 2;
    
    if(lastTop + 1 >= m_zzCount || lastBot + 1 >= m_zzCount)
        return PATTERN_SYMMETRICAL_TRI;
    
    double topDiff = m_zzPoints[lastTop].price - m_zzPoints[prevTop].price;
    double botDiff = m_zzPoints[lastBot].price - m_zzPoints[prevBot].price;
    
    if(topDiff >= 0 && botDiff > 0) return PATTERN_ASCEND_TRI;
    if(topDiff <= 0 && botDiff < 0) return PATTERN_DESCEND_TRI;
    
    return PATTERN_SYMMETRICAL_TRI;
}

//+------------------------------------------------------------------+
int CPatternDetector::DetermineRectType(int li, int vertices)
{
    double slope = CheckZZSlope(li, vertices);
    if(slope > m_zzK3) return PATTERN_ASCEND_RECT;
    if(slope < -m_zzK3) return PATTERN_DESCEND_RECT;
    return PATTERN_HORIZONTAL_RECT;
}

//+------------------------------------------------------------------+
void CPatternDetector::CreateArrowLabel(datetime t, double price,
    string txt, color c, bool above)
{
    if(!m_drawArrow && !m_drawLabel) return;
    
    static int counter = 0;
    string prefix = "CP12_";
    
    // Create arrow as OBJ_ARROW
    if(m_drawArrow)
    {
        string arrowName = prefix + "A_" + IntegerToString(counter);
        if(ObjectCreate(0, arrowName, OBJ_ARROW, 0, t, price))
        {
            ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, 
                             above ? m_arrowCodeBuy : m_arrowCodeSell);
            ObjectSetInteger(0, arrowName, OBJPROP_COLOR, c);
            ObjectSetInteger(0, arrowName, OBJPROP_ANCHOR, 
                             above ? ANCHOR_BOTTOM : ANCHOR_TOP);
            ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, true);
            ObjectSetInteger(0, arrowName, OBJPROP_HIDDEN, false);
        }
    }
    
    // Create label
    if(m_drawLabel)
    {
        string labelName = prefix + "L_" + IntegerToString(counter++);
        double labelPrice = above ? price + 15 * _Point : price - 15 * _Point;
        
        if(ObjectCreate(0, labelName, OBJ_TEXT, 0, t, labelPrice))
        {
            ObjectSetString(0, labelName, OBJPROP_TEXT, txt);
            ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, m_fontSize);
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, m_colorLabel);
            ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, 
                             above ? ANCHOR_BOTTOM : ANCHOR_TOP);
            ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, true);
            ObjectSetString(0, labelName, OBJPROP_FONTFAMILY, "Arial");
        }
    }
}

//+------------------------------------------------------------------+
void CPatternDetector::CreatePatternLine(int li, int vertices, bool bullish)
{
    if(!m_drawLine) return;
    
    if(vertices < 2) return;
    static int counter = 0;
    
    int s = li + 1;
    int e = li + 1 + (vertices - 1) * 2;
    if(e >= m_zzCount) return;
    
    string name = "CP12_LN_" + IntegerToString(counter++);
    
    if(ObjectCreate(0, name, OBJ_TREND, 0,
                    m_zzPoints[s].time, m_zzPoints[s].price,
                    m_zzPoints[e].time, m_zzPoints[e].price))
    {
        ObjectSetInteger(0, name, OBJPROP_COLOR, m_colorLine);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
    }
}

//+------------------------------------------------------------------+
void CPatternDetector::DoAlert(CPatternSignal &sig)
{
    if(!m_alertOn) return;
    
    datetime now = TimeCurrent();
    if(now - m_lastAlert < m_alertCooldown) return;
    m_lastAlert = now;
    
    string dir = sig.isBullish ? "BUY" : "SELL";
    string msg = sig.patternName + " [" + dir + "] Distance: " 
               + DoubleToString(sig.target, 0) + " pts";
    
    Print("[CPattern12] ", msg);
    
    if(m_soundOn) Alert(msg);
}

//+------------------------------------------------------------------+
bool CPatternDetector::IsPatternForming(int patternID)
{
    return (m_ovCount >= 2 && m_ovMaxSize > 0);
}

//+------------------------------------------------------------------+
//| Helper: Draw arrow on chart buffer (untuk indicator)              |
//| Returns arrow price, atau EMPTY_VALUE jika tidak ada             |
//+------------------------------------------------------------------+
double CP12_DrawSignal(int patternID, bool bullish, double flagpoleSize,
                        double &outTarget, double &outWidth)
{
    outTarget = flagpoleSize;  // target = flagpole distance
    outWidth  = flagpoleSize;  // width = same for simplicity
    return flagpoleSize;       // caller uses this to plot arrow
}

//+------------------------------------------------------------------+
//| END OF CLASS                                                     |
//+------------------------------------------------------------------+
#endif // CPATTERN12_MQH
//+------------------------------------------------------------------+