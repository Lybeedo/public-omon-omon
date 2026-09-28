//+------------------------------------------------------------------+
//|                                       Omon_Obet_Judas_Swing_V1.mq5 |
//|                                Copyright 2026, Trader Nakal Team   |
//|                        t.me/cuancux | timesynctrading.com          |
//+------------------------------------------------------------------+
#property copyright "Trader Nakal - Omon Agent"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

enum ENUM_TRADE_DIR
{
   TRADE_ALL        = 0,   // Semua Arah
   TRADE_BUY_ONLY   = 1,   // Buy Saja
   TRADE_SELL_ONLY  = 2    // Sell Saja
};

enum ENUM_RISK_MODE
{
   RISK_FIXED_LOT      = 0,   // Lot Tetap
   RISK_PERCENT_EQUITY = 1    // % Equity
};

enum ENUM_TP_MODE
{
   TP_FIXED       = 0,   // TP input (pips)
   TP_RR_1TO2     = 1,   // Risk : Reward = 1 : 2
   TP_RR_1TO3     = 2    // Risk : Reward = 1 : 3
};

input group "=== General Settings ==="
input ENUM_TRADE_DIR InpTradeDir     = TRADE_ALL;   // Pilihan Arah Trade
input int            InpDeviation    = 15;          // Deviasi Open Posisi (Poin)
input string         InpComment      = "JudasSwing"; // Comment Order
input int            InpMagicNumber  = 8899;        // ID Unik EA

input group "=== Judas Session Settings ==="
input int            InpAsianStartHour   = 0;       // Jam Mulai Sesi Asia (0-23)
input int            InpAsianEndHour     = 8;       // Jam Akhir Sesi Asia (0-23)
input int            InpBrokerOffsetHour = 0;       // Offset Jam Broker (-12 s/d +12)
input int            InpSweepBufferPips  = 2;       // Buffer Sweep (Pips)
input int            InpSLExtraPips      = 5;       // Jarak Ekstra SL di Luar Sweep (Pips)
input ENUM_TP_MODE   InpTPMode           = TP_RR_1TO2; // Mode Take Profit
input double         InpFixedTPPips      = 30.0;    // TP Fixed (Pips, jika mode Fixed)

input group "=== Filter Tren (Opsional) ==="
input bool           InpUseTrendFilter   = false;   // Gunakan EMA Filter
input int            InpEMAPeriod        = 200;     // Periode EMA Filter
input ENUM_TIMEFRAME InpEMATF            = PERIOD_H1; // Timeframe EMA

input group "=== Manajemen Modal & Risk ==="
input ENUM_RISK_MODE InpRiskMode         = RISK_FIXED_LOT; // Mode Risk
input double         InpFixedLot         = 0.01;    // Lot Tetap
input double         InpRiskPercent      = 1.0;     // Risk % Equity
input int            InpMaxSpreadPips    = 30;      // Max Spread (Pips, 0 = off)
input int            InpMaxDailyTrades   = 2;       // Max Trade per Hari

input group "=== Kill Switch (Basket Safety) ==="
input double         InpMaxDrawdownPct   = 20.0;    // Max Drawdown % Equity
input double         InpDailyProfitPct   = 0.0;     // Daily Profit Limit % (0 = off)

input group "=== Market Metric ==="
input int            InpEconometric      = 0;       // Eco-Metric (0: Disable)
input ENUM_TIMEFRAME InpTFMetric         = PERIOD_CURRENT; // Metric Time

//+=================================================================+
//| VARIABEL GLOBAL ENGINE                                          |
//+=================================================================+
CTrade       g_trade;
int          g_h_ema       = INVALID_HANDLE;
double       g_buf_ema[];

bool         g_hasLong     = false;
bool         g_hasShort    = false;

