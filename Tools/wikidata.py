"""Общая работа с Викиданными и Викискладом.

Два сборщика — городов и стран — спрашивают одно и то же: что здесь стоит
посмотреть и как выглядит фотография. Держать это в двух файлах значит
однажды починить отбор в одном и забыть про другой.
"""

import hashlib, json, os, re, subprocess, time
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent
CACHE = Path(os.environ.get("MAPA_WIKI_CACHE", ROOT / ".wiki-cache"))
CACHE_ONLY = os.environ.get("MAPA_CACHE_ONLY") == "1"

UA = "MAPA/0.1 (travel map app; contact via github.com/dnl04ka/mapa) curl"
SPARQL = "https://query.wikidata.org/sparql"
API_COMMONS = "https://commons.wikimedia.org/w/api.php"

THUMB = 640
PAUSE = 1.0

# Что считаем «местом, куда идут смотреть»: сооружения, музеи,
# археологические памятники, монументы, парки, площади.
INCLUDE_ROOTS = "wd:Q811979 wd:Q33506 wd:Q839954 wd:Q4989906 wd:Q22698 wd:Q2065736"

# Что не считаем. Отсекаем по типу, а не по названию: московский аэропорт
# называется «Шереметьево», а стадион в Буэнос-Айресе — «Бомбонера», и
# никакой список слов их не поймает.
#
# «Организации» здесь намеренно нет: Лувр — тоже организация, и с этим
# корнем из выдачи пропадали все музеи разом.
#
# «Спортивное сооружение» (Q1076486), наоборот, вернулось: без него
# проскакивал «Джузеппе Меацца», чьи классы не лежат под корнем «стадион».
# Вернуть его стало можно только после правила ниже: Колизей — тоже
# стадион по разметке, и спасает его археологический памятник.
# Дороги (Q34442) тоже здесь: «магистраль Банг На» формально сооружение
# и очень известна, но смотреть на неё никто не поедет. Мосты под этот
# корень не попадают — Акаси-Кайкё остаётся.
EXCLUDE_ROOTS = ("wd:Q1248784 wd:Q483110 wd:Q641226 wd:Q1076486 wd:Q55488 "
                 "wd:Q928830 wd:Q3918 wd:Q16917 wd:Q40357 wd:Q39715 "
                 "wd:Q11303 wd:Q34442")

# Классы, которые перевешивают исключение: если объект заведомо памятник,
# музей, храм или дворец, второй ярлык этого не отменяет.
STRONG_ROOTS = ("wd:Q839954 wd:Q33506 wd:Q4989906 wd:Q22698 wd:Q1370598 "
                "wd:Q23413 wd:Q16560 wd:Q174782 wd:Q751876")

JUNK_NAME = re.compile(
    r"аэропорт|вокзал|станция метро|метрополитен|университет|больница|тюрьма|"
    r"кладбище|стадион|автодром|ипподром|электростанц|водохранилищ|"
    r"посольств|тюрем", re.I)

JUNK_FILE = re.compile(
    r"(?:^|[\W_])(?:map|karte|flag|coat[\W_]of[\W_]arms|logo|seal|emblem|diagram|"
    r"plan|location|locator|montage|collage)(?:$|[\W_])", re.I)

CYRILLIC = re.compile(r"[А-Яа-яЁё]")
TAGS = re.compile(r"<[^>]+>")


def fetch(url, params, headers=None, attempts=5):
    """Запрос через curl с кэшем на диске.

    curl, а не urllib: у системного Python нет корневых сертификатов.
    Кэш — потому что сборку приходится перезапускать после каждой правки
    отбора, а Викиданные не любят, когда их спрашивают одно и то же по кругу.
    """
    cmd = ["curl", "-s", "-m", "120", "--get", url, "-H", "User-Agent: " + UA]
    for key, value in (headers or {}).items():
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


def sparql(query):
    return fetch(SPARQL, {"query": query}, {"Accept": "application/sparql-results+json"})


def hierarchy(roots):
    """Все подклассы заданных классов — одним запросом, один раз.

    Так получается в двенадцать раз быстрее. Если спрашивать `P31/P279*`
    внутри самого запроса, Викиданные обходят дерево классов заново для
    каждого города: Берлин считался пятьдесят шесть секунд против четырёх.
    """
    data = sparql(f"SELECT ?c WHERE {{ ?c wdt:P279* ?root . VALUES ?root {{ {roots} }} }}")
    if not data:
        return set()
    return {row["c"]["value"] for row in data.get("results", {}).get("bindings", [])}


