//+------------------------------------------------------------------+
//|                                              RoyalHegen_EA.mq5   |
//|                                         EA Royal Hegen    |
//|  v1.16                                                           |
//|  - SELL ketika %K masuk Overbought (>= OB level)                 |
//|  - BUY  ketika %K masuk Oversold  (<= OS level)                  |
//|  - Tanpa SL/TP (dikelola EA lain)                                |
//|  - Max 1 posisi first trigger per arah                           |
//|  - Hedge diizinkan (buy & sell bisa berjalan bersamaan)          |
//|  - Averaging: tambah posisi setiap N points jika floating loss   |
//|  - Jam trading berdasarkan jam server MT5                        |
//|  - Berhenti buka order baru jika daily profit target tercapai    |
//|  - Panel info visual di chart                                    |
//+------------------------------------------------------------------+
#property copyright "Mathias"
#property version   "1.16"
#property strict

#include <Trade\Trade.mqh>

//--- Input Parameters
input group "=== Stochastic Settings ==="
input bool   EnableStoch     = true;   // Aktifkan filter Stochastic
input bool   RequireCross    = true;   // true  = tunggu K cross D di zone OB/OS
                                        // false = langsung op saat masuk zone OB/OS
input int    Stoch_K         = 5;      // %K Period
input int    Stoch_D         = 3;      // %D Period (Smoothing)
input int    Stoch_Slowing   = 3;      // Slowing
input double OverboughtLevel = 80.0;   // Overbought Level => SELL
input double OversoldLevel   = 20.0;   // Oversold Level  => BUY

input group "=== EMA Filter ==="
input bool   EnableEMAFilter = true;   // Aktifkan filter EMA 200
input int    EMAPeriod       = 200;    // Period EMA
input ENUM_TIMEFRAMES EMATimeframe = PERIOD_CURRENT; // Timeframe EMA

input group "=== ADX Filter ==="
input bool   EnableADXFilter = true;   // Aktifkan filter ADX + DI
input int    ADXPeriod       = 14;     // Period ADX
input double ADXMinLevel     = 25.0;   // ADX minimum (trend kuat jika > level ini)
input ENUM_TIMEFRAMES ADXTimeframe = PERIOD_CURRENT; // Timeframe ADX

input group "=== HalfTrend Filter ==="
input bool   EnableHTFilter  = true;   // Aktifkan filter HalfTrend
input int    HTAmplitude     = 2;      // Amplitude (sensitivity, default 2)
input ENUM_TIMEFRAMES HTTimeframe = PERIOD_CURRENT; // Timeframe HalfTrend

input group "=== Trade Settings ==="
input double LotSize         = 0.01;   // Lot Size (first order)
input double TakeProfitUSD   = 100.0;  // Take Profit per grup posisi ($)
input string CommentBuy      = "RH Buy";  // Comment posisi BUY
input string CommentSell     = "RH Sell"; // Comment posisi SELL
input int    MagicNumber     = 303001; // Magic Number
input bool   AllowHedge      = false;  // true = boleh BUY & SELL bersamaan
                                        // false = tunggu satu sisi clear dulu

input group "=== Trailing Stop ==="
input bool   EnableTrailing   = true;  // Aktifkan trailing stop
input int    TrailingStart    = 200;   // Mulai trailing setelah profit N points
input int    TrailingDistance = 20;    // Jarak SL dari harga (points)
input int    TrailingStep     = 1;     // Geser SL minimal N points (points)

input group "=== DDR Settings ==="
input bool   EnableDDR       = true;   // Drawdown Reduction: posisi ke-N+1 tutup posisi ke-1
input int    DDRStartCount   = 20;     // DDR aktif setelah posisi ke-N (default 20)
                                        // Posisi ke-21 akan menutup posisi ke-1, dst
input double DDRMinProfit    = 0.0;    // Min total profit grup sebelum DDR boleh close ($)
                                        // 0 = DDR langsung close tanpa syarat profit

input group "=== Averaging Settings ==="
input bool   EnableAveraging = true;   // Aktifkan averaging
input int    AveragePoints   = 200;    // Jarak averaging (points)
input double LotMultiplier   = 1.0;    // Multiplier lot tiap level averaging
input bool   EnableAvgUp     = true;   // Avg UP: tambah posisi saat floating profit
input int    AvgUpPoints     = 200;    // Jarak avg up dari posisi terakhir (points)

input group "=== Trading Hours (Server Time) ==="
input int    StartHour       = 0;      // Jam mulai trading (0-23)
input int    EndHour         = 23;     // Jam akhir trading (0-23)

input group "=== Daily Target ==="
input double DailyTarget     = 50.0;   // Daily profit target ($), 0 = nonaktif
input int    CooldownMinutes = 5;      // Cooldown setelah TP hit (menit), 0 = nonaktif

input group "=== Panel Settings ==="
input int    PanelX          = 20;     // Panel posisi X
input int    PanelY          = 30;     // Panel posisi Y

//--- Panel prefix & dimensi
#define PREFIX       "SEA_"
#define PANEL_W      260
#define PANEL_H      432
#define FONT_NAME    "Consolas"
#define FONT_SIZE    9

//--- Warna panel
#define CLR_BG       C'20,20,30'
#define CLR_HEADER   C'30,30,45'
#define CLR_BORDER   C'60,60,90'
#define CLR_TITLE    C'180,180,255'
#define CLR_LABEL    C'140,140,160'
#define CLR_VALUE    clrWhite
#define CLR_BUY      C'80,200,120'
#define CLR_SELL     C'220,80,80'
#define CLR_PROFIT   C'80,220,120'
#define CLR_LOSS     C'220,80,80'
#define CLR_ACTIVE   C'80,220,120'
#define CLR_OFFHOUR  C'150,150,150'
#define CLR_TARGET   C'255,200,60'
#define CLR_BAR_BG   C'40,40,60'
#define CLR_BAR_FILL C'80,200,120'

//--- Global Objects
CTrade   trade;
int      stoch_handle;
int      ema_handle;
int      adx_handle;


datetime lastBarTime     = 0;   // waktu open candle terakhir yang sudah diproses
datetime lastTPTime      = 0;   // waktu terakhir TP hit (untuk cooldown)

//--- HalfTrend state (dihitung manual setiap candle baru)
int      htDirection     = 0;   // 1 = UP (bullish), -1 = DOWN (bearish), 0 = belum init
double   htLevel         = 0;   // garis HalfTrend saat ini
double   htHighMA        = 0;   // running high MA
double   htLowMA         = 0;   // running low MA

//--- Daily tracking
datetime lastResetDay      = 0;
double   dailyStartBalance = 0;   // akan diisi saat OnInit
double   dailyMaxDrawdown  = 0;   // drawdown terbesar hari ini (nilai negatif)
double   dailyTotalLot     = 0;   // total lot yang dipakai hari ini


//+------------------------------------------------------------------+
//| HalfTrend Calculator                                             |
//|                                                                  |
//| Algoritma:                                                       |
//|  1. Hitung EMA high dan EMA low dari N candle terakhir           |
//|  2. Jika harga close menembus EMA high -> trend UP               |
//|  3. Jika harga close menembus EMA low  -> trend DOWN             |
//|  4. Level HalfTrend bergerak hanya searah trend (ratchet)        |
//|                                                                  |
//| Return: 1=UP, -1=DOWN, 0=unknown                                 |
//+------------------------------------------------------------------+
int CalcHalfTrend()
{
   int    period  = HTAmplitude * 2;   // periode EMA = 2x amplitude
   int    bars    = period + 10;        // jumlah candle yang diambil
   ENUM_TIMEFRAMES tf = HTTimeframe;

   double closeArr[], highArr[], lowArr[];
   ArraySetAsSeries(closeArr, true);
   ArraySetAsSeries(highArr,  true);
   ArraySetAsSeries(lowArr,   true);

   if(CopyClose(_Symbol, tf, 0, bars, closeArr) < bars) return 0;
   if(CopyHigh(_Symbol,  tf, 0, bars, highArr)  < bars) return 0;
   if(CopyLow(_Symbol,   tf, 0, bars, lowArr)   < bars) return 0;

   //--- Gunakan candle [1] = closed, bukan [0] = sedang berjalan
   //--- Hitung simple moving average high dan low sebagai referensi
   double sumHigh = 0, sumLow = 0;
   for(int i = 1; i <= period; i++)
   {
      sumHigh += highArr[i];
      sumLow  += lowArr[i];
   }
   double maHigh = sumHigh / period;
   double maLow  = sumLow  / period;
   double close1 = closeArr[1];  // close candle terakhir yang closed

   //--- Update direction berdasarkan posisi close vs MA band
   int prevDir = htDirection;

   if(close1 > maHigh)
   {
      //--- Harga nembus ke atas MA high -> trend UP
      htDirection = 1;
      //--- Level HalfTrend = maLow (support), ratchet ke atas saja
      if(htDirection != prevDir || maLow > htLevel)
         htLevel = maLow;
   }
   else if(close1 < maLow)
   {
      //--- Harga nembus ke bawah MA low -> trend DOWN
      htDirection = -1;
      //--- Level HalfTrend = maHigh (resistance), ratchet ke bawah saja
      if(htDirection != prevDir || maHigh < htLevel)
         htLevel = maHigh;
   }
   //--- Di dalam band: direction tidak berubah

   return htDirection;
}

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+

