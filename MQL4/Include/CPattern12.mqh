//+------------------------------------------------------------------+
//|                                            CPattern12.mq4       |
//+------------------------------------------------------------------+
//| Library: 12 Chart Patterns Detector - MT4 Version                 |
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
//| KATEGORI 2 - PEAK-TROUGH (Rectangle, Triangle)                   |
//|   [7]  Horizontal Rect  - Edges datar & sejajar                   |
//|   [8]  Ascending Rect   - Edges naik (along trend)               |
//|   [9]  Descending Rect  - Edges turun (against trend)           |
//|   [10] Ascending Triangle - Tops flat, bottoms rising           |
//|   [11] Descending Triangle - Tops falling, bottoms flat          |
//|   [12] Symmetrical Triangle - Tops falling, bottoms rising       |
//|                                                                      |
//| OUTPUT:                                                           |
//|   - Arrow pada breakout bar (OBJ_ARROW)                           |
//|   - Label jarak (dalam points) pada breakout                      |
//|   - Garis boundary pattern (OBJ_TREND)                           |
//|                                                                      |
//| PAKAI: Copy ke MT4/MQL4/Include/ lalu #include <CPattern12.mq4> |
//+------------------------------------------------------------------+
#property copyright   "12 Chart Patterns Library v1.0 - MT4"
#property library

#ifndef CPATTERN12_MQ4
#define CPATTERN12_MQ4

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
    double      width;         // lebar pattern (points)
    bool        isBullish;    // true=BUY, false=SELL
    bool        isConfirmed;   // breakout confirmed
    int         startBar;      // bar mulai pattern
    int         endBar;        // bar akhir pattern (breakout)
};

//+------------------------------------------------------------------+
//| Peak/Trough Point (replaces ZigZag)                              |
//+------------------------------------------------------------------+
struct CPTPoint
{
    datetime    time;
    double      price;
    int         type;       // 1=peak, -1=trough, 0=none
};

//+------------------------------------------------------------------+
//| CPatternDetector - Main class (MT4 version)                       |
//+------------------------------------------------------------------+
class CPatternDetector
{
private:
    string      m_symbol;
    int         m_tf;
    
    // Bar overlap state (Flag/Pennant/Wedge)
    int         m_ovCount;
    int         m_ovStartBar;
    double      m_ovMaxSize;
    double      m_ovFlagpoleHigh;
    double      m_ovFlagpoleLow;
    int         m_ovFlagpoleBar;
    
    // Peak/Trough points (custom zigzag)
    CPTPoint    m_ptPoints[];
    int         m_ptCount;
    
    // Parameters
    double      m_minOverlap;
    int         m_minBars;
    double      m_rectK;
    double      m_taperK;
    double      m_expandK;
    double      m_slopeK;
    double      m_minPole;
    int         m_ptDepth;
    int         m_ptDev;
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
    int         m_alertCooldown;
    bool        m_alertOn;
    bool        m_soundOn;
    
    // Internal functions
    void        ResetOverlapState();
    void        DetectPTPoints(int maxBars);
    int         DetectBarOverlapPattern(int bar, CPatternSignal &sig);
    int         DetectZZPattern(int startIdx, CPatternSignal &sig);
    double      CalcAverSize(int start, int count, double &averBias,
                         double &averSizeDif);
    double      CheckPTSlope(int li, int vertices);
    int         DetermineRectType(int li, int vertices);
    int         DetermineTriangleType(int li, int vertices);
    void        CreateArrowLabel(datetime t, double price, string txt,
                         color c, bool above);
    void        CreatePatternLine(int li, int vertices, bool bullish);
    void        DoAlert(CPatternSignal &sig);
    
public:
    CPatternDetector();
    ~CPatternDetector();
    
    // Initialize - panggil di init() EA/Indicator
    void        Init(string symbol, int tf);
    
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
    
