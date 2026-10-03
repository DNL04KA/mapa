#!/usr/bin/env python3
"""Собирает достопримечательности стран.

Карточка страны показывала «Описания пока нет» у ста пятидесяти одной
страны из ста семидесяти шести: руками я написал двадцать пять и честно
остановился, потому что дальше начиналась выдумка.

Страна собирается из мест своих городов, а не отдельным запросом. Прямой
запрос «объекты этой страны» выглядит очевиднее, но даёт мусор: в полусотне
самых известных записей Франции лежат Париж, французский язык и Вторая
мировая война, а Эйфелева башня до отбора не доживает. Места городов уже
отобраны и проверены — остаётся взять лучшие и свести в один список.

Запросы к Викиданным при этом не нужны вовсе: всё уже в кэше после сборки
городов.

    python3 Tools/build_country_facts.py
"""

import json, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wikidata as wd

ROOT = Path(__file__).resolve().parent.parent
BORDERS = ROOT / "MAPA" / "Resources" / "world_110m.geojson"
CITIES = ROOT / "MAPA" / "Resources" / "cities.json"
OUT = ROOT / "MAPA" / "Resources" / "country-facts.json"

PER_COUNTRY = 6


def main():
    features = json.loads(BORDERS.read_text(encoding="utf-8"))["features"]
    country_names = {f["properties"]["id"]: f["properties"]["name_ru"] for f in features}
    cities = json.loads(CITIES.read_text(encoding="utf-8"))["cities"]

    # Названия городов и стран в список мест не годятся: в Викиданных
    # у них есть и класс «сооружение», и высокая известность.
    skip = {c["name_ru"] for c in cities} | set(country_names.values())

    include, exclude, strong = wd.classifiers()
    print(f"классов: смотрим {len(include)}, пропускаем {len(exclude)}, "
          f"прощаем {len(strong)}", flush=True)
    if not include:
        print("иерархия не загрузилась — без неё отбор бессмысленен")
        return 1

    found, missed = {}, 0
    for index, city in enumerate(cities, start=1):
        data = wd.near_city(city)
        if data is None:
            missed += 1
            continue
        for row in data.get("results", {}).get("bindings", []):
            item = wd.accept(row, include, exclude, strong, skip_names=skip)
            if item:
                found.setdefault(city["country"], {}).setdefault(item["ru"], item)
        if index % 200 == 0:
            print(f"  {index}/{len(cities)}", flush=True)

    if missed:
        print(f"городов без данных в кэше: {missed} — сначала прогоните build_city_facts.py")

    raw = {}
    for country, items in found.items():
        best = sorted(items.values(), key=lambda i: -i["links"])[:PER_COUNTRY]
        if best:
            raw[country] = best

    result = wd.attach_photos(raw)
    OUT.write_text(json.dumps(result, ensure_ascii=False, separators=(",", ":")),
                   encoding="utf-8")

    total = sum(len(v) for v in result.values())
    with_photo = sum(1 for v in result.values() for r in v if "small" in r)
    print(f"\n{OUT.relative_to(ROOT)}: {len(result)} стран из {len(country_names)}, "
          f"{total} мест, {with_photo} с фотографией, {OUT.stat().st_size // 1024} КБ")


if __name__ == "__main__":
    sys.exit(main())