int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);

   stoch_handle = iStochastic(_Symbol, PERIOD_CURRENT,
                               Stoch_K, Stoch_D, Stoch_Slowing,
                               MODE_SMA, STO_LOWHIGH);
   if(stoch_handle == INVALID_HANDLE)
   {
      Print("[RoyalHegen] Gagal buat Stochastic handle! Error: ", GetLastError());
      return INIT_FAILED;
   }

   ema_handle = iMA(_Symbol, EMATimeframe, EMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(ema_handle == INVALID_HANDLE)
   {
      Print("[RoyalHegen] Gagal buat EMA handle! Error: ", GetLastError());
      return INIT_FAILED;
   }

   //--- ADX: buffer 0=ADX, 1=+DI, 2=-DI
   adx_handle = iADX(_Symbol, ADXTimeframe, ADXPeriod);
   if(adx_handle == INVALID_HANDLE)
   {
      Print("[RoyalHegen] Gagal buat ADX handle! Error: ", GetLastError());
      return INIT_FAILED;
   }


   //--- Inisialisasi balance awal agar Max DD tidak error di hari pertama
   dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   ResetDailyIfNewDay();
   PanelCreate();

   Print("[RoyalHegen] v1.16 aktif | ", _Symbol,
        " |",
         " | OB:", OverboughtLevel, " OS:", OversoldLevel,
         " | Jam:", StartHour, "-", EndHour,
         " | Target:$", DailyTarget,
         " | Magic:", MagicNumber);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(stoch_handle != INVALID_HANDLE)
      IndicatorRelease(stoch_handle);
   if(ema_handle != INVALID_HANDLE)
      IndicatorRelease(ema_handle);
   if(adx_handle != INVALID_HANDLE)
      IndicatorRelease(adx_handle);
   PanelDelete();
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   ResetDailyIfNewDay();

   if(EnableAveraging)
   {
      CheckAveraging(POSITION_TYPE_BUY);
      CheckAveraging(POSITION_TYPE_SELL);
   }

   //--- DDR: Drawdown Reduction
   if(EnableDDR)
   {
      CheckDDR(POSITION_TYPE_BUY);
      CheckDDR(POSITION_TYPE_SELL);
   }

   //--- Cek take profit USD per sisi (dijalankan setiap tick)
   if(TakeProfitUSD > 0)
   {
      CheckTakeProfitUSD(POSITION_TYPE_BUY);
      CheckTakeProfitUSD(POSITION_TYPE_SELL);
   }

   //--- Trailing stop (dijalankan setiap tick)
   if(EnableTrailing)
      CheckTrailingStop();



   bool withinHours  = IsWithinTradingHours();
   bool targetHit    = IsDailyTargetReached();
   bool inCooldown   = (CooldownMinutes > 0 &&
                        lastTPTime > 0 &&
                        (TimeCurrent() - lastTPTime) < CooldownMinutes * 60);

   if(withinHours && !targetHit && !inCooldown)
   {
      //--- Deteksi candle baru: ambil waktu open candle[0] (sedang berjalan)
      datetime currentBarTime = (datetime)SeriesInfoInteger(_Symbol, PERIOD_CURRENT, SERIES_LASTBAR_DATE);
      bool     isNewBar       = (currentBarTime != lastBarTime);

      if(isNewBar)
      {
         lastBarTime = currentBarTime;

         //--- Ambil buffer %K (0) dan %D (1), perlu 3 candle untuk deteksi cross
         double stochK[], stochD[];
         ArraySetAsSeries(stochK, true);
         ArraySetAsSeries(stochD, true);
         if(CopyBuffer(stoch_handle, 0, 0, 3, stochK) >= 3 &&
            CopyBuffer(stoch_handle, 1, 0, 3, stochD) >= 3)
         {
            //--- Gunakan candle [1] = sudah CLOSE (final), [2] = sebelumnya
            double K1 = stochK[1];  // %K candle closed
            double D1 = stochD[1];  // %D candle closed
            double K2 = stochK[2];  // %K candle sebelumnya (untuk deteksi cross)
            double D2 = stochD[2];  // %D candle sebelumnya

            //--- Kondisi zone
            //--- Stochastic zone & cross
            //    EnableStoch=false -> semua kondisi stoch dianggap valid (bypass)
            //    RequireCross=false -> cukup masuk zone, tidak perlu cross
            bool inOB      = !EnableStoch || (K1 >= OverboughtLevel);
            bool inOS      = !EnableStoch || (K1 <= OversoldLevel);
            bool crossUp   = !EnableStoch || !RequireCross || (K2 < D2 && K1 > D1);
            bool crossDown = !EnableStoch || !RequireCross || (K2 > D2 && K1 < D1);

            //--- Hitung total posisi terbuka semua arah (termasuk averaging)
            int totalBuy  = CountPositions(POSITION_TYPE_BUY);
            int totalSell = CountPositions(POSITION_TYPE_SELL);
            bool anyBuy   = (totalBuy  > 0);
            bool anySell  = (totalSell > 0);

            Print("[RoyalHegen] Candle baru | K=", DoubleToString(K1,2),
                  " D=", DoubleToString(D1,2),
                  " | OB=", inOB, " OS=", inOS,
                  " | CrossUp=", crossUp, " CrossDown=", crossDown,
                  " | BuyPos=", totalBuy, " SellPos=", totalSell);

            //--- Hitung HalfTrend direction (candle closed)
            int  htDir     = EnableHTFilter ? CalcHalfTrend() : 0;
            bool htUp      = (htDir ==  1);  // trend UP   -> izinkan BUY
            bool htDown    = (htDir == -1);  // trend DOWN -> izinkan SELL

            //--- ADX + DI filter (candle closed [1])
            double adxBuf[], diPlusBuf[], diMinusBuf[];
            ArraySetAsSeries(adxBuf,     true);
            ArraySetAsSeries(diPlusBuf,  true);
            ArraySetAsSeries(diMinusBuf, true);
            bool   adxOK      = (CopyBuffer(adx_handle, 0, 0, 3, adxBuf)     >= 3 &&
                                 CopyBuffer(adx_handle, 1, 0, 3, diPlusBuf)  >= 3 &&
                                 CopyBuffer(adx_handle, 2, 0, 3, diMinusBuf) >= 3);
            double adxVal     = adxOK ? adxBuf[1]     : 0;
            double diPlus     = adxOK ? diPlusBuf[1]  : 0;
            double diMinus    = adxOK ? diMinusBuf[1] : 0;
            bool   adxStrong  = (adxVal >= ADXMinLevel);         // trend kuat
            bool   adxBuyOK   = adxOK && adxStrong && (diPlus > diMinus);  // +DI > -DI
            bool   adxSellOK  = adxOK && adxStrong && (diMinus > diPlus);  // -DI > +DI

            //--- Ambil nilai EMA pada candle closed [1]
            double emaVal[];
            ArraySetAsSeries(emaVal, true);
            bool emaOK    = (CopyBuffer(ema_handle, 0, 0, 3, emaVal) >= 3);
            double ema1   = emaOK ? emaVal[1] : 0;  // EMA candle closed
            double price1 = (iClose(_Symbol, PERIOD_CURRENT, 1)); // close candle [1]
            bool aboveEMA = (price1 > ema1);  // harga di atas EMA -> uptrend
            bool belowEMA = (price1 < ema1);  // harga di bawah EMA -> downtrend


            //--- BUY: di zone Oversold + K cross ke atas D
            //    Filter EMA: hanya valid jika harga DI ATAS EMA (uptrend)
            int firstBuyCount  = CountFirstPositions(POSITION_TYPE_BUY);
            int firstSellCount = CountFirstPositions(POSITION_TYPE_SELL);

            if(inOS && crossUp && !anyBuy && firstBuyCount < 1)
            {
               if(EnableEMAFilter && !aboveEMA)
                  Print("[RoyalHegen] SIGNAL BUY diabaikan | harga di bawah EMA",
                        EMAPeriod, " (", DoubleToString(ema1,_Digits), ")");
               else if(EnableADXFilter && !adxBuyOK)
                  Print("[RoyalHegen] SIGNAL BUY diabaikan | ADX=", DoubleToString(adxVal,1),
                        " +DI=", DoubleToString(diPlus,1),
                        " -DI=", DoubleToString(diMinus,1),
                        " (butuh ADX>", ADXMinLevel, " & +DI>-DI)");
               else if(EnableHTFilter && !htUp)
                  Print("[RoyalHegen] SIGNAL BUY diabaikan | HalfTrend=",
                        htDir == -1 ? "DOWN" : "NEUTRAL", " (butuh UP)");
               else if(!AllowHedge && anySell)
                  Print("[RoyalHegen] SIGNAL BUY diabaikan | AllowHedge=false | masih ada ",
                        totalSell, " SELL terbuka | tunggu clear dulu");
               else
               {
                  Print("[RoyalHegen] SIGNAL BUY | OS + K cross UP | K=",
                        DoubleToString(K1,2), " D=", DoubleToString(D1,2),
                        " | Price=", DoubleToString(price1,_Digits),
                        " EMA=", DoubleToString(ema1,_Digits));
                  OpenBuy(LotSize, CommentBuy);
               }
            }

            //--- SELL: di zone Overbought + K cross ke bawah D
            //    Filter EMA: hanya valid jika harga DI BAWAH EMA (downtrend)
            if(inOB && crossDown && !anySell && firstSellCount < 1)
            {
               if(EnableEMAFilter && !belowEMA)
                  Print("[RoyalHegen] SIGNAL SELL diabaikan | harga di atas EMA",
                        EMAPeriod, " (", DoubleToString(ema1,_Digits), ")");
               else if(EnableADXFilter && !adxSellOK)
                  Print("[RoyalHegen] SIGNAL SELL diabaikan | ADX=", DoubleToString(adxVal,1),
                        " +DI=", DoubleToString(diPlus,1),
                        " -DI=", DoubleToString(diMinus,1),
                        " (butuh ADX>", ADXMinLevel, " & -DI>+DI)");
               else if(EnableHTFilter && !htDown)
                  Print("[RoyalHegen] SIGNAL SELL diabaikan | HalfTrend=",
                        htDir == 1 ? "UP" : "NEUTRAL", " (butuh DOWN)");
               else if(!AllowHedge && anyBuy)
                  Print("[RoyalHegen] SIGNAL SELL diabaikan | AllowHedge=false | masih ada ",
                        totalBuy, " BUY terbuka | tunggu clear dulu");
               else
               {
                  Print("[RoyalHegen] SIGNAL SELL | OB + K cross DOWN | K=",
                        DoubleToString(K1,2), " D=", DoubleToString(D1,2),
                        " | Price=", DoubleToString(price1,_Digits),
                        " EMA=", DoubleToString(ema1,_Digits));
                  OpenSell(LotSize, CommentSell);
               }
            }
         }
      }
   }

   PanelUpdate();
}