    void        SetZZParams(int depth, int dev, 
                             int minVert, double k1, double k2, double k3)
    {
        m_ptDepth = depth;
        m_ptDev = dev;
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
    
    // Main scan - panggil di start() / OnCalculate
    // Returns: jumlah pattern ditemukan
    int         Scan(int startBar, int endBar,
                     CPatternSignal &signals[],   // output array
                     int &signalCount);
    
    // Get pattern name dari ID
    string      PatternName(int id);
    
    // Get bar count
    int         Bars();
    
    // Cleanup
    void        Release();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CPatternDetector::CPatternDetector()
{
    m_symbol = _Symbol;
    m_tf = _Period;
    m_ptCount = 0;
    
    ResetOverlapState();
    
    // Default parameters
    m_minOverlap = 0.40;
    m_minBars    = 5;
    m_rectK      = 0.33;
    m_taperK     = 0.05;
    m_expandK    = 0.05;
    m_slopeK     = 0.10;
    m_minPole    = 1.5;
    m_ptDepth    = 12;
    m_ptDev      = 5;
    m_minVert    = 2;
    m_zzK1       = 1.5;
    m_zzK2       = 0.25;
    m_zzK3       = 0.25;
    
    m_drawArrow  = true;
    m_drawLabel  = true;
    m_drawLine   = false;
    m_colorBuy   = Lime;
    m_colorSell  = Red;
    m_colorLabel = Yellow;
    m_colorLine  = DodgerBlue;
    m_fontSize   = 9;
    m_arrowCodeBuy = 233;
    m_arrowCodeSell = 234;
    
    m_alertOn    = false;
    m_soundOn    = false;
    m_alertCooldown = 60;
    m_lastAlert  = 0;
    
    ArrayResize(m_ptPoints, 200);
}

//+------------------------------------------------------------------+
CPatternDetector::~CPatternDetector()
{
    Release();
}

//+------------------------------------------------------------------+
void CPatternDetector::Init(string symbol, int tf)
{
    m_symbol = symbol;
    m_tf = tf;
    ResetOverlapState();
    Print("[CPattern12-MT4] Initialized for ", symbol, " TF=", tf);
}

//+------------------------------------------------------------------+
void CPatternDetector::Release()
{
    // Delete all pattern objects
    string name;
    for(int i = ObjectsTotal() - 1; i >= 0; i--)
    {
        name = ObjectName(i);
        if(StringFind(name, "CP12_") == 0)
            ObjectDelete(name);
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
int CPatternDetector::Bars()
{
    return Bars(m_symbol, m_tf);
}

//+------------------------------------------------------------------+
//| Detect Peak/Trough (simplified ZigZag)                          |
//+------------------------------------------------------------------+
void CPatternDetector::DetectPTPoints(int maxBars)
{
    m_ptCount = 0;
    
    int bars = MathMin(Bars(m_symbol, m_tf), maxBars);
    if(bars < 20) return;
    
    double high[], low[];
    datetime time[];
    
    ArrayResize(high, bars);
    ArrayResize(low, bars);
    ArrayResize(time, bars);
    
    // Copy data
    for(int i = 0; i < bars; i++)
    {
        high[i] = iHigh(m_symbol, m_tf, i);
        low[i]  = iLow(m_symbol, m_tf, i);
        time[i] = iTime(m_symbol, m_tf, i);
    }
    
    // Find significant peaks and troughs
    // Simple approach: find local max/min with depth filter
    double dev = m_ptDev * Point;
    
    for(int i = m_ptDepth; i < bars - m_ptDepth && m_ptCount < 100; i++)
    {
        bool isPeak = true;
        bool isTrough = true;
        
        // Check if it's a local extreme
        for(int k = i - m_ptDepth; k <= i + m_ptDepth; k++)
        {
            if(k == i) continue;
            if(k < 0 || k >= bars) continue;
            
            if(high[i] <= high[k]) isPeak = false;
            if(low[i] >= low[k])  isTrough = false;
        }
        
        if(isPeak || isTrough)
        {
            m_ptPoints[m_ptCount].time = time[i];
            m_ptPoints[m_ptCount].price = isPeak ? high[i] : low[i];
            m_ptPoints[m_ptCount].type = isPeak ? 1 : -1;
            m_ptCount++;
        }
    }
}

//+------------------------------------------------------------------+
int CPatternDetector::Scan(int startBar, int endBar,
                           CPatternSignal &signals[],
                           int &signalCount)
{
    signalCount = 0;
    if(startBar >= endBar) return 0;
    
    // Detect peak/trough points
    DetectPTPoints(endBar + 10);
    
    // === SCAN BAR OVERLAP PATTERNS ===
    for(int i = startBar; i < endBar - 1 && signalCount < 50; i++)
    {
        CPatternSignal sig;
        int pid = DetectBarOverlapPattern(i, sig);
        if(pid > 0)
        {
            sig.patternID = pid;
            sig.patternName = PatternName(pid);
            signals[signalCount] = sig;
            signalCount++;
        }
    }
    
    // === SCAN PEAK-TROUGH PATTERNS ===
    for(int li = 0; li < m_ptCount - (m_minVert * 2 + 2) && signalCount < 50; li++)
    {
        CPatternSignal sig;
        int pid = DetectZZPattern(li, sig);
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
int CPatternDetector::DetectBarOverlapPattern(int bar, CPatternSignal &sig)
{
    ZeroMemory(sig);
    sig.startBar = bar;
    
    if(bar < 1) return 0;
    
    double currSize = iHigh(m_symbol, m_tf, bar) - iLow(m_symbol, m_tf, bar);
    double prevSize = iHigh(m_symbol, m_tf, bar - 1) - iLow(m_symbol, m_tf, bar - 1);
    if(currSize <= 0 || prevSize <= 0) return 0;
    
    // Calculate overlap
    double overlap = MathMin(iHigh(m_symbol, m_tf, bar), iHigh(m_symbol, m_tf, bar - 1)) 
                   - MathMax(iLow(m_symbol, m_tf, bar), iLow(m_symbol, m_tf, bar - 1));
    bool hasOverlap = (overlap >= MathMin(currSize, prevSize) * m_minOverlap);
    
    if(hasOverlap)
    {
        if(m_ovCount == 0)
        {
            // Find flagpole (long bar before consolidation)
            m_ovStartBar = bar - 1;
            m_ovFlagpoleBar = bar - 1;
            m_ovMaxSize = prevSize;
            m_ovFlagpoleHigh = iHigh(m_symbol, m_tf, bar - 1);
            m_ovFlagpoleLow = iLow(m_symbol, m_tf, bar - 1);
            
            // Scan back for bigger bar (flagpole)
            for(int k = bar - 2; k >= MathMax(0, bar - 15); k--)
            {
                double sz = iHigh(m_symbol, m_tf, k) - iLow(m_symbol, m_tf, k);
                if(sz > m_ovMaxSize * 1.5)
                {
                    m_ovFlagpoleBar = k;
                    m_ovFlagpoleHigh = iHigh(m_symbol, m_tf, k);
                    m_ovFlagpoleLow = iLow(m_symbol, m_tf, k);
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
            detectedPID = ClassifyOverlapPattern(bar - 1);
        }
        
        ResetOverlapState();
        return detectedPID;
    }
    
    return 0; // Pattern still forming
}

//+------------------------------------------------------------------+
int CPatternDetector::ClassifyOverlapPattern(int endBar)
{
    double averSize, averBias, averSizeDif;
    averSize = CalcAverSize(m_ovStartBar, m_ovCount, averBias, averSizeDif);
    
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
    bool poleUp = (m_ovFlagpoleHigh - m_ovFlagpoleLow > 0);
    
    // Classify
    if(poleUp && isRect && slopeHoriz) return PATTERN_BULL_FLAG;
    if(!poleUp && isRect && slopeHoriz) return PATTERN_BEAR_FLAG;
    if(poleUp && isTaper) return PATTERN_BULL_PENNANT;
    if(!poleUp && isTaper) return PATTERN_BEAR_PENNANT;
    if(poleUp && isExpand && slopeUp) return PATTERN_RISING_WEDGE;
    if(!poleUp && isExpand && slopeDown) return PATTERN_FALLING_WEDGE;
    
    return 0;
}

//+------------------------------------------------------------------+
int CPatternDetector::DetectZZPattern(int startIdx, CPatternSignal &sig)
{
    ZeroMemory(sig);
    
    int reqCount = m_minVert * 2 + 2;
    if(startIdx + reqCount >= m_ptCount) return 0;
    
    int li = startIdx;
    
    // Base value = height of segment 1-2
    double base = MathAbs(m_ptPoints[li + 1].price - m_ptPoints[li + 2].price);
    if(base <= 0) return 0;
    
    // Flagpole: segment 0-1 should be >= K1 * base
    double l1 = MathAbs(m_ptPoints[li + 1].price - m_ptPoints[li].price);
    if(l1 < base * m_zzK1) return 0;
    
    // Calculate all segment heights
    double seg[];
    ArrayResize(seg, m_minVert);
    for(int i = 0; i < m_minVert; i++)
    {
        int j = li + 1 + i * 2;
        if(j + 1 < m_ptCount)
            seg[i] = MathAbs(m_ptPoints[j].price - m_ptPoints[j + 1].price);
        else
            seg[i] = 0;
    }
    
    // Determine direction from last segment
    int lastIdx = li + reqCount - 1;
    bool isBull = (m_ptPoints[lastIdx].price > m_ptPoints[lastIdx - 1].price);
    
    // Slope check
    double slope = CheckPTSlope(li, m_minVert);
    bool slopeHoriz = MathAbs(slope) < m_zzK3;
    bool slopeUp    = slope > m_zzK3;
    bool slopeDown  = slope < -m_zzK3;
    
    // === RECTANGULAR PATTERNS ===
    bool allRect = true;
    for(int i = 0; i < m_minVert - 1; i++)
    {
        if(MathAbs(seg[i] - base) > m_zzK2 * base)
        { allRect = false; break; }
    }
    
    if(allRect && (slopeHoriz || slopeUp || slopeDown))
    {
        sig.flagpoleSize = l1 / Point;
        sig.target = l1 / Point;
        sig.width = base / Point;
        sig.isBullish = isBull;
        sig.time = m_ptPoints[lastIdx].time;
        sig.price = m_ptPoints[lastIdx].price;
        sig.isConfirmed = true;
        
        if(slopeHoriz) return PATTERN_HORIZONTAL_RECT;
        if(slopeUp) return PATTERN_ASCEND_RECT;
        if(slopeDown) return PATTERN_DESCEND_RECT;
    }
    
    // === CONTRACTING TRIANGLES ===
    bool allContracting = true;
    for(int i = 0; i < m_minVert - 1; i++)
    {
        if(!(seg[i] - seg[i + 1] > m_zzK2 * base))
        { allContracting = false; break; }
    }
    
    if(allContracting)
    {
        sig.flagpoleSize = l1 / Point;
        sig.target = l1 / Point;
        sig.width = base / Point;
        sig.isBullish = isBull;
        sig.time = m_ptPoints[lastIdx].time;
        sig.price = m_ptPoints[lastIdx].price;
        sig.isConfirmed = true;
        
        int triType = DetermineTriangleType(li, m_minVert);
        if(triType > 0) return triType;
    }
    
    // === EXPANDING / SYMMETRICAL ===
    bool allExpanding = true;
    for(int i = 0; i < m_minVert - 1; i++)
    {
        if(!(seg[i + 1] - seg[i] > m_zzK2 * base))
        { allExpanding = false; break; }
    }
    
    if(allExpanding && MathAbs(slope) < m_zzK3 * 3)
    {
        sig.flagpoleSize = l1 / Point;
        sig.target = l1 / Point;
        sig.width = base / Point;
        sig.isBullish = isBull;
        sig.time = m_ptPoints[lastIdx].time;
        sig.price = m_ptPoints[lastIdx].price;
        sig.isConfirmed = true;
        
        return PATTERN_SYMMETRICAL_TRI;
    }
    
    return 0;
}

//+------------------------------------------------------------------+
double CPatternDetector::CalcAverSize(int start, int count,
    double &averBias, double &averSizeDif)
{
    if(count <= 0 || start < 0) return 0;
    
    double sum = iHigh(m_symbol, m_tf, start) - iLow(m_symbol, m_tf, start);
    averBias = 0;
    averSizeDif = 0;
    
    for(int k = start + 1; k < start + count; k++)
    {
        double sc = iHigh(m_symbol, m_tf, k) - iLow(m_symbol, m_tf, k);
        double sp = iHigh(m_symbol, m_tf, k - 1) - iLow(m_symbol, m_tf, k - 1);
        sum += sc;
        
        double mc = (iHigh(m_symbol, m_tf, k) + iLow(m_symbol, m_tf, k)) / 2.0;
        double mp = (iHigh(m_symbol, m_tf, k - 1) + iLow(m_symbol, m_tf, k - 1)) / 2.0;
        averBias += (mc - mp);
        averSizeDif += (sc - sp);
    }
    
    double averSize = sum / count;
    if(count > 1) averBias /= (count - 1);
    if(count > 1) averSizeDif /= (count - 1);
    
    return averSize;
}

//+------------------------------------------------------------------+
double CPatternDetector::CheckPTSlope(int li, int vertices)
{
    if(vertices < 2) return 0;
    
    double upSum = 0, dnSum = 0;
    int upCnt = 0, dnCnt = 0;
    
    for(int v = 1; v < vertices; v++)
    {
        int vi = li + 1 + v * 2;
        if(vi + 1 >= m_ptCount) continue;
        
        double mc = (m_ptPoints[vi].price + m_ptPoints[vi + 1].price) / 2.0;
        double mp = (m_ptPoints[vi - 2].price + m_ptPoints[vi - 1].price) / 2.0;
        
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
    
    if(lastTop + 1 >= m_ptCount || lastBot + 1 >= m_ptCount)
        return PATTERN_SYMMETRICAL_TRI;
    
    double topDiff = m_ptPoints[lastTop].price - m_ptPoints[prevTop].price;
    double botDiff = m_ptPoints[lastBot].price - m_ptPoints[prevBot].price;
    
    if(topDiff >= 0 && botDiff > 0) return PATTERN_ASCEND_TRI;
    if(topDiff <= 0 && botDiff < 0) return PATTERN_DESCEND_TRI;
    
    return PATTERN_SYMMETRICAL_TRI;
}

//+------------------------------------------------------------------+
int CPatternDetector::DetermineRectType(int li, int vertices)
{
    double slope = CheckPTSlope(li, vertices);
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
    
    // Create arrow
    if(m_drawArrow)
    {
        string arrowName = prefix + "A_" + IntegerToString(counter);
        if(ObjectCreate(0, arrowName, OBJ_ARROW, 0, t, price))
        {
            ObjectSet(arrowName, OBJPROP_ARROWCODE, 
                       above ? m_arrowCodeBuy : m_arrowCodeSell);
            ObjectSet(arrowName, OBJPROP_COLOR, c);
            ObjectSet(arrowName, OBJPROP_ANCHOR, 
                       above ? ANCHOR_BOTTOM : ANCHOR_TOP);
            ObjectSet(arrowName, OBJPROP_SELECTABLE, true);
            ObjectSet(arrowName, OBJPROP_HIDDEN, false);
        }
    }
    
    // Create label
    if(m_drawLabel)
    {
        string labelName = prefix + "L_" + IntegerToString(counter++);
        double labelPrice = above ? price + 15 * Point : price - 15 * Point;
        
        if(ObjectCreate(0, labelName, OBJ_TEXT, 0, t, labelPrice))
        {
            ObjectSetText(labelName, txt, m_fontSize, "Arial", c);
            ObjectSet(arrowName, OBJPROP_ANCHOR, 
                       above ? ANCHOR_BOTTOM : ANCHOR_TOP);
            ObjectSet(labelName, OBJPROP_SELECTABLE, true);
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
    if(e >= m_ptCount) return;
    
    string name = "CP12_LN_" + IntegerToString(counter++);
    
    if(ObjectCreate(0, name, OBJ_TREND, 0,
                    m_ptPoints[s].time, m_ptPoints[s].price,
                    m_ptPoints[e].time, m_ptPoints[e].price))
    {
        ObjectSet(name, OBJPROP_COLOR, m_colorLine);
        ObjectSet(name, OBJPROP_WIDTH, 1);
        ObjectSet(name, OBJPROP_STYLE, STYLE_DOT);
        ObjectSet(name, OBJPROP_RAY_RIGHT, false);
        ObjectSet(name, OBJPROP_SELECTABLE, true);
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
               + DoubleToStr(sig.target, 0) + " pts";
    
    Print("[CPattern12-MT4] ", msg);
    
    if(m_soundOn) Alert(msg);
}

//+------------------------------------------------------------------+
#endif // CPATTERN12_MQ4
//+------------------------------------------------------------------+