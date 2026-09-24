//+------------------------------------------------------------------+
//|                                       Omon_Obet_Whipsaw_Reversal_V1.mq5 |
//|                                Copyright 2024, Trader Nakal™ Team   |
//|             High-Volatility Whipsaw Reversal — Flip-and-Loop Engine |
//+------------------------------------------------------------------+
#property copyright "Trader Nakal™ — Omon Agent"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

enum ENUM_TRADE_DIR
{
   TRADE_ALL        = 0,   // Semua Arah
   TRADE_BUY_ONLY   = 1,   // Buy Saja
   TRADE_SELL_ONLY  = 2    // Sell Saja
};

enum ENUM_LOT_MODE
{
   LOT_FIXED        = 0,   // Lot Tetap
   LOT_PERCENT_RISK = 1    // % Risiko Equity
};

//+=================================================================+
//| INPUT PARAMETERS                                                |
//+=================================================================+
input group "=== General Settings ==="
input ENUM_TRADE_DIR InpTradeDir          = TRADE_ALL;       // Pilihan Arah Trade
input int            InpMagicNumber       = 8899;            // ID Unik EA
input string         InpComment           = "WhipsawRev";    // Comment Order
input int            InpDeviation         = 25;              // Deviasi Open (points)

input group "=== Signal & Volatility Filter ==="
input int            InpBBPeriod          = 20;              // Periode Bollinger Band
input double         InpBBDev             = 2.0;             // Deviasi BB
input int            InpATRPeriod         = 14;              // Periode ATR
input double         InpATRMin            = 0.0;             // ATR Minimum (0: disable)
input double         InpATRMultiplier     = 1.5;             // Multiplier jarak pending vs ATR
input bool           InpUseBBSignal       = true;            // Gunakan sinyal BB rejection
input bool           InpUseEngulfing      = true;            // Gunakan sinyal engulfing

input group "=== Whipsaw Loop Settings ==="
input double         InpPendingDistPips   = 5.0;             // Jarak pending order (pips)
input double         InpSLPips            = 0.0;             // SL awal per posisi (0: tidak pakai)
input double         InpTPPips            = 0.0;             // TP per posisi (0: tidak pakai)
input int            InpMaxFlipsWindow    = 3;               // Max flip dalam window
input int            InpFlipWindowSec     = 300;             // Window detik untuk hitung flip
input double         InpMinProfitPips     = 2.0;             // Min profit sebelum flip diizinkan
input int            InpMaxTotalFlips     = 10;              // Max total flip per sesi
input int            InpPauseCooldownMin  = 15;              // Cooldown pause (menit)

input group "=== Money Management ==="
input ENUM_LOT_MODE  InpLotMode           = LOT_FIXED;       // Mode Lot
input double         InpFixedLot          = 0.01;            // Lot Tetap
input double         InpRiskPercent       = 1.0;             // Risiko % Equity (jika mode %)
input double         InpSLForRiskPips     = 10.0;            // SL reference untuk hitung % risk

input group "=== Global Kill-Switch ==="
input double         InpMaxDrawdownPct    = 20.0;            // Max Drawdown % equity (0: disable)
input double         InpDailyProfitPct    = 0.0;             // Daily profit target % (0: disable)

//+=================================================================+
//| GLOBAL ENGINE VARIABLES                                         |
//+=================================================================+
CTrade       g_trade;
int          g_h_bands = INVALID_HANDLE;
int          g_h_atr   = INVALID_HANDLE;
double       g_buf_upper[], g_buf_lower[], g_buf_mid[];
double       g_buf_atr[];

bool         g_hasLong       = false;
bool         g_hasShort      = false;
ulong        g_activeTicket  = 0;       // Ticket posisi aktif
ulong        g_pendingTicket = 0;       // Ticket pending order aktif
ENUM_ORDER_TYPE g_pendingType = ORDER_TYPE_BUY; // Tipe pending aktif

