//+------------------------------------------------------------------+
//|                                       Daily_Reference_Line.mq5   |
//|                                  Copyright 2024, Agent Hermes    |
//|                                             https://mql5.com     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Agent Hermes"
#property link      ""
#property version   "1.00"
#property indicator_chart_window

//--- Enums untuk Dropdown
enum ENUM_PRICE_TYPE {
   PRICE_OPEN = 0,  // Open
   PRICE_HIGH = 1,  // High
   PRICE_LOW  = 2,  // Low
   PRICE_CLOSE= 3   // Close
};

//--- Input Parameters
input group "--- Time Settings ---"
input ENUM_TIMEFRAMES InpTimeframe   = PERIOD_H1;     // Reference Timeframe
input int             InpHourOffset  = 2;             // Hour Offset (e.g. 2)
input string          InpLineName    = "DailyRefLine"; // Line Name Prefix

input group "--- Price Settings ---"
input ENUM_PRICE_TYPE InpPriceSource = PRICE_OPEN;    // Price Source (Dropdown)

input group "--- Cosmetics & Alert ---"
input color           InpColor       = clrDodgerBlue; // Line Color
input ENUM_LINE_STYLE InpStyle       = STYLE_SOLID;   // Line Style
input int             InpWidth       = 2;             // Line Width
input bool            InpClearDaily  = true;          // Clear Line on New Daily
input bool            InpAlert       = false;         // Enable Alert on Touch

//--- Global Variables
datetime last_day_time = 0;
bool     alert_sent     = false;
string   obj_name;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   obj_name = InpLineName;
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectDelete(0, obj_name);
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
   // 1. Cek apakah hari baru telah dimulai
   datetime current_day_start = iTime(_Symbol, PERIOD_D1, 0);
   
   if(current_day_start != last_day_time)
   {
      // Jika hari baru dan InpClearDaily = true, hapus garis lama
      if(InpClearDaily) 
         ObjectDelete(0, obj_name);
      
      last_day_time = current_day_start;
      alert_sent = false; // Reset alert status untuk hari baru
      
      // 2. Hitung waktu target (Daily Open + Offset Jam)
      datetime target_time = current_day_start + (InpHourOffset * 3600);
      
      // 3. Cari index candle pada timeframe yang dipilih berdasarkan target_time
      int bar_index = iBarShift(_Symbol, InpTimeframe, target_time, false);
      
      if(bar_index != -1)
      {
         double target_price = 0;
         
         // 4. Ambil harga berdasarkan dropdown (Open/High/Low/Close)
         switch(InpPriceSource)
         {
            case PRICE_OPEN:  target_price = iOpen(_Symbol, InpTimeframe, bar_index); break;
            case PRICE_HIGH:  target_price = iHigh(_Symbol, InpTimeframe, bar_index); break;
            case PRICE_LOW:   target_price = iLow(_Symbol, InpTimeframe, bar_index);  break;
            case PRICE_CLOSE: target_price = iClose(_Symbol, InpTimeframe, bar_index);break;
         }
         
         if(target_price > 0)
         {
            CreateOrUpdateLine(target_price);
         }
      }
   }

   // 5. Logika Alert jika harga menyentuh garis
   if(InpAlert && !alert_sent && ObjectFind(0, obj_name) >= 0)
   {
      double line_price = ObjectGetDouble(0, obj_name, OBJPROP_PRICE);
      double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      // Cek jika harga crossing (melewati) garis
      if((current_bid >= line_price && current_ask <= line_price) || 
         (current_bid <= line_price && current_ask >= line_price))
      {
         Alert(_Symbol, " : Price touched the Daily Reference Line!");
         alert_sent = true;
      }
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Function to create or update the horizontal line                 |
//+------------------------------------------------------------------+
void CreateOrUpdateLine(double price)
{
   if(ObjectFind(0, obj_name) < 0)
   {
      ObjectCreate(0, obj_name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, InpColor);
      ObjectSetInteger(0, obj_name, OBJPROP_STYLE, InpStyle);
      ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, InpWidth);
      ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, true);
      ObjectSetString(0, obj_name, OBJPROP_TOOLTIP, "Daily Reference Line");
   }
   else
   {
      ObjectMove(0, obj_name, 0, 0, price);
   }
}
