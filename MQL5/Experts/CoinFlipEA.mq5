//+------------------------------------------------------------------+
//|                           CoinFlipEA.mq5                          |
//|                          Coin Flip Trading Experiment              |
//|                        500 → 5000 (RR 1:2)                        |
//+------------------------------------------------------------------+
#property copyright "Coin Flip EA"
#property link      "https://github.com/Lybeedo/public-omon-omon"
#property version   "1.1.0"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== CAPITAL & TARGET ==="
input double InpStartCapital  = 500.0;     // Initial capital
input double InpTargetCapital = 5000.0;    // Target capital
input double InpMinCapital    = 0.0;       // Stop if capital reaches this
input string InpCurrency      = "";        // Currency (auto-detect if empty)

input group "=== RISK & REWARD ==="
input double InpRiskPerTrade  = 50.0;      // Risk per trade (SL in currency)
input double InpRewardPerTrade = 100.0;    // Reward per trade (TP in currency)
input double InpRiskReward    = 2.0;       // Risk:Reward ratio (default 1:2)

input group "=== FLIP MODE ==="
input bool   InpToggleBuy     = true;      // Enable BUY direction (Heads)
input bool   InpToggleSell    = true;      // Enable SELL direction (Tails)
input bool   InpInstantFlip   = false;     // false=wait new candle, true=instant after close
input ENUM_TIMEFRAMES InpFlipTimeframe = PERIOD_M1; // Timeframe for flip trigger

input group "=== COIN FLIP ==="
input int    InpHeadsValue    = 500;       // Heads value (Buy)
input int    InpTailsValue    = 0;         // Tails value (Sell/Garuda)

input group "=== LOT SETTINGS ==="
input double InpMinLot        = 0.01;       // Minimum lot
input double InpMaxLot        = 1.0;        // Maximum lot

input group "=== TRADING ==="
input int    InpMagicNumber   = 88888;     // Magic Number
input ulong  InpDeviation     = 50;        // Slippage (points)
input int    InpMaxTrades     = 100;       // Max trades per session (0 = unlimited)
input int    InpMaxDailyTrades = 10;       // Max trades per day (0 = unlimited)
input bool   InpCloseOnTarget  = true;     // Stop when target reached
input bool   InpCloseOnBust    = true;     // Stop when busted

input group "=== TIME SCHEDULE ==="
input bool   InpEnableAsia    = false;     // Enable Asia session
input int    InpAsiaStartHH   = 7;         // Asia start hour (HH)
input int    InpAsiaStartMM   = 0;         // Asia start minute (MM)
input int    InpAsiaEndHH     = 15;        // Asia end hour (HH)
input int    InpAsiaEndMM     = 0;         // Asia end minute (MM)

input bool   InpEnableLondon  = false;     // Enable London session
input int    InpLondonStartHH = 8;         // London start hour
input int    InpLondonStartMM = 0;         // London start minute
input int    InpLondonEndHH   = 17;        // London end hour
input int    InpLondonEndMM   = 0;         // London end minute

input bool   InpEnableNY      = false;    // Enable New York session
input int    InpNYStartHH     = 13;        // NY start hour
input int    InpNYStartMM     = 30;        // NY start minute
input int    InpNYEndHH       = 21;        // NY end hour
input int    InpNYEndMM       = 0;         // NY end minute

input bool   InpUseAnyTime    = true;      // Ignore schedule (trade anytime)

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
CTrade  g_trade;

// Auto-detect digit & pip
int    GDigits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
double GPoint  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
double GPip    = (GDigits == 3 || GDigits == 5) ? GPoint * 10 : GPoint;

// Currency
string g_currency = "";

// Capital tracking
double g_currentCapital = 0;
double g_startCapital   = 0;
int    g_totalTrades    = 0;
int    g_dailyTrades    = 0;
int    g_wins           = 0;
int    g_losses         = 0;
double g_totalPnL       = 0;

// Flip tracking
int    g_lastFlipBar    = -1;         // Bar index of last flip (-1 = not set)
datetime g_lastFlipTime  = 0;         // Time of last flip

