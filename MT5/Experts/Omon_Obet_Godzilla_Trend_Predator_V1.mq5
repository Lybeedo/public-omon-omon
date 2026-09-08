//+------------------------------------------------------------------+
//|                                   Omon_Obet_Godzilla_Trend_Predator_V1.mq5 |
//|                                      Omon/Obet Team - Godzilla Edition        |
//|                                          Trend Predator Strategy                          |
//+------------------------------------------------------------------+
#property copyright "Omon/Obet Team"
#property link      ""
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

CTrade trade;

//--- Input Parameters
input group "=== CONFIGURATION ==="
input double InpLot = 0.01;             // Base Lot Size
input int InpMagicNumber = 7373;        // Magic Number
input ENUM_OFFSET_MODE InpOffsetMode = OFFSET_MODE_TRADE_DISTANCE;

input group "=== TREND DETECTOR ==="
input int InpFastMA = 9;                // Fast MA Period
input int InpSlowMA = 21;               // Slow MA Period
input ENUM_MA_METHOD InpMAMethod = MODE_EMA; // MA Method
input int InpADXPeriod = 14;            // ADX Period
input double InpADXTrendLevel = 25.0;   // ADX Trend Filter Level
input double InpADXOverheatLevel = 45.0;// ADX Overheat Level (Exit/Reduce)

input group "=== STRATEGY MODES ==="
input bool InpEnableTrendRide = true;   // Enable Trend Riding Mode
input bool InpEnableScalpMode = true;   // Enable Scalp Mode (Sideways)
input double InpLotMultTrend = 1.5;     // Lot Multiplier (Trend)
input double InpLotMultScalp = 0.5;     // Lot Multiplier (Scalping)

input group "=== RISK MANAGEMENT ==="
input int InpStopLoss = 200;            // Stop Loss (Points)
input int InpTakeProfit = 300;          // Take Profit (Points)
input int InpTrailingStop = 50;         // Trailing Stop (Points)
input int InpBreakEven = 100;           // Break Even Trigger (Points)

input group "=== DASHBOARD SETTINGS ==="
input string InpDashColor = "clrDodgerBlue";
input string InpBgColor = "clrDarkSlateGray";
input int InpPanelX = 20;               // Panel X Position
input int InpPanelY = 100;              // Panel Y Position

//--- Globals
double g_adxCurrent, g_fastCurrent, g_slowCurrent;
double g_fastPrev, g_slowPrev;
string g_trendStatus = "UNKNOWN";
color g_statusColor = clrYellow;
datetime g_lastBarTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    if(InpOffsetMode == OFFSET_MODE_TRADE_DISTANCE)
        trade.SetOffsetByMaxSlippage(3);
    
    trade.SetExpertMagicNumber(InpMagicNumber);
    trade.SetTypeFilling(GetPreferredFilling());
    trade.SetDeviationInPoints(30);
    
    InitializeIndicators();
    CreateDashboard();
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    ObjectsDeleteAll(0, "GODZILLA_DASH_");
    Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Ensure new bar to prevent repainting spam
    if(Time[0] == g_lastBarTime) return;
    g_lastBarTime = Time[0];
    
    RefreshIndicators();
    ManagePositions();
    CheckEntrySignals();
    UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Indicator Helpers                                                |
//+------------------------------------------------------------------+
void InitializeIndicators()
{
    ArraySetAsSeries(iClose(_Symbol, PERIOD_CURRENT), true);
    ArraySetAsSeries(iHigh(_Symbol, PERIOD_CURRENT), true);
    ArraySetAsSeries(iLow(_Symbol, PERIOD_CURRENT), true);
    ArraySetAsSeries(iTime(_Symbol, PERIOD_CURRENT), true);
}

void RefreshIndicators()
{
    double fastBuf[], slowBuf[], adxBuf[];
    ArraySetAsSeries(fastBuf, true);
    ArraySetAsSeries(slowBuf, true);
    ArraySetAsSeries(adxBuf, true);
    
    if(CopyBuffer(iCustom(_Symbol, PERIOD_CURRENT, "Indicator//TMA_Centered", 0), 0, 0, 3, fastBuf) < 3 ||
       CopyBuffer(iCustom(_Symbol, PERIOD_CURRENT, "Indicator//TMA_Centered", 0), 0, 0, 3, slowBuf) < 3)
    {
        // Fallback to iMA if custom indicator path fails or not registered
        for(int i=0; i<3; i++) {
            fastBuf[i] = iMA(_Symbol, PERIOD_CURRENT, InpFastMA, 0, InpMAMethod, PRICE_CLOSE, i);
            slowBuf[i] = iMA(_Symbol, PERIOD_CURRENT, InpSlowMA, 0, InpMAMethod, PRICE_CLOSE, i);
        }
    }
    
    double adxHandle = iADX(_Symbol, PERIOD_CURRENT, InpADXPeriod);
    CopyBuffer(adxHandle, 0, 0, 1, adxBuf);
    CloseHandle(adxHandle);
    
    g_fastPrev = g_fastCurrent;
    g_slowPrev = g_slowCurrent;
    g_fastCurrent = fastBuf[1];
    g_slowCurrent = slowBuf[1];
    g_adxCurrent = adxBuf[0];
}

