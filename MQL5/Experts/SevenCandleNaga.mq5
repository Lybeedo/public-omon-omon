//+------------------------------------------------------------------+
//|                              SevenCandleNaga.mq5                  |
//|                                      7NAGA Trading System         |
//|                                         Version 1.0.0            |
//+------------------------------------------------------------------+
#property copyright "7NAGA Trading System"
#property link      "https://7naga.dev"
#property version   "1.0.0"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== TIME SETTINGS (WIB) ==="
input int    InpAnalysisHour   = 9;       // Analysis Hour (WIB)
input int    InpAnalysisMin   = 30;      // Analysis Minute (WIB)
input int    InpExpiryHour    = 17;      // Expiry Hour (WIB)
input int    InpExpiryMin     = 0;       // Expiry Minute (WIB)
input int    InpTimeOffset    = 7;       // GMT Offset WIB (+7)

input group "=== ORDER SETTINGS ==="
input double InpLotSize       = 0.01;    // Base Lot per TP Zone
input int    InpBuyOffsetPts  = 100;     // Buy Stop offset from High (points)
input int    InpSellOffsetPts = 25;      // Sell Stop offset from Low (points)
input int    InpMagicNumber   = 77777;   // Magic Number
input ulong  InpDeviation     = 50;      // Slippage deviation (points)

input group "=== TP ZONES ==="
input double InpTP1Pips        = 10.0;   // TP1 Pips
input double InpTP2Pips        = 15.0;   // TP2 Pips (MIN)
input double InpTP3Pips        = 30.0;   // TP3 Pips
input double InpTP4Pips        = 50.0;   // TP4 Pips
input double InpTP5Pips        = 100.0;  // TP5 Pips
input double InpTP6Pips        = 200.0;  // TP6 Pips

input group "=== DISTANCE FILTER ==="
input int    InpMinDistance   = 70;      // Min distance in pips
input int    InpMaxDistance   = 200;     // Max distance in pips

input group "=== SL MODE ==="
input bool   InpSLModeOneshot = true;    // Oneshot SL (manual)

input group "=== FORBIDDEN DATES (YYYY,MM,DD) ==="
input string InpForbiddenDates = "";     // Comma-separated: YYYY.MM.DD

input group "=== NEWS FILTER ==="
input bool   InpSkipNFP        = true;   // Skip NFP days
input bool   InpSkipFOMC       = true;   // Skip FOMC days
input bool   InpSkipCPI        = true;   // Skip US CPI days
input bool   InpSkipMonday     = true;   // Skip Monday
input bool   InpSkipUSHoliday  = true;   // Skip US Federal Holidays

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
CTrade  g_trade;
datetime g_lastTradeDate = 0;
datetime g_lastAnalysisTime = 0;

// State machine
enum ENUM_EA_STATE {STATE_IDLE, STATE_ANALYZING, STATE_PLACING, STATE_ACTIVE, STATE_COMPLETED, STATE_SKIPPED};
ENUM_EA_STATE g_eState = STATE_IDLE;

// Order tracking
struct SOrderInfo {
    double  buyStopPrice;
    double  sellStopPrice;
    double  slBuyStop;
    double  slSellStop;
    double  spreadPips;
    double  tpIdealPips;
    double  tpIdealZone;
    double  high;
    double  low;
    datetime expiryTime;
    bool    buyTriggered;
    bool    sellTriggered;
    double  activeBuyPrice;
    double  activeSellPrice;
};

SOrderInfo g_order;

// TP zone info
struct STPZone {
    double pips;
    double priceOffset;
    double lot;
    bool   hit;
};

STPZone g_zones[6];

