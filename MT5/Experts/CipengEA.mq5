//+------------------------------------------------------------------+
//|                                                   CipengEA.mq5    |
//|                              Trend Following — Sell on Rally       |
//|                        https://t.me/simpleforextools              |
//|              Built by: Cipeng Strategy × SimpleForexTools         |
//+------------------------------------------------------------------+
#property copyright "Cipeng | SimpleForexTools"
#property link      "https://t.me/simpleforextools"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

// ╔══════════════════════════════════════════════════════════════════╗
// ║  ENUM & STRUCTURES                                               ║
// ╚══════════════════════════════════════════════════════════════════╝

enum ENUM_ENTRY_MODE
{
   MODE_BOTH      = 0,   // Buy & Sell
   MODE_SELL_ONLY  = 1,   // Sell only (default Cipeng)
   MODE_BUY_ONLY   = 2    // Buy only
};

enum ENUM_ATR_FILTER_MODE
{
   ATR_FILTER_AUTO  = 0,  // Block during high volatility
   ATR_FILTER_OFF   = 1   // Ignore ATR filter
};

struct SOrderParams
{
   double slPrice;
   double tpPrice;
   double entryPrice;
   double riskPips;
   ENUM_POSITION_TYPE_DIRECTION dir;
};

// ╔══════════════════════════════════════════════════════════════════╗
// ║  INPUTS — STRATEGY                                               ║
// ╚══════════════════════════════════════════════════════════════════╝

input group "=== Trend Filter ==="
input int    InpSMA_Period    = 20;          // SMA Period (Trend filter)
input ENUM_ENTRY_MODE InpEntryMode = MODE_SELL_ONLY; // Entry mode

input group "=== Sell Signal (Cipeng) ==="
input int    InpRSI_Period_S  = 14;          // RSI Period (Sell)
input double InpRSI_SellLevel  = 60;         // RSI Sell threshold (>60 = overbought)
input int    InpMACD_Fast_S   = 12;          // MACD Fast (Sell)
input int    InpMACD_Slow_S   = 26;          // MACD Slow (Sell)
input int    InpMACD_Signal_S = 9;           // MACD Signal (Sell)

input group "=== Buy Signal (Mirror) ==="
input int    InpRSI_Period_B   = 14;         // RSI Period (Buy)
input double InpRSI_BuyLevel   = 40;         // RSI Buy threshold (<40 = oversold)
input int    InpMACD_Fast_B   = 12;         // MACD Fast (Buy)
input int    InpMACD_Slow_B    = 26;         // MACD Slow (Buy)
input int    InpMACD_Signal_B  = 9;          // MACD Signal (Buy)

input group "=== Stop Loss / Take Profit ==="
input int    InpSL_BufferPips   = 20;        // SL buffer above swing high (pips)
input double InpRiskRewardRatio = 2.0;       // Risk:Reward ratio (1:2 default)
input int    InpTS_ActivatePips = 0;         // Trailing activation offset (pips) [0 = use RR]
input int    InpTS_StepPips     = 10;        // Trailing step (pips)

input group "=== Swing Detection ==="
input int    InpSwingLookback   = 20;        // Bars to look back for swing high/low

input group "=== ATR Filter (News / Volatility) ==="
input ENUM_ATR_FILTER_MODE InpATR_FilterMode = ATR_FILTER_AUTO;
input int    InpATR_Period     = 14;         // ATR Period
input double InpATR_Multiplier = 1.5;        // Block if ATR > SMA(ATR,20) × multiplier
input int    InpNewsMinutesBefore = 60;      // Minutes before news to block trades
input int    InpNewsMinutesAfter  = 30;      // Minutes after news to block trades

input group "=== Money Management ==="
input double InpRiskPercent     = 1.0;        // Risk per trade (% of equity)
input double InpMaxDailyLossPct= 2.0;        // Daily loss limit (% of equity)
input int    InpMaxTradesPerDay= 3;          // Max trades per day
input double InpMinLot         = 0.01;       // Minimum lot size
input double InpMaxLot         = 1.0;        // Maximum lot size

input group "=== Session Filter ==="
input bool   InpAllowAsian     = true;        // Allow Asian session (00:00-09:00)
input bool   InpAllowLondon    = true;        // Allow London session (08:00-12:00)
input bool   InpAllowNY        = true;        // Allow NY session (13:00-17:00)