int          g_flipCount     = 0;       // Flip dalam window aktif
int          g_totalFlips    = 0;       // Total flip dalam sesi
ulong        g_lastFlipTimes[];         // Array waktu flip (detik)
datetime     g_sessionStart  = 0;       // Waktu entry pertama sesi
datetime     g_pauseUntil    = 0;       // Cooldown setelah pause
bool         g_paused        = false;   // Flag pause sementara

//+=================================================================+
//| INITIALIZATION                                                  |
//+=================================================================+
int OnInit()
{
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints((ulong)InpDeviation);
   SetFillMode();
   g_trade.SetAsyncMode(false);

   g_h_bands = iBands(_Symbol, _Period, InpBBPeriod, 0, InpBBDev, PRICE_CLOSE);
   g_h_atr   = iATR(_Symbol, _Period, InpATRPeriod);

   if(g_h_bands == INVALID_HANDLE || g_h_atr == INVALID_HANDLE)
   {
      Print("[ERR] Gagal buat handle indikator");
      return(INIT_FAILED);
   }

   ArraySetAsSeries(g_buf_upper, true);
   ArraySetAsSeries(g_buf_lower, true);
   ArraySetAsSeries(g_buf_mid,   true);
   ArraySetAsSeries(g_buf_atr,   true);
   ArrayResize(g_lastFlipTimes, 0);

   Print("[SYSTEM] Whipsaw Reversal Loaded | Magic: ", InpMagicNumber);
   return(INIT_SUCCEEDED);
}

//+=================================================================+
//| DEINITIALIZATION                                                |
//+=================================================================+
void OnDeinit(const int reason)
{
   if(g_h_bands != INVALID_HANDLE) IndicatorRelease(g_h_bands);
   if(g_h_atr   != INVALID_HANDLE) IndicatorRelease(g_h_atr);
}

//+=================================================================+
//| AUTO DETECT FILL MODE (FOK / IOC)                               |
//+=================================================================+
void SetFillMode()
{
   uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      g_trade.SetTypeFilling(ORDER_FILLING_IOC);
   else
      g_trade.SetTypeFilling(ORDER_FILLING_RETURN);
}

//+=================================================================+
//| GLOBAL KILL-SWITCH CHECK                                        |
//+=================================================================+
bool CheckKillSwitch()
{
   if(InpMaxDrawdownPct <= 0.0 && InpDailyProfitPct <= 0.0) return(false);

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance <= 0.0) return(false);

   double ddPct = (balance - equity) / balance * 100.0;
   if(InpMaxDrawdownPct > 0.0 && ddPct >= InpMaxDrawdownPct)
   {
      Print("[KILL-SWITCH] Drawdown ", NormalizeDouble(ddPct, 2), "% ≥ ",
            InpMaxDrawdownPct, "%. Close all.");
      CloseAllPositions();
      DeleteAllPending();
      PauseLoop();
      return(true);
   }

   if(InpDailyProfitPct > 0.0)
   {
      double profitPct = (equity - balance) / balance * 100.0;
      if(profitPct >= InpDailyProfitPct)
      {
         Print("[KILL-SWITCH] Daily profit ", NormalizeDouble(profitPct, 2), "% ≥ ",
               InpDailyProfitPct, "%. Close all.");
         CloseAllPositions();
         DeleteAllPending();
         PauseLoop();
         return(true);
      }
   }

   return(false);
}

//+=================================================================+
//| MAIN TICK LOOP                                                  |
//+=================================================================+
void OnTick()
{
   static datetime lastBarTime = 0;
   datetime curBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool newBar = (curBarTime != lastBarTime);
   if(newBar) lastBarTime = curBarTime;

   // Refresh data
   if(!RefreshIndicator()) return;

   // Global kill-switch pertama
   if(CheckKillSwitch()) return;

   // Cek pause cooldown
   if(g_paused && TimeCurrent() >= g_pauseUntil)
   {
      g_paused = false;
      Print("[INFO] Cooldown selesai, loop aktif kembali");
   }

   // Verifikasi posisi dan order
   VerifyPositions();
   VerifyPending();

   // Deteksi dan proses flip (dapat terjadi mid-candle)
   ProcessFlips();

   // Pastikan setiap posisi aktif memiliki pending order opposite
   ManageHedge();

   // Entry baru hanya di candle baru dan tidak sedang ada posisi/pending
   if(newBar && !g_paused && g_activeTicket == 0 && g_pendingTicket == 0)
      CheckSignal();

   // Whipsaw guard: cek window flip
   CheckWhipsawWindow();
}

