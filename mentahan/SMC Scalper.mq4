//+------------------------------------------------------------------+
//|                                            SMC Sniper Scalper.mq4 |
//|                                           Copyright 2025, Trading |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property strict

// External Parameters
extern string StrategyInfo = "--- SMC SNIPER SCALPING SETTINGS ---";
extern double Fixed_Lot_Size = 0.1;
extern int Take_Profit_Pips = 6000;
extern int Stop_Loss_Pips = 500;
extern int Major_Leg_Grab_Volume = 330;
extern int Extreme_Leg_Grab_Volume = 400;
extern bool Enable_BreakEven = true;
extern int Custom_Grab_Exem_Trigger = 500;
extern int Extra_Pips_Added_to_Avoid_Spread_Losses = 100;
extern bool Enable_Total_Profit_Close = true;
extern double Total_Profit_Target_Dollars = 100.0;
extern double Total_Profit_Target_Percent = 5.0;
extern int Custom_Entries_Major = 14;
extern int Custom_Entries_Extreme = 1;
extern int MA_Period_Short = 14;
extern int MA_Period_Long = 100;
extern string MA_Timeframe = "4 Hours";
extern bool Buy_Only = false;
extern bool Sell_Only = false;

// Global Variables
double g_point;
int g_digits;
double g_stop_level;
double g_lots;
int g_magic_number = 76543;
string g_comment = "SMC SNIPER SCALPER";
int g_slippage = 3;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Adjust point value for different digit currencies
   g_digits = Digits;
   if (g_digits == 3 || g_digits == 5)
   {
      g_point = Point * 10;
   }
   else
   {
      g_point = Point;
   }
   
   // Get minimum stop level from broker
   g_stop_level = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
   
   // Check if trading is allowed
   if (!IsTradeAllowed())
   {
      Print("Trading is not allowed. Please enable automated trading or check if trading is disabled.");
      return INIT_FAILED;
   }
   
   // Additional initialization
   ChartSetInteger(ChartID(), CHART_FOREGROUND, false);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up any objects
   Comment("");
   ObjectsDeleteAll(0, OBJ_TEXT);
   ObjectsDeleteAll(0, OBJ_LABEL);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Update chart info
   RefreshRates();
   
   // Display information on chart
   ShowInfo();
   
   // Check if we need to close all trades based on profit target
   if (Enable_Total_Profit_Close && AccountProfit() >= Total_Profit_Target_Dollars)
   {
      CloseAllTrades();
      Print("Closed all trades because total profit target reached: $", Total_Profit_Target_Dollars);
      return;
   }
   
   // Check if we need to set existing trades to breakeven
   if (Enable_BreakEven)
   {
      ManageBreakEven();
   }
   
   // Only check for new trades if we have none open for this symbol and magic number
   if (GetTotalOpenTrades() == 0)
   {
      // Check for trading conditions and enter new trades
      CheckForTradingSignals();
   }
}

//+------------------------------------------------------------------+
//| Check for trading signals based on SMC rules                     |
//+------------------------------------------------------------------+
void CheckForTradingSignals()
{
   // Get indicator values
   double short_ma = iMA(Symbol(), GetTimeframeFromString(MA_Timeframe), MA_Period_Short, 0, MODE_EMA, PRICE_CLOSE, 1);
   double long_ma = iMA(Symbol(), GetTimeframeFromString(MA_Timeframe), MA_Period_Long, 0, MODE_EMA, PRICE_CLOSE, 1);
   
   // Get volume indicators
   double current_volume = iVolume(Symbol(), PERIOD_CURRENT, 1);
   
   // Buy logic
   bool buy_signal = false;
   if (!Sell_Only)
   {
      buy_signal = (short_ma > long_ma) && 
                  (current_volume >= Major_Leg_Grab_Volume) &&
                  (Custom_Entries_Major > 0);
                  
      // Extreme buy condition
      if (!buy_signal && (current_volume >= Extreme_Leg_Grab_Volume) && (Custom_Entries_Extreme > 0))
      {
         buy_signal = true;
      }
   }
   
   // Sell logic
   bool sell_signal = false;
   if (!Buy_Only)
   {
      sell_signal = (short_ma < long_ma) && 
                   (current_volume >= Major_Leg_Grab_Volume) &&
                   (Custom_Entries_Major > 0);
                   
      // Extreme sell condition
      if (!sell_signal && (current_volume >= Extreme_Leg_Grab_Volume) && (Custom_Entries_Extreme > 0))
      {
         sell_signal = true;
      }
   }
   
   // Execute trades based on signals
   if (buy_signal)
   {
      OpenBuyOrder();
   }
   else if (sell_signal)
   {
      OpenSellOrder();
   }
}

