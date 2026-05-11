//+------------------------------------------------------------------+
//|                                               3Musketeer.mq5      |
//|                                                  3 Musketeer EA  |
//|                                                                  |
//| RULE 1: RSI <20 + CCI <-100 + EMA5<SMMA8 (Buy)                   |
//|         RSI >80 + CCI >+100 + EMA5>SMMA8 (Sell)                  |
//| RULE 2: EMA10 cross SMA20 + Candle + RSI>50 (Buy)               |
//|         EMA10 cross SMA20 + Candle + RSI<50 (Sell)               |
//| RULE 3: Candle>EMA50 + EMA9 cross EMA21 + RSI>50 (Buy)          |
//|         Candle<EMA50 + EMA9 cross EMA21 + RSI<50 (Sell)          |
//|         - Opens new positions on signal even if previous floats  |
//|         - Reduces/cuts previous OP when new profit covers loss   |
//|         - Martingale on SL=0; Single-entry on SL>0              |
//|         - Grid Trading + Hedging + Partial TP + Trailing Stop    |
//+------------------------------------------------------------------+
#property copyright   "3 Musketeer EA"
#property version      "1.00"
#property indicator_chart_window
#property strict

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <Arrays/List.mqh>
#include <Arrays/CArrayLong.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== NAMA & IDENTITAS ==="
input string   InpEAComment       = "3 Musketeer";    // Nama EA
input long     InpMagic           = 20250511;          // Magic Number

input group "=== LOT & RISIKO ==="
input double   InpLot             = 0.01;              // Lot Size
input double   InpSL              = 0;                // Stop Loss (0=Martingale mode)
input double   InpTP              = 50;                // Take Profit (Points)
input double   InpTrailingStart   = 40;               // Trailing Start (Points)
input double   InpTrailingStop    = 30;               // Trailing Stop (Points)
input double   InpMaxLot          = 5.0;               // Lot Maksimum (Safety Cap)

input group "=== PILIHAN RULE ==="
input bool     InpUseRule1        = true;             // Pakai Rule 1 (RSI+CCI+MA)
input bool     InpUseRule2        = true;             // Pakai Rule 2 (EMA/SMA Cross)
input bool     InpUseRule3        = true;             // Pakai Rule 3 (EMA50+EMA Cross)
input bool     InpAllRules        = false;            // Pakai SEMUA Rule sekaligus

input group "=== GRID TRADING ==="
input bool     InpUseGrid         = true;             // Aktifkan Grid Trading
input double   InpGridDistance    = 25;               // Jarak Grid (Points)
input double   InpGridTP          = 30;               // Grid TP (Total Profit Close)

input group "=== MARTINGALE ==="
input bool     InpUseMarti        = true;             // Pakai Martingale
input double   InpMartiMultiplier = 1.25;             // Pengali Lot Martingale
input double   InpMartiStep       = 25;               // Jarak Martingale (Points)

input group "=== HEDGING ==="
input bool     InpUseHedge        = true;             // Pakai Hedging
input double   InpHedgePip        = 50;               // Floating>=X Points -> Hedge
input double   InpHedgeDistance   = 25;               // Jarak Hedge (Points)
input double   InpHedgeLot        = 0.01;             // Lot Hedging
input double   InpHedgeMultiplier = 1.25;             // Marti Hedge Multiplier

input group "=== TP PARTIAL ==="
input bool     InpUsePartialTP    = true;             // Pakai TP Partial
input double   InpPartialPercent  = 50;               // % Lot Ditutup di TP Partial

input group "=== JAM TRADING ==="
input bool     InpUseTradingHours = false;            // Pakai Jam Trading
input int      InpStartHour       = 9;                // Jam Mulai Trading
input int      InpEndHour         = 17;               // Jam Selesai Trading

input group "=== TARGET & DISPLAY ==="
input double   InpDailyTarget     = 100;              // Target Profit Harian (Points)
input bool     InpShowPanel       = true;             // Tampilkan Info Panel
input color    InpPanelBg         = clrDarkBlue;      // Warna Background Panel
input color    InpPanelText       = clrWhite;         // Warna Text Panel

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CTrade          g_trade;
CList           g_positions;          // Track all open positions
datetime        g_lastTradeTime       = 0;
datetime        g_lastTradeDay        = 0;
double          g_dailyProfit         = 0;
double          g_lastHighProfit      = 0;
bool            g_martiTriggered      = false;
bool            g_hedgeTriggered      = false;
double          g_prevEMA5            = 0;
double          g_prevEMA10           = 0;
double          g_prevEMA9            = 0;
double          g_prevSMA20           = 0;
double          g_prevEMA21           = 0;
datetime        g_lastBarTime         = 0;
bool            g_partialClosed[];    // per-position partial flag