// State
enum ENUM_CF_STATE {STATE_WAITING, STATE_READY, STATE_IN_TRADE, STATE_TARGET_REACHED, STATE_BUSTED};
ENUM_CF_STATE g_state = STATE_WAITING;

datetime g_sessionStart    = 0;
datetime g_lastTradeTime   = 0;
datetime g_lastDailyReset  = 0;

// Order tracking
double g_entryPrice      = 0;
double g_slPrice          = 0;
double g_tpPrice          = 0;
double g_positionLot      = 0;
bool   g_positionOpen     = false;
ulong  g_positionTicket   = 0;

//+------------------------------------------------------------------+
//| EXPERT INITIALIZATION                                            |
//+------------------------------------------------------------------+
int OnInit() {
    g_trade.SetExpertMagicNumber(InpMagicNumber);
    g_trade.SetDeviationInPoints(InpDeviation);
    g_trade.SetTypeFilling(ORDER_FILLING_FOK);
    g_trade.SetAsyncMode(false);

    // Auto-detect currency
    if(StringLen(InpCurrency) == 0) {
        string accCurrency = AccountInfoString(ACCOUNT_CURRENCY);
        g_currency = (StringLen(accCurrency) > 0) ? accCurrency : "USD";
    } else {
        g_currency = InpCurrency;
    }

    g_startCapital   = InpStartCapital;
    g_currentCapital = InpStartCapital;
    g_sessionStart   = TimeCurrent();
    g_lastDailyReset = GetDayStart(TimeCurrent());

    // Init last bar — use -1 so first tick always triggers flip
    g_lastFlipBar = iBarShift(_Symbol, InpFlipTimeframe, TimeCurrent()) + 1;

    Print("=== COIN FLIP EA v1.1.0 INITIALIZED ===");
    Print("Start Capital: ", DoubleToStr(InpStartCapital,2), " ", g_currency);
    Print("Target:       ", DoubleToStr(InpTargetCapital,2), " ", g_currency,
          " (", DoubleToStr(InpTargetCapital/InpStartCapital,1), "x)");
    Print("Risk:         ", DoubleToStr(InpRiskPerTrade,2), " ", g_currency);
    Print("Reward:       ", DoubleToStr(InpRewardPerTrade,2), " ", g_currency);
    Print("RR Ratio:     1:", DoubleToStr(InpRiskReward,1));
    Print("Heads(", InpHeadsValue, ")=BUY | Tails(", InpTailsValue, ")=SELL");
    Print("Toggle: Buy=", InpToggleBuy, " | Sell=", InpToggleSell);
    Print("Flip mode: ", InpInstantFlip ? "INSTANT" : "NEW CANDLE");
    Print("Flip TF:   ", EnumToString(InpFlipTimeframe));
    Print("Asia:    ", InpEnableAsia  ? "ON" : "OFF", " ", FormatHHMM(InpAsiaStartHH,InpAsiaStartMM),
          "-", FormatHHMM(InpAsiaEndHH,InpAsiaEndMM));
    Print("London:  ", InpEnableLondon ? "ON" : "OFF", " ", FormatHHMM(InpLondonStartHH,InpLondonStartMM),
          "-", FormatHHMM(InpLondonEndHH,InpLondonEndMM));
    Print("NY:      ", InpEnableNY     ? "ON" : "OFF", " ", FormatHHMM(InpNYStartHH,InpNYStartMM),
          "-", FormatHHMM(InpNYEndHH,InpNYEndMM));
    Print("AnyTime: ", InpUseAnyTime);
    Print("Expected EV/trade: ", DoubleToStr(CalculateExpectedValue(),2), " ", g_currency);
    Print("==========================================");

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| EXPERT DEINIT                                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Comment("");
    CloseAllPositions();
    Print("=== COIN FLIP EA DEINITIALIZED ===");
    PrintFinalStats();
}

