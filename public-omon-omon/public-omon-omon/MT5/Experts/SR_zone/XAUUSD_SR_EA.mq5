//+------------------------------------------------------------------+
//|                                       XAUUSD_SR_EA.mq5           |
//|                          Cuancux Algo Traders • Paulus Is        |
//|  XAUUSD S/R Zone Trading EA — VicChelenge System                 |
//|  v1.0 — initial build                                           |
//+------------------------------------------------------------------+
#property copyright   "Cuancux Algo Traders • Paulus Is"
#property link        "https://github.com/Lybeedo/public-omon-omon"
#property version     "1.00"
#property description "XAUUSD S/R Zone EA — VicChelenge System"
#property strict

#include <Include/SR_Config.mqh>
#include <Include/SR_Zones.mqh>
#include <Include/SR_Candles.mqh>
#include <Include/SR_TradeManager.mqh>
#include <Include/SR_Session.mqh>
#include <Include/SR_Logger.mqh>

//+------------------------------------------------------------------+
//|  Global instances                                                |
//+------------------------------------------------------------------+
CSR_Zones         g_zones;
CSR_Candles       g_candles;
CSR_TradeManager  g_tm;
CSR_Session       g_session;
CSR_Logger        g_logger;

//+------------------------------------------------------------------+
//|  INPUT PARAMETERS                                                |
//+------------------------------------------------------------------+
input group "=== RISK MANAGEMENT ==="
input double   RiskPercent       = 2.0;
input double   MinRiskReward     = 2.0;
input double   MaxRiskReward     = 0.0;

input group "=== POSITION SETTINGS ==="
input int      MaxOpenTrades     = 3;
input double   MaxSpreadPoints   = 30.0;

input group "=== SL / TP ==="
input double   StopLossPoints    = 150;
input double   TakeProfitPoints  = 300;
input bool     UsePartialProfit   = true;
input double   PartialTPPips      = 50;
input double   PartialTPPct      = 30;
input bool     UseBreakeven       = true;
input double   BetriggerPips      = 30;
input bool     UseTrailingStop    = true;
input double   TrailStartPips     = 80;
input double   TrailStepPips      = 20;

input group "=== ZONE DETECTION ==="
input string   BuyZonePrefix    = "SR_BuyZone";
input string   SellZonePrefix   = "SR_SellZone";
input int      ZoneLookbackBars = 100;
input int      InvalidationBars  = 3;
input double   ZoneTouchTolPips  = 10;

input group "=== CANDLE PATTERNS ==="
input bool     UseBullishEngulfing = true;
input bool     UseHammerPattern    = true;
input bool     UseMorningStar      = true;
input bool     UseBearishEngulfing = true;
input bool     UseShootingStar     = true;
input bool     UseEveningStar      = true;
input double   MinBodyRatio        = 0.5;

input group "=== SESSION FILTER ==="
input bool     UseNYSessionFilter = true;
input int      NYStartHour        = 8;
input int      NYStartMin         = 0;
input int      NYEndHour          = 17;
input int      NYEndMin           = 0;

input group "=== LOGGING & VISUAL ==="
input int      LogLevel           = 1;
input color    BuyZoneColor        = clrLime;
input color    SellZoneColor       = clrRed;
input color    ValidZoneColor      = clrDodgerBlue;
input color    InvalidZoneColor    = clrGray;

input group "=== MISC ==="
input int      MagicNumber        = 20250603;
input string   CommentPrefix      = "SR_EA";
input int      Slippage           = 3;

//+------------------------------------------------------------------+
//|  State                                                           |
//+------------------------------------------------------------------+
int    g_lastBar     = 0;
datetime g_lastScan  = 0;
int    g_tradeCount  = 0;

