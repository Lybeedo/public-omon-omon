//+------------------------------------------------------------------+
//|                        XAUUSD_Scalper_M1_VirtualTrail.mq5        |
//|                    Modified: Virtual Trailing Stop System        |
//|          No PositionModify — Internal tracking + manual close   |
//+------------------------------------------------------------------+
#property copyright   ""
#property version     "2.01"
#property strict
#property description "XAUUSD Scalper M1 - Virtual Trailing System"

//--- Input Parameters
input double Sar_period   = 0.56;   // SAR Period
input int    Step         = 25;     // Step (points)
input int    Acceleration = 9;      // Acceleration (seconds threshold)
input int    TrailingStop = 25;     // Trailing Stop (points)
input int    StopLoss     = 530;    // Stop Loss ratio (x/100 equity ratio)
input double Lots         = 0.05;   // Lot size
input int    Max_Spread   = 20;     // Max allowed spread (points)
input int    Magic        = 1111111;// Magic Number

//--- Trade object
#include <Trade\Trade.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\PositionInfo.mqh>

CTrade         trade;
COrderInfo     orderInfo;
CPositionInfo  posInfo;

//+------------------------------------------------------------------+
//| VIRTUAL TRAILING CLASS                                            |
//+------------------------------------------------------------------+
class CVirtualTrailing
{
private:
   struct TrailingData
   {
      ulong     ticket;
      double    virtualSL;
      double    trailingDistance;
      datetime  lastUpdate;
      bool      activated;
   };
   
   TrailingData m_positions[];
   double       m_trailingPts;
   double       m_stepPts;
   string       m_symbol;
   int          m_magic;
   double       m_equityHigh;

   //--- Helper: normalize price to digits
   double NormPrice(double price)
   {
      return NormalizeDouble(price, _Digits);
   }

   //--- Find index by ticket
   int FindByTicket(ulong ticket)
   {
      for(int i = 0; i < ArraySize(m_positions); i++)
         if(m_positions[i].ticket == ticket) return i;
      return -1;
   }

   //--- Resize array if needed
   void EnsureCapacity(int index)
   {
      if(index >= ArraySize(m_positions))
         ArrayResize(m_positions, index + 1);
   }

public:
   CVirtualTrailing(string symbol, int magic, double trailingPts, double stepPts)
   {
      m_symbol = symbol;
      m_magic = magic;
      m_trailingPts = trailingPts;
      m_stepPts = stepPts;
      m_equityHigh = 0;
   }

   //--- Initialize new position with virtual SL
   void AddPosition(ulong ticket, double entryPrice, bool isBuy)
   {
      int idx = FindByTicket(ticket);
      if(idx < 0)
      {
         idx = ArraySize(m_positions);
         ArrayResize(m_positions, idx + 1);
      }
      
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      m_positions[idx].ticket = ticket;
      m_positions[idx].lastUpdate = TimeCurrent();
      m_positions[idx].activated = false;
      
      // Initial virtual SL: entry price minus trailing distance
      if(isBuy)
         m_positions[idx].virtualSL = entryPrice - (m_trailingPts * point);
      else
         m_positions[idx].virtualSL = entryPrice + (m_trailingPts * point);
      
      m_positions[idx].trailingDistance = m_trailingPts * point;
      Print("[VTrailing] Add ticket ", ticket, " | Entry=", entryPrice, 
            " | VirtualSL=", m_positions[idx].virtualSL);
   }

   //--- Remove position from tracking
   void RemovePosition(ulong ticket)
   {
      int idx = FindByTicket(ticket);
      if(idx < 0) return;
      
      for(int i = idx; i < ArraySize(m_positions) - 1; i++)
         m_positions[i] = m_positions[i + 1];
      
      ArrayResize(m_positions, ArraySize(m_positions) - 1);
   }

