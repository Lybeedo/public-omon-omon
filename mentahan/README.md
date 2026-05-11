# MENTAHAN — Raw / Unprocessed EAs & Indicators

Folder ini berisi file EA/indicator mentah yang belum diproses. Setiap file adalah kandidat untuk dipelajari, dimodifikasi, atau di-backtest.

---

## File Index

### 1. MTF_Trend_Confluence.mq4
**Tipe:** Custom Indicator  
**Platform:** MT4  
**Strategy:** Multi-Timeframe EMA Confluence

```
BUY  → >= 3 TF setuju EMA9 > EMA21 (bullish)
SELL → >= 3 TF setuju EMA9 < EMA21 (bearish)
```

| TF | Fast EMA | Slow EMA | Min Agreement |
|----|----------|----------|---------------|
| M5/M15/H1/H4/D1 | 9 | 21 | 3 of 5 |

- Arrow + strength label di chart
- Confluence table (★/☆) di corner kanan atas
- ATR-based arrow offset
- Fire only on **transition** (tidak repeat)

**Catatan:** Indicator-only, tidak ada execution. Bisa jadi komponen TF filter untuk EA lain.

---

### 2. RoyalHegen_EA.mq5 (v1.16)
**Tipe:** EA (Scalping)  
**Platform:** MT5  
**Strategy:** Multi-Filter Stochastic + EMA + ADX + HalfTrend

```
BUY:
  - Stochastic %K <= Oversold (20)
  - %K cross UP %D
  - Harga di atas EMA200 (uptrend)
  - ADX > 25 + DI+ > DI-
  - HalfTrend = UP
  MAX 1 posisi per arah, hedge allowed

SELL:
  - Stochastic %K >= Overbought (80)
  - %K cross DOWN %D
  - Harga di bawah EMA200 (downtrend)
  - ADX > 25 + DI- > DI+
  - HalfTrend = DOWN
```

**Fitur:**
- DDR (Drawdown Reduction) — posisi ke-N+1 close posisi pertama
- Averaging — tiap 200 pts, lot multiplier
- Trailing stop (start 200 pts, distance 20 pts)
- Daily profit target ($)
- Cooldown setelah TP
- Panel visual

**Catatan:** No internal SL/TP — dirancang dikelola EA lain. Martingale tidak aktif (multiplier=1.0).

---

### 3. Prime_Quantum_AI.mq5 (v3.21)
**Tipe:** EA (AI Hybrid)  
**Platform:** MT5  
**Strategy:** AI chart analysis + indicator pre-filter

```
Mode 0 (Indicators Only):
  ADX + Alligator pre-filter → signal

Mode 1 (AI Hybrid):
  ADX + Alligator pre-filter → capture chart → AI analyze
  → direction + SL/TP from AI
```

**AI Providers:** Anthropic Claude, OpenAI GPT, Google Gemini, DeepSeek, xAI Grok

**Account Modes:**
- Standard Broker (money filter: equity target/stop)
- Prop Firm / Challenge (daily DD, trailing DD, target %)
- Funded Account

**Risk Modes:** Fixed Lot, % Balance, % Equity, Fixed $, % Free Margin

**Fitur:**
- Martingale (configurable multiplier & max level)
- Trailing: Fixed / ATR / Breakeven
- Partial close (2 tier)
- News filter (High Impact, before/after minutes)
- Trading hours filter
- Spread filter
- Emergency close key

**Catatan:** Requires API keys + WebRequest allowance di MT5 options. Complex — 2928 lines.

---

### 4. Murray Expert v6.mq4
**Tipe:** EA  
**Platform:** MT4  
**Status:** Binary file — tidak dapat dibaca/dianalisis.

---

## Status Notes

| File | Readable | Strategy Clear | Integration Candidate |
|------|----------|----------------|---------------------|
| MTF_Trend_Confluence.mq4 | Yes | Yes | TF filter component |
| RoyalHegen_EA.mq5 | Yes | Yes | Averaging/DDR module |
| Prime_Quantum_AI.mq5 | Yes | Yes | AI signal component |
| Murray Expert v6.mq4 | No | - | - |

---

*Last updated: 2026-05-10*
