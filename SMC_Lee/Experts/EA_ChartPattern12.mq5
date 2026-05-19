//+------------------------------------------------------------------+
//|                                          EA_ChartPattern12.mq5    |
//+------------------------------------------------------------------+
//| EA Trading 12 Chart Patterns                                     |
//| Version: 1.00                                                    |
//|                                                                      |
//| 12 PATTERNS:                                                      |
//| [1] Bull Flag   [7] Bear Flag   [13] Bullish Pennant [19] Bearish |
//| [25] Rising Wedge [31] Falling Wedge [37] Horizontal Rectangle    |
//| [43] Ascending Rect [49] Descending Rect [55] Ascending Triangle  |
//| [61] Descending Triangle [67] Symmetrical Triangle               |
//|                                                                      |
//| SETIAP PATTERN Punya:                                             |
//|   - WIDTH = jarak terlebar pembentuk pattern (points)             |
//|   - TARGET = flagpole height (points)                             |
//|   - PATTERN BERAKHIR saat BREAKOUT                                |
//+------------------------------------------------------------------+
#property copyright   "EA_ChartPattern12 v1.0"
#property version      "1.00"
#property icon        ""
#property strict

#include <Trade/Trade.mqh>
#include <CPattern12.mqh>

//+------------------------------------------------------------------+
//| INPUT - GLOBAL                                                    |
//+------------------------------------------------------------------+
input group "=== GLOBAL ==="
input long      InpMagic          = 20250512;    // Magic Number
input bool      InpAllowBuy       = true;        // Allow BUY trades
input bool      InpAllowSell      = true;        // Allow SELL trades
input double    InpLot            = 0.01;        // Lot Size

input group "=== PATTERN FILTER ==="
input int       InpMinPatternID   = 1;            // Min pattern ID (0=all, 1-12)
input int       InpMaxPatternID   = 12;           // Max pattern ID (1-12)
input ENUM_TIMEFRAMES InpTF        = PERIOD_CURRENT; // Timeframe

input group "=== BAR OVERLAP (Flag/Pennant/Wedge) ==="
input int       InpMinBars        = 5;            // Min bars consolidation
input double    InpMinOverlap     = 0.40;         // Min overlap ratio
input double    InpRectK          = 0.33;         // Rectangular tolerance
input double    InpTaperK         = 0.05;         // Pennant tolerance
input double    InpExpK          = 0.05;         // Wedge tolerance
input double    InpSlopeK         = 0.10;         // Slope bias
input double    InpMinPole        = 1.5;          // Min flagpole ratio

input group "=== PEAK-TROUGH (Rectangle/Triangle) ==="
input int       InpPTDepth        = 12;           // Peak/Trough depth
input int       InpPTDev          = 5;            // Deviation
input int       InpMinVert        = 2;            // Min vertices
input double    InpZZK1           = 1.5;          // Flagpole ratio
input double    InpZZK2           = 0.25;         // Parallelism tol
input double    InpZZK3           = 0.25;         // Slope tol

input group "=== TAKE PROFIT ==="
input ENUM_TP_MODE InpTPMode      = TP_DYNAMIC;   // TP Mode
input double    InpTPFix          = 50;           // TP Fix (points) - aktif jika FIX
input double    InpTPMultiplier   = 1.0;          // TP Multiplier (x width) - aktif jika DYNAMIC

input group "=== STOP LOSS ==="
input ENUM_SL_MODE InpSLMode      = SL_DYNAMIC;   // SL Mode
input double    InpSLFix          = 30;           // SL Fix (points) - aktif jika FIX
input double    InpSLMultiplier   = 1.0;          // SL Multiplier (x width) - aktif jika DYNAMIC

input group "=== TRAILING STOP ==="
input ENUM_TS_MODE InpTSMode      = TS_DYNAMIC_PCT;// TS Mode
input int       InpTSFixStart     = 100;          // TS Start Fix (points)
input int       InpTSFixStop      = 50;           // TS Stop Fix (points)
input double    InpTSActivPct     = 0.50;         // TS Activation (% of width) - aktif jika DYNAMIC_PCT
input double    InpTSStopPct      = 0.50;         // TS Stop (% of width) - aktif jika DYNAMIC_PCT

