//+------------------------------------------------------------------+
//|                                            XAU_HFT_Scalper.mq5    |
//|                                         Cuancux Algo Traders      |
//|                                    HFT Momentum Scalper XAUUSD    |
//+------------------------------------------------------------------+
#property copyright   "Cuancux Algo Traders"
#property version     "1.00"
#property description "XAUUSD HFT Scalper — Tick-Driven Momentum"
#property description "Auto-digit · SL/TP · Trailing · No Flood"
#property description " "
#property description "STRATEGY: EMA cross + tick volume surge"
#property description "SYMBOL:   XAUUSD (gold, auto-digit)"
#property description "TIMEFRAME: M1 (fast) / Tick entries"
#property description "RISK:     ATR-based SL, % risk sizing"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//===================================================================
//  INPUT PARAMETERS
//===================================================================
input group "═══ ENTRY SIGNAL ═══"
input int      InpFastMAPeriod   = 6;       // Fast EMA Period
input int      InpSlowMAPeriod   = 21;      // Slow EMA Period
input double   InpMomentumFactor = 0.25;    // Entry threshold × ATR
input int      InpVolumeMult     = 2;       // Tick volume > N× avg triggers
input int      InpATRPeriod      = 14;      // ATR period
input int      InpConfBars       = 2;       // Confirmation bars

input group "═══ RISK MANAGEMENT ═══"
input double   InpRiskPercent    = 0.3;     // Risk per trade %
input double   InpFixedLots      = 0.0;     // Fixed lots (0 = auto %)
input double   InpSL_ATR         = 2.5;     // SL = ATR × this
input double   InpTP_RR          = 2.0;     // TP = SL × this (RR ratio)
input int      InpMaxSpread      = 80;      // Max spread (points)

input group "═══ TRAILING STOP ═══"
input bool     InpEnableTrail    = true;    // Enable trailing
input double   InpTrailTrigger   = 1.5;     // Trail activates at ×ATR profit
input double   InpTrailStep      = 20;      // Trail step (points)
input double   InpTrailDist      = 1.2;     // Trail distance ×ATR

input group "═══ HFT ANTI-FLOOD ═══"
input int      InpCooldownMs     = 300;     // Min ms between trades
input int      InpMaxDailyTrades = 200;     // Max trades per day
input int      InpMaxPositions   = 1;       // Max concurrent open

input group "═══ SESSION FILTER ═══"
input bool     InpUseSession     = false;   // Enable session filter
input int      InpLondonOpen     = 8;       // London open (GMT)
input int      InpNYClose        = 22;      // NY close (GMT)
input bool     InpSkipMondayAM   = true;    // Skip Mon 00:00-08:00
input bool     InpSkipFridayPM   = true;    // Skip Fri 17:00-Close

input group "═══ GENERAL ═══"
input int      InpMagic          = 777001;  // Magic Number
input string   InpTradeComment   = "XAU_HFT";// Order comment
input bool     InpAutoDigits     = true;    // Auto-detect Gold digits

//===================================================================
//  GLOBALS
//===================================================================
CTrade         g_trade;
CPositionInfo  g_pos;
CAccountInfo   g_acct;

int            g_hFastMA   = INVALID_HANDLE;
int            g_hSlowMA   = INVALID_HANDLE;
int            g_hATR      = INVALID_HANDLE;

datetime       g_lastOrderTime;
ulong          g_prevTickTime;
double         g_prevBid, g_prevAsk;
int            g_tradesToday;
datetime       g_tradeDateReset;
int            g_ticketNumber;

int            g_digits;
double         g_point;
double         g_tickValue;
double         g_tickSize;
double         g_lotStep;
double         g_minLot;
double         g_maxLot;
string         g_sym;

