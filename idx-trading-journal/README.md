# 📊 IDX Trading Journal — AI Powered

Jurnal trading saham IDX otomatis pakai **Google Gemini API** (gratis).  
Upload screenshot chart/PDF dari broker atau input manual. AI akan ekstrak data + berikan insight reasoning.

---

## 🚀 Quick Start (Siap Pakai)

### 1. Install Dependensi
```bash
uv pip install google-generativeai pillow pandas
```

### 2. Setup API Key
1. Buka [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Buat API Key → Copy
3. Paste di `config.json` atau set environment variable:
```bash
export GEMINI_API_KEY="your_key_here"
```

### 3. Jalankan
```bash
uv run trading_journal.py
```

---

## 📂 Cara Kerja

| Mode | Cara | Output |
|------|------|--------|
| 📸 **Image Upload** | Screenshot chart/order book → upload | AI ekstrak: symbol, harga, P&L, setup |
| 📄 **PDF Upload** | Trade report dari broker (PDF) | AI baca & ringkaskan |
| ⌨️ **Manual Input** | Ketik sendiri data trade | AI berikan reasoning & evaluasi |

Semua trade disimpan ke `journal/idx_trading_journal.csv`

---

## 🎯 Fitur

- ✅ **AI Image Analysis** — Gemini baca screenshot chart/MT5
- ✅ **PDF Text Extraction** — via Gemini + OCR bawaan
- ✅ **Manual Entry** — Input cepat via prompt
- ✅ **Auto Reasoning** — AI evaluasi: disiplin, emosi, setup quality
- ✅ **CSV Export** — Bisa dibuka di Excel/Google Sheets
- ✅ **Statistics** — Win rate, R-ratio, profit/loss summary
- ✅ **IDX Saham Support** — Format khusus BBRI, TLKM, BBCA, dst

---

## 📁 Output CSV Fields

```
tanggal, symbol, direction, entry, exit, sl, tp, volume, pnl, 
setup_type, emotion, discipline_score, ai_notes, screenshot_path
```

---

## 🛠️ Requirements

- Python 3.10+
- `uv` (installer) atau `pip`
- Google Gemini API Key (gratis tier)

---

Made for 🇮🇩 IDX traders | No grid, no martingale, pure adaptive AI 📈