input group "=== TRADE MANAGEMENT ==="
input int       InpMaxPositions   = 3;            // Max positions per pattern
input bool      InpOnePatternOnePos = false;      // 1 pos per pattern (no repeat)
input int       InpCooldown       = 0;            // Cooldown after close (bars)
input bool      InpAlertOn         = true;        // Alert on entry
input color     InpArrowBuy        = clrLime;      // Arrow color BUY
input color     InpArrowSell       = clrRed;       // Arrow color SELL

//+------------------------------------------------------------------+
//| Enumerations                                                      |
//+------------------------------------------------------------------+
enum ENUM_TP_MODE
{
    TP_FIX,        // Fix pips
    TP_DYNAMIC      // Dynamic: multiplier x pattern width
};

enum ENUM_SL_MODE
{
    SL_FIX,         // Fix pips
    SL_DYNAMIC      // Dynamic: multiplier x pattern width
};

enum ENUM_TS_MODE
{
    TS_NONE,        // No trailing
    TS_FIX,         // Fix: start/stop points
    TS_DYNAMIC_PCT  // Dynamic: % of pattern width
};

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade          g_trade;
CPatternDetector g_detector;

datetime        g_lastBarTime     = 0;
datetime        g_lastBuyTime     = 0;
datetime        g_lastSellTime    = 0;

int             g_lastBuyBar      = -1;
int             g_lastSellBar     = -1;

int             g_hZZ;             // ZigZag handle

int             g_processedPatterns[];
int             g_patternCounter  = 0;

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
    // Validate
    if(InpLot < 0.01)          { Print("InpLot minimal 0.01"); return INIT_PARAMETERS_INCORRECT; }
    if(InpTPMultiplier <= 0)  { Print("InpTPMultiplier harus > 0"); return INIT_PARAMETERS_INCORRECT; }
    if(InpSLMultiplier <= 0)  { Print("InpSLMultiplier harus > 0"); return INIT_PARAMETERS_INCORRECT; }
    if(InpTSStopPct <= 0 || InpTSStopPct > 1) { Print("InpTSStopPct harus 0.01 - 1.0"); return INIT_PARAMETERS_INCORRECT; }
    if(InpMaxPatternID < InpMinPatternID) { Print("InpMaxPatternID harus >= InpMinPatternID"); return INIT_PARAMETERS_INCORRECT; }
    
    // Init trade
    g_trade.SetExpertMagicNumber(InpMagic);
    g_trade.SetDeviationInPoints(10);
    g_trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    // Init pattern detector
    g_detector.Init(_Symbol, InpTF);
    g_detector.SetOverlapParams(InpMinOverlap, InpMinBars, InpRectK, InpTaperK, 
                                InpExpK, InpSlopeK, InpMinPole);
    g_detector.SetZZParams(InpPTDepth, InpPTDev, 3, InpMinVert, 
                           InpZZK1, InpZZK2, InpZZK3);
    g_detector.SetDrawParams(false, false, false, InpArrowBuy, InpArrowSell,
                             clrYellow, clrDodgerBlue, 9, 233, 234);
    g_detector.SetAlertParams(InpAlertOn, false, 60);
    
    // Resize processed patterns array
    ArrayResize(g_processedPatterns, 100);
    
    Print("=== EA_ChartPattern12 Initialized ===");
    Print("Magic: ", InpMagic, " | Lot: ", InpLot);
    Print("TP Mode: ", EnumToString(InpTPMode), " | SL Mode: ", EnumToString(InpSLMode));
    Print("TS Mode: ", EnumToString(InpTSMode));
    Print("Pattern Range: ", InpMinPatternID, " - ", InpMaxPatternID);
    Print("Allow BUY: ", InpAllowBuy, " | Allow SELL: ", InpAllowSell);
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    g_detector.Release();
    Comment("");
    Print("=== EA_ChartPattern12 Deinitialized ===");
}

