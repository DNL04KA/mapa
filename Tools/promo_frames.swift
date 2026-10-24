// Кадры рекламного ролика.
//
// Каждый кадр рисуется здесь целиком: фон, телефон, экран внутри него,
// подписи. Движение считается от времени, а не собирается переходами
// ffmpeg, — только так оно получается плавным и управляемым. Запись с
// экрана симулятора для этого не годится: `simctl io recordVideo` отдаёт
// полтора десятка кадров на сцену и половину из них тратит на загрузку.
//
//     swift Tools/promo_frames.swift <папка-снимков> <папка-кадров>
//
// Дальше кадры склеивает ffmpeg — см. Tools/make_promo.sh.

import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

let W = 1080.0, H = 1920.0
let fps = 60.0

// MARK: - Сценарий

/// Сцена ролика: экран, подпись и сколько держится.
struct Scene {
    let shot: String
    let title: String
    let subtitle: String
    let seconds: Double
    /// Дополнительные снимки — для монтажа полотен внутри одной сцены.
    var montage: [String] = []
}

let scenes: [Scene] = [
    Scene(shot: "map", title: "Твой мир — в процентах",
          subtitle: "Страны закрашиваются цветом своего флага", seconds: 4.6),
    Scene(shot: "marks", title: "Отметь, где был",
          subtitle: "Списком за минуту, а не охотой по глобусу", seconds: 4.2),
    Scene(shot: "country", title: "Что смотреть в стране",
          subtitle: "Места, маршрут по городам, дни и бюджет", seconds: 4.6),
    Scene(shot: "routes", title: "Маршруты",
          subtitle: "Свои и готовые наброски по странам", seconds: 4.0),
    Scene(shot: "community", title: "Лучшие маршруты",
          subtitle: "По оценкам тех, кто уже съездил", seconds: 4.2),
    Scene(shot: "map", title: "Своё оформление",
          subtitle: "Пятнадцать полотен и восемь палитр",
          seconds: 4.4, montage: ["surface-ink", "surface-paper", "map"]),
    Scene(shot: "share", title: "Карточка для сторис",
          subtitle: "Картинкой или видео, одним касанием", seconds: 4.2),
]

let introSeconds = 2.8
let outroSeconds = 3.4
let total = introSeconds + scenes.reduce(0) { $0 + $1.seconds } + outroSeconds

// MARK: - Основа

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write(Data("нужны папка снимков и папка кадров\n".utf8))
    exit(2)
}
let shotsDir = URL(fileURLWithPath: args[1])
let framesDir = URL(fileURLWithPath: args[2])
try? FileManager.default.createDirectory(at: framesDir, withIntermediateDirectories: true)

let space = CGColorSpaceCreateDeviceRGB()

func rgb(_ hex: UInt32, _ a: Double = 1) -> CGColor {
    CGColor(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255, alpha: a)
}

let void = 0x06070C as UInt32, abyss = 0x0B0D15 as UInt32
let indigo = 0x6C5CFF as UInt32, indigoSoft = 0x9B8CFF as UInt32

var cache: [String: CGImage] = [:]
func shot(_ name: String) -> CGImage? {
    if let c = cache[name] { return c }
    let url = shotsDir.appendingPathComponent(name + ".png")
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
    cache[name] = img
    return img
}

// MARK: - Плавности

/// Разгон и торможение. Линейное движение в ролике читается как рывок.
func easeInOut(_ t: Double) -> Double {
    t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
}
func easeOut(_ t: Double) -> Double { 1 - pow(1 - t, 3) }
/// Лёгкий отскок в конце — телефон «садится» на место, а не примерзает.
func easeOutBack(_ t: Double) -> Double {
    let c1 = 1.70158, c3 = c1 + 1
    return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)
}
func clamp(_ v: Double, _ lo: Double = 0, _ hi: Double = 1) -> Double { min(max(v, lo), hi) }
func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

// MARK: - Рисование

func font(_ size: Double, _ weight: CGFloat) -> CTFont {
    let base = CTFontCreateUIFontForLanguage(.system, size, nil)
        ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
    let d = CTFontDescriptorCreateCopyWithAttributes(CTFontCopyFontDescriptor(base), [
        kCTFontTraitsAttribute: [kCTFontWeightTrait: weight],
    ] as CFDictionary)
    return CTFontCreateWithFontDescriptor(d, size, nil)
}
enum Wt {
    static let regular: CGFloat = 0, medium: CGFloat = 0.23
    static let semibold: CGFloat = 0.3, bold: CGFloat = 0.4, heavy: CGFloat = 0.56
}

