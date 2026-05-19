//+------------------------------------------------------------------+
//|                                             CloseAllPositions.mq5 |
//|                                                    7NAGA System   |
//+------------------------------------------------------------------+
#property copyright   "7NAGA - Close All Positions"
#property version     "1.00"
#property script_show_inputs

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                |
//+------------------------------------------------------------------+
input ENUM_POSITION_TYPE posFilter = POSITION_TYPE_ALL; // Position Filter: ALL / BUY only / SELL only
input ulong       slippage       = 10;                   // Slippage (points)
input bool        verbose        = true;                // Show detailed log

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   CTrade trade;
   trade.SetExpertMagicNumber(0);   // close ALL magic (0 = all)
   trade.SetDeviationInPoints(slippage);

   // Collect positions
   ulong tickets[];
   int total = PositionsTotal();
   
   if(total == 0)
   {
      Print("No positions found.");
      return;
   }

   // Gather ticket numbers
   ArrayResize(tickets, 0);
   for(int i = total - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == Symbol())   // only current symbol
      {
         ulong ticket = PositionGetTicket(i);
         ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         
         if(posFilter == POSITION_TYPE_ALL ||
            posFilter == type)
         {
            ArrayResize(tickets, ArraySize(tickets) + 1);
            tickets[ArraySize(tickets) - 1] = ticket;
         }
      }
   }

   if(ArraySize(tickets) == 0)
   {
      Print("No matching positions to close.");
      return;
   }

   //--- Close ALL in one shot (fast bulk mode)
   int    closed = 0;
   int    failed = 0;
   double totalLots = 0;
   double totalProfit = 0;

   for(int i = 0; i < ArraySize(tickets); i++)
   {
      ulong ticket = tickets[i];
      
      if(!PositionSelectByTicket(ticket))
      {
         if(verbose) Print("Ticket #", ticket, " already closed or invalid.");
         failed++;
         continue;
      }

      string   sym     = PositionGetString(POSITION_SYMBOL);
      double   vol     = PositionGetDouble(POSITION_VOLUME);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double   profit  = PositionGetDouble(POSITION_PROFIT);
      ulong    mag     = PositionGetInteger(POSITION_MAGIC);

      bool result = false;
      
      if(type == POSITION_TYPE_BUY)
         result = trade.PositionClose(ticket, slippage);
      else if(type == POSITION_TYPE_SELL)
         result = trade.PositionClose(ticket, slippage);

      if(result)
      {
         closed++;
         totalLots += vol;
         totalProfit += profit;
         if(verbose)
            Print("✓ Closed #", ticket, " ", 
                  EnumToString(type), " ", vol, " lots | P/L: ", 
                  DoubleToString(profit, 2), " ", AccountInfoString(ACCOUNT_CURRENCY));
      }
      else
      {
         failed++;
         if(verbose)
            Print("✗ Failed to close #", ticket, " | Error: ", 
                  ErrorDescription(GetLastError()));
      }
   }

   //--- Summary
   Print("═══════════════════════════════════");
   Print("  CLOSE ALL SUMMARY");
   Print("═══════════════════════════════════");
   Print("  Closed : ", closed);
   Print("  Failed : ", failed);
   Print("  Total Lots   : ", DoubleToString(totalLots, 2));
   Print("  Total Profit : ", DoubleToString(totalProfit, 2), " ", AccountInfoString(ACCOUNT_CURRENCY));
   Print("═══════════════════════════════════");
}
//+------------------------------------------------------------------+
