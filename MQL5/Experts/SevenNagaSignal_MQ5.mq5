//+------------------------------------------------------------------+
//|                    7NAGA Telegram Signal EA                       |
//|                    XAUUSD M30 | Auto Signal                       |
//|                              v2.3                                 |
//+------------------------------------------------------------------+
#property copyright   "7NAGA Trading System"
#property version     "2.30"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input string  InpBotToken     = "8744785467:AAHyxr-TarjAbdmdeoGpDZoACuqEjGJIxvw"; // Telegram Bot Token
input string  InpChatID       = "-1003749363129";         // Telegram Channel/Group ID
input string  InpThreadID     = "261";                     // Topic/Thread ID (kosongkan kalau tidak ada)
input int     InpNumCandles   = 7;            // Number of M30 candles for H/L
input int     InpWIBOffset    = 7;            // WIB Offset from UTC (default: 7)
input int     InpHourSend     = 9;            // Hour to send daily signal (24h format, server time)
input bool    InpMondaySkip   = true;         // Skip on Monday?
input int     InpPipAddHigh   = 100;           // Pips added to rounded HIGH (BUY STOP)
input int     InpPipSubLow    = 25;           // Pips subtracted from rounded LOW (SELL STOP)
input color   InpColorHigh    = clrRed;       // HIGH line color
input color   InpColorLow     = clrLime;      // LOW line color
input int     InpLineWidth    = 2;            // Line width

//+------------------------------------------------------------------+
//| GLOBAL STATE                                                     |
//+------------------------------------------------------------------+
datetime      g_lastCandle    = 0;
string        g_lastSignalKey = "";
string        g_lastHighStr   = "";
string        g_lastLowStr    = "";

//+------------------------------------------------------------------+
//| HTTP GET wrapper (no external libs needed)                       |
//+------------------------------------------------------------------+
string HttpGet(string url)
{
    char   data[];
    char   result[];
    string headers;
    string resp;

    int timeout = 15000;
    int code = WebRequest("GET", url, headers, timeout, data, result, headers);

    if(code == 200)
    {
        resp = CharArrayToString(result);
        return resp;
    }
    return "ERROR:" + IntegerToString(code);
}

//+------------------------------------------------------------------+
//| Helper: Telegram send message via Bot API                        |
//+------------------------------------------------------------------+
bool SendTelegram(string token, string chat_id, string text)
{
    string url = "https://api.telegram.org/bot" + token
               + "/sendMessage?chat_id=" + chat_id
               + "&text=" + text
               + "&parse_mode=HTML"
               + "&disable_web_page_preview=true";

    // Add topic/thread ID if set
    if(InpThreadID != "")
        url += "&message_thread_id=" + InpThreadID;

    string resp = HttpGet(url);
    return (StringFind(resp, "\"ok\":true") >= 0);
}

//+------------------------------------------------------------------+
//| Round UP to nearest 0.05  (for HIGH)                             |
//| 0.00-0.06 → 0.05 | 0.07-0.09 → 0.10 | 0.10-0.16 → 0.15 | ...  |
//+------------------------------------------------------------------+
double RoundUpTo05(double price)
{
    double whole = MathFloor(price);
    double dec    = price - whole;

    double rdec;
    if(dec <= 0.06)         rdec = 0.05;
    else if(dec <= 0.09)   rdec = 0.10;
    else if(dec <= 0.16)    rdec = 0.15;
    else if(dec <= 0.19)   rdec = 0.20;
    else if(dec <= 0.26)    rdec = 0.25;
    else if(dec <= 0.29)    rdec = 0.30;
    else if(dec <= 0.36)    rdec = 0.35;
    else if(dec <= 0.39)    rdec = 0.40;
    else if(dec <= 0.46)    rdec = 0.45;
    else if(dec <= 0.49)    rdec = 0.50;
    else if(dec <= 0.56)    rdec = 0.55;
    else if(dec <= 0.59)    rdec = 0.60;
    else if(dec <= 0.66)    rdec = 0.65;
    else if(dec <= 0.69)    rdec = 0.70;
    else if(dec <= 0.76)    rdec = 0.75;
    else if(dec <= 0.79)    rdec = 0.80;
    else if(dec <= 0.86)    rdec = 0.85;
    else if(dec <= 0.89)    rdec = 0.90;
    else if(dec <= 0.96)    rdec = 0.95;
    else                    rdec = 1.00;  // 0.97-0.99 → next integer

    double result = whole + rdec;
    if(rdec >= 1.00) result += 1.00;
    return result;
}

