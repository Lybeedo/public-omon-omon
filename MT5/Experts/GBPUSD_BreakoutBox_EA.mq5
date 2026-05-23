//+------------------------------------------------------------------+
//|              GBPUSD_BreakoutBox_EA.mq5                            |
//|  Based on Deni Dollar Technique (Bandung)                        |
//|  GBPUSD Only | Break 4-Candle HL Box | TP30 | No SL | Switch     |
//+------------------------------------------------------------------+
#property copyright "7NAGA / omon-omon"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Digit & Pip Auto-Detect                                          |
//+------------------------------------------------------------------+
int    GDigits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
double GPoint  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
double GPip    = (GDigits == 3 || GDigits == 5) ? GPoint * 10 : GPoint;

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== SESSION ==="
input ENUM_DAY_OF_WEEK  InpTradingDay      = MONDAY;       // Start trading day
input int               InpStartHour       = 7;            // Box start hour (broker time)
input int               InpCandleCount     = 4;            // Number of candles for HL box

input group "=== TRADE ==="
input double            InpBaseLot         = 0.1;          // Base lot size
input double            InpTPPips          = 30.0;        // TP in pips (300 points for 5-digit)
input int               InpMaxSpread       = 30;           // Max spread (pips)
input double            InpMaxSwitch       = 3;           // Max switch count (0=unlimited)
input int               InpMagicNumber     = 77777;        // Magic number
input int               InpMaxTrades       = 1;            // Max open positions

input group "=== RISK ==="
input double            InpMaxEquityRisk   = 50.0;        // Max equity drawdown % (0=disabled)
input double            InpRiskPerLot      = 50.0;        // USD per 0.1 lot risk (for lot calc)
input bool              InpEnableSwitch    = true;         // Enable switch/double lot on reverse

input group "=== FILTER ==="
input int               InpFilterCandles   = 0;            // Filter candles (0=disabled)
input bool              InpAllowSameDir    = false;        // Allow same direction after TP
input ENUM_TIMEFRAMES   InpTimeframe       = PERIOD_M15;   // Working timeframe