input group "=== General ==="
input ulong  InpMagic          = 20260603;   // EA Magic Number
input int    InpSlippage       = 3;          // Slippage (points)
input bool   InpCommentEnabled  = true;       // Enable order comments
input bool   InpDebugMode       = false;      // Debug print to Experts log

// ╔══════════════════════════════════════════════════════════════════╗
// ║  GLOBALS                                                         ║
// ╚══════════════════════════════════════════════════════════════════╝

CTrade         g_trade;
CSymbolInfo    g_symbol;
CArrayObj      g_newsCache;                  // Simple news cache

datetime       g_barTime      = 0;
datetime       g_lastTradeDate = 0;
int            g_tradesToday   = 0;
double         g_dailyLossLimit= 0.0;
bool           g_dailyLimitHit = false;
double         g_dayStartEquity = 0.0;
double         g_dailyPnL      = 0.0;

// ╔══════════════════════════════════════════════════════════════════╗
// ║  UTILITY FUNCTIONS                                               ║
// ╚══════════════════════════════════════════════════════════════════╝

#define DEBUG if(InpDebugMode) Print

//+------------------------------------------------------------------+
//| Get point value in account currency terms                        |
//+------------------------------------------------------------------+
double PipValue()
{
   double tick = g_symbol.TickSize();
   double point = g_symbol.Point();
   // Pip = 10 points for 5-digit / 1 point for 4-digit (normalized)
   double pipSize = (g_symbol.Digits() == 5 || g_symbol.Digits() == 3) ? tick * 10 : tick;
   return pipSize;
}

//+------------------------------------------------------------------+
//| Convert pips to price                                            |
//+------------------------------------------------------------------+
double PipsToPrice(int pips)
{
   return PipValue() * (double)pips;
}

//+------------------------------------------------------------------+
//| Normalize price to broker tick                                   |
//+------------------------------------------------------------------+
double NormalizePrice(double price)
{
   return NormalizeDouble(price, g_symbol.Digits());
}

//+------------------------------------------------------------------+
//| ATR-based volatility filter                                      |
//+------------------------------------------------------------------+
bool IsVolatilitySafe()
{
   if(InpATR_FilterMode == ATR_FILTER_OFF) return true;

   double atr = iATR(_Symbol, PERIOD_CURRENT, InpATR_Period);
   if(atr <= 0) return true; // Fallback: allow

   // Simple SMA of ATR over 20 bars
   double atrSum = 0;
   for(int i = 0; i < 20; i++)
   {
      double a = iATR(_Symbol, PERIOD_CURRENT, InpATR_Period, i);
      if(a > 0) atrSum += a;
   }
   double atrSMA = (atrSum / 20.0);
   if(atrSMA <= 0) return true;

   DEBUG("CIPENG: ATR=", DoubleToString(atr, 5), " ATR_SMA=", DoubleToString(atrSMA, 5), " Ratio=", DoubleToString(atr / atrSMA, 2));
   return (atr <= atrSMA * InpATR_Multiplier);
}

//+------------------------------------------------------------------+
//| Find swing high (highest high in lookback window)                 |
//+------------------------------------------------------------------+
bool FindSwingHigh(int startBar, int lookback, double &outPrice, int &outBar)
{
   double maxPrice = -DBL_MAX;
   int    maxBar   = -1;

   for(int i = startBar; i > startBar - lookback && i >= 0; i--)
   {
      double h = iHigh(_Symbol, PERIOD_CURRENT, i);
      if(h > maxPrice)
      {
         maxPrice = h;
         maxBar   = i;
      }
   }

   if(maxBar < 0) return false;
   outPrice = maxPrice;
   outBar   = maxBar;
   return true;
}

//+------------------------------------------------------------------+
//| Find swing low (lowest low in lookback window)                   |
//+------------------------------------------------------------------+
bool FindSwingLow(int startBar, int lookback, double &outPrice, int &outBar)
{
   double minPrice = DBL_MAX;
   int    minBar   = -1;

   for(int i = startBar; i > startBar - lookback && i >= 0; i--)
   {
      double l = iLow(_Symbol, PERIOD_CURRENT, i);
      if(l < minPrice)
      {
         minPrice = l;
         minBar   = i;
      }
   }

   return (minBar >= 0) ? (outPrice = minPrice, outBar = minBar, true) : false;
}

