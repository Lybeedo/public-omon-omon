//+------------------------------------------------------------------+
//|                                   Omon_Obet_XAUUSD_Sell_V1.mq5   |
//| Telegram: t.me/cuancux                                           |
//| Website: timesynctrading.com                                     |
//| Copyright: t.me/lybeedo                                          |
//+------------------------------------------------------------------+
#property copyright "Trader Nakal™ — Omon Agent"
#property version   "1.01"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== Signal Parameters ==="
input double InpEntryPrice   = 4153.75;    // Target Entry Price
input double InpTPPrice      = 4104.43;    // Target Take Profit
input double InpSLPrice      = 4170.19;    // Target Stop Loss
input double InpLot          = 0.01;       // Lot Size

input group "=== Filter Settings (M15) ==="
input int    InpEMA_Fast     = 20;         // EMA Fast
input int    InpEMA_Mid      = 50;         // EMA Mid
input int    InpEMA_Slow     = 200;        // EMA Slow
input int    InpRSI_Period   = 14;         // RSI Period
input int    InpADX_Period   = 14;         // ADX Period

input group "=== General Settings ==="
input int    InpMagicNumber  = 20261002;   // Magic Number
input int    InpDeviation    = 100;        // Deviation (Points)
input string InpComment      = "Omon_Sell_XAUUSD";

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
CTrade g_trade;
int    h_ema_fast, h_ema_mid, h_ema_slow;
int    h_rsi, h_macd, h_adx;

bool   g_hasShort = false;

//+------------------------------------------------------------------+
//| EXPERT INITIALIZATION                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_trade.SetDeviationInPoints(InpDeviation);
   
   // Initialize Handles for M15
   h_ema_fast = iMA(_Symbol, PERIOD_M15, InpEMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   h_ema_mid  = iMA(_Symbol, PERIOD_M15, InpEMA_Mid, 0, MODE_EMA, PRICE_CLOSE);
   h_ema_slow = iMA(_Symbol, PERIOD_M15, InpEMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   h_rsi      = iRSI(_Symbol, PERIOD_M15, InpRSI_Period, PRICE_CLOSE);
   h_macd     = iMACD(_Symbol, PERIOD_M15, 12, 26, 9, PRICE_CLOSE);
   h_adx      = iADX(_Symbol, PERIOD_M15, InpADX_Period);
   
   if(h_ema_fast == INVALID_HANDLE || h_adx == INVALID_HANDLE) {
      Print("❌ [SYSTEM] Failed to create indicator handles");
      return(INIT_FAILED);
   }

   Print("✅ [SYSTEM] Omon_Obet_XAUUSD_Sell_V1 Loaded | Target Entry: ", InpEntryPrice);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| EXPERT DEINITIALIZATION                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(h_ema_fast);
   IndicatorRelease(h_ema_mid);
   IndicatorRelease(h_ema_slow);
   IndicatorRelease(h_rsi);
   IndicatorRelease(h_macd);
   IndicatorRelease(h_adx);
}

//+------------------------------------------------------------------+
//| EXPERT TICK FUNCTION                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastBarTime = 0;
   datetime curBarTime = iTime(_Symbol, PERIOD_M15, 0);
   
   if(curBarTime == lastBarTime) return;
   lastBarTime = curBarTime;

   VerifyPositions();
   
   if(!g_hasShort && IsShortCondition()) {
      ExecuteSell();
   }
}

//+------------------------------------------------------------------+
//| POSITION VERIFICATION                                            |
//+------------------------------------------------------------------+
void VerifyPositions()
{
   g_hasShort = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) g_hasShort = true;
      }
   }
}

//+------------------------------------------------------------------+
//| SELL CONDITION LOGIC                                             |
//+------------------------------------------------------------------+
bool IsShortCondition()
{
   double ema_f[1], ema_m[1], ema_s[1], rsi[1], macd_main[1], adx_main[1], adx_plus[1], adx_minus[1];
   
   if(CopyBuffer(h_ema_fast, 0, 0, 1, ema_f) < 1) return false;
   if(CopyBuffer(h_ema_mid,  0, 0, 1, ema_m) < 1) return false;
   if(CopyBuffer(h_ema_slow, 0, 0, 1, ema_s) < 1) return false;
   if(CopyBuffer(h_rsi,      0, 0, 1, rsi)   < 1) return false;
   if(CopyBuffer(h_macd,     0, 0, 1, macd_main) < 1) return false;
   if(CopyBuffer(h_adx,      0, 0, 1, adx_main) < 1) return false;
   if(CopyBuffer(h_adx,      1, 0, 1, adx_plus) < 1) return false;
   if(CopyBuffer(h_adx,      2, 0, 1, adx_minus) < 1) return false;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // 1. EMA Stack Bearish Check (Price < Fast < Mid < Slow)
   bool ema_bearish = (bid < ema_f[0] && ema_f[0] < ema_m[0] && ema_m[0] < ema_s[0]);
   
   // 2. Momentum Check (RSI < 50, MACD < 0)
   bool momentum_bearish = (rsi[0] < 50 && macd_main[0] < 0);
   
   // 3. Trend Intensity (ADX > 20, DI- > DI+)
   bool adx_bearish = (adx_main[0] > 20 && adx_minus[0] > adx_plus[0]);
   
   // 4. Price Level Check (Sell below or at suggested entry)
   bool price_valid = (bid <= InpEntryPrice);

   if(ema_bearish && momentum_bearish && adx_bearish && price_valid) {
      Print("🔴 [SIGNAL] Bearish Confluence Detected on M15. Executing Sell.");
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| EXECUTE SELL POSITION                                            |
//+------------------------------------------------------------------+
void ExecuteSell()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = NormalizeDouble(InpSLPrice, _Digits);
   double tp = NormalizeDouble(InpTPPrice, _Digits);
   
   // Safety check for stop levels
   double min_stop = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(MathAbs(bid - sl) < min_stop) sl = NormalizeDouble(bid + min_stop + (10 * _Point), _Digits);
   if(MathAbs(bid - tp) < min_stop) tp = NormalizeDouble(bid - min_stop - (10 * _Point), _Digits);

   if(g_trade.Sell(InpLot, _Symbol, bid, sl, tp, InpComment)) {
      Print("✅ [TRADE] Sell Order Placed. Price: ", bid, " SL: ", sl, " TP: ", tp);
   } else {
      Print("❌ [ERROR] Sell Order Failed. Code: ", g_trade.ResultRetcode());
   }
}
