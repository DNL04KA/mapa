// Покадровый экспорт фильма со звуком.
//
//   node Promo/cinematic/render.mjs                 → mapa-film.mp4, 1080×1920, 60 к/с
//   node Promo/cinematic/render.mjs --preview       → mapa-film-preview.mp4, 30 к/с, быстрее
//   node Promo/cinematic/render.mjs --stills 0,3,7 --dir кадры
//
// Звук собирается заново из timeline.js (sound.py), поэтому картинка и
// дорожка не могут разойтись: обе читают одни и те же секунды.

import { spawnSync, spawn } from "node:child_process";
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const require = createRequire(import.meta.url);
const { chromium } = require("playwright");

const here = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const option = (name, fallback) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : fallback; };
const flag = (name) => args.includes(name);

const preview = flag("--preview");
const fps = Number(option("--fps", preview ? "30" : "60"));
const output = resolve(option("--out", join(here, preview ? "mapa-film-preview.mp4" : "mapa-film.mp4")));
const stills = option("--stills", null);
const stillsDir = resolve(option("--dir", join(here, "stills")));
const soundtrack = join(here, "soundtrack.wav");

if (!existsSync(join(here, "..", "world.js"))) {
    const { buildWorld } = await import("../build-world.mjs");
    buildWorld();
}

if (!stills && !flag("--no-audio")) {
    const sound = spawnSync("python3", [join(here, "sound.py"), soundtrack], { stdio: "inherit" });
    if (sound.status !== 0) throw new Error("sound.py не собрал дорожку");
}

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 360, height: 640 }, deviceScaleFactor: 3 });
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
    const withAudio = !flag("--no-audio");
    const encoder = spawn("ffmpeg", [
        "-y", "-loglevel", "error",
        "-f", "image2pipe", "-framerate", String(fps), "-i", "-",
        ...(withAudio ? ["-i", soundtrack] : []),
        "-c:v", "libx264", "-preset", preview ? "veryfast" : "slow", "-crf", preview ? "20" : "15",
        "-pix_fmt", "yuv420p", "-r", String(fps),
        ...(withAudio ? ["-c:a", "aac", "-b:a", "256k", "-ar", "48000"] : []),
        "-t", String(duration),
        "-movflags", "+faststart",
        output
    ], { stdio: ["pipe", "inherit", "inherit"] });
    const finished = new Promise((ok, fail) => encoder.on("close", (code) => code === 0 ? ok() : fail(new Error(`ffmpeg: код ${code}`))));

    const total = Math.round(duration * fps);
    for (let index = 0; index < total; index++) {
        const image = await frame(index / fps);
        if (!encoder.stdin.write(image)) await new Promise((ok) => encoder.stdin.once("drain", ok));
        if (index % fps === 0) process.stdout.write(`\r${(index / fps).toFixed(0)} / ${duration} с`);
    }
    encoder.stdin.end();
    await finished;
    console.log(`\r${output}`);
}

await browser.close();
