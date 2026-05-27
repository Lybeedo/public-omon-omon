//+------------------------------------------------------------------+
//|                   Gold Trade Pro EA (Clean MT4)                   |
//|                         https://fxprosystems.com/                 |
//|                         Ported by: Cuancux Algo Traders           |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2020-2026, FXProSystems.com"
#property link        "https://fxprosystems.com/"
#property version     "2.00"
#property strict

//+------------------------------------------------------------------+
//| INCLUDES                                                         |
//+------------------------------------------------------------------+
#include <stdlib.mqh>

//+------------------------------------------------------------------+
//| ENUMS                                                            |
//+------------------------------------------------------------------+
enum ENUM_SIGNAL_MODE   { SIG_FRACTAL_MA = 0, SIG_MA_CROSS = 1 };
enum ENUM_TIMEFRAME    { TF_D1 = 1440, TF_H4 = 240, TF_H1 = 60, TF_M30 = 30, TF_M15 = 15 };

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== General ==="
bool    Gen_ShowInfoPanel      = true;     // Show info panel on chart
double  Gen_PanelSizeAdjust    = 1.0;      // Panel size multiplier
int     Gen_MagicNumber        = 1000;     // EA Magic Number
string  Gen_Comment            = "Gold Trade Pro v2";

input group "=== Strategy Activation ==="
bool    Strat_EnableA          = true;     // Strategy A (Conservative)
bool    Strat_EnableB          = true;     // Strategy B (Aggressive)
bool    Strat_EnableC          = true;     // Strategy C (Swing)
bool    Strat_EnableD          = true;     // Strategy D (Trend)
bool    Strat_EnableE          = true;     // Strategy E (Scalping)
bool    Strat_EnableF          = true;     // Strategy F (Breakout)
bool    Strat_EnableG          = true;     // Strategy G (Reversal)
bool    Strat_EnableH          = true;     // Strategy H (Multi-timeframe)

input group "=== Filters ==="
double  Filter_MaxSpread       = 500;      // Maximum spread (points)
bool    Filter_UseVirtualExpiry = true;     // Use virtual order expiration

input group "=== Lot Size ==="
int     MM_RiskMode            = 0;        // 0=Manual, 1=RPT, 2=LotsPerBalance
double  MM_StartLots           = 0.01;     // Starting lot size
int     MM_LotPerBalanceStep    = 600;      // Balance per lot step
double  MM_RiskPerTrade        = 2.0;      // Risk % per trade (RPT mode)
bool    MM_UseEquity           = false;    // Use equity for risk calc
bool    MM_OnlyIncrease        = true;     // Only allow increasing lots

input group "=== Trade Filters ==="
bool    Filter_HighLowBreakout  = true;    // Enable high/low breakout filter
bool    Filter_Reversal         = false;   // Enable reversal filter
bool    Filter_MATrend          = false;   // Enable MA trend filter
bool    Filter_Volatility       = true;    // Enable volatility filter
int     Filter_MaxTradesPerSignal = 5;    // Max trades per signal

input group "=== Trailing SL ==="
bool    Trail_Enable            = false;   // Enable trailing stop loss
double  Trail_StartPoints       = 10.0;    // Trailing activation (points)
double  Trail_StepPoints        = 10.0;    // Trailing step (points)
double  Trail_MaxDistance       = 100.0;   // Max trailing distance (points)
double  Trail_SafeDistance      = 0.1;     // Min profit to activate trail (points)

input group "=== Break-Even ==="
bool    BE_Enable              = false;    // Enable break-even
double  BE_ProfitPoints         = 0.0;      // Profit in points to activate BE
double  BE_OffsetPoints         = 0.0;      // Offset from entry price

input group "=== High/Low Trailing SL ==="
bool    HL_Enable              = false;   // Enable high/low trailing SL
string  HL_Timeframe            = "M15";   // Timeframe for HL reference

input group "=== Zone Recovery ==="
bool    ZR_Enable              = false;   // Enable zone recovery
double  ZR_LotMultiplier       = 1.0;      // Lot multiplier for recovery trades

input group "=== Trading Hours ==="
bool    TH_Enable              = false;   // Enable trading hours filter
int     TH_StartDay            = 0;        // Start day (0=Sun..6=Sat)
int     TH_StartHour           = 0;        // Start hour (0-23)
int     TH_EndDay              = 6;        // End day (0=Sun..6=Sat)
int     TH_EndHour             = 24;       // End hour (0-24)
bool    TH_AllowWeekend        = false;    // Allow weekend trading

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+

