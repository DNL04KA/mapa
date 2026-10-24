---
paths:
  - "MAPA/Features/**/*.swift"
  - "MAPA/DesignSystem/**/*.swift"
  - "MAPA/App/**/*.swift"
---

# SwiftUI в MAPA

Цель iOS 16, поэтому: `ObservableObject` + `@Published`, **не** `@Observable`
(iOS 17+). `NavigationStack` доступен, `NavigationView` не нужен.

## Экран никогда не задаёт стиль руками

Цвета, размеры, шрифты, тени, анимации берутся из `DS.*`
(`DesignSystem/Tokens/`). Литерал цвета или `.font(.system(size: 14))` в
`Features/` — ошибка: нужный токен либо уже есть, либо его надо добавить в
`DesignSystem`.

Не использовать `List` и `Form` — внешний вид приложения построен на
собственных контейнерах (`GlassSurface`, `SectionHeader`, `PillButton`).

Шрифты берутся из `DS.Font`, размеры значков — из `DS.Size`: `glyph*` для
значков внутри строк (шеврон, галочка, звезда), `icon*` для самостоятельных.

**Единственное исключение** — блок `percent` в
`Features/Stats/WorldStatsPanel.swift`. Главное число приложения набрано
вручную, с четырьмя размерами под светлую и тёмную тему, и это осознанно:
на карте оно неоновое, на бумаге журнальное. Вынос в токены сделал бы
по токену на каждое значение и ничего не улучшил. Трогать его не нужно;
новых исключений заводить тоже.

## Анимации — только через dsMotion

```swift
@Environment(\.dsMotion) private var motion
...
.animation(motion.animation(.snappy), value: state)
.transition(motion.transition(.scale.combined(with: .opacity)))
```

Прямой `withAnimation(.spring())` или `@Environment(\.accessibilityReduceMotion)`
в экране — ошибка: `DSMotionContext` существует ровно для того, чтобы Reduce
Motion работал везде одновременно. Бесконечный фоновый дрейф запускать только
при `motion.allowsAmbientMotion`, смещения параллакса умножать на
`motion.travelScale`.

## Прозрачность

У каждого `.ultraThinMaterial` должен быть непрозрачный запасной вариант при
`motion.reduceTransparency`. Смотри `DesignSystem/Components/GlassSurface.swift`
и повторяй этот приём, а не добавляй материал напрямую.

## Состояние

- `@State` — состояние самого экрана; `@StateObject` — владение моделью;
  `@ObservedObject` — только когда модель передана снаружи.
- Тяжёлые вычисления (геометрия, статистика) живут в `Core/` и во
  вью-моделях, не в `body`. `body` вызывается часто и непредсказуемо.
- Карта рисуется в `Canvas` (`Features/Map/MapCanvas.swift`). Любое изменение
  там влияет на каждый кадр — см. skill `swiftui-performance-audit`.

## Доступность

Каждый интерактивный элемент получает `accessibilityLabel`; декоративное —
`accessibilityHidden(true)`. Составные карточки объединяются через
`accessibilityElement(children:)`. Подробная проверка — skill
`ios-accessibility-audit`.

## Liquid Glass

В `.claude/skills/swiftui-liquid-glass/` лежит оригинальный skill Thomas
Ricouard про API iOS 26+. Он установлен на вырост и **сейчас неприменим**:
нужных символов нет в SDK, `#available(iOS 26, *)` их не добавляет. При
конфликте побеждает это правило. Условия включения — в
`.claude/skills/swiftui-liquid-glass/SOURCE.md`.
