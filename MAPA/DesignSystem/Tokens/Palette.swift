import SwiftUI
import UIKit

/// Корневое пространство имён дизайн-системы MAPA.
/// Всё, что относится к внешнему виду, живёт под `DS.` — так в автокомплите
/// сразу видно, что доступно, и ни один хардкод-цвет не пролезает в фичи.
public enum DS {}

// MARK: - Сырая палитра

public extension DS {

    /// Сырые оттенки. Напрямую в UI их использовать не нужно —
    /// для этого есть семантические роли ниже (`DS.Color`).
    enum Palette {
        // Основа: не чёрный, а глубокий сине-фиолетовый космос.
        // Чистый #000000 в тёмной теме читается «дёшево» и убивает глубину.
        static let void       = SwiftUI.Color(hex: 0x06070C)
        static let abyss      = SwiftUI.Color(hex: 0x0B0D15)
        static let deep       = SwiftUI.Color(hex: 0x11141F)
        static let surface    = SwiftUI.Color(hex: 0x171B29)
        static let elevated   = SwiftUI.Color(hex: 0x1F2436)
        static let veil       = SwiftUI.Color(hex: 0x2A3048)

        // Текст
        static let inkHigh    = SwiftUI.Color(hex: 0xF4F5FA)
        static let inkMid     = SwiftUI.Color(hex: 0xA7ADC4)
        static let inkLow     = SwiftUI.Color(hex: 0x6B7189)

        // Брендовый акцент — электрический индиго.
        static let indigo     = SwiftUI.Color(hex: 0x6C5CFF)
        static let indigoSoft = SwiftUI.Color(hex: 0x9B8CFF)

        // Цвета статусов живут в DS.StatusColor: они заданы в HSB,
        // чтобы у каждой страны мог быть свой оттенок внутри статуса.
        // Ниже — декоративные оттенки: фоновая аврора и служебные подписи.
        // Со статусами они не связаны, менять их можно независимо.
        static let mint       = SwiftUI.Color(hex: 0x5FE3B4)
        static let lagoon     = SwiftUI.Color(hex: 0x22A7C9)
        static let magenta    = SwiftUI.Color(hex: 0xE86FD1)

        // Служебные
        static let danger     = SwiftUI.Color(hex: 0xFF5C6E)
        static let ocean      = SwiftUI.Color(hex: 0x0D1220)   // «вода» на карте

        // MARK: Светлая сторона

        // Не белый лист, а тёплая бумага — тот же материал, что у светлого
        // полотна карты. Чистый #FFFFFF рядом с ней выглядит как дырка.
        static let paper      = SwiftUI.Color(hex: 0xFBFAF7)
        static let paperDeep  = SwiftUI.Color(hex: 0xF2F0EB)
        static let paperSunk  = SwiftUI.Color(hex: 0xE9E7E1)

        static let inkDark    = SwiftUI.Color(hex: 0x141A21)
        static let inkDarkMid = SwiftUI.Color(hex: 0x5A6470)
        static let inkDarkLow = SwiftUI.Color(hex: 0x8B949F)
    }
}

// MARK: - Семантические роли

public extension DS {

    /// Роли, а не оттенки. В экранах используем только это:
    /// если завтра поменяем бренд, правка будет ровно здесь.
    enum Color {

        /// Цвет, который сам знает, что делать на светлом и на тёмном.
        ///
        /// Так панели следуют выбранному полотну карты без единой правки
        /// на местах: панель объявляет свою схему один раз, а все роли
        /// переключаются сами. Пока роли были статично-тёмными, светлая
        /// карта соседствовала с чёрными панелями, и это выглядело так,
        /// будто половину приложения забыли покрасить.
        static func adaptive(light: SwiftUI.Color, dark: SwiftUI.Color) -> SwiftUI.Color {
            SwiftUI.Color(UIColor { trait in
                trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
            })
        }

        // Фоны и поверхности (по возрастанию высоты над «дном»)
        public static let canvas        = adaptive(light: Palette.paper,     dark: Palette.void)
        public static let background    = adaptive(light: Palette.paperDeep, dark: Palette.abyss)
        public static let surface       = adaptive(light: Palette.paper,     dark: Palette.surface)
        public static let surfaceRaised = adaptive(light: .white,            dark: Palette.elevated)
        public static let surfaceSunken = adaptive(light: Palette.paperSunk, dark: Palette.deep)

        // Границы и разделители
        public static let hairline     = adaptive(light: .black.opacity(0.07),
                                                  dark:  .white.opacity(0.07))
        public static let border       = adaptive(light: .black.opacity(0.12),
                                                  dark:  .white.opacity(0.12))
        public static let borderStrong = adaptive(light: .black.opacity(0.22),
                                                  dark:  .white.opacity(0.22))

        // Текст
        public static let ink          = adaptive(light: Palette.inkDark,    dark: Palette.inkHigh)
        public static let inkSecondary = adaptive(light: Palette.inkDarkMid, dark: Palette.inkMid)
        public static let inkTertiary  = adaptive(light: Palette.inkDarkLow, dark: Palette.inkLow)
        public static let inkOnAccent  = adaptive(light: .white,             dark: Palette.void)

        /// Подложка панели: то, на чём лежит содержимое всплывающих панелей.
        public static let panel        = adaptive(light: Palette.paper, dark: Palette.abyss)

        /// Затемнение под панелью. На светлой теме затемняем слабее:
        /// чёрная пелена поверх бумаги выглядит как сбой, а не как глубина.
        public static let scrim        = adaptive(light: .black.opacity(0.18),
                                                  dark:  Palette.void.opacity(0.45))

        // Акцент
        public static let accent       = Palette.indigo
        public static let accentSoft   = Palette.indigoSoft
        public static let danger       = Palette.danger

        // Карта
        public static let mapWater     = Palette.ocean
        public static let mapLandIdle  = SwiftUI.Color(hex: 0x1C2131)
        public static let mapBorder    = SwiftUI.Color.white.opacity(0.17)

        /// Непрозрачная замена материалу, когда включён Reduce Transparency.
        public static let materialFallback = adaptive(light: .white, dark: Palette.elevated)

        /// Первые три места в топе. Цвет здесь, а не в экране: место —
        /// понятие приложения, а не частность одного списка.
        public static let gold   = SwiftUI.Color(hex: 0xE8C45F)
        public static let silver = SwiftUI.Color(hex: 0xBFC7D4)
        public static let bronze = SwiftUI.Color(hex: 0xCE8E5A)
    }
}

// MARK: - Hex

public extension Color {
    /// `Color(hex: 0x1A2B3C)` — короче и читаемее, чем три дробных числа.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255,
            opacity: opacity
        )
    }
}