// Strategy configuration structure
struct StrategyConfig
{
    int      MagicOffset;        // Magic number offset
    string   Label;              // Strategy label for orders
    double   SignalTF;           // Signal timeframe (minutes)
    double   ConfirmTF;          // Confirmation timeframe (minutes)
    int      FractalPeriod;      // Candle period for fractal
    int      MAPeriod;           // MA period
    double   SLPoints;           // Stop loss in points
    double   TPPoints;           // Take profit in points
    double   TrailStart;         // Trailing start points
    double   TrailStep;          // Trailing step points
    double   BEProfit;           // Break-even profit trigger
    double   BEOffset;           // Break-even offset points
    double   MaxSpread;          // Max spread for this strategy
    int      ExpiryHours;        // Virtual expiry hours
    bool     Enabled;            // Is this strategy enabled?
};

// Global strategy configs
StrategyConfig gStrategies[8];

// Runtime state per strategy
struct StrategyState
{
    double  FractalHigh1;
    double  FractalLow1;
    double  FractalHigh2;
    double  FractalLow2;
    double  MA1;
    double  MA2;
    double  MA3;
    double  LastHigh;
    double  LastLow;
    double  HighBefore;
    double  LowBefore;
    bool    HighBreakout;
    bool    LowBreakout;
    bool    BuySignal;
    bool    SellSignal;
    datetime LastSignalTime;
    int     OpenOrdersCount;
    double  LowestFractalHigh;   // Track lowest fractal high for buy signals
    double  HighestFractalLow;    // Track highest fractal low for sell signals
};

StrategyState gState[8];

// Global tracking
int    gTotalStrategies       = 8;
string gSymbol                 = "";
double gPoint                  = 0;
double gDigitsAdjust           = 1;
int    gDigits                 = 0;
double gSpread                 = 0;
double gStopLevel              = 0;
double gFreezeLevel            = 0;
double gMinLot                 = 0;
double gMaxLot                 = 0;
double gLotStep                = 0;
double gBalance                = 0;
double gEquity                 = 0;
double gLots[];               // Dynamic lot array per strategy
datetime gLastBarTime         = 0;
datetime gLastBarTimeM5        = 0;

//+------------------------------------------------------------------+
//| EXPERT INITIALIZATION                                            |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize symbol info
    gSymbol = Symbol();
    gPoint  = MarketInfo(gSymbol, MODE_POINT);
    gDigits = (int)MarketInfo(gSymbol, MODE_DIGITS);
    
    // Handle 3/5 digit brokers
    if(gDigits == 3 || gDigits == 5)
        gDigitsAdjust = 10.0;
    else
        gDigitsAdjust = 1.0;
    
    gPoint *= gDigitsAdjust;
    
    // Get market info
    gSpread      = MarketInfo(gSymbol, MODE_SPREAD);
    gStopLevel   = MarketInfo(gSymbol, MODE_STOPLEVEL) * gDigitsAdjust;
    gFreezeLevel = MarketInfo(gSymbol, MODE_FREEZELEVEL) * gDigitsAdjust;
    gMinLot      = MarketInfo(gSymbol, MODE_MINLOT);
    gMaxLot      = MarketInfo(gSymbol, MODE_MAXLOT);
    gLotStep     = MarketInfo(gSymbol, MODE_LOTSTEP);
    gBalance     = AccountBalance();
    gEquity      = AccountEquity();
    
    // Validate settings
    if(Filter_MaxSpread <= 0) Filter_MaxSpread = 500;
    if(Trail_StartPoints <= 0) Trail_StartPoints = gStopLevel;
    if(Trail_StepPoints <= 0) Trail_StepPoints = gStopLevel;
    
    // Initialize strategy configurations
    InitStrategies();
    
    // Initialize lots array
    ArrayResize(gLots, gTotalStrategies);
    for(int i = 0; i < gTotalStrategies; i++)
    {
        gLots[i] = CalculateLotSize(i, MM_StartLots);
    }
    
    // Create info panel
    if(Gen_ShowInfoPanel)
        CreateInfoPanel();
    
    Print("Gold Trade Pro EA v2.00 initialized on ", gSymbol);
    Print("Account: ", AccountNumber(), " | Balance: ", AccountBalance());
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| EXPERT DEINIT                                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Comment("");
    ObjectsDeleteAll(0, "GTP_");
}

//+------------------------------------------------------------------+
//| EXPERT TICK                                                      |
//+------------------------------------------------------------------+
void OnTick()
{
    // Skip if symbol is not gold
    if(!IsGoldSymbol())
        return;
    
    // Update market info
    UpdateMarketInfo();
    
    // Check for new bar (main timeframe)
    datetime currentBarTime = iTime(gSymbol, PERIOD_M1, 0);
    if(currentBarTime == gLastBarTime)
        return;
    gLastBarTime = currentBarTime;
    
    // Process each enabled strategy
    for(int s = 0; s < gTotalStrategies; s++)
    {
        if(!gStrategies[s].Enabled)
            continue;
        
        // Update strategy-specific state
        UpdateStrategyState(s);
        
        // Check trading conditions
        CheckSignalConditions(s);
        
        // Execute trade if signal valid
        if(gState[s].BuySignal)
            ExecuteBuy(s);
        else if(gState[s].SellSignal)
            ExecuteSell(s);
        
        // Manage existing orders
        ManageOrders(s);
    }
    
    // Update info panel
    if(Gen_ShowInfoPanel)
        UpdateInfoPanel();
}

