//+------------------------------------------------------------------+
//|                                                     guppy_mma.mq5 |
//|                                          © mladen, 2016          |
//|                                    www.forex-tsd.com, mql5.com   |
//+------------------------------------------------------------------+
#property copyright "© mladen, 2016, MetaQuotes Software Corp."
#property link      "www.forex-tsd.com, www.mql5.com"
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 13
#property indicator_plots   12
//+------------------------------------------------------------------+

input ENUM_TIMEFRAMES    TimeFrame   = PERIOD_CURRENT;  // Time frame
input ENUM_APPLIED_PRICE Price       = PRICE_CLOSE;     // Guppy MMAs price
input ENUM_MA_METHOD     Method      = MODE_EMA;         // Guppy MMAs method
input color              ColorFrom   = Lime;             // Starting color for MAs
input color              ColorTo     = MediumVioletRed;  // Ending color for MAs
input bool               Interpolate = true;             // Interpolate when in multi time frame mode?

double count[]; ENUM_TIMEFRAMES timeFrame;

//+------------------------------------------------------------------+
struct simpleMa { int handle; double buffer[]; };
       simpleMa aBuffers[12];
int steps;

//+------------------------------------------------------------------+
int OnInit()
{
   int periods[] = {3,5,8,10,12,15,30,35,40,45,50,60};
       steps     = ArraySize(periods);

       timeFrame = MathMax(_Period,TimeFrame);
       for (int i=0;i<steps; i++)
       {
         if (timeFrame==_Period)
            { int handle = iMA(NULL,0,periods[i],0,Method,Price); aBuffers[i].handle = handle; }
            SetIndexBuffer(i,aBuffers[i].buffer,INDICATOR_DATA);
               PlotIndexSetInteger(i,PLOT_DRAW_TYPE,DRAW_LINE);
               PlotIndexSetInteger(i,PLOT_COLOR_INDEXES,1);
               PlotIndexSetInteger(i,PLOT_LINE_COLOR,gradientColor(i,steps,ColorFrom,ColorTo));
               PlotIndexSetString(i,PLOT_LABEL,"Guppy MA "+IntegerToString(periods[i]));
       }
       SetIndexBuffer(12,count,INDICATOR_CALCULATIONS);
   IndicatorSetString(INDICATOR_SHORTNAME,timeFrameToString(timeFrame)+" Guppy MMA");
   return(0);
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime& time[],
                const double& open[],
                const double& high[],
                const double& low[],
                const double& close[],
                const long& tick_volume[],
                const long& volume[],
                const int& spread[])
{
   if (Bars(_Symbol,_Period)<rates_total) return(-1);

      if (timeFrame!=_Period)
      {
         double result[]; datetime currTime[],nextTime[];
         static int indHandle =-1;
                if (indHandle==-1) indHandle = iCustom(_Symbol,timeFrame,getIndicatorName(),PERIOD_CURRENT,Price,Method);
                if (indHandle==-1)                          return(0);
                if (CopyBuffer(indHandle,12,0,1,result)==-1) return(0);

                #define _processed EMPTY_VALUE-1
                int i,limit = rates_total-(int)MathMin(result[0]*PeriodSeconds(timeFrame)/PeriodSeconds(_Period),rates_total);
                for (limit=MathMax(limit,0); limit>0 && !IsStopped(); limit--) if (count[limit]==_processed) break;
                for (i=MathMin(limit,MathMax(prev_calculated-1,0)); i<rates_total && !IsStopped(); i++    )
                {
                  bool OK = true;
                     for (int b=0; b<steps; b++) { if (CopyBuffer(indHandle,b,time[i],1,result)==-1) { OK=false; break; } aBuffers[b].buffer[i] = result[0]; } if (!OK) break;
                                                                                                                          count[i]              = _processed;

                   #define _interpolate(buff,i,k,n) buff[i-k] = buff[i]+(buff[i-n]-buff[i])*k/n
                   if (!Interpolate) continue; CopyTime(_Symbol,TimeFrame,time[i  ],1,currTime);
                      if (i<(rates_total-1)) { CopyTime(_Symbol,TimeFrame,time[i+1],1,nextTime); if (currTime[0]==nextTime[0]) continue; }
                      int n,k;
                         for(n=1; (i-n)> 0 && time[i-n] >= currTime[0]; n++) continue;
                         for(k=1; (i-k)>=0 && k<n; k++)
                           for (int b=0; b<steps; b++)  _interpolate(aBuffers[b].buffer,i,k,n);
                }
                if (i!=rates_total) return(0); return(rates_total);
      }

   int limit = rates_total-prev_calculated; if (prev_calculated > 0) limit++;
            for (int i=0; i<steps; i++)
                     CopyBuffer(aBuffers[i].handle,0,0,limit,aBuffers[i].buffer);
   count[rates_total-1] = MathMax(rates_total-prev_calculated+1,1);
   return(rates_total);
}

//+------------------------------------------------------------------+
color gradientColor(int step, int totalSteps, color from, color to)
{
   color newBlue  = getColor(step,totalSteps,(from & 0XFF0000)>>16,(to & 0XFF0000)>>16)<<16;
   color newGreen = getColor(step,totalSteps,(from & 0X00FF00)>> 8,(to & 0X00FF00)>> 8) <<8;
   color newRed   = getColor(step,totalSteps,(from & 0X0000FF)    ,(to & 0X0000FF)    )    ;
   return(newBlue+newGreen+newRed);
}

color getColor(int stepNo, int totalSteps, color from, color to)
{
   double step = (from-to)/(totalSteps-1.0);
   return((color)round(from-step*stepNo));
}

//+------------------------------------------------------------------+
string getIndicatorName()
{
   string progPath = MQL5InfoString(MQL5_PROGRAM_PATH); int start=-1;
   while (true)
   {
      int foundAt = StringFind(progPath,"\\",start+1);
      if (foundAt>=0)
               start = foundAt;
      else  break;
   }

   string indicatorName = StringSubstr(progPath,start+1);
          indicatorName = StringSubstr(indicatorName,0,StringLen(indicatorName)-4);
   return(indicatorName);
}

//+------------------------------------------------------------------+
int    _tfsPer[]={PERIOD_M1,PERIOD_M2,PERIOD_M3,PERIOD_M4,PERIOD_M5,PERIOD_M6,PERIOD_M10,PERIOD_M12,PERIOD_M15,PERIOD_M20,PERIOD_M30,PERIOD_H1,PERIOD_H2,PERIOD_H3,PERIOD_H4,PERIOD_H6,PERIOD_H8,PERIOD_H12,PERIOD_D1,PERIOD_W1,PERIOD_MN1};
string _tfsStr[]={"1 minute","2 minutes","3 minutes","4 minutes","5 minutes","6 minutes","10 minutes","12 minutes","15 minutes","20 minutes","30 minutes","1 hour","2 hours","3 hours","4 hours","6 hours","8 hours","12 hours","daily","weekly","monthly"};
string timeFrameToString(int period)
{
   if (period==PERIOD_CURRENT)
       period = _Period;
         int i; for(i=ArraySize(_tfsPer)-1;i>=0;i--) if(period==_tfsPer[i]) break;
   return(_tfsStr[i]);
}
//+------------------------------------------------------------------+