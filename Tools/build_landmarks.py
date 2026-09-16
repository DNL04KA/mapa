#!/usr/bin/env python3
"""Собирает фотографии достопримечательностей из Викимедиа.

Почему так, а не «скачать красивые картинки из интернета»: у фотографий есть
автор и лицензия. Викимедиа — единственный большой источник, где снимки можно
брать бесплатно, если назвать автора. Скрипт находит страницу места в русской
Википедии, берёт её главное фото и вместе с ним — автора и лицензию.

Главная работа здесь — не найти картинку, а **не взять чужую**. Поиск по
названию охотно подсовывает похожее: на «Сен-Мишель» из Бордо — Мон-Сен-Мишель
из Нормандии, на «Кристианию» из Копенгагена — коллаж Осло (это его старое имя).
Поэтому каждая находка проверяется по координатам: если место дальше 120 км от
города, оно не наше. Отдельно отсеиваются карты, схемы, гербы и коллажи —
по имени файла и по типу: фотографии на Викискладе — JPEG, а PNG почти всегда
карта или логотип.

Ссылки записываются в landmarks.json, сами файлы не качаются: 240 фотографий
раздули бы приложение на сотню мегабайт. Телефон скачает только то, что
пользователь увидит, и сохранит в кэше.

    python3 Tools/build_landmarks.py
"""

import hashlib, json, math, os, re, subprocess, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FACTS = ROOT / "MAPA" / "Core" / "Travel" / "CityFacts.swift"
CITIES = ROOT / "MAPA" / "Resources" / "cities.json"
OUT = ROOT / "MAPA" / "Resources" / "landmarks.json"

UA = "MAPA/0.1 (travel map app; contact via github.com/dnl04ka/mapa) curl"
API_RU = "https://ru.wikipedia.org/w/api.php"
API_COMMONS = "https://commons.wikimedia.org/w/api.php"

PAUSE = 1.2           # Викимедиа режет тех, кто частит; торопиться некуда
THUMB_SMALL = 640
THUMB_LARGE = 1280
MAX_KM = 120          # Помпеи в 25 км от Неаполя, Версаль в 20 от Парижа — влезают

# Имена файлов, за которыми почти никогда не стоит фотография места.
JUNK = re.compile(
    r"(?:^|[\W_])(?:montage|collage|karte|map|maps|mapa|carte|locator|location"
    r"|flag|flags|wappen|seal|logo|emblem|diagram|schema|plan|plans|grundriss"
    r"|poster|banner|icon|symbol|chart|timeline|coin|coins|stamp|medal|blason"
    r"|coat[\W_]of[\W_]arms|sngcop)(?:$|[\W_])", re.I)


CACHE = Path(os.environ.get("MAPA_WIKI_CACHE", ROOT / ".wiki-cache"))


# Названия, которые сами себя не находят: «Золотые Ворота» в русской Википедии
# — это ворота в Киеве, а не мост в Сан-Франциско. Проверено вручную по одному.
TITLE_OVERRIDES = {
    ("Берлин", "Рейхстаг"): "Рейхстаг (здание)",
    ("Марракеш", "Джемаа эль-Фна"): "Джамаа-эль-Фна",
    ("Майами", "Район ар-деко"): "Район ар-деко в Майами-Бич",
    ("Сан-Франциско", "Золотые Ворота"): "Золотые Ворота (мост)",
    ("Сан-Франциско", "Ломбард-стрит"): "Ломбард-стрит (Сан-Франциско)",
    ("Севилья", "Пласа-де-Эспанья"): "Площадь Испании (Севилья)",
    ("Турин", "Египетский музей"): "Египетский музей (Турин)",
    ("Турин", "Палаццо Реале"): "Королевский дворец (Турин)",
    ("Франкфурт", "Небоскрёбы Майнхэттена"): "Коммерцбанк-Тауэр",
    ("Чиангмай", "Ват Чеди Луанг"): "Ват Чеди Луанг",
    # Проверено глазами по контактному листу: здесь автоматика брала снимок
    # правильного города, но не того места.
    ("Амстердам", "Каналы"): "Каналы Амстердама",
    ("Афины", "Древняя агора"): "Афинская агора",
    ("Баку", "Пламенные башни"): "Flame Towers",
    ("Дубай", "Дубай-Молл"): "Дубай Молл",
    ("Лион", "Базилика Фурвьер"): "Базилика Нотр-Дам де Фурвьер",
    ("Лиссабон", "Алфама"): "Алфама",
    ("Москва", "Зарядье"): "Зарядье (парк)",
    ("Москва", "Красная площадь"): "Красная площадь",
    ("Рим", "Ватикан"): "Собор Святого Петра",
    ("Рио-де-Жанейро", "Сахарная голова"): "Сахарная Голова (гора)",
    ("Рио-де-Жанейро", "Христос-Искупитель"): "Статуя Христа-Искупителя",
}


