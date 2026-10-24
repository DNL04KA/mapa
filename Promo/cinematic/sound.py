"""Звук ролика MAPA, собранный из таймлайна.

Лицензированной музыки в проекте нет, поэтому дорожка синтезируется здесь:
пэд и пульс в темпе 120, удары, «вжухи» камеры, тики загорающихся стран,
счётчик процента, звуковой логотип. Всё — собственный синтез на numpy,
ни одного сэмпла со стороны. Это временная дорожка: перед публикацией её
можно заменить музыкой с подтверждённой лицензией, оставив звуковые акценты.

Тайминги читаются из timeline.js — того же файла, по которому двигается
картинка, поэтому звук и монтаж не расходятся.

    python3 Promo/cinematic/sound.py Promo/cinematic/soundtrack.wav
"""

import json
import sys
import wave
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
SR = 48000
RNG = np.random.default_rng(20261024)


def read_js_object(path, marker):
    text = path.read_text(encoding="utf-8")
    body = text[text.index(marker):]
    return json.loads(body[body.index("{"):body.rindex("}") + 1])


TL = read_js_object(HERE / "timeline.js", "window.MAPA_TIMELINE")
DURATION = TL["duration"]
TOTAL = int(SR * (DURATION + 3.0))
mix = np.zeros((2, TOTAL))
bus_dry = np.zeros((2, TOTAL))      # сухие удары и низ — без ревербератора
bus_pad = np.zeros((2, TOTAL))      # гармония отдельно: у неё срезается низ


# MARK: - Примитивы

def note(name):
    """Частота ноты: «D5», «F#4»."""
    names = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
    pitch, octave = name[:-1], int(name[-1])
    midi = 12 * (octave + 1) + names[pitch]
    return 440.0 * 2 ** ((midi - 69) / 12)


def place(signal, at, pan=0.0, gain=1.0, dry=False, bus=None):
    """Кладёт моно- или стереосигнал в момент at, панорама −1…1 по равной мощности."""
    start = int(at * SR)
    if start >= TOTAL:
        return
    target = bus if bus is not None else (bus_dry if dry else mix)
    if signal.ndim == 1:
        angle = (pan + 1) * np.pi / 4
        signal = np.vstack([signal * np.cos(angle), signal * np.sin(angle)]) * np.sqrt(2)
    end = min(TOTAL, start + signal.shape[1])
    target[:, start:end] += signal[:, :end - start] * gain


def envelope(n, attack, release, curve=3.0):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    r = np.clip((n / SR - t) / max(release, 1e-4), 0, 1) ** curve
    return a * r


def decay(n, seconds):
    return np.exp(-np.arange(n) / SR / seconds)


def sine(freq, n, phase=0.0):
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * freq * t + phase)


def glide(f0, f1, n, tau):
    t = np.arange(n) / SR
    freq = f1 + (f0 - f1) * np.exp(-t / tau)
    return np.sin(2 * np.pi * np.cumsum(freq) / SR)


def spectral_filter(signal, gain_of_freq):
    spectrum = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(len(signal), 1 / SR)
    return np.fft.irfft(spectrum * gain_of_freq(freqs), len(signal))


def sweep_noise(length, f0, f1, width=0.9, shape=None, seed=None):
    """Шум с полосой, плывущей от f0 к f1 (по логарифму) — основа «вжуха»."""
    rng = np.random.default_rng(seed) if seed is not None else RNG
    n = int(length * SR)
    source = rng.standard_normal(n + 4096)
    hop, size = 512, 2048
    window = np.hanning(size)
    out = np.zeros(n + size)
    freqs = np.fft.rfftfreq(size, 1 / SR)
    log_f = np.log(np.maximum(freqs, 1))
    for start in range(0, n, hop):
        p = start / max(1, n)
        p = shape(p) if shape else p
        centre = np.log(f0) + (np.log(f1) - np.log(f0)) * p
        band = np.exp(-0.5 * ((log_f - centre) / width) ** 2)
        chunk = np.fft.irfft(np.fft.rfft(source[start:start + size] * window) * band, size)
        out[start:start + size] += chunk * window
    out = out[:n]
    return out / (np.max(np.abs(out)) + 1e-9)


