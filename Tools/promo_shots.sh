#!/bin/bash
# Снимки для ролика.
#
# Берём именно снимки, а не запись с экрана: `simctl io recordVideo`
# отдаёт рваный поток в полтора десятка кадров на сцену, и половина из
# них — загрузка приложения. Движение в ролике рисуется отдельно и в
# 60 кадрах, а снимок нужен резкий и в полном разрешении.
#
#     Tools/promo_shots.sh [папка]

set -uo pipefail
DEVICE="${MAPA_DEVICE:-iPhone 14 Pro Max}"
OUT="${1:-build/promo/shots}"
APP=com.mapa.app

UDID=$(xcrun simctl list devices available \
       | grep "$DEVICE (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[ -n "$UDID" ] || { echo "нет симулятора «$DEVICE»" >&2; exit 1; }

mkdir -p "$OUT"
xcrun simctl boot "$UDID" 2>/dev/null
sleep 5

MARKED=FRA,ITA,ESP,DEU,TUR,PRT,GRC,CZE,AUT,POL,NLD,HRV,MNE,GEO,ARE
WISH=JPN,PER,MEX,NOR,ISL

shot() { # имя экран [доп. переменные]
  local name="$1" screen="$2"; shift 2
  xcrun simctl terminate "$UDID" "$APP" 2>/dev/null
  env "$@" \
      SIMCTL_CHILD_MAPA_MARKED="$MARKED" SIMCTL_CHILD_MAPA_WISH="$WISH" \
      SIMCTL_CHILD_MAPA_SCREEN="$screen" \
      xcrun simctl launch "$UDID" "$APP" \
      -AppleLanguages "(ru)" -AppleLocale ru_RU -onboarding.done YES >/dev/null
  sleep "${WAIT:-11}"
  xcrun simctl io "$UDID" screenshot "$OUT/$name.png" >/dev/null 2>&1
  echo "  $name"
}

echo "снимки:"
shot map       map
shot marks     marks
shot country   card-JPN
shot routes    routes
shot community community SIMCTL_CHILD_MAPA_DEMO_COMMUNITY=1
shot share     export
shot account   account

# Полотна для монтажа: одна и та же карта в разных материалах.
for s in ink neon paper flags; do
  shot "surface-$s" map SIMCTL_CHILD_MAPA_SURFACE="$s"
done

xcrun simctl terminate "$UDID" "$APP" 2>/dev/null
echo "готово: $OUT"
