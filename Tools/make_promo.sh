#!/bin/bash
# Ролик о приложении: снимаем экраны, рисуем кадры, склеиваем.
#
#     Tools/make_promo.sh [папка]
#
# Экраны открываются переменной MAPA_SCREEN — у симулятора в командной
# строке нет пальцев. Она же прячет отладочную кнопку замеров: в ролике
# должно быть ровно то, что увидит человек.
#
# Перед съёмкой стоит отметить на карте десяток стран и собрать маршрут:
# пустая карта честно показывает ноль процентов, но показывать ею нечего.

set -euo pipefail

DEVICE="${MAPA_DEVICE:-iPhone 14 Pro Max}"
WORK="${1:-build/promo}"
APP_ID="com.mapa.app"
DERIVED="${MAPA_DERIVED:-build/screenshots}"

UDID=$(xcrun simctl list devices available \
       | grep "$DEVICE (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[ -n "$UDID" ] || { echo "нет симулятора «$DEVICE»" >&2; exit 1; }

mkdir -p "$WORK/shots" "$WORK/frames"
rm -f "$WORK/frames"/*.jpg

echo "симулятор: $DEVICE"
xcrun simctl boot "$UDID" 2>/dev/null || true
sleep 5
xcodebuild -project MAPA.xcodeproj -scheme MAPA \
           -destination "id=$UDID" -derivedDataPath "$DERIVED" build >/dev/null
xcrun simctl install "$UDID" "$DERIVED/Build/Products/Debug-iphonesimulator/MAPA.app"

shoot() { # имя экран [ещё-переменные]
    xcrun simctl terminate "$UDID" "$APP_ID" 2>/dev/null || true
    env SIMCTL_CHILD_MAPA_SCREEN="$2" "${@:3}" \
        xcrun simctl launch "$UDID" "$APP_ID" \
        -AppleLanguages "(ru)" -AppleLocale ru_RU -onboarding.done "$ONBOARDING" >/dev/null
    sleep 11          # фотографии тянутся из сети
    xcrun simctl io "$UDID" screenshot "$WORK/shots/$1.png" >/dev/null 2>&1
    echo "  $1"
}

ONBOARDING=NO
shoot 1-hello   ""
ONBOARDING=YES
shoot 2-map     ""
shoot 3-search  search       SIMCTL_CHILD_MAPA_SEARCH=кёльн
shoot 4-country card-JPN
shoot 5-city    city-ITA-Rome
shoot 6-photo   city-ITA-Rome SIMCTL_CHILD_MAPA_PHOTO=1
shoot 7-routes  routes
shoot 8-theme   theme
shoot 9-share   export

xcrun simctl terminate "$UDID" "$APP_ID" 2>/dev/null || true

echo "рисуем кадры"
swift Tools/make_promo.swift "$WORK/shots" "$WORK/frames"

echo "склеиваем"
ffmpeg -y -loglevel error -framerate 30 -i "$WORK/frames/frame-%05d.jpg" \
       -c:v libx264 -pix_fmt yuv420p -preset slow -crf 20 \
       -movflags +faststart "$WORK/MAPA.mp4"

echo "готово: $WORK/MAPA.mp4"
