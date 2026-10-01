#!/usr/bin/env python3
"""
Готовит города для бандла MAPA.

Сырые данные (public domain, Natural Earth):
    curl -L -o ne_cities.geojson \\
      https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_populated_places_simple.geojson

Запуск:
    python3 Tools/build_cities.py ne_cities.geojson
"""

import json
import os
import re
import sys

from city_names_ru import CITY_NAMES_RU

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT = os.path.join(ROOT, "MAPA", "Resources", "cities.json")
BORDERS = os.path.join(ROOT, "MAPA", "Resources", "world_110m.geojson")


# Порог «крупного города» для подсчёта квоты.
BIG_CITY = 500_000

# Сколько городов показываем у страны.
#
# Шесть на всех было честно, но неверно: у Монако шесть и не наберётся,
# а Россия с шестью точками выглядит пустой — туда можно ехать десять раз
# и каждый раз в новое место.
#
# Считаем по двум независимым причинам поехать ещё раз и берём большую:
#   размер страны — в Канаде и Австралии городов немного, но между ними
#     тысячи километров, и каждый это отдельная поездка;
#   число крупных городов — Германия меньше Алжира вчетверо, а ехать в ней
#     есть куда: Берлин, Гамбург, Мюнхен, Кёльн и так далее.
# По одной только площади Германия получала шесть городов и теряла Мюнхен.
def quota(area_km2: float, big_cities: int) -> int:
    if area_km2 > 5_000_000:
        by_area = 16
    elif area_km2 > 1_500_000:
        by_area = 12
    elif area_km2 > 400_000:
        by_area = 9
    else:
        by_area = 6
    return min(16, max(6, by_area, big_cities))


# Столица страны — ровно один класс.
#
# Соседний «Admin-0 capital alt» выглядит заманчиво: там действительно лежат
# Гаага при Амстердаме и Путраджая при Куала-Лумпуре. Но там же лежат Киото,
# Лагос, Багио и Эль-Аюн — столицы чего угодно, кроме своей страны. Звёздочка
# «столица» на Киото — это не спорная трактовка, а ошибка, поэтому класс
# целиком не берём: одна столица на страну честнее двух, из которых одна врёт.
CAPITAL_CLASSES = {"Admin-0 capital"}

# Страны, где и основной класс даёт несколько записей. Разобрано поимённо,
# берём место, где заседает правительство:
#   Боливия     — Ла-Пас: Сукре конституционная, но власть в Ла-Пасе
#   Кот-д’Ивуар — Ямусукро: официальная столица с 1983 года
#   ЮАР         — Претория: исполнительная столица (в данных есть и
#                 Йоханнесбург, который столицей не является вовсе)
#   Мьянма      — Нейпьидо: действующая столица, Янгон — бывшая
PRIMARY_CAPITAL = {
    "BOL": "La Paz",
    "CIV": "Yamoussoukro",
    "ZAF": "Pretoria",
    "MMR": "Naypyidaw",
}

# Запасные классы — строго по порядку и только там, где столицы не нашлось
# вовсе. Natural Earth считает Гренландию и Пуэрто-Рико частями других
# государств, поэтому Нуук у неё столица региона, а Сан-Хуан — столица
# первого уровня. Если же применять эти классы ко всем подряд, в столицы
# попадают Киото, Эдинбург и Фуншал — они столицы чего угодно, кроме страны.
FALLBACK_CAPITAL_CLASSES = ("Admin-0 region capital", "Admin-1 capital")


# Невидимые символы направления текста. В данных они встречаются у названий
# из арабских и ивритских регионов («Granada» с U+200E на конце) и делают
# ключ непохожим на самого себя — поиск перевода молча не находил город.
INVISIBLE = re.compile(r"[\u200b-\u200f\u202a-\u202e\u2066-\u2069\ufeff]")


def cities_with_content() -> set:
    """Города, у которых в приложении есть достопримечательности.

    Читаем прямо из `CityFacts.swift`: держать второй список здесь — значит
    однажды их разойтись. Связь некрасивая, зато ошибку видно сразу.
    """
    source = os.path.join(ROOT, "MAPA", "Core", "Travel", "CityFacts.swift")
    with open(source, encoding="utf-8") as fh:
        return set(re.findall(r'^\s*"([^"]+)": \[', fh.read(), re.M))


WITH_CONTENT = cities_with_content()


