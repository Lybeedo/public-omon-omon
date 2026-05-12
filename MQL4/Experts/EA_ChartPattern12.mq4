//+------------------------------------------------------------------+
//|                                        EA_ChartPattern12.mq4     |
//+------------------------------------------------------------------+
//| EA Trading 12 Chart Patterns - MT4 Version                       |
//| Version: 1.00                                                    |
//|                                                                      |
//| 12 PATTERNS:                                                      |
//| [1] Bull Flag    [2] Bear Flag    [3] Bullish Pennant            |
//| [4] Bearish Pen  [5] Rising Wedg  [6] Falling Wedge              |
//| [7] Horiz Rect   [8] Ascend Rect  [9] Descend Rect               |
//| [10] Ascend Tri  [11] Descend Tri [12] Symmetrical Triangle      |
//|                                                                      |
//| SETIAP PATTERN PUNYA:                                             |
//|   - WIDTH = jarak terlebar pembentuk pattern (points)             |
//|   - TARGET = flagpole height (points)                             |
//|   - PATTERN BERAKHIR saat BREAKOUT                                |
//+------------------------------------------------------------------+
#property copyright   "EA_ChartPattern12 MT4 v1.0"
#property version      "1.00"
#property strict

#include <CPattern12.mq4>

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
input int       InpTPMode         = 1;            // 0=FIX, 1=DYNAMIC
input double    InpTPFix          = 50;           // TP Fix (points) - aktif jika 0
input double    InpTPMultiplier   = 1.0;          // TP Multiplier (x width) - aktif jika 1

input group "=== STOP LOSS ==="
input int       InpSLMode         = 1;            // 0=FIX, 1=DYNAMIC
input double    InpSLFix          = 30;           // SL Fix (points) - aktif jika 0
input double    InpSLMultiplier   = 1.0;          // SL Multiplier (x width) - aktif jika 1

input group "=== TRAILING STOP ==="
input int       InpTSMode         = 2;            // 0=NONE, 1=FIX, 2=DYNAMIC_PCT
input int       InpTSFixStart     = 100;          // TS Start Fix (points) - aktif jika 1
input int       InpTSFixStop      = 50;           // TS Stop Fix (points)
input double    InpTSActivPct     = 0.50;         // TS Activation (% of width) - aktif jika 2
input double    InpTSStopPct      = 0.50;         // TS Stop (% of width)

input group "=== TRADE MANAGEMENT ==="
input int       InpMaxPositions   = 3;            // Max positions per pattern
input bool      InpOnePatternOnePos = false;      // 1 pos per pattern (no repeat)
input int       InpCooldown       = 0;            // Cooldown after close (bars)
input bool      InpAlertOn         = true;        // Alert on entry

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CPatternDetector g_detector;

datetime        g_lastBarTime     = 0;
int             g_lastBuyBar      = -1;
int             g_lastSellBar     = -1;
datetime        g_lastBuyTime     = 0;
datetime        g_lastSellTime    = 0;

