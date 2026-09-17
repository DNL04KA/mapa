import SwiftUI

/// Из чего сделана вода.
///
/// Это главное, что отличает полотно от простой смены оттенка: на старинной
/// карте океан заштрихован пером, на чертеже расчерчен миллиметровкой,
/// в космосе усыпан звёздами. Меняется материал, а не цвет.
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

/// Чем нарисованы границы. `nil` — обычная волосяная линия.
public struct BorderStyle: Equatable {
    var color: Color
    var width: CGFloat
    /// Пунктир в точках экрана; `nil` — сплошная.
    var dash: [CGFloat]?
}

// MARK: - Полотно

/// Полотно — то, на чём нарисована карта: вода, суша, границы, зерно.
///
/// Отделено от цветов сознательно. Это два разных вопроса: «на чём рисуем»
/// и «чем закрашиваем страны». Раньше они были слиты в одну тему, и чтобы
/// получить бумагу с яркими странами или ночь со спокойными, пришлось бы
/// заводить тему на каждое сочетание — девятнадцать полотен на восемь палитр
/// это полторы сотни строк-близнецов.
public struct MapSurface: Identifiable, Equatable {

    public let id: String
    public let name: String
    /// Платные полотна видно в списке, но выбрать их пока нельзя.
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

    var oceanPattern: OceanPattern = .plain
    /// Цвет узора воды. `nil` — берётся от границ.
    var patternColor: Color?
    var borderStyle: BorderStyle?
    /// Зерно поверх карты: бумага, плёнка, шум ЭЛТ.
    var grain: Double = 0

    /// Потолок свечения для этого полотна.
    ///
    /// Не «сколько светить», а «сколько разрешено»: на пергаменте неон
    /// неуместен при любой палитре — там краска впитывается, а не светится.
    /// Итоговое свечение — меньшее из потолка полотна и запроса палитры.
    var maxGlow: Double = 1

    /// Полотно требует плоской заливки независимо от палитры.
    /// Бумага — именно такой случай: градиент внутри страны на ней читается
    /// как типографский брак.
    var forcesFlatFill: Bool = false

    /// Мягкая тень, которую суша отбрасывает на воду.
    ///
    /// Одна эта деталь отличает дорогую карту от дешёвой: берег перестаёт быть
    /// линией и становится краем, у карты появляется толщина. На тёмных полотнах
    /// не нужна — там глубину даёт свечение.
    var landShadow: Double = 0
    /// Короткое описание материала для панели оформления.
    var subtitle: String?
    /// Светлое полотно. Меняет не только палитру: по светлому фону не работает
    /// ни неон, ни белый текст поверх карты, поэтому интерфейс переворачивается.
    public var isLight: Bool = false

