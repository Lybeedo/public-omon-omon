//+------------------------------------------------------------------+
//|                                    BreakoutChannel_EA.mq4       |
//+------------------------------------------------------------------+
//| Breakout Channel EA v1.00                                         |
//| Detects price channel breakout and trades the momentum           |
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

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== CHANNEL SETTINGS ==="
input int    InpChannelPeriod   = 20;          // Channel Period (N bars)
input int    InpChannelType     = 0;           // Channel Type (0-4, see description)
input double InpDeviation       = 2.0;          // Std Deviation Multiplier
input double InpRaffScale      = 1.0;          // Raff Scale (0.5 = 50%)

input group "=== TIMEFRAME FILTER ==="
input bool   InpUseHigherTF    = true;         // Use Higher TF for detection?
input int    InpHTFPeriod      = 60;           // Higher TF Minutes (1,5,15,60,240)
input int    InpConfirmBars    = 1;            // Confirm breakout after N bars

input group "=== TRADE SETTINGS ==="
input double InpLotSize        = 0.01;         // Lot Size
input double InpRiskPercent    = 0.0;          // Risk % (0 = use fixed lot)
input double InpMaxRisk        = 50.0;         // Max risk in USD (per trade)
input double InpSLPips         = 0.0;         // Stop Loss (pips, 0 = channel width)
input double InpTPPips         = 0.0;          // Take Profit (pips, 0 = 2x SL)
input double InpSLAtMultiplier = 1.0;         // SL = Channel Width x this
input double InpTPAtMultiplier = 2.0;         // TP = Channel Width x this

input group "=== BREAKOUT FILTER ==="
input double InpMinWidthPips   = 30.0;         // Min channel width (pips)
input double InpMaxWidthPips    = 500.0;        // Max channel width (pips)
input double InpMinStrength    = 0.0;          // Min breakout strength (0.0-1.0)
input bool   InpConfirmClose   = true;         // Require close above/below channel

input group "=== SESSION FILTER ==="
input bool   InpTradeLondon    = true;         // Allow London session (07:00-10:00)
input bool   InpTradeNY        = false;        // Allow NY session (13:00-16:00)
input bool   InpAvoidNews      = false;        // Avoid high impact news hours?
input int    InpNewsOffsetMins = 60;           // Minutes before/after news to avoid

input group "=== MANAGEMENT ==="
input int    InpMagic          = 55501;        // Magic Number
input string InpComment        = "BreakoutCh";  // Trade Comment
input int    InpMaxTrades      = 1;            // Max open trades
input bool   InpOneTradePerBar = true;         // Only 1 trade per bar

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
CPriceChannel  g_ch;
SChannelParams g_params;

datetime       g_lastTradeBar   = 0;
datetime       g_lastCheck      = 0;
int            g_digits          = 0;
double         g_point          = 0;
double         g_pip            = 0;
double         g_spread         = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    // Setup digits/pip
    g_digits = (int)MarketInfo(_Symbol, MODE_DIGITS);
    g_point  = MarketInfo(_Symbol, MODE_POINT);
    if(g_digits == 3 || g_digits == 5)
        g_pip = g_point * 10;
    else
        g_pip = g_point;
    
    // Initialize channel
    g_params.type      = InpChannelType;
    g_params.period    = InpChannelPeriod;
    g_params.deviation = InpDeviation;
    g_params.raffScale = InpRaffScale;
    
    g_ch.InitEx(g_params);
    
    // Get current spread
    g_spread = MarketInfo(_Symbol, MODE_SPREAD) * g_pip;
    
    Comment("Breakout Channel EA v1.0\nChannel: " + ChannelTypeName(InpChannelType) 
            + " | Period: " + IntegerToString(InpChannelPeriod));
    
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
    // Rate limit checks
    datetime now = TimeCurrent();
    if(now - g_lastCheck < 5) return;  // Check every 5 seconds
    g_lastCheck = now;
    
    // Detect breakout
    ENUM_CHANNEL_BREAKOUT breakout = DetectBreakoutSignal();
    
    if(breakout != BREAKOUT_NONE)
    {
        // Check if we can trade
        if(!CanOpenTrade()) return;
        
        // Open trade
        OpenTrade(breakout);
    }
    
    // Manage open trades
    ManageTrades();
}