//+------------------------------------------------------------------+
//| Open buy order with proper risk management                       |
//+------------------------------------------------------------------+
void OpenBuyOrder()
{
   double lot_size = Fixed_Lot_Size;
   double stop_loss = NormalizeDouble(Bid - Stop_Loss_Pips * g_point, g_digits);
   double take_profit = NormalizeDouble(Ask + Take_Profit_Pips * g_point, g_digits);
   
   // Add extra pips to avoid spread losses
   stop_loss = NormalizeDouble(stop_loss - Extra_Pips_Added_to_Avoid_Spread_Losses * g_point, g_digits);
   
   // Check if SL/TP are valid according to broker rules
   if (Ask - stop_loss < g_stop_level)
   {
      stop_loss = NormalizeDouble(Ask - g_stop_level - g_point, g_digits);
   }
   
   if (take_profit - Ask < g_stop_level)
   {
      take_profit = NormalizeDouble(Ask + g_stop_level + g_point, g_digits);
   }
   
   // Open the buy order
   int ticket = OrderSend(Symbol(), OP_BUY, lot_size, Ask, g_slippage, stop_loss, take_profit, g_comment, g_magic_number, 0, clrGreen);
   
   // Check for errors
   if (ticket < 0)
   {
      int error = GetLastError();
      //Print("Error opening buy order: ", error, " - ", ErrorDescription(error));
   }
   else
   {
      //Print("Buy order opened. Ticket: ", ticket, " at price: ", Ask, " SL: ", stop_loss, " TP: ", take_profit);
   }
}

//+------------------------------------------------------------------+
//| Open sell order with proper risk management                      |
//+------------------------------------------------------------------+
void OpenSellOrder()
{
   double lot_size = Fixed_Lot_Size;
   double stop_loss = NormalizeDouble(Ask + Stop_Loss_Pips * g_point, g_digits);
   double take_profit = NormalizeDouble(Bid - Take_Profit_Pips * g_point, g_digits);
   
   // Add extra pips to avoid spread losses
   stop_loss = NormalizeDouble(stop_loss + Extra_Pips_Added_to_Avoid_Spread_Losses * g_point, g_digits);
   
   // Check if SL/TP are valid according to broker rules
   if (stop_loss - Bid < g_stop_level)
   {
      stop_loss = NormalizeDouble(Bid + g_stop_level + g_point, g_digits);
   }
   
   if (Bid - take_profit < g_stop_level)
   {
      take_profit = NormalizeDouble(Bid - g_stop_level - g_point, g_digits);
   }
   
   // Open the sell order
   int ticket = OrderSend(Symbol(), OP_SELL, lot_size, Bid, g_slippage, stop_loss, take_profit, g_comment, g_magic_number, 0, clrRed);
   
   // Check for errors
   if (ticket < 0)
   {
      int error = GetLastError();
      //Print("Error opening sell order: ", error, " - ", ErrorDescription(error));
   }
   else
   {
      Print("Sell order opened. Ticket: ", ticket, " at price: ", Bid, " SL: ", stop_loss, " TP: ", take_profit);
   }
}