def layer(*parts):
    """Складывает сигналы разной длины, выравнивая по началу."""
    out = np.zeros(max(len(p) for p in parts))
    for part in parts:
        out[:len(part)] += part
    return out


def soft_click(length=0.02, bright=4500):
    n = int(length * SR)
    burst = RNG.standard_normal(n) * decay(n, 0.003)
    return spectral_filter(burst, lambda f: np.exp(-0.5 * ((np.log(np.maximum(f, 1)) - np.log(bright)) / 0.6) ** 2))


# MARK: - Инструменты

def bell(freq, length=1.6, brightness=1.0):
    """Стеклянный колокольчик: неровные обертоны, верх гаснет быстрее низа."""
    n = int(length * SR)
    partials = [(1.0, 1.0, 1.0), (2.0, 0.42, 0.55), (2.76, 0.28 * brightness, 0.32), (5.4, 0.12 * brightness, 0.16)]
    out = np.zeros(n)
    for ratio, amp, tau in partials:
        out += amp * sine(freq * ratio, n) * decay(n, length * tau)
    return out * envelope(n, 0.002, 0.05)


def pluck(freq, length=0.5):
    """Мягкий щипок: нечётные гармоники, тёмный и короткий."""
    n = int(length * SR)
    out = np.zeros(n)
    for k, amp in [(1, 1.0), (3, 0.22), (5, 0.07)]:
        out += amp * sine(freq * k, n) * decay(n, 0.22 / k ** 0.6)
    return out * envelope(n, 0.003, 0.05)


def thump(at, depth=1.0, f0=110, f1=42, length=0.9):
    """Низкий удар: синус с падающей высотой и щелчок атаки."""
    n = int(length * SR)
    body = glide(f0, f1, n, 0.045) * decay(n, 0.26 * depth + 0.08)
    place(body * 0.9 * depth, at, dry=True)
    place(soft_click(0.012, 2200) * 0.25 * depth, at, dry=True)


def whoosh(start, end, f0, f1, gain=0.5, pan=(0.0, 0.0), width=0.85, seed=None):
    length = end - start
    n = int(length * SR)
    body = sweep_noise(length, f0, f1, width, shape=lambda p: p * p * (3 - 2 * p), seed=seed)
    t = np.linspace(0, 1, n)
    # Нарастает и обрывается мягко, а не «включается».
    amp = np.sin(np.pi * t) ** 1.6
    left_pan = np.interp(t, [0, 1], [pan[0], pan[1]])
    angle = (left_pan + 1) * np.pi / 4
    stereo = np.vstack([body * amp * np.cos(angle), body * amp * np.sin(angle)]) * np.sqrt(2)
    place(stereo * gain, start)


def pad_chord(names, start, end, gain=0.11, attack=0.6, release=0.9):
    """Пэд: на каждую ноту — расстроенная пара с мягкими гармониками."""
    n = int((end - start + release) * SR)
    left = np.zeros(n)
    right = np.zeros(n)
    for index, name in enumerate(names):
        freq = note(name)
        for detune, channel in [(-0.0035, left), (0.0035, right)]:
            f = freq * (1 + detune)
            voice = np.zeros(n)
            for k, amp in [(1, 1.0), (2, 0.18), (3, 0.06)]:
                voice += amp * sine(f * k, n, phase=index * 0.7 + k)
            channel += voice
    env = envelope(n, attack, release, curve=1.5)
    slow = 0.85 + 0.15 * np.sin(2 * np.pi * 0.25 * np.arange(n) / SR)
    stereo = np.vstack([left, right]) * env * slow / len(names)
    place(stereo * gain, start, bus=bus_pad)


# MARK: - Партитура

BEAT = 60 / TL["bpm"]

