//+------------------------------------------------------------------+
//|                                                  ASSARV10.mq5    |
//|                                             www.assarofficial.com|
//|                       Converted from MQL4, with cooldown updates |
//+------------------------------------------------------------------+
#property copyright "www.assarofficial.com"
#property link      "support@assarofficial.com"
#property version   "1.02"
#property description "ASSARV10 - Misty Horivak"
#property description "Default settings are for 6 digit pairs"
#property description "Use default setting with leverage 1:500!"
#property description "Use on any time frame. But do NOT move between time frames."
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\SymbolInfo.mqh>

CTrade         m_trade;
CPositionInfo  m_position;
COrderInfo     m_order;
CAccountInfo   m_account;
CSymbolInfo    m_symbol;

//+------------------------------------------------------------------+
//| Indicator handles                                                 |
//+------------------------------------------------------------------+
int hMA_Low  = INVALID_HANDLE;
int hMA_High = INVALID_HANDLE;
int hBands   = INVALID_HANDLE;
int hEnvelopes = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Enums                                                             |
//+------------------------------------------------------------------+
enum ENUM_SLTP_MODE
{
   Server = 0, // Place SL n TP
   Client = 1  // Hidden SL n TP
};

enum ENUM_TRAILINGSTOP_METHOD
{
   TS_NONE            = 0, // No Trailing Stop
   TS_CLASSIC         = 1, // Classic
   TS_STEP_DISTANCE   = 2, // Step Keep Distance
   TS_STEP_BY_STEP    = 3  // Step By Step
};

enum lottype
{
   Fixed_lot          = 0,
   Risk_per_trade     = 1,
   Margin_percent_use = 2
};

enum trailingmode
{
   Adaptive_by_Time       = 0,
   Adaptive_by_Volatility = 1,
   Adaptive_by_Volume     = 2
};

enum gmt
{
   Auto_GMT_not_for_tester = 0,
   Manual_GMT              = 1
};

//+------------------------------------------------------------------+
//| MQL4 compat constants                                             |
//+------------------------------------------------------------------+
#define MODE_LWMA  3
#define MODE_UPPER 0
#define MODE_LOWER 1

//+------------------------------------------------------------------+
//| Input parameters                                                  |
//+------------------------------------------------------------------+
input string Contact1           = "www.assarofficial.com";
input string Contact2           = "support@assarofficial.com";
input string Important3         = "Default settings are for 6 digit pairs";
input string Important4         = "Use default setting with leverage 1:500!";
input string Important5         = "Use on any time frame. But do NOT move between time frames.";
input string Currency           = "Any currency pair under 4 pip spread.";
input bool   mm                 = true;
input double risk               = 1;
input double default_lot        = 0.01;
input int    MaxSpread          = 40;
input int    StopLoss           = 200;
input int    TakeProfit         = 50;
input ENUM_SLTP_MODE        SLnTPMode        = Client;
input int    LockProfitAfter    = 20;
input int    ProfitLock         = 15;
input ENUM_TRAILINGSTOP_METHOD TrailingStopMethod = TS_STEP_DISTANCE;
input int    TrailingStop       = 5;
input int    TrailingStep       = 1;
input bool   inpEnableAlert     = true;

//--- Cooldown after losing streak
input int    MaxConsecutiveLosses = 3;
input int    CooldownMinutes      = 60;

//--- Broker compatibility options
input bool   DisableSpreadCheck   = false;  // Skip MaxSpread filter
input bool   EnableDigitCheck     = false;  // Validate broker digit fraction

input string hint4                  = "===== Forex Events Settings =====";
input bool   FilterByEvents         = false;
input int    BeforeEventsInMinutes  = 60;
input int    AfterEventsInMinutes   = 30;
input int    EventsAlertDispX       = 15;
input int    EventsAlertDispY       = 15;
input string EventLabelFont         = "Verdana";
input int    EventLabelFontSize     = 8;
input bool   IncludeHigh            = true;
input bool   IncludeMedium          = true;
input bool   IncludeLow             = false;
input color  HighImpactColor        = clrRed;
input color  MediumImpactColor      = clrOrange;
input color  LowImpactColor         = clrYellow;
input bool   IncludeSpeaks          = true;
input bool   IncludeHolidays        = true;
input bool   ReportAllPairs         = false;
input bool   ReportUSD              = true;
input bool   ReportEUR              = true;
input bool   ReportGBP              = true;
input bool   ReportCAD              = true;
input bool   ReportCHF              = true;
input bool   ReportJPY              = true;
input bool   ReportAUD              = true;
input bool   ReportNZD              = true;
input bool   ReportCNY              = true;

//--- Non-input copies of input vars (since input vars are const in MQL5)
bool   mm_internal       = true;
double risk_internal     = 1;
double default_lot_internal = 0.01;

//+------------------------------------------------------------------+
//| Global variables                                                  |
//+------------------------------------------------------------------+
int      Expert_Id            = 8888;
string   Expert_Comment       = "ASSARV10";
string   COMMENT              = "ASSARV10 support@assarofficial.com";

int      Zi_396, Zi_400, Zi_404, Zi_408, Zi_412, Zi_416, Zi_420, Zi_424;
int      Z_count_428 = 0;
int      Zi_432 = 0;
double   Zda_436[30];
double   Z_lots_440;
double   Zd_448, Zd_456, Zd_464, Zd_472;
double   Z_lotstep_480;
double   Z_marginrequired_488;
double   Zd_496 = 0.0;

bool     ECN_Mode           = false;
bool     Debug              = false;
bool     Verbose            = true;
int      MaxExecution       = 0;
int      MaxExecutionMinutes = 10;
double   AddPriceGap        = 0.0;
double   Commission         = 0.0;
int      Slippage           = 3;
double   MinimumUseStopLevel = 10.0;
double   VolatilityMultiplier = 125.0;
double   VolatilityLimit    = 325.0;
bool     UseVolatilityPercentage = true;
int      f;
double   VolatilityPercentageLimit = 125.0;
int      UseIndicatorSwitch = 3;
double   BBDeviation        = 1.5;
bool     AUTOMM             = true;
double   EnvelopesDeviation = 0.07;
int      OrderExpireSeconds = 3600;
double   MinLots            = 0.01;
double   MaxLots            = 1000.0;
bool     TakeShots          = true;
int      DelayTicks         = 1;
int      ShotsPerBar        = 1;
string   Zs_320             = "ASSARV10 support@assarofficial.com";
int      Z_period_328       = 3;
int      Z_digits_332       = 0;
int      Zi_336             = 0;
datetime Z_time_340         = 0;
int      Z_count_344        = 0;
int      Zi_348             = 0;
int      Zi_352             = -1;
int      Zi_356             = 0;
int      Zi_360             = 0;

lottype  Lot_Type           = 1;
double   Lot_Risk           = 1.0;
double   Lot_Max            = 0.0;
bool     TrailingStop_CorrectSL    = true;
bool     TrailingStop_UseRealOPAndSL = true;
trailingmode TrailingStop_TrailingMode = 0;

datetime Z_datetime_364;
int      Z_leverage_368;
double   Zi_372;
int      Zi_376, Zi_380, Zi_384, Zi_388, Zi_392;

datetime Zi_504;
int      Zi_508             = -1;
int      Zi_512             = 3000000;
int      Zi_516             = 0;

string   lbl                = "Assar.";
string   gbl;
string   STR_OPTYPE[]       = {"Buy", "Sell", "Buy Limit", "Sell Limit", "Buy Stop", "Sell Stop"};
string   lblEvent;
bool     Reset;

//--- Cooldown tracking
int      consecutiveLosses  = 0;
datetime cooldownUntil      = 0;

//--- Event system globals
int      EventsAlertDispCorner = 2;

//+------------------------------------------------------------------+
//| Cached iMA wrapper - uses handle created in OnInit               |
//+------------------------------------------------------------------+
double iMA_mql5(string symbol, ENUM_TIMEFRAMES tf, int period, int shift, int method, int applied, int index)
{
   int handle = INVALID_HANDLE;
   if (applied == PRICE_LOW && hMA_Low != INVALID_HANDLE)
      handle = hMA_Low;
   else if (applied == PRICE_HIGH && hMA_High != INVALID_HANDLE)
      handle = hMA_High;
   else
   {
      handle = iMA(symbol, tf, period, shift, (ENUM_MA_METHOD)method, applied);
      if (handle == INVALID_HANDLE) return 0;
   }
   double buf[];
   ArraySetAsSeries(buf, true);
   for (int tryIdx = index; tryIdx <= 1; tryIdx++)
   {
      if (CopyBuffer(handle, 0, tryIdx, 1, buf) > 0)
      {
         if (handle != hMA_Low && handle != hMA_High) IndicatorRelease(handle);
         return buf[0];
      }
   }
   if (handle != hMA_Low && handle != hMA_High) IndicatorRelease(handle);
   return 0;
}

//+------------------------------------------------------------------+
//| Cached iBands wrapper                                             |
//+------------------------------------------------------------------+
double iBands_mql5(string symbol, ENUM_TIMEFRAMES tf, int period, double deviation, int shift, int applied, int mode, int index)
{
   int handle = hBands;
   if (handle == INVALID_HANDLE)
   {
      handle = iBands(symbol, tf, period, shift, deviation, applied);
      if (handle == INVALID_HANDLE) return 0;
   }
   double buf[];
   ArraySetAsSeries(buf, true);
   for (int tryIdx = index; tryIdx <= 1; tryIdx++)
   {
      if (CopyBuffer(handle, mode, tryIdx, 1, buf) > 0)
      {
         if (handle != hBands) IndicatorRelease(handle);
         return buf[0];
      }
   }
   if (handle != hBands) IndicatorRelease(handle);
   return 0;
}