//+------------------------------------------------------------------+
//| ===========================================================       |
//|  PANEL FUNCTIONS                                                  |
//| ===========================================================       |
//+------------------------------------------------------------------+

//--- Buat semua objek panel
void PanelCreate()
{
   PanelDelete();

   // Y layout (jarak 16px per row):
   // 36  : STATUS
   // 52  : Stoch %K
   // 68  : Stoch %D
   // 84  : Signal
   // 100 : EMA
   // 116 : ADX/DI
   // 132 : HalfTrend
   // 148 : Server
   // ---- sep1 @ 166 ----
   // 175 : BUY
   // 191 :   Lots
   // 207 :   P/L
   // 223 :   Orders
   // ---- sep2 @ 241 ----
   // 250 : SELL
   // 266 :   Lots
   // 282 :   P/L
   // 298 :   Orders
   // ---- sep3 @ 316 ----
   // 325 : Daily P/L
   // 341 : Target
   // 357 : [bar bg/fill]
   // 373 : progress %
   // ---- sep4 @ 389 ----
   // 398 : Max DD
   // 414 : Daily Lot

   ObjRect(PREFIX+"bg",  PanelX, PanelY, PANEL_W, PANEL_H, CLR_BG, CLR_BORDER);
   ObjRect(PREFIX+"hdr", PanelX, PanelY, PANEL_W, 28,      CLR_HEADER, CLR_BORDER);
   ObjText(PREFIX+"title", PanelX+10, PanelY+7, "EA ROYAL HEGEN", FONT_SIZE+1, CLR_TITLE, true);

   ObjText(PREFIX+"lbl_status", PanelX+10,  PanelY+36,  "STATUS",                              FONT_SIZE-1, CLR_LABEL);
   ObjText(PREFIX+"val_status", PanelX+100, PanelY+36,  "---",                                 FONT_SIZE,   CLR_VALUE);

   ObjText(PREFIX+"lbl_stochK", PanelX+10,  PanelY+52,  "Stoch %K",                            FONT_SIZE-1, CLR_LABEL);
   ObjText(PREFIX+"val_stochK", PanelX+100, PanelY+52,  "---",                                 FONT_SIZE,   CLR_VALUE);

   ObjText(PREFIX+"lbl_stochD", PanelX+10,  PanelY+68,  "Stoch %D",                            FONT_SIZE-1, CLR_LABEL);
   ObjText(PREFIX+"val_stochD", PanelX+100, PanelY+68,  "---",                                 FONT_SIZE,   CLR_VALUE);

   ObjText(PREFIX+"lbl_cross",  PanelX+10,  PanelY+84,  "Signal",                              FONT_SIZE-1, CLR_LABEL);
   ObjText(PREFIX+"val_cross",  PanelX+100, PanelY+84,  "---",                                 FONT_SIZE,   CLR_VALUE);

   ObjText(PREFIX+"lbl_ema",    PanelX+10,  PanelY+100, "EMA "+IntegerToString(EMAPeriod),      FONT_SIZE-1, CLR_LABEL);
   ObjText(PREFIX+"val_ema",    PanelX+100, PanelY+100, "---",                                 FONT_SIZE,   CLR_VALUE);

   ObjText(PREFIX+"lbl_adx",    PanelX+10,  PanelY+116, "ADX/DI",                              FONT_SIZE-1, CLR_LABEL);
   ObjText(PREFIX+"val_adx",    PanelX+100, PanelY+116, "---",                                 FONT_SIZE,   CLR_VALUE);

   ObjText(PREFIX+"lbl_ht",     PanelX+10,  PanelY+132, "HalfTrend",                           FONT_SIZE-1, CLR_LABEL);
   ObjText(PREFIX+"val_ht",     PanelX+100, PanelY+132, "---",                                 FONT_SIZE,   CLR_VALUE);

   ObjText(PREFIX+"lbl_time",   PanelX+10,  PanelY+148, "Server",                              FONT_SIZE-1, CLR_LABEL);
   ObjText(PREFIX+"val_time",   PanelX+100, PanelY+148, "---",                                 FONT_SIZE,   CLR_VALUE);

   ObjHLine(PREFIX+"sep1", PanelX, PanelY+166, PANEL_W);

   ObjText(PREFIX+"lbl_buy",    PanelX+10,  PanelY+175, "BUY",                                 FONT_SIZE,   CLR_BUY, true);
   ObjText(PREFIX+"lbl_buylot", PanelX+10,  PanelY+191, "  Lots",                              FONT_SIZE-1, CLR_LABEL);
   ObjText(PREFIX+"val_buylot", PanelX+100, PanelY+191, "---",                                 FONT_SIZE,   CLR_VALUE);
   ObjText(PREFIX+"lbl_buypl",  PanelX+10,  PanelY+207, "  P/L",                               FONT_SIZE-1, CLR_LABEL);
   ObjText(PREFIX+"val_buypl",  PanelX+100, PanelY+207, "---",                                 FONT_SIZE,   CLR_VALUE);
   ObjText(PREFIX+"lbl_buyord", PanelX+10,  PanelY+223, "  Orders",                            FONT_SIZE-1, CLR_LABEL);
   ObjText(PREFIX+"val_buyord", PanelX+100, PanelY+223, "---",                                 FONT_SIZE,   CLR_VALUE);

   ObjHLine(PREFIX+"sep2", PanelX, PanelY+241, PANEL_W);

   ObjText(PREFIX+"lbl_sell",    PanelX+10,  PanelY+250, "SELL",                               FONT_SIZE,   CLR_SELL, true);
   ObjText(PREFIX+"lbl_selllot", PanelX+10,  PanelY+266, "  Lots",                             FONT_SIZE-1, CLR_LABEL);
   ObjText(PREFIX+"val_selllot", PanelX+100, PanelY+266, "---",                                FONT_SIZE,   CLR_VALUE);
   ObjText(PREFIX+"lbl_sellpl",  PanelX+10,  PanelY+282, "  P/L",                              FONT_SIZE-1, CLR_LABEL);
   ObjText(PREFIX+"val_sellpl",  PanelX+100, PanelY+282, "---",                                FONT_SIZE,   CLR_VALUE);
   ObjText(PREFIX+"lbl_sellord", PanelX+10,  PanelY+298, "  Orders",                           FONT_SIZE-1, CLR_LABEL);
   ObjText(PREFIX+"val_sellord", PanelX+100, PanelY+298, "---",                                FONT_SIZE,   CLR_VALUE);

   ObjHLine(PREFIX+"sep3", PanelX, PanelY+316, PANEL_W);

   ObjText(PREFIX+"lbl_daily",  PanelX+10,  PanelY+325, "Daily P/L",                          FONT_SIZE-1, CLR_LABEL);
   ObjText(PREFIX+"val_daily",  PanelX+100, PanelY+325, "---",                                 FONT_SIZE,   CLR_VALUE);

   ObjText(PREFIX+"lbl_target", PanelX+10,  PanelY+341, "Target",                              FONT_SIZE-1, CLR_LABEL);
   ObjText(PREFIX+"val_target", PanelX+100, PanelY+341, "$"+DoubleToString(DailyTarget,2),     FONT_SIZE,   CLR_TARGET);

   ObjRect(PREFIX+"bar_bg",   PanelX+10, PanelY+357, PANEL_W-20, 12, CLR_BAR_BG,   CLR_BAR_BG);
   ObjRect(PREFIX+"bar_fill", PanelX+10, PanelY+357, 0,          12, CLR_BAR_FILL, CLR_BAR_FILL);
   ObjText(PREFIX+"val_prog", PanelX+10, PanelY+373, "0%",                                     FONT_SIZE-1, CLR_LABEL);

   ObjHLine(PREFIX+"sep4", PanelX, PanelY+389, PANEL_W);

   ObjText(PREFIX+"lbl_mdd",  PanelX+10,  PanelY+398, "Max DD",                               FONT_SIZE-1, CLR_LABEL);
   ObjText(PREFIX+"val_mdd",  PanelX+100, PanelY+398, "---",                                   FONT_SIZE,   CLR_LOSS);

   ObjText(PREFIX+"lbl_dlot", PanelX+10,  PanelY+414, "Daily Lot",                             FONT_SIZE-1, CLR_LABEL);
   ObjText(PREFIX+"val_dlot", PanelX+100, PanelY+414, "0.00",                                  FONT_SIZE,   CLR_VALUE);

   ChartRedraw();
}
//--- Update nilai panel setiap tick
void PanelUpdate()
{
   // ---- Status ----
   bool   inHours    = IsWithinTradingHours();
   bool   tgtReached = IsDailyTargetReached();
   string statusStr;
   color  statusClr;

   bool   inCooldownP = (CooldownMinutes > 0 &&
                         lastTPTime > 0 &&
                         (TimeCurrent() - lastTPTime) < CooldownMinutes * 60);

   if(tgtReached)
   { statusStr = "TARGET HIT";  statusClr = CLR_TARGET; }
   else if(inCooldownP)
   {
      int secLeft = (int)(CooldownMinutes * 60 - (TimeCurrent() - lastTPTime));
      statusStr = StringFormat("COOLDOWN %dm%02ds", secLeft/60, secLeft%60);
      statusClr = CLR_TARGET;
   }
   else if(!inHours)
   { statusStr = "OFF HOURS";   statusClr = CLR_OFFHOUR; }
   else
   { statusStr = "ACTIVE";      statusClr = CLR_ACTIVE; }

   ObjSetText(PREFIX+"val_status", statusStr, statusClr);

   // ---- Stochastic %K / %D / Signal ----
   double stochK2[], stochD2[];
   ArraySetAsSeries(stochK2, true);
   ArraySetAsSeries(stochD2, true);
   if(!EnableStoch)
   {
      ObjSetText(PREFIX+"val_stochK", "OFF", CLR_LABEL);
      ObjSetText(PREFIX+"val_stochD", "OFF", CLR_LABEL);
   }
   else if(CopyBuffer(stoch_handle, 0, 0, 3, stochK2) >= 3 &&
           CopyBuffer(stoch_handle, 1, 0, 3, stochD2) >= 3)
   {
      double k0 = stochK2[0]; // live (untuk display real-time)
      double d0 = stochD2[0];
      double k1 = stochK2[1]; // closed
      double d1 = stochD2[1];
      double k2 = stochK2[2];
      double d2 = stochD2[2];

      // %K display (real-time)
      color kClr = CLR_VALUE;
      if(k0 >= OverboughtLevel)    kClr = CLR_SELL;
      else if(k0 <= OversoldLevel) kClr = CLR_BUY;
      string kStr = DoubleToString(k0, 2);
      kStr += (k0 >= OverboughtLevel ? "  [OB]" : (k0 <= OversoldLevel ? "  [OS]" : ""));
      ObjSetText(PREFIX+"val_stochK", kStr, kClr);

      // %D display (real-time)
      ObjSetText(PREFIX+"val_stochD", DoubleToString(d0, 2), CLR_LABEL);

      // Signal berdasarkan candle closed [1]
      bool inOB2      = (k1 >= OverboughtLevel);
      bool inOS2      = (k1 <= OversoldLevel);
      bool crossUp2   = !RequireCross || (k2 < d2 && k1 > d1);
      bool crossDown2 = !RequireCross || (k2 > d2 && k1 < d1);

      string sigStr = "WAIT";
      color  sigClr = CLR_LABEL;
      int panelBuy  = CountPositions(POSITION_TYPE_BUY);
      int panelSell = CountPositions(POSITION_TYPE_SELL);

      //--- Cek EMA untuk panel signal
      double emaP[];
      ArraySetAsSeries(emaP, true);
      bool   emaAvail  = (EnableEMAFilter && CopyBuffer(ema_handle, 0, 0, 3, emaP) >= 3);
      double closeP    = iClose(_Symbol, PERIOD_CURRENT, 1);
      bool   aboveEMAP = (!EnableEMAFilter || (emaAvail && closeP > emaP[1]));
      bool   belowEMAP = (!EnableEMAFilter || (emaAvail && closeP < emaP[1]));


      //--- ADX check for panel signal
      double adxPS[], diPPS[], diMPS[];
      ArraySetAsSeries(adxPS,  true);
      ArraySetAsSeries(diPPS,  true);
      ArraySetAsSeries(diMPS,  true);
      bool adxPOK   = (CopyBuffer(adx_handle, 0, 0, 3, adxPS)  >= 3 &&
                       CopyBuffer(adx_handle, 1, 0, 3, diPPS)  >= 3 &&
                       CopyBuffer(adx_handle, 2, 0, 3, diMPS)  >= 3);
      bool adxPBuy  = (!EnableADXFilter || (adxPOK && adxPS[1] >= ADXMinLevel && diPPS[1] > diMPS[1]));
      bool adxPSell = (!EnableADXFilter || (adxPOK && adxPS[1] >= ADXMinLevel && diMPS[1] > diPPS[1]));

      //--- HT check for panel signal
      int  htDirP  = EnableHTFilter ? CalcHalfTrend() : 1;
      bool htUpP   = (htDirP ==  1);
      bool htDownP = (htDirP == -1);

      bool stochBuyOK  = !EnableStoch || (inOS2 && crossUp2);
      bool stochSellOK = !EnableStoch || (inOB2 && crossDown2);
      // crossUp2/crossDown2 sudah include RequireCross logic di atas

      if(inOS2 && crossUp2 && panelBuy == 0 && !aboveEMAP)
                                   { sigStr = "BUY - BAWAH EMA";        sigClr = CLR_LABEL; }
      else if(inOS2 && crossUp2 && panelBuy == 0 && aboveEMAP && !adxPBuy)
                                   { sigStr = "BUY - ADX LEMAH/DI-";    sigClr = CLR_LABEL; }
      else if(inOS2 && crossUp2 && panelBuy == 0 && aboveEMAP && !htUpP)
                                   { sigStr = "BUY - HT DOWN/NEUTRAL";  sigClr = CLR_LABEL; }
      else if(inOS2 && crossUp2 && panelBuy == 0 && (AllowHedge || panelSell == 0))
                                   { sigStr = "BUY READY";              sigClr = CLR_BUY;   }
      else if(inOS2 && crossUp2 && !AllowHedge && panelSell > 0)
                                   { sigStr = "BUY - SELL BELUM CLEAR"; sigClr = CLR_LABEL; }
      else if(inOS2 && crossUp2 && AllowHedge && panelSell > 0 && panelBuy == 0)
                                   { sigStr = "BUY READY (HEDGE)";      sigClr = CLR_BUY;   }
      else if(inOB2 && crossDown2 && panelSell == 0 && !belowEMAP)
                                   { sigStr = "SELL - ATAS EMA";        sigClr = CLR_LABEL; }
      else if(inOB2 && crossDown2 && panelSell == 0 && belowEMAP && !adxPSell)
                                   { sigStr = "SELL - ADX LEMAH/DI+";   sigClr = CLR_LABEL; }
      else if(inOB2 && crossDown2 && panelSell == 0 && belowEMAP && !htDownP)
                                   { sigStr = "SELL - HT UP/NEUTRAL";   sigClr = CLR_LABEL; }
      else if(inOB2 && crossDown2 && panelSell == 0 && (AllowHedge || panelBuy == 0))
                                   { sigStr = "SELL READY";             sigClr = CLR_SELL;  }
      else if(inOB2 && crossDown2 && !AllowHedge && panelBuy > 0)
                                   { sigStr = "SELL - BUY BELUM CLEAR"; sigClr = CLR_LABEL; }
      else if(inOB2 && crossDown2 && AllowHedge && panelBuy > 0 && panelSell == 0)
                                   { sigStr = "SELL READY (HEDGE)";     sigClr = CLR_SELL;  }
      else if(inOB2)  { sigStr = RequireCross ? "OB (tunggu cross)" : "OB - filter lain"; sigClr = CLR_SELL; }
      else if(inOS2)  { sigStr = RequireCross ? "OS (tunggu cross)" : "OS - filter lain"; sigClr = CLR_BUY;  }
      ObjSetText(PREFIX+"val_cross", sigStr, sigClr);
   }

   // ---- EMA Filter display ----
   if(EnableEMAFilter)
   {
      double emaDisp[];
      ArraySetAsSeries(emaDisp, true);
      if(CopyBuffer(ema_handle, 0, 0, 2, emaDisp) >= 2)
      {
         double eNow   = emaDisp[0];
         double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         bool   above  = (bid > eNow);
         string emaStr = DoubleToString(eNow, _Digits);
         emaStr += above ? "  [ABOVE]" : "  [BELOW]";
         ObjSetText(PREFIX+"val_ema", emaStr, above ? CLR_BUY : CLR_SELL);
      }
   }
   else
      ObjSetText(PREFIX+"val_ema", "OFF", CLR_LABEL);

   // ---- ADX/DI display ----
   if(EnableADXFilter)
   {
      double adxD[], diPD[], diMD[];
      ArraySetAsSeries(adxD,  true);
      ArraySetAsSeries(diPD,  true);
      ArraySetAsSeries(diMD,  true);
      if(CopyBuffer(adx_handle, 0, 0, 2, adxD)  >= 2 &&
         CopyBuffer(adx_handle, 1, 0, 2, diPD)  >= 2 &&
         CopyBuffer(adx_handle, 2, 0, 2, diMD)  >= 2)
      {
         double aNow  = adxD[0];
         double dpNow = diPD[0];
         double dmNow = diMD[0];
         bool   strong = (aNow >= ADXMinLevel);
         string adxStr = StringFormat("%.1f  +DI:%.1f  -DI:%.1f", aNow, dpNow, dmNow);
         color  adxClr;
         if(!strong)               adxClr = CLR_LABEL;   // ADX lemah
         else if(dpNow > dmNow)    adxClr = CLR_BUY;     // +DI > -DI bullish
         else                      adxClr = CLR_SELL;    // -DI > +DI bearish
         ObjSetText(PREFIX+"val_adx", adxStr, adxClr);
      }
   }
   else
      ObjSetText(PREFIX+"val_adx", "OFF", CLR_LABEL);

   // ---- HalfTrend display ----
   if(EnableHTFilter)
   {
      int  htDirNow = CalcHalfTrend();
      string htStr;
      color  htClr;
      if(htDirNow == 1)       { htStr = "UP (Bullish)";   htClr = CLR_BUY;  }
      else if(htDirNow == -1) { htStr = "DOWN (Bearish)"; htClr = CLR_SELL; }
      else                    { htStr = "NEUTRAL";         htClr = CLR_LABEL;}
      ObjSetText(PREFIX+"val_ht", htStr, htClr);
   }
   else
      ObjSetText(PREFIX+"val_ht", "OFF", CLR_LABEL);

   // ---- Server time ----
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   string timeStr = StringFormat("%02d:%02d:%02d", dt.hour, dt.min, dt.sec);
   timeStr += StringFormat("  (%02d:00-%02d:59)", StartHour, EndHour);
   ObjSetText(PREFIX+"val_time", timeStr, inHours ? CLR_VALUE : CLR_OFFHOUR);

   // ---- BUY positions ----
   double buyPL   = 0;
   double buyLots = 0;
   int    buyOrd  = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)  != _Symbol)    continue;
      if(PositionGetInteger(POSITION_MAGIC)  != MagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE)   != POSITION_TYPE_BUY) continue;
      buyPL   += PositionGetDouble(POSITION_PROFIT);
      buyLots += PositionGetDouble(POSITION_VOLUME);
      buyOrd++;
   }

   // ---- SELL positions ----
   double sellPL   = 0;
   double sellLots = 0;
   int    sellOrd  = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)  != _Symbol)    continue;
      if(PositionGetInteger(POSITION_MAGIC)  != MagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE)   != POSITION_TYPE_SELL) continue;
      sellPL   += PositionGetDouble(POSITION_PROFIT);
      sellLots += PositionGetDouble(POSITION_VOLUME);
      sellOrd++;
   }

   // BUY display
   if(buyOrd > 0)
   {
      ObjSetText(PREFIX+"val_buylot",
                 DoubleToString(buyLots, 2) + " lot", CLR_VALUE);
      string buyTPStr = FormatMoney(buyPL);
      if(TakeProfitUSD > 0) buyTPStr += "  / $"+DoubleToString(TakeProfitUSD,2);
      ObjSetText(PREFIX+"val_buypl", buyTPStr, buyPL >= 0 ? CLR_PROFIT : CLR_LOSS);
      ObjSetText(PREFIX+"val_buyord", IntegerToString(buyOrd) + " posisi", CLR_VALUE);
   }
   else
   {
      ObjSetText(PREFIX+"val_buylot", "0 lot",     CLR_LABEL);
      ObjSetText(PREFIX+"val_buypl",  "--",        CLR_LABEL);
      ObjSetText(PREFIX+"val_buyord", "0 posisi",  CLR_LABEL);
   }

   // SELL display
   if(sellOrd > 0)
   {
      ObjSetText(PREFIX+"val_selllot",
                 DoubleToString(sellLots, 2) + " lot", CLR_VALUE);
      string sellTPStr = FormatMoney(sellPL);
      if(TakeProfitUSD > 0) sellTPStr += "  / $"+DoubleToString(TakeProfitUSD,2);
      ObjSetText(PREFIX+"val_sellpl", sellTPStr, sellPL >= 0 ? CLR_PROFIT : CLR_LOSS);
      ObjSetText(PREFIX+"val_sellord", IntegerToString(sellOrd) + " posisi", CLR_VALUE);
   }
   else
   {
      ObjSetText(PREFIX+"val_selllot", "0 lot",     CLR_LABEL);
      ObjSetText(PREFIX+"val_sellpl",  "--",        CLR_LABEL);
      ObjSetText(PREFIX+"val_sellord", "0 posisi",  CLR_LABEL);
   }

   // ---- Daily P/L ----
   double equity      = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyProfit = equity - dailyStartBalance;
   ObjSetText(PREFIX+"val_daily", FormatMoney(dailyProfit),
              dailyProfit >= 0 ? CLR_PROFIT : CLR_LOSS);

   //--- Update max drawdown harian
   //    Selalu update: catat nilai dailyProfit terendah sejak awal hari
   if(dailyProfit < dailyMaxDrawdown)
      dailyMaxDrawdown = dailyProfit;

   string mddStr;
   color  mddClr;
   if(dailyMaxDrawdown < 0)
   {
      mddStr = FormatMoney(dailyMaxDrawdown);
      mddClr = CLR_LOSS;
   }
   else
   {
      mddStr = "$0.00";
      mddClr = CLR_LABEL;
   }
   ObjSetText(PREFIX+"val_mdd", mddStr, mddClr);

   //--- Daily total lot
   ObjSetText(PREFIX+"val_dlot",
              DoubleToString(dailyTotalLot, 2) + " lot",
              CLR_VALUE);


   // ---- Progress bar ----
   if(DailyTarget > 0)
   {
      double pct     = MathMin(dailyProfit / DailyTarget, 1.0);
      if(pct < 0) pct = 0;
      int barMaxW    = PANEL_W - 20;
      int fillW      = (int)MathRound(pct * barMaxW);

      ObjectDelete(0, PREFIX+"bar_fill");
      ObjRect(PREFIX+"bar_fill", PanelX+10, PanelY+389, fillW, 12,
              tgtReached ? CLR_TARGET : CLR_BAR_FILL,
              tgtReached ? CLR_TARGET : CLR_BAR_FILL);

      ObjSetText(PREFIX+"val_prog",
                 StringFormat("%.0f%%  ($%.2f / $%.2f)", pct*100, dailyProfit, DailyTarget),
                 tgtReached ? CLR_TARGET : CLR_LABEL);
   }
   else
   {
      ObjSetText(PREFIX+"val_prog", "Daily Target nonaktif", CLR_LABEL);
   }

   //--- Draw TP lines di chart
   DrawTPLines();

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Draw garis TP di chart untuk BUY dan SELL                        |
//| Harga TP = weighted avg entry + TakeProfitUSD / totalVol / contract|
//+------------------------------------------------------------------+
void DrawTPLines()
{
   double tpBuyPrice  = CalcGroupTPPrice(POSITION_TYPE_BUY);
   double tpSellPrice = CalcGroupTPPrice(POSITION_TYPE_SELL);

   DrawOneLine("tp_buy",  tpBuyPrice,  clrLimeGreen, "TP BUY");
   DrawOneLine("tp_sell", tpSellPrice, clrTomato,    "TP SELL");
}

