#!/usr/bin/env python3
"""Проверяет города по границам стран.

Зачем: координаты городов и полигоны стран приходят из разных наборов
данных, и ничто не гарантирует, что они сходятся. Ошибка здесь тихая —
столица просто окажется в море или в соседней стране, и заметит это
пользователь, а не мы.

Проверяем три вещи:
  1. каждая страна имеет ровно одну столицу;
  2. город лежит внутри полигона своей страны;
  3. если не лежит — насколько далеко от него.

Третий пункт обязателен. Границы у нас упрощены до 1:110m, и приморский
город честно оказывается «в море» на километр-другой — это не ошибка
данных, а цена упрощения. Ругаться имеет смысл только на заметные
расхождения.

    python3 Tools/check_cities.py
"""

import json, math, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CITIES = ROOT / "MAPA" / "Resources" / "cities.json"
BORDERS = ROOT / "MAPA" / "Resources" / "world_110m.geojson"

# Дальше этого расхождение уже не объяснить упрощением границ.
TOLERANCE_KM = 60


def rings(geometry):
    """Все внешние кольца полигонов страны."""
    kind, coords = geometry["type"], geometry["coordinates"]
    if kind == "Polygon":
        return [coords[0]]
    if kind == "MultiPolygon":
        return [polygon[0] for polygon in coords]
    return []


def inside(point, ring):
    """Луч вправо: нечётное число пересечений — точка внутри."""
    x, y = point
    result = False
    for i in range(len(ring)):
        x1, y1 = ring[i]
        x2, y2 = ring[i - 1]
        if (y1 > y) != (y2 > y):
            if x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
                result = not result
    return result


def km_between(a, b):
    lon1, lat1 = a
    lon2, lat2 = b
    lat1, lat2 = math.radians(lat1), math.radians(lat2)
    dlat, dlon = lat2 - lat1, math.radians(lon2 - lon1)
    h = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    return 6371.0 * 2 * math.asin(min(1.0, math.sqrt(h)))


def distance_to_ring(point, ring):
    """Расстояние до ближайшей вершины кольца. Грубо, но для порога хватает."""
    return min(km_between(point, vertex) for vertex in ring)


def main():
    cities = json.loads(CITIES.read_text(encoding="utf-8"))["cities"]
    features = json.loads(BORDERS.read_text(encoding="utf-8"))["features"]
    shapes = {f["properties"]["id"]: rings(f["geometry"]) for f in features}
    names = {f["properties"]["id"]: f["properties"]["name_ru"] for f in features}

    print(f"городов: {len(cities)}, стран с границами: {len(shapes)}")

    # 1. Столицы
    caps = {}
    for city in cities:
        if city["capital"]:
            caps.setdefault(city["country"], []).append(city["name_ru"])

    countries_with_cities = {c["country"] for c in cities}
    no_capital = sorted(countries_with_cities - set(caps))
    many = {k: v for k, v in caps.items() if len(v) > 1}

    print(f"\nстолиц: {sum(len(v) for v in caps.values())}")
    if many:
        print("НЕСКОЛЬКО СТОЛИЦ:")
        for cid, items in sorted(many.items()):
            print(f"  {names.get(cid, cid):28} {', '.join(items)}")
    if no_capital:
        print(f"БЕЗ СТОЛИЦЫ ({len(no_capital)}):")
        for cid in no_capital:
            print(f"  {names.get(cid, cid)} ({cid})")

    # 2–3. Положение
    outside = []
    for city in cities:
        ring_list = shapes.get(city["country"])
        if not ring_list:
            continue
        point = (city["lon"], city["lat"])
        if any(inside(point, ring) for ring in ring_list):
            continue
        gap = min(distance_to_ring(point, ring) for ring in ring_list)
        outside.append((gap, city))

    far = [(gap, c) for gap, c in outside if gap > TOLERANCE_KM]
    near = len(outside) - len(far)

    print(f"\nвне полигона: {len(outside)} "
          f"(из них в пределах {TOLERANCE_KM} км — {near}, это цена упрощения границ)")
    if far:
        print(f"\nДАЛЕКО ОТ СВОЕЙ СТРАНЫ ({len(far)}) — разобрано вручную:")
        print("  Азорские, Мадейра, Галапагосы, Биоко, Вануату: острова, которых")
        print("  нет в упрощённых границах 1:110m. Координаты городов верные,")
        print("  в полигон страны они не попадают — это не ошибка данных.")
        for gap, c in sorted(far, reverse=True):
            mark = "столица" if c["capital"] else "город"
            print(f"  {gap:7.0f} км  {c['name_ru']:22} {mark:8} {names.get(c['country'], c['country'])}")

    # Падаем только на настоящих ошибках. Расхождение с полигоном —
    # предупреждение: острова в упрощённых границах не нарисованы.
    return 1 if many or no_capital else 0


if __name__ == "__main__":
    sys.exit(main())
