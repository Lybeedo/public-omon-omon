//+------------------------------------------------------------------+
//| VPA_BDTL_Volume_V10.mq5                                          |
//| Volume Price Analysis + Break of Structure DTL + Volume           |
//| Converted from TradingView Pine Script v10.0                      |
//| Original: VPA + BDTL + VOLUME v10.0                               |
//+------------------------------------------------------------------+
#property copyright "Converted: Pine Script v10.0 -> MQL5"
#property version   "1.000"
#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots   5

//+------------------------------------------------------------------+
//| Buffer IDs                                                       |
//+------------------------------------------------------------------+
#define BUF_RSI        0  // RSI(14)
#define BUF_EMA        1  // EMA(50)
#define BUF_DTL        2  // DTL line
#define BUF_TSL        3  // Trailing Stop
#define BUF_BPR        4  // Buying Pressure
#define BUF_SPR        5  // Selling Pressure
#define BUF_DTL_BRK    6  // DTL Breakout signal
#define BUF_VPA_STATUS 7  // VPA status buffer


//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
group_vpa(string)  "VPA Sniper Settings"
group_dtl(string)  "Structural DTL Settings"
group_trade(string) "Trade Management"
group_vis(string)  "Dashboard & Visuals"

// VPA
input float  InpVolMult     = 1.2;   group=group_vpa
input float  InpSpreadMult  = 1.1;   group=group_vpa

// DTL
input int    InpPivotLB     = 10;    group=group_dtl

// TSL
input float  InpTSLMult     = 2.0;   group=group_trade

// Visuals
input string InpDashPos     = "Top Right"; group=group_vis

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
double ExtRSIBuffer[];
double ExtEMABuffer[];
double ExtDTLBuffer[];
double ExtTSLBuffer[];
double ExtBPRBuffer[];
double ExtSPRBuffer[];
double ExtDTLBrkBuffer[];
double ExtVPAStatusBuffer[];

//--- DTL pivot state
double gP1Y = EMPTY_VALUE, gP2Y = EMPTY_VALUE;
int    gP1X = 0, gP2X = 0;
double gSlope = 0.0;
double gLastPH = 0.0;

//--- ATR handle
int gAtrHandle = INVALID_HANDLE;
double gAtrBuffer[];

//--- EMA handle
int gEmaHandle = INVALID_HANDLE;
double gEmaBuffer[];