//+------------------------------------------------------------------+
//| EXPERT TICK                                                      |
//+------------------------------------------------------------------+
void OnTick() {
    datetime now = TimeCurrent();

    // Reset daily counter
    if(GetDayStart(now) > g_lastDailyReset) {
        g_dailyTrades = 0;
        g_lastDailyReset = GetDayStart(now);
    }

    // Check terminal states
    if(g_state == STATE_TARGET_REACHED || g_state == STATE_BUSTED) {
        return;
    }

    // Always start as ready
    if(g_state == STATE_WAITING) {
        g_state = STATE_READY;
    }

    // Check capital targets
    if(InpCloseOnTarget && g_currentCapital >= InpTargetCapital) {
        CloseAllPositions();
        g_state = STATE_TARGET_REACHED;
        Print("================================");
        Print("🎯 TARGET REACHED! ", DoubleToStr(g_currentCapital,2), " ", g_currency);
        PrintFinalStats();
        return;
    }
    if(InpCloseOnBust && g_currentCapital <= InpMinCapital) {
        CloseAllPositions();
        g_state = STATE_BUSTED;
        Print("================================");
        Print("💀 BUSTED! ", DoubleToStr(g_currentCapital,2), " ", g_currency);
        PrintFinalStats();
        return;
    }

    // Check schedule
    if(!IsInSchedule(now)) {
        return;
    }

    // Check trade limits
    if(InpMaxTrades > 0 && g_totalTrades >= InpMaxTrades) {
        Print("Max trades reached (", InpMaxTrades, "). Stopping.");
        g_state = STATE_TARGET_REACHED;
        return;
    }
    if(InpMaxDailyTrades > 0 && g_dailyTrades >= InpMaxDailyTrades) {
        return;
    }

    // Check open position
    if(g_positionOpen) {
        CheckPosition();
        return;
    }

    // Open new trade
    if(g_state == STATE_READY && !g_positionOpen) {
        // Check flip trigger (new candle or instant)
        if(ShouldFlip(now)) {
            OpenNewTrade();
        }
    }
}

//+------------------------------------------------------------------+
//| SHOULD FLIP — returns true if conditions for new flip are met    |
//+------------------------------------------------------------------+
bool ShouldFlip(datetime now) {
    if(!InpInstantFlip) {
        // Wait for new candle on selected timeframe
        int currentBar = iBarShift(_Symbol, InpFlipTimeframe, now);
        if(currentBar <= g_lastFlipBar) {
            return false; // Same bar, no flip yet
        }
        g_lastFlipBar = currentBar;
        g_lastFlipTime = now;
        return true;
    } else {
        // Instant flip — flip immediately after position close
        // Only flip once per tick when state is READY
        // Use a guard: only flip if at least 1 second passed since last flip
        // to avoid rapid re-entry within same candle
        if(now - g_lastFlipTime < 1) {
            return false;
        }
        g_lastFlipTime = now;
        return true;
    }
}

