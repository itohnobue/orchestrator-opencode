#!/usr/bin/env bash
# vision.sh — Invoke GLM-4.6V for image analysis via Z.ai API
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if ! command -v uv &> /dev/null; then
    echo "Installing uv..." >&2
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

env -u PYTHONPATH PYTHONIOENCODING=utf-8 uv run "$SCRIPT_DIR/vision.py" "$@"
