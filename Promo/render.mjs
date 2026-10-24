// Покадровый экспорт ролика в MP4.
//
// Страница рисует кадр как функцию времени, поэтому экспорт не записывает
// экран в реальном времени, а просит у неё каждый кадр по очереди: ни один
// не пропадёт, сколько бы ни рисовался, и результат одинаков при каждом запуске.
//
//   node Promo/render.mjs                         → Promo/mapa-promo.mp4, 30 к/с
//   node Promo/render.mjs --fps 60 --out film.mp4
//   node Promo/render.mjs --stills 0,3.5,8.2 --dir кадры
//
// Нужны Node 18+, ffmpeg и Playwright с Chromium.

import { spawn } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { buildWorld } from "./build-world.mjs";

const require = createRequire(import.meta.url);
const { chromium } = require("playwright");

const here = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const option = (name, fallback) => {
    const index = args.indexOf(name);
    return index >= 0 ? args[index + 1] : fallback;
};

const fps = Number(option("--fps", "30"));
const output = resolve(option("--out", join(here, "mapa-promo.mp4")));
const stills = option("--stills", null);
const stillsDir = resolve(option("--dir", join(here, "stills")));

buildWorld();

const browser = await chromium.launch();
const page = await browser.newPage({
    viewport: { width: 360, height: 640 },
    deviceScaleFactor: 3          // 1080×1920
});
page.on("pageerror", (error) => { console.error(error); process.exitCode = 1; });

await page.goto(pathToFileURL(join(here, "index.html")).href + "?export");
await page.waitForFunction(() => window.__promoReady === true);
const duration = await page.evaluate(() => window.__promo.duration);

async function frame(t) {
    await page.evaluate((time) => window.__promo.seek(time), t);
    return page.screenshot({ type: "png", animations: "disabled" });
}

if (stills) {
    mkdirSync(stillsDir, { recursive: true });
    for (const value of stills.split(",").map(Number)) {
        const file = join(stillsDir, `t${value.toFixed(2).padStart(5, "0")}.png`);
        writeFileSync(file, await frame(value));
        console.log(file);
    }
} else {
    const total = Math.round(duration * fps);
    const encoder = spawn("ffmpeg", [
        "-y", "-loglevel", "error",
        "-f", "image2pipe", "-framerate", String(fps), "-i", "-",
        "-c:v", "libx264", "-preset", "slow", "-crf", "16",
        "-pix_fmt", "yuv420p", "-movflags", "+faststart",
        output
    ], { stdio: ["pipe", "inherit", "inherit"] });
    const finished = new Promise((ok, fail) =>
        encoder.on("close", (code) => code === 0 ? ok() : fail(new Error(`ffmpeg: код ${code}`))));

    for (let index = 0; index < total; index++) {
        const image = await frame(index / fps);
        if (!encoder.stdin.write(image)) {
            await new Promise((ok) => encoder.stdin.once("drain", ok));
        }
        if (index % fps === 0) process.stdout.write(`\r${(index / fps).toFixed(0)} / ${duration} с`);
    }
    encoder.stdin.end();
    await finished;
    console.log(`\r${output}`);
}

await browser.close();