    /// Мини-превью для списка.
    var previewGradient: LinearGradient {
        LinearGradient(
            colors: [landTop, oceanTop, oceanBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Палитра

/// Откуда берутся цвета отмеченных стран.
public enum PaletteMode: Equatable {
    /// Тон флага страны — пёстро и узнаваемо.
    case flags
    /// Подобранный набор. Один цвет в наборе — это одноцветная карта.
    case set([Color])
}

/// Палитра — чем закрашены страны.
///
/// Живёт отдельно от полотна, потому что это личный выбор другого рода:
/// полотно про настроение карты, палитра про то, как выглядит именно твоя
/// жизнь на ней.
public struct MapPalette: Identifiable, Equatable {

    public let id: String
    public let name: String
    public let isPremium: Bool
    let mode: PaletteMode
    /// Цвет страны, где ты живёшь. Он не входит в набор: если бы входил,
    /// рано или поздно достался бы обычной стране, и дом перестал бы быть
    /// единственным.
    let home: Color
    /// Сколько свечения просит палитра. Реальное — не больше, чем разрешает полотно.
    var glow: Double = 1
    /// Плоская заливка без градиента внутри страны.
    var isFlat: Bool = false
    /// Насколько бледнее прожитого рисуется «хочу».
    ///
    /// Мечта и факт должны отличаться с одного взгляда. В наборах тона глубокие,
    /// поэтому там гасим сильнее; у флагов цвета и так разные по светлоте.
    var wishOpacity: Double = 0.38
    var subtitle: String?

    /// Цвет конкретной страны. Выбор устойчив: одна и та же страна всегда
    /// получает свой тон, а соседи почти никогда не совпадают.
    func color(for countryID: String) -> Color? {
        guard case let .set(colors) = mode, !colors.isEmpty else { return nil }
        var hash: UInt64 = 0x9E3779B97F4A7C15
        for byte in countryID.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100000001b3
        }
        return colors[Int(hash % UInt64(colors.count))]
    }

    /// Мини-превью: четыре тона набора или радуга у флагов.
    var previewColors: [Color] {
        switch mode {
        case .flags:
            return [Color(hex: 0xE2483D), Color(hex: 0xE8A93C),
                    Color(hex: 0x3F8F4E), Color(hex: 0x3A62B0)]
        case let .set(colors):
            guard colors.count >= 4 else {
                return Array(repeating: colors.first ?? home, count: 4)
            }
            let step = max(1, colors.count / 4)
            return (0..<4).map { colors[($0 * step) % colors.count] }
        }
    }
}

// MARK: - Оформление целиком

/// Полотно плюс палитра — то, что видит отрисовка карты.
///
/// Сборка, а не отдельный третий набор настроек: всё, что здесь есть,
/// вычисляется из двух половин. Рисующему коду по-прежнему приходит один
/// объект, поэтому разделение ничего ему не сломало.
public struct MapTheme: Equatable {

    public let surface: MapSurface
    public let palette: MapPalette

    public init(surface: MapSurface, palette: MapPalette) {
        self.surface = surface
        self.palette = palette
    }

    public var id: String { surface.id + "+" + palette.id }

    public var isLight: Bool { surface.isLight }
    public var accent: Color { surface.accent }
    public var auroraColors: [Color] { surface.auroraColors }
    public var graticuleOpacity: Double { surface.graticuleOpacity }
    var landTop: Color { surface.landTop }
    var oceanTop: Color { surface.oceanTop }
    var oceanPattern: OceanPattern { surface.oceanPattern }
    var grain: Double { surface.grain }
    var landShadow: Double { surface.landShadow }

    /// Свечение: меньшее из того, что разрешает полотно, и того, что просит
    /// палитра. Неон на пергаменте не должен светиться, даже если его выбрали.
    var markedGlow: Double { min(surface.maxGlow, palette.glow) }
    var flatFill: Bool { surface.forcesFlatFill || palette.isFlat }

    var ocean: Gradient { Gradient(colors: [surface.oceanTop, surface.oceanBottom]) }
    var land: Gradient { Gradient(colors: [surface.landTop, surface.landBottom]) }
    var border: Color { surface.borderStyle?.color ?? .white.opacity(surface.borderOpacity) }
    var borderWidth: CGFloat { surface.borderStyle?.width ?? 0.9 }
    var borderDash: [CGFloat]? { surface.borderStyle?.dash }
    var graticule: Color {
        isLight ? .black.opacity(surface.graticuleOpacity * 1.6)
                : .white.opacity(surface.graticuleOpacity)
    }
    var pattern: Color { surface.patternColor ?? border.opacity(0.5) }

    /// Цвет текста и значков поверх карты.
    public var mapInk: Color { isLight ? Color(hex: 0x141A21) : .white }

    /// Цвет тени под этим текстом — противоположный, иначе он не читается.
    public var mapInkShadow: Color {
        isLight ? Color.white.opacity(0.9) : DS.Palette.void.opacity(0.85)
    }

    public static let `default` = MapTheme(surface: .night, palette: .flags)
}


// MARK: - Каталог палитр

public extension MapPalette {

    static let free: [MapPalette] = [flags, ink]

    /// Первыми идут те, по которым сразу видно, за что платят.
    static let premium: [MapPalette] = [
        neon, sunsetPalette, seaPalette, forestPalette,
        vintagePalette, charcoal, candy, monoAccent
    ]

    static var all: [MapPalette] { free + premium }

    static func palette(id: String) -> MapPalette {
        all.first { $0.id == id } ?? .flags
    }

    // MARK: Открытые

    static let flags = MapPalette(
        id: "flags", name: "Флаги", isPremium: false,
        mode: .flags,
        home: Color(hex: 0x5FE3B4),
        glow: 1,
        wishOpacity: 0.74,
        subtitle: "Цвет страны — с её флага"
    )

    /// Семь тонов одного семейства: близкие по светлоте, слабые по насыщенности.
    /// Соседние страны различимы, но ни одна не выскакивает вперёд — так
    /// выглядят дорогие бумажные карты.
    static let ink = MapPalette(
        id: "ink", name: "Чернила", isPremium: false,
        mode: .set([
            Color(hex: 0x2E4A6B), Color(hex: 0x3F6560), Color(hex: 0x55677A),
            Color(hex: 0x6B7355), Color(hex: 0x7A5B4C), Color(hex: 0x5B5570),
            Color(hex: 0x87764C)
        ]),
        home: Color(hex: 0x2B2724),
        glow: 0, isFlat: true,
        subtitle: "Приглушённые тона одной семьи"
    )

    // MARK: Платные

    static let neon = MapPalette(
        id: "neon", name: "Неон", isPremium: true,
        mode: .set([
            Color(hex: 0x00E5FF), Color(hex: 0xFF2E93), Color(hex: 0x7CFF3D),
            Color(hex: 0xFFB000), Color(hex: 0x9B5CFF), Color(hex: 0x00FFC2)
        ]),
        home: Color(hex: 0xFFFFFF),
        glow: 1.4,
        wishOpacity: 0.3,
        subtitle: "Вывеска в ночном городе"
    )

    static let sunsetPalette = MapPalette(
        id: "palette-sunset", name: "Закат", isPremium: true,
        mode: .set([
            Color(hex: 0xC2512F), Color(hex: 0xD98324), Color(hex: 0xA8374E),
            Color(hex: 0xE0A33C), Color(hex: 0x8C4A6B), Color(hex: 0xB5643A)
        ]),
        home: Color(hex: 0x3A2028),
        glow: 0.7, isFlat: true,
        subtitle: "Тёплые от охры до сливы"
    )

    static let seaPalette = MapPalette(
        id: "palette-sea", name: "Море", isPremium: true,
        mode: .set([
            Color(hex: 0x1F4E6B), Color(hex: 0x2A7A82), Color(hex: 0x3E6E9E),
            Color(hex: 0x24606B), Color(hex: 0x4A5C8A), Color(hex: 0x2E8C93)
        ]),
        home: Color(hex: 0x10222E),
        glow: 0.6, isFlat: true,
        subtitle: "От мелководья к глубине"
    )

    static let forestPalette = MapPalette(
        id: "palette-forest", name: "Лес", isPremium: true,
        mode: .set([
            Color(hex: 0x3A5F3A), Color(hex: 0x5C7A45), Color(hex: 0x2F5148),
            Color(hex: 0x7A8A4E), Color(hex: 0x4A6B58), Color(hex: 0x6B7A3A)
        ]),
        home: Color(hex: 0x24301F),
        glow: 0.5, isFlat: true,
        subtitle: "Хвоя, мох и молодая листва"
    )

    static let vintagePalette = MapPalette(
        id: "palette-vintage", name: "Винтаж", isPremium: true,
        mode: .set([
            Color(hex: 0x9C7B4E), Color(hex: 0xB08D5F), Color(hex: 0x8A6A45),
            Color(hex: 0xA8825A), Color(hex: 0x7A5F42), Color(hex: 0xC0A070)
        ]),
        home: Color(hex: 0x4A3728),
        glow: 0.25, isFlat: true,
        wishOpacity: 0.32,
        subtitle: "Выцветшая типографская краска"
    )

    /// Одноцветная карта. Самый строгий вариант: страны отличаются не цветом,
    /// а тем, что они закрашены.
    static let charcoal = MapPalette(
        id: "palette-charcoal", name: "Уголь", isPremium: true,
        mode: .set([Color(hex: 0x23282E)]),
        home: Color(hex: 0x000000),
        glow: 0, isFlat: true,
        wishOpacity: 0.22,
        subtitle: "Один цвет на всю карту"
    )

    static let candy = MapPalette(
        id: "palette-candy", name: "Леденцы", isPremium: true,
        mode: .set([
            Color(hex: 0xFF6B8A), Color(hex: 0xFFC145), Color(hex: 0x4ECDC4),
            Color(hex: 0xA06CD5), Color(hex: 0x6BCB77), Color(hex: 0xFF9B54)
        ]),
        home: Color(hex: 0x2B2438),
        glow: 0.8,
        wishOpacity: 0.34,
        subtitle: "Открытая и весёлая"
    )

    /// Один цвет, но взятый от полотна: карта красится тем же тоном, что и
    /// её акцент. Самый «встроенный» вариант — работает на любом полотне.
    static let monoAccent = MapPalette(
        id: "palette-accent", name: "Акцент", isPremium: true,
        mode: .set([]),          // пусто: цвет берётся у полотна
        home: Color(hex: 0x1A1A1A),
        glow: 0.6, isFlat: true,
        wishOpacity: 0.3,
        subtitle: "Цвет самого полотна"
    )
}

// MARK: - Каталог полотен

public extension MapSurface {

    static let free: [MapSurface] = [night, paper, dawn, depth]

    /// Первыми идут флагманы — по ним и видно, за что платят.
    static let premium: [MapSurface] = [
        atlas, blueprint, cosmos,
        sunset, aurora, sakura, desert,
        emerald, granite, neon, arctic,
        volcano, mint, indigo, coffee
    ]

    static var all: [MapSurface] { free + premium }

    static func surface(id: String) -> MapSurface {
        all.first { $0.id == id } ?? .night
    }

    // MARK: Открытые

    static let night = MapSurface(
        id: "night", name: "Ночь", isPremium: false,
        oceanTop: Color(hex: 0x121A2E), oceanBottom: Color(hex: 0x0B0F1C),
        landTop: Color(hex: 0x39426B), landBottom: Color(hex: 0x232A42),
        borderOpacity: 0.17, graticuleOpacity: 0.05,
        accent: Color(hex: 0x6C5CFF),
        auroraColors: [Color(hex: 0x6C5CFF), Color(hex: 0x22A7C9), Color(hex: 0xE86FD1)],
        subtitle: "Глубокая синяя ночь"
    )

    static let dawn = MapSurface(
        id: "dawn", name: "Рассвет", isPremium: false,
        oceanTop: Color(hex: 0x1E1327), oceanBottom: Color(hex: 0x0F0913),
        landTop: Color(hex: 0x5A4270), landBottom: Color(hex: 0x33253F),
        borderOpacity: 0.20, graticuleOpacity: 0.05,
        accent: Color(hex: 0xFF7A9E),
        auroraColors: [Color(hex: 0xFF7A9E), Color(hex: 0xFFB067), Color(hex: 0x9A5CFF)],
        subtitle: "Сумерки перед рассветом"
    )

    static let depth = MapSurface(
        id: "depth", name: "Глубина", isPremium: false,
        oceanTop: Color(hex: 0x07202B), oceanBottom: Color(hex: 0x03111A),
        landTop: Color(hex: 0x23525E), landBottom: Color(hex: 0x143038),
        borderOpacity: 0.18, graticuleOpacity: 0.06,
        accent: Color(hex: 0x2BD9C4),
        auroraColors: [Color(hex: 0x2BD9C4), Color(hex: 0x1E7FA8), Color(hex: 0x0C4C5E)],
        subtitle: "Толща океана"
    )

    static let paper = MapSurface(
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
        maxGlow: 0,
        forcesFlatFill: true,
        landShadow: 0.22,
        subtitle: "Тёплая бумага с тенью",
        isLight: true
    )

    // MARK: Платные

    static let sunset = MapSurface(
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
        maxGlow: 0.95,
        subtitle: "Рябь под закатом"
    )

    static let aurora = MapSurface(
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
        maxGlow: 1.0,
        subtitle: "Ленты над водой"
    )

    static let sakura = MapSurface(
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
        maxGlow: 0.75,
        subtitle: "Лепестки на воде"
    )

    static let desert = MapSurface(
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
        maxGlow: 0.4,
        subtitle: "Волны дюн"
    )

    static let cosmos = MapSurface(
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

    static let emerald = MapSurface(
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
        maxGlow: 1.0,
        subtitle: "Изолинии глубин"
    )

    static let granite = MapSurface(
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
        maxGlow: 0.35,
        subtitle: "Гравюра резцом"
    )

    static let neon = MapSurface(
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
        maxGlow: 1.0,
        subtitle: "Строки развёртки"
    )

    static let atlas = MapSurface(
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
        maxGlow: 0.3,
        subtitle: "Пергамент и перо"
    )

    static let blueprint = MapSurface(
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
        maxGlow: 0.55,
        subtitle: "Миллиметровка и пунктир"
    )

    static let arctic = MapSurface(
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
        maxGlow: 0.8,
        subtitle: "Изморозь по воде"
    )

    static let volcano = MapSurface(
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
        maxGlow: 1.0,
        subtitle: "Тлеющие угли"
    )

    static let mint = MapSurface(
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
        maxGlow: 0.9,
        subtitle: "Пузырьки воздуха"
    )

    static let indigo = MapSurface(
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
        maxGlow: 0.9,
        subtitle: "Косой дождь"
    )

    static let coffee = MapSurface(
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
        maxGlow: 0.45,
        subtitle: "Плетение холста"
    )

}


// MARK: - Оформление в окружении

/// Мелкие элементы поверх карты — подписи городов, значок дома, кнопки —
/// должны знать, светлая под ними карта или тёмная. Тащить оформление
/// параметром через пять уровней вьюх незачем, поэтому оно лежит в окружении.
private struct MapThemeKey: EnvironmentKey {
    static let defaultValue = MapTheme.default
}

public extension EnvironmentValues {
    var mapTheme: MapTheme {
        get { self[MapThemeKey.self] }
        set { self[MapThemeKey.self] = newValue }
    }
}