void DrawOneLine(string tag, double price, color clr, string labelText)
{
   string lineObj = PREFIX + tag + "_line";
   string lblObj  = PREFIX + tag + "_lbl";

   if(price <= 0)
   {
      ObjectDelete(0, lineObj);
      ObjectDelete(0, lblObj);
      return;
   }

   //--- Garis horizontal
   if(ObjectFind(0, lineObj) < 0)
      ObjectCreate(0, lineObj, OBJ_HLINE, 0, 0, price);
   ObjectSetDouble(0,  lineObj, OBJPROP_PRICE,      price);
   ObjectSetInteger(0, lineObj, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, lineObj, OBJPROP_STYLE,      STYLE_DASH);
   ObjectSetInteger(0, lineObj, OBJPROP_WIDTH,      2);
   ObjectSetInteger(0, lineObj, OBJPROP_BACK,       false);
   ObjectSetInteger(0, lineObj, OBJPROP_SELECTABLE, false);
   ObjectSetString(0,  lineObj, OBJPROP_TOOLTIP,
                   StringFormat("%s  $%.2f  @ %s",
                                labelText, TakeProfitUSD,
                                DoubleToString(price, _Digits)));

   //--- Label teks di ujung kanan garis pakai OBJ_LABEL (screen coords)
   //    Posisi Y dihitung dari harga ke pixel chart
   if(ObjectFind(0, lblObj) < 0)
      ObjectCreate(0, lblObj, OBJ_LABEL, 0, 0, 0);

   string txt = StringFormat("%s  $%.2f  @ %s",
                              labelText, TakeProfitUSD,
                              DoubleToString(price, _Digits));

   //--- Gunakan corner kanan atas, posisi X=5 dari kanan, Y dikira dari harga
   int    chartH    = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   double priceMin  = ChartGetDouble(0, CHART_PRICE_MIN);
   double priceMax  = ChartGetDouble(0, CHART_PRICE_MAX);
   int    labelY    = 50; // fallback

   if(priceMax > priceMin)
   {
      double ratio = (price - priceMin) / (priceMax - priceMin);
      labelY = (int)((1.0 - ratio) * chartH);
      labelY = (int)MathMax(12, MathMin(chartH - 12, labelY));
   }

   ObjectSetInteger(0, lblObj, OBJPROP_XDISTANCE,   5);
   ObjectSetInteger(0, lblObj, OBJPROP_YDISTANCE,   labelY);
   ObjectSetInteger(0, lblObj, OBJPROP_CORNER,      CORNER_RIGHT_UPPER);
   ObjectSetString(0,  lblObj, OBJPROP_TEXT,        txt);
   ObjectSetString(0,  lblObj, OBJPROP_FONT,        "Consolas");
   ObjectSetInteger(0, lblObj, OBJPROP_FONTSIZE,    8);
   ObjectSetInteger(0, lblObj, OBJPROP_COLOR,       clr);
   ObjectSetInteger(0, lblObj, OBJPROP_BACK,        false);
   ObjectSetInteger(0, lblObj, OBJPROP_SELECTABLE,  false);
   ObjectSetInteger(0, lblObj, OBJPROP_ANCHOR,      ANCHOR_RIGHT);
}

