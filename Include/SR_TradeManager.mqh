//+------------------------------------------------------------------+
//|                                           SR_TradeManager.mqh   |
//|                          Cuancux Algo Traders • Paulus Is        |
//+------------------------------------------------------------------+
#ifndef SR_TRADEMANAGER_MQH
#define SR_TRADEMANAGER_MQH

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//|  Trade state tracking                                            |
//+------------------------------------------------------------------+
struct STradeState
  {
   ulong       ticket;
   double      entryPrice;
   double      stopLoss;
   double      takeProfit;
   double      partialTPPrice;
   double      breakevenPrice;
   bool        partialHit;
   bool        beTriggered;
   bool        trailingActive;
   double      trailingStart;
   double      bestPrice;
   double      riskPips;
   double      partialClosePrice;
   datetime    openTime;
   int         zoneIdx;
   ENUM_POSITION_TYPE posType;
  };

//+------------------------------------------------------------------+
class CSR_TradeManager
  {
private:
   CTrade             m_trade;
   STradeState        m_states[];
   int                m_stateCount;
   int                m_magic;
   string             m_commentPrefix;
   int                m_slippage;
   double             m_riskPercent;
   double             m_minRR;
   double             m_maxRR;

   double             m_slPoints;
   double             m_tpPoints;
   bool               m_usePartial;
   double             m_partialTPPips;
   double             m_partialTPPct;
   bool               m_useBE;
   double             m_beTriggerPips;
   bool               m_useTrail;
   double             m_trailStartPips;
   double             m_trailStepPips;
   int                m_maxTrades;

public:
                     CSR_TradeManager(void);
                    ~CSR_TradeManager(void);

   void              Configure(
                        int magic, string commentPrefix, int slippage,
                        double riskPercent, double minRR, double maxRR,
                        double slPoints, double tpPoints,
                        bool usePartial, double partialTPPips, double partialTPPct,
                        bool useBE, double beTriggerPips,
                        bool useTrail, double trailStartPips, double trailStepPips,
                        int maxTrades);

   bool              OpenTrade(ENUM_ZONE_TYPE zoneType,
                               double zoneHigh, double zoneLow,
                               int zoneIdx,
                               double &slPrice, double &tpPrice,
                               double &lotSize);

   void              ManageTrades(void);
   int               CountOpenTrades(void);

   double            CalcRiskReward(double entryPrice, double slPrice, double tpPrice) const;
   int               StateCount(void) const { return m_stateCount; }
   STradeState*      GetState(int idx);

private:
   bool              OpenPosition(ENUM_ZONE_TYPE zoneType, double sl, double tp,
                                  double lot, int zoneIdx, ENUM_POSITION_TYPE posType,
                                  STradeState &stateOut);
   void              CheckPartialTP(STradeState &s);
   void              CheckBreakeven(STradeState &s);
   void              CheckTrailing(STradeState &s);
   bool              ModifyPosition(ulong ticket, double sl, double tp);
   bool              ClosePartial(ulong ticket, double lot);
  };

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|  P_ format conversion for XAUUSDm (5-digit price)                 |
//|  EA input is in "points" where 1 pip = 10 points                 |
//|  XAUUSD: Point = 0.00001 → 1 P_point = 0.001 price (100 points) |
//+------------------------------------------------------------------+
double g_pointsToPrice(double points)
  {
   // For 5-digit XAUUSD: 1 pip = 10 points, 1 P_point = Point * 1000
   // e.g. 150 points SL = 150 * 0.00001 * 1000 = 0.15 price = 1500 broker points
   return points * Point * 1000.0;
  }

//+------------------------------------------------------------------+
double g_priceToPoints(double price)
  {
   // Reverse of g_pointsToPrice: convert price difference back to points
   // price / (Point * 1000.0) = points
   // e.g. 0.15 price / 0.00001 / 1000 = 15000 points  
   return price / Point / 1000.0;
  }

//+------------------------------------------------------------------+
CSR_TradeManager::CSR_TradeManager(void)
  : m_magic(0), m_slippage(3), m_riskPercent(2.0),
    m_minRR(2.0), m_maxRR(0.0), m_stateCount(0),
    m_slPoints(150), m_tpPoints(300),
    m_usePartial(false), m_partialTPPips(50), m_partialTPPct(30),
    m_useBE(false), m_beTriggerPips(30),
    m_useTrail(false), m_trailStartPips(80), m_trailStepPips(20),
    m_maxTrades(3)
  {
   ArrayResize(m_states, 64);
  }