long         g_todayDay    = 0;
double       g_asianHigh   = 0.0;
double       g_asianLow    = 0.0;
bool         g_asianSet    = false;
bool         g_sweepHigh   = false;
bool         g_sweepLow    = false;
double       g_sweepHighPrice = 0.0;
double       g_sweepLowPrice  = 0.0;
int          g_dailyTrades = 0;

//+=================================================================+
//| HELPER - PIP -> POINT                                            |
//+=================================================================+
double PipToPoint()
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return ((digits % 2) != 0) ? 10.0 * _Point : _Point;
}

double PipsToPrice(double pips)
{
   return pips * PipToPoint();
}

//+=================================================================+
//| INITIALIZATION                                                  |
//+=================================================================+
int OnInit()
{
   if(InpAsianStartHour < 0 || InpAsianStartHour > 23) return INIT_PARAMETERS_INCORRECT;
   if(InpAsianEndHour   < 0 || InpAsianEndHour   > 23) return INIT_PARAMETERS_INCORRECT;
   if(InpAsianEndHour  <= InpAsianStartHour)           return INIT_PARAMETERS_INCORRECT;
   if(InpBrokerOffsetHour < -12 || InpBrokerOffsetHour > 12) return INIT_PARAMETERS_INCORRECT;
   if(InpMagicNumber <= 0)                             return INIT_PARAMETERS_INCORRECT;
   if(InpRiskPercent < 0.0 || InpRiskPercent > 100.0)  return INIT_PARAMETERS_INCORRECT;

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   SetFillMode();
   g_trade.SetDeviationInPoints(InpDeviation);
   g_trade.SetAsyncMode(false);

   if(InpUseTrendFilter)
   {
      g_h_ema = iMA(_Symbol, InpEMATF, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(g_h_ema == INVALID_HANDLE)
      {
         Print("[!] [ERR] iMA EMA filter failed:", GetLastError());
         return INIT_FAILED;
      }
      ArraySetAsSeries(g_buf_ema, true);
   }

   if(InpEconometric > 0)
   {
      int tf_seconds = (int)PeriodSeconds(InpTFMetric);
      int interval   = tf_seconds * InpEconometric;
      EventSetTimer(interval);
      Print("[T] [TIMER] Eco-Metric active | TF:", EnumToString(InpTFMetric), "| Interval:", interval, "s");
   }

   ResetSessionVars();
   g_todayDay = 0;

   Print("[OK] [SYSTEM] Judas Swing V1 Loaded | Magic: ", InpMagicNumber);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(g_h_ema != INVALID_HANDLE) IndicatorRelease(g_h_ema);
   if(InpEconometric > 0) EventKillTimer();
}

void OnTimer()
{
}

//+=================================================================+
//| FILL MODE AUTO-DETECT                                           |
//+=================================================================+
void SetFillMode()
{
   uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      g_trade.SetTypeFilling(ORDER_FILLING_IOC);
   else
      g_trade.SetTypeFilling(ORDER_FILLING_RETURN);
}

//+=================================================================+
//| RESET SESSION VARS                                              |
//+=================================================================+
void ResetSessionVars()
{
   g_asianHigh      = 0.0;
   g_asianLow       = 0.0;
   g_asianSet       = false;
   g_sweepHigh      = false;
   g_sweepLow       = false;
   g_sweepHighPrice = 0.0;
   g_sweepLowPrice  = 0.0;
}

//+=================================================================+
//| LOCAL HOUR FROM SERVER TIME                                     |
//+=================================================================+
int LocalHour(datetime serverTime)
{
   datetime localTime = serverTime + (InpBrokerOffsetHour * 3600);
   MqlDateTime dt;
   TimeToStruct(localTime, dt);
   return dt.hour;
}

//+=================================================================+
//| ON TICK                                                         |
//+=================================================================+
void OnTick()
{
   if(CheckKillSwitch()) return;

   static datetime lastBarTime = 0;
   datetime curBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(curBarTime == lastBarTime) return;
   lastBarTime = curBarTime;

   datetime serverTime = TimeCurrent();
   long currentDay = serverTime / 86400;

   // Reset harian
   if(currentDay != g_todayDay)
   {
      g_todayDay    = currentDay;
      g_dailyTrades = 0;
      ResetSessionVars();
   }

   int localHour = LocalHour(serverTime);

   // Build Asian range saat sesi Asia selesai
   if(!g_asianSet && localHour >= InpAsianEndHour)
   {
      BuildAsianRange();
      g_asianSet = true;
      if(g_asianHigh > 0.0 && g_asianLow > 0.0 && g_asianHigh > g_asianLow)
      {
         Print("[J] [JUDAS] Asian Range locked | High: ", g_asianHigh, " | Low: ", g_asianLow);
      }
      else
      {
         Print("[!] [JUDAS] Asian Range invalid - menunggu hari berikutnya");
      }
   }

   if(!g_asianSet || g_asianHigh <= 0.0 || g_asianLow <= 0.0) return;

   if(!RefreshIndicator()) return;
   VerifyPositions();
   CheckSignal();
}

//+=================================================================+
//| BUILD ASIAN RANGE                                               |
//+=================================================================+
void BuildAsianRange()
{
   int totalBars = iBars(_Symbol, PERIOD_CURRENT);
   if(totalBars < 3) return;

   double highest = 0.0;
   double lowest  = DBL_MAX;
   bool found = false;

   for(int i = totalBars - 1; i >= 0; i--)
   {
      datetime barTime = iTime(_Symbol, PERIOD_CURRENT, i);
      int h = LocalHour(barTime);
      if(h < InpAsianStartHour) continue;
      if(h >= InpAsianEndHour)  continue;

      double hi = iHigh(_Symbol, PERIOD_CURRENT, i);
      double lo = iLow(_Symbol, PERIOD_CURRENT, i);
      if(hi > highest) highest = hi;
      if(lo < lowest)  lowest  = lo;
      found = true;
   }

   if(found)
   {
      g_asianHigh = highest;
      g_asianLow  = lowest;
   }
}

//+=================================================================+
//| KILL SWITCH                                                     |
//+=================================================================+
bool CheckKillSwitch()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance <= 0.0) return false;

   double ddPct = (balance - equity) / balance * 100.0;
   if(ddPct >= InpMaxDrawdownPct)
   {
      CloseAllPositions();
      DeleteAllPending();
      Print("[K] [KILL] Drawdown limit hit: ", DoubleToString(ddPct, 2), "%");
      return true;
   }

   if(InpDailyProfitPct > 0.0)
   {
      double profitPct = (equity - balance) / balance * 100.0;
      if(profitPct >= InpDailyProfitPct)
      {
         CloseAllPositions();
         DeleteAllPending();
         Print("[K] [KILL] Daily profit limit hit: ", DoubleToString(profitPct, 2), "%");
         return true;
      }
   }

   return false;
}