//+------------------------------------------------------------------+
//| INITIALIZE STRATEGIES                                            |
//+------------------------------------------------------------------+
void InitStrategies()
{
    // Strategy A - Conservative Daily Breakout
    gStrategies[0].MagicOffset   = 0;
    gStrategies[0].Label        = "GTP_A";
    gStrategies[0].SignalTF     = 1440;
    gStrategies[0].ConfirmTF    = 60;
    gStrategies[0].FractalPeriod= 1;
    gStrategies[0].MAPeriod     = 20;
    gStrategies[0].SLPoints     = 150.0;
    gStrategies[0].TPPoints     = 680.0;
    gStrategies[0].TrailStart   = 50.0;
    gStrategies[0].TrailStep    = 30.0;
    gStrategies[0].BEProfit     = 0;
    gStrategies[0].BEOffset     = 0;
    gStrategies[0].MaxSpread    = Filter_MaxSpread;
    gStrategies[0].ExpiryHours  = 408;
    gStrategies[0].Enabled      = Strat_EnableA;
    
    // Strategy B - Aggressive Breakout
    gStrategies[1].MagicOffset   = 1;
    gStrategies[1].Label        = "GTP_B";
    gStrategies[1].SignalTF     = 1440;
    gStrategies[1].ConfirmTF    = 60;
    gStrategies[1].FractalPeriod= 1;
    gStrategies[1].MAPeriod     = 20;
    gStrategies[1].SLPoints     = 400.0;
    gStrategies[1].TPPoints     = 380.0;
    gStrategies[1].TrailStart   = 80.0;
    gStrategies[1].TrailStep    = 40.0;
    gStrategies[1].BEProfit     = 0;
    gStrategies[1].BEOffset     = 0;
    gStrategies[1].MaxSpread    = Filter_MaxSpread;
    gStrategies[1].ExpiryHours  = 168;
    gStrategies[1].Enabled      = Strat_EnableB;
    
    // Strategy C - Swing
    gStrategies[2].MagicOffset   = 2;
    gStrategies[2].Label        = "GTP_C";
    gStrategies[2].SignalTF     = 1440;
    gStrategies[2].ConfirmTF    = 60;
    gStrategies[2].FractalPeriod= 2;
    gStrategies[2].MAPeriod     = 20;
    gStrategies[2].SLPoints     = 900.0;
    gStrategies[2].TPPoints     = 980.0;
    gStrategies[2].TrailStart   = 100.0;
    gStrategies[2].TrailStep    = 50.0;
    gStrategies[2].BEProfit     = 0;
    gStrategies[2].BEOffset     = 0;
    gStrategies[2].MaxSpread    = Filter_MaxSpread;
    gStrategies[2].ExpiryHours  = 408;
    gStrategies[2].Enabled      = Strat_EnableC;
    
    // Strategy D - Trend Following
    gStrategies[3].MagicOffset   = 3;
    gStrategies[3].Label        = "GTP_D";
    gStrategies[3].SignalTF     = 1440;
    gStrategies[3].ConfirmTF    = 60;
    gStrategies[3].FractalPeriod= 1;
    gStrategies[3].MAPeriod     = 20;
    gStrategies[3].SLPoints     = 900.0;
    gStrategies[3].TPPoints     = 680.0;
    gStrategies[3].TrailStart   = 100.0;
    gStrategies[3].TrailStep    = 50.0;
    gStrategies[3].BEProfit     = 0;
    gStrategies[3].BEOffset     = 0;
    gStrategies[3].MaxSpread    = Filter_MaxSpread;
    gStrategies[3].ExpiryHours  = 48;
    gStrategies[3].Enabled      = Strat_EnableD;
    
    // Strategy E - Scalping
    gStrategies[4].MagicOffset   = 4;
    gStrategies[4].Label        = "GTP_E";
    gStrategies[4].SignalTF     = 1440;
    gStrategies[4].ConfirmTF    = 60;
    gStrategies[4].FractalPeriod= 2;
    gStrategies[4].MAPeriod     = 20;
    gStrategies[4].SLPoints     = 550.0;
    gStrategies[4].TPPoints     = 480.0;
    gStrategies[4].TrailStart   = 80.0;
    gStrategies[4].TrailStep    = 30.0;
    gStrategies[4].BEProfit     = 0;
    gStrategies[4].BEOffset     = 0;
    gStrategies[4].MaxSpread    = Filter_MaxSpread;
    gStrategies[4].ExpiryHours  = 480;
    gStrategies[4].Enabled      = Strat_EnableE;
    
    // Strategy F - Quick Breakout
    gStrategies[5].MagicOffset   = 5;
    gStrategies[5].Label        = "GTP_F";
    gStrategies[5].SignalTF     = 1440;
    gStrategies[5].ConfirmTF    = 60;
    gStrategies[5].FractalPeriod= 1;
    gStrategies[5].MAPeriod     = 20;
    gStrategies[5].SLPoints     = 700.0;
    gStrategies[5].TPPoints     = 30.0;
    gStrategies[5].TrailStart   = 50.0;
    gStrategies[5].TrailStep    = 30.0;
    gStrategies[5].BEProfit     = 0;
    gStrategies[5].BEOffset     = 0;
    gStrategies[5].MaxSpread    = Filter_MaxSpread;
    gStrategies[5].ExpiryHours  = 384;
    gStrategies[5].Enabled      = Strat_EnableF;
    
    // Strategy G - Reversal
    gStrategies[6].MagicOffset   = 6;
    gStrategies[6].Label        = "GTP_G";
    gStrategies[6].SignalTF     = 1440;
    gStrategies[6].ConfirmTF    = 60;
    gStrategies[6].FractalPeriod= 1;
    gStrategies[6].MAPeriod     = 20;
    gStrategies[6].SLPoints     = 150.0;
    gStrategies[6].TPPoints     = 280.0;
    gStrategies[6].TrailStart   = 50.0;
    gStrategies[6].TrailStep    = 20.0;
    gStrategies[6].BEProfit     = 0;
    gStrategies[6].BEOffset     = 0;
    gStrategies[6].MaxSpread    = Filter_MaxSpread;
    gStrategies[6].ExpiryHours  = 240;
    gStrategies[6].Enabled      = Strat_EnableG;
    
    // Strategy H - Multi-Timeframe
    gStrategies[7].MagicOffset   = 7;
    gStrategies[7].Label        = "GTP_H";
    gStrategies[7].SignalTF     = 1440;
    gStrategies[7].ConfirmTF    = 60;
    gStrategies[7].FractalPeriod= 1;
    gStrategies[7].MAPeriod     = 20;
    gStrategies[7].SLPoints     = 250.0;
    gStrategies[7].TPPoints     = 980.0;
    gStrategies[7].TrailStart   = 50.0;
    gStrategies[7].TrailStep    = 20.0;
    gStrategies[7].BEProfit     = 0;
    gStrategies[7].BEOffset     = 0;
    gStrategies[7].MaxSpread    = Filter_MaxSpread;
    gStrategies[7].ExpiryHours  = 432;
    gStrategies[7].Enabled      = Strat_EnableH;
}

