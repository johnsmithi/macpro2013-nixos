#!/usr/bin/env bash
# Копирует обои из assets/ репозитория в ~/Pictures/Wallpapers —
# оттуда их при каждом входе подхватывает swaybg (см. niri/config.kdl).
# Copies wallpapers from the repo's assets/ into ~/Pictures/Wallpapers,
# where swaybg picks a random one at every niri login (see niri/config.kdl).
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")/../assets" && pwd)"
dst="${HOME}/Pictures/Wallpapers"

mkdir -p "$dst"
cp -v "$src"/*.jpg "$dst"/
echo "Done: $(ls -1 "$dst" | wc -l | tr -d ' ') file(s) in $dst"
