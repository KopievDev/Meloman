#!/bin/bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
  echo "MLX Vocal Separation requires a Mac with Apple Silicon (M1 or newer)." >&2
  exit 1
fi

QUALITY=false
if [[ "${1:-}" == "--quality" ]]; then
  QUALITY=true
elif [[ $# -gt 0 ]]; then
  echo "Usage: ./scripts/setup-mlx.sh [--quality]" >&2
  exit 2
fi

PYTHON=""
for candidate in python3.12 python3.13 python3.11 python3.10 python3; do
  if command -v "$candidate" >/dev/null 2>&1; then
    if "$candidate" -c 'import sys; assert (3,10) <= sys.version_info[:2] < (3,14)' >/dev/null 2>&1; then
      PYTHON="$(command -v "$candidate")"
      break
    fi
  fi
done

if [[ -z "$PYTHON" ]]; then
  echo "Install Python 3.12 (for example: brew install python@3.12), then retry." >&2
  exit 1
fi

DEST="$HOME/Library/Application Support/Meloman/Engines/MLX"
mkdir -p "$DEST"
if [[ ! -x "$DEST/bin/python" ]]; then
  "$PYTHON" -m venv "$DEST"
fi

echo "Installing isolated MLX runtime (first run needs an internet connection)..."
"$DEST/bin/python" -m pip install --disable-pip-version-check --upgrade pip
if [[ "$QUALITY" == true ]]; then
  echo "Installing extra checkpoint-conversion dependencies for BS-RoFormer..."
  "$DEST/bin/python" -m pip install --disable-pip-version-check "mlx-audio-separator[convert]==0.1.20"
else
  "$DEST/bin/python" -m pip install --disable-pip-version-check "mlx-audio-separator==0.1.20"
fi
"$DEST/bin/python" -c 'import mlx.core; from mlx_audio_separator import Separator; print("MLX runtime ready")'

if [[ ! -x "$DEST/bin/mlx-audio-separator" ]]; then
  echo "Installation incomplete: CLI not found" >&2
  exit 1
fi

echo "MLX engine installed: $DEST/bin/mlx-audio-separator"
if [[ "$QUALITY" == true ]]; then
  echo "Optional BS-RoFormer dependencies ready. Select BS-RoFormer in Meloman."
else
  echo "Mel-Band RoFormer ready. For BS-RoFormer, rerun: ./scripts/setup-mlx.sh --quality"
fi