//+------------------------------------------------------------------+
//| Hitung harga TP untuk satu sisi posisi                           |
//| Return 0 jika tidak ada posisi atau TakeProfitUSD = 0            |
//+------------------------------------------------------------------+
double CalcGroupTPPrice(ENUM_POSITION_TYPE posType)
{
   if(TakeProfitUSD <= 0) return 0;

   double totalVolume = 0;
   double weightedSum = 0;
   int    posCount    = 0;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))                     continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)       continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)   continue;
      if(PositionGetInteger(POSITION_TYPE)  != (long)posType) continue;
      double vol = PositionGetDouble(POSITION_VOLUME);
      weightedSum  += PositionGetDouble(POSITION_PRICE_OPEN) * vol;
      totalVolume  += vol;
      posCount++;
   }

   if(posCount == 0 || totalVolume == 0) return 0;

   double avgEntry   = weightedSum / totalVolume;
   double contractSz = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double tpDist     = TakeProfitUSD / totalVolume / contractSz;

   double tpPrice = (posType == POSITION_TYPE_BUY)
                    ? NormalizeDouble(avgEntry + tpDist, _Digits)
                    : NormalizeDouble(avgEntry - tpDist, _Digits);

   return tpPrice;
}

//--- Hapus semua objek panel
void PanelDelete()
{
   ObjectsDeleteAll(0, PREFIX);
   //--- Hapus juga TP lines (pakai prefix yg sama)
   ChartRedraw();
}
//+------------------------------------------------------------------+
//| Helper functions                                                  |
//+------------------------------------------------------------------+
void ObjRect(string name, int x, int y, int w, int h, color bg, color border)
{
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,      w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,      h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,    bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      border);
   ObjectSetInteger(0, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BACK,       false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void ObjText(string name, int x, int y, string text, int fontSize, color clr, bool bold = false)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
   ObjectSetString(0,  name, OBJPROP_TEXT,       text);
   ObjectSetString(0,  name, OBJPROP_FONT,       bold ? FONT_NAME+" Bold" : FONT_NAME);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BACK,       false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void ObjSetText(string name, string text, color clr)
{
   ObjectSetString(0,  name, OBJPROP_TEXT,  text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void ObjHLine(string name, int x, int y, int w)
{
   ObjRect(name, x, y, w, 1, CLR_BORDER, CLR_BORDER);
}

string FormatMoney(double val)
{
   return (val >= 0 ? "+" : "") + "$" + DoubleToString(val, 2);
}

bool IsWithinTradingHours()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int h = dt.hour;
   return (StartHour <= EndHour)
          ? (h >= StartHour && h <= EndHour)
          : (h >= StartHour || h <= EndHour);
}

void ResetDailyIfNewDay()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime todayStart = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", dt.year, dt.mon, dt.day));
   if(todayStart != lastResetDay)
   {
      lastResetDay       = todayStart;
      dailyStartBalance  = AccountInfoDouble(ACCOUNT_BALANCE);
      dailyMaxDrawdown   = 0;
      dailyTotalLot      = 0;
      Print("[RoyalHegen] Hari baru | Balance awal: $", DoubleToString(dailyStartBalance, 2));
   }
}

bool IsDailyTargetReached()
{
   if(DailyTarget <= 0) return false;
   double equity      = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyProfit = equity - dailyStartBalance;
   if(dailyProfit >= DailyTarget)
   {
      static datetime lastLog = 0;
      if(TimeCurrent() - lastLog >= 60)
      {
         Print("[RoyalHegen] Daily target tercapai! $", DoubleToString(dailyProfit,2), " / $", DailyTarget);
         lastLog = TimeCurrent();
      }
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Averaging DOWN: tambah posisi saat floating LOSS >= AveragePoints|
//| Averaging UP  : tambah posisi saat floating PROFIT >= AvgUpPoints |
//+------------------------------------------------------------------+
void CheckAveraging(ENUM_POSITION_TYPE posType)
{
   //--- Cari posisi terakhir dibuka (waktu paling baru)
   datetime lastOpenTime  = 0;
   double   lastOpenPrice = 0;
   double   lastLot       = 0;
   bool     found         = false;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)  != _Symbol)      continue;
      if(PositionGetInteger(POSITION_MAGIC)  != MagicNumber)   continue;
      if(PositionGetInteger(POSITION_TYPE)   != (long)posType) continue;
      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if(t > lastOpenTime)
      {
         lastOpenTime  = t;
         lastOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         lastLot       = PositionGetDouble(POSITION_VOLUME);
         found         = true;
      }
   }
   if(!found) return;

   //--- Guard: tunggu 1 detik agar posisi terdaftar dulu
   if((TimeCurrent() - lastOpenTime) < 1) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   //--- Cari entry TERTINGGI dan TERENDAH dari semua posisi satu sisi
   double highestEntry = -DBL_MAX;
   double lowestEntry  =  DBL_MAX;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))                     continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)       continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)   continue;
      if(PositionGetInteger(POSITION_TYPE)  != (long)posType) continue;
      double ep = PositionGetDouble(POSITION_PRICE_OPEN);
      if(ep > highestEntry) highestEntry = ep;
      if(ep < lowestEntry)  lowestEntry  = ep;
   }

   //--- Hitung jarak dari entry terakhir ke harga sekarang
   double distDown = 0;
   double distUp   = 0;

   if(posType == POSITION_TYPE_BUY)
   {
      distDown = (lastOpenPrice - bid) / _Point;  // positif = harga turun (BUY rugi)
      distUp   = (bid - lastOpenPrice) / _Point;  // positif = harga naik (BUY profit)
   }
   else
   {
      distDown = (ask - lastOpenPrice) / _Point;  // positif = harga naik (SELL rugi)
      distUp   = (lastOpenPrice - ask) / _Point;  // positif = harga turun (SELL profit)
   }

   //--- Avg DOWN (loss direction)
   if(distDown >= AveragePoints)
   {
      double nextLot = CalcNextLot(posType);
      Print("[RoyalHegen] Avg DOWN ", posType == POSITION_TYPE_BUY ? "BUY" : "SELL",
            " | dist=", DoubleToString(distDown,1), " pts | lot=", nextLot);
      if(posType == POSITION_TYPE_BUY) OpenBuy(nextLot,  CommentBuy);
      else                             OpenSell(nextLot, CommentSell);
      return;
   }

   //--- Avg UP (profit direction)
   //    Syarat: harga harus sudah MELEWATI entry tertinggi/terendah
   //    + AvgUpPoints tambahan di atasnya
   //    Tujuan: tidak avg up ketika masih di tengah2 posisi avg down
   if(EnableAvgUp)
   {
      bool priceBreakout = false;
      double breakoutDist = 0;

      if(posType == POSITION_TYPE_BUY)
      {
         //--- BUY: harga harus di ATAS entry tertinggi + AvgUpPoints
         double threshold = highestEntry + AvgUpPoints * _Point;
         priceBreakout = (bid > threshold);
         breakoutDist  = (bid - highestEntry) / _Point;
      }
      else
      {
         //--- SELL: harga harus di BAWAH entry terendah - AvgUpPoints
         double threshold = lowestEntry - AvgUpPoints * _Point;
         priceBreakout = (ask < threshold);
         breakoutDist  = (lowestEntry - ask) / _Point;
      }

      if(priceBreakout)
      {
         double nextLotUp = CalcNextLot(posType);
         Print("[RoyalHegen] Avg UP ", posType == POSITION_TYPE_BUY ? "BUY" : "SELL",
               " | breakout=", DoubleToString(breakoutDist,1), " pts dari teratas",
               " | lot=", nextLotUp);
         if(posType == POSITION_TYPE_BUY) OpenBuy(nextLotUp,  CommentBuy);
         else                             OpenSell(nextLotUp, CommentSell);
      }
   }
}

