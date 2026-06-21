//+------------------------------------------------------------------+
//                        BEGAJUL-Scalper V3.0                       |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\PositionInfo.mqh>

//----------------------- Input Parameters -------------------------------------------------

input string Configuration        = "==== Configuration ====";
input int    Magic                 = -1;
input string OrderCmt             ="BEGAJUL";
input bool   ECN_Mode             = false;
input bool   Debug                = false;
input bool   Verbose              = false;
input bool   VirtualPendingOrders = true;
input bool   VirtualStops         = true;

input string TradingSettings            = "==== Trade settings ====";
input double MaxSpread                  = 30.0;
input int    MaxExecution               = 0;
input int    MaxExecutionMinutes        = 5;
input double TakeProfit                 = 10.0;
input double StopLoss                   = 60.0;
input double TrailingStart              = 0;
input double Commission                 = 0;
input int    Slippage                   = 3;
input bool   UseDynamicVolatilityLimit  = true;
input double VolatilityMultiplier       = 125;
input double VolatilityLimit            = 180;
input bool   UseVolatilityPercentage    = true;
input double VolatilityPercentageLimit  = 60;
input bool   UseMovingAverage           = true;
input bool   UseBollingerBands          = true;
input double Deviation                  = 1.50;
input int    OrderExpireSeconds         = 3600;

input string Money_Management  = "==== Money Management ====";
input bool   MoneyManagement   = false;
input int    MaxPositions      = 1;
input double MinLots           = 0.01;
input double MaxLots           = 100.0;
input double Risk              = 2.0;
input double ManualLotsize     = 0.01;

input string Screen_Shooter = "==== Screen Shooter ====";
input bool   TakeShots      = false;
input int    DelayTicks     = 1;
input int    ShotsPerBar    = 1;

input string             _tmp50_           = " --- Virtual Orders: graphic ---";
input ENUM_BASE_CORNER   VOrdText_corner   = CORNER_RIGHT_UPPER;
input int                VOrdText_x        = 25;
input int                VOrdText_dx       = 60;
input int                VOrdText_y        = 20;
input int                VOrdText_dy       = 14;
input string             VOrdText_font     = "Arial";
input int                VOrdText_font_size= 8;
input color              VOrdText_font_color = clrGold;

//----------------------- Globals ----------------------------------------------------------

string ea_version = "BEGAJUL-Scalper V3.0";

int    indicatorperiod    = 3;
int    brokerdigits       = 0;
int    globalerror        = 0;
long   lasttime           = 0;
int    tickcounter        = 0;
int    upto30counter      = 0;
int    execution          = -1;
int    avg_execution      = 0;
int    execution_samples  = 0;
int    starttime;
int    leverage;
double lotbase;
int    err_busyserver;
int    err_lostconnection;
int    err_toomanyrequest;
int    err_invalidprice;
int    err_invalidstops;
int    err_invalidtradevolume;
int    err_pricechange;
int    err_brokerbuzy;
int    err_requotes;
int    err_toomanyrequests;
int    err_trademodifydenied;
int    err_tradecontextbuzy;

double array_spread[30];
double lotsize;
double highest;
double lowest;
double stoplevel;
double stopout;
double lotstep;
double marginforonelot;

int    skipedticks    = 0;
int    ticks_samples  = 0;
double avg_tickspermin = 0;

double vStopLoss;
double vTakeProfit;
double vManualLotsize;
double vRisk;
double vMinLots;
double vMaxLots;
double vVolatilityPercentageLimit;
double vVolatilityLimit;
double vVolatilityMultiplier;
double vCommission;
double vTrailingStart;
int    vMaxExecutionMinutes;
long   vMagic;

// Indicator handles
int    h_MA_Low  = INVALID_HANDLE;
int    h_MA_High = INVALID_HANDLE;
int    h_BB      = INVALID_HANDLE;

// Trade objects
CTrade      trade;
COrderInfo  orderInfo;
CPositionInfo posInfo;

//--- Virtual Orders Storage
#define VO_MAX 1000

int    a_N = 0;
ulong  a_tickets[VO_MAX];
int    a_type[VO_MAX];
string a_symbol[VO_MAX];
double a_volume[VO_MAX];
double a_open_price[VO_MAX];
double a_sl[VO_MAX];
double a_tp[VO_MAX];
long   a_magic[VO_MAX];
string a_comment[VO_MAX];
color  a_color[VO_MAX];

// *** FIX: flag untuk membedakan ticket virtual vs real ***
// true  = ticket adalah virtual number (belum ada posisi real)
// false = ticket adalah position ticket real dari broker
bool   a_is_virtual_ticket[VO_MAX];

ulong  g_next_virtual_ticket = 1000000000;

int    vo_sel_ind = -1;
string vo_prefix;

bool   g_has_active_order = false;

#define MODE_TRADES      0
#define SELECT_BY_POS    0
#define SELECT_BY_TICKET 1