//===================================================================
int OnInit()
{
   g_sym      = _Symbol;
   g_digits   = (int)SymbolInfoInteger(g_sym, SYMBOL_DIGITS);
   g_point    = SymbolInfoDouble(g_sym, SYMBOL_POINT);
   g_tickSize = SymbolInfoDouble(g_sym, SYMBOL_TRADE_TICK_SIZE);
   g_tickValue= SymbolInfoDouble(g_sym, SYMBOL_TRADE_TICK_VALUE);
   g_lotStep  = SymbolInfoDouble(g_sym, SYMBOL_VOLUME_STEP);
   g_minLot   = SymbolInfoDouble(g_sym, SYMBOL_VOLUME_MIN);
   g_maxLot   = SymbolInfoDouble(g_sym, SYMBOL_VOLUME_MAX);

   if(InpAutoDigits && StringFind(g_sym, "XAU", 0) >= 0)
   {
      if(g_digits == 3) g_point = 0.001;
      else if(g_digits == 2) g_point = 0.01;
      else if(g_digits == 1) g_point = 0.1;
      Print("[AUTO] XAU detected. digits=", g_digits, " point=", g_point);
   }

   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_trade.SetDeviationInPoints(100);
   g_trade.LogLevel(LOG_LEVEL_ERRORS);

   g_hFastMA = iMA(g_sym, PERIOD_M1, InpFastMAPeriod, 0, MODE_EMA, PRICE_TYPICAL);
   g_hSlowMA = iMA(g_sym, PERIOD_M1, InpSlowMAPeriod, 0, MODE_EMA, PRICE_TYPICAL);
   g_hATR    = iATR(g_sym, PERIOD_M1, InpATRPeriod);

   if(g_hFastMA == INVALID_HANDLE || g_hSlowMA == INVALID_HANDLE || g_hATR == INVALID_HANDLE)
   {
      Print("FAILED: Indicator creation error");
      return INIT_FAILED;
   }

   g_lastOrderTime = 0;
   g_prevTickTime  = 0;
   g_prevBid = 0; g_prevAsk = 0;
   g_tradesToday = 0;
   g_tradeDateReset = 0;

   Print("===================================");
   Print(" XAU HFT Scalper v1.0");
   Print(" Cuancux Algo Traders");
   Print("===================================");
   PrintFormat(" Symbol: %s | Digits: %d | Point: %.5f", g_sym, g_digits, g_point);
   PrintFormat(" MinLot: %.2f | Step: %.2f", g_minLot, g_lotStep);
   double spread = (SymbolInfoDouble(g_sym, SYMBOL_ASK) - SymbolInfoDouble(g_sym, SYMBOL_BID)) / g_point;
   PrintFormat(" Spread: %.0f points (now)", spread);
   Print("===================================");

   return INIT_SUCCEEDED;
}

//===================================================================
void OnDeinit(const int reason)
{
   if(g_hFastMA != INVALID_HANDLE) IndicatorRelease(g_hFastMA);
   if(g_hSlowMA != INVALID_HANDLE) IndicatorRelease(g_hSlowMA);
   if(g_hATR    != INVALID_HANDLE) IndicatorRelease(g_hATR);
   Comment("");
   Print("XAU HFT stopped. Trades today: ", g_tradesToday);
}

//===================================================================
void OnTick()
{
   double bid = SymbolInfoDouble(g_sym, SYMBOL_BID);
   double ask = SymbolInfoDouble(g_sym, SYMBOL_ASK);
   ulong  now = GetTickCount64();

   //--- Anti-flood: de-duplicate identical ticks
   if(bid == g_prevBid && ask == g_prevAsk && now == g_prevTickTime)
      return;
   g_prevBid = bid; g_prevAsk = ask; g_prevTickTime = now;

   //--- Daily reset
   datetime todayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(todayStart != g_tradeDateReset)
   {
      g_tradesToday    = 0;
      g_tradeDateReset = todayStart;
   }

   //--- Daily cap
   if(g_tradesToday >= InpMaxDailyTrades) return;

   //--- Cooldown
   if(g_lastOrderTime > 0)
   {
      if(now - g_lastOrderTime < (ulong)InpCooldownMs) return;
   }

   //--- Session
   if(InpUseSession && !IsSession()) return;

   //--- Spread
   if((ask - bid) / g_point > InpMaxSpread) return;

   //--- Manage open
   if(CountMyPos() >= InpMaxPositions)
   {
      ManageTrail();
      return;
   }

   //--- Indicators
   double fast[3], slow[3], atr[2];
   if(CopyBuffer(g_hFastMA, 0, 0, 3, fast) < 3) return;
   if(CopyBuffer(g_hSlowMA, 0, 0, 3, slow) < 3) return;
   if(CopyBuffer(g_hATR,    0, 0, 2, atr)  < 2) return;

   double curATR = atr[0];
   if(curATR <= 0) return;

   //--- Volume surge check
   long tickVol = iVolume(g_sym, PERIOD_M1, 0);
   double avgVol = AvgVolume(20);
   if(tickVol < avgVol * InpVolumeMult) return;

   //--- Signal
   double fastSpeed = fast[0] - fast[1];
   double priceMom  = bid - fast[0];

   bool isBull = (fast[0] > slow[0]) && (fastSpeed > 0) &&
                 (priceMom > 0) &&
                 (MathAbs(fastSpeed) >= InpMomentumFactor * curATR);

   bool isBear = (fast[0] < slow[0]) && (fastSpeed < 0) &&
                 (priceMom < 0) &&
                 (MathAbs(fastSpeed) >= InpMomentumFactor * curATR);

   if(isBull && !isBear)  OpenTrade(ORDER_TYPE_BUY,  bid, ask, curATR);
   if(isBear && !isBull)  OpenTrade(ORDER_TYPE_SELL, bid, ask, curATR);
}