//+------------------------------------------------------------------+
//| Find nearest support below price (sell TP)                       |
//+------------------------------------------------------------------+
double FindNearestSupport(int fromBar, double currentPrice)
{
   double supportPrice = 0;
   int    lastSwingIdx = -1;
   double lastSwingPrice = 0;

   for(int i = fromBar - 1; i >= 1; i--)
   {
      double swPrice; int swIdx;
      if(FindSwingLow(i, InpSwingLookback, swPrice, swIdx))
      {
         if(swPrice > 0 && swPrice < currentPrice)
         {
            if(supportPrice == 0 || swPrice < supportPrice)
               supportPrice = swPrice;
         }
         // Track last valid swing low
         if(swPrice > 0 && swPrice < currentPrice)
            { lastSwingPrice = swPrice; lastSwingIdx = swIdx; }
      }
   }

   // Fallback: use recent swing low
   if(supportPrice == 0 && lastSwingPrice > 0)
      return lastSwingPrice;

   return supportPrice;
}

//+------------------------------------------------------------------+
//| Find nearest resistance above price (buy TP)                     |
//+------------------------------------------------------------------+
double FindNearestResistance(int fromBar, double currentPrice)
{
   double resistPrice = 0;

   for(int i = fromBar - 1; i >= 1; i--)
   {
      double swPrice; int swIdx;
      if(FindSwingHigh(i, InpSwingLookback, swPrice, swIdx))
      {
         if(swPrice > 0 && swPrice > currentPrice)
         {
            if(resistPrice == 0 || swPrice < resistPrice)
               resistPrice = swPrice;
         }
      }
   }
   return resistPrice;
}

//+------------------------------------------------------------------+
//| Check if price is rejected from resistance (for sell)            |
//+//+------------------------------------------------------------------+
bool IsRejectingResistance(int bar)
{
   if(bar < 2) return false;

   double high0  = iHigh(_Symbol, PERIOD_CURRENT, bar);
   double high1  = iHigh(_Symbol, PERIOD_CURRENT, bar - 1);
   double close0 = iClose(_Symbol, PERIOD_CURRENT, bar);
   double close1 = iClose(_Symbol, PERIOD_CURRENT, bar - 1);

   // Rejection: candle had a wick above body (rejected upward)
   double bodyTop = MathMax(close0, open(bar));
   double bodyBot = MathMin(close0, open(bar));
   double upperWick = high0 - bodyTop;
   double bodySize  = MathAbs(close0 - open(bar));

   // Upper wick > body = rejection pattern
   return (upperWick > bodySize && bodySize > 0);
}

//+------------------------------------------------------------------+
//| Check if price is rejected from support (for buy)                |
//+------------------------------------------------------------------+
bool IsRejectingSupport(int bar)
{
   if(bar < 2) return false;

   double low0   = iLow(_Symbol, PERIOD_CURRENT, bar);
   double low1   = iLow(_Symbol, PERIOD_CURRENT, bar - 1);
   double close0 = iClose(_Symbol, PERIOD_CURRENT, bar);
   double open0  = open(bar);

   // Rejection: candle had a wick below body (rejected downward)
   double bodyTop = MathMax(close0, open0);
   double bodyBot = MathMin(close0, open0);
   double lowerWick = bodyBot - low0;
   double bodySize  = MathAbs(close0 - open0);

   return (lowerWick > bodySize && bodySize > 0);
}

double open(int bar) { return iOpen(_Symbol, PERIOD_CURRENT, bar); }