//+------------------------------------------------------------------+
//| Round DOWN to nearest 0.05  (for LOW)                            |
//| 0.00-0.02 → 0.00 | 0.03-0.07 → 0.05 | 0.08-0.12 → 0.10 | ...  |
//+------------------------------------------------------------------+
double RoundDownTo05(double price)
{
    double whole = MathFloor(price);
    double dec    = price - whole;

    double rdec;
    if(dec < 0.03)          rdec = 0.00;
    else if(dec < 0.08)    rdec = 0.05;
    else if(dec < 0.13)    rdec = 0.10;
    else if(dec < 0.18)    rdec = 0.15;
    else if(dec < 0.23)    rdec = 0.20;
    else if(dec < 0.28)    rdec = 0.25;
    else if(dec < 0.33)    rdec = 0.30;
    else if(dec < 0.38)    rdec = 0.35;
    else if(dec < 0.43)    rdec = 0.40;
    else if(dec < 0.48)    rdec = 0.45;
    else if(dec < 0.53)    rdec = 0.50;
    else if(dec < 0.58)    rdec = 0.55;
    else if(dec < 0.63)    rdec = 0.60;
    else if(dec < 0.68)    rdec = 0.65;
    else if(dec < 0.73)    rdec = 0.70;
    else if(dec < 0.78)    rdec = 0.75;
    else if(dec < 0.83)    rdec = 0.80;
    else if(dec < 0.88)    rdec = 0.85;
    else if(dec < 0.93)    rdec = 0.90;
    else if(dec < 0.98)    rdec = 0.95;
    else                    rdec = 1.00;  // 0.98-0.99 → next integer

    double result = whole + rdec;
    if(rdec >= 1.00) result += 1.00;
    return result;
}

//+------------------------------------------------------------------+
//| Helper: month name in Indonesian                                 |
//+------------------------------------------------------------------+
string BulanIND(int mon)
{
    switch(mon)
    {
        case  1: return "Jan";
        case  2: return "Feb";
        case  3: return "Mar";
        case  4: return "Apr";
        case  5: return "Mei";
        case  6: return "Jun";
        case  7: return "Jul";
        case  8: return "Agu";
        case  9: return "Sep";
        case 10: return "Okt";
        case 11: return "Nov";
        case 12: return "Des";
    }
    return "???";
}

//+------------------------------------------------------------------+
//| Format signal card for Telegram                                  |
//+------------------------------------------------------------------+
string BuildSignalCard(double high, double low, double range,
                        double finalHigh, double finalLow,
                        double buyStop, double sellStop,
                        int wibHour, int wibMin,
                        MqlDateTime &dt)
{
    // Range status
    string rangeStatus = "";
    if(range > 200)
    {
        rangeStatus = "\n⚠️ HIGH RISK: Range > 200 pips\n⚠️ Trade at your own risk!\n";
    }
    else if(range < 70)
    {
        rangeStatus = "\n⚠️ HIGH RISK: Range < 70 pips\n⚠️ Spread too tight — trade at your own risk!\n";
    }
    else if(range > 120)
    {
        rangeStatus = "\n⚡ CAUTION: Range " + DoubleToString(range, 2) + " pts (>120 pips)\n";
    }
    else
    {
        rangeStatus = "\n✅ Range normal — " + DoubleToString(range, 2) + " pts\n";
    }

    string txt =
        "━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
       +"🐉 <b>7 NAGA SIGNAL</b> — XAUUSD\n"
       +"━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
       +"🕐 Session : 06:30 - 09:30 WIB\n"
       +"📅 Date   : " + IntegerToString(dt.day) + " "
       +              BulanIND(dt.mon) + " " + IntegerToString(dt.year) + "\n"
       +"⏰ Time   : " + StringFormat("%02d:%02d WIB", wibHour, wibMin) + "\n"
       +"\n"
       +"🎯 HIGH   : " + DoubleToString(high, _Digits) + "\n"
       +"🎯 LOW    : " + DoubleToString(low, _Digits) + "\n"
       +"📐 Range  : " + DoubleToString(range, _Digits) + " pts\n"
       +"━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
       +"✅ Rounded HIGH → " + DoubleToString(finalHigh, _Digits) + "\n"
       +"✅ Rounded LOW  → " + DoubleToString(finalLow, _Digits) + "\n"
       +"━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
       +"💰 BUY  → if price > " + DoubleToString(buyStop, _Digits) + "\n"
       +"📉 SELL → if price < " + DoubleToString(sellStop, _Digits) + "\n"
       +"━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
       + rangeStatus
       +"<i>7NAGA MT5 Signal EA</i>\n";

    return txt;
}