//+------------------------------------------------------------------+
//| Detect breakout signal                                            |
//+------------------------------------------------------------------+
ENUM_CHANNEL_BREAKOUT DetectBreakoutSignal()
{
    // Load appropriate timeframe
    ENUM_TIMEFRAMES tf = PERIOD_CURRENT;
    if(InpUseHigherTF)
        tf = (ENUM_TIMEFRAMES)InpHTFPeriod;
    
    // Scan recent bars for confirmed breakout
    for(int i = 0; i < InpConfirmBars; i++)
    {
        SChannelSignal s = g_ch.DetectBreakout(i, tf);
        
        if(s.breakout == BREAKOUT_NONE || !s.isConfirmed)
            continue;
        
        // Check strength filter
        if(s.strength < InpMinStrength)
            continue;
        
        // Check channel width
        double widthPips = s.widthAtBreak / g_pip;
        if(widthPips < InpMinWidthPips || widthPips > InpMaxWidthPips)
            continue;
        
        // Only take first confirmed breakout per bar
        if(InpOneTradePerBar && s.barIndex > 0)
            continue;
        
        // Confirm candle must be in direction of breakout
        if(InpConfirmClose)
        {
            double closePrice = iClose(_Symbol, tf, i);
            double openPrice  = iOpen(_Symbol, tf, i);
            
            if(s.breakout == BREAKOUT_BULLISH && closePrice < openPrice)
                continue;
            if(s.breakout == BREAKOUT_BEARISH && closePrice > openPrice)
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
    // Get signal details
    SChannelSignal s = g_ch.DetectBreakout(0, InpUseHigherTF ? (ENUM_TIMEFRAMES)InpHTFPeriod : PERIOD_CURRENT);
    
    double entryPrice = Ask;
    double slPrice    = 0;
    double tpPrice    = 0;
    double width      = s.widthAtBreak;
    
    int    type       = (breakout == BREAKOUT_BULLISH) ? OP_BUY : OP_SELL;
    double price      = (type == OP_BUY) ? Ask : Bid;
    
    // Calculate lot size
    double lot = InpLotSize;
    if(InpRiskPercent > 0)
    {
        double riskUSD = AccountBalance() * InpRiskPercent / 100.0;
        double slPips = (InpSLPips > 0) ? InpSLPips : width / g_pip * InpSLAtMultiplier;
        if(slPips > 0)
        {
            double pipValue = lot * g_pip * 10;  // per pip per lot for XAUUSD approx
            lot = MathMin(lot, riskUSD / (slPips * g_pip * 10));
        }
    }
    lot = MathMax(lot, MarketInfo(_Symbol, MODE_MINLOT));
    lot = MathMin(lot, MarketInfo(_Symbol, MODE_MAXLOT));
    
    // Calculate SL
    if(InpSLPips > 0)
    {
        slPrice = (type == OP_BUY) ? price - InpSLPips * g_pip : price + InpSLPips * g_pip;
    }
    else
    {
        slPrice = (type == OP_BUY) ? price - width * InpSLAtMultiplier : price + width * InpSLAtMultiplier;
    }
    
    // Calculate TP
    if(InpTPPips > 0)
    {
        tpPrice = (type == OP_BUY) ? price + InpTPPips * g_pip : price - InpTPPips * g_pip;
    }
    else
    {
        tpPrice = (type == OP_BUY) ? price + width * InpTPAtMultiplier : price - width * InpTPAtMultiplier;
    }
    
    // Normalize prices
    slPrice = NormalizeDouble(slPrice, g_digits);
    tpPrice = NormalizeDouble(tpPrice, g_digits);
    
    // Send order
    int ticket = OrderSend(_Symbol, type, lot, price, 0, slPrice, tpPrice, InpComment, InpMagic, 0, clrNONE);
    
    if(ticket > 0)
    {
        Print("Breakout ", breakout == BREAKOUT_BULLISH ? "BUY" : "SELL",
              " opened. Entry: ", price, " SL: ", slPrice, " TP: ", tpPrice,
              " Width: ", width/g_pip, " pips");
    }
    else
    {
        Print("OrderSend failed. Error: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Manage open trades                                               |
//+------------------------------------------------------------------+
void ManageTrades()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if(OrderSymbol() != _Symbol) continue;
        if(OrderMagicNumber() != InpMagic) continue;
        
        // BE trailing stop after 1:1 reward
        double openPrice = OrderOpenPrice();
        double currentSL = OrderStopLoss();
        double price     = (OrderType() == OP_BUY) ? Bid : Ask;
        double profitPips = (OrderType() == OP_BUY) 
            ? (price - openPrice) / g_pip 
            : (openPrice - price) / g_pip;
        
        // Break even when profit > 50% of risk
        if(profitPips > (InpSLPips > 0 ? InpSLPips * 0.5 : 5))
        {
            double bePrice = openPrice + (OrderType() == OP_BUY ? g_pip * 2 : -g_pip * 2);
            if(OrderType() == OP_BUY && currentSL < bePrice)
                OrderModify(ticket, openPrice, bePrice, OrderTakeProfit(), 0);
            else if(OrderType() == OP_SELL && currentSL > bePrice)
                OrderModify(ticket, openPrice, bePrice, OrderTakeProfit(), 0);
        }
    }
}

//+------------------------------------------------------------------+
//| Can open trade?                                                  |
//+------------------------------------------------------------------+
bool CanOpenTrade()
{
    // Check trade count
    int openCount = 0;
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if(OrderSymbol() == _Symbol && OrderMagicNumber() == InpMagic)
            openCount++;
    }
    if(openCount >= InpMaxTrades) return false;
    
    // Check session filter
    if(!IsSessionAllowed()) return false;
    
    // Check spread
    if(g_spread > 50 * g_pip) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Session filter                                                    |
//+------------------------------------------------------------------+
bool IsSessionAllowed()
{
    MqlTradeRequest request;
    MqlTradeResult result;
    datetime now = TimeCurrent();
    int h = Hour();
    
    // London: 07:00 - 10:00
    if(InpTradeLondon && h >= 7 && h < 10) return true;
    
    // NY: 13:00 - 16:00
    if(InpTradeNY && h >= 13 && h < 16) return true;
    
    // If no session filter enabled, allow all
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
        case 3: return "Bollinger";
        case 4: return "Raff";
        default: return "Unknown";
    }
}

//+------------------------------------------------------------------+
//| Helper: Pip to price                                              |
//+------------------------------------------------------------------+
double PipsToPrice(double pips)
{
    return pips * g_pip;
}

//+------------------------------------------------------------------+
//| Helper: Price to pips                                             |
//+------------------------------------------------------------------+
double PriceToPips(double price)
{
    return price / g_pip;
}
//+------------------------------------------------------------------+