//+------------------------------------------------------------------+
//| EXPERT INITIALIZATION                                            |
//+------------------------------------------------------------------+
int OnInit() {
    g_trade.SetExpertMagicNumber(InpMagicNumber);
    g_trade.SetDeviationInPoints(InpDeviation);
    g_trade.SetTypeFilling(ORDER_FILLING_FOK);
    g_trade.SetAsyncMode(false);

    g_zones[0].pips = InpTP1Pips;  g_zones[0].lot = InpLotSize;
    g_zones[1].pips = InpTP2Pips;  g_zones[1].lot = InpLotSize;
    g_zones[2].pips = InpTP3Pips;  g_zones[2].lot = InpLotSize;
    g_zones[3].pips = InpTP4Pips;  g_zones[3].lot = InpLotSize;
    g_zones[4].pips = InpTP5Pips;  g_zones[4].lot = InpLotSize;
    g_zones[5].pips = InpTP6Pips;  g_zones[5].lot = InpLotSize;

    g_order.expiryTime = D'2099.12.31 17:00:00';

    Print("=== 7NAGA EA Initialized ===");
    Print("Magic: ", InpMagicNumber);
    Print("Buy Offset: +", InpBuyOffsetPts, " pts | Sell Offset: -", InpSellOffsetPts, " pts");
    Print("TP Zones: ", InpTP1Pips, " / ", InpTP2Pips, " / ", InpTP3Pips, " / ",
          InpTP4Pips, " / ", InpTP5Pips, " / ", InpTP6Pips);

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| EXPERT DEINIT                                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    DeleteAllPending();
    Print("=== 7NAGA EA Deinitialized ===");
}

//+------------------------------------------------------------------+
//| EXPERT TICK                                                      |
//+------------------------------------------------------------------+
void OnTick() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);

    int wibHour = (dt.hour - InpTimeOffset + 24) % 24;
    int wibDay  = dt.day_of_week;

    if(g_eState == STATE_ACTIVE && TimeCurrent() >= g_order.expiryTime) {
        ExpireAllPositions();
        return;
    }

    if(wibHour == InpAnalysisHour && dt.min == InpAnalysisMin && g_lastAnalysisTime != (int)TimeCurrent()/60) {
        g_lastAnalysisTime = (int)TimeCurrent()/60;

        if(g_eState == STATE_IDLE || g_eState == STATE_COMPLETED || g_eState == STATE_SKIPPED) {
            RunAnalysis();
        }
    }

    if(g_eState == STATE_ACTIVE) {
        TrackTPCheck();
    }
}

