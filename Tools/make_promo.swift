// Кадры ролика о приложении.
//
// Берёт снимки экранов и раскладывает их на вертикальном холсте 1080×1920:
// фон приложения, телефон со скруглёнными углами, подпись сверху. Каждый
// экран держится несколько секунд с медленным наездом и растворяется в
// следующий.
//
// Кадры рисуются кодом, а не собираются в редакторе, по той же причине,
// что и иконка: ролик придётся пересобирать после каждой заметной правки
// интерфейса, и делать это руками значит однажды показать старое
// приложение.
//
//     swift Tools/make_promo.swift <папка-со-снимками> <папка-для-кадров>
//
// Дальше кадры склеивает ffmpeg — см. Tools/make_promo.sh.

import Foundation
import CoreGraphics
import ImageIO
import CoreText
import UniformTypeIdentifiers

let width = 1080.0
let height = 1920.0
let fps = 30.0
let holdSeconds = 2.4      // сколько держится экран
let fadeSeconds = 0.6      // сколько длится растворение в следующий

/// Что показываем и что подписываем. Порядок — это и есть сценарий:
/// сначала зачем это всё, потом карта, потом то, что внутри.
let scenes: [(file: String, title: String, subtitle: String)] = [
    ("1-hello",   "Закрась мир",           "Карта, которую ты заполняешь сам"),
    ("2-map",     "Отмечай страны",        "Был, живу, хочу — 201 страна"),
    ("3-search",  "Найди любое место",     "Страны и 899 городов, на двух языках"),
    ("4-country", "Карточка страны",       "Фотографии мест, маршрут и дни"),
    ("5-city",    "Что посмотреть",        "И в каком порядке обойти"),
    ("6-photo",   "Во весь экран",         "С именем автора и лицензией"),
    ("7-routes",  "Маршруты",              "Свои и наброски по странам"),
    ("8-theme",   "Своё оформление",       "Полотно и палитра — отдельно"),
    ("9-share",   "Поделись картой",       "Картинка и видео для сторис"),
]

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write(Data("нужны папка снимков и папка кадров\n".utf8))
    exit(2)
}
let shots = URL(fileURLWithPath: args[1])
let out = URL(fileURLWithPath: args[2])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

let space = CGColorSpaceCreateDeviceRGB()

func rgb(_ hex: UInt32, _ alpha: Double = 1) -> CGColor {
    CGColor(red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            alpha: alpha)
}

func load(_ name: String) -> CGImage? {
    let url = shots.appendingPathComponent(name + ".png")
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

func text(_ ctx: CGContext, _ string: String, size: Double, weight: CGFloat,
          color: CGColor, center: CGPoint, tracking: Double = 0) {
    let font = CTFontCreateWithFontDescriptor(
        CTFontDescriptorCreateWithAttributes([
            kCTFontFamilyNameAttribute: "SF Pro Display",
            kCTFontTraitsAttribute: [kCTFontWeightTrait: weight]
        ] as CFDictionary), size, nil)
    let attrs: [CFString: Any] = [
        kCTFontAttributeName: font,
        kCTForegroundColorAttributeName: color,
        kCTKernAttributeName: tracking
    ]
    let line = CTLineCreateWithAttributedString(
        CFAttributedStringCreate(nil, string as CFString, attrs as CFDictionary))
    let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
    ctx.textPosition = CGPoint(x: center.x - bounds.width / 2 - bounds.minX,
                               y: center.y - bounds.height / 2 - bounds.minY)
    CTLineDraw(line, ctx)
}

/// Телефон: снимок со скруглёнными углами, тонкой рамкой и тенью.
func drawPhone(_ ctx: CGContext, image: CGImage, scale: Double, alpha: Double) {
    let targetHeight = 1480.0 * scale
    let targetWidth = targetHeight * Double(image.width) / Double(image.height)
    let rect = CGRect(x: (width - targetWidth) / 2,
                      y: 140 + (1480 - targetHeight) / 2,
                      width: targetWidth, height: targetHeight)
    let radius = 52.0 * scale

    ctx.saveGState()
    ctx.setAlpha(alpha)
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 60,
                  color: rgb(0x000000, 0.55))
    ctx.setFillColor(rgb(0x0B0D15))
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius,
                       transform: nil))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.setAlpha(alpha)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius,
                       transform: nil))
    ctx.clip()
    ctx.draw(image, in: rect)
    ctx.restoreGState()

    ctx.saveGState()
    ctx.setAlpha(alpha)
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.10))
    ctx.setLineWidth(2)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius,
                       transform: nil))
    ctx.strokePath()
    ctx.restoreGState()
}

