//+------------------------------------------------------------------+
//|                        SevenCandleNaga.mq4                       |
//|                           7NAGA Trading System                     |
//|                              Version 1.0.0                        |
//+------------------------------------------------------------------+
#property copyright "7NAGA Trading System"
#property link      "https://7naga.dev"
#property version   "1.0.0"
#property strict

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== TIME SETTINGS (WIB) ==="
input int    InpAnalysisHour   = 9;
input int    InpAnalysisMin   = 30;
input int    InpExpiryHour    = 17;
input int    InpExpiryMin     = 0;
input int    InpTimeOffset    = 7;

input group "=== ORDER SETTINGS ==="
input double InpLotSize       = 0.01;
input int    InpBuyOffsetPts  = 100;
input int    InpSellOffsetPts = 25;
input int    InpMagicNumber   = 77777;
input int    InpDeviation     = 5;

input group "=== TP ZONES ==="
input double InpTP1Pips        = 10.0;
input double InpTP2Pips        = 15.0;
input double InpTP3Pips        = 30.0;
input double InpTP4Pips        = 50.0;
input double InpTP5Pips        = 100.0;
input double InpTP6Pips        = 200.0;

input group "=== DISTANCE FILTER ==="
input int    InpMinDistance   = 70;
input int    InpMaxDistance   = 200;

input group "=== SL MODE ==="
input bool   InpSLModeOneshot = true;

input group "=== FORBIDDEN DATES (YYYY.MM.DD) ==="
input string InpForbiddenDates = "";

input group "=== NEWS FILTER ==="
input bool   InpSkipNFP        = true;
input bool   InpSkipFOMC       = true;
input bool   InpSkipCPI        = true;
input bool   InpSkipMonday     = true;
input bool   InpSkipUSHoliday  = true;

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
datetime g_lastTradeDate   = 0;
datetime g_lastAnalysisMin = 0;

#define STATE_IDLE       0
#define STATE_ANALYZING  1
#define STATE_PLACING    2
#define STATE_ACTIVE     3
#define STATE_COMPLETED  4
#define STATE_SKIPPED    5
int g_eState = STATE_IDLE;

double g_buyStopPrice  = 0;
double g_sellStopPrice = 0;
double g_slBuyStop     = 0;
double g_slSellStop    = 0;
double g_spreadPips    = 0;
double g_tpIdealPips   = 0;
double g_tpIdealZone   = 0;
double g_high          = 0;
double g_low           = 0;
datetime g_expiryTime  = 0;
bool    g_zoneHit[6];

//+------------------------------------------------------------------+
//| EXPERT INITIALIZATION                                            |
//+------------------------------------------------------------------+
int OnInit() {
   Print("=== 7NAGA EA Initialized (MQL4) ===");
   Print("Magic: ", InpMagicNumber);
   Print("Buy Offset: +", InpBuyOffsetPts, " pts | Sell Offset: -", InpSellOffsetPts, " pts");
   ArrayInitialize(g_zoneHit, false);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| EXPERT DEINIT                                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   DeleteAllPending();
   Print("=== 7NAGA EA Deinitialized ===");
}

//+------------------------------------------------------------------+
//| EXPERT TICK                                                      |
//+------------------------------------------------------------------+
void OnTick() {
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);

   int wibHour = dt.hour - InpTimeOffset;
   if(wibHour < 0) wibHour += 24;

   // Check expiry
   if(g_eState == STATE_ACTIVE && now >= g_expiryTime && g_expiryTime > 0) {
      ExpireAllPositions();
      return;
   }

   // Check triggered orders
   if(g_eState == STATE_ACTIVE) {
      CheckTriggeredOrders();
   }

   // Analysis window: 09:30 WIB
   int currentMin = dt.hour * 60 + dt.min;
   int targetMin  = InpAnalysisHour * 60 + InpAnalysisMin;

   if(currentMin == targetMin && g_lastAnalysisMin != currentMin) {
      g_lastAnalysisMin = currentMin;
      if(g_eState == STATE_IDLE || g_eState == STATE_COMPLETED || g_eState == STATE_SKIPPED) {
         RunAnalysis();
      }
   }
}