//+------------------------------------------------------------------+
//| Cached iEnvelopes wrapper                                         |
//+------------------------------------------------------------------+
double iEnvelopes_mql5(string symbol, ENUM_TIMEFRAMES tf, int period, int method, int shift, int applied, double deviation, int mode, int index)
{
   int handle = hEnvelopes;
   if (handle == INVALID_HANDLE)
   {
      handle = iEnvelopes(symbol, tf, period, shift, (ENUM_MA_METHOD)method, applied, deviation);
      if (handle == INVALID_HANDLE) return 0;
   }
   double buf[];
   ArraySetAsSeries(buf, true);
   for (int tryIdx = index; tryIdx <= 1; tryIdx++)
   {
      if (CopyBuffer(handle, mode, tryIdx, 1, buf) > 0)
      {
         if (handle != hEnvelopes) IndicatorRelease(handle);
         return buf[0];
      }
   }
   if (handle != hEnvelopes) IndicatorRelease(handle);
   return 0;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("====== Initialization of ", Zs_320, " ======");

   m_symbol.Name(Symbol());
   m_symbol.Refresh();
   m_trade.SetExpertMagicNumber(Expert_Id);
   mm_internal = mm;
   risk_internal = risk;
   default_lot_internal = default_lot;

   gbl = lbl + Symbol() + ".";
   if (MQLInfoInteger(MQL_TESTER))
   {
      gbl = "B." + gbl;
      GlobalVariablesDeleteAll(gbl);
   }
   if (FilterByEvents) { InitEvents(); Reset = true; }

   Z_datetime_364 = TimeLocal();
   Zi_336 = (EnableDigitCheck) ? 0 : -1;
   Z_digits_332 = (int)m_symbol.Digits();
   Z_leverage_368 = (int)m_account.Leverage();
   Z_lotstep_480 = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

   if (UseIndicatorSwitch < 1 || UseIndicatorSwitch > 4) UseIndicatorSwitch = 1;
   if (UseIndicatorSwitch == 4) UseVolatilityPercentage = false;

   Zd_464 = MinimumUseStopLevel;
   if (AddPriceGap == 0.0 && Zd_464 != 0.0) { }
   else if (Zd_464 == 0.0 && AddPriceGap == 0.0) Zd_464 = MinimumUseStopLevel;

   VolatilityPercentageLimit = VolatilityPercentageLimit / 100.0 + 1.0;
   VolatilityMultiplier /= 10.0;
   ArrayInitialize(Zda_436, 0);
   VolatilityLimit *= m_symbol.Point();
   Commission = f0_12(Commission * m_symbol.Point());
   Zd_464 *= m_symbol.Point();
   AddPriceGap *= m_symbol.Point();

    // FIX #3: Ensure stop gap meets broker minimum stop distance plus one extra point of buffer
    double brokerStopLevel = (double)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL) * m_symbol.Point();
    if (brokerStopLevel > 0 && Zd_464 < brokerStopLevel + m_symbol.Point())
       Zd_464 = brokerStopLevel + m_symbol.Point();
    if (Verbose)
    {
       Print("Init: EXEMODE=" + IntegerToString(SymbolInfoInteger(Symbol(), SYMBOL_TRADE_EXEMODE)) +
             " FILLING_MODE=" + IntegerToString(SymbolInfoInteger(Symbol(), SYMBOL_FILLING_MODE)) +
             " STOPS_LEVEL=" + IntegerToString(SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL)) +
             " FREEZE_LEVEL=" + IntegerToString(SymbolInfoInteger(Symbol(), SYMBOL_TRADE_FREEZE_LEVEL)) +
             " Point=" + DoubleToString(m_symbol.Point()) +
             " Zd_464=" + DoubleToString(Zd_464));
    }

   MinLots = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   MaxLots = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   if (MaxLots < MinLots) MaxLots = MinLots;

   Z_marginrequired_488 = SymbolInfoDouble(Symbol(), SYMBOL_MARGIN_INITIAL);
   Zi_372 = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_CONTRACT_SIZE);

   f0_4();
   Z_lots_440 = f0_11();

   if (Expert_Id < 0) f0_13();
   if (MaxExecution > 0) MaxExecutionMinutes = 60 * MaxExecution;
   f0_14();

   //--- Create cached indicator handles
   if (hMA_Low == INVALID_HANDLE)
      hMA_Low = iMA(Symbol(), PERIOD_M1, Z_period_328, 0, MODE_LWMA, PRICE_LOW);
   if (hMA_High == INVALID_HANDLE)
      hMA_High = iMA(Symbol(), PERIOD_M1, Z_period_328, 0, MODE_LWMA, PRICE_HIGH);
   if (hBands == INVALID_HANDLE)
      hBands = iBands(Symbol(), PERIOD_M1, Z_period_328, 0, BBDeviation, PRICE_OPEN);
   if (hEnvelopes == INVALID_HANDLE)
      hEnvelopes = iEnvelopes(Symbol(), PERIOD_M1, Z_period_328, 0, MODE_LWMA, PRICE_OPEN, EnvelopesDeviation);

   Print("========== Initialization complete! ===========\n");
   return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if (FilterByEvents) DeInitEvents();
   string Ms_0 = "";
   if (MQLInfoInteger(MQL_TESTER) && MaxExecution > 0)
   {
      Ms_0 = Ms_0 + "During backtesting " + IntegerToString(Z_count_428) + " number of ticks was ";
      Ms_0 = Ms_0 + "skipped to simulate latency of up to " + IntegerToString(MaxExecution) + " ms";
      f0_3(Ms_0);
   }
   //--- Release indicator handles
   if (hMA_Low     != INVALID_HANDLE) { IndicatorRelease(hMA_Low);     hMA_Low     = INVALID_HANDLE; }
   if (hMA_High    != INVALID_HANDLE) { IndicatorRelease(hMA_High);    hMA_High    = INVALID_HANDLE; }
   if (hBands      != INVALID_HANDLE) { IndicatorRelease(hBands);      hBands      = INVALID_HANDLE; }
   if (hEnvelopes  != INVALID_HANDLE) { IndicatorRelease(hEnvelopes);  hEnvelopes  = INVALID_HANDLE; }
   f0_5();
   Print(Zs_320, " has been deinitialized!");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   if (!TerminalInfoInteger(TERMINAL_CONNECTED) || m_account.Login() == 0 ||
       Bars(Symbol(), PERIOD_CURRENT) <= 30)
      return;

   if (TerminalInfoInteger(TERMINAL_CONNECTED) && FilterByEvents)
   {
      CheckEvents(Reset);
      if (Reset) Reset = false;
   }

   mm_internal = mm;
   AUTOMM = mm_internal;
   f0_9();
   SetSLnTP();
}

