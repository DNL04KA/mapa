import SwiftUI

/// Аватарка-зверь.
///
/// Пейзаж в кружке сорока восьми точек читается цветным пятном: мелкие
/// детали пропадают, и все картинки становятся похожи. Морда — нет. Глаза
/// и уши работают на любом размере, и своего зверя человек узнаёт в списке
/// мгновенно, как узнают знакомое лицо в толпе.
///
/// Десять зверей, у каждого своя мелочь из дороги: лиса в очках, пингвин в
/// шарфе, медведь в кепке. Рисуются кодом по той же причине, что иконка
/// приложения: один набор на все размеры и ни одного файла, который
/// разойдётся с палитрой.
struct AvatarFace: View {

    let index: Int
    var size: CGFloat = 64

    static let count = 10

    private var face: Int { ((index % Self.count) + Self.count) % Self.count }

    var body: some View {
        Canvas { context, bounds in
            let rect = CGRect(origin: .zero, size: bounds)
            context.clip(to: Path(ellipseIn: rect))
            draw(face, &context, rect)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(.white.opacity(0.16), lineWidth: max(1, size * 0.02))
        }
        .accessibilityHidden(true)
    }

    private func draw(_ face: Int, _ c: inout GraphicsContext, _ r: CGRect) {
        switch face {
        case 0: fox(&c, r)
        case 1: bear(&c, r)
        case 2: cat(&c, r)
        case 3: penguin(&c, r)
        case 4: panda(&c, r)
        case 5: owl(&c, r)
        case 6: whale(&c, r)
        case 7: hare(&c, r)
        case 8: raccoon(&c, r)
        default: frog(&c, r)
        }
    }

    // MARK: - Звери

    private func fox(_ c: inout GraphicsContext, _ r: CGRect) {
        // Фон холоднее самой лисы: на тёплом её уши пропадали.
        background(&c, r, [0xFFE3C4, 0xE8A06A])
        ear(&c, r, x: 0.26, colour: 0xC2451B, inner: 0xFFD2B5)
        ear(&c, r, x: 0.74, colour: 0xC2451B, inner: 0xFFD2B5)
        head(&c, r, colour: 0xF2762E)
        // Белая маска от носа к щекам — главное, по чему узнают лису.
        ellipse(&c, r, x: 0.5, y: 0.72, w: 0.5, h: 0.34, colour: 0xFFF1E0)
        eyes(&c, r, y: 0.56, spread: 0.16, radius: 0.052)
        muzzle(&c, r, y: 0.7, colour: 0x2A1A14)
    }

    private func bear(_ c: inout GraphicsContext, _ r: CGRect) {
        background(&c, r, [0xD9BFA3, 0xA37B55])
        roundEar(&c, r, x: 0.24, y: 0.3, radius: 0.13, colour: 0x8A6240, inner: 0xC79B74)
        roundEar(&c, r, x: 0.76, y: 0.3, radius: 0.13, colour: 0x8A6240, inner: 0xC79B74)
        head(&c, r, colour: 0xA3744C)
        // Кепка: он собрался в дорогу, а не просто позирует.
        cap(&c, r, colour: 0x2E7D74, peak: 0x1F5B55)
        ellipse(&c, r, x: 0.5, y: 0.74, w: 0.44, h: 0.3, colour: 0xE8D2B8)
        eyes(&c, r, y: 0.6, spread: 0.15, radius: 0.05)
        muzzle(&c, r, y: 0.72, colour: 0x3A2418)
    }

    private func cat(_ c: inout GraphicsContext, _ r: CGRect) {
        background(&c, r, [0xC9D6E8, 0x8295AD])
        ear(&c, r, x: 0.27, colour: 0x6F7C91, inner: 0xE2A9B8)
        ear(&c, r, x: 0.73, colour: 0x6F7C91, inner: 0xE2A9B8)
        head(&c, r, colour: 0x8294AC)
        eyes(&c, r, y: 0.58, spread: 0.16, radius: 0.055, colour: 0x2BE0A8)
        muzzle(&c, r, y: 0.72, colour: 0xE2A9B8)
        whiskers(&c, r, y: 0.74)
    }

    private func penguin(_ c: inout GraphicsContext, _ r: CGRect) {
        background(&c, r, [0xBFE4F5, 0x6AA8CC])
        head(&c, r, colour: 0x1E2733)
        // Белая манишка.
        ellipse(&c, r, x: 0.5, y: 0.78, w: 0.56, h: 0.46, colour: 0xF5F7FA)
        eyes(&c, r, y: 0.56, spread: 0.14, radius: 0.05, colour: 0xFFFFFF, pupil: 0x1E2733)
        triangle(&c, r, x: 0.5, y: 0.7, w: 0.14, h: 0.12, colour: 0xF2A33C)
        scarf(&c, r, colour: 0xE2485F)
    }