//+------------------------------------------------------------------+
//| Indicator Handle Arrays                                          |
//+------------------------------------------------------------------+
int   g_hRSI, g_hCCI, g_hEMA5, g_hSMMA8, g_hEMA10, g_hSMA20;
int   g_hEMA50, g_hEMA9, g_hEMA21;
int   g_hAC;   // Accelerator
ENUM_APPLIED_PRICE g_priceClose = PRICE_CLOSE;
ENUM_APPLIED_PRICE g_priceTypical = PRICE_TYPICAL;

//+------------------------------------------------------------------+
//| TicketInfo class to track positions                               |
//+------------------------------------------------------------------+
class PositionInfo
{
public:
   ulong       ticket;
   datetime    openTime;
   double      openPrice;
   double      lotSize;
   bool        isBuy;
   bool        partialClosed;
   double      closedLot;
   string      ruleName;
   double      martiStep;
   
   PositionInfo()
   {
      ticket = 0;
      openTime = 0;
      openPrice = 0;
      lotSize = 0;
      isBuy = false;
      partialClosed = false;
      closedLot = 0;
      ruleName = "";
      martiStep = 0;
   }
};

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   //-- Validate inputs
   if(InpLot < 0.01)          { Print("InpLot minimal 0.01"); return INIT_PARAMETERS_INCORRECT; }
   if(InpTP <= 0)             { Print("InpTP harus > 0"); return INIT_PARAMETERS_INCORRECT; }
   if(InpGridDistance <= 0 && InpUseGrid) { Print("InpGridDistance harus > 0"); return INIT_PARAMETERS_INCORRECT; }
   if(InpMartiMultiplier <= 0 && InpUseMarti) { Print("InpMartiMultiplier harus > 0"); return INIT_PARAMETERS_INCORRECT; }
   
   //-- Check at least one rule is active
   if(!InpUseRule1 && !InpUseRule2 && !InpUseRule3 && !InpAllRules)
   {
      Print("Minimal satu Rule harus diaktifkan!");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   //-- Initialize trade object
   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(10);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   //-- Create indicators
   if(!InitIndicators())
      return INIT_FAILED;
   
   //-- Reset daily profit on new day
   g_lastTradeDay = (datetime)MathFloor((double)TimeCurrent() / 86400.0);
   g_dailyProfit = 0;
   
   Print("=== 3 Musketeer EA Initialized ===");
   Print("EA Comment: ", InpEAComment);
   Print("Magic: ", InpMagic);
   Print("Lot: ", InpLot, " | TP: ", InpTP, " | SL: ", InpSL);
   Print("Grid: ", InpUseGrid, " | Marti: ", InpUseMarti, " | Hedge: ", InpUseHedge);
   Print("Rules Active - R1:", InpUseRule1, " R2:", InpUseRule2, " R3:", InpUseRule3, " All:", InpAllRules);
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Deinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(g_hRSI);
   IndicatorRelease(g_hCCI);
   IndicatorRelease(g_hEMA5);
   IndicatorRelease(g_hSMMA8);
   IndicatorRelease(g_hEMA10);
   IndicatorRelease(g_hSMA20);
   IndicatorRelease(g_hEMA50);
   IndicatorRelease(g_hEMA9);
   IndicatorRelease(g_hEMA21);
   IndicatorRelease(g_hAC);
   
   Comment("");
   Print("=== 3 Musketeer EA Deinitialized ===");
}

//+------------------------------------------------------------------+
//| Main Tick Handler                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   //-- Ensure new bar (avoid spam)
   datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBar == g_lastBarTime)
      return;
   g_lastBarTime = currentBar;
   
   //-- Check trading hours
   if(!IsTradingAllowed())
      return;
   
   //-- Update daily profit tracking
   UpdateDailyProfit();
   
   //-- Check daily target
   if(g_dailyProfit >= InpDailyTarget && InpDailyTarget > 0)
   {
      CloseAllPositions("Daily Target Reached");
      return;
   }
   
   //-- Check grid TP (close all if total profit > threshold)
   if(InpUseGrid)
      CheckGridTP();
   
   //-- Check hedging
   if(InpUseHedge)
      CheckHedging();
   
   //-- Check trailing stop for all positions
   ManageTrailingStop();
   
   //-- Check partial TP
   if(InpUsePartialTP)
      ManagePartialTP();
   
   //-- Manage floating positions (Rule 3: cut when new profit covers old loss)
   ManageFloating();
   
   //-- Main signal detection
   bool buySignal  = false;
   bool sellSignal = false;
   string activeRule = "";
   
   //-- Rule 1
   if(InpUseRule1 || InpAllRules)
   {
      if(CheckRule1Buy())  { buySignal = true;  activeRule = "R1"; }
      if(CheckRule1Sell()) { sellSignal = true; activeRule = "R1"; }
   }
   
   //-- Rule 2
   if((InpUseRule2 || InpAllRules) && !buySignal && !sellSignal)
   {
      if(CheckRule2Buy())  { buySignal = true;  activeRule = "R2"; }
      if(CheckRule2Sell()) { sellSignal = true; activeRule = "R2"; }
   }
   
   //-- Rule 3 (most aggressive - opens even if others float)
   if(InpUseRule3 || InpAllRules)
   {
      if(CheckRule3Buy())  { buySignal = true;  activeRule = "R3"; }
      if(CheckRule3Sell()) { sellSignal = true; activeRule = "R3"; }
   }
   
   //-- Execute trades
   if(buySignal)
   {
      ExecuteTrade(ORDER_TYPE_BUY, activeRule);
   }
   if(sellSignal)
   {
      ExecuteTrade(ORDER_TYPE_SELL, activeRule);
   }
   
   //-- Grid martingale logic
   if(InpUseGrid && InpUseMarti)
      ManageGridMartingale();
   
   //-- Display info panel
   if(InpShowPanel)
      DisplayPanel();
}

