// Экспорт знака: лист концепций, SVG знака и словесного знака, иконка 1024.
//
//   NODE_PATH="$(npm root -g)" node Promo/brand/export.mjs

import { writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const require = createRequire(import.meta.url);
const { chromium } = require("playwright");
const here = dirname(fileURLToPath(import.meta.url));

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1600, height: 1000 } });
await page.goto(pathToFileURL(join(here, "concepts.html")).href);
await page.screenshot({ path: join(here, "concepts.png"), fullPage: true });

const svgs = await page.evaluate(() => {
    const B = window.MAPA_BRAND;
    const xml = (svg) => svg.replace("<svg ", '<svg xmlns="http://www.w3.org/2000/svg" ');
    return {
        mark: xml(B.bloom(512)),
        lockup: (() => {
            // Знак и слово в одной системе координат: высота знака 120,
            // слово 84 по оптической высоте, зазор 28.
            const mark = B.bloomCircles().map((c) =>
                `<circle cx="${(60 + c.cx * 60).toFixed(3)}" cy="${(60 + c.cy * 60).toFixed(3)}" r="${(c.r * 60).toFixed(3)}" fill="${c.fill}"/>`).join("");
            const { parts, width } = B.wordmarkPaths();
            const scale = 0.84;
            const words = parts.map((p) => `<path d="${p.d}" transform="translate(${p.x} 0)"/>`).join("");
            const total = 120 + 28 + width * scale + 12;
            return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${total.toFixed(1)} 120" width="${total.toFixed(1)}" height="120">${mark}`
                + `<g transform="translate(148 18) scale(${scale})" fill="none" stroke="${B.INDIGO}" stroke-width="22" stroke-linecap="round" stroke-linejoin="round">${words}</g></svg>`;
        })()
    };
});
writeFileSync(join(here, "mapa-mark.svg"), svgs.mark + "\n");
writeFileSync(join(here, "mapa-lockup.svg"), svgs.lockup + "\n");

// Иконка: бумажный фон полотна «Светлая» и знак с полями по сетке iOS.
const icon = await browser.newPage({ viewport: { width: 1024, height: 1024 } });
await icon.setContent(`<body style="margin:0"><div style="width:1024px;height:1024px;display:flex;align-items:center;justify-content:center;background:linear-gradient(160deg,#FFFFFF,#F2F0EB)">${svgs.mark.replace('width="512" height="512"', 'width="600" height="600"')}</div></body>`);
await icon.screenshot({ path: join(here, "mapa-icon-1024.png") });

await browser.close();
console.log("concepts.png, mapa-mark.svg, mapa-lockup.svg, mapa-icon-1024.png");