//+------------------------------------------------------------------+
//| FIX UTAMA: Cari position ticket real berdasarkan magic + symbol  |
//| Digunakan setelah OrderSend untuk mendapatkan ticket yang valid  |
//+------------------------------------------------------------------+
ulong FindRealPositionTicket(string symbol, long magic)
{
   // Scan semua posisi terbuka
   for (int pi = 0; pi < PositionsTotal(); pi++)
   {
      string ps = PositionGetSymbol(pi);
      if (ps != symbol) continue;
      if ((long)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      return (ulong)PositionGetInteger(POSITION_TICKET);
   }
   return 0;
}

//+------------------------------------------------------------------+
//| FIX UTAMA: SelectByTicket yang aman untuk virtual vs real ticket |
//| Jika ticket adalah virtual, scan broker via magic+symbol         |
//+------------------------------------------------------------------+
bool SelectPositionSafe(int arr_idx)
{
   if (arr_idx < 0 || arr_idx >= a_N) return false;

   // Jika ticket sudah berupa real position ticket
   if (!a_is_virtual_ticket[arr_idx])
      return posInfo.SelectByTicket(a_tickets[arr_idx]);

   // Ticket masih virtual — coba cari posisi real via magic+symbol
   // Ini terjadi jika FindRealPositionTicket() gagal saat OrderSend
   ulong real_ticket = FindRealPositionTicket(a_symbol[arr_idx], a_magic[arr_idx]);
   if (real_ticket == 0) return false;

   // Update array dengan real ticket agar tidak perlu scan lagi
   a_tickets[arr_idx]            = real_ticket;
   a_is_virtual_ticket[arr_idx]  = false;
   Print("[SelectSafe] Resolved virtual ticket -> real ticket #", real_ticket);
   return posInfo.SelectByTicket(real_ticket);
}

//+------------------------------------------------------------------+
//| Cek apakah EA sudah punya posisi TERBUKA (bukan pending)        |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   // Cek posisi real di broker — ini SELALU akurat
   for (int i = 0; i < PositionsTotal(); i++)
   {
      string sym = PositionGetSymbol(i);
      if (sym != Symbol()) continue;
      if ((long)PositionGetInteger(POSITION_MAGIC) == vMagic)
         return true;
   }

   // Cek virtual array untuk BUY/SELL (posisi yang sudah tereksekusi)
   for (int i = 0; i < a_N; i++)
   {
      if (a_symbol[i] != Symbol()) continue;
      if (a_magic[i]  != vMagic)  continue;
      if (a_type[i] == ORDER_TYPE_BUY || a_type[i] == ORDER_TYPE_SELL)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Cek apakah EA sudah punya pending order (virtual maupun real)   |
//+------------------------------------------------------------------+
bool HasPendingOrder()
{
   for (int i = 0; i < a_N; i++)
   {
      if (a_symbol[i] != Symbol()) continue;
      if (a_magic[i]  != vMagic)  continue;
      if (a_type[i] == ORDER_TYPE_BUY_STOP  || a_type[i] == ORDER_TYPE_SELL_STOP ||
          a_type[i] == ORDER_TYPE_BUY_LIMIT || a_type[i] == ORDER_TYPE_SELL_LIMIT)
         return true;
   }

   for (int i = 0; i < OrdersTotal(); i++)
   {
      ulong otk = OrderGetTicket(i);
      if (otk == 0) continue;
      if (OrderGetString(ORDER_SYMBOL) != Symbol()) continue;
      if ((long)OrderGetInteger(ORDER_MAGIC) == vMagic)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Hitung semua order aktif (pending + open) milik EA ini          |
//+------------------------------------------------------------------+
int CountActiveOrders()
{
   int count = 0;

   if (VirtualPendingOrders || VirtualStops)
   {
      for (int i = 0; i < a_N; i++)
      {
         if (a_symbol[i] == Symbol() && a_magic[i] == vMagic)
            count++;
      }
   }
   else
   {
      for (int i = 0; i < PositionsTotal(); i++)
      {
         string sym = PositionGetSymbol(i);
         if (sym != Symbol()) continue;
         if ((long)PositionGetInteger(POSITION_MAGIC) == vMagic)
            count++;
      }
      for (int i = 0; i < OrdersTotal(); i++)
      {
         ulong otk = OrderGetTicket(i);
         if (otk == 0) continue;
         if (OrderGetString(ORDER_SYMBOL) != Symbol()) continue;
         if ((long)OrderGetInteger(ORDER_MAGIC) == vMagic)
            count++;
      }
   }

   return count;
}

//+------------------------------------------------------------------+
//| Sinkronkan array virtual dengan posisi & order real di broker    |
//+------------------------------------------------------------------+
void SyncVirtualFromReal()
{
   for (int pi = 0; pi < PositionsTotal(); pi++)
   {
      string pos_sym = PositionGetSymbol(pi);
      if (pos_sym != Symbol()) continue;
      if ((long)PositionGetInteger(POSITION_MAGIC) != (long)vMagic) continue;

      ulong ticket = PositionGetInteger(POSITION_TICKET);
      if (GetSAInd(ticket) >= 0) continue;
      if (a_N >= VO_MAX) break;

      a_tickets[a_N]              = ticket;
      a_is_virtual_ticket[a_N]    = false;  // ini real ticket
      a_type[a_N]                 = (int)PositionGetInteger(POSITION_TYPE);
      a_symbol[a_N]               = pos_sym;
      a_volume[a_N]               = PositionGetDouble(POSITION_VOLUME);
      a_open_price[a_N]           = PositionGetDouble(POSITION_PRICE_OPEN);
      a_sl[a_N]                   = PositionGetDouble(POSITION_SL);
      a_tp[a_N]                   = PositionGetDouble(POSITION_TP);
      a_magic[a_N]                = (long)PositionGetInteger(POSITION_MAGIC);
      a_comment[a_N]              = PositionGetString(POSITION_COMMENT);
      a_color[a_N]                = clrNONE;
      a_N++;
      Print("[BGJL] Sync posisi real ticket #", ticket, " -> virtual array");
   }

   for (int oi = 0; oi < OrdersTotal(); oi++)
   {
      ulong otk = OrderGetTicket(oi);
      if (otk == 0) continue;
      if (OrderGetString(ORDER_SYMBOL) != Symbol()) continue;
      if ((long)OrderGetInteger(ORDER_MAGIC) != (long)vMagic) continue;
      if (GetSAInd(otk) >= 0) continue;
      if (a_N >= VO_MAX) break;

      a_tickets[a_N]              = otk;
      a_is_virtual_ticket[a_N]    = false;  // ini real order ticket
      a_type[a_N]                 = (int)OrderGetInteger(ORDER_TYPE);
      a_symbol[a_N]               = Symbol();
      a_volume[a_N]               = OrderGetDouble(ORDER_VOLUME_CURRENT);
      a_open_price[a_N]           = OrderGetDouble(ORDER_PRICE_OPEN);
      a_sl[a_N]                   = OrderGetDouble(ORDER_SL);
      a_tp[a_N]                   = OrderGetDouble(ORDER_TP);
      a_magic[a_N]                = (long)OrderGetInteger(ORDER_MAGIC);
      a_comment[a_N]              = OrderGetString(ORDER_COMMENT);
      a_color[a_N]                = clrNONE;
      a_N++;
      Print("[BGJL] Sync pending order ticket #", otk, " -> virtual array");
   }

   if (a_N > 0)
   {
      g_has_active_order = true;
      Print("[BGJL] SyncVirtualFromReal selesai: ", a_N, " order/posisi dimuat");
   }
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   string prefix = MQLInfoString(MQL_PROGRAM_NAME) + "_";
   vo_prefix = prefix + "vo_";

   a_N = 0;

   vMagic = (long)Magic;
   if (vMagic < 0)
      sub_magicnumber();

   if (!MQLInfoInteger(MQL_TESTER))
   {
      LoadStops();
      SyncVirtualFromReal();
   }

   Print("====== Initialization of ", ea_version, " ======");

   starttime = (int)TimeLocal();
   globalerror = -1;

   brokerdigits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
   leverage     = (int)AccountInfoInteger(ACCOUNT_LEVERAGE);

   long freeze_level = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_FREEZE_LEVEL);
   long stops_level  = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
   long sl_raw       = MathMax(freeze_level, stops_level);

   stopout  = AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL);
   lotstep  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

   vStopLoss                = StopLoss;
   vTakeProfit              = TakeProfit;
   vManualLotsize           = ManualLotsize;
   vRisk                    = Risk;
   vMinLots                 = MinLots;
   vMaxLots                 = MaxLots;
   vVolatilityPercentageLimit = VolatilityPercentageLimit;
   vVolatilityLimit         = VolatilityLimit;
   vVolatilityMultiplier    = VolatilityMultiplier;
   vCommission              = Commission;
   vTrailingStart           = TrailingStart;
   vMaxExecutionMinutes     = MaxExecutionMinutes;

   stoplevel = (double)sl_raw * _Point;

   if (vStopLoss  < stoplevel / _Point) vStopLoss  = stoplevel / _Point;
   if (vTakeProfit < stoplevel / _Point) vTakeProfit = stoplevel / _Point;

   vVolatilityPercentageLimit = vVolatilityPercentageLimit / 100.0 + 1.0;
   vVolatilityMultiplier      = vVolatilityMultiplier / 10.0;
   ArrayInitialize(array_spread, 0);
   vVolatilityLimit = vVolatilityLimit * _Point;
   vCommission      = sub_normalizebrokerdigits(vCommission * _Point);
   vTrailingStart   = vTrailingStart * _Point;

   double minlot_broker = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double maxlot_broker = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   if (vMinLots < minlot_broker) vMinLots = minlot_broker;
   if (vMaxLots > maxlot_broker) vMaxLots = maxlot_broker;
   if (vMaxLots < vMinLots)      vMaxLots = vMinLots;

   marginforonelot = 0;
   if (!OrderCalcMargin(ORDER_TYPE_BUY, Symbol(), 1.0,
                   SymbolInfoDouble(Symbol(), SYMBOL_ASK),
                   marginforonelot) || marginforonelot <= 0.0)
   {
      Print("Warning: OrderCalcMargin failed atau margin=0, pakai fallback 1.0");
      marginforonelot = 1.0;
   }

   lotbase = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_CONTRACT_SIZE);

   sub_recalculatewrongrisk();
   lotsize = sub_calculatelotsize();

   if (MaxExecution > 0)
      vMaxExecutionMinutes = MaxExecution * 60;

   h_MA_Low  = iMA(Symbol(), PERIOD_M1, indicatorperiod, 0, MODE_LWMA, PRICE_LOW);
   h_MA_High = iMA(Symbol(), PERIOD_M1, indicatorperiod, 0, MODE_LWMA, PRICE_HIGH);
   h_BB      = iBands(Symbol(), PERIOD_M1, indicatorperiod, 0, Deviation, PRICE_OPEN);

   if (h_MA_Low == INVALID_HANDLE || h_MA_High == INVALID_HANDLE || h_BB == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create indicator handles!");
      return (INIT_FAILED);
   }

   trade.SetExpertMagicNumber((ulong)vMagic);
   trade.SetDeviationInPoints(Slippage * fpc());

   sub_printdetails();
   Print("========== Initialization complete! ===========\n");
   return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   sub_printsumofbrokererrors();
   if (h_MA_Low  != INVALID_HANDLE) IndicatorRelease(h_MA_Low);
   if (h_MA_High != INVALID_HANDLE) IndicatorRelease(h_MA_High);
   if (h_BB      != INVALID_HANDLE) IndicatorRelease(h_BB);

   for (int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string nm = ObjectName(0, i);
      if (StringFind(nm, vo_prefix) == 0)
         ObjectDelete(0, nm);
   }
   ChartRedraw(0);
   Print(ea_version, " has been deinitialized!");
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   bool bDraw = true;
   if (MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)) bDraw = false;
   if (MQLInfoInteger(MQL_OPTIMIZATION)) bDraw = false;

   if (VirtualPendingOrders)
      VO_CheckPendingOrders();

   VO_UpdatePOType();

   if (VirtualStops)
   {
      VO_CheckStops();
      VO_ClearStops();
   }

   int bars_m1 = Bars(Symbol(), PERIOD_M1);
   if (bars_m1 > indicatorperiod)
      sub_trade();
   else
      Print("Please wait until enough of bar data has been gathered!");

   if ((VirtualPendingOrders || VirtualStops) && bDraw)
   {
      VO_DrawStops();
      DrawVirtualLines();
   }
}

