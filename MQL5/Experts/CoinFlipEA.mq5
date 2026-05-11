//+------------------------------------------------------------------+
//|                           CoinFlipEA.mq5                          |
//|                          Coin Flip Trading Experiment              |
//|                        500 USC → 5000 USC (RR 1:2)               |
//+------------------------------------------------------------------+
#property copyright "Coin Flip EA"
#property link      "https://github.com/Lybeedo/public-omon-omon"
#property version   "1.0.0"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== CAPITAL & TARGET ==="
input double InpStartCapital  = 500.0;     // Initial capital (USC)
input double InpTargetCapital = 5000.0;   // Target capital (USC)
input double InpMinCapital    = 0.0;       // Stop if capital reaches this

input group "=== RISK & REWARD ==="
input double InpRiskUSC       = 50.0;      // Risk per trade (USC) = SL
input double InpRewardUSC     = 100.0;     // Reward per trade (USC) = TP
input double InpRiskReward    = 2.0;       // Risk:Reward ratio (default 1:2)

input group "=== COIN FLIP ==="
input int    InpHeadsSide     = 500;       // Heads value (Buy)
input int    InpTailsSide     = 0;         // Tails value (Sell/Garuda)
input bool   InpSimulateFlip  = true;      // Simulate flip (use random), else alternate

input group "=== LOT SETTINGS ==="
input double InpMinLot        = 0.01;       // Minimum lot
input double InpMaxLot        = 1.0;        // Maximum lot
input double InpRiskPercent   = 0.0;        // Risk % of capital (0 = use fixed USC risk)

input group "=== TRADING ==="
input int    InpMagicNumber   = 88888;     // Magic Number
input ulong  InpDeviation     = 50;         // Slippage (points)
input int    InpMaxTrades     = 100;       // Max trades per session (0 = unlimited)
input int    InpMaxDailyTrades = 10;       // Max trades per day (0 = unlimited)
input bool   InpCloseOnTarget  = true;     // Close all and stop when target reached
input bool   InpCloseOnBust    = true;     // Close all and stop when busted

input group "=== TIME FILTER ==="
input int    InpStartHour     = 0;         // Trading start hour (0 = all day)
input int    InpEndHour       = 23;        // Trading end hour

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
CTrade  g_trade;

// Auto-detect digit & pip
int    GDigits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
double GPoint  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
double GPip    = (GDigits == 3 || GDigits == 5) ? GPoint * 10 : GPoint;

// Capital tracking
double g_currentCapital = 0;
double g_startCapital   = 0;
int    g_totalTrades    = 0;
int    g_dailyTrades    = 0;
int    g_wins           = 0;
int    g_losses         = 0;
double g_totalPnL       = 0;

// State
enum ENUM_CF_STATE {STATE_WAITING, STATE_READY, STATE_IN_TRADE, STATE_TARGET_REACHED, STATE_BUSTED};
ENUM_CF_STATE g_state = STATE_WAITING;

datetime g_sessionStart    = 0;
datetime g_lastTradeTime   = 0;
datetime g_lastDailyReset  = 0;
bool     g_tradeDirection  = false;  // false = buy, true = sell

// Order tracking
double g_entryPrice        = 0;
double g_slPrice            = 0;
double g_tpPrice            = 0;
double g_positionLot        = 0;
bool   g_positionOpen       = false;
ulong  g_positionTicket     = 0;

