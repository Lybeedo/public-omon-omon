# 📊 IDX Trading Journal — AI Powered (Web UI)

Jurnal trading saham IDX otomatis pakai **Google Gemini API** (gratis).  
Buka di browser → Upload screenshot/PDF atau input manual. AI ekstrak data + berikan insight.

---

## 🚀 Quick Start (Siap Pakai)

### 1. Install Dependensi
```bash
uv pip install -r requirements.txt
# atau: pip install -r requirements.txt
```

### 2. Setup API Key
1. Buka [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Buat API Key → Copy
3. Edit `config.json`:
```json
{
  "gemini_api_key": "sk-...your-key...",
  "model": "gemini-2.5-flash"
}
```

### 3. Jalankan Web UI
```bash
# Windows
run.bat

# Linux/Mac
chmod +x run.sh && ./run.sh

# Atau langsung
python app.py
```

**Browser otomatis terbuka di:** `http://localhost:7860`

---

## 📑 4 Tab di Browser

| Tab | Cara | Output |
|-----|------|--------|
| 📸 **Upload Image** | Drop screenshot chart/order book | AI ekstrak: symbol, harga, P&L, setup |
| 📝 **Manual Entry** | Isi form trade | AI berikan reasoning, discipline score, R-ratio |
| 📄 **PDF Report** | Upload trade report broker | AI baca & ringkaskan semua trade |
| 📊 **History & Stats** | Lihat semua trade | Win rate, total P&L, setup distribution |

---

## 📁 Files

```
idx-trading-journal/
├── app.py                ← Main Web UI (Gradio)
├── trading_journal.py    ← CLI version (backup)
├── requirements.txt      ← Dependencies
├── config.json           ← API key & settings
├── run.bat               ← Windows launcher
├── run.sh                ← Linux/Mac launcher
└── .env.example          ← API key template
```

---

## 📋 CSV Export

Semua trade auto-save ke `journal/idx_trading_journal.csv`

Buka di Excel/Google Sheets untuk analisis lebih lanjut.

---

## 🎯 Fitur

- ✅ **Web UI** — Buka di browser, tanpa install aplikasi
- ✅ **AI Image Analysis** — Gemini baca screenshot chart/MT5
- ✅ **PDF Text Extraction** — Baca report broker
- ✅ **Manual Entry** — Input cepat via form
- ✅ **Auto Reasoning** — AI evaluasi: disiplin, emosi, setup quality
- ✅ **CSV Export** — Bisa dibuka di Excel/Google Sheets
- ✅ **Statistics** — Win rate, R-ratio, profit/loss summary
- ✅ **IDX Saham Support** — Format khusus BBRI, TLKM, BBCA, dst

---

## 🛠️ Requirements

- Python 3.10+
- Google Gemini API Key (gratis tier)
- Chrome/Edge/Firefox (any modern browser)

---

Made for 🇮🇩 IDX traders | No grid, no martingale, pure adaptive AI 📈