//+------------------------------------------------------------------+
//| Main trading subroutine                                          |
//+------------------------------------------------------------------+
void sub_trade()
{
   string local_textstring;
   bool   local_wasordermodified;
   bool   local_ordersenderror;
   bool   local_isbidgreaterthanima;
   bool   local_isbidgreaterthanibands;
   bool   local_isbidgreaterthanindy;

   ulong  local_orderticket;
   datetime local_orderexpiretime;
   int    local_loopcount2;
   int    local_loopcount1;
   int    local_pricedirection;
   int    local_counter1;
   int    local_counter2;
   int    local_askpart;
   int    local_bidpart;

   double local_ask;
   double local_bid;
   double local_askplusdistance;
   double local_bidminusdistance;
   double local_volatilitypercentage = 0.0;
   double local_orderstoploss;
   double local_ordertakeprofit;
   double local_tpadjust;
   double local_ihigh;
   double local_ilow;
   double local_imalow;
   double local_imahigh;
   double local_imadiff;
   double local_ibandsupper;
   double local_ibandslower;
   double local_ibandsdiff;
   double local_volatility;
   double local_spread;
   double local_avgspread;
   double local_realavgspread;
   double local_fakeprice;
   double local_sumofspreads;
   double local_askpluscommission;
   double local_bidminuscommission;
   double local_skipticks;

   //--- Tick counter
   datetime bar_time[];
   if (CopyTime(Symbol(), PERIOD_M1, 0, 1, bar_time) > 0)
   {
      if (lasttime < bar_time[0])
      {
         if (ticks_samples < 10) ticks_samples++;
         avg_tickspermin = avg_tickspermin + (tickcounter - avg_tickspermin) / ticks_samples;
         lasttime    = bar_time[0];
         tickcounter = 0;
      }
      else
         tickcounter++;
   }

   if (MQLInfoInteger(MQL_TESTER) && MaxExecution != 0 && execution != -1)
   {
      local_skipticks = MathRound(avg_tickspermin * MaxExecution / (60.0 * 1000.0));
      if (skipedticks >= (int)local_skipticks)
      {
         execution   = -1;
         skipedticks = 0;
      }
      else
      {
         skipedticks++;
         return;
      }
   }

   local_ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   local_bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);

   double hi_buf[1], lo_buf[1];
   CopyHigh(Symbol(), PERIOD_M1, 0, 1, hi_buf);
   CopyLow (Symbol(), PERIOD_M1, 0, 1, lo_buf);
   local_ihigh      = hi_buf[0];
   local_ilow       = lo_buf[0];
   local_volatility = local_ihigh - local_ilow;

   double ma_low_buf[1], ma_high_buf[1];
   CopyBuffer(h_MA_Low,  0, 0, 1, ma_low_buf);
   CopyBuffer(h_MA_High, 0, 0, 1, ma_high_buf);
   local_imalow  = ma_low_buf[0];
   local_imahigh = ma_high_buf[0];
   local_imadiff = local_imahigh - local_imalow;
   local_isbidgreaterthanima = (local_bid >= local_imalow + local_imadiff / 2.0);

   double bb_upper[1], bb_lower[1];
   CopyBuffer(h_BB, 1, 0, 1, bb_upper);
   CopyBuffer(h_BB, 2, 0, 1, bb_lower);
   local_ibandsupper = bb_upper[0];
   local_ibandslower = bb_lower[0];
   local_ibandsdiff  = local_ibandsupper - local_ibandslower;
   local_isbidgreaterthanibands = (local_bid >= local_ibandslower + local_ibandsdiff / 2.0);

   local_isbidgreaterthanindy = false;
   if (!UseMovingAverage && UseBollingerBands && local_isbidgreaterthanibands)
   {
      local_isbidgreaterthanindy = true;
      highest = local_ibandsupper;
      lowest  = local_ibandslower;
   }
   else if (UseMovingAverage && !UseBollingerBands && local_isbidgreaterthanima)
   {
      local_isbidgreaterthanindy = true;
      highest = local_imahigh;
      lowest  = local_imalow;
   }
   else if (UseMovingAverage && UseBollingerBands && local_isbidgreaterthanima && local_isbidgreaterthanibands)
   {
      local_isbidgreaterthanindy = true;
      highest = MathMax(local_ibandsupper, local_imahigh);
      lowest  = MathMin(local_ibandslower, local_imalow);
   }

   local_spread          = local_ask - local_bid;
   local_orderexpiretime = (datetime)(TimeCurrent() + OrderExpireSeconds);
   lotsize               = sub_calculatelotsize();

   ArrayCopy(array_spread, array_spread, 0, 1, 29);
   array_spread[29] = local_spread;
   if (upto30counter < 30) upto30counter++;
   local_sumofspreads = 0;
   local_loopcount2   = 29;
   for (local_loopcount1 = 0; local_loopcount1 < upto30counter; local_loopcount1++)
   {
      local_sumofspreads += array_spread[local_loopcount2];
      local_loopcount2--;
   }
   local_avgspread = local_sumofspreads / upto30counter;

   local_askpluscommission  = sub_normalizebrokerdigits(local_ask + vCommission);
   local_bidminuscommission = sub_normalizebrokerdigits(local_bid - vCommission);
   local_realavgspread      = local_avgspread + vCommission;

   if (UseDynamicVolatilityLimit)
      vVolatilityLimit = local_realavgspread * vVolatilityMultiplier;

   local_pricedirection = 0;

   if (local_volatility && vVolatilityLimit && lowest && highest)
   {
      if (local_volatility > vVolatilityLimit)
      {
         local_volatilitypercentage = local_volatility / vVolatilityLimit;
         if (!UseVolatilityPercentage || local_volatilitypercentage > vVolatilityPercentageLimit)
         {
            if (local_bid < lowest)       local_pricedirection = -1;
            else if (local_bid > highest) local_pricedirection =  1;
         }
      }
      else
         local_volatilitypercentage = 0;
   }

   if (AccountInfoDouble(ACCOUNT_BALANCE) <= 0.0)
   {
      Comment("ERROR -- Account Balance is " + DoubleToString(MathRound(AccountInfoDouble(ACCOUNT_BALANCE)), 0));
      return;
   }

   execution      = -1;
   local_counter2 = 0;

   local_counter1 = CountActiveOrders();
   g_has_active_order = (local_counter1 > 0);

   if (Debug && g_has_active_order)
      Print("[XMT] Ada ", local_counter1, " order/posisi aktif - skip entry baru");

   //--- Loop through virtual orders untuk trailing/modify
   for (local_loopcount2 = 0; local_loopcount2 < OrdersTotalEx(); local_loopcount2++)
   {
      if (!OrderSelectEx(local_loopcount2, SELECT_BY_POS, MODE_TRADES)) continue;

      if ((long)OrderMagicNumberEx() == vMagic)
      {
         if (OrderSymbolEx() != Symbol())
         {
            local_counter2++;
            continue;
         }

         int ord_type = OrderTypeEx();

         switch (ord_type)
         {
         case ORDER_TYPE_BUY:
            {
               local_orderstoploss   = OrderStopLossEx();
               local_ordertakeprofit = OrderTakeProfitEx();
               if (local_ordertakeprofit < sub_normalizebrokerdigits(local_askpluscommission + stoplevel) &&
                   local_askpluscommission + stoplevel - local_ordertakeprofit > vTrailingStart)
               {
                  local_orderstoploss   = sub_normalizebrokerdigits(local_bid - stoplevel);
                  local_ordertakeprofit = sub_normalizebrokerdigits(local_askpluscommission + stoplevel);
                  execution = (int)(GetTickCount64() & 0x7FFFFFFF);
                  local_wasordermodified = OrderModifyEx(OrderTicketEx(), 0,
                                                         local_orderstoploss,
                                                         local_ordertakeprofit,
                                                         local_orderexpiretime, clrLime);
                  if (local_wasordermodified)
                  {
                     execution = (int)(GetTickCount64() & 0x7FFFFFFF) - execution;
                     if (TakeShots && !MQLInfoInteger(MQL_TESTER)) sub_takesnapshot();
                  }
                  else
                  {
                     execution = -1;
                     sub_errormessages();
                  }
               }
            }
            break;

         case ORDER_TYPE_SELL:
            {
               local_orderstoploss   = OrderStopLossEx();
               local_ordertakeprofit = OrderTakeProfitEx();
               if (local_ordertakeprofit > sub_normalizebrokerdigits(local_bidminuscommission - stoplevel) &&
                   local_ordertakeprofit - local_bidminuscommission + stoplevel > vTrailingStart)
               {
                  local_orderstoploss   = sub_normalizebrokerdigits(local_ask + stoplevel);
                  local_ordertakeprofit = sub_normalizebrokerdigits(local_bidminuscommission - stoplevel);
                  execution = (int)(GetTickCount64() & 0x7FFFFFFF);
                  local_wasordermodified = OrderModifyEx(OrderTicketEx(), 0,
                                                         local_orderstoploss,
                                                         local_ordertakeprofit,
                                                         local_orderexpiretime, clrOrange);
                  if (local_wasordermodified)
                  {
                     execution = (int)(GetTickCount64() & 0x7FFFFFFF) - execution;
                     if (TakeShots && !MQLInfoInteger(MQL_TESTER)) sub_takesnapshot();
                  }
                  else
                  {
                     execution = -1;
                     sub_errormessages();
                  }
               }
            }
            break;

         case ORDER_TYPE_BUY_STOP:
            if (!local_isbidgreaterthanindy)
            {
               local_tpadjust = OrderTakeProfitEx() - OrderOpenPriceEx() - vCommission;
               if (sub_normalizebrokerdigits(local_ask + stoplevel) < OrderOpenPriceEx() &&
                   OrderOpenPriceEx() - local_ask - stoplevel > vTrailingStart)
               {
                  execution = (int)(GetTickCount64() & 0x7FFFFFFF);
                  local_wasordermodified = OrderModifyEx(OrderTicketEx(),
                     sub_normalizebrokerdigits(local_ask + stoplevel),
                     sub_normalizebrokerdigits(local_bid + stoplevel - local_tpadjust),
                     sub_normalizebrokerdigits(local_askpluscommission + stoplevel + local_tpadjust),
                     0, clrLime);
                  if (local_wasordermodified)
                  {
                     execution = (int)(GetTickCount64() & 0x7FFFFFFF) - execution;
                     if (Debug || Verbose) Print("Order executed in ", execution, " ms");
                  }
                  else { execution = -1; sub_errormessages(); }
               }
            }
            else
               OrderDeleteEx(OrderTicketEx());
            break;

         case ORDER_TYPE_SELL_STOP:
            if (local_isbidgreaterthanindy)
            {
               local_tpadjust = OrderOpenPriceEx() - OrderTakeProfitEx() - vCommission;
               if (sub_normalizebrokerdigits(local_bid - stoplevel) > OrderOpenPriceEx() &&
                   local_bid - stoplevel - OrderOpenPriceEx() > vTrailingStart)
               {
                  execution = (int)(GetTickCount64() & 0x7FFFFFFF);
                  local_wasordermodified = OrderModifyEx(OrderTicketEx(),
                     sub_normalizebrokerdigits(local_bid - stoplevel),
                     sub_normalizebrokerdigits(local_ask - stoplevel + local_tpadjust),
                     sub_normalizebrokerdigits(local_bidminuscommission - stoplevel - local_tpadjust),
                     0, clrOrange);
                  if (local_wasordermodified)
                  {
                     execution = (int)(GetTickCount64() & 0x7FFFFFFF) - execution;
                     if (Debug || Verbose) Print("Order executed in ", execution, " ms");
                  }
                  else { execution = -1; sub_errormessages(); }
               }
            }
            else
               OrderDeleteEx(OrderTicketEx());
            break;
         }
      }
   }

   if (globalerror >= 0 || globalerror == -2)
   {
      local_bidpart = (int)NormalizeDouble(local_bid / _Point, 0);
      local_askpart = (int)NormalizeDouble(local_ask / _Point, 0);
      if (local_bidpart % 10 != 0 || local_askpart % 10 != 0)
         globalerror = -1;
      else
      {
         if (globalerror >= 0 && globalerror < 10) globalerror++;
         else globalerror = -2;
      }
   }

   local_ordersenderror = false;

   if (local_pricedirection != 0 && MaxExecution > 0 && avg_execution > MaxExecution)
   {
      local_pricedirection = 0;
      if (Debug || Verbose)
         Print("Server is too Slow. Average Execution: ", avg_execution);
   }

   //--- Send new orders
   bool bHasOpen    = HasOpenPosition();
   bool bHasPending = HasPendingOrder();
   if (!bHasOpen && !bHasPending && local_pricedirection != 0 &&
       sub_normalizebrokerdigits(local_realavgspread) <= sub_normalizebrokerdigits(MaxSpread * _Point) &&
       globalerror == -1)
   {
      if (local_pricedirection < 0) // BUYSTOP
      {
         execution = (int)(GetTickCount64() & 0x7FFFFFFF);
         local_askplusdistance = local_ask + stoplevel;

         if (ECN_Mode)
         {
            local_orderticket = OrderSendEx(Symbol(), ORDER_TYPE_BUY_STOP, lotsize,
                                             local_askplusdistance, Slippage, 0, 0, OrderCmt,
                                             (long)vMagic, (datetime)0, clrLime);
            if (local_orderticket > 0)
            {
               execution = (int)(GetTickCount64() & 0x7FFFFFFF) - execution;
               if (Debug || Verbose) Print("Order executed in ", execution, " ms");
               PlaySound("news.wav");
               Print("BUYSTOP: ", sub_dbl2strbrokerdigits(local_ask + stoplevel),
                     " SL: ",  sub_dbl2strbrokerdigits(local_bid + stoplevel),
                     " TP: ",  sub_dbl2strbrokerdigits(local_askpluscommission + stoplevel));
               if (TakeShots && !MQLInfoInteger(MQL_TESTER)) sub_takesnapshot();

               local_wasordermodified = OrderModifyEx(local_orderticket,
                  local_askplusdistance,
                  local_askplusdistance - vStopLoss * _Point,
                  local_askplusdistance + vTakeProfit * _Point,
                  local_orderexpiretime, clrLime);
               if (local_wasordermodified)
               {
                  execution = (int)(GetTickCount64() & 0x7FFFFFFF) - execution;
                  if (Debug || Verbose) Print("Order executed in ", execution, " ms");
               }
               else { local_ordersenderror = true; execution = -1; sub_errormessages(); }
            }
            else { local_ordersenderror = true; execution = -1; sub_errormessages(); }
         }
         else
         {
            local_orderticket = OrderSendEx(Symbol(), ORDER_TYPE_BUY_STOP, lotsize,
               local_askplusdistance, Slippage,
               local_askplusdistance - vStopLoss * _Point,
               local_askplusdistance + vTakeProfit * _Point,
               OrderCmt, (long)vMagic, (datetime)local_orderexpiretime, clrLime);
            if (local_orderticket > 0)
            {
               execution = (int)(GetTickCount64() & 0x7FFFFFFF) - execution;
               if (Debug || Verbose) Print("Order executed in ", execution, " ms");
               PlaySound("news.wav");
               Print("BUYSTOP: ", sub_dbl2strbrokerdigits(local_ask + stoplevel),
                     " SL: ", sub_dbl2strbrokerdigits(local_bid + stoplevel),
                     " TP: ", sub_dbl2strbrokerdigits(local_askpluscommission + stoplevel));
               if (TakeShots && !MQLInfoInteger(MQL_TESTER)) sub_takesnapshot();
            }
            else { local_ordersenderror = true; execution = -1; sub_errormessages(); }
         }
      }
      else if (local_pricedirection > 0) // SELLSTOP
      {
         local_bidminusdistance = local_bid - stoplevel;
         execution = (int)(GetTickCount64() & 0x7FFFFFFF);

         if (ECN_Mode)
         {
            local_orderticket = OrderSendEx(Symbol(), ORDER_TYPE_SELL_STOP, lotsize,
               local_bidminusdistance, Slippage, 0, 0, OrderCmt, (long)vMagic, (datetime)0, clrOrange);
            local_wasordermodified = OrderModifyEx(local_orderticket,
               local_bidminusdistance,
               local_bidminusdistance + vStopLoss * _Point,
               local_bidminusdistance - vTakeProfit * _Point,
               local_orderexpiretime, clrOrange);
            if (local_wasordermodified)
            {
               execution = (int)(GetTickCount64() & 0x7FFFFFFF) - execution;
               if (Debug || Verbose) Print("Order executed in ", execution, " ms");
               PlaySound("news.wav");
               Print("SELLSTOP: ", sub_dbl2strbrokerdigits(local_bid - stoplevel),
                     " SL: ", sub_dbl2strbrokerdigits(local_ask - stoplevel),
                     " TP: ", sub_dbl2strbrokerdigits(local_bidminuscommission - stoplevel));
               if (TakeShots && !MQLInfoInteger(MQL_TESTER)) sub_takesnapshot();
            }
            else { local_ordersenderror = true; execution = -1; sub_errormessages(); }
         }
         else
         {
            local_orderticket = OrderSendEx(Symbol(), ORDER_TYPE_SELL_STOP, lotsize,
               local_bidminusdistance, Slippage,
               local_bidminusdistance + vStopLoss * _Point,
               local_bidminusdistance - vTakeProfit * _Point,
               OrderCmt, (long)vMagic, (datetime)local_orderexpiretime, clrOrange);
            if (local_orderticket > 0)
            {
               execution = (int)(GetTickCount64() & 0x7FFFFFFF) - execution;
               if (Debug || Verbose) Print("Order executed in ", execution, " ms");
               if (TakeShots && !MQLInfoInteger(MQL_TESTER)) sub_takesnapshot();
               PlaySound("news.wav");
               Print("SELLSTOP: ", sub_dbl2strbrokerdigits(local_bid - stoplevel),
                     " SL: ", sub_dbl2strbrokerdigits(local_ask - stoplevel),
                     " TP: ", sub_dbl2strbrokerdigits(local_bidminuscommission - stoplevel));
            }
            else { local_ordersenderror = true; execution = -1; sub_errormessages(); }
         }
      }
   }

   //--- Execution speed test
   if (MaxExecution != 0 && execution == -1 &&
       (int)(TimeLocal() - starttime) % vMaxExecutionMinutes == 0)
   {
      if (MQLInfoInteger(MQL_TESTER) && MaxExecution != 0)
      {
         MathSrand((int)TimeLocal());
         execution = MathRand() / (32767 / MaxExecution);
      }
      else if (!MQLInfoInteger(MQL_TESTER))
      {
         local_fakeprice   = local_ask * 2.0;
         local_orderticket = OrderSendEx(Symbol(), ORDER_TYPE_BUY_STOP, lotsize,
            local_fakeprice, Slippage, 0, 0, OrderCmt, (long)vMagic, (datetime)0, clrLime);
         execution = (int)(GetTickCount64() & 0x7FFFFFFF);
         OrderModifyEx(local_orderticket, local_fakeprice + 10 * _Point, 0, 0, 0, clrLime);
         execution = (int)(GetTickCount64() & 0x7FFFFFFF) - execution;
         OrderDeleteEx(local_orderticket);
      }
   }

   if (execution >= 0)
   {
      if (execution_samples < 10) execution_samples++;
      avg_execution = avg_execution + (execution - avg_execution) / execution_samples;
   }

   //--- Comment display
   if (globalerror >= 0)
      Comment("Robot is initializing...");
   else
   {
      if (globalerror == -2)
         Comment("ERROR -- Instrument " + Symbol() + " prices should have " + IntegerToString(brokerdigits) + " fraction digits on broker account");
      else
      {
         local_textstring = TimeToString(TimeCurrent()) + " Tick: " + sub_adjust00instring(tickcounter) +
                            " Ticks/min:" + DoubleToString(avg_tickspermin, 1);
         if (Debug || Verbose)
         {
            local_textstring += "\n*** DEBUG MODE *** \nCurrency pair: " + Symbol() +
               ", Volatility: "         + sub_dbl2strbrokerdigits(local_volatility) +
               ", vVolatilityLimit: "   + sub_dbl2strbrokerdigits(vVolatilityLimit) +
               ", VolatilityPercentage: " + sub_dbl2strbrokerdigits(local_volatilitypercentage);
            string dir_str = (local_pricedirection == -1) ? "BUY " :
                             (local_pricedirection ==  1) ? "SELL" : "NULL";
            local_textstring += "\nPriceDirection: " + dir_str +
               ", ImaHigh: "    + sub_dbl2strbrokerdigits(local_imahigh) +
               ", ImaLow: "     + sub_dbl2strbrokerdigits(local_imalow) +
               ", BBandUpper: " + sub_dbl2strbrokerdigits(local_ibandsupper) +
               ", BBandLower: " + sub_dbl2strbrokerdigits(local_ibandslower) +
               ", Expire: "     + TimeToString(local_orderexpiretime, TIME_MINUTES) +
               ", NumOrders: "  + IntegerToString(local_counter1) +
               ", HasOpen: "    + (bHasOpen    ? "YES" : "NO") +
               ", HasPending: " + (bHasPending ? "YES" : "NO");
            local_textstring += "\nTrailingLimit: " + sub_dbl2strbrokerdigits(stoplevel) +
               ", Stoplevel: "     + sub_dbl2strbrokerdigits(stoplevel) +
               ", TrailingStart: " + sub_dbl2strbrokerdigits(vTrailingStart);
         }
         local_textstring += "\nBid: " + sub_dbl2strbrokerdigits(local_bid) +
            ", ASK: "         + sub_dbl2strbrokerdigits(local_ask) +
            ", AvgSpread: "   + sub_dbl2strbrokerdigits(local_avgspread) +
            ", Commission: "  + sub_dbl2strbrokerdigits(vCommission) +
            ", RealAvgSpread: " + sub_dbl2strbrokerdigits(local_realavgspread) +
            ", Lots: "        + DoubleToString(lotsize, 5) +
            ", MinLots: "     + DoubleToString(vMinLots, 5) +
            ", Execution: "   + IntegerToString(execution) + " ms";
         if (sub_normalizebrokerdigits(local_realavgspread) > sub_normalizebrokerdigits(MaxSpread * _Point))
            local_textstring += "\nThe current spread (" + sub_dbl2strbrokerdigits(local_realavgspread) +
               ") is higher than MaxSpread (" + sub_dbl2strbrokerdigits(MaxSpread * _Point) + ") - no trading!";
         if (MaxExecution > 0 && avg_execution > MaxExecution)
            local_textstring += "\nAvg Execution (" + IntegerToString(avg_execution) +
               ") > MaxExecution (" + IntegerToString(MaxExecution) + " ms) - no trading!";

         Comment(local_textstring);
         if (local_counter1 != 0 || local_pricedirection != 0 || Verbose)
            sub_printformattedstring(local_textstring);
      }
   }
}

