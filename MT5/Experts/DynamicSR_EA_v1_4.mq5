//+------------------------------------------------------------------+
//|                                              DynamicSR EA v1.4.mq5|
//|                                  Copyright 2026, Lead MQL5 Dev   |
//|                                          Developed for Bambang  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Lead MQL5 Dev"
#property link      "https://cuancux.com"
#property version   "1.40"
#property strict

//--- ENUMS
enum ENUM_STATE { STATE_RANGE_BUILDING, STATE_ACTIVE };
enum ENUM_SR_STATE { SR_NEUTRAL, SR_SUPPORT, SR_RESISTANCE };
enum ENUM_SCAN_RESULT { SCAN_SUCCESS, SCAN_INCOMPLETE, SCAN_GAP_DETECTED };

//--- INPUT PARAMETERS
input group "=== VISUAL SETTINGS ==="
input bool   InpShowVisuals   = true;      // Show Visuals
input color  InpColorHH       = clrBlue;   // Color HH (1.000)
input color  InpColorLL       = clrRed;    // Color LL (0.000)
input color  InpColorPivot    = clrYellow; // Color Pivot (0.500)
input color  InpColorExtUp    = clrAqua;   // Color Extension Up
input color  InpColorExtDn    = clrOrange; // Color Extension Down
input color  InpColorBuyZone  = clrGreen;  // Color Buy Zone (Support)
input color  InpColorSellZone = clrRed;    // Color Sell Zone (Resistance)

input group "=== STRATEGY SETTINGS ==="
input string InpTargetSymbol   = "XAUUSD";   // Target Symbol (e.g. XAUUSD)
input double InpSRDistRatio   = 0.382;     // SR Zone Width (x Range)
input long   InpMagicNumber   = 123456;    // Magic Number

//--- CONSTANTS
#define PREFIX "DSR_"
#define RANGE_M15_CANDLES 8
#define MAX_M15_SCAN      1000 
#define MIN_RANGE_PIPS    10

//--- STRUCTURES
struct SR_Level {
   double      price;
   double      multiplier;
   ENUM_SR_STATE state;
   string      line_name;
   string      zone_name;
   bool        is_reference; 
};

//--- GLOBAL VARIABLES
ENUM_STATE   g_State = STATE_RANGE_BUILDING;
datetime     g_H8Time = 0;
double       g_BldHH = 0;
double       g_BldLL = 0;
double       g_Range = 0;
int          g_M15Count = 0;
SR_Level     g_Levels[];
int          g_TotalLevels = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   if(_Symbol != InpTargetSymbol) {
      Print("DynamicSR: Symbol mismatch. Target: ", InpTargetSymbol, " | Current: ", _Symbol);
      return(INIT_FAILED);
   }
   EventSetTimer(1);
   PerformRecoveryScan();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   DeleteObjects();
   EventKillTimer();
}

void OnTick() {
   if(!InpShowVisuals) return;
   MaintainVisuals();

   datetime currentH8 = GetH8Time();
   if(currentH8 != g_H8Time) CheckH8(currentH8);

   if(g_State == STATE_RANGE_BUILDING) {
      ENUM_SCAN_RESULT res = ScanM15Range(currentH8, g_BldHH, g_BldLL);
      if(res == SCAN_SUCCESS) {
         g_Range = g_BldHH - g_BldLL;
         double minRange = MIN_RANGE_PIPS * _Point * 10;
         if(g_Range >= minRange) {
            BuildGrid();
            g_State = STATE_ACTIVE;
         }
      }
   } 
   else if(g_State == STATE_ACTIVE) {
      if(IsNewM15Bar()) UpdateSR();
   }
}

void OnTimer() {}

//+------------------------------------------------------------------+
//| CORE LOGIC FUNCTIONS                                             |
//+------------------------------------------------------------------+

