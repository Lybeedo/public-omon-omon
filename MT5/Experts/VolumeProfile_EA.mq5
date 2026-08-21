//+------------------------------------------------------------------+
//|                              VolumeProfile_EA.mq5                |
//|                                Cuancux Algo Traders / Paulus     |
//|                   Fabio Volume Profile + ATR Dynamic TP/SL       |
//+------------------------------------------------------------------+
#property copyright   "Cuancux Algo Traders"
#property version     "1.00"
#property strict
#property description "Fabio Volume Profile Strategy - World Cup Trader"
#property description "Session VA breakout/reversion + LuxAlgo enhancements"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Input: Profile Mode                                               |
//+------------------------------------------------------------------+
input group "=== PROFILE MODE ==="
input bool     UsePrevDayProfile  = true;   // Use Previous Day Profile (static)
input int      ProfileLookback    = 30;    // Bars lookback for profile calculation
input int      SessionStartHour   = 18;    // Session anchor hour (broker time)
input int      SessionStartMin    = 0;     // Session anchor minute

//+------------------------------------------------------------------+
//| Input: Value Area                                                 |
//+------------------------------------------------------------------+
input group "=== VALUE AREA ==="
input double   VA_Percent         = 70.0;   // Value Area % (70 = 70% volume)
input double   VA_Padding         = 1.0;   // Padding above/below VA (points)

//+------------------------------------------------------------------+
//| Input: Volume Filter                                              |
//+------------------------------------------------------------------+
input group "=== VOLUME FILTER ==="
input bool     UseVolumeFilter    = true;   // Enable volume filter
input int      VolDeclineBars     = 3;     // Consecutive declining volume bars
input double   VolMinRatio        = 0.7;   // Min volume ratio vs average

//+------------------------------------------------------------------+
//| Input: LuxAlgo Enhancements                                       |
//+------------------------------------------------------------------+
input group "=== LUXALGO ENHANCEMENTS ==="
input bool     Use5BarRule        = true;   // 5-bar entry window
input int      MaxEntryBars       = 5;     // Max bars after breakout for entry
input bool     UseEngulfingFilter = true;   // Engulfing candle filter
input bool     VolExpandingOnReversal = true; // Volume expanding on reversal

//+------------------------------------------------------------------+
//| Input: ATR Dynamic TP/SL                                          |
//+------------------------------------------------------------------+
input group "=== ATR DYNAMIC TP/SL ==="
input int      ATR_Period         = 14;    // ATR period
input double   ATR_Mult_TP        = 2.0;   // TP multiplier (ATR x N)
input double   ATR_Mult_SL        = 1.5;   // SL multiplier (ATR x N)
input bool     UseATRTight        = false; // Tight ATR for scalping

//+------------------------------------------------------------------+
//| Input: Trade Management                                           |
//+------------------------------------------------------------------+
input group "=== TRADE MANAGEMENT ==="
input double   FixedLotSize       = 0.1;   // Fixed lot (0 = risk-based)
input double   RiskPercent        = 2.0;   // Risk % if FixedLot=0
input int      MaxOpenPositions   = 1;     // Max concurrent positions
input bool     UseBreakeven       = true;  // Enable breakeven
input int      BE_Offset          = 100;   // BE offset (points)
input int      ExpirationMinutes  = 240;   // Pending order expiry (0=no expiry)

//+------------------------------------------------------------------+
//| Input: Session Filter                                             |
//+------------------------------------------------------------------+
input group "=== SESSION FILTER ==="
input bool     UseSessionFilter   = false; // Enable session filter
input int      SignalStartHour    = 9;     // Allow entries from this hour
input int      SignalStartMinute  = 30;
input int      SignalEndHour      = 17;    // Stop entries after this hour
input int      SignalEndMinute    = 0;

//+------------------------------------------------------------------+
//| Input: Broker Offset                                              |
//+------------------------------------------------------------------+
input group "=== BROKER OFFSET ==="
input int      BrokerOffsetMins   = 0;     // Broker offset from UTC (minutes)