//+------------------------------------------------------------------+
//| Helper Functions                                                  |
//+------------------------------------------------------------------+
string sub_dbl2strbrokerdigits(double a)
{
   return DoubleToString(a, brokerdigits);
}

double sub_normalizebrokerdigits(double a)
{
   return NormalizeDouble(a, brokerdigits);
}

string sub_adjust00instring(int a)
{
   if (a < 10)  return "00" + IntegerToString(a);
   if (a < 100) return "0"  + IntegerToString(a);
   return IntegerToString(a);
}

void sub_printformattedstring(string a)
{
   int diff, pos = -1;
   while (pos < StringLen(a))
   {
      diff = pos + 1;
      pos  = StringFind(a, "\n", diff);
      if (pos == -1) { Print(StringSubstr(a, diff)); return; }
      Print(StringSubstr(a, diff, pos - diff));
   }
}

void sub_magicnumber()
{
   string pair    = Symbol();
   int    length  = StringLen(pair);
   int    asciisum = 0;
   for (int i = 0; i < length - 1; i++)
      asciisum += StringGetCharacter(pair, i);
   vMagic = (long)(AccountInfoInteger(ACCOUNT_LOGIN) + asciisum);
}

void sub_takesnapshot()
{
   static datetime local_lastbar = 0;
   static int      local_doshot  = -1;
   static int      local_oldphase = 3000000;
   int local_shotinterval;
   int local_phase;

   if (ShotsPerBar > 0)
      local_shotinterval = (int)MathRound((60.0 * PeriodSeconds()) / ShotsPerBar);
   else
      local_shotinterval = PeriodSeconds();

   datetime bar_time[];
   CopyTime(Symbol(), PERIOD_CURRENT, 0, 1, bar_time);
   local_phase = (int)MathFloor((double)(TimeCurrent() - bar_time[0]) / local_shotinterval);

   if (bar_time[0] != local_lastbar)
   {
      local_lastbar  = bar_time[0];
      local_doshot   = DelayTicks;
   }
   else if (local_phase > local_oldphase)
      sub_makescreenshot("i");

   local_oldphase = local_phase;
   if (local_doshot == 0) sub_makescreenshot("");
   if (local_doshot >= 0) local_doshot--;
}

string sub_maketimestring(int num, int digits)
{
   string result = IntegerToString(num);
   while (StringLen(result) < digits) result = "0" + result;
   return result;
}

