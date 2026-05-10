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

## Notes

- No separate Telegram API credentials needed — uses the configured bot.
- Cron jobs run in fresh session with no chat context — always include all necessary context in the prompt.
- For Telegram channel posts, use channel username or ID in the deliver target.