//+------------------------------------------------------------------+
//| UPDATE STRATEGY STATE                                            |
//+------------------------------------------------------------------+
void UpdateStrategyState(int strategyIndex)
{
    StrategyConfig cfg = gStrategies[strategyIndex];
    StrategyState st;
    
    // Get timeframe
    int signalTF = (int)cfg.SignalTF;
    int confirmTF = (int)cfg.ConfirmTF;
    
    // Get current and previous fractal values
    st.FractalHigh1 = iFractals(gSymbol, signalTF, MODE_UPPER, 1);
    st.FractalLow1  = iFractals(gSymbol, signalTF, MODE_LOWER, 1);
    st.FractalHigh2 = iFractals(gSymbol, signalTF, MODE_UPPER, 2);
    st.FractalLow2  = iFractals(gSymbol, signalTF, MODE_LOWER, 2);
    
    // Get high/low
    st.LastHigh  = iHigh(gSymbol, signalTF, 1);
    st.LastLow   = iLow(gSymbol, signalTF, 1);
    st.HighBefore = iHigh(gSymbol, signalTF, 2);
    st.LowBefore  = iLow(gSymbol, signalTF, 2);
    
    // Get MA values
    st.MA1 = iMA(gSymbol, signalTF, cfg.MAPeriod, 0, MODE_SMA, PRICE_CLOSE, 1);
    st.MA2 = iMA(gSymbol, signalTF, cfg.MAPeriod, 0, MODE_SMA, PRICE_CLOSE, 2);
    st.MA3 = iMA(gSymbol, signalTF, cfg.MAPeriod, 0, MODE_SMA, PRICE_CLOSE, 3);
    
    // Check breakout conditions
    double breakoutBuffer = 5.0 * gPoint; // Small buffer for confirmation
    
    st.HighBreakout = (st.FractalHigh1 > st.LastHigh + breakoutBuffer);
    st.LowBreakout  = (st.FractalLow1 < st.LastLow - breakoutBuffer);
    
    gState[strategyIndex] = st;
}

