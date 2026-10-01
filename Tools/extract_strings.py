#!/usr/bin/env python3
"""Собирает строки интерфейса из исходников в Localizable.strings.

Почему не регулярным выражением: в Swift внутри строки бывает подстановка
`\\(...)`, а внутри подстановки — своя строка с кавычками. Любая регулярка
на этом рано или поздно съезжает и начинает захватывать комментарии. Здесь
обычный разбор символ за символом: пропускаем комментарии, входим в строку,
считаем скобки внутри подстановок.

Подстановки заменяются на `%@`: именно так ключ выглядит для системы.

    python3 Tools/extract_strings.py
"""

import os, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# Содержимое, а не интерфейс: достопримечательности и описания стран.
# Их перевод — отдельная работа, и в таблицу интерфейса им нельзя.
SKIP = {"CityFacts.swift", "CountryFacts.swift"}
CYRILLIC = re.compile(r"[А-Яа-яЁё]")


def literals(source: str):
    """Все строковые литералы файла, с подстановками в виде %@."""
    i, n = 0, len(source)
    while i < n:
        ch = source[i]
        if ch == "/" and i + 1 < n and source[i + 1] == "/":
            i = source.find("\n", i)
            if i < 0:
                return
            continue
        if ch == "/" and i + 1 < n and source[i + 1] == "*":
            end = source.find("*/", i + 2)
            i = n if end < 0 else end + 2
            continue
        if ch != '"':
            i += 1
            continue

        # Многострочные литералы в интерфейсе не используем — пропускаем.
        if source.startswith('"""', i):
            end = source.find('"""', i + 3)
            i = n if end < 0 else end + 3
            continue

        i += 1
        parts, ok = [], False
        while i < n:
            ch = source[i]
            if ch == "\\" and i + 1 < n:
                if source[i + 1] == "(":
                    depth, i = 1, i + 2
                    while i < n and depth:
                        if source[i] == "(":
                            depth += 1
                        elif source[i] == ")":
                            depth -= 1
                        elif source[i] == '"':      # строка внутри подстановки
                            i += 1
                            while i < n and source[i] != '"':
                                i += 2 if source[i] == "\\" else 1
                        i += 1
                    parts.append("%@")
                    continue
                parts.append(source[i:i + 2])
                i += 2
                continue
            if ch == '"':
                i += 1
                ok = True
                break
            if ch == "\n":                           # незакрытая кавычка
                break
            parts.append(ch)
            i += 1
        if ok:
            yield "".join(parts)


def main():
    keys = {}
    for path in sorted((ROOT / "MAPA").rglob("*.swift")):
        if path.name in SKIP:
            continue
        for value in literals(path.read_text(encoding="utf-8")):
            if CYRILLIC.search(value):
                keys.setdefault(value, set()).add(path.name)

    print("ключей: {}".format(len(keys)))
    print("с подстановкой: {}".format(sum(1 for k in keys if "%@" in k)))

    out = ROOT / "MAPA" / "Resources" / "ru.lproj" / "Localizable.strings"
    lines = ["/* Русский — язык оригинала: ключ совпадает со значением.",
             "   Файл собирается Tools/extract_strings.py, править руками незачем. */",
             ""]
    for key in sorted(keys):
        lines.append('"{}" = "{}";'.format(key, key))
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("записано: {}".format(out.relative_to(ROOT)))

    missing = []
    en = ROOT / "MAPA" / "Resources" / "en.lproj" / "Localizable.strings"
    if en.exists():
        have = set(re.findall(r'^"((?:[^"\\]|\\.)*)" =', en.read_text(encoding="utf-8"), re.M))
        missing = [k for k in keys if k not in have]
    print("нет английского перевода: {}".format(len(missing)))
    if missing:
        (ROOT / ".missing-en.txt").write_text("\n".join(sorted(missing)) + "\n", encoding="utf-8")
        print("список: .missing-en.txt")


if __name__ == "__main__":
    sys.exit(main())
