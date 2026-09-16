import SwiftUI

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
    }
}

// MARK: - Семантические роли

public extension DS {

    /// Роли, а не оттенки. В экранах используем только это:
    /// если завтра поменяем бренд, правка будет ровно здесь.
    enum Color {
        // Фоны и поверхности (по возрастанию высоты над «дном»)
        public static let canvas       = Palette.void
        public static let background   = Palette.abyss
        public static let surface      = Palette.surface
        public static let surfaceRaised = Palette.elevated
        public static let surfaceSunken = Palette.deep

        // Границы и разделители
        public static let hairline     = SwiftUI.Color.white.opacity(0.07)
        public static let border       = SwiftUI.Color.white.opacity(0.12)
        public static let borderStrong = SwiftUI.Color.white.opacity(0.22)

        // Текст
        public static let ink          = Palette.inkHigh
        public static let inkSecondary = Palette.inkMid
        public static let inkTertiary  = Palette.inkLow
        public static let inkOnAccent  = Palette.void

        // Акцент
        public static let accent       = Palette.indigo
        public static let accentSoft   = Palette.indigoSoft
        public static let danger       = Palette.danger

        // Карта
        public static let mapWater     = Palette.ocean
        public static let mapLandIdle  = SwiftUI.Color(hex: 0x1C2131)
        public static let mapBorder    = SwiftUI.Color.white.opacity(0.17)

        /// Непрозрачная замена материалу, когда включён Reduce Transparency.
        public static let materialFallback = Palette.elevated
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
