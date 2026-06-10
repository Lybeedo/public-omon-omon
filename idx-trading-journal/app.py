#!/usr/bin/env python3
"""
IDX Trading Journal — Web UI (Gradio)
Powered by Google Gemini API (gratis)

Usage:
    uv pip install -r requirements.txt
    python app.py
"""

import os
import sys
import json
import csv
import shutil
from datetime import datetime
from pathlib import Path
from typing import Dict

import gradio as gr
import pandas as pd
import google.genai as genai
from PIL import Image as PILImage

# ───────────────────────────────────────────────
# CONFIG
# ───────────────────────────────────────────────
CONFIG_PATH = "config.json"
JOURNAL_DIR = Path("journal")
SCREENSHOTS_DIR = JOURNAL_DIR / "screenshots"
JOURNAL_DIR.mkdir(exist_ok=True)
SCREENSHOTS_DIR.mkdir(exist_ok=True)

FIELDS = [
    "timestamp", "date", "symbol", "direction", "entry", "exit", "sl", "tp",
    "volume", "pnl", "pnl_percent", "setup_type", "emotion", "discipline_score",
    "r_ratio", "ai_analysis", "ai_lessons", "screenshot_path", "manual_notes"
]

SETUP_TYPES = [
    "breakout", "pullback", "reversal", "trend following",
    "support bounce", "resistance rejection", "news play", "scalping"
]

EMOTIONS = ["tenang", "greedy", "takut", "netral", "FOMO", "yakin"]


def load_config() -> dict:
    if os.path.exists(CONFIG_PATH):
        with open(CONFIG_PATH, "r") as f:
            return json.load(f)
    return {}


def save_config(cfg: dict):
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)


def init_gemini(api_key: str = None):
    if api_key is None:
        cfg = load_config()
        api_key = cfg.get("gemini_api_key") or os.getenv("GEMINI_API_KEY", "")
    if not api_key or api_key.startswith("YOUR_"):
        return None
    return genai.Client(api_key=api_key)


CLIENT = init_gemini()
MODEL_NAME = load_config().get("model", "gemini-2.5-flash")


def get_api_key_status():
    cfg = load_config()
    key = cfg.get("gemini_api_key", "")
    if key and not key.startswith("YOUR_"):
        return "🟢 API Key sudah aktif", key
    return "🔴 API Key belum diisi — AI fitur gak bisa jalan", ""


def set_api_key(key_input: str):
    global CLIENT
    key = key_input.strip()
    if not key:
        return "🔴 API Key kosong", ""
    cfg = load_config()
    cfg["gemini_api_key"] = key
    save_config(cfg)
    CLIENT = init_gemini(key)
    return "🟢 API Key aktif — AI ready!", key

def get_csv_path() -> str:
    cfg = load_config()
    return cfg.get("journal_file", str(JOURNAL_DIR / "idx_trading_journal.csv"))


