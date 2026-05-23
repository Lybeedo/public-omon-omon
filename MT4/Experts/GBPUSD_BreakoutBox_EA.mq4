//+------------------------------------------------------------------+
//|           GBPUSD_BreakoutBox_EA.mq4                              |
//|  Based on Deni Dollar Technique (Bandung)                        |
//|  GBPUSD Only | Break 4-Candle HL Box | TP30 | No SL | Switch     |
//+------------------------------------------------------------------+
#property copyright "7NAGA / omon-omon"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Digit & Pip Auto-Detect                                          |
//+------------------------------------------------------------------+
int    GDigits;
double GPoint;
double GPip;

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== SESSION ==="
int    InpTradingDay     = 1;        // Day (1=Mon ... 5=Fri, 0=all)
int    InpStartHour      = 7;        // Box start hour (broker time)
int    InpCandleCount    = 4;        // Number of candles for HL box

input group "=== TRADE ==="
double InpBaseLot        = 0.1;     // Base lot size
double InpTPPips         = 30.0;    // TP in pips
int    InpMaxSpread      = 30;      // Max spread (pips)
double InpMaxSwitch      = 3;       // Max switch count (0=unlimited)
int    InpMagicNumber    = 77777;    // Magic number
int    InpMaxTrades      = 1;       // Max open positions

input group "=== RISK ==="
double InpMaxEquityRisk  = 50.0;    // Max equity drawdown % (0=disabled)
double InpRiskPerLot     = 50.0;    // USD per 0.1 lot risk
bool   InpEnableSwitch   = true;    // Enable switch/double lot on reverse

input group "=== FILTER ==="
int    InpFilterCandles   = 0;       // Filter candles (0=disabled)
bool   InpAllowSameDir    = false;  // Allow same direction after TP

