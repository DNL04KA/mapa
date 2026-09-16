#!/usr/bin/env python3
"""
Готовит города для бандла MAPA.

Сырые данные (public domain, Natural Earth):
    curl -L -o ne_cities.geojson \\
      https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_populated_places_simple.geojson

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


def normalize(name: str) -> str:
    """В данных встречаются двойные пробелы («Washington,  D.C.»)."""
    return re.sub(r"\s+", " ", name).strip()


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    with open(sys.argv[1]) as fh:
        raw = json.load(fh)
    with open(BORDERS) as fh:
        country_ids = {f["properties"]["id"] for f in json.load(fh)["features"]}

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
        # им делать нечего.
        if country == "ATA":
            skipped.append(props.get("name"))
            continue

        name = normalize(props.get("name") or "")
        name_ru = CITY_NAMES_RU.get(name)
        translated = name_ru is not None

        cities.append({
            "id": "{}-{}".format(country, re.sub(r"[^A-Za-z0-9]", "", props.get("nameascii") or name)),
            "name": name,
            "name_ru": name_ru or name,
            "country": country,
            "lon": round(float(props["longitude"]), 4),
            "lat": round(float(props["latitude"]), 4),
            # Столица страны — её показываем на карте первой.
            "capital": bool(props.get("adm0cap")),
            "_translated": translated,
            "population": int(props.get("pop_max") or 0),
        })

    # Оставляем по шесть самых значимых городов на страну: столько и показываем.
    # Полторы тысячи записей в бандле ради невидимого хвоста не нужны.
    by_country = {}
    for city in cities:
        by_country.setdefault(city["country"], []).append(city)

    cities = []
    for group in by_country.values():
        group.sort(key=lambda c: -(c["population"] * (4 if c["capital"] else 1)))
        cities.extend(group[:6])

    # Считаем непереведённые только среди тех, что реально попали в бандл.
    untranslated = [c["name"] for c in cities if not c["_translated"]]
    for city in cities:
        del city["_translated"]

    cities.sort(key=lambda c: (-c["population"], c["id"]))

    ids = [c["id"] for c in cities]
    duplicates = {i for i in ids if ids.count(i) > 1}
    if duplicates:
        print("ВНИМАНИЕ: неуникальные идентификаторы:", duplicates)

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, "w") as fh:
        json.dump({"cities": cities}, fh, separators=(",", ":"), ensure_ascii=False)

    print("городов:      {} (до шести на страну)".format(len(cities)))
    print("столиц:       {}".format(sum(1 for c in cities if c["capital"])))
    print("стран:        {}".format(len({c["country"] for c in cities})))
    print("без перевода: {}".format(", ".join(untranslated) if untranslated else "нет"))
    print("пропущено:    {}".format(len(skipped)))
    print("размер:       {:.0f} КБ".format(os.path.getsize(OUTPUT) / 1024))


if __name__ == "__main__":
    main()
