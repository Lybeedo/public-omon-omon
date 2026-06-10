#!/usr/bin/env python3
"""
IDX Trading Journal - AI Powered by Google Gemini
Upload screenshot/PDF atau input manual. AI ekstrak & evaluasi trade.
"""

import os
import sys
import json
import csv
import re
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict, List

# Gemini
import google.generativeai as genai
from PIL import Image

# --- Konfigurasi ---
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


def load_config() -> dict:
    if not os.path.exists(CONFIG_PATH):
        return {"gemini_api_key": os.getenv("GEMINI_API_KEY", ""), "model": "gemini-2.5-flash"}
    with open(CONFIG_PATH, "r") as f:
        return json.load(f)


def init_gemini(cfg: dict):
    api_key = cfg.get("gemini_api_key") or os.getenv("GEMINI_API_KEY")
    if not api_key or api_key == "YOUR_GEMINI_API_KEY_HERE":
        print("\n❌ API Key Gemini belum diset!")
        print("   Cara: export GEMINI_API_KEY='your_key' atau edit config.json")
        sys.exit(1)
    genai.configure(api_key=api_key)
    model_name = cfg.get("model", "gemini-2.5-flash")
    return genai.GenerativeModel(model_name)


def get_csv_path(cfg: dict) -> str:
    return cfg.get("journal_file", str(JOURNAL_DIR / "idx_trading_journal.csv"))


