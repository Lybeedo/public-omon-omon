//+------------------------------------------------------------------+
//|                                             MurrayMathEA.mq4     |
//|        Murray Math + Fibonacci + Anchored VWAP Trading EA        |
//|                         MT5 Version                               |
//+------------------------------------------------------------------+
#property copyright "Murray Math EA v1.0"
#property version   "1.00"
#property link      "https://github.com/Lybeedo/public-omon-omon"
#property description "Murray Math 8-Level + Fibo + VWAP Multi-Timeframe EA"
#property strict

#include <Include/Utils.mqh>
#include <Include/MurrayMath.mqh>
#include <Include/FiboLevels.mqh>
#include <Include/VWAP.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
// --- General ---
input group "=== GENERAL ==="
input string   EA_Comment        = "MurrayMath";     // Order comment
input double   MaxSpread        = 30;               // Max spread (points) for entry
input bool     UseTradeFilter   = true;            // Enable spread & trading hour filter
input int       MaxOpenOrders   = 3;               // Max concurrent orders per direction

// --- Murray Math ---
input group "=== MURRAY MATH ==="
input int        MM_LookbackBars   = 100;           // Bars to calculate swing range
input int        MM_OctaveMode     = 0;            // 0=Auto, 1=Manual Step
input double     MM_ManualStep     = 0.001;        // Manual step (if octaveMode=1)
input ENUM_LINE_STYLE MM_LineStyle   = STYLE_DASH;   // Line style for MM levels
input int        MM_LineWidth       = 1;            // Line width (0-5)
input bool       MM_ShowLabels      = true;         // Show level labels on chart
input bool       MM_ShowZones       = true;         // Show colored zones between levels
input color      MM_ColorBuyZone    = clrLime;      // Buy zone color
input color      MM_ColorSellZone   = clrRed;       // Sell zone color
input color      MM_ColorNeutral    = clrGray;      // Neutral zone color

// --- Fibonacci ---
input group "=== FIBONACCI ==="
input int        Fibo_Lookback      = 50;            // Bars to detect swing high/low
input int        Fibo_MinSwingPips  = 30;           // Minimum swing size (pips)
input ENUM_LINE_STYLE Fibo_LineStyle  = STYLE_SOLID;  // Fibo line style
input int        Fibo_LineWidth      = 1;            // Fibo line width
input bool       Fibo_ShowRetrace   = true;         // Show retracement levels
input bool       Fibo_ShowExtension = true;         // Show extension levels

// --- Anchored VWAP ---
input group "=== ANCHORED VWAP ==="
input ENUM_VWAP_RESET VWAP_ResetMode   = VWAP_DAILY; // VWAP reset mode
input int            VWAP_SessionHour  = 8;          // Session start hour (broker time)
input bool          VWAP_ShowBands    = true;       // Show +1σ / +2σ bands
input color         VWAP_Color        = clrGold;    // VWAP line color

// --- Entry & Risk ---
input group "=== ENTRY & RISK ==="
input double        RiskPercent       = 2.0;         // Risk per trade (%)
input double        SL_Pips           = 30;          // Stop loss (pips)
input double        TP_Pips           = 50;          // Take profit (pips)
input double        TrailingStart     = 15;          // Start trailing after (pips)
input double        TrailingStep      = 5;           // Trailing step (pips)
input ENUM_ORDER_TYPE_FILLING OrderFillMode   = ORDER_FILLING_FOK;  // MT5 only, MT4 ignores // Fill policy

// --- Confirmation Filter ---
input group "=== FILTERS ==="
input bool          Filter_VWAPConfirm = true;       // Require VWAP confirmation
input bool          Filter_FiboConfirm = false;      // Require Fibo zone confirmation
input bool          Filter_ZoneConfirm = true;       // Require Murray zone filter
input int           Filter_MinTrendBars = 3;         // Min bars price must stay above/below VWAP

// --- Time Filter ---
input group "=== TRADING HOURS ==="
input int            TradeHourStart    = 8;           // Start hour (broker time, 0=disabled)
input int            TradeHourEnd      = 22;          // End hour (0=disabled)

//+------------------------------------------------------------------+
//| Global Instances                                                 |
//+------------------------------------------------------------------+
CMurrayMath   g_Murray;
CFiboCalculator g_Fibo;
CAnchoredVWAP g_VWAP;

