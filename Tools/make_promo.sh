#!/bin/bash
# Рекламный ролик о приложении, целиком из исходников.
#
#     Tools/make_promo.sh [папка]
#
# Три шага, каждый отдельным инструментом:
#   1. promo_shots.sh   — снимает экраны приложения на симуляторе;
#   2. promo_frames.swift — рисует все кадры ролика в 60 fps;
#   3. ffmpeg           — складывает кадры в файл.
#
# Снимки, а не запись с экрана: `simctl io recordVideo` отдаёт рваный
# поток в полтора десятка кадров на сцену и половину тратит на загрузку
# приложения. Движение поэтому рисуется, а не снимается.

set -euo pipefail
WORK="${1:-build/promo}"

echo "1/3 снимки экранов"
Tools/promo_shots.sh "$WORK/shots"

echo "2/3 кадры"
rm -rf "$WORK/frames"; mkdir -p "$WORK/frames"
swift Tools/promo_frames.swift "$WORK/shots" "$WORK/frames"

echo "3/3 сборка"
ffmpeg -v error -y -framerate 60 -i "$WORK/frames/f%05d.jpg" \
  -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -movflags +faststart \
  "$WORK/mapa-promo.mp4"

ls -lh "$WORK/mapa-promo.mp4"