//--- Table
long gTableId = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set indicator buffers
   SetIndexBuffer(BUF_RSI,       ExtRSIBuffer,       INDICATOR_DATA);
   SetIndexBuffer(BUF_EMA,       ExtEMABuffer,       INDICATOR_DATA);
   SetIndexBuffer(BUF_DTL,        ExtDTLBuffer,       INDICATOR_DATA);
   SetIndexBuffer(BUF_TSL,        ExtTSLBuffer,       INDICATOR_CALCULATIONS);
   SetIndexBuffer(BUF_BPR,        ExtBPRBuffer,        INDICATOR_DATA);
   SetIndexBuffer(BUF_SPR,        ExtSPRBuffer,        INDICATOR_DATA);
   SetIndexBuffer(BUF_DTL_BRK,    ExtDTLBrkBuffer,    INDICATOR_DATA);
   SetIndexBuffer(BUF_VPA_STATUS, ExtVPAStatusBuffer, INDICATOR_DATA);

   // Plot settings
   PlotIndexSetString(0, PLOT_LABEL, "RSI(14)");
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, clrDodgerBlue);

   PlotIndexSetString(1, PLOT_LABEL, "EMA(50)");
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, clrLime);

   PlotIndexSetString(2, PLOT_LABEL, "DTL");
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_SECTION);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, clrRed);
   PlotIndexSetInteger(2, PLOT_LINE_STYLE, STYLE_DASH);

   PlotIndexSetString(3, PLOT_LABEL, "TSL");
   PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, clrRed);

   PlotIndexSetString(4, PLOT_LABEL, "BuyPressure");
   PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(4, PLOT_ARROW, 233); // Up arrow
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, clrLime);

   PlotIndexSetString(5, PLOT_LABEL, "SellPressure");
   PlotIndexSetInteger(5, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(5, PLOT_ARROW, 234); // Down arrow
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, clrRed);

   PlotIndexSetInteger(0, INDICATOR_DATA, 0);
   PlotIndexSetInteger(1, INDICATOR_DATA, 0);
   PlotIndexSetInteger(2, INDICATOR_DATA, 0);
   PlotIndexSetInteger(3, INDICATOR_DATA, 0);
   PlotIndexSetInteger(4, INDICATOR_DATA, 0);
   PlotIndexSetInteger(5, INDICATOR_DATA, 0);

   // Create handles
   gAtrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
   if(gAtrHandle == INVALID_HANDLE) { Print("[VPA] ATR handle error!"); return(INIT_FAILED); }

   gEmaHandle = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(gEmaHandle == INVALID_HANDLE) { Print("[VPA] EMA handle error!"); return(INIT_FAILED); }

   // Reset DTL state
   gP1Y = EMPTY_VALUE; gP2Y = EMPTY_VALUE;
   gP1X = 0; gP2X = 0; gSlope = 0.0; gLastPH = 0.0;

   // Create dashboard table
   gTableId = (long)ChartGetInteger(0, CHART_ID);
   ObjectCreate(0, "VPA_Table", OBJ_RECTANGLE_LABEL, 0, 0, 0, 0, 0);
   ObjectSetInteger(0, "VPA_Table", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "VPA_Table", OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, "VPA_Table", OBJPROP_XSIZE, 220);
   ObjectSetInteger(0, "VPA_Table", OBJPROP_YSIZE, 320);
   ObjectSetInteger(0, "VPA_Table", OBJPROP_BGCOLOR, C'15,15,15');
   ObjectSetInteger(0, "VPA_Table", OBJPROP_BORDER_COLOR, clrGray);
   ObjectSetInteger(0, "VPA_Table", OBJPROP_ZORDER, 1);

   IndicatorSetString(INDICATOR_SHORTNAME, "VPA+BDTL+v10.0");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(gAtrHandle != INVALID_HANDLE) IndicatorRelease(gAtrHandle);
   if(gEmaHandle != INVALID_HANDLE) IndicatorRelease(gEmaHandle);
   ObjectDelete(0, "VPA_Table");
   Comment("");
}

//+------------------------------------------------------------------+
//| CalculateVolumeSignals                                           |
//+------------------------------------------------------------------+
void CalculateVolumeSignals(int shift, double& volAvg, double& bodySize,
                             double& lowerWick, double& upperWick,
                             double& spread, double& avgSpread,
                             bool& isHighVol, bool& isWideSpread,
                             bool& isNarrowSpread)
{
   if(shift < 20) { volAvg = 0; spread = 0; avgSpread = 0; return; }

   double volSum = 0;
   for(int i = shift; i < shift + 20; i++) volSum += (double)Volume[i];
   volAvg = volSum / 20.0;

   double highC = High[iHighest(NULL, 0, MODE_HIGH, 20, shift)];
   double lowC  = Low[iLowest(NULL, 0, MODE_LOW,  20, shift)];
   double avgH  = 0, avgL = 0;
   for(int i = shift; i < shift + 20; i++) { avgH += High[i]; avgL += Low[i]; }
   avgSpread = (avgH - avgL) / 20.0;

   spread     = High[shift] - Low[shift];
   bodySize   = MathAbs(Close[shift] - Open[shift]);
   lowerWick  = MathMin(Open[shift], Close[shift]) - Low[shift];
   upperWick  = High[shift] - MathMax(Open[shift], Close[shift]);

   isHighVol     = (Volume[shift] > volAvg * InpVolMult);
   isWideSpread  = (spread > avgSpread * InpSpreadMult);
   isNarrowSpread = (spread < avgSpread * 0.7);
}

//+------------------------------------------------------------------+
//| CalculateEMA                                                     |
//+------------------------------------------------------------------+
double CalcEMA(int shift, int period, int handle, double& emaBuffer[])
{
   double ema = 0;
   if(handle != INVALID_HANDLE)
   {
      if(CopyBuffer(handle, 0, shift, 1, emaBuffer) <= 0)
         return ema;
      ema = emaBuffer[0];
   }
   return ema;
}

//+------------------------------------------------------------------+
//| CalculateVPA                                                     |
//+------------------------------------------------------------------+
bool IsVPABullValid(bool isHighVol, bool isWideSpread)
{
   return (Close[0] > Open[0]) && isHighVol && isWideSpread;
}