    private func panda(_ c: inout GraphicsContext, _ r: CGRect) {
        background(&c, r, [0xE8EDF2, 0xA8B6C4])
        roundEar(&c, r, x: 0.24, y: 0.28, radius: 0.13, colour: 0x1E2733, inner: 0x1E2733)
        roundEar(&c, r, x: 0.76, y: 0.28, radius: 0.13, colour: 0x1E2733, inner: 0x1E2733)
        head(&c, r, colour: 0xF7F9FB)
        // Чёрные пятна вокруг глаз, чуть наклонённые внутрь.
        ellipse(&c, r, x: 0.36, y: 0.56, w: 0.22, h: 0.26, colour: 0x1E2733)
        ellipse(&c, r, x: 0.64, y: 0.56, w: 0.22, h: 0.26, colour: 0x1E2733)
        dot(&c, r, x: 0.37, y: 0.56, radius: 0.045, colour: 0xFFFFFF)
        dot(&c, r, x: 0.63, y: 0.56, radius: 0.045, colour: 0xFFFFFF)
        muzzle(&c, r, y: 0.72, colour: 0x1E2733)
    }

    private func owl(_ c: inout GraphicsContext, _ r: CGRect) {
        background(&c, r, [0xC9B8E8, 0x7A5BA8])
        triangle(&c, r, x: 0.3, y: 0.26, w: 0.2, h: 0.16, colour: 0x6B4E96)
        triangle(&c, r, x: 0.7, y: 0.26, w: 0.2, h: 0.16, colour: 0x6B4E96)
        head(&c, r, colour: 0x7F5FAE)
        // Огромные глаза в светлых кругах — сова узнаётся по ним.
        dot(&c, r, x: 0.36, y: 0.56, radius: 0.15, colour: 0xF5EDFF)
        dot(&c, r, x: 0.64, y: 0.56, radius: 0.15, colour: 0xF5EDFF)
        dot(&c, r, x: 0.36, y: 0.56, radius: 0.075, colour: 0x2A1E3D)
        dot(&c, r, x: 0.64, y: 0.56, radius: 0.075, colour: 0x2A1E3D)
        dot(&c, r, x: 0.385, y: 0.535, radius: 0.025, colour: 0xFFFFFF)
        dot(&c, r, x: 0.665, y: 0.535, radius: 0.025, colour: 0xFFFFFF)
        triangle(&c, r, x: 0.5, y: 0.72, w: 0.1, h: 0.1, colour: 0xF2A33C)
    }

    private func whale(_ c: inout GraphicsContext, _ r: CGRect) {
        background(&c, r, [0x8FD8F0, 0x2E7FB8])
        // Фонтан — две капли над головой.
        dot(&c, r, x: 0.5, y: 0.2, radius: 0.045, colour: 0xF0FAFF)
        dot(&c, r, x: 0.58, y: 0.26, radius: 0.03, colour: 0xF0FAFF)
        ellipse(&c, r, x: 0.5, y: 0.66, w: 0.78, h: 0.58, colour: 0x2A5F96)
        ellipse(&c, r, x: 0.5, y: 0.8, w: 0.56, h: 0.3, colour: 0xE8F4FA)
        eyes(&c, r, y: 0.6, spread: 0.17, radius: 0.045, colour: 0xFFFFFF, pupil: 0x16324F)
        smile(&c, r, y: 0.74, width: 0.3, colour: 0x16324F)
    }

    private func hare(_ c: inout GraphicsContext, _ r: CGRect) {
        background(&c, r, [0xF5E0E8, 0xC79BB0])
        longEar(&c, r, x: 0.37, colour: 0xE8D2DC, inner: 0xE2A9B8)
        longEar(&c, r, x: 0.63, colour: 0xE8D2DC, inner: 0xE2A9B8)
        head(&c, r, colour: 0xEFDCE4)
        eyes(&c, r, y: 0.6, spread: 0.15, radius: 0.05)
        muzzle(&c, r, y: 0.73, colour: 0xD47A96)
        whiskers(&c, r, y: 0.75)
    }

