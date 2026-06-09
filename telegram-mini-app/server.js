/**
 * 🚀 Telegram Mini App — Server
 * Production-ready Express server with Telegram initData validation
 */

const express = require('express');
const crypto = require('crypto');
const path = require('path');
const app = express();

// ─── Middleware ───────────────────────────────────────────
app.use(express.static('public'));
app.use(express.json());

// ─── Config ──────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
const BOT_TOKEN = process.env.BOT_TOKEN || '';

// ─── Health Check ────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: Date.now() });
});

// ─── Telegram initData Validation (WAJIB!) ──────────────
// Doc: https://core.telegram.org/bots/webapps#validating-data-received-via-the-mini-app
function validateTelegramWebAppData(initData, botToken) {
  try {
    const urlParams = new URLSearchParams(initData);
    const hash = urlParams.get('hash');
    if (!hash) return { valid: false, error: 'No hash provided' };

    urlParams.delete('hash');

    // Sort params alphabetically
    const dataCheckArr = [];
    for (const [key, value] of urlParams.entries()) {
      dataCheckArr.push(`${key}=${value}`);
    }
    dataCheckArr.sort();
    const dataCheckString = dataCheckArr.join('\n');

    // HMAC-SHA256 with secret key from bot token
    const secretKey = crypto
      .createHmac('sha256', 'WebAppData')
      .update(botToken)
      .digest();

    const computedHash = crypto
      .createHmac('sha256', secretKey)
      .update(dataCheckString)
      .digest('hex');

    if (computedHash !== hash) {
      return { valid: false, error: 'Hash mismatch' };
    }

    // Check auth_date (max 24 hours)
    const authDate = parseInt(urlParams.get('auth_date') || '0', 10);
    const maxAge = 24 * 60 * 60; // 24 hours
    if (Date.now() / 1000 - authDate > maxAge) {
      return { valid: false, error: 'Data expired (>24h)' };
    }

    // Parse user data
    const userRaw = urlParams.get('user');
    const user = userRaw ? JSON.parse(userRaw) : null;

    return { valid: true, user };
  } catch (err) {
    return { valid: false, error: err.message };
  }
}

// ─── API: Validate initData ─────────────────────────────
app.post('/api/validate', (req, res) => {
  const { initData } = req.body;

  if (!initData) {
    return res.status(400).json({ ok: false, error: 'Missing initData' });
  }

  if (!BOT_TOKEN) {
    return res.status(500).json({ ok: false, error: 'BOT_TOKEN not configured' });
  }

  const result = validateTelegramWebAppData(initData, BOT_TOKEN);
  res.json({ ok: result.valid, user: result.user, error: result.error });
});

// ─── API: Receive form/action data from Mini App ────────
app.post('/api/action', (req, res) => {
  const { initData, action, payload } = req.body;

  if (!BOT_TOKEN) {
    return res.status(500).json({ ok: false, error: 'BOT_TOKEN not configured' });
  }

  const validation = validateTelegramWebAppData(initData, BOT_TOKEN);
  if (!validation.valid) {
    return res.status(403).json({ ok: false, error: 'Unauthorized' });
  }

  // 🔧 TAMBAHIN LOGIC LO DI SINI
  console.log(`📨 Action from ${validation.user?.first_name}:`, action, payload);

  res.json({
    ok: true,
    message: `Action "${action}" received`,
    user: validation.user?.first_name
  });
});

// ─── Fallback → index.html ──────────────────────────────
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// ─── Start ───────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`🚀 Mini App server running on port ${PORT}`);
  console.log(`📡 Health: http://localhost:${PORT}/health`);
  if (!BOT_TOKEN) console.warn('⚠️  BOT_TOKEN not set — validation will fail');
});
