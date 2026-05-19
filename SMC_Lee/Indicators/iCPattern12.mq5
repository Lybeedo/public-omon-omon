//+------------------------------------------------------------------+
//|                                          iCPattern12.mq5        |
//+------------------------------------------------------------------+
//| Chart Pattern 12 Indicator                                        |
//| Uses CPattern12.mqh library                                       |
//|                                                                      |
//| BUFFERS:                                                           |
//|   [0] BuyArrow  - Arrow UP pada breakout BUY                       |
//|   [1] SellArrow - Arrow DOWN pada breakout SELL                    |
//|   [2] BuyLabel  - Label jarak pattern BUY                           |
//|   [3] SellLabel - Label jarak pattern SELL                          |
//+------------------------------------------------------------------+
#property copyright   "iCPattern12 v1.0"
#property version      "1.00"
#property indicator_chart_window
#property indicator_plots   4
#property strict

#include <CPattern12.mqh>

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

input group "=== ZIGZAG PARAMETERS ==="
input int      InpZZDepth    = 12;      // ZigZag depth
input int      InpZZDev      = 5;       // ZigZag deviation
input int      InpZZBack     = 3;       // ZigZag backstep
input int      InpMinVert    = 2;       // Min vertices (N)
input double   InpZZK1       = 1.5;     // Flagpole ratio
input double   InpZZK2       = 0.25;    // Parallelism tolerance
input double   InpZZK3       = 0.25;    // Slope tolerance

input group "=== DISPLAY ==="
input color    InpBuyColor   = clrLime;   // BUY arrow color
input color    InpSellColor  = clrRed;    // SELL arrow color
input color    InpLabelColor = clrYellow; // Label color
input color    InpLineColor  = clrDodgerBlue; // Line color
input int      InpFontSize   = 9;        // Label font size
input int      InpArrowBuy   = 233;      // Arrow code BUY (233=up, 241=triangle)
input int      InpArrowSell  = 234;      // Arrow code SELL (234=down)
input bool     InpShowLabel  = true;     // Show distance label
input bool     InpShowLine   = false;    // Show pattern boundary lines

input group "=== ALERT ==="
input bool     InpAlertOn    = true;     // Enable alerts
input bool     InpAlertSound = true;    // Play sound
input int      InpAlertCool  = 60;       // Alert cooldown (sec)
input int      InpHistory    = 500;      // Bars to analyze

//+------------------------------------------------------------------+
//| Global instances                                                 |
//+------------------------------------------------------------------+
CPatternDetector g_detector;

// Indicator buffers
double g_buyArrow[];
double g_sellArrow[];
double g_buyLabel[];
double g_sellLabel[];
double g_buyLine[];
double g_sellLine[];

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
    // Set buffers
    SetIndexBuffer(0, g_buyArrow, INDICATOR_DATA);
    SetIndexBuffer(1, g_sellArrow, INDICATOR_DATA);
    SetIndexBuffer(2, g_buyLabel, INDICATOR_DATA);
    SetIndexBuffer(3, g_sellLabel, INDICATOR_DATA);
    SetIndexBuffer(4, g_buyLine, INDICATOR_DATA);
    SetIndexBuffer(5, g_sellLine, INDICATOR_DATA);
    
    // Arrow codes
    PlotIndexSetInteger(0, PLOT_ARROW, InpArrowBuy);
    PlotIndexSetInteger(1, PLOT_ARROW, InpArrowSell);
    
    // Initialize detector
    g_detector.Init(_Symbol, PERIOD_CURRENT);
    
    // Set parameters
    g_detector.SetOverlapParams(InpMinOverlap, InpMinBars, 
                                 InpRectK, InpTaperK, InpExpK, 
                                 InpSlopeK, InpMinPole);
    g_detector.SetZZParams(InpZZDepth, InpZZDev, InpZZBack,
                            InpMinVert, InpZZK1, InpZZK2, InpZZK3);
    g_detector.SetDrawParams(true, InpShowLabel, InpShowLine,
                              InpBuyColor, InpSellColor, InpLabelColor,
                              InpLineColor, InpFontSize, InpArrowBuy, InpArrowSell);
    g_detector.SetAlertParams(InpAlertOn, InpAlertSound, InpAlertCool);
    
    // Empty values
    ArrayInitialize(g_buyArrow, EMPTY_VALUE);
    ArrayInitialize(g_sellArrow, EMPTY_VALUE);
    ArrayInitialize(g_buyLabel, EMPTY_VALUE);
    ArrayInitialize(g_sellLabel, EMPTY_VALUE);
    ArrayInitialize(g_buyLine, EMPTY_VALUE);
    ArrayInitialize(g_sellLine, EMPTY_VALUE);
    
    IndicatorSetString(INDICATOR_SHORTNAME, "ChartPattern12");
    IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
    
    Print("=== iCPattern12 Initialized ===");
    Print("Patterns: Bull/Bear Flag, Pennant, Wedge, Rectangle, Triangle");
    Print("ZigZag: depth=", InpZZDepth, " dev=", InpZZDev, " back=", InpZZBack);
    Print("Bar Overlap: minBars=", InpMinBars, " minOverlap=", InpMinOverlap);
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    g_detector.Release();
    Comment("");
    Print("=== iCPattern12 Deinitialized ===");
}