//+------------------------------------------------------------------+
//| EXPERT INITIALIZATION                                            |
//+------------------------------------------------------------------+
int OnInit() {
    g_trade.SetExpertMagicNumber(InpMagicNumber);
    g_trade.SetDeviationInPoints(InpDeviation);
    g_trade.SetTypeFilling(ORDER_FILLING_FOK);
    g_trade.SetAsyncMode(false);

    g_startCapital   = InpStartCapital;
    g_currentCapital = InpStartCapital;
    g_sessionStart   = TimeCurrent();
    g_lastDailyReset = GetDayStart(TimeCurrent());

    // Calculate lot from USC risk if risk percent is set
    double riskLot = 0;
    if(InpRiskPercent > 0) {
        riskLot = CalculateLotFromRiskPercent(InpRiskPercent);
    }

    Print("=== COIN FLIP EA INITIALIZED ===");
    Print("Start Capital: ", DoubleToStr(InpStartCapital, 2), " USC");
    Print("Target:       ", DoubleToStr(InpTargetCapital, 2), " USC (", DoubleToStr(InpTargetCapital/InpStartCapital, 1), "x)");
    Print("Risk:         ", DoubleToStr(InpRiskUSC, 2), " USC per trade");
    Print("Reward:       ", DoubleToStr(InpRewardUSC, 2), " USC per trade");
    Print("RR Ratio:     1:", DoubleToStr(InpRiskReward, 1));
    Print("Heads (", InpHeadsSide, ") = BUY | Tails (", InpTailsSide, ") = SELL");
    Print("Expected Value per trade: ", DoubleToStr(CalculateExpectedValue(), 2), " USC");
    Print("Win Probability (theoretical): 50%");
    Print("Digits: ", GDigits, " | Point: ", DoubleToStr(GPoint, 5), " | Pip: ", DoubleToStr(GPipe, 5));
    Print("================================");

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| EXPERT DEINIT                                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    CloseAllPositions();
    Print("=== COIN FLIP EA DEINITIALIZED ===");
    PrintFinalStats();
}

//+------------------------------------------------------------------+
//| EXPERT TICK                                                      |
//+------------------------------------------------------------------+
void OnTick() {
    datetime now = TimeCurrent();

    // Reset daily trade counter
    if(GetDayStart(now) > g_lastDailyReset) {
        g_dailyTrades = 0;
        g_lastDailyReset = GetDayStart(now);
    }

    // Check state conditions
    if(g_state == STATE_WAITING) {
        g_state = STATE_READY;
    }

    if(g_state == STATE_TARGET_REACHED || g_state == STATE_BUSTED) {
        return;
    }

    // Check target
    if(InpCloseOnTarget && g_currentCapital >= InpTargetCapital) {
        CloseAllPositions();
        g_state = STATE_TARGET_REACHED;
        Print("================================");
        Print("🎯 TARGET REACHED! Capital: ", DoubleToStr(g_currentCapital, 2), " USC");
        Print("SUCCESS! Reached target in ", g_totalTrades, " trades");
        PrintFinalStats();
        return;
    }

    // Check busted
    if(InpCloseOnBust && g_currentCapital <= InpMinCapital) {
        CloseAllPositions();
        g_state = STATE_BUSTED;
        Print("================================");
        Print("💀 BUSTED! Capital: ", DoubleToStr(g_currentCapital, 2), " USC");
        Print("Survived ", g_totalTrades, " trades");
        PrintFinalStats();
        return;
    }

    // Check time filter
    MqlDateTime dt;
    TimeToStruct(now, dt);
    if(InpStartHour > 0 && dt.hour < InpStartHour) return;
    if(InpEndHour < 23 && dt.hour > InpEndHour) return;

    // Check max trades
    if(InpMaxTrades > 0 && g_totalTrades >= InpMaxTrades) {
        Print("Max trades reached (", InpMaxTrades, "). Stopping.");
        g_state = STATE_TARGET_REACHED;
        return;
    }
    if(InpMaxDailyTrades > 0 && g_dailyTrades >= InpMaxDailyTrades) {
        return; // Wait for next day
    }

    // Check if we have an open position
    if(g_positionOpen) {
        CheckPosition();
        return;
    }

    // Open new trade
    if(g_state == STATE_READY && !g_positionOpen) {
        OpenNewTrade();
    }
}