   //--- Update virtual trailing level (NO PositionModify sent)
   //   Called every tick — checks equity high and updates virtual SL
   void Update(double equity, double balance, double lastEquityHigh, double slRatio)
   {
      // Update equity high watermark
      if(equity > m_equityHigh)
         m_equityHigh = equity;
      
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double eqRatio = (balance > 0) ? equity / balance : 1.0;

      for(int i = 0; i < ArraySize(m_positions); i++)
      {
         ulong ticket = m_positions[i].ticket;
         
         // Verify position still exists
         if(!posInfo.SelectByTicket(ticket))
         {
            RemovePosition(ticket);
            i--;
            continue;
         }
         
         double openPrice = posInfo.PriceOpen();
         bool   isBuy = (posInfo.PositionType() == POSITION_TYPE_BUY);
         double currentSL = posInfo.StopLoss();
         double currentPrice = isBuy ? bid : ask;

         // Check trigger: equity dropped below threshold OR new equity high
         bool triggerTrail = (equity > lastEquityHigh * 0.999) || (eqRatio < slRatio);
         
         if(!triggerTrail && m_positions[i].activated)
            triggerTrail = true; // Once activated, keep trailing
         
         if(!triggerTrail) continue;

         // Activate trailing
         m_positions[i].activated = true;

         double newVirtualSL = 0;
         
         if(isBuy)
         {
            // BUY: trailing moves UP only (price going favorable)
            // Trigger: bid moved up enough relative to open price
            double profitDist = point * 60;
            if(currentPrice > (openPrice + profitDist))
            {
               double candidate = currentPrice - (m_trailingPts * point);
               if(candidate > m_positions[i].virtualSL)
                  newVirtualSL = candidate;
            }
         }
         else
         {
            // SELL: trailing moves DOWN only (price going favorable)
            // Trigger: ask moved down enough relative to open price
            double profitDist = point * 60;
            if(currentPrice < (openPrice - profitDist))
            {
               double candidate = currentPrice + (m_trailingPts * point);
               if(candidate < m_positions[i].virtualSL)
                  newVirtualSL = candidate;
            }
         }

         if(newVirtualSL > 0)
         {
            newVirtualSL = NormPrice(newVirtualSL);
            m_positions[i].virtualSL = newVirtualSL;
            m_positions[i].lastUpdate = TimeCurrent();
         }
      }
   }

   //--- Check if price hit virtual SL → return tickets to close
   //   Returns array of tickets that should be closed
   void CheckTrigger(double bid, double ask, ulong &tickets[], int &count)
   {
      count = 0;
      ArrayResize(tickets, ArraySize(m_positions));
      
      for(int i = 0; i < ArraySize(m_positions); i++)
      {
         ulong ticket = m_positions[i].ticket;
         
         if(!posInfo.SelectByTicket(ticket)) continue;
         
         double openPrice = posInfo.PriceOpen();
         bool   isBuy = (posInfo.PositionType() == POSITION_TYPE_BUY);
         double currentPrice = isBuy ? bid : ask;
         double virtualSL = m_positions[i].virtualSL;
         
         // Check if price crossed virtual SL
         bool triggered = false;
         
         if(isBuy)
         {
            // BUY: triggered if bid dropped to or below virtual SL
            if(bid <= virtualSL)
               triggered = true;
         }
         else
         {
            // SELL: triggered if ask rose to or above virtual SL
            if(ask >= virtualSL)
               triggered = true;
         }
         
         if(triggered)
         {
            tickets[count] = ticket;
            count++;
            
            double pnl = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
            Print("[VTrailing] TRIGGER ticket ", ticket, 
                  " | Type=", isBuy ? "BUY" : "SELL",
                  " | Price=", currentPrice,
                  " | VirtualSL=", virtualSL,
                  " | P&L=", pnl);
         }
      }
   }

   //--- Sync: remove tickets that no longer exist
   void Sync()
   {
      for(int i = ArraySize(m_positions) - 1; i >= 0; i--)
      {
         if(!posInfo.SelectByTicket(m_positions[i].ticket))
            RemovePosition(m_positions[i].ticket);
      }
   }

   //--- Get virtual SL for a ticket (for display/debugging)
   double GetVirtualSL(ulong ticket)
   {
      int idx = FindByTicket(ticket);
      if(idx < 0) return 0;
      return m_positions[idx].virtualSL;
   }

   //--- Get count of tracked positions
   int Count() { return ArraySize(m_positions); }
};

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
string   EA_Name        = "XAUUSD Scalper M1";
int      MaxOrders      = 4;
int      SpreadSamples  = 100;
int      MinBarSamples  = 10;
int      SlipPage       = 10;
int      MinStopLevel   = 33;

double   AvgSpread      = 0;
double   MaxSpreadPts   = 0;
double   Momentum       = 0;
double   LastEquityHigh = 0;

double   SpreadArray[];
double   PriceHistory[];
int      TimeHistory[];

int      BuyStopCount   = 0;
int      SellStopCount  = 0;
int      BuyStopTime    = 0;
int      SellStopTime   = 0;
int      LastBarCount   = 0;
int      TrailingMin    = 33;