//+------------------------------------------------------------------+
CSR_TradeManager::~CSR_TradeManager(void) {}

//+------------------------------------------------------------------+
void CSR_TradeManager::Configure(
   int magic, string commentPrefix, int slippage,
   double riskPercent, double minRR, double maxRR,
   double slPoints, double tpPoints,
   bool usePartial, double partialTPPips, double partialTPPct,
   bool useBE, double beTriggerPips,
   bool useTrail, double trailStartPips, double trailStepPips,
   int maxTrades)
  {
   m_magic           = magic;
   m_commentPrefix   = commentPrefix;
   m_slippage        = slippage;
   m_riskPercent     = riskPercent;
   m_minRR           = minRR;
   m_maxRR           = maxRR;
   m_slPoints        = slPoints;
   m_tpPoints        = tpPoints;
   m_usePartial      = usePartial;
   m_partialTPPips   = partialTPPips;
   m_partialTPPct    = partialTPPct;
   m_useBE           = useBE;
   m_beTriggerPips   = beTriggerPips;
   m_useTrail        = useTrail;
   m_trailStartPips  = trailStartPips;
   m_trailStepPips   = trailStepPips;
   m_maxTrades       = maxTrades;

   m_trade.SetExpertMagicNumber(m_magic);
   m_trade.SetDeviationInPoints(m_slippage);
   m_trade.SetTypeFilling(ORDER_FILLING_FOK);
  }

//+------------------------------------------------------------------+
double CSR_TradeManager::CalcRiskReward(double entry, double sl, double tp) const
  {
   double risk   = MathAbs(entry - sl);
   double reward = MathAbs(tp - entry);
   if(risk == 0) return 0;
   return reward / risk;
  }

//+------------------------------------------------------------------+
double CalcLotFromRisk(double riskAmount, double slPips)
  {
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double lotStep   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(tickSize == 0 || lotStep == 0 || slPips <= 0) return minLot;

   double pipValue  = tickValue / tickSize;          // value of 1 pip per lot
   double riskPerLot = slPips * pipValue;

   double lot = riskAmount / riskPerLot;
   lot = MathFloor(lot / lotStep) * lotStep;
   lot = MathMax(lot, minLot);
   lot = MathMin(lot, maxLot);
   return lot;
  }

//+------------------------------------------------------------------+
bool CSR_TradeManager::OpenTrade(ENUM_ZONE_TYPE zoneType,
                                  double zoneHigh, double zoneLow,
                                  int zoneIdx,
                                  double &slPrice, double &tpPrice,
                                  double &lotSize)
  {
   if(CountOpenTrades() >= m_maxTrades)
     { if(LogLevel >= 1) Print("[TRADE] Max open trades reached"); return false; }

   double spreadPts = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spreadPts > MaxSpreadPoints)
     { if(LogLevel >= 2) Print("[TRADE] Spread too wide: ", spreadPts); return false; }

   double entryPrice, sl, tp;
   double slPts  = (m_slPoints  > 0) ? m_slPoints  : 150.0;
   double tpPts  = (m_tpPoints  > 0) ? m_tpPoints  : 300.0;

   ENUM_POSITION_TYPE posType;
   if(zoneType == ZONE_BUY)
     {
      posType   = POSITION_TYPE_BUY;
      entryPrice = zoneHigh + Point * 5;
      sl         = zoneLow  - g_pointsToPrice(slPts);
      tp         = entryPrice + g_pointsToPrice(tpPts);
     }
   else if(zoneType == ZONE_SELL)
     {
      posType   = POSITION_TYPE_SELL;
      entryPrice = zoneLow  - Point * 5;
      sl         = zoneHigh + g_pointsToPrice(slPts);
      tp         = entryPrice - g_pointsToPrice(tpPts);
     }
   else return false;

   slPrice = sl; tpPrice = tp;

   double rr = CalcRiskReward(entryPrice, sl, tp);
   if(rr < m_minRR || (m_maxRR > 0 && rr > m_maxRR))
     {
      if(LogLevel >= 1)
         PrintFormat("[TRADE] RR=%.2f not valid (min=%.2f max=%.2f)", rr, m_minRR, m_maxRR);
      return false;
     }

   double slPips     = g_priceToPoints(MathAbs(entryPrice - sl));
   double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * m_riskPercent / 100.0;
   double lot        = CalcLotFromRisk(riskAmount, slPips);

   slPrice  = sl;
   tpPrice  = tp;
   lotSize  = lot;

   STradeState st;
   bool result = OpenPosition(zoneType, sl, tp, lot, zoneIdx, posType, st);

   if(result)
     {
      st.entryPrice    = entryPrice;
      st.riskPips      = slPips;
      st.zoneIdx       = zoneIdx;
      st.posType       = posType;
      st.openTime      = TimeCurrent();

      if(m_usePartial)
        {
         st.partialTPPrice = (posType == POSITION_TYPE_BUY)
                             ? entryPrice + g_pointsToPrice(m_partialTPPips)
                             : entryPrice - g_pointsToPrice(m_partialTPPips);
         st.breakevenPrice = entryPrice;
        }

      m_states[m_stateCount++] = st;

      if(LogLevel >= 1)
         PrintFormat("[TRADE] OPENED %s lot=%.2f entry=%.5f SL=%.5f TP=%.5f RR=%.2f",
                     EnumToString(posType), lot, entryPrice, sl, tp, rr);
     }

   return result;
  }

