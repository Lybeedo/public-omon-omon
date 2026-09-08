//+------------------------------------------------------------------+
//|                                      Omon_Obet_Digimon_Evolution_V1.mq5 |
//|                                          Full Digimon Framework       |
//|                                      Omon/Obet Team - Digital World   |
//+------------------------------------------------------------------+
#property copyright "Omon/Obet Team - Digimon Protocol"
#property link      ""
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

CTrade    trade;
datetime  g_lastBarTime = 0;

//--- Inputs: DIGIMON PARAMETERS
input group "=== EVOLUTION STAGE ==="
input int InpStage = 1;             // Evolution Stage (1: Rookie, 2: Champion, 3: Ultimate, 4: Mega)
                                   // 1: Basic Strategy
                                   // 2+: Advanced Features Enabled

input group "=== ARMOR MODULE (Survival) ==="
input double InpMaxDailyLossPct = 2.0;// Max Daily Loss %
input bool InpEnableKillSwitch = true;// Global Basket Kill Switch
input double InpKillThresholdPct = 5.0;// Total Equity Drop % Trigger Kill
input double InpMinBalanceToLive = 10.0;// Min Balance below which EA stops

input group "=== WEAPON MODULE (Precision) ==="
input bool InpUseMTFTrend = true;     // Multi-Timeframe Confirmation
input ENUM_TIMEFRAMES InpTfFilter = PERIOD_H1; // Higher TF filter
input bool InpUseSpreadFilter = true;// Spread Filter (Avoid spikes)
input int InpMaxSpreadPoints = 50;    // Max allowed spread in points

input group "=== WISDOM MODULE (Adaptation) ==="
input bool InpAdaptiveSLTP = true;    // Dynamic SL/TP based on ATR
input int InpADXTrendPeriod = 14;     // ADX Period for Regime Detection
input double InpTrendStrength = 20.0; // Level > Trend Mode
input double InpVolatilityMultiplier = 2.0; // SL/TP = ATR * Mult

input group "=== SPEED MODULE (Execution) ==="
input int InpFastRetryCount = 3;      // Orders send retry attempts
input int InpSlippagePoint = 50;      // Max slippage allowed

//--- Globals / State
double g_currentSpread = 0;
int g_adxLevel = 0;                 // 0=None, 1=TrendStrong, 2=Overheat, 3=Ranging
string g_systemMode = "ROOKIE";
ulong g_masterMagic = 73739;        // Unique Magic Number
int g_totalTradesToday = 0;

//--- Data Buffers
double g_atrValue = 0.0;
double g_adxValue = 0.0;
long g_highestHighCurrent = 0;
long g_lowestLowCurrent = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Setup Trade Object
    trade.SetExpertMagicNumber(g_masterMagic);
    trade.SetDeviationInPoints(InpSlippagePoint);
    trade.SetTypeFilling(GetFillingMode());
    trade.SetAsyncMode(false); // Synchronous for strict retry logic

    InitializeSystem();
    
    Print("DIGIMON PROTOCOL INITIALIZED. STAGE: ", GetEnumString((ENUM_STAGE)InpStage));
    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    ObjectsDeleteAll(0, "DIGIMON_");
    Comment("");
}

//+------------------------------------------------------------------+
//| Main Tick Loop                                                   |
//+------------------------------------------------------------------+
void OnTick()
{
    UpdateState();

    // --- ARMOB CHECKS (Priority 1) ---
    if(!IsSystemSafe()) return; 

    // --- NEW BAR LOGIC (Optional - remove for tick-based entry) ---
    if(Time[0] == g_lastBarTime && InpStage < 4) return; // Only wait for new bar in low stages
    if(Time[0] != g_lastBarTime) g_lastBarTime = Time[0];

    // --- WEAPON CHECKS (Priority 2) ---
    if(!PassWeaponsChecks()) return;

    // --- WISDOM CALCULATIONS (Priority 3) ---
    CalculateMetrics();
    SetDynamicParameters();

    // --- EXECUTION (Priority 4) ---
    ProcessTradingLogic();
    
    UpdateDashboard();
}

