//+------------------------------------------------------------------+
//|                                                 EasyMath.mq5      |
//|                                                  Cuancux Algo    |
//+------------------------------------------------------------------+
#property copyright   "Cuancux Algo Traders"
#property version      "1.00"
#property indicator_chart_window
#property indicator_buffers   0

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input double InpParameter   = 0.21;   // Parameter (sqrt subtractor)
input bool   InpShowLabel   = true;   // Show price labels on chart

//+------------------------------------------------------------------+
//| Global variables                                                  |
//+------------------------------------------------------------------+
double gBuyEntry    = 0.0;
double gSellEntry   = 0.0;
double gHighPrice   = 0.0;
double gLowPrice    = 0.0;
double gRange       = 0.0;

//+------------------------------------------------------------------+
//| Custom indicator initialization                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   if(InpParameter < 0)
   {
      Print("InpParameter must be >= 0. Exiting.");
      return INIT_PARAMETERS_INCORRECT;
   }

   // Check for minimum bars
   if(Bars(_Symbol, PERIOD_CURRENT) < 2)
   {
      Print("Not enough bars. Exiting.");
      return INIT_FAILED;
   }

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Calculate entry levels                                            |
//+------------------------------------------------------------------+
void CalculateEntries()
{
   // Get current bar's High and Low
   double high = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double low  = iLow(_Symbol, PERIOD_CURRENT, 1);

   gHighPrice = high;
   gLowPrice  = low;
   gRange     = high - low;

   // Buy Entry  = (sqrt(High) - Parameter)^2
   double buySqrt = MathSqrt(high) - InpParameter;
   gBuyEntry = buySqrt * buySqrt;

   // Sell Entry = (sqrt(Low) + Parameter)^2
   double sellSqrt = MathSqrt(low) + InpParameter;
   gSellEntry = sellSqrt * sellSqrt;

   // Clamp: buy must be within [low, high]
   if(gBuyEntry > high)  gBuyEntry = high;
   if(gBuyEntry < low)   gBuyEntry = low;

   // Clamp: sell must be within [low, high]
   if(gSellEntry < low)  gSellEntry = low;
   if(gSellEntry > high) gSellEntry = high;
}

//+------------------------------------------------------------------+
//| Expert iteration (called on every tick)                          |
//+------------------------------------------------------------------+
void OnTick()
{
   CalculateEntries();
   DrawObjects();
}

//+------------------------------------------------------------------+
//| Calculate on chart calc                                           |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double &price[])
{
   CalculateEntries();
   DrawObjects();
   return rates_total;
}

//+------------------------------------------------------------------+
//| Draw horizontal lines & labels                                    |
//+------------------------------------------------------------------+
void DrawObjects()
{
   string prefix = "EM_";

   // Delete old objects
   ObjectDelete(0, prefix + "BuyLine");
   ObjectDelete(0, prefix + "SellLine");
   ObjectDelete(0, prefix + "BuyLabel");
   ObjectDelete(0, prefix + "SellLabel");
   ObjectDelete(0, prefix + "InfoLabel");

   // Buy Line (green)
   ObjectCreate(0, prefix + "BuyLine", OBJ_HLINE, 0, 0, gBuyEntry);
   ObjectSetInteger(0, prefix + "BuyLine", OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, prefix + "BuyLine", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, prefix + "BuyLine", OBJPROP_STYLE, STYLE_DASH);

   // Sell Line (red)
   ObjectCreate(0, prefix + "SellLine", OBJ_HLINE, 0, 0, gSellEntry);
   ObjectSetInteger(0, prefix + "SellLine", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, prefix + "SellLine", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, prefix + "SellLine", OBJPROP_STYLE, STYLE_DASH);

   if(InpShowLabel)
   {
      // Buy Label
      ObjectCreate(0, prefix + "BuyLabel", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, prefix + "BuyLabel", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, prefix + "BuyLabel", OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, prefix + "BuyLabel", OBJPROP_YDISTANCE, 20);
      ObjectSetString(0, prefix + "BuyLabel", OBJPROP_TEXT,
         StringFormat("BUY  %s  (sqrt%.0f - %.2f)^2",
         DoubleToString(gBuyEntry, _Digits),
         gHighPrice, InpParameter));
      ObjectSetInteger(0, prefix + "BuyLabel", OBJPROP_COLOR, clrLime);

      // Sell Label
      ObjectCreate(0, prefix + "SellLabel", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, prefix + "SellLabel", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, prefix + "SellLabel", OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, prefix + "SellLabel", OBJPROP_YDISTANCE, 40);
      ObjectSetString(0, prefix + "SellLabel", OBJPROP_TEXT,
         StringFormat("SELL %s  (sqrt%.0f + %.2f)^2",
         DoubleToString(gSellEntry, _Digits),
         gLowPrice, InpParameter));
      ObjectSetInteger(0, prefix + "SellLabel", OBJPROP_COLOR, clrRed);

      // Info Label
      ObjectCreate(0, prefix + "InfoLabel", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, prefix + "InfoLabel", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, prefix + "InfoLabel", OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, prefix + "InfoLabel", OBJPROP_YDISTANCE, 65);
      ObjectSetString(0, prefix + "InfoLabel", OBJPROP_TEXT,
         StringFormat("High: %.0f  Low: %.0f  Range: %.0f",
         gHighPrice, gLowPrice, gRange));
      ObjectSetInteger(0, prefix + "InfoLabel", OBJPROP_COLOR, clrWhite);
   }
}
//+------------------------------------------------------------------+
