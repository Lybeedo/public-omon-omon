//+------------------------------------------------------------------+
//|                                         Ichimoku_TK_Cross_V1.mq5 |
//|                                 Copyright 2026, Trader Nakal™     |
//|                                     https://github.com/Lybeedo    |
//+------------------------------------------------------------------+
#property copyright   "Trader Nakal™ — Omon Engine"
#property version     "1.00"
#property description "Ichimoku TK Cross + Kumo Breakout + Dashboard"
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
// ENUM & GLOBALS
//+------------------------------------------------------------------+
enum ENUM_ENTRY_MODE {
   MODE_TK_CROSS = 0,    // Tenkan/Kijun Cross only
   MODE_KUMO_BREAK = 1,  // Price vs Cloud + TK Cross
   MODE_ALL_FILTERS = 2  // Kumo + TK Cross + Chikou confirmation
};

input group "=== Indikator Ichimoku ==="
input int                InpTenkanPeriod    = 9;       // Tenkan-sen Period
input int                InpKijunPeriod     = 26;      // Kijun-sen Period
input int                InpSenkouBPeriod   = 52;      // Senkou Span B Period
input int                InpDisplacement    = 26;      // Displacement (shift)

input group "=== Filter & Konfirmasi ==="
input ENUM_ENTRY_MODE    InpEntryMode       = MODE_ALL_FILTERS; // Mode Entry
input bool               InpUseChikouFilter = true;         // Aktifkan filter Chikou

input group "=== Manajemen Risiko ==="
input ENUM_APPLIED_RISK  InpRiskMode        = RISK_PERCENT_EQUITY; // Risk Mode
input double             InpRiskPercent     = 1.0;           // Risk % Equity
input double             InpFixedLot        = 0.01;          // Fixed Lot Size
input int                InpMultiplier      = 1;              // Position Multiplier

input group "=== Stop Loss & TP ==="
input int                InpATR_SL_Period   = 14;            // ATR Period for SL
input double             InpATR_SL_Multiplier = 2.0;         // ATR Multiplier for SL
input double             InpATF_TP_Multiplier = 3.0;         // ATR Multiplier for TP
input double             InpTrailingStop_ATR = 1.5;         // Trailing (ATR mult.)
input int                InpMinSL_Points    = 300;           // Min SL distance (points)
input int                InpMinTP_Points    = 300;           // Min TP distance (points)

input group "=== Money Management ==="
input int                InpMagicNumber     = 789456;
input string             InpComment         = "Ichimoku_TK_Cross";

// Global engine variables
CTrade                   trade;
int                      g_hIchimoku = INVALID_HANDLE;

// Ichimoku buffer arrays
double                   g_tenkan[];
double                   g_kijun[];
double                   g_senkouA[];
double                   g_senkouB[];
double                   g_chikou[];

// Panel vars
string                   g_panelName = "Ichimoku_Dashboard";

//+------------------------------------------------------------------+
// OnInit / OnDeinit
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(30);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   // Try IOC if FOK fails later
   g_hIchimoku = iCustom(_Symbol, PERIOD_CURRENT, "Indicators\\Ichimoku", 
                         InpTenkanPeriod, InpKijunPeriod, InpSenkouBPeriod, InpDisplacement);
   if(g_hIchimoku == INVALID_HANDLE) {
      Print("❌ Gagal create handle Ichimoku:", GetLastError());
      return(INIT_FAILED);
   }
   
   // Set array series mode
   ArraySetAsSeries(g_tenkan, true);
   ArraySetAsSeries(g_kijun, true);
   ArraySetAsSeries(g_senkouA, true);
   ArraySetAsSeries(g_senkouB, true);
   ArraySetAsSeries(g_chikou, true);
   
   // Setup order filling — retry with IOC if FOK rejected
   if(!IsOrderFillTypeAllowed(SYMBOL_ORDER_FILLING_FOK))
      trade.SetTypeFilling(ORDER_FILLING_IOC);
   
   CreateDashboard();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(g_hIchimoku != INVALID_HANDLE) IndicatorRelease(g_hIchimoku);
   ObjectsDeleteAll(0, g_panelName);
   ChartRedraw();
}

