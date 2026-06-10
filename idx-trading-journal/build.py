"""
Build script for IDX Trading Journal — PyInstaller
Run: python build.py
Output: dist/IDX_Trading_Journal/
"""
import sys
import os
import subprocess

# Ensure PyInstaller is installed
try:
    import PyInstaller.__main__
except ImportError:
    print("Installing PyInstaller...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pyinstaller>=6.0"])
    import PyInstaller.__main__

# Build args
args = [
    "app.py",
    "--name=IDX_Trading_Journal",
    "--onedir",              # Folder mode: faster startup, editable config
    "--console",             # Show console for debugging/logs
    "--add-data", "config.json;.",
    "--add-data", ".env;.",
    "--add-data", "README.md;.",
    "--hidden-import", "uvicorn",
    "--hidden-import", "uvicorn.logging",
    "--hidden-import", "uvicorn.loops.auto",
    "--hidden-import", "uvicorn.protocols.http.auto",
    "--hidden-import", "uvicorn.protocols.websockets.auto",
    "--hidden-import", "uvicorn.lifespan.on",
    "--hidden-import", "fastapi",
    "--hidden-import", "starlette",
    "--hidden-import", "gradio",
    "--hidden-import", "gradio.themes",
    "--hidden-import", "gradio.components",
    "--hidden-import", "google.genai",
    "--hidden-import", "google.genai.client",
    "--hidden-import", "google.genai.types",
    "--hidden-import", "google.genai.models",
    "--hidden-import", "PIL._imagingtk",
    "--hidden-import", "pandas._libs.tslibs.base",
    "--hidden-import", "numpy.core._dtype_ctypes",
    "--hidden-import", "pydantic",
    "--hidden-import", "pydantic.v1",
    "--hidden-import", "anyio._backends._asyncio",
    "--collect-all", "gradio",
    "--collect-all", "gradio_client",
    "--collect-all", "fastapi",
    "--collect-all", "uvicorn",
    "--collect-all", "starlette",
    "--collect-all", "pydantic",
    "--collect-all", "anyio",
    "--collect-all", "httpx",
    "--collect-all", "httptools",
    "--collect-all", "websockets",
    "--clean",
    "--noconfirm",
    "--distpath=./dist",
    "--workpath=./build",
]

print("=" * 60)
print("Building IDX Trading Journal...")
print("=" * 60)
print()

PyInstaller.__main__.run(args)

print()
print("=" * 60)
print("Build complete!")
print(f"Output: dist/IDX_Trading_Journal/")
print("Run: dist/IDX_Trading_Journal/IDX_Trading_Journal.exe")
print("=" * 60)