bool IsVPABearValid(bool isHighVol, bool isWideSpread)
{
   return (Close[0] < Open[0]) && isHighVol && isWideSpread;
}

bool IsVPASquat(bool isHighVol, bool isNarrowSpread)
{
   return isHighVol && isNarrowSpread;
}

//+------------------------------------------------------------------+
//| DTL Breakout Detection                                           |
//+------------------------------------------------------------------+
void UpdateDTL(int shift)
{
   double ph = iCustomPivotHigh(shift, InpPivotLB);

   if(ph > 0 && ph != gLastPH)
   {
      gP2Y = gP1Y; gP2X = gP1X;
      gP1Y = ph;
      gP1X = shift - InpPivotLB;
      gLastPH = ph;

      if(gP2X > 0 && gP1X > 0 && gP2X != gP1X)
         gSlope = (gP1Y - gP2Y) / (double)(gP1X - gP2X);
   }
}

//+------------------------------------------------------------------+
//| Custom Pivot High                                                |
//+------------------------------------------------------------------+
double iCustomPivotHigh(int shift, int lookback)
{
   if(shift < lookback) return 0;
   double peak = High[shift];
   for(int i = 1; i <= lookback; i++)
   {
      if(High[shift - i] > peak) return 0;
   }
   for(int i = 1; i <= lookback; i++)
   {
      if(High[shift + i] > peak) return 0;
   }
   return peak;
}

//+------------------------------------------------------------------+
//| GetDTLPrice                                                      |
//+------------------------------------------------------------------+
double GetDTLPrice(int shift)
{
   if(gP1Y == EMPTY_VALUE || gP2Y == EMPTY_VALUE || gP1X == 0) return 0;
   if(gP1Y >= gP2Y) return 0;
   return gP1Y + gSlope * (double)(shift - gP1X);
}

//+------------------------------------------------------------------+
//| GetEMASlope & Trend                                              |
//+------------------------------------------------------------------+
double GetEMASlope(int emaHandle, int shift)
{
   double emaCur = 0, emaPrev = 0;
   double buf1[], buf2[];

   if(emaHandle != INVALID_HANDLE)
   {
      CopyBuffer(emaHandle, 0, shift, 1, buf1);
      CopyBuffer(emaHandle, 0, shift + 5, 1, buf2);
      if(ArraySize(buf1) > 0 && ArraySize(buf2) > 0)
      {
         emaCur = buf1[0]; emaPrev = buf2[0];
         if(emaPrev != 0) return (emaCur - emaPrev) / emaPrev * 100.0;
      }
   }
   return 0.0;
}

string GetTrendStrength(double emaSlope)
{
   if(emaSlope > 0.1)  return "STRONG BULL";
   if(emaSlope > 0)    return "WEAK BULL";
   if(emaSlope > -0.1) return "WEAK BEAR";
   return "STRONG BEAR";
}

color GetTrendColor(double emaSlope)
{
   if(emaSlope > 0.1)  return clrLime;
   if(emaSlope > 0)    return clrMediumSeaGreen;
   if(emaSlope > -0.1) return clrOrange;
   return clrRed;
}