//+------------------------------------------------------------------+
//|  OpenPosition — uses pending SELL STOP for sell entries          |
//|  SELL: entry below market, SL above entry, TP below entry       |
//+------------------------------------------------------------------+
bool CSR_TradeManager::OpenPosition(ENUM_ZONE_TYPE zoneType, double sl, double tp,
                                    double lot, int zoneIdx,
                                    ENUM_POSITION_TYPE posType,
                                    STradeState &stateOut)
  {
   string comment = m_commentPrefix + " Z" + IntegerToString(zoneIdx);

   // Normalize all prices to symbol digits
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   double entryNorm = (posType == POSITION_TYPE_BUY)
                      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                      : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Enforce minimum stop distance from broker
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double freezeLevel = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);

   if(posType == POSITION_TYPE_SELL)
     {
      double market = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double minSL = market + stopLevel * Point;
      if(sl <= market)
        {
         // SL must be above market by at least stopLevel
         sl = NormalizeDouble(minSL + Point * 5, _Digits);
        }
      // TP must be below entry for sell
      if(tp >= entryNorm) tp = NormalizeDouble(entryNorm - Point * 50, _Digits);
     }
   else  // POSITION_TYPE_BUY
     {
      double market = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double minSL = market - stopLevel * Point;
      if(sl >= market)
        {
         sl = NormalizeDouble(minSL - Point * 5, _Digits);
        }
      // TP must be above entry for buy
      if(tp <= entryNorm) tp = NormalizeDouble(entryNorm + Point * 50, _Digits);
     }

   // Re-check RR after adjustments
   double adjRR = CalcRiskReward(entryNorm, sl, tp);
   if(adjRR < m_minRR)
     {
      if(LogLevel >= 1)
         PrintFormat("[TRADE] Adjusted SL/TP violates min RR (%.2f < %.2f)", adjRR, m_minRR);
      return false;
     }

   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   bool result;
   if(posType == POSITION_TYPE_BUY)
      result = m_trade.Buy(lot, _Symbol, entryNorm, sl, tp, comment);
   else
     {
      // Use SELL STOP pending order for sell entries
      double price = NormalizeDouble(entryNorm - Point * 30, _Digits);  // stop price below market
      result = m_trade.SellStop(lot, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
     }

   if(result)
     {
      stateOut.ticket        = m_trade.ResultOrder();
      stateOut.entryPrice    = m_trade.ResultPrice();
      stateOut.stopLoss      = sl;
      stateOut.takeProfit    = tp;
      stateOut.partialHit    = false;
      stateOut.beTriggered   = false;
      stateOut.trailingActive= false;
      stateOut.bestPrice     = stateOut.entryPrice;
     }
   else
     {
      if(LogLevel >= 1)
         PrintFormat("[TRADE] OPEN FAILED err=%d Ask=%.5f Bid=%.5f SL=%.5f TP=%.5f stopLvl=%d",
                     GetLastError(),
                     SymbolInfoDouble(_Symbol, SYMBOL_ASK),
                     SymbolInfoDouble(_Symbol, SYMBOL_BID),
                     sl, tp, stopLevel);
     }

   (void)zoneType;
   return result;
  }