func text(_ ctx: CGContext, _ s: String, _ f: CTFont, _ color: CGColor,
          centerX: Double, baselineY: Double, tracking: Double = 0, alpha: Double = 1) {
    guard alpha > 0.003, !s.isEmpty else { return }
    let attrs: [CFString: Any] = [
        kCTFontAttributeName: f,
        kCTForegroundColorAttributeName: color.copy(alpha: color.alpha * alpha) ?? color,
        kCTKernAttributeName: tracking,
    ]
    let line = CTLineCreateWithAttributedString(
        CFAttributedStringCreate(nil, s as CFString, attrs as CFDictionary))
    let b = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
    ctx.textPosition = CGPoint(x: centerX - b.width / 2 - b.minX, y: baselineY)
    CTLineDraw(line, ctx)
}

func glow(_ ctx: CGContext, at p: CGPoint, radius: Double, color: UInt32, alpha: Double) {
    guard alpha > 0.002 else { return }
    let g = CGGradient(colorsSpace: space, colors: [rgb(color, alpha), rgb(color, 0)] as CFArray,
                       locations: [0, 1])!
    ctx.drawRadialGradient(g, startCenter: p, startRadius: 0, endCenter: p,
                           endRadius: radius, options: [])
}

/// Фон: градиент и три пятна света, которые медленно дышат.
///
/// Дыхание — не украшение: на неподвижном фоне любой наезд на телефон
/// выглядит дёрганым, потому что глазу не за что зацепиться.
func background(_ ctx: CGContext, t: Double) {
    let g = CGGradient(colorsSpace: space, colors: [rgb(abyss), rgb(void)] as CFArray,
                       locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])
    let drift = sin(t * 0.22)
    let drift2 = cos(t * 0.17)
    glow(ctx, at: CGPoint(x: 210 + drift * 60, y: H - 300 + drift2 * 50),
         radius: 640, color: indigo, alpha: 0.30)
    glow(ctx, at: CGPoint(x: W - 160 - drift2 * 50, y: 430 + drift * 60),
         radius: 580, color: 0x2E7FB8, alpha: 0.22)
    glow(ctx, at: CGPoint(x: W / 2, y: H / 2 + drift * 90),
         radius: 720, color: indigoSoft, alpha: 0.07)
}

let screenBase = CGRect(x: 217, y: 352, width: 646, height: 1400)

/// Телефон: корпус, тень, кромка и экран внутри.
///
/// `lift` — насколько он поднят снизу, `scale` — наезд камеры.
func device(_ ctx: CGContext, lift: Double, scale: Double, alpha: Double,
            draw screen: (CGContext, CGRect) -> Void) {
    guard alpha > 0.003 else { return }
    let r = screenBase
    let cx = r.midX, cy = r.midY
    ctx.saveGState()
    ctx.setAlpha(alpha)
    ctx.translateBy(x: cx, y: cy - lift)
    ctx.scaleBy(x: scale, y: scale)
    ctx.translateBy(x: -cx, y: -cy)

    let body = r.insetBy(dx: -14, dy: -14)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -26), blur: 70, color: rgb(0, 0.75))
    ctx.setFillColor(rgb(0x11131C))
    ctx.addPath(CGPath(roundedRect: body, cornerWidth: 62, cornerHeight: 62, transform: nil))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: 50, cornerHeight: 50, transform: nil))
    ctx.clip()
    screen(ctx, r)
    ctx.restoreGState()

    ctx.setStrokeColor(rgb(0xFFFFFF, 0.16))
    ctx.setLineWidth(1.5)
    ctx.addPath(CGPath(roundedRect: body, cornerWidth: 62, cornerHeight: 62, transform: nil))
    ctx.strokePath()
    ctx.restoreGState()
}

/// Снимок внутри экрана с медленным наездом.
func fill(_ ctx: CGContext, _ rect: CGRect, _ image: CGImage, push: Double, alpha: Double) {
    guard alpha > 0.003 else { return }
    let k = 1 + push * 0.05
    let w = rect.width * k, h = rect.height * k
    ctx.saveGState()
    ctx.setAlpha(alpha)
    ctx.draw(image, in: CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h))
    ctx.restoreGState()
}

// MARK: - Кадр

