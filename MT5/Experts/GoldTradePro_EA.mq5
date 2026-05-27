//+------------------------------------------------------------------+
//|                   Gold Trade Pro EA (Clean MT5)                   |
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
#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| ENUMS                                                            |
//+------------------------------------------------------------------+
enum ENUM_SIGNAL_MODE   { SIGNAL_FRACTAL_MA = 0, SIGNAL_MA_CROSS = 1 };
enum ENUM_TIMEFRAME    { TF_D1 = 1440, TF_H4 = 240, TF_H1 = 60, TF_M30 = 30, TF_M15 = 15 };

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== General ==="
bool    Gen_ShowInfoPanel      = true;     // Show info panel on chart
double  Gen_PanelSizeAdjust    = 1.0;      // Panel size multiplier
int     Gen_MagicNumber        = 1000;      // EA Magic Number
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
bool    Filter_UseVirtualExpiry = true;    // Use virtual order expiration

input group "=== Lot Size ==="
int     MM_RiskMode            = 0;        // 0=Manual, 1=RPT, 2=LotsPerBalance
double  MM_StartLots           = 0.01;     // Starting lot size
int     MM_LotPerBalanceStep   = 600;      // Balance per lot step
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
int     TH_EndDay               = 6;        // End day (0=Sun..6=Sat)
int     TH_EndHour             = 24;       // End hour (0-24)
bool    TH_AllowWeekend        = false;    // Allow weekend trading

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+

// Trade instance
CTrade gTrade;

// Strategy configuration structure
struct SStrategyConfig
{
    int      MagicOffset;        // Magic number offset
    string   Label;              // Strategy label for orders
    int      SignalTF;           // Signal timeframe (minutes)
    int      ConfirmTF;          // Confirmation timeframe (minutes)
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
SStrategyConfig  gStrategies[8];

// Runtime state per strategy
struct SStrategyState
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

SStrategyState gState[8];

// Global tracking
int      gTotalStrategies = 8;
string   gSymbol          = "";
double   gPoint           = 0;
int      gDigits          = 0;
double   gSpread          = 0;
long     gStopLevel       = 0;
double   gMinLot          = 0;
double   gMaxLot          = 0;
double   gLotStep         = 0;
double   gBalance         = 0;
double   gEquity          = 0;
double   gLots[];         // Dynamic lot array per strategy
datetime gLastBarTime     = 0;
datetime gLastBarTimeM5   = 0;
bool     gInitialized     = false;

//+------------------------------------------------------------------+
//| EXPERT INITIALIZATION                                            |
//+------------------------------------------------------------------+
int OnInit()
{
    // Set trade parameters
    gTrade.SetExpertMagicNumber(Gen_MagicNumber);
    gTrade.SetDeviationInPoints(3);
    gTrade.SetTypeFilling(ORDER_FILLING_FOK);
    gTrade.SetComment(Gen_Comment);
    
    // Initialize symbol info
    gSymbol = Symbol();
    gPoint  = SymbolInfoDouble(gSymbol, SYMBOL_POINT);
    gDigits = (int)SymbolInfoInteger(gSymbol, SYMBOL_DIGITS);
    
    // Handle 3/5 digit brokers (normalize to 2 decimal places for gold)
    if(gDigits == 3 || gDigits == 5)
        gPoint *= 10;
    
    // Get market info
    gSpread    = SymbolInfoInteger(gSymbol, SYMBOL_SPREAD);
    gStopLevel = SymbolInfoInteger(gSymbol, SYMBOL_TRADE_STOPS_LEVEL);
    gMinLot    = SymbolInfoDouble(gSymbol, SYMBOL_VOLUME_MIN);
    gMaxLot    = SymbolInfoDouble(gSymbol, SYMBOL_VOLUME_MAX);
    gLotStep   = SymbolInfoDouble(gSymbol, SYMBOL_VOLUME_STEP);
    gBalance   = AccountInfoDouble(ACCOUNT_BALANCE);
    gEquity    = AccountInfoDouble(ACCOUNT_EQUITY);
    
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
    Print("Account: ", (int)AccountInfoInteger(ACCOUNT_LOGIN), 
          " | Balance: ", AccountInfoDouble(ACCOUNT_BALANCE));
    
    gInitialized = true;
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| EXPERT DEINIT                                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Comment("");
    ObjectsDeleteAll(0, "GTP_");
    gInitialized = false;
}

//+------------------------------------------------------------------+
//| EXPERT TICK                                                      |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!gInitialized)
        return;
    
