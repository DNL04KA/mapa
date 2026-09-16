import SwiftUI

/// Из чего сделана вода.
///
/// Это главное, что отличает тему от простой смены палитры: на старинной карте
/// океан заштрихован пером, на чертеже расчерчен миллиметровкой, в космосе
/// усыпан звёздами. Меняется материал, а не оттенок.
public enum OceanPattern: Equatable {
    case plain
    /// Диагональная штриховка пером — старинный атлас.
    case hatching
    /// Миллиметровая сетка — чертёж.
    case grid
    /// Звёздная россыпь — вид из космоса.
    case stars
    /// Мелкая рябь на воде.
    case waves
    /// Широкие ленты полярного сияния.
    case ribbons
    /// Лепестки на поверхности.
    case speckle
    /// Волны песчаных дюн.
    case dunes
    /// Топографические изолинии.
    case contours
    /// Перекрёстная штриховка — гравюра.
    case crosshatch
    /// Строки развёртки старого монитора.
    case scanlines
    /// Изморозь: короткие штрихи под случайными углами.
    case frost
    /// Тлеющие угли.
    case embers
    /// Пузырьки воздуха.
    case bubbles
    /// Косой дождь.
    case rain
    /// Переплетение нитей.
    case weave
}

/// Откуда берутся цвета отмеченных стран.
public enum CountryPalette: Equatable {
    /// Тон флага страны — пёстро и узнаваемо.
    case flags
    /// Подобранная палитра из восьми приглушённых тонов — спокойно и дорого.
    case curated
}

/// Чем нарисованы границы.
public struct BorderStyle: Equatable {
    var color: Color
    var width: CGFloat
    /// Пунктир в точках экрана; `nil` — сплошная.
    var dash: [CGFloat]?
}

/// Оформление карты.
///
/// Тема меняет «сцену»: материал воды и суши, чем нарисованы границы,
/// зернистость бумаги, фон и акцент. Цвета отмеченных стран она не трогает —
/// они приходят от флагов, и подменять их темой значило бы ломать смысл карты.
public struct MapTheme: Identifiable, Equatable {

    public let id: String
    public let name: String
    /// Платные темы видно в списке, но выбрать их пока нельзя.
    public let isPremium: Bool

    let oceanTop: Color
    let oceanBottom: Color
    public let landTop: Color
    let landBottom: Color
    let borderOpacity: Double
    public let graticuleOpacity: Double
    public let accent: Color
    /// Два-три пятна фоновой авроры за картой.
    public let auroraColors: [Color]

    // MARK: Материал

    var oceanPattern: OceanPattern = .plain
    /// Цвет узора воды. `nil` — берётся от границ.
    var patternColor: Color?
    /// Откуда берутся цвета отмеченных стран.
public enum CountryPalette: Equatable {
    /// Тон флага страны — пёстро и узнаваемо.
    case flags
    /// Подобранная палитра из восьми приглушённых тонов — спокойно и дорого.
    case curated
}

/// Чем нарисованы границы. `nil` — обычная волосяная линия.
    var borderStyle: BorderStyle?
    /// Зерно поверх карты: бумага, плёнка, шум ЭЛТ.
    var grain: Double = 0
    /// Сила неонового свечения отмеченных стран.
    /// На пергаменте неон неуместен — там краска впитывается, а не светится.
    var markedGlow: Double = 1
    /// Заливать страны плоским цветом, без градиента и внутреннего света.
    /// Так выглядят обычные карты путешествий: цвет ровный, как из фломастера.
    var flatFill: Bool = false
    /// Откуда брать цвета отмеченных стран.
    var palette: CountryPalette = .flags
    /// Мягкая тень, которую суша отбрасывает на воду.
    ///
    /// Одна эта деталь отличает дорогую карту от дешёвой: берег перестаёт быть
    /// линией и становится краем, у карты появляется толщина. На тёмных темах
    /// не нужна — там глубину даёт свечение.
    var landShadow: Double = 0
    /// Короткое описание материала для панели оформления.
    var subtitle: String?
    /// Светлая карта. Меняет не только палитру: по светлому фону не работает
    /// ни неон, ни белый текст поверх карты, поэтому интерфейс переворачивается.
    public var isLight: Bool = false