//+------------------------------------------------------------------+
//| Globals                                                           |
//+------------------------------------------------------------------+
#define PREFIX "VP_"
CTrade g_trade;

// Volume profile data
struct SVolumeProfile
{
   double  vah;       // Value Area High
   double  val;       // Value Area Low
   double  poc;       // Point of Control
   double  totalVol;  // Total volume
};

SVolumeProfile g_profile;
double         g_atr = 0;
double         g_avgVol = 0;
static datetime g_lastProfileUpdate = 0;
static bool     g_newSession = false;

//+------------------------------------------------------------------+
//| Get current broker time                                           |
//+------------------------------------------------------------------+
datetime GetBrokerTime()
{
   MqlDateTime brokerTm;
   TimeToStruct(TimeCurrent(), brokerTm);
   return StringFormat("%04d.%02d.%02d %02d:%02d:%02d",
                      brokerTm.year, brokerTm.mon, brokerTm.day,
                      brokerTm.hour, brokerTm.min, brokerTm.sec);
}

//+------------------------------------------------------------------+
//| Check if within signal window                                     |
//+------------------------------------------------------------------+
bool IsWithinSignalWindow()
{
   if(!UseSessionFilter) return true;
   
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   int curMin = tm.hour * 60 + tm.min;
   int startMin = SignalStartHour * 60 + SignalStartMinute;
   int endMin   = SignalEndHour   * 60 + SignalEndMinute;
   
   if(endMin > startMin)
      return (curMin >= startMin && curMin <= endMin);
   else
      return (curMin >= startMin || curMin <= endMin);
}

//+------------------------------------------------------------------+
//| Calculate Volume Profile (current or previous day)                |
//+------------------------------------------------------------------+
void CalculateVolumeProfile()
{
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   datetime today = StructToTime(tm);
   
   datetime sessionStart;
   if(UsePrevDayProfile)
   {
      // Use previous day's data
      today -= PeriodSeconds(PERIOD_D1);
   }
   else
   {
      // Use current session start
      sessionStart = today + (SessionStartHour * 3600 + SessionStartMin * 60);
      if(TimeCurrent() < sessionStart) sessionStart -= PeriodSeconds(PERIOD_D1);
   }
   
   // Check if new session
   if(g_lastProfileUpdate != (datetime)today)
   {
      g_newSession = true;
      g_lastProfileUpdate = (datetime)today;
   }
   
   // Get rates
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int count = UsePrevDayProfile ? (int)(PeriodSeconds(PERIOD_D1) / PeriodSeconds(_Period)) : ProfileLookback;
   count = MathMin(count, 500); // Safety limit
   
   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, count, rates);
   if(copied <= 0) return;
   
   // Calculate volume distribution
   double maxVol = 0;
   double minVol = DBL_MAX;
   double totalVol = 0;
   
   // Find price range
   double maxPrice = rates[0].high;
   double minPrice = rates[0].low;
   for(int i = 0; i < copied; i++)
   {
      if(rates[i].high > maxPrice) maxPrice = rates[i].high;
      if(rates[i].low < minPrice) minPrice = rates[i].low;
      totalVol += rates[i].tick_volume;
   }
   
   if(totalVol == 0) return;
   
   // Use 100 price bins
   int bins = 100;
   double binSize = (maxPrice - minPrice) / bins;
   if(binSize == 0) return;
   
   double[] binVolume = new double[bins];
   ArrayInitialize(binVolume, 0);
   
   // Distribute volume into bins
   for(int i = 0; i < copied; i++)
   {
      double typical = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
      int bin = (int)((typical - minPrice) / binSize);
      bin = MathMax(0, MathMin(bins - 1, bin));
      binVolume[bin] += rates[i].tick_volume;
      
      if(binVolume[bin] > maxVol) maxVol = binVolume[bin];
      if(binVolume[bin] < minVol) minVol = binVolume[bin];
   }
   
   // Find POC (highest volume bin)
   double pocPrice = 0;
   double maxBinVol = 0;
   for(int i = 0; i < bins; i++)
   {
      if(binVolume[i] > maxBinVol)
      {
         maxBinVol = binVolume[i];
         pocPrice = minPrice + (i + 0.5) * binSize;
      }
   }
   
   // Find Value Area (70% volume centered on POC)
   double vaTarget = totalVol * (VA_Percent / 100.0);
   double cumVol = maxBinVol;
   int pocBin = (int)((pocPrice - minPrice) / binSize);
   
   int leftBin = pocBin;
   int rightBin = pocBin;
   
   while(cumVol < vaTarget && (leftBin > 0 || rightBin < bins - 1))
   {
      double leftVol = (leftBin > 0) ? binVolume[leftBin - 1] : 0;
      double rightVol = (rightBin < bins - 1) ? binVolume[rightBin + 1] : 0;
      
      if(leftVol >= rightVol && leftBin > 0)
      {
         leftBin--;
         cumVol += binVolume[leftBin];
      }
      else if(rightBin < bins - 1)
      {
         rightBin++;
         cumVol += binVolume[rightBin];
      }
      else break;
   }
   
   // Set profile values
   g_profile.val = minPrice + leftBin * binSize;
   g_profile.vah = minPrice + (rightBin + 1) * binSize;
   g_profile.poc = pocPrice;
   g_profile.totalVol = totalVol;
   
   // Add padding
   g_profile.val -= VA_Padding * _Point;
   g_profile.vah += VA_Padding * _Point;
   
   // Normalize
   g_profile.val = NormalizeDouble(g_profile.val, _Digits);
   g_profile.vah = NormalizeDouble(g_profile.vah, _Digits);
   g_profile.poc = NormalizeDouble(g_profile.poc, _Digits);
   
   // Calculate average volume for filter
   g_avgVol = totalVol / copied;
}