// State
int        g_MagicBuy  = 2025011;
int        g_MagicSell = 2025012;
datetime   g_LastTradeBar = 0;
int        g_TicketCounter = 0;
double     g_LastSignal = 0;
int        g_LastSignalBar = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                           |
//+------------------------------------------------------------------+
int OnInit() {
    // Validate parameters
    if(SL_Pips <= 0) { Print("ERROR: SL_Pips must be > 0"); return INIT_PARAMETERS_INCORRECT; }
    if(TP_Pips <= 0) { Print("ERROR: TP_Pips must be > 0"); return INIT_PARAMETERS_INCORRECT; }
    if(RiskPercent <= 0 || RiskPercent > 20) { Print("ERROR: RiskPercent must be 0.1-20"); return INIT_PARAMETERS_INCORRECT; }
    if(MaxSpread < 0) { Print("ERROR: MaxSpread must be >= 0"); return INIT_PARAMETERS_INCORRECT; }

    // Initialize VWAP
    g_VWAP.mResetMode = VWAP_ResetMode;
    g_VWAP.mSessionHour = VWAP_SessionHour;

    // Calculate initial levels
    RefreshLevels();

    Print("=== Murray Math EA Initialized ===");
    Print("Symbol: ", _Symbol, " | Digits: ", GetDigits());
    Print("Risk: ", RiskPercent, "% | SL: ", SL_Pips, " | TP: ", TP_Pips);
    Print("MM Lookback: ", MM_LookbackBars, " | Fibo Lookback: ", Fibo_Lookback);
    Print("VWAP Mode: ", g_VWAP.GetSessionName());
    Print("===================================");
    DrawAllLevels();

    EventSetTimer(5);  // Refresh every 5 seconds for MT4

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Comment("");
    EventKillTimer();
    ObjectsDeleteAll(0, "MurrayMath_", 0);
    ObjectsDeleteAll(0, "MurrayMath_Fibo", 0);
    ObjectsDeleteAll(0, "MurrayMath_VWAP", 0);
    Print("Murray Math EA unloaded. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Main tick function                                               |
//+------------------------------------------------------------------+
void OnTick() {
    // Only trade on new bar
    if(!IsNewBar()) return;

    // Update indicators on each new bar
    RefreshLevels();

    // Recalculate VWAP
    double vwap = g_VWAP.Update(0);
    double bid  = Bid;
    double ask  = Ask;
    double spread = (ask - bid) / GetPoint();

    // Check spread filter
    if(UseTradeFilter && spread > MaxSpread) {
        return;
    }

    // Check trading hours
    if(!IsTradeAllowed()) return;

    // Generate signal
    int signal = GetSignal(bid, vwap);

    // Execute
    if(signal != 0) {
        ManageOrders(signal, bid, ask);
    }

    // Manage existing trades
    ManageTrailing();
    ManageEquityProtection();

    // Update chart info
    UpdateChartComment(bid, vwap, spread);
}

//+------------------------------------------------------------------+
//| Signal Generation                                                |
//+------------------------------------------------------------------+
int GetSignal(double price, double vwap) {
    int mmZone  = g_Murray.GetCurrentZone(price);
    int vwapPos = g_VWAP.GetPricePosition(price);
    int vwapTrend = g_VWAP.GetTrend(Filter_MinTrendBars);
    int fiboZone = g_Fibo.InFiboZone(price, 5 * GetPoint());

    double signalScore = 0;
    int direction = 0;

    // === BUY CONDITIONS ===
    // 1. Price in Murray buy zone (0-2/8)
    if(mmZone <= 2) signalScore += 3;
    // 2. Price in deep buy zone (0-1/8)
    if(mmZone <= 1) signalScore += 2;
    // 3. VWAP confirmation
    if(price > vwap) signalScore += 2;
    if(Filter_VWAPConfirm && price <= vwap) signalScore -= 3;
    // 4. VWAP trend bullish
    if(vwapTrend == 1) signalScore += 1;
    // 5. Fibo zone confirmation
    if(fiboZone == 1 && mUpTrend()) signalScore += 2;
    if(Filter_FiboConfirm && fiboZone == 0) signalScore -= 2;
    // 6. Price above VWAP +1σ = strong buy
    if(vwapPos >= 1) signalScore += 1;
    // 7. Decision zone breakout (3/8)
    if(mmZone == 3 && price > vwap) { signalScore += 3; direction = 1; }
    // 8. 4/8 pivot bounce (price retraces to 4/8 then goes up)
    if(mmZone == 4 && price > vwap) signalScore += 1;

    // === SELL CONDITIONS ===
    // 1. Price in Murray sell zone (6-8/8)
    if(mmZone >= 6) signalScore -= 3;
    // 2. Price in deep sell zone (7-8/8)
    if(mmZone >= 7) signalScore -= 2;
    // 3. VWAP confirmation
    if(price < vwap) signalScore -= 2;
    if(Filter_VWAPConfirm && price >= vwap) signalScore += 3;
    // 4. VWAP trend bearish
    if(vwapTrend == -1) signalScore -= 1;
    // 5. Fibo zone confirmation
    if((fiboZone == 2 || fiboZone == 4) && !mUpTrend()) signalScore -= 2;
    if(Filter_FiboConfirm && fiboZone == 0) signalScore += 2;
    // 6. Price below VWAP -1σ = strong sell
    if(vwapPos <= -1) signalScore -= 1;
    // 7. Decision zone breakout (5/8)
    if(mmZone == 5 && price < vwap) { signalScore -= 3; direction = -1; }
    // 8. 4/8 pivot bounce (price retraces to 4/8 then goes down)
    if(mmZone == 4 && price < vwap) signalScore -= 1;

    // Override for decision zone breakout
    if(direction != 0) return direction;

    // Threshold
    if(signalScore >= 5) return 1;   // Strong buy
    if(signalScore <= -5) return -1;  // Strong sell

    return 0;
}

bool mUpTrend() {
    return g_Fibo.mUpDirection > 0;
}

//+------------------------------------------------------------------+
//| Refresh Murray + Fibo + VWAP levels                             |
//+------------------------------------------------------------------+
void RefreshLevels() {
    // Murray Math
    g_Murray.Calculate(MM_LookbackBars);

    // Fibonacci
    g_Fibo.DetectSwing(Fibo_Lookback, Fibo_MinSwingPips);

    // VWAP
    g_VWAP.Update(0);
}

//+------------------------------------------------------------------+
//| Order Management                                                |
//+------------------------------------------------------------------+
bool ManageOrders(int signal, double bid, double ask) {
    // Count existing orders
    int buyCount  = CountOrders(g_MagicBuy);
    int sellCount = CountOrders(g_MagicSell);

    double lot = ComputeLotSize(SL_Pips, RiskPercent);
    if(lot < MarketInfo(_Symbol, MODE_MINLOT)) return false;
    if(lot > MarketInfo(_Symbol, MODE_MAXLOT)) lot = MarketInfo(_Symbol, MODE_MAXLOT);

    double slPips = SL_Pips * GetPoint();
    double tpPips = TP_Pips * GetPoint();

    double vwap = g_VWAP.GetVWAP();

    if(signal > 0 && buyCount < MaxOpenOrders) {
        // === BUY ===
        double sl   = NormalizeSL(bid - slPips);
        double tp   = NormalizeTP(bid + tpPips);

        // Validate SL/TP distance
        if(bid - sl < 5 * GetPoint() || tp - bid < 5 * GetPoint()) return false;

        // Check for overlapping Fibo levels
        double slFibo = g_Fibo.GetNearestFibo(sl, 10);
        if(slFibo > 0) {
            // Adjust SL to below Fibo support
            sl = NormalizeSL(slFibo - 5 * GetPoint());
        }

        string cmt = StringFormat("%s BUY | Zone:%d | VWAP:%.5f", 
            EA_Comment, g_Murray.GetCurrentZone(bid), vwap);

        return PlaceOrder(ORDER_TYPE_BUY, ask, sl, tp, lot, g_MagicBuy, cmt);
    }

    if(signal < 0 && sellCount < MaxOpenOrders) {
        // === SELL ===
        double sl   = NormalizeSL(ask + slPips);
        double tp   = NormalizeTP(bid - tpPips);

        if(ask - sl < 5 * GetPoint() || bid - tp < 5 * GetPoint()) return false;

        // Adjust SL to above Fibo resistance
        double slFibo = g_Fibo.GetNearestFibo(sl, 10);
        if(slFibo > 0) {
            sl = NormalizeSL(slFibo + 5 * GetPoint());
        }

        string cmt = StringFormat("%s SELL | Zone:%d | VWAP:%.5f",
            EA_Comment, g_Murray.GetCurrentZone(bid), vwap);

        return PlaceOrder(ORDER_TYPE_SELL, bid, sl, tp, lot, g_MagicSell, cmt);
    }

    return false;
}

bool PlaceOrder(ENUM_ORDER_TYPE type, double price, double sl, double tp, double lot, int magic, string cmt) {
    MqlTradeRequest req = {};
    MqlTradeResult  res = {};

    req.action    = TRADE_ACTION_DEAL;
    req.symbol    = _Symbol;
    req.volume    = lot;
    req.type      = type;
    req.price     = price;
    req.sl        = sl;
    req.tp        = tp;
    req.deviation = 10;
    req.magic     = magic;
    req.comment   = cmt;
    
    bool sent = OrderSend(req, res);
    if(!sent || res.retcode != TRADE_RETCODE_DONE) {
        PrintFormat("OrderSend FAILED! Retcode=%d", res.retcode);
        return false;
    }

    PrintFormat("ORDER PLACED: %s %s %.2f @ %.5f SL=%.5f TP=%.5f | Ticket=#%d",
        cmt, EnumToString(type), lot, price, sl, tp, res.order);
    return true;
}

int CountOrders(int magic) {
    int count = 0;
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) ? OrderSymbol() : "" == _Symbol && OrderMagic() == magic) {
            count++;
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Trailing Stop                                                   |
//+------------------------------------------------------------------+
void ManageTrailing() {
    if(TrailingStart <= 0) return;

    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) ? OrderSymbol() : "" != _Symbol) continue;
        ulong ticket = OrderTicket();
        long  magic  = OrderMagic();
        if(magic != g_MagicBuy && magic != g_MagicSell) continue;

        double openPrice = OrderOpenPrice();
        double curPrice  = OrderClosePrice();
        double sl        = OrderStopLoss();
        double tp        = OrderTakeProfit();
        double pts       = GetPoint();
        ENUM_ORDER_TYPE posType = (ENUM_ORDER_TYPE)OrderType();

        double profitPips = (posType == OP_BUY)
            ? (curPrice - openPrice) / pts
            : (openPrice - curPrice) / pts;

        if(profitPips < TrailingStart) continue;

        double newSL = 0;
        if(posType == OP_BUY) {
            double trailDist = (profitPips - TrailingStart) / pts;
            double trailingMultiple = MathFloor(trailDist / TrailingStep) * TrailingStep;
            newSL = openPrice + (TrailingStart + trailingMultiple - 5) * pts;
        } else {
            double trailDist = (profitPips - TrailingStart) / pts;
            double trailingMultiple = MathFloor(trailDist / TrailingStep) * TrailingStep;
            newSL = openPrice - (TrailingStart + trailingMultiple - 5) * pts;
        }

        newSL = NormalizePrice(newSL);

        // Only modify if new SL is better
        if(posType == OP_BUY && newSL > sl) {
            ModifySL(ticket, newSL);
        } else if(posType == OP_SELL && newSL < sl && sl == 0) {
            ModifySL(ticket, newSL);
        }
    }
}