//+------------------------------------------------------------------+
//| ANALYSIS ROUTINE                                                 |
//+------------------------------------------------------------------+
void RunAnalysis() {
   Print("=== 7NAGA ANALYSIS STARTED ===");
   g_eState = STATE_ANALYZING;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int dayOfWeek = (dt.day_of_week + 6) % 7 + 1;

   if(InpSkipMonday && dayOfWeek == 1) {
      Print("❌ SKIPPED: Monday");
      g_eState = STATE_SKIPPED;
      return;
   }

   if(IsForbiddenDate()) {
      Print("❌ SKIPPED: Forbidden Date");
      g_eState = STATE_SKIPPED;
      return;
   }

   if(InpSkipUSHoliday && IsUSHoliday()) {
      Print("❌ SKIPPED: US Holiday");
      g_eState = STATE_SKIPPED;
      return;
   }

   if((InpSkipNFP || InpSkipFOMC || InpSkipCPI) && IsHighImpactNewsDay()) {
      Print("❌ SKIPPED: High Impact News Day");
      g_eState = STATE_SKIPPED;
      return;
   }

   datetime todayDate = StrToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day) + " 00:00:00");
   if(g_lastTradeDate == todayDate) {
      Print("⏳ Already traded today");
      g_eState = STATE_COMPLETED;
      return;
   }

   double high, low;
   if(!Get7CandleLevels(high, low)) {
      Print("❌ Failed to get 7 candle data");
      g_eState = STATE_IDLE;
      return;
   }

   double roundedHigh = RoundToMultiple5_Up(high);
   double roundedLow  = RoundToMultiple5_Down(low);

   double point  = Point;
   double buyStop  = NormalizeDouble(roundedHigh + InpBuyOffsetPts * point, Digits);
   double sellStop = NormalizeDouble(roundedLow  - InpSellOffsetPts * point, Digits);

   double pipsFactor = (Digits == 5 || Digits == 3) ? 10.0 : 1.0;
   double spreadPips = (buyStop - sellStop) / point / pipsFactor;

   Print("High: ", DoubleToStr(high, Digits), " → Rounded UP: ", DoubleToStr(roundedHigh, Digits));
   Print("Low:  ", DoubleToStr(low,  Digits), " → Rounded DOWN: ", DoubleToStr(roundedLow, Digits));
   Print("Buy Stop:  ", DoubleToStr(buyStop,  Digits), " (+", InpBuyOffsetPts, " pts)");
   Print("Sell Stop: ", DoubleToStr(sellStop, Digits), " (-", InpSellOffsetPts, " pts)");
   Print("Spread: ", DoubleToStr(spreadPips, 1), " pips");

   if(spreadPips < InpMinDistance || spreadPips > InpMaxDistance) {
      Print("❌ SKIPPED: Distance ", DoubleToStr(spreadPips, 1), " pips outside [", IntegerToString(InpMinDistance), "-", IntegerToString(InpMaxDistance), "]");
      g_eState = STATE_SKIPPED;
      return;
   }

   double tpIdealPips = spreadPips / 2.0;
   double tpIdealZone = GetNearestTPZone(tpIdealPips);

   Print("TP Ideal: ", DoubleToStr(tpIdealPips, 1), " pips → Zone ", IntegerToString((int)tpIdealZone), " (", DoubleToStr(GetZonePips(tpIdealZone), 0), " pips)");

   g_high          = high;
   g_low           = low;
   g_buyStopPrice  = buyStop;
   g_sellStopPrice = sellStop;
   g_slSellStop    = buyStop;
   g_slBuyStop     = sellStop;
   g_spreadPips    = spreadPips;
   g_tpIdealPips   = tpIdealPips;
   g_tpIdealZone   = tpIdealZone;
   ArrayInitialize(g_zoneHit, false);

   MqlDateTime exp;
   TimeToStruct(TimeCurrent(), exp);
   exp.hour = InpExpiryHour;
   exp.min  = InpExpiryMin;
   exp.sec  = 0;
   g_expiryTime = StructToTime(exp);

   g_eState = STATE_PLACING;
   PlacePendingOrders();
   g_lastTradeDate = todayDate;
}

