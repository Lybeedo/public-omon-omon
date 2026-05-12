//+------------------------------------------------------------------+
//|                                 BreakoutChannel_EA.mq5           |
//+------------------------------------------------------------------+
//| Breakout Channel EA v1.00 - MT5 Version                          |
//| Detects price channel breakout and trades the momentum          |
//|                                                                  |
//| Channel Types:                                                   |
//|   0 = DONCHIAN   (Highest/Lowest N bars)                         |
//|   1 = LINEAR REG (Linear regression + std dev)                  |
//|   2 = PITCHFORK  (Andrew's Pitchfork)                           |
//|   3 = BOLLINGER  (MA +/- bands)                                 |
//|   4 = RAFF       (Raff Regression Channel)                       |
//|                                                                  |
//| Use with: #include <PriceChannel.mqh>                            |
//+------------------------------------------------------------------+
#property copyright   "Breakout Channel EA v1.0"
#property link        "https://github.com/Lybeedo/public-omon-omon"
#property version     "1.00"
#property strict

#include <PriceChannel.mqh>
#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== CHANNEL SETTINGS ==="
input int    InpChannelPeriod   = 20;          // Channel Period (N bars)
input int    InpChannelType     = 0;           // Channel Type (0-4): 0=Donchian,1=LinReg,2=Pitchfork,3=BB,4=Raff
input double InpDeviation       = 2.0;         // Std Deviation Multiplier
input double InpRaffScale       = 1.0;         // Raff Scale (0.5 = 50%)

input group "=== TIMEFRAME FILTER ==="
input bool   InpUseHigherTF     = true;         // Use Higher TF for detection?
input int    InpHTFPeriod       = 60;          // Higher TF Minutes (1,5,15,60,240,1440)
input int    InpConfirmBars     = 1;           // Confirm breakout after N bars

input group "=== TRADE SETTINGS ==="
input double InpLotSize         = 0.01;        // Lot Size
input double InpRiskPercent      = 0.0;         // Risk % (0 = use fixed lot)
input double InpMaxRiskUSD      = 50.0;         // Max risk in USD per trade
input double InpSLPips          = 0.0;         // Stop Loss (pips, 0 = auto from channel width)
input double InpTPPips          = 0.0;          // Take Profit (pips, 0 = auto from SL)
input double InpSLMultiplier     = 1.0;         // SL = Channel Width x this multiplier
input double InpTPMultiplier    = 2.0;         // TP = SL x this multiplier

input group "=== BREAKOUT FILTER ==="
input double InpMinWidthPips    = 30.0;         // Min channel width (pips)
input double InpMaxWidthPips    = 500.0;        // Max channel width (pips)
input double InpMinStrength     = 0.0;          // Min breakout strength (0.0-1.0)
input bool   InpRequireCandleDir = true;         // Require candle direction match breakout?

input group "=== SESSION FILTER ==="
input bool   InpTradeLondon     = true;         // Allow London session (07:00-10:00)
input bool   InpTradeNY         = false;        // Allow NY session (13:00-16:00)
input bool   InpAvoidWeekend    = true;         // No trades on Friday after 16:00

input group "=== MANAGEMENT ==="
input ulong  InpMagic           = 55501;        // Magic Number
input string InpComment         = "BreakoutCh";  // Trade Comment
input int    InpMaxTrades       = 1;            // Max open trades per direction
input int    InpMaxTotalTrades  = 3;            // Max total open trades
input bool   InpOneTradePerBar  = true;         // Only 1 trade per bar
input bool   InpBreakEvenonR    = true;         // Move SL to BE after 1:1 reward
input double InpBEBufferPips    = 2.0;          // Buffer pips beyond BE price

input group "=== TRAILING ==="
input bool   InpTrailingStop    = false;        // Enable trailing stop?
input double InpTrailTriggerPips = 30.0;        // Start trailing after profit (pips)
input double InpTrailStepPips   = 10.0;         // Trail step (pips)

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
CPriceChannel  g_ch;
SChannelParams g_params;
CTrade         g_trade;

datetime       g_lastTradeBar   = 0;
datetime       g_lastCheck     = 0;
int            g_digits         = 0;
double         g_point          = 0;
double         g_pip            = 0;
double         g_spread         = 0;
bool           g_initOk         = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    // Symbol setup
    if(!SymbolSelect(_Symbol, true)) return INIT_FAILED;
    
    // Digits / pip
    g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    g_point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    g_pip    = (g_digits == 3 || g_digits == 5) ? g_point * 10 : g_point;
    
    // Trade setup
    g_trade.SetExpertMagicNumber(InpMagic);
    g_trade.SetDeviationInPoints(10);
    g_trade.SetAsyncMode(false);
    
    // Channel init
    g_params.type       = InpChannelType;
    g_params.period    = InpChannelPeriod;
    g_params.deviation = InpDeviation;
    g_params.raffScale = InpRaffScale;
    
    g_ch.InitEx(g_params);
    
    g_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * g_pip;
    g_initOk  = true;
    
    Comment("Breakout Channel EA v1.0\n"
            "Channel: " + ChannelTypeName(InpChannelType) 
            + " | Period: " + IntegerToString(InpChannelPeriod)
            + "\nSpread: " + DoubleToString(g_spread/g_pip, 1) + " pips");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!g_initOk) return;
    
    // Rate limit: check max every 3 seconds
    datetime now = TimeCurrent();
    if(now - g_lastCheck < 3) return;
    g_lastCheck = now;
    
    // Refresh spread
    g_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * g_pip;
    
    // Detect breakout
    ENUM_CHANNEL_BREAKOUT breakout = DetectBreakoutSignal();
    
    if(breakout != BREAKOUT_NONE)
    {
        if(CanOpenTrade())
            OpenTrade(breakout);
    }
    
    // Manage trades
    ManageTrades();
}