//+=================================================================+
//| REFRESH INDICATOR DATA                                          |
//+=================================================================+
bool RefreshIndicator()
{
   ResetLastError();
   if(CopyBuffer(g_h_bands, 1, 0, 3, g_buf_upper) < 3)
   {
      Print("[ERR] CopyBuffer BB Upper failed: ", GetLastError());
      return(false);
   }
   ResetLastError();
   if(CopyBuffer(g_h_bands, 2, 0, 3, g_buf_lower) < 3)
   {
      Print("[ERR] CopyBuffer BB Lower failed: ", GetLastError());
      return(false);
   }
   ResetLastError();
   if(CopyBuffer(g_h_bands, 0, 0, 3, g_buf_mid) < 3)
   {
      Print("[ERR] CopyBuffer BB Mid failed: ", GetLastError());
      return(false);
   }
   ResetLastError();
   if(CopyBuffer(g_h_atr, 0, 0, 3, g_buf_atr) < 3)
   {
      Print("[ERR] CopyBuffer ATR failed: ", GetLastError());
      return(false);
   }
   return(true);
}

//+=================================================================+
//| VERIFIKASI POSISI AKTIF                                         |
//+=================================================================+
void VerifyPositions()
{
   g_hasLong      = false;
   g_hasShort     = false;
   g_activeTicket = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
      {
         g_hasLong = true;
         g_activeTicket = ticket;
      }
      else if(ptype == POSITION_TYPE_SELL)
      {
         g_hasShort = true;
         g_activeTicket = ticket;
      }
   }
}

//+=================================================================+
//| VERIFIKASI PENDING ORDER AKTIF                                  |
//+=================================================================+
void VerifyPending()
{
   g_pendingTicket = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;

      g_pendingTicket = ticket;
      g_pendingType   = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      break;
   }
}

//+=================================================================+
//| ENTRY SIGNAL                                                    |
//+=================================================================+
void CheckSignal()
{
   if(!PassVolatilityFilter()) return;

   double sl = 0.0, tp = 0.0;

   bool canBuy  = (InpTradeDir == TRADE_ALL || InpTradeDir == TRADE_BUY_ONLY);
   bool canSell = (InpTradeDir == TRADE_ALL || InpTradeDir == TRADE_SELL_ONLY);

   if(canSell && IsShort())
   {
      OpenEntryAndHedge(ORDER_TYPE_SELL, sl, tp);
      return;
   }
   if(canBuy && IsLong())
   {
      OpenEntryAndHedge(ORDER_TYPE_BUY, sl, tp);
      return;
   }
}

//+=================================================================+
//| SIGNAL MODULES                                                  |
//+=================================================================+
bool IsShort()
{
   if(InpTradeDir == TRADE_BUY_ONLY) return(false);

   bool bbSignal = false;
   bool engSignal = false;

   double open1  = iOpen(_Symbol, _Period, 1);
   double high1  = iHigh(_Symbol, _Period, 1);
   double low1   = iLow(_Symbol, _Period, 1);
   double close1 = iClose(_Symbol, _Period, 1);
   double close2 = iClose(_Symbol, _Period, 2);
   double open2  = iOpen(_Symbol, _Period, 2);

   if(InpUseBBSignal)
   {
      // Rejection dari upper band: high tembus BB upper tapi close di dalam
      bbSignal = (high1 > g_buf_upper[1] && close1 < g_buf_upper[1] && close1 < open1);
   }

   if(InpUseEngulfing)
   {
      // Bearish engulfing
      engSignal = (close1 < open1 && close2 > open2 &&
                   open1 > close2 && close1 < open2);
   }

   return(bbSignal || engSignal);
}