//+------------------------------------------------------------------+
//| State Machine                                                    |
//+------------------------------------------------------------------+
enum EBSTATE {
   BSTATE_IDLE,
   BSTATE_BUILD_BOX,
   BSTATE_READY,
   BSTATE_PENDING_BREAK,
   BSTATE_ACTIVE_LONG,
   BSTATE_ACTIVE_SHORT,
   BSTATE_COMPLETE
};

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
EBSTATE  gState        = BSTATE_IDLE;
datetime gBoxStartTime = 0;
datetime gLastBarTime  = 0;
double   gBoxHigh      = 0;
double   gBoxLow       = 0;
double   gEntryPrice   = 0;
double   gTPPips        = 0;
double   gBaseLot       = 0;
double   gCurrentLot    = 0;
int      gSwitchCount   = 0;
bool     gBoxBuilt      = false;
datetime gPendingBar    = 0;
double   gPendingSide   = 0;
datetime gSessionDate   = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int init() {
   if(Symbol() != "GBPUSD" && Symbol() != "GBPUSDm") {
      Alert("⚠️ This EA is for GBPUSD only!");
      return;
   }
   
   GDigits = Digits;
   GPoint  = Point;
   GPip    = (GDigits == 3 || GDigits == 5) ? GPoint * 10 : GPoint;
   
   gTPPips     = InpTPPips;
   gBaseLot    = InpBaseLot;
   gCurrentLot = InpBaseLot;
   
   Print("✅ GBPUSD_BreakoutBox EA (MT4) loaded | TP=", InpTPPips, " pips");
   return 0;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
int deinit() {
   DeleteBoxObjects();
   Print("EA removed.");
   return 0;
}

//+------------------------------------------------------------------+
//| Main Tick Handler                                                |
//+------------------------------------------------------------------+
void OnTick() {
   // Equity guard
   if(InpMaxEquityRisk > 0) {
      double equity  = AccountEquity();
      double balance = AccountBalance();
      if(equity < balance * (1 - InpMaxEquityRisk / 100.0)) {
         CloseAllPositions();
         gState = BSTATE_IDLE;
         Print("⚠️ Equity protection triggered.");
         return;
      }
   }
   
   datetime curBar = iTime(Symbol(), PERIOD_CURRENT, 0);
   if(curBar == gLastBarTime) return;
   gLastBarTime = curBar;
   
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
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   
   // Day check: 0=all days, 1=Mon...5=Fri
   if(InpTradingDay != 0 && dt.day_of_week != InpTradingDay) return;
   
   if(dt.hour >= InpStartHour && !gBoxBuilt) {
      gBoxStartTime = iTime(Symbol(), PERIOD_CURRENT, 0);
      gSessionDate  = StrToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
      gSwitchCount  = 0;
      gCurrentLot   = InpBaseLot;
      gState = BSTATE_BUILD_BOX;
      Print("📦 Box build started at hour ", InpStartHour);
   }
}

//+------------------------------------------------------------------+
//| Build HL Box from first N candles                                |
//+------------------------------------------------------------------+
void BuildBox() {
   if(gBoxBuilt) return;
   
   // Wait for enough candles
   if(iTime(Symbol(), PERIOD_CURRENT, InpCandleCount) == 0) return;
   
   double highestHigh = -99999;
   double lowestLow   = 99999;
   
   for(int i = 0; i < InpCandleCount; i++) {
      double h = iHigh(Symbol(), PERIOD_CURRENT, i);
      double l = iLow(Symbol(), PERIOD_CURRENT, i);
      if(h > highestHigh) highestHigh = h;
      if(l < lowestLow)   lowestLow   = l;
   }
   
   gBoxHigh = highestHigh;
   gBoxLow  = lowestLow;
   gBoxBuilt = true;
   gState = BSTATE_READY;
   
   DrawBox(gBoxHigh, gBoxLow);
   
   double rangePips = (gBoxHigh - gBoxLow) / GPip;
   Print("📊 Box built | High=", DoubleToStr(gBoxHigh, GDigits),
         " | Low=", DoubleToStr(gBoxLow, GDigits),
         " | Range=", DoubleToStr(rangePips, 1), " pips");
}

//+------------------------------------------------------------------+
//| Detect breakout from box                                          |
//+------------------------------------------------------------------+
void DetectBreakout() {
   double close = iClose(Symbol(), PERIOD_CURRENT, 0);
   double high  = iHigh(Symbol(), PERIOD_CURRENT, 0);
   double low   = iLow(Symbol(), PERIOD_CURRENT, 0);
   
   // Count open positions for this magic
   int cnt = CountPositions();
   if(cnt >= InpMaxTrades) return;
   
   // Break UP
   if(close > gBoxHigh) {
      gPendingSide = 1;
      gPendingBar  = iTime(Symbol(), PERIOD_CURRENT, 0);
      gState = BSTATE_PENDING_BREAK;
      Print("🔺 Breakout UP | Close=", DoubleToStr(close, GDigits));
   }
   // Break DOWN
   else if(close < gBoxLow) {
      gPendingSide = -1;
      gPendingBar  = iTime(Symbol(), PERIOD_CURRENT, 0);
      gState = BSTATE_PENDING_BREAK;
      Print("🔻 Breakout DOWN | Close=", DoubleToStr(close, GDigits));
   }
}

//+------------------------------------------------------------------+
//| Confirm breakout with next candle                                |
//+------------------------------------------------------------------+
void ConfirmBreakout() {
   datetime curBar = iTime(Symbol(), PERIOD_CURRENT, 0);
   if(curBar == gPendingBar) return; // Wait for next candle
   
   double close = iClose(Symbol(), PERIOD_CURRENT, 0);
   
   bool valid = (gPendingSide > 0 && close > gBoxHigh) ||
                (gPendingSide < 0 && close < gBoxLow);
   
   if(valid) {
      if(gPendingSide > 0) ExecuteBuy();
      else                  ExecuteSell();
   } else {
      gState = BSTATE_READY;
      Print("❌ Breakout not confirmed.");
   }
   
   gPendingBar = 0;
}

//+------------------------------------------------------------------+
//| Execute BUY order                                                |
//+------------------------------------------------------------------+
void ExecuteBuy() {
   double ask = Ask;
   double spreadPips = (Ask - Bid) / GPip;
   
   if(spreadPips > InpMaxSpread) {
      Print("⚠️ Spread too high: ", DoubleToStr(spreadPips, 1), " pips");
      gState = BSTATE_READY;
      return;
   }
   
   double tpPrice = ask + gTPPips * GPip;
   double lot = gCurrentLot;
   
   int ticket = OrderSend(Symbol(), OP_BUY, lot, ask, 3, 0, tpPrice,
                          "GBPUSD_Box | Switch=" + DoubleToStr(gSwitchCount, 0),
                          InpMagicNumber, 0, clrGreen);
   
   if(ticket > 0) {
      gEntryPrice = ask;
      gState = BSTATE_ACTIVE_LONG;
      Print("🟢 BUY opened | Lot=", DoubleToStr(lot, 2),
            " | Entry=", DoubleToStr(ask, GDigits),
            " | TP=", DoubleToStr(tpPrice, GDigits));
   } else {
      Print("❌ BUY failed: ", GetLastError());
      gState = BSTATE_READY;
   }
}

//+------------------------------------------------------------------+
//| Execute SELL order                                               |
//+------------------------------------------------------------------+
void ExecuteSell() {
   double bid = Bid;
   double spreadPips = (Ask - Bid) / GPip;
   
   if(spreadPips > InpMaxSpread) {
      Print("⚠️ Spread too high: ", DoubleToStr(spreadPips, 1), " pips");
      gState = BSTATE_READY;
      return;
   }
   
   double tpPrice = bid - gTPPips * GPip;
   double lot = gCurrentLot;
   
   int ticket = OrderSend(Symbol(), OP_SELL, lot, bid, 3, 0, tpPrice,
                          "GBPUSD_Box | Switch=" + DoubleToStr(gSwitchCount, 0),
                          InpMagicNumber, 0, clrRed);
   
   if(ticket > 0) {
      gEntryPrice = bid;
      gState = BSTATE_ACTIVE_SHORT;
      Print("🔴 SELL opened | Lot=", DoubleToStr(lot, 2),
            " | Entry=", DoubleToStr(bid, GDigits),
            " | TP=", DoubleToStr(tpPrice, GDigits));
   } else {
      Print("❌ SELL failed: ", GetLastError());
      gState = BSTATE_READY;
   }
}

//+------------------------------------------------------------------+
//| Monitor active position                                          |
//+------------------------------------------------------------------+
void MonitorActivePosition() {
   // Find position
   int cnt = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber) continue;
      cnt++;
      
      double posPrice   = OrderOpenPrice();
      double posCurrent = (OrderType() == OP_BUY) ? Bid : Ask;
      double posProfit  = OrderProfit();
      int    posType    = OrderType();
      
      double tpDistPips = (posType == OP_BUY)
          ? (posCurrent - posPrice) / GPip
          : (posPrice - posCurrent) / GPip;
      
      // TP hit
      if(tpDistPips >= gTPPips) {
         OrderClose(OrderTicket(), OrderLots(), 
                    (posType == OP_BUY) ? Bid : Ask, 3, clrNONE);
         Print("🎯 TP hit! Profit=", DoubleToStr(posProfit, 2));
         gState = BSTATE_COMPLETE;
         return;
      }
      
      // Switch logic
      if(InpEnableSwitch && tpDistPips < 0) {
         bool doSwitch = (posType == OP_BUY && Bid < gBoxLow) ||
                         (posType == OP_SELL && Ask > gBoxHigh);
         
         if(doSwitch) {
            if(InpMaxSwitch > 0 && gSwitchCount >= InpMaxSwitch) {
               OrderClose(OrderTicket(), OrderLots(),
                          (posType == OP_BUY) ? Bid : Ask, 3, clrNONE);
               Print("🛑 Max switch reached.");
               gState = BSTATE_COMPLETE;
               return;
            }
            
            OrderClose(OrderTicket(), OrderLots(),
                       (posType == OP_BUY) ? Bid : Ask, 3, clrNONE);
            
            gCurrentLot *= 2;
            gSwitchCount++;
            gState = BSTATE_READY;
            
            Print("🔁 Switch #", DoubleToStr(gSwitchCount, 0),
                  " | New lot=", DoubleToStr(gCurrentLot, 2));
            DetectBreakout();
            return;
         }
      }
   }
   
   // Position gone (manual close)
   if(cnt == 0) {
      gState = BSTATE_COMPLETE;
      Print("🏁 Position complete.");
   }
}