void MaintainVisuals() {
   if(g_TotalLevels <= 0) return;
   datetime right_time = TimeCurrent() + PeriodSeconds()*15;
   datetime left_time  = TimeCurrent() - PeriodSeconds()*10;

   for(int i=0; i<g_TotalLevels; i++) {
      if(ObjectFind(0, g_Levels[i].line_name) >= 0) {
         ObjectSetInteger(0, g_Levels[i].line_name, OBJPROP_TIME, 0, TimeCurrent() - PeriodSeconds()*5);
         ObjectSetInteger(0, g_Levels[i].line_name, OBJPROP_TIME, 1, right_time);
      }
      if(!g_Levels[i].is_reference && ObjectFind(0, g_Levels[i].zone_name) >= 0) {
         ObjectSetInteger(0, g_Levels[i].zone_name, OBJPROP_TIME, 0, left_time);
         ObjectSetInteger(0, g_Levels[i].zone_name, OBJPROP_TIME, 1, right_time);
      }
   }
}

datetime GetH8Time() {
   datetime times[];
   if(CopyTime(_Symbol, PERIOD_H8, 0, 1, times) > 0) return times[0];
   return 0;
}

void CheckH8(datetime newH8Time) {
   g_H8Time = newH8Time;
   g_State = STATE_RANGE_BUILDING;
   g_M15Count = 0;
   Print("DynamicSR: New H8 detected. Resetting to RANGE_BUILDING.");
}

ENUM_SCAN_RESULT ScanM15Range(datetime h8_open, double &out_hh, double &out_ll) {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   datetime fetch_start = h8_open - (24 * 3600); 
   int copied = CopyRates(_Symbol, PERIOD_M15, fetch_start, MAX_M15_SCAN, rates);
   if(copied <= 0) return SCAN_INCOMPLETE;

   int first_idx = -1;
   for(int i = 0; i < copied; i++) {
      if(rates[i].time >= h8_open) { first_idx = i; break; }
   }
   if(first_idx == -1) return SCAN_INCOMPLETE;

   double temp_hh = rates[first_idx].high;
   double temp_ll = rates[first_idx].low;
   int count = 1;

   for(int j = first_idx - 1; j >= 0; j--) {
      long diff = (long)rates[j+1].time - (long)rates[j].time;
      if(diff > (2 * 15 * 60)) return SCAN_GAP_DETECTED;
      if(rates[j].high > temp_hh) temp_hh = rates[j].high;
      if(rates[j].low < temp_ll)  temp_ll = rates[j].low;
      count++;
      if(count >= RANGE_M15_CANDLES) break;
   }

   if(count < RANGE_M15_CANDLES) return SCAN_INCOMPLETE;
   out_hh = temp_hh; out_ll = temp_ll;
   return SCAN_SUCCESS;
}

void BuildGrid() {
   DeleteObjects(); 
   double multipliers[] = {0.0, 0.5, 1.0, 1.618, 2.618, 4.236, 6.854, -1.618, -2.618, -4.236, -6.854};
   int total = ArraySize(multipliers);
   ArrayResize(g_Levels, total);
   g_TotalLevels = total;

   for(int i=0; i<total; i++) {
      g_Levels[i].multiplier = multipliers[i];
      g_Levels[i].price = g_BldLL + (g_Range * multipliers[i]);
      g_Levels[i].state = SR_NEUTRAL;
      g_Levels[i].line_name = PREFIX + "L_" + IntegerToString(i);
      g_Levels[i].zone_name = PREFIX + "Z_" + IntegerToString(i);
      g_Levels[i].is_reference = (MathAbs(multipliers[i] - 0.0) < 0.001 || MathAbs(multipliers[i] - 1.0) < 0.001);
      
      ObjectCreate(0, g_Levels[i].line_name, OBJ_TREND, 0, TimeCurrent(), g_Levels[i].price, TimeCurrent() + PeriodSeconds()*10, g_Levels[i].price);
      ObjectSetInteger(0, g_Levels[i].line_name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, g_Levels[i].line_name, OBJPROP_COLOR, GetLevelColor(multipliers[i]));
      
      if(!g_Levels[i].is_reference) {
         ObjectCreate(0, g_Levels[i].zone_name, OBJ_RECTANGLE, 0, TimeCurrent(), g_Levels[i].price, TimeCurrent() + PeriodSeconds()*10, g_Levels[i].price);
         ObjectSetInteger(0, g_Levels[i].zone_name, OBJPROP_FILL, true);
         ObjectSetInteger(0, g_Levels[i].zone_name, OBJPROP_BACK, true);
      }
   }
}