func drawCaption(_ ctx: CGContext, title: String, subtitle: String, alpha: Double) {
    ctx.saveGState()
    ctx.setAlpha(alpha)
    text(ctx, title, size: 64, weight: .init(0.62), color: rgb(0xFFFFFF),
         center: CGPoint(x: width / 2, y: height - 150))
    text(ctx, subtitle, size: 34, weight: .init(0.2), color: rgb(0xA7ADC4),
         center: CGPoint(x: width / 2, y: height - 220))
    ctx.restoreGState()
}

func background(_ ctx: CGContext) {
    ctx.setFillColor(rgb(0x06070C))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    if let gradient = CGGradient(colorsSpace: space,
                                 colors: [rgb(0x241B6B), rgb(0x06070C)] as CFArray,
                                 locations: [0, 1]) {
        ctx.drawRadialGradient(gradient,
                               startCenter: CGPoint(x: width / 2, y: height * 0.78),
                               startRadius: 0,
                               endCenter: CGPoint(x: width / 2, y: height * 0.78),
                               endRadius: width * 1.1,
                               options: [])
    }
    // Подпись приложения внизу — тихо, разрядкой.
    text(ctx, "MAPA", size: 30, weight: .init(0.5), color: rgb(0xFFFFFF, 0.35),
         center: CGPoint(x: width / 2, y: 68), tracking: 10)
}

// MARK: - Сборка

var frameIndex = 0

func write(_ ctx: CGContext) {
    guard let image = ctx.makeImage() else { return }
    let url = out.appendingPathComponent(String(format: "frame-%05d.jpg", frameIndex))
    guard let dest = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.jpeg.identifier as CFString, 1,
        [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary) else { return }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    frameIndex += 1
}

func canvas() -> CGContext {
    CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8,
              bytesPerRow: 0, space: space,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

let loaded = scenes.compactMap { scene -> (CGImage, String, String)? in
    guard let image = load(scene.file) else {
        FileHandle.standardError.write(Data("нет снимка \(scene.file)\n".utf8))
        return nil
    }
    return (image, scene.title, scene.subtitle)
}
guard !loaded.isEmpty else { exit(1) }

let holdFrames = Int(holdSeconds * fps)
let fadeFrames = Int(fadeSeconds * fps)

for (index, scene) in loaded.enumerated() {
    // Держим экран с медленным наездом.
    for frame in 0..<holdFrames {
        let progress = Double(frame) / Double(holdFrames)
        let ctx = canvas()
        background(ctx)
        drawPhone(ctx, image: scene.0, scale: 1 + 0.035 * progress, alpha: 1)
        drawCaption(ctx, title: scene.1, subtitle: scene.2, alpha: 1)
        write(ctx)
    }

    // Растворяем в следующий.
    guard index + 1 < loaded.count else { break }
    let next = loaded[index + 1]
    for frame in 0..<fadeFrames {
        let progress = Double(frame) / Double(fadeFrames)
        let ctx = canvas()
        background(ctx)
        drawPhone(ctx, image: scene.0, scale: 1.035 + 0.02 * progress, alpha: 1 - progress)
        drawCaption(ctx, title: scene.1, subtitle: scene.2, alpha: 1 - progress)
        drawPhone(ctx, image: next.0, scale: 0.97 + 0.03 * progress, alpha: progress)
        drawCaption(ctx, title: next.1, subtitle: next.2, alpha: progress)
        write(ctx)
    }
}

print("кадров: \(frameIndex), секунд: \(Double(frameIndex) / fps)")
