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

import json, math, re, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wikidata as wd

ROOT = Path(__file__).resolve().parent.parent
CITIES = ROOT / "MAPA" / "Resources" / "cities.json"
BORDERS = ROOT / "MAPA" / "Resources" / "world_110m.geojson"
OUT = ROOT / "MAPA" / "Resources" / "city-facts.json"

PER_CITY = 4

# Родовые слова: если два места начинаются с них, это ещё не значит, что
# они одно и то же. «Мечеть Имама» и «Мечеть Шейха Лютфаллы» стоят на одной
# площади в трёхстах метрах друг от друга и остаются разными мечетями.
GENERIC = {"мечет", "собор", "храм", "музей", "церко", "парк", "замок",
           "дворе", "базил", "монас", "башня", "мост", "площа", "театр"}

# Ближе этого две записи с одинаковым началом названия — один объект,
# описанный дважды.
SAME_PLACE_KM = 0.4


def first_root(name):
    """Начало первого слова: «Пирамида» и «Пирамиды» — одно и то же."""
    words = re.findall(r"[^\W\d_]+", name.lower())
    return words[0][:5] if words and len(words[0]) >= 5 else None


def distance_km(a, b):
    radius = 6371.0088
    lat1, lat2 = math.radians(a[1]), math.radians(b[1])
    dlat = math.radians(b[1] - a[1])
    dlon = math.radians(b[0] - a[0])
    h = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    return 2 * radius * math.asin(math.sqrt(h))


def is_neighbour_city(item, cities_by_name):
    """Это не достопримечательность, а соседний город.

    В списке Гизы первым местом стоял Каир, в списке Пирея — Афины.
    Проверяем не по названию, а по названию вместе с точкой: «Давид» во
    Флоренции — статуя Микеланджело, а не город в Панаме, и «Минск» в
    Шэньчжэне — авианосец-музей, а не столица Беларуси.
    """
    twin = cities_by_name.get(item["ru"])
    if not twin or item.get("lat") is None:
        return False
    return distance_km((item["lon"], item["lat"]), (twin["lon"], twin["lat"])) < 5


def deduplicate(items, city_root):
    """Убирает повторы одного объекта.

    В Каире Викиданные знают и «Пирамиды Гизы», и «Пирамиду Хеопса» — для
    прогулки это две строки про одно место. Признак повтора: рядом и
    одинаковое начало названия. Город из сравнения исключён: «Севильский
    собор» и «Севильский Алькасар» — разные места, у них просто общий
    город в имени.
    """
    kept = []
    for item in items:
        root = first_root(item["ru"])
        duplicate = False
        if root and root not in GENERIC and root != city_root:
            for other in kept:
                if first_root(other["ru"]) != root:
                    continue
                if item.get("lat") is None or other.get("lat") is None:
                    continue
                if distance_km((item["lon"], item["lat"]),
                               (other["lon"], other["lat"])) < SAME_PLACE_KM:
                    duplicate = True
                    break
        if not duplicate:
            kept.append(item)
    return kept


def country_extents():
    """Половина охвата страны в градусах — чтобы не заглядывать за границу.

    Нужно только карликам: у Люксембурга охват вдвое больше любого радиуса
    и ничего не меняет, а у Монако и Ватикана он и есть весь радиус.
    """
    data = json.loads(BORDERS.read_text(encoding="utf-8"))
    out = {}
    for feature in data["features"]:
        xs, ys = [], []
        stack = [feature["geometry"]["coordinates"]]
        while stack:
            node = stack.pop()
            if node and isinstance(node[0], (int, float)):
                xs.append(node[0]); ys.append(node[1])
            else:
                stack.extend(node)
        if xs:
            out[feature["properties"]["id"]] = max(
                (max(xs) - min(xs)) / 2, (max(ys) - min(ys)) / 2)
    return out


def country_names():
    data = json.loads(BORDERS.read_text(encoding="utf-8"))
    return {f["properties"]["name_ru"] for f in data["features"]
            if f["properties"].get("name_ru")}


def main():
    limit = None
    if "--limit" in sys.argv:
        limit = int(sys.argv[sys.argv.index("--limit") + 1])

    cities = json.loads(CITIES.read_text(encoding="utf-8"))["cities"]
    # Сначала столицы и крупные: если прогон прервётся, важное уже собрано.
    cities.sort(key=lambda c: -(c["population"] * (4 if c["capital"] else 1)))
    if limit:
        cities = cities[:limit]

    extents = country_extents()
    cities_by_name = {c["name_ru"]: c for c in cities}
    # Названия стран — не достопримечательности: в списке Рима первым
    # местом стоял «Ватикан», который у нас и сам страна на карте.
    countries = country_names()
    include, exclude, strong = wd.classifiers()
    print(f"классов: смотрим {len(include)}, пропускаем {len(exclude)}, "
          f"прощаем {len(strong)}", flush=True)

    raw, done = {}, 0
    for city in cities:
        data = wd.near_city(city, cap=extents.get(city["country"]))
        done += 1
        if data is None:
            continue

        items, seen = [], set()
        for row in data.get("results", {}).get("bindings", []):
            item = wd.accept(row, include, exclude, strong,
                             skip_names=countries | {city["name_ru"]})
            if not item or item["ru"] in seen:
                continue
            if is_neighbour_city(item, cities_by_name):
                continue
            seen.add(item["ru"])
            items.append(item)
            # Берём с запасом: часть отсеется как повтор одного объекта.
            if len(items) >= PER_CITY * 2:
                break

        items = deduplicate(items, first_root(city["name_ru"]))[:PER_CITY]
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