//+------------------------------------------------------------------+
void CSR_TradeManager::ManageTrades(void)
  {
   for(int i = 0; i < m_stateCount; i++)
     {
      if(m_states[i].ticket == 0) continue;

      // Select position by ticket
      if(!PositionSelectByTicket(m_states[i].ticket)) continue;

      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double currPrice = (posType == POSITION_TYPE_BUY)
                         ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      // Track best price
      if(posType == POSITION_TYPE_BUY)
         { if(currPrice > m_states[i].bestPrice) m_states[i].bestPrice = currPrice; }
      else
         { if(currPrice < m_states[i].bestPrice) m_states[i].bestPrice = currPrice; }

      CheckPartialTP(m_states[i]);
      CheckBreakeven(m_states[i]);
      CheckTrailing(m_states[i]);
     }
  }

//+------------------------------------------------------------------+
void CSR_TradeManager::CheckPartialTP(STradeState &s)
  {
   if(!m_usePartial || s.partialHit) return;
   if(!PositionSelectByTicket(s.ticket)) return;

   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double currPrice = (posType == POSITION_TYPE_BUY)
                      ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   bool triggered = (posType == POSITION_TYPE_BUY)
                    ? (currPrice >= s.partialTPPrice)
                    : (currPrice <= s.partialTPPrice);

   if(triggered)
     {
      double vol    = PositionGetDouble(POSITION_VOLUME);
      double closeL = vol * m_partialTPPct / 100.0;
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      closeL = MathMax(closeL, minLot);

      if(ClosePartial(s.ticket, closeL))
        {
         s.partialHit = true;
         s.partialClosePrice = currPrice;
         if(LogLevel >= 1)
            PrintFormat("[TRADE] PARTIAL TP hit @ %.5f, closed %.2f lots", currPrice, closeL);
        }
     }
  }

//+------------------------------------------------------------------+
void CSR_TradeManager::CheckBreakeven(STradeState &s)
  {
   if(!m_useBE || s.beTriggered || !s.partialHit) return;
   if(!PositionSelectByTicket(s.ticket)) return;

   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double currPrice = (posType == POSITION_TYPE_BUY)
                      ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double profitPts = (posType == POSITION_TYPE_BUY)
                      ? (currPrice - s.entryPrice)
                      : (s.entryPrice - currPrice);

   double beThrPts = g_pointsToPrice(m_beTriggerPips);

   if(profitPts >= beThrPts)
     {
      double newSL = (posType == POSITION_TYPE_BUY)
                     ? s.entryPrice + Point * 2   // slight buffer above entry
                     : s.entryPrice - Point * 2;

      if(ModifyPosition(s.ticket, newSL, s.takeProfit))
        {
         s.beTriggered = true;
         if(LogLevel >= 1)
            PrintFormat("[TRADE] BREAKEVEN set @ %.5f", newSL);
        }
     }
  }

//+------------------------------------------------------------------+
void CSR_TradeManager::CheckTrailing(STradeState &s)
  {
   if(!m_useTrail || !s.beTriggered) return;
   if(!PositionSelectByTicket(s.ticket)) return;

   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double currPrice = (posType == POSITION_TYPE_BUY)
                      ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double trailTrigger = g_pointsToPrice(m_trailStartPips);
   double profitPts = (posType == POSITION_TYPE_BUY)
                      ? (currPrice - s.entryPrice)
                      : (s.entryPrice - currPrice);

   if(profitPts < trailTrigger) return;

   s.trailingActive = true;

   double trailStep    = g_pointsToPrice(m_trailStepPips);
   double lockedPts    = trailTrigger + MathFloor((profitPts - trailTrigger) / trailStep) * trailStep;
   double newSL = (posType == POSITION_TYPE_BUY)
                  ? s.entryPrice + lockedPts
                  : s.entryPrice - lockedPts;

   double currSL = PositionGetDouble(POSITION_SL);
   bool improve = (posType == POSITION_TYPE_BUY)
                  ? (newSL > currSL)
                  : (newSL < currSL);

   if(improve) ModifyPosition(s.ticket, newSL, s.takeProfit);
  }

//+------------------------------------------------------------------+
bool CSR_TradeManager::ModifyPosition(ulong ticket, double sl, double tp)
  {
   return m_trade.PositionModify(ticket, sl, tp);
  }

//+------------------------------------------------------------------+
bool CSR_TradeManager::ClosePartial(ulong ticket, double lot)
  {
   return m_trade.PositionClosePartial(ticket, lot);
  }

//+------------------------------------------------------------------+
int CSR_TradeManager::CountOpenTrades(void)
  {
   int count = 0;
   int total  = PositionsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != m_magic) continue;
      count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
STradeState* CSR_TradeManager::GetState(int idx)
  {
   if(idx < 0 || idx >= m_stateCount) return NULL;
   return &m_states[idx];
  }

#endif
//+------------------------------------------------------------------+