    // Update market info
    UpdateMarketInfo();
    
    // Check for new bar (main timeframe)
    datetime currentBarTime = (datetime)SeriesInfoInteger(gSymbol, PERIOD_D1, SERIES_LAST_BAR_TIME);
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
    gStrategies[0].Label         = "GTP_A";
    gStrategies[0].SignalTF      = PERIOD_D1;
    gStrategies[0].ConfirmTF     = PERIOD_H1;
    gStrategies[0].FractalPeriod = 1;
    gStrategies[0].MAPeriod     = 20;
    gStrategies[0].SLPoints      = 150.0;
    gStrategies[0].TPPoints      = 680.0;
    gStrategies[0].TrailStart    = 50.0;
    gStrategies[0].TrailStep     = 30.0;
    gStrategies[0].BEProfit      = 0;
    gStrategies[0].BEOffset      = 0;
    gStrategies[0].MaxSpread     = Filter_MaxSpread;
    gStrategies[0].ExpiryHours   = 408;
    gStrategies[0].Enabled       = Strat_EnableA;
    
    // Strategy B - Aggressive Breakout
    gStrategies[1].MagicOffset   = 1;
    gStrategies[1].Label         = "GTP_B";
    gStrategies[1].SignalTF      = PERIOD_D1;
    gStrategies[1].ConfirmTF     = PERIOD_H1;
    gStrategies[1].FractalPeriod = 1;
    gStrategies[1].MAPeriod     = 20;
    gStrategies[1].SLPoints      = 400.0;
    gStrategies[1].TPPoints      = 380.0;
    gStrategies[1].TrailStart    = 80.0;
    gStrategies[1].TrailStep     = 40.0;
    gStrategies[1].BEProfit      = 0;
    gStrategies[1].BEOffset      = 0;
    gStrategies[1].MaxSpread     = Filter_MaxSpread;
    gStrategies[1].ExpiryHours   = 168;
    gStrategies[1].Enabled       = Strat_EnableB;
    
    // Strategy C - Swing
    gStrategies[2].MagicOffset   = 2;
    gStrategies[2].Label         = "GTP_C";
    gStrategies[2].SignalTF      = PERIOD_D1;
    gStrategies[2].ConfirmTF     = PERIOD_H1;
    gStrategies[2].FractalPeriod = 2;
    gStrategies[2].MAPeriod     = 20;
    gStrategies[2].SLPoints      = 900.0;
    gStrategies[2].TPPoints      = 980.0;
    gStrategies[2].TrailStart    = 100.0;
    gStrategies[2].TrailStep     = 50.0;
    gStrategies[2].BEProfit      = 0;
    gStrategies[2].BEOffset      = 0;
    gStrategies[2].MaxSpread     = Filter_MaxSpread;
    gStrategies[2].ExpiryHours   = 408;
    gStrategies[2].Enabled       = Strat_EnableC;
    
    // Strategy D - Trend Following
    gStrategies[3].MagicOffset   = 3;
    gStrategies[3].Label         = "GTP_D";
    gStrategies[3].SignalTF      = PERIOD_D1;
    gStrategies[3].ConfirmTF     = PERIOD_H1;
    gStrategies[3].FractalPeriod = 1;
    gStrategies[3].MAPeriod     = 20;
    gStrategies[3].SLPoints      = 900.0;
    gStrategies[3].TPPoints      = 680.0;
    gStrategies[3].TrailStart    = 100.0;
    gStrategies[3].TrailStep     = 50.0;
    gStrategies[3].BEProfit      = 0;
    gStrategies[3].BEOffset      = 0;
    gStrategies[3].MaxSpread     = Filter_MaxSpread;
    gStrategies[3].ExpiryHours   = 48;
    gStrategies[3].Enabled       = Strat_EnableD;
    
