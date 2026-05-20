//+------------------------------------------------------------------+
//|        EA_SMC_FVG_Hybrid.mq5                                     |
//|        SMC + FVG Hybrid Trading System                            |
//|        v1.0 - Institutional Grade                                 |
//+------------------------------------------------------------------+
#property copyright "Omon-Omon Algo Traders"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| INCLUDES                                                         |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <Indicators/Indicators.mqh>

//+------------------------------------------------------------------+
//| INPUTS - SMC SETTINGS                                            |
//+------------------------------------------------------------------+
group("SMC Settings")
input int      InpSwingPeriod    = 5;          // Swing Pivot Period
input int      InpAtrPeriod      = 14;         // ATR Period
input double   InpAtrMultSL      = 1.5;        // ATR SL Multiplier
input double   InpAtrMultTP      = 2.5;        // ATR TP Multiplier
input bool     InpUseVolFilter   = true;       // Volume Spike Filter
input double   InpVolMultiplier  = 1.5;        // Volume Spike Multiplier

group("FVG Settings")
input int      InpFvgLookback    = 3;          // FVG Lookback Bars
input double   InpFvgThreshold   = 0.5;        // FVG Min Gap (% ATR)
input int      InpMaxFVGs        = 10;         // Max Stored FVGs

group("Trade Management")
input double   InpRiskPercent    = 1.0;        // Risk per Trade (%)
input double   InpMaxLot         = 2.0;        // Max Lot Size
input int      InpMaxPositions   = 3;          // Max Open Positions
input int      InpMagicNumber    = 2026001;    // Magic Number
input int      InpSlippage       = 3;          // Slippage (points)

group("HTF Settings")
input ENUM_TIMEFRAMES InpHtf1    = PERIOD_D1;  // HTF-1 (Daily Bias)
input ENUM_TIMEFRAMES InpHtf2    = PERIOD_H4;  // HTF-2 (Structure)

group("EA Control")
input bool     InpAutoMode       = true;        // Auto Trading Mode
input ENUM_LOT_MODE InpLotMode   = LOT_MODE_RISK;// Lot Mode
input double   InpFixedLot       = 0.01;        // Fixed Lot (if not risk mode)

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
CTrade          trade;
CPositionInfo   position;
COrderInfo      order;

CiATR          *atrHandle;
CiMA           *maVolHandle;
CiEMA          *ema8Handle, *ema21Handle, *ema50Handle, *ema200Handle;

// HTF handles
CiEMA          *htf1Ema50Handle, *htf1Ema200Handle;
CiEMA          *htf2Ema50Handle, *htf2Ema200Handle;
CiClose        *htf1CloseHandle, *htf2CloseHandle;

datetime       lastBarTime       = 0;
datetime       lastTradeTime     = 0;
int            spreadFilter      = 50;          // Max spread (points)

//+------------------------------------------------------------------+
//| ENUMS & STRUCTS                                                  |
//+------------------------------------------------------------------+
enum ENUM_MARKET_MODE { MODE_NEUTRAL, MODE_BULL, MODE_BEAR };
enum ENUM_TRADE_MODE { MODE_SWING, MODE_SCALP, MODE_HYBRID };

struct SFVG {
   datetime time;
   double   top;
   double   bottom;
   string   direction;
   double   size;
};

struct SSwingPoint {
   double   price;
   datetime time;
   int      type; // 1=high, -1=low
};

struct STradeSetup {
   ENUM_MARKET_MODE direction;
   double           entryPrice;
   double           stopLoss;
   double           takeProfit;
   double           lotSize;
   double           rrRatio;
   int              confidence;
   ENUM_TRADE_MODE  tradeMode;
   string           reasoning;
};

//+------------------------------------------------------------------+
//| STORAGE                                                          |
//+------------------------------------------------------------------+
SFVG           gBullishFVGs[];
SFVG           gBearishFVGs[];
SSwingPoint    gLastSwingHigh;
SSwingPoint    gLastSwingLow;
int            gBosDir = 0;        // 1=bull, -1=bear, 0=neutral
double         gBosLevel = 0;
bool           gBullCHoCH = false;
bool           gBearCHoCH = false;
bool           gBullBOS = false;
bool           gBearBOS = false;