void UpdateSR() {
   double close_price = iClose(_Symbol, PERIOD_M15, 1);
   double srDist = g_Range * InpSRDistRatio;
   for(int i=0; i<g_TotalLevels; i++) {
      if(g_Levels[i].is_reference) continue;
      double lvl = g_Levels[i].price;
      if(g_Levels[i].state == SR_NEUTRAL) {
         if(close_price > lvl) g_Levels[i].state = SR_SUPPORT;
         else if(close_price < lvl) g_Levels[i].state = SR_RESISTANCE;
      }
      else if(g_Levels[i].state == SR_SUPPORT) {
         if(close_price < lvl - srDist) g_Levels[i].state = SR_RESISTANCE;
      }
      else if(g_Levels[i].state == SR_RESISTANCE) {
         if(close_price > lvl + srDist) g_Levels[i].state = SR_SUPPORT;
      }
      color zone_col = (g_Levels[i].state == SR_SUPPORT) ? InpColorBuyZone : (g_Levels[i].state == SR_RESISTANCE) ? InpColorSellZone : clrNONE;
      ObjectSetInteger(0, g_Levels[i].line_name, OBJPROP_TIME, 0, TimeCurrent() - PeriodSeconds()*5);
      ObjectSetInteger(0, g_Levels[i].line_name, OBJPROP_TIME, 1, TimeCurrent() + PeriodSeconds()*15);
      if(zone_col != clrNONE) {
         ObjectSetInteger(0, g_Levels[i].zone_name, OBJPROP_FILL, true);
         ObjectSetInteger(0, g_Levels[i].zone_name, OBJPROP_COLOR, zone_col);
         ObjectSetDouble(0, g_Levels[i].zone_name, OBJPROP_PRICE, 0, lvl);
         ObjectSetDouble(0, g_Levels[i].zone_name, OBJPROP_PRICE, 1, lvl + (g_Levels[i].state == SR_SUPPORT ? -srDist : srDist));
      } else {
         ObjectSetInteger(0, g_Levels[i].zone_name, OBJPROP_FILL, false);
      }
   }
}

void PerformRecoveryScan() {
   datetime h8 = GetH8Time();
   double hh, ll;
   ENUM_SCAN_RESULT res = ScanM15Range(h8, hh, ll);
   if(res == SCAN_SUCCESS) {
      g_H8Time = h8; g_BldHH = hh; g_BldLL = ll; g_Range = hh - ll;
      BuildGrid(); g_State = STATE_ACTIVE;
      Print("DynamicSR: Recovery successful (Current H8).");
   } else {
      datetime prevH8 = h8 - (8 * 3600);
      Print("DynamicSR: Current H8 incomplete. Trying fallback (Previous H8)...");
      res = ScanM15Range(prevH8, hh, ll);
      if(res == SCAN_SUCCESS) {
         g_H8Time = prevH8; g_BldHH = hh; g_BldLL = ll; g_Range = hh - ll;
         BuildGrid(); g_State = STATE_ACTIVE;
         Print("DynamicSR: Recovery successful (Fallback H8 found).");
      } else {
         Print("DynamicSR: Recovery failed for both. Check if M15 history is loaded!");
      }
   }
}

bool IsNewM15Bar() {
   static datetime last_m15 = 0;
   datetime current_m15 = iTime(_Symbol, PERIOD_M15, 0);
   if(current_m15 != last_m15) { last_m15 = current_m15; return true; }
   return false;
}

color GetLevelColor(double mult) {
   if(MathAbs(mult - 0.0) < 0.001) return InpColorLL;
   if(MathAbs(mult - 1.0) < 0.001) return InpColorHH;
   if(MathAbs(mult - 0.5) < 0.001) return InpColorPivot;
   return (mult < 0) ? InpColorExtDn : InpColorExtUp;
}

void DeleteObjects() {
   ObjectsDeleteAll(0, PREFIX);
}
```