    // Strategy E - Scalping
    gStrategies[4].MagicOffset   = 4;
    gStrategies[4].Label         = "GTP_E";
    gStrategies[4].SignalTF      = PERIOD_D1;
    gStrategies[4].ConfirmTF     = PERIOD_H1;
    gStrategies[4].FractalPeriod = 2;
    gStrategies[4].MAPeriod     = 20;
    gStrategies[4].SLPoints      = 550.0;
    gStrategies[4].TPPoints      = 480.0;
    gStrategies[4].TrailStart    = 80.0;
    gStrategies[4].TrailStep     = 30.0;
    gStrategies[4].BEProfit      = 0;
    gStrategies[4].BEOffset      = 0;
    gStrategies[4].MaxSpread     = Filter_MaxSpread;
    gStrategies[4].ExpiryHours   = 480;
    gStrategies[4].Enabled       = Strat_EnableE;
    
    // Strategy F - Quick Breakout
    gStrategies[5].MagicOffset   = 5;
    gStrategies[5].Label         = "GTP_F";
    gStrategies[5].SignalTF      = PERIOD_D1;
    gStrategies[5].ConfirmTF     = PERIOD_H1;
    gStrategies[5].FractalPeriod = 1;
    gStrategies[5].MAPeriod     = 20;
    gStrategies[5].SLPoints      = 700.0;
    gStrategies[5].TPPoints      = 30.0;
    gStrategies[5].TrailStart    = 50.0;
    gStrategies[5].TrailStep     = 30.0;
    gStrategies[5].BEProfit      = 0;
    gStrategies[5].BEOffset      = 0;
    gStrategies[5].MaxSpread     = Filter_MaxSpread;
    gStrategies[5].ExpiryHours   = 384;
    gStrategies[5].Enabled       = Strat_EnableF;
    
    // Strategy G - Reversal
    gStrategies[6].MagicOffset   = 6;
    gStrategies[6].Label         = "GTP_G";
    gStrategies[6].SignalTF      = PERIOD_D1;
    gStrategies[6].ConfirmTF     = PERIOD_H1;
    gStrategies[6].FractalPeriod = 1;
    gStrategies[6].MAPeriod     = 20;
    gStrategies[6].SLPoints      = 150.0;
    gStrategies[6].TPPoints      = 280.0;
    gStrategies[6].TrailStart    = 50.0;
    gStrategies[6].TrailStep     = 20.0;
    gStrategies[6].BEProfit      = 0;
    gStrategies[6].BEOffset      = 0;
    gStrategies[6].MaxSpread     = Filter_MaxSpread;
    gStrategies[6].ExpiryHours   = 240;
    gStrategies[6].Enabled       = Strat_EnableG;
    
    // Strategy H - Multi-Timeframe
    gStrategies[7].MagicOffset   = 7;
    gStrategies[7].Label         = "GTP_H";
    gStrategies[7].SignalTF      = PERIOD_D1;
    gStrategies[7].ConfirmTF     = PERIOD_H1;
    gStrategies[7].FractalPeriod = 1;
    gStrategies[7].MAPeriod     = 20;
    gStrategies[7].SLPoints      = 250.0;
    gStrategies[7].TPPoints      = 980.0;
    gStrategies[7].TrailStart    = 50.0;
    gStrategies[7].TrailStep     = 20.0;
    gStrategies[7].BEProfit      = 0;
    gStrategies[7].BEOffset      = 0;
    gStrategies[7].MaxSpread     = Filter_MaxSpread;
    gStrategies[7].ExpiryHours   = 432;
    gStrategies[7].Enabled       = Strat_EnableH;
}