    private func raccoon(_ c: inout GraphicsContext, _ r: CGRect) {
        background(&c, r, [0xCFD8E0, 0x76848F])
        roundEar(&c, r, x: 0.24, y: 0.3, radius: 0.12, colour: 0x5A646E, inner: 0x8A949E)
        roundEar(&c, r, x: 0.76, y: 0.3, radius: 0.12, colour: 0x5A646E, inner: 0x8A949E)
        head(&c, r, colour: 0x8E99A3)
        // Маска поперёк глаз — главный признак енота.
        var mask = Path()
        mask.addRoundedRect(in: CGRect(x: r.minX + r.width * 0.16, y: r.minY + r.height * 0.46,
                                       width: r.width * 0.68, height: r.height * 0.22),
                            cornerSize: CGSize(width: r.width * 0.1, height: r.width * 0.1))
        c.fill(mask, with: .color(Color(hex: 0x2E3740)))
        dot(&c, r, x: 0.36, y: 0.57, radius: 0.045, colour: 0xFFFFFF)
        dot(&c, r, x: 0.64, y: 0.57, radius: 0.045, colour: 0xFFFFFF)
        ellipse(&c, r, x: 0.5, y: 0.76, w: 0.4, h: 0.26, colour: 0xE8EDF2)
        muzzle(&c, r, y: 0.74, colour: 0x2E3740)
    }

    private func frog(_ c: inout GraphicsContext, _ r: CGRect) {
        background(&c, r, [0xCDEFC4, 0x5FA85C])
        // Глаза сверху, как у лягушки, — выпуклые и над головой.
        dot(&c, r, x: 0.33, y: 0.38, radius: 0.15, colour: 0x6EB85F)
        dot(&c, r, x: 0.67, y: 0.38, radius: 0.15, colour: 0x6EB85F)
        head(&c, r, colour: 0x5CA84F)
        dot(&c, r, x: 0.33, y: 0.38, radius: 0.1, colour: 0xFFFFFF)
        dot(&c, r, x: 0.67, y: 0.38, radius: 0.1, colour: 0xFFFFFF)
        dot(&c, r, x: 0.33, y: 0.38, radius: 0.05, colour: 0x1E2733)
        dot(&c, r, x: 0.67, y: 0.38, radius: 0.05, colour: 0x1E2733)
        smile(&c, r, y: 0.7, width: 0.44, colour: 0x24512A)
        dot(&c, r, x: 0.3, y: 0.68, radius: 0.035, colour: 0xE2857F)
        dot(&c, r, x: 0.7, y: 0.68, radius: 0.035, colour: 0xE2857F)
    }

    // MARK: - Детали

    private func background(_ c: inout GraphicsContext, _ r: CGRect, _ colours: [UInt32]) {
        c.fill(Path(r), with: .linearGradient(
            Gradient(colors: colours.map { Color(hex: $0) }),
            startPoint: CGPoint(x: r.minX, y: r.minY),
            endPoint: CGPoint(x: r.maxX, y: r.maxY)))
    }

    /// Голова: круг чуть ниже центра, чтобы сверху осталось место ушам.
    private func head(_ c: inout GraphicsContext, _ r: CGRect, colour: UInt32) {
        ellipse(&c, r, x: 0.5, y: 0.62, w: 0.78, h: 0.74, colour: colour)
    }

    private func ellipse(_ c: inout GraphicsContext, _ r: CGRect,
                         x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, colour: UInt32) {
        let frame = CGRect(x: r.minX + r.width * (x - w / 2),
                           y: r.minY + r.height * (y - h / 2),
                           width: r.width * w, height: r.height * h)
        c.fill(Path(ellipseIn: frame), with: .color(Color(hex: colour)))
    }

    private func dot(_ c: inout GraphicsContext, _ r: CGRect,
                     x: CGFloat, y: CGFloat, radius: CGFloat, colour: UInt32) {
        ellipse(&c, r, x: x, y: y, w: radius * 2, h: radius * 2, colour: colour)
    }

    /// Треугольное ухо с цветной серединой.
    private func ear(_ c: inout GraphicsContext, _ r: CGRect,
                     x: CGFloat, colour: UInt32, inner: UInt32) {
        triangle(&c, r, x: x, y: 0.22, w: 0.26, h: 0.26, colour: colour)
        triangle(&c, r, x: x, y: 0.26, w: 0.13, h: 0.15, colour: inner)
    }

    private func roundEar(_ c: inout GraphicsContext, _ r: CGRect,
                          x: CGFloat, y: CGFloat, radius: CGFloat,
                          colour: UInt32, inner: UInt32) {
        dot(&c, r, x: x, y: y, radius: radius, colour: colour)
        dot(&c, r, x: x, y: y, radius: radius * 0.55, colour: inner)
    }

    private func longEar(_ c: inout GraphicsContext, _ r: CGRect,
                         x: CGFloat, colour: UInt32, inner: UInt32) {
        ellipse(&c, r, x: x, y: 0.2, w: 0.16, h: 0.4, colour: colour)
        ellipse(&c, r, x: x, y: 0.22, w: 0.08, h: 0.28, colour: inner)
    }

