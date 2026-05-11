# SPEC — EA Strategy List

Deskripsi strategy ditulis di sini setelah EA selesai dibuat.

---

## 7NAGA
**File:** `MQL4/Experts/SevenCandleNaga.mq4`, `MQL5/Experts/SevenCandleNaga.mq5`  
**Symbol:** GOLD (XAUUSD) | **Timeframe:** Intraday (M1)  
**Method:** Buy Stop + Sell Stop

**Rules:**
- Analisis: 09:30 WIB | Expiry: 17:00 WIB
- Buy Stop = HIGH (kelipatan 5) + 100 pts
- Sell Stop = LOW (kelipatan 5) - 25 pts
- SL = oneshot
- 6 zona TP: 10/15/30/50/100/200 pips (0.01 lot per zona)
- Filter: Senin, NFP, FOMC, CPI, US Holiday
- Distance: 70-200 pips (outside = skip)

---

## CoinFlipEA
**File:** `MQL5/Experts/CoinFlipEA.mq5`  
**Symbol:** Multi-pair | **Timeframe:** Configurable (M1 default)  
**Method:** Flip trading dengan kapitalisasi

**Rules:**
- Start: $500 → Target: $5000
- RR 1:2 — Risk $50, Reward $100
- Lot sizing otomatis berdasarkan risk
- Flip trigger: new candle / instant
- Filter sesi: Asia, London, New York

---

## 7NAGA Signal
**File:** `MQL5/Experts/SevenNagaSignal_MQ5.mq5`  
**Symbol:** GOLD (XAUUSD) | **Timeframe:** M30  
**Method:** Indikator + auto-send signal ke Telegram

**Rules:**
- Ambil HIGH/LOW dari 7 candle terakhir
- Kirim pesan ke Telegram: Buy Stop price, Sell Stop price
- Gambar garis HIGH (merah) dan LOW (hijau)
- Skip Senin

---

## Breakout & Pullback
**File:** `MQL4/Experts/BreakoutPullback.mq4`, `MQL5/Experts/BreakoutPullback.mq5`  
**Symbol:** GOLD (XAUUSD) | **Timeframe:** H1  
**Method:** Breakout range + retest entry

**Rules:**
- Range: 20 bar | Min range: 100 pips
- Entry: Pullback ke level yang di-break
- SL: ATR 14 x 1.5
- TP: 1R (50%) + 2R (50%)
- Lot: Risk 2%