//+------------------------------------------------------------------+
//|                                            XAU_OptionsLevels.mq5 |
//|  Options Market Structure — GEX/DEX, Call/Put Walls, Gamma Flip  |
//|  Reads: data/xau_options_levels.csv (FILE_COMMON or scripts/)    |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, Lybeedo"
#property link        ""
#property version     "1.00"
#property description "XAU Options Levels: C-WALL, P-WALL, Gamma Flip, Max Pain, Vol Trigger"
#property strict

//--- Plots (6 horizontal lines)
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   6

#property indicator_label1  "C-WALL"
#property indicator_type1   DRAW_HLINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "P-WALL"
#property indicator_type2   DRAW_HLINE
#property indicator_color2  clrGreen
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#property indicator_label3  "Gamma Flip"
#property indicator_type3   DRAW_HLINE
#property indicator_color3  clrOrange
#property indicator_style3  STYLE_DASH
#property indicator_width3  1

#property indicator_label4  "Max Pain"
#property indicator_type4   DRAW_HLINE
#property indicator_color4  clrDeepSkyBlue
#property indicator_style4  STYLE_DASH
#property indicator_width4  1

#property indicator_label5  "Vol Trigger"
#property indicator_type5   DRAW_HLINE
#property indicator_color5  clrLime
#property indicator_style5  STYLE_DOT
#property indicator_width5  1

#property indicator_label6  "Current Price"
#property indicator_type6   DRAW_HLINE
#property indicator_color6  clrYellow
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1

//--- Buffers
double g_cwall[], g_pwall[], g_flip[], g_pain[], g_voltrig[], g_price[];
double g_netgex[], g_netdex[], g_gexratio[];
double g_condition[], g_confluence[];

//--- CSV path
string g_csv_path;

//+------------------------------------------------------------------+
//| LOAD CSV                                                          |
//+------------------------------------------------------------------+
bool LoadCSV() {
   // Try FILE_COMMON first, then scripts/
   string common = TerminalInfoString(TERMINAL_COMMONDIRECTORY);
   string candidates[] = {
      common + "\\Files\\xau_options_levels.csv",
      "xau_options_levels.csv",
      "data/xau_options_levels.csv"
   };

   int handle = INVALID_HANDLE;
   for(int i = 0; i < ArraySize(candidates); i++) {
      ResetLastError();
      handle = FileOpen(candidates[i], FILE_READ | FILE_TXT | FILE_ANSI);
      if(handle != INVALID_HANDLE) {
         g_csv_path = candidates[i];
         break;
      }
   }

   if(handle == INVALID_HANDLE) {
      Print("[XAU_Options] CSV not found, using defaults");
      SetDefaults();
      return false;
   }

   string header = FileReadString(handle);
   int loaded = 0;

   while(!FileIsEnding(handle)) {
      string line = FileReadString(handle);
      if(StringLen(line) == 0) continue;

      int f1 = StringFind(line, ',', 0);
      if(f1 < 0) continue;
      string level = StringSubstr(line, 0, f1);
      int    f2 = StringFind(line, ',', f1 + 1);
      if(f2 < 0) continue;
      string price_s = StringSubstr(line, f1 + 1, f2 - f1 - 1);
      int    f3 = StringFind(line, ',', f2 + 1);
      string pct_s   = StringSubstr(line, f2 + 1, f3 - f2 - 1);
      int    f4 = StringFind(line, ',', f3 + 1);
      string type_s  = (f4 > f3) ? StringSubstr(line, f3 + 1, f4 - f3 - 1)
                                : StringSubstr(line, f3 + 1);

      double price = StringToDouble(price_s);

      if(level == "SYMBOL")          g_price[0]    = price;
      else if(level == "NET_GEX")   g_netgex[0]   = price;
      else if(level == "NET_DEX")   g_netdex[0]   = price;
      else if(level == "GEX_RATIO") g_gexratio[0] = price;
      else if(level == "CONDITION") g_condition[0]= price;
      else if(level == "CONFLUENCE")g_confluence[0]= price;
      else if(level == "C-WALL")    g_cwall[0]    = price;
      else if(level == "P-WALL")    g_pwall[0]    = price;
      else if(level == "Gamma Flip")g_flip[0]     = price;
      else if(level == "Max Pain")  g_pain[0]     = price;
      else if(level == "Vol Trigger")g_voltrig[0] = price;

      loaded++;
   }

   FileClose(handle);
   Print("[XAU_Options] Loaded ", loaded, " entries from ", g_csv_path);
   return loaded > 0;
}

