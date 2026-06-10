#!/bin/bash
# IDX Trading Journal Web UI Launcher
# chmod +x run.sh && ./run.sh

echo "🚀 IDX Trading Journal — Web UI (Gradio)"
echo "========================================="
echo ""

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 tidak ditemukan. Install dulu."
    exit 1
fi

# Check uv (recommended) or pip
if command -v uv &> /dev/null; then
    echo "📦 Using uv..."
    uv pip install -q -r requirements.txt 2>/dev/null || true
    uv run app.py
else
    echo "📦 Using pip..."
    pip install -q -r requirements.txt 2>/dev/null || true
    python3 app.py
fi