//+------------------------------------------------------------------+
//| Count open positions for this magic                              |
//+------------------------------------------------------------------+
int CountPositions() {
   int cnt = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber) continue;
      cnt++;
   }
   return cnt;
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions() {
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber) continue;
      int type = OrderType();
      double price = (type == OP_BUY) ? Bid : Ask;
      OrderClose(OrderTicket(), OrderLots(), price, 3, clrNONE);
   }
}

//+------------------------------------------------------------------+
//| Draw Box on chart                                                 |
//+------------------------------------------------------------------+
void DrawBox(double high, double low) {
   DeleteBoxObjects();
   
   datetime start = iTime(Symbol(), PERIOD_CURRENT, InpCandleCount);
   datetime end   = iTime(Symbol(), PERIOD_CURRENT, 0) + 86400; // EOD
   
   string boxName = "GBox";
   ObjectCreate(boxName, OBJ_RECTANGLE, 0, start, high, end, low);
   ObjectSetInteger(boxName, OBJPROP_COLOR, clrLime);
   ObjectSetInteger(boxName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(boxName, OBJPROP_FILL, 1);
   ObjectSetInteger(boxName, OBJPROP_BACK, 0);
   
   string lblName = "GBoxLbl";
   ObjectCreate(lblName, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(lblName, OBJPROP_TEXT, 
                   "GBPUSD Box | Range: " + 
                   DoubleToStr((high-low)/GPip, 0) + " pips");
   ObjectSetInteger(lblName, OBJPROP_COLOR, clrLime);
   ObjectSetInteger(lblName, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(lblName, OBJPROP_CORNER, 0);
   ObjectSetInteger(lblName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(lblName, OBJPROP_YDISTANCE, 10);
}

//+------------------------------------------------------------------+
//| Delete box objects                                                |
//+------------------------------------------------------------------+
void DeleteBoxObjects() {
   ObjectDelete("GBox");
   ObjectDelete("GBoxLbl");
}

//+------------------------------------------------------------------+
//| Reset box for new session                                        |
//+------------------------------------------------------------------+
void ResetBox() {
   gBoxBuilt   = false;
   gBoxHigh    = 0;
   gBoxLow     = 0;
   gState      = BSTATE_IDLE;
   gSwitchCount = 0;
   gCurrentLot  = InpBaseLot;
   DeleteBoxObjects();
   Print("🔄 Box reset");
}

//+------------------------------------------------------------------+
//| OnTimer - daily reset                                            |
//+------------------------------------------------------------------+
int OnTimerEvent() {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour == 0 && dt.min <= 5) ResetBox();
   return 0;
}

//+------------------------------------------------------------------+
//| ChartEvent - manual reset                                        |
//+------------------------------------------------------------------+
void OnChartEvent(int id, long lparam, double dparam, string sparam) {
   if(id == CHARTEVENT_KEYBOARD) {
      if(lparam == KEY_DELETE) ResetBox();
   }
}
//+------------------------------------------------------------------+