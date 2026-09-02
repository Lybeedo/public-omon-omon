//+------------------------------------------------------------------+
//|                                      SwingFailurePattern.mq5     |
//|                                  Based on Gold Badger - SFP      |
//|                                                                  |
//|  Strategy: Swing Failure Pattern (Stop Hunt / False Breakout)    |
//|  - Bearish SFP: Higher High break + Close Below Swing -> SELL   |
//|  - Bullish SFP: Lower Low break + Close Above Swing -> BUY      |
//+------------------------------------------------------------------+
#property copyright "Trader Nakal"
#property link      ""
#property version   "1.00"
#property strict
#property indicator_chart_window

#include <Trade\Trade.mqh>

input group="=== Strategy Settings ==="
input int              InpSwingLength     = 5;          // Swing Length (Pivot Lookback)
input bool             EnableBuySignal    = true;       // Enable Bullish SFP
input bool             EnableSellSignal   = true;       // Enable Bearish SFP

input group="=== Risk Management ==="
input double           InpLots            = 0.01;       // Lot Size
input double           InpSL_Points       = 500;        // Stop Loss (Points)
input double           InpTP_Points       = 1000;       // Take Profit (Points)
input double           InpBreakEven_Pts   = 300;        // Break Even Trigger (Points)

input group="=== Signal Display ==="
input bool             ShowLabels         = true;       // Show Signal Labels
input color            ColorBullish       = clrLimeGreen; // Bullish SFP Color
input color            ColorBearish       = clrRed;      // Bearish SFP Color

CTrade trade;
int handlePivotHigh;
int handlePivotLow;

struct PivotInfo {
   int    barIndex;
   double price;
};

PivotInfo lastSwingHigh;
PivotInfo lastSwingLow;
datetime lastSignalTime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(123456);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   lastSignalTime = 0;
   Print("Swing Failure Pattern EA initialized");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!IsNewBar()) return;
   
   CheckForSignals();
}

//+------------------------------------------------------------------+
//| Check for SFP signals                                            |
//+------------------------------------------------------------------+
void CheckForSignals(void)
{
   // Calculate swing highs and lows
   double swingHigh = GetSwingHigh(InpSwingLength);
   double swingLow = GetSwingLow(InpSwingLength);
   
   if(swingHigh == 0 || swingLow == 0) return;
   
   // --- BEARISH SFP DETECTION ---
   // Condition: Price makes higher high (breaks above swing) but closes below swing
   if(EnableSellSignal && CanTrade())
   {
      double currentHigh = High_D(1);
      double currentClose = Close_D(1);
      
      if(currentHigh > swingHigh && currentClose < swingHigh)
      {
         OpenSellOrder();
         if(ShowLabels) DrawLabel("SELL SFP", CurrentPrice(), ColorBearish, true);
      }
   }
   
   // --- BULLISH SFP DETECTION ---
   // Condition: Price makes lower low (breaks below swing) but closes above swing
   if(EnableBuySignal && CanTrade())
   {
      double currentLow = Low_D(1);
      double currentClose = Close_D(1);
      
      if(currentLow < swingLow && currentClose > swingLow)
      {
         OpenBuyOrder();
         if(ShowLabels) DrawLabel("BUY SFP", CurrentPrice(), ColorBullish, false);
      }
   }
}

//+------------------------------------------------------------------+
//| Get pivot high value                                             |
//+------------------------------------------------------------------+
double GetSwingHigh(int length)
{
   for(int i = 1; i <= length * 2; i++)
   {
      if(i >= Bars(_Symbol, _Period)) break;
      
      bool isHigh = true;
      for(int j = 1; j <= length; j++)
      {
         if(High_D(i+j) >= High_D(i) || High_D(i-j) >= High_D(i))
         {
            isHigh = false;
            break;
         }
      }
      if(isHigh) return High_D(i);
   }
   return 0;
}