//+------------------------------------------------------------------+
//| ANALYSIS ROUTINE                                                 |
//+------------------------------------------------------------------+
void RunAnalysis() {
    Print("=== 7NAGA ANALYSIS STARTED ===");
    g_eState = STATE_ANALYZING;

    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    int wibDay = (dt.day_of_week + 6) % 7 + 1;
    if(InpSkipMonday && wibDay == 1) {
        Print("❌ SKIPPED: Monday");
        g_eState = STATE_SKIPPED;
        return;
    }

    if(IsForbiddenDate()) {
        Print("❌ SKIPPED: Forbidden Date");
        g_eState = STATE_SKIPPED;
        return;
    }

    if(InpSkipUSHoliday && IsUSHoliday()) {
        Print("❌ SKIPPED: US Holiday");
        g_eState = STATE_SKIPPED;
        return;
    }

    if((InpSkipNFP || InpSkipFOMC || InpSkipCPI) && IsHighImpactNewsDay()) {
        Print("❌ SKIPPED: High Impact News Day");
        g_eState = STATE_SKIPPED;
        return;
    }

    MqlDateTime today;
    TimeToStruct(TimeCurrent(), today);
    datetime todayDate = StringToTime(StringFormat("%04d.%02d.%02d", today.year, today.mon, today.day));
    if(g_lastTradeDate == todayDate) {
        Print("⏳ Already traded today: ", DateToString(todayDate));
        g_eState = STATE_COMPLETED;
        return;
    }

    double high, low;
    if(!Get7CandleLevels(high, low)) {
        Print("❌ Failed to get 7 candle data");
        g_eState = STATE_IDLE;
        return;
    }

    double roundedHigh = RoundToMultiple5_Up(high);
    double roundedLow  = RoundToMultiple5_Down(low);

    double buyStop  = NormalizeDouble(roundedHigh + InpBuyOffsetPts * Point(), Digits());
    double sellStop = NormalizeDouble(roundedLow  - InpSellOffsetPts * Point(), Digits());

    double spreadPips = (buyStop - sellStop) / Point() / 10.0;

    Print("High: ", high, " → Rounded UP: ", roundedHigh);
    Print("Low:  ", low,  " → Rounded DOWN: ", roundedLow);
    Print("Buy Stop:  ", buyStop, " (+", InpBuyOffsetPts, " pts from ", roundedHigh, ")");
    Print("Sell Stop: ", sellStop, " (-", InpSellOffsetPts, " pts from ", roundedLow, ")");
    Print("Spread: ", DoubleToString(spreadPips, 1), " pips");

    if(spreadPips < InpMinDistance || spreadPips > InpMaxDistance) {
        Print("❌ SKIPPED: Distance ", DoubleToString(spreadPips,1), " pips outside [",
              InpMinDistance, "-", InpMaxDistance, "] range");
        g_eState = STATE_SKIPPED;
        return;
    }

    double tpIdealPips = spreadPips / 2.0;
    double tpIdealZone = GetNearestTPZone(tpIdealPips);

    Print("TP Ideal: ", DoubleToString(tpIdealPips,1), " pips → Zone ", (int)tpIdealZone,
          " (", GetZonePips(tpIdealZone), " pips)");

    g_order.high         = high;
    g_order.low          = low;
    g_order.buyStopPrice  = buyStop;
    g_order.sellStopPrice = sellStop;
    g_order.slSellStop    = buyStop;
    g_order.slBuyStop     = sellStop;
    g_order.spreadPips    = spreadPips;
    g_order.tpIdealPips   = tpIdealPips;
    g_order.tpIdealZone  = tpIdealZone;
    g_order.buyTriggered  = false;
    g_order.sellTriggered = false;

    MqlDateTime exp;
    TimeToStruct(TimeCurrent(), exp);
    exp.hour = InpExpiryHour;
    exp.min  = InpExpiryMin;
    exp.sec  = 0;
    g_order.expiryTime = StructToTime(exp);

    g_eState = STATE_PLACING;
    PlacePendingOrders();

    g_lastTradeDate = todayDate;
}

//+------------------------------------------------------------------+
//| GET 7 CANDLE LEVELS                                              |
//+------------------------------------------------------------------+
bool Get7CandleLevels(double &high, double &low) {
    high = 0;
    low  = DBL_MAX;

    for(int i = 1; i <= 7; i++) {
        double h = iHigh(_Symbol, PERIOD_CURRENT, i);
        double l = iLow(_Symbol, PERIOD_CURRENT, i);
        if(h > high) high = h;
        if(l < low)  low  = l;
    }

    if(high <= 0 || low >= DBL_MAX || high <= low) return false;

    Print("7 Candle Range: High=", high, " Low=", low);
    return true;
}

//+------------------------------------------------------------------+
//| ROUND UP TO MULTIPLE OF 5 (HIGH / Buy Stop)                     |
//| 02→05, 03→05, 04→05, 07→10, 08→10, 09→10                        |
//+------------------------------------------------------------------+
double RoundToMultiple5_Up(double price) {
    double scaled = price * 100.0;
    double last2  = MathFmod(scaled, 100.0);

    if(last2 <= 5.0) {
        scaled = MathFloor(scaled / 100.0) * 100.0 + 5.0;
    } else {
        scaled = MathFloor(scaled / 100.0) * 100.0 + 10.0;
    }
    return scaled / 100.0;
}

//+------------------------------------------------------------------+
//| ROUND DOWN TO MULTIPLE OF 5 (LOW / Sell Stop)                   |
//| 03→00, 07→05, 02→00, 05→05                                       |
//+------------------------------------------------------------------+
double RoundToMultiple5_Down(double price) {
    double scaled = price * 100.0;
    double last2  = MathFmod(scaled, 100.0);

    if(last2 < 5.0) {
        scaled = MathFloor(scaled / 100.0) * 100.0;
    } else if(last2 <= 5.0) {
        scaled = MathFloor(scaled / 100.0) * 100.0 + 5.0;
    } else {
        scaled = MathFloor(scaled / 100.0) * 100.0 + 5.0;
    }
    return scaled / 100.0;
}