void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      g_trade.PositionClose(ticket);
   }
}

void DeleteAllPending()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      g_trade.OrderDelete(ticket);
   }
}

//+=================================================================+
//| VERIFIKASI POSISI                                               |
//+=================================================================+
void VerifyPositions()
{
   bool foundLong  = false;
   bool foundShort = false;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(posType == POSITION_TYPE_BUY)  foundLong  = true;
      if(posType == POSITION_TYPE_SELL) foundShort = true;
   }

   g_hasLong  = foundLong;
   g_hasShort = foundShort;
}

//+=================================================================+
//| REFRESH INDICATOR                                               |
//+=================================================================+
bool RefreshIndicator()
{
   if(InpUseTrendFilter && g_h_ema != INVALID_HANDLE)
   {
      ResetLastError();
      if(CopyBuffer(g_h_ema, 0, 0, 3, g_buf_ema) < 3)
      {
         Print("[!] [ERR] CopyBuffer EMA failed:", GetLastError());
         return false;
      }
   }
   return true;
}

//+=================================================================+
//| SIGNAL LOGIC                                                    |
//+=================================================================+
void CheckSignal()
{
   if(g_dailyTrades >= InpMaxDailyTrades) return;
   if(InpMaxSpreadPips > 0 && SpreadPips() > InpMaxSpreadPips) return;

   double sl = 0.0;
   double tp = 0.0;

   if((InpTradeDir == TRADE_ALL || InpTradeDir == TRADE_BUY_ONLY) && !g_hasLong && IsLong())
   {
      ExecutePosition(ORDER_TYPE_BUY, sl, tp);
   }

   if((InpTradeDir == TRADE_ALL || InpTradeDir == TRADE_SELL_ONLY) && !g_hasShort && IsShort())
   {
      ExecutePosition(ORDER_TYPE_SELL, sl, tp);
   }
}