# Гармония по тактам (2 с): светлый ре мажор, без драмы.
CHORDS = [
    (0.0, 3.0, ["D3", "A3", "E4", "F#4", "C#5"]),
    (3.0, 5.0, ["G2", "D3", "B3", "F#4", "A4"]),
    (5.0, 7.0, ["A2", "E3", "C#4", "F#4", "B4"]),
    (7.0, 9.5, ["B2", "F#3", "D4", "A4", "C#5"]),
    (9.5, 12.0, ["G2", "D3", "B3", "F#4", "E5"]),
    (12.0, 14.5, ["E2", "B2", "G3", "D4", "F#4"]),
    (14.5, 16.3, ["A2", "E3", "B3", "D4", "F#4"]),
]
for start, end, chord in CHORDS:
    pad_chord(chord, start, end, gain=0.12, release=0.9 if end < 16 else 0.45)

# Пульс восьмыми — от превращения карты в экран до карточки и снова
# в кульминации. В карточке и на знаке его нет: там пауза.
PENTA = ["D5", "E5", "F#5", "A5", "B5", "D6"]
ARP_BY_CHORD = {3.0: ["D5", "F#5", "A5", "B5"], 5.0: ["E5", "A5", "C#6", "B5"], 7.0: ["D5", "F#5", "A5", "C#6"],
                9.5: ["D5", "G5", "B5", "F#5"], 12.0: ["E5", "G5", "B5", "D6"], 14.5: ["E5", "A5", "B5", "D6"]}


def arp_notes(t):
    key = max(k for k in ARP_BY_CHORD if k <= t)
    return ARP_BY_CHORD[key]


for section, (start, end, gain) in enumerate([(3.0, 9.4, 0.10), (14.5, 16.4, 0.13)]):
    step = BEAT / 2
    t = start
    index = 0
    while t < end - 1e-6:
        notes = arp_notes(t)
        place(pluck(note(notes[index % len(notes)]), 0.45), t, pan=0.35 * np.sin(index * 1.3), gain=gain)
        if index % 2 == 0:
            thump(t, depth=0.22 if index % 4 == 0 else 0.12, f0=90, f1=48, length=0.35)
        t += step
        index += 1

# MARK: Сцена 1 — лист мира

thump(TL["impact"], depth=1.25, f0=120, f1=38, length=1.4)
place(sweep_noise(0.6, 3000, 400, 0.7, seed=1) * envelope(int(0.6 * SR), 0.002, 0.5) * 0.35, TL["impact"])
whoosh(TL["dive"][0], TL["dive"][1] + 0.15, 280, 3600, gain=0.42, pan=(-0.2, 0.2), seed=2)

# Тики стран: порядок и панорама — те же, что в кадре (дом, затем по
# удалению от него; запад слева, восток справа).
world = read_js_object(HERE.parent / "world.js", "window.MAPA_WORLD")
anchors = {c["id"]: (c["main"][0] + c["main"][2] / 2, c["main"][1] + c["main"][3] / 2) for c in world["countries"]}
home = "POL"
visited = ["DEU", "FRA", "ESP", "PRT", "ITA", "AUT", "CZE", "HUN", "NLD", "BEL", "CHE", "HRV", "GRC", "TUR", "GEO"]
order = [home] + sorted(visited, key=lambda c: np.hypot(anchors[c][0] - anchors[home][0], anchors[c][1] - anchors[home][1]))
scale = ["D5", "E5", "F#5", "A5", "B5"]
for index, country in enumerate(order):
    at = TL["ignite"]["start"] + index * TL["ignite"]["step"]
    octave_shift = index // len(scale)
    name = scale[index % len(scale)]
    freq = note(name[:-1] + str(int(name[-1]) + octave_shift))
    pan = float(np.clip((anchors[country][0] - anchors[home][0]) * 22, -0.8, 0.8))
    place(bell(freq, 0.9, brightness=0.8), at, pan=pan, gain=0.16)
    place(soft_click(0.01, 6000), at, pan=pan, gain=0.05)

# Лист становится экраном: стеклянный щелчок на доле.
dock_end = TL["dock"][1]
place(bell(note("A5"), 1.2) * 0.6 + bell(note("D6"), 1.2) * 0.4, dock_end, gain=0.2)
place(soft_click(0.015, 3000), dock_end, gain=0.15)
thump(dock_end, depth=0.5, f0=95, f1=45, length=0.6)

# MARK: Сцена 2 — касание

