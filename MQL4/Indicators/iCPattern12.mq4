//+------------------------------------------------------------------+
//|                                       iCPattern12.mq4          |
//+------------------------------------------------------------------+
//| Chart Pattern 12 Indicator - MT4 Version                           |
//| Uses CPattern12.mq4 library                                       |
//+------------------------------------------------------------------+
#property copyright   "iCPattern12 v1.0 - MT4"
#property version      "1.00"
#property indicator_chart_window

#include <CPattern12.mq4>

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== PATTERN FILTER ==="
input int      InpMinPatternID = 0;   // Min pattern ID (0=all, 1-12 specific)
input int      InpMaxPatternID = 12;  // Max pattern ID (0=all)
input bool     InpBullOnly     = false; // BUY signals only
input bool     InpBearOnly     = false; // SELL signals only

input group "=== BAR OVERLAP PARAMETERS ==="
input int      InpMinBars    = 5;       // Min bars consolidation
input double   InpMinOverlap = 0.40;    // Min overlap ratio (0-1)
input double   InpRectK      = 0.33;    // Flag rectangular tolerance
input double   InpTaperK     = 0.05;    // Pennant tolerance
input double   InpExpK       = 0.05;    // Wedge tolerance
input double   InpSlopeK     = 0.10;    // Slope bias tolerance
input double   InpMinPole    = 1.5;     // Min flagpole (x base)

input group "=== PEAK-TROUGH PARAMETERS ==="
input int      InpPTDepth    = 12;      // Peak/Trough depth
input int      InpPTDev      = 5;       // Deviation filter
input int      InpMinVert    = 2;       // Min vertices (N)
input double   InpZZK1       = 1.5;     // Flagpole ratio
input double   InpZZK2       = 0.25;    // Parallelism tolerance
input double   InpZZK3       = 0.25;    // Slope tolerance

input group "=== DISPLAY ==="
input color    InpBuyColor   = Lime;      // BUY arrow color
input color    InpSellColor  = Red;       // SELL arrow color
input color    InpLabelColor = Yellow;    // Label color
input color    InpLineColor  = DodgerBlue; // Line color
input int      InpFontSize   = 9;         // Label font size
input int      InpArrowBuy   = 233;       // Arrow code BUY
input int      InpArrowSell  = 234;       // Arrow code SELL
input bool     InpShowLabel  = true;      // Show distance label
input bool     InpShowLine   = false;     // Show pattern boundary lines

input group "=== ALERT ==="
input bool     InpAlertOn    = true;      // Enable alerts
input bool     InpAlertSound = true;      // Play sound
input int      InpAlertCool  = 60;        // Alert cooldown (sec)
input int      InpHistory    = 500;       // Bars to analyze

//+------------------------------------------------------------------+
//| Global instances                                                 |
//+------------------------------------------------------------------+
CPatternDetector g_detector;
datetime g_lastBarTime = 0;

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    g_detector.Init(_Symbol, _Period);
    
    g_detector.SetOverlapParams(InpMinOverlap, InpMinBars, 
                                 InpRectK, InpTaperK, InpExpK, 
                                 InpSlopeK, InpMinPole);
    g_detector.SetZZParams(InpPTDepth, InpPTDev,
                            InpMinVert, InpZZK1, InpZZK2, InpZZK3);
    g_detector.SetDrawParams(true, InpShowLabel, InpShowLine,
                              InpBuyColor, InpSellColor, InpLabelColor,
                              InpLineColor, InpFontSize, InpArrowBuy, InpArrowSell);
    g_detector.SetAlertParams(InpAlertOn, InpAlertSound, InpAlertCool);
    
    Comment("");
    
    Print("=== iCPattern12 MT4 Initialized ===");
    Print("Patterns: Bull/Bear Flag, Pennant, Wedge, Rectangle, Triangle");
    Print("Peak-Trough: depth=", InpPTDepth, " dev=", InpPTDev);
    Print("Bar Overlap: minBars=", InpMinBars, " minOverlap=", InpMinOverlap);
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Deinitialization                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    g_detector.Release();
    Comment("");
    Print("=== iCPattern12 MT4 Deinitialized ===");
}

//+------------------------------------------------------------------+
//| Main tick handler                                                |
//+------------------------------------------------------------------+
void OnTick()
{
    // Avoid processing same bar multiple times
    datetime currentBar = iTime(_Symbol, _Period, 0);
    if(currentBar == g_lastBarTime) return;
    g_lastBarTime = currentBar;
    
    int totalBars = Bars(_Symbol, _Period);
    int startBar = MathMax(0, totalBars - InpHistory);
    int limit = totalBars - 1;
    
    // Array untuk sinyal
    CPatternSignal signals[];
    ArrayResize(signals, 50);
    int count = 0;
    
    // Scan patterns
    g_detector.Scan(startBar, limit, signals, count);
    
    // Display info panel
    DisplayPanel(signals, count);
    
    // Log detected patterns
    for(int i = 0; i < count; i++)
    {
        CPatternSignal &sig = signals[i];
        
        if(InpMinPatternID > 0 && sig.patternID < InpMinPatternID) continue;
        if(InpMaxPatternID > 0 && sig.patternID > InpMaxPatternID) continue;
        if(InpBullOnly && !sig.isBullish) continue;
        if(InpBearOnly && sig.isBullish) continue;
        
        // Create visual objects
        CreateSignalObjects(sig);
    }
}

