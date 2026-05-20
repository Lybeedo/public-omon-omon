//+------------------------------------------------------------------+
//| AK_RPG.mq5                                                        |
//| EA Grid Hedge Martingale - Converted from Pine Script             |
//| Buy + Sell / Buy Only / Sell Only with Grid Averaging            |
//| Martingale Lot, Trailing Lock, Drawdown Protection                |
//+------------------------------------------------------------------+
#property strict
#property version   "1.0"
#property icon      ""
#property link      ""
#property copyright "7NAGA Trading System"
#property description "AK_RPG - Grid Hedge Martingale EA. No indicator. Dar Der Dor."

//+------------------------------------------------------------------+
//| INPUTS - GROUP 1: LOT & MARTINGALE                                |
//+------------------------------------------------------------------+
input group "📊 Lot & Martingale"
input double iLotSize     = 0.01;  // Lot Size
input double iMartingale  = 1.8;   // Martingale Multiplier
input int    iDelay       = 3;     // Delay (Order sebelum lot naik)
input double iMaxLot      = 1.0;   // Max Lot Cap

//+------------------------------------------------------------------+
//| INPUTS - GROUP 2: TRADE MODE                                     |
//+------------------------------------------------------------------+
input group "🎯 Trade Mode"
input string iTradeMode  = "BOTH"; // Mode: BOTH, BUY ONLY, SELL ONLY

//+------------------------------------------------------------------+
//| INPUTS - GROUP 3: GRID TRIGGER                                   |
//+------------------------------------------------------------------+
input group "📏 Grid Trigger"
input int    iGridStep   = 100;    // Grid Step (points = $1 profit)
input int    iMaxOrders  = 10;     // Max Orders Per Side

//+------------------------------------------------------------------+
//| INPUTS - GROUP 4: TRAILING LOCK                                  |
//+------------------------------------------------------------------+
input group "🔒 Trailing Lock"
input double iTrailingStart = 5.0;  // Trailing Start ($)
input double iTrailingLock   = 1.0;  // Trailing Lock ($)
input double iTrailingStep   = 3.0;  // Trailing Step ($)

//+------------------------------------------------------------------+
//| INPUTS - GROUP 5: GLOBAL PROTECTION                              |
//+------------------------------------------------------------------+
input group "🛡️ Global Protection"
input double iMaxDrawdown   = 50.0;  // Max Drawdown ($)
input bool   iAutoReopen    = true;  // Auto Reopen Setelah Close All
input ulong  iMagicNumber   = 12345; // Magic Number

//+------------------------------------------------------------------+
//| CONSTANTS                                                         |
//+------------------------------------------------------------------+
#define POINTS_PER_DOLLAR 100.0

//+------------------------------------------------------------------+
//| GLOBAL STATE                                                      |
//+------------------------------------------------------------------+
bool   gHasOpenedInitial = false;
bool   gHasClosedAll     = false;
bool   gTrailingActive   = false;
double gLockLevel        = 0.0;

//+------------------------------------------------------------------+
//| OnInit                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   string modeStr;
   if(iTradeMode == "BUY ONLY")       modeStr = "BUY ONLY";
   else if(iTradeMode == "SELL ONLY") modeStr = "SELL ONLY";
   else                               modeStr = "BOTH (BUY + SELL)";

   Print("==========================================");
   Print("         AK_RPG - Grid Hedge Martingale");
   Print("==========================================");
   Print("   Lot Size    : ", DoubleToString(iLotSize, 2));
   Print("   Martingale  : ", DoubleToString(iMartingale, 2), "x");
   Print("   Delay       : ", iDelay, " orders per lot step");
   Print("   Max Lot     : ", DoubleToString(iMaxLot, 2));
   Print("   Mode        : ", modeStr);
   Print("   Grid Step   : ", iGridStep, " points ($", iGridStep/POINTS_PER_DOLLAR, ")");
   Print("   Max Orders  : ", iMaxOrders, " per side");
   Print("   Trailing    : Start $", iTrailingStart, " | Lock $", iTrailingLock, " | Step $", iTrailingStep);
   Print("   Max DD      : $", iMaxDrawdown);
   Print("   Auto Reopen : ", (iAutoReopen ? "YES" : "NO"));
   Print("   Magic       : ", iMagicNumber);
   Print("==========================================");
   Print("   NO INDICATOR. NO ANALYSIS. JUST GAS!");
   Print("==========================================");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("[OK] AK_RPG stopped. Reason=", reason);
}