//--- Virtual Trailing System
CVirtualTrailing *g_vTrail;

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(Magic);
   trade.SetDeviationInPoints(SlipPage);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   //--- Validate trailing stop vs broker minimum
   int brokerStopLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int effectiveTrail  = TrailingStop;
   int effectiveStep   = Step;

   if(effectiveTrail <= brokerStopLevel) effectiveTrail = brokerStopLevel + 1;
   if(effectiveStep  <= brokerStopLevel) effectiveStep  = brokerStopLevel + 1;
   if(effectiveTrail < MinStopLevel)     effectiveTrail = MinStopLevel;

   TrailingMin = effectiveTrail;

   //--- Initialize spread buffer
   ArrayResize(SpreadArray,  SpreadSamples);
   ArrayResize(PriceHistory, SpreadSamples);
   ArrayResize(TimeHistory,  SpreadSamples);

   double currentSpread = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        - SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   ArrayFill(SpreadArray,  0, SpreadSamples, currentSpread);
   ArrayFill(PriceHistory, 0, SpreadSamples, SymbolInfoDouble(_Symbol, SYMBOL_BID));
   ArrayFill(TimeHistory,  0, SpreadSamples, (int)TimeCurrent());

   MaxSpreadPts = NormalizeDouble(Max_Spread * _Point, _Digits);
   LastEquityHigh = AccountInfoDouble(ACCOUNT_EQUITY);

   //--- Initialize Virtual Trailing System
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_vTrail = new CVirtualTrailing(_Symbol, Magic, TrailingMin, Step);
   Print("[VT] Virtual Trailing initialized | Distance=", TrailingMin, " pts");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(CheckPointer(g_vTrail) != POINTER_INVALID)
   {
      delete g_vTrail;
      g_vTrail = NULL;
   }
}

//+------------------------------------------------------------------+
//| Calculate momentum and update rolling buffers                     |
//+------------------------------------------------------------------+
void CalcMomentum()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   ArrayCopy(SpreadArray, SpreadArray, 0, 1, SpreadSamples - 1);
   SpreadArray[SpreadSamples - 1] = NormalizeDouble(ask - bid, _Digits);
   AvgSpread = 0;
   for(int i = 0; i < SpreadSamples; i++) AvgSpread += SpreadArray[i];
   AvgSpread /= SpreadSamples;

   ArrayCopy(PriceHistory, PriceHistory, 0, 1, SpreadSamples - 1);
   ArrayCopy(TimeHistory,  TimeHistory,  0, 1, SpreadSamples - 1);
   PriceHistory[SpreadSamples - 1] = bid;
   TimeHistory[SpreadSamples - 1]  = (int)TimeCurrent();

   int   lastIdx   = SpreadSamples - 1;
   int   lastTime  = TimeHistory[lastIdx];
   double lastPrice = PriceHistory[lastIdx];
   double basePrice = 0;

   for(int j = lastIdx; j >= 0; j--)
   {
      if((lastTime - TimeHistory[j]) > Acceleration)
      {
         basePrice = PriceHistory[j];
         break;
      }
   }

   Momentum = lastPrice - basePrice;

   if(MathAbs(Momentum / _Point) > 1000)
      Momentum = 0;
}

//+------------------------------------------------------------------+
//| Validate lot size                                                |
//+------------------------------------------------------------------+
double NormalizeLots(double lots)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   double result = MathRound(lots / lotStep) * lotStep;
   result = MathMax(result, minLot);
   result = MathMin(result, maxLot);
   return NormalizeDouble(result, 2);
}