//+------------------------------------------------------------------+
//| Force close via CloseBy hedge
//+------------------------------------------------------------------+
//| Force close via CloseBy hedge                                     |
//+------------------------------------------------------------------+
void ForceCloseGroup(ENUM_POSITION_TYPE posType, string reason)
{
   string side        = (posType == POSITION_TYPE_BUY)  ? "BUY"  : "SELL";
   ENUM_POSITION_TYPE oppType = (posType == POSITION_TYPE_BUY) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;

   ulong  tickets[];
   double volumes[];
   int    found       = 0;
   double totalVolume = 0;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))                     continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)       continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)   continue;
      if(PositionGetInteger(POSITION_TYPE)  != (long)posType) continue;
      double vol = PositionGetDouble(POSITION_VOLUME);
      ArrayResize(tickets, found+1);
      ArrayResize(volumes, found+1);
      tickets[found] = ticket;
      volumes[found] = vol;
      totalVolume   += vol;
      found++;
   }
   if(found == 0) { Print("[RoyalHegen] ForceClose ", side, " | tidak ada posisi"); return; }
   Print("[RoyalHegen] ForceClose ", side, " | ", reason, " | ", found, " posisi");

   trade.SetDeviationInPoints(100);
   trade.SetExpertMagicNumber(MagicNumber + 1);
   bool hedgeOK = (posType == POSITION_TYPE_BUY)
                  ? trade.Sell(totalVolume, _Symbol, 0, 0, 0, "CloseBy_Hedge")
                  : trade.Buy(totalVolume, _Symbol, 0, 0, 0, "CloseBy_Hedge");
   trade.SetExpertMagicNumber(MagicNumber);

   if(!hedgeOK)
   {
      Print("[RoyalHegen] Hedge gagal | fallback close biasa");
      for(int i = 0; i < found; i++)
         for(int t = 0; t < 5; t++) { if(trade.PositionClose(tickets[i])) break; Sleep(200); }
      trade.SetDeviationInPoints(10);
      return;
   }
   Sleep(300);
   ulong hedgeTicket = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)  != _Symbol)       continue;
      if(PositionGetInteger(POSITION_TYPE)   != (long)oppType)  continue;
      if(PositionGetString(POSITION_COMMENT) != "CloseBy_Hedge") continue;
      hedgeTicket = ticket;
      break;
   }
   if(hedgeTicket == 0)
   {
      for(int i = 0; i < found; i++) { trade.PositionClose(tickets[i]); Sleep(100); }
      trade.SetDeviationInPoints(10);
      return;
   }
   for(int i = 0; i < found; i++)
   {
      if(!PositionSelectByTicket(tickets[i])) continue;
      if(!PositionSelectByTicket(hedgeTicket)) break;
      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      req.action      = TRADE_ACTION_CLOSE_BY;
      req.position    = tickets[i];
      req.position_by = hedgeTicket;
      req.symbol      = _Symbol;
      req.magic       = MagicNumber;
      req.deviation   = 100;
      if(!OrderSend(req, res))
         Print("[RoyalHegen] CloseBy #", tickets[i], " gagal | ", res.retcode);
      else
      {
         Sleep(100);
         for(int j = PositionsTotal()-1; j >= 0; j--)
         {
            ulong t = PositionGetTicket(j);
            if(!PositionSelectByTicket(t)) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol)      continue;
            if(PositionGetInteger(POSITION_TYPE)  != (long)oppType) continue;
            hedgeTicket = t;
            break;
         }
      }
   }
   Sleep(200);
   if(PositionSelectByTicket(hedgeTicket))
      for(int t = 0; t < 5; t++) { if(trade.PositionClose(hedgeTicket)) break; Sleep(200); }
   trade.SetDeviationInPoints(10);
}