//+------------------------------------------------------------------+
//| CHECK SIGNAL CONDITIONS                                          |
//+------------------------------------------------------------------+
void CheckSignalConditions(int strategyIndex)
{
    StrategyConfig cfg  = gStrategies[strategyIndex];
    StrategyState  st   = gState[strategyIndex];
    
    // Reset signals
    gState[strategyIndex].BuySignal  = false;
    gState[strategyIndex].SellSignal = false;
    
    // Count open orders for this strategy
    gState[strategyIndex].OpenOrdersCount = CountStrategyOrders(strategyIndex);
    
    // Check spread filter
    if(gSpread > cfg.MaxSpread)
        return;
    
    // Check max trades limit
    if(gState[strategyIndex].OpenOrdersCount >= Filter_MaxTradesPerSignal)
        return;
    
    // Check trading hours
    if(!CheckTradingHours())
        return;
    
    // Get current price
    double bid = MarketInfo(gSymbol, MODE_BID);
    double ask = MarketInfo(gSymbol, MODE_ASK);
    
    // Check for open trades limit
    if(gState[strategyIndex].OpenOrdersCount >= 1 && cfg.SLPoints <= 0)
        return;
    
    // Buy signal: Price above MA, fractal high broken, MA rising
    bool buyCondition = (
        bid > st.MA1 &&
        st.HighBreakout &&
        st.FractalHigh1 > st.FractalHigh2 &&
        st.MA1 > st.MA2 &&
        Filter_HighLowBreakout
    );
    
    // Sell signal: Price below MA, fractal low broken, MA falling
    bool sellCondition = (
        ask < st.MA1 &&
        st.LowBreakout &&
        st.FractalLow1 < st.FractalLow2 &&
        st.MA1 < st.MA2 &&
        Filter_HighLowBreakout
    );
    
    // Additional filter: MA trend confirmation
    if(Filter_MATrend)
    {
        buyCondition  = buyCondition && (st.MA1 > st.MA3);
        sellCondition = sellCondition && (st.MA1 < st.MA3);
    }
    
    // Check volatility filter
    if(Filter_Volatility)
    {
        double atr = iATR(gSymbol, PERIOD_D1, 14);
        if(atr < 200 * gPoint) // Minimum volatility
            return;
    }
    
    // Check for reversal signal
    if(Filter_Reversal && gState[strategyIndex].OpenOrdersCount > 0)
    {
        buyCondition  = buyCondition && (bid > PositionOpenPrice(strategyIndex, OP_BUY));
        sellCondition = sellCondition && (ask < PositionOpenPrice(strategyIndex, OP_SELL));
    }
    
    // Set signals
    if(buyCondition)
        gState[strategyIndex].BuySignal = true;
    
    if(sellCondition)
        gState[strategyIndex].SellSignal = true;
}

//+------------------------------------------------------------------+
//| EXECUTE BUY ORDER                                                |
//+------------------------------------------------------------------+
void ExecuteBuy(int strategyIndex)
{
    StrategyConfig cfg = gStrategies[strategyIndex];
    StrategyState st = gState[strategyIndex];
    
    double ask = MarketInfo(gSymbol, MODE_ASK);
    
    // Calculate SL and TP
    double sl = ask - cfg.SLPoints * gPoint;
    double tp = ask + cfg.TPPoints * gPoint;
    
    // Apply stop level check
    sl = NormalizeDouble(MathMax(sl, ask - gStopLevel * gPoint), gDigits);
    tp = NormalizeDouble(MathMin(tp, ask + gStopLevel * gPoint), gDigits);
    
    // Get lot size
    double lotSize = gLots[strategyIndex];
    
    // Open order
    int ticket = OrderSend(
        gSymbol,
        OP_BUY,
        lotSize,
        ask,
        (int)(3 * gDigitsAdjust),
        sl,
        tp,
        StringFormat("%s [%s] %s", Gen_Comment, cfg.Label, TimeToStr(TimeCurrent(), TIME_DATE)),
        Gen_MagicNumber + cfg.MagicOffset,
        0,
        clrGreen
    );
    
    if(ticket > 0)
    {
        Print(cfg.Label, " BUY opened. Ticket: ", ticket, " | Lot: ", lotSize, " | SL: ", sl, " | TP: ", tp);
        
        // Update state
        gState[strategyIndex].LastSignalTime = TimeCurrent();
    }
    else
    {
        Print(cfg.Label, " BUY failed. Error: ", GetLastError());
    }
    
    // Reset signal
    gState[strategyIndex].BuySignal = false;
}