void sub_makescreenshot(string sx = "")
{
   static int no = 0;
   no++;
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   string fn = "SnapShot" + Symbol() + IntegerToString(Period()) + "\\" +
               IntegerToString(t.year) + "-" + sub_maketimestring(t.mon, 2) + "-" + sub_maketimestring(t.day, 2) +
               " " + sub_maketimestring(t.hour, 2) + "_" + sub_maketimestring(t.min, 2) + "_" + sub_maketimestring(t.sec, 2) +
               " " + IntegerToString(no) + sx + ".gif";
   if (!ChartScreenShot(0, fn, 640, 480))
      Print("ScreenShot error: ", GetLastError());
}

double sub_calculatelotsize()
{
   double available = AccountInfoDouble(ACCOUNT_EQUITY);

   if (marginforonelot <= 0.0 || lotstep <= 0.0 || available <= 0.0)
      return vMinLots;

   double maxlot = MathFloor(available * 0.98 / marginforonelot / lotstep) * lotstep;
   double local_lotsize;

   if (!MoneyManagement)
   {
      local_lotsize = vManualLotsize;
      if (vManualLotsize > maxlot)
      {
         local_lotsize  = maxlot;
         vManualLotsize = maxlot;
         Print("Note: Manual lotsize is too high. Adjusted to ", DoubleToString(maxlot, 2));
      }
      else if (vManualLotsize < vMinLots)
         local_lotsize = vMinLots;
   }
   else
      local_lotsize = MathFloor(vRisk / 102.0 * available / vStopLoss / lotstep) * lotstep;

   if (local_lotsize < vMinLots)
      local_lotsize = vMinLots;

   return local_lotsize;
}

void sub_recalculatewrongrisk()
{
   double available  = AccountInfoDouble(ACCOUNT_EQUITY);
   double maxlot     = MathFloor(available / marginforonelot / lotstep) * lotstep;
   double maxrisk    = MathFloor(maxlot * vStopLoss / available * 100.0 / 0.1) * 0.1;
   double minlot     = vMinLots;
   double minrisk    = MathRound(minlot * vStopLoss / available * 100.0 / 0.1) * 0.1;

   if (MoneyManagement)
   {
      if (vRisk > maxrisk) { vRisk = maxrisk; Print("Risk adjusted to max: ", DoubleToString(maxrisk, 1)); }
      if (vRisk < minrisk) { vRisk = minrisk; Print("Risk adjusted to min: ", DoubleToString(minrisk, 1)); }
   }
   else
   {
      double broker_minlot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
      double broker_maxlot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
      double calc_maxlot   = MathFloor(available * 0.98 / marginforonelot / lotstep) * lotstep;

      if (vManualLotsize < vMinLots) { vManualLotsize = vMinLots; }
      if (vManualLotsize > vMaxLots) { vManualLotsize = vMaxLots; }
      if (vManualLotsize > calc_maxlot) { vManualLotsize = calc_maxlot; }
   }
}

void sub_printdetails()
{
   Print("Broker name: ",         AccountInfoString(ACCOUNT_COMPANY));
   Print("Broker server: ",       AccountInfoString(ACCOUNT_SERVER));
   Print("Account type: ",        EnumToString((ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE)));
   Print("Initial balance: ",     AccountInfoDouble(ACCOUNT_BALANCE), " ", AccountInfoString(ACCOUNT_CURRENCY));
   Print("Broker digits: ",       brokerdigits);
   Print("Broker stoplevel: ",    stoplevel / _Point, " pip (=", DoubleToString(stoplevel, 5), ")");
   Print("Broker stopout: ",      stopout, "%");
   Print("Broker Point: ",        DoubleToString(_Point, brokerdigits));
   Print("Leverage: ",            leverage);
   Print("Margin per lot: ",      marginforonelot, " ", AccountInfoString(ACCOUNT_CURRENCY));
   Print("Contract size: ",       lotbase, " ", AccountInfoString(ACCOUNT_CURRENCY));
   Print("MinLots: ",             vMinLots);
   Print("MaxLots: ",             vMaxLots);
   Print("LotStep: ",             lotstep);
   Print("Risk: ",                vRisk, "%");
   Print("Lotsize: ",             DoubleToString(lotsize, 2),
         MoneyManagement ? " (auto)" : " (manual)");
}

void sub_printandcomment(string txt) { Print(txt); Comment(txt); }

void sub_errormessages()
{
   int err = GetLastError();
   switch (err)
   {
      case 4:   err_busyserver++;         break;
      case 6:   err_lostconnection++;     break;
      case 8:   err_toomanyrequest++;     break;
      case 129: err_invalidprice++;       break;
      case 130: err_invalidstops++;       break;
      case 131: err_invalidtradevolume++; break;
      case 135: err_pricechange++;        break;
      case 137: err_brokerbuzy++;         break;
      case 138: err_requotes++;           break;
      case 141: err_toomanyrequests++;    break;
      case 145: err_trademodifydenied++;  break;
      case 146: err_tradecontextbuzy++;   break;
   }
}

void sub_printsumofbrokererrors()
{
   string t = "Number of times broker reported ";
   if (err_busyserver       > 0) Print(t + "server busy: ",            err_busyserver);
   if (err_lostconnection   > 0) Print(t + "connection lost: ",        err_lostconnection);
   if (err_toomanyrequest   > 0) Print(t + "too many requests: ",      err_toomanyrequest);
   if (err_invalidprice     > 0) Print(t + "invalid price: ",          err_invalidprice);
   if (err_invalidstops     > 0) Print(t + "invalid SL/TP: ",          err_invalidstops);
   if (err_invalidtradevolume>0) Print(t + "invalid lot size: ",       err_invalidtradevolume);
   if (err_pricechange      > 0) Print(t + "price changed: ",          err_pricechange);
   if (err_brokerbuzy       > 0) Print(t + "broker busy: ",            err_brokerbuzy);
   if (err_requotes         > 0) Print(t + "requotes: ",               err_requotes);
   if (err_toomanyrequests  > 0) Print(t + "too many requests: ",      err_toomanyrequests);
   if (err_trademodifydenied> 0) Print(t + "modify denied: ",          err_trademodifydenied);
   if (err_tradecontextbuzy > 0) Print(t + "trade context busy: ",     err_tradecontextbuzy);
}

//+------------------------------------------------------------------+
//| Virtual Order Layer                                               |
//+------------------------------------------------------------------+
int GetSAInd(ulong ticket)
{
   for (int i = 0; i < a_N; i++)
      if (a_tickets[i] == ticket) return i;
   return -1;
}

int OrdersTotalEx()
{
   if (!VirtualPendingOrders && !VirtualStops)
      return OrdersTotal();
   return a_N;
}

bool OrderSelectEx(int index, int select, int pool = MODE_TRADES)
{
   if (!VirtualPendingOrders && !VirtualStops)
   {
      if (select == SELECT_BY_POS)
      {
         ulong ticket = OrderGetTicket(index);
         return (ticket > 0);
      }
      return OrderSelect((ulong)index);
   }

   if (pool == MODE_TRADES)
   {
      if (select == SELECT_BY_POS)  { vo_sel_ind = index; return true; }
      if (select == SELECT_BY_TICKET)
      {
         vo_sel_ind = GetSAInd((ulong)index);
         return (vo_sel_ind >= 0);
      }
   }
   return false;
}

bool OrderDeleteEx(ulong ticket)
{
   if (!VirtualPendingOrders && !VirtualStops)
      return trade.OrderDelete(ticket);

   int ind = GetSAInd(ticket);
   if (ind >= 0) VOrderRemove(ind);
   return true;
}

ulong OrderTicketEx()
{
   if (!VirtualPendingOrders && !VirtualStops)
      return OrderGetTicket(vo_sel_ind);
   return a_tickets[vo_sel_ind];
}

int OrderTypeEx()
{
   if (!VirtualPendingOrders && !VirtualStops)
   {
      ulong tk = OrderGetTicket(vo_sel_ind);
      if (orderInfo.Select(tk)) return (int)orderInfo.OrderType();
      return -1;
   }
   return a_type[vo_sel_ind];
}

string OrderSymbolEx()
{
   if (!VirtualPendingOrders && !VirtualStops)
   {
      ulong tk = OrderGetTicket(vo_sel_ind);
      if (orderInfo.Select(tk)) return orderInfo.Symbol();
      return "";
   }
   return a_symbol[vo_sel_ind];
}

double OrderOpenPriceEx()
{
   if (!VirtualPendingOrders && !VirtualStops)
   {
      ulong tk = OrderGetTicket(vo_sel_ind);
      if (orderInfo.Select(tk)) return orderInfo.PriceOpen();
      return 0;
   }
   return a_open_price[vo_sel_ind];
}

double OrderStopLossEx()
{
   if (!VirtualPendingOrders && !VirtualStops)
   {
      ulong tk = OrderGetTicket(vo_sel_ind);
      if (orderInfo.Select(tk)) return orderInfo.StopLoss();
      return 0;
   }
   return a_sl[vo_sel_ind];
}

double OrderTakeProfitEx()
{
   if (!VirtualPendingOrders && !VirtualStops)
   {
      ulong tk = OrderGetTicket(vo_sel_ind);
      if (orderInfo.Select(tk)) return orderInfo.TakeProfit();
      return 0;
   }
   return a_tp[vo_sel_ind];
}

long OrderMagicNumberEx()
{
   if (!VirtualPendingOrders && !VirtualStops)
   {
      ulong tk = OrderGetTicket(vo_sel_ind);
      if (orderInfo.Select(tk)) return orderInfo.Magic();
      return -1;
   }
   return a_magic[vo_sel_ind];
}