whoosh(TL["flight"][0] - 0.1, TL["flight"][1] + 0.1, 500, 2200, gain=0.4, pan=(-0.6, 0.6), seed=3)
place(layer(soft_click(0.02, 1800) * 0.6, pluck(note("A4"), 0.2) * 0.2), TL["tap"], gain=0.5)
whoosh(TL["sheetUp"], TL["sheetUp"] + 0.4, 600, 2800, gain=0.18, seed=4)
place(soft_click(0.02, 2400) * 0.6, TL["pick"], gain=0.5)
place(pluck(note("F#5"), 0.4), TL["pick"], gain=0.18)

apply = TL["apply"]
thump(apply, depth=0.9, f0=100, f1=40, length=1.0)
place(sweep_noise(0.9, 400, 2400, 0.8, seed=5) * envelope(int(0.9 * SR), 0.05, 0.6) * 0.22, apply)
for name, offset, gain in [("D6", 0.0, 0.14), ("F#6", 0.06, 0.1), ("A6", 0.12, 0.08)]:
    place(bell(note(name), 1.8), apply + offset, pan=(offset - 0.06) * 6, gain=gain)

# Счётчик 2.5 → 7.7: тик на каждые полпроцента по той же пружине .flow.
response, damping = 0.68, 0.88
w0 = 2 * np.pi / response
wd = w0 * np.sqrt(1 - damping ** 2)
times = np.arange(0, 1.4, 1 / 1000)
curve = 1 - np.exp(-damping * w0 * times) * (np.cos(wd * times) + damping * w0 / wd * np.sin(wd * times))
before, after = 2.478, 7.709
values = before + (after - before) * curve
last = before
tick = 0
for t, v in zip(times, values):
    if v - last >= 0.5:
        last = v
        place(soft_click(0.008, 5000 + tick * 300), apply + t, pan=-0.2, gain=0.08)
        place(sine(1800 + tick * 120, int(0.03 * SR)) * decay(int(0.03 * SR), 0.008), apply + t, gain=0.05)
        tick += 1

thump(TL["land"], depth=1.0, f0=110, f1=40, length=1.1)
place(bell(note("D5"), 2.0, 0.6), TL["land"], gain=0.12)
whoosh(TL["pull"][0], TL["pull"][1] + 0.1, 2400, 500, gain=0.22, seed=6)

# MARK: Сцена 3 — карточка

whoosh(TL["lift"][0], TL["lift"][1] + 0.1, 350, 4200, gain=0.34, pan=(0.0, -0.1), seed=7)
for name, offset in [("B5", 0.0), ("D6", 0.08), ("F#6", 0.16), ("A6", 0.24)]:
    place(bell(note(name), 1.6, 0.7), TL["cardReveal"] + offset, pan=0.3 - offset * 2, gain=0.07)
whoosh(TL["drop"][0], TL["drop"][1] + 0.05, 3600, 380, gain=0.3, pan=(-0.1, 0.1), seed=8)
thump(TL["drop"][1], depth=0.45, f0=90, f1=45, length=0.5)

# MARK: Сцена 4 — мир и таблица

whoosh(TL["world"][0], TL["world"][1] + 0.2, 1800, 260, gain=0.36, pan=(0.3, -0.3), width=1.1, seed=9)
place(layer(soft_click(0.02, 1800) * 0.6, pluck(note("A4"), 0.2) * 0.2), TL["statsTap"], gain=0.5)
rows = [True, False, True, True, False, False]       # весь мир, Африка, Азия, Европа, С. и Ю. Америка
for index, active in enumerate(rows):
    at = TL["bars"]["start"] + index * TL["bars"]["step"]
    freq = note(["D5", "E5", "F#5", "A5", "B5", "C#6"][index])
    place(pluck(freq, 0.3), at, pan=-0.3 + index * 0.1, gain=0.11 if active else 0.04)

# Океания: одна страна — девять десятых континента. Подъём и удар.
oce = TL["oceania"]
riser_n = int(0.75 * SR)
riser = glide(note("A4"), note("A5"), riser_n, 0.5)
riser = (riser * np.linspace(0.2, 1, riser_n) ** 2) * 0.12
place(riser, oce, gain=1.0)
place(sweep_noise(0.75, 500, 5200, 0.7, seed=10) * np.linspace(0, 1, riser_n) ** 2 * 0.22, oce)
thump(oce + 0.75, depth=1.0, f0=120, f1=40, length=1.0)
for name, offset in [("A5", 0.0), ("D6", 0.03), ("F#6", 0.06)]:
    place(bell(note(name), 1.8), oce + 0.75 + offset, gain=0.11)

