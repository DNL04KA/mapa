#!/usr/bin/env python3
"""Собирает достопримечательности городов из Викиданных.

Почему не из головы. Для восьмидесяти городов я написал списки руками, и
это сработало. Для восьмисот так нельзя: где-то я вспомню верно, где-то
правдоподобно, и отличить одно от другого будет нечем. Поэтому источник —
Викиданные, а признак «стоит посмотреть» — число языковых разделов, в
которых о месте написали. Это грубая мера, зато честная и проверяемая.

Что получается на выходе: русское и английское название, ссылка на
фотографию с Викисклада, имя автора и лицензия.

Фотография берётся прямо из записи места (свойство P18), а не ищется по
названию. Прошлый способ — поиск статьи по имени — подсовывал Мон-Сен-Мишель
вместо базилики в Бордо и коллаж Осло вместо Христиании. Здесь такого быть
не может: картинка привязана к самому объекту.

    python3 Tools/build_city_facts.py [--limit N]
"""

import hashlib, json, os, re, subprocess, sys, time
from urllib.parse import unquote
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CITIES = ROOT / "MAPA" / "Resources" / "cities.json"
OUT = ROOT / "MAPA" / "Resources" / "city-facts.json"
CACHE = Path(os.environ.get("MAPA_WIKI_CACHE", ROOT / ".wiki-cache"))

UA = "MAPA/0.1 (travel map app; contact via github.com/dnl04ka/mapa) curl"
SPARQL = "https://query.wikidata.org/sparql"
API_COMMONS = "https://commons.wikimedia.org/w/api.php"

THUMB = 640
PER_CITY = 4
PAUSE = 1.0

# Что считаем «местом, куда идут смотреть»: сооружения, музеи,
# археологические памятники, монументы, парки, площади.
INCLUDE_ROOTS = "wd:Q811979 wd:Q33506 wd:Q839954 wd:Q4989906 wd:Q22698 wd:Q2065736"

# Что не считаем. Отсекаем по типу, а не по названию: московский аэропорт
# называется «Шереметьево», а стадион в Буэнос-Айресе — «Бомбонера», и никакой
# список слов их не поймает.
# «Организация» и «компания» сюда не входят намеренно: Лувр — тоже
# организация, и с ними из выдачи пропадали все музеи разом.
# «Спортивное сооружение» сюда не входит намеренно: Колизей — амфитеатр,
# и вместе с современными стадионами из выдачи пропадал он. Стадионы и
# арены отсекаются своими классами, этого достаточно.
EXCLUDE_ROOTS = ("wd:Q1248784 wd:Q483110 wd:Q641226 wd:Q55488 "
                 "wd:Q928830 wd:Q3918 wd:Q16917 wd:Q40357 wd:Q39715 wd:Q11303")

# Классы, которые перевешивают исключение.
#
# Колизей в Викиданных помечен сразу и археологическим памятником, и
# стадионом — и правило «есть исключающий класс, значит мимо» выбрасывало
# главную достопримечательность Рима. Если объект заведомо памятник, музей,
# храм или дворец, никакой второй ярлык этого не отменяет. «Бомбонера» же
# только стадион, и её по-прежнему не видно.
STRONG_ROOTS = ("wd:Q839954 wd:Q33506 wd:Q4989906 wd:Q22698 wd:Q1370598 "
                "wd:Q23413 wd:Q16560 wd:Q174782 wd:Q751876")


def hierarchy(roots):
    """Все подклассы заданных классов — одним запросом, один раз.

    Так получается в двенадцать раз быстрее. Если спрашивать `P31/P279*`
    внутри геозапроса, Викиданные обходят дерево классов заново для каждого
    города: Берлин считался пятьдесят шесть секунд против четырёх. Дерево
    же одно на весь мир — его и берём один раз, а разбор делаем у себя.
    """
    data = fetch(SPARQL, {"query": f"""
SELECT ?c WHERE {{
  ?c wdt:P279* ?root .
  VALUES ?root {{ {roots} }}
}}"""}, {"Accept": "application/sparql-results+json"})
    if not data:
        return set()
    return {row["c"]["value"] for row in data.get("results", {}).get("bindings", [])}