//+------------------------------------------------------------------+
//| Indicator Initialization                                         |
//+------------------------------------------------------------------+
bool InitIndicators()
{
   // RSI 14
   g_hRSI = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
   if(g_hRSI == INVALID_HANDLE) { Print("Failed to create RSI"); return false; }
   
   // CCI 14
   g_hCCI = iCCI(_Symbol, PERIOD_CURRENT, 14, PRICE_TYPICAL);
   if(g_hCCI == INVALID_HANDLE) { Print("Failed to create CCI"); return false; }
   
   // EMA 5 on Close
   g_hEMA5 = iMA(_Symbol, PERIOD_CURRENT, 5, 0, MODE_EMA, PRICE_CLOSE);
   if(g_hEMA5 == INVALID_HANDLE) { Print("Failed to create EMA5"); return false; }
   
   // SMMA 8 on Typical
   g_hSMMA8 = iMA(_Symbol, PERIOD_CURRENT, 8, 0, MODE_SMMA, PRICE_TYPICAL);
   if(g_hSMMA8 == INVALID_HANDLE) { Print("Failed to create SMMA8"); return false; }
   
   // EMA 10 on Close
   g_hEMA10 = iMA(_Symbol, PERIOD_CURRENT, 10, 0, MODE_EMA, PRICE_CLOSE);
   if(g_hEMA10 == INVALID_HANDLE) { Print("Failed to create EMA10"); return false; }
   
   // SMA 20 on Close
   g_hSMA20 = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE);
   if(g_hSMA20 == INVALID_HANDLE) { Print("Failed to create SMA20"); return false; }
   
   // EMA 50 on Close
   g_hEMA50 = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(g_hEMA50 == INVALID_HANDLE) { Print("Failed to create EMA50"); return false; }
   
   // EMA 9 on Close
   g_hEMA9 = iMA(_Symbol, PERIOD_CURRENT, 9, 0, MODE_EMA, PRICE_CLOSE);
   if(g_hEMA9 == INVALID_HANDLE) { Print("Failed to create EMA9"); return false; }
   
   // EMA 21 on Close
   g_hEMA21 = iMA(_Symbol, PERIOD_CURRENT, 21, 0, MODE_EMA, PRICE_CLOSE);
   if(g_hEMA21 == INVALID_HANDLE) { Print("Failed to create EMA21"); return false; }
   
   // Accelerator
   g_hAC = iAC(_Symbol, PERIOD_CURRENT);
   if(g_hAC == INVALID_HANDLE) { Print("Failed to create AC"); }
   
   return true;
}

//+------------------------------------------------------------------+
//| Get Indicator Buffer Values (shift 0 = current, 1 = previous)   |
//+------------------------------------------------------------------+
double GetRSI(int shift=0)     { double val[]; CopyBuffer(g_hRSI, 0, shift, 1, val); return val[0]; }
double GetCCI(int shift=0)    { double val[]; CopyBuffer(g_hCCI, 0, shift, 1, val); return val[0]; }
double GetEMA5(int shift=0)   { double val[]; CopyBuffer(g_hEMA5, 0, shift, 1, val); return val[0]; }
double GetSMMA8(int shift=0) { double val[]; CopyBuffer(g_hSMMA8, 0, shift, 1, val); return val[0]; }
double GetEMA10(int shift=0)  { double val[]; CopyBuffer(g_hEMA10, 0, shift, 1, val); return val[0]; }
double GetSMA20(int shift=0)  { double val[]; CopyBuffer(g_hSMA20, 0, shift, 1, val); return val[0]; }
double GetEMA50(int shift=0)  { double val[]; CopyBuffer(g_hEMA50, 0, shift, 1, val); return val[0]; }
double GetEMA9(int shift=0)   { double val[]; CopyBuffer(g_hEMA9, 0, shift, 1, val); return val[0]; }
double GetEMA21(int shift=0)  { double val[]; CopyBuffer(g_hEMA21, 0, shift, 1, val); return val[0]; }