//+------------------------------------------------------------------+
//| IS IN SCHEDULE                                                   |
//+------------------------------------------------------------------+
bool IsInSchedule(datetime dt) {
    if(InpUseAnyTime) return true;

    int currentMins = (dt.hour * 60) + dt.min;

    // Asia: default 07:00-15:00 WIB (convert to broker server time)
    if(InpEnableAsia) {
        int startMins = InpAsiaStartHH * 60 + InpAsiaStartMM;
        int endMins   = InpAsiaEndHH   * 60 + InpAsiaEndMM;
        if(IsInRange(currentMins, startMins, endMins)) return true;
    }

    // London: default 08:00-17:00
    if(InpEnableLondon) {
        int startMins = InpLondonStartHH * 60 + InpLondonStartMM;
        int endMins   = InpLondonEndHH   * 60 + InpLondonEndMM;
        if(IsInRange(currentMins, startMins, endMins)) return true;
    }

    // NY: default 13:30-21:00
    if(InpEnableNY) {
        int startMins = InpNYStartHH * 60 + InpNYStartMM;
        int endMins   = InpNYEndHH   * 60 + InpNYEndMM;
        if(IsInRange(currentMins, startMins, endMins)) return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| IS IN RANGE                                                      |
//+------------------------------------------------------------------+
bool IsInRange(int current, int start, int end) {
    // Handle overnight ranges (e.g., 21:00-06:00)
    if(end < start) {
        return (current >= start || current <= end);
    }
    return (current >= start && current <= end);
}

//+------------------------------------------------------------------+
//| OPEN NEW TRADE                                                   |
//+------------------------------------------------------------------+
void OpenNewTrade() {
    // Coin flip using MathRand — no manual seed needed
    // MathRand uses internal LCG, ~50/50 distribution
    int flipValue = (MathRand() % 2 == 0) ? InpHeadsValue : InpTailsValue;
    bool isBuy = (flipValue == InpHeadsValue);

    // Check toggle
    if(!InpToggleBuy && isBuy) {
        // BUY disabled, flip to opposite
        isBuy = false;
        flipValue = InpTailsValue;
    } else if(!InpToggleSell && !isBuy) {
        // SELL disabled, flip to opposite
        isBuy = true;
        flipValue = InpHeadsValue;
    }

    // If both toggles are off, skip
    if(!InpToggleBuy && !InpToggleSell) {
        Print("⚠️ Both BUY and SELL disabled. Skipping.");
        return;
    }

    Print("--------------------------------");
    Print("COIN FLIP #", g_totalTrades + 1, " | Result: ", flipValue,
          " | ", isBuy ? "BUY 🟢" : "SELL 🔴");

    double lot = CalculateLot();
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = GPoint;

    // Calculate SL/TP in price from currency risk
    double pipValuePerLot = GetContractSize() * GPip;
    double slPoints = InpRiskPerTrade / pipValuePerLot;
    double tpPoints = InpRewardPerTrade / pipValuePerLot;

    double entryPrice, slPrice, tpPrice;

    if(isBuy) {
        entryPrice = ask;
        slPrice    = NormalizeDouble(entryPrice - slPoints * point, Digits());
        tpPrice    = NormalizeDouble(entryPrice + tpPoints * point, Digits());
    } else {
        entryPrice = bid;
        slPrice    = NormalizeDouble(entryPrice + slPoints * point, Digits());
        tpPrice    = NormalizeDouble(entryPrice - tpPoints * point, Digits());
    }

    ENUM_ORDER_TYPE type = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

    bool success = g_trade.PositionOpen(_Symbol, type, lot, entryPrice, slPrice, tpPrice,
                                        "CF#" + IntegerToString(g_totalTrades + 1));

    if(success) {
        g_positionTicket = g_trade.ResultOrder();
        g_entryPrice     = entryPrice;
        g_slPrice        = slPrice;
        g_tpPrice        = tpPrice;
        g_positionLot    = lot;
        g_positionOpen   = true;
        g_lastTradeTime  = TimeCurrent();
        g_state          = STATE_IN_TRADE;

        Print("📊 Entry: ", DoubleToStr(entryPrice, Digits()),
              " | SL: ", DoubleToStr(slPrice, Digits()), " (", DoubleToStr(slPoints, 0), " pts)",
              " | TP: ", DoubleToStr(tpPrice, Digits()), " (", DoubleToStr(tpPoints, 0), " pts)",
              " | Lot: ", DoubleToStr(lot, 2));
        Print("💰 Capital: ", DoubleToStr(g_currentCapital, 2), " ", g_currency);
    } else {
        Print("❌ Open failed: ", g_trade.ResultComment());
    }
}

//+------------------------------------------------------------------+
//| CHECK POSITION                                                   |
//+------------------------------------------------------------------+
void CheckPosition() {
    if(!g_positionOpen) return;

    if(!PositionSelectByTicket(g_positionTicket)) {
        g_positionOpen = false;
        return;
    }

    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    int    type         = (int)PositionGetInteger(POSITION_TYPE);

    bool hitSL = (type == POSITION_TYPE_BUY && currentPrice <= g_slPrice) ||
                 (type == POSITION_TYPE_SELL && currentPrice >= g_slPrice);
    bool hitTP = (type == POSITION_TYPE_BUY && currentPrice >= g_tpPrice) ||
                 (type == POSITION_TYPE_SELL && currentPrice <= g_tpPrice);

    if(hitSL || hitTP) {
        g_trade.PositionClose(g_positionTicket);

        if(hitTP) {
            g_wins++;
            g_currentCapital += InpRewardPerTrade;
            Print("✅ WIN! +", DoubleToStr(InpRewardPerTrade, 2), " ", g_currency);
        } else {
            g_losses++;
            g_currentCapital -= InpRiskPerTrade;
            Print("❌ LOSS! -", DoubleToStr(InpRiskPerTrade, 2), " ", g_currency);
        }

        g_totalTrades++;
        g_dailyTrades++;
        g_totalPnL += (hitTP ? InpRewardPerTrade : -InpRiskPerTrade);

        Print("📈 Capital: ", DoubleToStr(g_currentCapital, 2), " ", g_currency,
              " | W:", g_wins, " L:", g_losses,
              " | Winrate: ", DoubleToStr(GetWinrate(), 1), "%");

        g_positionOpen = false;
        g_state = STATE_READY;
    }
}

//+------------------------------------------------------------------+
//| CALCULATE LOT                                                    |
//+------------------------------------------------------------------+
double CalculateLot() {
    double pipValuePerLot = GetContractSize() * GPip;
    double slPoints = InpRiskPerTrade / pipValuePerLot;
    double lot = InpRiskPerTrade / (slPoints * GPoint * GetContractSize());
    lot = NormalizeDouble(MathMax(lot, InpMinLot), 2);
    lot = MathMin(lot, InpMaxLot);
    return lot;
}

//+------------------------------------------------------------------+
//| GET CONTRACT SIZE                                                |
//+------------------------------------------------------------------+
double GetContractSize() {
    double cs = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    return (cs > 0) ? cs : 100.0;
}

//+------------------------------------------------------------------+
//| CALCULATE EXPECTED VALUE                                         |
//+------------------------------------------------------------------+
double CalculateExpectedValue() {
    return (0.5 * InpRewardPerTrade) - (0.5 * InpRiskPerTrade);
}

//+------------------------------------------------------------------+
//| GET WINRATE                                                       |
//+------------------------------------------------------------------+
double GetWinrate() {
    return (g_totalTrades == 0) ? 0.0 : (double)g_wins / g_totalTrades * 100.0;
}

//+------------------------------------------------------------------+
//| GET DAY START                                                     |
//+------------------------------------------------------------------+
datetime GetDayStart(datetime dt) {
    MqlDateTime st;
    TimeToStruct(dt, st);
    st.hour = 0; st.min = 0; st.sec = 0;
    return StructToTime(st);
}

//+------------------------------------------------------------------+
//| FORMAT HH:MM                                                     |
//+------------------------------------------------------------------+
string FormatHHMM(int hh, int mm) {
    return StringFormat("%02d:%02d", hh, mm);
}

//+------------------------------------------------------------------+
//| CLOSE ALL POSITIONS                                              |
//+------------------------------------------------------------------+
void CloseAllPositions() {
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(PositionGetSymbol(i) == _Symbol &&
           PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
            g_trade.PositionClose(PositionGetInteger(POSITION_TICKET));
        }
    }
    g_positionOpen = false;
}

//+------------------------------------------------------------------+
//| PRINT FINAL STATISTICS                                           |
//+------------------------------------------------------------------+
void PrintFinalStats() {
    Print("================================");
    Print("=== FINAL STATISTICS ===");
    Print("Total Trades:  ", g_totalTrades);
    Print("Wins:         ", g_wins, " (", DoubleToStr(GetWinrate(),1), "%)");
    Print("Losses:       ", g_losses);
    Print("Total PnL:    ", DoubleToStr(g_totalPnL,2), " ", g_currency);
    Print("Final Capital:", DoubleToStr(g_currentCapital,2), " ", g_currency);
    Print("Multiplier:   ", DoubleToStr(g_currentCapital/g_startCapital,2), "x");
    Print("================================");
}

//+------------------------------------------------------------------+
//| DASHBOARD (Comment)                                              |
//+------------------------------------------------------------------+
string GetStateText() {
    switch(g_state) {
        case STATE_WAITING:        return "[WAITING]";
        case STATE_READY:          return "[READY]";
        case STATE_IN_TRADE:       return "[IN TRADE]";
        case STATE_TARGET_REACHED: return "[TARGET ✓]";
        case STATE_BUSTED:         return "[BUSTED ✗]";
    }
    return "[?]";
}

string GetDirectionIcon() {
    if(!g_positionOpen) return "🎲";
    int type = (int)PositionGetInteger(POSITION_TYPE);
    return (type == POSITION_TYPE_BUY) ? "🟢 BUY" : "🔴 SELL";
}

string GetFlipModeIcon() {
    return InpInstantFlip ? "⚡INSTANT" : "🕯️CANDLE";
}

string GetScheduleStatus() {
    if(InpUseAnyTime) return "ANYTIME";
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    int nowMins = dt.hour * 60 + dt.min;
    string active = "";
    if(InpEnableAsia && IsInRange(nowMins, InpAsiaStartHH*60+InpAsiaStartMM, InpAsiaEndHH*60+InpAsiaEndMM))
        active = "ASIA";
    if(InpEnableLondon && IsInRange(nowMins, InpLondonStartHH*60+InpLondonStartMM, InpLondonEndHH*60+InpLondonEndMM))
        active = "LONDON";
    if(InpEnableNY && IsInRange(nowMins, InpNYStartHH*60+InpNYStartMM, InpNYEndHH*60+InpNYEndMM))
        active = "NY";
    return StringLen(active) > 0 ? active : "CLOSED";
}

void OnChartEvent(const int id, const ulong& lparam, const double& dparam, const string& sparam) {
    if(id == CHARTEVENT_CHART_CHANGE || id == CHARTEVENT_KEY) {
        double progress = (g_currentCapital - InpStartCapital) / (InpTargetCapital - InpStartCapital) * 100.0;
        progress = MathMax(0, MathMin(100, progress));

        string sep = "─────────────────────────";
        string bar = "";
        int barLen = 28;
        int filled = (int)(progress / 100.0 * barLen);
        for(int i = 0; i < barLen; i++) bar += (i < filled) ? "█" : "░";

        Comment(
            sep, "\n",
            "  COIN FLIP EA (v1.1.0)", "\n",
            sep, "\n\n",

            "  Capital  : ", DoubleToStr(g_currentCapital,2), " ", g_currency, "\n",
            "  Target   : ", DoubleToStr(InpTargetCapital,2), " ", g_currency, "\n",
            "  Start    : ", DoubleToStr(InpStartCapital,2), " ", g_currency, "\n\n",

            "  ", bar, "\n",
            "  ", DoubleToStr(progress,1), "%  (", DoubleToStr(g_currentCapital,0), "/",
              DoubleToStr(InpTargetCapital,0), ")\n\n",

            "  Trades   : ", g_totalTrades, " (W:", g_wins, " L:", g_losses, ")\n",
            "  Winrate  : ", DoubleToStr(GetWinrate(),1), "%\n",
            "  Total PnL: ", DoubleToStr(g_totalPnL,2), " ", g_currency, "\n\n",

            "  Risk     : ", DoubleToStr(InpRiskPerTrade,2), " ", g_currency, "\n",
            "  Reward   : ", DoubleToStr(InpRewardPerTrade,2), " ", g_currency, "\n",
            "  RR       : 1:", DoubleToStr(InpRiskReward,1), "\n",
            "  EV/trade : ", DoubleToStr(CalculateExpectedValue(),2), " ", g_currency, "\n\n",

            "  Mode     : ", GetFlipModeIcon(), "\n",
            "  BUY      : ", InpToggleBuy  ? "ON 🟢" : "OFF", "\n",
            "  SELL     : ", InpToggleSell ? "ON 🔴" : "OFF", "\n",
            "  TF       : ", EnumToString(InpFlipTimeframe), "\n",
            "  Schedule : ", GetScheduleStatus(), "\n\n",

            "  ", GetDirectionIcon(), " ", GetStateText(), "\n\n",

            sep, "\n",
            "  Heads(", InpHeadsValue, ")=BUY | Tails(", InpTailsValue, ")=SELL\n",
            sep
        );
    }
}
//+------------------------------------------------------------------+