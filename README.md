# Omon-Omon Repo

Koleksi EA (Expert Advisor) MQL4 & MQL5 untuk MetaTrader.

---

## Cara Request File Baru & Push ke Repo

### Alur Kerja

```
1. Request
   Kirim prompt / deskripsi strategi ke bot

2. Bot Generate
   Bot buat file EA di ~/omon-omon/

3. Review & Koreksi
   Test, minta revisi jika perlu

4. Push ke Repo
   git push origin main
```

---

### Prompt Template

```
Buat EA [nama] untuk [pair] [timeframe]
Strategy: [deskripsi singkat]
- Entry: [kondisi buy/sell]
- Exit: [TP/SL]
- Filter: [waktu/news/holiday]
- Lot: [fixed/risk-based]
```

### Contoh Prompt

**Sederhana:**
```
Buat EA "GridX" untuk GOLD M1
Strategy: Buy jika RSI < 30, Sell jika RSI > 70
- TP: 10 pips, SL: 20 pips
- Lot: 0.01 fix
```

**Lengkap:**
```
Buat EA "BreakoutX" untuk GOLD H1
Strategy: Breakout highest high 20 bar + pullback entry
- Range: 20 bar
- Entry: Pullback ke level yang di-break
- SL: ATR 14 x 1.5
- TP: 1R (TP1) + 2R (TP2)
- Lot: Risk 2%
- Filter: Skip high-impact news
- Max 1 trade per sinyal
```

---

## Struktur Repo

```
omon-omon/
├── README.md     ← kamu sekarang
├── SPEC.md       ← list EA & strategy
├── skill.md      ← script template
├── soul.md       ← memory & preferensi
├── MQL4/         ← EA MT4
└── MQL5/         ← EA MT5
```

---

## Catatan

- Repo ini untuk development & testing
- Repo stabil (hanya README): [public-collection](https://github.com/Lybeedo/public-collection)
- Setelah EA selesai, strategy-nya ditulis di SPEC.md