def normalize(name: str) -> str:
    """Двойные пробелы («Washington,  D.C.») и невидимые управляющие символы."""
    return re.sub(r"\s+", " ", INVISIBLE.sub("", name)).strip()


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    with open(sys.argv[1]) as fh:
        raw = json.load(fh)
    with open(BORDERS) as fh:
        borders = json.load(fh)["features"]
    country_ids = {f["properties"]["id"] for f in borders}
    country_area = {f["properties"]["id"]: f["properties"]["area_km2"] for f in borders}

    cities = []
    skipped = []
    untranslated = []

    for feature in raw["features"]:
        props = feature["properties"]
        country = props.get("adm0_a3")

        # Города-государства вроде Сингапура и Монако в границах 1:110m
        # отсутствуют: у них нет полигона, значит и привязать их не к чему.
        if country not in country_ids:
            skipped.append(props.get("name"))
            continue

        # Антарктические станции — не города, и в списке «куда съездить»
        # им делать нечего. Отсекаем и по стране, и по типу точки: станции
        # есть и за пределами Антарктиды.
        if country == "ATA" or props.get("featurecla") == "Scientific station":
            skipped.append(props.get("name"))
            continue

        name = normalize(props.get("name") or "")
        name_ru = CITY_NAMES_RU.get(name)

        # Города без русского названия не берём вовсе.
        #
        # Раньше они попадали в список под латинским именем, и рядом с
        # «Ярославлем» стоял «Novosibirsk». Подробный набор 1:10m — это
        # семь тысяч точек, перевести все разом нельзя, а список из двух
        # алфавитов выглядит как недоделка. Лучше меньше, но на одном языке.
        if name_ru is None:
            untranslated.append(name)
            continue

        cities.append({
            "id": "{}-{}".format(country, re.sub(r"[^A-Za-z0-9]", "", props.get("nameascii") or name)),
            "name": name,
            "name_ru": name_ru,
            "country": country,
            "lon": round(float(props["longitude"]), 4),
            "lat": round(float(props["latitude"]), 4),
            # Столица страны — её показываем на карте первой.
            "capital": bool(props.get("adm0cap")) or props.get("featurecla") in CAPITAL_CLASSES,
            "_fallbackRank": (FALLBACK_CAPITAL_CLASSES.index(props["featurecla"])
                              if props.get("featurecla") in FALLBACK_CAPITAL_CLASSES else None),
            "population": int(props.get("pop_max") or 0),
        })

    # Один и тот же город приходит дважды под разными написаниями
    # («Bandar Lampung» и «Bandarlampung»): идентификатор у них получается
    # один, а запись должна остаться одна — та, где населения больше.
    unique = {}
    for city in cities:
        kept = unique.get(city["id"])
        if kept is None or city["population"] > kept["population"]:
            unique[city["id"]] = city
    cities = list(unique.values())

    by_country = {}
    for city in cities:
        by_country.setdefault(city["country"], []).append(city)

    # Одна столица на страну: несколько звёздочек в списке городов читаются
    # как ошибка, даже когда данные формально правы.
    for country, group in by_country.items():
        marked = [c for c in group if c["capital"]]
        if len(marked) > 1:
            wanted = PRIMARY_CAPITAL.get(country)
            keep = next((c for c in marked if c["name"] == wanted), None) \
                or max(marked, key=lambda c: c["population"])
            for city in marked:
                city["capital"] = city is keep
            if wanted is None:
                print("ВНИМАНИЕ: несколько столиц у {}, оставлена {}"
                      .format(country, keep["name_ru"]))

    cities = []
    for country, group in by_country.items():
        big = sum(1 for c in group if c["population"] >= BIG_CITY)
        limit = quota(country_area.get(country, 0), big)
        group.sort(key=lambda c: -(c["population"] * (4 if c["capital"] else 1)))
        picked = group[:limit]

        # Город, про который приложению есть что рассказать, остаётся всегда.
        # Иначе случается самое обидное: у Мюнхена есть и фотографии, и список
        # достопримечательностей, а из списка городов он вылетает по населению,
        # и всё это добро становится недостижимым.
        for city in group:
            if city["name_ru"] in WITH_CONTENT and city not in picked:
                picked.append(city)

        # Столица обязана попасть в список, даже если по населению не прошла:
        # страна без столицы в списке городов выглядит как ошибка, и это
        # ровно то, чем она и была.
        if not any(c["capital"] for c in picked):
            capital = next((c for c in group if c["capital"]), None)
            if capital is None:
                options = [c for c in group if c["_fallbackRank"] is not None]
                options.sort(key=lambda c: (c["_fallbackRank"], -c["population"]))
                capital = options[0] if options else None
                if capital:
                    capital["capital"] = True
            if capital:
                picked = [c for c in picked if c is not capital][:limit - 1] + [capital]
        cities.extend(picked)

    for city in cities:
        del city["_fallbackRank"]

    cities.sort(key=lambda c: (-c["population"], c["id"]))

    ids = [c["id"] for c in cities]
    duplicates = {i for i in ids if ids.count(i) > 1}
    if duplicates:
        print("ВНИМАНИЕ: неуникальные идентификаторы:", duplicates)

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, "w") as fh:
        json.dump({"cities": cities}, fh, separators=(",", ":"), ensure_ascii=False)

    without_capital = sorted({c["country"] for c in cities}
                             - {c["country"] for c in cities if c["capital"]})
    print("городов:      {} (от 6 до 16 на страну)".format(len(cities)))
    print("без столицы:  {}".format(", ".join(without_capital) if without_capital else "нет"))
    print("столиц:       {}".format(sum(1 for c in cities if c["capital"])))
    print("стран:        {}".format(len({c["country"] for c in cities})))
    print("отброшено без перевода: {} точек".format(len(untranslated)))
    print("пропущено:    {}".format(len(skipped)))
    print("размер:       {:.0f} КБ".format(os.path.getsize(OUTPUT) / 1024))


if __name__ == "__main__":
    main()