//+------------------------------------------------------------------+
//|  OnInit                                                          |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_zones.Configure(BuyZonePrefix, SellZonePrefix,
                     InvalidationBars, ZoneTouchTolPips);

   g_candles.Configure(
      UseBullishEngulfing, UseHammerPattern, UseMorningStar,
      UseBearishEngulfing, UseShootingStar, UseEveningStar,
      MinBodyRatio);

   g_tm.Configure(MagicNumber, CommentPrefix, Slippage,
                  RiskPercent, MinRiskReward, MaxRiskReward,
                  StopLossPoints, TakeProfitPoints,
                  UsePartialProfit, PartialTPPips, PartialTPPct,
                  UseBreakeven, BetriggerPips,
                  UseTrailingStop, TrailStartPips, TrailStepPips,
                  MaxOpenTrades);

   g_session.Configure(UseNYSessionFilter, NYStartHour, NYStartMin,
                        NYEndHour, NYEndMin);

   g_logger.Configure(LogLevel, 30);

   g_logger.Log("=== XAUUSD S/R EA INITIALIZED ===");
   g_logger.Log("Buy prefix: " + BuyZonePrefix + " | Sell prefix: " + SellZonePrefix);
   g_logger.Log(g_session.SessionInfo());

   g_zones.Scan();
   g_zones.LogAllZones(LogLevel);
   g_lastBar = iBarShift(_Symbol, PERIOD_CURRENT, iTime(_Symbol, PERIOD_CURRENT, 0));

   RefreshInfo();

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//|  OnTick                                                          |
//+------------------------------------------------------------------+
void OnTick()
  {
   int currBar = iBarShift(_Symbol, PERIOD_CURRENT,
                           iTime(_Symbol, PERIOD_CURRENT, 0));
   bool newBar = (currBar < g_lastBar);
   g_lastBar = currBar;

   // Manage open trades every tick
   g_tm.ManageTrades();

   if(!newBar) return;

   // Session filter
   if(!g_session.IsSessionOpen())
     { if(LogLevel >= 2) g_logger.Log("Outside NY session"); return; }

   // Scan / update zones
   g_zones.Scan();
   g_zones.UpdateTouches();
   g_zones.CheckInvalidation(InvalidationBars);
   if(LogLevel >= 2) g_zones.LogAllZones(LogLevel);

   // Scan for entry signals
   for(int i = 0; i < g_zones.ZoneCount(); i++)
     {
      SZone* zone = g_zones.GetZone(i);
      if(zone == NULL) continue;
      if(zone.state == ZONE_INVALIDATED) continue;
      if(zone.entryTriggered) continue;

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double zoneHigh = g_zones.GetZoneHigh(i);
      double zoneLow  = g_zones.GetZoneLow(i);

      // Check if price is inside or touching zone
      bool nearZone = (bid >= zoneLow - ZoneTouchTolPips * Point)
                      && (bid <= zoneHigh + ZoneTouchTolPips * Point);
      if(!nearZone) continue;

      // Detect reversal candle on bar 1
      ENUM_REVERSAL_PATTERN pattern = REVERSAL_NONE;
      SCandleSignal sig;
      sig.reversalHigh  = iHigh(NULL, 0, 1);
      sig.reversalLow   = iLow(NULL, 0, 1);
      sig.reversalOpen  = iOpen(NULL, 0, 1);
      sig.reversalClose = iClose(NULL, 0, 1);
      sig.reversalBar   = 1;
      sig.pattern       = REVERSAL_NONE;

      bool hasReversal = g_candles.DetectReversal(1, pattern);
      if(!hasReversal) continue;
      sig.pattern = pattern;

      // Verify reversal aligns with zone direction
      bool patternMatchesZone = (zone.type == ZONE_BUY && sig.reversalClose > sig.reversalOpen)
                                 || (zone.type == ZONE_SELL && sig.reversalClose < sig.reversalOpen);
      if(!patternMatchesZone) continue;

      // Check confirmation on bar 0
      bool hasConf = g_candles.DetectConfirmation(1, zone.type, sig);
      if(!hasConf) continue;

      // Open trade
      double slPrice, tpPrice, lotSize;
      bool opened = g_tm.OpenTrade(zone.type, zoneHigh, zoneLow, i,
                                   slPrice, tpPrice, lotSize);

      if(opened)
        {
         zone.entryTriggered = true;
         g_tradeCount++;
         g_logger.LogFormat(
            "[SIGNAL] %s | Pattern=%s | Bid=%.5f | SL=%.5f | TP=%.5f | Lot=%.2f",
            zone.name,
            g_candles.PatternToString(pattern),
            bid, slPrice, tpPrice, lotSize);
        }
     }

   RefreshInfo();
  }

