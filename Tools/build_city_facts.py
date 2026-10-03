#!/usr/bin/env python3
"""Собирает достопримечательности городов из Викиданных.

Для восьмидесяти городов я написал списки руками, и это сработало. Для
восьмисот так нельзя: где-то вспомню верно, где-то правдоподобно, и
отличить одно от другого будет нечем. Поэтому источник — Викиданные,
а признак «стоит посмотреть» — число языковых разделов, в которых
о месте написали. Грубо, зато честно и проверяемо.

Фотография берётся прямо из записи места, а не ищется по названию статьи:
прошлый способ подсовывал Мон-Сен-Мишель вместо базилики в Бордо.

    python3 Tools/build_city_facts.py [--limit N]
"""

import json, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wikidata as wd

ROOT = Path(__file__).resolve().parent.parent
CITIES = ROOT / "MAPA" / "Resources" / "cities.json"
OUT = ROOT / "MAPA" / "Resources" / "city-facts.json"

PER_CITY = 4


def main():
    limit = None
    if "--limit" in sys.argv:
        limit = int(sys.argv[sys.argv.index("--limit") + 1])

    cities = json.loads(CITIES.read_text(encoding="utf-8"))["cities"]
    # Сначала столицы и крупные: если прогон прервётся, важное уже собрано.
    cities.sort(key=lambda c: -(c["population"] * (4 if c["capital"] else 1)))
    if limit:
        cities = cities[:limit]

    include, exclude, strong = wd.classifiers()
    print(f"классов: смотрим {len(include)}, пропускаем {len(exclude)}, "
          f"прощаем {len(strong)}", flush=True)

    raw, done = {}, 0
    for city in cities:
        data = wd.near_city(city)
        done += 1
        if data is None:
            continue

        items, seen = [], set()
        for row in data.get("results", {}).get("bindings", []):
            item = wd.accept(row, include, exclude, strong, skip_names={city["name_ru"]})
            if not item or item["ru"] in seen:
                continue
            seen.add(item["ru"])
            items.append(item)
            if len(items) >= PER_CITY:
                break

        if items:
            raw[city["id"]] = items
        if done % 100 == 0:
            print(f"  {done}/{len(cities)}: с местами {len(raw)}", flush=True)

    result = wd.attach_photos(raw)
    OUT.write_text(json.dumps(result, ensure_ascii=False, separators=(",", ":")),
                   encoding="utf-8")

    total = sum(len(rows) for rows in result.values())
    with_photo = sum(1 for rows in result.values() for r in rows if "small" in r)
    print(f"\n{OUT.relative_to(ROOT)}: {len(result)} городов, {total} мест, "
          f"{with_photo} с фотографией, {OUT.stat().st_size // 1024} КБ")


if __name__ == "__main__":
    sys.exit(main())
