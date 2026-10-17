#!/bin/bash
# Снимки для App Store — пять экранов на двух языках.
#
# В магазин нужны картинки ровно 1290×2796 (6.7″), поэтому снимаем на
# iPhone 14 Pro Max, а не на том симуляторе, который под рукой.
#
# Экраны открываются переменной MAPA_SCREEN: у симулятора в командной
# строке нет пальцев, нажать «Маршруты» нечем. Она же прячет отладочную
# кнопку замеров — снимок должен показывать то, что увидит человек.
#
#     Tools/make_screenshots.sh [папка]
#
# Перед съёмкой стоит отметить на карте десяток стран и собрать маршрут:
# пустая карта честно показывает ноль процентов, но продавать ею нечего.

set -euo pipefail

DEVICE="${MAPA_DEVICE:-iPhone 14 Pro Max}"
OUT="${1:-screenshots}"
APP_ID="com.mapa.app"
DERIVED="${MAPA_DERIVED:-build/screenshots}"

UDID=$(xcrun simctl list devices available \
       | grep "$DEVICE (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')

if [ -z "$UDID" ]; then
    echo "нет симулятора «$DEVICE»" >&2
    exit 1
fi

echo "симулятор: $DEVICE ($UDID)"
xcrun simctl boot "$UDID" 2>/dev/null || true
sleep 5

xcodebuild -project MAPA.xcodeproj -scheme MAPA \
           -destination "id=$UDID" -derivedDataPath "$DERIVED" build >/dev/null
xcrun simctl install "$UDID" "$DERIVED/Build/Products/Debug-iphonesimulator/MAPA.app"

shoot() { # язык экран имя
    xcrun simctl terminate "$UDID" "$APP_ID" 2>/dev/null || true
    MAPA_SCREEN="$2" SIMCTL_CHILD_MAPA_SCREEN="$2" \
        xcrun simctl launch "$UDID" "$APP_ID" \
        -AppleLanguages "($1)" -AppleLocale "$1" -onboarding.done YES >/dev/null
    # Фотографии тянутся из сети: без паузы в кадр попадут пустые рамки.
    sleep 11
    xcrun simctl io "$UDID" screenshot "$OUT/$1/$3.png" >/dev/null 2>&1
    echo "  $1/$3.png"
}

for LANG in ru en; do
    mkdir -p "$OUT/$LANG"
    shoot "$LANG" map       1-map
    shoot "$LANG" card-JPN  2-country
    shoot "$LANG" routes    3-routes
    shoot "$LANG" theme     4-theme
    shoot "$LANG" export    5-share
done

echo "готово: $OUT"