//+------------------------------------------------------------------+
//| Main trading logic                                                |
//+------------------------------------------------------------------+
void f0_9()
{
   string Ms_unused_8;
   bool   bool_24 = false;
   int    Mi_32 = 0, Mi_36 = 0, Mi_40 = 0;
   ulong  ticket_52 = 0;
   int    Mi_88 = 0, Mi_92 = 0;
   double Md_128 = 0;
   double price_144, order_stoploss_152, order_takeprofit_160;
   double Md_184 = 0, Md_192 = 0, Md_200 = 0;
   double Md_208 = 0, Md_216 = 0, Md_224 = 0;
   double Md_232 = 0, Md_240 = 0, Md_248 = 0;
   double price_312, Md_344;

   datetime times[];
   ArraySetAsSeries(times, true);
   if (CopyTime(Symbol(), PERIOD_CURRENT, 0, 1, times) <= 0) return;

   if (Z_time_340 < times[0])
   {
      if (Zi_432 < 10) Zi_432++;
      Zd_496 += (Z_count_344 - Zd_496) / Zi_432;
      Z_time_340 = times[0];
      Z_count_344 = 0;
   }
   else Z_count_344++;

   if (MQLInfoInteger(MQL_TESTER) && MaxExecution != 0 && Zi_352 != -1)
   {
      Md_344 = MathRound(Zd_496 * MaxExecution / 60000.0);
      if (Z_count_428 >= Md_344)
      {
         Zi_352 = -1;
         Z_count_428 = 0;
      }
      else
      {
         Z_count_428++;
         return;
      }
   }

   double ask_96  = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double bid_104 = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double ihigh_168 = iHigh(Symbol(), PERIOD_M1, 0);
   double ilow_176  = iLow(Symbol(), PERIOD_M1, 0);
   double Md_280    = ihigh_168 - ilow_176;
   string Ms_16     = "";

   if (UseIndicatorSwitch == 1 || UseIndicatorSwitch == 4)
   {
      Md_184 = iMA_mql5(Symbol(), PERIOD_M1, Z_period_328, 0, MODE_LWMA, PRICE_LOW, 0);
      Md_192 = iMA_mql5(Symbol(), PERIOD_M1, Z_period_328, 0, MODE_LWMA, PRICE_HIGH, 0);
      if (Md_184 != 0 && Md_192 != 0)
      {
         Md_200 = Md_192 - Md_184;
         Mi_32  = (bid_104 >= Md_184 + Md_200 / 2.0) ? 1 : 0;
      }
      Ms_16  = "iMA_low: " + f0_6(Md_184) + ", iMA_high: " + f0_6(Md_192) + ", iMA_diff: " + f0_6(Md_200);
   }
   if (UseIndicatorSwitch == 2)
   {
      Md_208 = iBands_mql5(Symbol(), PERIOD_M1, Z_period_328, BBDeviation, 0, PRICE_OPEN, MODE_UPPER, 0);
      Md_216 = iBands_mql5(Symbol(), PERIOD_M1, Z_period_328, BBDeviation, 0, PRICE_OPEN, MODE_LOWER, 0);
      if (Md_208 != 0 && Md_216 != 0)
      {
         Md_224 = Md_208 - Md_216;
         Mi_36  = (bid_104 >= Md_216 + Md_224 / 2.0) ? 1 : 0;
      }
      Ms_16  = "iBands_upper: " + f0_6(Md_216) + ", iBands_lower: " + f0_6(Md_216) + ", iBands_diff: " + f0_6(Md_224);
   }
   if (UseIndicatorSwitch == 3)
   {
      Md_232 = iEnvelopes_mql5(Symbol(), PERIOD_M1, Z_period_328, MODE_LWMA, 0, PRICE_OPEN, EnvelopesDeviation, MODE_UPPER, 0);
      Md_240 = iEnvelopes_mql5(Symbol(), PERIOD_M1, Z_period_328, MODE_LWMA, 0, PRICE_OPEN, EnvelopesDeviation, MODE_LOWER, 0);
      if (Md_232 != 0 && Md_240 != 0)
      {
         Md_248 = Md_232 - Md_240;
         Mi_40  = (bid_104 >= Md_240 + Md_248 / 2.0) ? 1 : 0;
      }
      Ms_16  = "iEnvelopes_upper: " + f0_6(Md_232) + ", iEnvelopes_lower: " + f0_6(Md_240) + ", iEnvelopes_diff: " + f0_6(Md_248);
   }

   bool Mi_48 = false;
   int  Mi_72 = 0;
   if (UseIndicatorSwitch == 1)
   {
      Zd_448 = Md_192;
      Zd_456 = Md_184;
      if (Mi_32 == 1) Mi_48 = true;
   }
   else if (UseIndicatorSwitch == 2)
   {
      Zd_448 = Md_208;
      Zd_456 = Md_216;
      if (Mi_36 == 1) Mi_48 = true;
   }
   else if (UseIndicatorSwitch == 3)
   {
      Zd_448 = Md_232;
      Zd_456 = Md_240;
      if (Mi_40 == 1) Mi_48 = true;
   }

   double Md_288 = ask_96 - bid_104;
   datetime datetime_56 = TimeCurrent() + OrderExpireSeconds;

   Z_lots_440 = f0_11();

   ArrayCopy(Zda_436, Zda_436, 0, 1, 29);
   Zda_436[29] = Md_288;
   if (Zi_348 < 30) Zi_348++;

   double Md_320 = 0;
   int pos_64 = 29;
   for (int count_68 = 0; count_68 < Zi_348; count_68++)
   {
      Md_320 += Zda_436[pos_64];
      pos_64--;
   }
   double Md_296 = (Zi_348 > 0) ? Md_320 / Zi_348 : 0;
   double Md_328 = f0_12(ask_96 + Commission);
   double Md_336 = f0_12(bid_104 - Commission);
   double Md_304 = Md_296 + Commission;

   if (mm_internal == true) VolatilityLimit = Md_304 * VolatilityMultiplier;

   if (Md_280 != 0 && VolatilityLimit != 0 && Zd_456 != 0 && Zd_448 != 0 && UseIndicatorSwitch != 4)
   {
      if (Md_280 > VolatilityLimit)
      {
         Md_128 = Md_280 / VolatilityLimit;
         if (UseVolatilityPercentage == false ||
            (UseVolatilityPercentage == true && Md_128 > VolatilityPercentageLimit))
         {
            // FIX #1: Corrected signal direction.
            // Price above upper band → BUY_STOP breakout (Mi_72 = -1)
            // Price below lower band → SELL_STOP breakout (Mi_72 = 1)
            if (bid_104 > Zd_448) Mi_72 = -1;
            else if (bid_104 < Zd_456) Mi_72 = 1;
         }
      }
      else Md_128 = 0;
   }

   if (m_account.Balance() <= 0.0)
   {
      Comment("ERROR -- Account Balance is " + DoubleToString(MathRound(m_account.Balance()), 0));
      return;
   }

   //--- Cooldown check
   if (cooldownUntil > 0 && TimeCurrent() < cooldownUntil)
   {
      Comment("ASSARV10 - Cooldown active: " + IntegerToString((int)((cooldownUntil - TimeCurrent()) / 60)) + " min remaining");
      if (Debug || Verbose) Print("Cooldown active until ", TimeToString(cooldownUntil));
      ManagePositionsOnly();
      return;
   }
   if (cooldownUntil > 0 && TimeCurrent() >= cooldownUntil)
   {
      cooldownUntil = 0;
      consecutiveLosses = 0;
      COMMENT = "ASSARV10 support@assarofficial.com";
      if (Debug || Verbose) Print("Cooldown ended. Resuming trading.");
   }

   Zi_352 = -1;
   int count_76 = 0;

   //--- Count existing positions and clean up stale pending orders
   for (pos_64 = 0; pos_64 < PositionsTotal(); pos_64++)
   {
      if (m_position.SelectByIndex(pos_64))
      {
         if (m_position.Magic() == Expert_Id && m_position.Symbol() == Symbol())
         {
            if (m_position.PositionType() == POSITION_TYPE_BUY ||
                m_position.PositionType() == POSITION_TYPE_SELL)
               count_76++;
         }
      }
   }

   //--- Handle pending orders
   if (!Mi_48)
   {
      for (pos_64 = 0; pos_64 < OrdersTotal(); pos_64++)
      {
         if (m_order.SelectByIndex(pos_64))
         {
            if (m_order.Magic() == Expert_Id && m_order.Symbol() == Symbol())
            {
               if (m_order.OrderType() == ORDER_TYPE_BUY_STOP)
               {
                  m_trade.OrderDelete(m_order.Ticket());
               }
            }
         }
      }
   }
   else
   {
      for (pos_64 = 0; pos_64 < OrdersTotal(); pos_64++)
      {
         if (m_order.SelectByIndex(pos_64))
         {
            if (m_order.Magic() == Expert_Id && m_order.Symbol() == Symbol())
            {
               if (m_order.OrderType() == ORDER_TYPE_SELL_STOP)
               {
                  m_trade.OrderDelete(m_order.Ticket());
               }
            }
         }
      }
   }

   if (Zi_336 >= 0 || Zi_336 == -2)
   {
      Mi_92 = (int)NormalizeDouble(bid_104 / m_symbol.Point(), 0);
      Mi_88 = (int)NormalizeDouble(ask_96 / m_symbol.Point(), 0);
      if (Mi_92 % 10 != 0 || Mi_88 % 10 != 0) Zi_336 = -1;
      else
      {
         if (Zi_336 >= 0 && Zi_336 < 10) Zi_336++;
         else Zi_336 = -2;
      }
   }

   int Mi_unused_28 = 0;
   if (Mi_72 != 0 && MaxExecution > 0 && Zi_356 > MaxExecution)
   {
      Mi_72 = 0;
      if (Debug || Verbose) Print("Server is too Slow. Average Execution: " + IntegerToString(Zi_356));
   }

   // FIX #3: Compute a safe minimum gap. SYMBOL_TRADE_STOPS_LEVEL may return 0 at API level,
   // so enforce a hard floor of 50 points.
   double apiStopLevel = (double)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
   double stopLvl = (apiStopLevel <= 0) ? 50.0 : apiStopLevel;
   double stopLvlPrice = stopLvl * m_symbol.Point();
   double safeGap = MathMax(Zd_464, stopLvlPrice);

   double Md_112 = ask_96  + safeGap;   // BUY_STOP fallback price
   double Md_120 = bid_104 - safeGap;   // SELL_STOP fallback price
   string event;

   double point = m_symbol.Point();

   // FIX #4: Spread check — compare raw point-based spread against MaxSpread in points,
   // not multiplied by point again (avoids double-scaling on 5-digit brokers).
   double spreadInPoints = (ask_96 - bid_104) / point;
   bool   spreadOk       = DisableSpreadCheck || (spreadInPoints <= (double)MaxSpread);

   if (count_76 == 0 && Mi_72 != 0 && spreadOk && Zi_336 == -1)
   {
      if ((Mi_72 == -1 || Mi_72 == 2) && !IsAnyEventAround(TimeGMT(), event))
      {
          double liveAsk  = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
          price_144 = NormalizeDouble(liveAsk + safeGap, Z_digits_332);
          double order_sl = NormalizeDouble(liveAsk - stopLvlPrice, Z_digits_332);
          double order_tp = NormalizeDouble(price_144 + stopLvlPrice, Z_digits_332);
          if (Debug || Verbose) Print("BUY_STOP price=" + DoubleToString(price_144, Z_digits_332) + " sl=" + DoubleToString(order_sl, Z_digits_332) + " tp=" + DoubleToString(order_tp, Z_digits_332) + " ask=" + f0_6(liveAsk) + " stopLvl=" + DoubleToString(stopLvl,0));
         MqlTradeRequest req = {};
         MqlTradeResult  res = {};
         req.action      = TRADE_ACTION_PENDING;
         req.symbol      = Symbol();
         req.volume      = Z_lots_440;
         req.price       = price_144;
         req.sl          = order_sl;
         req.tp          = order_tp;
         req.type        = ORDER_TYPE_BUY_STOP;
         req.magic       = Expert_Id;
         req.comment     = COMMENT;
         Zi_352 = (int)GetTickCount();
         if (OrderSend(req, res))
         {
            ticket_52 = res.order;
            Zi_352 = (int)GetTickCount() - Zi_352;
            if (Debug || Verbose) Print("BUY_STOP retcode=" + IntegerToString(res.retcode) + " ticket=" + IntegerToString(ticket_52) + " in " + IntegerToString(Zi_352) + " ms");
            if (res.retcode == TRADE_RETCODE_DONE && ticket_52 > 0)
            {
               if (TakeShots && (!MQLInfoInteger(MQL_TESTER))) f0_8();
               if (SLnTPMode != Client && OrderSelect(ticket_52))
               {
                  double ap = OrderGetDouble(ORDER_PRICE_OPEN);
                  order_stoploss_152 = f0_12(ap - Md_288 - StopLoss * point - AddPriceGap);
                  order_takeprofit_160 = f0_12(ap + TakeProfit * point + AddPriceGap);
                  bool_24 = m_trade.OrderModify(ticket_52, ap, order_stoploss_152, order_takeprofit_160, ORDER_TIME_GTC, 0);
               }
            }
            else
            {
               Mi_unused_28 = 1;
               Zi_352 = -1;
               f0_0();
            }
         }
         else
         {
            Mi_unused_28 = 1;
            Zi_352 = -1;
            f0_0();
         }
      }

      if ((Mi_72 == 1 || Mi_72 == 2) && !IsAnyEventAround(TimeGMT(), event))
      {
          double liveBid  = SymbolInfoDouble(Symbol(), SYMBOL_BID);
          price_144 = NormalizeDouble(liveBid - safeGap, Z_digits_332);
          double order_sl = NormalizeDouble(liveBid + stopLvlPrice, Z_digits_332);
          double order_tp = NormalizeDouble(price_144 - stopLvlPrice, Z_digits_332);
          if (Debug || Verbose) Print("SELL_STOP price=" + DoubleToString(price_144, Z_digits_332) + " sl=" + DoubleToString(order_sl, Z_digits_332) + " tp=" + DoubleToString(order_tp, Z_digits_332) + " bid=" + f0_6(liveBid) + " stopLvl=" + DoubleToString(stopLvl,0));
         MqlTradeRequest req = {};
         MqlTradeResult  res = {};
         req.action      = TRADE_ACTION_PENDING;
         req.symbol      = Symbol();
         req.volume      = Z_lots_440;
         req.price       = price_144;
         req.sl          = order_sl;
         req.tp          = order_tp;
         req.type        = ORDER_TYPE_SELL_STOP;
         req.magic       = Expert_Id;
         req.comment     = COMMENT;
         Zi_352 = (int)GetTickCount();
         if (OrderSend(req, res))
         {
            ticket_52 = res.order;
            Zi_352 = (int)GetTickCount() - Zi_352;
            if (Debug || Verbose) Print("SELL_STOP retcode=" + IntegerToString(res.retcode) + " ticket=" + IntegerToString(ticket_52) + " in " + IntegerToString(Zi_352) + " ms");
            if (res.retcode == TRADE_RETCODE_DONE && ticket_52 > 0)
            {
               if (TakeShots && (!MQLInfoInteger(MQL_TESTER))) f0_8();
               if (SLnTPMode != Client && OrderSelect(ticket_52))
               {
                  double ap = OrderGetDouble(ORDER_PRICE_OPEN);
                  order_stoploss_152 = f0_12(ap + Md_288 + StopLoss * point + AddPriceGap);
                  order_takeprofit_160 = f0_12(ap - TakeProfit * point - AddPriceGap);
                  bool_24 = m_trade.OrderModify(ticket_52, ap, order_stoploss_152, order_takeprofit_160, ORDER_TIME_GTC, 0);
               }
            }
            else
            {
               Mi_unused_28 = 1;
               Zi_352 = -1;
               f0_0();
            }
         }
         else
         {
            Mi_unused_28 = 1;
            Zi_352 = -1;
            f0_0();
         }
      }
   }

   if (MaxExecution != 0 && Zi_352 == -1 &&
       (TimeLocal() - Z_datetime_364) % MaxExecutionMinutes == 0 &&
       !IsAnyEventAround(TimeGMT(), event))
   {
      if (MQLInfoInteger(MQL_TESTER) && MaxExecution != 0)
      {
         MathSrand((uint)TimeLocal());
         Zi_352 = (int)(MathRand() / (32767.0 / (double)MaxExecution));
      }
      else
      {
         price_312 = 2.0 * ask_96;
         MqlTradeRequest req = {};
         MqlTradeResult  res = {};
         req.action    = TRADE_ACTION_PENDING;
         req.symbol    = Symbol();
         req.volume    = Z_lots_440;
         req.price     = price_312;
         req.type      = ORDER_TYPE_BUY_STOP;
         req.deviation = Slippage;
         req.magic     = Expert_Id;
         req.comment   = COMMENT;

          Zi_352 = (int)GetTickCount();
          bool sent1 = OrderSend(req, res);
          ulong tmpTicket = res.order;

          req.action    = TRADE_ACTION_MODIFY;
          req.order     = tmpTicket;
          req.price     = price_312 + 10.0 * point;
          req.sl        = 0;
          req.tp        = 0;
          bool sent2 = OrderSend(req, res);
          Zi_352 = (int)GetTickCount() - Zi_352;

          req.action = TRADE_ACTION_REMOVE;
          req.order  = tmpTicket;
          bool sent3 = OrderSend(req, res);
      }
   }

   if (Zi_352 >= 0)
   {
      if (Zi_360 < 10) Zi_360++;
      Zi_356 += (Zi_352 - Zi_356) / Zi_360;
   }

   if (Zi_336 >= 0)
   {
      Comment("Robot is initializing...");
      return;
   }
   if (Zi_336 == -2)
   {
      Comment("ERROR -- Instrument " + Symbol() + " prices should have " +
              IntegerToString(Z_digits_332) + " fraction digits on broker account. Set EnableDigitCheck=false to skip.");
      return;
   }

   string Ms_0 = TimeToString(TimeCurrent()) + " Tick: " + f0_10(Z_count_344);
   if (Debug || Verbose)
   {
      Ms_0 = Ms_0 + "\n*** DEBUG MODE *** \nCurrency pair: " + Symbol() +
             ", Volatility: " + f0_6(Md_280) + ", VolatilityLimit: " + f0_6(VolatilityLimit) +
             ", VolatilityPercentage: " + f0_6(Md_128);
      Ms_0 = Ms_0 + "\nPriceDirection: " + StringSubstr("BUY NULLSELLBOTH", Mi_72 * 4 + 4, 4) +
             ", Expire: " + TimeToString(datetime_56, TIME_MINUTES) +
             ", Open orders: " + IntegerToString(count_76);
      Ms_0 = Ms_0 + "\nBid: " + f0_6(bid_104) + ", Ask: " + f0_6(ask_96) + ", " + Ms_16;
      Ms_0 = Ms_0 + "\nAvgSpread: " + f0_6(Md_296) + ", RealAvgSpread: " + f0_6(Md_304) +
             ", Commission: " + f0_6(Commission) + ", Lots: " + DoubleToString(Z_lots_440, 2) +
             ", Execution: " + IntegerToString(Zi_352) + " ms" +
             ", DisableSpreadCheck: " + (DisableSpreadCheck ? "ON" : "OFF") +
             ", EnableDigitCheck: " + (EnableDigitCheck ? "ON" : "OFF") +
             ", SpreadPts: " + DoubleToString(spreadInPoints, 1) + "/" + IntegerToString(MaxSpread);

      if (cooldownUntil > 0)
         Ms_0 = Ms_0 + "\nCOOLDOWN: " + IntegerToString((int)((cooldownUntil - TimeCurrent()) / 60)) + " min remaining";

      if (!spreadOk)
      {
         Ms_0 = Ms_0 + "\nThe current spread (" + DoubleToString(spreadInPoints, 1) + " pts) " +
                "is higher than MaxSpread (" + IntegerToString(MaxSpread) + " pts), no trading now!";
      }
      if (MaxExecution > 0 && Zi_356 > MaxExecution)
      {
         Ms_0 = Ms_0 + "\nThe current Avg Execution (" + IntegerToString(Zi_356) +
                ") is higher than what has been set as MaxExecution (" +
                IntegerToString(MaxExecution) + " ms), so no trading is allowed!";
      }
      Comment(Ms_0);
      f0_2(Ms_0);
   }
}