//+------------------------------------------------------------------+
//| Get ATR                                                           |
//+------------------------------------------------------------------+
double GetATR()
{
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(iATR(_Symbol, PERIOD_CURRENT, ATR_Period), 0, 0, 2, atr) < 2) return 0;
   return atr[0];
}

//+------------------------------------------------------------------+
//| Check if volume is declining (for breakout filter)               |
//+------------------------------------------------------------------+
bool CheckVolumeDeclining(int bars)
{
   if(!UseVolumeFilter) return true;
   
   long[] vol = new long[bars + 1];
   if(CopyVolume(_Symbol, PERIOD_CURRENT, 0, bars + 1, vol) <= 0) return true;
   
   ArraySetAsSeries(vol, true);
   
   int declineCount = 0;
   for(int i = 0; i < bars && i < bars; i++)
   {
      if(vol[i] < vol[i + 1]) declineCount++;
      else break;
   }
   
   return declineCount >= VolDeclineBars;
}

//+------------------------------------------------------------------+
//| Check for engulfing candle                                        |
//+------------------------------------------------------------------+
bool CheckEngulfing(bool isBuy)
{
   if(!UseEngulfingFilter) return true;
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 2, rates) < 2) return true;
   
   if(isBuy)
   {
      // Bullish engulfing: current close > current open > previous close > previous open
      return (rates[1].close > rates[1].open) &&   // Previous bullish
             (rates[0].close > rates[0].open) &&   // Current bullish
             (rates[0].open <= rates[1].close) &&  // Current open inside prev range
             (rates[0].close >= rates[1].high);    // Current close above prev high
   }
   else
   {
      // Bearish engulfing: current close < current open < previous close < previous open
      return (rates[1].close < rates[1].open) &&   // Previous bearish
             (rates[0].close < rates[0].open) &&   // Current bearish
             (rates[0].open >= rates[1].close) &&  // Current open inside prev range
             (rates[0].close <= rates[1].low);     // Current close below prev low
   }
}

//+------------------------------------------------------------------+
//| Check if volume is expanding on reversal                         |
//+------------------------------------------------------------------+
bool CheckVolExpanding()
{
   if(!VolExpandingOnReversal) return true;
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 2, rates) < 2) return true;
   
   return rates[0].tick_volume > rates[1].tick_volume;
}