    /// Цвет текста и значков поверх карты.
    public var mapInk: SwiftUI.Color {
        isLight ? SwiftUI.Color(hex: 0x141A21) : .white
    }

    /// Цвет тени под этим текстом — противоположный, иначе он не читается.
    public var mapInkShadow: SwiftUI.Color {
        isLight ? SwiftUI.Color.white.opacity(0.9) : DS.Palette.void.opacity(0.85)
    }

    var ocean: Gradient { Gradient(colors: [oceanTop, oceanBottom]) }
    var land: Gradient { Gradient(colors: [landTop, landBottom]) }
    var border: Color { borderStyle?.color ?? .white.opacity(borderOpacity) }
    var borderWidth: CGFloat { borderStyle?.width ?? 0.9 }
    var borderDash: [CGFloat]? { borderStyle?.dash }
    var graticule: Color {
        isLight ? .black.opacity(graticuleOpacity * 1.6) : .white.opacity(graticuleOpacity)
    }
    var pattern: Color { patternColor ?? border.opacity(0.5) }

    /// Мини-превью для списка тем.
    var previewGradient: LinearGradient {
        LinearGradient(
            colors: [landTop, oceanTop, oceanBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

public extension MapTheme {

    static let free: [MapTheme] = [night, paper, dawn, depth]

    /// Первыми идут флагманы — по ним и видно, за что платят.
    static let premium: [MapTheme] = [
        atlas, blueprint, cosmos,
        sunset, aurora, sakura, desert,
        emerald, granite, neon, arctic,
        volcano, mint, indigo, coffee
    ]

    static var all: [MapTheme] { free + premium }

    static let `default` = night

    static func theme(id: String) -> MapTheme {
        all.first { $0.id == id } ?? .default
    }

    // MARK: Бесплатные

    static let night = MapTheme(
        id: "night", name: "Ночь", isPremium: false,
        oceanTop: Color(hex: 0x121A2E), oceanBottom: Color(hex: 0x0B0F1C),
        landTop: Color(hex: 0x39426B), landBottom: Color(hex: 0x232A42),
        borderOpacity: 0.17, graticuleOpacity: 0.05,
        accent: Color(hex: 0x6C5CFF),
        auroraColors: [Color(hex: 0x6C5CFF), Color(hex: 0x22A7C9), Color(hex: 0xE86FD1)]
    )

    static let dawn = MapTheme(
        id: "dawn", name: "Рассвет", isPremium: false,
        oceanTop: Color(hex: 0x1E1327), oceanBottom: Color(hex: 0x0F0913),
        landTop: Color(hex: 0x5A4270), landBottom: Color(hex: 0x33253F),
        borderOpacity: 0.20, graticuleOpacity: 0.05,
        accent: Color(hex: 0xFF7A9E),
        auroraColors: [Color(hex: 0xFF7A9E), Color(hex: 0xFFB067), Color(hex: 0x9A5CFF)]
    )

    static let depth = MapTheme(
        id: "depth", name: "Глубина", isPremium: false,
        oceanTop: Color(hex: 0x07202B), oceanBottom: Color(hex: 0x03111A),
        landTop: Color(hex: 0x23525E), landBottom: Color(hex: 0x143038),
        borderOpacity: 0.18, graticuleOpacity: 0.06,
        accent: Color(hex: 0x2BD9C4),
        auroraColors: [Color(hex: 0x2BD9C4), Color(hex: 0x1E7FA8), Color(hex: 0x0C4C5E)]
    )

    /// Светлая карта, сделанная как бумажная.
    ///
    /// Ни чистого серого, ни бирюзы: суша тёплая, цвета кости, вода —
    /// приглушённый сине-серый. Суша отбрасывает на воду мягкую тень, поверх
    /// лежит зерно бумаги. Заливка стран плоская, но тона глубокие,
    /// а не леденцовые.
    static let paper = MapTheme(
        id: "paper", name: "Светлая", isPremium: false,
        // Вода почти без цвета: тон чуть холоднее суши, а разделяет их тень.
        // Голубое море сразу читается как дешёвая заготовка.
        oceanTop: Color(hex: 0xEFEEEB), oceanBottom: Color(hex: 0xE6E5E1),
        landTop: Color(hex: 0xFBFAF7), landBottom: Color(hex: 0xF4F2ED),
        borderOpacity: 0.9, graticuleOpacity: 0,
        accent: Color(hex: 0x2E4A6B),
        auroraColors: [Color(hex: 0xEFEEEB), Color(hex: 0xEFEEEB), Color(hex: 0xEFEEEB)],
        // Граница тёплая и почти неразличимая: разделитель, а не рисунок.
        borderStyle: BorderStyle(color: Color(hex: 0xA79E92).opacity(0.42), width: 0.7, dash: nil),
        grain: 0.05,
        markedGlow: 0,
        flatFill: true,
        palette: .curated,
        landShadow: 0.22,
        subtitle: "Бумага и подобранная палитра",
        isLight: true
    )

    // MARK: Платные

    static let sunset = MapTheme(
        id: "sunset", name: "Закат", isPremium: true,
        oceanTop: Color(hex: 0x2A1330), oceanBottom: Color(hex: 0x120814),
        landTop: Color(hex: 0x7A3B54), landBottom: Color(hex: 0x412032),
        borderOpacity: 0.22, graticuleOpacity: 0.06,
        accent: Color(hex: 0xFF8A4C),
        auroraColors: [Color(hex: 0xFF8A4C), Color(hex: 0xE8446F), Color(hex: 0x7B3FA8)],
        oceanPattern: .waves,
        patternColor: Color(hex: 0xFFB07A).opacity(0.30),
        borderStyle: BorderStyle(color: Color(hex: 0xFFB98A).opacity(0.45), width: 1.0, dash: nil),
        grain: 0.06,
        markedGlow: 0.95,
        subtitle: "Рябь под закатом"
    )

    static let aurora = MapTheme(
        id: "aurora", name: "Северное сияние", isPremium: true,
        oceanTop: Color(hex: 0x061A1C), oceanBottom: Color(hex: 0x020B0D),
        landTop: Color(hex: 0x1D5A4A), landBottom: Color(hex: 0x0F3229),
        borderOpacity: 0.2, graticuleOpacity: 0.07,
        accent: Color(hex: 0x4CFFB0),
        auroraColors: [Color(hex: 0x4CFFB0), Color(hex: 0x37C6E8), Color(hex: 0x9B6BFF)],
        oceanPattern: .ribbons,
        patternColor: Color(hex: 0x7DFFCB).opacity(0.16),
        borderStyle: BorderStyle(color: Color(hex: 0x9EFFD8).opacity(0.42), width: 0.9, dash: nil),
        grain: 0.05,
        markedGlow: 1.0,
        subtitle: "Ленты над водой"
    )

    static let sakura = MapTheme(
        id: "sakura", name: "Сакура", isPremium: true,
        oceanTop: Color(hex: 0x241623), oceanBottom: Color(hex: 0x120A11),
        landTop: Color(hex: 0x77405F), landBottom: Color(hex: 0x42233A),
        borderOpacity: 0.22, graticuleOpacity: 0.06,
        accent: Color(hex: 0xFF9FC4),
        auroraColors: [Color(hex: 0xFF9FC4), Color(hex: 0xFFCFE0), Color(hex: 0xA85C8A)],
        oceanPattern: .speckle,
        patternColor: Color(hex: 0xFFD3E4).opacity(0.5),
        borderStyle: BorderStyle(color: Color(hex: 0xFFC9DE).opacity(0.4), width: 1.0, dash: nil),
        grain: 0.09,
        markedGlow: 0.75,
        subtitle: "Лепестки на воде"
    )

    static let desert = MapTheme(
        id: "desert", name: "Пустыня", isPremium: true,
        oceanTop: Color(hex: 0x1F1710), oceanBottom: Color(hex: 0x0F0B07),
        landTop: Color(hex: 0x7A5C36), landBottom: Color(hex: 0x453220),
        borderOpacity: 0.24, graticuleOpacity: 0.06,
        accent: Color(hex: 0xE8A34C),
        auroraColors: [Color(hex: 0xE8A34C), Color(hex: 0xC46A3A), Color(hex: 0x6E4B2A)],
        oceanPattern: .dunes,
        patternColor: Color(hex: 0xC9945A).opacity(0.30),
        borderStyle: BorderStyle(color: Color(hex: 0x5A3E20).opacity(0.8), width: 1.2, dash: nil),
        grain: 0.14,
        markedGlow: 0.4,
        subtitle: "Волны дюн"
    )

    /// Космос: карта висит в звёздном небе.
    static let cosmos = MapTheme(
        id: "cosmos", name: "Космос", isPremium: true,
        oceanTop: Color(hex: 0x0B0720), oceanBottom: Color(hex: 0x03020C),
        landTop: Color(hex: 0x322A6B), landBottom: Color(hex: 0x1A163C),
        borderOpacity: 0.20, graticuleOpacity: 0.08,
        accent: Color(hex: 0x9B7BFF),
        auroraColors: [Color(hex: 0x9B7BFF), Color(hex: 0x4C6BFF), Color(hex: 0xE86FD1)],
        oceanPattern: .stars,
        patternColor: Color.white.opacity(0.8),
        grain: 0.04,
        subtitle: "Звёздное небо под картой"
    )

    static let emerald = MapTheme(
        id: "emerald", name: "Изумруд", isPremium: true,
        oceanTop: Color(hex: 0x071A14), oceanBottom: Color(hex: 0x030C09),
        landTop: Color(hex: 0x1F5C42), landBottom: Color(hex: 0x113627),
        borderOpacity: 0.19, graticuleOpacity: 0.06,
        accent: Color(hex: 0x3EE08A),
        auroraColors: [Color(hex: 0x3EE08A), Color(hex: 0x1F9E7A), Color(hex: 0x0E5F4F)],
        oceanPattern: .contours,
        patternColor: Color(hex: 0x6FE8B4).opacity(0.16),
        borderStyle: BorderStyle(color: Color(hex: 0x8FF0C4).opacity(0.35), width: 0.9, dash: nil),
        grain: 0.05,
        markedGlow: 1.0,
        subtitle: "Изолинии глубин"
    )

    static let granite = MapTheme(
        id: "granite", name: "Гранит", isPremium: true,
        oceanTop: Color(hex: 0x16181B), oceanBottom: Color(hex: 0x0A0B0D),
        landTop: Color(hex: 0x45494F), landBottom: Color(hex: 0x2A2D31),
        borderOpacity: 0.24, graticuleOpacity: 0.05,
        accent: Color(hex: 0xB9C0C9),
        auroraColors: [Color(hex: 0x6E7681), Color(hex: 0x40454B), Color(hex: 0x8A929C)],
        oceanPattern: .crosshatch,
        patternColor: Color(hex: 0x9AA3AE).opacity(0.16),
        borderStyle: BorderStyle(color: Color(hex: 0x1A1C1F).opacity(0.85), width: 1.3, dash: nil),
        grain: 0.13,
        markedGlow: 0.35,
        subtitle: "Гравюра резцом"
    )

    static let neon = MapTheme(
        id: "neon", name: "Неон", isPremium: true,
        oceanTop: Color(hex: 0x0D0420), oceanBottom: Color(hex: 0x05010D),
        landTop: Color(hex: 0x3A1160), landBottom: Color(hex: 0x1E0A35),
        borderOpacity: 0.26, graticuleOpacity: 0.09,
        accent: Color(hex: 0xFF2BD1),
        auroraColors: [Color(hex: 0xFF2BD1), Color(hex: 0x00E5FF), Color(hex: 0x7B00FF)],
        oceanPattern: .scanlines,
        patternColor: Color(hex: 0x00E5FF).opacity(0.13),
        borderStyle: BorderStyle(color: Color(hex: 0x00E5FF).opacity(0.6), width: 0.9, dash: nil),
        grain: 0.07,
        markedGlow: 1.0,
        subtitle: "Строки развёртки"
    )

    /// Старинный атлас: пергамент, чернильные границы, штриховка океана пером.
    static let atlas = MapTheme(
        id: "atlas", name: "Атлас", isPremium: true,
        oceanTop: Color(hex: 0x2A2317), oceanBottom: Color(hex: 0x17130C),
        landTop: Color(hex: 0x8A7448), landBottom: Color(hex: 0x5A4A2C),
        borderOpacity: 0.30, graticuleOpacity: 0.10,
        accent: Color(hex: 0xE0C285),
        auroraColors: [Color(hex: 0xD9C089), Color(hex: 0x8A7346), Color(hex: 0x4A3D28)],
        oceanPattern: .hatching,
        patternColor: Color(hex: 0x6E5A33).opacity(0.55),
        borderStyle: BorderStyle(color: Color(hex: 0x3A2E18).opacity(0.85), width: 1.3, dash: nil),
        grain: 0.16,
        markedGlow: 0.3,
        subtitle: "Пергамент и перо"
    )

    /// Чертёж: миллиметровка, тонкие белые линии, границы пунктиром.
    static let blueprint = MapTheme(
        id: "blueprint", name: "Чертёж", isPremium: true,
        oceanTop: Color(hex: 0x0A2044), oceanBottom: Color(hex: 0x05122A),
        landTop: Color(hex: 0x143869), landBottom: Color(hex: 0x0B2148),
        borderOpacity: 0.40, graticuleOpacity: 0.14,
        accent: Color(hex: 0x7FD4FF),
        auroraColors: [Color(hex: 0x7FD4FF), Color(hex: 0x2B6BB0), Color(hex: 0x0E2E5E)],
        oceanPattern: .grid,
        patternColor: Color.white.opacity(0.10),
        borderStyle: BorderStyle(color: Color.white.opacity(0.55), width: 0.9, dash: [4, 3]),
        grain: 0.05,
        markedGlow: 0.55,
        subtitle: "Миллиметровка и пунктир"
    )

    static let arctic = MapTheme(
        id: "arctic", name: "Арктика", isPremium: true,
        oceanTop: Color(hex: 0x13202B), oceanBottom: Color(hex: 0x080F15),
        landTop: Color(hex: 0x51707F), landBottom: Color(hex: 0x2E4351),
        borderOpacity: 0.24, graticuleOpacity: 0.07,
        accent: Color(hex: 0x9FE0FF),
        auroraColors: [Color(hex: 0x9FE0FF), Color(hex: 0x5AA8CE), Color(hex: 0xD6F2FF)],
        oceanPattern: .frost,
        patternColor: Color(hex: 0xD6F2FF).opacity(0.35),
        borderStyle: BorderStyle(color: Color(hex: 0xE6F6FF).opacity(0.5), width: 1.1, dash: nil),
        grain: 0.08,
        markedGlow: 0.8,
        subtitle: "Изморозь по воде"
    )

    static let volcano = MapTheme(
        id: "volcano", name: "Вулкан", isPremium: true,
        oceanTop: Color(hex: 0x1A0C0A), oceanBottom: Color(hex: 0x0A0504),
        landTop: Color(hex: 0x6B2A22), landBottom: Color(hex: 0x3A1613),
        borderOpacity: 0.24, graticuleOpacity: 0.06,
        accent: Color(hex: 0xFF5A34),
        auroraColors: [Color(hex: 0xFF5A34), Color(hex: 0xB01F1F), Color(hex: 0x5E1414)],
        oceanPattern: .embers,
        patternColor: Color(hex: 0xFF6A2A).opacity(0.6),
        borderStyle: BorderStyle(color: Color(hex: 0x2A0D09).opacity(0.9), width: 1.2, dash: nil),
        grain: 0.1,
        markedGlow: 1.0,
        subtitle: "Тлеющие угли"
    )

    static let mint = MapTheme(
        id: "mint", name: "Мята", isPremium: true,
        oceanTop: Color(hex: 0x0B1F1E), oceanBottom: Color(hex: 0x050F0F),
        landTop: Color(hex: 0x2C6660), landBottom: Color(hex: 0x183B38),
        borderOpacity: 0.2, graticuleOpacity: 0.06,
        accent: Color(hex: 0x7FE8D0),
        auroraColors: [Color(hex: 0x7FE8D0), Color(hex: 0x3FA894), Color(hex: 0xBFF5E8)],
        oceanPattern: .bubbles,
        patternColor: Color(hex: 0xBFF5E8).opacity(0.22),
        borderStyle: BorderStyle(color: Color(hex: 0xCFF7EC).opacity(0.4), width: 0.9, dash: nil),
        grain: 0.04,
        markedGlow: 0.9,
        subtitle: "Пузырьки воздуха"
    )

    static let indigo = MapTheme(
        id: "indigo", name: "Индиго", isPremium: true,
        oceanTop: Color(hex: 0x0A1230), oceanBottom: Color(hex: 0x040718),
        landTop: Color(hex: 0x2A3C82), landBottom: Color(hex: 0x16214B),
        borderOpacity: 0.2, graticuleOpacity: 0.07,
        accent: Color(hex: 0x5C8CFF),
        auroraColors: [Color(hex: 0x5C8CFF), Color(hex: 0x2B3FA8), Color(hex: 0x8FB4FF)],
        oceanPattern: .rain,
        patternColor: Color(hex: 0x9FBFFF).opacity(0.32),
        borderStyle: BorderStyle(color: Color(hex: 0xAFC8FF).opacity(0.4), width: 0.9, dash: nil),
        grain: 0.06,
        markedGlow: 0.9,
        subtitle: "Косой дождь"
    )

    static let coffee = MapTheme(
        id: "coffee", name: "Кофе", isPremium: true,
        oceanTop: Color(hex: 0x1B1310), oceanBottom: Color(hex: 0x0C0807),
        landTop: Color(hex: 0x63453A), landBottom: Color(hex: 0x392722),
        borderOpacity: 0.24, graticuleOpacity: 0.06,
        accent: Color(hex: 0xD2A182),
        auroraColors: [Color(hex: 0xD2A182), Color(hex: 0x8A5F48), Color(hex: 0x4A3128)],
        oceanPattern: .weave,
        patternColor: Color(hex: 0xA8785C).opacity(0.24),
        borderStyle: BorderStyle(color: Color(hex: 0x2A1A14).opacity(0.85), width: 1.2, dash: nil),
        grain: 0.15,
        markedGlow: 0.45,
        subtitle: "Плетение холста"
    )

}


// MARK: - Тема в окружении

/// Мелкие элементы поверх карты — подписи городов, значок дома, кнопки —
/// должны знать, светлая под ними карта или тёмная. Тащить тему параметром
/// через пять уровней вьюх незачем, поэтому она лежит в окружении.
private struct MapThemeKey: EnvironmentKey {
    static let defaultValue = MapTheme.default
}

public extension EnvironmentValues {
    var mapTheme: MapTheme {
        get { self[MapThemeKey.self] }
        set { self[MapThemeKey.self] = newValue }
    }
}