//+------------------------------------------------------------------+
//| Manage existing positions during cooldown (SL/TP/TS only)        |
//+------------------------------------------------------------------+
void ManagePositionsOnly()
{
   SetSLnTP();
}

//+------------------------------------------------------------------+
//| Utility: double to string with symbol digits                     |
//+------------------------------------------------------------------+
string f0_6(double Od_0)
{
   return (DoubleToString(Od_0, Z_digits_332));
}

//+------------------------------------------------------------------+
//| Utility: normalize double to symbol digits                       |
//+------------------------------------------------------------------+
double f0_12(double Od_0)
{
   return (NormalizeDouble(Od_0, Z_digits_332));
}

//+------------------------------------------------------------------+
//| Utility: integer to zero-padded string                           |
//+------------------------------------------------------------------+
string f0_10(int Oi_0)
{
   if (Oi_0 < 10)  return ("00" + IntegerToString(Oi_0));
   if (Oi_0 < 100) return ("0" + IntegerToString(Oi_0));
   return ("" + IntegerToString(Oi_0));
}

//+------------------------------------------------------------------+
//| Print multi-line string                                          |
//+------------------------------------------------------------------+
void f0_2(string Os_0)
{
   int Mi_8;
   int Mi_12 = -1;
   while (Mi_12 < StringLen(Os_0))
   {
      Mi_8 = Mi_12 + 1;
      Mi_12 = StringFind(Os_0, "\n", Mi_8);
      if (Mi_12 == -1)
      {
         Print(StringSubstr(Os_0, Mi_8));
         return;
      }
      Print(StringSubstr(Os_0, Mi_8, Mi_12 - Mi_8));
   }
}

//+------------------------------------------------------------------+
//| Generate expert ID from account + symbol                         |
//+------------------------------------------------------------------+
int f0_13()
{
   string Ms_0   = Symbol();
   int    str_len_8 = StringLen(Ms_0);
   int    Mi_12  = 0;
   for (int Mi_16 = 0; Mi_16 < str_len_8 - 1; Mi_16++)
      Mi_12 += (int)StringGetCharacter(Ms_0, Mi_16);
   Expert_Id = (int)m_account.Login() + Mi_12;
   return (0);
}

//+------------------------------------------------------------------+
//| Screenshot logic                                                  |
//+------------------------------------------------------------------+
void f0_8()
{
   int Mi_0;
   if (ShotsPerBar > 0) Mi_0 = (int)MathRound(60.0 * PeriodSeconds(PERIOD_CURRENT) / 60.0 / ShotsPerBar);
   else Mi_0 = PeriodSeconds(PERIOD_CURRENT) / 60;

   datetime times[];
   ArraySetAsSeries(times, true);
   CopyTime(Symbol(), PERIOD_CURRENT, 0, 2, times);

   MqlDateTime dt;
   TimeCurrent(dt);

   int Mi_4 = (int)MathFloor((TimeCurrent() - times[0]) / Mi_0);
   if (times[0] != Zi_504)
   {
      Zi_504 = times[0];
      Zi_508 = DelayTicks;
   }
   else if (Mi_4 > Zi_512) f0_1("i");
   Zi_512 = Mi_4;
   if (Zi_508 == 0) f0_1("");
   if (Zi_508 >= 0) Zi_508--;
}

//+------------------------------------------------------------------+
//| Zero-pad integer                                                  |
//+------------------------------------------------------------------+
string f0_7(int Oi_0, int Oi_4)
{
   string dbl2str_8 = IntegerToString(Oi_0);
   while (StringLen(dbl2str_8) < Oi_4)
      dbl2str_8 = "0" + dbl2str_8;
   return (dbl2str_8);
}

//+------------------------------------------------------------------+
//| Take screenshot                                                   |
//+------------------------------------------------------------------+
void f0_1(string Os_0 = "")
{
   Zi_516++;
   MqlDateTime dt;
   TimeCurrent(dt);
   string Ms_8 = "SnapShot" + Symbol() + IntegerToString(PeriodSeconds(PERIOD_CURRENT)/60) +
                 "\\" + IntegerToString(dt.year) + "-" + f0_7(dt.mon, 2) + "-" +
                 f0_7(dt.day, 2) + " " + f0_7(dt.hour, 2) + "_" + f0_7(dt.min, 2) +
                 "_" + f0_7(dt.sec, 2) + " " + IntegerToString(Zi_516) + Os_0 + ".gif";
   if (!ChartScreenShot(0, Ms_8, 640, 480))
      Print("ScreenShot error: ", GetLastError());
}

