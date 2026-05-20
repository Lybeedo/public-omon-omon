# JavaneseTrader EA - MT4/MT5 Expert Advisor

**Filosofi trading:** *"Tuku ketika rego ra gelem mudun. Dol ketika rego ra gelem munggah."*

> Beli ketika harga sudah tidak mau turun lagi. Jual ketika harga sudah tidak mau naik lagi.

---

## Struktur Folder

```
omon-omon/
  MT4/                 # MetaTrader 4 (MQ4)
    Experts/           # Expert Advisors
    Indicators/        # Custom Indicators
    Scripts/           # Standalone Scripts
    Include/           # Shared Header Files
  MT5/                 # MetaTrader 5 (MQ5)
    Experts/           # Expert Advisors
    Indicators/        # Custom Indicators
    Scripts/           # Standalone Scripts
    Include/           # Shared Header Files
  Mentahan/            # File mentah / raw resources
  Skills/              # Dokumentasi skill & workflow
```

---

## Fitur Utama

### Strategi Entry
- **TUKU (Buy):** Price refuses to go down
  - Swing low detection
  - Higher low confirmation
  - RSI oversold filter (opsional)

- **DOL (Sell):** Price refuses to go up
  - Swing high detection
  - Lower high confirmation
  - RSI overbought filter (opsional)

### Risk Management
- Fixed lot atau dynamic lot (% risk)
- Stop Loss (static points atau ATR-based)
- Take Profit (static points atau RR ratio)
- Breakeven lock setelah X points profit

### Trailing Stop
- **STEP:** SL bergerak per step setelah trigger
- **LINEAR:** SL mengikuti harga dengan distance tetap

### Filter & Control
- RSI filter
- Session filter (jam trading)
- Max concurrent orders per symbol

---

## Instalasi

### MT5
1. Copy file `.mq5` dari folder `MT5/` ke:
   ```
   %APPDATA%\MetaQuotes\Terminal\<ID>\MQL5\
   ```
2. Restart MT5 terminal
3. Navigator > Expert Advisors > Drag ke chart

### MT4
1. Copy file `.mq4` dari folder `MT4/` ke:
   ```
   %APPDATA%\MetaQuotes\Terminal\<ID>\MQL4\
   ```
2. Restart MT4 terminal
3. Navigator > Expert Advisors > Drag ke chart

---

## Parameter Inputs

### Entry Settings
| Parameter | Default | Deskripsi |
|-----------|---------|-----------|
| LookbackPeriod | 20 | Jumlah candle untuk swing detection |
| MinSwingSize | 0.5% | Minimum swing size |
| WaitCandles | 3 | Konfirmasi candle sebelum entry |
| UseRSIFilter | true | Aktifkan RSI filter |
| RSIPeriod | 14 | RSI period |
| RSIBuyLevel | 30 | RSI oversold threshold |
| RSISellLevel | 70 | RSI overbought threshold |

### Risk Management
| Parameter | Default | Deskripsi |
|-----------|---------|-----------|
| RiskPercent | 2.0% | Risk per trade |
| FixedLot | 0.0 | Fixed lot (0 = use RiskPercent) |
| StopLossPoints | 500 | SL dalam points (0 = ATR dynamic) |
| TakeProfitPoints | 1000 | TP dalam points (0 = RR ratio) |
| TakeProfitRatio | 2.0 | TP:SL ratio |
| UseBreakeven | true | Aktifkan breakeven |
| BreakevenOffset | 100 | Points profit sebelum BE trigger |

### Trailing
| Parameter | Default | Deskripsi |
|-----------|---------|-----------|
| UseTrailing | true | Aktifkan trailing stop |
| TrailingStart | 100 | Points profit untuk mulai trailing |
| TrailingStep | 50 | Step size per movement |
| TrailingDistance | 50 | Jarak dari harga |
| TrailingMode | STEP | STEP atau LINEAR |

---

## Catatan Penting

- **Backtest dulu** sebelum live trading
- Disarankan TF H1 atau lebih
- Kombinasi dengan trend filter (MA cross) meningkatkan akurasi
- Jangan lupa set `MaxOrders` sesuai strategi

---

## Backtest Template

Gunakan Strategy Tester:
- **Period:** M30 - H1
- **Model:** Every tick (or nearest)
- **Date:** Minimal 3 bulan data
- **Deposit:** Sesuaikan dengan risk management

---

## Version History

### v1.00
- Swing detection (Tuku/Dol logic)
- RSI filter
- Trailing stop (Step & Linear)
- Breakeven trigger
- Session filter
- Dynamic lot sizing

---

*"Sabar lan disiplin ngenteni momentum sing bener."*