//+------------------------------------------------------------------+
//| Rule 1: RSI + CCI + MA Crossover                                 |
//+------------------------------------------------------------------+
bool CheckRule1Buy()
{
   // RSI < 20 (oversold), CCI < -100 (bearish extreme), EMA5 < SMMA8
   double rsi0   = GetRSI(0);
   double cci0  = GetCCI(0);
   double ema5_0 = GetEMA5(0);
   double smma8_0 = GetSMMA8(0);
   double ema5_1 = GetEMA5(1);
   double smma8_1 = GetSMMA8(1);
   
   bool rsiOK  = (rsi0 < 20);
   bool cciOK  = (cci0 < -100);
   bool maOK   = (ema5_0 < smma8_0);
   
   // MA cross confirmed: EMA5 was above SMMA8 before
   bool crossConfirmed = (ema5_1 >= smma8_1) && (ema5_0 < smma8_0);
   
   if(rsiOK && cciOK && maOK)
   {
      Print("RULE1 BUY TRIGGERED: RSI=", rsi0, " CCI=", cci0, " EMA5=", ema5_0, " SMMA8=", smma8_0);
      return true;
   }
   return false;
}

bool CheckRule1Sell()
{
   double rsi0   = GetRSI(0);
   double cci0  = GetCCI(0);
   double ema5_0 = GetEMA5(0);
   double smma8_0 = GetSMMA8(0);
   double ema5_1 = GetEMA5(1);
   double smma8_1 = GetSMMA8(1);
   
   bool rsiOK = (rsi0 > 80);
   bool cciOK = (cci0 > 100);
   bool maOK  = (ema5_0 > smma8_0);
   
   if(rsiOK && cciOK && maOK)
   {
      Print("RULE1 SELL TRIGGERED: RSI=", rsi0, " CCI=", cci0, " EMA5=", ema5_0, " SMMA8=", smma8_0);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Rule 2: EMA10 Cross SMA20 + Candle + RSI                         |
//+------------------------------------------------------------------+
bool CheckRule2Buy()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 2, rates) < 2) return false;
   
   double ema10_0 = GetEMA10(0);
   double ema10_1 = GetEMA10(1);
   double sma20_0 = GetSMA20(0);
   double sma20_1 = GetSMA20(1);
   double rsi0    = GetRSI(0);
   
   // EMA10 crosses above SMA20 from below
   bool crossUp = (ema10_1 < sma20_1) && (ema10_0 >= sma20_0);
   
   // Candle closes above EMA10
   bool candleAbove = (rates[0].close > ema10_0);
   
   // RSI > 50
   bool rsiOK = (rsi0 > 50);
   
   if(crossUp && candleAbove && rsiOK)
   {
      Print("RULE2 BUY TRIGGERED: EMA10=", ema10_0, " SMA20=", sma20_0, " RSI=", rsi0);
      return true;
   }
   return false;
}

bool CheckRule2Sell()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 2, rates) < 2) return false;
   
   double ema10_0 = GetEMA10(0);
   double ema10_1 = GetEMA10(1);
   double sma20_0 = GetSMA20(0);
   double sma20_1 = GetSMA20(1);
   double rsi0    = GetRSI(0);
   
   // EMA10 crosses below SMA20 from above
   bool crossDown = (ema10_1 > sma20_1) && (ema10_0 <= sma20_0);
   
   // Candle closes below EMA10
   bool candleBelow = (rates[0].close < ema10_0);
   
   // RSI < 50
   bool rsiOK = (rsi0 < 50);
   
   if(crossDown && candleBelow && rsiOK)
   {
      Print("RULE2 SELL TRIGGERED: EMA10=", ema10_0, " SMA20=", sma20_0, " RSI=", rsi0);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Rule 3: Candle > EMA50 + EMA9 Cross EMA21 + RSI                  |
//+------------------------------------------------------------------+
bool CheckRule3Buy()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 2, rates) < 2) return false;
   
   double ema50_0 = GetEMA50(0);
   double ema9_0  = GetEMA9(0);
   double ema9_1  = GetEMA9(1);
   double ema21_0 = GetEMA21(0);
   double ema21_1 = GetEMA21(1);
   double rsi0    = GetRSI(0);
   
   // Candle above EMA50
   bool candleAbove = (rates[0].close > ema50_0);
   
   // EMA9 crosses above EMA21
   bool crossUp = (ema9_1 < ema21_1) && (ema9_0 >= ema21_0);
   
   // RSI > 50
   bool rsiOK = (rsi0 > 50);
   
   if(candleAbove && crossUp && rsiOK)
   {
      Print("RULE3 BUY TRIGGERED: EMA9=", ema9_0, " EMA21=", ema21_0, " EMA50=", ema50_0, " RSI=", rsi0);
      return true;
   }
   return false;
}