//+------------------------------------------------------------------+
//| Lot size calculation                                              |
//+------------------------------------------------------------------+
double f0_11()
{
   int    Mi_40   = 0;
   if (Z_lotstep_480 == 1.0) Mi_40 = 0;
   if (Z_lotstep_480 == 0.1) Mi_40 = 1;
   if (Z_lotstep_480 == 0.01) Mi_40 = 2;

   double Md_8      = m_account.Equity();
   if (Md_8 <= 0.0) Md_8 = m_account.Balance();
   if (Md_8 <= 0.0 || Z_marginrequired_488 <= 0.0 || Z_lotstep_480 <= 0.0) return (MinLots);
   double Md_24     = MathMin(MathFloor(0.98 * Md_8 / Z_marginrequired_488 / Z_lotstep_480) * Z_lotstep_480, MaxLots);
   double Md_32     = MinLots;
   double Md_ret_16 = MathMin(MathFloor(risk_internal / 102.0 * Md_8 / (StopLoss + AddPriceGap) / Z_lotstep_480) * Z_lotstep_480, MaxLots);
   Md_ret_16 = NormalizeDouble(Md_ret_16, Mi_40);

   string Ms_0 = "";
   if (AUTOMM == false)
   {
      Md_ret_16 = default_lot_internal;
      if (default_lot_internal > Md_24)
      {
         Md_ret_16 = Md_24;
         Ms_0 = "Note: Manual lotsize is too high. It has been recalculated to max allowed " + DoubleToString(Md_24, 2);
         Print(Ms_0);
         Comment(Ms_0);
         default_lot_internal = Md_24;
      }
      else if (default_lot_internal < Md_32) Md_ret_16 = Md_32;
   }
   return (Md_ret_16);
}

//+------------------------------------------------------------------+
//| Risk validation                                                   |
//+------------------------------------------------------------------+
double f0_4()
{
   double Md_8  = m_account.Equity();
   if (Md_8 <= 0.0) Md_8 = m_account.Balance();
   if (Md_8 <= 0.0) return (0.0);
   double Md_16 = (Z_marginrequired_488 > 0 && Z_lotstep_480 > 0) ? MathFloor(Md_8 / Z_marginrequired_488 / Z_lotstep_480) * Z_lotstep_480 : 0;
   double Md_40 = (Md_8 > 0) ? MathFloor(100.0 * (Md_16 * (Zd_464 + StopLoss) / Md_8) / 0.1) / 10.0 : 0;
   double Md_24 = MinLots;
   double Md_48 = (Md_8 > 0) ? MathRound(100.0 * (Md_24 * StopLoss / Md_8) / 0.1) / 10.0 : 0;
   string Ms_0 = "";

   if (AUTOMM == true)
   {
      if (risk_internal > Md_40)
      {
         Ms_0 = "Note: risk has manually been set to " + DoubleToString(risk_internal, 1) +
                " but cannot be higher than " + DoubleToString(Md_40, 1) +
                " according to the broker, StopLoss and Equity. Adjusted to " +
                DoubleToString(Md_40, 1) + "%";
         risk_internal = Md_40;
         f0_3(Ms_0);
      }
      if (risk_internal < Md_48)
      {
         Ms_0 = "Note: risk has manually been set to " + DoubleToString(risk_internal, 1) +
                " but cannot be lower than " + DoubleToString(Md_48, 1) +
                " according to the broker, StopLoss, AddPriceGap and Equity. Adjusted to " +
                DoubleToString(Md_48, 1) + "%";
         risk_internal = Md_48;
         f0_3(Ms_0);
      }
   }
   else
   {
      if (default_lot_internal < MinLots)
      {
         Ms_0 = "Manual lotsize " + DoubleToString(default_lot_internal, 2) +
                " cannot be less than " + DoubleToString(MinLots, 2) +
                ". Adjusted to " + DoubleToString(MinLots, 2);
         default_lot_internal = MinLots;
         f0_3(Ms_0);
      }
      if (default_lot_internal > MaxLots)
      {
         Ms_0 = "Manual lotsize " + DoubleToString(default_lot_internal, 2) +
                " cannot be greater than " + DoubleToString(MaxLots, 2) +
                ". Adjusted to " + DoubleToString(MinLots, 2);
         default_lot_internal = MaxLots;
         f0_3(Ms_0);
      }
      if (default_lot_internal > Md_16)
      {
         Ms_0 = "Manual lotsize " + DoubleToString(default_lot_internal, 2) +
                " cannot be greater than max allowed lotsize. Adjusted to " +
                DoubleToString(Md_16, 2);
         default_lot_internal = Md_16;
         f0_3(Ms_0);
      }
   }
   return (0.0);
}

//+------------------------------------------------------------------+
//| Print broker info                                                 |
//+------------------------------------------------------------------+
void f0_14()
{
   string Ms_0, Ms_8, Ms_16;

   int tradeMode = (int)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   int Mi_24 = (tradeMode == ACCOUNT_TRADE_MODE_DEMO ? 1 : 0) + (MQLInfoInteger(MQL_TESTER) ? 1 : 0);
   int Mi_28 = (int)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   int Mi_32 = (int)AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE);

   if (Mi_28 == 0) Ms_0 = "that floating profit/loss is not used for calculation.";
   else if (Mi_28 == 1) Ms_0 = "both floating profit and loss on open positions.";
   else if (Mi_28 == 2) Ms_0 = "only profitable values, where current loss on open positions are not included.";
   else if (Mi_28 == 3) Ms_0 = "only loss values are used for calculation, where current profitable open positions are not included.";

   if (Mi_32 == 0) Ms_8 = "percentage ratio between margin and equity.";
   else if (Mi_32 == 1) Ms_8 = "comparison of the free margin level to the absolute value.";

   if (AUTOMM == true) Ms_16 = " (automatically calculated lots).";
   else Ms_16 = " (fixed manual lots).";

   Print("Broker name: ", m_account.Company());
   Print("Broker server: ", m_account.Server());
   string acctType = (Mi_24 == 2) ? "Test" : ((Mi_24 == 1) ? "Demo" : "Real");
   Print("Account type: ", acctType);
   Print("Initial account balance: ", m_account.Balance(), " ", m_account.Currency());
   Print("Broker digits: ", Z_digits_332);
   Print("Broker stoplevel / freezelevel (max): ", Zd_464, " points.");
   Print("Broker stopout level: ", Zd_472, "%");
   Print("Broker Point: ", DoubleToString(m_symbol.Point(), Z_digits_332), " on ", m_account.Currency());
   Print("Broker account leverage in percentage: ", Z_leverage_368);
   Print("Broker credit value on the account: ", m_account.Credit());
   Print("Broker account margin: ", m_account.Margin());
   Print("Broker calculation of free margin allowed to open positions considers " + Ms_0);
   Print("Broker calculates stopout level as " + Ms_8);
   Print("Broker requires at least ", Z_marginrequired_488, " ", m_account.Currency(), " in margin for 1 lot.");
   Print("Broker set 1 lot to trade ", Zi_372, " ", m_account.Currency());
   Print("Broker minimum allowed lotsize: ", MinLots);
   Print("Broker maximum allowed lotsize: ", MaxLots);
   Print("Broker allow lots to be resized in ", Z_lotstep_480, " steps.");
   Print("risk: ", risk_internal, "%");
   Print("risk adjusted lotsize: ", DoubleToString(Z_lots_440, 2) + Ms_16);
}

//+------------------------------------------------------------------+
//| Print and comment                                                 |
//+------------------------------------------------------------------+
void f0_3(string Os_0)
{
   Print(Os_0);
   Comment(Os_0);
}

//+------------------------------------------------------------------+
//| Error counter                                                     |
//+------------------------------------------------------------------+
void f0_0()
{
   int error_0 = GetLastError();
   switch (error_0)
   {
      case 1:     Zi_376++; return;
      case 4:     Zi_380++; return;
      case 6:     Zi_384++; return;
      case 8:     Zi_388++; return;
      case 129:   Zi_392++; return;
      case 130:   Zi_396++; return;
      case 131:   Zi_400++; return;
      case 135:   Zi_404++; return;
      case 137:   Zi_408++; return;
      case 138:   Zi_412++; return;
      case 141:   Zi_416++; return;
      case 145:   Zi_420++; return;
      case 146:   Zi_424++; return;
   }
}

//+------------------------------------------------------------------+
//| Print error summary on deinit                                    |
//+------------------------------------------------------------------+
void f0_5()
{
   string Ms_0 = "Number of times the brokers server reported that ";
   if (Zi_376 > 0) f0_3(Ms_0 + "SL and TP was modified to existing values: " + IntegerToString(Zi_376));
   if (Zi_380 > 0) f0_3(Ms_0 + "it is busy: " + IntegerToString(Zi_380));
   if (Zi_384 > 0) f0_3(Ms_0 + "the connection is lost: " + IntegerToString(Zi_384));
   if (Zi_388 > 0) f0_3(Ms_0 + "there was too many requests: " + IntegerToString(Zi_388));
   if (Zi_392 > 0) f0_3(Ms_0 + "the price was invalid: " + IntegerToString(Zi_392));
   if (Zi_396 > 0) f0_3(Ms_0 + "invalid SL and/or TP: " + IntegerToString(Zi_396));
   if (Zi_400 > 0) f0_3(Ms_0 + "invalid lot size: " + IntegerToString(Zi_400));
   if (Zi_404 > 0) f0_3(Ms_0 + "the price has changed: " + IntegerToString(Zi_404));
   if (Zi_408 > 0) f0_3(Ms_0 + "the broker is busy: " + IntegerToString(Zi_408));
   if (Zi_412 > 0) f0_3(Ms_0 + "requotes: " + IntegerToString(Zi_412));
   if (Zi_416 > 0) f0_3(Ms_0 + "too many requests: " + IntegerToString(Zi_416));
   if (Zi_420 > 0) f0_3(Ms_0 + "modifying orders is denied: " + IntegerToString(Zi_420));
   if (Zi_424 > 0) f0_3(Ms_0 + "trade context is busy: " + IntegerToString(Zi_424));
}