//+------------------------------------------------------------------+
//| UPDATE STRATEGY STATE                                            |
//+------------------------------------------------------------------+
void UpdateStrategyState(int strategyIndex)
{
    SStrategyConfig cfg = gStrategies[strategyIndex];
    SStrategyState st;
    
    // Get timeframe
    ENUM_TIMEFRAMES signalTF = (ENUM_TIMEFRAMES)cfg.SignalTF;
    ENUM_TIMEFRAMES confirmTF = (ENUM_TIMEFRAMES)cfg.ConfirmTF;
    
    // Get current and previous fractal values
    st.FractalHigh1 = iFractals(gSymbol, signalTF, MODE_UPPER, 1);
    st.FractalLow1  = iFractals(gSymbol, signalTF, MODE_LOWER, 1);
    st.FractalHigh2 = iFractals(gSymbol, signalTF, MODE_UPPER, 2);
    st.FractalLow2  = iFractals(gSymbol, signalTF, MODE_LOWER, 2);
    
    // Get high/low
    st.LastHigh   = iHigh(gSymbol, signalTF, 1);
    st.LastLow    = iLow(gSymbol, signalTF, 1);
    st.HighBefore = iHigh(gSymbol, signalTF, 2);
    st.LowBefore  = iLow(gSymbol, signalTF, 2);
    
    // Get MA values
    st.MA1 = iMA(gSymbol, signalTF, cfg.MAPeriod, 0, MODE_SMA, PRICE_CLOSE, 1);
    st.MA2 = iMA(gSymbol, signalTF, cfg.MAPeriod, 0, MODE_SMA, PRICE_CLOSE, 2);
    st.MA3 = iMA(gSymbol, signalTF, cfg.MAPeriod, 0, MODE_SMA, PRICE_CLOSE, 3);
    
    // Check breakout conditions
    double breakoutBuffer = 5.0 * gPoint;
    
    st.HighBreakout = (st.FractalHigh1 > st.LastHigh + breakoutBuffer);
    st.LowBreakout  = (st.FractalLow1 < st.LastLow - breakoutBuffer);
    
    gState[strategyIndex] = st;
}