def init_csv(path: str):
    if not os.path.exists(path):
        with open(path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(FIELDS)
        print(f"✅ CSV journal dibuat: {path}\n")


def read_csv(path: str) -> List[Dict]:
    if not os.path.exists(path):
        return []
    with open(path, "r", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def append_csv(path: str, row: Dict):
    with open(path, "a", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        writer.writerow(row)


def ask(prompt: str, default: str = "") -> str:
    val = input(f"{prompt}: ").strip()
    return val if val else default


def ask_float(prompt: str, default: float = 0.0) -> float:
    try:
        return float(input(f"{prompt}: ").strip())
    except (ValueError, EOFError):
        return default


def ask_int(prompt: str, default: int = 0) -> int:
    try:
        return int(input(f"{prompt}: ").strip())
    except (ValueError, EOFError):
        return default


def parse_symbol(raw: str, cfg: dict) -> str:
    raw = raw.upper().strip()
    # Auto append .JK if not present
    if not raw.endswith(".JK") and len(raw) <= 4:
        raw = raw + ".JK"
    return raw


def save_screenshot(source_path: str) -> str:
    """Copy uploaded file to journal/screenshots/"""
    ext = Path(source_path).suffix
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    dest = SCREENSHOTS_DIR / f"trade_{ts}{ext}"
    import shutil
    shutil.copy2(source_path, dest)
    return str(dest)


def gemini_analyze_image(model, image_path: str) -> str:
    """Kirim image ke Gemini, minta ekstrak data trade"""
    img = Image.open(image_path)
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
1. ANALISIS: evaluasi singkat trade ini (2-3 kalimat)
2. LESSON: pelajaran yang bisa dipetik
3. DISCIPLINE_SCORE: 1-10 (apakah trade sesuai plan?)

Jika data tidak terlihat, tulis "NOT_VISIBLE".
"""
    try:
        response = model.generate_content([prompt, img])
        return response.text
    except Exception as e:
        return f"ERROR: {e}"


def gemini_analyze_pdf(model, pdf_path: str) -> str:
    """Upload PDF ke Gemini untuk diekstrak (Gemini bisa baca PDF langsung)"""
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
    try:
        # Upload file to Gemini
        file_obj = genai.upload_file(pdf_path)
        response = model.generate_content([prompt, file_obj])
        return response.text
    except Exception as e:
        return f"ERROR: {e}"


def gemini_reasoning(model, trade_data: dict) -> dict:
    """AI reasoning untuk trade yang sudah diinput manual"""
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
        response = model.generate_content(prompt)
        text = response.text
        return parse_ai_response(text)
    except Exception as e:
        return {
            "ai_analysis": f"Error: {e}",
            "ai_lessons": "-",
            "discipline_score": "5",
            "r_ratio": "-"
        }


def parse_ai_response(text: str) -> dict:
    """Parse output Gemini yang berisi ANALISIS, LESSON, DISCIPLINE_SCORE, R_RATIO"""
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
    """Parse output Gemini dari image analysis"""
    data = {
        "symbol": "", "direction": "", "entry": "", "exit": "",
        "sl": "", "tp": "", "volume": "", "pnl": "",
        "setup_type": "", "ai_analysis": "", "ai_lessons": "",
        "discipline_score": "", "r_ratio": ""
    }
    for line in text.split("\n"):
        if ":" in line:
            key, val = line.split(":", 1)
            key = key.strip().lower()
            val = val.strip()
            if key in data:
                data[key] = val
    return data


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
        rr = round(reward / risk, 2)
        return str(rr)
    except:
        return "-"


def banner():
    print("\n" + "="*60)
    print("   📈 IDX TRADING JOURNAL — AI Powered by Google Gemini")
    print("="*60)


def menu():
    print("\n📚 MENU:")
    print("   [1] ⌨️  Input Manual Trade")
    print("   [2] 📸  Upload Image (Screenshot Chart/Trade)")
    print("   [3] 📄  Upload PDF (Broker Report)")
    print("   [4] 📊  View Statistics & History")
    print("   [5] 📂  Export/Show CSV Path")
    print("   [0] 🚪  Exit")
    print("-"*60)


def input_manual(model, cfg: dict) -> dict:
    print("\n📝 INPUT MANUAL TRADE\n")
    
    symbol = ask("Symbol saham (e.g. BBRI)", "BBRI")
    symbol = parse_symbol(symbol, cfg)
    
    direction = ask("Direction [BUY/SELL]", "BUY").upper()
    entry = ask_float("Entry price")
    exit_p = ask_float("Exit price (0 jika masih open)")
    sl = ask_float("Stop Loss")
    tp = ask_float("Take Profit")
    volume = ask_int("Volume (lot)", 1)
    pnl = ask_float("P&L (Rp)", 0)
    
    setup_types = cfg.get("setup_types", ["breakout", "pullback", "reversal", "trend following"])
    print(f"\nSetup types: {', '.join(setup_types)}")
    setup = ask("Setup type", "breakout")
    
    emotion = ask("Emosi saat trade [tenang/greedy/takut/netral]", "netral")
    notes = ask("Catatan manual", "")
    
    # AI Reasoning
    print("\n🤖 Gemini sedang analisa trade...")
    trade_data = {
        "symbol": symbol, "direction": direction, "entry": entry,
        "exit": exit_p, "sl": sl, "tp": tp, "pnl": pnl,
        "setup_type": setup, "emotion": emotion, "manual_notes": notes
    }
    ai_result = gemini_reasoning(model, trade_data)
    
    ts = datetime.now()
    row = {
        "timestamp": ts.strftime("%Y-%m-%d %H:%M:%S"),
        "date": ask("Tanggal trade [DD/MM/YYYY]", ts.strftime("%d/%m/%Y")),
        "symbol": symbol,
        "direction": direction,
        "entry": str(entry),
        "exit": str(exit_p) if exit_p else "",
        "sl": str(sl),
        "tp": str(tp),
        "volume": str(volume),
        "pnl": str(pnl),
        "pnl_percent": str(calc_pnl_percent(entry, exit_p if exit_p else entry, direction)),
        "setup_type": setup,
        "emotion": emotion,
        "discipline_score": ai_result.get("discipline_score", "5"),
        "r_ratio": ai_result.get("r_ratio", calc_r_ratio(entry, sl, tp, direction)),
        "ai_analysis": ai_result.get("ai_analysis", ""),
        "ai_lessons": ai_result.get("ai_lessons", ""),
        "screenshot_path": "",
        "manual_notes": notes
    }
    
    print("\n📋 AI ANALYSIS:")
    print(f"   Discipline Score: {row['discipline_score']}/10")
    print(f"   R-Ratio: {row['r_ratio']}")
    print(f"   Analysis: {row['ai_analysis'][:120]}...")
    print(f"   Lesson: {row['ai_lessons'][:120]}...")
    
    return row


def input_image(model, cfg: dict) -> dict:
    print("\n📸 UPLOAD IMAGE TRADE\n")
    path = ask("Path file image (JPG/PNG)", "")
    if not path or not os.path.exists(path):
        print("❌ File tidak ditemukan!")
        return {}
    
    print("🤖 Gemini sedang membaca image...")
    result = gemini_analyze_image(model, path)
    
    if result.startswith("ERROR"):
        print(f"\n❌ {result}")
        return {}
    
    data = parse_image_response(result)
    
    print("\n📝 DATA TEREKSTRAK:")
    for k, v in data.items():
        if v and v != "NOT_VISIBLE":
            print(f"   {k}: {v}")
    
    # Save screenshot
    saved_path = save_screenshot(path)
    
    # Ask user confirm / edit
    print("\n✅ Konfirmasi data (Enter untuk pakai, atau ketik untuk edit):")
    symbol = parse_symbol(ask(f"Symbol", data.get("symbol", "")), cfg)
    direction = ask(f"Direction", data.get("direction", "BUY")).upper()
    entry = float(ask(f"Entry", data.get("entry", "0")) or 0)
    exit_p = float(ask(f"Exit", data.get("exit", "0")) or 0)
    sl = float(ask(f"SL", data.get("sl", "0")) or 0)
    tp = float(ask(f"TP", data.get("tp", "0")) or 0)
    volume = int(ask(f"Volume", data.get("volume", "1")) or 1)
    pnl = float(ask(f"P&L", data.get("pnl", "0")) or 0)
    setup = ask(f"Setup", data.get("setup_type", "breakout"))
    emotion = ask("Emosi", "netral")
    notes = ask("Catatan", "")
    
    ts = datetime.now()
    row = {
        "timestamp": ts.strftime("%Y-%m-%d %H:%M:%S"),
        "date": ask("Tanggal", ts.strftime("%d/%m/%Y")),
        "symbol": symbol,
        "direction": direction,
        "entry": str(entry),
        "exit": str(exit_p) if exit_p else "",
        "sl": str(sl),
        "tp": str(tp),
        "volume": str(volume),
        "pnl": str(pnl),
        "pnl_percent": str(calc_pnl_percent(entry, exit_p if exit_p else entry, direction)),
        "setup_type": setup,
        "emotion": emotion,
        "discipline_score": data.get("discipline_score", "5"),
        "r_ratio": data.get("r_ratio", calc_r_ratio(entry, sl, tp, direction)),
        "ai_analysis": data.get("ai_analysis", ""),
        "ai_lessons": data.get("ai_lessons", ""),
        "screenshot_path": saved_path,
        "manual_notes": notes
    }
    return row


def input_pdf(model, cfg: dict):
    print("\n📄 UPLOAD PDF (AI akan ekstrak semua trade)\n")
    path = ask("Path file PDF", "")
    if not path or not os.path.exists(path):
        print("❌ File tidak ditemukan!")
        return []
    
    print("🤖 Gemini sedang membaca PDF...")
    result = gemini_analyze_pdf(model, path)
    
    if result.startswith("ERROR"):
        print(f"\n❌ {result}")
        return []
    
    print("\n📋 OUTPUT GEMINI:")
    print("-"*60)
    print(result)
    print("-"*60)
    print("\nℹ️  Copy data di atas untuk input manual (belum auto-parse multi-trade)")
    return []


def show_stats(cfg: dict):
    path = get_csv_path(cfg)
    rows = read_csv(path)
    if not rows:
        print("\n📊 Belum ada data trade.")
        return
    
    total = len(rows)
    wins = sum(1 for r in rows if float(r.get("pnl", 0) or 0) > 0)
    losses = sum(1 for r in rows if float(r.get("pnl", 0) or 0) < 0)
    breakeven = total - wins - losses
    win_rate = round(wins / total * 100, 1) if total else 0
    
    total_pnl = sum(float(r.get("pnl", 0) or 0) for r in rows)
    
    print("\n" + "="*60)
    print("   📊 STATISTIK TRADING")
    print("="*60)
    print(f"   Total Trades: {total}")
    print(f"   🔴 Wins: {wins}  |  🔵 Losses: {losses}  |  ⚪ BE: {breakeven}")
    print(f"   Win Rate: {win_rate}%")
    print(f"   Total P&L: Rp {total_pnl:,.0f}")
    
    # Setup stats
    setups: Dict[str, int] = {}
    for r in rows:
        s = r.get("setup_type", "unknown")
        setups[s] = setups.get(s, 0) + 1
    
    print("\n   📝 Setup Distribution:")
    for s, c in sorted(setups.items(), key=lambda x: -x[1]):
        print(f"      {s}: {c}")
    
    # Recent trades
    print("\n   📅 5 Trade Terakhir:")
    for r in rows[-5:]:
        sym = r.get("symbol", "?")
        pnl = float(r.get("pnl", 0) or 0)
        emoji = "🔴" if pnl > 0 else ("🔵" if pnl < 0 else "⚪")
        print(f"      {emoji} {sym} | {r.get('date','')} | Rp {pnl:,.0f} | {r.get('setup_type','')}")
    print("="*60)


def export_csv(cfg: dict):
    path = get_csv_path(cfg)
    print(f"\n📂 CSV Journal path:\n   {os.path.abspath(path)}")
    print(f"\n📈 Buka di Excel/Google Sheets untuk analisis lebih lanjut.")


def main():
    banner()
    cfg = load_config()
    model = init_gemini(cfg)
    csv_path = get_csv_path(cfg)
    init_csv(csv_path)
    
    print("\n✅ Gemini connected!")
    print(f"   Model: {cfg.get('model', 'gemini-2.5-flash')}")
    print(f"   Journal: {csv_path}")
    
    while True:
        menu()
        choice = ask("Pilih", "1")
        
        if choice == "1":
            row = input_manual(model, cfg)
            if row:
                append_csv(csv_path, row)
                print("\n✅ Trade tersimpan!")
        
        elif choice == "2":
            row = input_image(model, cfg)
            if row:
                append_csv(csv_path, row)
                print("\n✅ Trade dari image tersimpan!")
        
        elif choice == "3":
            input_pdf(model, cfg)
        
        elif choice == "4":
            show_stats(cfg)
        
        elif choice == "5":
            export_csv(cfg)
        
        elif choice == "0":
            print("\n👋 Sampai jumpa! Trade well, trade smart.")
            break
        else:
            print("\n❌ Pilihan tidak valid.")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n👋 Exit.")
    except Exception as e:
        print(f"\n❌ Error: {e}")
        raise
