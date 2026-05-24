//+------------------------------------------------------------------+
//|                         VolShield EA                             |
//|  Volatility-Adaptive Position Sizing (Anti-Martingale)           |
//|  Time-Weighted Exit | Signal Confidence Filter                   |
//|  By: Cuancux Algo Traders                                        |
//+------------------------------------------------------------------+
#property copyright "VolShield EA"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
#include <Arrays/ArrayDouble.mqh>
#include <Arrays/ArrayInt.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+

// --- General ---
input group "=== GENERAL ==="
input double   InpBaseLot        = 0.1;      // Base Lot Size
input int      InpMagicNumber    = 2026001;  // Magic Number
input string   InpComment        = "VolShield";

// --- Volatility ATR Settings ---
input group "=== VOLATILITY (ATR) ==="
input int      InpATRPeriod      = 14;        // ATR Period
input ENUM_APPLIED_PRICE InpATRPrice = PRICE_TYPICAL;
input double   InpATRHighThresh = 1.5;       // High ATR Multiplier (volatile = small lot)
input double   InpATRLowThresh  = 0.7;       // Low ATR Multiplier (quiet = normal lot)
input double   InpMinLotMult    = 0.3;       // Min lot multiplier at high volatility
input double   InpMaxLotMult    = 1.0;       // Max lot multiplier at low volatility

// --- Signal Confidence ---
input group "=== SIGNAL CONFIDENCE ==="
input int      InpRSIPeriod     = 14;        // RSI Period
input int      InpRSIBuyLevel   = 35;        // RSI Buy Threshold
input int      InpRSISellLevel  = 65;        // RSI Sell Threshold
input int      InpMACDFast      = 12;        // MACD Fast EMA
input int      InpMACDSlow      = 26;        // MACD Slow EMA
input int      InpMACDSignal    = 9;         // MACD Signal
input int      InpADXPeriod     = 14;        // ADX Period
input int      InpADXMin        = 20;        // Min ADX to trade (trend confirmation)
input double   InpConfThreshold = 0.55;       // Min Signal Confidence (0.0-1.0)

// --- Time-Weighted Exit ---
input group "=== TIME-WEIGHTED EXIT ==="
input int      InpMaxHoldBars   = 240;       // Max bars to hold (4hr on H1 = 4 bars, M15 = 16 bars)
input double   InpTimeExitRR    = -0.30;     // R:R threshold for time exit
input int      InpStagnantBars  = 6;         // Bars with no progress before force close
input double   InpMinMovePts    = 50;        // Min points to count as "progress"

// --- Take Profit & Trailing ---
input group "=== TP & TRAILING ==="
input double   InpBaseTP        = 2.0;       // Base TP in R (reward:risk)
input double   InpATRTPAdjust   = 0.5;       // ATR TP adjustment multiplier
input bool     InpUseTrail      = true;      // Enable Trailing Stop
input double   InpTrailStart    = 1.0;       // Trail starts at X*R profit
input double   InpTrailDist     = 0.5;       // Trail distance in R

// --- Risk Management ---
input group "=== RISK MANAGEMENT ==="
input double   InpMaxRisk       = 2.0;       // Max risk per trade (% of equity)
input int      InpMaxOpenTrades = 3;         // Max concurrent trades
input bool     InpCloseOnHighRisk = true;    // Emergency close on extreme volatility

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
CTrade         trade;
CArrayDouble   atrHistory;
CArrayDouble   confHistory;
datetime       lastTradeTime;
double         gAtrCurrent;
double         gAtrAverage;
double         gVolatilityRatio;
double         gSignalConfidence;
int            gPositionTicket = 0;

//+------------------------------------------------------------------+
//| EXPERT INITIALIZATION                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(50);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   // Warm up ATR
   double atr = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   if(atr == INVALID_HANDLE)
   {
      Print("[VolShield] ERROR: Failed to create ATR indicator");
      return INIT_FAILED;
   }
   
   // Initialize history
   for(int i = 0; i < 10; i++)
   {
      atrHistory.Add(0);
      confHistory.Add(0.5);
   }
   
   Print("[VolShield] EA Initialized - Magic: ", InpMagicNumber);
   Print("[VolShield] ATR Period: ", InpATRPeriod, 
          " | Conf Threshold: ", DoubleToString(InpConfThreshold,2),
          " | Max Hold: ", InpMaxHoldBars, " bars");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| EXPERT DEINITIALIZATION                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("[VolShield] EA Deinitialized - Reason: ", reason);
}