//+------------------------------------------------------------------+
//| CHECK SIGNAL CONDITIONS                                          |
//+------------------------------------------------------------------+
void CheckSignalConditions(int strategyIndex)
{
    SStrategyConfig cfg = gStrategies[strategyIndex];
    SStrategyState st = gState[strategyIndex];
    
    // Reset signals
    gState[strategyIndex].BuySignal  = false;
    gState[strategyIndex].SellSignal = false;
    
    // Count open orders for this strategy
    gState[strategyIndex].OpenOrdersCount = CountStrategyPositions(strategyIndex);
    
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
    double bid = SymbolInfoDouble(gSymbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(gSymbol, SYMBOL_ASK);
    
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
        if(atr < 200 * gPoint)
            return;
    }
    
    // Check for reversal signal
    if(Filter_Reversal && gState[strategyIndex].OpenOrdersCount > 0)
    {
        double posPrice = GetPositionOpenPrice(strategyIndex, POSITION_TYPE_BUY);
        if(posPrice > 0)
            buyCondition = buyCondition && (bid > posPrice);
        
        posPrice = GetPositionOpenPrice(strategyIndex, POSITION_TYPE_SELL);
        if(posPrice > 0)
            sellCondition = sellCondition && (ask < posPrice);
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
    SStrategyConfig cfg = gStrategies[strategyIndex];
    
    double ask = SymbolInfoDouble(gSymbol, SYMBOL_ASK);
    
    // Calculate SL and TP in price terms
    double sl = NormalizeDouble(ask - cfg.SLPoints * gPoint, gDigits);
    double tp = NormalizeDouble(ask + cfg.TPPoints * gPoint, gDigits);
    
    // Apply stop level check
    double minSL = SymbolInfoDouble(gSymbol, SYMBOL_BID) - gStopLevel * gPoint;
    if(sl < minSL) sl = minSL;
    
    // Get lot size
    double lotSize = gLots[strategyIndex];
    
    // Open order using CTrade
    bool result = gTrade.Buy(lotSize, gSymbol, ask, sl, tp, 
                             StringFormat("%s [%s]", Gen_Comment, cfg.Label));
    
    if(result)
    {
        ulong ticket = gTrade.ResultOrder();
        Print(cfg.Label, " BUY opened. Ticket: ", ticket, 
              " | Lot: ", lotSize, " | SL: ", sl, " | TP: ", tp);
        
        gState[strategyIndex].LastSignalTime = TimeCurrent();
    }
    else
    {
        Print(cfg.Label, " BUY failed. Error: ", gTrade.ResultRetcode(), 
              " - ", gTrade.ResultRetcodeDescription());
    }
    
    // Reset signal
    gState[strategyIndex].BuySignal = false;
}

//+------------------------------------------------------------------+
//| EXECUTE SELL ORDER                                               |
//+------------------------------------------------------------------+
void ExecuteSell(int strategyIndex)
{
    SStrategyConfig cfg = gStrategies[strategyIndex];
    
    double bid = SymbolInfoDouble(gSymbol, SYMBOL_BID);
    
    // Calculate SL and TP in price terms
    double sl = NormalizeDouble(bid + cfg.SLPoints * gPoint, gDigits);
    double tp = NormalizeDouble(bid - cfg.TPPoints * gPoint, gDigits);
    
    // Apply stop level check
    double maxSL = SymbolInfoDouble(gSymbol, SYMBOL_ASK) + gStopLevel * gPoint;
    if(sl > maxSL) sl = maxSL;
    
    // Get lot size
    double lotSize = gLots[strategyIndex];
    
    // Open order using CTrade
    bool result = gTrade.Sell(lotSize, gSymbol, bid, sl, tp,
                              StringFormat("%s [%s]", Gen_Comment, cfg.Label));
    
    if(result)
    {
        ulong ticket = gTrade.ResultOrder();
        Print(cfg.Label, " SELL opened. Ticket: ", ticket,
              " | Lot: ", lotSize, " | SL: ", sl, " | TP: ", tp);
        
        gState[strategyIndex].LastSignalTime = TimeCurrent();
    }
    else
    {
        Print(cfg.Label, " SELL failed. Error: ", gTrade.ResultRetcode(),
              " - ", gTrade.ResultRetcodeDescription());
    }
    
    // Reset signal
    gState[strategyIndex].SellSignal = false;
}

//+------------------------------------------------------------------+
//| MANAGE ORDERS (Trailing, Break-Even, Close)                      |
//+------------------------------------------------------------------+
void ManageOrders(int strategyIndex)
{
    SStrategyConfig cfg = gStrategies[strategyIndex];
    int magic = Gen_MagicNumber + cfg.MagicOffset;
    
    // Count total positions
    int totalPositions = CountStrategyPositions(strategyIndex);
    
    // No positions to manage
    if(totalPositions == 0)
        return;
    
    // Loop through all positions
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!PositionSelect(gSymbol))
            continue;
        
        if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
        
        if(PositionGetInteger(POSITION_TYPE) > POSITION_TYPE_SELL)
            continue;
        
        double openPrice   = PositionGetDouble(POSITION_OPEN_PRICE);
        double currentSL   = PositionGetDouble(POSITION_SL);
        double currentTP   = PositionGetDouble(POSITION_TP);
        ulong   ticket     = PositionGetInteger(POSITION_TICKET);
        
        double bid = SymbolInfoDouble(gSymbol, SYMBOL_BID);
        double ask = SymbolInfoDouble(gSymbol, SYMBOL_ASK);
        double profit = PositionGetDouble(POSITION_PROFIT);
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        
        // --- Break-Even Management ---
        if(BE_Enable && cfg.BEProfit > 0)
        {
            double triggerDist = cfg.BEProfit * gPoint;
            
            if(posType == POSITION_TYPE_BUY && (bid - openPrice) >= triggerDist)
            {
                double bePrice = openPrice + cfg.BEOffset * gPoint;
                if(currentSL < bePrice || currentSL == 0)
                {
                    if(!gTrade.PositionModify(ticket, bePrice, currentTP))
                        Print("BE modify failed: ", gTrade.ResultRetcodeDescription());
                }
            }
            else if(posType == POSITION_TYPE_SELL && (openPrice - ask) >= triggerDist)
            {
                double bePrice = openPrice - cfg.BEOffset * gPoint;
                if(currentSL > bePrice || currentSL == 0)
                {
                    if(!gTrade.PositionModify(ticket, bePrice, currentTP))
                        Print("BE modify failed: ", gTrade.ResultRetcodeDescription());
                }
            }
        }
        
        // --- Trailing Stop Loss ---
        if(Trail_Enable)
        {
            double profitDist = (posType == POSITION_TYPE_BUY) ? 
                                (bid - openPrice) : 
                                (openPrice - ask);
            
            if(profitDist >= Trail_StartPoints * gPoint)
            {
                double newSL;
                if(posType == POSITION_TYPE_BUY)
                {
                    newSL = NormalizeDouble(bid - Trail_StepPoints * gPoint, gDigits);
                    if(newSL > currentSL || currentSL == 0)
                    {
                        if(!gTrade.PositionModify(ticket, newSL, currentTP))
                            Print("Trail modify failed: ", gTrade.ResultRetcodeDescription());
                    }
                }
                else
                {
                    newSL = NormalizeDouble(ask + Trail_StepPoints * gPoint, gDigits);
                    if(newSL < currentSL || currentSL == 0)
                    {
                        if(!gTrade.PositionModify(ticket, newSL, currentTP))
                            Print("Trail modify failed: ", gTrade.ResultRetcodeDescription());
                    }
                }
            }
        }
        
        // --- Zone Recovery ---
        if(ZR_Enable && totalPositions > 0)
        {
            double recoveryDistance = cfg.SLPoints * 0.5 * gPoint;
            
            if(posType == POSITION_TYPE_BUY && (openPrice - ask) >= recoveryDistance)
            {
                double recoveryLot = NormalizeDouble(
                    PositionGetDouble(POSITION_VOLUME) * ZR_LotMultiplier, 2);
                recoveryLot = MathMin(recoveryLot, gMaxLot);
                
                double recoverySL = ask - cfg.SLPoints * gPoint * 0.8;
                double recoveryTP = ask + cfg.TPPoints * gPoint * 0.5;
                
                gTrade.Buy(recoveryLot, gSymbol, ask, recoverySL, recoveryTP,
                           StringFormat("ZR_%s", cfg.Label));
            }
            else if(posType == POSITION_TYPE_SELL && (bid - openPrice) >= recoveryDistance)
            {
                double recoveryLot = NormalizeDouble(
                    PositionGetDouble(POSITION_VOLUME) * ZR_LotMultiplier, 2);
                recoveryLot = MathMin(recoveryLot, gMaxLot);
                
                double recoverySL = bid + cfg.SLPoints * gPoint * 0.8;
                double recoveryTP = bid - cfg.TPPoints * gPoint * 0.5;
                
                gTrade.Sell(recoveryLot, gSymbol, bid, recoverySL, recoveryTP,
                             StringFormat("ZR_%s", cfg.Label));
            }
        }
        
        // --- Auto-close on signal reversal ---
        if(Filter_Reversal)
        {
            if(posType == POSITION_TYPE_BUY && gState[strategyIndex].SellSignal)
            {
                gTrade.PositionClose(ticket);
            }
            else if(posType == POSITION_TYPE_SELL && gState[strategyIndex].BuySignal)
            {
                gTrade.PositionClose(ticket);
            }
        }
        
        // --- Virtual Expiration ---
        if(Filter_UseVirtualExpiry && cfg.ExpiryHours > 0)
        {
            datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
            datetime expiryTime = openTime + cfg.ExpiryHours * 3600;
            
            if(TimeCurrent() > expiryTime)
            {
                gTrade.PositionClose(ticket);
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
    gSpread = SymbolInfoInteger(gSymbol, SYMBOL_SPREAD);
    gBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    gEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    
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

// Count positions for a strategy
int CountStrategyPositions(int strategyIndex)
{
    int cnt = 0;
    int magic = Gen_MagicNumber + gStrategies[strategyIndex].MagicOffset;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!PositionSelectByTicket(PositionGetTicket(i)))
            continue;
        if(PositionGetString(POSITION_SYMBOL) != gSymbol)
            continue;
        if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
        if(PositionGetInteger(POSITION_TYPE) > POSITION_TYPE_SELL)
            continue;
        cnt++;
    }
    return cnt;
}

// Get position open price for specific type
double GetPositionOpenPrice(int strategyIndex, ENUM_POSITION_TYPE posType)
{
    int magic = Gen_MagicNumber + gStrategies[strategyIndex].MagicOffset;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!PositionSelectByTicket(PositionGetTicket(i)))
            continue;
        if(PositionGetString(POSITION_SYMBOL) != gSymbol)
            continue;
        if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
        if(PositionGetInteger(POSITION_TYPE) != posType)
            continue;
        return PositionGetDouble(POSITION_OPEN_PRICE);
    }
    return 0;
}