void LoadStops()
{
   for (int i = 0; i < VO_MAX; i++)
   {
      string obj_name = vo_prefix + "ord" + IntegerToString(i);
      if (ObjectFind(0, obj_name) == -1) continue;

      string txt = ObjectGetString(0, obj_name, OBJPROP_TEXT);
      a_tickets[a_N]              = (ulong)StringToInteger(txt);
      a_is_virtual_ticket[a_N]    = false; // dari chart object = sudah real
      a_type[a_N]                 = -1;
      a_volume[a_N]               = 0;
      a_symbol[a_N]               = "";
      a_open_price[a_N]           = 0;
      a_sl[a_N]                   = 0;
      a_tp[a_N]                   = 0;
      a_magic[a_N]                = 0;
      a_comment[a_N]              = "";
      a_color[a_N]                = clrNONE;

      string n2;
      n2 = vo_prefix + "ord" + IntegerToString(i) + "_type";
      if (ObjectFind(0, n2) != -1) a_type[a_N] = Str2OrdType(ObjectGetString(0, n2, OBJPROP_TEXT));

      n2 = vo_prefix + "ord" + IntegerToString(i) + "_volume";
      if (ObjectFind(0, n2) != -1) a_volume[a_N] = StringToDouble(ObjectGetString(0, n2, OBJPROP_TEXT));

      n2 = vo_prefix + "ord" + IntegerToString(i) + "_symbol";
      if (ObjectFind(0, n2) != -1) a_symbol[a_N] = ObjectGetString(0, n2, OBJPROP_TEXT);

      n2 = vo_prefix + "ord" + IntegerToString(i) + "_open_price";
      if (ObjectFind(0, n2) != -1) a_open_price[a_N] = StringToDouble(ObjectGetString(0, n2, OBJPROP_TEXT));

      n2 = vo_prefix + "ord" + IntegerToString(i) + "_sl";
      if (ObjectFind(0, n2) != -1) a_sl[a_N] = StringToDouble(ObjectGetString(0, n2, OBJPROP_TEXT));

      n2 = vo_prefix + "ord" + IntegerToString(i) + "_tp";
      if (ObjectFind(0, n2) != -1) a_tp[a_N] = StringToDouble(ObjectGetString(0, n2, OBJPROP_TEXT));

      n2 = vo_prefix + "ord" + IntegerToString(i) + "_magic";
      if (ObjectFind(0, n2) != -1) a_magic[a_N] = StringToInteger(ObjectGetString(0, n2, OBJPROP_TEXT));

      n2 = vo_prefix + "ord" + IntegerToString(i) + "_comment";
      if (ObjectFind(0, n2) != -1) a_comment[a_N] = ObjectGetString(0, n2, OBJPROP_TEXT);

      n2 = vo_prefix + "ord" + IntegerToString(i) + "_color";
      if (ObjectFind(0, n2) != -1) a_color[a_N] = StringToColor(ObjectGetString(0, n2, OBJPROP_TEXT));

      a_N++;
   }
}

//+------------------------------------------------------------------+
//| OrderSendEx - gunakan unique ticket untuk virtual orders         |
//+------------------------------------------------------------------+
ulong OrderSendEx(string symbol, int cmd, double volume, double price,
                  int slippage, double stoploss, double takeprofit,
                  string comment = "", long magic = 0, datetime expiration = 0,
                  color arrow_color = clrNONE)
{
   if (!VirtualPendingOrders && !VirtualStops)
   {
      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      req.symbol      = symbol;
      req.volume      = volume;
      req.sl          = stoploss;
      req.tp          = takeprofit;
      req.magic       = magic;
      req.comment     = comment;
      req.deviation   = slippage * fpc();
      req.type_time   = ORDER_TIME_SPECIFIED;
      req.expiration  = (datetime)expiration;

      ENUM_ORDER_TYPE otype = (ENUM_ORDER_TYPE)cmd;
      req.action      = TRADE_ACTION_PENDING;
      req.type        = otype;
      req.price       = price;

      if (OrderSend(req, res)) return res.order;
      return 0;
   }

   bool is_pending = (cmd == ORDER_TYPE_BUY_STOP  || cmd == ORDER_TYPE_SELL_STOP ||
                      cmd == ORDER_TYPE_BUY_LIMIT  || cmd == ORDER_TYPE_SELL_LIMIT);

   if (VirtualPendingOrders && is_pending)
   {
      ulong ticket = g_next_virtual_ticket++;
      a_tickets[a_N]              = ticket;
      a_is_virtual_ticket[a_N]    = true;   // ini adalah virtual ticket
      a_type[a_N]                 = cmd;
      a_symbol[a_N]               = symbol;
      a_volume[a_N]               = volume;
      a_open_price[a_N]           = price;
      a_sl[a_N]                   = stoploss;
      a_tp[a_N]                   = takeprofit;
      a_magic[a_N]                = magic;
      a_comment[a_N]              = comment;
      a_color[a_N]                = arrow_color;
      a_N++;
      return ticket;
   }

   if (VirtualStops)
   {
      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      req.action    = TRADE_ACTION_PENDING;
      req.symbol    = symbol;
      req.volume    = volume;
      req.price     = price;
      req.sl        = 0;
      req.tp        = 0;
      req.magic     = magic;
      req.comment   = comment;
      req.deviation = slippage * fpc();
      req.type      = (ENUM_ORDER_TYPE)cmd;
      req.type_time = ORDER_TIME_SPECIFIED;
      req.expiration= (datetime)expiration;

      ulong ticket = 0;
      if (OrderSend(req, res)) ticket = res.order;

      a_tickets[a_N]              = ticket;
      a_is_virtual_ticket[a_N]    = false;  // ini real order ticket dari broker
      a_type[a_N]                 = cmd;
      a_symbol[a_N]               = symbol;
      a_volume[a_N]               = volume;
      a_open_price[a_N]           = price;
      a_sl[a_N]                   = stoploss;
      a_tp[a_N]                   = takeprofit;
      a_magic[a_N]                = magic;
      a_comment[a_N]              = comment;
      a_color[a_N]                = arrow_color;
      a_N++;
      return ticket;
   }

   return 0;
}

