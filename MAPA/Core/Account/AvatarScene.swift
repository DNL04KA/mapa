import SwiftUI

/// Аватарка-пейзаж.
///
/// Значок на градиенте есть у каждого второго приложения, и запомнить его
/// нельзя. Здесь вместо значка маленькая картинка: закат в горах, море,
/// северное сияние, ночной город. Двенадцать штук, и человек узнаёт свою
/// с одного взгляда — как узнают обложку книги, а не корешок.
///
/// Рисуется кодом, а не лежит картинками. Причина та же, что у иконки
/// приложения: аватарку в сорок восемь точек и в сто сорок надо показывать
/// одинаково чётко, а набор из двенадцати картинок в трёх размерах — это
/// тридцать шесть файлов, которые разойдутся при первой же правке палитры.
struct AvatarScene: View {

    let index: Int
    var size: CGFloat = 64

    /// Сколько всего пейзажей.
    static let count = 12

    private var scene: Int { ((index % Self.count) + Self.count) % Self.count }

    var body: some View {
        Canvas { context, bounds in
            let rect = CGRect(origin: .zero, size: bounds)
            context.clip(to: Path(ellipseIn: rect))
            draw(scene, in: &context, rect: rect)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            // Ободок изнутри: он отделяет кружок от тёмной панели и
            // добавляет ему объёма на любом фоне.
            Circle().strokeBorder(.white.opacity(0.18), lineWidth: max(1, size * 0.022))
        }
        .accessibilityHidden(true)
    }

    // MARK: - Сами пейзажи

    private func draw(_ scene: Int, in context: inout GraphicsContext, rect: CGRect) {
        switch scene {
        case 0:  sunsetMountains(&context, rect)
        case 1:  sea(&context, rect)
        case 2:  aurora(&context, rect)
        case 3:  city(&context, rect)
        case 4:  desert(&context, rect)
        case 5:  forest(&context, rect)
        case 6:  snowPeaks(&context, rect)
        case 7:  island(&context, rect)
        case 8:  starryNight(&context, rect)
        case 9:  sunrise(&context, rect)
        case 10: canyon(&context, rect)
        default: northernSea(&context, rect)
        }
    }

    private func sunsetMountains(_ c: inout GraphicsContext, _ r: CGRect) {
        sky(&c, r, [0xFFB45C, 0xE2622F, 0x7A2E52])
        disc(&c, r, x: 0.5, y: 0.47, radius: 0.15, color: 0xFFE9A8)
        ridge(&c, r, base: 0.92, peaks: [(0.18, 0.56), (0.5, 0.74), (0.86, 0.60)], color: 0x5B2342)
        ridge(&c, r, base: 1.0, peaks: [(0.0, 0.78), (0.35, 0.90), (0.72, 0.80), (1.0, 0.92)],
              color: 0x37142C)
    }

    private func sea(_ c: inout GraphicsContext, _ r: CGRect) {
        sky(&c, r, [0x8FE3F0, 0x3FA9D6, 0x1C5F96])
        disc(&c, r, x: 0.72, y: 0.3, radius: 0.1, color: 0xFFF3C4)
        wave(&c, r, y: 0.62, amplitude: 0.05, color: 0x1F6FA8)
        wave(&c, r, y: 0.74, amplitude: 0.06, color: 0x14527F)
        wave(&c, r, y: 0.88, amplitude: 0.05, color: 0x0C3A5E)
    }

    private func aurora(_ c: inout GraphicsContext, _ r: CGRect) {
        sky(&c, r, [0x101A3A, 0x1B2A5B, 0x0A1026])
        stars(&c, r, count: 14, seed: 7)
        ribbon(&c, r, y: 0.34, color: 0x5FE3B4, opacity: 0.75)
        ribbon(&c, r, y: 0.44, color: 0x6C5CFF, opacity: 0.55)
        ridge(&c, r, base: 1.0, peaks: [(0.12, 0.72), (0.46, 0.84), (0.84, 0.70)], color: 0x060B1C)
    }

