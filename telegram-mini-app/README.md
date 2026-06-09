# 🚀 Telegram Mini App Boilerplate

Siap pakai, tinggal deploy!

## 📁 Struktur

```
telegram-mini-app/
├── public/
│   └── index.html        ← Frontend (Mini App UI)
├── server.js              ← Express server + initData validation
├── bot.js                 ← Telegram bot (handles /start + receives data)
├── .env.example           ← Config template
├── package.json
└── README.md
```

## 🏁 Quick Start

### 1. Setup
```bash
cp .env.example .env
# Edit .env — isi BOT_TOKEN dan WEBAPP_URL
npm install
```

### 2. Jalankan
```bash
# Terminal 1 — Server (serve frontend + API)
npm start

# Terminal 2 — Bot
node bot.js
```

### 3. Test Lokal (butuh HTTPS)
```bash
# Pakai ngrok
npm install -g ngrok
ngrok http 3000
# Copy HTTPS URL → set ke WEBAPP_URL di .env
```

### 4. Setup Bot
```
1. Chat @BotFather
2. /mybots → pilih bot
3. Bot Settings → Menu Button → Configure
4. Masukkan URL Mini App lo
```

## 🌐 Deploy

### Vercel
```bash
npm i -g vercel
vercel --prod
```

### Railway
```bash
railway login
railway init
railway up
```

### Docker
```bash
docker build -t mini-app .
docker run -p 3000:3000 --env-file .env mini-app
```

### VPS (PM2)
```bash
npm install -g pm2
pm2 start server.js --name mini-app
pm2 start bot.js --name mini-bot
pm2 save
```

## 📡 API Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/health` | GET | Health check |
| `/api/validate` | POST | Validate Telegram initData |
| `/api/action` | POST | Receive actions from Mini App |

## 🔒 Security

- ✅ `initData` HMAC-SHA256 validation
- ✅ 24h expiry check on auth_date
- ✅ Server-side user verification

## 📱 Mini App Features

- 🎨 Auto theme (light/dark ikut Telegram)
- 📳 Haptic feedback
- 💬 Native popups (bukan alert())
- 🔙 BackButton support
- ✅ Closing confirmation
- 📤 sendData() ke bot

## ⚡ Credits

Built with ❤️ for **Cuancux Algo Traders** community