//+=================================================================+
//| LONG LOGIC - Judas Sweep Low + Reversal                         |
//+=================================================================+
bool IsLong()
{
   if(InpTradeDir == TRADE_SELL_ONLY) return false;

   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double high1  = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double low1   = iLow(_Symbol, PERIOD_CURRENT, 1);
   if(close1 == 0.0 || high1 == 0.0 || low1 == 0.0) return false;

   double buffer = PipsToPrice(InpSweepBufferPips);

   // Deteksi sweep low: candle sebelumnya low di bawah Asian low - buffer
   if(!g_sweepLow && low1 < g_asianLow - buffer)
   {
      g_sweepLow      = true;
      g_sweepLowPrice = low1;
      Print("[J] [JUDAS] Sweep Low detected: ", g_sweepLowPrice, " | Asian Low: ", g_asianLow);
      return false;
   }

   // Entry long: setelah sweep low, candle close kembali di atas Asian low
   if(g_sweepLow && close1 > g_asianLow)
   {
      if(InpUseTrendFilter && ArraySize(g_buf_ema) > 0)
      {
         double ema = g_buf_ema[0];
         if(ema > 0.0 && close1 < ema) return false;
      }
      return true;
   }

   return false;
}

//+=================================================================+
//| SHORT LOGIC - Judas Sweep High + Reversal                       |
//+=================================================================+
bool IsShort()
{
   if(InpTradeDir == TRADE_BUY_ONLY) return false;

   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double high1  = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double low1   = iLow(_Symbol, PERIOD_CURRENT, 1);
   if(close1 == 0.0 || high1 == 0.0 || low1 == 0.0) return false;

   double buffer = PipsToPrice(InpSweepBufferPips);

   // Deteksi sweep high: candle sebelumnya high di atas Asian high + buffer
   if(!g_sweepHigh && high1 > g_asianHigh + buffer)
   {
      g_sweepHigh      = true;
      g_sweepHighPrice = high1;
      Print("[J] [JUDAS] Sweep High detected: ", g_sweepHighPrice, " | Asian High: ", g_asianHigh);
      return false;
   }

   // Entry short: setelah sweep high, candle close kembali di bawah Asian high
   if(g_sweepHigh && close1 < g_asianHigh)
   {
      if(InpUseTrendFilter && ArraySize(g_buf_ema) > 0)
      {
         double ema = g_buf_ema[0];
         if(ema > 0.0 && close1 > ema) return false;
      }
      return true;
   }

   return false;
}

//+=================================================================+
//| EKSEKUSI POSISI                                                 |
//+=================================================================+
void ExecutePosition(ENUM_ORDER_TYPE type, double &sl, double &tp)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double entryPrice = (type == ORDER_TYPE_BUY) ? ask : bid;

   CalculateTargets(type, entryPrice, sl, tp);

   double lots = CalculateLot(sl, entryPrice);
   if(lots <= 0.0)
   {
      Print("[!] [ERR] Lot size invalid: ", lots);
      return;
   }

   if(!g_trade.PositionOpen(_Symbol, type, lots, entryPrice, sl, tp, InpComment))
   {
      Print("[!] [ERR] PositionOpen failed:", GetLastError());
      return;
   }

   g_dailyTrades++;
   if(type == ORDER_TYPE_BUY)  g_hasLong  = true;
   if(type == ORDER_TYPE_SELL) g_hasShort = true;
}