//+------------------------------------------------------------------+
//| ARMOR MODULE                                                     |
//+------------------------------------------------------------------+
bool IsSystemSafe()
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    
    if(balance < InpMinBalanceToLive) { StopEA("BALANCE LOW"); return false; }
    
    // Kill Switch Logic
    if(InpEnableKillSwitch)
    {
        double lossPct = (balance - equity) / balance * 100.0;
        if(lossPct >= InpKillThresholdPct) 
        {
            CloseAllPositions("KILL SWITCH TRIGGERED");
            return false;
        }
    }
    return true;
}

void CloseAllPositions(string reason)
{
    Print("[ARMOR] ", reason);
    for(int i = PositionsTotal()-1; i>=0; i--)
    {
        ulong t = PositionGetTicket(i);
        if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==g_masterMagic)
        {
            trade.PositionClose(t);
        }
    }
    EventSetTimer(1); // Reset timer manually if needed, or handle state
}

void StopEA(string msg)
{
    Print("[ARMOR] CRITICAL STOP: ", msg);
    // Optional: Disable indicators, change status
}

//+------------------------------------------------------------------+
//| WEAPON MODULE                                                    |
//+------------------------------------------------------------------+
bool PassWeaponsChecks()
{
    // Spread Check
    if(InpUseSpreadFilter)
    {
        long spread_long = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
        g_currentSpread = (double)spread_long;
        if(g_currentSpread > InpMaxSpreadPoints) return false;
    }

    // MTF Trend Check (Only in Stage 2+)
    if(InpStage >= 2 && InpUseMTFTrend)
    {
        if(!CheckMTFTrend()) return false;
    }
    return true;
}

bool CheckMTFTrend()
{
    // Simple MA cross on higher timeframe
    int maHandle = iMA(_Symbol, InpTfFilter, 50, 0, MODE_EMA, PRICE_CLOSE);
    double mtfVal[];
    ArraySetAsSeries(mtfVal, true);
    CopyBuffer(maHandle, 0, 0, 1, mtfVal);
    double closeVal = iClose(_Symbol, PERIOD_CURRENT, 0);
    CloseHandle(maHandle);
    
    // Just a placeholder logic for MTF confirmation example: Price > MA on H1 allows Buys only
    // Real implementation would compare current candle to MA
    return true; 
}

//+------------------------------------------------------------------+
//| WISDOM MODULE                                                    |
//+------------------------------------------------------------------+
void CalculateMetrics()
{
    // Calculate ATR
    int atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
    double atrBuf[];
    ArraySetAsSeries(atrBuf, true);
    CopyBuffer(atrHandle, 0, 0, 1, atrBuf);
    g_atrValue = atrBuf[0];
    CloseHandle(atrHandle);

    // ADX Level
    int adxHandle = iADX(_Symbol, PERIOD_CURRENT, InpADXTrendPeriod);
    double adxBuf[];
    ArraySetAsSeries(adxBuf, true);
    CopyBuffer(adxHandle, 0, 0, 1, adxBuf);
    g_adxValue = adxBuf[0];
    CloseHandle(adxHandle);
    
    if(g_adxValue >= InpTrendStrength * 2.0) g_adxLevel = 2; // Overheated
    else if(g_adxValue >= InpTrendStrength) g_adxLevel = 1;  // Strong Trend
    else g_adxLevel = 3; // Ranging
}

void SetDynamicParameters()
{
    // If Wise Mode, we don't hardcode SL/TP in OrderSend, we calculate them here
    // Stored in global vars or calculated at OpenPosition time
    // For simplicity, we calculate target SL/TP prices inside ProcessTradingLogic
}