//+------------------------------------------------------------------+
//| Get highest HIGH over last N M30 candles                         |
//+------------------------------------------------------------------+
double GetSessionHigh(int count)
{
    double maxH = 0;
    for(int i = 1; i <= count; i++)
    {
        double h = iHigh(NULL, PERIOD_M30, i);
        if(i == 1 || h > maxH) maxH = h;
    }
    return maxH;
}

//+------------------------------------------------------------------+
//| Get lowest LOW over last N M30 candles                           |
//+------------------------------------------------------------------+
double GetSessionLow(int count)
{
    double minL = DBL_MAX;
    for(int i = 1; i <= count; i++)
    {
        double l = iLow(NULL, PERIOD_M30, i);
        if(i == 1 || l < minL) minL = l;
    }
    return minL;
}

//+------------------------------------------------------------------+
//| Convert server time to WIB (UTC+InpWIBOffset)                    |
//+------------------------------------------------------------------+
void GetWIBTime(int &wibHour, int &wibMin)
{
    MqlDateTime dt;
    TimeCurrent(dt);

    int baseHour = dt.hour;
    int baseMin  = dt.min;

    int wib = baseHour + InpWIBOffset;
    if(wib >= 24) wib -= 24;
    else if(wib < 0) wib += 24;

    wibHour = wib;
    wibMin  = baseMin;
}

//+------------------------------------------------------------------+
//| Check: is Monday?                                                 |
//+------------------------------------------------------------------+
bool IsMonday(MqlDateTime &dt)
{
    return (dt.day_of_week == 1);  // MQL5: 1 = Monday
}

//+------------------------------------------------------------------+
//| Draw HIGH / LOW horizontal lines on chart                         |
//+------------------------------------------------------------------+
void DrawLevels(double high, double low)
{
    string hiName = "7NAGA_High";
    string loName = "7NAGA_Low";

    if(ObjectFind(0, hiName) < 0)
        ObjectCreate(0, hiName, OBJ_HLINE, 0, 0, high);
    else
        ObjectMove(0, hiName, 0, 0, high);
    ObjectSetInteger(0, hiName, OBJPROP_COLOR, InpColorHigh);
    ObjectSetInteger(0, hiName, OBJPROP_WIDTH, InpLineWidth);
    ObjectSetString(0, hiName, OBJPROP_TEXT, "🎯 HIGH: " + DoubleToString(high, _Digits));

    if(ObjectFind(0, loName) < 0)
        ObjectCreate(0, loName, OBJ_HLINE, 0, 0, low);
    else
        ObjectMove(0, loName, 0, 0, low);
    ObjectSetInteger(0, loName, OBJPROP_COLOR, InpColorLow);
    ObjectSetInteger(0, loName, OBJPROP_WIDTH, InpLineWidth);
    ObjectSetString(0, loName, OBJPROP_TEXT, "🎯 LOW: " + DoubleToString(low, _Digits));
}

//+------------------------------------------------------------------+
//| Show status on chart                                             |
//+------------------------------------------------------------------+
void ChartComment(double high, double low, double range,
                   double finalHigh, double finalLow,
                   double buyStop, double sellStop)
{
    string riskTxt = "";
    if(range > 200 || range < 70)
        riskTxt = " | ⚠️ HIGH RISK";
    else if(range > 120)
        riskTxt = " | ⚡ CAUTION";
    else
        riskTxt = " | ✅ OK";

    string msg = StringFormat(
        "🐉 7NAGA SIGNAL — XAUUSD\n"
       +"━━━━━━━━━━━━━━━━━━\n"
       +"🎯 HIGH : %.2f  (→ %.2f)\n"
       +"🎯 LOW  : %.2f  (→ %.2f)\n"
       +"📐 Range: %.2f pts%s\n"
       +"━━━━━━━━━━━━━━━━━━\n"
       +"💰 BUY  > %.2f\n"
       +"📉 SELL < %.2f",
        high, finalHigh,
        low,  finalLow,
        range, riskTxt,
        buyStop, sellStop
    );
    Comment(msg);
}