bool IsLong()
{
   if(InpTradeDir == TRADE_SELL_ONLY) return(false);

   bool bbSignal = false;
   bool engSignal = false;

   double open1  = iOpen(_Symbol, _Period, 1);
   double high1  = iHigh(_Symbol, _Period, 1);
   double low1   = iLow(_Symbol, _Period, 1);
   double close1 = iClose(_Symbol, _Period, 1);
   double close2 = iClose(_Symbol, _Period, 2);
   double open2  = iOpen(_Symbol, _Period, 2);

   if(InpUseBBSignal)
   {
      // Rejection dari lower band: low tembus BB lower tapi close di dalam
      bbSignal = (low1 < g_buf_lower[1] && close1 > g_buf_lower[1] && close1 > open1);
   }

   if(InpUseEngulfing)
   {
      // Bullish engulfing
      engSignal = (close1 > open1 && close2 < open2 &&
                   open1 < close2 && close1 > open2);
   }

   return(bbSignal || engSignal);
}

//+=================================================================+
//| VOLATILITY FILTER                                               |
//+=================================================================+
bool PassVolatilityFilter()
{
   if(ArraySize(g_buf_atr) < 1) return(false);
   if(InpATRMin <= 0.0) return(true);

   double atrValue = g_buf_atr[0];
   if(atrValue <= 0.0) return(false);

   double minAtrPoints = InpATRMin * PipToPoint();
   return(atrValue >= minAtrPoints);
}

//+=================================================================+
//| OPEN ENTRY + PENDING HEDGE                                      |
//+=================================================================+
void OpenEntryAndHedge(ENUM_ORDER_TYPE type, double sl, double tp)
{
   if(g_paused) return;

   double entryPrice = (type == ORDER_TYPE_BUY) ?
                       SymbolInfoDouble(_Symbol, SYMBOL_ASK) :
                       SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double lot = CalculateLot(type, sl);

   // Buka posisi market
   if(!g_trade.PositionOpen(_Symbol, type, lot, entryPrice, sl, tp, InpComment))
   {
      Print("[ERR] Gagal open posisi: ", GetLastError());
      return;
   }

   // Ambil ticket posisi yang baru dibuka
   Sleep(50);
   VerifyPositions();
   if(g_activeTicket == 0)
   {
      Print("[ERR] Posisi tidak ditemukan setelah open");
      return;
   }

   // Reset sesi tracking
   g_sessionStart = TimeCurrent();
   g_totalFlips   = 0;
   ArrayResize(g_lastFlipTimes, 0);

   // Tempatkan pending order opposite
   ENUM_POSITION_TYPE ptype = (type == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   PlaceOppositePending(ptype, entryPrice, lot);
}

//+=================================================================+
//| PLACE OPPOSITE PENDING STOP                                     |
//+=================================================================+
void PlaceOppositePending(ENUM_POSITION_TYPE posType, double entryPrice, double lot)
{
   double pendingDist = PendingDistancePoints();
   double price = 0.0;
   ENUM_ORDER_TYPE orderType;

   if(posType == POSITION_TYPE_BUY)
   {
      orderType = ORDER_TYPE_SELL_STOP;
      price = NormalizeDouble(entryPrice - pendingDist, _Digits);
   }
   else
   {
      orderType = ORDER_TYPE_BUY_STOP;
      price = NormalizeDouble(entryPrice + pendingDist, _Digits);
   }

   double sl = 0.0, tp = 0.0;
   if(InpSLPips > 0.0)
   {
      if(orderType == ORDER_TYPE_BUY_STOP)
         sl = NormalizeDouble(price - InpSLPips * PipToPoint(), _Digits);
      else
         sl = NormalizeDouble(price + InpSLPips * PipToPoint(), _Digits);
   }
   if(InpTPPips > 0.0)
   {
      if(orderType == ORDER_TYPE_BUY_STOP)
         tp = NormalizeDouble(price + InpTPPips * PipToPoint(), _Digits);
      else
         tp = NormalizeDouble(price - InpTPPips * PipToPoint(), _Digits);
   }

   // Validasi jarak minimum order
   double freeze = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
   double stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double minDist = MathMax(freeze, stopLevel);

   double currentPrice = (orderType == ORDER_TYPE_BUY_STOP) ?
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK) :
                         SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(MathAbs(price - currentPrice) < minDist)
   {
      Print("[WARN] Pending order terlalu dekat current price, dist: ",
            NormalizeDouble(MathAbs(price - currentPrice) / _Point, 1));
      return;
   }

   if(!g_trade.OrderOpen(_Symbol, orderType, lot, 0, price, sl, tp,
                          ORDER_TIME_GTC, 0, InpComment))
   {
      Print("[ERR] Gagal place pending: ", GetLastError(),
            " | Type: ", EnumToString(orderType), " | Price: ", price);
   }
   else
   {
      Sleep(50);
      VerifyPending();
   }
}