//+------------------------------------------------------------------+
//| UpdateDashboard                                                  |
//+------------------------------------------------------------------+
void UpdateDashboard(double rsiVal, double emaSlope, string trendStr,
                     color trendCol, bool buySig, bool squat,
                     bool bullVPA, bool bearVPA, string tf)
{
   string vpaLabel;
   color vpaColor;
   if(squat)      { vpaLabel = "SQUAT TRAP"; vpaColor = clrOrange; }
   else if(bullVPA){ vpaLabel = "VALID BULL"; vpaColor = clrLime; }
   else if(bearVPA){ vpaLabel = "VALID BEAR"; vpaColor = clrRed; }
   else           { vpaLabel = "NEUTRAL";    vpaColor = clrGray; }

   string aiLabel;
   color aiColor;
   if(buySig)     { aiLabel = "BUY NOW"; aiColor = clrLime; }
   else if(squat) { aiLabel = "CAUTION"; aiColor = clrOrange; }
   else           { aiLabel = "WAIT";    aiColor = clrDarkGray; }

   color rsiBg = (rsiVal > 70) ? clrRed : (rsiVal < 30) ? clrLime : clrDimGray;

   // Labels
   string labels[];
   string values[];
   color  bgs[];
   color  txts[];

   ArrayResize(labels, 7);
   ArrayResize(values, 7);
   ArrayResize(bgs, 7);
   ArrayResize(txts, 7);

   labels[0] = "MASTER VPA v10.0";  values[0] = tf + "M";   bgs[0] = clrDodgerBlue; txts[0] = clrWhite;
   labels[1] = "RSI (14)";           values[1] = DoubleToString(rsiVal, 2); bgs[1] = rsiBg;  txts[1] = clrWhite;
   labels[2] = "Trend";              values[2] = trendStr;    bgs[2] = trendCol;  txts[2] = clrWhite;
   labels[3] = "VPA Status";         values[3] = vpaLabel;   bgs[3] = vpaColor; txts[3] = clrWhite;
   labels[4] = "AI Suggestion";      values[4] = aiLabel;    bgs[4] = aiColor;  txts[4] = clrWhite;
   labels[5] = "VPA Bull";           values[5] = bullVPA ? "ON" : "OFF"; bgs[5] = bullVPA ? clrLime : clrDimGray; txts[5] = clrWhite;
   labels[6] = "Squat";              values[6] = squat ? "YES" : "NO"; bgs[6] = squat ? clrOrange : clrDimGray; txts[6] = clrWhite;

   int cols = 2;
   int rows = ArraySize(labels);
   int xBase = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) - 250;
   int yBase = 30;

   for(int r = 0; r < rows; r++)
   {
      string lblObj = "VPA_L" + IntegerToString(r);
      string valObj = "VPA_V" + IntegerToString(r);

      ObjectCreate(0, lblObj, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, lblObj, OBJPROP_XDISTANCE, xBase);
      ObjectSetInteger(0, lblObj, OBJPROP_YDISTANCE, yBase + r * 24);
      ObjectSetString(0, lblObj, OBJPROP_TEXT, labels[r]);
      ObjectSetInteger(0, lblObj, OBJPROP_COLOR, txts[r]);
      ObjectSetInteger(0, lblObj, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, lblObj, OBJPROP_ZORDER, 2);

      ObjectCreate(0, valObj, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, valObj, OBJPROP_XDISTANCE, xBase + 110);
      ObjectSetInteger(0, valObj, OBJPROP_YDISTANCE, yBase + r * 24);
      ObjectSetString(0, valObj, OBJPROP_TEXT, values[r]);
      ObjectSetInteger(0, valObj, OBJPROP_COLOR, txts[r]);
      ObjectSetInteger(0, valObj, OBJPROP_BGCOLOR, bgs[r]);
      ObjectSetInteger(0, valObj, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, valObj, OBJPROP_ZORDER, 2);
   }
}