//+------------------------------------------------------------------+
//| OnTick                                                            |
//+------------------------------------------------------------------+
void OnTick()
{
    // New bar check
    datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(currentBar == g_lastBarTime) return;
    g_lastBarTime = currentBar;
    
    // Count our positions
    int buyCount = CountPositions(POSITION_TYPE_BUY);
    int sellCount = CountPositions(POSITION_TYPE_SELL);
    
    // Scan patterns
    CPatternSignal signals[];
    ArrayResize(signals, 50);
    int count = 0;
    
    int totalBars = Bars(_Symbol, PERIOD_CURRENT);
    int startBar = MathMax(0, totalBars - 500);
    int limit = totalBars - 1;
    
    g_detector.Scan(startBar, limit, signals, count);
    
    // Process each signal
    for(int i = 0; i < count; i++)
    {
        CPatternSignal &sig = signals[i];
        
        // Filter by pattern ID range
        if(sig.patternID < InpMinPatternID || sig.patternID > InpMaxPatternID)
            continue;
        
        // Filter by direction
        if(sig.isBullish && !InpAllowBuy) continue;
        if(!sig.isBullish && !InpAllowSell) continue;
        
        // Check cooldown
        if(sig.isBullish && g_lastBuyBar > 0)
        {
            int barsSince = totalBars - 1 - g_lastBuyBar;
            if(barsSince < InpCooldown) continue;
        }
        if(!sig.isBullish && g_lastSellBar > 0)
        {
            int barsSince = totalBars - 1 - g_lastSellBar;
            if(barsSince < InpCooldown) continue;
        }
        
        // Check max positions
        if(sig.isBullish && buyCount >= InpMaxPositions) continue;
        if(!sig.isBullish && sellCount >= InpMaxPositions) continue;
        
        // One pattern one position
        if(InpOnePatternOnePos && HasPatternPosition(sig.patternID, sig.isBullish))
            continue;
        
        // Check if pattern is already processed on this bar
        if(IsPatternProcessed(sig.time, sig.isBullish)) continue;
        
        // === OPEN POSITION ===
        OpenPosition(sig);
        
        // Mark as processed
        AddProcessedPattern(sig.time, sig.isBullish);
    }
    
    // Manage trailing stop for all positions
    if(InpTSMode != TS_NONE)
        ManageTrailing();
    
    // Display panel
    DisplayPanel(signals, count, buyCount, sellCount);
}

//+------------------------------------------------------------------+
//| Open Position                                                     |
//+------------------------------------------------------------------+
void OpenPosition(CPatternSignal &sig)
{
    double price, sl, tp;
    double width = sig.width * _Point;    // Pattern width in price
    double point = _Point;
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    double lot = InpLot;
    
    ENUM_ORDER_TYPE type = sig.isBullish ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    
    // Calculate TP
    if(InpTPMode == TP_FIX)
    {
        tp = sig.isBullish ? ask + InpTPFix * point : bid - InpTPFix * point;
    }
    else // TP_DYNAMIC
    {
        double dynamicTP = sig.target * InpTPMultiplier * point;
        tp = sig.isBullish ? ask + dynamicTP : bid - dynamicTP;
    }
    
    // Calculate SL
    if(InpSLMode == SL_FIX)
    {
        sl = sig.isBullish ? ask - InpSLFix * point : bid + InpSLFix * point;
    }
    else // SL_DYNAMIC
    {
        double dynamicSL = sig.width * InpSLMultiplier * point;
        sl = sig.isBullish ? ask - dynamicSL : bid + dynamicSL;
    }
    
    // For BUY: SL should be below entry
    // For SELL: SL should be above entry
    if(sig.isBullish && sl >= ask) sl = 0;
    if(!sig.isBullish && sl <= bid) sl = 0;
    
    price = sig.isBullish ? ask : bid;
    
    string comment = StringFormat("CP12 [%s] W:%0.f TP:%s",
                                  sig.patternName, 
                                  sig.width,
                                  InpTPMode == TP_FIX ? 
                                      DoubleToString(InpTPFix, 0) : 
                                      DoubleToString(InpTPMultiplier, 2) + "x");
    
    bool result;
    if(sig.isBullish)
        result = g_trade.Buy(lot, _Symbol, price, sl, tp, comment);
    else
        result = g_trade.Sell(lot, _Symbol, price, sl, tp, comment);
    
    if(result)
    {
        ulong ticket = g_trade.ResultOrder();
        Print("=== PATTERN TRADE OPENED ===");
        Print("Pattern  : ", sig.patternName, " [ID=", sig.patternID, "]");
        Print("Direction: ", sig.isBullish ? "BUY" : "SELL");
        Print("Width    : ", sig.width, " points (", sig.width * _Point, " price)");
        Print("Target   : ", sig.target, " points");
        Print("Lot      : ", lot, " | Price: ", price, " | SL: ", sl, " | TP: ", tp);
        Print("Ticket   : ", ticket);
        
        if(sig.isBullish) { g_lastBuyTime = TimeCurrent(); g_lastBuyBar = Bars(_Symbol, PERIOD_CURRENT) - 1; }
        else { g_lastSellTime = TimeCurrent(); g_lastSellBar = Bars(_Symbol, PERIOD_CURRENT) - 1; }
        
        if(InpAlertOn)
            Alert(sig.patternName, " ", sig.isBullish ? "BUY" : "SELL", 
                  " | Width: ", DoubleToString(sig.width, 0), "pt");
    }
    else
    {
        Print("ORDER FAILED: ", g_trade.ResultRetCodeDescription());
    }
}