//+------------------------------------------------------------------+
//| HELPER: COUNT POSITIONS BY MAGIC + SIDE                          |
//+------------------------------------------------------------------+
int CountBuyPositions()
{
   int cnt = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC)  == iMagicNumber &&
         PositionGetInteger(POSITION_TYPE)   == POSITION_TYPE_BUY)
      {
         cnt++;
      }
   }
   return cnt;
}

int CountSellPositions()
{
   int cnt = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC)  == iMagicNumber &&
         PositionGetInteger(POSITION_TYPE)   == POSITION_TYPE_SELL)
      {
         cnt++;
      }
   }
   return cnt;
}

//+------------------------------------------------------------------+
//| HELPER: GET FLOATING PROFIT (PNL) BY SIDE                        |
//+------------------------------------------------------------------+
double GetFloatingBuy()
{
   double pnl = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC)  == iMagicNumber &&
         PositionGetInteger(POSITION_TYPE)   == POSITION_TYPE_BUY)
      {
         pnl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      }
   }
   return pnl;
}

double GetFloatingSell()
{
   double pnl = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC)  == iMagicNumber &&
         PositionGetInteger(POSITION_TYPE)   == POSITION_TYPE_SELL)
      {
         pnl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      }
   }
   return pnl;
}

//+------------------------------------------------------------------+
//| HELPER: GET TOTAL CLOSED PROFIT                                  |
//+------------------------------------------------------------------+
double GetClosedProfit()
{
   double total = 0.0;
   HistorySelect(0, TimeCurrent());
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      if(HistoryDealGetString(i, DEAL_SYMBOL) == _Symbol &&
         HistoryDealGetInteger(i, DEAL_MAGIC)  == iMagicNumber)
      {
         total += HistoryDealGetDouble(i, DEAL_PROFIT);
      }
   }
   return total;
}

//+------------------------------------------------------------------+
//| HELPER: CALCULATE LOT PER LAYER (Delay Martingale)              |
//+------------------------------------------------------------------+
double CalcLot(int layer)
{
   double level    = (layer - 1) / iDelay;
   int    levelInt = (int)MathFloor(level);
   double baseLot  = iLotSize * MathPow(iMartingale, levelInt);
   baseLot = MathMin(baseLot, iMaxLot);
   baseLot = MathRound(baseLot * 100) / 100.0;
   return baseLot;
}