//+------------------------------------------------------------------+
// OnTick — Main Engine
//+------------------------------------------------------------------+
void OnTick()
{
   // Static candle guard (VPS optimization)
   static datetime lastBarTime = 0;
   datetime curBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(curBarTime == lastBarTime) return;
   lastBarTime = curBarTime;
   
   // Refresh indicator data
   if(!RefreshIndicator()) return;
   
   // Update panel every new bar
   UpdateDashboard();
   
   // Check existing positions first
   VerifyPositions();
   if(g_hasLong || g_hasShort) {
      ManageOpenPositions();
      return;
   }
   
   // No open position → check for entry signals
   int signal = CheckSignal();
   if(signal == SIGNAL_LONG)  ExecutePosition(ORDER_TYPE_BUY);
   if(signal == SIGNAL_SHORT) ExecutePosition(ORDER_TYPE_SELL);
}

//+------------------------------------------------------------------+
// Indicator Data Refresh
//+------------------------------------------------------------------+
bool RefreshIndicator()
{
   ResetLastError();
   if(CopyBuffer(g_hIchimoku, 0, 0, 3, g_tenkan) < 3) {
      Print("⚠️ [ERR] CopyBuffer TENKAN failed:", GetLastError());
      return(false);
   }
   ResetLastError();
   if(CopyBuffer(g_hIchimoku, 1, 0, 3, g_kijun) < 3) {
      Print("⚠️ [ERR] CopyBuffer KIJUN failed:", GetLastError());
      return(false);
   }
   ResetLastError();
   if(CopyBuffer(g_hIchimoku, 2, 0, 3, g_senkouA) < 3) {
      Print("⚠️ [ERR] CopyBuffer SENKOU_A failed:", GetLastError());
      return(false);
   }
   ResetLastError();
   if(CopyBuffer(g_hIchimoku, 3, 0, 3, g_senkouB) < 3) {
      Print("⚠️ [ERR] CopyBuffer SENKOU_B failed:", GetLastError());
      return(false);
   }
   ResetLastError();
   if(CopyBuffer(g_hIchimoku, 4, 0, 3, g_chikou) < 3) {
      Print("⚠️ [ERR] CopyBuffer CHIKOU failed:", GetLastError());
      return(false);
   }
   return(true);
}

//+------------------------------------------------------------------+
// Position Verification (descending loop)
//+------------------------------------------------------------------+
bool g_hasLong  = false;
bool g_hasShort = false;

void VerifyPositions()
{
   g_hasLong  = false;
   g_hasShort = false;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)  g_hasLong = true;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) g_hasShort = true;
   }
}

//+------------------------------------------------------------------+
// Signal Generation — TK Cross + Kumo + Chikou
//+------------------------------------------------------------------+
enum ENUM_SIGNAL { SIGNAL_NONE = 0, SIGNAL_LONG = 1, SIGNAL_SHORT = -1 };