def api(endpoint, **params):
    """Запрос к API через curl: у системного Python нет корневых сертификатов.

    Ответы кладутся в кэш: Викимедиа не любит, когда её опрашивают одним и тем
    же по кругу, а скрипт приходится перезапускать после каждой правки отбора.
    """
    params.setdefault("format", "json")
    params.setdefault("formatversion", "2")
    cmd = ["curl", "-s", "-m", "40", "--get", endpoint, "-H", "User-Agent: " + UA]
    for key, value in params.items():
        cmd += ["--data-urlencode", f"{key}={value}"]

    CACHE.mkdir(exist_ok=True)
    key = CACHE / (hashlib.sha1("\0".join(cmd).encode()).hexdigest() + ".json")
    if key.exists():
        return json.loads(key.read_text(encoding="utf-8"))

    for attempt in range(6):
        result = subprocess.run(cmd, capture_output=True)
        if result.returncode == 0 and result.stdout:
            try:
                data = json.loads(result.stdout)
            except json.JSONDecodeError:
                data = None
            if data is not None and "error" not in data:
                key.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
                time.sleep(PAUSE)
                return data
        if attempt == 5:
            raise RuntimeError(f"не отвечает: {endpoint}\n"
                               f"rc={result.returncode}\n"
                               f"{result.stdout[:400]!r}\n{result.stderr[:200]!r}\n"
                               f"{params}")
        time.sleep(15.0 * (attempt + 1))


def chunks(seq, n):
    for i in range(0, len(seq), n):
        yield seq[i:i + n]


def parse_catalog():
    """Читает каталог прямо из CityFacts.swift, чтобы списки не разъезжались."""
    body = FACTS.read_text(encoding="utf-8").split("catalog: [String: [String]] = [", 1)[1]
    cities = []
    for line in body.splitlines():
        m = re.match(r'^"([^"]+)":\s*\[(.+)\],\s*$', line.strip())
        if m:
            cities.append((m.group(1), re.findall(r'"([^"]+)"', m.group(2))))
    return cities


def city_coords():
    data = json.loads(CITIES.read_text(encoding="utf-8"))["cities"]
    return {c["name_ru"]: (c["lat"], c["lon"]) for c in data}


def km_between(a, b):
    lat1, lon1 = map(math.radians, a)
    lat2, lon2 = map(math.radians, b)
    h = (math.sin((lat2 - lat1) / 2) ** 2
         + math.cos(lat1) * math.cos(lat2) * math.sin((lon2 - lon1) / 2) ** 2)
    return 6371.0 * 2 * math.asin(min(1.0, math.sqrt(h)))


def clean_title(name):
    """«Тайная вечеря» → Тайная вечеря. Кавычки — не часть заголовка."""
    return name.replace("«", "").replace("»", "").strip()


def norm_file(name):
    """«Colosseo 2020.jpg» и «Colosseo_2020.jpg» — один и тот же файл."""
    return name.replace(" ", "_")


def pages(titles):
    """Заголовок → {файл, координаты}. Сразу разрешает перенаправления."""
    found, redirects = {}, {}
    for batch in chunks(titles, 40):
        data = api(API_RU, action="query", prop="pageimages|coordinates",
                   piprop="name", redirects=1, titles="|".join(batch))
        q = data.get("query", {})
        for r in q.get("normalized", []) + q.get("redirects", []):
            redirects[r["from"]] = r["to"]
        for page in q.get("pages", []):
            if page.get("missing"):
                continue
            coord = (page.get("coordinates") or [None])[0]
            found[page["title"]] = {
                "file": page.get("pageimage"),
                "coord": (coord["lat"], coord["lon"]) if coord else None,
            }
    return found, redirects


def article_images(titles):
    """Все картинки статьи по порядку.

    Нужно там, где главная картинка страницы — герб или карта: снимок всё равно
    в статье есть, просто не первым. Брать из самой статьи куда надёжнее, чем
    искать по названию: это гарантированно картинка про это место.
    """
    out = {}
    for batch in chunks(titles, 8):
        data = api(API_RU, action="query", prop="images", imlimit="max",
                   redirects=1, titles="|".join(batch))
        for page in data.get("query", {}).get("pages", []):
            names = [im["title"][len("File:"):] for im in page.get("images", [])]
            out[page["title"]] = names
    return out


def search_page(query):
    data = api(API_RU, action="query", list="search", srsearch=query,
               srlimit=4, srnamespace=0)
    return [hit["title"] for hit in data.get("query", {}).get("search", [])]


TAGS = re.compile(r"<[^>]+>")
SPACES = re.compile(r"\s+")


def strip_html(value):
    text = TAGS.sub(" ", value)
    for a, b in (("&amp;", "&"), ("&quot;", '"'), ("&#039;", "'"),
                 ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " ")):
        text = text.replace(a, b)
    return SPACES.sub(" ", text).strip(" ,;")[:80]


def strip_tracking(url):
    """Убирает utm-хвост: он не нужен и ломает кэш по имени файла."""
    return url.split("?")[0]