//+------------------------------------------------------------------+
//| PLACE PENDING ORDERS                                             |
//+------------------------------------------------------------------+
void PlacePendingOrders() {
    DeleteAllPending();

    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    MqlTradeRequest request = {};
    MqlTradeResult  result   = {};

    if(g_order.buyStopPrice <= ask) {
        Print("⚠️ Buy Stop price ", g_order.buyStopPrice, " <= Ask ", ask);
        g_order.buyStopPrice = ask + InpBuyOffsetPts * Point();
    }

    ZeroMemory(request);
    request.action    = TRADE_ACTION_PENDING;
    request.symbol    = _Symbol;
    request.volume    = InpLotSize;
    request.type      = ORDER_TYPE_BUY_STOP;
    request.price     = g_order.buyStopPrice;
    request.sl        = g_order.slSellStop;
    request.tp        = 0;
    request.magic     = InpMagicNumber;
    request.expiration = (int)g_order.expiryTime;
    request.comment   = "7NAGA BuyStop";

    if(!OrderSend(request, result)) {
        Print("❌ Buy Stop order failed: ", result.comment);
    } else {
        Print("✅ BUY STOP placed at ", g_order.buyStopPrice, " | SL=", g_order.slSellStop, " | Spread=", DoubleToString(g_order.spreadPips,1), " pips");
    }

    if(g_order.sellStopPrice >= bid) {
        Print("⚠️ Sell Stop price ", g_order.sellStopPrice, " >= Bid ", bid);
        g_order.sellStopPrice = bid - InpSellOffsetPts * Point();
    }

    ZeroMemory(request);
    request.action    = TRADE_ACTION_PENDING;
    request.symbol    = _Symbol;
    request.volume    = InpLotSize;
    request.type      = ORDER_TYPE_SELL_STOP;
    request.price     = g_order.sellStopPrice;
    request.sl        = g_order.slBuyStop;
    request.tp        = 0;
    request.magic     = InpMagicNumber;
    request.expiration = (int)g_order.expiryTime;
    request.comment   = "7NAGA SellStop";

    if(!OrderSend(request, result)) {
        Print("❌ Sell Stop order failed: ", result.comment);
    } else {
        Print("✅ SELL STOP placed at ", g_order.sellStopPrice, " | SL=", g_order.slBuyStop, " | Spread=", DoubleToString(g_order.spreadPips,1), " pips");
    }

    g_eState = STATE_ACTIVE;
    Print("=== 7NAGA ORDERS PLACED ===");
    Print("Expiry: ", DateTimeToString(g_order.expiryTime));
    Print("TP Ideal Zone: ", (int)g_order.tpIdealZone, " (", GetZonePips(g_order.tpIdealZone), " pips)");
}

//+------------------------------------------------------------------+
//| TRACK TP ZONES                                                   |
//+------------------------------------------------------------------+
void TrackTPCheck() {
    double totalBuyLots  = 0;
    double totalSellLots = 0;

    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(PositionGetSymbol(i) != _Symbol) continue;
        if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
            totalBuyLots += PositionGetDouble(POSITION_VOLUME);
        } else {
            totalSellLots += PositionGetDouble(POSITION_VOLUME);
        }
    }

    if(totalBuyLots > 0 || totalSellLots > 0) {
        for(int z = 0; z < 6; z++) {
            if(g_zones[z].hit) continue;
        }
        if(InpSLModeOneshot) {
            CancelOppositePending(totalBuyLots > 0, totalSellLots > 0);
        }
    }
}