int CheckSignal()
{
   // Current candle (index 0): price data
   double ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double close0 = iClose(_Symbol, PERIOD_CURRENT, 0);
   
   // Previous candle crosses are at index 1-2 (crossover detected there)
   double tenkan_prev1  = g_tenkan[1];
   double kijun_prev1   = g_kijun[1];
   double tenkan_prev2  = g_tenkan[2];
   double kijun_prev2   = g_kijun[2];
   
   double senkouA_prev1 = g_senkouA[1];
   double senkouB_prev1 = g_senkouB[1];
   double chikou_curr   = g_chikou[0];
   
   // --- LONG SIGNAL ---
   // Bullish TK Cross: Tenkan crosses ABOVE Kijun
   bool bullishTK = (tenkan_prev1 <= kijun_prev1) && (g_tenkan[0] > g_kijun[0]);
   // Or already above (consolidated trend-following mode)
   bool tenkanAboveKijun = (g_tenkan[0] > g_kijun[0]);
   
   // Kumo breakout: price above cloud (SenkouA + SenkouB average)
   double cloudAvg = (senkouA_prev1 + senkouB_prev1) / 2.0;
   bool aboveCloud = (close0 > senkouA_prev1) && (close0 > senkouB_prev1);
   
   // Chikou confirmation: Chikou above price from 26 bars ago
   double price26ago = iClose(_Symbol, PERIOD_CURRENT, 26);
   bool chikouClean = (chikou_curr > price26ago);
   
   bool longSignal = false;
   switch(InpEntryMode) {
      case MODE_TK_CROSS:
         longSignal = bullishTK || tenkanAboveKijun;
         break;
      case MODE_KUMO_BREAK:
         longSignal = (bullishTK || tenkanAboveKijun) && aboveCloud;
         break;
      case MODE_ALL_FILTERS:
         if(!InpUseChikouFilter)
            longSignal = (bullishTK || tenkanAboveKijun) && aboveCloud;
         else
            longSignal = (bullishTK || tenkanAboveKijun) && aboveCloud && chikouClean;
         break;
   }
   
   // --- SHORT SIGNAL ---
   // Bearish TK Cross: Tenkan crosses BELOW Kijun
   bool bearishTK = (tenkan_prev1 >= kijun_prev1) && (g_tenkan[0] < g_kijun[0]);
   bool tenkanBelowKijun = (g_tenkan[0] < g_kijun[0]);
   
   bool belowCloud = (close0 < senkouA_prev1) && (close0 < senkouB_prev1);
   bool chikouBearish = (chikou_curr < price26ago);
   
   bool shortSignal = false;
   switch(InpEntryMode) {
      case MODE_TK_CROSS:
         shortSignal = bearishTK || tenkanBelowKijun;
         break;
      case MODE_KUMO_BREAK:
         shortSignal = (bearishTK || tenkanBelowKijun) && belowCloud;
         break;
      case MODE_ALL_FILTERS:
         if(!InpUseChikouFilter)
            shortSignal = (bearishTK || tenkanBelowKijun) && belowCloud;
         else
            shortSignal = (bearishTK || tenkanBelowKijun) && belowCloud && chikouBearish;
         break;
   }
   
   if(longSignal) return SIGNAL_LONG;
   if(shortSignal) return SIGNAL_SHORT;
   return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
// Position Management — Open, Modify SL/TP, Trailing
//+------------------------------------------------------------------+
void ExecutePosition(ENUM_ORDER_TYPE type)
{
   double sl = 0, tp = 0;
   CalculateTargets(type, sl, tp);
   
   double lot = CalculateLotSize(sl);
   if(lot < GetMinLot()) return;
   
   double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) 
                                            : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(type == ORDER_TYPE_BUY) {
      if(!trade.Buy(lot, _Symbol, price, sl, tp, InpComment)) {
         Print("❌ Buy gagal:", trade.ResultRetcodeDescription());
      } else {
         Print("✅ BUY ", lot, " lot @ ", price, " | SL:", sl, " TP:", tp);
      }
   } else {
      if(!trade.Sell(lot, _Symbol, price, sl, tp, InpComment)) {
         Print("❌ Sell gagal:", trade.ResultRetcodeDescription());
      } else {
         Print("✅ SELL ", lot, " lot @ ", price, " | SL:", sl, " TP:", tp);
      }
   }
}

void ManageOpenPositions()
{
   // Handle trailing stop for each position
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double posSL = PositionGetDouble(POSITION_SL);
      double posTP = PositionGetDouble(POSITION_TP);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double currentSL = posSL;
      
      if(posType == POSITION_TYPE_BUY) {
         double atrSL = TrailingSL(bid, openPrice, TRAILING_UP);
         if(atrSL > currentSL && atrSL > 0) currentSL = atrSL;
      } else {
         double atrSL = TrailingSL(ask, openPrice, TRAILING_DOWN);
         if((atrSL < currentSL && currentSL > 0) || currentSL == 0) currentSL = atrSL;
      }
      
      // Only modify if SL changed significantly (> 5 points)
      if(MathAbs(currentSL - posSL) > _Point * 5) {
         trade.PositionModify(ticket, currentSL, posTP);
      }
   }
}