//+=================================================================+
//| MANAGE HEDGE: PASTIKAN ADA PENDING UNTUK POSISI AKTIF           |
//+=================================================================+
void ManageHedge()
{
   if(g_activeTicket == 0) return;
   if(g_pendingTicket != 0) return;
   if(g_paused) return;

   if(!PositionSelectByTicket(g_activeTicket)) return;

   ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double lot        = PositionGetDouble(POSITION_VOLUME);

   PlaceOppositePending(ptype, entryPrice, lot);
}

//+=================================================================+
//| PROCESS FLIPS                                                   |
//+=================================================================+
void ProcessFlips()
{
   // Hitung jumlah posisi kita saat ini
   int ourPositions = CountOurPositions();

   // Jika tidak ada posisi, tidak ada yang diproses
   if(ourPositions == 0) return;

   // Jika ada lebih dari 1 posisi kita → pending telah trigger menjadi posisi baru
   // Ini adalah kondisi flip. Posisi baru adalah yang paling baru (ticket terbesar).
   if(ourPositions >= 2)
   {
      // Temukan posisi terbaru (ticket terbesar) dan terlama (ticket terkecil)
      ulong newestTicket = 0;
      ulong oldestTicket = ULONG_MAX;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

         if(ticket > newestTicket) newestTicket = ticket;
         if(ticket < oldestTicket) oldestTicket = ticket;
      }

      if(newestTicket == 0) return;

      // Cek apakah posisi lama (oldest) mencapai min profit sebelum di-flip
      double oldProfitPips = PositionProfitPips(oldestTicket);
      if(oldProfitPips < InpMinProfitPips)
      {
         Print("[WHIPSAW] Flip tanpa min profit (", NormalizeDouble(oldProfitPips, 2),
               " pips). Close all & pause.");
         CloseAllPositions();
         DeleteAllPending();
         PauseLoop();
         return;
      }

      // Tutup posisi lama
      if(oldestTicket != newestTicket)
         g_trade.PositionClose(oldestTicket);

      // Update tracking ke posisi baru
      g_activeTicket = newestTicket;
      RecordFlip();

      // Tempatkan pending opposite untuk posisi baru
      if(!PositionSelectByTicket(g_activeTicket)) return;
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double lot        = PositionGetDouble(POSITION_VOLUME);

      PlaceOppositePending(ptype, entryPrice, lot);
   }
}

//+=================================================================+
//| COUNT OUR POSITIONS                                             |
//+=================================================================+
int CountOurPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      count++;
   }
   return(count);
}

//+=================================================================+
//| RECORD FLIP                                                     |
//+=================================================================+
void RecordFlip()
{
   g_totalFlips++;

   datetime now = TimeCurrent();
   int size = ArraySize(g_lastFlipTimes);
   ArrayResize(g_lastFlipTimes, size + 1);
   g_lastFlipTimes[size] = (long)now;

   // Bersihkan flip yang sudah di luar window
   int cutoff = (int)(now - InpFlipWindowSec);
   int validCount = 0;
   for(int i = 0; i < ArraySize(g_lastFlipTimes); i++)
   {
      if(g_lastFlipTimes[i] >= cutoff)
      {
         g_lastFlipTimes[validCount] = g_lastFlipTimes[i];
         validCount++;
      }
   }
   ArrayResize(g_lastFlipTimes, validCount);
   g_flipCount = validCount;

   Print("[FLIP] #", g_totalFlips, " | Window count: ", g_flipCount,
         " | Time: ", TimeToString(now));
}