//+------------------------------------------------------------------+
//| SPEED MODULE & CORE LOGIC                                        |
//+------------------------------------------------------------------+
void ProcessTradingLogic()
{
    // Simplified Core Logic for Demo purposes
    // In a full scenario, this connects to your specific strategy (e.g. Godzilla logic)
    
    // Example: Buy if ADX is trending AND price action pattern
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Dynamic SL/TP calculation
    double dynamicSL, dynamicTP;
    if(InpAdaptiveSLTP)
    {
        double step = g_atrValue * InpVolatilityMultiplier;
        dynamicSL = ask + step; // Placeholder Sell SL calc logic adjusted later
        dynamicTP = bid - step;
    }
    else
    {
        dynamicSL = 0; dynamicTP = 0; // Standard Points used in inputs usually
    }
    
    // --- STRATEGY ENGINE INTEGRATION POINT ---
    // This block simulates checking if conditions are met. 
    // Replace with your actual crossover/momentum logic.
    bool buySignal = (iClose(_Symbol, PERIOD_CURRENT, 0) > iOpen(_Symbol, PERIOD_CURRENT, 0)) && (g_adxLevel == 1 || InpStage < 2);
    bool sellSignal = (iClose(_Symbol, PERIOD_CURRENT, 0) < iOpen(_Symbol, PERIOD_CURRENT, 0)) && (g_adxLevel == 1 || InpStage < 2);
    
    int openLongs = CountPositions(POSITION_TYPE_BUY);
    int openShorts = CountPositions(POSITION_TYPE_SELL);
    
    if(buySignal && openLongs == 0)
        ExecuteBuy();
        
    if(sellSignal && openShorts == 0)
        ExecuteSell();
        
    ManageActiveTrades();
}

void ExecuteBuy()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double sl = AskForSL(ask, POSITION_TYPE_BUY);
    double tp = AskForTP(ask, POSITION_TYPE_BUY);
    
    RetryOrder(trade.Buy(InpGetLot(), _Symbol, ask, sl, tp, "DIGIMON BITE"));
}

void ExecuteSell()
{
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl = AskForSL(bid, POSITION_TYPE_SELL);
    double tp = AskForTP(bid, POSITION_TYPE_SELL);
    
    RetryOrder(trade.Sell(InpGetLot(), _Symbol, bid, sl, tp, "DIGIMON CLAW"));
}

void RetryOrder(bool result)
{
    if(!result)
    {
        for(int i=0; i<InpFastRetryCount; i++)
        {
            Sleep(100 * (i+1));
            result = trade.TransactionWait(); // Pseudo logic for retry loop
            if(result) break;
        }
    }
}

double AskForSL(double entryPrice, long type)
{
    if(InpAdaptiveSLTP)
    {
        return (type==POSITION_BUY) ? entryPrice - (g_atrValue * 2.0) : entryPrice + (g_atrValue * 2.0);
    }
    // Fallback to static points if not adaptive
    return 0; 
}

double AskForTP(double entryPrice, long type)
{
    if(InpAdaptiveSLTP)
    {
        return (type==POSITION_BUY) ? entryPrice + (g_atrValue * 3.0) : entryPrice - (g_atrValue * 3.0);
    }
    return 0;
}

double InpGetLot()
{
    double base = 0.01; // Input parameter needs to be added
    if(InpStage >= 3) base *= 1.5; // Speed/Wisdom boost lot?
    return base;
}