//+------------------------------------------------------------------+
//| Check free margin                                                |
//+------------------------------------------------------------------+
bool HasEnoughMargin()
{
   double lotSize        = NormalizeLots(Lots);
   double marginRequired = SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_REQUIRED) * lotSize;

   if(AccountInfoDouble(ACCOUNT_FREEMARGIN) < marginRequired)
   {
      Print("Not enough free margin! Required: ", marginRequired,
            " Available: ", AccountInfoDouble(ACCOUNT_FREEMARGIN));
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Count orders                                                      |
//+------------------------------------------------------------------+
void CountOrders(int &totalOpen, int &buyStops, int &sellStops,
                 double &totalProfit, double &lowestEntry, double &highestEntry)
{
   totalOpen   = 0;
   buyStops    = 0;
   sellStops   = 0;
   totalProfit = 0;
   lowestEntry  = DBL_MAX;
   highestEntry = -DBL_MAX;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i))
      {
         if(posInfo.Magic() == Magic && posInfo.Symbol() == _Symbol)
         {
            totalOpen++;
            totalProfit += posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
            if(posInfo.PriceOpen() < lowestEntry)  lowestEntry  = posInfo.PriceOpen();
            if(posInfo.PriceOpen() > highestEntry) highestEntry = posInfo.PriceOpen();
            
            // Sync: add new positions to virtual trailing
            if(CheckPointer(g_vTrail) != POINTER_INVALID)
               g_vTrail.AddPosition(posInfo.Ticket(), posInfo.PriceOpen(),
                                    posInfo.PositionType() == POSITION_TYPE_BUY);
         }
      }
   }

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(orderInfo.SelectByIndex(i))
      {
         if(orderInfo.Magic() == Magic && orderInfo.Symbol() == _Symbol)
         {
            if(orderInfo.OrderType() == ORDER_TYPE_BUY_STOP)  buyStops++;
            if(orderInfo.OrderType() == ORDER_TYPE_SELL_STOP) sellStops++;

            if(orderInfo.PriceOpen() < lowestEntry)  lowestEntry  = orderInfo.PriceOpen();
            if(orderInfo.PriceOpen() > highestEntry) highestEntry = orderInfo.PriceOpen();
         }
      }
   }

   if(lowestEntry  == DBL_MAX)  lowestEntry  = 0;
   if(highestEntry == -DBL_MAX) highestEntry = 0;
}

//+------------------------------------------------------------------+
//| Close all positions                                               |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i))
      {
         if(posInfo.Magic() == Magic && posInfo.Symbol() == _Symbol)
         {
            // Remove from virtual trailing before closing
            if(CheckPointer(g_vTrail) != POINTER_INVALID)
               g_vTrail.RemovePosition(posInfo.Ticket());
            
            trade.PositionClose(posInfo.Ticket());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Close specific positions (used by virtual trailing trigger)      |
//+------------------------------------------------------------------+
void ClosePositionsByTicket(ulong &tickets[], int count)
{
   for(int i = 0; i < count; i++)
   {
      ulong ticket = tickets[i];
      if(posInfo.SelectByTicket(ticket))
      {
         if(posInfo.Magic() == Magic && posInfo.Symbol() == _Symbol)
         {
            Print("[VT-Close] Closing ticket ", ticket);
            trade.PositionClose(ticket);
            
            // Remove from virtual trailing
            if(CheckPointer(g_vTrail) != POINTER_INVALID)
               g_vTrail.RemovePosition(ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Delete all pending orders                                         |
//+------------------------------------------------------------------+
void DeleteAllPending()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(orderInfo.SelectByIndex(i))
      {
         if(orderInfo.Magic() == Magic && orderInfo.Symbol() == _Symbol)
            trade.OrderDelete(orderInfo.Ticket());
      }
   }
}

//+------------------------------------------------------------------+
//| Delete pending BUY STOP orders                                    |
//+------------------------------------------------------------------+
void DeleteBuyStops()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(orderInfo.SelectByIndex(i))
      {
         if(orderInfo.Magic() == Magic && orderInfo.Symbol() == _Symbol
            && orderInfo.OrderType() == ORDER_TYPE_BUY_STOP)
            trade.OrderDelete(orderInfo.Ticket());
      }
   }
}

//+------------------------------------------------------------------+
//| Delete pending SELL STOP orders                                   |
//+------------------------------------------------------------------+
void DeleteSellStops()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(orderInfo.SelectByIndex(i))
      {
         if(orderInfo.Magic() == Magic && orderInfo.Symbol() == _Symbol
            && orderInfo.OrderType() == ORDER_TYPE_SELL_STOP)
            trade.OrderDelete(orderInfo.Ticket());
      }
   }
}

//+------------------------------------------------------------------+
//| Manage VIRTUAL trailing (NO PositionModify)                       |
//+------------------------------------------------------------------+
void ManageVirtualTrailing()
{
   if(CheckPointer(g_vTrail) == POINTER_INVALID) return;

   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double slRatio = StopLoss / 100.0;

   // Update virtual trailing levels — NO server modification
   g_vTrail.Update(equity, balance, LastEquityHigh, slRatio);
}

//+------------------------------------------------------------------+
//| Check VIRTUAL trailing trigger                                    |
//+------------------------------------------------------------------+
void CheckVirtualTrailingTrigger()
{
   if(CheckPointer(g_vTrail) == POINTER_INVALID) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   ulong tickets[];
   int count = 0;

   g_vTrail.CheckTrigger(bid, ask, tickets, count);

   if(count > 0)
   {
      Print("[VT] Virtual trailing triggered for ", count, " position(s)");
      ClosePositionsByTicket(tickets, count);
   }
}

//+------------------------------------------------------------------+
//| Manage stale pending orders                                       |
//+------------------------------------------------------------------+
void ManageStalePending()
{
   int now = (int)TimeCurrent();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!orderInfo.SelectByIndex(i)) continue;
      if(orderInfo.Magic() != Magic || orderInfo.Symbol() != _Symbol) continue;

      if(orderInfo.OrderType() == ORDER_TYPE_BUY_STOP)
      {
         int age = now - BuyStopTime;
         if(age > Acceleration && Momentum < (_Point * 70))
            trade.OrderDelete(orderInfo.Ticket());
      }

      if(orderInfo.OrderType() == ORDER_TYPE_SELL_STOP)
      {
         int age = now - SellStopTime;
         if(age > Acceleration && Momentum > (_Point * -70))
            trade.OrderDelete(orderInfo.Ticket());
      }
   }
}

