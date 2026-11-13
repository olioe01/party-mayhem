#!/bin/bash
# Party Mayhem natív build: zene -> web.zip -> import -> Windows exe
set -e
cd "$(dirname "$0")/.."
[ -f music/board.wav ] || node tools/make_music.mjs
python3 tools/pack_web.py
# verzióazonosító az online játékhoz: csak egyező buildek csatlakozhatnak egymáshoz
cat $(find scripts -name '*.gd' | sort) | sha1sum | cut -c1-8 > build_id.txt
godot --headless --path . --import > /dev/null 2>&1 || true
mkdir -p build
godot --headless --path . --export-release "Windows Desktop" build/PartyMayhem.exe
ls -la build/PartyMayhem.exe