    private func triangle(_ c: inout GraphicsContext, _ r: CGRect,
                          x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, colour: UInt32) {
        var path = Path()
        path.move(to: CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * (y - h / 2)))
        path.addLine(to: CGPoint(x: r.minX + r.width * (x - w / 2),
                                 y: r.minY + r.height * (y + h / 2)))
        path.addLine(to: CGPoint(x: r.minX + r.width * (x + w / 2),
                                 y: r.minY + r.height * (y + h / 2)))
        path.closeSubpath()
        c.fill(path, with: .color(Color(hex: colour)))
    }

    /// Два глаза с бликом: без блика взгляд получается стеклянным.
    private func eyes(_ c: inout GraphicsContext, _ r: CGRect, y: CGFloat, spread: CGFloat,
                      radius: CGFloat, colour: UInt32 = 0x1E2733, pupil: UInt32? = nil) {
        for x in [0.5 - spread, 0.5 + spread] {
            dot(&c, r, x: x, y: y, radius: radius, colour: colour)
            if let pupil {
                dot(&c, r, x: x, y: y, radius: radius * 0.55, colour: pupil)
            }
            dot(&c, r, x: x + radius * 0.3, y: y - radius * 0.35,
                radius: radius * 0.28, colour: 0xFFFFFF)
        }
    }

    private func muzzle(_ c: inout GraphicsContext, _ r: CGRect, y: CGFloat, colour: UInt32) {
        ellipse(&c, r, x: 0.5, y: y, w: 0.13, h: 0.09, colour: colour)
        smile(&c, r, y: y + 0.07, width: 0.2, colour: colour)
    }

    private func smile(_ c: inout GraphicsContext, _ r: CGRect,
                       y: CGFloat, width: CGFloat, colour: UInt32) {
        var path = Path()
        path.move(to: CGPoint(x: r.minX + r.width * (0.5 - width / 2), y: r.minY + r.height * y))
        path.addQuadCurve(
            to: CGPoint(x: r.minX + r.width * (0.5 + width / 2), y: r.minY + r.height * y),
            control: CGPoint(x: r.midX, y: r.minY + r.height * (y + 0.07)))
        c.stroke(path, with: .color(Color(hex: colour)),
                 style: StrokeStyle(lineWidth: r.width * 0.025, lineCap: .round))
    }

    private func whiskers(_ c: inout GraphicsContext, _ r: CGRect, y: CGFloat) {
        var path = Path()
        for side in [-1.0, 1.0] as [CGFloat] {
            for offset in [-0.03, 0.03] as [CGFloat] {
                path.move(to: CGPoint(x: r.minX + r.width * (0.5 + side * 0.09),
                                      y: r.minY + r.height * (y + offset)))
                path.addLine(to: CGPoint(x: r.minX + r.width * (0.5 + side * 0.28),
                                         y: r.minY + r.height * (y + offset * 2)))
            }
        }
        c.stroke(path, with: .color(.white.opacity(0.8)),
                 style: StrokeStyle(lineWidth: r.width * 0.015, lineCap: .round))
    }

    private func cap(_ c: inout GraphicsContext, _ r: CGRect, colour: UInt32, peak: UInt32) {
        var crown = Path()
        crown.addArc(center: CGPoint(x: r.midX, y: r.minY + r.height * 0.42),
                     radius: r.width * 0.3, startAngle: .degrees(180),
                     endAngle: .degrees(360), clockwise: false)
        crown.closeSubpath()
        c.fill(crown, with: .color(Color(hex: colour)))
        let brim = CGRect(x: r.minX + r.width * 0.52, y: r.minY + r.height * 0.4,
                          width: r.width * 0.34, height: r.height * 0.06)
        c.fill(Path(roundedRect: brim, cornerRadius: r.height * 0.03),
               with: .color(Color(hex: peak)))
    }

    /// Шарф под мордой, а не по нижнему краю кружка: у самого края он
    /// читался полоской, а не одеждой.
    private func scarf(_ c: inout GraphicsContext, _ r: CGRect, colour: UInt32) {
        let band = CGRect(x: r.minX + r.width * 0.18, y: r.minY + r.height * 0.8,
                          width: r.width * 0.64, height: r.height * 0.11)
        c.fill(Path(roundedRect: band, cornerRadius: r.height * 0.05),
               with: .color(Color(hex: colour)))
        let tail = CGRect(x: r.minX + r.width * 0.6, y: r.minY + r.height * 0.84,
                          width: r.width * 0.11, height: r.height * 0.14)
        c.fill(Path(roundedRect: tail, cornerRadius: r.height * 0.04),
               with: .color(Color(hex: colour).opacity(0.88)))
    }
}