//+------------------------------------------------------------------+
//| Lock Profit                                                       |
//+------------------------------------------------------------------+
bool LockProfit(int TiketOrder, int TargetPoints, int LockedPoints)
{
   if (TargetPoints == 0 || LockedPoints == 0) return false;

   if (!PositionSelectByTicket((ulong)TiketOrder)) return false;

   double ask    = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double bid    = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double point  = m_symbol.Point();
   int    digits = (int)m_symbol.Digits();

   double CurrentSL = 0;
   if (m_position.StopLoss() != 0)
      CurrentSL = m_position.StopLoss();
   else
      CurrentSL = m_position.PriceOpen();

   if (SLnTPMode == Client)
   {
      CurrentSL = GlobalVariableGet(gbl + IntegerToString(TiketOrder) + ".SL");
      if (CurrentSL == 0 && m_position.StopLoss() != 0)
         CurrentSL = m_position.StopLoss();
   }

   double PSL = 0;
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)m_position.PositionType();

   if (posType == POSITION_TYPE_BUY &&
       (bid - m_position.PriceOpen()) >= TargetPoints * point &&
       CurrentSL <= m_position.PriceOpen())
   {
      PSL = NormalizeDouble(m_position.PriceOpen() + (LockedPoints * point), digits);
   }
   else if (posType == POSITION_TYPE_SELL &&
            (m_position.PriceOpen() - ask) >= TargetPoints * point &&
            CurrentSL >= m_position.PriceOpen())
   {
      PSL = NormalizeDouble(m_position.PriceOpen() - (LockedPoints * point), digits);
   }
   else
      return false;

   Print(STR_OPTYPE[posType], " #", TiketOrder, " ProfitLock: OP=",
         m_position.PriceOpen(), " CSL=", CurrentSL, " PSL=", PSL,
         " LP=", LockedPoints);

   if (SLnTPMode == Server)
   {
      m_trade.PositionModify((ulong)TiketOrder, PSL, m_position.TakeProfit());
      return true;
   }
   else
   {
      GlobalVariableSet(gbl + IntegerToString(TiketOrder) + ".SL", PSL);
      return true;
   }
}

//+------------------------------------------------------------------+
//| Trailing Stop                                                     |
//+------------------------------------------------------------------+
bool RZ_TrailingStop(int TiketOrder, int JumlahPoin, int Step = 1,
                     ENUM_TRAILINGSTOP_METHOD Method = TS_STEP_DISTANCE)
{
   if (JumlahPoin == 0) return false;

   if (!PositionSelectByTicket((ulong)TiketOrder)) return false;

   double point  = m_symbol.Point();
   int    digits = (int)m_symbol.Digits();
   double ask    = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double bid    = SymbolInfoDouble(Symbol(), SYMBOL_BID);

   double CurrentSL = 0;
   if (m_position.StopLoss() != 0)
      CurrentSL = m_position.StopLoss();
   else
      CurrentSL = m_position.PriceOpen();

   double minstoplevel = m_symbol.StopsLevel();
   if (SLnTPMode == Client)
   {
      CurrentSL = GlobalVariableGet(gbl + IntegerToString(TiketOrder) + ".SL");
      if (CurrentSL == 0 && m_position.StopLoss() != 0)
         CurrentSL = m_position.StopLoss();
   }

   JumlahPoin = JumlahPoin + (int)minstoplevel;

   double TSL = 0;
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)m_position.PositionType();

   if (posType == POSITION_TYPE_BUY &&
       (bid - m_position.PriceOpen()) > JumlahPoin * point)
   {
      if (CurrentSL == 0 || CurrentSL < m_position.PriceOpen())
         CurrentSL = m_position.PriceOpen();

      if ((bid - CurrentSL) >= JumlahPoin * point)
      {
         switch (Method)
         {
            case TS_CLASSIC:
               TSL = NormalizeDouble(bid - (JumlahPoin * point), digits);
               break;
            case TS_STEP_DISTANCE:
               TSL = NormalizeDouble(bid - ((JumlahPoin - Step) * point), digits);
               break;
            case TS_STEP_BY_STEP:
               TSL = NormalizeDouble(CurrentSL + (Step * point), digits);
               break;
            default:
               TSL = 0;
         }
      }
      if (SLnTPMode == Client && TSL != 0 && TSL < CurrentSL) TSL = 0;
   }
   else if (posType == POSITION_TYPE_SELL &&
            (m_position.PriceOpen() - ask) > JumlahPoin * point)
   {
      if (CurrentSL == 0 || CurrentSL > m_position.PriceOpen())
         CurrentSL = m_position.PriceOpen();

      if ((CurrentSL - ask) >= JumlahPoin * point)
      {
         switch (Method)
         {
            case TS_CLASSIC:
               TSL = NormalizeDouble(ask + (JumlahPoin * point), digits);
               break;
            case TS_STEP_DISTANCE:
               TSL = NormalizeDouble(ask + ((JumlahPoin - Step) * point), digits);
               break;
            case TS_STEP_BY_STEP:
               TSL = NormalizeDouble(CurrentSL - (Step * point), digits);
               break;
            default:
               TSL = 0;
         }
      }
      if (SLnTPMode == Client && TSL != 0 && TSL > CurrentSL) TSL = 0;
   }

   if (TSL == 0) return false;

   Print(STR_OPTYPE[posType], " #", TiketOrder, " TrailingStop: OP=",
         m_position.PriceOpen(), " CSL=", CurrentSL, " TSL=", TSL,
         " TS=", JumlahPoin, " Step=", Step);

   bool res = false;
   if (SLnTPMode == Server)
   {
      res = m_trade.PositionModify((ulong)TiketOrder, TSL, m_position.TakeProfit());
   }
   else
   {
      GlobalVariableSet(gbl + IntegerToString(TiketOrder) + ".SL", TSL);
      res = true;
   }
   return res;
}

