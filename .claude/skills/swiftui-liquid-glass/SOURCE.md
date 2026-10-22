# Происхождение и применимость

`SKILL.md` и `references/liquid-glass.md` скопированы без изменений из
<https://github.com/Dimillian/Skills> (каталог `swiftui-liquid-glass`).
Лицензия MIT, © 2026 Thomas Ricouard. Скачано 22.10.2026.

## Внимание: к текущему состоянию MAPA неприменимо

Skill описывает API **iOS 26+** (`glassEffect`, `GlassEffectContainer`,
`.buttonStyle(.glass)`). В проекте:

- `IPHONEOS_DEPLOYMENT_TARGET = 16.0`
- сборка на Xcode 14.2+, в SDK этих символов нет

Поэтому код из skill сейчас **не скомпилируется**, и `#available(iOS 26, *)`
этого не спасёт: проверка доступности не добавляет отсутствующие в SDK
символы.

Правило `.claude/rules/swiftui.md` (никаких API новее iOS 16) имеет приоритет
над этим skill до тех пор, пока не выполнены оба условия:

1. установлен Xcode 26+ с SDK iOS 26;
2. осознанно поднят deployment target либо добавлена ветка `#available`,
   собираемая новым SDK.

До этого момента стеклянные поверхности в проекте делаются через
`DesignSystem/Components/GlassSurface.swift` с `.ultraThinMaterial` и
непрозрачным запасным вариантом при Reduce Transparency.