//+------------------------------------------------------------------+
//| EXECUTE SELL ORDER                                               |
//+------------------------------------------------------------------+
void ExecuteSell(int strategyIndex)
{
    StrategyConfig cfg = gStrategies[strategyIndex];
    StrategyState st = gState[strategyIndex];
    
    double bid = MarketInfo(gSymbol, MODE_BID);
    
    // Calculate SL and TP
    double sl = bid + cfg.SLPoints * gPoint;
    double tp = bid - cfg.TPPoints * gPoint;
    
    // Apply stop level check
    sl = NormalizeDouble(MathMin(sl, bid + gStopLevel * gPoint), gDigits);
    tp = NormalizeDouble(MathMax(tp, bid - gStopLevel * gPoint), gDigits);
    
    // Get lot size
    double lotSize = gLots[strategyIndex];
    
    // Open order
    int ticket = OrderSend(
        gSymbol,
        OP_SELL,
        lotSize,
        bid,
        (int)(3 * gDigitsAdjust),
        sl,
        tp,
        StringFormat("%s [%s] %s", Gen_Comment, cfg.Label, TimeToStr(TimeCurrent(), TIME_DATE)),
        Gen_MagicNumber + cfg.MagicOffset,
        0,
        clrRed
    );
    
    if(ticket > 0)
    {
        Print(cfg.Label, " SELL opened. Ticket: ", ticket, " | Lot: ", lotSize, " | SL: ", sl, " | TP: ", tp);
        
        // Update state
        gState[strategyIndex].LastSignalTime = TimeCurrent();
    }
    else
    {
        Print(cfg.Label, " SELL failed. Error: ", GetLastError());
    }
    
    // Reset signal
    gState[strategyIndex].SellSignal = false;
}