bool ModifySL(int ticket, double newSL) {
    if(!OrderSelect(ticket, SELECT_BY_TICKET)) return false;
    return OrderModify(ticket, OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrNONE);
}
    req.action  = TRADE_ACTION_SLTP;
    req.position = ticket;
    req.sl       = newSL;
    req.magic    = 0;  // Position mode
    return OrderSend(req, res) && res.retcode == TRADE_RETCODE_DONE;
}

//+------------------------------------------------------------------+
//| Equity Protection                                                |
//+------------------------------------------------------------------+
void ManageEquityProtection() {
    static datetime lastCheck = 0;
    datetime now = TimeCurrent();
    if(now - lastCheck < 60) return;  // Check every 60 seconds
    lastCheck = now;

    double equity = AccountEquity();
    double balance = AccountBalance();

    // Drawdown protection: close all if drawdown > 10%
    if(equity < balance * 0.90) {
        CloseAllOrders(0);
        Print("EQUITY PROTECTION: Drawdown >10%, all orders closed");
    }
}

void CloseAllOrders(int magic) {
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) ? OrderSymbol() : "" != _Symbol) continue;
        if(magic != 0 && OrderMagic() != magic) continue;
        ulong ticket = OrderTicket();
        TradeClose(ticket);
    }
}

bool TradeClose(int ticket) {
    if(!OrderSelect(ticket, SELECT_BY_TICKET)) return false;
    bool result;
    if(OrderType() == OP_BUY) {
    req.action = TRADE_ACTION_DEAL;
    req.position = ticket;
    req.volume = OrderLots();
    req.deviation = 10;
    ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderType();
    req.price = (type == OP_BUY) ? Bid
                                           : Ask;
    req.type = (type == OP_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    return OrderSend(req, res) && res.retcode == TRADE_RETCODE_DONE;
}

//+------------------------------------------------------------------+
//| Time Filter                                                     |
//+------------------------------------------------------------------+
bool IsTradeAllowed() {
    if(TradeHourStart == 0 && TradeHourEnd == 0) return true;
    if(TradeHourStart == TradeHourEnd) return true;

    MqlDateTime dt;
    TimeCurrent(dt);

    if(TradeHourStart == 0) return (dt.hour < TradeHourEnd);
    if(TradeHourEnd == 0)   return (dt.hour >= TradeHourStart);
    if(TradeHourStart < TradeHourEnd) {
        return (dt.hour >= TradeHourStart && dt.hour < TradeHourEnd);
    } else {
        // Wrap around midnight
        return (dt.hour >= TradeHourStart || dt.hour < TradeHourEnd);
    }
}

//+------------------------------------------------------------------+
//| Chart Comment (Dashboard)                                       |
//+------------------------------------------------------------------+
void UpdateChartComment(double bid, double vwap, double spread) {
    int zone = g_Murray.GetCurrentZone(bid);
    string zoneName = "";
    color zoneColor = clrWhite;

    if(zone == 0) { zoneName = "0/8 EXTREME BUY";  zoneColor = clrDarkBlue; }
    else if(zone == 1) { zoneName = "1/8 WEAK BUY"; zoneColor = clrBlue; }
    else if(zone == 2) { zoneName = "2/8 TP BUY";   zoneColor = clrDodgerBlue; }
    else if(zone == 3) { zoneName = "3/8 DECISION BUY"; zoneColor = clrLime; }
    else if(zone == 4) { zoneName = "4/8 PIVOT";    zoneColor = clrWhite; }
    else if(zone == 5) { zoneName = "5/8 DECISION SELL"; zoneColor = clrOrange; }
    else if(zone == 6) { zoneName = "6/8 TP SELL";   zoneColor = clrOrangeRed; }
    else if(zone == 7) { zoneName = "7/8 WEAK SELL"; zoneColor = clrRed; }
    else if(zone == 8) { zoneName = "8/8 EXTREME SELL"; zoneColor = clrDarkRed; }

    int vwapTrend = g_VWAP.GetTrend();
    string trendStr = vwapTrend > 0 ? "BULL" : vwapTrend < 0 ? "BEAR" : "NEUT";

    string txt = StringFormat(
        "Murray Math EA v1.0\n"
        "====================\n"
        "Zone: %s\n"
        "VWAP: %.5f (%s)\n"
        "Price: %.5f\n"
        "Spread: %.1f pts\n"
        "--------------------\n"
        "Fibo Swing: %.5f - %.5f\n"
        "Fibo Zone: %s\n"
        "====================\n"
        "SL: %.1f pips  TP: %.1f pips\n"
        "Risk: %.1f%%\n"
        "====================\n"
        "OHLC H: %.5f\n"
        "OHLC L: %.5f",
        zoneName, vwap, trendStr, bid, spread,
        g_Fibo.mSwingLow, g_Fibo.mSwingHigh,
        FiboZoneName(g_Fibo.InFiboZone(bid)),
        SL_Pips, TP_Pips, RiskPercent,
        iHigh(_Symbol, PERIOD_CURRENT, 0),
        iLow(_Symbol, PERIOD_CURRENT, 0)
    );

    Comment(txt);
}

string FiboZoneName(int zone) {
    if(zone == 0) return "---";
    if(zone == 1) return "GOLDEN (38.2-61.8)";
    if(zone == 2) return "DEEP (78.6)";
    if(zone == 3) return "OTHER";
    return "EXTENSION";
}

//+------------------------------------------------------------------+
    // Delete old objects
    string prefix = "MurrayMath_";
    ObjectsDeleteAll(0, prefix);

    if(MM_ShowZones) DrawMMZones();
    if(Fibo_ShowRetrace || Fibo_ShowExtension) DrawFiboLevels();
    if(VWAP_ShowBands) DrawVWAPBands();
}

void DrawMMZones() {
    string prefix = "MurrayMath_";
    double levels[9];
    g_Murray.GetAllLevels(levels);

    for(int i = 0; i < 8; i++) {
        double top    = levels[i + 1];
        double bottom = levels[i];
        color  col;
        string name;

        if(i <= 2) { col = MM_ColorBuyZone; name = "BUY_ZONE"; }
        else if(i >= 6) { col = MM_ColorSellZone; name = "SELL_ZONE"; }
        else { col = MM_ColorNeutral; name = "NEUTRAL"; }

        string objName = StringFormat("%sZone_%d", prefix, i);
        ObjectCreate(0, objName, OBJ_RECTANGLE, 0, 0, bottom, 0, top);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, col);
        ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetDouble(0, objName, OBJPROP_FILL, true);
        ObjectSetDouble(0, objName, OBJPROP_TRANSPARENT, 85);
        ObjectSetInteger(0, objName, OBJPROP_TIME, 0, TimeCurrent());
    }
}