//+=================================================================+
//| PERHITUNGAN TARGET SL/TP                                        |
//+=================================================================+
void CalculateTargets(ENUM_ORDER_TYPE type, double entryPrice, double &sl_out, double &tp_out)
{
   double pip     = PipToPoint();
   double slExtra = PipsToPrice(InpSLExtraPips);

   if(type == ORDER_TYPE_BUY)
   {
      double stopPrice = (g_sweepLowPrice > 0.0) ? g_sweepLowPrice : g_asianLow;
      sl_out = NormalizeDouble(stopPrice - slExtra, _Digits);

      double risk = entryPrice - sl_out;
      if(risk <= 0.0)
      {
         sl_out = NormalizeDouble(entryPrice - (50.0 * pip), _Digits);
         risk   = entryPrice - sl_out;
      }

      if(InpTPMode == TP_FIXED)
         tp_out = NormalizeDouble(entryPrice + PipsToPrice(InpFixedTPPips), _Digits);
      else if(InpTPMode == TP_RR_1TO2)
         tp_out = NormalizeDouble(entryPrice + (risk * 2.0), _Digits);
      else if(InpTPMode == TP_RR_1TO3)
         tp_out = NormalizeDouble(entryPrice + (risk * 3.0), _Digits);
   }
   else // SELL
   {
      double stopPrice = (g_sweepHighPrice > 0.0) ? g_sweepHighPrice : g_asianHigh;
      sl_out = NormalizeDouble(stopPrice + slExtra, _Digits);

      double risk = sl_out - entryPrice;
      if(risk <= 0.0)
      {
         sl_out = NormalizeDouble(entryPrice + (50.0 * pip), _Digits);
         risk   = sl_out - entryPrice;
      }

      if(InpTPMode == TP_FIXED)
         tp_out = NormalizeDouble(entryPrice - PipsToPrice(InpFixedTPPips), _Digits);
      else if(InpTPMode == TP_RR_1TO2)
         tp_out = NormalizeDouble(entryPrice - (risk * 2.0), _Digits);
      else if(InpTPMode == TP_RR_1TO3)
         tp_out = NormalizeDouble(entryPrice - (risk * 3.0), _Digits);
   }
}

//+=================================================================+
//| LOT SIZE CALCULATION                                            |
//+=================================================================+
double CalculateLot(double sl, double entryPrice)
{
   if(InpRiskMode == RISK_FIXED_LOT)
   {
      return NormalizeLot(InpFixedLot);
   }

   double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmt  = equity * InpRiskPercent / 100.0;
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

   if(tickSize <= 0.0 || tickVal <= 0.0) return 0.0;

   double slDistance = MathAbs(entryPrice - sl);
   if(slDistance <= 0.0) return 0.0;

   double ticksAtRisk = slDistance / tickSize;
   double lot         = riskAmt / (ticksAtRisk * tickVal);

   return NormalizeLot(lot);
}

double NormalizeLot(double lot)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(lotStep <= 0.0) lotStep = 0.01;
   if(maxLot <= 0.0)  maxLot  = lot;

   lot = MathFloor(lot / lotStep) * lotStep;
   lot = MathMax(minLot, MathMin(maxLot, lot));

   return NormalizeDouble(lot, 2);
}

//+=================================================================+
//| SPREAD HELPER                                                   |
//+=================================================================+
double SpreadPips()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (ask - bid) / PipToPoint();
}

//+------------------------------------------------------------------+