# Сооружения, которые формально подходят под класс, но в список «что
# посмотреть» не годятся: в аэропорт не ездят смотреть, а стадион интересен
# только по билету на матч. Ищем в любом месте названия, а не в начале:
# «Международный аэропорт имени Шаха Джалала» начинается не с того слова.
JUNK_NAME = re.compile(
    r"аэропорт|вокзал|станция метро|метрополитен|университет|больница|тюрьма|"
    r"кладбище|стадион|автодром|ипподром|электростанц|водохранилищ|"
    r"парламент|посольств|тюрем", re.I)

# Русская метка иногда записана латиницей («Tokyo Sky Tree»). В русском
# списке такое выглядит как недоделка, а подходящей замены у нас нет —
# пропускаем и берём следующее по известности.
CYRILLIC = re.compile(r"[А-Яа-яЁё]")

JUNK_FILE = re.compile(
    r"(?:^|[\W_])(?:map|karte|flag|coat[\W_]of[\W_]arms|logo|seal|emblem|diagram|"
    r"plan|location|locator|montage|collage)(?:$|[\W_])", re.I)


# Сборка без сети: только то, что уже скачано.
#
# Полный обход восьмисот городов идёт часами, а файл нужен раньше. В этом
# режиме скрипт собирает каталог из кэша и честно пропускает недобранное —
# так приложение всегда можно собрать с тем, что есть на руках.
CACHE_ONLY = os.environ.get("MAPA_CACHE_ONLY") == "1"


def fetch(url, params, headers, attempts=5):
    cmd = ["curl", "-s", "-m", "120", "--get", url, "-H", "User-Agent: " + UA]
    for key, value in headers.items():
        cmd += ["-H", f"{key}: {value}"]
    for key, value in params.items():
        cmd += ["--data-urlencode", f"{key}={value}"]

    CACHE.mkdir(exist_ok=True)
    key = CACHE / (hashlib.sha1("\0".join(cmd).encode()).hexdigest() + ".json")
    if key.exists():
        return json.loads(key.read_text(encoding="utf-8"))
    if CACHE_ONLY:
        return None

    for attempt in range(attempts):
        result = subprocess.run(cmd, capture_output=True)
        if result.returncode == 0 and result.stdout:
            try:
                data = json.loads(result.stdout)
            except json.JSONDecodeError:
                data = None
            if data is not None:
                key.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
                time.sleep(PAUSE)
                return data
        if attempt == attempts - 1:
            return None
        time.sleep(8 * (attempt + 1))
    return None


def radius(city):
    """Полградуса вокруг мегаполиса и восьмушка вокруг городка.

    Радиус от размера города, а не общий: в Москве интересное разбросано на
    тридцать километров, а у городка на сто тысяч в тот же радиус попадут
    соседние города вместе со своими достопримечательностями.
    """
    population = city["population"]
    if population > 5_000_000:
        return 0.22
    if population > 1_000_000:
        return 0.15
    if population > 300_000:
        return 0.11
    return 0.08


def landmarks(city, include, exclude, strong):
    r = radius(city)
    query = f"""
SELECT ?item ?ru ?en ?img ?links (GROUP_CONCAT(DISTINCT ?class; separator=" ") AS ?classes) WHERE {{
  SERVICE wikibase:box {{
    ?item wdt:P625 ?loc .
    bd:serviceParam wikibase:cornerWest "Point({city['lon'] - r:.4f} {city['lat'] - r:.4f})"^^geo:wktLiteral .
    bd:serviceParam wikibase:cornerEast "Point({city['lon'] + r:.4f} {city['lat'] + r:.4f})"^^geo:wktLiteral .
  }}
  ?item wikibase:sitelinks ?links .
  FILTER(?links > 15)
  ?item wdt:P31 ?class .
  ?item rdfs:label ?ru . FILTER(LANG(?ru) = "ru")
  ?item rdfs:label ?en . FILTER(LANG(?en) = "en")
  OPTIONAL {{ ?item wdt:P18 ?img }}
}}
GROUP BY ?item ?ru ?en ?img ?links
ORDER BY DESC(?links)
LIMIT 60
"""
    data = fetch(SPARQL, {"query": query}, {"Accept": "application/sparql-results+json"})
    if not data:
        return []

    out, seen = [], set()
    for row in data.get("results", {}).get("bindings", []):
        ru = row["ru"]["value"]
        if ru in seen or ru == city["name_ru"]:
            continue
        classes = set(row.get("classes", {}).get("value", "").split())
        if not classes & include:
            continue
        if classes & exclude and not classes & strong:
            continue
        if JUNK_NAME.search(ru) or not CYRILLIC.search(ru):
            continue
        seen.add(ru)
        image = row.get("img", {}).get("value", "")
        out.append({"ru": ru, "en": row["en"]["value"],
                    "file": unquote(image.rsplit("/", 1)[-1]).replace("_", " ") if image else ""})
        if len(out) >= PER_CITY:
            break
    return out