//+------------------------------------------------------------------+
// Target Calculator — ATR Based SL/TP
//+------------------------------------------------------------------+
void CalculateTargets(ENUM_ORDER_TYPE type, double &sl, double &tp)
{
   double atr = GetATR(InpATR_SL_Period);
   if(atr <= 0) atr = _Point * 50; // fallback
   
   double slDistance = atr * InpATR_SL_Multiplier;
   double tpDistance = atr * InpATF_TP_Multiplier;
   
   // Enforce minimum distance
   double minDist = _Point * MathMax(InpMinSL_Points, InpMinTP_Points);
   if(slDistance < minDist) slDistance = minDist;
   if(tpDistance < minDist) tpDistance = minDist;
   
   if(type == ORDER_TYPE_BUY) {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = NormalizeDouble(ask - slDistance, _Digits);
      tp = NormalizeDouble(ask + tpDistance, _Digits);
   } else {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = NormalizeDouble(bid + slDistance, _Digits);
      tp = NormalizeDouble(bid - tpDistance, _Digits);
   }
}

//+------------------------------------------------------------------+
// ATR Calculator
//+------------------------------------------------------------------+
double GetATR(int period)
{
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   
   int handle = iATR(_Symbol, PERIOD_CURRENT, period);
   if(handle == INVALID_HANDLE) return 0;
   
   if(CopyBuffer(handle, 0, 0, 1, atrBuffer) < 1) {
      IndicatorRelease(handle);
      return 0;
   }
   
   double atr = atrBuffer[0];
   IndicatorRelease(handle);
   return atr;
}

//+------------------------------------------------------------------+
// Trailing Stop Logic
//+------------------------------------------------------------------+
enum ENUM_TRAIL_DIR { TRAILING_UP = 0, TRAILING_DOWN = 1 };

double TrailingSL(double currentPrice, double openPrice, ENUM_TRAIL_DIR dir)
{
   double atr = GetATR(InpATR_SL_Period);
   if(atr <= 0) atr = _Point * 50;
   
   double trailDistance = atr * InpTrailingStop_ATR;
   double minSL = _Point * InpMinSL_Points;
   if(trailDistance < minSL) trailDistance = minSL;
   
   if(dir == TRAILING_UP) {
      return NormalizeDouble(currentPrice - trailDistance, _Digits);
   } else {
      return NormalizeDouble(currentPrice + trailDistance, _Digits);
   }
}

//+------------------------------------------------------------------+
// Lot Size Calculator
//+------------------------------------------------------------------+
double CalculateLotSize(double slPoints)
{
   double minLot = GetMinLot();
   double maxLot = GetMaxLot();
   double lotStep = GetLotStep();
   
   double lot = 0;
   
   if(InpRiskMode == RISK_FIXED_LOT) {
      lot = InpFixedLot * InpMultiplier;
   } else {
      // RISK_PERCENT_EQUITY
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmount = equity * (InpRiskPercent / 100.0);
      
      // Slippage in points
      if(slPoints <= 0) slPoints = _Point * 300;
      
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      
      // Rough lot calculation: riskAmount / (sl_points * point_value_per_lot)
      double pointValuePerLot = (tickValue / tickSize) * _Point;
      if(pointValuePerLot <= 0) pointValuePerLot = 1.0;
      
      lot = riskAmount / (slPoints / _Point * pointValuePerLot);
   }
   
   // Apply multiplier
   lot *= InpMultiplier;
   
   // Normalize to broker limits
   lot = MathFloor(lot / lotStep) * lotStep;
   lot = MathMax(minLot, MathMin(maxLot, lot));
   
   return lot;
}

//+------------------------------------------------------------------+
// Broker Helper Functions
//+------------------------------------------------------------------+
double GetMinLot() {
   return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
}
double GetMaxLot() {
   return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
}
double GetLotStep() {
   return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
}

bool IsOrderFillTypeAllowed(ENUM_ORDER_TYPE_FILLING fillType) {
   long fillTypeLong = (long)fillType;
   long allowed = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   return ((allowed & fillTypeLong) == fillTypeLong);
}

