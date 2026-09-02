//+------------------------------------------------------------------+
//|                                             AlternatingEA.mq5    |
//|                                  Advanced Grid w/ Auto-Hedge     |
//+------------------------------------------------------------------+
#property copyright "Trader Nakal"
#property link      ""
#property version   "1.00"
#property strict
#property indicator_chart_window

#include <Trade\Trade.mqh>
#include <Arrays\ArrayObj.mqh>

CTrade         trade;
CArrayObj      posList;

//--- Input Parameters
input group="=== Core Strategy ==="
input double   InpBaseLot       = 0.01;   // Base Lot Size
input int      InpGridStep      = 50;     // Distance between Levels (Points)
input int      InpBasketTP      = 250;    // Basket Recovery TP (Points from Bottom)

input group="=== Hedge System ==="
input int      InpHedgeTrigPts  = 100;    // Loss Threshold to Trigger Hedge (Points)
input int      InpHedgeTpPts    = 100;    // Hedge Take Profit (Points)
input int      InpHedgeGridStp  = 50;     // Distance between Hedge Levels (Points)

//--- Globals
ulong MagicNum = 12345;
bool  HedgeL3Active = false;
bool  HedgeL8Active = false;
int   CurrentLevel = 0;

struct PosInfo {
   ulong      ticket;
   string     type; // "BUY" or "SELL"
   double     volume;
   double     openPrice;
   int        level;
   datetime   createTime;
};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNum);
   trade.SetDeviationInPoints(20);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   Print("Alternating EA Init. Grid Step: ", InpGridStep, " pts");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   RefreshPositions();
   CheckMarketCondition();
}

//+------------------------------------------------------------------+
//| Load positions into array                                        |
//+------------------------------------------------------------------+
void RefreshPositions(void)
{
   posList.DeleteAll();
   
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong t = PositionGetTicket(i);
      if(t==0) continue;
      
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNum) {
         
         PosInfo info;
         info.ticket = t;
         info.type   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL";
         info.volume = PositionGetDouble(POSITION_VOLUME);
         info.openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         info.createTime = (datetime)PositionGetInteger(POSITION_TIME);
         
         // Extract Level from Comment (e.g., "L1" -> 1)
         info.level = StringSubstr(PositionGetString(POSITION_COMMENT), 1); 
         if(StringLen(info.level) == 0) info.level = 0; // Safety
        
         posList.Add(info);
      }
   }
}

//+------------------------------------------------------------------+
//| Main Strategy Logic                                              |
//+------------------------------------------------------------------+
void CheckMarketCondition(void)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Determine Trend Direction based on highest main level present
   int maxLevel = 0;
   string trendType = "";
   double bottomPrice = 0;
   
   for(int i=0; i<posList.Total(); i++) {
      PosInfo* p = posList.At(i);
      if(p != NULL) {
         // Filter for Main Trend (Numbers only, no minus signs)
         if(!StringFind(p->type, "-")) {
            if(StringToInt(p->level) > maxLevel) {
               maxLevel = StringToInt(p->level);
               trendType = p->type;
            }
            // Track lowest point for Buys, Highest for Sells
            double price = (p->type == "BUY") ? p->openPrice : p->openPrice;
            if(bottomPrice == 0 || price < bottomPrice) bottomPrice = price;
         }
      }
   }
   
   // Initialize first level if empty
   if(maxLevel == 0) {
      OpenMainOrder(trendType, 1, ask, bid);
      return;
   }
   
   // Determine Price Action for Next Level
   // For Buy: If Low < BottomPrice - GridStep, open next.
   // For Sell: If High > BottomPrice + GridStep, open next.
   
   if(trendType == "BUY") {
      if(GetLowestBar(1) < bottomPrice - InpGridStep * Point()) {
         OpenNextLevel("BUY", maxLevel + 1, ask, bid);
      }
   } else {
      if(GetHighestBar(1) > bottomPrice + InpGridStep * Point()) {
         OpenNextLevel("SELL", maxLevel + 1, ask, bid);
      }
   }
   
   // Check Win Condition (Basket TP)
   CheckBasketWin(trendType, bottomPrice);
   
   // Check Hedge Triggers
   CheckHedgeTriggers(trendType, bottomPrice);
   
   // Clean Stale Hedges (Manual TP check helper)
   ManageHedgeTargets();
}

//+------------------------------------------------------------------+
//| Place Order                                                      |
//+------------------------------------------------------------------+
void OpenMainOrder(string type, int lvl, double ask, double bid)
{
   double vol = NormalizeDouble(InpBaseLot, 2);
   string comment = IntegerToString(lvl);
   double tp = 0;
   
   if(type == "BUY") {
      // Target 250 points above entry
      tp = ask + InpBasketTP * Point(); 
      trade.Buy(vol, _Symbol, ask, 0, tp, comment);
   } else {
      tp = bid - InpBasketTP * Point();
      trade.Sell(vol, _Symbol, bid, 0, tp, comment);
   }
}