bool CheckRule3Sell()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 2, rates) < 2) return false;
   
   double ema50_0 = GetEMA50(0);
   double ema9_0  = GetEMA9(0);
   double ema9_1  = GetEMA9(1);
   double ema21_0 = GetEMA21(0);
   double ema21_1 = GetEMA21(1);
   double rsi0    = GetRSI(0);
   
   // Candle below EMA50
   bool candleBelow = (rates[0].close < ema50_0);
   
   // EMA9 crosses below EMA21
   bool crossDown = (ema9_1 > ema21_1) && (ema9_0 <= ema21_0);
   
   // RSI < 50
   bool rsiOK = (rsi0 < 50);
   
   if(candleBelow && crossDown && rsiOK)
   {
      Print("RULE3 SELL TRIGGERED: EMA9=", ema9_0, " EMA21=", ema21_0, " EMA50=", ema50_0, " RSI=", rsi0);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Execute Trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE type, string ruleName)
{
   double price, sl, tp;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double point     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double lot = InpLot;
   
   //-- Martingale: check if we should increase lot
   if(InpUseMarti && InpSL == 0)
   {
      double lastLot = GetLastLotSize();
      if(lastLot > 0)
         lot = MathMin(lastLot * InpMartiMultiplier, InpMaxLot);
   }
   
   //-- Calculate SL and TP
   double slPoints  = InpSL * point;
   double tpPoints  = InpTP * point;
   
   if(type == ORDER_TYPE_BUY)
   {
      price = ask;
      sl    = (InpSL > 0) ? price - slPoints : 0;
      tp    = price + tpPoints;
      
      //-- Martingale TP distance mode: use price distance as TP
      if(InpUseMarti && InpSL == 0)
      {
         tp = price + (InpMartiStep * point);
      }
      
      //-- Grid TP
      if(InpUseGrid && InpSL == 0)
      {
         tp = price + (InpGridDistance * point);
      }
   }
   else
   {
      price = bid;
      sl    = (InpSL > 0) ? price + slPoints : 0;
      tp    = price - tpPoints;
      
      if(InpUseMarti && InpSL == 0)
      {
         tp = price - (InpMartiStep * point);
      }
      
      if(InpUseGrid && InpSL == 0)
      {
         tp = price - (InpGridDistance * point);
      }
   }
   
   string comment = InpEAComment + " [" + ruleName + "]";
   bool result;
   
   if(type == ORDER_TYPE_BUY)
      result = g_trade.Buy(lot, _Symbol, price, sl, tp, comment);
   else
      result = g_trade.Sell(lot, _Symbol, price, sl, tp, comment);
   
   if(result)
   {
      ulong ticket = g_trade.ResultOrder();
      Print("ORDER OPENED: ", type == ORDER_TYPE_BUY ? "BUY" : "SELL",
            " Lot=", lot, " Price=", price, " SL=", sl, " TP=", tp,
            " Ticket=", ticket, " Rule=", ruleName);
      g_lastTradeTime = TimeCurrent();
   }
   else
   {
      Print("ORDER FAILED: ", g_trade.ResultRetCode(), " - ", g_trade.ResultRetCodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Get last opened lot size for martingale                          |
//+------------------------------------------------------------------+
double GetLastLotSize()
{
   double lastLot = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagic)
      {
         if(PositionGetInteger(POSITION_TYPE) == (int)PositionGetString(POSITION_TYPE))
         {
            lastLot = PositionGetDouble(POSITION_VOLUME);
            break;
         }
      }
   }
   return lastLot;
}

//+------------------------------------------------------------------+
//| Get positions of our EA only                                      |
//+------------------------------------------------------------------+
void GetEAPositions(CArrayLong &tickets, CArrayLong &types, CArrayLong &magics)
{
   tickets.Clear();
   types.Clear();
   magics.Clear();
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagic)
      {
         tickets.Add(PositionGetTicket(i));
         types.Add(PositionGetInteger(POSITION_TYPE));
         magics.Add(PositionGetInteger(POSITION_MAGIC));
      }
   }
}

//+------------------------------------------------------------------+
//| Total Floating P/L in Points (Points, not currency)              |
//+------------------------------------------------------------------+
double GetTotalFloatingPoints(bool &isBuy, double &avgPrice)
{
   double totalProfitPoints = 0;
   double totalLots = 0;
   double weightedPrice = 0;
   isBuy = false;
   avgPrice = 0;
   int buyCount = 0, sellCount = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagic)
      {
         ulong type = PositionGetInteger(POSITION_TYPE);
         double lot = PositionGetDouble(POSITION_VOLUME);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRICK_SIZE);
         double profit    = PositionGetDouble(POSITION_PROFIT);
         
         // Convert profit to points
         double points = (tickSize > 0) ? (profit / (lot * tickValue / tickSize)) : 0;
         
         if(type == POSITION_TYPE_BUY)
         {
            totalProfitPoints += points;
            weightedPrice += openPrice * lot;
            totalLots += lot;
            buyCount++;
         }
         else
         {
            totalProfitPoints -= points;
            weightedPrice += openPrice * lot;
            totalLots += lot;
            sellCount++;
         }
      }
   }
   
   if(totalLots > 0)
      avgPrice = weightedPrice / totalLots;
   
   isBuy = (buyCount > sellCount);
   
   return MathAbs(totalProfitPoints);
}