//+------------------------------------------------------------------+
//| ON INIT                                                          |
//+------------------------------------------------------------------+
int OnInit()
{
    if(InpBotToken == "" || InpChatID == "")
    {
        Print("[7NAGA] WARNING: Bot Token atau Chat ID belum diset!");
        Alert("[7NAGA] Set InpBotToken dan InpChatID di Input Parameters!");
    }

    if(InpNumCandles < 2)
    {
        Print("[7NAGA] ERROR: InpNumCandles harus >= 2");
        return INIT_PARAMETERS_INCORRECT;
    }

    Print("┌──────────────────────────────┐");
    Print("│  🐉 7NAGA SIGNAL EA v2.3     │");
    Print("│  Token: ", (InpBotToken!=""?"SET":"BELUM SET"), "                   │");
    Print("│  ChatID: ", (InpChatID!=""?"SET":"BELUM SET"), "                  │");
    Print("│  Thread: ", (InpThreadID!=""?InpThreadID:"NONE"), "                   │");
    Print("│  Candles: ", InpNumCandles, " M30               │");
    Print("│  WIB Offset: +", InpWIBOffset, "                  │");
    Print("│  Monday Skip: ", (InpMondaySkip?"YES":"NO"), "                │");
    Print("└──────────────────────────────┘");

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| ON DEINIT                                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    ObjectDelete(0, "7NAGA_High");
    ObjectDelete(0, "7NAGA_Low");
    Comment("");
}

//+------------------------------------------------------------------+
//| ON TICK — main logic (runs on every new M30 candle)              |
//+------------------------------------------------------------------+
void OnTick()
{
    // Detect new M30 candle
    datetime curCandle = iTime(NULL, PERIOD_M30, 0);
    if(curCandle == g_lastCandle)
        return;
    g_lastCandle = curCandle;

    // Time info
    MqlDateTime dt;
    TimeCurrent(dt);

    // Skip Monday if enabled
    if(InpMondaySkip && IsMonday(dt))
    {
        Comment("[7NAGA] ❌ MONDAY — SKIP DAY");
        return;
    }

    // Calculate HIGH / LOW from last N M30 candles
    double rawHigh  = GetSessionHigh(InpNumCandles);
    double rawLow   = GetSessionLow(InpNumCandles);
    double range    = rawHigh - rawLow;

    // Round according to 7NAGA rules
    double finalHigh = RoundUpTo05(rawHigh);   // HIGH → round UP
    double finalLow  = RoundDownTo05(rawLow);   // LOW  → round DOWN

    // BUY STOP = rounded HIGH + 100 pips (1.00 for XAUUSD 2-digit)
    // SELL STOP = rounded LOW  -  25 pips (0.25 for XAUUSD 2-digit)
    double buyStop  = finalHigh + (InpPipAddHigh / 100.0);
    double sellStop = finalLow  - (InpPipSubLow  / 100.0);

    // Convert to WIB
    int wibHour, wibMin;
    GetWIBTime(wibHour, wibMin);

    // Update chart visuals
    DrawLevels(rawHigh, rawLow);
    ChartComment(rawHigh, rawLow, range, finalHigh, finalLow, buyStop, sellStop);

    // Build unique signal key (avoids duplicate sends)
    string sigKey = StringFormat("%.4f|%.4f|%04d%02d%02d",
                                 rawHigh, rawLow, dt.year, dt.mon, dt.day);

    // Send only if new day signal
    if(sigKey != g_lastSignalKey)
    {
        g_lastSignalKey = sigKey;
        g_lastHighStr  = DoubleToString(rawHigh, _Digits);
        g_lastLowStr   = DoubleToString(rawLow, _Digits);

        string card = BuildSignalCard(rawHigh, rawLow, range,
                                      finalHigh, finalLow,
                                      buyStop, sellStop,
                                      wibHour, wibMin, dt);

        if(InpBotToken != "" && InpChatID != "")
        {
            bool ok = SendTelegram(InpBotToken, InpChatID, card);
            Print("[7NAGA] Signal ", ok ? "SENT ✓" : "FAILED ✗");
        }
        else
        {
            Print("[7NAGA] Telegram not configured. Signal preview:");
            Print(card);
        }
    }
}

//+------------------------------------------------------------------+
//| ON CALCULATE (standard indicator callback — delegates to OnTick) |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                 const int prev_calculated,
                 const datetime &time[],
                 const double &open[],
                 const double &high[],
                 const double &low[],
                 const double &close[],
                 const long &tick_volume[],
                 const long &volume[],
                 const int &spread[])
{
    OnTick();
    return rates_total;
}
//+------------------------------------------------------------------+