void ManageActiveTrades()
{
    // Trailing / Break Even Logic goes here
    for(int i=PositionsTotal()-1; i>=0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionGetString(POSITION_SYMBOL) == _Symbol)
        {
            double sl = PositionGetDouble(POSITION_SL);
            double op = PositionGetDouble(POSITION_PRICE_OPEN);
            long type = PositionGetInteger(POSITION_TYPE);
            
            double profit = (type==POSITION_BUY) ? 
                (SymbolInfoDouble(_Symbol, SYMBOL_BID) - op) / _Point :
                (op - SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / _Point;
                
            // BE trigger
            if(profit > 100 && sl < op) // Buy BE
            {
                trade.PositionModify(ticket, op, PositionGetDouble(POSITION_TP));
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Utilities                                                        |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING GetFillingMode()
{
    long fill = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
    if((fill & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK) return ORDER_FILLING_FOK;
    if((fill & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) return ORDER_FILLING_IOC;
    return ORDER_FILLING_RETURN;
}

int CountPositions(long type)
{
    int c=0;
    for(int i=0;i<PositionsTotal();i++)
    {
        if(PositionGetTicket(i)>0 && PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_TYPE)==type) c++;
    }
    return c;
}

void InitializeSystem()
{
    CreateDashboardBase();
}

string GetEnumString(int val)
{
    switch(val)
    {
        case 1: return "ROOKIE 🦆";
        case 2: return "CHAMPION 🦎";
        case 3: return "ULTIMATE 🐼";
        case 4: return "MEGA 🐲";
        default: return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| DASHBOARD DIGIMON                                                |
//+------------------------------------------------------------------+
void CreateDashboardBase()
{
    CreateObjRect("DIGIMON_BG", 20, 100, 300, 250, clrBlack, 2);
    CreateLabel("DIGIMON_TITLE", "OMON DIGIMON", 30, 110, clrWhite, "Arial", 120);
    CreateLabel("DIGIMON_SUB", "Evolution Framework", 30, 125, clrDimGray, "Arial", 100);
    CreateLine("DIGIMON_SEP", clrLime);
}

void UpdateDashboard()
{
    string modeStr = GetEnumString(InpStage);
    UpdateLabel("DIGIMON_STATUS", "MODE: " + modeStr, 30, 150, clrGold);
    UpdateLabel("DIGIMON_SPREAD", "SPREAD: " + DoubleToString(g_currentSpread), 30, 170, (g_currentSpread > 30)?clrRed:clrSilver);
    UpdateLabel("DIGIMON_ADIX", "ADX: " + DoubleToString(g_adxValue), 30, 190, clrSilver);
    UpdateLabel("DIGIMON_ATR", "ATR: " + DoubleToString(g_atrValue/_Point, 0) + " pts", 30, 210, clrAqua);
    
    double bal = AccountInfoDouble(ACCOUNT_BALANCE);
    double eq = AccountInfoDouble(ACCOUNT_EQUITY);
    color pnlColor = (eq - bal >= 0) ? clrLime : clrRed;
    UpdateLabel("DIGIMON_PNL", "EQUITY: $" + DoubleToString(eq, 2), 30, 230, pnlColor);
    
    // HP Bar Simulation (Visual flair)
    int hpWidth = (int)((bal / 1000.0) * 280); // Fake scale
    UpdateLabel("DIGIMON_HP_BAR", "HP: [" + StringSubstr(StringFind(hpWidth, ' ', 0) >=0 ? "=" : "===========", 0, MathMin(280,hpWidth)) + "]", 30, 250, clrYellow);
}

// Helper object creation wrappers...
void CreateObjRect(string n, int x, int y, int w, int h, color c, int wth=1)
{
    ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, n, OBJPROP_XSIZE, w); ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
    ObjectSetInteger(0, n, OBJPROP_BGCOLOR, c); ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER); ObjectSetInteger(0, n, OBJPROP_BACK, true);
}

void CreateLabel(string n, string t, int x, int y, color c, string font="Arial", int z=100)
{
    ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
    ObjectSetString(0, n, OBJPROP_TEXT, t);
    ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, n, OBJPROP_COLOR, c); ObjectSetString(0, n, OBJPROP_FONT, font);
    ObjectSetInteger(0, n, OBJPROP_FONTSIZE, 10); ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, n, OBJPROP_ZORDER, z);
}

void UpdateLabel(string n, string t, int x, int y, color c)
{
    ObjectMove(0, n, 0, x, y); // Hack to update position if needed, but usually text/color is enough
    ObjectSetString(0, n, OBJPROP_TEXT, t);
    ObjectSetInteger(0, n, OBJPROP_COLOR, c);
}

void CreateLine(color c)
{
    // Placeholder for line separator logic
}
//+------------------------------------------------------------------+