//+------------------------------------------------------------------+
//| Manage Trailing Stop                                              |
//+------------------------------------------------------------------+
void ManageTrailing()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) != _Symbol) continue;
        if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
        
        ulong ticket = PositionGetTicket(i);
        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double sl = PositionGetDouble(POSITION_SL);
        double tp = PositionGetDouble(POSITION_TP);
        double profitPts = 0;
        
        double point = _Point;
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        
        if(type == POSITION_TYPE_BUY)
        {
            profitPts = (bid - openPrice) / point;
            
            if(InpTSMode == TS_FIX)
            {
                // Fix trailing: start at X pips profit, move SL to Y pips behind
                if(profitPts >= InpTSFixStart)
                {
                    double newSL = bid - InpTSFixStop * point;
                    if(newSL > sl)
                    {
                        g_trade.PositionModify(ticket, newSL, tp);
                    }
                }
            }
            else if(InpTSMode == TS_DYNAMIC_PCT)
            {
                // Dynamic: get pattern width from comment
                double width = GetPatternWidthFromComment(PositionGetString(POSITION_COMMENT));
                if(width <= 0) width = profitPts; // fallback
                
                double activationPts = width * InpTSActivPct;
                double stopPts = width * InpTSStopPct;
                
                if(profitPts >= activationPts)
                {
                    double newSL = bid - stopPts * point;
                    if(newSL > sl)
                    {
                        g_trade.PositionModify(ticket, newSL, tp);
                    }
                }
            }
        }
        else // SELL
        {
            profitPts = (openPrice - ask) / point;
            
            if(InpTSMode == TS_FIX)
            {
                if(profitPts >= InpTSFixStart)
                {
                    double newSL = ask + InpTSFixStop * point;
                    if(newSL < sl || sl == 0)
                    {
                        g_trade.PositionModify(ticket, newSL, tp);
                    }
                }
            }
            else if(InpTSMode == TS_DYNAMIC_PCT)
            {
                double width = GetPatternWidthFromComment(PositionGetString(POSITION_COMMENT));
                if(width <= 0) width = profitPts;
                
                double activationPts = width * InpTSActivPct;
                double stopPts = width * InpTSStopPct;
                
                if(profitPts >= activationPts)
                {
                    double newSL = ask + stopPts * point;
                    if(newSL < sl || sl == 0)
                    {
                        g_trade.PositionModify(ticket, newSL, tp);
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Get pattern width from comment (for dynamic trailing)             |
//+------------------------------------------------------------------+
double GetPatternWidthFromComment(string comment)
{
    // Comment format: "CP12 [PatternName] W:XX.XX TP:..."
    // Extract "W:" value
    int pos = StringFind(comment, "W:");
    if(pos >= 0)
    {
        string numStr = StringSubstr(comment, pos + 2, 10);
        double val;
        if(StringToDouble(numStr, val))
            return val;
    }
    return 0;
}

//+------------------------------------------------------------------+
//| Count Positions                                                   |
//+------------------------------------------------------------------+
int CountPositions(ENUM_POSITION_TYPE type)
{
    int cnt = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) != _Symbol) continue;
        if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
        if(PositionGetInteger(POSITION_TYPE) == type) cnt++;
    }
    return cnt;
}

//+------------------------------------------------------------------+
//| Check if pattern already has position                             |
//+------------------------------------------------------------------+
bool HasPatternPosition(int patternID, bool isBullish)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) != _Symbol) continue;
        if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
        
        string comment = PositionGetString(POSITION_COMMENT);
        if(StringFind(comment, "CP12 [") >= 0)
        {
            if(isBullish && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) return true;
            if(!isBullish && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Pattern processed tracking                                        |
//+------------------------------------------------------------------+
bool IsPatternProcessed(datetime time, bool isBullish)
{
    for(int i = 0; i < g_patternCounter; i++)
    {
        if(g_processedPatterns[i] == time)
            return true;
    }
    return false;
}

void AddProcessedPattern(datetime time, bool isBullish)
{
    if(g_patternCounter >= ArraySize(g_processedPatterns))
    {
        ArrayResize(g_processedPatterns, g_patternCounter + 50);
    }
    g_processedPatterns[g_patternCounter++] = (int)time;
    
    // Keep only last 100 processed
    if(g_patternCounter > 100)
    {
        for(int i = 0; i < 50; i++)
            g_processedPatterns[i] = g_processedPatterns[i + 50];
        g_patternCounter -= 50;
    }
}

//+------------------------------------------------------------------+
//| Display Panel                                                     |
//+------------------------------------------------------------------+
void DisplayPanel(CPatternSignal &signals[], int count, int buyCnt, int sellCnt)
{
    string txt = "";
    txt += "================================================\n";
    txt += "     EA_ChartPattern12  |  v1.00\n";
    txt += "================================================\n";
    txt += "Symbol    : " + _Symbol + "\n";
    txt += "Timeframe : " + EnumToString(_Period) + "\n";
    txt += "----------------------------------------------\n";
    txt += "POSISI TERBUKA:\n";
    txt += "  BUY  : " + IntegerToString(buyCnt) + " posisi\n";
    txt += "  SELL : " + IntegerToString(sellCnt) + " posisi\n";
    txt += "  TOTAL: " + IntegerToString(buyCnt + sellCnt) + " posisi\n";
    txt += "----------------------------------------------\n";
    txt += "PATTERN DETECTED: " + IntegerToString(count) + "x\n";
    txt += "  (last scan)\n";
    txt += "----------------------------------------------\n";
    txt += "SETTINGS:\n";
    txt += "  TP Mode  : " + (InpTPMode == TP_FIX ? 
                 "FIX " + DoubleToString(InpTPFix, 0) + "pt" : 
                 "DYNAMIC " + DoubleToString(InpTPMultiplier, 2) + "x width") + "\n";
    txt += "  SL Mode  : " + (InpSLMode == SL_FIX ? 
                 "FIX " + DoubleToString(InpSLFix, 0) + "pt" : 
                 "DYNAMIC " + DoubleToString(InpSLMultiplier, 2) + "x width") + "\n";
    txt += "  TS Mode  : ";
    if(InpTSMode == TS_NONE) txt += "OFF\n";
    else if(InpTSMode == TS_FIX) txt += "FIX " + IntegerToString(InpTSFixStart) + "/" + IntegerToString(InpTSFixStop) + "pt\n";
    else txt += "DYNAMIC " + DoubleToString(InpTSActivPct * 100, 0) + "%/" + DoubleToString(InpTSStopPct * 100, 0) + "%\n";
    txt += "  Pattern  : " + IntegerToString(InpMinPatternID) + " - " + IntegerToString(InpMaxPatternID) + "\n";
    txt += "  Lot      : " + DoubleToString(InpLot, 2) + "\n";
    txt += "  Max Pos  : " + IntegerToString(InpMaxPositions) + "\n";
    txt += "================================================\n";
    
    Comment(txt);
}

//+------------------------------------------------------------------+
//| Chart Event                                                       |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, 
                  const double &dparam, const string &sparam)
{
    // Future expansion
}
//+------------------------------------------------------------------+