//+------------------------------------------------------------------+
//| INIT                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialize CTrade
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetComment("SMC+FVG Hybrid EA v1.0");

   //--- Create indicator handles
   atrHandle      = new CiATR(InpAtrPeriod);
   maVolHandle    = new CiMA(20, MODE_SMA, PRICE_VOLUME);
   ema8Handle     = new CiEMA(8);
   ema21Handle    = new CiEMA(21);
   ema50Handle    = new CiEMA(50);
   ema200Handle   = new CiEMA(200);

   // HTF handles
   htf1Ema50Handle   = new CiEMA(InpHtf1, 50);
   htf1Ema200Handle  = new CiEMA(InpHtf1, 200);
   htf2Ema50Handle   = new CiEMA(InpHtf2, 50);
   htf2Ema200Handle  = new CiEMA(InpHtf2, 200);
   htf1CloseHandle   = new CiClose(InpHtf1);
   htf2CloseHandle   = new CiClose(InpHtf2);

   //--- Check handles
   if(!CheckHandles(atrHandle, maVolHandle, ema8Handle, ema21Handle,
                    ema50Handle, ema200Handle,
                    htf1Ema50Handle, htf1Ema200Handle,
                    htf2Ema50Handle, htf2Ema200Handle,
                    htf1CloseHandle, htf2CloseHandle)) {
      Print("ERROR: Failed to create indicator handles!");
      return INIT_FAILED;
   }

   //--- Initialize swing points
   gLastSwingHigh.price = 0;
   gLastSwingHigh.time  = 0;
   gLastSwingHigh.type  = 0;
   gLastSwingLow.price  = 0;
   gLastSwingLow.time   = 0;
   gLastSwingLow.type   = 0;

   Print("✅ SMC+FVG Hybrid EA Initialized");
   Print("   Symbol: ", Symbol());
   Print("   Spread Filter: ", spreadFilter, " points");
   Print("   Risk: ", InpRiskPercent, "%");
   Print("   Max Positions: ", InpMaxPositions);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINIT                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Delete handles
   SafeDelete(atrHandle);
   SafeDelete(maVolHandle);
   SafeDelete(ema8Handle);
   SafeDelete(ema21Handle);
   SafeDelete(ema50Handle);
   SafeDelete(ema200Handle);
   SafeDelete(htf1Ema50Handle);
   SafeDelete(htf1Ema200Handle);
   SafeDelete(htf2Ema50Handle);
   SafeDelete(htf2Ema200Handle);
   SafeDelete(htf1CloseHandle);
   SafeDelete(htf2CloseHandle);

   Comment("");
}

//+------------------------------------------------------------------+
//| TICK                                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Wait for new bar
   if(!IsNewBar()) return;

   //--- Check spread
   if(CheckSpreadTooHigh()) return;

   //--- Update indicators data
   if(!RefreshIndicators()) return;

   //--- Core analysis
   UpdateSwingPoints();
   DetectBOS();
   DetectFVG();
   DetectCHoCH();

   //--- Generate setup
   STradeSetup setup = GenerateTradeSetup();

   //--- Print dashboard
   PrintDashboard(setup);

   //--- Auto trading
   if(InpAutoMode) {
      ManageTrades(setup);
      ExecuteSetup(setup);
   }
}

//+------------------------------------------------------------------+
//| IS NEW BAR                                                       |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBarTime = iTime(Symbol(), PERIOD_CURRENT, 0);
   if(currentBarTime != lastBarTime) {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| CHECK SPREAD TOO HIGH                                            |
//+------------------------------------------------------------------+
bool CheckSpreadTooHigh()
{
   int spread = (int)SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);
   return (spread > spreadFilter);
}