void DrawFiboLevels() {
    string prefix = "MurrayMath_Fibo";
    double bid = Bid;

    // Retracements
    if(Fibo_ShowRetrace) {
        for(int i = 0; i < 5; i++) {
            double price = g_Fibo.GetRetrace(i);
            string name = StringFormat("%sRetr_%d", prefix, i);
            ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
            ObjectSetInteger(0, name, OBJPROP_COLOR, g_Fibo.GetRetraceInfo(i).clr);
            ObjectSetInteger(0, name, OBJPROP_STYLE, Fibo_LineStyle);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, Fibo_LineWidth);
            ObjectSetString(0, name, OBJPROP_TEXT, g_Fibo.GetRetraceInfo(i).name);
        }
    }

    // Extensions
    if(Fibo_ShowExtension) {
        for(int i = 0; i < 6; i++) {
            double price = g_Fibo.GetExtension(i);
            string name = StringFormat("%sExt_%d", prefix, i);
            ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
            ObjectSetInteger(0, name, OBJPROP_COLOR, g_Fibo.GetExtensionInfo(i).clr);
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, Fibo_LineWidth);
            ObjectSetString(0, name, OBJPROP_TEXT, g_Fibo.GetExtensionInfo(i).name);
        }
    }
}

void DrawVWAPBands() {
    string prefix = "MurrayMath_VWAP";
    double vwap = g_VWAP.GetVWAP();

    // Main VWAP line
    ObjectCreate(0, prefix + "Main", OBJ_HLINE, 0, 0, vwap);
    ObjectSetInteger(0, prefix + "Main", OBJPROP_COLOR, VWAP_Color);
    ObjectSetInteger(0, prefix + "Main", OBJPROP_WIDTH, 2);

    // +1σ and -1σ
    double up1  = g_VWAP.GetUpperBand(1);
    double dn1  = g_VWAP.GetLowerBand(1);
    ObjectCreate(0, prefix + "Up1", OBJ_HLINE, 0, 0, up1);
    ObjectSetInteger(0, prefix + "Up1", OBJPROP_COLOR, C'0,150,255');
    ObjectSetInteger(0, prefix + "Up1", OBJPROP_STYLE, STYLE_DASH);
    ObjectCreate(0, prefix + "Dn1", OBJ_HLINE, 0, 0, dn1);
    ObjectSetInteger(0, prefix + "Dn1", OBJPROP_COLOR, C'0,150,255');
    ObjectSetInteger(0, prefix + "Dn1", OBJPROP_STYLE, STYLE_DASH);

    // +2σ and -2σ
    double up2  = g_VWAP.GetUpperBand(2);
    double dn2  = g_VWAP.GetLowerBand(2);
    ObjectCreate(0, prefix + "Up2", OBJ_HLINE, 0, 0, up2);
    ObjectSetInteger(0, prefix + "Up2", OBJPROP_COLOR, C'100,100,200');
    ObjectSetInteger(0, prefix + "Up2", OBJPROP_STYLE, STYLE_DOT);
    ObjectCreate(0, prefix + "Dn2", OBJ_HLINE, 0, 0, dn2);
    ObjectSetInteger(0, prefix + "Dn2", OBJPROP_COLOR, C'100,100,200');
    ObjectSetInteger(0, prefix + "Dn2", OBJPROP_STYLE, STYLE_DOT);
}
//+------------------------------------------------------------------+
//| Timer (for periodic refresh)                                     |
//+------------------------------------------------------------------+
void OnTimer() {
   // Refresh every 5 seconds
   RefreshLevels();
    RefreshLevels();
}
//+------------------------------------------------------------------+