//+------------------------------------------------------------------+
//| Manage breakeven for open trades                                 |
//+------------------------------------------------------------------+
void ManageBreakEven()
{
   for (int i = 0; i < OrdersTotal(); i++)
   {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if (OrderSymbol() == Symbol() && OrderMagicNumber() == g_magic_number)
         {
            // Check if order is in profit by Custom_Grab_Exem_Trigger points
            if (OrderType() == OP_BUY)
            {
               double profit_pips = (Bid - OrderOpenPrice()) / g_point;
               if (profit_pips >= Custom_Grab_Exem_Trigger)
               {
                  // Set stop loss to break even plus 1 point
                  if (OrderStopLoss() < OrderOpenPrice())
                  {
                     bool modified = OrderModify(OrderTicket(), OrderOpenPrice(), OrderOpenPrice() + g_point, OrderTakeProfit(), 0, clrBlue);
                     if (modified)
                     {
                        Print("Modified order #", OrderTicket(), " to breakeven");
                     }
                  }
               }
            }
            else if (OrderType() == OP_SELL)
            {
               double profit_pips = (OrderOpenPrice() - Ask) / g_point;
               if (profit_pips >= Custom_Grab_Exem_Trigger)
               {
                  // Set stop loss to break even plus 1 point
                  if (OrderStopLoss() > OrderOpenPrice() || OrderStopLoss() == 0)
                  {
                     bool modified = OrderModify(OrderTicket(), OrderOpenPrice(), OrderOpenPrice() - g_point, OrderTakeProfit(), 0, clrBlue);
                     if (modified)
                     {
                        Print("Modified order #", OrderTicket(), " to breakeven");
                     }
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get total open trades for current symbol and magic number        |
//+------------------------------------------------------------------+
int GetTotalOpenTrades()
{
   int total = 0;
   
   for (int i = 0; i < OrdersTotal(); i++)
   {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if (OrderSymbol() == Symbol() && OrderMagicNumber() == g_magic_number)
         {
            total++;
         }
      }
   }
   
   return total;
}

//+------------------------------------------------------------------+
//| Close all open trades                                            |
//+------------------------------------------------------------------+
void CloseAllTrades()
{
   for (int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if (OrderSymbol() == Symbol() && OrderMagicNumber() == g_magic_number)
         {
            bool closed = false;
            int ticket = OrderTicket();
            
            if (OrderType() == OP_BUY)
            {
               closed = OrderClose(ticket, OrderLots(), Bid, g_slippage, clrAqua);
            }
            else if (OrderType() == OP_SELL)
            {
               closed = OrderClose(ticket, OrderLots(), Ask, g_slippage, clrPink);
            }
            
            if (!closed)
            {
               Print("Error closing order #", ticket, ": ", GetLastError());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Convert timeframe string to timeframe constant                   |
//+------------------------------------------------------------------+
int GetTimeframeFromString(string timeframe)
{
   if (timeframe == "1 Minute" || timeframe == "1 Min" || timeframe == "M1") return PERIOD_M1;
   if (timeframe == "5 Minutes" || timeframe == "5 Min" || timeframe == "M5") return PERIOD_M5;
   if (timeframe == "15 Minutes" || timeframe == "15 Min" || timeframe == "M15") return PERIOD_M15;
   if (timeframe == "30 Minutes" || timeframe == "30 Min" || timeframe == "M30") return PERIOD_M30;
   if (timeframe == "1 Hour" || timeframe == "H1") return PERIOD_H1;
   if (timeframe == "4 Hours" || timeframe == "H4") return PERIOD_H4;
   if (timeframe == "1 Day" || timeframe == "D1") return PERIOD_D1;
   if (timeframe == "1 Week" || timeframe == "W1") return PERIOD_W1;
   if (timeframe == "1 Month" || timeframe == "MN") return PERIOD_MN1;
   
   // Default to H4 if timeframe not recognized
   return PERIOD_H4;
}

//+------------------------------------------------------------------+
//| Display information on chart                                     |
//+------------------------------------------------------------------+
void ShowInfo()
{
   string info = "";
   
   info += "SMC SNIPER SCALPER\n";
   info += "Symbol: " + Symbol() + "\n";
   info += "Spread: " + DoubleToStr(MarketInfo(Symbol(), MODE_SPREAD), 1) + " pips\n";
   info += "Time: " + TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\n\n";
   
   info += "Take Profit: " + IntegerToString(Take_Profit_Pips) + " pips\n";
   info += "Stop Loss: " + IntegerToString(Stop_Loss_Pips) + " pips\n";
   info += "Break Even: " + (Enable_BreakEven ? "Enabled" : "Disabled") + "\n";
   info += "Position Size: " + DoubleToStr(Fixed_Lot_Size, 2) + " lots\n\n";
   
   info += "Open Trades: " + IntegerToString(GetTotalOpenTrades()) + "\n";
   info += "Account Balance: " + DoubleToStr(AccountBalance(), 2) + " " + AccountCurrency() + "\n";
   info += "Account Equity: " + DoubleToStr(AccountEquity(), 2) + " " + AccountCurrency() + "\n";
   info += "Current Profit: " + DoubleToStr(AccountEquity() - AccountBalance(), 2) + " " + AccountCurrency() + "\n";
   
   Comment(info);
}