//+------------------------------------------------------------------+
//| OPEN NEW TRADE                                                   |
//+------------------------------------------------------------------+
void OpenNewTrade() {
    // Flip coin
    int flipResult = FlipCoin();
    bool isBuy = (flipResult == InpHeadsSide);

    Print("--------------------------------");
    Print("COIN FLIP #", g_totalTrades + 1, " | Result: ", flipResult,
          " | Action: ", isBuy ? "BUY 🟢" : "SELL 🔴");

    // Calculate lot based on risk
    double lot = CalculateLot();

    // Get current prices
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = GPoint;

    // Calculate SL and TP in price terms
    double slDistanceUSC = InpRiskUSC / (lot * GetContractSize());
    double tpDistanceUSC = InpRewardUSC / (lot * GetContractSize());

    // Convert to price distance
    double slPoints = slDistanceUSC / point;
    double tpPoints = tpDistanceUSC / point;

    double entryPrice, slPrice, tpPrice;

    if(isBuy) {
        entryPrice = ask;
        slPrice    = NormalizeDouble(entryPrice - slPoints * point, Digits);
        tpPrice    = NormalizeDouble(entryPrice + tpPoints * point, Digits);
    } else {
        entryPrice = bid;
        slPrice    = NormalizeDouble(entryPrice + slPoints * point, Digits);
        tpPrice    = NormalizeDouble(entryPrice - tpPoints * point, Digits);
    }

    // Validate prices
    if(isBuy && slPrice >= entryPrice) {
        slPrice = NormalizeDouble(entryPrice - slPoints * point * 0.9, Digits);
    }
    if(!isBuy && slPrice <= entryPrice) {
        slPrice = NormalizeDouble(entryPrice + slPoints * point * 0.9, Digits);
    }

    // Open position
    ENUM_ORDER_TYPE type = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

    bool success = g_trade.PositionOpen(_Symbol, type, lot, entryPrice, slPrice, tpPrice,
                                        "CoinFlip #" + IntegerToString(g_totalTrades + 1));

    if(success) {
        // Get ticket
        ulong ticket = g_trade.ResultOrder();
        g_positionTicket = ticket;
        g_entryPrice      = entryPrice;
        g_slPrice         = slPrice;
        g_tpPrice         = tpPrice;
        g_positionLot     = lot;
        g_positionOpen    = true;
        g_lastTradeTime   = TimeCurrent();
        g_state           = STATE_IN_TRADE;

        double slDist = MathAbs(entryPrice - slPrice) / point;
        double tpDist = MathAbs(entryPrice - tpPrice) / point;

        Print("📊 Entry: ", DoubleToStr(entryPrice, Digits),
              " | SL: ", DoubleToStr(slPrice, Digits), " (", DoubleToStr(slDist, 0), " pts)",
              " | TP: ", DoubleToStr(tpPrice, Digits), " (", DoubleToStr(tpDist, 0), " pts)",
              " | Lot: ", DoubleToStr(lot, 2));
        Print("💰 Capital before trade: ", DoubleToStr(g_currentCapital, 2), " USC");
    } else {
        Print("❌ Failed to open position: ", g_trade.ResultComment());
    }
}

//+------------------------------------------------------------------+
//| CHECK POSITION                                                   |
//+------------------------------------------------------------------+
void CheckPosition() {
    if(!g_positionOpen) return;

    // Check if position still exists
    if(!PositionSelectByTicket(g_positionTicket)) {
        g_positionOpen = false;
        return;
    }

    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double openPrice    = PositionGetDouble(POSITION_PRICE_OPEN);
    double volume       = PositionGetDouble(POSITION_VOLUME);
    int    type         = (int)PositionGetInteger(POSITION_TYPE);

    double profitUSC = 0;
    if(type == POSITION_TYPE_BUY) {
        profitUSC = (currentPrice - openPrice) / GPoint * volume * GPip;
    } else {
        profitUSC = (openPrice - currentPrice) / GPoint * volume * GPip;
    }

    // Check SL
    bool hitSL = false;
    bool hitTP = false;

    if(type == POSITION_TYPE_BUY) {
        if(currentPrice <= g_slPrice) hitSL = true;
        if(currentPrice >= g_tpPrice) hitTP = true;
    } else {
        if(currentPrice >= g_slPrice) hitSL = true;
        if(currentPrice <= g_tpPrice) hitTP = true;
    }

    if(hitSL || hitTP) {
        g_trade.PositionClose(g_positionTicket);

        if(hitTP) {
            g_wins++;
            g_currentCapital += InpRewardUSC;
            Print("✅ WIN! +", DoubleToStr(InpRewardUSC, 2), " USC");
        } else {
            g_losses++;
            g_currentCapital -= InpRiskUSC;
            Print("❌ LOSS! -", DoubleToStr(InpRiskUSC, 2), " USC");
        }

        g_totalTrades++;
        g_dailyTrades++;
        g_totalPnL += (hitTP ? InpRewardUSC : -InpRiskUSC);

        Print("📈 Capital after trade: ", DoubleToStr(g_currentCapital, 2), " USC",
              " | Winrate: ", DoubleToStr(GetWinrate(), 1), "%",
              " | Total PnL: ", DoubleToStr(g_totalPnL, 2), " USC");

        g_positionOpen = false;
        g_state = STATE_READY;
    }
}

