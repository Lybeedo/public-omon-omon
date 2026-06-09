/**
 * 🤖 Telegram Bot — Mini App Launcher
 * Handles /start and receives data from the Mini App
 */

const TelegramBot = require('node-telegram-bot-api');

// ─── Config ──────────────────────────────────────────────
const BOT_TOKEN = process.env.BOT_TOKEN;
const WEBAPP_URL = process.env.WEBAPP_URL || 'https://YOUR-DOMAIN.com';

if (!BOT_TOKEN) {
  console.error('❌ BOT_TOKEN required! Set it in .env');
  process.exit(1);
}

const bot = new TelegramBot(BOT_TOKEN, { polling: true });

console.log('🤖 Bot started! Waiting for messages...');

// ─── /start — Launch Mini App ───────────────────────────
bot.onText(/\/start/, (msg) => {
  const chatId = msg.chat.id;
  const name = msg.from?.first_name || 'User';

  bot.sendMessage(chatId,
    `🚀 *Selamat datang, ${name}!*\n\nKlik tombol di bawah buat buka Mini App 👇`,
    {
      parse_mode: 'Markdown',
      reply_markup: {
        inline_keyboard: [
          [{ text: '📱 Buka Mini App', web_app: { url: WEBAPP_URL } }]
        ]
      }
    }
  );
});

// ─── /help ───────────────────────────────────────────────
bot.onText(/\/help/, (msg) => {
  bot.sendMessage(msg.chat.id,
    `📖 *Commands:*\n\n` +
    `/start — Buka Mini App\n` +
    `/help — Bantuan\n`,
    { parse_mode: 'Markdown' }
  );
});

// ─── Receive data dari Mini App ─────────────────────────
bot.on('web_app_data', (msg) => {
  const chatId = msg.chat.id;
  const rawData = msg.web_app_data?.data;

  try {
    const data = JSON.parse(rawData);
    console.log('📩 Data from Mini App:', data);

    // 🔧 HANDLE DATA DARI MINI APP DI SINI
    const action = data.action || 'unknown';

    switch (action) {
      case 'submit':
        bot.sendMessage(chatId,
          `✅ Data berhasil diterima!\n\n` +
          `📋 Data: \`${JSON.stringify(data)}\``,
          { parse_mode: 'Markdown' }
        );
        break;

      case 'demo_click':
        bot.sendMessage(chatId, `🖱️ Kamu klik tombol demo!`);
        break;

      default:
        bot.sendMessage(chatId,
          `📦 Data: \`${rawData}\``,
          { parse_mode: 'Markdown' }
        );
    }
  } catch (err) {
    console.error('❌ Parse error:', err.message);
    bot.sendMessage(chatId, `📦 Raw: ${rawData}`);
  }
});

// ─── Error handler ──────────────────────────────────────
bot.on('polling_error', (err) => {
  console.error('🔴 Polling error:', err.code, err.message);
});
