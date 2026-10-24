// Знак MAPA — предложение, а не существующий фирменный стиль.
//
// У приложения нет логотипа: слот AppIcon пуст, бренд живёт только словом
// «MAPA», набранным системным округлым шрифтом (DS.Font.brand) в индиго
// AccentColor. Здесь — три концепции знака и словесный знак, нарисованные
// кодом, чтобы ролик мог их анимировать, а не вставлять картинкой.

(function () {
    const INDIGO = "#6C5CFF";      // DS.Palette.indigo = AccentColor
    const INDIGO_SOFT = "#9B8CFF"; // DS.Palette.indigoSoft
    const INDIGO_DEEP = "#4A3BD8";
    const PAPER = "#FBFAF7";

    // MARK: «Растекание»
    //
    // Три круга, касающиеся изнутри в одной точке. Так в приложении краска
    // растекается по стране из точки касания (MapCanvas.drawBloom): знак —
    // это застывший момент, когда ты отметил страну.
    const BLOOM_POINT = [-Math.SQRT1_2, Math.SQRT1_2];   // касание снизу слева
    const BLOOM_RADII = [1, 0.66, 0.36];
    const BLOOM_TONES = [INDIGO, "#8F82FF", "#C4BCFF"];

    function bloomCircles(progress = [1, 1, 1]) {
        return BLOOM_RADII.map((radius, index) => {
            const r = radius * progress[index];
            const cx = BLOOM_POINT[0] * (1 - r);
            const cy = BLOOM_POINT[1] * (1 - r);
            return { cx, cy, r, fill: BLOOM_TONES[index] };
        });
    }

    function bloom(size, progress) {
        const circles = bloomCircles(progress)
            .filter((c) => c.r > 0.0005)
            .map((c) => `<circle cx="${c.cx.toFixed(5)}" cy="${c.cy.toFixed(5)}" r="${c.r.toFixed(5)}" fill="${c.fill}"/>`)
            .join("");
        return `<svg width="${size}" height="${size}" viewBox="-1 -1 2 2" style="overflow:visible" aria-label="MAPA">${circles}</svg>`;
    }

    // MARK: «Сгиб»
    //
    // Сложенная гармошкой бумажная карта, верхний край которой даёт букву M.
    function fold(size) {
        const panels = [
            ["6,30 28,14 28,70 6,86", INDIGO_DEEP],
            ["28,14 50,44 50,100 28,70", INDIGO_SOFT],
            ["50,44 72,14 72,70 50,100", INDIGO_DEEP],
            ["72,14 94,30 94,86 72,70", INDIGO_SOFT]
        ];
        const polys = panels.map(([points, fill]) => `<polygon points="${points}" fill="${fill}"/>`).join("");
        return `<svg width="${size}" height="${size}" viewBox="0 7 100 100">${polys}</svg>`;
    }

    // MARK: «Меркатор»
    //
    // Мир в приложении — квадрат 1×1 (MapProjection.swift). Параллели
    // разбегаются к полюсам ровно по формуле Меркатора; одна полоса залита.
    function grid(size) {
        const lat = (deg) => {
            const r = deg * Math.PI / 180;
            return 0.5 - Math.log(Math.tan(Math.PI / 4 + r / 2)) / (2 * Math.PI);
        };
        const lines = [-60, -30, 0, 30, 60].map((d) => 8 + lat(d) * 84);
        const band = `<rect x="8" y="${lines[3].toFixed(2)}" width="84" height="${(lines[4] - lines[3]).toFixed(2)}" fill="${INDIGO_SOFT}"/>`;
        const rules = lines.map((y) => `<line x1="8" x2="92" y1="${y.toFixed(2)}" y2="${y.toFixed(2)}" stroke="${PAPER}" stroke-width="3.2"/>`).join("");
        const meridians = [29, 50, 71].map((x) => `<line x1="${x}" x2="${x}" y1="8" y2="92" stroke="${PAPER}" stroke-width="3.2"/>`).join("");
        return `<svg width="${size}" height="${size}" viewBox="0 0 100 100">
            <clipPath id="g${size}"><rect x="8" y="8" width="84" height="84" rx="20"/></clipPath>
            <g clip-path="url(#g${size})"><rect x="8" y="8" width="84" height="84" fill="${INDIGO}"/>${band}${rules}${meridians}</g>
        </svg>`;
    }

    // MARK: Словесный знак
    //
    // Монолиния с круглыми концами и стыками — продолжение DS.Font.brand
    // (heavy, rounded), но своими кривыми: шрифт в ролике и на любой
    // платформе выглядит одинаково и умеет прорисовываться штрихом.
    const LETTERS = {
        M: { width: 92, d: "M11 89 V11 L46 58 L81 11 V89" },
        A: { width: 84, d: "M8 89 L42 11 L76 89 M23 64 H61" },
        P: { width: 76, d: "M11 89 V11 H42 A23 23 0 0 1 42 57 H11" }
    };

    function wordmarkPaths(text = "MAPA", gap = 12) {
        let x = 0;
        const parts = [];
        for (const char of text) {
            const letter = LETTERS[char];
            parts.push({ d: letter.d, x });
            x += letter.width + gap;
        }
        return { parts, width: x - gap };
    }

    function wordmark(height, color = INDIGO, draw = 1) {
        const { parts, width } = wordmarkPaths();
        const paths = parts.map((p) =>
            `<path d="${p.d}" transform="translate(${p.x} 0)" pathLength="1" stroke-dasharray="1 1" stroke-dashoffset="${(1 - draw).toFixed(4)}"/>`).join("");
        return `<svg height="${height}" viewBox="0 0 ${width} 100" style="width:${(height * width / 100).toFixed(2)}px">
            <g fill="none" stroke="${color}" stroke-width="22" stroke-linecap="round" stroke-linejoin="round">${paths}</g>
        </svg>`;
    }

    window.MAPA_BRAND = { INDIGO, INDIGO_SOFT, PAPER, bloom, bloomCircles, fold, grid, wordmark, wordmarkPaths, BLOOM_POINT };
})();