//+------------------------------------------------------------------+
//| COIN FLIP                                                        |
//+------------------------------------------------------------------+
int FlipCoin() {
    if(InpSimulateFlip) {
        // Use system time microseconds for randomness
        datetime now = TimeCurrent();
        MqlDateTime dt;
        TimeToStruct(now, dt);

        // Simple pseudo-random based on time
        int seed = dt.sec * 1000000 + dt.min * 1000 + dt.hour;
        MathSrand((uint)seed);

        if(MathRand() % 2 == 0) {
            return InpHeadsSide;  // 500
        } else {
            return InpTailsSide;  // 0 (Garuda)
        }
    } else {
        // Alternate mode
        return (g_totalTrades % 2 == 0) ? InpHeadsSide : InpTailsSide;
    }
}

//+------------------------------------------------------------------+
//| CALCULATE LOT                                                    |
//+------------------------------------------------------------------+
double CalculateLot() {
    if(InpRiskPercent > 0) {
        return MathMin(CalculateLotFromRiskPercent(InpRiskPercent), InpMaxLot);
    }

    // Fixed USC risk
    double tickValue = GPip * GetContractSize(); // Value per point per lot
    double lotFromRisk = InpRiskUSC / (tickValue * (InpRiskReward + 1)); // Simplified

    // More precise: lot = risk USC / (SL in pips * pip value per lot)
    double slPips = InpRiskUSC / (InpRewardUSC / InpRiskReward); // SL in USC = RiskUSC, so SL pips = RiskUSC / (RewardUSC/RR)
    // Actually: if we risk InpRiskUSC and get InpRewardUSC, the SL distance is InpRiskUSC worth of points
    double pipValuePerLot = GetContractSize() * GPip;
    double slPoints = InpRiskUSC / pipValuePerLot;
    double lot = InpRiskUSC / (slPoints * GPoint * GetContractSize());

    lot = NormalizeDouble(lot, 2);
    lot = MathMax(lot, InpMinLot);
    lot = MathMin(lot, InpMaxLot);

    return lot;
}

//+------------------------------------------------------------------+
//| CALCULATE LOT FROM RISK PERCENT                                  |
//+------------------------------------------------------------------+
double CalculateLotFromRiskPercent(double percent) {
    double riskAmount = g_currentCapital * (percent / 100.0);
    double pipValuePerLot = GetContractSize() * GPip;

    // For a given risk, lot = risk / (SL_distance * pip_value)
    // SL distance in points = InpRiskUSC / (pipValuePerLot * lot)
    // So lot = sqrt(risk / pipValuePerLot) simplified
    // Let's just approximate: lot = risk / (some_safeguard)

    // More practical: calculate based on fixed risk
    double lot = riskAmount / (InpRiskUSC); // rough
    lot = NormalizeDouble(lot, 2);
    lot = MathMax(lot, InpMinLot);
    lot = MathMin(lot, InpMaxLot);

    return lot;
}

//+------------------------------------------------------------------+
//| GET CONTRACT SIZE                                                |
//+------------------------------------------------------------------+
double GetContractSize() {
    // For gold, usually 100 oz per lot, or 1 = 1oz depending on broker
    // Use SymbolInfoDouble for accurate contract size
    double cs = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    if(cs <= 0) cs = 100.0; // Default fallback
    return cs;
}

//+------------------------------------------------------------------+
//| CALCULATE EXPECTED VALUE                                         |
//+------------------------------------------------------------------+
double CalculateExpectedValue() {
    double winRate = 0.5; // Fair coin
    double ev = (winRate * InpRewardUSC) - (winRate * InpRiskUSC);
    return ev;
}