//+------------------------------------------------------------------+
//| MANAGE ORDERS (Trailing, Break-Even, Close)                      |
//+------------------------------------------------------------------+
void ManageOrders(int strategyIndex)
{
    StrategyConfig cfg = gStrategies[strategyIndex];
    
    // Count total orders
    int totalOrders = CountStrategyOrders(strategyIndex);
    
    // No orders to manage
    if(totalOrders == 0)
        return;
    
    // Loop through all orders
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;
        
        if(OrderSymbol() != gSymbol)
            continue;
        
        if(OrderMagicNumber() != Gen_MagicNumber + cfg.MagicOffset)
            continue;
        
        // Skip pending orders
        if(OrderType() > OP_SELL)
            continue;
        
        double openPrice   = OrderOpenPrice();
        double currentSL   = OrderStopLoss();
        double currentTP  = OrderTakeProfit();
        double bid        = MarketInfo(gSymbol, MODE_BID);
        double ask        = MarketInfo(gSymbol, MODE_ASK);
        double profit     = OrderProfit();
        
        // --- Break-Even Management ---
        if(BE_Enable && cfg.BEProfit > 0)
        {
            double triggerDist = cfg.BEProfit * gPoint;
            
            if(OrderType() == OP_BUY && (bid - openPrice) >= triggerDist)
            {
                double bePrice = openPrice + cfg.BEOffset * gPoint;
                if(currentSL < bePrice || currentSL == 0)
                {
                    if(!OrderModify(OrderTicket(), openPrice, bePrice, currentTP, 0, clrBlue))
                        Print("BE modify failed: ", GetLastError());
                }
            }
            else if(OrderType() == OP_SELL && (openPrice - ask) >= triggerDist)
            {
                double bePrice = openPrice - cfg.BEOffset * gPoint;
                if(currentSL > bePrice || currentSL == 0)
                {
                    if(!OrderModify(OrderTicket(), openPrice, bePrice, currentTP, 0, clrBlue))
                        Print("BE modify failed: ", GetLastError());
                }
            }
        }
        
        // --- Trailing Stop Loss ---
        if(Trail_Enable)
        {
            double profitDist = (OrderType() == OP_BUY) ? (bid - openPrice) : (openPrice - ask);
            
            if(profitDist >= Trail_StartPoints * gPoint)
            {
                double newSL;
                if(OrderType() == OP_BUY)
                {
                    newSL = NormalizeDouble(bid - Trail_StepPoints * gPoint, gDigits);
                    if(newSL > currentSL || currentSL == 0)
                    {
                        if(!OrderModify(OrderTicket(), openPrice, newSL, currentTP, 0, clrNONE))
                            Print("Trail modify failed: ", GetLastError());
                    }
                }
                else
                {
                    newSL = NormalizeDouble(ask + Trail_StepPoints * gPoint, gDigits);
                    if(newSL < currentSL || currentSL == 0)
                    {
                        if(!OrderModify(OrderTicket(), openPrice, newSL, currentTP, 0, clrNONE))
                            Print("Trail modify failed: ", GetLastError());
                    }
                }
            }
        }
        
        // --- Zone Recovery ---
        if(ZR_Enable && totalOrders > 0)
        {
            // Recovery logic: if price moves against position by X points, add another position
            double recoveryDistance = cfg.SLPoints * 0.5 * gPoint;
            
            if(OrderType() == OP_BUY && (openPrice - ask) >= recoveryDistance)
            {
                // Price moved against buy - add recovery trade
                double recoveryLot = NormalizeDouble(OrderLots() * ZR_LotMultiplier, 2);
                recoveryLot = MathMin(recoveryLot, gMaxLot);
                
                double recoverySL = ask - cfg.SLPoints * gPoint * 0.8;
                double recoveryTP = ask + cfg.TPPoints * gPoint * 0.5;
                
                OrderSend(gSymbol, OP_BUY, recoveryLot, ask, (int)(3 * gDigitsAdjust), 
                          recoverySL, recoveryTP, StringFormat("ZR_%s", cfg.Label), 
                          Gen_MagicNumber + cfg.MagicOffset, 0, clrLime);
            }
            else if(OrderType() == OP_SELL && (bid - openPrice) >= recoveryDistance)
            {
                // Price moved against sell - add recovery trade
                double recoveryLot = NormalizeDouble(OrderLots() * ZR_LotMultiplier, 2);
                recoveryLot = MathMin(recoveryLot, gMaxLot);
                
                double recoverySL = bid + cfg.SLPoints * gPoint * 0.8;
                double recoveryTP = bid - cfg.TPPoints * gPoint * 0.5;
                
                OrderSend(gSymbol, OP_SELL, recoveryLot, bid, (int)(3 * gDigitsAdjust),
                          recoverySL, recoveryTP, StringFormat("ZR_%s", cfg.Label),
                          Gen_MagicNumber + cfg.MagicOffset, 0, clrLime);
            }
        }
        
        // --- Auto-close on signal reversal ---
        if(Filter_Reversal)
        {
            if(OrderType() == OP_BUY && gState[strategyIndex].SellSignal)
            {
                if(!OrderClose(OrderTicket(), OrderLots(), bid, (int)(3 * gDigitsAdjust), clrMagenta))
                    Print("Close failed: ", GetLastError());
            }
            else if(OrderType() == OP_SELL && gState[strategyIndex].BuySignal)
            {
                if(!OrderClose(OrderTicket(), OrderLots(), ask, (int)(3 * gDigitsAdjust), clrMagenta))
                    Print("Close failed: ", GetLastError());
            }
        }
        
        // --- Virtual Expiration ---
        if(Filter_UseVirtualExpiry && cfg.ExpiryHours > 0)
        {
            datetime expiryTime = OrderOpenTime() + cfg.ExpiryHours * 3600;
            if(TimeCurrent() > expiryTime)
            {
                if(OrderType() == OP_BUY)
                    if(!OrderClose(OrderTicket(), OrderLots(), bid, (int)(3 * gDigitsAdjust), clrOrange))
                        Print("Expiry close failed: ", GetLastError());
                else if(OrderType() == OP_SELL)
                    if(!OrderClose(OrderTicket(), OrderLots(), ask, (int)(3 * gDigitsAdjust), clrOrange))
                        Print("Expiry close failed: ", GetLastError());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| HELPER FUNCTIONS                                                 |
//+------------------------------------------------------------------+

// Check if symbol is gold
bool IsGoldSymbol()
{
    string sym = Symbol();
    return (
        StringFind(sym, "XAUUSD") >= 0 ||
        StringFind(sym, "xauusd") >= 0 ||
        StringFind(sym, "GOLD") >= 0 ||
        StringFind(sym, "gold") >= 0
    );
}

// Update market info
void UpdateMarketInfo()
{
    gSpread = MarketInfo(gSymbol, MODE_SPREAD);
    gBalance = AccountBalance();
    gEquity = AccountEquity();
    
    if(MM_UseEquity)
        gBalance = gEquity;
}

// Calculate lot size based on risk mode
double CalculateLotSize(int strategyIndex, double baseLot)
{
    double lot = baseLot;
    
    if(MM_RiskMode == 0) // Manual lot
    {
        lot = NormalizeDouble(baseLot, 2);
    }
    else if(MM_RiskMode == 1) // Risk Percentage
    {
        double riskAmount = gBalance * (MM_RiskPerTrade / 100.0);
        double riskPoints = gStrategies[strategyIndex].SLPoints * gPoint;
        if(riskPoints > 0)
            lot = riskAmount / (riskPoints / gPoint);
        
        lot = NormalizeDouble(lot, 2);
    }
    else if(MM_RiskMode == 2) // Lots per balance
    {
        lot = MathFloor(gBalance / MM_LotPerBalanceStep) * baseLot;
        lot = NormalizeDouble(lot, 2);
    }
    
    // Ensure within broker limits
    lot = MathMax(lot, gMinLot);
    lot = MathMin(lot, gMaxLot);
    
    // Only increase mode
    if(MM_OnlyIncrease && ArraySize(gLots) > strategyIndex)
        if(lot < gLots[strategyIndex])
            lot = gLots[strategyIndex];
    
    return lot;
}

// Count orders for a strategy
int CountStrategyOrders(int strategyIndex)
{
    int cnt = 0;
    int magic = Gen_MagicNumber + gStrategies[strategyIndex].MagicOffset;
    
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;
        if(OrderSymbol() != gSymbol)
            continue;
        if(OrderMagicNumber() != magic)
            continue;
        if(OrderType() > OP_SELL)
            continue;
        cnt++;
    }
    return cnt;
}

// Get position open price for specific type
double PositionOpenPrice(int strategyIndex, int orderType)
{
    int magic = Gen_MagicNumber + gStrategies[strategyIndex].MagicOffset;
    
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;
        if(OrderSymbol() != gSymbol)
            continue;
        if(OrderMagicNumber() != magic)
            continue;
        if(OrderType() != orderType)
            continue;
        return OrderOpenPrice();
    }
    return 0;
}

// Check if trading is allowed based on hours
bool CheckTradingHours()
{
    if(!TH_Enable)
        return true;
    
    datetime now = TimeCurrent();
    int day = TimeDayOfWeek(now);
    int hour = TimeHour(now);
    
    // Simple day/hour check
    if(day < TH_StartDay || day > TH_EndDay)
        return TH_AllowWeekend && (day == 0 || day == 6);
    
    if(hour < TH_StartHour || hour >= TH_EndHour)
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| INFO PANEL                                                       |
//+------------------------------------------------------------------+
void CreateInfoPanel()
{
    ObjectCreate("GTP_Panel", OBJ_LABEL, 0, 0, 0);
    ObjectSet("GTP_Panel", OBJPROP_CORNER, 0);
    ObjectSet("GTP_Panel", OBJPROP_XDISTANCE, 10);
    ObjectSet("GTP_Panel", OBJPROP_YDISTANCE, 10);
    ObjectSetText("GTP_Panel", "Gold Trade Pro EA v2.00", 12, "Arial", clrGold);
    ObjectSet("GTP_Panel", OBJPROP_BACK, false);
    ObjectSet("GTP_Panel", OBJPROP_SELECTABLE, false);
    
    ObjectCreate("GTP_Info", OBJ_LABEL, 0, 0, 0);
    ObjectSet("GTP_Info", OBJPROP_CORNER, 0);
    ObjectSet("GTP_Info", OBJPROP_XDISTANCE, 10);
    ObjectSet("GTP_Info", OBJPROP_YDISTANCE, 30);
    ObjectSetText("GTP_Info", "", 10, "Courier New", clrWhite);
    ObjectSet("GTP_Info", OBJPROP_BACK, false);
    ObjectSet("GTP_Info", OBJPROP_SELECTABLE, false);
}

void UpdateInfoPanel()
{
    string info = "";
    
    info += "Account: " + IntegerToString(AccountNumber()) + "\n";
    info += "Balance: " + DoubleToStr(AccountBalance(), 2) + "\n";
    info += "Equity: " + DoubleToStr(AccountEquity(), 2) + "\n";
    info += "Spread: " + IntegerToString((int)gSpread) + "\n";
    info += "----------------------------------------\n";
    
    int totalActive = 0;
    for(int s = 0; s < gTotalStrategies; s++)
    {
        if(gStrategies[s].Enabled)
        {
            int cnt = CountStrategyOrders(s);
            totalActive += cnt;
            info += StringFormat("%s: %d orders | Lots: %.2f\n", 
                gStrategies[s].Label, cnt, gLots[s]);
        }
    }
    
    info += "----------------------------------------\n";
    info += "Total Active: " + IntegerToString(totalActive) + "\n";
    info += "Server: " + AccountServer() + "\n";
    info += "www.fxprosystems.com";
    
    ObjectSetText("GTP_Info", info, 9, "Courier New", clrLime);
}

//+------------------------------------------------------------------+
//| ON_TIMER (Optional: check every minute)                          |
//+------------------------------------------------------------------+
datetime gLastMinuteCheck = 0;

void OnTimer()
{
    datetime now = TimeCurrent();
    
    // Check every minute
    if(now - gLastMinuteCheck < 60)
        return;
    
    gLastMinuteCheck = now;
    
    // Update lot sizes for all strategies
    for(int i = 0; i < gTotalStrategies; i++)
    {
        if(MM_RiskMode > 0)
            gLots[i] = CalculateLotSize(i, MM_StartLots);
    }
}

//+------------------------------------------------------------------+