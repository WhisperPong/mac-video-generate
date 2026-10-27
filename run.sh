#!/bin/bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMFY="$ROOT/ComfyUI"
cd "$COMFY"
echo '打开 http://127.0.0.1:8288；按 Ctrl+C 停止。'
export ASFP8_INT8_EXT=1
exec "$COMFY/venv/bin/python" main.py \
  --listen 127.0.0.1 --port 8288 \
  --reserve-vram 1 --cache-none --disable-smart-memory "$@"
