//+------------------------------------------------------------------+
//|                                 JavaneseTrader_Config.mqh         |
//|                                        Shared configuration      |
//+------------------------------------------------------------------+
#ifndef JAVANESE_TRADER_CONFIG
#define JAVANESE_TRADER_CONFIG

#define VERSION "1.00"

//+------------------------------------------------------------------+
//| Signal types                                                     |
//+------------------------------------------------------------------+
enum ENUM_JAVA_SIGNAL
{
   SIGNAL_NONE        = 0,
   SIGNAL_TUKU        = 1,   // Buy - price won't go down
   SIGNAL_DOL         = 2,   // Sell - price won't go up
   SIGNAL_STRONG_BUY  = 3,
   SIGNAL_STRONG_SELL = 4
};

//+------------------------------------------------------------------+
//| Trailing modes                                                   |
//+------------------------------------------------------------------+
enum ENUM_TRAILING_MODE
{
   TRAILING_STEP      = 0,
   TRAILING_LINEAR    = 1
};

//+------------------------------------------------------------------+
//| Calculate lot from risk %                                        |
//+------------------------------------------------------------------+
double CalcLotFromRisk(string symbol, double riskPercent, int slPoints)
{
   double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmt  = balance * (riskPercent / 100.0);

   double tickVal  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double point    = SymbolInfoDouble(symbol, SYMBOL_POINT);

   double lot = riskAmt / (slPoints * tickVal * point);

   double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   lot = MathRound(lot / step) * step;

   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

   return MathMax(minLot, MathMin(maxLot, lot));
}

//+------------------------------------------------------------------+
//| Normalize price                                                  |
//+------------------------------------------------------------------+
double NormalizePrice(string symbol, double price)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
}

//+------------------------------------------------------------------+
//| Get spread in points                                             |
//+------------------------------------------------------------------+
int GetSpreadPoints(string symbol)
{
   return (int)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
}

#endif