//+=================================================================+
//| CHECK WHIPSAW WINDOW                                            |
//+=================================================================+
void CheckWhipsawWindow()
{
   if(g_paused) return;

   // Max total flips
   if(InpMaxTotalFlips > 0 && g_totalFlips >= InpMaxTotalFlips)
   {
      Print("[PAUSE] Max total flips reached: ", g_totalFlips);
      CloseAllPositions();
      DeleteAllPending();
      PauseLoop();
      return;
   }

   // Max flips dalam window
   if(InpMaxFlipsWindow > 0 && g_flipCount >= InpMaxFlipsWindow)
   {
      Print("[PAUSE] Max flips in window: ", g_flipCount,
            " within ", InpFlipWindowSec, "s");
      CloseAllPositions();
      DeleteAllPending();
      PauseLoop();
   }
}

//+=================================================================+
//| PAUSE LOOP                                                      |
//+=================================================================+
void PauseLoop()
{
   g_paused = true;
   g_pauseUntil = TimeCurrent() + InpPauseCooldownMin * 60;
   g_totalFlips = 0;
   g_flipCount  = 0;
   ArrayResize(g_lastFlipTimes, 0);
   Print("[PAUSE] Loop dijeda sampai ", TimeToString(g_pauseUntil));
}

//+=================================================================+
//| CLOSE ALL POSITIONS (BY MAGIC)                                  |
//+=================================================================+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      g_trade.PositionClose(ticket);
   }
   Sleep(50);
   VerifyPositions();
}

//+=================================================================+
//| DELETE ALL PENDING ORDERS (BY MAGIC)                            |
//+=================================================================+
void DeleteAllPending()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;

      g_trade.OrderDelete(ticket);
   }
   Sleep(50);
   VerifyPending();
}

//+=================================================================+
//| LOT CALCULATION                                                 |
//+=================================================================+
double CalculateLot(ENUM_ORDER_TYPE type, double slPrice)
{
   double lot = InpFixedLot;

   if(InpLotMode == LOT_PERCENT_RISK)
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double riskMoney = equity * InpRiskPercent / 100.0;
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

      if(tickSize > 0.0 && tickValue > 0.0)
      {
         double slPoints = InpSLForRiskPips * PipToPoint();
         if(slPoints <= 0.0) slPoints = InpPendingDistPips * PipToPoint();
         double lossPerLot = (slPoints / tickSize) * tickValue;
         if(lossPerLot > 0.0)
            lot = riskMoney / lossPerLot;
      }
   }

   return(NormalizeLot(lot));
}

//+=================================================================+
//| NORMALIZE LOT                                                   |
//+=================================================================+
double NormalizeLot(double lot)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(lotStep <= 0.0) lotStep = 0.01;

   lot = MathFloor(lot / lotStep) * lotStep;
   lot = MathMax(minLot, MathMin(maxLot, lot));

   return(NormalizeDouble(lot, 2));
}

//+=================================================================+
//| PENDING DISTANCE                                                |
//+=================================================================+
double PendingDistancePoints()
{
   double distPips = InpPendingDistPips;

   if(InpATRMultiplier > 0.0 && ArraySize(g_buf_atr) > 0 && g_buf_atr[0] > 0.0)
      distPips = MathMax(distPips, g_buf_atr[0] * InpATRMultiplier / PipToPoint());

   return(distPips * PipToPoint());
}

//+=================================================================+
//| PROFIT IN PIPS                                                  |
//+=================================================================+
double PositionProfitPips(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return(0.0);

   ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currPrice = (ptype == POSITION_TYPE_BUY) ?
                      SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                      SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double points = (ptype == POSITION_TYPE_BUY) ?
                   (currPrice - openPrice) :
                   (openPrice - currPrice);

   return(points / PipToPoint());
}

//+=================================================================+
//| PIP TO POINT CONVERTER                                          |
//+=================================================================+
double PipToPoint()
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return((digits % 2 != 0) ? 10.0 * _Point : _Point);
}

//+------------------------------------------------------------------+