//+------------------------------------------------------------------+
//| REFRESH INDICATORS                                               |
//+------------------------------------------------------------------+
bool RefreshIndicators()
{
   return atrHandle.Handle() != INVALID_HANDLE
       && maVolHandle.Handle() != INVALID_HANDLE
       && ema8Handle.Handle() != INVALID_HANDLE
       && ema21Handle.Handle() != INVALID_HANDLE
       && ema50Handle.Handle() != INVALID_HANDLE
       && ema200Handle.Handle() != INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| GET VALUES                                                       |
//+------------------------------------------------------------------+
double GetATR(int shift=1) { return atrHandle.GetData(shift); }
double GetVolMA(int shift=1) { return maVolHandle.GetData(shift); }
double GetEma8(int shift=1) { return ema8Handle.GetData(shift); }
double GetEma21(int shift=1) { return ema21Handle.GetData(shift); }
double GetEma50(int shift=1) { return ema50Handle.GetData(shift); }
double GetEma200(int shift=1) { return ema200Handle.GetData(shift); }

double GetHtf1Ema50(int shift=1) { return htf1Ema50Handle.GetData(shift); }
double GetHtf1Ema200(int shift=1) { return htf1Ema200Handle.GetData(shift); }
double GetHtf2Ema50(int shift=1) { return htf2Ema50Handle.GetData(shift); }
double GetHtf2Ema200(int shift=1) { return htf2Ema200Handle.GetData(shift); }
double GetHtf1Close(int shift=1) { return htf1CloseHandle.GetData(shift); }
double GetHtf2Close(int shift=1) { return htf2CloseHandle.GetData(shift); }

//+------------------------------------------------------------------+
//| VOLUME SPIKE CHECK                                               |
//+------------------------------------------------------------------+
bool IsVolumeSpike()
{
   if(!InpUseVolFilter) return true;
   
   double vol = (double)Volume(0);
   double volMa = GetVolMA(1);
   
   return (vol > volMa * InpVolMultiplier);
}

//+------------------------------------------------------------------+
//| UPDATE SWING POINTS                                              |
//+------------------------------------------------------------------+
void UpdateSwingPoints()
{
   double high0  = High(1);
   double high1  = High(2);
   double high2  = High(3);
   double low0   = Low(1);
   double low1   = Low(2);
   double low2   = Low(3);
   double close0 = Close(1);
   
   //--- Swing High: high[1] is highest of surrounding bars
   if(high1 > high0 && high1 > high2) {
      gLastSwingHigh.price = high1;
      gLastSwingHigh.time  = iTime(Symbol(), PERIOD_CURRENT, 2);
      gLastSwingHigh.type  = 1;
   }
   
   //--- Swing Low: low[1] is lowest of surrounding bars
   if(low1 < low0 && low1 < low2) {
      gLastSwingLow.price = low1;
      gLastSwingLow.time  = iTime(Symbol(), PERIOD_CURRENT, 2);
      gLastSwingLow.type  = -1;
   }
}

//+------------------------------------------------------------------+
//| DETECT BOS                                                       |
//+------------------------------------------------------------------+
void DetectBOS()
{
   double close0 = Close(0);
   double high0  = High(0);
   double low0   = Low(0);
   
   //--- Reset flags
   gBullBOS = false;
   gBearBOS = false;
   
   //--- Bull BOS: close above last swing high
   if(gLastSwingHigh.price > 0 && close0 > gLastSwingHigh.price && gBosDir != 1) {
      gBosDir = 1;
      gBosLevel = close0;
      gBullBOS = true;
      Print("🟢 BULL BOS DETECTED at ", DoubleToStr(close0, _Digits));
   }
   
   //--- Bear BOS: close below last swing low
   if(gLastSwingLow.price > 0 && close0 < gLastSwingLow.price && gBosDir != -1) {
      gBosDir = -1;
      gBosLevel = close0;
      gBearBOS = true;
      Print("🔴 BEAR BOS DETECTED at ", DoubleToStr(close0, _Digits));
   }
}

//+------------------------------------------------------------------+
//| DETECT FVG                                                       |
//+------------------------------------------------------------------+
void DetectFVG()
{
   double atrVal = GetATR(1);
   double threshold = atrVal * InpFvgThreshold / 100.0;
   
   //--- Index reference: bar 1 = current, bar 2 = 1 bar ago, bar 3 = 2 bars ago
   // FVG detection: candle N high < candle N-2 low (bullish FVG)
   //               candle N low  > candle N-2 high (bearish FVG)
   
   double high0  = High(0);
   double high1  = High(1);
   double high2  = High(2);
   double low0   = Low(0);
   double low1   = Low(1);
   double low2   = Low(2);
   double mid1   = (High(1) + Low(1)) / 2.0;
   
   //--- Bullish FVG: low of current candle > high 2 bars ago
   double bullGap = low0 - high2;
   if(bullGap > threshold && bullGap > 0) {
      SFVG fvg;
      fvg.time      = iTime(Symbol(), PERIOD_CURRENT, 0);
      fvg.top       = high1; // candle 1 body top
      fvg.bottom    = MathMax(low0, low1);
      fvg.direction = "bullish";
      fvg.size      = bullGap;
      
      ArrayResize(gBullishFVGs, ArraySize(gBullishFVGs) + 1);
      gBullishFVGs[ArraySize(gBullishFVGs) - 1] = fvg;
      
      //--- Keep max FVGs
      if(ArraySize(gBullishFVGs) > InpMaxFVGs) {
         ArrayCopy(gBullishFVGs, gBullishFVGs, 0, 1, ArraySize(gBullishFVGs) - 1);
         ArrayResize(gBullishFVGs, InpMaxFVGs);
      }
      
      Print("🔵 BULLISH FVG detected: ", DoubleToStr(fvg.bottom, _Digits),
            " - ", DoubleToStr(fvg.top, _Digits),
            " Size: ", DoubleToStr(fvg.size, _Digits));
   }
   
   //--- Bearish FVG: high of current candle < low 2 bars ago
   double bearGap = low2 - high0;
   if(bearGap > threshold && bearGap > 0) {
      SFVG fvg;
      fvg.time      = iTime(Symbol(), PERIOD_CURRENT, 0);
      fvg.top       = MathMin(high0, high1);
      fvg.bottom    = low1; // candle 1 body bottom
      fvg.direction = "bearish";
      fvg.size      = bearGap;
      
      ArrayResize(gBearishFVGs, ArraySize(gBearishFVGs) + 1);
      gBearishFVGs[ArraySize(gBearishFVGs) - 1] = fvg;
      
      if(ArraySize(gBearishFVGs) > InpMaxFVGs) {
         ArrayCopy(gBearishFVGs, gBearishFVGs, 0, 1, ArraySize(gBearishFVGs) - 1);
         ArrayResize(gBearishFVGs, InpMaxFVGs);
      }
      
      Print("🔴 BEARISH FVG detected: ", DoubleToStr(fvg.bottom, _Digits),
            " - ", DoubleToStr(fvg.top, _Digits),
            " Size: ", DoubleToStr(fvg.size, _Digits));
   }
}

//+------------------------------------------------------------------+
//| DETECT CHoCH                                                     |
//+------------------------------------------------------------------+
void DetectCHoCH()
{
   double close0 = Close(0);
   
   gBullCHoCH = false;
   gBearCHoCH = false;
   
   //--- Bull CHoCH: Bull BOS then price breaks below last swing low
   if(gBosDir == 1 && gLastSwingLow.price > 0 && close0 < gLastSwingLow.price) {
      gBullCHoCH = true;
      Print("🟡 BULL CHoCH DETECTED - Bull trend invalidated, potential reversal");
   }
   
   //--- Bear CHoCH: Bear BOS then price breaks above last swing high
   if(gBosDir == -1 && gLastSwingHigh.price > 0 && close0 > gLastSwingHigh.price) {
      gBearCHoCH = true;
      Print("🟡 BEAR CHoCH DETECTED - Bear trend invalidated, potential reversal");
   }
}

//+------------------------------------------------------------------+
//| GET HTF BIAS                                                     |
//+------------------------------------------------------------------+
ENUM_MARKET_MODE GetHtfBias()
{
   double htf1Close = GetHtf1Close(1);
   double htf1Ema50 = GetHtf1Ema50(1);
   double htf1Ema200= GetHtf1Ema200(1);
   
   if(htf1Close > htf1Ema50 && htf1Ema50 > htf1Ema200) return MODE_BULL;
   if(htf1Close < htf1Ema50 && htf1Ema50 < htf1Ema200) return MODE_BEAR;
   return MODE_NEUTRAL;
}

//+------------------------------------------------------------------+
//| DETECT TRADE MODE                                                |
//+------------------------------------------------------------------+
ENUM_TRADE_MODE DetectTradeMode()
{
   double atrVal  = GetATR(1);
   double close0  = Close(0);
   double volRatio = atrVal / close0 * 100.0;
   
   //--- Count HTF alignment
   int alignment = 0;
   alignment += (GetHtf1Close(1) > GetHtf1Ema50(1))  ? 1 : -1;
   alignment += (GetHtf2Close(1) > GetHtf2Ema50(1))  ? 1 : -1;
   alignment += (GetHtf1Close(1) > GetHtf1Ema200(1)) ? 1 : -1;
   alignment += (GetHtf2Close(1) > GetHtf2Ema200(1)) ? 1 : -1;
   
   if(alignment >= 3 && volRatio < 0.3) return MODE_HYBRID;
   if(volRatio >= 0.3) return MODE_SCALP;
   return MODE_SWING;
}

//+------------------------------------------------------------------+
//| GET DIRECTION BIAS (scoring)                                     |
//+------------------------------------------------------------------+
ENUM_MARKET_MODE GetBias(out int &score)
{
   score = 0;
   ENUM_MARKET_MODE bias = MODE_NEUTRAL;
   
   double ema8   = GetEma8(1);
   double ema21  = GetEma21(1);
   double ema50  = GetEma50(1);
   double ema200 = GetEma200(1);
   double close0 = Close(0);
   double open0  = Open(0);
   
   //--- EMA alignment
   score += (ema8 > ema21)  ? 1 : -1;
   score += (ema21 > ema50) ? 1 : -1;
   score += (close0 > ema50)? 1 : -1;
   score += (ema50 > ema200)? 1 : -1;
   score += (close0 > open0)? 1 : -1;
   
   //--- HTF contribution
   ENUM_MARKET_MODE htfBias = GetHtfBias();
   score += (htfBias == MODE_BULL) ? 2 : (htfBias == MODE_BEAR) ? -2 : 0;
   
   //--- Structure contribution
   score += (gBosDir == 1) ? 2 : (gBosDir == -1) ? -2 : 0;
   score += gBullCHoCH ? 1 : gBearCHoCH ? -1 : 0;
   
   //--- Volume
   score += IsVolumeSpike() ? 1 : -1;
   
   //--- Convert to bias
   if(score >= 3) bias = MODE_BULL;
   else if(score <= -3) bias = MODE_BEAR;
   else bias = MODE_NEUTRAL;
   
   return bias;
}

//+------------------------------------------------------------------+
//| GENERATE TRADE SETUP                                             |
//+------------------------------------------------------------------+
STradeSetup GenerateTradeSetup()
{
   STradeSetup setup;
   ZeroMemory(setup);
   
   int score = 0;
   ENUM_MARKET_MODE bias = GetBias(score);
   ENUM_TRADE_MODE tradeMode = DetectTradeMode();
   double atrVal = GetATR(1);
   double close0 = Close(0);
   
   setup.tradeMode = tradeMode;
   
   //--- BULLISH SETUP
   if(bias == MODE_BULL && (ArraySize(gBullishFVGs) > 0 || gBullCHoCH || gBullBOS)) {
      setup.direction = MODE_BULL;
      
      // Entry: FVG bottom or close
      if(ArraySize(gBullishFVGs) > 0) {
         SFVG lastFvg = gBullishFVGs[ArraySize(gBullishFVGs) - 1];
         setup.entryPrice = NormalizeDouble(lastFvg.bottom, _Digits);
      } else {
         setup.entryPrice = NormalizeDouble(close0, _Digits);
      }
      
      // SL: below swing low or close - ATR*SL_mult
      double slDist = atrVal * InpAtrMultSL;
      if(gLastSwingLow.price > 0) {
         setup.stopLoss = NormalizeDouble(MathMin(gLastSwingLow.price - atrVal * 0.5, close0 - slDist), _Digits);
      } else {
         setup.stopLoss = NormalizeDouble(close0 - slDist, _Digits);
      }
      
      // TP: ATR*TP_mult from entry
      setup.takeProfit = NormalizeDouble(close0 + atrVal * InpAtrMultTP, _Digits);
      
      // RR
      double risk = setup.entryPrice - setup.stopLoss;
      double reward = setup.takeProfit - setup.entryPrice;
      setup.rrRatio = (risk > 0) ? NormalizeDouble(reward / risk, 2) : 0;
      
      // Lot size
      setup.lotSize = CalculateLotSize(risk);
      
      // Confidence
      setup.confidence = 6;
      if(IsVolumeSpike()) setup.confidence += 2;
      if(gBullCHoCH) setup.confidence += 1;
      if(ArraySize(gBullishFVGs) > 0) setup.confidence += 1;
      if(gBosDir == 1) setup.confidence += 1;
      setup.confidence = MathMin(10, MathMax(1, setup.confidence));
      
      setup.reasoning = StringFormat(
         "Bull bias (%d pts) | FVG:%d | CHoCH:%s | VolSpike:%s | HTF:%s | Mode:%s",
         score, ArraySize(gBullishFVGs),
         gBullCHoCH ? "YES" : "NO",
         IsVolumeSpike() ? "YES" : "NO",
         EnumToString(GetHtfBias()),
         EnumToString(tradeMode)
      );
   }
   
   //--- BEARISH SETUP
   else if(bias == MODE_BEAR && (ArraySize(gBearishFVGs) > 0 || gBearCHoCH || gBearBOS)) {
      setup.direction = MODE_BEAR;
      
      if(ArraySize(gBearishFVGs) > 0) {
         SFVG lastFvg = gBearishFVGs[ArraySize(gBearishFVGs) - 1];
         setup.entryPrice = NormalizeDouble(lastFvg.top, _Digits);
      } else {
         setup.entryPrice = NormalizeDouble(close0, _Digits);
      }
      
      double slDist = atrVal * InpAtrMultSL;
      if(gLastSwingHigh.price > 0) {
         setup.stopLoss = NormalizeDouble(MathMax(gLastSwingHigh.price + atrVal * 0.5, close0 + slDist), _Digits);
      } else {
         setup.stopLoss = NormalizeDouble(close0 + slDist, _Digits);
      }
      
      setup.takeProfit = NormalizeDouble(close0 - atrVal * InpAtrMultTP, _Digits);
      
      double risk = setup.stopLoss - setup.entryPrice;
      double reward = setup.entryPrice - setup.takeProfit;
      setup.rrRatio = (risk > 0) ? NormalizeDouble(reward / risk, 2) : 0;
      
      setup.lotSize = CalculateLotSize(risk);
      
      setup.confidence = 6;
      if(IsVolumeSpike()) setup.confidence += 2;
      if(gBearCHoCH) setup.confidence += 1;
      if(ArraySize(gBearishFVGs) > 0) setup.confidence += 1;
      if(gBosDir == -1) setup.confidence += 1;
      setup.confidence = MathMin(10, MathMax(1, setup.confidence));
      
      setup.reasoning = StringFormat(
         "Bear bias (%d pts) | FVG:%d | CHoCH:%s | VolSpike:%s | HTF:%s | Mode:%s",
         score, ArraySize(gBearishFVGs),
         gBearCHoCH ? "YES" : "NO",
         IsVolumeSpike() ? "YES" : "NO",
         EnumToString(GetHtfBias()),
         EnumToString(tradeMode)
      );
   }
   
   //--- NEUTRAL: no setup
   else {
      setup.direction = MODE_NEUTRAL;
      setup.confidence = 0;
      setup.reasoning = "No valid setup - neutral bias or insufficient confirmation";
   }
   
   return setup;
}

//+------------------------------------------------------------------+
//| CALCULATE LOT SIZE                                               |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistance)
{
   if(slDistance <= 0) return InpFixedLot;
   
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * InpRiskPercent / 100.0;
   
   double tickValue  = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double tickSize    = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   double pointSize   = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   
   double slPoints = slDistance / pointSize;
   double riskPerLot = slPoints * tickValue / tickSize * pointSize;
   
   double lot = 0;
   if(riskPerLot > 0) {
      lot = riskAmount / riskPerLot;
   }
   
   //--- Apply limits
   double minLot  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double maxLot  = InpMaxLot;
   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   
   lot = MathMax(minLot, MathMin(maxLot, lot));
   lot = MathFloor(lot / lotStep) * lotStep;
   
   //--- Fallback to fixed lot
   if(lot < minLot) lot = InpFixedLot;
   
   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| MANAGE EXISTING TRADES                                           |
//+------------------------------------------------------------------+
void ManageTrades(STradeSetup &setup)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(position.SelectByIndex(i)) {
         if(position.Magic() != InpMagicNumber) continue;
         if(position.Symbol() != Symbol()) continue;
         
         double openPrice = position.PriceOpen();
         double currentPrice = position.PriceCurrent();
         double profit = position.Profit();
         double unrealizedPnL = position.UnrealizedDealProfit();
         
         //--- Check for breakeven move
         double openPL = profit;
         double sl = position.StopLoss();
         
         if(position.PositionType() == POSITION_TYPE_BUY) {
            double profitPts = (currentPrice - openPrice) / SymbolInfoDouble(Symbol(), SYMBOL_POINT);
            // Move SL to breakeven when 1:1 RR is reached
            if(profitPts > (MathAbs(openPrice - sl) / SymbolInfoDouble(Symbol(), SYMBOL_POINT)) * 2
               && sl < openPrice) {
               trade.PositionModify(Symbol(), openPrice, position.TakeProfit());
            }
         }
         else if(position.PositionType() == POSITION_TYPE_SELL) {
            double profitPts = (openPrice - currentPrice) / SymbolInfoDouble(Symbol(), SYMBOL_POINT);
            if(profitPts > (MathAbs(sl - openPrice) / SymbolInfoDouble(Symbol(), SYMBOL_POINT)) * 2
               && sl > openPrice) {
               trade.PositionModify(Symbol(), openPrice, position.TakeProfit());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| EXECUTE SETUP                                                    |
//+------------------------------------------------------------------+
void ExecuteSetup(STradeSetup &setup)
{
   if(setup.direction == MODE_NEUTRAL) return;
   if(setup.confidence < 5) {
      Print("⚠️ Setup confidence too low (", setup.confidence, "/10) - skipping");
      return;
   }
   
   //--- Count open positions
   int openPos = CountOpenPositions();
   if(openPos >= InpMaxPositions) {
      Print("Max positions reached (", InpMaxPositions, ")");
      return;
   }
   
   //--- Check if same setup already in progress
   if(lastTradeTime > 0 && TimeCurrent() - lastTradeTime < 300) {
      return; // 5 min cooldown
   }
   
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   double sl = 0;
   double tp = 0;
   double entry = 0;
   ENUM_ORDER_TYPE orderType = ORDER_TYPE_BUY;
   
   if(setup.direction == MODE_BULL) {
      entry = ask;
      sl    = setup.stopLoss;
      tp    = setup.takeProfit;
      orderType = (setup.tradeMode == MODE_SCALP) ? ORDER_TYPE_BUY : ORDER_TYPE_BUY_LIMIT;
      
      // For LIMIT orders, entry price should be below current price
      if(orderType == ORDER_TYPE_BUY_LIMIT) {
         entry = NormalizeDouble(bid - GetATR(1) * 0.5, _Digits);
      }
   }
   else if(setup.direction == MODE_BEAR) {
      entry = bid;
      sl    = setup.stopLoss;
      tp    = setup.takeProfit;
      orderType = (setup.tradeMode == MODE_SCALP) ? ORDER_TYPE_SELL : ORDER_TYPE_SELL_LIMIT;
      
      if(orderType == ORDER_TYPE_SELL_LIMIT) {
         entry = NormalizeDouble(ask + GetATR(1) * 0.5, _Digits);
      }
   }
   
   //--- Validate SL and TP
   if(!ValidateSLTP(orderType, entry, sl, tp)) {
      Print("❌ Invalid SL/TP - skipping trade");
      return;
   }
   
   //--- Execute
   bool result = false;
   if(orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_SELL) {
      result = trade.PositionOpen(Symbol(), orderType, setup.lotSize, entry, sl, tp,
         StringFormat("SMC+FVG | %s | Conf:%d | RR:%.2f",
         setup.reasoning, setup.confidence, setup.rrRatio));
   } else {
      result = trade.OrderOpen(Symbol(), orderType, setup.lotSize, entry, sl, tp, 0,
         StringFormat("SMC+FVG Limit | %s | Conf:%d", setup.reasoning, setup.confidence));
   }
   
   if(result) {
      lastTradeTime = TimeCurrent();
      Print("✅ ORDER EXECUTED: ", EnumToString(orderType),
            " Entry:", DoubleToStr(entry, _Digits),
            " SL:", DoubleToStr(sl, _Digits),
            " TP:", DoubleToStr(tp, _Digits),
            " Lot:", DoubleToStr(setup.lotSize, 2),
            " RR:", DoubleToStr(setup.rrRatio, 2));
   } else {
      Print("❌ ORDER FAILED: ", GetLastError(),
            " Comment: ", trade.ResultComment());
   }
}

//+------------------------------------------------------------------+
//| VALIDATE SL/TP                                                   |
//+------------------------------------------------------------------+
bool ValidateSLTP(ENUM_ORDER_TYPE orderType, double entry, double sl, double tp)
{
   double point  = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double spread = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * point;
   
   double minSL  = point * SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
   
   if(orderType == ORDER_TYPE_BUY) {
      if(sl >= entry) return false;
      if(tp <= entry) return false;
      if(entry - sl < minSL) return false;
   }
   else if(orderType == ORDER_TYPE_SELL) {
      if(sl <= entry) return false;
      if(tp >= entry) return false;
      if(sl - entry < minSL) return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| COUNT OPEN POSITIONS                                             |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(position.SelectByIndex(i)) {
         if(position.Magic() == InpMagicNumber && position.Symbol() == Symbol()) {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| PRINT DASHBOARD                                                   |
//+------------------------------------------------------------------+
void PrintDashboard(STradeSetup &setup)
{
   string modeStr = "";
   if(setup.tradeMode == MODE_HYBRID) modeStr = "🔷 HYBRID";
   else if(setup.tradeMode == MODE_SWING) modeStr = "📊 SWING";
   else modeStr = "⚡ SCALP";
   
   string biasStr = "";
   int score = 0;
   ENUM_MARKET_MODE bias = GetBias(score);
   if(bias == MODE_BULL) biasStr = "🟢 BULLISH";
   else if(bias == MODE_BEAR) biasStr = "🔴 BEARISH";
   else biasStr = "⚪ NEUTRAL";
   
   string bosStr = (gBosDir == 1) ? "🟢 BULL" : (gBosDir == -1) ? "🔴 BEAR" : "⚪ NEUT";
   string volStr = IsVolumeSpike() ? "✅" : "❌";
   
   string dirStr = (setup.direction == MODE_BULL) ? "📈 BUY" :
                   (setup.direction == MODE_BEAR) ? "📉 SELL" : "⏸️ NONE";
   
   // Confidence bar
   string confBar = "";
   int conf = setup.confidence;
   for(int i = 0; i < 10; i++) confBar += (i < conf) ? "█" : "░";
   
   string comment = StringFormat(
      "══════════════════════════════════════\n" +
      "   SMC + FVG Hybrid Dashboard v1.0   \n" +
      "══════════════════════════════════════\n" +
      "  Pair     : %s\n" +
      "  Price    : %s\n" +
      "  Spread   : %d pts\n" +
      "──────────────────────────────────────\n" +
      "  Bias     : %s (score: %+d)\n" +
      "  Mode     : %s\n" +
      "  HTF Bias : %s\n" +
      "  BOS      : %s\n" +
      "  Vol Spike: %s\n" +
      "──────────────────────────────────────\n" +
      "  Bull FVGs : %d\n" +
      "  Bear FVGs : %d\n" +
      "  CHoCH    : %s\n" +
      "──────────────────────────────────────\n" +
      "  Direction : %s\n" +
      "  Entry     : %s\n" +
      "  SL        : %s\n" +
      "  TP        : %s\n" +
      "  R:R       : %s\n" +
      "  Lot       : %s\n" +
      "──────────────────────────────────────\n" +
      "  Confidence: %s [%d/10]\n" +
      "══════════════════════════════════════",
      Symbol(),
      DoubleToStr(Close(0), _Digits),
      (int)SymbolInfoInteger(Symbol(), SYMBOL_SPREAD),
      biasStr, score,
      modeStr,
      EnumToString(GetHtfBias()),
      bosStr,
      volStr,
      ArraySize(gBullishFVGs),
      ArraySize(gBearishFVGs),
      (gBullCHoCH || gBearCHoCH) ? "YES 🟡" : "NO",
      dirStr,
      (setup.direction != MODE_NEUTRAL) ? DoubleToStr(setup.entryPrice, _Digits) : "—",
      (setup.direction != MODE_NEUTRAL) ? DoubleToStr(setup.stopLoss, _Digits) : "—",
      (setup.direction != MODE_NEUTRAL) ? DoubleToStr(setup.takeProfit, _Digits) : "—",
      (setup.direction != MODE_NEUTRAL) ? DoubleToStr(setup.rrRatio, 2) : "—",
      (setup.direction != MODE_NEUTRAL) ? DoubleToStr(setup.lotSize, 2) : "—",
      confBar, setup.confidence
   );
   
   Comment(comment);
}

//+------------------------------------------------------------------+
//| CHECK HANDLES                                                    |
//+------------------------------------------------------------------+
bool CheckHandles(CiATR &atr, CiMA &vol, CiEMA &e8, CiEMA &e21,
                  CiEMA &e50, CiEMA &e200,
                  CiEMA &h1e50, CiEMA &h1e200,
                  CiEMA &h2e50, CiEMA &h2e200,
                  CiClose &h1c, CiClose &h2c)
{
   bool ok = true;
   if(atr.Handle() == INVALID_HANDLE) ok = false;
   if(vol.Handle() == INVALID_HANDLE) ok = false;
   if(e8.Handle()  == INVALID_HANDLE) ok = false;
   if(e21.Handle() == INVALID_HANDLE) ok = false;
   if(e50.Handle() == INVALID_HANDLE) ok = false;
   if(e200.Handle()== INVALID_HANDLE) ok = false;
   if(h1e50.Handle() == INVALID_HANDLE) ok = false;
   if(h1e200.Handle()== INVALID_HANDLE) ok = false;
   if(h2e50.Handle() == INVALID_HANDLE) ok = false;
   if(h2e200.Handle()== INVALID_HANDLE) ok = false;
   if(h1c.Handle()   == INVALID_HANDLE) ok = false;
   if(h2c.Handle()   == INVALID_HANDLE) ok = false;
   return ok;
}

//+------------------------------------------------------------------+
//| SAFE DELETE                                                      |
//+------------------------------------------------------------------+
template<typename T>
void SafeDelete(T &obj)
{
   if(CheckPointer(obj) != POINTER_INVALID) {
      obj.Destroy();
      delete obj;
      obj = NULL;
   }
}

//+------------------------------------------------------------------+
//| LOT MODE ENUM                                                    |
//+------------------------------------------------------------------+
enum ENUM_LOT_MODE {
   LOT_MODE_RISK,     // Risk-based lot sizing
   LOT_MODE_FIXED      // Fixed lot
};
