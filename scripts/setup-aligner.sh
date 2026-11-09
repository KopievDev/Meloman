#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
    echo "Meloman lyrics aligner requires an Apple Silicon Mac." >&2
    exit 1
fi

PYTHON=""
for candidate in python3.12 python3.11 python3.13 python3; do
    if command -v "$candidate" >/dev/null 2>&1 &&
        "$candidate" -c 'import sys; assert (3,11) <= sys.version_info[:2] < (3,14)' >/dev/null 2>&1; then
        PYTHON="$(command -v "$candidate")"
        break
    fi
done

if [[ -z "$PYTHON" ]]; then
    echo "Install Python 3.12 (brew install python@3.12) and rerun." >&2
    exit 1
fi

DEST="$HOME/Library/Application Support/Meloman/Engines/LyricsAligner"
mkdir -p "$DEST"
if [[ ! -x "$DEST/bin/python" ]]; then
    "$PYTHON" -m venv "$DEST"
fi

echo "Installing offline lyrics CTC alignment dependencies into a private venv..."
"$DEST/bin/python" -m pip install --disable-pip-version-check --upgrade pip
"$DEST/bin/python" -m pip install --disable-pip-version-check \
    "torch==2.6.0" "transformers==4.49.0" "numpy==1.26.4" \
    "soundfile==0.13.1" "sentencepiece==0.2.0"

"$DEST/bin/python" -c 'import numpy, torch, transformers, soundfile; from transformers import Wav2Vec2BertForCTC, Wav2Vec2BertProcessor; print("Lyrics CTC aligner ready")'
echo "The large multilingual music model will download once when you synchronize known lyrics."
echo "Offline runtime: $DEST/bin/python"