def file_info(files):
    """Имя файла на Викискладе → превью, автор, лицензия."""
    out = {}
    files = [f for f in files if f and not JUNK_FILE.search(f)
             and f.lower().endswith((".jpg", ".jpeg"))]
    for i in range(0, len(files), 25):
        batch = files[i:i + 25]
        data = fetch(API_COMMONS, {
            "action": "query", "format": "json", "formatversion": "2",
            "prop": "imageinfo", "iiprop": "url|extmetadata|mime",
            "iiurlwidth": str(THUMB),
            "iiextmetadatafilter": "Artist|LicenseShortName",
            "titles": "|".join("File:" + f for f in batch),
        }, {})
        if not data:
            continue
        for page in data.get("query", {}).get("pages", []):
            info = (page.get("imageinfo") or [None])[0]
            if not info or not info.get("thumburl") or info.get("mime") != "image/jpeg":
                continue
            meta = info.get("extmetadata", {})
            small = info["thumburl"].split("?")[0]
            out[page["title"][len("File:"):]] = {
                "small": small,
                "large": small.replace(f"/{THUMB}px-", "/1280px-"),
                "author": strip_html(meta.get("Artist", {}).get("value", "")),
                "license": strip_html(meta.get("LicenseShortName", {}).get("value", "")),
            }
    return out


TAGS = re.compile(r"<[^>]+>")


def strip_html(value):
    text = TAGS.sub(" ", value)
    for a, b in (("&amp;", "&"), ("&quot;", '"'), ("&#039;", "'"), ("&nbsp;", " ")):
        text = text.replace(a, b)
    return re.sub(r"\s+", " ", text).strip(" ,;")[:80]


def main():
    limit = None
    if "--limit" in sys.argv:
        limit = int(sys.argv[sys.argv.index("--limit") + 1])

    cities = json.loads(CITIES.read_text(encoding="utf-8"))["cities"]
    # Сначала столицы и крупные: если прогон прервётся, важное уже собрано.
    cities.sort(key=lambda c: -(c["population"] * (4 if c["capital"] else 1)))
    if limit:
        cities = cities[:limit]

    include = hierarchy(INCLUDE_ROOTS)
    exclude = hierarchy(EXCLUDE_ROOTS)
    strong = hierarchy(STRONG_ROOTS)
    print(f"классов: смотрим {len(include)}, пропускаем {len(exclude)}, "
          f"из них прощаем {len(strong)}", flush=True)
    if not include:
        print("иерархия не загрузилась — без неё отбор бессмысленен")
        return 1

    result, done = {}, 0
    for city in cities:
        items = landmarks(city, include, exclude, strong)
        done += 1
        if items:
            result[city["id"]] = items
        if done % 25 == 0:
            print(f"  {done}/{len(cities)}: с местами {len(result)}", flush=True)

    files = sorted({item["file"] for items in result.values() for item in items})
    print(f"городов с местами: {len(result)}; файлов: {len(files)}", flush=True)
    info = file_info(files)

    out = {}
    for city_id, items in result.items():
        rows = []
        for item in items:
            photo = info.get(item["file"].replace(" ", "_")) or info.get(item["file"])
            row = {"ru": item["ru"], "en": item["en"]}
            if photo:
                row.update(small=photo["small"], large=photo["large"],
                           author=photo["author"], license=photo["license"])
            rows.append(row)
        out[city_id] = rows

    OUT.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    with_photo = sum(1 for rows in out.values() for r in rows if "small" in r)
    total = sum(len(rows) for rows in out.values())
    print(f"\n{OUT.relative_to(ROOT)}: {len(out)} городов, {total} мест, "
          f"{with_photo} с фотографией, {OUT.stat().st_size // 1024} КБ")


if __name__ == "__main__":
    sys.exit(main())
