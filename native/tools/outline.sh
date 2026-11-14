#!/bin/bash
# Egy vagy több .gd fájl vázlata sorszámokkal (osztály, konstansok, függvények),
# hogy a nagy fájlokból csak a szükséges sortartományt kelljen beolvasni.
# Használat: tools/outline.sh scripts/world/chars3d.gd [további fájlok...]
#            tools/outline.sh -v fájl      a tagváltozókat is mutatja
cd "$(dirname "$0")/.."
pat='^(class_name|extends|static func|func|class |enum|signal|const)'
if [ "$1" = "-v" ]; then pat='^(class_name|extends|static func|func|class |enum|signal|const|var|static var|@export|@onready)'; shift; fi
for f in "$@"; do
	[ $# -gt 1 ] && echo "## $f ($(wc -l < "$f") sor)"
	grep -nE "$pat" "$f" | cut -c1-140
done