//+------------------------------------------------------------------+
//| Check if position is open for this EA                            |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      CPositionInfo pos;
      if(pos.SelectByIndex(i))
      {
         if(pos.Symbol() == _Symbol && pos.Magic() == InpMagic)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Get position for this EA                                         |
//+------------------------------------------------------------------+
bool GetMyPosition(CPositionInfo &pos)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(pos.SelectByIndex(i))
      {
         if(pos.Symbol() == _Symbol && pos.Magic() == InpMagic)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check if session is allowed                                      |
//+------------------------------------------------------------------+
bool IsSessionAllowed()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   int h = dt.hour;

   if(!InpAllowAsian && h >= 0 && h < 9) return false;
   if(!InpAllowLondon && h >= 8 && h < 12) return false;
   if(!InpAllowNY && h >= 13 && h < 17) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk %                               |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistancePips)
{
   if(slDistancePips <= 0) return InpMinLot;

   double equity    = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmt   = equity * (InpRiskPercent / 100.0);
   double pipSize   = PipValue();
   double contract  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double pipCost   = contract * pipSize; // account currency per pip per lot
   double lot       = riskAmt / (slDistancePips * pipCost);
   lot = MathMax(lot, InpMinLot);
   lot = MathMin(lot, InpMaxLot);
   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| Compute trade parameters for sell (Cipeng pattern)              |
//+------------------------------------------------------------------+
bool ComputeSellParams(double closePrice, SOrderParams &params)
{
   // Find swing high for SL
   double swingHighPrice; int swingHighBar;
   if(!FindSwingHigh(1, InpSwingLookback, swingHighPrice, swingHighBar))
      return false;

   double slDistPips = (swingHighPrice - closePrice) / PipValue();
   if(slDistPips < 5 || slDistPips > 200) return false; // Sanity check

   double slPrice   = NormalizePrice(swingHighPrice + PipsToPrice(InpSL_BufferPips));
   double slDist    = slPrice - closePrice;

   double tpDist    = slDist * InpRiskRewardRatio;
   double nearestSupport = FindNearestSupport(1, closePrice);
   double tpPrice;

   if(nearestSupport > 0 && (nearestSupport - closePrice) < tpDist)
      tpPrice = NormalizePrice(nearestSupport);
   else
      tpPrice = NormalizePrice(closePrice - tpDist);

   params.slPrice    = slPrice;
   params.tpPrice   = tpPrice;
   params.entryPrice = NormalizePrice(closePrice);
   params.riskPips   = slDistPips;
   params.dir        = POSITION_TYPE_SELL;

   DEBUG("CIPENG SELL: entry=", DoubleToString(closePrice, _Digits),
         " SL=", DoubleToString(slPrice, _Digits),
         " TP=", DoubleToString(tpPrice, _Digits),
         " risk=", DoubleToString(params.riskPips, 1), " pips");

   return true;
}

//+------------------------------------------------------------------+
//| Compute trade parameters for buy (mirror)                        |
//+------------------------------------------------------------------+
bool ComputeBuyParams(double closePrice, SOrderParams &params)
{
   // Find swing low for SL
   double swingLowPrice; int swingLowBar;
   if(!FindSwingLow(1, InpSwingLookback, swingLowPrice, swingLowBar))
      return false;

   double slDistPips = (closePrice - swingLowPrice) / PipValue();
   if(slDistPips < 5 || slDistPips > 200) return false;

   double slPrice   = NormalizePrice(swingLowPrice - PipsToPrice(InpSL_BufferPips));
   double slDist    = closePrice - slPrice;

   double tpDist    = slDist * InpRiskRewardRatio;
   double nearestResist = FindNearestResistance(1, closePrice);
   double tpPrice;

   if(nearestResist > 0 && (nearestResist - closePrice) > tpDist)
      tpPrice = NormalizePrice(nearestResist);
   else
      tpPrice = NormalizePrice(closePrice + tpDist);

   params.slPrice    = slPrice;
   params.tpPrice   = tpPrice;
   params.entryPrice = NormalizePrice(closePrice);
   params.riskPips   = slDistPips;
   params.dir        = POSITION_TYPE_BUY;

   DEBUG("CIPENG BUY: entry=", DoubleToString(closePrice, _Digits),
         " SL=", DoubleToString(slPrice, _Digits),
         " TP=", DoubleToString(tpPrice, _Digits),
         " risk=", DoubleToString(params.riskPips, 1), " pips");

   return true;
}

//+------------------------------------------------------------------+
//| Check if new bar has formed                                       |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime curBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(curBarTime == g_barTime) return false;
   g_barTime = curBarTime;
   return true;
}

//+------------------------------------------------------------------+
//| Reset daily counters at start of new day                         |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime todayDate = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));

   if(g_lastTradeDate != todayDate)
   {
      g_lastTradeDate  = todayDate;
      g_tradesToday    = 0;
      g_dailyLimitHit  = false;
      g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_dailyPnL       = 0.0;
      DEBUG("CIPENG: Daily reset — trades=", g_tradesToday,
            " startEquity=", DoubleToString(g_dayStartEquity, 2));
   }
}

//+------------------------------------------------------------------+
//| Check and update daily loss limit                                |
//+------------------------------------------------------------------+
void UpdateDailyPnL()
{
   if(g_dayStartEquity <= 0) return;
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_dailyPnL = (currentEquity - g_dayStartEquity) / g_dayStartEquity * 100.0;

   if(g_dailyPnL <= -InpMaxDailyLossPct)
   {
      g_dailyLimitHit = true;
      DEBUG("CIPENG: DAILY LOSS LIMIT HIT! PnL=", DoubleToString(g_dailyPnL, 2), "%");
   }
}