//+------------------------------------------------------------------+
//| Check if breakout occurred and track bars since                   |
//+------------------------------------------------------------------+
struct BreakoutState
{
   bool  longBreakout;  // Price broke below VAL
   bool  shortBreakout; // Price broke above VAH
   int   barsSinceLong;
   int   barsSinceShort;
   bool  longTriggered;
   bool  shortTriggered;
};

BreakoutState g_breakout;

void UpdateBreakoutState()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 10, rates) < 10) return;
   
   // Check each recent bar for breakouts
   for(int i = 0; i < 10; i++)
   {
      if(rates[i].low <= g_profile.val && !g_breakout.longBreakout)
      {
         g_breakout.longBreakout = true;
         g_breakout.barsSinceLong = 0;
      }
      if(rates[i].high >= g_profile.vah && !g_breakout.shortBreakout)
      {
         g_breakout.shortBreakout = true;
         g_breakout.barsSinceShort = 0;
      }
   }
   
   // Increment counters
   if(g_breakout.longBreakout && !g_breakout.longTriggered)
      g_breakout.barsSinceLong++;
   if(g_breakout.shortBreakout && !g_breakout.shortTriggered)
      g_breakout.barsSinceShort++;
}

//+------------------------------------------------------------------+
//| Check long setup                                                  |
//+------------------------------------------------------------------+
bool CheckLongSetup()
{
   if(!g_breakout.longBreakout || g_breakout.longTriggered) return false;
   if(g_breakout.barsSinceLong > MaxEntryBars && Use5BarRule) return false;
   
   // Check volume filter
   if(!CheckVolumeDeclining(VolDeclineBars)) return false;
   
   // Check for close back inside value area
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, rates) < 1) return false;
   
   bool closeInside = (rates[0].close > g_profile.val);
   
   // Check volume expanding
   if(!CheckVolExpanding()) return false;
   
   // Check engulfing
   if(!CheckEngulfing(true)) return false;
   
   return closeInside;
}

//+------------------------------------------------------------------+
//| Check short setup                                                 |
//+------------------------------------------------------------------+
bool CheckShortSetup()
{
   if(!g_breakout.shortBreakout || g_breakout.shortTriggered) return false;
   if(g_breakout.barsSinceShort > MaxEntryBars && Use5BarRule) return false;
   
   // Check volume filter
   if(!CheckVolumeDeclining(VolDeclineBars)) return false;
   
   // Check for close back inside value area
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, rates) < 1) return false;
   
   bool closeInside = (rates[0].close < g_profile.vah);
   
   // Check volume expanding
   if(!CheckVolExpanding()) return false;
   
   // Check engulfing
   if(!CheckEngulfing(false)) return false;
   
   return closeInside;
}

//+------------------------------------------------------------------+
//| Normalize lot size                                                |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
{
   double minLot   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double step     = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double maxLot   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double norm     = MathRound(lot / step) * step;
   return MathMax(minLot, MathMin(maxLot, norm));
}

//+------------------------------------------------------------------+
//| Calculate risk-based lot                                          |
//+------------------------------------------------------------------+
double CalcRiskLot(double slDistance)
{
   if(slDistance <= 0) return NormalizeLot(FixedLotSize > 0 ? FixedLotSize : 0.01);
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk = balance * (RiskPercent / 100.0);
   double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSz  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double slTicks = slDistance / tickSz;
   
   double lot = risk / (slTicks * tickVal);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(lot < minLot) lot = minLot;
   
   return NormalizeLot(lot);
}

//+------------------------------------------------------------------+
//| Count open positions                                              |
//+------------------------------------------------------------------+
int CountPositions()
{
   int cnt = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_UNKNOWN)
         cnt++;
   }
   return cnt;
}