//+------------------------------------------------------------------+
//| Detect breakout signal                                            |
//+------------------------------------------------------------------+
ENUM_CHANNEL_BREAKOUT DetectBreakoutSignal()
{
    ENUM_TIMEFRAMES tf = PERIOD_CURRENT;
    if(InpUseHigherTF)
        tf = (ENUM_TIMEFRAMES)InpHTFPeriod;
    
    for(int i = 0; i < InpConfirmBars; i++)
    {
        SChannelSignal s = g_ch.DetectBreakout(i, tf);
        
        if(s.breakout == BREAKOUT_NONE || !s.isConfirmed)
            continue;
        
        if(s.strength < InpMinStrength)
            continue;
        
        double widthPips = s.widthAtBreak / g_pip;
        if(widthPips < InpMinWidthPips || widthPips > InpMaxWidthPips)
            continue;
        
        if(InpOneTradePerBar && s.barIndex > 0)
            continue;
        
        // Candle direction filter
        if(InpRequireCandleDir)
        {
            double close1 = iClose(_Symbol, tf, i);
            double open1  = iOpen(_Symbol, tf, i);
            
            if(s.breakout == BREAKOUT_BULLISH && close1 < open1)
                continue;
            if(s.breakout == BREAKOUT_BEARISH && close1 > open1)
                continue;
        }
        
        g_lastTradeBar = iTime(_Symbol, tf, 0);
        return (ENUM_CHANNEL_BREAKOUT)s.breakout;
    }
    
    return BREAKOUT_NONE;
}

//+------------------------------------------------------------------+
//| Open trade                                                       |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_CHANNEL_BREAKOUT breakout)
{
    ENUM_TIMEFRAMES tf = InpUseHigherTF ? (ENUM_TIMEFRAMES)InpHTFPeriod : PERIOD_CURRENT;
    SChannelSignal s = g_ch.DetectBreakout(0, tf);
    
    double price    = SymbolInfoDouble(_Symbol, breakout == BREAKOUT_BULLISH ? SYMBOL_ASK : SYMBOL_BID);
    double width    = s.widthAtBreak;
    double slPrice  = 0;
    double tpPrice  = 0;
    double lot      = InpLotSize;
    bool   isBuy    = (breakout == BREAKOUT_BULLISH);
    
    // Risk-based lot
    if(InpRiskPercent > 0 || InpMaxRiskUSD > 0)
    {
        double slPips = (InpSLPips > 0) ? InpSLPips : width / g_pip * InpSLMultiplier;
        
        if(slPips > 0)
        {
            // Pip value for XAUUSD approx: lot * g_pip * 10 per pip
            double pipValue = lot * g_pip * 10;
            if(pipValue <= 0) pipValue = 0.1; // fallback
            
            double maxRiskUSD = InpMaxRiskUSD;
            if(InpRiskPercent > 0)
                maxRiskUSD = MathMax(maxRiskUSD, AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0);
            
            double lotByRisk = maxRiskUSD / (slPips * g_pip * 10);
            lot = MathMax(0.01, MathMin(lotByRisk, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX)));
        }
    }
    
    // Normalize lot
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    lot = MathMax(lot, minLot);
    lot = MathFloor(lot / step) * step;
    
    // Calculate SL
    if(InpSLPips > 0)
    {
        slPrice = isBuy ? price - InpSLPips * g_pip : price + InpSLPips * g_pip;
    }
    else
    {
        slPrice = isBuy ? price - width * InpSLMultiplier : price + width * InpSLMultiplier;
    }
    
    // Calculate TP
    if(InpTPPips > 0)
    {
        tpPrice = isBuy ? price + InpTPPips * g_pip : price - InpTPPips * g_pip;
    }
    else
    {
        double slDist = MathAbs(price - slPrice);
        tpPrice = isBuy ? price + slDist * InpTPMultiplier : price - slDist * InpTPMultiplier;
    }
    
    // Normalize
    slPrice = NormalizeDouble(slPrice, g_digits);
    tpPrice = NormalizeDouble(tpPrice, g_digits);
    price   = NormalizeDouble(price, g_digits);
    
    // Send
    bool result;
    if(isBuy)
        result = g_trade.Buy(lot, _Symbol, price, slPrice, tpPrice, (int)ORDER_FILLING_FOK);
    else
        result = g_trade.Sell(lot, _Symbol, price, slPrice, tpPrice, (int)ORDER_FILLING_FOK);
    
    if(result)
    {
        ulong ticket = g_trade.ResultOrder();
        Print("Breakout ", isBuy ? "BUY" : "SELL",
              " | Entry: ", price,
              " | SL: ", slPrice, " (", (MathAbs(price-slPrice)/g_pip):.1f," pips)",
              " | TP: ", tpPrice, " (", (MathAbs(tpPrice-price)/g_pip):.1f," pips)",
              " | Width: ", width/g_pip:.1f," pips",
              " | Strength: ", s.strength:.2f,
              " | Ticket: ", ticket);
    }
    else
    {
        Print("Order failed. Deal=", g_trade.ResultDeal(), 
              " Order=", g_trade.ResultOrder(),
              " Retcode=", g_trade.ResultRetcode(),
              " Comment=", g_trade.ResultComment());
    }
}