//+------------------------------------------------------------------+
//| Execute a trade                                                   |
//+------------------------------------------------------------------+
bool ExecuteTrade(SOrderParams &params)
{
   double lot = CalculateLotSize(params.riskPips);

   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(InpSlippage);
   g_trade.SetType(params.dir);

   bool result;
   if(params.dir == POSITION_TYPE_SELL)
      result = g_trade.Sell(lot, _Symbol, 0.0, params.slPrice, params.tpPrice);
   else
      result = g_trade.Buy(lot, _Symbol, 0.0, params.slPrice, params.tpPrice);

   if(result)
   {
      g_tradesToday++;
      if(InpCommentEnabled)
      {
         string cmt = StringFormat("Cipeng|%s|RR=%.1f|Risk=%.0fpips",
            params.dir == POSITION_TYPE_SELL ? "SELL" : "BUY",
            InpRiskRewardRatio, params.riskPips);
         g_trade.ResultComment(cmt);
      }
      DEBUG("CIPENG: Trade executed — ", params.dir == POSITION_TYPE_SELL ? "SELL" : "BUY",
            " lot=", DoubleToString(lot, 2),
            " SL=", DoubleToString(params.slPrice, _Digits),
            " TP=", DoubleToString(params.tpPrice, _Digits));
   }
   else
   {
      DEBUG("CIPENG: Trade FAILED — ", params.dir == POSITION_TYPE_SELL ? "SELL" : "BUY",
            " code=", GetLastError(),
            " msg=", ErrorDescription(GetLastError()));
   }

   return result;
}

//+------------------------------------------------------------------+
//| Trailing stop logic                                               |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   CPositionInfo pos;
   if(!GetMyPosition(pos)) return;

   double entryPrice = pos.PriceOpen();
   double currentPrice = pos.PriceCurrent();
   double slPrice = pos.StopLoss();
   double pipVal = PipValue();

   double profitPips = (pos.PositionType() == POSITION_TYPE_SELL)
      ? (entryPrice - currentPrice) / pipVal
      : (currentPrice - entryPrice) / pipVal;

   // Activate trailing at 1:1 or InpTS_ActivatePips
   double activationPips = (InpTS_ActivatePips > 0) ? InpTS_ActivatePips : pos.Volume();

   if(profitPips < activationPips) return;

   double tsDistPips = MathMax(InpTS_StepPips, 5);
   double newSL;

   if(pos.PositionType() == POSITION_TYPE_SELL)
   {
      // For sell: TS moves SL up
      double tsDist = PipsToPrice((int)tsDistPips);
      newSL = currentPrice + tsDist;
      newSL = NormalizePrice(newSL);
      if(newSL < slPrice)  // Only move SL up (for sell)
         return; // Invalid
      // SL should be above current price for sell but below entry (locked)
      // Simple TS: lock in profit when price moves favorably
      newSL = NormalizePrice(entryPrice - PipsToPrice((int)tsDistPips / 2));
      if(newSL > slPrice && newSL < currentPrice)
      {
         g_trade.PositionModify(pos.Ticket(), newSL, pos.TakeProfit());
         DEBUG("CIPENG: TS activated for SELL — newSL=", DoubleToString(newSL, _Digits));
      }
   }
   else
   {
      // For buy: TS moves SL down
      double tsDist = PipsToPrice((int)tsDistPips);
      newSL = currentPrice - tsDist;
      newSL = NormalizePrice(newSL);
      if(newSL < slPrice && newSL > currentPrice)
      {
         g_trade.PositionModify(pos.Ticket(), newSL, pos.TakeProfit());
         DEBUG("CIPENG: TS activated for BUY — newSL=", DoubleToString(newSL, _Digits));
      }
   }
}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  EVENT HANDLERS                                                  ║
// ╚══════════════════════════════════════════════════════════════════╝