// Check if trading is allowed based on hours
bool CheckTradingHours()
{
    if(!TH_Enable)
        return true;
    
    datetime now = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(now, dt);
    
    int day = dt.day_of_week;
    int hour = dt.hour;
    
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
    ObjectCreate(0, "GTP_Panel", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "GTP_Panel", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "GTP_Panel", OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, "GTP_Panel", OBJPROP_YDISTANCE, 10);
    ObjectSetString(0, "GTP_Panel", OBJPROP_TEXT, "Gold Trade Pro EA v2.00");
    ObjectSetInteger(0, "GTP_Panel", OBJPROP_FONTSIZE, 12);
    ObjectSetString(0, "GTP_Panel", OBJPROP_FONT, "Arial");
    ObjectSetInteger(0, "GTP_Panel", OBJPROP_COLOR, clrGold);
    ObjectSetInteger(0, "GTP_Panel", OBJPROP_BACK, false);
    ObjectSetInteger(0, "GTP_Panel", OBJPROP_SELECTABLE, false);
    
    ObjectCreate(0, "GTP_Info", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "GTP_Info", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "GTP_Info", OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, "GTP_Info", OBJPROP_YDISTANCE, 30);
    ObjectSetString(0, "GTP_Info", OBJPROP_TEXT, "");
    ObjectSetInteger(0, "GTP_Info", OBJPROP_FONTSIZE, 10);
    ObjectSetString(0, "GTP_Info", OBJPROP_FONT, "Courier New");
    ObjectSetInteger(0, "GTP_Info", OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, "GTP_Info", OBJPROP_BACK, false);
    ObjectSetInteger(0, "GTP_Info", OBJPROP_SELECTABLE, false);
}