//+------------------------------------------------------------------+
//| Set SL, TP, trailing stop, lock profit, and cooldown tracking    |
//+------------------------------------------------------------------+
bool SetSLnTP()
{
   double SL, TP;
   SL = TP = 0.00;

   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (!m_position.SelectByIndex(i)) break;
      if (m_position.Symbol() != Symbol()) continue;
      if (m_position.Magic() != Expert_Id) continue;

      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)m_position.PositionType();
      if (posType != POSITION_TYPE_BUY && posType != POSITION_TYPE_SELL) continue;

      double point      = m_symbol.Point();
      double minstoplevel = m_symbol.StopsLevel();
      double ask        = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      double bid        = SymbolInfoDouble(Symbol(), SYMBOL_BID);
      int    digits     = (int)m_symbol.Digits();

      double sl = GlobalVariableGet(gbl + IntegerToString(m_position.Ticket()) + ".SL");

      double ClosePrice = 0;
      int    Points     = 0;
      color  CloseColor = clrNONE;

      if (posType == POSITION_TYPE_BUY)
      {
         CloseColor = clrBlue;
         ClosePrice = bid;
         Points     = (int)((ClosePrice - m_position.PriceOpen()) / point);
      }
      else if (posType == POSITION_TYPE_SELL)
      {
         CloseColor = clrRed;
         ClosePrice = ask;
         Points     = (int)((m_position.PriceOpen() - ClosePrice) / point);
      }

      //--- Client-side stop: close if price hits virtual SL
      if (SLnTPMode == Client && sl != 0)
      {
         if (posType == POSITION_TYPE_BUY &&
             NormalizeDouble(bid, digits) <= NormalizeDouble(sl, digits))
         {
            if (m_trade.PositionClose(m_position.Ticket(), Slippage))
            {
               if (inpEnableAlert)
                  Alert("Closed by Virtual SL #", IntegerToString(m_position.Ticket()),
                        " PL=", DoubleToString(m_position.Profit(), 2),
                        " Points=", IntegerToString(Points));

               if (m_position.Profit() < 0)
               {
                  consecutiveLosses++;
                  COMMENT = "ASSARV10 [L" + IntegerToString(consecutiveLosses) + "] support@assarofficial.com";
                  if (consecutiveLosses >= MaxConsecutiveLosses)
                  {
                     cooldownUntil = TimeCurrent() + CooldownMinutes * 60;
                     if (Verbose || Debug)
                        Print("Cooldown triggered. Consecutive losses: " +
                              IntegerToString(consecutiveLosses) +
                              ". Paused until ", TimeToString(cooldownUntil));
                  }
               }
               else
               {
                  if (consecutiveLosses > 0) consecutiveLosses = 0;
                  COMMENT = "ASSARV10 support@assarofficial.com";
               }
            }
            continue;
         }
         if (posType == POSITION_TYPE_SELL &&
             NormalizeDouble(ask, digits) >= NormalizeDouble(sl, digits))
         {
            if (m_trade.PositionClose(m_position.Ticket(), Slippage))
            {
               if (inpEnableAlert)
                  Alert("Closed by Virtual SL #", IntegerToString(m_position.Ticket()),
                        " PL=", DoubleToString(m_position.Profit(), 2),
                        " Points=", IntegerToString(Points));

               if (m_position.Profit() < 0)
               {
                  consecutiveLosses++;
                  COMMENT = "ASSARV10 [L" + IntegerToString(consecutiveLosses) + "] support@assarofficial.com";
                  if (consecutiveLosses >= MaxConsecutiveLosses)
                  {
                     cooldownUntil = TimeCurrent() + CooldownMinutes * 60;
                     if (Verbose || Debug)
                        Print("Cooldown triggered. Consecutive losses: " +
                              IntegerToString(consecutiveLosses) +
                              ". Paused until ", TimeToString(cooldownUntil));
                  }
               }
               else
               {
                  if (consecutiveLosses > 0) consecutiveLosses = 0;
                  COMMENT = "ASSARV10 support@assarofficial.com";
               }
            }
            continue;
         }
      }

      //--- Server-side SL/TP
      if (SLnTPMode == Server)
      {
         if (posType == POSITION_TYPE_BUY)
         {
            SL = (StopLoss > 0) ? NormalizeDouble(m_position.PriceOpen() - ((StopLoss + minstoplevel) * point), digits) : 0;
            TP = (TakeProfit > 0) ? NormalizeDouble(m_position.PriceOpen() + ((TakeProfit + minstoplevel) * point), digits) : 0;
         }
         else if (posType == POSITION_TYPE_SELL)
         {
            SL = (StopLoss > 0) ? NormalizeDouble(m_position.PriceOpen() + ((StopLoss + minstoplevel) * point), digits) : 0;
            TP = (TakeProfit > 0) ? NormalizeDouble(m_position.PriceOpen() - ((TakeProfit + minstoplevel) * point), digits) : 0;
         }

         if (m_position.StopLoss() == 0.0 && m_position.TakeProfit() == 0.0)
            m_trade.PositionModify(m_position.Ticket(), SL, TP);
         else if (m_position.TakeProfit() == 0.0)
            m_trade.PositionModify(m_position.Ticket(), m_position.StopLoss(), TP);
         else if (m_position.StopLoss() == 0.0)
            m_trade.PositionModify(m_position.Ticket(), SL, m_position.TakeProfit());
      }
      //--- Client-side SL/TP (virtual close)
      else if (SLnTPMode == Client)
      {
         if ((TakeProfit > 0 && Points >= TakeProfit) ||
             (StopLoss > 0 && Points <= -StopLoss))
         {
            if (m_trade.PositionClose(m_position.Ticket(), 3))
            {
               if (inpEnableAlert)
               {
                  if (m_position.Profit() > 0)
                     Alert("Closed by Virtual TP #", IntegerToString(m_position.Ticket()),
                           " Profit=", DoubleToString(m_position.Profit(), 2),
                           " Points=", IntegerToString(Points));
                  if (m_position.Profit() < 0)
                     Alert("Closed by Virtual SL #", IntegerToString(m_position.Ticket()),
                           " Loss=", DoubleToString(m_position.Profit(), 2),
                           " Points=", IntegerToString(Points));
               }

               if (m_position.Profit() < 0)
               {
                  consecutiveLosses++;
                  COMMENT = "ASSARV10 [L" + IntegerToString(consecutiveLosses) + "] support@assarofficial.com";
                  if (consecutiveLosses >= MaxConsecutiveLosses)
                  {
                     cooldownUntil = TimeCurrent() + CooldownMinutes * 60;
                     if (Verbose || Debug)
                        Print("Cooldown triggered. Consecutive losses: " +
                              IntegerToString(consecutiveLosses) +
                              ". Paused until ", TimeToString(cooldownUntil));
                  }
               }
               else
               {
                  if (consecutiveLosses > 0) consecutiveLosses = 0;
                  COMMENT = "ASSARV10 support@assarofficial.com";
               }
            }
         }
      }

      //--- Lock Profit + Trailing Stop
      if (LockProfitAfter > 0 && ProfitLock > 0 && Points >= LockProfitAfter)
      {
         if (Points <= LockProfitAfter + TrailingStop)
            LockProfit((int)m_position.Ticket(), LockProfitAfter, ProfitLock);
         else if (Points >= LockProfitAfter + TrailingStop)
            RZ_TrailingStop((int)m_position.Ticket(), TrailingStop, TrailingStep, TrailingStopMethod);
      }
      else if (LockProfitAfter == 0)
      {
         RZ_TrailingStop((int)m_position.Ticket(), TrailingStop, TrailingStep, TrailingStopMethod);
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| FOREX EVENTS MANAGER                                              |
//+------------------------------------------------------------------+
#define TITLE     0
#define COUNTRY   1
#define DATE      2
#define TIME      3
#define IMPACT    4
#define FORECAST  5
#define PREVIOUS  6
#define EVENTMAX 256

bool     SkipSameTimeNews   = false;
bool     EnableLogging      = false;
bool     SaveXmlFiles       = true;
bool     AllowWebUpdates    = true;
int      DebugLevel         = 5;
string   sUrl               = "https://www.forexfactory.com/ff_calendar_thisweek.xml";
int      logHandle          = -1;
string   sTags[7]           = {"<title>", "<country>", "<date>", "<time>", "<impact>", "<forecast>", "<previous>"};
string   eTags[7]           = {"</title>", "</country>", "</date>", "</time>", "</impact>", "</forecast>", "</previous>"};
string   mainData[EVENTMAX][7];
datetime mainDataGMT[EVENTMAX];
string   lines[];
color    colors[];
int      NewsCount;
string   checkCountries;

//+------------------------------------------------------------------+
bool IsAnyEventAround(datetime base, string &event)
{
   if (MQLInfoInteger(MQL_TESTER)) return (false);
   if (!FilterByEvents) return (false);

   datetime dt;
   for (int i = 0; i < NewsCount; i++)
   {
      dt = StringToTime(MakeDateTime(mainData[i][DATE], mainData[i][TIME]));
      if (mainData[i][IMPACT] == "Holiday" && base - dt < 24 * 60 * 60)
      {
         event = mainData[i][COUNTRY] + " - " + TimeToString(dt, TIME_DATE | TIME_SECONDS) +
                 " - " + mainData[i][TITLE];
         return (true);
      }
      if (dt >= base && dt - base <= BeforeEventsInMinutes * 60)
      {
         event = mainData[i][COUNTRY] + " - " + TimeToString(dt, TIME_DATE | TIME_SECONDS) +
                 " - " + mainData[i][TITLE];
         return (true);
      }
      else if (base >= dt && base - dt <= AfterEventsInMinutes * 60)
      {
         event = mainData[i][COUNTRY] + " - " + TimeToString(dt, TIME_DATE | TIME_SECONDS) +
                 " - " + mainData[i][TITLE];
         return (true);
      }
   }
   return (false);
}

//+------------------------------------------------------------------+
int CheckEvents(bool reset = false)
{
   static int newsIdx = 0;
   static datetime PrevReadTime = 0;
   if (reset) PrevReadTime = 0;

   if (!MQLInfoInteger(MQL_TESTER) &&
       (newsIdx == 0 || (TimeLocal() - PrevReadTime > 60 * 60)))
   {
      string sXMLData = ReadXMLFile();
      if (sXMLData == "") return (0);
      newsIdx = ParseXML(sXMLData);
      PrevReadTime = TimeLocal();
   }

   datetime Gmt = TimeGMT(), time = 0;
   ArrayResize(lines, 0);
   ArrayResize(colors, 0);
   NewsCount = newsIdx;

   int i;
   for (i = 0; i < newsIdx; i++)
   {
      if (mainData[i][IMPACT] == "Holiday") continue;
      time = StringToTime(MakeDateTime(mainData[i][DATE], mainData[i][TIME]));
      if (time > Gmt) break;
   }
   if (i == newsIdx) i = newsIdx - 5;
   i--;
   if (i < 0) i = 0;

   int index = -1;
   int dif   = (int)(TimeGMT() - TimeCurrent());
   int mod   = (int)MathMod(MathAbs(dif), 60);
   int add   = 0;
   if (mod != 0 && mod > 30)  add = (60 - mod);
   if (mod != 0 && mod < 30)  add = -mod;
   if (dif < 0)  dif = dif - add;
   else if (dif >= 0) dif = dif + add;
   Gmt = TimeGMT();

   for (; i < newsIdx; i++)
   {
      time = StringToTime(MakeDateTime(mainData[i][DATE], mainData[i][TIME]));
      if (Gmt > time && (Gmt - time) > AfterEventsInMinutes * 60) continue;
      if (Gmt < time && (time - Gmt) > BeforeEventsInMinutes * 60) continue;

      index++;
      ArrayResize(lines, index + 1);
      ArrayResize(colors, index + 1);
      lines[index] = mainData[i][COUNTRY] + ", " + mainData[i][TITLE] + ", ";
      if (time < Gmt)
         lines[index] = lines[index] + "-" + TimeToString(TimeCurrent() - (time - dif), TIME_SECONDS);
      else
         lines[index] = lines[index] + TimeToString(time - dif - TimeCurrent(), TIME_SECONDS);
      colors[index] = LowImpactColor;
      if (mainData[i][IMPACT] == "High")   colors[index] = HighImpactColor;
      else if (mainData[i][IMPACT] == "Medium") colors[index] = MediumImpactColor;
      else if (mainData[i][IMPACT] == "Low")    colors[index] = LowImpactColor;
      if (index == 4) break;
   }

   for (i = index; i >= 0; i--)
   {
      DrawLabel(lblEvent + IntegerToString(index - i), EventsAlertDispX,
                EventsAlertDispY * (index - i + 1), colors[i]);
      ObjectSetString(0, lblEvent + IntegerToString(index - i), OBJPROP_TEXT,
                      lines[i]);
      ObjectSetInteger(0, lblEvent + IntegerToString(index - i), OBJPROP_FONTSIZE,
                       EventLabelFontSize);
      ObjectSetString(0, lblEvent + IntegerToString(index - i), OBJPROP_FONT,
                      EventLabelFont);
   }

   if (index == -1)
   {
      index = 0;
      DrawLabel(lblEvent + IntegerToString(index), EventsAlertDispX,
                EventsAlertDispY * (index + 1), clrRed);
      ObjectSetString(0, lblEvent + IntegerToString(index), OBJPROP_TEXT,
                      "no events around!!!");
      ObjectSetInteger(0, lblEvent + IntegerToString(index), OBJPROP_FONTSIZE,
                       EventLabelFontSize);
      ObjectSetString(0, lblEvent + IntegerToString(index), OBJPROP_FONT,
                      EventLabelFont);
   }

   for (i = index + 1; i < 10; i++)
      if (ObjectFind(0, lblEvent + IntegerToString(i)) != -1)
         ObjectDelete(0, lblEvent + IntegerToString(i));

   return (1);
}

//+------------------------------------------------------------------+
void InitEvents()
{
   if (!EnableLogging) DebugLevel = 0;
   OpenLog("FFCal" + Symbol() + IntegerToString(PeriodSeconds(PERIOD_CURRENT)/60));
   lblEvent = lbl + "Event.";

   checkCountries = "";
   if (ReportAUD) checkCountries = checkCountries + ",AUD,";
   if (ReportCAD) checkCountries = checkCountries + ",CAD,";
   if (ReportCHF) checkCountries = checkCountries + ",CHF,";
   if (ReportCNY) checkCountries = checkCountries + ",CNY,";
   if (ReportEUR) checkCountries = checkCountries + ",EUR,";
   if (ReportGBP) checkCountries = checkCountries + ",GBP,";
   if (ReportJPY) checkCountries = checkCountries + ",JPY,";
   if (ReportNZD) checkCountries = checkCountries + ",NZD,";
   if (ReportUSD) checkCountries = checkCountries + ",USD,";
}

//+------------------------------------------------------------------+
void DeInitEvents()
{
   if (logHandle > 0) FileClose(logHandle);
   for (int i = 0; i < 10; i++)
      if (ObjectFind(0, lblEvent + IntegerToString(i)) != -1)
         ObjectDelete(0, lblEvent + IntegerToString(i));
}

//+------------------------------------------------------------------+
string GetXmlFileName()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   return (IntegerToString(dt.mon) + "-" + IntegerToString(dt.day) + "-" +
           IntegerToString(dt.year) + "-" + "FFCal.xml");
}