//+------------------------------------------------------------------+
//| GET 7 CANDLE LEVELS                                              |
//+------------------------------------------------------------------+
bool Get7CandleLevels(double &high, double &low) {
   high = 0;
   low  = 999999;
   for(int i = 1; i <= 7; i++) {
      double h = iHigh(NULL, 0, i);
      double l = iLow(NULL, 0, i);
      if(h > high) high = h;
      if(l < low)  low  = l;
   }
   if(high <= 0 || low >= 999999 || high <= low) return false;
   Print("7 Candle Range: High=", DoubleToStr(high,Digits), " Low=", DoubleToStr(low,Digits));
   return true;
}

//+------------------------------------------------------------------+
//| ROUND UP TO MULTIPLE OF 5 (HIGH / Buy Stop)                      |
//+------------------------------------------------------------------+
double RoundToMultiple5_Up(double price) {
   double scaled = price * 100.0;
   double last2  = MathMod(scaled, 100.0);
   if(last2 <= 5.0) {
      scaled = MathFloor(scaled / 100.0) * 100.0 + 5.0;
   } else {
      scaled = MathFloor(scaled / 100.0) * 100.0 + 10.0;
   }
   return scaled / 100.0;
}

//+------------------------------------------------------------------+
//| ROUND DOWN TO MULTIPLE OF 5 (LOW / Sell Stop)                    |
//+------------------------------------------------------------------+
double RoundToMultiple5_Down(double price) {
   double scaled = price * 100.0;
   double last2  = MathMod(scaled, 100.0);
   if(last2 < 5.0) {
      scaled = MathFloor(scaled / 100.0) * 100.0;
   } else {
      scaled = MathFloor(scaled / 100.0) * 100.0 + 5.0;
   }
   return scaled / 100.0;
}

//+------------------------------------------------------------------+
//| PLACE PENDING ORDERS                                             |
//+------------------------------------------------------------------+
void PlacePendingOrders() {
   DeleteAllPending();

   double ask = Ask;
   double bid = Bid;
   double point = Point;

   if(g_buyStopPrice <= ask) {
      Print("⚠️ Buy Stop adjusting above ask");
      g_buyStopPrice = NormalizeDouble(ask + InpBuyOffsetPts * point, Digits);
   }
   if(g_sellStopPrice >= bid) {
      Print("⚠️ Sell Stop adjusting below bid");
      g_sellStopPrice = NormalizeDouble(bid - InpSellOffsetPts * point, Digits);
   }

   double slBuy  = NormalizeDouble(g_sellStopPrice, Digits);
   double slSell = NormalizeDouble(g_buyStopPrice, Digits);

   int ticketBuy = OrderSend(Symbol(), OP_BUYSTOP, InpLotSize, g_buyStopPrice, InpDeviation, slBuy, 0, "7NAGA BuyStop", InpMagicNumber, g_expiryTime, clrNONE);
   if(ticketBuy > 0) {
      Print("✅ BUY STOP at ", DoubleToStr(g_buyStopPrice, Digits), " | SL=", DoubleToStr(slBuy, Digits), " | Spread=", DoubleToStr(g_spreadPips, 1), " pips");
   } else {
      Print("❌ BUY STOP failed: ", ErrorDescription(GetLastError()));
   }

   int ticketSell = OrderSend(Symbol(), OP_SELLSTOP, InpLotSize, g_sellStopPrice, InpDeviation, slSell, 0, "7NAGA SellStop", InpMagicNumber, g_expiryTime, clrNONE);
   if(ticketSell > 0) {
      Print("✅ SELL STOP at ", DoubleToStr(g_sellStopPrice, Digits), " | SL=", DoubleToStr(slSell, Digits), " | Spread=", DoubleToStr(g_spreadPips, 1), " pips");
   } else {
      Print("❌ SELL STOP failed: ", ErrorDescription(GetLastError()));
   }

   g_eState = STATE_ACTIVE;
   Print("=== 7NAGA ORDERS PLACED ===");
   Print("Expiry: ", TimeToStr(g_expiryTime, TIME_DATE|TIME_MINUTES));
   Print("TP Ideal: Zone ", IntegerToString((int)g_tpIdealZone), " (", DoubleToStr(GetZonePips(g_tpIdealZone), 0), " pips)");
}

