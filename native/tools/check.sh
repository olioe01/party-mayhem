#!/bin/bash
# Headless próbafuttatás zajszűréssel: csak a játék saját sorai és a valódi hibák látszanak.
# Használat: tools/check.sh [másodperc] [játékkapcsolók...]
#   tools/check.sh                      30 mp-es botos játék (koronavadászat)
#   tools/check.sh 60 --mode=mountain   hegymászás
#   tools/check.sh 40 --mg=beam         egy adott minijáték
# A teljes napló: /tmp/pm_check.log. Kilépési kód: 0 = nincs szkripthiba, 1 = van.
cd "$(dirname "$0")/.."
secs=30
if [[ "$1" =~ ^[0-9]+$ ]]; then secs=$1; shift; fi
log=${PM_CHECK_LOG:-/tmp/pm_check.log}
verbose=""
for a in "$@"; do [ "$a" = "--verbose" ] && verbose="--verbose"; done

timeout $((secs + 90)) godot --headless $verbose --path . -- \
	--bots=4 --autostart --speed=20 --quit-at="$secs" "$@" > "$log" 2>&1
code=$?

# a Godot headless kilépéskori szivárgás-üzenetei ártalmatlanok, csak elfedik a lényeget
awk '
	skip && /^[[:space:]]+at: / { skip = 0; next }
	{ skip = 0 }
	/Cannot get path of node as it is not in a scene tree|Leaked instance dependency|RID allocations of type|Pages in use exist at exit|ObjectDB instances leaked|resources still in use at exit/ { skip = 1; next }
	/^Godot Engine v|^$/ { next }
	{ print }
' "$log" | { [ -n "$verbose" ] && grep -E '^\[|ERROR|WARNING|^[[:space:]]+at: |Party Mayhem' || cat; } | head -n "${PM_CHECK_LINES:-80}"

errs=$(grep -cE 'SCRIPT ERROR|Parse Error|Failed to load script|Invalid (call|access|get|set)|Compile Error' "$log")
if [ "$code" = 124 ]; then echo "== IDŐTÚLLÉPÉS (a játék nem lépett ki $((secs + 90)) mp alatt)"; exit 1; fi
if [ "$errs" != 0 ]; then echo "== $errs szkripthiba (részletek: $log)"; exit 1; fi
echo "== rendben, szkripthiba nincs (${secs} mp, kilépési kód: $code)"