//+------------------------------------------------------------------+
//| Manage open trades                                               |
//+------------------------------------------------------------------+
void ManageTrades()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetTicket(i) <= 0) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
        
        ulong    ticket  = PositionGetInteger(POSITION_TICKET);
        double   openP   = PositionGetDouble(POSITION_OPEN_PRICE);
        double   slP     = PositionGetDouble(POSITION_SL);
        double   tpP     = PositionGetDouble(POSITION_TP);
        double   vol     = PositionGetDouble(POSITION_VOLUME_CURRENT);
        bool     isBuy   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
        
        double   price   = isBuy ? ask : bid;
        double   profit  = PositionGetDouble(PROFIT);
        double   slDist   = MathAbs(price - slP);
        double   tpDist   = MathAbs(tpP - price);
        double   slPips   = slDist / g_pip;
        double   profitPips = profit / (vol * g_pip * 10);
        
        bool     modified = false;
        
        // Break even
        if(InpBreakEvenonR && slP > 0)
        {
            double bePrice = isBuy ? openP + InpBEBufferPips * g_pip : openP - InpBEBufferPips * g_pip;
            
            if(isBuy && slP < bePrice - g_pip * 0.5)
            {
                slP = bePrice;
                modified = true;
            }
            else if(!isBuy && slP > bePrice + g_pip * 0.5)
            {
                slP = bePrice;
                modified = true;
            }
        }
        
        // Trailing stop
        if(InpTrailingStop && profitPips >= InpTrailTriggerPips)
        {
            double newSL;
            if(isBuy)
            {
                newSL = price - InpTrailStepPips * g_pip;
                if(newSL > slP && newSL > openP)
                {
                    slP = newSL;
                    modified = true;
                }
            }
            else
            {
                newSL = price + InpTrailStepPips * g_pip;
                if(newSL < slP || slP == 0)
                {
                    if(newSL < openP)
                    {
                        slP = newSL;
                        modified = true;
                    }
                }
            }
        }
        
        if(modified)
        {
            g_trade.PositionModify(ticket, slP, tpP);
        }
    }
}

//+------------------------------------------------------------------+
//| Can open trade?                                                  |
//+------------------------------------------------------------------+
bool CanOpenTrade()
{
    // Count open trades
    int countDir = 0, countTotal = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetTicket(i) <= 0) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
        
        countTotal++;
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            countDir++;
        else
            countDir++;
    }
    
    if(countTotal >= InpMaxTotalTrades) return false;
    
    // Session filter
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    if(!IsSessionAllowed(dt)) return false;
    
    // Spread check: max 50 pips
    if(g_spread > 50 * g_pip) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Session filter                                                    |
//+------------------------------------------------------------------+
bool IsSessionAllowed(MqlDateTime &dt)
{
    int h = dt.hour;
    int day = dt.day_of_week; // 0=Sunday, 1=Monday, ... 6=Saturday
    
    // Weekend off
    if(InpAvoidWeekend && (day == 0 || day == 6)) return false;
    
    // Friday after 16:00 no new trades
    if(InpAvoidWeekend && day == 5 && h >= 16) return false;
    
    // Session windows
    bool inLondon = (h >= 7 && h < 10);
    bool inNY     = (h >= 13 && h < 16);
    
    if(InpTradeLondon && inLondon) return true;
    if(InpTradeNY && inNY) return true;
    
    if(!InpTradeLondon && !InpTradeNY) return true;
    
    return false;
}

//+------------------------------------------------------------------+
//| Helper: Channel type name                                         |
//+------------------------------------------------------------------+
string ChannelTypeName(int t)
{
    switch(t)
    {
        case 0: return "Donchian";
        case 1: return "Linear Regression";
        case 2: return "Pitchfork";
        case 3: return "Bollinger Bands";
        case 4: return "Raff Channel";
        default: return "Unknown";
    }
}

//+------------------------------------------------------------------+