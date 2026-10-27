#!/bin/bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMFY="$ROOT/ComfyUI"
MACMAX="$ROOT/minimax-h3-mac"
PYTHON_VERSION="${PYTHON_VERSION:-3.14}"

brew install git "python@$PYTHON_VERSION"
[[ -d "$COMFY" ]] || git clone --depth 1 --branch v0.34.0 \
  https://github.com/Comfy-Org/ComfyUI.git "$COMFY"
[[ -d "$MACMAX" ]] || git clone --depth 1 \
  https://github.com/Bambushu/minimax-h3-mac.git "$MACMAX"

# 复用已有环境；重跑不会更新仓库或覆盖工作流。
[[ -d "$COMFY/venv" ]] || \
  "$(brew --prefix "python@$PYTHON_VERSION")/bin/python$PYTHON_VERSION" \
    -m venv "$COMFY/venv"
PY="$COMFY/venv/bin/python"
export PIP_CONSTRAINT="$ROOT/requirements-mac.txt"
"$PY" -m pip install --upgrade pip
"$PY" -m pip install torch torchvision torchaudio
"$PY" -m pip install -r "$COMFY/requirements.txt" huggingface_hub
COMFY_ROOT="$COMFY" zsh "$MACMAX/install_node_packs.sh" all

HF="$COMFY/venv/bin/hf"
"$HF" download Abiray/MiniMax-H3-Pruned-GGUF \
  MiniMax-H3-FL2VA-Pruned-Q4_K_M.gguf \
  --local-dir "$COMFY/models/diffusion_models"
"$HF" download Comfy-Org/Krea-2 \
  text_encoders/qwen3vl_4b_fp8_scaled.safetensors \
  --local-dir "$COMFY/models"
"$HF" download NicoLab28/ClipProj-MiniMax-H3 \
  mmh3-4b-ClipProj-v3.1.safetensors \
  --local-dir "$COMFY/models/clip_projections"
"$HF" download Comfy-Org/MiniMax-H3 \
  vae/minimax_h3_video_vae_fp16.safetensors \
  vae/minimax_h3_audio_vae_fp32.safetensors \
  --local-dir "$COMFY/models"
"$HF" download Plaguekind/H3-Lora \
  H3-PK-Parasyte-Turbo.safetensors \
  --local-dir "$COMFY/models/loras"

echo '环境与模型已就绪。执行 ./run.sh，导入 workflow-m1pro-32gb.json。'