func render(at t: Double) -> CGImage? {
    guard let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8,
                              bytesPerRow: 0, space: space,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high
    background(ctx, t: t)

    // --- Заставка
    if t < introSeconds {
        let p = clamp(t / 1.1)
        let e = easeOut(p)
        let out = clamp((t - (introSeconds - 0.5)) / 0.5)
        let a = (1 - easeInOut(out))
        // Имя наезжает из крупного в своё, одновременно проявляясь.
        let size = mix(230, 186, e)
        text(ctx, "MAPA", font(size, Wt.heavy), rgb(0xFFFFFF),
             centerX: W / 2, baselineY: H / 2 + 20, tracking: mix(28, 8, e), alpha: e * a)
        let sp = clamp((t - 0.45) / 0.8)
        text(ctx, "КАРТА ТВОИХ ПУТЕШЕСТВИЙ", font(34, Wt.semibold), rgb(indigoSoft, 0.95),
             centerX: W / 2, baselineY: H / 2 - 80 - mix(26, 0, easeOut(sp)),
             tracking: 7, alpha: easeOut(sp) * a)
        return ctx.makeImage()
    }

    // --- Какая сцена идёт
    var start = introSeconds
    var index = 0
    for (i, s) in scenes.enumerated() {
        if t < start + s.seconds { index = i; break }
        start += s.seconds
        index = i
    }
    let afterScenes = introSeconds + scenes.reduce(0) { $0 + $1.seconds }
    let isOutro = t >= afterScenes

    // --- Телефон
    // Поднимается снизу один раз в начале и уезжает в конце; между
    // сценами он стоит, а меняется только то, что внутри.
    let rise = clamp((t - introSeconds) / 0.9)
    var lift = mix(-980, 0, easeOutBack(rise))
    var deviceAlpha = easeOut(clamp((t - introSeconds) / 0.5))
    if isOutro {
        let o = clamp((t - afterScenes) / 0.8)
        lift = mix(0, -900, easeInOut(o))
        deviceAlpha = 1 - easeInOut(clamp((t - afterScenes) / 0.7))
    }

    let scene = scenes[index]
    let local = t - start
    let push = clamp(local / scene.seconds)

    device(ctx, lift: lift, scale: mix(1.0, 1.012, push), alpha: deviceAlpha) { c, rect in
        // Монтаж полотен внутри одной сцены — быстрые смены материала.
        if !scene.montage.isEmpty {
            let steps = scene.montage.count
            let per = scene.seconds / Double(steps)
            let i = min(Int(local / per), steps - 1)
            let within = (local - Double(i) * per) / per
            if let img = shot(scene.montage[i]) {
                fill(c, rect, img, push: within, alpha: 1)
            }
            // Подмешиваем следующий материал к концу шага.
            if i + 1 < steps, within > 0.78, let next = shot(scene.montage[i + 1]) {
                fill(c, rect, next, push: 0, alpha: easeInOut((within - 0.78) / 0.22))
            }
            return
        }
        if let img = shot(scene.shot) { fill(c, rect, img, push: push, alpha: 1) }
        // Следующий экран проявляется прямо внутри телефона — переход
        // между сценами происходит в экране, а не в монтаже.
        let tail = scene.seconds - local
        if tail < 0.55, index + 1 < scenes.count {
            let nextScene = scenes[index + 1]
            let nextName = nextScene.montage.first ?? nextScene.shot
            if let img = shot(nextName) {
                fill(c, rect, img, push: 0, alpha: easeInOut(clamp((0.55 - tail) / 0.55)))
            }
        }
    }

    // --- Подпись
    if !isOutro {
        let appear = easeOut(clamp((local - 0.18) / 0.5))
        let leave = 1 - easeInOut(clamp((local - (scene.seconds - 0.4)) / 0.4))
        let a = appear * leave * deviceAlpha
        let rise = mix(22, 0, appear)
        text(ctx, scene.title, font(62, Wt.bold), rgb(0xFFFFFF),
             centerX: W / 2, baselineY: 212 - rise, alpha: a)
        let sub = easeOut(clamp((local - 0.3) / 0.5))
        text(ctx, scene.subtitle, font(33, Wt.regular), rgb(0xFFFFFF, 0.62),
             centerX: W / 2, baselineY: 148 - mix(18, 0, sub), alpha: sub * leave * deviceAlpha)
    }

    // --- Финал
    if isOutro {
        let o = t - afterScenes
        let p = easeOut(clamp((o - 0.35) / 0.8))
        text(ctx, "MAPA", font(150, Wt.heavy), rgb(0xFFFFFF),
             centerX: W / 2, baselineY: H / 2 + 40 - mix(18, 0, p), tracking: 6, alpha: p)
        let p2 = easeOut(clamp((o - 0.7) / 0.8))
        text(ctx, "201 страна · 899 городов", font(40, Wt.medium), rgb(0xFFFFFF, 0.75),
             centerX: W / 2, baselineY: H / 2 - 55, alpha: p2)
        let p3 = easeOut(clamp((o - 1.0) / 0.8))
        text(ctx, "Карта рисуется сама — без MapKit и тайлов",
             font(30, Wt.regular), rgb(0xFFFFFF, 0.45), centerX: W / 2,
             baselineY: H / 2 - 125, alpha: p3)
        text(ctx, "iPhone · iOS 16", font(30, Wt.semibold), rgb(indigoSoft),
             centerX: W / 2, baselineY: 230, tracking: 4, alpha: p3)
    }

    return ctx.makeImage()
}

// MARK: - Запись

let count = Int(total * fps)
print("кадров: \(count)  (\(String(format: "%.1f", total)) с)")

let options = [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary
for i in 0..<count {
    guard let image = render(at: Double(i) / fps) else { continue }
    let url = framesDir.appendingPathComponent(String(format: "f%05d.jpg", i))
    guard let dest = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { continue }
    CGImageDestinationAddImage(dest, image, options)
    CGImageDestinationFinalize(dest)
    if i % 120 == 0 { print("  \(i)/\(count)") }
}
print("готово")