//+------------------------------------------------------------------+
//| CANCEL OPPOSITE PENDING (Switching Mode)                          |
//+------------------------------------------------------------------+
void CancelOppositePending(bool buyActive, bool sellActive) {
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        if(OrderSelect(i) == false) continue;
        if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
        if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;

        ulong ticket = OrderGetInteger(ORDER_TICKET);

        if(buyActive && OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP) {
            g_trade.OrderDelete(ticket);
            Print("🛑 Cancelled opposite SELL STOP (Buy is active)");
        }
        else if(sellActive && OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP) {
            g_trade.OrderDelete(ticket);
            Print("🛑 Cancelled opposite BUY STOP (Sell is active)");
        }
    }
}

//+------------------------------------------------------------------+
//| DELETE ALL PENDING ORDERS                                        |
//+------------------------------------------------------------------+
void DeleteAllPending() {
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        if(OrderSelect(i) == false) continue;
        if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
        if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
        int type = (int)OrderGetInteger(ORDER_TYPE);
        if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP) {
            g_trade.OrderDelete(OrderGetInteger(ORDER_TICKET));
        }
    }
}

//+------------------------------------------------------------------+
//| EXPIRE ALL POSITIONS                                             |
//+------------------------------------------------------------------+
void ExpireAllPositions() {
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(PositionGetSymbol(i) != _Symbol) continue;
        if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        g_trade.PositionClose(PositionGetInteger(POSITION_TICKET));
    }
    DeleteAllPending();
    Print("⏰ 17:00 WIB — All positions expired");
    g_eState = STATE_COMPLETED;
}

//+------------------------------------------------------------------+
//| GET NEAREST TP ZONE                                              |
//+------------------------------------------------------------------+
double GetNearestTPZone(double pips) {
    double zones[] = {InpTP1Pips, InpTP2Pips, InpTP3Pips, InpTP4Pips, InpTP5Pips, InpTP6Pips};
    double bestZone = 2;
    double minDiff = MathAbs(pips - InpTP2Pips);
    for(int i = 0; i < 6; i++) {
        double diff = MathAbs(pips - zones[i]);
        if(diff < minDiff) {
            minDiff = diff;
            bestZone = i + 1;
        }
    }
    return bestZone;
}

//+------------------------------------------------------------------+
//| GET ZONE PIPS                                                    |
//+------------------------------------------------------------------+
double GetZonePips(double zone) {
    int idx = (int)zone - 1;
    if(idx < 0 || idx >= 6) return InpTP2Pips;
    return g_zones[idx].pips;
}

//+------------------------------------------------------------------+
//| IS FORBIDDEN DATE                                                |
//+------------------------------------------------------------------+
bool IsForbiddenDate() {
    if(InpForbiddenDates == "") return false;
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    string todayStr = StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day);
    string dates[];
    int count = StringSplit(InpForbiddenDates, ',', dates);
    for(int i = 0; i < count; i++) {
        string d = StringTrim(dates[i]);
        if(d == todayStr) return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| IS US HOLIDAY                                                    |
//+------------------------------------------------------------------+
bool IsUSHoliday() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    int month = dt.mon;
    int day   = dt.day;
    if(month == 1 && day == 1)  return true;
    if(month == 7 && day == 4)  return true;
    if(month == 12 && day == 25) return true;
    if(month == 11 && day >= 22 && day <= 28 && dt.day_of_week == 4) return true;
    return false;
}

//+------------------------------------------------------------------+
//| IS HIGH IMPACT NEWS DAY                                          |
//+------------------------------------------------------------------+
bool IsHighImpactNewsDay() {
    return false;
}

//+------------------------------------------------------------------+
//| UTILITY                                                          |
//+------------------------------------------------------------------+
string DateTimeToString(datetime dt) {
    MqlDateTime st;
    TimeToStruct(dt, st);
    return StringFormat("%04d-%02d-%02d %02d:%02d:%02d", st.year, st.mon, st.day, st.hour, st.min, st.sec);
}

string DateToString(datetime dt) {
    MqlDateTime st;
    TimeToStruct(dt, st);
    return StringFormat("%04d.%02d.%02d", st.year, st.mon, st.day);
}
//+------------------------------------------------------------------+