    private func city(_ c: inout GraphicsContext, _ r: CGRect) {
        sky(&c, r, [0x6C5CFF, 0x9B5CFF, 0x2A1B4D])
        disc(&c, r, x: 0.28, y: 0.3, radius: 0.09, color: 0xFFF0C9)
        let towers: [(CGFloat, CGFloat, CGFloat)] = [
            (0.08, 0.62, 0.14), (0.24, 0.52, 0.12), (0.38, 0.68, 0.10),
            (0.50, 0.44, 0.14), (0.66, 0.60, 0.12), (0.80, 0.54, 0.16),
        ]
        for (x, top, width) in towers {
            let tower = CGRect(x: r.minX + r.width * x, y: r.minY + r.height * top,
                               width: r.width * width, height: r.height * (1 - top))
            c.fill(Path(tower), with: .color(Color(hex: 0x1B1038)))
            // Пара окон — иначе силуэт читается как забор.
            for row in 0..<3 {
                let window = CGRect(x: tower.minX + tower.width * 0.3,
                                    y: tower.minY + tower.height * (0.18 + CGFloat(row) * 0.26),
                                    width: tower.width * 0.22, height: tower.height * 0.1)
                if window.maxY < tower.maxY {
                    c.fill(Path(window), with: .color(Color(hex: 0xFFD98A).opacity(0.85)))
                }
            }
        }
    }

    private func desert(_ c: inout GraphicsContext, _ r: CGRect) {
        sky(&c, r, [0xFFE0B0, 0xFFA85C, 0xE2622F])
        disc(&c, r, x: 0.32, y: 0.3, radius: 0.11, color: 0xFFF6DC)
        // Барханы в три слоя, каждый заметно темнее предыдущего: на
        // тёплом небе близкие оттенки сливаются в одно пятно.
        dune(&c, r, y: 0.58, bulge: 0.16, color: 0xE0A05A)
        dune(&c, r, y: 0.74, bulge: -0.14, color: 0xA85E2E)
        dune(&c, r, y: 0.9, bulge: 0.12, color: 0x6B3418)
    }

    private func forest(_ c: inout GraphicsContext, _ r: CGRect) {
        sky(&c, r, [0xBFE8C8, 0x5C9E77, 0x24543F])
        disc(&c, r, x: 0.68, y: 0.28, radius: 0.08, color: 0xFFF6C9)
        firs(&c, r, base: 0.86, tops: [0.46, 0.58, 0.40, 0.62, 0.50], color: 0x235240)
        firs(&c, r, base: 1.0, tops: [0.62, 0.52, 0.68, 0.56], color: 0x12352A, offset: 0.1)
    }

    private func snowPeaks(_ c: inout GraphicsContext, _ r: CGRect) {
        sky(&c, r, [0xD8ECFF, 0x8FBEE6, 0x3E6E9E])
        ridge(&c, r, base: 1.0, peaks: [(0.2, 0.42), (0.52, 0.60), (0.84, 0.36)], color: 0x4A6B8C)
        // Снежные шапки поверх вершин.
        cap(&c, r, peak: (0.2, 0.42), width: 0.12)
        cap(&c, r, peak: (0.84, 0.36), width: 0.14)
        ridge(&c, r, base: 1.0, peaks: [(0.0, 0.78), (0.4, 0.88), (1.0, 0.74)], color: 0x2E4A6B)
    }

    private func island(_ c: inout GraphicsContext, _ r: CGRect) {
        sky(&c, r, [0x7FE8DC, 0x2EBFB0, 0x0E6A73])
        disc(&c, r, x: 0.74, y: 0.26, radius: 0.09, color: 0xFFF4CC)
        // Остров — холм с пляжем.
        var hill = Path()
        hill.move(to: CGPoint(x: r.minX + r.width * 0.26, y: r.minY + r.height * 0.72))
        hill.addQuadCurve(to: CGPoint(x: r.minX + r.width * 0.74, y: r.minY + r.height * 0.72),
                          control: CGPoint(x: r.minX + r.width * 0.5, y: r.minY + r.height * 0.42))
        hill.closeSubpath()
        c.fill(hill, with: .color(Color(hex: 0x1F7A52)))
        wave(&c, r, y: 0.74, amplitude: 0.03, color: 0xF2E2B8)
        wave(&c, r, y: 0.84, amplitude: 0.05, color: 0x0E7B82)
        wave(&c, r, y: 0.95, amplitude: 0.04, color: 0x0A5A66)
    }

