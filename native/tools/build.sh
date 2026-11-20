#!/bin/bash
# Party Mayhem natív build: zene -> web.zip -> import -> Windows exe
set -e
cd "$(dirname "$0")/.."
[ -f music/board.wav ] || node tools/make_music.mjs
[ -f music/spooky.wav ] || node tools/make_music.mjs spooky
python3 tools/pack_web.py
# verzióazonosító az online játékhoz: csak egyező buildek csatlakozhatnak egymáshoz
cat $(find scripts -name '*.gd' | sort) | sha1sum | cut -c1-8 > build_id.txt
godot --headless --path . --import > /dev/null 2>&1 || true
mkdir -p build
godot --headless --path . --export-release "Windows Desktop" build/PartyMayhem.exe
# Cloudflare-alagút (lobbi gomb): a cloudflared.exe az exe mellé kerül, hogy ne kelljen futás közben letölteni
if [ ! -f build/cloudflared.exe ]; then
  curl -fsSL -o build/cloudflared.exe.part https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe \
    && mv build/cloudflared.exe.part build/cloudflared.exe \
    || { rm -f build/cloudflared.exe.part; echo "FIGYELEM: a cloudflared.exe letöltése nem sikerült (a játék futáskor letölti)"; }
fi
ls -la build/PartyMayhem.exe build/cloudflared.exe 2>/dev/null || true
