#!/usr/bin/env python3
"""
Готовит границы стран для бандла MAPA.

Сырой Natural Earth весит ~840 КБ, из которых почти всё — 168 полей атрибутов
на каждую страну (от кодов ISO до оценок ВВП за 2019 год). Нам нужно пять полей.
Скрипт выбрасывает лишнее, округляет координаты, чистит геометрию
и считает площадь — она понадобится для «% мира» на 4-м этапе.

Сырые данные (public domain, Natural Earth):
    curl -L -o ne_110m.geojson \\
      https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_admin_0_countries.geojson

Запуск:
    python3 Tools/build_borders.py ne_110m.geojson
"""

import json
import math
import os
import sys

from flag_colors import FLAG_COLORS

OUTPUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "MAPA", "Resources", "world_110m.geojson"
)

# Точность координат. 3 знака ≈ 110 м по экватору.
# На максимальном зуме приложения это заметно меньше пикселя.
PRECISION = 3

# Порог упрощения Дугласа–Пекера в градусах.
# Держим маленьким: датасет и так лёгкий, а «срезанные» мысы сразу видно.
EPSILON = 0.015

# Кольца короче этого выбрасываем — это точки-артефакты, не острова.
MIN_RING_POINTS = 4

EARTH_RADIUS_KM = 6371.0088

# Открытый океан — не страна.
SKIP_CONTINENTS = {"Seven seas (open ocean)"}


def douglas_peucker(points, epsilon):
    """Классическое упрощение полилинии. Хвостовая рекурсия развёрнута в стек."""
    if len(points) < 3:
        return points

    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    stack = [(0, len(points) - 1)]

    while stack:
        first, last = stack.pop()
        if last <= first + 1:
            continue

        ax, ay = points[first]
        bx, by = points[last]
        dx, dy = bx - ax, by - ay
        norm = math.hypot(dx, dy)

        max_dist = 0.0
        index = first
        for i in range(first + 1, last):
            px, py = points[i]
            if norm == 0:
                dist = math.hypot(px - ax, py - ay)
            else:
                dist = abs(dy * px - dx * py + bx * ay - by * ax) / norm
            if dist > max_dist:
                max_dist = dist
                index = i

        if max_dist > epsilon:
            keep[index] = True
            stack.append((first, index))
            stack.append((index, last))

    return [p for p, k in zip(points, keep) if k]


def clean_ring(ring):
    """Округляет, убирает дубли подряд и замыкает кольцо."""
    rounded = [(round(x, PRECISION), round(y, PRECISION)) for x, y in ring]

    deduped = [rounded[0]]
    for point in rounded[1:]:
        if point != deduped[-1]:
            deduped.append(point)

    simplified = douglas_peucker(deduped, EPSILON)

    if len(simplified) < MIN_RING_POINTS:
        return None
    if simplified[0] != simplified[-1]:
        simplified.append(simplified[0])
    return simplified


def ring_area_km2(ring):
    """
    Площадь сферического многоугольника через избыток по формуле L'Huilier
    в её «интегральной» форме. Знак говорит о направлении обхода —
    им мы отличаем дырки (озёра, анклавы) от внешнего контура.
    """
    if len(ring) < 4:
        return 0.0
    total = 0.0
    for i in range(len(ring) - 1):
        lon1, lat1 = math.radians(ring[i][0]), math.radians(ring[i][1])
        lon2, lat2 = math.radians(ring[i + 1][0]), math.radians(ring[i + 1][1])
        total += (lon2 - lon1) * (2 + math.sin(lat1) + math.sin(lat2))
    return total * EARTH_RADIUS_KM * EARTH_RADIUS_KM / 2.0


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    source = sys.argv[1]
    raw_size = os.path.getsize(source)
    with open(source) as fh:
        data = json.load(fh)

    features = []
    points_before = 0
    points_after = 0
    skipped = []

    for feature in data["features"]:
        props = feature["properties"]
        continent = props.get("CONTINENT") or ""
        if continent in SKIP_CONTINENTS:
            skipped.append(props.get("NAME"))
            continue

        geometry = feature["geometry"]
        polygons = (
            geometry["coordinates"]
            if geometry["type"] == "MultiPolygon"
            else [geometry["coordinates"]]
        )

        clean_polygons = []
        area = 0.0
        for polygon in polygons:
            rings = []
            for index, ring in enumerate(polygon):
                points_before += len(ring)
                cleaned = clean_ring(ring)
                if cleaned is None:
                    continue
                points_after += len(cleaned)
                rings.append([[x, y] for x, y in cleaned])
                # Первое кольцо — внешний контур, остальные — дырки.
                signed = ring_area_km2(cleaned)
                area += abs(signed) if index == 0 else -abs(signed)
            if rings:
                clean_polygons.append(rings)

        if not clean_polygons:
            skipped.append(props.get("NAME"))
            continue

        # ISO_A3 у Норвегии, Франции и ещё трёх территорий равен «-99».
        # ADM0_A3 заполнен всегда — он и становится нашим идентификатором.
        iso = props.get("ISO_A3")
        code = iso if iso and iso != "-99" else props.get("ADM0_A3")

        features.append({
            "type": "Feature",
            "properties": {
                "id": code,
                "name": props.get("NAME"),
                "name_ru": props.get("NAME_RU") or props.get("NAME"),
                "continent": continent,
                "area_km2": round(area),
                # Цвет флага — им страна заливается на карте.
                "color": FLAG_COLORS.get(code),
            },
            "geometry": {
                "type": "MultiPolygon",   # единый тип — парсер проще
                "coordinates": clean_polygons,
            },
        })

    features.sort(key=lambda f: f["properties"]["id"])

    ids = [f["properties"]["id"] for f in features]
    duplicates = {i for i in ids if ids.count(i) > 1}
    if duplicates:
        print("ВНИМАНИЕ: неуникальные идентификаторы:", duplicates)

    output = {"type": "FeatureCollection", "features": features}
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, "w") as fh:
        json.dump(output, fh, separators=(",", ":"), ensure_ascii=False)

    new_size = os.path.getsize(OUTPUT)
    print("стран:      {}  (пропущено: {})".format(len(features), ", ".join(str(s) for s in skipped) or "нет"))
    print("точек:      {} -> {}  ({:.0f}%)".format(points_before, points_after, 100 * points_after / points_before))
    print("размер:     {:.0f} КБ -> {:.0f} КБ".format(raw_size / 1024, new_size / 1024))
    print("суша:       {:,} км²".format(int(sum(f["properties"]["area_km2"] for f in features))))
    missing = [f["properties"]["id"] for f in features if not f["properties"]["color"]]
    print("без цвета:  {}".format(", ".join(missing) if missing else "нет"))
    print("результат:  {}".format(OUTPUT))


if __name__ == "__main__":
    main()