void SetDefaults() {
   g_price[0]    = 4144.5;
   g_cwall[0]    = 4144.5;
   g_pwall[0]    = 3994.5;
   g_flip[0]     = 4044.5;
   g_pain[0]     = 3994.5;
   g_voltrig[0]  = 4224.5;
   g_netgex[0]   = 9.3;
   g_netdex[0]   = -101.2;
   g_gexratio[0] = 1.13;
   g_condition[0]= 1.0;
   g_confluence[0]= 0.0;
}

//+------------------------------------------------------------------+
//| INIT                                                              |
//+------------------------------------------------------------------+
int OnInit() {
   SetIndexBuffer(0, g_cwall,    INDICATOR_DATA);
   SetIndexBuffer(1, g_pwall,    INDICATOR_DATA);
   SetIndexBuffer(2, g_flip,     INDICATOR_DATA);
   SetIndexBuffer(3, g_pain,     INDICATOR_DATA);
   SetIndexBuffer(4, g_voltrig,  INDICATOR_DATA);
   SetIndexBuffer(5, g_price,    INDICATOR_DATA);

   SetIndexBuffer(6,  g_netgex,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(7,  g_netdex,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(8,  g_gexratio,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(9,  g_condition, INDICATOR_CALCULATIONS);
   SetIndexBuffer(10, g_confluence,INDICATOR_CALCULATIONS);

   // Empty value = no draw for missing levels
   for(int i = 0; i < 6; i++)
      PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, 0.0);

   if(!LoadCSV()) SetDefaults();

   // Update labels with values
   PlotIndexSetString(0, PLOT_LABEL, "C-WALL " + DoubleToString(g_cwall[0], 1));
   PlotIndexSetString(1, PLOT_LABEL, "P-WALL " + DoubleToString(g_pwall[0], 1));
   PlotIndexSetString(2, PLOT_LABEL, "Flip   " + DoubleToString(g_flip[0], 1));
   PlotIndexSetString(3, PLOT_LABEL, "Pain   " + DoubleToString(g_pain[0], 1));
   PlotIndexSetString(4, PLOT_LABEL, "VolTrig " + DoubleToString(g_voltrig[0], 1));
   PlotIndexSetString(5, PLOT_LABEL, "Price  " + DoubleToString(g_price[0], 1));

   string status = StringFormat("XAU Opt | GEX=%+.1fM DEX=%+.1fM Rat=%.2f | %s | Con=%s",
       g_netgex[0], g_netdex[0], g_gexratio[0],
       (g_condition[0]>0?"POS GAMMA":"NEG GAMMA"),
       (g_confluence[0]>0?"YES":"NO"));
   IndicatorSetString(INDICATOR_SHORTNAME, status);

   Print("[XAU_Options] OnInit | ", status);
   EventSetTimer(60); // reload every 60s
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   EventKillTimer();
   Print("[XAU_Options] Deinit reason=", reason);
}

//+------------------------------------------------------------------+
//| ON TIMER — reload CSV                                           |
//+------------------------------------------------------------------+
void OnTimer() {
   if(LoadCSV()) {
      PlotIndexSetString(0, PLOT_LABEL, "C-WALL " + DoubleToString(g_cwall[0], 1));
      PlotIndexSetString(1, PLOT_LABEL, "P-WALL " + DoubleToString(g_pwall[0], 1));
      PlotIndexSetString(2, PLOT_LABEL, "Flip   " + DoubleToString(g_flip[0], 1));
      PlotIndexSetString(3, PLOT_LABEL, "Pain   " + DoubleToString(g_pain[0], 1));
      PlotIndexSetString(4, PLOT_LABEL, "VolTrig " + DoubleToString(g_voltrig[0], 1));
      PlotIndexSetString(5, PLOT_LABEL, "Price  " + DoubleToString(g_price[0], 1));

      string status = StringFormat("XAU Opt | GEX=%+.1fM DEX=%+.1fM Rat=%.2f | %s | Con=%s",
          g_netgex[0], g_netdex[0], g_gexratio[0],
          (g_condition[0]>0?"POS GAMMA":"NEG GAMMA"),
          (g_confluence[0]>0?"YES":"NO"));
      IndicatorSetString(INDICATOR_SHORTNAME, status);
   }
}

//+------------------------------------------------------------------+
//| ON CALCULATE — update price line from chart                      |
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
                const int &spread[]) {
   if(rates_total > 0)
      g_price[0] = close[rates_total - 1];
   return(rates_total);
}
//+------------------------------------------------------------------+
