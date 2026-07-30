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

# Verify the served loose files (addon.xml plus declared assets) still match
# the source manifests. The generator adds and overwrites but never deletes,
# so a renamed or removed asset would otherwise be served forever, and it
# skips a declared asset that has no source file without a word, so one can
# also be missing from the channel unnoticed. Old version zips are kept on
# purpose and are not checked. Report only; nothing is deleted here.
python3 - <<'EOF'
import os
import sys
from xml.etree import ElementTree

zips = os.path.join("repo", "zips")
orphans = []
missing = []
unsourced = []

for addon_id in sorted(os.listdir(zips)):
    addon_dir = os.path.join(zips, addon_id)
    if not os.path.isdir(addon_dir):
        continue
    src = os.path.join("repo", addon_id)
    if not os.path.isdir(src):
        unsourced.append(addon_dir)
        continue

    expected = {"addon.xml"}
    root = ElementTree.parse(os.path.join(src, "addon.xml")).getroot()
    for ext in root.findall("extension"):
        if ext.get("point") not in ("xbmc.addon.metadata", "kodi.addon.metadata"):
            continue
        assets = ext.find("assets")
        if assets is None:
            continue
        for art in assets:
            text = (art.text or "").strip()
            if text:
                expected.add(os.path.normpath(text))

    for parent, dirs, files in os.walk(addon_dir):
        for fn in files:
            if fn.endswith(".zip"):
                continue
            rel = os.path.normpath(os.path.relpath(os.path.join(parent, fn), addon_dir))
            if rel not in expected:
                orphans.append(os.path.join(addon_dir, rel))

    for rel in sorted(expected):
        if not os.path.isfile(os.path.join(addon_dir, rel)):
            missing.append(os.path.join(addon_dir, rel))

fail = False
if orphans:
    fail = True
    print("ERROR: served files with no source in any addon manifest:")
    for p in orphans:
        print("  " + p)
if missing:
    fail = True
    print("ERROR: declared assets missing from the served files:")
    for p in missing:
        print("  " + p)
if unsourced:
    fail = True
    print("ERROR: served addon directories with no source addon folder:")
    for p in unsourced:
        print("  " + p)
if fail:
    sys.exit(1)
EOF
