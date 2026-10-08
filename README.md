# MAPA

Кинематографичная карта путешествий с маршрутами от сообщества.

## Как открыть проект

`MAPA.xcodeproj` **генерируется** из содержимого папки `MAPA/`:

```bash
python3 Tools/generate_project.py
open MAPA.xcodeproj
```

Добавил или удалил файл — просто перезапусти генератор. Так мы не правим
`project.pbxproj` руками и не ловим конфликты в git.

## Структура

```
MAPA/
  App/            точка входа и корневой экран
  Core/           модели и сервисы, не зависящие от UI
  DesignSystem/   токены, движение, хаптика, компоненты
  Features/       экраны
  Resources/      ассеты
Tools/            генератор Xcode-проекта
```

## Границы стран

В бандле лежит `MAPA/Resources/world_110m.geojson` — это обработанный
Natural Earth 1:110m (public domain). Пересобрать:

```bash
curl -L -o /tmp/ne_110m.geojson \
  https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_admin_0_countries.geojson
python3 Tools/build_borders.py /tmp/ne_110m.geojson
```

Скрипт выбрасывает 163 ненужных атрибута из 168, округляет координаты,
слегка упрощает контуры и считает площадь каждой страны: 819 КБ → 197 КБ,
176 стран, 10 298 точек.

Данные 1:110m держат зум примерно до 14× — дальше береговая линия
распадается на видимые отрезки. Отсюда `MapCamera.maxZoom`. Переход
на 1:50m поднимет потолок ценой веса бандла.

## Города

`MAPA/Resources/cities.json` — 541 город из Natural Earth 1:50m
(public domain), до шести на страну, все с русскими названиями. Пересобрать:

```bash
curl -L -o /tmp/ne_cities.geojson \\
  https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_populated_places_simple.geojson
cd Tools && python3 build_cities.py /tmp/ne_cities.geojson
```

Русские названия лежат в `Tools/city_names_ru.py` — в исходных данных их нет.
Скрипт сообщает, если в бандл попал город без перевода.

Отбор: по шесть самых значимых городов на страну (столица весит вчетверо
по населению). Полторы тысячи записей ради невидимого хвоста не нужны —
на экране всё равно показывается не больше шести.

Пропущены города-государства (Сингапур, Монако, Ватикан) — в границах 1:110m
у них нет полигона, привязать их не к чему, — и антарктические станции.

## Хранение отметок

Отметки лежат за протоколом `TravelLogStorage`. Сейчас реализация одна —
`FileTravelLogStorage`: JSON в Application Support, атомарная запись.

SwiftData требует iOS 17 и Xcode 15, которых на этой машине пока нет.
Когда они появятся, добавляется `SwiftDataTravelLogStorage`, и меняется
одна строка — значение по умолчанию в `WorldMapViewModel.init`.
Формат файла содержит поле `version`, так что перенос данных из JSON
в SwiftData будет разовой миграцией, а не потерей.

## Требования

- Сейчас: Xcode 14.2, цель сборки iOS 16.0
- Начиная с 4-го этапа (SwiftData) понадобится Xcode 15+ и macOS 13.5+;
  тогда `DEPLOYMENT_TARGET` в `Tools/generate_project.py` поднимается до `17.0`.

## Правила дизайн-системы

1. В экранах нет литеральных цветов, размеров и `Animation` — только `DS.*`.
2. Любая анимация проходит через `@Environment(\.dsMotion)`, чтобы Reduce Motion
   работал сам собой.
3. Материал (`.ultraThinMaterial`) всегда идёт с непрозрачным запасным вариантом
   для Reduce Transparency.
4. Стандартные `List` и `Form` не используются.

## Проверки

```bash
# Тесты (19 штук): проекция, камера, чтение старых маршрутов,
# статистика, целостность справочников.
xcodebuild test -project MAPA.xcodeproj -scheme MAPA \
  -destination 'platform=iOS Simulator,name=iPhone 14 Pro'

# Города против границ стран: одна столица на страну, координаты в своей стране.
python3 Tools/check_cities.py

# Строки интерфейса: собрать ru-таблицу и показать, чего нет в английской.
python3 Tools/extract_strings.py
```