//+------------------------------------------------------------------+
//| OnCalculate                                                       |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_vol[],
                const long &vol[],
                const int &spread[])
{
    if(rates_total < 20) return 0;
    
    int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
    if(start < 1) start = 1;
    
    int limit = MathMin(rates_total - 1, InpHistory);
    
    // Array untuk sinyal
    CPatternSignal signals[];
    ArrayResize(signals, 50);
    int count = 0;
    
    // Scan patterns
    g_detector.Scan(start, limit, open, high, low, close, time, signals, count);
    
    // Plot arrows and labels
    for(int i = 0; i < count; i++)
    {
        CPatternSignal &sig = signals[i];
        
        // Filter by pattern ID range
        if(InpMinPatternID > 0 && sig.patternID < InpMinPatternID) continue;
        if(InpMaxPatternID > 0 && sig.patternID > InpMaxPatternID) continue;
        
        // Filter by direction
        if(InpBullOnly && !sig.isBullish) continue;
        if(InpBearOnly && sig.isBullish) continue;
        
        // Find bar index for this signal
        int barIdx = -1;
        for(int b = 0; b < rates_total; b++)
        {
            if(time[b] >= sig.time)
            {
                barIdx = b;
                break;
            }
        }
        
        if(barIdx < 0 || barIdx >= rates_total) continue;
        
        // Format distance label
        string distTxt = DoubleToString(sig.target, 0) + "pt";
        string fullTxt = g_detector.PatternName(sig.patternID) 
                        + " (" + distTxt + ")";
        
        if(sig.isBullish)
        {
            g_buyArrow[barIdx] = low[barIdx] - 5 * _Point;
            
            if(InpShowLabel)
            {
                g_buyLabel[barIdx] = high[barIdx] + 15 * _Point;
                
                // Create text object
                string name = "CP12_L_" + IntegerToString(barIdx) + "_" 
                            + IntegerToString(sig.patternID);
                if(ObjectCreate(0, name, OBJ_TEXT, 0, time[barIdx], 
                                high[barIdx] + 20 * _Point))
                {
                    ObjectSetString(0, name, OBJPROP_TEXT, fullTxt);
                    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize);
                    ObjectSetInteger(0, name, OBJPROP_COLOR, InpLabelColor);
                    ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
                }
            }
        }
        else
        {
            g_sellArrow[barIdx] = high[barIdx] + 5 * _Point;
            
            if(InpShowLabel)
            {
                g_sellLabel[barIdx] = low[barIdx] - 15 * _Point;
                
                string name = "CP12_L_" + IntegerToString(barIdx) + "_" 
                            + IntegerToString(sig.patternID);
                if(ObjectCreate(0, name, OBJ_TEXT, 0, time[barIdx],
                                low[barIdx] - 20 * _Point))
                {
                    ObjectSetString(0, name, OBJPROP_TEXT, fullTxt);
                    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize);
                    ObjectSetInteger(0, name, OBJPROP_COLOR, InpLabelColor);
                    ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_TOP);
                }
            }
        }
    }
    
    // Display info panel
    DisplayPanel(signals, count);
    
    return rates_total;
}

//+------------------------------------------------------------------+
//| Display info panel                                                |
//+------------------------------------------------------------------+
void DisplayPanel(CPatternSignal &signals[], int count)
{
    string txt = "";
    txt += "===========================================\n";
    txt += "      iCPattern12 - Chart Pattern 12\n";
    txt += "===========================================\n";
    txt += "Symbol  : " + _Symbol + "\n";
    txt += "Timeframe: " + EnumToString(_Period) + "\n";
    txt += "-----------------------------------------\n";
    txt += "PATTERNS DETECTED: " + IntegerToString(count) + "\n";
    txt += "-----------------------------------------\n";
    
    // Count by type
    int bullCnt = 0, bearCnt = 0;
    for(int i = 0; i < count; i++)
    {
        if(signals[i].isBullish) bullCnt++;
        else bearCnt++;
    }
    
    txt += "BUY signals : " + IntegerToString(bullCnt) + "\n";
    txt += "SELL signals: " + IntegerToString(bearCnt) + "\n";
    txt += "-----------------------------------------\n";
    txt += "Pattern List:\n";
    
    for(int i = 0; i < MathMin(count, 10); i++)
    {
        string dir = signals[i].isBullish ? "[BUY]" : "[SELL]";
        txt += "  " + IntegerToString(i + 1) + ". " 
            + signals[i].patternName + " " + dir + "\n";
        txt += "     Distance: " + DoubleToString(signals[i].target, 0) + "pts\n";
    }
    
    if(count > 10) txt += "  ... and " + IntegerToString(count - 10) + " more\n";
    
    txt += "===========================================\n";
    txt += "MinBars: " + IntegerToString(InpMinBars);
    txt += " | MinOverlap: " + DoubleToString(InpMinOverlap, 2) + "\n";
    txt += "ZZ Depth: " + IntegerToString(InpZZDepth) + "\n";
    
    Comment(txt);
}

//+------------------------------------------------------------------+
//| Chart event - click to delete label                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
{
    if(id == CHARTEVENT_OBJECT_CLICK)
    {
        if(StringFind(sparam, "CP12_") == 0)
        {
            ObjectDelete(0, sparam);
        }
    }
}
//+------------------------------------------------------------------+