datetime        g_processedTimes[];
int             g_processedCount   = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    if(InpLot < 0.01)       { Print("InpLot minimal 0.01"); return INIT_PARAMETERS_INCORRECT; }
    if(InpTPMultiplier <= 0) { Print("InpTPMultiplier harus > 0"); return INIT_PARAMETERS_INCORRECT; }
    if(InpSLMultiplier <= 0) { Print("InpSLMultiplier harus > 0"); return INIT_PARAMETERS_INCORRECT; }
    if(InpTSStopPct <= 0 || InpTSStopPct > 1) { Print("InpTSStopPct harus 0.01 - 1.0"); return INIT_PARAMETERS_INCORRECT; }
    if(InpMaxPatternID < InpMinPatternID) { Print("InpMaxPatternID >= InpMinPatternID"); return INIT_PARAMETERS_INCORRECT; }
    
    g_detector.Init(_Symbol, _Period);
    g_detector.SetOverlapParams(InpMinOverlap, InpMinBars, InpRectK, InpTaperK, 
                                InpExpK, InpSlopeK, InpMinPole);
    g_detector.SetZZParams(InpPTDepth, InpPTDev, InpMinVert, 
                           InpZZK1, InpZZK2, InpZZK3);
    g_detector.SetDrawParams(false, false, false, Lime, Red, Yellow, DodgerBlue, 9, 233, 234);
    g_detector.SetAlertParams(InpAlertOn, false, 60);
    
    ArrayResize(g_processedTimes, 200);
    
    Print("=== EA_ChartPattern12 MT4 Initialized ===");
    Print("Magic: ", InpMagic, " | Lot: ", InpLot);
    Print("TP Mode: ", InpTPMode, " | SL Mode: ", InpSLMode);
    Print("TS Mode: ", InpTSMode);
    Print("Pattern Range: ", InpMinPatternID, " - ", InpMaxPatternID);
    Print("Allow BUY: ", InpAllowBuy, " | Allow SELL: ", InpAllowSell);
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    g_detector.Release();
    Comment("");
    Print("=== EA_ChartPattern12 MT4 Deinitialized ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
    // New bar check
    datetime currentBar = iTime(_Symbol, _Period, 0);
    if(currentBar == g_lastBarTime) return;
    g_lastBarTime = currentBar;
    
    // Count positions
    int buyCount = CountPositions(OP_BUY);
    int sellCount = CountPositions(OP_SELL);
    
    // Scan patterns
    CPatternSignal signals[];
    ArrayResize(signals, 50);
    int count = 0;
    
    int totalBars = Bars(_Symbol, _Period);
    int startBar = MathMax(0, totalBars - 500);
    int limit = totalBars - 1;
    
    g_detector.Scan(startBar, limit, signals, count);
    
    // Process signals
    for(int i = 0; i < count; i++)
    {
        CPatternSignal &sig = signals[i];
        
        // Filter by pattern ID
        if(sig.patternID < InpMinPatternID || sig.patternID > InpMaxPatternID)
            continue;
        
        // Filter by direction
        if(sig.isBullish && !InpAllowBuy) continue;
        if(!sig.isBullish && !InpAllowSell) continue;
        
        // Cooldown check
        int currBar = Bars(_Symbol, _Period) - 1;
        if(sig.isBullish && g_lastBuyBar >= 0)
            if(currBar - g_lastBuyBar < InpCooldown) continue;
        if(!sig.isBullish && g_lastSellBar >= 0)
            if(currBar - g_lastSellBar < InpCooldown) continue;
        
        // Max positions check
        if(sig.isBullish && buyCount >= InpMaxPositions) continue;
        if(!sig.isBullish && sellCount >= InpMaxPositions) continue;
        
        // One pattern one position
        if(InpOnePatternOnePos && HasPatternPosition(sig.patternID, sig.isBullish))
            continue;
        
        // Already processed this bar?
        if(IsProcessed(sig.time)) continue;
        
        // Open position
        OpenPosition(sig);
        
        // Mark as processed
        AddProcessed(sig.time);
    }
    
    // Trailing stop management
    if(InpTSMode > 0)
        ManageTrailing();
    
    // Display panel
    DisplayPanel(signals, count, buyCount, sellCount);
}

//+------------------------------------------------------------------+
//| Open Position (MT4)                                               |
//+------------------------------------------------------------------+
void OpenPosition(CPatternSignal &sig)
{
    double point = Point;
    double spread = MarketInfo(_Symbol, MODE_SPREAD) * point;
    double ask = Ask;
    double bid = Bid;
    
    double price = sig.isBullish ? ask : bid;
    double lot = InpLot;
    
    double tp = 0, sl = 0;
    
    // Calculate TP
    if(InpTPMode == 0) // FIX
    {
        tp = sig.isBullish ? ask + InpTPFix * point : bid - InpTPFix * point;
    }
    else // DYNAMIC
    {
        double dynTP = sig.width * InpTPMultiplier * point;
        tp = sig.isBullish ? ask + dynTP : bid - dynTP;
    }
    
    // Calculate SL
    if(InpSLMode == 0) // FIX
    {
        sl = sig.isBullish ? ask - InpSLFix * point : bid + InpSLFix * point;
    }
    else // DYNAMIC
    {
        double dynSL = sig.width * InpSLMultiplier * point;
        sl = sig.isBullish ? ask - dynSL : bid + dynSL;
    }
    
    // Safety: SL should be on correct side
    if(sig.isBullish && sl >= ask) sl = 0;
    if(!sig.isBullish && sl <= bid) sl = 0;
    
    // Normalize price
    double normPrice = NormalizeDouble(price, Digits);
    double normTP = NormalizeDouble(tp, Digits);
    double normSL = NormalizeDouble(sl, Digits);
    
    // Comment
    string comment = StringFormat("CP12 [%s] W:%g TP:%s",
                                  sig.patternName, 
                                  sig.width,
                                  InpTPMode == 0 ? DoubleToStr(InpTPFix, 0) : DoubleToStr(InpTPMultiplier, 2) + "x");
    
    int cmd = sig.isBullish ? OP_BUY : OP_SELL;
    
    int ticket = OrderSend(_Symbol, cmd, lot, normPrice, 10, normSL, normTP, comment, InpMagic, 0, 
                           sig.isBullish ? clrBlue : clrRed);
    
    if(ticket > 0)
    {
        Print("=== PATTERN TRADE OPENED ===");
        Print("Pattern  : ", sig.patternName, " [ID=", sig.patternID, "]");
        Print("Direction: ", sig.isBullish ? "BUY" : "SELL");
        Print("Width    : ", sig.width, " points");
        Print("Target   : ", sig.target, " points");
        Print("Lot      : ", lot, " | Price: ", normPrice, " | SL: ", normSL, " | TP: ", normTP);
        Print("Ticket   : ", ticket);
        
        if(sig.isBullish) { g_lastBuyTime = TimeCurrent(); g_lastBuyBar = Bars(_Symbol, _Period) - 1; }
        else { g_lastSellTime = TimeCurrent(); g_lastSellBar = Bars(_Symbol, _Period) - 1; }
        
        if(InpAlertOn)
            Alert(sig.patternName, " ", sig.isBullish ? "BUY" : "SELL", 
                  " | Width: ", DoubleToStr(sig.width, 0), "pt");
    }
    else
    {
        int err = GetLastError();
        Print("ORDER FAILED: Error=", err, " ", ErrorDescription(err));
    }
}

