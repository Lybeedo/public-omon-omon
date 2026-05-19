//+------------------------------------------------------------------+
//|                                      DarvasBox_Indicator.mq5      |
//|                                      Source: MQL5 Article #17466   |
//|                                      Darvas Box Breakout Logic     |
//+------------------------------------------------------------------+
#property copyright "Zhuo Kai Chen"
#property link      "https://www.mql5.com/en/articles/17466"
#property version   "1.00"
#property indicator_chart_window

input int lookBack  = 100;  // Lookback period for box detection
input int checkBar = 3;    // Number of confirmation bars (M)
input color boxColor = clrBlue;

//+------------------------------------------------------------------+
//| Global variables for Darvas Box                                   |
//+------------------------------------------------------------------+
double high;
double low;
bool   boxFormed = false;

//+------------------------------------------------------------------+
//| DetectDarvasBox                                                   |
//| Detects if there is a Darvas box for a given lookback period     |
//| and confirmation candle amount. Assigns high/low range to         |
//| variables and plots the box rectangle on the chart.              |
//+------------------------------------------------------------------+
bool DetectDarvasBox(int n = 100, int M = 3)
{
   // Clear previous Darvas box objects
   for(int k = ObjectsTotal(0, 0, -1) - 1; k >= 0; k--)
   {
      string name = ObjectName(0, k);
      if(StringFind(name, "DarvasBox_") == 0)
         ObjectDelete(0, name);
   }

   bool current_box_active = false;

   // Start checking from the oldest bar within the lookback period
   for(int i = M + 1; i <= n; i++)
   {
      // Get high of current bar and previous bar
      double high_current = iHigh(_Symbol, PERIOD_CURRENT, i);
      double high_prev    = iHigh(_Symbol, PERIOD_CURRENT, i + 1);

      // Check for a new high
      if(high_current > high_prev)
      {
         // Check if the next M bars do not exceed the high
         bool pullback = true;
         for(int k = 1; k <= M; k++)
         {
            if(i - k < 0)   // Ensure we don't go beyond available bars
            {
               pullback = false;
               break;
            }
            double high_next = iHigh(_Symbol, PERIOD_CURRENT, i - k);
            if(high_next > high_current)
            {
               pullback = false;
               break;
            }
         }

         // If pullback condition is met, define the box
         if(pullback)
         {
            double top    = high_current;
            double bottom = iLow(_Symbol, PERIOD_CURRENT, i);

            // Find the lowest low over the bar and the next M bars
            for(int k = 1; k <= M; k++)
            {
               double low_next = iLow(_Symbol, PERIOD_CURRENT, i - k);
               if(low_next < bottom)
                  bottom = low_next;
            }

            // Check for breakout from (i - M - 1) to current bar (index 0)
            int j = i - M - 1;
            while(j >= 0)
            {
               double close_j = iClose(_Symbol, PERIOD_CURRENT, j);
               if(close_j > top || close_j < bottom)
                  break;   // Breakout found
               j--;
            }
            j++;  // Adjust to the bar after breakout (or 0 if no breakout)

            // Create a unique object name
            string obj_name = "DarvasBox_" + IntegerToString(i);

            // Plot the box
            datetime time_start = iTime(_Symbol, PERIOD_CURRENT, i);
            datetime time_end;
            if(j > 0)
            {
               // Historical box: ends at breakout bar
               time_end = iTime(_Symbol, PERIOD_CURRENT, j);
            }
            else
            {
               // Current box: extends to current bar
               time_end = iTime(_Symbol, PERIOD_CURRENT, 0);
               current_box_active = true;
            }

            high = top;
            low = bottom;
            ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, time_start, top, time_end, bottom);
            ObjectSetInteger(0, obj_name, OBJPROP_COLOR, boxColor);
            ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
            boxFormed = true;

            // Since we're only plotting the most recent box, break after finding it
            break;
         }
      }
   }

   return current_box_active;
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
   // Reset box state on first calculation
   if(prev_calculated == 0)
   {
      boxFormed = false;
   }

   boxFormed = DetectDarvasBox(lookBack, checkBar);

   return rates_total;
}
//+------------------------------------------------------------------+