//+------------------------------------------------------------------+
//| DrawVPAAnnotations                                               |
//+------------------------------------------------------------------+
void DrawVPAAnnotations(bool dtlBreak, bool squat, bool bullVPA, bool bearVPA)
{
   if(dtlBreak)
   {
      string obj = "VPA_DTLBrk";
      ObjectCreate(0, obj, OBJ_ARROW_BUY, 0, Time[0], Low[0] - 30*_Point);
      ObjectSetInteger(0, obj, OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, obj, OBJPROP_ARROW_CODE, 233);
      ObjectSetString(0, obj, OBJPROP_TEXT, "VPA+DTL");
   }
   if(squat)
   {
      string obj = "VPA_Squat";
      ObjectCreate(0, obj, OBJ_TEXT, 0, Time[0], High[0] + 50*_Point);
      ObjectSetString(0, obj, OBJPROP_TEXT, "SQUAT");
      ObjectSetInteger(0, obj, OBJPROP_COLOR, clrOrange);
      ObjectSetInteger(0, obj, OBJPROP_FONTSIZE, 8);
   }
   // Candle coloring via comment
   string barColor = "";
   if(squat)       barColor = "ORANGE";
   else if(bullVPA) barColor = "GREEN";
   else if(bearVPA) barColor = "RED";
}

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < 60) return(0);

   int start = prev_calculated > 0 ? prev_calculated - 1 : 1;

   // Copy ATR & EMA
   double atrBuf[], emaBuf[];
   ArraySetAsSeries(atrBuf, true);
   ArraySetAsSeries(emaBuf, true);
   CopyBuffer(gAtrHandle, 0, 0, rates_total, atrBuf);
   CopyBuffer(gEmaHandle, 0, 0, rates_total, emaBuf);

   // TSL state
   static double prevTSL = 0;
   static bool inPos = false;

   for(int i = start; i < rates_total && !IsStopped(); i++)
   {
      //--- Global math every bar
      double volAvg = 0, bodySize = 0, lowerWick = 0, upperWick = 0;
      double spread_ = 0, avgSpread = 0;
      bool isHighVol = false, isWideSpread = false, isNarrowSpread = false;
      CalculateVolumeSignals(i, volAvg, bodySize, lowerWick, upperWick, spread_, avgSpread, isHighVol, isWideSpread, isNarrowSpread);

      //--- RSI
      ExtRSIBuffer[i] = iRSI(NULL, 0, 14, PRICE_CLOSE, i);

      //--- EMA
      if(i < ArraySize(emaBuf) && !MathIsValidNumber(emaBuf[i])) ExtEMABuffer[i] = emaBuf[i];

      //--- DTL
      UpdateDTL(i);
      double dtlPrice = GetDTLPrice(i);
      ExtDTLBuffer[i] = (dtlPrice > 0) ? dtlPrice : EMPTY_VALUE;

      //--- Buy signal: VPA bull valid + DTL breakout + EMA slope > -0.05
      double emaSlope = GetEMASlope(gEmaHandle, i);
      bool bullVPA = IsVPABullValid(isHighVol, isWideSpread);
      bool bearVPA = IsVPABearValid(isHighVol, isWideSpread);
      bool squat   = IsVPASquat(isHighVol, isNarrowSpread);

      bool dtlBreak = false;
      if(i >= 1 && dtlPrice > 0 && close[i] > dtlPrice && close[i-1] <= dtlPrice)
         dtlBreak = true;
      ExtDTLBrkBuffer[i] = dtlBreak ? High[i] : EMPTY_VALUE;

      bool buySignal = bullVPA && dtlBreak && (emaSlope > -0.05);
      ExtVPAStatusBuffer[i] = buySignal ? 1.0 : (squat ? 0.5 : 0.0);

      //--- Buying / Selling pressure
      bool buyPressure  = (lowerWick > bodySize * 2) && isHighVol;
      bool sellPressure = (upperWick > bodySize * 2) && isHighVol;
      ExtBPRBuffer[i] = buyPressure  ? Low[i]  : EMPTY_VALUE;
      ExtSPRBuffer[i] = sellPressure ? High[i] : EMPTY_VALUE;

      //--- TSL
      double atr = (i < ArraySize(atrBuf)) ? atrBuf[i] : 0;
      double tslCalc = (atr > 0) ? close[i] - atr * InpTSLMult : EMPTY_VALUE;

      if(buySignal) inPos = true;

      if(inPos)
      {
         if(buySignal || bearVPA)
         {
            double newTSL = (tslCalc > prevTSL) ? tslCalc : prevTSL;
            if(tslCalc > 0 || prevTSL > 0)
            {
               ExtTSLBuffer[i] = newTSL;
               prevTSL = newTSL;
            }
         }
      }
      else
      {
         prevTSL = 0;
         ExtTSLBuffer[i] = EMPTY_VALUE;
      }

      //--- Close position on TSL or bear VPA (no real trading here)
      if(inPos)
      {
         if(buySignal) inPos = false; // simple flip logic
         if(bearVPA)  inPos = false;
      }

      //--- Dashboard update on last bar
      if(i == rates_total - 1)
      {
         string tf = Period() >= 60 ? IntegerToString(Period()/60) + "H" : IntegerToString(Period());
         string trendStr = GetTrendStrength(emaSlope);
         color trendCol  = GetTrendColor(emaSlope);
         double rsiVal   = ExtRSIBuffer[i];
         UpdateDashboard(rsiVal, emaSlope, trendStr, trendCol, buySignal, squat, bullVPA, bearVPA, tf);
         DrawVPAAnnotations(dtlBreak, squat, bullVPA, bearVPA);

         // Candle colors via chart
         if(bullVPA) ChartSetInteger(0, CHART_BRING_TO_TOP, true); // just signal
      }
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