//+------------------------------------------------------------------+
//| Manage Trailing Stop (MT4)                                        |
//+------------------------------------------------------------------+
void ManageTrailing()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if(OrderSymbol() != _Symbol) continue;
        if(OrderMagicNumber() != InpMagic) continue;
        if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
        
        double openPrice = OrderOpenPrice();
        double sl = OrderStopLoss();
        double tp = OrderTakeProfit();
        double point = Point;
        double bid = Bid;
        double ask = Ask;
        
        double profitPts = 0;
        
        if(OrderType() == OP_BUY)
        {
            profitPts = (bid - openPrice) / point;
            
            if(InpTSMode == 1) // FIX
            {
                if(profitPts >= InpTSFixStart)
                {
                    double newSL = bid - InpTSFixStop * point;
                    if(newSL > sl || sl == 0)
                    {
                        bool mod = OrderModify(OrderTicket(), openPrice, newSL, tp, 0, clrNONE);
                        if(!mod) Print("Trail BUY failed: ", GetLastError());
                    }
                }
            }
            else if(InpTSMode == 2) // DYNAMIC_PCT
            {
                double width = GetWidthFromComment(OrderComment());
                if(width <= 0) width = profitPts;
                
                double activationPts = width * InpTSActivPct;
                double stopPts = width * InpTSStopPct;
                
                if(profitPts >= activationPts)
                {
                    double newSL = bid - stopPts * point;
                    if(newSL > sl)
                    {
                        bool mod = OrderModify(OrderTicket(), openPrice, newSL, tp, 0, clrNONE);
                        if(!mod) Print("Trail BUY failed: ", GetLastError());
                    }
                }
            }
        }
        else // OP_SELL
        {
            profitPts = (openPrice - ask) / point;
            
            if(InpTSMode == 1) // FIX
            {
                if(profitPts >= InpTSFixStart)
                {
                    double newSL = ask + InpTSFixStop * point;
                    if(newSL < sl || sl == 0)
                    {
                        bool mod = OrderModify(OrderTicket(), openPrice, newSL, tp, 0, clrNONE);
                        if(!mod) Print("Trail SELL failed: ", GetLastError());
                    }
                }
            }
            else if(InpTSMode == 2) // DYNAMIC_PCT
            {
                double width = GetWidthFromComment(OrderComment());
                if(width <= 0) width = profitPts;
                
                double activationPts = width * InpTSActivPct;
                double stopPts = width * InpTSStopPct;
                
                if(profitPts >= activationPts)
                {
                    double newSL = ask + stopPts * point;
                    if(newSL < sl || sl == 0)
                    {
                        bool mod = OrderModify(OrderTicket(), openPrice, newSL, tp, 0, clrNONE);
                        if(!mod) Print("Trail SELL failed: ", GetLastError());
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Get pattern width from comment                                    |
//+------------------------------------------------------------------+
double GetWidthFromComment(string comment)
{
    int pos = StringFind(comment, "W:");
    if(pos >= 0)
    {
        string numStr = StringSubstr(comment, pos + 2, 10);
        double val = StrToDouble(numStr);
        if(val > 0) return val;
    }
    return 0;
}

//+------------------------------------------------------------------+
//| Count Positions                                                    |
//+------------------------------------------------------------------+
int CountPositions(int type)
{
    int cnt = 0;
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if(OrderSymbol() != _Symbol) continue;
        if(OrderMagicNumber() != InpMagic) continue;
        if(OrderType() == type) cnt++;
    }
    return cnt;
}

//+------------------------------------------------------------------+
//| Check if pattern has position                                     |
//+------------------------------------------------------------------+
bool HasPatternPosition(int patternID, bool isBullish)
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if(OrderSymbol() != _Symbol) continue;
        if(OrderMagicNumber() != InpMagic) continue;
        if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
        
        string comment = OrderComment();
        if(StringFind(comment, "CP12 [") >= 0)
        {
            if(isBullish && OrderType() == OP_BUY) return true;
            if(!isBullish && OrderType() == OP_SELL) return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Processed pattern tracking                                         |
//+------------------------------------------------------------------+
bool IsProcessed(datetime time)
{
    for(int i = 0; i < g_processedCount; i++)
    {
        if(g_processedTimes[i] == time) return true;
    }
    return false;
}

void AddProcessed(datetime time)
{
    if(g_processedCount >= ArraySize(g_processedTimes))
    {
        for(int i = 0; i < 50; i++)
            g_processedTimes[i] = g_processedTimes[i + 50];
        g_processedCount -= 50;
    }
    g_processedTimes[g_processedCount++] = time;
}

//+------------------------------------------------------------------+
//| Display Panel (MT4)                                               |
//+------------------------------------------------------------------+
void DisplayPanel(CPatternSignal &signals[], int count, int buyCnt, int sellCnt)
{
    string txt = "";
    txt = txt + "================================================\n";
    txt = txt + "   EA_ChartPattern12 MT4  |  v1.00\n";
    txt = txt + "================================================\n";
    txt = txt + "Symbol    : " + _Symbol + "\n";
    txt = txt + "Timeframe : " + GetPeriodName(_Period) + "\n";
    txt = txt + "----------------------------------------------\n";
    txt = txt + "POSISI TERBUKA:\n";
    txt = txt + "  BUY  : " + IntegerToString(buyCnt) + " posisi\n";
    txt = txt + "  SELL : " + IntegerToString(sellCnt) + " posisi\n";
    txt = txt + "  TOTAL: " + IntegerToString(buyCnt + sellCnt) + " posisi\n";
    txt = txt + "----------------------------------------------\n";
    txt = txt + "PATTERN DETECTED: " + IntegerToString(count) + "x\n";
    txt = txt + "----------------------------------------------\n";
    txt = txt + "SETTINGS:\n";
    txt = txt + "  TP Mode  : " + (InpTPMode == 0 ? "FIX " + DoubleToStr(InpTPFix, 0) + "pt" : "DYNAMIC " + DoubleToStr(InpTPMultiplier, 2) + "x width") + "\n";
    txt = txt + "  SL Mode  : " + (InpSLMode == 0 ? "FIX " + DoubleToStr(InpSLFix, 0) + "pt" : "DYNAMIC " + DoubleToStr(InpSLMultiplier, 2) + "x width") + "\n";
    txt = txt + "  TS Mode  : ";
    if(InpTSMode == 0) txt = txt + "OFF\n";
    else if(InpTSMode == 1) txt = txt + "FIX " + IntegerToString(InpTSFixStart) + "/" + IntegerToString(InpTSFixStop) + "pt\n";
    else txt = txt + "DYNAMIC " + DoubleToStr(InpTSActivPct * 100, 0) + "%/" + DoubleToStr(InpTSStopPct * 100, 0) + "%\n";
    txt = txt + "  Pattern  : " + IntegerToString(InpMinPatternID) + " - " + IntegerToString(InpMaxPatternID) + "\n";
    txt = txt + "  Lot      : " + DoubleToStr(InpLot, 2) + "\n";
    txt = txt + "  Max Pos  : " + IntegerToString(InpMaxPositions) + "\n";
    txt = txt + "================================================\n";
    
    Comment(txt);
}

//+------------------------------------------------------------------+
//| Get period name                                                   |
//+------------------------------------------------------------------+
string GetPeriodName(int period)
{
    switch(period)
    {
        case PERIOD_M1: return "M1";
        case PERIOD_M5: return "M5";
        case PERIOD_M15: return "M15";
        case PERIOD_M30: return "M30";
        case PERIOD_H1: return "H1";
        case PERIOD_H4: return "H4";
        case PERIOD_D1: return "D1";
        case PERIOD_W1: return "W1";
        case PERIOD_MN1: return "MN1";
        default: return "M" + IntegerToString(period);
    }
}
//+------------------------------------------------------------------+