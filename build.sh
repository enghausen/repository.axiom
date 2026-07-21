#!/usr/bin/env bash
# Copies the addon sources from ../axiom (single source of truth) into the
# layout _repo_generator.py expects, then regenerates repo/zips/.
set -euo pipefail

cd "$(dirname "$0")"
SRC="../axiom"

for addon in plugin.video.axiom context.axiom; do
    if [ ! -d "$SRC/$addon" ]; then
        echo "error: $SRC/$addon not found" >&2
        exit 1
    fi
    rm -rf "repo/$addon"
    cp -r "$SRC/$addon" "repo/$addon"
    find "repo/$addon" -type d -name '__pycache__' -prune -exec rm -rf {} +
done

python3 _repo_generator.py