# MARK: Знак
#
# Перед ним — вдох тишины: пульс уже замолчал. Затем три ноты на три
# круга знака и аккорд, который держится до конца. Этот мотив — звуковой
# логотип, его можно повторять в будущих роликах.

whoosh(TL["wipe"][0] - 0.25, TL["wipe"][1], 2600, 600, gain=0.2, seed=11)
thump(TL["wipe"][1] - 0.05, depth=0.7, f0=80, f1=36, length=1.6)
motif = ["D5", "A5", "F#6"]
for index, name in enumerate(motif):
    at = TL["mark"]["start"] + index * TL["mark"]["step"]
    place(bell(note(name), 2.6, 0.9), at, pan=(index - 1) * 0.25, gain=0.2)
    place(pluck(note(name), 0.6), at, pan=(index - 1) * 0.25, gain=0.08)
pad_chord(["D3", "A3", "F#4", "A4", "E5"], TL["mark"]["start"], DURATION - 0.2, gain=0.16, attack=0.35, release=1.6)
whoosh(TL["wordmark"][0], TL["wordmark"][1] + 0.2, 1200, 6000, gain=0.07, seed=12)


# MARK: - Пространство и сведение

def reverb(signal, seconds=2.6):
    """Свёртка с синтетическим залом: распадающийся шум, разный слева и справа."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    tail = np.exp(-t / (seconds / 6.9))
    ir = np.vstack([RNG.standard_normal(n), RNG.standard_normal(n)]) * tail
    ir = np.vstack([spectral_filter(ch, lambda f: 1 / (1 + (f / 6000) ** 2)) for ch in ir])
    ir[:, :int(0.012 * SR)] = 0                       # предзадержка
    ir /= np.sqrt(np.sum(ir ** 2, axis=1, keepdims=True))
    size = signal.shape[1] + n
    out = np.vstack([np.fft.irfft(np.fft.rfft(signal[c], size) * np.fft.rfft(ir[c], size), size) for c in range(2)])
    return out[:, :signal.shape[1]]


# Гармонии низ не нужен: его держат удары. Срез ниже 140 Гц убирает муть,
# верх выше 6 кГц приглушён — пэд не спорит с колокольчиками.
pad = np.vstack([spectral_filter(ch, lambda f: (1 / np.sqrt(1 + (140 / np.maximum(f, 1)) ** 4)) / np.sqrt(1 + (f / 6000) ** 2))
                 for ch in bus_pad])
mix += pad * 0.85

wet = reverb(mix)
master = mix * 0.82 + wet * 0.45 + bus_dry + reverb(bus_dry, 1.2) * 0.12

# Низ ниже 30 Гц телефон всё равно не сыграет, а запас съест.
master = np.vstack([spectral_filter(ch, lambda f: 1 / np.sqrt(1 + (28 / np.maximum(f, 1)) ** 8)) for ch in master])

master = master[:, :int(DURATION * SR)]
fade = int(0.35 * SR)
master[:, -fade:] *= np.linspace(1, 0, fade) ** 2

rms = np.sqrt(np.mean(master ** 2))
master *= 10 ** (-17 / 20) / (rms + 1e-9)
peak_limit = 10 ** (-1.0 / 20)
master = np.tanh(master / peak_limit) * peak_limit

target = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "soundtrack.wav"
pcm = (np.clip(master.T, -1, 1) * 32767).astype("<i2")
with wave.open(str(target), "wb") as file:
    file.setnchannels(2)
    file.setsampwidth(2)
    file.setframerate(SR)
    file.writeframes(pcm.tobytes())

print(f"{target.name}: {DURATION:.1f} с, пик {20 * np.log10(np.max(np.abs(master)) + 1e-9):.1f} дБ, "
      f"RMS {20 * np.log10(np.sqrt(np.mean(master ** 2)) + 1e-9):.1f} дБ")