//+------------------------------------------------------------------+
//| CHECK TRIGGERED ORDERS                                           |
//+------------------------------------------------------------------+
void CheckTriggeredOrders() {
   double totalBuyLots  = 0;
   double totalSellLots = 0;

   // Check pending expiry
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() == OP_BUYSTOP || OrderType() == OP_SELLSTOP) {
         if(OrderExpiration() > 0 && TimeCurrent() >= OrderExpiration()) {
            OrderDelete(OrderTicket());
         }
      }
   }

   // Scan positions
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(!PositionSelect(Symbol())) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
         totalBuyLots += PositionGetDouble(POSITION_VOLUME);
      } else {
         totalSellLots += PositionGetDouble(POSITION_VOLUME);
      }
   }

   // Switching mode
   if(InpSLModeOneshot) {
      CancelOppositePending(totalBuyLots > 0, totalSellLots > 0);
   }

   // TP zone check
   double tpZones[] = {InpTP1Pips, InpTP2Pips, InpTP3Pips, InpTP4Pips, InpTP5Pips, InpTP6Pips};
   double pipsFactor = (Digits == 5 || Digits == 3) ? 10.0 : 1.0;

   for(int z = 0; z < 6; z++) {
      if(g_zoneHit[z]) continue;
      double zonePips = tpZones[z];

      if(totalBuyLots > 0) {
         double entryPrice = GetPositionEntryPrice(POSITION_TYPE_BUY);
         if(entryPrice > 0) {
            double profit = (Bid - entryPrice) / Point / pipsFactor;
            if(profit >= zonePips) {
               double closeLot = MathMin(InpLotSize, totalBuyLots);
               ClosePartial(POSITION_TYPE_BUY, closeLot);
               g_zoneHit[z] = true;
               Print("🎯 TP", IntegerToString(z+1), " HIT (+", DoubleToStr(zonePips,0), " pips) | Closed ", DoubleToStr(closeLot,2), " lots");
            }
         }
      }

      if(totalSellLots > 0) {
         double entryPrice = GetPositionEntryPrice(POSITION_TYPE_SELL);
         if(entryPrice > 0) {
            double profit = (entryPrice - Ask) / Point / pipsFactor;
            if(profit >= zonePips) {
               double closeLot = MathMin(InpLotSize, totalSellLots);
               ClosePartial(POSITION_TYPE_SELL, closeLot);
               g_zoneHit[z] = true;
               Print("🎯 TP", IntegerToString(z+1), " HIT (+", DoubleToStr(zonePips,0), " pips) | Closed ", DoubleToStr(closeLot,2), " lots");
            }
         }
      }
   }

   // Check if all done
   if(totalBuyLots <= 0 && totalSellLots <= 0 && g_lastTradeDate > 0) {
      bool anyPending = false;
      for(int i = OrdersTotal() - 1; i >= 0; i--) {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false) continue;
         if(OrderSymbol() != Symbol()) continue;
         if(OrderMagicNumber() != InpMagicNumber) continue;
         int t = OrderType();
         if(t == OP_BUYSTOP || t == OP_SELLSTOP) { anyPending = true; break; }
      }
      if(!anyPending) {
         Print("=== 7NAGA DAY COMPLETED ===");
         g_eState = STATE_COMPLETED;
      }
   }
}

//+------------------------------------------------------------------+
//| GET POSITION ENTRY PRICE                                         |
//+------------------------------------------------------------------+
double GetPositionEntryPrice(int posType) {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if((int)PositionGetInteger(POSITION_TYPE) != posType) continue;
      return PositionGetDouble(POSITION_PRICE_OPEN);
   }
   return 0;
}

//+------------------------------------------------------------------+
//| PARTIAL CLOSE                                                    |
//+------------------------------------------------------------------+
void ClosePartial(int posType, double lot) {
   if(lot <= 0) return;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if((int)PositionGetInteger(POSITION_TYPE) != posType) continue;
      if(!PositionClosePartial(PositionGetInteger(POSITION_TICKET), lot)) {
         Print("❌ Partial close failed: ", ErrorDescription(GetLastError()));
      }
      break;
   }
}

//+------------------------------------------------------------------+
//| CANCEL OPPOSITE PENDING                                          |
//+------------------------------------------------------------------+
void CancelOppositePending(bool buyActive, bool sellActive) {
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      int type = OrderType();
      if(buyActive && type == OP_SELLSTOP) { OrderDelete(OrderTicket()); Print("🛑 Cancelled SELL STOP"); }
      else if(sellActive && type == OP_BUYSTOP) { OrderDelete(OrderTicket()); Print("🛑 Cancelled BUY STOP"); }
   }
}