    private func starryNight(_ c: inout GraphicsContext, _ r: CGRect) {
        sky(&c, r, [0x1B2A5B, 0x0E1430, 0x05070F])
        stars(&c, r, count: 22, seed: 3)
        disc(&c, r, x: 0.7, y: 0.26, radius: 0.1, color: 0xF3F1E0)
        ridge(&c, r, base: 1.0, peaks: [(0.25, 0.76), (0.6, 0.86), (0.92, 0.78)], color: 0x070A18)
    }

    private func sunrise(_ c: inout GraphicsContext, _ r: CGRect) {
        sky(&c, r, [0xFFE3A3, 0xFF9E7A, 0xE8628E])
        disc(&c, r, x: 0.5, y: 0.58, radius: 0.17, color: 0xFFF8E0)
        // Дорожка от солнца по воде.
        for row in 0..<4 {
            let y = 0.68 + CGFloat(row) * 0.08
            let width = 0.34 - CGFloat(row) * 0.05
            let line = CGRect(x: r.minX + r.width * (0.5 - width / 2),
                              y: r.minY + r.height * y,
                              width: r.width * width, height: r.height * 0.035)
            c.fill(Path(roundedRect: line, cornerRadius: r.height * 0.02),
                   with: .color(Color(hex: 0xFFF1C9).opacity(0.75 - Double(row) * 0.15)))
        }
        wave(&c, r, y: 0.66, amplitude: 0.02, color: 0xB1486F)
    }

    private func canyon(_ c: inout GraphicsContext, _ r: CGRect) {
        sky(&c, r, [0xFFC27A, 0xE07A4B, 0x8E3B2F])
        disc(&c, r, x: 0.5, y: 0.32, radius: 0.1, color: 0xFFEFC8)
        // Два обрыва навстречу друг другу, между ними река.
        var left = Path()
        left.move(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.46))
        left.addLine(to: CGPoint(x: r.minX + r.width * 0.42, y: r.minY + r.height * 0.62))
        left.addLine(to: CGPoint(x: r.minX + r.width * 0.36, y: r.maxY))
        left.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        left.closeSubpath()
        c.fill(left, with: .color(Color(hex: 0x8C3A2A)))

