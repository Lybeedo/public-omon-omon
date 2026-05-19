# Telegram Sender Module

## Method 1: Cron Job with Deliver Target

Best for: scheduled reports (daily P&L, weekly summary), recurring alerts.

```
Create cron job with:
  deliver: "telegram"
  schedule: "0 9 * * *"  (daily 9 AM)
  prompt: "Generate and send yesterday's trading summary"
```

Supported deliver targets:
- `"origin"` → Back to the originating chat
- `"telegram"` → Default Telegram bot chat
- `"telegram:CHAT_ID"` → Specific chat ID
- `"telegram:CHAT_ID:THREAD_ID"` → Topic/thread in group

## Method 2: Direct send_message Tool

Best for: real-time alerts triggered by trading events, error notifications.

```json
send_message(to="telegram", text="🚨 EUR/USD triggered buy signal at 1.0850")
```

## Method 3: Inline Response (current session)

When responding in a Telegram group/chat, just reply normally — messages deliver to the originating chat automatically.

## Best Practices

1. **Structured messages** — use emoji + clear format:
   ```
   📊 Daily Report
   Pair: XAUUSD
   Result: +$150
   Win Rate: 67%
   ```

2. **Error alerts** — include actionable info:
   ```
   ⚠️ EA Error Detected
   EA: 7NAGA GOLD v2.1
   Error: Connection timeout
   Action: Check VPS internet
   ```

3. **Avoid spam** — group related info into single messages, not multiple.

4. **Batch reports** — send consolidated daily/weekly reports instead of per-trade alerts.

## MQL5 Example — Send Alert to Telegram

```mql5
//+------------------------------------------------------------------+
//| Simple Telegram Sender for MQL5                                   |
//+------------------------------------------------------------------+
#include <WinHttp32.mqh>

bool SendTelegramMessage(string botToken, long chatId, string message)
{
    string url = "https://api.telegram.org/bot" + botToken +
                 "/sendMessage?chat_id=" + (string)chatId +
                 "&text=" + message;

    char post[];
    char result[];
    string headers = "Content-Type: application/json";

    int timeout = 5000;
    bool res = WebRequest("GET", url, headers, timeout, post, result);

    if(res) Print("Telegram sent successfully");
    else    Print("Telegram send failed, error: ", res);

    return res;
}

//+------------------------------------------------------------------+
//| Usage in EA/Indicator                                            |
//+------------------------------------------------------------------+
void OnTick()
{
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // Example: Alert when price crosses level
    if(price >= 2050.0)
    {
        string msg = "🚀 XAUUSD crossed " + DoubleToString(price, 2);
        SendTelegramMessage("YOUR_BOT_TOKEN", 123456789, msg);
    }
}
```

## MQL4 Example — Send Alert to Telegram

```mql4
//+------------------------------------------------------------------+
//| Simple Telegram Sender for MQL4                                   |
//+------------------------------------------------------------------+
#import "wininet.dll"
int InternetOpenW(string agent, int accessType, string proxyName,
                  string proxyBypass, int flags);
int InternetOpenUrlW(int hInternet, string url, string headers,
                     int headersLen, int flags, int context);
int InternetCloseHandle(int hInternet);
#import

bool SendTelegramMessage(string botToken, long chatId, string message)
{
    string url = "https://api.telegram.org/bot" + botToken +
                 "/sendMessage?chat_id=" + (string)chatId +
                 "&text=" + message;

    int hInternet = InternetOpenW("MQL4", 0, "", "", 0);
    if(hInternet == 0) { Print("InternetOpen failed"); return false; }

    int hConnect = InternetOpenUrlW(hInternet, url, "", 0, 0, 0);
    InternetCloseHandle(hInternet);

    if(hConnect != 0)
    {
        InternetCloseHandle(hConnect);
        Print("Telegram sent successfully");
        return true;
    }

    Print("Telegram send failed");
    return false;
}

//+------------------------------------------------------------------+
//| Usage in EA/Indicator                                            |
//+------------------------------------------------------------------+
void OnTick()
{
    double price = Bid;

    if(price >= 2050.0)
    {
        string msg = "🚀 XAUUSD crossed " + DoubleToStr(price, 2);
        SendTelegramMessage("YOUR_BOT_TOKEN", 123456789, msg);
    }
}
```

## Trade Notification Example (MQL5)

```mql5
//+------------------------------------------------------------------+
//| Send trade alert when order is opened                             |
//+------------------------------------------------------------------+
void OnTrade()
{
    HistorySelect(0, TimeCurrent());
    uint total = HistoryDealsTotal();

    for(uint i = total - 1; i >= 0; i--)
    {
        if(HistoryDealGetTicket(i) > 0)
        {
            string symbol    = HistoryDealGetString(i, DEAL_SYMBOL);
            double volume    = HistoryDealGetDouble(i, DEAL_VOLUME);
            double price     = HistoryDealGetDouble(i, DEAL_PRICE);
            long   type      = HistoryDealGetInteger(i, DEAL_TYPE);
            string typeStr   = type == DEAL_TYPE_BUY ? "BUY" : "SELL";

            string msg = StringFormat(
                "📊 Trade Alert\n%s %s %.2f @ %.5f",
                typeStr, symbol, volume, price
            );

            SendTelegramMessage("YOUR_BOT_TOKEN", 123456789, msg);
            break; // only notify latest deal
        }
    }
}
```

## Notes

- No separate Telegram API credentials needed — uses the configured bot.
- Cron jobs run in fresh session with no chat context — always include all necessary context in the prompt.
- For Telegram channel posts, use channel username or ID in the deliver target.
- Replace `YOUR_BOT_TOKEN` with your actual Telegram bot token.
- Replace `123456789` with your actual Chat ID (use @userinfobot to get yours).
- For MQL5 WebRequest, add `https://api.telegram.org` to "Allowed URLs" in EA properties.