//+------------------------------------------------------------------+
//| Get pivot low value                                              |
//+------------------------------------------------------------------+
double GetSwingLow(int length)
{
   for(int i = 1; i <= length * 2; i++)
   {
      if(i >= Bars(_Symbol, _Period)) break;
      
      bool isLow = true;
      for(int j = 1; j <= length; j++)
      {
         if(Low_D(i+j) <= Low_D(i) || Low_D(i-j) <= Low_D(i))
         {
            isLow = false;
            break;
         }
      }
      if(isLow) return Low_D(i);
   }
   return 0;
}

//+------------------------------------------------------------------+
//| Open Buy Order                                                   |
//+------------------------------------------------------------------+
void OpenBuyOrder(void)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = (InpSL_Points > 0) ? ask - InpSL_Points * Point() : 0;
   double tp = (InpTP_Points > 0) ? ask + InpTP_Points * Point() : 0;
   
   if(trade.Buy(InpLots, _Symbol, ask, sl, tp, "SFP BUY"))
   {
      PrintFormat("BUY order opened at %.5f | Lots: %.2f", ask, InpLots);
   }
   else
   {
      PrintFormat("BUY order failed: %s",trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Open Sell Order                                                  |
//+------------------------------------------------------------------+
void OpenSellOrder(void)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = (InpSL_Points > 0) ? bid + InpSL_Points * Point() : 0;
   double tp = (InpTP_Points > 0) ? bid - InpTP_Points * Point() : 0;
   
   if(trade.Sell(InpLots, _Symbol, bid, sl, tp, "SFP SELL"))
   {
      PrintFormat("SELL order opened at %.5f | Lots: %.2f", bid, InpLots);
   }
   else
   {
      PrintFormat("SELL order failed: %s",trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Check if we can trade (no open positions for this symbol)        |
//+------------------------------------------------------------------+
bool CanTrade(void)
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == trade.RequestMagic())
         return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Check if new bar formed                                          |
//+------------------------------------------------------------------+
bool IsNewBar(void)
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(lastBarTime != currentBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Draw signal label                                                |
//+------------------------------------------------------------------+
void DrawLabel(string labelText, double price, color labelColor, bool isUpper)
{
   string uniqueName = "SFP_" + labelText + "_" + IntegerToString(TimeCurrent());
   double yPrice = isUpper ? price + 20 * _Point : price - 20 * _Point;
   
   ObjectCreate(0, uniqueName, OBJ_TEXT, 0, TimeCurrent(), yPrice);
   ObjectSetString(0, uniqueName, OBJPROP_TEXT, labelText);
   ObjectSetInteger(0, uniqueName, OBJPROP_COLOR, labelColor);
   ObjectSetInteger(0, uniqueName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, uniqueName, OBJPROP_FONT, "Arial Bold");
}

//+------------------------------------------------------------------+
//| Get current price                                                |
//+------------------------------------------------------------------+
double CurrentPrice(void)
{
   return(SymbolInfoDouble(_Symbol, SYMBOL_BID));
}

//+------------------------------------------------------------------+
//| High array helper                                                |
//+------------------------------------------------------------------+
double High_D(int index)
{
   return iHigh(_Symbol, PERIOD_CURRENT, index);
}

//+------------------------------------------------------------------+
//| Low array helper                                                 |
//+------------------------------------------------------------------+
double Low_D(int index)
{
   return iLow(_Symbol, PERIOD_CURRENT, index);
}

//+------------------------------------------------------------------+
//| Close array helper                                               |
//+------------------------------------------------------------------+
double Close_D(int index)
{
   return iClose(_Symbol, PERIOD_CURRENT, index);
}

//+------------------------------------------------------------------+
//| Point helper                                                     |
//+------------------------------------------------------------------+
double PointHelper(void)
{
   return SymbolInfoDouble(_Symbol, SYMBOL_POINT);
}
//+------------------------------------------------------------------+