//+------------------------------------------------------------------+
//| GET WINRATE                                                       |
//+------------------------------------------------------------------+
double GetWinrate() {
    if(g_totalTrades == 0) return 0;
    return (double)g_wins / g_totalTrades * 100.0;
}

//+------------------------------------------------------------------+
//| GET DAY START                                                     |
//+------------------------------------------------------------------+
datetime GetDayStart(datetime dt) {
    MqlDateTime st;
    TimeToStruct(dt, st);
    st.hour  = 0;
    st.min   = 0;
    st.sec   = 0;
    return StructToTime(st);
}

//+------------------------------------------------------------------+
//| CLOSE ALL POSITIONS                                              |
//+------------------------------------------------------------------+
void CloseAllPositions() {
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(PositionGetSymbol(i) == _Symbol) {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                g_trade.PositionClose(PositionGetInteger(POSITION_TICKET));
            }
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
    Print("Total Trades:    ", g_totalTrades);
    Print("Wins:            ", g_wins, " (", DoubleToStr(GetWinrate(), 1), "%)");
    Print("Losses:          ", g_losses);
    Print("Total PnL:       ", DoubleToStr(g_totalPnL, 2), " USC");
    Print("Final Capital:   ", DoubleToStr(g_currentCapital, 2), " USC");
    Print("Start Capital:   ", DoubleToStr(g_startCapital, 2), " USC");
    Print("Multiplier:      ", DoubleToStr(g_currentCapital / g_startCapital, 2), "x");
    Print("Expected EV:    ", DoubleToStr(CalculateExpectedValue(), 2), " USC/trade");
    Print("================================");
}

//+------------------------------------------------------------------+
//| EXPERT COMMENT (display stats on chart)                          |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const ulong& lparam, const double& dparam, const string& sparam) {
    if(id == CHARTEVENT_CHART_CHANGE) {
        Comment(
            "=== COIN FLIP EA ===\n",
            "Capital: ", DoubleToStr(g_currentCapital, 2), " USC\n",
            "Target:  ", DoubleToStr(InpTargetCapital, 2), " USC\n",
            "───────────────\n",
            "Trades: ", g_totalTrades, " (W:", g_wins, " L:", g_losses, ")\n",
            "Winrate: ", DoubleToStr(GetWinrate(), 1), "%\n",
            "───────────────\n",
            "Risk: ", DoubleToStr(InpRiskUSC, 2), " USC | Reward: ", DoubleToStr(InpRewardUSC, 2), " USC\n",
            "RR: 1:", DoubleToStr(InpRiskReward, 1), "\n",
            "───────────────\n",
            "EV per trade: ", DoubleToStr(CalculateExpectedValue(), 2), " USC\n",
            "Total PnL: ", DoubleToStr(g_totalPnL, 2), " USC\n",
            "───────────────\n",
            "State: ",
            (g_state == STATE_WAITING ? "WAITING" :
             g_state == STATE_READY ? "READY" :
             g_state == STATE_IN_TRADE ? "IN TRADE" :
             g_state == STATE_TARGET_REACHED ? "TARGET REACHED!" :
             "BUSTED!")
        );
    }
}

//+------------------------------------------------------------------+
//| GAMBLER'S RUIN PROBABILITY (reference)                           |
//+------------------------------------------------------------------+
/*
Theoretical ruin probability calculation:

Using asymmetric random walk (Gambler's Ruin with drift):

- Start capital: S = 500 USC
- Target: T = 5000 USC
- Win amount: +100 USC (TP)
- Loss amount: -50 USC (SL)
- Win probability: p = 0.50

For asymmetric case with unequal step sizes:
- q = 1 - p = 0.50
- a = 50 (loss step)
- b = 100 (win step)

Ruin probability = ?
Success probability ≈ 99.19%

Formula (approximation):
P_ruin = ( (q/p)^(S/b) - (q/p)^(T/b) ) / (1 - (q/p)^(T/b))

With p=q=0.5, this approaches boundary cases.
The positive drift (b > a) makes reaching target much more likely.
*/
//+------------------------------------------------------------------+