//+------------------------------------------------------------------+
//|  RefreshInfo — chart comment display                             |
//+------------------------------------------------------------------+
void RefreshInfo()
  {
   g_logger.Clear();
   g_logger.Add("=== XAUUSD S/R EA ===");
   g_logger.Add(g_session.SessionInfo());

   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   g_logger.Add(StringFormat("Spread: %.0f pts | Trades: %d/%d",
                              spread, g_tm.CountOpenTrades(), MaxOpenTrades));
   g_logger.AddBlank();

   // Zone summary
   int buyAct = 0, sellAct = 0, buyInv = 0, sellInv = 0;
   for(int i = 0; i < g_zones.ZoneCount(); i++)
     {
      ENUM_ZONE_TYPE    t = g_zones.GetZoneType(i);
      ENUM_ZONE_STATE   s = g_zones.GetZoneState(i);
      if(t == ZONE_BUY)  { if(s == ZONE_ACTIVE) buyAct++; else if(s == ZONE_INVALIDATED) buyInv++; }
      if(t == ZONE_SELL) { if(s == ZONE_ACTIVE) sellAct++; else if(s == ZONE_INVALIDATED) sellInv++; }
     }
   g_logger.Add(StringFormat("Zones: Buy Active=%d Invalid=%d | Sell Active=%d Invalid=%d",
                              buyAct, buyInv, sellAct, sellInv));
   g_logger.AddBlank();

   // Trade states
   for(int i = 0; i < g_tm.StateCount(); i++)
     {
      STradeState* st = g_tm.GetState(i);
      if(st == NULL || st.ticket == 0) continue;
      string tpStr = (st.posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      g_logger.Add(StringFormat("Ticket=%I64u | %s | Entry=%.5f | P/L=%+.0f pts",
                                st.ticket, tpStr, st.entryPrice,
                                (st.posType == POSITION_TYPE_BUY)
                                ? (SymbolInfoDouble(_Symbol, SYMBOL_BID) - st.entryPrice) / Point / 10.0
                                : (st.entryPrice - SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / Point / 10.0));
      string flags = "";
      if(st.partialHit)    flags += " PARTIAL";
      if(st.beTriggered)   flags += " BE";
      if(st.trailingActive) flags += " TRAIL";
      g_logger.Add("   Flags:" + flags);
     }

   g_logger.Render();
  }

//+------------------------------------------------------------------+
//|  OnDeinit                                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Comment("");
   g_logger.Log("EA removed, reason=" + IntegerToString(reason));
  }

//+------------------------------------------------------------------+
//|  OnTradeTransaction                                             |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                         const MqlTradeRequest &request,
                         const MqlTradeResult &result)
  {
   if(LogLevel >= 2)
      PrintFormat("TradeTrans: type=%d order=%I64u ret=%d",
                 (int)trans.type, trans.order, (int)result.retcode);
   (void)request;
  }

//+------------------------------------------------------------------+
//|  OnTimer — periodic zone scan every 5 sec                       |
//+------------------------------------------------------------------+
void OnTimer()
  {
   datetime now = TimeCurrent();
   if(now - g_lastScan < 5) return;
   g_lastScan = now;

   g_zones.Scan();
   g_zones.UpdateTouches();
   g_zones.CheckInvalidation(InvalidationBars);
  }
//+------------------------------------------------------------------+