        var right = Path()
        right.move(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.5))
        right.addLine(to: CGPoint(x: r.minX + r.width * 0.58, y: r.minY + r.height * 0.66))
        right.addLine(to: CGPoint(x: r.minX + r.width * 0.64, y: r.maxY))
        right.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        right.closeSubpath()
        c.fill(right, with: .color(Color(hex: 0x6E2B22)))

        let river = CGRect(x: r.minX + r.width * 0.42, y: r.minY + r.height * 0.66,
                           width: r.width * 0.16, height: r.height * 0.34)
        c.fill(Path(river), with: .color(Color(hex: 0x2F7E8C)))
    }

    /// Айсберг. Был ещё одной грядой синих гор и путался со «снежными
    /// вершинами» — а белая глыба на тёмной воде не похожа ни на что.
    private func northernSea(_ c: inout GraphicsContext, _ r: CGRect) {
        sky(&c, r, [0xCDE7F5, 0x79B4D6, 0x2B6A96])
        stars(&c, r, count: 6, seed: 11)

        var berg = Path()
        berg.move(to: CGPoint(x: r.minX + r.width * 0.5, y: r.minY + r.height * 0.3))
        berg.addLine(to: CGPoint(x: r.minX + r.width * 0.72, y: r.minY + r.height * 0.66))
        berg.addLine(to: CGPoint(x: r.minX + r.width * 0.26, y: r.minY + r.height * 0.66))
        berg.closeSubpath()
        c.fill(berg, with: .linearGradient(
            Gradient(colors: [Color(hex: 0xFFFFFF), Color(hex: 0xBBD9EC)]),
            startPoint: CGPoint(x: r.midX, y: r.minY + r.height * 0.3),
            endPoint: CGPoint(x: r.midX, y: r.minY + r.height * 0.66)))

        // Подводная часть — тенью под водой, как это и бывает.
        var under = Path()
        under.move(to: CGPoint(x: r.minX + r.width * 0.22, y: r.minY + r.height * 0.66))
        under.addLine(to: CGPoint(x: r.minX + r.width * 0.78, y: r.minY + r.height * 0.66))
        under.addLine(to: CGPoint(x: r.minX + r.width * 0.6, y: r.minY + r.height * 0.84))
        under.addLine(to: CGPoint(x: r.minX + r.width * 0.36, y: r.minY + r.height * 0.84))
        under.closeSubpath()

        wave(&c, r, y: 0.66, amplitude: 0.02, color: 0x1C4E73)
        c.fill(under, with: .color(Color(hex: 0x3D82A8).opacity(0.55)))
        wave(&c, r, y: 0.88, amplitude: 0.04, color: 0x10324C)
    }

    // MARK: - Кирпичики

    private func sky(_ c: inout GraphicsContext, _ r: CGRect, _ colors: [UInt32]) {
        c.fill(Path(r), with: .linearGradient(
            Gradient(colors: colors.map { Color(hex: $0) }),
            startPoint: CGPoint(x: r.midX, y: r.minY),
            endPoint: CGPoint(x: r.midX, y: r.maxY)))
    }

    private func disc(_ c: inout GraphicsContext, _ r: CGRect,
                      x: CGFloat, y: CGFloat, radius: CGFloat, color: UInt32) {
        let size = r.width * radius * 2
        let frame = CGRect(x: r.minX + r.width * x - size / 2,
                           y: r.minY + r.height * y - size / 2,
                           width: size, height: size)
        c.fill(Path(ellipseIn: frame), with: .color(Color(hex: color)))
    }

    /// Горный хребет: ломаная по вершинам, залитая до низа круга.
    private func ridge(_ c: inout GraphicsContext, _ r: CGRect, base: CGFloat,
                       peaks: [(CGFloat, CGFloat)], color: UInt32) {
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.minY + r.height * base))
        for (x, y) in peaks {
            path.addLine(to: CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y))
        }
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * base))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        path.closeSubpath()
        c.fill(path, with: .color(Color(hex: color)))
    }

    private func cap(_ c: inout GraphicsContext, _ r: CGRect,
                     peak: (CGFloat, CGFloat), width: CGFloat) {
        var path = Path()
        let apex = CGPoint(x: r.minX + r.width * peak.0, y: r.minY + r.height * peak.1)
        path.move(to: apex)
        path.addLine(to: CGPoint(x: apex.x - r.width * width / 2,
                                 y: apex.y + r.height * width * 0.75))
        path.addLine(to: CGPoint(x: apex.x + r.width * width / 2,
                                 y: apex.y + r.height * width * 0.75))
        path.closeSubpath()
        c.fill(path, with: .color(.white.opacity(0.92)))
    }

    private func wave(_ c: inout GraphicsContext, _ r: CGRect,
                      y: CGFloat, amplitude: CGFloat, color: UInt32) {
        var path = Path()
        let level = r.minY + r.height * y
        path.move(to: CGPoint(x: r.minX, y: level))
        path.addQuadCurve(to: CGPoint(x: r.midX, y: level),
                          control: CGPoint(x: r.minX + r.width * 0.25,
                                           y: level - r.height * amplitude))
        path.addQuadCurve(to: CGPoint(x: r.maxX, y: level),
                          control: CGPoint(x: r.minX + r.width * 0.75,
                                           y: level + r.height * amplitude))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        path.closeSubpath()
        c.fill(path, with: .color(Color(hex: color)))
    }

    private func dune(_ c: inout GraphicsContext, _ r: CGRect,
                      y: CGFloat, bulge: CGFloat, color: UInt32) {
        var path = Path()
        let level = r.minY + r.height * y
        path.move(to: CGPoint(x: r.minX, y: level))
        path.addQuadCurve(to: CGPoint(x: r.maxX, y: level + r.height * bulge * 0.3),
                          control: CGPoint(x: r.midX, y: level - r.height * bulge))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        path.closeSubpath()
        c.fill(path, with: .color(Color(hex: color)))
    }

    private func firs(_ c: inout GraphicsContext, _ r: CGRect, base: CGFloat,
                      tops: [CGFloat], color: UInt32, offset: CGFloat = 0) {
        let step = 1.0 / CGFloat(tops.count)
        for (index, top) in tops.enumerated() {
            let centre = step * (CGFloat(index) + 0.5) + offset
            var path = Path()
            path.move(to: CGPoint(x: r.minX + r.width * centre, y: r.minY + r.height * top))
            path.addLine(to: CGPoint(x: r.minX + r.width * (centre - step * 0.6),
                                     y: r.minY + r.height * base))
            path.addLine(to: CGPoint(x: r.minX + r.width * (centre + step * 0.6),
                                     y: r.minY + r.height * base))
            path.closeSubpath()
            c.fill(path, with: .color(Color(hex: color)))
        }
        c.fill(Path(CGRect(x: r.minX, y: r.minY + r.height * base,
                           width: r.width, height: r.height * (1 - base))),
               with: .color(Color(hex: color)))
    }

    /// Звёзды по псевдослучайным, но всегда одинаковым местам: аватарка
    /// не должна меняться между запусками.
    private func stars(_ c: inout GraphicsContext, _ r: CGRect, count: Int, seed: UInt64) {
        var value = seed &* 6364136223846793005 &+ 1442695040888963407
        for _ in 0..<count {
            value = value &* 6364136223846793005 &+ 1442695040888963407
            let x = CGFloat((value >> 16) % 1000) / 1000
            value = value &* 6364136223846793005 &+ 1442695040888963407
            let y = CGFloat((value >> 16) % 600) / 1000
            let size = r.width * (CGFloat((value >> 8) % 12) / 1000 + 0.012)
            let frame = CGRect(x: r.minX + r.width * x - size / 2,
                               y: r.minY + r.height * y - size / 2,
                               width: size, height: size)
            c.fill(Path(ellipseIn: frame), with: .color(.white.opacity(0.85)))
        }
    }

    private func ribbon(_ c: inout GraphicsContext, _ r: CGRect,
                        y: CGFloat, color: UInt32, opacity: Double) {
        var path = Path()
        let level = r.minY + r.height * y
        path.move(to: CGPoint(x: r.minX, y: level))
        path.addCurve(to: CGPoint(x: r.maxX, y: level - r.height * 0.06),
                      control1: CGPoint(x: r.minX + r.width * 0.3, y: level - r.height * 0.18),
                      control2: CGPoint(x: r.minX + r.width * 0.6, y: level + r.height * 0.1))
        path.addLine(to: CGPoint(x: r.maxX, y: level + r.height * 0.1))
        path.addCurve(to: CGPoint(x: r.minX, y: level + r.height * 0.16),
                      control1: CGPoint(x: r.minX + r.width * 0.6, y: level + r.height * 0.26),
                      control2: CGPoint(x: r.minX + r.width * 0.3, y: level - r.height * 0.02))
        path.closeSubpath()
        c.fill(path, with: .linearGradient(
            Gradient(colors: [Color(hex: color).opacity(opacity), .clear]),
            startPoint: CGPoint(x: r.midX, y: level - r.height * 0.1),
            endPoint: CGPoint(x: r.midX, y: level + r.height * 0.2)))
    }
}