void UpdateInfoPanel()
{
    string info = "";
    
    info += "Account: " + IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN)) + "\n";
    info += "Balance: " + DoubleToStr(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\n";
    info += "Equity: " + DoubleToStr(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "\n";
    info += "Spread: " + IntegerToString((int)gSpread) + "\n";
    info += "----------------------------------------\n";
    
    int totalActive = 0;
    for(int s = 0; s < gTotalStrategies; s++)
    {
        if(gStrategies[s].Enabled)
        {
            int cnt = CountStrategyPositions(s);
            totalActive += cnt;
            info += StringFormat("%s: %d orders | Lots: %.2f\n",
                gStrategies[s].Label, cnt, gLots[s]);
        }
    }
    
    info += "----------------------------------------\n";
    info += "Total Active: " + IntegerToString(totalActive) + "\n";
    info += "Server: " + AccountInfoString(ACCOUNT_SERVER) + "\n";
    info += "www.fxprosystems.com";
    
    ObjectSetString(0, "GTP_Info", OBJPROP_TEXT, info);
}

//+------------------------------------------------------------------+
//| ON_TIMER (Optional: check every minute)                           |
//+------------------------------------------------------------------+
datetime gLastMinuteCheck = 0;

void OnTimer()
{
    if(!gInitialized)
        return;
        
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