//+------------------------------------------------------------------+
//| Drawdown Reduction (DDR)                                          |
//| Tutup posisi PERTAMA (paling lama) menggunakan profit posisi     |
//| TERAKHIR untuk mengurangi drawdown secara bertahap               |
//+------------------------------------------------------------------+
void CheckDDR(ENUM_POSITION_TYPE posType)
{
   if(!EnableDDR) return;

   //--- Kumpulkan semua posisi satu sisi, urutkan berdasarkan waktu buka
   ulong    tickets[];
   datetime times[];
   double   profits[];
   int      found = 0;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))                     continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)       continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)   continue;
      if(PositionGetInteger(POSITION_TYPE)  != (long)posType) continue;
      ArrayResize(tickets, found+1);
      ArrayResize(times,   found+1);
      ArrayResize(profits, found+1);
      tickets[found] = ticket;
      times[found]   = (datetime)PositionGetInteger(POSITION_TIME);
      profits[found] = PositionGetDouble(POSITION_PROFIT);
      found++;
   }

   //--- DDR baru aktif setelah jumlah posisi >= DDRStartCount + 1
   //    Contoh: DDRStartCount=10, butuh minimal 11 posisi
   if(found <= DDRStartCount) return;

   //--- Urutkan posisi dari yang PALING LAMA ke PALING BARU (bubble sort)
   for(int i = 0; i < found-1; i++)
      for(int j = i+1; j < found; j++)
         if(times[j] < times[i])
         {
            ulong    tmpT = tickets[i]; tickets[i] = tickets[j]; tickets[j] = tmpT;
            datetime tmpD = times[i];   times[i]   = times[j];   times[j]   = tmpD;
            double   tmpP = profits[i]; profits[i] = profits[j]; profits[j] = tmpP;
         }

   //--- Posisi ke-1 = index 0 (paling lama dibuka)
   //--- Posisi ke-(DDRStartCount+1) = index DDRStartCount (paling baru dalam grup DDR)
   int firstIdx = 0;
   int lastIdx  = DDRStartCount;  // posisi ke-11 jika DDRStartCount=10

   //--- Guard: posisi terakhir harus sudah terbuka minimal 1 detik
   if((TimeCurrent() - times[lastIdx]) < 1) return;

   //--- Cek profit GABUNGAN posisi ke-1 dan ke-(DDRStartCount+1)
   //    Ini inti DDR: posisi lama rugi + posisi baru profit = net profit
   double pairProfit = profits[firstIdx] + profits[lastIdx];

   if(pairProfit < DDRMinProfit)
   {
      // Uncomment baris di bawah untuk debug:
      // Print("[RoyalHegen] DDR skip | #", tickets[firstIdx], "(", DoubleToString(profits[firstIdx],2),
      //       ") + #", tickets[lastIdx], "(", DoubleToString(profits[lastIdx],2),
      //       ") = $", DoubleToString(pairProfit,2), " < min $", DDRMinProfit);
      return;
   }

   string side = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
   Print("[RoyalHegen] DDR ", side,
         " | Posisi=", found,
         " | #", tickets[firstIdx], " profit=", DoubleToString(profits[firstIdx],2),
         " + #", tickets[lastIdx],  " profit=", DoubleToString(profits[lastIdx],2),
         " = $", DoubleToString(pairProfit,2), " >= $", DDRMinProfit,
         " | CloseBy keduanya");

   //--- CloseBy: tutup posisi pertama dan terakhir sekaligus
   //    CloseBy menutup kedua posisi tanpa kena spread
   if(!PositionSelectByTicket(tickets[firstIdx])) return;
   if(!PositionSelectByTicket(tickets[lastIdx]))  return;

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action      = TRADE_ACTION_CLOSE_BY;
   req.position    = tickets[firstIdx];
   req.position_by = tickets[lastIdx];
   req.symbol      = _Symbol;
   req.magic       = MagicNumber;
   req.deviation   = 100;

   if(!OrderSend(req, res))
   {
      Print("[RoyalHegen] DDR CloseBy gagal | ", res.retcode,
            " | Fallback close satu per satu");
      trade.SetDeviationInPoints(100);
      trade.PositionClose(tickets[firstIdx]);
      Sleep(200);
      trade.PositionClose(tickets[lastIdx]);
      trade.SetDeviationInPoints(10);
   }
   else
      Print("[RoyalHegen] DDR CloseBy OK | #", tickets[firstIdx],
            " dan #", tickets[lastIdx], " tertutup | net=$",
            DoubleToString(pairProfit,2));
}

