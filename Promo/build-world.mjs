// Собирает Promo/world.js из той же геометрии, что рисует приложение.
//
// Страница ролика открывается двойным щелчком, без сервера, а браузер не даёт
// странице с file:// читать соседние файлы через fetch. Поэтому геометрия
// подключается обычным <script>: проекция Меркатора считается здесь один раз,
// в браузер попадают уже точки единичного квадрата — как в MapProjection.swift.

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const source = join(here, "..", "MAPA", "Resources", "world_110m.geojson");
const target = join(here, "world.js");

const MAX_LATITUDE = 85.05112877980659;

function unitPoint(longitude, latitude) {
    const clamped = Math.min(Math.max(latitude, -MAX_LATITUDE), MAX_LATITUDE);
    const radians = clamped * Math.PI / 180;
    const x = (longitude + 180) / 360;
    const y = 0.5 - Math.log(Math.tan(Math.PI / 4 + radians / 2)) / (2 * Math.PI);
    return [Math.min(Math.max(x, 0), 1), Math.min(Math.max(y, 0), 1)];
}

const round = (value) => Math.round(value * 1e6) / 1e6;

export function buildWorld() {
    const geojson = JSON.parse(readFileSync(source, "utf8"));

    const countries = geojson.features.map((feature) => {
        const properties = feature.properties;
        const polygons = feature.geometry.type === "Polygon"
            ? [feature.geometry.coordinates]
            : feature.geometry.coordinates;

        const rings = [];
        // Главный массив — как mainBounds в Country.swift: силуэт в карточке
        // вписывается по нему, иначе острова сжимают страну в полоску.
        let main = null;
        let mainArea = -1;

        for (const polygon of polygons) {
            let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
            for (const ring of polygon) {
                const flat = [];
                for (const [longitude, latitude] of ring) {
                    const [x, y] = unitPoint(longitude, latitude);
                    flat.push(round(x), round(y));
                    minX = Math.min(minX, x); maxX = Math.max(maxX, x);
                    minY = Math.min(minY, y); maxY = Math.max(maxY, y);
                }
                rings.push(flat);
            }
            const area = (maxX - minX) * (maxY - minY);
            if (area > mainArea) {
                mainArea = area;
                main = [minX, minY, maxX - minX, maxY - minY].map(round);
            }
        }

        return {
            id: properties.id,
            name: properties.name,
            nameRU: properties.name_ru,
            continent: properties.continent,
            area: properties.area_km2,
            color: properties.color,
            main,
            rings
        };
    });

    const body = "// Сгенерировано Promo/build-world.mjs из MAPA/Resources/world_110m.geojson.\n"
        + "// Не править руками: перезапусти node Promo/build-world.mjs.\n"
        + "window.MAPA_WORLD = " + JSON.stringify({ countries }) + ";\n";
    writeFileSync(target, body);
    return { count: countries.length, bytes: body.length };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
    const { count, bytes } = buildWorld();
    console.log(`world.js: ${count} стран, ${(bytes / 1024).toFixed(0)} КБ`);
}