def classifiers():
    """Три набора классов: что берём, что нет и что перевешивает запрет.

    Пустой набор — это не «нечего исключать», а «иерархия не скачалась»,
    и работать дальше нельзя: отбор молча пропустит стадионы и аэропорты.
    Один раз так и вышло при сборке из кэша, и в списке Испании появились
    «Камп Ноу» и «Барахас».
    """
    include, exclude, strong = (hierarchy(INCLUDE_ROOTS),
                                hierarchy(EXCLUDE_ROOTS),
                                hierarchy(STRONG_ROOTS))
    if not include or not exclude or not strong:
        raise RuntimeError(
            "иерархия классов не загрузилась ({}/{}/{}) — отбор был бы неверным"
            .format(len(include), len(exclude), len(strong)))
    return include, exclude, strong


def radius(population):
    """Полградуса вокруг мегаполиса и восьмушка вокруг городка.

    Радиус от размера города, а не общий: в Москве интересное разбросано
    на тридцать километров, а у городка на сто тысяч в тот же радиус
    попадут соседние города вместе со своими достопримечательностями.
    """
    if population > 5_000_000:
        return 0.22
    if population > 1_000_000:
        return 0.15
    if population > 300_000:
        return 0.11
    return 0.08


def near_city(city):
    """Известные объекты вокруг города — сырой ответ Викиданных.

    Один запрос на город, и его хватает обоим сборщикам: страна собирается
    из мест своих городов, а не отдельным запросом по стране. Прямой запрос
    «объекты этой страны» выглядит очевиднее, но не работает: в полусотне
    самых известных записей Франции лежат Париж, французский язык и Вторая
    мировая, а Эйфелева башня до отбора не доживает.
    """
    r = radius(city["population"])
    return sparql(f"""
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
""")


def accept(row, include, exclude, strong, skip_names=()):
    """Годится ли находка. Возвращает запись или `None`."""
    ru = row["ru"]["value"]
    if ru in skip_names or JUNK_NAME.search(ru) or not CYRILLIC.search(ru):
        return None

    classes = set(row.get("classes", {}).get("value", "").split())
    if not classes & include:
        return None
    if classes & exclude and not classes & strong:
        return None

    image = row.get("img", {}).get("value", "")
    return {
        "ru": ru,
        "en": row["en"]["value"],
        "file": unquote(image.rsplit("/", 1)[-1]).replace("_", " ") if image else "",
        # Число языковых разделов — наша мера известности. Нужна там, где
        # места разных городов сливаются в один список страны.
        "links": int(row["links"]["value"]),
    }


def strip_html(value):
    text = TAGS.sub(" ", value)
    for a, b in (("&amp;", "&"), ("&quot;", '"'), ("&#039;", "'"), ("&nbsp;", " ")):
        text = text.replace(a, b)
    return re.sub(r"\s+", " ", text).strip(" ,;")[:80]


def file_info(files):
    """Имя файла на Викискладе → превью, автор, лицензия."""
    out = {}
    files = [f for f in files if f and not JUNK_FILE.search(f)
             and f.lower().endswith((".jpg", ".jpeg"))]
    for i in range(0, len(files), 25):
        data = fetch(API_COMMONS, {
            "action": "query", "format": "json", "formatversion": "2",
            "prop": "imageinfo", "iiprop": "url|extmetadata|mime",
            "iiurlwidth": str(THUMB),
            "iiextmetadatafilter": "Artist|LicenseShortName",
            "titles": "|".join("File:" + f for f in files[i:i + 25]),
        })
        if not data:
            continue
        for page in data.get("query", {}).get("pages", []):
            info = (page.get("imageinfo") or [None])[0]
            if not info or not info.get("thumburl") or info.get("mime") != "image/jpeg":
                continue
            meta = info.get("extmetadata", {})
            small = info["thumburl"].split("?")[0]
            out[page["title"][len("File:"):].replace(" ", "_")] = {
                "small": small,
                "large": small.replace(f"/{THUMB}px-", "/1280px-"),
                "author": strip_html(meta.get("Artist", {}).get("value", "")),
                "license": strip_html(meta.get("LicenseShortName", {}).get("value", "")),
            }
    return out


def attach_photos(catalog):
    """Подставляет фотографии к собранным местам."""
    files = sorted({item["file"] for items in catalog.values() for item in items})
    info = file_info(files)
    out = {}
    for key, items in catalog.items():
        rows = []
        for item in items:
            photo = info.get(item["file"].replace(" ", "_"))
            row = {"ru": item["ru"], "en": item["en"]}
            if photo:
                row.update(small=photo["small"], large=photo["large"],
                           author=photo["author"], license=photo["license"])
            rows.append(row)
        out[key] = rows
    return out