//+------------------------------------------------------------------+
//| HELPER: OPEN POSITION                                            |
//+------------------------------------------------------------------+
bool OpenPosition(ENUM_ORDER_TYPE type, string comment)
{
   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   double price = (type == ORDER_TYPE_BUY) ?
                 SymbolInfoDouble(_Symbol, SYMBOL_ASK) :
                 SymbolInfoDouble(_Symbol, SYMBOL_BID);

   req.action   = TRADE_ACTION_DEAL;
   req.symbol   = _Symbol;
   req.volume   = iLotSize; // Lot di-set per order di OnTick
   req.type     = type;
   req.price    = price;
   req.sl       = 0;
   req.tp       = 0;
   req.deviation= 30;
   req.magic    = iMagicNumber;
   req.comment  = comment;

   if(!OrderSend(req, res))
   {
      Print("[ERROR] OrderSend failed! Retcode=", res.retcode, " Comment=", res.comment);
      return false;
   }

   if(res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED)
   {
      Print("[OK] ", comment, " opened @ ", price);
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| HELPER: CLOSE ALL POSITIONS                                      |
//+------------------------------------------------------------------+
bool CloseAllPositions(string reason)
{
   bool anyClosed = false;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC)  == iMagicNumber)
      {
         MqlTradeRequest req;
         MqlTradeResult  res;
         ZeroMemory(req);
         ZeroMemory(res);

         ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE);
         double price = (type == ORDER_TYPE_BUY) ?
                        SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                        SymbolInfoDouble(_Symbol, SYMBOL_ASK);

         req.action    = TRADE_ACTION_DEAL;
         req.symbol    = _Symbol;
         req.volume    = PositionGetDouble(POSITION_VOLUME);
         req.type      = (type == ORDER_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
         req.price     = price;
         req.deviation = 30;
         req.magic     = iMagicNumber;
         req.comment   = reason;

         if(OrderSend(req, res))
         {
            if(res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED)
            {
               anyClosed = true;
            }
         }
      }
   }

   return anyClosed;
}