def file_info(files):
    """Имя файла → ссылки на превью, автор, лицензия. Не-фотографии отсеиваются."""
    out = {}
    for batch in chunks(files, 25):
        for endpoint in (API_COMMONS, API_RU):
            missing = [f for f in batch if norm_file(f) not in out]
            if not missing:
                break
            data = api(endpoint, action="query", prop="imageinfo",
                       iiprop="url|extmetadata|mime",
                       iiurlwidth=THUMB_SMALL,
                       iiextmetadatafilter="Artist|LicenseShortName",
                       titles="|".join("File:" + f for f in missing))
            for page in data.get("query", {}).get("pages", []):
                info = (page.get("imageinfo") or [None])[0]
                if not info or not info.get("thumburl"):
                    continue
                if info.get("mime") != "image/jpeg":
                    continue          # фотографии на Викискладе — JPEG
                meta = info.get("extmetadata", {})
                small = strip_tracking(info["thumburl"])
                large = small.replace(f"/{THUMB_SMALL}px-", f"/{THUMB_LARGE}px-")
                out[norm_file(page["title"][len("File:"):])] = {
                    "small": small,
                    "large": large,
                    "author": strip_html(meta.get("Artist", {}).get("value", "")),
                    "license": strip_html(meta.get("LicenseShortName", {}).get("value", "")),
                }
    return out


def main():
    catalog_src = parse_catalog()
    coords = city_coords()
    print(f"городов в каталоге: {len(catalog_src)}")

    wanted = {(city, name): TITLE_OVERRIDES.get((city, name), clean_title(name))
              for city, items in catalog_src for name in items}
    titles = sorted(set(wanted.values()))
    print(f"названий к проверке: {len(titles)}")

    found, redirects = pages(titles)

    def resolve(title):
        seen = set()
        while title in redirects and title not in seen:
            seen.add(title)
            title = redirects[title]
        return title

    def near(city, page):
        """Место не должно оказаться в другой стране."""
        home = coords.get(city)
        if not page["coord"] or not home:
            return None                      # координат нет — судить нечем
        return km_between(page["coord"], home) <= MAX_KM

    def good_file(name):
        return bool(name) and name.lower().endswith((".jpg", ".jpeg")) \
            and not JUNK.search(name)

    # Шаг 1: главная картинка страницы с таким названием.
    picked, need_article, need_search = {}, {}, []
    for key, title in wanted.items():
        city, _ = key
        page = found.get(resolve(title))
        if page is None:
            need_search.append(key)
            continue
        if near(city, page) is False:
            need_search.append(key)          # страница про другое место
            continue
        if good_file(page["file"]):
            picked[key] = page["file"]
        else:
            need_article[key] = resolve(title)
    print(f"главная картинка подошла: {len(picked)}; "
          f"смотрим статью: {len(need_article)}; ищем: {len(need_search)}")

    # Шаг 2: если главная картинка — герб или карта, берём первый снимок из статьи.
    if need_article:
        images = article_images(sorted(set(need_article.values())))
        rest = []
        for key, title in need_article.items():
            photo = next((n for n in images.get(title, []) if good_file(n)), None)
            if photo:
                picked[key] = photo
            else:
                rest.append(key)
        need_search += rest
        print(f"нашлось в статьях: {len(need_article) - len(rest)}")

    # Шаг 3: последняя попытка — поиск по названию и городу.
    misses = []
    for city, name in need_search:
        try:
            hits = search_page(f"{clean_title(name)} {city}")
        except RuntimeError:
            hits = []
        hit_pages, hit_redirects = (pages(hits) if hits else ({}, {}))
        found.update(hit_pages)
        redirects.update(hit_redirects)
        for hit in hits:
            page = found.get(resolve(hit))
            if not page or near(city, page) is not True:
                continue                     # без подтверждённых координат не берём
            if good_file(page["file"]):
                picked[(city, name)] = page["file"]
                break
        else:
            misses.append((city, name))

    print(f"с фотографией: {len(picked)}, без: {len(misses)}")

    files = sorted(set(picked.values()))
    print(f"файлов: {len(files)}")
    info = file_info(files)

    result, dropped = {}, []
    for (city, name), fname in sorted(picked.items()):
        meta = info.get(norm_file(fname))
        if not meta:
            dropped.append((city, name))
            continue
        result.setdefault(city, []).append({
            "name": name, "small": meta["small"], "large": meta["large"],
            "author": meta["author"], "license": meta["license"],
        })

    order = {city: {n: i for i, n in enumerate(items)} for city, items in catalog_src}
    for city, items in result.items():
        items.sort(key=lambda it: order[city].get(it["name"], 99))

    OUT.write_text(json.dumps(result, ensure_ascii=False, separators=(",", ":")),
                   encoding="utf-8")
    total = sum(len(v) for v in result.values())

    without = sorted(misses + dropped)
    if without:
        print(f"\nбез фотографии ({len(without)}) — покажем без картинки, врать не станем:")
        for city, name in without:
            print(f"  {city} — {name}")

    print(f"\n{OUT.relative_to(ROOT)}: {len(result)} городов, {total} фотографий, "
          f"{OUT.stat().st_size // 1024} КБ")


if __name__ == "__main__":
    sys.exit(main())