//+------------------------------------------------------------------+
// DASHBOARD / PANEL VISUAL
//+------------------------------------------------------------------+
void CreateDashboard()
{
   int x = 20, y = 30, spacing = 22, lineHeight = 18;
   color labelColor = clrWhiteSmoke;
   color headerColor = clrGold;
   color borderColor = clrDarkSlateGray;
   
   // Background panel
   CreateRoundRect(g_panelName + "_BG", x - 10, y - 20, 340, 420, borderColor);
   
   // Header
   CreateLabel(g_panelName + "_Title", x, y, "📊 ICHIMOKU TK CROSS", headerColor, 12, FontWeightBold);
   
   // Separator
   CreateHLine(g_panelName + "_Sep1", x - 5, y + 18, 330, clrDimGray);
   
   y += spacing + 5;
   
   // Status section
   CreateLabel(g_panelName + "_L1", x, y, "Status: ...", labelColor, 10);
   CreateLabel(g_panelName + "_L2", x, y + lineHeight, "Tenkan/Kijun: ...", labelColor, 10);
   CreateLabel(g_panelName + "_L3", x, y + lineHeight*2, "Kumo (Cloud): ...", labelColor, 10);
   CreateLabel(g_panelName + "_L4", x, y + lineHeight*3, "Chikou Span: ...", labelColor, 10);
   
   y += lineHeight*4 + 15;
   CreateHLine(g_panelName + "_Sep2", x - 5, y, 330, clrDimGray);
   
   // Signal section
   CreateLabel(g_panelName + "_L5", x, y + 5, "Signal: MENUNGGU", clrLightGray, 11, FontWeightBold);
   
   y += lineHeight*2 + 15;
   CreateHLine(g_panelName + "_Sep3", x - 5, y, 330, clrDimGray);
   
   // Position info
   CreateLabel(g_panelName + "_L6", x, y + 5, "Posisi: Tidak ada", labelColor, 10);
   CreateLabel(g_panelName + "_L7", x, y + lineHeight, "Pip Value: ...", labelColor, 10);
   
   y += lineHeight*2 + 15;
   CreateHLine(g_panelName + "_Sep4", x - 5, y, 330, clrDimGray);
   
   // Settings summary
   CreateLabel(g_panelName + "_L8", x, y + 5, "SL: ATR×"+DoubleToString(InpATR_SL_Multiplier,1), clrSilver, 9);
   CreateLabel(g_panelName + "_L9", x, y + lineHeight, "TP: ATR×"+DoubleToString(InpATF_TP_Multiplier,1), clrSilver, 9);
   CreateLabel(g_panelName + "_L10", x, y + lineHeight*2, "Risk: "+GetRiskDisplay(), clrSilver, 9);
   
   ChartRedraw();
}