//+------------------------------------------------------------------+
//| DELETE ALL PENDING                                               |
//+------------------------------------------------------------------+
void DeleteAllPending() {
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      int type = OrderType();
      if(type == OP_BUYSTOP || type == OP_SELLSTOP) OrderDelete(OrderTicket());
   }
}

//+------------------------------------------------------------------+
//| EXPIRE ALL POSITIONS                                             |
//+------------------------------------------------------------------+
void ExpireAllPositions() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      PositionClose(PositionGetInteger(POSITION_TICKET));
   }
   DeleteAllPending();
   Print("⏰ 17:00 WIB — All positions expired");
   g_eState = STATE_COMPLETED;
}

//+------------------------------------------------------------------+
//| GET NEAREST TP ZONE                                              |
//+------------------------------------------------------------------+
double GetNearestTPZone(double pips) {
   double zones[6];
   zones[0] = InpTP1Pips; zones[1] = InpTP2Pips; zones[2] = InpTP3Pips;
   zones[3] = InpTP4Pips; zones[4] = InpTP5Pips; zones[5] = InpTP6Pips;
   double bestZone = 2;
   double minDiff  = MathAbs(pips - InpTP2Pips);
   for(int i = 0; i < 6; i++) {
      double diff = MathAbs(pips - zones[i]);
      if(diff < minDiff) { minDiff = diff; bestZone = i + 1; }
   }
   return bestZone;
}

//+------------------------------------------------------------------+
//| GET ZONE PIPS                                                    |
//+------------------------------------------------------------------+
double GetZonePips(double zone) {
   int idx = (int)zone - 1;
   switch(idx) {
      case 0: return InpTP1Pips; case 1: return InpTP2Pips;
      case 2: return InpTP3Pips; case 3: return InpTP4Pips;
      case 4: return InpTP5Pips; case 5: return InpTP6Pips;
   }
   return InpTP2Pips;
}

//+------------------------------------------------------------------+
//| IS FORBIDDEN DATE                                                |
//+------------------------------------------------------------------+
bool IsForbiddenDate() {
   if(StringLen(InpForbiddenDates) == 0) return false;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   string todayStr = StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day);
   string dates[];
   int count = StringSplit(InpForbiddenDates, ',', dates);
   for(int i = 0; i < count; i++) {
      if(StringTrim(dates[i]) == todayStr) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| IS US HOLIDAY                                                    |
//+------------------------------------------------------------------+
bool IsUSHoliday() {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int m = dt.mon, d = dt.day;
   if(m == 1 && d == 1)  return true;
   if(m == 7 && d == 4)  return true;
   if(m == 12 && d == 25) return true;
   if(m == 11 && d >= 22 && d <= 28 && dt.day_of_week == 4) return true;
   if(m == 5 && d >= 25 && dt.day_of_week == 1) return true;
   if(m == 9 && d <= 7 && dt.day_of_week == 1) return true;
   return false;
}

//+------------------------------------------------------------------+
//| IS HIGH IMPACT NEWS DAY                                          |
//+------------------------------------------------------------------+
bool IsHighImpactNewsDay() {
   return false;
}

//+------------------------------------------------------------------+
//| ERROR DESCRIPTION                                                |
//+------------------------------------------------------------------+
string ErrorDescription(int error) {
   switch(error) {
      case 0:   return "No error";
      case 1:   return "No result";
      case 2:   return "Common error";
      case 3:   return "Invalid trade parameters";
      case 4:   return "Trade server busy";
      case 5:   return "No connection";
      case 6:   return "Too many requests";
      case 64:  return "Account disabled";
      case 65:  return "Invalid account";
      case 66:  return "Trade timeout";
      case 67:  return "Invalid price";
      case 70:  return "Trade disabled";
      case 71:  return "Not enough money";
      case 72:  return "Price changed";
      case 73:  return "Invalid stops";
      case 74:  return "Invalid trade volume";
      case 75:  return "Market closed";
      case 76:  return "No quotes";
      default:  return "Unknown error " + IntegerToString(error);
   }
}
//+------------------------------------------------------------------+