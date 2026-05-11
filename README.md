# Omon-Omon Repo

Koleksi EA (Expert Advisor) MQL4 & MQL5 untuk MetaTrader.

---

## Cara Request & Push File Baru

### Alur Kerja

```
1. Request coding EA
   └── Kirim prompt / deskripsi strategi ke bot
   
2. Bot generate & buat file
   └── File dibuat di ~/omon-omon/
   
3. Review & koreksi (opsional)
   └── Test, minta revisi jika perlu
   
4. Push ke repo
   └── git push origin main
```

### Prompt Template

```
Buat EA [nama] untuk [pair/timeframe]
Strategy: [deskripsi]
- Entry: [kondisi buy/sell]
- Exit: [TP/SL]
- Filter: [waktu/news/holiday]
```

### Contoh Prompt

```
Buat EA "GridX" untuk GOLD M1
Strategy: Buy jika RSI < 30, Sell jika RSI > 70
- TP: 10 pips, SL: 20 pips
- Lot: 0.01 fix
- Max 3 order per hari
- Skip Senin & US Holiday
```

---

## Struktur Repo

```
omon-omon/
├── README.md     ← kamu sekarang
├── SPEC.md       ← list EA & deskripsi
├── skill.md      ← scripttemplate coding
├── soul.md       ← memory & preferensi
├── MQL4/         ← EA untuk MT4
└── MQL5/         ← EA untuk MT5
```

---

## File EA Publish

Gunakan repo ini untuk development & testing.  
Repo stabil: [public-collection](https://github.com/Lybeedo/public-collection)