void OpenNextLevel(string type, int lvl, double ask, double bid)
{
   double vol = NormalizeDouble(lvl * InpBaseLot, 2);
   string comment = IntegerToString(lvl);
   double tp = 0;
   
   if(type == "BUY") {
      tp = ask + InpBasketTP * Point();
      trade.Buy(vol, _Symbol, ask, 0, tp, comment);
   } else {
      tp = bid - InpBasketTP * Point();
      trade.Sell(vol, _Symbol, bid, 0, tp, comment);
   }
   PrintFormat("Opened %s Level %d @ %.5f", type, lvl, (type=="BUY"?ask:bid));
}

void OpenHedge(string direction, int id, double price)
{
   double vol = NormalizeDouble(id * InpBaseLot, 2);
   string comment = "-" + IntegerToString(id);
   double tp = 0;
   
   if(direction == "SELL") {
      tp = price - InpHedgeTpPts * Point();
      trade.Sell(vol, _Symbol, price, 0, tp, comment);
   } else {
      tp = price + InpHedgeTpPts * Point();
      trade.Buy(vol, _Symbol, price, 0, tp, comment);
   }
   PrintFormat("Hedge %s %d activated", comment, id);
}

//+------------------------------------------------------------------+
//| Calculate Drawdown                                               |
//+------------------------------------------------------------------+
double GetDrawdown(string type) {
   double totalVol = 0;
   double avgPrice = 0;
   
   for(int i=0; i<posList.Total(); i++) {
      PosInfo* p = posList.At(i);
      if(p != NULL && !StringFind(p->type, "-") && StringCase(p->type) == StringCase(type)) {
         totalVol += p->volume;
         avgPrice += p->openPrice * p->volume;
      }
   }
   
   if(totalVol == 0) return 0;
   avgPrice /= totalVol;
   
   double currentPrc = (type == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double diff = (type == "BUY") ? (avgPrice - currentPrc) : (currentPrc - avgPrice);
   return diff / Point();
}

//+------------------------------------------------------------------+
//| Check Basket Profit (Exit Strategy)                              |
//+------------------------------------------------------------------+
void CheckBasketWin(string type, double bottom) {
   double currentPrice = (type == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double profitDist = (type == "BUY") ? (currentPrice - bottom) : (bottom - currentPrice);
   
   // Simple logic: if price recovered InpBasketTP from the bottom, close ALL
   if(profitDist >= InpBasketTP * Point()) {
      Print("Basket Profit Reached! Resetting...");
      CloseAll();
   }
}

//+------------------------------------------------------------------+
//| Trigger Hedges                                                   |
//+------------------------------------------------------------------+
void CheckHedgeTriggers(string trend, double bottom)
{
   double drawdown = GetDrawdown(trend);
   int mainLevel = GetCurrentMainLevel(trend);
   
   // Level 3 Hedge (-1 to -5)
   if(mainLevel >= 3 && !HedgeL3Active && drawdown > InpHedgeTrigPts) {
      double hedgePrice = (trend == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      for(int i=1; i<=5; i++) {
         // Counter-trend
         string dir = (trend == "BUY") ? "SELL" : "BUY";
         OpenHedge(dir, i, hedgePrice);
      }
      HedgeL3Active = true;
   }
   
   // Level 8 Hedge (-6 to -10)
   if(mainLevel >= 8 && !HedgeL8Active && drawdown > InpHedgeTrigPts) {
      double hedgePrice = (trend == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      for(int i=6; i<=10; i++) {
         string dir = (trend == "BUY") ? "SELL" : "BUY";
         OpenHedge(dir, i, hedgePrice);
      }
      HedgeL8Active = true;
   }
}

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
int GetCurrentMainLevel(string trend) {
   int mx = 0;
   for(int i=0; i<posList.Total(); i++) {
      PosInfo* p = posList.At(i);
      if(p != NULL && !StringFind(p->type, "-") && StringCase(p->type) == StringCase(trend)) {
         int l = StringToInt(p->level);
         if(l > mx) mx = l;
      }
   }
   return mx;
}

void CloseAll(void) {
   for(int i=posList.Total()-1; i>=0; i--) {
      PosInfo* p = posList.At(i);
      if(p != NULL) trade.PositionClose(p->ticket);
   }
   HedgeL3Active = false;
   HedgeL8Active = false;
}

double GetLowestBar(int count) {
   double mn = 99999999;
   for(int i=1; i<=count; i++) {
      if(Low[i] < mn) mn = Low[i];
   }
   return mn;
}

double GetHighestBar(int count) {
   double mx = 0;
   for(int i=1; i<=count; i++) {
      if(High[i] > mx) mx = High[i];
   }
   return mx;
}

double PointHelper() { return _Point; }