//+------------------------------------------------------------------+
//| EXPERT TICK FUNCTION                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Update market data
   UpdateMarketData();
   
   // Check for time-weighted exits on existing positions
   CheckTimeWeightedExit();
   
   // Check for trailing stop
   if(InpUseTrail)
      ManageTrailingStop();
   
   // Check for new entries
   if(CountOpenTrades() < InpMaxOpenTrades)
      TryOpenPosition();
}

//+------------------------------------------------------------------+
//| UPDATE MARKET DATA                                               |
//+------------------------------------------------------------------+
void UpdateMarketData()
{
   double atr = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   if(atr == INVALID_HANDLE) return;
   
   double atrVal[1];
   if(CopyBuffer(atr, 0, 0, 1, atrVal) <= 0) return;
   
   gAtrCurrent = atrVal[0];
   
   // Calculate average ATR over last 20 bars
   double atrArr[20];
   if(CopyBuffer(atr, 0, 0, 20, atrArr) > 0)
   {
      double sum = 0;
      for(int i = 0; i < 20; i++) sum += atrArr[i];
      gAtrAverage = sum / 20.0;
   }
   
   // Volatility ratio: >1 = high volatility, <1 = low volatility
   if(gAtrAverage > 0)
      gVolatilityRatio = gAtrCurrent / gAtrAverage;
   else
      gVolatilityRatio = 1.0;
   
   // Update ATR history
   atrHistory.Add(gAtrCurrent);
   if(atrHistory.Total() > 20) atrHistory.Delete(0);
   
   // Calculate signal confidence
   gSignalConfidence = CalculateSignalConfidence();
   confHistory.Add(gSignalConfidence);
   if(confHistory.Total() > 10) confHistory.Delete(0);
   
   // Indicator handles cleanup will be done automatically by MT5
}

//+------------------------------------------------------------------+
//| CALCULATE SIGNAL CONFIDENCE (0.0 - 1.0)                          |
//+------------------------------------------------------------------+
double CalculateSignalConfidence()
{
   double conf = 0.5; // Neutral
   
   //--- RSI Component ---
   double rsi = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
   if(rsi > 0)
   {
      double rsiConf = 0;
      if(rsi < InpRSIBuyLevel)
         rsiConf = (InpRSIBuyLevel - rsi) / InpRSIBuyLevel;  // Strong oversold = high conf
      else if(rsi > InpRSISellLevel)
         rsiConf = (rsi - InpRSISellLevel) / (100 - InpRSISellLevel); // Strong overbought = high conf
      
      conf += rsiConf * 0.35; // 35% weight
   }
   
   //--- MACD Component ---
   double macdMain[1], macdSignal[1];
   int macdHandle = iMACD(_Symbol, PERIOD_CURRENT, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   if(macdHandle != INVALID_HANDLE)
   {
      if(CopyBuffer(macdHandle, 0, 0, 1, macdMain) > 0 &&
         CopyBuffer(macdHandle, 1, 0, 1, macdSignal) > 0)
      {
         double macdConf = 0;
         double spread = gAtrCurrent * 0.2;
         if(macdMain[0] > macdSignal[0] + spread)
            macdConf = MathMin(1.0, macdMain[0] / (gAtrCurrent * 0.5)); // Bullish
         else if(macdMain[0] < macdSignal[0] - spread)
            macdConf = MathMin(1.0, MathAbs(macdMain[0]) / (gAtrCurrent * 0.5)); // Bearish
         
         conf += macdConf * 0.35; // 35% weight
      }
   }
   
   //--- ADX Trend Strength Component ---
   double adx = iADX(_Symbol, PERIOD_CURRENT, InpADXPeriod);
   if(adx > 0)
   {
      double adxConf = 0;
      if(adx >= InpADXMin)
         adxConf = MathMin(1.0, (adx - InpADXMin) / (60 - InpADXMin));
      
      conf += adxConf * 0.20; // 20% weight
      // If ADX < Min, reduce confidence (no clear trend)
      if(adx < InpADXMin && conf > 0.3)
         conf *= 0.5;
   }
   
   //--- Volatility Filter ---
   // High volatility reduces confidence (less reliable signals)
   if(gVolatilityRatio > InpATRHighThresh)
   {
      conf *= 0.7; // Reduce by 30%
      Print("[VolShield] High volatility detected (", DoubleToString(gVolatilityRatio,2),
            ") - Confidence reduced to: ", DoubleToString(conf,2));
   }
   
   // Clamp to 0-1
   conf = MathMax(0.0, MathMin(1.0, conf));
   
   return conf;
}

//+------------------------------------------------------------------+
//| VOLATILITY-ADAPTIVE LOT SIZING                                   |
//+------------------------------------------------------------------+
double CalculateAdaptiveLot()
{
   double baseLot = InpBaseLot;
   double lotMultiplier = 1.0;
   
   // High ATR (volatile market) -> smaller lot
   if(gVolatilityRatio > InpATRHighThresh)
   {
      // Scale down: higher ATR = more reduction
      double excess = gVolatilityRatio - InpATRHighThresh;
      lotMultiplier = InpMinLotMult - (excess * 0.2);
      lotMultiplier = MathMax(InpMinLotMult * 0.5, lotMultiplier); // Floor at 50% of min
      
      Print("[VolShield] HIGH VOLATILITY - Lot reduced: ",
            DoubleToString(lotMultiplier,2), "x | ATR Ratio: ",
            DoubleToString(gVolatilityRatio,2));
   }
   // Low ATR (quiet market) -> normal or slightly larger lot
   else if(gVolatilityRatio < InpATRLowThresh)
   {
      lotMultiplier = InpMaxLotMult;
      Print("[VolShield] LOW VOLATILITY - Normal lot | ATR Ratio: ",
            DoubleToString(gVolatilityRatio,2));
   }
   // Normal ATR range
   else
   {
      lotMultiplier = 0.8;
   }
   
   // Apply risk-based lot sizing
   double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (InpMaxRisk / 100.0);
   double riskBasedLot = riskAmount / (gAtrCurrent * 10 * _Point);
   riskBasedLot = MathMax(riskBasedLot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));
   riskBasedLot = MathMin(riskBasedLot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));
   
   // Take the smaller of: adaptive lot or risk-based lot
   double adaptiveLot = baseLot * lotMultiplier;
   double finalLot = MathMin(adaptiveLot, riskBasedLot * 1.5);
   
   // Round to lot step
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   finalLot = MathRound(finalLot / lotStep) * lotStep;
   
   Print("[VolShield] Final Lot: ", DoubleToString(finalLot,2),
         " | Multiplier: ", DoubleToString(lotMultiplier,2),
         " | Risk Amount: $", DoubleToString(riskAmount,2));
   
   return finalLot;
}