//+------------------------------------------------------------------+
//| OnTick                                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- INIT: Open initial positions at bar 0 (first tick)
   if(!gHasOpenedInitial)
   {
      if(iTradeMode == "BOTH")
      {
         if(OpenPosition(ORDER_TYPE_BUY,  "BUY")) {}
         if(OpenPosition(ORDER_TYPE_SELL, "SELL")) {}
      }
      else if(iTradeMode == "BUY ONLY")
      {
         if(OpenPosition(ORDER_TYPE_BUY, "BUY")) {}
      }
      else if(iTradeMode == "SELL ONLY")
      {
         if(OpenPosition(ORDER_TYPE_SELL, "SELL")) {}
      }

      gHasOpenedInitial = true;
   }

   //--- Get current state
   int    buyCount  = CountBuyPositions();
   int    sellCount = CountSellPositions();
   double buyProfit = GetFloatingBuy();
   double sellProfit= GetFloatingSell();
   double totalProfit = buyProfit + sellProfit;
   int    totalOpen = buyCount + sellCount;

   //--- Print status every 10 ticks (to reduce spam)
   static int tickCounter = 0;
   tickCounter++;
   if(tickCounter % 10 == 0)
   {
      Print("[STATUS] BUY=", buyCount, "($", DoubleToString(buyProfit, 2),
            ") | SELL=", sellCount, "($", DoubleToString(sellProfit, 2),
            ") | TOTAL=$", DoubleToString(totalProfit, 2),
            " | Trailing=", (gTrailingActive ? "ON (Lock=$" : "OFF"),
            (gTrailingActive ? DoubleToString(gLockLevel, 2) : ""), ")");
   }

   //--- GRID TRIGGER: Open new BUY order
   double buyThreshold = (iGridStep / POINTS_PER_DOLLAR) * buyCount;
   bool   triggerBuy = (buyCount > 0 && buyCount < iMaxOrders) &&
                       (iTradeMode == "BOTH" || iTradeMode == "BUY ONLY") &&
                       (buyProfit >= buyThreshold);

   if(triggerBuy)
   {
      double lot = CalcLot(buyCount + 1);
      // Override lot for this order
      MqlTradeRequest req;
      MqlTradeResult  res;
      ZeroMemory(req);
      ZeroMemory(res);

      double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.action   = TRADE_ACTION_DEAL;
      req.symbol   = _Symbol;
      req.volume   = lot;
      req.type     = ORDER_TYPE_BUY;
      req.price    = price;
      req.sl       = 0;
      req.tp       = 0;
      req.deviation= 30;
      req.magic    = iMagicNumber;
      req.comment  = "BUY_" + IntegerToString(buyCount + 1);

      if(OrderSend(req, res))
      {
         if(res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED)
            Print("[GRID] BUY_", buyCount + 1, " opened. Lot=", DoubleToString(lot, 2),
                  " | BuyProfit=", DoubleToString(buyProfit, 2),
                  " | Threshold=$", DoubleToString(buyThreshold, 2));
      }
   }

   //--- GRID TRIGGER: Open new SELL order
   double sellThreshold = (iGridStep / POINTS_PER_DOLLAR) * sellCount;
   bool   triggerSell = (sellCount > 0 && sellCount < iMaxOrders) &&
                        (iTradeMode == "BOTH" || iTradeMode == "SELL ONLY") &&
                        (sellProfit >= sellThreshold);

   if(triggerSell)
   {
      double lot = CalcLot(sellCount + 1);
      MqlTradeRequest req;
      MqlTradeResult  res;
      ZeroMemory(req);
      ZeroMemory(res);

      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.action   = TRADE_ACTION_DEAL;
      req.symbol   = _Symbol;
      req.volume   = lot;
      req.type     = ORDER_TYPE_SELL;
      req.price    = price;
      req.sl       = 0;
      req.tp       = 0;
      req.deviation= 30;
      req.magic    = iMagicNumber;
      req.comment  = "SELL_" + IntegerToString(sellCount + 1);

      if(OrderSend(req, res))
      {
         if(res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED)
            Print("[GRID] SELL_", sellCount + 1, " opened. Lot=", DoubleToString(lot, 2),
                  " | SellProfit=", DoubleToString(sellProfit, 2),
                  " | Threshold=$", DoubleToString(sellThreshold, 2));
      }
   }

   //--- TRAILING LOCK LOGIC
   double trailingBase = totalProfit;

   if(iTradeMode == "BUY ONLY")
      trailingBase = buyProfit;
   else if(iTradeMode == "SELL ONLY")
      trailingBase = sellProfit;

   gTrailingActive = (trailingBase >= iTrailingStart);

   if(gTrailingActive)
   {
      int steps = (int)MathFloor((trailingBase - iTrailingStart) / iTrailingStep);
      gLockLevel = iTrailingLock + steps * iTrailingStep;

      if(trailingBase <= gLockLevel)
      {
         Print("[TRAILING LOCK] TotalProfit=$", DoubleToString(trailingBase, 2),
               " <= Lock=$", DoubleToString(gLockLevel, 2), " → CLOSE ALL");
         CloseAllPositions("Trailing Lock Hit");
         gHasClosedAll = true;
      }
   }

   //--- GLOBAL DRAWDOWN PROTECTION
   double totalLoss = GetClosedProfit() + totalProfit;
   if(totalLoss <= -iMaxDrawdown)
   {
      Print("[DRAWDOWN] TotalLoss=$", DoubleToString(totalLoss, 2),
            " >= MaxDD=$", DoubleToString(-iMaxDrawdown, 2), " → CLOSE ALL");
      CloseAllPositions("Max Drawdown");
      gHasClosedAll = true;
   }

   //--- AUTO REOPEN (only if ALL closed and was closed by system)
   if(gHasClosedAll && totalOpen == 0 && iAutoReopen)
   {
      Sleep(1000); // Small delay to avoid immediate re-entry

      if(iTradeMode == "BOTH")
      {
         if(OpenPosition(ORDER_TYPE_BUY,  "BUY_REOPEN")) {}
         if(OpenPosition(ORDER_TYPE_SELL, "SELL_REOPEN")) {}
      }
      else if(iTradeMode == "BUY ONLY")
      {
         if(OpenPosition(ORDER_TYPE_BUY, "BUY_REOPEN")) {}
      }
      else if(iTradeMode == "SELL ONLY")
      {
         if(OpenPosition(ORDER_TYPE_SELL, "SELL_REOPEN")) {}
      }

      gHasClosedAll = false;
      Print("[AUTO REOPEN] Positions restarted!");
   }
}
//+------------------------------------------------------------------+