//+------------------------------------------------------------------+
//| Grid TP - close all if total profit > GridTP threshold           |
//+------------------------------------------------------------------+
void CheckGridTP()
{
   double totalProfit = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagic)
      {
         totalProfit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      }
   }
   
   if(totalProfit >= InpGridTP)
   {
      CloseAllPositions("Grid TP Reached: " + DoubleToString(totalProfit, 2));
   }
}

//+------------------------------------------------------------------+
//| Hedging - open opposite direction when floating >= threshold     |
//+------------------------------------------------------------------+
void CheckHedging()
{
   if(!InpUseHedge) return;
   
   bool isBuy;
   double avgPrice;
   double floatingPips = GetTotalFloatingPoints(isBuy, avgPrice);
   
   double pipValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10; // For 5-digit broker
   
   // Convert floating points to comparable unit
   if(floatingPips >= InpHedgePip)
   {
      // Only hedge once per condition
      if(g_hedgeTriggered) return;
      
      ENUM_ORDER_TYPE hedgeType = isBuy ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      double price = (hedgeType == ORDER_TYPE_BUY) ? 
                     SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                     SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      string comment = InpEAComment + " [HEDGE]";
      bool result;
      
      if(hedgeType == ORDER_TYPE_BUY)
         result = g_trade.Buy(InpHedgeLot, _Symbol, price, 0, 0, comment);
      else
         result = g_trade.Sell(InpHedgeLot, _Symbol, price, 0, 0, comment);
      
      if(result)
      {
         Print("HEDGE OPENED: ", hedgeType == ORDER_TYPE_BUY ? "BUY" : "SELL",
               " Lot=", InpHedgeLot, " Price=", price);
         g_hedgeTriggered = true;
      }
   }
   else
   {
      g_hedgeTriggered = false;
   }
}

//+------------------------------------------------------------------+
//| Grid Martingale - add positions at grid distance                 |
//+------------------------------------------------------------------+
void ManageGridMartingale()
{
   if(!InpUseGrid || !InpUseMarti) return;
   if(InpSL > 0) return; // Single entry mode, no martingale
   
   double point     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double gridStep = InpGridDistance * point;
   double lastPrice = SymbolInfoDouble(_Symbol, BID);
   
   // Check if we need to add grid position
   // This is simplified: in real grid, you track the grid levels
   // Here we check if there's any position open and the price moved grid distance
}