def init_csv():
    path = get_csv_path()
    if not os.path.exists(path):
        with open(path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(FIELDS)


def read_csv() -> pd.DataFrame:
    path = get_csv_path()
    if not os.path.exists(path):
        return pd.DataFrame(columns=FIELDS)
    return pd.read_csv(path, encoding="utf-8")


def append_csv(row: Dict):
    path = get_csv_path()
    with open(path, "a", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        writer.writerow(row)


def parse_symbol(raw: str) -> str:
    raw = raw.upper().strip()
    if not raw.endswith(".JK") and len(raw) <= 4:
        raw = raw + ".JK"
    return raw


def save_upload(file_path: str) -> str:
    if not file_path or not os.path.exists(file_path):
        return ""
    ext = Path(file_path).suffix
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    dest = SCREENSHOTS_DIR / f"trade_{ts}{ext}"
    shutil.copy2(file_path, dest)
    return str(dest)


def calc_pnl_percent(entry: float, exit: float, direction: str) -> float:
    if entry == 0:
        return 0.0
    if direction.upper() == "BUY":
        return round((exit - entry) / entry * 100, 2)
    else:
        return round((entry - exit) / entry * 100, 2)


def calc_r_ratio(entry: float, sl: float, tp: float, direction: str) -> str:
    try:
        if direction.upper() == "BUY":
            risk = entry - sl
            reward = tp - entry
        else:
            risk = sl - entry
            reward = entry - tp
        if risk == 0:
            return "-"
        return str(round(reward / risk, 2))
    except:
        return "-"


# ───────────────────────────────────────────────
# GEMINI HELPERS (new SDK: google.genai)
# ───────────────────────────────────────────────

def gemini_image_analysis(image_path: str) -> str:
    if not CLIENT:
        return "ERROR: Gemini API key belum diset."
    try:
        img = PILImage.open(image_path)
        prompt = """
Kamu adalah asisten jurnal trading profesional untuk saham Indonesia (IDX).
Analisis screenshot chart/trade ini dan ekstrak data dalam format:

SYMBOL: [kode saham, tambahkan .JK]
DIRECTION: [BUY atau SELL]
ENTRY: [harga entry]
EXIT: [harga exit, kosong jika masih open]
SL: [stop loss]
TP: [take profit]
VOLUME: [lot]
PNL: [profit/loss dalam Rupiah]
SETUP_TYPE: [breakout/pullback/reversal/trend following/support bounce/resistance rejection/news play/scalping]

Berikan juga:
ANALISIS: evaluasi singkat trade (2-3 kalimat)
LESSON: pelajaran yang bisa dipetik
DISCIPLINE_SCORE: 1-10 (apakah trade sesuai plan?)

Jika data tidak terlihat, tulis "NOT_VISIBLE".
"""
        response = CLIENT.models.generate_content(
            model=MODEL_NAME,
            contents=[prompt, img]
        )
        return response.text
    except Exception as e:
        return f"ERROR: {e}"


def gemini_pdf_analysis(pdf_path: str) -> str:
    if not CLIENT:
        return "ERROR: Gemini API key belum diset."
    try:
        prompt = """
Kamu adalah asisten jurnal trading profesional untuk saham Indonesia (IDX).
Baca PDF trade report ini dan ekstrak SEMUA trade dalam format:

SYMBOL: [kode saham .JK]
DIRECTION: [BUY/SELL]
ENTRY: [harga]
EXIT: [harga]
SL: [stop loss]
TP: [take profit]
VOLUME: [lot]
PNL: [profit/loss]
SETUP_TYPE: [breakout/pullback/reversal/dll]
TANGGAL: [DD/MM/YYYY]

Berikan ringkasan total P&L dan evaluasi disiplin trading.
"""
        file_obj = CLIENT.files.upload(file=pdf_path)
        response = CLIENT.models.generate_content(
            model=MODEL_NAME,
            contents=[prompt, file_obj]
        )
        return response.text
    except Exception as e:
        return f"ERROR: {e}"


def gemini_reasoning(trade_data: dict) -> dict:
    if not CLIENT:
        return {"ai_analysis": "API key belum diset", "ai_lessons": "-", "discipline_score": "5", "r_ratio": "-"}
    prompt = f"""
Kamu adalah mentor trading profesional. Evaluasi trade ini:

Symbol: {trade_data['symbol']}
Direction: {trade_data['direction']}
Entry: {trade_data['entry']}
Exit: {trade_data['exit']}
SL: {trade_data['sl']}
TP: {trade_data['tp']}
P&L: {trade_data['pnl']}
Setup: {trade_data['setup_type']}
Emosi: {trade_data['emotion']}
Notes: {trade_data['manual_notes']}

Berikan dalam format:
ANALISIS: [evaluasi singkat]
LESSON: [pelajaran]
DISCIPLINE_SCORE: [1-10]
R_RATIO: [risk/reward ratio, hitung dari entry/sl/tp]
"""
    try:
        response = CLIENT.models.generate_content(
            model=MODEL_NAME,
            contents=[prompt]
        )
        text = response.text
        return parse_ai_response(text)
    except Exception as e:
        return {"ai_analysis": f"Error: {e}", "ai_lessons": "-", "discipline_score": "5", "r_ratio": "-"}


def parse_ai_response(text: str) -> dict:
    result = {"ai_analysis": "", "ai_lessons": "", "discipline_score": "", "r_ratio": ""}
    for line in text.split("\n"):
        if line.startswith("ANALISIS:"):
            result["ai_analysis"] = line.replace("ANALISIS:", "").strip()
        elif line.startswith("LESSON:"):
            result["ai_lessons"] = line.replace("LESSON:", "").strip()
        elif line.startswith("DISCIPLINE_SCORE:"):
            result["discipline_score"] = line.replace("DISCIPLINE_SCORE:", "").strip()
        elif line.startswith("R_RATIO:"):
            result["r_ratio"] = line.replace("R_RATIO:", "").strip()
    return result


def parse_image_response(text: str) -> dict:
    data = {k: "" for k in ["symbol", "direction", "entry", "exit", "sl", "tp", "volume", "pnl", "setup_type", "ai_analysis", "ai_lessons", "discipline_score", "r_ratio"]}
    for line in text.split("\n"):
        if ":" in line:
            key, val = line.split(":", 1)
            key = key.strip().lower()
            val = val.strip()
            if key in data:
                data[key] = val
    return data


# ───────────────────────────────────────────────
# HANDLERS
# ───────────────────────────────────────────────

def handle_image_upload(image, date, emotion, notes):
    if image is None:
        return "❌ Upload image dulu", "", {}, "", ""

    # Save image
    temp_path = f"/tmp/gradio_upload_{datetime.now().strftime('%Y%m%d%H%M%S')}.png"
    image.save(temp_path)
    saved_path = save_upload(temp_path)

    # Gemini analysis
    result = gemini_image_analysis(temp_path)
    if result.startswith("ERROR"):
        return f"❌ {result}", "", {}, "", ""

    data = parse_image_response(result)

    # Build response
    extracted = f"""
**📊 Data Terekstrak:**
- Symbol: {data.get('symbol', 'N/A')}
- Direction: {data.get('direction', 'N/A')}
- Entry: {data.get('entry', 'N/A')}
- Exit: {data.get('exit', 'N/A')}
- SL: {data.get('sl', 'N/A')}
- TP: {data.get('tp', 'N/A')}
- Volume: {data.get('volume', 'N/A')}
- P&L: {data.get('pnl', 'N/A')}
- Setup: {data.get('setup_type', 'N/A')}
"""

    ai_analysis = data.get('ai_analysis', '')
    ai_lessons = data.get('ai_lessons', '')
    discipline = data.get('discipline_score', '5')
    r_ratio = data.get('r_ratio', '-')

    # Prepare row data
    entry_f = float(data.get('entry', '0') or 0)
    exit_f = float(data.get('exit', '0') or 0)
    direction = data.get('direction', 'BUY').upper()

    row = {
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "date": date or datetime.now().strftime("%d/%m/%Y"),
        "symbol": parse_symbol(data.get('symbol', '')),
        "direction": direction,
        "entry": str(entry_f),
        "exit": str(exit_f) if exit_f else "",
        "sl": str(float(data.get('sl', '0') or 0)),
        "tp": str(float(data.get('tp', '0') or 0)),
        "volume": str(int(float(data.get('volume', '1') or 1))),
        "pnl": str(float(data.get('pnl', '0') or 0)),
        "pnl_percent": str(calc_pnl_percent(entry_f, exit_f if exit_f else entry_f, direction)),
        "setup_type": data.get('setup_type', 'breakout'),
        "emotion": emotion,
        "discipline_score": discipline,
        "r_ratio": r_ratio,
        "ai_analysis": ai_analysis,
        "ai_lessons": ai_lessons,
        "screenshot_path": saved_path,
        "manual_notes": notes
    }

    append_csv(row)
    return "✅ Trade tersimpan!", extracted, row, ai_analysis, ai_lessons


def handle_manual_entry(symbol, direction, entry, exit, sl, tp, volume, pnl, setup_type, emotion, date, notes):
    if not symbol:
        return "❌ Symbol wajib diisi", "", "", ""

    symbol = parse_symbol(symbol)
    entry_f = float(entry or 0)
    exit_f = float(exit or 0)
    sl_f = float(sl or 0)
    tp_f = float(tp or 0)
    pnl_f = float(pnl or 0)
    direction = direction.upper()

    # AI reasoning
    trade_data = {
        "symbol": symbol, "direction": direction, "entry": entry_f,
        "exit": exit_f, "sl": sl_f, "tp": tp_f, "pnl": pnl_f,
        "setup_type": setup_type, "emotion": emotion, "manual_notes": notes
    }
    ai = gemini_reasoning(trade_data)

    r_ratio = ai.get('r_ratio', calc_r_ratio(entry_f, sl_f, tp_f, direction))

    row = {
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "date": date or datetime.now().strftime("%d/%m/%Y"),
        "symbol": symbol,
        "direction": direction,
        "entry": str(entry_f),
        "exit": str(exit_f) if exit_f else "",
        "sl": str(sl_f),
        "tp": str(tp_f),
        "volume": str(int(volume or 1)),
        "pnl": str(pnl_f),
        "pnl_percent": str(calc_pnl_percent(entry_f, exit_f if exit_f else entry_f, direction)),
        "setup_type": setup_type,
        "emotion": emotion,
        "discipline_score": ai.get('discipline_score', '5'),
        "r_ratio": r_ratio,
        "ai_analysis": ai.get('ai_analysis', ''),
        "ai_lessons": ai.get('ai_lessons', ''),
        "screenshot_path": "",
        "manual_notes": notes
    }

    append_csv(row)

    summary = f"""
**✅ Trade Tersimpan!**

📊 Discipline Score: {row['discipline_score']}/10
📈 R-Ratio: {r_ratio}

🤖 AI Analysis:
{ai.get('ai_analysis', '-')}

💡 Lesson:
{ai.get('ai_lessons', '-')}
"""

    return "✅ Saved", summary, ai.get('ai_analysis', ''), ai.get('ai_lessons', '')


def handle_pdf_upload(pdf_file):
    if pdf_file is None:
        return "❌ Upload PDF dulu"
    result = gemini_pdf_analysis(pdf_file)
    return result


def load_history():
    df = read_csv()
    if df.empty:
        return df, "Belum ada trade", "0", "0%", "0"

    total = len(df)
    wins = len(df[pd.to_numeric(df['pnl'], errors='coerce').fillna(0) > 0])
    losses = len(df[pd.to_numeric(df['pnl'], errors='coerce').fillna(0) < 0])
    win_rate = round(wins / total * 100, 1) if total else 0
    total_pnl = pd.to_numeric(df['pnl'], errors='coerce').fillna(0).sum()

    stats = f"📊 Total: {total} | 🟢 Wins: {wins} | 🔴 Losses: {losses} | Win Rate: {win_rate}%"
    pnl_str = f"Rp {total_pnl:,.0f}"

    return df, stats, pnl_str, f"{win_rate}%", str(total)


def refresh_history():
    df, stats, pnl, wr, total = load_history()
    return df, stats, pnl, wr, total


# ───────────────────────────────────────────────
# GRADIO UI
# ───────────────────────────────────────────────

def build_ui():
    with gr.Blocks(title="IDX Trading Journal") as demo:
        gr.Markdown("""
        # 📈 IDX Trading Journal — AI Powered
        **Jurnal trading saham IDX dengan AI Google Gemini (gratis)**
        Upload screenshot chart, input manual, atau PDF report broker.
        """)

        with gr.Tabs():
            # ── TAB 1: LAUNCH / SETUP ──
            with gr.TabItem("🚀 Launch"):
                gr.Markdown("""
                ## 🔑 Setup API Key
                Masukkan API key dari [Google AI Studio](https://aistudio.google.com/app/apikey) untuk aktifkan fitur AI.
                Key gratis, gak perlu kartu kredit.
                """)

                with gr.Row():
                    with gr.Column(scale=3):
                        api_key_input = gr.Textbox(
                            label="🔑 Gemini API Key",
                            placeholder="Paste API key dari Google AI Studio...",
                            type="password",
                            value=load_config().get("gemini_api_key", ""),
                        )
                    with gr.Column(scale=1):
                        api_key_status = gr.Textbox(
                            label="Status",
                            value=get_api_key_status()[0],
                            interactive=False,
                        )

                with gr.Row():
                    with gr.Column(scale=1):
                        api_key_btn = gr.Button("🚀 Launch App", variant="primary")
                    with gr.Column(scale=3):
                        launch_result = gr.Textbox(
                            label="Result",
                            interactive=False,
                            value="Klik Launch untuk aktifkan AI...",
                        )

                api_key_btn.click(
                    set_api_key,
                    inputs=[api_key_input],
                    outputs=[api_key_status, api_key_input],
                ).then(
                    lambda status: f"✅ App launched! {status}" if "🟢" in status else f"❌ {status}",
                    inputs=[api_key_status],
                    outputs=[launch_result],
                )

                # Auto-load status on startup
                demo.load(
                    get_api_key_status,
                    outputs=[api_key_status, api_key_input],
                )

                gr.Markdown("""
                ---
                ### 📋 Cara Dapat API Key (Gratis):
                1. Buka [Google AI Studio](https://aistudio.google.com/app/apikey)
                2. Klik **"Create API Key"**
                3. Copy key → Paste di atas → Klik **Launch**
                4. Key auto-save ke `config.json`, sekali setup aja
                """)

            # ── TAB 2: IMAGE ──
            with gr.TabItem("📸 Upload Image"):
                gr.Markdown("Upload screenshot chart atau trade dari broker. AI akan ekstrak data otomatis.")

                with gr.Row():
                    with gr.Column(scale=1):
                        image_input = gr.Image(label="Screenshot Chart/Trade", type="pil")
                        date_img = gr.Textbox(label="Tanggal", placeholder="DD/MM/YYYY", value=datetime.now().strftime("%d/%m/%Y"))
                        emotion_img = gr.Dropdown(label="Emosi", choices=EMOTIONS, value="netral")
                        notes_img = gr.Textbox(label="Catatan Manual", lines=2)
                        btn_img = gr.Button("🚀 Analyze & Save", variant="primary")

                    with gr.Column(scale=1):
                        status_img = gr.Textbox(label="Status", interactive=False)
                        extracted_img = gr.Markdown(label="Data Terekstrak")
                        json_preview = gr.JSON(label="Row Preview")
                        ai_analysis_img = gr.Textbox(label="🤖 AI Analysis", lines=3, interactive=False)
                        ai_lessons_img = gr.Textbox(label="💡 Lesson", lines=2, interactive=False)

                btn_img.click(
                    handle_image_upload,
                    inputs=[image_input, date_img, emotion_img, notes_img],
                    outputs=[status_img, extracted_img, json_preview, ai_analysis_img, ai_lessons_img]
                )

            # ── TAB 3: MANUAL ──
            with gr.TabItem("📝 Manual Entry"):
                gr.Markdown("Input data trade secara manual. AI akan memberikan reasoning dan evaluasi.")

                with gr.Row():
                    with gr.Column(scale=1):
                        symbol = gr.Textbox(label="Symbol", placeholder="BBRI, TLKM, etc.")
                        direction = gr.Dropdown(label="Direction", choices=["BUY", "SELL"], value="BUY")
                        entry = gr.Number(label="Entry Price", value=0)
                        exit_p = gr.Number(label="Exit Price (0 = open)", value=0)
                        sl = gr.Number(label="Stop Loss", value=0)
                        tp = gr.Number(label="Take Profit", value=0)

                    with gr.Column(scale=1):
                        volume = gr.Number(label="Volume (lot)", value=1)
                        pnl = gr.Number(label="P&L (Rp)", value=0)
                        setup = gr.Dropdown(label="Setup Type", choices=SETUP_TYPES, value="breakout")
                        emotion = gr.Dropdown(label="Emosi", choices=EMOTIONS, value="netral")
                        date_man = gr.Textbox(label="Tanggal", value=datetime.now().strftime("%d/%m/%Y"))
                        notes_man = gr.Textbox(label="Catatan", lines=2)
                        btn_man = gr.Button("💾 Save & Analyze", variant="primary")

                with gr.Row():
                    status_man = gr.Textbox(label="Status", interactive=False)
                    summary_man = gr.Markdown()
                    ai_analysis_man = gr.Textbox(label="🤖 AI Analysis", lines=3, interactive=False)
                    ai_lessons_man = gr.Textbox(label="💡 Lesson", lines=2, interactive=False)

                btn_man.click(
                    handle_manual_entry,
                    inputs=[symbol, direction, entry, exit_p, sl, tp, volume, pnl, setup, emotion, date_man, notes_man],
                    outputs=[status_man, summary_man, ai_analysis_man, ai_lessons_man]
                )

            # ── TAB 4: PDF ──
            with gr.TabItem("📄 PDF Report"):
                gr.Markdown("Upload PDF trade report dari broker. AI akan ekstrak semua trade.")
                pdf_input = gr.File(label="Upload PDF", file_types=[".pdf"])
                btn_pdf = gr.Button("📖 Read PDF", variant="primary")
                pdf_output = gr.Markdown()

                btn_pdf.click(handle_pdf_upload, inputs=[pdf_input], outputs=[pdf_output])

            # ── TAB 5: HISTORY ──
            with gr.TabItem("📊 History & Stats"):
                gr.Markdown("Lihat semua trade dan statistik.")

                with gr.Row():
                    stat_total = gr.Textbox(label="Total Trades", value="0", interactive=False)
                    stat_winrate = gr.Textbox(label="Win Rate", value="0%", interactive=False)
                    stat_pnl = gr.Textbox(label="Total P&L", value="Rp 0", interactive=False)

                with gr.Row():
                    stats_text = gr.Textbox(label="Summary", value="Belum ada trade", interactive=False)

                btn_refresh = gr.Button("🔄 Refresh", variant="secondary")
                history_table = gr.Dataframe(label="Journal History", interactive=False)

                btn_refresh.click(
                    refresh_history,
                    inputs=[],
                    outputs=[history_table, stats_text, stat_pnl, stat_winrate, stat_total]
                )

                # Auto load on tab open
                demo.load(
                    refresh_history,
                    outputs=[history_table, stats_text, stat_pnl, stat_winrate, stat_total]
                )

        gr.Markdown("""
        ---
        🔗 Powered by **Google Gemini API** (gratis) | 🇮🇩 Khusus saham IDX
        """)

    return demo


if __name__ == "__main__":
    init_csv()
    app = build_ui()
    app.launch(
        server_name="0.0.0.0",
        server_port=7860,
        show_error=True,
        inbrowser=True,
        theme=gr.themes.Soft(),
    )