//+------------------------------------------------------------------+
//| State Machine                                                    |
//+------------------------------------------------------------------+
enum EBSTATE {
   BSTATE_IDLE,         // Waiting for session start
   BSTATE_BUILD_BOX,    // Building HL box from candles
   BSTATE_READY,        // Box ready, waiting for break
   BSTATE_PENDING_BREAK,// Break detected, not yet confirmed
   BSTATE_ACTIVE_LONG,  // In BUY position
   BSTATE_ACTIVE_SHORT, // In SELL position
   BSTATE_SWITCHING,    // Switch/double lot triggered
   BSTATE_COMPLETE      // TP hit, waiting for next session
};

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
EBSTATE      gState         = BSTATE_IDLE;
datetime     gBoxStartTime  = 0;
datetime     gLastBarTime   = 0;
double       gBoxHigh       = 0;
double       gBoxLow        = 0;
double       gEntryPrice    = 0;
double       gTPPips        = 0;
double       gBaseLot       = 0;
double       gCurrentLot    = 0;
int          gSwitchCount   = 0;
bool         gBoxBuilt      = false;
datetime     gPendingBar    = 0;
double       gPendingSide   = 0; // +1 = buy break, -1 = sell break
CTrade       gTrade;
datetime     gSessionDate   = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit() {
   if(_Symbol != "GBPUSD") {
      Alert("⚠️ This EA is for GBPUSD only!");
      return INIT_PARAMETERS_INCORRECT;
   }
   gTrade.SetExpertMagicNumber(InpMagicNumber);
   gTrade.SetDeviationInPoints(10);
   gTPPips = InpTPPips;
   gBaseLot = InpBaseLot;
   gCurrentLot = InpBaseLot;
   Print("✅ GBPUSD_BreakoutBox EA loaded | TP=", InpTPPips, " pips | BaseLot=", InpBaseLot);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   Print("EA removed. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Main Tick Handler                                                |
//+------------------------------------------------------------------+
void OnTick() {
   // Equity guard
   if(InpMaxEquityRisk > 0) {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(equity < balance * (1 - InpMaxEquityRisk / 100.0)) {
         if(PositionSelect(_Symbol)) {
            gTrade.PositionClose(_Symbol);
            gState = BSTATE_IDLE;
            Print("⚠️ Equity protection triggered. All positions closed.");
         }
         return;
      }
   }

   datetime curBar = iTime(_Symbol, InpTimeframe, 0);
   if(curBar == gLastBarTime) return; // Same bar, skip
   gLastBarTime = curBar;

   // State machine
   switch(gState) {
      case BSTATE_IDLE:
         CheckSessionStart();
         break;
      case BSTATE_BUILD_BOX:
         BuildBox();
         break;
      case BSTATE_READY:
         DetectBreakout();
         break;
      case BSTATE_PENDING_BREAK:
         ConfirmBreakout();
         break;
      case BSTATE_ACTIVE_LONG:
      case BSTATE_ACTIVE_SHORT:
         MonitorActivePosition();
         break;
   }
}

//+------------------------------------------------------------------+
//| Check if session should start                                    |
//+------------------------------------------------------------------+
void CheckSessionStart() {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Only run on configured trading day
   ENUM_DAY_OF_WEEK today = (ENUM_DAY_OF_WEEK)dt.day_of_week;
   if(today != InpTradingDay && InpTradingDay != 0) {
      return;
   }
   
   int curHour = dt.hour;
   
   if(curHour >= InpStartHour && !gBoxBuilt) {
      gBoxStartTime = iTime(_Symbol, InpTimeframe, 0);
      gSessionDate = StringToTime(DateToStr(TimeCurrent(), TIME_DATE));
      gSwitchCount = 0;
      gCurrentLot = InpBaseLot;
      gState = BSTATE_BUILD_BOX;
      Print("📦 [", EnumToString((ENUM_DAY_OF_WEEK)today), "] Box build started at hour ", InpStartHour);
   }
}

//+------------------------------------------------------------------+
//| Build HL Box from first N candles                                |
//+------------------------------------------------------------------+
void BuildBox() {
   if(gBoxBuilt) return;
   
   datetime curBar = iTime(_Symbol, InpTimeframe, 0);
   
   // Wait until we have enough candles
   datetime firstCandleTime = iTime(_Symbol, InpTimeframe, InpCandleCount);
   if(firstCandleTime == 0) return;
   
   double highestHigh = -DBL_MAX;
   double lowestLow   = DBL_MAX;
   
   for(int i = 0; i < InpCandleCount; i++) {
      double h = iHigh(_Symbol, InpTimeframe, i);
      double l = iLow(_Symbol, InpTimeframe, i);
      if(h > highestHigh) highestHigh = h;
      if(l < lowestLow) lowestLow = l;
   }
   
   gBoxHigh = highestHigh;
   gBoxLow  = lowestLow;
   gBoxBuilt = true;
   gState = BSTATE_READY;
   
   // Visual box
   DrawBox(gBoxHigh, gBoxLow);
   
   Print("📊 Box built | High=", gBoxHigh, " | Low=", gBoxLow, 
         " | Range=", (gBoxHigh - gBoxLow)/GPip, " pips");
}

//+------------------------------------------------------------------+
//| Detect breakout from box                                          |
//+------------------------------------------------------------------+
void DetectBreakout() {
   double close = iClose(_Symbol, InpTimeframe, 0);
   double high  = iHigh(_Symbol, InpTimeframe, 0);
   double low   = iLow(_Symbol, InpTimeframe, 0);
   
   // Wait for candle close confirmation
   // Break UP: candle close above box high
   if(close > gBoxHigh) {
      gPendingSide = 1;
      gPendingBar = iTime(_Symbol, InpTimeframe, 0);
      gState = BSTATE_PENDING_BREAK;
      Print("🔺 Breakout UP detected | Close=", close, " > BoxHigh=", gBoxHigh);
   }
   // Break DOWN: candle close below box low
   else if(close < gBoxLow) {
      gPendingSide = -1;
      gPendingBar = iTime(_Symbol, InpTimeframe, 0);
      gState = BSTATE_PENDING_BREAK;
      Print("🔻 Breakout DOWN detected | Close=", close, " < BoxLow=", gBoxLow);
   }
}

//+------------------------------------------------------------------+
//| Confirm breakout with next candle                                |
//+------------------------------------------------------------------+
void ConfirmBreakout() {
   datetime curBar = iTime(_Symbol, InpTimeframe, 0);
   if(curBar == gPendingBar) return; // Wait for next candle
   
   double close = iClose(_Symbol, InpTimeframe, 0);
   
   // Validate break direction still holds
   if(gPendingSide > 0 && close > gBoxHigh) {
      ExecuteBuy();
   } else if(gPendingSide < 0 && close < gBoxLow) {
      ExecuteSell();
   } else {
      // False breakout - back to ready
      gState = BSTATE_READY;
      Print("❌ Breakout not confirmed. Back to watching.");
   }
   
   gPendingBar = 0;
}

//+------------------------------------------------------------------+
//| Execute BUY order                                                |
//+------------------------------------------------------------------+
void ExecuteBuy() {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Spread check
   double spreadPips = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / GPip;
   if(spreadPips > InpMaxSpread) {
      Print("⚠️ Spread too high: ", spreadPips, " pips. Skip.");
      gState = BSTATE_READY;
      return;
   }
   
   double tpPrice = ask + gTPPips * GPip;
   
   // Lot sizing based on equity risk
   double riskAmt = InpRiskPerLot * (gCurrentLot / 0.1);
   double slPips = 0; // No SL for this strategy
   
   bool ok = gTrade.Buy(gCurrentLot, _Symbol, ask, 0, tpPrice, 
                        "GBPUSD_BreakoutBox | Switch=" + IntegerToString(gSwitchCount));
   
   if(ok) {
      gEntryPrice = ask;
      gState = BSTATE_ACTIVE_LONG;
      Print("🟢 BUY opened | Lot=", gCurrentLot, " | Entry=", ask, 
            " | TP=", tpPrice, " | Switch#", gSwitchCount);
   } else {
      Print("❌ BUY failed: ", GetLastError());
      gState = BSTATE_READY;
   }
}

//+------------------------------------------------------------------+
//| Execute SELL order                                               |
//+------------------------------------------------------------------+
void ExecuteSell() {
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double spreadPips = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / GPip;
   if(spreadPips > InpMaxSpread) {
      Print("⚠️ Spread too high: ", spreadPips, " pips. Skip.");
      gState = BSTATE_READY;
      return;
   }
   
   double tpPrice = bid - gTPPips * GPip;
   
   bool ok = gTrade.Sell(gCurrentLot, _Symbol, bid, 0, tpPrice, 
                         "GBPUSD_BreakoutBox | Switch=" + IntegerToString(gSwitchCount));
   
   if(ok) {
      gEntryPrice = bid;
      gState = BSTATE_ACTIVE_SHORT;
      Print("🔴 SELL opened | Lot=", gCurrentLot, " | Entry=", bid,
            " | TP=", tpPrice, " | Switch#", gSwitchCount);
   } else {
      Print("❌ SELL failed: ", GetLastError());
      gState = BSTATE_READY;
   }
}

//+------------------------------------------------------------------+
//| Monitor active position                                          |
//+------------------------------------------------------------------+
void MonitorActivePosition() {
   if(!PositionSelect(_Symbol)) {
      // Position closed manually or by TP
      gState = BSTATE_COMPLETE;
      Print("🏁 Position complete. Waiting for next session.");
      return;
   }
   
   double posPrice    = PositionGetDouble(POSITION_PRICE_OPEN);
   double posCurrent  = PositionGetDouble(POSITION_PRICE_CURRENT);
   double posProfit   = PositionGetDouble(POSITION_PROFIT);
   long   posType     = PositionGetInteger(POSITION_TYPE);
   
   double tpDistPips = (posType == POSITION_TYPE_BUY)
      ? (posCurrent - posPrice) / GPip
      : (posPrice - posCurrent) / GPip;
   
   // TP hit
   if(tpDistPips >= gTPPips) {
      gTrade.PositionClose(_Symbol);
      Print("🎯 TP hit! Profit=", posProfit);
      gState = BSTATE_COMPLETE;
      return;
   }
   
   // Switch logic: check for reverse break
   bool doSwitch = false;
   
   if(InpEnableSwitch && tpDistPips < 0) {
      // In loss / opposite direction
      if(posType == POSITION_TYPE_BUY && posCurrent < gBoxLow) {
         doSwitch = true;
         Print("🔄 Switch triggered: BUY -> SELL (price broke box low)");
      } else if(posType == POSITION_TYPE_SELL && posCurrent > gBoxHigh) {
         doSwitch = true;
         Print("🔄 Switch triggered: SELL -> BUY (price broke box high)");
      }
   }
   
   if(doSwitch) {
      // Check switch limit
      if(InpMaxSwitch > 0 && gSwitchCount >= InpMaxSwitch) {
         gTrade.PositionClose(_Symbol);
         Print("🛑 Max switch reached. Position closed.");
         gState = BSTATE_COMPLETE;
         return;
      }
      
      // Close current
      gTrade.PositionClose(_Symbol);
      
      // Double lot & switch
      gCurrentLot *= 2;
      gSwitchCount++;
      
      // Re-enter opposite direction
      if(posType == POSITION_TYPE_BUY) {
         gPendingSide = -1;
         gState = BSTATE_READY;
         Print("🔁 Switch #", gSwitchCount, " | New lot=", gCurrentLot);
         // DetectBreakout will handle the sell entry
         DetectBreakout();
      } else {
         gPendingSide = 1;
         gState = BSTATE_READY;
         DetectBreakout();
      }
   }
}

//+------------------------------------------------------------------+
//| Draw Box on chart (for visual reference)                        |
//+------------------------------------------------------------------+
void DrawBox(double high, double low) {
   string name = "GBox_";
   datetime start = iTime(_Symbol, PERIOD_CURRENT, InpCandleCount);
   datetime end   = iTime(_Symbol, PERIOD_CURRENT, 0) + 60*60*24; // Until end of day
   
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, start, high, end, low);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   
   // Label
   string lbl = "Lbl_";
   ObjectCreate(0, lbl, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, lbl, OBJPROP_TEXT, "GBPUSD Box | " + 
                   DoubleToString((high-low)/GPip, 0) + " pips");
   ObjectSetInteger(0, lbl, OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 10);
}

//+------------------------------------------------------------------+
//| Reset box for new day                                            |
//+------------------------------------------------------------------+
void OnTimer() {
   // Reset daily
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour == 0 && dt.min == 0) {
      ResetBox();
   }
}

//+------------------------------------------------------------------+
//| Force reset (call from OnInit or manually)                       |
//+------------------------------------------------------------------+
void ResetBox() {
   gBoxBuilt = false;
   gBoxHigh  = 0;
   gBoxLow   = 0;
   gState    = BSTATE_IDLE;
   gSwitchCount = 0;
   gCurrentLot = InpBaseLot;
   
   ObjectDelete(0, "GBox_");
   ObjectDelete(0, "Lbl_");
   
   Print("🔄 Box reset for new session");
}

//+------------------------------------------------------------------+
//| Global tick (backup for OnTimer reset)                           |
//+------------------------------------------------------------------+
long OnTimerEvent() {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour == 0 && dt.min <= 5) {
      ResetBox();
   }
   return 0;
}

//+------------------------------------------------------------------+
//| ChartEvent - manual reset trigger                                |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
   if(id == CHARTEVENT_KEYBOARD) {
      if(lparam == KEY_DELETE) ResetBox();
   }
}
//+------------------------------------------------------------------+