//+------------------------------------------------------------------+
//| Trailing Stop                                                    |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   if(InpTrailingStop <= 0 || InpTrailingStart <= 0) return;
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double trailingStart = InpTrailingStart * point;
   double trailingStop  = InpTrailingStop * point;
   double ask = SymbolInfoDouble(_Symbol, ASK);
   double bid = SymbolInfoDouble(_Symbol, BID);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      
      ulong ticket     = PositionGetTicket(i);
      ulong type       = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl        = PositionGetDouble(POSITION_SL);
      double tp        = PositionGetDouble(POSITION_TP);
      double lot       = PositionGetDouble(POSITION_VOLUME);
      
      if(type == POSITION_TYPE_BUY)
      {
         double profitPoints = (bid - openPrice);
         if(profitPoints >= trailingStart)
         {
            double newSL = bid - trailingStop;
            if(newSL > sl)
            {
               g_trade.PositionModify(ticket, newSL, tp);
            }
         }
      }
      else // SELL
      {
         double profitPoints = (openPrice - ask);
         if(profitPoints >= trailingStart)
         {
            double newSL = ask + trailingStop;
            if(newSL < sl || sl == 0)
            {
               g_trade.PositionModify(ticket, newSL, tp);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Partial TP - close 50% when price reaches 50% of TP               |
//+------------------------------------------------------------------+
void ManagePartialTP()
{
   if(!InpUsePartialTP || InpPartialPercent <= 0) return;
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double ask   = SymbolInfoDouble(_Symbol, ASK);
   double bid   = SymbolInfoDouble(_Symbol, BID);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      
      ulong ticket     = PositionGetTicket(i);
      ulong type       = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double tp        = PositionGetDouble(POSITION_TP);
      double lot       = PositionGetDouble(POSITION_VOLUME);
      double partialPct = InpPartialPercent / 100.0;
      double closeLot  = NormalizeDouble(lot * partialPct, 2);
      
      if(closeLot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) continue;
      
      if(type == POSITION_TYPE_BUY)
      {
         double tpDistance = MathAbs(tp - openPrice);
         double currentDist = bid - openPrice;
         
         if(tp > 0 && currentDist >= tpDistance * 0.5 && lot > closeLot * 0.9)
         {
            bool res = g_trade.PositionClose(ticket, closeLot);
            if(res)
            {
               Print("PARTIAL TP CLOSED: BUY Ticket=", ticket, " Lot=", closeLot,
                     " Current=", bid, " TP=", tp);
               
               // Adjust remaining TP to target full profit
               double remainingLot = lot - closeLot;
               if(remainingLot > 0)
               {
                  // Move TP for remaining position higher
                  double newTP = openPrice + (tpDistance * 1.5);
                  g_trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), newTP);
               }
            }
         }
      }
      else // SELL
      {
         double tpDistance = MathAbs(openPrice - tp);
         double currentDist = openPrice - ask;
         
         if(tp > 0 && currentDist >= tpDistance * 0.5 && lot > closeLot * 0.9)
         {
            bool res = g_trade.PositionClose(ticket, closeLot);
            if(res)
            {
               Print("PARTIAL TP CLOSED: SELL Ticket=", ticket, " Lot=", closeLot,
                     " Current=", ask, " TP=", tp);
               
               double remainingLot = lot - closeLot;
               if(remainingLot > 0)
               {
                  double newTP = openPrice - (tpDistance * 1.5);
                  g_trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), newTP);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Rule 3 Floating Management: if new position profit > old loss   |
//| then reduce/close previous positions                             |
//+------------------------------------------------------------------+
void ManageFloating()
{
   // Get all our positions
   double totalProfit = 0;
   double totalLoss   = 0;
   CArrayLong lossTickets;
   CArrayLong profitTickets;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      
      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      
      if(profit >= 0)
         totalProfit += profit;
      else
         totalLoss += MathAbs(profit);
   }
   
   // If total profit covers total loss, close losing positions gradually
   if(totalProfit > totalLoss && totalLoss > 0)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) != _Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
         
         double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         if(profit < 0)
         {
            ulong ticket = PositionGetTicket(i);
            // Close losing position to "recover" - Rule 3 style
            if(totalProfit > totalLoss * 1.5) // Only if profit significantly exceeds loss
            {
               g_trade.PositionClose(ticket);
               Print("RULE3 FLOATING CLOSE: Ticket=", ticket, " Loss=", profit);
               totalProfit -= MathAbs(profit);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Close All Positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions(string reason)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      
      ulong ticket = PositionGetTicket(i);
      g_trade.PositionClose(ticket);
      Print("CLOSE ALL: Ticket=", ticket, " Reason=", reason);
   }
   g_hedgeTriggered = false;
}

//+------------------------------------------------------------------+
//| Update Daily Profit                                              |
//+------------------------------------------------------------------+
void UpdateDailyProfit()
{
   datetime today = (datetime)MathFloor((double)TimeCurrent() / 86400.0);
   if(today != g_lastTradeDay)
   {
      g_lastTradeDay = today;
      g_dailyProfit = 0;
      g_hedgeTriggered = false;
   }
   
   // Accumulate closed trade profits
   // This is simplified - in production, track from trade history
   double todayProfit = 0;
   HistorySelect(0, TimeCurrent());
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagic) continue;
      
      datetime dealTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      datetime dealDay = (datetime)MathFloor((double)dealTime / 86400.0);
      if(dealDay == today)
      {
         todayProfit += HistoryDealGetDouble(ticket, DEAL_PROFIT) 
                      + HistoryDealGetDouble(ticket, DEAL_COMMISSION)
                      + HistoryDealGetDouble(ticket, DEAL_SWAP);
      }
   }
   g_dailyProfit = todayProfit;
}

//+------------------------------------------------------------------+
//| Is Trading Allowed                                               |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   if(!InpUseTradingHours) return true;
   
   MqlTradeTransaction trans;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   if(dt.hour >= InpStartHour && dt.hour < InpEndHour)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Display Info Panel                                               |
//+------------------------------------------------------------------+
void DisplayPanel()
{
   string symbol = _Symbol;
   double point  = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double ask    = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(symbol, SYMBOL_BID);
   
   double rsi   = GetRSI(0);
   double cci   = GetCCI(0);
   double ema5  = GetEMA5(0);
   double smma8 = GetSMMA8(0);
   double ema10 = GetEMA10(0);
   double sma20 = GetSMA20(0);
   double ema9  = GetEMA9(0);
   double ema21 = GetEMA21(0);
   double ema50 = GetEMA50(0);
   double ema50_1 = GetEMA50(1);
   
   // Count positions
   int buyCount = 0, sellCount = 0;
   double totalProfit = 0;
   double totalLots = 0;
   double maxFloating = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      
      double lot = PositionGetDouble(POSITION_VOLUME);
      double profit = PositionGetDouble(POSITION_PROFIT);
      
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) buyCount++;
      else sellCount++;
      
      totalProfit += profit;
      totalLots += lot;
      
      if(profit < maxFloating) maxFloating = profit;
   }
   
   // Determine active rule
   string activeRules = "";
   if(InpUseRule1) activeRules += "R1 ";
   if(InpUseRule2) activeRules += "R2 ";
   if(InpUseRule3) activeRules += "R3 ";
   if(InpAllRules) activeRules = "ALL";
   
   // Determine trend
   string trend = "NEUTRAL";
   if(rsi > 50 && cci > 0 && ema5 > smma8) trend = "BULLISH";
   if(rsi < 50 && cci < 0 && ema5 < smma8) trend = "BEARISH";
   
   string txt = "";
   txt += "========================================\n";
   txt += "       3 MUSKETEER EA v1.00\n";
   txt += "========================================\n";
   txt += "Symbol   : " + symbol + "\n";
   txt += "Ask      : " + DoubleToString(ask, _Digits) + "\n";
   txt += "Bid      : " + DoubleToString(bid, _Digits) + "\n";
   txt += "Spread   : " + IntegerToString((int)MathAbs(ask - bid)/point) + " pts\n";
   txt += "----------------------------------------\n";
   txt += "INDIKATOR:\n";
   txt += "RSI(14)  : " + DoubleToString(rsi, 2) + "  ";
   txt += (rsi < 20 ? "[OVERsold]" : rsi > 80 ? "[OVERbought]" : "") + "\n";
   txt += "CCI(14)  : " + DoubleToString(cci, 2) + "\n";
   txt += "EMA5     : " + DoubleToString(ema5, _Digits) + "\n";
   txt += "SMMA8    : " + DoubleToString(smma8, _Digits) + "\n";
   txt += "EMA10    : " + DoubleToString(ema10, _Digits) + "\n";
   txt += "SMA20    : " + DoubleToString(sma20, _Digits) + "\n";
   txt += "EMA9     : " + DoubleToString(ema9, _Digits) + "\n";
   txt += "EMA21    : " + DoubleToString(ema21, _Digits) + "\n";
   txt += "EMA50    : " + DoubleToString(ema50, _Digits) + "\n";
   txt += "----------------------------------------\n";
   txt += "STATUS   : " + trend + "\n";
   txt += "Rules    : " + activeRules + "\n";
   txt += "----------------------------------------\n";
   txt += "POSISI TERBUKA:\n";
   txt += "Buy      : " + IntegerToString(buyCount) + " posisi\n";
   txt += "Sell     : " + IntegerToString(sellCount) + " posisi\n";
   txt += "Total Lot: " + DoubleToString(totalLots, 2) + "\n";
   txt += "Total P/L: " + DoubleToString(totalProfit, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + "\n";
   txt += "Max Float: " + DoubleToString(maxFloating, 2) + "\n";
   txt += "----------------------------------------\n";
   txt += "SETTINGS:\n";
   txt += "Lot      : " + DoubleToString(InpLot, 2) + "\n";
   txt += "TP       : " + DoubleToString(InpTP, 0) + " pts\n";
   txt += "SL       : " + (InpSL == 0 ? "MARTI" : DoubleToString(InpSL, 0)) + "\n";
   txt += "Trailing : " + DoubleToString(InpTrailingStart, 0) + "/" + DoubleToString(InpTrailingStop, 0) + "\n";
   txt += "Grid     : " + (InpUseGrid ? "ON " + DoubleToString(InpGridDistance, 0) + "pts" : "OFF") + "\n";
   txt += "Marti    : " + (InpUseMarti ? "ON x" + DoubleToString(InpMartiMultiplier, 2) : "OFF") + "\n";
   txt += "Hedge    : " + (InpUseHedge ? "ON >=" + DoubleToString(InpHedgePip, 0) + "pts" : "OFF") + "\n";
   txt += "PartialTP: " + (InpUsePartialTP ? "ON " + DoubleToString(InpPartialPercent, 0) + "%" : "OFF") + "\n";
   txt += "----------------------------------------\n";
   txt += "Daily P/L: " + DoubleToString(g_dailyProfit, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + "\n";
   txt += "Target   : " + DoubleToString(InpDailyTarget, 0) + " pts\n";
   txt += "----------------------------------------\n";
   
   // Show which rules are triggering
   bool r1b = CheckRule1Buy();  bool r1s = CheckRule1Sell();
   bool r2b = CheckRule2Buy();  bool r2s = CheckRule2Sell();
   bool r3b = CheckRule3Buy();  bool r3s = CheckRule3Sell();
   
   txt += "SIGNALS:\n";
   txt += (r1b ? "[R1 BUY] " : r1s ? "[R1 SELL] " : "");
   txt += (r2b ? "[R2 BUY] " : r2s ? "[R2 SELL] " : "");
   txt += (r3b ? "[R3 BUY] " : r3s ? "[R3 SELL] " : "");
   if(!r1b && !r1s && !r2b && !r2s && !r3b && !r3s) txt += "No Signal";
   txt += "\n========================================\n";
   
   Comment(txt);
}

//+------------------------------------------------------------------+
//| Chart Event                                                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // Handle chart events for future expansion
}
