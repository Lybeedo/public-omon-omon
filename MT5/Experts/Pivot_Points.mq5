//+------------------------------------------------------------------+
//|                                                  Pivot_Points.mq5 |
//|                                  Copyright 2026, Paulus Is/Hermes |
//|                                             https://github.com/Lybeedo|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Paulus Is/Hermes"
#property link      "https://github.com/Lybeedo"
#property version   "1.00"
#property strict

//--- Enumerations
enum ENUM_PIVOT_MODE {
   MODE_CLASSIC,       // Classic
   MODE_FIBONACCI,     // Fibonacci
   MODE_DEMARK        // DeMark
};

enum ENUM_TIMEFRAME_CHOICE {
   TF_D1 = PERIOD_D1,     // Daily (D1)
   TF_H4 = PERIOD_H4,     // H4
   TF_H1 = PERIOD_H1,     // H1
   TF_M30 = PERIOD_M30,   // M30
   TF_M15 = PERIOD_M15    // M15
};

//--- Input Parameters
input ENUM_PIVOT_MODE InpMode = MODE_CLASSIC;      // Pivot Mode
input ENUM_TIMEFRAME_CHOICE InpTF = TF_D1;         // Timeframe

//--- Global Variables
double pp, r1, r2, r3, s1, s2, s3;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("Pivot Points EA Started. Mode: ", EnumToString(InpMode), " TF: ", EnumToString((ENUM_TIMEFRAMES)InpTF));
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "PIVOT_");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   CalculatePivots();
   DrawLevels();
}

//+------------------------------------------------------------------+
//| Core Calculation Logic                                           |
//+------------------------------------------------------------------+
void CalculatePivots()
{
   ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)InpTF;
   
   double high  = iHigh(_Symbol, tf, 1);
   double low   = iLow(_Symbol, tf, 1);
   double close = iClose(_Symbol, tf, 1);
   double open  = iOpen(_Symbol, tf, 1);

   if(high == 0 || low == 0 || close == 0) return;

   if(InpMode == MODE_CLASSIC) {
      pp = (high + low + close) / 3.0;
      r1 = (2.0 * pp) - low;
      s1 = (2.0 * pp) - high;
      r2 = pp + (high - low);
      s2 = pp - (high - low);
      r3 = high + 2.0 * (pp - low);
      s3 = low - 2.0 * (high - pp);
   }
   else if(InpMode == MODE_FIBONACCI) {
      pp = (high + low + close) / 3.0;
      r1 = pp + (0.382 * (high - low));
      r2 = pp + (0.618 * (high - low));
      r3 = pp + (1.000 * (high - low));
      s1 = pp - (0.382 * (high - low));
      s2 = pp - (0.618 * (high - low));
      s3 = pp - (1.000 * (high - low));
   }
   else if(InpMode == MODE_DEMARK) {
      double x;
      if(close < open) x = high + (2.0 * low) + close;
      else if(close > open) x = (2.0 * high) + low + close;
      else x = high + low + (2.0 * close);
      
      pp = x / 4.0;
      r1 = (2.0 * pp) - low;
      s1 = (2.0 * pp) - high;
   }
}

//+------------------------------------------------------------------+
//| Drawing Logic                                                    |
//+------------------------------------------------------------------+
void DrawLevels()
{
   CreateLine("PIVOT_PP", pp, clrYellow);
   if(r1 > 0) CreateLine("PIVOT_R1", r1, clrRed);
   if(s1 > 0) CreateLine("PIVOT_S1", s1, clrLime);
   if(r2 > 0) CreateLine("PIVOT_R2", r2, clrRed);
   if(s2 > 0) CreateLine("PIVOT_S2", s2, clrLime);
}

void CreateLine(string name, double price, color clr)
{
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
   } else {
      ObjectMove(0, name, 0, 0, price);
   }
}
