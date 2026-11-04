#!/bin/bash
# Снимки для App Store — восемь экранов на двух языках.
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
# Карта и маршруты набираются сами: MAPA_MARKED/MAPA_WISH раскладывают
# отметки, MAPA_ROUTES собирает маршрут тем же планировщиком, который
# предложит его человеку. Поэтому снимать можно на чистом симуляторе и
# получать один и тот же кадр, а не то, что осталось от прошлого раза.
#
# Экрана сообщества здесь нет намеренно: пока не поднят сервер, показать
# можно только демонстрационные профили, а выдуманные люди в магазине —
# обман. Появится сервер — появится и кадр.

set -euo pipefail

DEVICE="${MAPA_DEVICE:-iPhone 14 Pro Max}"
OUT="${1:-screenshots}"
APP_ID="com.mapa.app"
DERIVED="${MAPA_DERIVED:-build/screenshots}"

# Карта человека, который ездит, но мир не объездил: 15 стран на трёх
# континентах. Полностью закрашенная карта продаёт хуже — по ней не
# видно, что приложение вообще считает.
MARKED="FRA,ITA,ESP,PRT,DEU,CZE,HRV,GRC,TUR,ISL,NOR,THA,JPN,MEX,USA"
WISH="PER,NZL,ZAF,ARG"
ROUTES="JPN,ITA"

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
# Начисто перед каждым языком: отметки и маршруты лежат в контейнере
# приложения, и русский прогон оставил бы английскому маршруты с
# названиями «Япония» — название страны попадает в маршрут в тот момент,
# когда его берут, и потом не переводится, это уже данные человека.
fresh() {
    xcrun simctl uninstall "$UDID" "$APP_ID" 2>/dev/null || true
    xcrun simctl install "$UDID" "$DERIVED/Build/Products/Debug-iphonesimulator/MAPA.app"
}

shoot() { # язык экран имя [пауза]
    xcrun simctl terminate "$UDID" "$APP_ID" 2>/dev/null || true
    SIMCTL_CHILD_MAPA_SCREEN="$2" \
    SIMCTL_CHILD_MAPA_MARKED="$MARKED" \
    SIMCTL_CHILD_MAPA_WISH="$WISH" \
    SIMCTL_CHILD_MAPA_ROUTES="$ROUTES" \
        xcrun simctl launch "$UDID" "$APP_ID" \
        -AppleLanguages "($1)" -AppleLocale "$1" -onboarding.done YES >/dev/null
    # Фотографии тянутся из сети: без паузы в кадр попадут пустые рамки.
    sleep "${4:-11}"
    xcrun simctl io "$UDID" screenshot "$OUT/$1/$3.png" >/dev/null 2>&1
    echo "  $1/$3.png"
}

for LANG in ru en; do
    mkdir -p "$OUT/$LANG"
    fresh
    shoot "$LANG" map            1-map       6
    shoot "$LANG" marks          2-marks     6
    shoot "$LANG" card-JPN       3-country
    shoot "$LANG" city-JPN-Kyoto 4-city
    shoot "$LANG" routes         5-routes
    shoot "$LANG" route          6-route
    shoot "$LANG" theme          7-theme     6
    shoot "$LANG" export         8-share
done

echo "готово: $OUT"