void CheckTakeProfitUSD(ENUM_POSITION_TYPE posType)
{
   double totalProfit = 0;
   int    posCount    = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)  != _Symbol)      continue;
      if(PositionGetInteger(POSITION_MAGIC)  != MagicNumber)   continue;
      if(PositionGetInteger(POSITION_TYPE)   != (long)posType) continue;
      totalProfit += PositionGetDouble(POSITION_PROFIT);
      posCount++;
   }
   if(posCount == 0 || totalProfit < TakeProfitUSD) return;
   string side = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
   Print("[RoyalHegen] TP hit | ", side, " | $", DoubleToString(totalProfit,2),
         " | Cooldown ", CooldownMinutes, " menit dimulai");
   ForceCloseGroup(posType, "TP $"+DoubleToString(TakeProfitUSD,2));
   if(CooldownMinutes > 0) lastTPTime = TimeCurrent();
}

void TrailingStopForSide(ENUM_POSITION_TYPE posType)
{
   double startPts = TrailingStart    * _Point;
   double distPts  = TrailingDistance * _Point;
   double stepPts  = TrailingStep     * _Point;
   ulong  tickets[];
   double totalVolume = 0, weightedSum = 0;
   int    sz = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))                     continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)       continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)   continue;
      if(PositionGetInteger(POSITION_TYPE)  != (long)posType) continue;
      double vol = PositionGetDouble(POSITION_VOLUME);
      weightedSum += PositionGetDouble(POSITION_PRICE_OPEN) * vol;
      totalVolume += vol;
      ArrayResize(tickets, sz+1);
      tickets[sz++] = ticket;
   }
   if(sz == 0 || totalVolume == 0) return;
   double avgEntry   = weightedSum / totalVolume;
   double bid        = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask        = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double profitDist = (posType == POSITION_TYPE_BUY) ? (bid - avgEntry) : (avgEntry - ask);
   if(profitDist < startPts) return;
   double newSL = (posType == POSITION_TYPE_BUY)
                  ? NormalizeDouble(bid - distPts, _Digits)
                  : NormalizeDouble(ask + distPts, _Digits);
   for(int i = 0; i < sz; i++)
   {
      if(!PositionSelectByTicket(tickets[i])) continue;
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      bool move = (posType == POSITION_TYPE_BUY)
                  ? (currentSL == 0 || newSL > currentSL + stepPts)
                  : (currentSL == 0 || newSL < currentSL - stepPts);
      if(move) trade.PositionModify(tickets[i], newSL, currentTP);
   }
}

void CheckTrailingStop()
{
   TrailingStopForSide(POSITION_TYPE_BUY);
   TrailingStopForSide(POSITION_TYPE_SELL);
}

void OpenBuy(double lot, string comment)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(!trade.Buy(lot, _Symbol, ask, 0, 0, comment))
      Print("[RoyalHegen] BUY gagal! ", trade.ResultRetcode(), " | ", trade.ResultRetcodeDescription());
   else { dailyTotalLot += lot; Print("[RoyalHegen] BUY @ ", DoubleToString(ask,_Digits), " lot=", lot, " (", comment, ")"); }
}

void OpenSell(double lot, string comment)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(!trade.Sell(lot, _Symbol, bid, 0, 0, comment))
      Print("[RoyalHegen] SELL gagal! ", trade.ResultRetcode(), " | ", trade.ResultRetcodeDescription());
   else { dailyTotalLot += lot; Print("[RoyalHegen] SELL @ ", DoubleToString(bid,_Digits), " lot=", lot, " (", comment, ")"); }
}

int CountFirstPositions(ENUM_POSITION_TYPE type)
{
   int count = 0;
   string targetComment = (type == POSITION_TYPE_BUY) ? CommentBuy : CommentSell;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)  != _Symbol)      continue;
      if(PositionGetInteger(POSITION_MAGIC)  != MagicNumber)   continue;
      if(PositionGetInteger(POSITION_TYPE)   != (long)type)    continue;
      if(PositionGetString(POSITION_COMMENT) != targetComment) continue;
      count++;
   }
   return count;
}

int CountPositions(ENUM_POSITION_TYPE type)
{
   int count = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol    &&
         PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
         PositionGetInteger(POSITION_TYPE)  == (long)type)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Hitung lot untuk level averaging berikutnya                      |
//|                                                                  |
//| Rumus: LotSize * LotMultiplier^(jumlah_posisi_sekarang)          |
//| Contoh: LotSize=0.01, Multiplier=1.01, 5 posisi ada:            |
//|   Level 6 = 0.01 * 1.01^5 = 0.01050 -> 0.01 (step 0.01)        |
//|   Level 10 = 0.01 * 1.01^9 = 0.01094 -> 0.01                   |
//|   Level 20 = 0.01 * 1.01^19= 0.01208 -> 0.01 atau 0.02         |
//|   Level 70 = 0.01 * 1.01^69= 0.01985 -> 0.02                   |
//+------------------------------------------------------------------+
double CalcNextLot(ENUM_POSITION_TYPE posType)
{
   //--- Hitung jumlah posisi yang sudah ada
   int posCount = CountPositions(posType);

   //--- Lot = LotSize * Multiplier^posCount
   //    posCount = jumlah posisi sekarang = level berikutnya - 1
   double rawLot = LotSize * MathPow(LotMultiplier, posCount);

   //--- Normalisasi ke step lot broker
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   //--- Gunakan MathFloor agar tidak over-round ke atas
   double lot = MathFloor(rawLot / stepLot) * stepLot;
   lot = MathMax(minLot, MathMin(maxLot, lot));

   //--- Pastikan selalu naik minimal 1 step dari posisi pertama
   if(LotMultiplier > 1.0 && lot < minLot) lot = minLot;

   return NormalizeDouble(lot, 2);
}

double NormalizeLot(double lot)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathRound(lot / stepLot) * stepLot;
   lot = MathMax(minLot, MathMin(maxLot, lot));
   return NormalizeDouble(lot, 2);
}
//+------------------------------------------------------------------+
