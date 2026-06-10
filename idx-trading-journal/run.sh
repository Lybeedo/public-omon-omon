#!/bin/bash
# IDX Trading Journal Launcher
# chmod +x run.sh && ./run.sh

echo "🚀 IDX Trading Journal - AI Powered"
echo "===================================="

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 tidak ditemukan. Install dulu."
    exit 1
fi

# Check uv (recommended) or pip
if command -v uv &> /dev/null; then
    echo "📦 Using uv..."
    uv pip install -q google-generativeai pillow pandas 2>/dev/null || true
    uv run trading_journal.py
else
    echo "📦 Using pip..."
    pip install -q google-generativeai pillow pandas 2>/dev/null || true
    python3 trading_journal.py
fi