//+------------------------------------------------------------------+
//| Create signal visual objects                                     |
//+------------------------------------------------------------------+
void CreateSignalObjects(CPatternSignal &sig)
{
    string prefix = "CP12_";
    static int counter = 0;
    
    string dir = sig.isBullish ? "BUY" : "SELL";
    string distTxt = DoubleToStr(sig.target, 0) + "pt";
    string fullTxt = sig.patternName + " (" + distTxt + ")";
    
    color arrColor = sig.isBullish ? InpBuyColor : InpSellColor;
    int arrowCode = sig.isBullish ? InpArrowBuy : InpArrowSell;
    
    // Create arrow
    if(InpShowLabel || true)
    {
        string arrowName = prefix + "A_" + IntegerToString(counter);
        if(ObjectCreate(arrowName, OBJ_ARROW, 0, sig.time, sig.price))
        {
            ObjectSet(arrowName, OBJPROP_ARROWCODE, arrowCode);
            ObjectSet(arrowName, OBJPROP_COLOR, arrColor);
            ObjectSet(arrowName, OBJPROP_WIDTH, 2);
            ObjectSet(arrowName, OBJPROP_SELECTABLE, true);
            ObjectSet(arrowName, OBJPROP_HIDDEN, false);
        }
        
        // Create label
        if(InpShowLabel)
        {
            string labelName = prefix + "L_" + IntegerToString(counter++);
            double labelPrice = sig.isBullish 
                ? sig.price - 20 * Point 
                : sig.price + 20 * Point;
                
            if(ObjectCreate(labelName, OBJ_TEXT, 0, sig.time, labelPrice))
            {
                ObjectSetText(labelName, fullTxt, InpFontSize, "Arial", InpLabelColor);
                ObjectSet(labelName, OBJPROP_SELECTABLE, true);
            }
        }
    }
    
    // Create pattern line
    if(InpShowLine && sig.startBar >= 0)
    {
        string lineName = prefix + "LN_" + IntegerToString(counter++);
        double price1 = iHigh(_Symbol, _Period, sig.startBar);
        double price2 = sig.price;
        datetime time1 = iTime(_Symbol, _Period, sig.startBar);
        
        if(ObjectCreate(lineName, OBJ_TREND, 0, time1, price1, sig.time, price2))
        {
            ObjectSet(lineName, OBJPROP_COLOR, InpLineColor);
            ObjectSet(lineName, OBJPROP_WIDTH, 1);
            ObjectSet(lineName, OBJPROP_STYLE, STYLE_DOT);
            ObjectSet(lineName, OBJPROP_RAY_RIGHT, false);
            ObjectSet(lineName, OBJPROP_SELECTABLE, true);
        }
    }
}

//+------------------------------------------------------------------+
//| Display info panel                                                |
//+------------------------------------------------------------------+
void DisplayPanel(CPatternSignal &signals[], int count)
{
    string txt = "";
    txt = txt + "===========================================\n";
    txt = txt + "    iCPattern12 MT4 - Chart Pattern 12\n";
    txt = txt + "===========================================\n";
    txt = txt + "Symbol   : " + _Symbol + "\n";
    txt = txt + "Timeframe: " + GetPeriodName(_Period) + "\n";
    txt = txt + "-----------------------------------------\n";
    txt = txt + "Patterns detected: " + IntegerToString(count) + "\n";
    
    int bullCnt = 0, bearCnt = 0;
    for(int i = 0; i < count; i++)
    {
        if(signals[i].isBullish) bullCnt++;
        else bearCnt++;
    }
    
    txt = txt + "BUY signals : " + IntegerToString(bullCnt) + "\n";
    txt = txt + "SELL signals: " + IntegerToString(bearCnt) + "\n";
    txt = txt + "-----------------------------------------\n";
    txt = txt + "Pattern List:\n";
    
    for(int i = 0; i < MathMin(count, 10); i++)
    {
        string dir = signals[i].isBullish ? "[BUY]" : "[SELL]";
        txt = txt + "  " + IntegerToString(i + 1) + ". " 
            + signals[i].patternName + " " + dir + "\n";
        txt = txt + "     Distance: " + DoubleToStr(signals[i].target, 0) + "pts\n";
    }
    
    if(count > 10) txt = txt + "  ... and " + IntegerToString(count - 10) + " more\n";
    
    txt = txt + "===========================================\n";
    txt = txt + "MinBars: " + IntegerToString(InpMinBars);
    txt = txt + " | MinOverlap: " + DoubleToStr(InpMinOverlap, 2) + "\n";
    txt = txt + "PT Depth: " + IntegerToString(InpPTDepth) + "\n";
    
    Comment(txt);
}

//+------------------------------------------------------------------+
//| Helper: Get period name                                          |
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
//| Chart event - click to delete objects                            |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
{
    if(id == CHARTEVENT_OBJECT_CLICK)
    {
        if(StringFind(sparam, "CP12_") == 0)
        {
            ObjectDelete(sparam);
        }
    }
}
//+------------------------------------------------------------------+