//+------------------------------------------------------------------+
//| Count pending orders                                              |
//+------------------------------------------------------------------+
int CountPendingOrders()
{
   int cnt = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderGetString(ORDER_SYMBOL) == _Symbol) cnt++;
   }
   return cnt;
}

//+------------------------------------------------------------------+
//| Delete all pending orders                                         |
//+------------------------------------------------------------------+
void DeletePendingOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(OrderGetString(ORDER_SYMBOL) == _Symbol)
         OrderDelete(ticket);
   }
}

//+------------------------------------------------------------------+
//| Draw profile zones                                                |
//+------------------------------------------------------------------+
void DrawProfileZones()
{
   // Remove old objects
   ObjectsDeleteAll(0, PREFIX);
   
   datetime now = (datetime)TimeCurrent();
   datetime right = now + PeriodSeconds(PERIOD_H1);
   
   // VAH line
   string vahName = PREFIX + "VAH";
   ObjectCreate(0, vahName, OBJ_HLINE, 0, now, g_profile.vah);
   ObjectSetInteger(0, vahName, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, vahName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, vahName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetString(0, vahName, OBJPROP_TEXT, "VAH");
   
   // VAL line
   string valName = PREFIX + "VAL";
   ObjectCreate(0, valName, OBJ_HLINE, 0, now, g_profile.val);
   ObjectSetInteger(0, valName, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, valName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, valName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetString(0, valName, OBJPROP_TEXT, "VAL");
   
   // POC line
   string pocName = PREFIX + "POC";
   ObjectCreate(0, pocName, OBJ_HLINE, 0, now, g_profile.poc);
   ObjectSetInteger(0, pocName, OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, pocName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, pocName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetString(0, pocName, OBJPROP_TEXT, "POC");
   
   // Value Area fill
   string vaName = PREFIX + "VA_Zone";
   ObjectCreate(0, vaName, OBJ_RECTANGLE, 0, now, g_profile.val);
   ObjectSetInteger(0, vaName, OBJPROP_TIME, 1, right);
   ObjectSetDouble(0, vaName, OBJPROP_PRICE, 1, g_profile.vah);
   ObjectSetInteger(0, vaName, OBJPROP_COLOR, clrMagenta);
   ObjectSetInteger(0, vaName, OBJPROP_FILL, true);
   ObjectSetInteger(0, vaName, OBJPROP_BACK, true);
}

//+------------------------------------------------------------------+
//| Draw dashboard                                                    |
//+------------------------------------------------------------------+
void DrawDashboard()
{
   string info = "=== Volume Profile EA ===\n" +
                 "VAH: " + DoubleToString(g_profile.vah, _Digits) + "\n" +
                 "VAL: " + DoubleToString(g_profile.val, _Digits) + "\n" +
                 "POC: " + DoubleToString(g_profile.poc, _Digits) + "\n" +
                 "ATR: " + DoubleToString(g_atr, _Digits) + "\n" +
                 "TP: " + DoubleToString(g_atr * (UseATRTight ? 1.0 : ATR_Mult_TP), _Digits) + "\n" +
                 "SL: " + DoubleToString(g_atr * (UseATRTight ? 0.8 : ATR_Mult_SL), _Digits) + "\n" +
                 "Long Break: " + (g_breakout.longBreakout ? "YES" : "NO") + " (" + IntegerToString(g_breakout.barsSinceLong) + " bars)\n" +
                 "Short Break: " + (g_breakout.shortBreakout ? "YES" : "NO") + " (" + IntegerToString(g_breakout.barsSinceShort) + " bars)\n" +
                 "Open Positions: " + IntegerToString(CountPositions());
   Comment(info);
}

//+------------------------------------------------------------------+
//| Execute trade                                                     |
//+------------------------------------------------------------------+
void ExecuteTrade(bool isLong)
{
   g_trade.SetExpertMagicNumber(20260821);
   g_trade.SetDeviationInPoints(5);
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double slDist = g_atr * (UseATRTight ? 0.8 : ATR_Mult_SL);
   double tpDist = g_atr * (UseATRTight ? 1.0 : ATR_Mult_TP);
   
   double lot;
   if(FixedLotSize > 0)
      lot = NormalizeLot(FixedLotSize);
   else
      lot = CalcRiskLot(slDist);
   
   if(isLong)
   {
      double sl = NormalizeDouble(bid - slDist, _Digits);
      double tp = NormalizeDouble(ask + tpDist, _Digits);
      
      if(!g_trade.Buy(lot, _Symbol, ask, sl, tp, "VP_LONG"))
         Print("[VP] Buy failed: ", GetLastError());
      else
         Print("[VP] LONG entered at ", ask, " | SL: ", sl, " | TP: ", tp);
   }
   else
   {
      double sl = NormalizeDouble(ask + slDist, _Digits);
      double tp = NormalizeDouble(bid - tpDist, _Digits);
      
      if(!g_trade.Sell(lot, _Symbol, bid, sl, tp, "VP_SHORT"))
         Print("[VP] Sell failed: ", GetLastError());
      else
         Print("[VP] SHORT entered at ", bid, " | SL: ", sl, " | TP: ", tp);
   }
}

//+------------------------------------------------------------------+
//| Manage breakeven                                                  |
//+------------------------------------------------------------------+
void ManageBreakeven()
{
   if(!UseBreakeven) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      
      ulong ticket = PositionGetInteger(POSITION_TICKET);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double currentPrice = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                            SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                            SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      double profitPoints = 0;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         profitPoints = (currentPrice - entry) / _Point;
      else
         profitPoints = (entry - currentPrice) / _Point;
      
      if(profitPoints >= BE_Offset && sl < entry)
      {
         double newSL = NormalizeDouble(entry + BE_Offset * _Point, _Digits);
         g_trade.PositionModify(_Symbol, ticket, newSL, 0);
         Print("[VP] BE triggered for position ", ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Reset breakout state on new session                               |
//+------------------------------------------------------------------+
void ResetBreakoutState()
{
   g_breakout.longBreakout = false;
   g_breakout.shortBreakout = false;
   g_breakout.barsSinceLong = 0;
   g_breakout.barsSinceShort = 0;
   g_breakout.longTriggered = false;
   g_breakout.shortTriggered = false;
}

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   g_trade.SetExpertMagicNumber(20260821);
   ResetBreakoutState();
   Print("=== Volume Profile EA initialized ===");
   Print("Symbol: ", _Symbol, " | Period: ", EnumToString(_Period));
   Print("Mode: ", UsePrevDayProfile ? "Previous Day Profile" : "Current Session Profile");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, PREFIX);
   Comment("");
   Print("=== Volume Profile EA deinitialized: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick                                                       |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastCandleTime = 0;
   
   // Calculate ATR
   g_atr = GetATR();
   if(g_atr <= 0) return;
   
   // Check new session
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   datetime today = StructToTime(tm);
   
   if(today != g_lastProfileUpdate)
   {
      ResetBreakoutState();
      g_lastProfileUpdate = today;
   }
   
   // Calculate volume profile
   CalculateVolumeProfile();
   if(g_profile.vah == 0 || g_profile.val == 0) return;
   
   // Check new candle
   datetime candleTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool newCandle = (candleTime != lastCandleTime);
   if(newCandle) lastCandleTime = candleTime;
   
   // Update breakout state
   UpdateBreakoutState();
   
   // Draw visual
   DrawProfileZones();
   DrawDashboard();
   
   // Manage breakeven
   ManageBreakeven();
   
   // Check signals on new candle
   if(newCandle && IsWithinSignalWindow() && CountPositions() < MaxOpenPositions)
   {
      // Long setup: price broke below VAL, now closing back inside
      if(CheckLongSetup())
      {
         ExecuteTrade(true);
         g_breakout.longTriggered = true;
      }
      
      // Short setup: price broke above VAH, now closing back inside
      if(CheckShortSetup())
      {
         ExecuteTrade(false);
         g_breakout.shortTriggered = true;
      }
   }
}
//+------------------------------------------------------------------+