//+------------------------------------------------------------------+
//| Main OnTick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   //--- Step 1: Validate lot size
   double lotSize = NormalizeLots(Lots);
   if(lotSize <= 0)
   {
      Print("Invalid lot size after normalization.");
      return;
   }

   //--- Step 2: Check free margin
   if(!HasEnoughMargin()) return;

   //--- Step 3: Update momentum calculation
   CalcMomentum();

   //--- Step 4: Check spread filter
   double currentSpread = ask - bid;
   if(currentSpread > MaxSpreadPts) return;

   //--- Step 5: Count current orders
   int    totalOpen, buyStops, sellStops;
   double totalProfit, lowestEntry, highestEntry;
   CountOrders(totalOpen, buyStops, sellStops, totalProfit, lowestEntry, highestEntry);

   //--- Step 6: Global profit target → close everything
   double profitTarget = Lots * 200;
   if(totalProfit > profitTarget)
   {
      CloseAllPositions();
      DeleteAllPending();
      return;
   }

   //--- Step 7: VIRTUAL Trailing (NO PositionModify)
   ManageVirtualTrailing();

   //--- Step 7b: Check if virtual SL triggered → close positions
   CheckVirtualTrailingTrigger();

   //--- Step 8: Manage stale pending orders
   ManageStalePending();

   //--- Step 9: Re-count after potential closings
   CountOrders(totalOpen, buyStops, sellStops, totalProfit, lowestEntry, highestEntry);

   //--- Step 10: Entry logic (only on new bar)
   int currentBars = Bars(_Symbol, PERIOD_CURRENT);
   if(currentBars == LastBarCount) return;

   //--- SAR values
   double sarCurrent = iSAR(_Symbol, PERIOD_CURRENT, Sar_period, 0.2, 0);
   if(sarCurrent == EMPTY_VALUE || sarCurrent == 0) return;

   //--- Bollinger Bands values
   int bbHandle = iBands(_Symbol, PERIOD_CURRENT, 20, 0, 2, PRICE_CLOSE);
   if(bbHandle == INVALID_HANDLE) return;

   double bbUpper[], bbLower[], bbMiddle[];
   ArraySetAsSeries(bbUpper,  true);
   ArraySetAsSeries(bbLower,  true);
   ArraySetAsSeries(bbMiddle, true);

   if(CopyBuffer(bbHandle, 1, 0, 3, bbUpper)  < 3) return;
   if(CopyBuffer(bbHandle, 2, 0, 3, bbLower)  < 3) return;
   if(CopyBuffer(bbHandle, 0, 0, 3, bbMiddle) < 3) return;

   IndicatorRelease(bbHandle);

   double close0 = iClose(_Symbol, PERIOD_CURRENT, 0);

   //--- Only enter if total open orders < MaxOrders
   if(totalOpen < MaxOrders)
   {
      //--- BUY STOP Entry Condition
      if(Momentum > (_Point * 60))
      {
         double sarEntry = sarCurrent - (Step * _Point);
         bool sarBullish = (sarEntry > close0);
         bool belowLowest = (lowestEntry == 0 || ((Step * _Point) + ask) < lowestEntry);

         if(sarBullish && belowLowest && buyStops == 0)
         {
            double entryPrice = NormalizeDouble(ask + (Step * _Point), _Digits);
            if(trade.BuyStop(lotSize, entryPrice, _Symbol, 0, 0, ORDER_TIME_GTC, 0, EA_Name))
            {
               BuyStopTime = (int)TimeCurrent();
               Print("[Entry] BUY STOP placed at ", entryPrice);
            }
         }
      }

      //--- SELL STOP Entry Condition
      if(Momentum < (_Point * -60))
      {
         double sarEntry = sarCurrent + (Step * _Point);
         bool sarBearish = (sarEntry < close0);
         bool aboveHighest = (highestEntry == 0 || (bid - (Step * _Point)) > highestEntry);

         if(sarBearish && aboveHighest && sellStops == 0)
         {
            double entryPrice = NormalizeDouble(bid - (Step * _Point), _Digits);
            if(trade.SellStop(lotSize, entryPrice, _Symbol, 0, 0, ORDER_TIME_GTC, 0, EA_Name))
            {
               SellStopTime = (int)TimeCurrent();
               Print("[Entry] SELL STOP placed at ", entryPrice);
            }
         }
      }
   }

   //--- Step 11: Secondary signal logic (Bollinger Band breakout)
   int dirBias = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i) && posInfo.Magic() == Magic && posInfo.Symbol() == _Symbol)
      {
         if(posInfo.PositionType() == POSITION_TYPE_BUY)  dirBias = 1;
         if(posInfo.PositionType() == POSITION_TYPE_SELL) dirBias = -1;
      }
   }
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(orderInfo.SelectByIndex(i) && orderInfo.Magic() == Magic && orderInfo.Symbol() == _Symbol)
      {
         if(orderInfo.OrderType() == ORDER_TYPE_BUY_STOP)  dirBias = 1;
         if(orderInfo.OrderType() == ORDER_TYPE_SELL_STOP) dirBias = -1;
      }
   }

   int secOrderCount = 0;
   double secLowest  = DBL_MAX;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(orderInfo.SelectByIndex(i) && orderInfo.Magic() == Magic)
         if(orderInfo.Comment() == "3782") 
         { 
            secOrderCount++; 
            if(orderInfo.PriceOpen() < secLowest) secLowest = orderInfo.PriceOpen(); 
         }
   }
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i) && posInfo.Magic() == Magic)
         if(posInfo.Comment() == "3782") 
         { 
            secOrderCount++; 
            if(posInfo.PriceOpen() < secLowest) secLowest = posInfo.PriceOpen(); 
         }
   }
   if(secLowest == DBL_MAX) secLowest = 0;

   //--- BB Upper breakout → BUY STOP secondary
   double bbGap = _Point * 20;
   if((bbUpper[0] - bbGap) > ask)
   {
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if(orderInfo.SelectByIndex(i) && orderInfo.Magic() == Magic
            && orderInfo.OrderType() == ORDER_TYPE_BUY_STOP
            && orderInfo.Comment() == "3782")
            trade.OrderDelete(orderInfo.Ticket());
      }

      double entryB = NormalizeDouble(ask + (_Point * 30), _Digits);
      bool okEntry  = (secLowest == 0 || ((_Point * 50) + ask) < secLowest);

      if(okEntry && (dirBias == 0 || dirBias == 1))
      {
         trade.BuyStop(lotSize, entryB, _Symbol, 0, 0, ORDER_TIME_GTC, 0, "3782");
         Print("[Entry] BB BUY STOP placed at ", entryB);
      }
      LastBarCount = currentBars;
      return;
   }

   //--- BB Lower + momentum filter → SELL STOP secondary
   double bbLowerFilter = NormalizeDouble(bbLower[1] + (_Point * 20), _Digits);
   if(bbLowerFilter >= bid) return;

   if(currentBars == LastBarCount) return;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(orderInfo.SelectByIndex(i) && orderInfo.Magic() == Magic
         && orderInfo.OrderType() == ORDER_TYPE_SELL_STOP
         && orderInfo.Comment() == "3782")
         trade.OrderDelete(orderInfo.Ticket());
   }

   double entryS  = NormalizeDouble(bid - (_Point * 30), _Digits);
   bool   okSell  = (secLowest == 0 || (bid - (_Point * 50)) > LastEquityHigh);

   if(okSell && (dirBias == 0 || dirBias == -1))
   {
      trade.SellStop(lotSize, entryS, _Symbol, 0, 0, ORDER_TIME_GTC, 0, "3782");
      Print("[Entry] BB SELL STOP placed at ", entryS);
   }

   LastBarCount = currentBars;
}
//+------------------------------------------------------------------+