//===================================================================
void OpenTrade(ENUM_ORDER_TYPE type, double bid, double ask, double atr)
{
   double entry = (type == ORDER_TYPE_BUY) ? ask : bid;

   double slDist = atr * InpSL_ATR;
   slDist = MathMax(slDist, 60 * g_point); // floor
   double tpDist = slDist * InpTP_RR;

   double sl, tp;
   if(type == ORDER_TYPE_BUY)
   { sl = entry - slDist; tp = entry + tpDist; }
   else
   { sl = entry + slDist; tp = entry - tpDist; }

   double lots = GetLot(entry, sl, type);
   if(lots <= 0) return;

   sl = NormalizePrice(sl);
   tp = NormalizePrice(tp);
   entry = NormalizePrice(entry);

   if(!g_trade.PositionOpen(g_sym, type, lots, entry, sl, tp, InpTradeComment))
   {
      uint rc = g_trade.ResultRetcode();
      if(rc == TRADE_RETCODE_REQUOTE || rc == TRADE_RETCODE_PRICE_OFF || rc == TRADE_RETCODE_TIMEOUT)
         return; // silent — normal HFT condition
      Print("Order FAIL: ", rc, " ", g_trade.ResultRetcodeDescription());
      return;
   }

   g_ticketNumber  = (int)g_trade.ResultOrder();
   g_lastOrderTime = GetTickCount64();
   g_tradesToday++;
}

//===================================================================
double GetLot(double entry, double sl, ENUM_ORDER_TYPE type)
{
   if(InpFixedLots > 0) return NormLot(InpFixedLots);

   double balance = g_acct.Balance();
   if(balance <= 0) balance = g_acct.Equity();

   double riskMoney = balance * InpRiskPercent / 100.0;
   double slDist    = MathAbs(entry - sl);
   if(slDist <= 0) return g_minLot;

   double tickVal = (g_tickValue > 0) ? g_tickValue : 0.01;
   double tickSz  = (g_tickSize  > 0) ? g_tickSize  : g_point;

   double lots = (riskMoney / slDist) * tickSz / tickVal;
   lots = MathFloor(lots / g_lotStep) * g_lotStep;
   return NormLot(lots);
}

//===================================================================
void ManageTrail()
{
   if(!InpEnableTrail) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Symbol() != g_sym) continue;
      if(g_pos.Magic()  != InpMagic) continue;

      double curPrice = SymbolInfoDouble(g_sym, SYMBOL_BID);
      double openPr   = g_pos.PriceOpen();
      double curSL    = g_pos.StopLoss();
      double curTP    = g_pos.TakeProfit();

      double atr[1];
      if(CopyBuffer(g_hATR, 0, 0, 1, atr) < 1) return;
      double a = atr[0];
      if(a <= 0) return;

      double trigger = a * InpTrailTrigger;
      double dist    = a * InpTrailDist;

      if(g_pos.PositionType() == POSITION_TYPE_BUY)
      {
         if((curPrice - openPr) < trigger) continue;
         double newSL = curPrice - dist;
         newSL = NormalizePrice(newSL);
         if(newSL > curSL && MathAbs(newSL - curSL) >= InpTrailStep * g_point)
         {
            if(g_trade.PositionModify(g_pos.Ticket(), newSL, curTP))
               Print("Trail BUY: SL->", newSL);
         }
      }
      else
      {
         if((openPr - curPrice) < trigger) continue;
         double newSL = curPrice + dist;
         newSL = NormalizePrice(newSL);
         if((curSL <= 0 || newSL < curSL) && MathAbs(newSL - curSL) >= InpTrailStep * g_point)
         {
            if(g_trade.PositionModify(g_pos.Ticket(), newSL, curTP))
               Print("Trail SELL: SL->", newSL);
         }
      }
   }
}

//===================================================================
int CountMyPos()
{
   int cnt = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(g_pos.SelectByIndex(i))
         if(g_pos.Symbol() == g_sym && g_pos.Magic() == InpMagic)
            cnt++;
   }
   return cnt;
}

//===================================================================
bool IsSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6) return false;
   if(InpSkipMondayAM && dt.day_of_week == 1 && dt.hour < InpLondonOpen) return false;
   if(InpSkipFridayPM && dt.day_of_week == 5 && dt.hour >= InpNYClose) return false;
   if(dt.hour < InpLondonOpen || dt.hour >= InpNYClose) return false;
   return true;
}

//===================================================================
double AvgVolume(int bars)
{
   double sum = 0;
   for(int i = 0; i < bars; i++)
   {
      long v = iVolume(g_sym, PERIOD_M1, i);
      if(v > 0) sum += (double)v;
   }
   return (sum > 0) ? sum / bars : 1;
}

//===================================================================
double NormalizePrice(double p)
{
   return NormalizeDouble(p, g_digits);
}
double NormLot(double lot)
{
   if(lot < g_minLot) lot = g_minLot;
   if(lot > g_maxLot) lot = g_maxLot;
   double step = (g_lotStep > 0) ? g_lotStep : 0.01;
   lot = MathFloor(lot / step) * step;
   return NormalizeDouble(lot, 2);
}
//+------------------------------------------------------------------+