//+------------------------------------------------------------------+
int ParseXML(string sData)
{
   string pair  = Symbol();
   string cntry1 = StringSubstr(pair, 0, 3);
   string cntry2 = StringSubstr(pair, 3, 3);

   if (DebugLevel > 0) Print("cntry1 = ", cntry1, " cntry2 = ", cntry2);
   if (DebugLevel > 0) Log("Weekly calendar for " + pair + "\n\n");

   int newsIdx = 0;
   int BoEvent = 0;
   int begin, next, end;
   string PrevNewsTime = "";

   while (newsIdx < EVENTMAX)
   {
      BoEvent = StringFind(sData, "<event>", BoEvent);
      if (BoEvent == -1) break;

      BoEvent += 7;
      next = StringFind(sData, "</event>", BoEvent);
      if (next == -1) break;

      string myEvent = StringSubstr(sData, BoEvent, next - BoEvent);
      BoEvent = next;

      begin = 0;
      bool skip = false;
      for (int i = 0; i < 7; i++)
      {
         mainData[newsIdx][i] = "";
         next = StringFind(myEvent, sTags[i], begin);
         if (next == -1)
            continue;
         else
         {
            begin = next + StringLen(sTags[i]);
            end   = StringFind(myEvent, eTags[i], begin);
            if (end > begin && end != -1)
            {
               mainData[newsIdx][i] = StringSubstr(myEvent, begin, end - begin);
               if (StringSubstr(mainData[newsIdx][i], 0, 9) == "<![CDATA[")
               {
                  mainData[newsIdx][i] = StringSubstr(mainData[newsIdx][i], 9,
                                                       StringLen(mainData[newsIdx][i]) - 12);
               }
               if (StringSubstr(mainData[newsIdx][i], 0, 4) == "&lt;")
                  mainData[newsIdx][i] = "<" + StringSubstr(mainData[newsIdx][i], 4);
               if (StringSubstr(mainData[newsIdx][i], 0, 4) == "&gt;")
                  mainData[newsIdx][i] = ">" + StringSubstr(mainData[newsIdx][i], 4);
            }
         }
      }

      if (cntry1 != mainData[newsIdx][COUNTRY] &&
          cntry2 != mainData[newsIdx][COUNTRY] && (!ReportAllPairs))
         skip = true;
      if (StringFind(checkCountries, cntry1) == -1 &&
          StringFind(checkCountries, cntry2) == -1)
         skip = true;
      if (!IncludeHigh && mainData[newsIdx][IMPACT] == "High")
         skip = true;
      if (!IncludeMedium && mainData[newsIdx][IMPACT] == "Medium")
         skip = true;
      if (!IncludeLow && mainData[newsIdx][IMPACT] == "Low")
         skip = true;
      if (!IncludeHolidays && mainData[newsIdx][IMPACT] == "Holiday")
         skip = true;
      if (!IncludeSpeaks &&
          (StringFind(mainData[newsIdx][TITLE], "speaks") != -1 ||
           StringFind(mainData[newsIdx][TITLE], "Speaks") != -1))
         skip = true;

      if (mainData[newsIdx][IMPACT] == "Holiday")
         mainData[newsIdx][TIME] = "0:00am";

      if (mainData[newsIdx][TIME] == "All Day" ||
          mainData[newsIdx][TIME] == "Tentative" ||
          mainData[newsIdx][TIME] == "")
         skip = true;

      if (SkipSameTimeNews &&
          PrevNewsTime == mainData[newsIdx][DATE] + mainData[newsIdx][TIME])
         skip = true;

      PrevNewsTime = mainData[newsIdx][DATE] + mainData[newsIdx][TIME];

      if (!skip)
      {
         mainDataGMT[newsIdx] = StringToTime(MakeDateTime(mainData[newsIdx][DATE],
                                                           mainData[newsIdx][TIME]));
         if (DebugLevel > 0)
         {
            Log("FOREX FACTORY\nTitle: " + mainData[newsIdx][TITLE] +
                "\nCountry: " + mainData[newsIdx][COUNTRY] +
                "\nDate: " + mainData[newsIdx][DATE] +
                "\nTime: " + mainData[newsIdx][TIME] +
                "\nImpact: " + mainData[newsIdx][IMPACT] +
                "\nForecast: " + mainData[newsIdx][FORECAST] +
                "\nPrevious: " + mainData[newsIdx][PREVIOUS] + "\n\n");
         }
         newsIdx++;
      }
      else
      {
         mainData[newsIdx][TITLE] = "";
      }
   }

   return (newsIdx);
}

//+------------------------------------------------------------------+
string MakeDateTime(string strDate, string strTime)
{
   string strMonth = StringSubstr(strDate, 0, 2);
   string strDay   = StringSubstr(strDate, 3, 2);
   string strYear  = StringSubstr(strDate, 6, 4);

   int nTimeColonPos = StringFind(strTime, ":");
   string strHour   = StringSubstr(strTime, 0, nTimeColonPos);
   string strMinute = StringSubstr(strTime, nTimeColonPos + 1, 2);
   string strAM_PM  = StringSubstr(strTime, StringLen(strTime) - 2);

   int nHour24 = (int)StringToInteger(strHour);
   if ((strAM_PM == "pm" || strAM_PM == "PM") && nHour24 != 12)
      nHour24 += 12;
   if ((strAM_PM == "am" || strAM_PM == "AM") && nHour24 == 12)
      nHour24 = 0;

   strHour = IntegerToString(nHour24);
   if (nHour24 < 10) strHour = " 0" + strHour;
   else               strHour = " " + strHour;

   return (strYear + "." + strMonth + "." + strDay + strHour + ":" + strMinute);
}

//+------------------------------------------------------------------+
string ReadXMLFile()
{
   string tmpData = "";
   bool   NeedToGetFile = false;

   string xmlFileName = GetXmlFileName();
   int xmlHandle = FileOpen(xmlFileName, FILE_BIN | FILE_READ);

   if (xmlHandle >= 0)
   {
      if (FileSize(xmlHandle) < 70) NeedToGetFile = true;
      FileClose(xmlHandle);
   }
   else
   {
      NeedToGetFile = true;
   }

   if (AllowWebUpdates)
   {
      if (DebugLevel > 1)
         Print(DoubleToString(GlobalVariableGet("LastUpdateTime"), 0) +
               " " + IntegerToString(TimeLocal() - (int)GlobalVariableGet("LastUpdateTime")));

      if (NeedToGetFile ||
          GlobalVariableCheck("LastUpdateTime") == false ||
          (TimeLocal() - GlobalVariableGet("LastUpdateTime")) > 2 * 60 * 60)
      {
         if (DebugLevel > 1) Print("sUrl == ", sUrl);
         if (DebugLevel > 0) Print("Grabbing Web, url = ", sUrl);

         bool isOk = GrabWeb2(sUrl, tmpData);
         if (!isOk) return ("");

         if (DebugLevel > 0)
         {
            Print("Opening XML file...\n");
            Print(tmpData);
         }

         xmlHandle = FileOpen(xmlFileName, FILE_BIN | FILE_WRITE);
         if (xmlHandle < 0)
         {
            if (DebugLevel > 0)
               Print("Can't open new xml file, the last error is ", GetLastError());
            return ("");
         }
         FileWriteString(xmlHandle, tmpData, StringLen(tmpData));
         FileClose(xmlHandle);

         if (DebugLevel > 0) Print("Wrote XML file...\n");

         if (StringFind(tmpData, "</weeklyevents>", 0) > 0 ||
             StringFind(tmpData, "<event>", 0) > 0)
         {
            GlobalVariableSet("LastUpdateTime", TimeLocal());
         }
         else
         {
            Alert("FFCal Error - Web page download was not complete!");
            return ("");
         }
      }
   }

   if (tmpData != "") return (tmpData);

   xmlHandle = FileOpen(xmlFileName, FILE_BIN | FILE_READ);
   if (xmlHandle < 0)
   {
      Print("Can't open xml file: ", xmlFileName, ".  The last error is ", GetLastError());
      return ("");
   }
   if (DebugLevel > 0) Print("XML file open must be okay");

   tmpData = "";
   string buffer;
   while (!FileIsEnding(xmlHandle))
   {
      buffer = "";
      buffer = FileReadString(xmlHandle, 4096);
      tmpData = tmpData + buffer;
   }
   FileClose(xmlHandle);

   static string OLDxmlFileName = "";
   if (!SaveXmlFiles && AllowWebUpdates)
   {
      if (xmlFileName != OLDxmlFileName && OLDxmlFileName != "")
         FileDelete(OLDxmlFileName);
   }
   OLDxmlFileName = xmlFileName;

   return (tmpData);
}

//+------------------------------------------------------------------+
void DrawLabel(string name, int x, int y, color col)
{
   if (ObjectFind(0, name) == -1)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_CORNER, EventsAlertDispCorner);
      if (EventsAlertDispCorner == 0 || EventsAlertDispCorner == 2)
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
      else
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   }
   if (ObjectGetInteger(0, name, OBJPROP_COLOR) != col)
      ObjectSetInteger(0, name, OBJPROP_COLOR, col);
}

//+------------------------------------------------------------------+
bool GrabWeb2(string strUrl, string &strWebPage)
{
   string cookie = NULL, headers;
   char   post[], result[];
   int    res;
   ResetLastError();
   int timeout = 5000;

   res = WebRequest("GET", strUrl, cookie, NULL, timeout, post, 0, result, headers);
   if (res == -1)
   {
      Print("Error in WebRequest. Error code = ", GetLastError());
      Alert("Add the address \n" + strUrl +
            "\nin the list of allowed URLs in Tools -> Options -> Expert Advisors");
      return (false);
   }
   else
   {
      strWebPage = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      return (true);
   }
}

//+------------------------------------------------------------------+
void OpenLog(string strName)
{
   if (!EnableLogging) return;

   if (logHandle <= 0)
   {
      string strMonthPad = "";
      string strDayPad   = "";
      MqlDateTime mdt;
      TimeToStruct(TimeCurrent(), mdt);
      if (mdt.mon < 10) strMonthPad = "0";
      if (mdt.day < 10) strDayPad   = "0";

      string strFilename;
      StringConcatenate(strFilename, strName, "_", mdt.year, strMonthPad, mdt.mon,
                        strDayPad, mdt.day, "_log.txt");

      logHandle = FileOpen(strFilename, FILE_CSV | FILE_READ | FILE_WRITE);
      Print("logHandle =================================== ", logHandle);
   }
   if (logHandle > 0)
   {
      FileFlush(logHandle);
      FileSeek(logHandle, 0, SEEK_END);
   }
}

//+------------------------------------------------------------------+
void Log(string msg)
{
   if (!EnableLogging) return;
   if (logHandle <= 0) return;

   msg = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS) + " " + msg;
   FileWrite(logHandle, msg);
}
//+------------------------------------------------------------------+