//+------------------------------------------------------------------+
//| CALCULATE ADAPTIVE STOP LOSS (in R)                              |
//+------------------------------------------------------------------+
double CalculateStopLoss(double &slPts, ENUM_ORDER_TYPE type)
{
   double atrSL = gAtrCurrent * 1.5; // Base SL = 1.5 ATR
   
   // Adjust SL based on volatility
   if(gVolatilityRatio > InpATRHighThresh)
      atrSL *= 1.3; // Wider SL in volatile market (avoid premature knockout)
   else if(gVolatilityRatio < InpATRLowThresh)
      atrSL *= 0.8; // Tighter SL in quiet market
   
   slPts = atrSL / _Point;
   return atrSL;
}

//+------------------------------------------------------------------+
//| TRY OPEN POSITION                                                |
//+------------------------------------------------------------------+
void TryOpenPosition()
{
   // Throttle: no new trades within 3 bars of last trade
   if(lastTradeTime > 0)
   {
      datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      if(currentTime - lastTradeTime < 3 * PeriodSeconds(PERIOD_CURRENT))
         return;
   }
   
   // Check signal confidence threshold
   if(gSignalConfidence < InpConfThreshold)
   {
      Print("[VolShield] Signal confidence too low: ",
            DoubleToString(gSignalConfidence,2),
            " < ", DoubleToString(InpConfThreshold,2));
      return;
   }
   
   // Get indicator values for directional decision
   double rsi = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
   double macdMain[1], macdSignal[1];
   int macdHandle = iMACD(_Symbol, PERIOD_CURRENT, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   
   bool buySignal = false;
   bool sellSignal = false;
   
   // BUY: RSI oversold + MACD bullish cross + ADX confirms uptrend
   if(rsi > 0 && rsi < InpRSIBuyLevel)
   {
      if(macdHandle != INVALID_HANDLE)
      {
         if(CopyBuffer(macdHandle, 0, 0, 1, macdMain) > 0 &&
            CopyBuffer(macdHandle, 1, 0, 1, macdSignal) > 0)
         {
            if(macdMain[0] > macdSignal[0])
            {
               double adx = iADX(_Symbol, PERIOD_CURRENT, InpADXPeriod);
               if(adx > 0 && adx >= InpADXMin)
                  buySignal = true;
               else if(adx > 0) // Weak ADX but RSI + MACD strong
                  buySignal = true; // Still allow with warning
            }
         }
      }
   }
   
   // SELL: RSI overbought + MACD bearish cross + ADX confirms downtrend
   if(rsi > 0 && rsi > InpRSISellLevel)
   {
      if(macdHandle != INVALID_HANDLE)
      {
         if(CopyBuffer(macdHandle, 0, 0, 1, macdMain) > 0 &&
            CopyBuffer(macdHandle, 1, 0, 1, macdSignal) > 0)
         {
            if(macdMain[0] < macdSignal[0])
            {
               double adx = iADX(_Symbol, PERIOD_CURRENT, InpADXPeriod);
               if(adx > 0 && adx >= InpADXMin)
                  sellSignal = true;
               else if(adx > 0)
                  sellSignal = true;
            }
         }
      }
   }
   
   if(!buySignal && !sellSignal)
      return;
   
   // Calculate lot
   double lot = CalculateAdaptiveLot();
   if(lot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
      return;
   
   // Calculate SL
   double slPts;
   double slDist = CalculateStopLoss(slPts, buySignal ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double price = buySignal ? ask : bid;
   
   double slPrice;
   if(buySignal)
      slPrice = ask - slDist;
   else
      slPrice = bid + slDist;
   
   // Normalize prices
   slPrice = NormalizeDouble(slPrice, _Digits);
   price = NormalizeDouble(price, _Digits);
   
   // Calculate TP based on ATR
   double tpDist = slDist * InpBaseTP;
   double tpPrice;
   if(buySignal)
      tpPrice = ask + tpDist + (gAtrCurrent * InpATRTPAdjust);
   else
      tpPrice = bid - tpDist - (gAtrCurrent * InpATRTPAdjust);
   tpPrice = NormalizeDouble(tpPrice, _Digits);
   
   // Execute trade
   bool success = false;
   if(buySignal)
      success = trade.Buy(lot, _Symbol, price, slPrice, tpPrice, InpComment);
   else
      success = trade.Sell(lot, _Symbol, price, slPrice, tpPrice, InpComment);
   
   if(success)
   {
      lastTradeTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      uint resultCode = trade.ResultRetcode();
      gPositionTicket = (int)trade.ResultOrder();
      
      Print("[VolShield] === TRADE OPENED ===");
      Print("  Direction: ", buySignal ? "BUY" : "SELL");
      Print("  Lot: ", DoubleToString(lot,2),
            " | ATR: ", DoubleToString(gAtrCurrent,5),
            " | VolRatio: ", DoubleToString(gVolatilityRatio,2));
      Print("  Confidence: ", DoubleToString(gSignalConfidence,2));
      Print("  SL: ", DoubleToString(slPrice,_Digits),
            " | TP: ", DoubleToString(tpPrice,_Digits));
      Print("  Ticket: ", gPositionTicket);
   }
   else
   {
      Print("[VolShield] TRADE FAILED - Error: ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| CHECK TIME-WEIGHTED EXIT                                         |
//| Core concept: Bukan exit karena price hit SL/TP                   |
//| Tapi exit berdasarkan: waktu + kondisi posisi                    |
//+------------------------------------------------------------------+
void CheckTimeWeightedExit()
{
   if(!PositionSelect(_Symbol)) return;
   
   // Get position info
   ulong ticket     = PositionGetTicket(0);
   double openPrice= PositionGetDouble(POSITION_PRICE_OPEN);
   datetime openTime= (datetime)PositionGetInteger(POSITION_TIME);
   double volume   = PositionGetDouble(POSITION_VOLUME);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   
   int barsOpen = iBarShift(_Symbol, PERIOD_CURRENT, openTime);
   if(barsOpen < 0) barsOpen = 0;
   
   // Calculate current P&L in points
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   double slPts;
   CalculateStopLoss(slPts, posType == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   double slDistance = slPts * _Point;
   
   double pnlPoints = 0;
   if(posType == POSITION_TYPE_BUY)
      pnlPoints = (currentPrice - openPrice) / _Point;
   else
      pnlPoints = (openPrice - currentPrice) / _Point;
   
   // Current R:R (negative = loss, positive = profit)
   double currentRR = (pnlPoints * _Point) / slDistance;
   
   // Get entry bar and check stagnant movement
   static datetime lastProgressCheck = 0;
   static double lastProgressPrice = 0;
   
   if(lastProgressCheck == 0)
   {
      lastProgressCheck = TimeCurrent();
      lastProgressPrice = openPrice;
   }
   
   bool isStagnant = false;
   double priceMovement = 0;
   if(posType == POSITION_TYPE_BUY)
      priceMovement = currentPrice - lastProgressPrice;
   else
      priceMovement = lastProgressPrice - currentPrice;
   
   if(priceMovement < InpMinMovePts * _Point)
      isStagnant = true;
   
   Print("[VolShield] Position Check | Bars: ", barsOpen,
         " | RR: ", DoubleToString(currentRR,2),
         " | Stagnant: ", isStagnant ? "YES" : "NO");
   
   //--- RULE 1: TIME EXIT ---
   // After MaxHoldBars and still in loss beyond TimeExitRR
   if(barsOpen >= InpMaxHoldBars)
   {
      if(currentRR <= InpTimeExitRR)
      {
         ClosePosition(ticket, "TIME EXIT: Max hold reached + loss threshold");
         ResetProgress();
         return;
      }
      else if(currentRR > 0.5)
      {
         // In profit - extend hold, but check other rules
         Print("[VolShield] Position held past max bars - in profit, continuing...");
      }
   }
   
   //--- RULE 2: STAGNANT EXIT ---
   // Position not moving in direction of trade for stagnant bars
   if(barsOpen >= InpStagnantBars && isStagnant)
   {
      if(currentRR <= 0) // In loss AND stagnant
      {
         ClosePosition(ticket, "STAGNANT EXIT: No progress in loss");
         ResetProgress();
         return;
      }
   }
   
   //--- RULE 3: EMERGENCY HIGH VOLATILITY EXIT ---
   if(InpCloseOnHighRisk && gVolatilityRatio > 2.5)
   {
      if(currentRR <= 0.1) // Small profit or loss
      {
         ClosePosition(ticket, "EMERGENCY: Extreme volatility - protecting capital");
         ResetProgress();
         return;
      }
   }
   
   // Update progress checkpoint every bar
   if(iBarShift(_Symbol, PERIOD_CURRENT, lastProgressCheck) >= 1)
   {
      lastProgressCheck = TimeCurrent();
      lastProgressPrice = currentPrice;
   }
}

//+------------------------------------------------------------------+
//| MANAGE TRAILING STOP                                             |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   if(!PositionSelect(_Symbol)) return;
   
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   double slPts;
   double slDistance = CalculateStopLoss(slPts, 
      PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   
   double currentRR = 0;
   double slLevel = 0;
   
   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
   {
      currentRR = (currentPrice - openPrice) / slDistance;
      slLevel = PositionGetDouble(POSITION_SL);
      
      // Trail starts at TrailStart*R profit
      double triggerProfit = slDistance * InpTrailStart;
      if(currentPrice - openPrice >= triggerProfit)
      {
         double newSL = currentPrice - (slDistance * InpTrailDist);
         if(newSL > slLevel && newSL > openPrice)
         {
            trade.PositionModify(_Symbol, newSL, PositionGetDouble(POSITION_TP));
            Print("[VolShield] TRAIL: New SL = ", DoubleToString(newSL, _Digits));
         }
      }
   }
   else
   {
      currentRR = (openPrice - currentPrice) / slDistance;
      slLevel = PositionGetDouble(POSITION_SL);
      
      double triggerProfit = slDistance * InpTrailStart;
      if(openPrice - currentPrice >= triggerProfit)
      {
         double newSL = currentPrice + (slDistance * InpTrailDist);
         if(newSL < slLevel || slLevel == 0)
         {
            trade.PositionModify(_Symbol, newSL, PositionGetDouble(POSITION_TP));
            Print("[VolShield] TRAIL: New SL = ", DoubleToString(newSL, _Digits));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| CLOSE POSITION WITH LOGGING                                      |
//+------------------------------------------------------------------+
void ClosePosition(ulong ticket, string reason)
{
   if(!trade.PositionClose(ticket))
   {
      Print("[VolShield] CLOSE FAILED - Ticket: ", ticket,
            " | Error: ", GetLastError());
   }
   else
   {
      double pnl = PositionGetDouble(POSITION_PROFIT);
      Print("[VolShield] === POSITION CLOSED ===");
      Print("  Ticket: ", ticket);
      Print("  Reason: ", reason);
      Print("  P&L: $", DoubleToString(pnl, 2));
   }
}

//+------------------------------------------------------------------+
//| RESET PROGRESS TRACKER                                           |
//+------------------------------------------------------------------+
void ResetProgress()
{
   lastProgressCheck = 0;
   lastProgressPrice = 0;
   gPositionTicket = 0;
}

//+------------------------------------------------------------------+
//| COUNT OPEN TRADES                                                |
//+------------------------------------------------------------------+
int CountOpenTrades()
{
   int count = 0;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| ON_TIMER (optional - run checks every minute)                    |
//+------------------------------------------------------------------+
void OnTimer()
{
   UpdateMarketData();
   CheckTimeWeightedExit();
   
   if(InpUseTrail)
      ManageTrailingStop();
}
//+------------------------------------------------------------------+