//+------------------------------------------------------------------+
//| Fill Mode Detection                                              |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING GetPreferredFilling()
{
    long fillMode = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
    if((fillMode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK) return ORDER_FILLING_FOK;
    if((fillMode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) return ORDER_FILLING_IOC;
    return ORDER_FILLING_RETURN;
}

//+------------------------------------------------------------------+
//| Position Management (Trailing, BE, Exit)                         |
//+------------------------------------------------------------------+
void ManagePositions()
{
    for(int i = PositionsTotal()-1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        
        long type = PositionGetInteger(POSITION_TYPE);
        double sl = PositionGetDouble(POSITION_SL);
        double tp = PositionGetDouble(POSITION_TP);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentSL = sl;
        double currentTP = tp;
        bool modified = false;
        
        double profitPoints = (type == POSITION_BUY) ? 
                              (SymbolInfoDouble(_Symbol, SYMBOL_BID) - openPrice) / _Point :
                              (openPrice - SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / _Point;
                              
        // Break Even
        if(profitPoints >= InpBreakEven)
        {
            if(type == POSITION_BUY && sl < openPrice)
            {
                currentSL = openPrice;
                modified = true;
            }
            else if(type == POSITION_SELL && sl > openPrice)
            {
                currentSL = openPrice;
                modified = true;
            }
        }
        
        // Trailing Stop
        if(profitPoints >= InpBreakEven + InpTrailingStop)
        {
            if(type == POSITION_BUY)
            {
                double newSL = SymbolInfoDouble(_Symbol, SYMBOL_BID) - (InpTrailingStop * _Point);
                if(newSL > currentSL) { currentSL = newSL; modified = true; }
            }
            else
            {
                double newSL = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + (InpTrailingStop * _Point);
                if(currentSL == 0 || newSL < currentSL) { currentSL = newSL; modified = true; }
            }
        }
        
        if(modified && !trade.PositionModify(ticket, NormalizeDouble(currentSL, _Digits), NormalizeDouble(currentTP, _Digits)))
        {
            Print("Godzilla Failed Modify: ", trade.ResultRetcodeDescription());
        }
    }
}

//+------------------------------------------------------------------+
//| Entry Signal Logic                                               |
//+------------------------------------------------------------------+
void CheckEntrySignals()
{
    bool trendUp = (g_fastCurrent > g_slowCurrent);
    bool trendDown = (g_fastCurrent < g_slowCurrent);
    bool crosUp = (g_fastPrev <= g_slowPrev && g_fastCurrent > g_slowCurrent);
    bool crosDown = (g_fastPrev >= g_slowPrev && g_fastCurrent < g_slowCurrent);
    
    int activeLongs = CountActivePositions(POSITION_TYPE_BUY);
    int activeShorts = CountActivePositions(POSITION_TYPE_SELL);
    
    double lotSize = InpLot;
    
    // Determine Mode & Lot Size
    if(g_adxCurrent >= InpADXTrendLevel)
    {
        g_trendStatus = "TREND RIDER 🦖";
        g_statusColor = clrLime;
        lotSize *= InpLotMultTrend;
    }
    else if(InpADXTrendLevel > g_adxCurrent)
    {
        g_trendStatus = "SCALP HUNTER 🐾";
        g_statusColor = clrGold;
        lotSize *= InpLotMultScalp;
    }
    else
    {
        g_trendStatus = "NEUTRAL ZONE";
        g_statusColor = clrWhite;
    }
    
    // Override for extreme ADX
    if(g_adxCurrent >= InpADXOverheatLevel)
    {
        g_trendStatus = "OVERHEATED ⚠️";
        g_statusColor = clrRed;
    }
    
    // Limit positions
    if(trendUp && InpEnableTrendRide && activeLongs == 0)
    {
        // Wait for pullback or confirmation? Simple crossover for now.
        // Add small buffer to avoid whipsaw
        if(!IsRecentCrossDown()) 
            OpenPosition(ORDER_TYPE_BUY, lotSize);
    }
    else if(trendDown && InpEnableTrendRide && activeShorts == 0)
    {
        if(!IsRecentCrossUp())
            OpenPosition(ORDER_TYPE_SELL, lotSize);
    }
    else if(crosDown && InpEnableScalpMode && activeShorts == 0 && g_adxCurrent < InpADXTrendLevel)
    {
        OpenPosition(ORDER_TYPE_SELL, lotSize);
    }
    else if(crosUp && InpEnableScalpMode && activeLongs == 0 && g_adxCurrent < InpADXTrendLevel)
    {
        OpenPosition(ORDER_TYPE_BUY, lotSize);
    }
}

bool IsRecentCrossDown()
{
    for(int i=3; i<=10; i++) 
        if(g_fastCurrent > g_slowCurrent && g_fastCurrent < g_slowCurrent) return true; // Simplified history check placeholder
    return false;
}
bool IsRecentCrossUp()
{
    return false; // Placeholder
}

void OpenPosition(ENUM_ORDER_TYPE type, double lot)
{
    double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl = (type == ORDER_TYPE_BUY) ? price - InpStopLoss*_Point : price + InpStopLoss*_Point;
    double tp = (type == ORDER_TYPE_BUY) ? price + InpTakeProfit*_Point : price - InpTakeProfit*_Point;
    
    if(trade.PositionOpen(_Symbol, type, NormalizeDouble(lot, 2), price, 3, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits)))
    {
        Print("Godzilla BITE! Opened ", EnumToString(type), " Lot: ", lot, " @ ", price);
    }
    else
    {
        Print("Godzilla Missed! Retcode: ", trade.ResultRetcodeDescription());
    }
}

int CountActivePositions(long posType)
{
    int count = 0;
    for(int i=0; i<PositionsTotal(); i++)
    {
        if(PositionGetTicket(i) > 0)
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
               PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
               PositionGetInteger(POSITION_TYPE) == posType)
                count++;
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Dashboard Engine                                                 |
//+------------------------------------------------------------------+
void CreateDashboard()
{
    // Background Panel
    CreateObjRect("GODZILLA_DASH_BG", InpPanelX, InpPanelY, 280, 220, StringToColor(InpBgColor), 2);
    CreateObjLine("GODZILLA_DASH_TOP", InpPanelX, InpPanelY, 280, clrRed, 3);
    
    string title = "🦖 GODZILLA EA v1.0";
    CreateLabel("GODZILLA_DASH_TITLE", title, InpPanelX+10, InpPanelY+5, clrRed, "Arial Bold", CORNER_LEFT_UPPER, 100);
    
    CreateLabel("GODZILLA_DASH_SEP1", "------------------------------", InpPanelX+10, InpPanelY+25, clrDimGray, "Consolas", CORNER_LEFT_UPPER, 90);
    CreateLabel("GODZILLA_DASH_SEP2", "------------------------------", InpPanelX+10, InpPanelY+195, clrDimGray, "Consolas", CORNER_LEFT_UPPER, 90);
}

void UpdateDashboard()
{
    long balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double profit = equity - balance;
    double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    int trades = PositionsTotal();
    
    string pnlStr = DoubleToString(profit, 2);
    color pnlColor = profit >= 0 ? clrLime : clrRed;
    
    // Update Text Elements
    UpdateLabel("GODZILLA_DASH_STATUS", "STATUS: " + g_trendStatus, InpPanelX+10, InpPanelY+35, g_statusColor);
    UpdateLabel("GODZILLA_DASH_ADIX", "ADX: " + DoubleToString(g_adxCurrent, 1), InpPanelX+10, InpPanelY+55, clrSilver);
    UpdateLabel("GODZILLA_DASH_EMA", "FAST/SLW: " + DoubleToString(g_fastCurrent, _Digits) + "/" + DoubleToString(g_slowCurrent, _Digits), InpPanelX+10, InpPanelY+75, clrAqua);
    UpdateLabel("GODZILLA_DASH_SPREAD", "SPREAD: " + IntegerToString(spread), InpPanelX+10, InpPanelY+95, clrOrange);
    UpdateLabel("GODZILLA_DASH_PROFIT", "PNL: $" + pnlStr, InpPanelX+10, InpPanelY+115, pnlColor);
    UpdateLabel("GODZILLA_DASH_TRADES", "OPEN TRADES: " + IntegerToString(trades), InpPanelX+10, InpPanelY+135, clrWhiteSmoke);
    UpdateLabel("GODZILLA_DASH_LOT", "ACTIVE LOT: " + DoubleToString(InpLot * (g_adxCurrent >= InpADXTrendLevel ? InpLotMultTrend : InpLotMultScalp), 2), InpPanelX+10, InpPanelY+155, clrYellow);
}

void CreateLabel(string name, string text, int x, int y, color clr, string font="Arial", ENUM_BASE_CORNER corner=CORNER_LEFT_UPPER, int z_order=0)
{
    if(ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetString(0, name, OBJPROP_TEXT, text);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetString(0, name, OBJPROP_FONT, font);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
        ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
        ObjectSetInteger(0, name, OBJPROP_ZORDER, z_order);
    }
}

void UpdateLabel(string name, string text, int x, int y, color clr)
{
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void CreateObjRect(string name, int x, int y, int w, int h, color clr, int width=1)
{
    ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_BACK, true);
}

void CreateObjLine(string name, int x, int y, int w, color clr, int width=2)
{
    ObjectCreate(0, name, OBJ_HLINE, 0, 0, y); // Horizontal line hack for top border
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

// Helper to map input color string to actual color
color StringToColor(string colName)
{
    if(colName == "clrDodgerBlue") return clrDodgerBlue;
    if(colName == "clrDarkSlateGray") return clrDarkSlateGray;
    if(colName == "clrRed") return clrRed;
    if(colName == "clrLime") return clrLime;
    if(colName == "clrGold") return clrGold;
    return clrWhite;
}