void UpdateDashboard()
{
   int x = 20, y = 30, spacing = 22, lineHeight = 18;
   color cGreen = clrLimeGreen;
   color cRed = clrIndianRed;
   color cOrange = clrOrange;
   color cGray = clrGainsboro;
   
   // Status
   string statusText = "MENUNGGU";
   color statusColor = cGray;
   
   // Tenkan/Kijun analysis
   string tkText = "Datar";
   color tkColor = cGray;
   if(g_tenkan[0] > g_kijun[0]) {
      tkText = "↑ BULLISH (Tenkan > Kijun)";
      tkColor = cGreen;
   } else if(g_tenkan[0] < g_kijun[0]) {
      tkText = "↓ BEARISH (Tenkan < Kijun)";
      tkColor = cRed;
   } else {
      tkText = "=" + " DATAR (Cross Point)";
      tkColor = cOrange;
   }
   
   ObjectSetString(0, g_panelName+"_L2", OBJPROP_TEXT, tkText);
   ObjectSetInteger(0, g_panelName+"_L2", OBJPROP_COLOR, tkColor);
   
   // Kumo (Cloud) analysis
   string kumoText = "...";
   color kumoColor = cGray;
   double close0 = iClose(_Symbol, PERIOD_CURRENT, 0);
   double senkouAvg = (g_senkouA[1] + g_senkouB[1]) / 2.0;
   
   if(close0 > g_senkouA[1] && close0 > g_senkouB[1]) {
      kumoText = "☀️ DI ATAS AWAN (Bullish)";
      kumoColor = cGreen;
   } else if(close0 < g_senkouA[1] && close0 < g_senkouB[1]) {
      kumoText = "🌑 DI BAWAH AWAN (Bearish)";
      kumoColor = cRed;
   } else {
      kumoText = "⛅ DALAM AWAN (Sideways)";
      kumoColor = cOrange;
   }
   
   ObjectSetString(0, g_panelName+"_L3", OBJPROP_TEXT, kumoText);
   ObjectSetInteger(0, g_panelName+"_L3", OBJPROP_COLOR, kumoColor);
   
   // Chikou Span analysis
   string chikouText = "...";
   color chikouColor = cGray;
   double price26ago = iClose(_Symbol, PERIOD_CURRENT, 26);
   if(InpUseChikouFilter) {
      if(g_chikou[0] > price26ago) {
         chikouText = "✓ Di atas harga (Bullish Confirm)";
         chikouColor = cGreen;
      } else if(g_chikou[0] < price26ago) {
         chikouText = "✗ Di bawah harga (Bearish Confirm)";
         chikouColor = cRed;
      } else {
         chikouText = "~ Menyentuh harga (Ambigu)";
         chikouColor = cOrange;
      }
   } else {
      chikouText = "Filter dinonaktifkan";
      chikouColor = clrSilver;
   }
   
   ObjectSetString(0, g_panelName+"_L4", OBJPROP_TEXT, chikouText);
   ObjectSetInteger(0, g_panelName+"_L4", OBJPROP_COLOR, chikouColor);
   
   // Position info
   string posCount = "Tidak ada posisi terbuka";
   int totalPos = 0;
   int buyPos = 0, sellPos = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      totalPos++;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) buyPos++;
      else sellPos++;
   }
   
   if(totalPos == 0) {
      posCount = "Tidak ada posisi terbuka";
   } else {
      posCount = StringFormat("%d BUY | %d SELL | Total: %d", buyPos, sellPos, totalPos);
   }
   
   ObjectSetString(0, g_panelName+"_L6", OBJPROP_TEXT, posCount);
   
   // Pip value
   double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   ObjectSetString(0, g_panelName+"_L7", OBJPROP_TEXT, 
                   "Pip Value: $"+DoubleToString(tickVal, 2)+" / tick");
   
   // Signal
   int signal = CheckSignal();
   string sigText = "⏳ MENUNGGU...";
   color sigColor = cGray;
   
   if(signal == SIGNAL_LONG) {
      sigText = "🟢 BUY SIGNAL DETECTED!";
      sigColor = cGreen;
      statusText = "BUY ACTIVE";
      statusColor = cGreen;
   } else if(signal == SIGNAL_SHORT) {
      sigText = "🔴 SELL SIGNAL DETECTED!";
      sigColor = cRed;
      statusText = "SELL ACTIVE";
      statusColor = cRed;
   }
   
   ObjectSetString(0, g_panelName+"_L5", OBJPROP_TEXT, sigText);
   ObjectSetInteger(0, g_panelName+"_L5", OBJPROP_COLOR, sigColor);
   ObjectSetString(0, g_panelName+"_L1", OBJPROP_TEXT, "Status: "+statusText);
   ObjectSetInteger(0, g_panelName+"_L1", OBJPROP_COLOR, statusColor);
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
// Panel Building Helpers
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, color clr, 
                 int fontSize = 10, ENUM_FONT_WEIGHT fw = FontWeightNormal)
{
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
   } else {
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   }
}

void CreateHLine(string name, int x, int y, int width, color clr)
{
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
   }
}

void CreateRoundRect(string name, int x, int y, int w, int h, color clr)
{
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      // Semi-transparent background
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   }
}

string GetRiskDisplay()
{
   if(InpRiskMode == RISK_FIXED_LOT)
      return "Fixed Lot: "+DoubleToString(InpFixedLot, 2);
   else
      return "% Equity: "+DoubleToString(InpRiskPercent, 1)+"%";
}
//+------------------------------------------------------------------+