bool OrderModifyEx(ulong ticket, double price, double stoploss, double takeprofit,
                   datetime expiration, color arrow_color = clrNONE)
{
   if (!VirtualPendingOrders && !VirtualStops)
      return trade.OrderModify(ticket, price, stoploss, takeprofit,
                                ORDER_TIME_SPECIFIED, expiration);

   int ind = GetSAInd(ticket);
   if (ind == -1) return false;

   bool is_open    = (a_type[ind] == ORDER_TYPE_BUY  || a_type[ind] == ORDER_TYPE_SELL);
   bool is_pending = (a_type[ind] == ORDER_TYPE_BUY_STOP  || a_type[ind] == ORDER_TYPE_SELL_STOP ||
                      a_type[ind] == ORDER_TYPE_BUY_LIMIT  || a_type[ind] == ORDER_TYPE_SELL_LIMIT);

   if (VirtualPendingOrders && VirtualStops)
   {
      if (is_open)    { a_sl[ind] = stoploss; a_tp[ind] = takeprofit; return true; }
      if (is_pending) { a_open_price[ind] = price; a_sl[ind] = stoploss; a_tp[ind] = takeprofit; return true; }
   }
   else if (VirtualPendingOrders)
   {
      if (is_open)    return trade.OrderModify(ticket, price, stoploss, takeprofit, ORDER_TIME_SPECIFIED, expiration);
      if (is_pending) { a_open_price[ind] = price; a_sl[ind] = stoploss; a_tp[ind] = takeprofit; return true; }
   }
   else if (VirtualStops)
   {
      if (is_open)    { a_sl[ind] = stoploss; a_tp[ind] = takeprofit; return true; }
      if (is_pending)
      {
         if (!trade.OrderModify(ticket, price, 0, 0, ORDER_TIME_SPECIFIED, expiration)) return false;
         a_open_price[ind] = price; a_sl[ind] = stoploss; a_tp[ind] = takeprofit;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| FIX UTAMA: VO_CheckPendingOrders                                 |
//| - Gunakan SelectPositionSafe() bukan posInfo.SelectByTicket()    |
//| - Tangani res.order == 0 dengan fallback scan + retry delay      |
//+------------------------------------------------------------------+
void VO_CheckPendingOrders()
{
   // Jika sudah ada posisi terbuka, jangan eksekusi pending apapun
   if (HasOpenPosition()) return;

   double ask  = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double bid  = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   int    digs = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);

   for (int i = 0; i < a_N; i++)
   {
      double send_sl  = (!VirtualStops) ? a_sl[i]  : 0.0;
      double send_tp  = (!VirtualStops) ? a_tp[i]  : 0.0;
      double virt_sl  = a_sl[i];
      double virt_tp  = a_tp[i];

      MqlTradeRequest req = {};
      MqlTradeResult  res = {};

      bool triggered = false;
      ENUM_ORDER_TYPE exec_type = ORDER_TYPE_BUY;

      if (a_type[i] == ORDER_TYPE_BUY_STOP &&
          NormalizeDouble(ask, digs) >= NormalizeDouble(a_open_price[i], digs))
      {
         req.type  = ORDER_TYPE_BUY;
         req.price = ask;
         exec_type = ORDER_TYPE_BUY;
         triggered = true;
      }
      else if (a_type[i] == ORDER_TYPE_BUY_LIMIT &&
               NormalizeDouble(ask, digs) <= NormalizeDouble(a_open_price[i], digs))
      {
         req.type  = ORDER_TYPE_BUY;
         req.price = ask;
         exec_type = ORDER_TYPE_BUY;
         triggered = true;
      }
      else if (a_type[i] == ORDER_TYPE_SELL_STOP &&
               NormalizeDouble(bid, digs) <= NormalizeDouble(a_open_price[i], digs))
      {
         req.type  = ORDER_TYPE_SELL;
         req.price = bid;
         exec_type = ORDER_TYPE_SELL;
         triggered = true;
      }
      else if (a_type[i] == ORDER_TYPE_SELL_LIMIT &&
               NormalizeDouble(bid, digs) >= NormalizeDouble(a_open_price[i], digs))
      {
         req.type  = ORDER_TYPE_SELL;
         req.price = bid;
         exec_type = ORDER_TYPE_SELL;
         triggered = true;
      }

      if (!triggered) continue;

      req.action    = TRADE_ACTION_DEAL;
      req.symbol    = Symbol();
      req.volume    = a_volume[i];
      req.sl        = send_sl;
      req.tp        = send_tp;
      req.magic     = a_magic[i];
      req.comment   = a_comment[i];
      req.deviation = Slippage * fpc();

      if (OrderSend(req, res) && res.deal > 0)
      {
         // *** FIX: res.order di MT5 live bisa 0 (async) — gunakan fallback scan ***
         ulong pos_ticket = res.order;

         if (pos_ticket == 0)
         {
            // Fallback: scan PositionsTotal berdasarkan magic + symbol
            pos_ticket = FindRealPositionTicket(Symbol(), a_magic[i]);

            if (pos_ticket == 0)
            {
               // *** FIX: Jika posisi belum muncul (async delay), tandai sebagai
               //     "executed" dengan virtual ticket sementara, set flag is_virtual=true
               //     agar SelectPositionSafe() bisa resolve di tick berikutnya ***
               Print("[VO_Check] pos_ticket belum tersedia (async), akan resolve di tick berikutnya");
               a_type[i]               = exec_type;      // ubah type ke BUY/SELL
               a_is_virtual_ticket[i]  = true;           // masih virtual, akan di-resolve nanti
               a_sl[i]                 = virt_sl;
               a_tp[i]                 = virt_tp;
               return;
            }
         }

         // Update array dengan real position ticket
         a_tickets[i]            = pos_ticket;
         a_is_virtual_ticket[i]  = false;  // sekarang sudah real
         a_type[i]               = exec_type;
         a_sl[i]                 = virt_sl;
         a_tp[i]                 = virt_tp;

         Print("[VO_Check] Pending tereksekusi -> pos_ticket=", pos_ticket,
               " deal=", res.deal,
               " type=", (exec_type == ORDER_TYPE_BUY ? "BUY" : "SELL"),
               " sl=", DoubleToString(virt_sl, digs),
               " tp=", DoubleToString(virt_tp, digs));

         return; // satu eksekusi per tick
      }
      else
      {
         Print("[VO_Check] OrderSend gagal, error=", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| FIX: VO_UpdatePOType - gunakan SelectPositionSafe()             |
//| Ini handle kasus ticket virtual yang belum resolve ke real       |
//+------------------------------------------------------------------+
void VO_UpdatePOType()
{
   for (int i = a_N - 1; i >= 0; i--)
   {
      // *** FIX: Coba resolve virtual ticket ke real ticket ***
      if (a_is_virtual_ticket[i] &&
          (a_type[i] == ORDER_TYPE_BUY || a_type[i] == ORDER_TYPE_SELL))
      {
         ulong real_ticket = FindRealPositionTicket(a_symbol[i], a_magic[i]);
         if (real_ticket > 0)
         {
            a_tickets[i]           = real_ticket;
            a_is_virtual_ticket[i] = false;
            Print("[UpdatePOType] Resolved virtual -> real ticket #", real_ticket);
         }
         else
         {
            // Masih belum ada posisi real — skip dulu, jangan hapus
            continue;
         }
      }

      ulong ticket = a_tickets[i];

      // Untuk pending virtual, tidak perlu select posisi
      if (a_type[i] == ORDER_TYPE_BUY_STOP  || a_type[i] == ORDER_TYPE_SELL_STOP ||
          a_type[i] == ORDER_TYPE_BUY_LIMIT  || a_type[i] == ORDER_TYPE_SELL_LIMIT)
      {
         // Pending virtual tidak butuh posisi select — skip
         continue;
      }

      // Untuk posisi terbuka, verifikasi masih ada
      if (!posInfo.SelectByTicket(ticket))
      {
         // *** FIX: Jangan langsung hapus — cek dulu apakah masih ada di broker ***
         // Cek via scan PositionsTotal sebagai double-check
         bool still_exists = false;
         for (int pi = 0; pi < PositionsTotal(); pi++)
         {
            string ps = PositionGetSymbol(pi);
            if (ps != a_symbol[i]) continue;
            if ((long)PositionGetInteger(POSITION_MAGIC) != a_magic[i]) continue;
            // Posisi ini masih ada, update ticket
            ulong new_ticket = (ulong)PositionGetInteger(POSITION_TICKET);
            if (new_ticket != ticket)
            {
               a_tickets[i] = new_ticket;
               Print("[UpdatePOType] Ticket updated: ", ticket, " -> ", new_ticket);
            }
            still_exists = true;
            break;
         }
         if (!still_exists && HistoryDealSelect(ticket))
         {
            VOrderRemove(i);
            continue;
         }
         // Jika tidak di history juga, biarkan — mungkin async delay
         continue;
      }

      if (posInfo.PositionType() == POSITION_TYPE_BUY)
      {
         if (a_type[i] == ORDER_TYPE_BUY_STOP || a_type[i] == ORDER_TYPE_BUY_LIMIT)
            a_type[i] = ORDER_TYPE_BUY;
      }
      else if (posInfo.PositionType() == POSITION_TYPE_SELL)
      {
         if (a_type[i] == ORDER_TYPE_SELL_STOP || a_type[i] == ORDER_TYPE_SELL_LIMIT)
            a_type[i] = ORDER_TYPE_SELL;
      }
   }
}

//+------------------------------------------------------------------+
//| FIX: VO_CheckStops - gunakan SelectPositionSafe()               |
//+------------------------------------------------------------------+
void VO_CheckStops()
{
<<<<<<< HEAD
   for (int i = 0; i < a_N; i++)
   {
      if (a_type[i] != ORDER_TYPE_BUY && a_type[i] != ORDER_TYPE_SELL) continue;

      // *** FIX: Gunakan SelectPositionSafe agar virtual ticket di-resolve dulu ***
      if (!SelectPositionSafe(i)) continue;

      double bid  = SymbolInfoDouble(posInfo.Symbol(), SYMBOL_BID);
      double ask  = SymbolInfoDouble(posInfo.Symbol(), SYMBOL_ASK);
      int    digs = (int)SymbolInfoInteger(posInfo.Symbol(), SYMBOL_DIGITS);
      double sl   = a_sl[i];
      double tp   = a_tp[i];
=======
   // 1. Gunakan Descending Loop (mundur) supaya index gak berantakan pas ada posisi close
   for (int i = a_N - 1; i >= 0; i--)
   {
      if (a_type[i] != ORDER_TYPE_BUY && a_type[i] != ORDER_TYPE_SELL) continue;

      // 2. Gunakan TICKET, bukan INDEX, supaya lebih stabil di Live Trading
      ulong ticket = a_tickets[i];
      if (!PositionSelectByTicket(ticket)) continue; 

      // 3. Ambil data langsung dari posisi yang sudah terpilih
      string sym = PositionGetString(POSITION_SYMBOL);
      if (sym != _Symbol) continue; // Pastikan hanya proses symbol ini

      double bid  = SymbolInfoDouble(sym, SYMBOL_BID);
      double ask  = SymbolInfoDouble(sym, SYMBOL_ASK);
      int    digs = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      double sl   = a_sl[i];
      double tp   = a_tp[i];
      double vol  = PositionGetDouble(POSITION_VOLUME);
>>>>>>> 69977ad (fix: BEGAJUL Virtual SL/TP logic (descending loop & ticket selection))

      MqlTradeRequest req = {};
      MqlTradeResult  res = {};

<<<<<<< HEAD
      if (a_type[i] == ORDER_TYPE_BUY)
      {
         if (tp > 0 && NormalizeDouble(bid, digs) >= NormalizeDouble(tp, digs))
         {
            Print("[CheckStops] Close BUY by VirtualTP ", DoubleToString(tp, digs));
            req.action    = TRADE_ACTION_DEAL;
            req.symbol    = posInfo.Symbol();
            req.type      = ORDER_TYPE_SELL;
            req.volume    = posInfo.Volume();
            req.price     = bid;
            req.deviation = Slippage * fpc();
            req.position  = a_tickets[i];
            bool rc1 = OrderSend(req, res);
            if (!rc1) Print("[CheckStops] Close BUY TP error: ", GetLastError());
            continue;
         }
         if (sl > 0 && NormalizeDouble(bid, digs) <= NormalizeDouble(sl, digs))
         {
            Print("[CheckStops] Close BUY by VirtualSL ", DoubleToString(sl, digs));
            req.action    = TRADE_ACTION_DEAL;
            req.symbol    = posInfo.Symbol();
            req.type      = ORDER_TYPE_SELL;
            req.volume    = posInfo.Volume();
            req.price     = bid;
            req.deviation = Slippage * fpc();
            req.position  = a_tickets[i];
            bool rc2 = OrderSend(req, res);
            if (!rc2) Print("[CheckStops] Close BUY SL error: ", GetLastError());
=======
      // --- LOGIC BUY ---
      if (a_type[i] == ORDER_TYPE_BUY)
      {
         // Check Virtual TP
         if (tp > 0 && NormalizeDouble(bid, digs) >= NormalizeDouble(tp, digs))
         {
            Print("[CheckStops] Close BUY by VirtualTP @ ", DoubleToString(bid, digs), " (Target: ", DoubleToString(tp, digs), ")");
            req.action    = TRADE_ACTION_DEAL;
            req.symbol    = sym;
            req.type      = ORDER_TYPE_SELL;
            req.volume    = vol;
            req.price     = bid;
            req.deviation = Slippage * fpc();
            req.position  = ticket;
            if (!OrderSend(req, res)) Print("[CheckStops] Close BUY TP error: ", GetLastError());
            continue;
         }
         // Check Virtual SL
         if (sl > 0 && NormalizeDouble(bid, digs) <= NormalizeDouble(sl, digs))
         {
            Print("[CheckStops] Close BUY by VirtualSL @ ", DoubleToString(bid, digs), " (Target: ", DoubleToString(sl, digs), ")");
            req.action    = TRADE_ACTION_DEAL;
            req.symbol    = sym;
            req.type      = ORDER_TYPE_SELL;
            req.volume    = vol;
            req.price     = bid;
            req.deviation = Slippage * fpc();
            req.position  = ticket;
            if (!OrderSend(req, res)) Print("[CheckStops] Close BUY SL error: ", GetLastError());
>>>>>>> 69977ad (fix: BEGAJUL Virtual SL/TP logic (descending loop & ticket selection))
            continue;
         }
      }

<<<<<<< HEAD
      if (a_type[i] == ORDER_TYPE_SELL)
      {
         if (tp > 0 && NormalizeDouble(ask, digs) <= NormalizeDouble(tp, digs))
         {
            Print("[CheckStops] Close SELL by VirtualTP ", DoubleToString(tp, digs));
            req.action    = TRADE_ACTION_DEAL;
            req.symbol    = posInfo.Symbol();
            req.type      = ORDER_TYPE_BUY;
            req.volume    = posInfo.Volume();
            req.price     = ask;
            req.deviation = Slippage * fpc();
            req.position  = a_tickets[i];
            bool rc3 = OrderSend(req, res);
            if (!rc3) Print("[CheckStops] Close SELL TP error: ", GetLastError());
            continue;
         }
         if (sl > 0 && NormalizeDouble(ask, digs) >= NormalizeDouble(sl, digs))
         {
            Print("[CheckStops] Close SELL by VirtualSL ", DoubleToString(sl, digs));
            req.action    = TRADE_ACTION_DEAL;
            req.symbol    = posInfo.Symbol();
            req.type      = ORDER_TYPE_BUY;
            req.volume    = posInfo.Volume();
            req.price     = ask;
            req.deviation = Slippage * fpc();
            req.position  = a_tickets[i];
            bool rc4 = OrderSend(req, res);
            if (!rc4) Print("[CheckStops] Close SELL SL error: ", GetLastError());
=======
      // --- LOGIC SELL ---
      else if (a_type[i] == ORDER_TYPE_SELL)
      {
         // Check Virtual TP
         if (tp > 0 && NormalizeDouble(ask, digs) <= NormalizeDouble(tp, digs))
         {
            Print("[CheckStops] Close SELL by VirtualTP @ ", DoubleToString(ask, digs), " (Target: ", DoubleToString(tp, digs), ")");
            req.action    = TRADE_ACTION_DEAL;
            req.symbol    = sym;
            req.type      = ORDER_TYPE_BUY;
            req.volume    = vol;
            req.price     = ask;
            req.deviation = Slippage * fpc();
            req.position  = ticket;
            if (!OrderSend(req, res)) Print("[CheckStops] Close SELL TP error: ", GetLastError());
            continue;
         }
         // Check Virtual SL
         if (sl > 0 && NormalizeDouble(ask, digs) >= NormalizeDouble(sl, digs))
         {
            Print("[CheckStops] Close SELL by VirtualSL @ ", DoubleToString(ask, digs), " (Target: ", DoubleToString(sl, digs), ")");
            req.action    = TRADE_ACTION_DEAL;
            req.symbol    = sym;
            req.type      = ORDER_TYPE_BUY;
            req.volume    = vol;
            req.price     = ask;
            req.deviation = Slippage * fpc();
            req.position  = ticket;
            if (!OrderSend(req, res)) Print("[CheckStops] Close SELL SL error: ", GetLastError());
>>>>>>> 69977ad (fix: BEGAJUL Virtual SL/TP logic (descending loop & ticket selection))
            continue;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| FIX: VO_ClearStops - gunakan SelectPositionSafe()               |
//+------------------------------------------------------------------+
void VO_ClearStops()
{
   for (int i = a_N - 1; i >= 0; i--)
   {
      if (a_type[i] != ORDER_TYPE_BUY && a_type[i] != ORDER_TYPE_SELL) continue;

      // *** FIX: Jika ticket masih virtual, jangan hapus — posisi mungkin belum muncul ***
      if (a_is_virtual_ticket[i]) continue;

      ulong ticket   = a_tickets[i];
      bool  bRemove  = false;

      if (!posInfo.SelectByTicket(ticket))
      {
         // Verifikasi via scan PositionsTotal sebelum hapus
         bool still_exists = false;
         for (int pi = 0; pi < PositionsTotal(); pi++)
         {
            string ps = PositionGetSymbol(pi);
            if (ps != a_symbol[i]) continue;
            if ((long)PositionGetInteger(POSITION_MAGIC) != a_magic[i]) continue;
            still_exists = true;
            break;
         }
         if (!still_exists) bRemove = true;
      }

      if (bRemove) VOrderRemove(i);
   }
}

void VOrderRemove(int ind)
{
   for (int j = ind; j < a_N - 1; j++)
   {
      a_tickets[j]              = a_tickets[j+1];
      a_is_virtual_ticket[j]    = a_is_virtual_ticket[j+1];
      a_type[j]                 = a_type[j+1];
      a_symbol[j]               = a_symbol[j+1];
      a_volume[j]               = a_volume[j+1];
      a_open_price[j]           = a_open_price[j+1];
      a_sl[j]                   = a_sl[j+1];
      a_tp[j]                   = a_tp[j+1];
      a_magic[j]                = a_magic[j+1];
      a_comment[j]              = a_comment[j+1];
      a_color[j]                = a_color[j+1];
   }
   a_N--;
}

void VO_DrawStops()
{
   string obj_name;

   obj_name = vo_prefix + "Legend";
   if (ObjectFind(0, obj_name) == -1)
      ObjectCreate(0, obj_name, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, obj_name, OBJPROP_TEXT, "Virtual Orders Storage");
   ObjectSetString(0, obj_name, OBJPROP_FONT, VOrdText_font);
   ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, VOrdText_font_size);
   ObjectSetInteger(0, obj_name, OBJPROP_COLOR, VOrdText_font_color);
   ObjectSetInteger(0, obj_name, OBJPROP_CORNER, VOrdText_corner);
   ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, VOrdText_x);
   ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, VOrdText_y);

   string ColPref[7] = {"ticket", "type", "volume", "symbol", "open_price", "sl", "tp"};

   for (int i = 0; i < a_N; i++)
   {
      int    digs  = (int)SymbolInfoInteger(a_symbol[i], SYMBOL_DIGITS);
      string vals[7];
      vals[0] = IntegerToString(a_tickets[i]);
      vals[1] = OrdType2Str(a_type[i]);
      vals[2] = DoubleToString(a_volume[i], 2);
      vals[3] = a_symbol[i];
      vals[4] = DoubleToString(a_open_price[i], digs);
      vals[5] = DoubleToString(a_sl[i], digs);
      vals[6] = DoubleToString(a_tp[i], digs);

      int dx = VOrdText_x;
      for (int j = 6; j >= 0; j--)
      {
         obj_name = vo_prefix + "ord" + IntegerToString(i) + "_" + ColPref[j];
         if (ObjectFind(0, obj_name) == -1)
            ObjectCreate(0, obj_name, OBJ_LABEL, 0, 0, 0);
         ObjectSetString(0, obj_name, OBJPROP_TEXT, vals[j]);
         ObjectSetString(0, obj_name, OBJPROP_FONT, VOrdText_font);
         ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, VOrdText_font_size);
         ObjectSetInteger(0, obj_name, OBJPROP_COLOR, VOrdText_font_color);
         ObjectSetInteger(0, obj_name, OBJPROP_CORNER, VOrdText_corner);
         ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, dx);
         ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, VOrdText_y + (i+1) * VOrdText_dy);
         dx += VOrdText_dx;
      }
   }

   for (int i = a_N; i < 1000; i++)
   {
      obj_name = vo_prefix + "ord" + IntegerToString(i);
      if (ObjectFind(0, obj_name) != -1) ObjectDelete(0, obj_name);
   }
}

void DrawVirtualLines()
{
   for (int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string nm = ObjectName(0, i);
      if (StringFind(nm, vo_prefix + "line_") == 0)
         ObjectDelete(0, nm);
   }

   int digs = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);

   for (int i = 0; i < a_N; i++)
   {
      if (a_type[i] != ORDER_TYPE_BUY && a_type[i] != ORDER_TYPE_SELL) continue;

      string base = vo_prefix + "line_" + IntegerToString(i);

      string nm_entry = base + "_entry";
      if (ObjectFind(0, nm_entry) == -1)
         ObjectCreate(0, nm_entry, OBJ_HLINE, 0, 0, 0);
      ObjectSetDouble(0, nm_entry, OBJPROP_PRICE, a_open_price[i]);
      ObjectSetInteger(0, nm_entry, OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, nm_entry, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, nm_entry, OBJPROP_WIDTH, 1);
      ObjectSetString(0, nm_entry, OBJPROP_TEXT,
         (a_type[i] == ORDER_TYPE_BUY ? "BUY" : "SELL") +
         " Entry: " + DoubleToString(a_open_price[i], digs));

      if (a_sl[i] > 0)
      {
         string nm_sl = base + "_sl";
         if (ObjectFind(0, nm_sl) == -1)
            ObjectCreate(0, nm_sl, OBJ_HLINE, 0, 0, 0);
         ObjectSetDouble(0, nm_sl, OBJPROP_PRICE, a_sl[i]);
         ObjectSetInteger(0, nm_sl, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, nm_sl, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, nm_sl, OBJPROP_WIDTH, 2);
         ObjectSetString(0, nm_sl, OBJPROP_TEXT,
            "Virtual SL: " + DoubleToString(a_sl[i], digs));
      }

      if (a_tp[i] > 0)
      {
         string nm_tp = base + "_tp";
         if (ObjectFind(0, nm_tp) == -1)
            ObjectCreate(0, nm_tp, OBJ_HLINE, 0, 0, 0);
         ObjectSetDouble(0, nm_tp, OBJPROP_PRICE, a_tp[i]);
         ObjectSetInteger(0, nm_tp, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, nm_tp, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, nm_tp, OBJPROP_WIDTH, 2);
         ObjectSetString(0, nm_tp, OBJPROP_TEXT,
            "Virtual TP: " + DoubleToString(a_tp[i], digs));
      }

      if (vTrailingStart > 0)
      {
         double trail_level = 0;
         string trail_label = "";
         if (a_type[i] == ORDER_TYPE_BUY)
         {
            trail_level = a_open_price[i] + vTrailingStart;
            trail_label = "Trail Start BUY: " + DoubleToString(trail_level, digs);
         }
         else
         {
            trail_level = a_open_price[i] - vTrailingStart;
            trail_label = "Trail Start SELL: " + DoubleToString(trail_level, digs);
         }

         string nm_tr = base + "_trail";
         if (ObjectFind(0, nm_tr) == -1)
            ObjectCreate(0, nm_tr, OBJ_HLINE, 0, 0, 0);
         ObjectSetDouble(0, nm_tr, OBJPROP_PRICE, trail_level);
         ObjectSetInteger(0, nm_tr, OBJPROP_COLOR, clrOrange);
         ObjectSetInteger(0, nm_tr, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, nm_tr, OBJPROP_WIDTH, 1);
         ObjectSetString(0, nm_tr, OBJPROP_TEXT, trail_label);
      }

      string nm_lbl = base + "_label";
      if (ObjectFind(0, nm_lbl) == -1)
         ObjectCreate(0, nm_lbl, OBJ_LABEL, 0, 0, 0);
      string lbl_txt = "";
      if (a_sl[i] > 0) lbl_txt += "SL:" + DoubleToString(a_sl[i], digs) + "  ";
      if (a_tp[i] > 0) lbl_txt += "TP:" + DoubleToString(a_tp[i], digs);
      ObjectSetString(0, nm_lbl, OBJPROP_TEXT, lbl_txt);
      ObjectSetInteger(0, nm_lbl, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, nm_lbl, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, nm_lbl, OBJPROP_YDISTANCE, 60 + i * 30);
      ObjectSetInteger(0, nm_lbl, OBJPROP_COLOR, clrYellow);
      ObjectSetString(0, nm_lbl, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, nm_lbl, OBJPROP_FONTSIZE, 9);
   }

   ChartRedraw(0);
}

string OrdType2Str(int type)
{
   switch (type)
   {
      case ORDER_TYPE_BUY:        return "Buy";
      case ORDER_TYPE_SELL:       return "Sell";
      case ORDER_TYPE_BUY_LIMIT:  return "BuyLimit";
      case ORDER_TYPE_SELL_LIMIT: return "SellLimit";
      case ORDER_TYPE_BUY_STOP:   return "BuyStop";
      case ORDER_TYPE_SELL_STOP:  return "SellStop";
   }
   return IntegerToString(type);
}

int Str2OrdType(string sType)
{
   if (sType == "Buy")       return ORDER_TYPE_BUY;
   if (sType == "Sell")      return ORDER_TYPE_SELL;
   if (sType == "BuyLimit")  return ORDER_TYPE_BUY_LIMIT;
   if (sType == "SellLimit") return ORDER_TYPE_SELL_LIMIT;
   if (sType == "BuyStop")   return ORDER_TYPE_BUY_STOP;
   if (sType == "SellStop")  return ORDER_TYPE_SELL_STOP;
   return -1;
}

int fpc()
{
   int d = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
   if (d == 3 || d == 5) return 10;
   return 1;
}
//+------------------------------------------------------------------+