//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize symbol
   if(!g_symbol.Name(_Symbol))
   {
      Print("CIPENG: Failed to initialize symbol: ", _Symbol);
      return(INIT_PARAMETERS_INCORRECT);
   }

   g_trade.SetExpertMagicNumber(InpMagic);

   // Validate inputs
   if(InpSMA_Period < 2)    { Print("CIPENG: SMA period must be >= 2"); return INIT_PARAMETERS_INCORRECT; }
   if(InpRSI_SellLevel < 50 || InpRSI_BuyLevel > 50) { /* Allow flexible */ }
   if(InpRiskRewardRatio < 0.5) { Print("CIPENG: Risk:Reward must be >= 0.5"); return INIT_PARAMETERS_INCORRECT; }

   CheckDailyReset();
   DEBUG("CIPENG: EA Initialized — Symbol=", _Symbol, " Magic=", InpMagic);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DEBUG("CIPENG: EA Deinitialized — reason=", reason);
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(!IsNewBar()) return;

   // Refresh rate limit checks
   CheckDailyReset();
   UpdateDailyPnL();

   if(g_dailyLimitHit)
   {
      DEBUG("CIPENG: Daily loss limit hit — no new trades");
      return;
   }

   if(g_tradesToday >= InpMaxTradesPerDay)
   {
      DEBUG("CIPENG: Max daily trades reached");
      return;
   }

   if(HasOpenPosition())
   {
      // Manage trailing stop for open position
      ManageTrailingStop();
      return;
   }

   if(!IsSessionAllowed())
   {
      DEBUG("CIPENG: Session not allowed");
      return;
   }

   if(!IsVolatilitySafe())
   {
      DEBUG("CIPENG: High volatility — trade blocked");
      return;
   }

   // ============ ANALYZE MARKET ============

   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double smaVal = iMA(_Symbol, PERIOD_CURRENT, InpSMA_Period, 0, MODE_SMA, PRICE_CLOSE, 1);
   double rsiVal  = iRSI(_Symbol, PERIOD_CURRENT, InpRSI_Period_S, PRICE_CLOSE, 1);
   double macdMain, macdSignal, macdHist;
   iMACD(_Symbol, PERIOD_CURRENT, InpMACD_Fast_S, InpMACD_Slow_S, InpMACD_Signal_S, PRICE_CLOSE, 1, macdMain, macdSignal, macdHist);

   DEBUG("CIPENG: SMA=", DoubleToString(smaVal, _Digits),
         " RSI=", DoubleToString(rsiVal, 1),
         " MACD_hist=", DoubleToString(macdHist, 5),
         " close=", DoubleToString(close1, _Digits));

   SOrderParams params;

   // ============ SELL LOGIC (Cipeng) ============
   if(InpEntryMode == MODE_BOTH || InpEntryMode == MODE_SELL_ONLY)
   {
      bool bearishBias   = (close1 < smaVal);
      bool rsiOB         = (rsiVal > InpRSI_SellLevel);
      bool macdNeg       = (macdHist < 0);
      bool rejection     = IsRejectingResistance(1);

      DEBUG("CIPENG SELL CHECK: bearish=", bearishBias,
            " RSI_OB=", rsiOB, " MACD_neg=", macdNeg, " reject=", rejection);

      if(bearishBias && rsiOB && macdNeg)
      {
         if(ComputeSellParams(close1, params))
         {
            ExecuteTrade(params);
            return;
         }
      }
   }

   // ============ BUY LOGIC (Mirror) ============
   if(InpEntryMode == MODE_BOTH || InpEntryMode == MODE_BUY_ONLY)
   {
      double rsiValBuy = iRSI(_Symbol, PERIOD_CURRENT, InpRSI_Period_B, PRICE_CLOSE, 1);
      double macdMainB, macdSigB, macdHistB;
      iMACD(_Symbol, PERIOD_CURRENT, InpMACD_Fast_B, InpMACD_Slow_B, InpMACD_Signal_B, PRICE_CLOSE, 1, macdMainB, macdSigB, macdHistB);

      bool bullBias   = (close1 > smaVal);
      bool rsiOS      = (rsiValBuy < InpRSI_BuyLevel);
      bool macdPos    = (macdHistB > 0);
      bool rejectionB = IsRejectingSupport(1);

      DEBUG("CIPENG BUY CHECK: bull=", bullBias,
            " RSI_OS=", rsiOS, " MACD_pos=", macdPos, " reject=", rejectionB);

      if(bullBias && rsiOS && macdPos)
      {
         if(ComputeBuyParams(close1, params))
         {
            ExecuteTrade(params);
            return;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Handle trade events (comment closes/TP/SL)                       |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans)
{
   if(trans.type == TRADE_TRANSACTION_POSITION)
   {
      UpdateDailyPnL();
   }
}
//+------------------------------------------------------------------+