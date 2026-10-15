// Иконка приложения.
//
// Рисуется кодом, а не лежит картинкой: иконку придётся править — сдвинуть
// точку, сменить оттенок, — и каждый раз повторять это руками в редакторе
// значит однажды получить другую иконку. Здесь видно, из чего она собрана,
// и пересобрать можно одной командой.
//
//     swift Tools/make_icon.swift
//
// Знак — маршрут из пяти остановок, сложенный в букву M: и название, и то,
// чем приложение занимается, в одной фигуре. До него тут был настоящий
// глобус с настоящими границами; он честно показывал карту и так же честно
// превращался в тёмное пятно среди ярких соседей по экрану. В шестьдесят
// пикселей выживает одна толстая фигура, а не география.
//
// Названия внутри нет намеренно: iOS подписывает «MAPA» под значком сама,
// и надпись в такой плитке превращается в грязную полоску.
//
// Результат: MAPA/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let side = 1024.0
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let outURL = root.appendingPathComponent(
    "MAPA/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png")

func rgb(_ hex: UInt32, _ alpha: Double = 1) -> CGColor {
    CGColor(red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            alpha: alpha)
}

// Цвета приложения: индиго переходит в сирень, остановки — акценты палитры.
let gradientTop: UInt32 = 0x3B2BD9
let gradientBottom: UInt32 = 0x8B3BD6
let stopColors: [UInt32] = [0xE86FD1, 0x22A7C9, 0x5FE3B4, 0x9B8CFF, 0xE86FD1]

let space = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: Int(side), height: Int(side),
                          bitsPerComponent: 8, bytesPerRow: 0, space: space,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    exit(1)
}

// Фон.
if let gradient = CGGradient(colorsSpace: space,
                             colors: [rgb(gradientTop), rgb(gradientBottom)] as CFArray,
                             locations: [0, 1]) {
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: 0, y: side),
                           end: CGPoint(x: side, y: 0),
                           options: [])
}

// Сетка — тихий намёк на карту под маршрутом. Настолько тихий, что в
// размере значка её не видно; она работает только на большой плитке в
// магазине, и это нормально.
ctx.setStrokeColor(rgb(0xFFFFFF, 0.08))
ctx.setLineWidth(side * 0.004)
for step in stride(from: 0.0, through: side, by: side / 8) {
    ctx.move(to: CGPoint(x: step, y: 0)); ctx.addLine(to: CGPoint(x: step, y: side))
    ctx.move(to: CGPoint(x: 0, y: step)); ctx.addLine(to: CGPoint(x: side, y: step))
}
ctx.strokePath()

// Затемнение по углам: без него плитка выглядит плоской наклейкой.
if let vignette = CGGradient(colorsSpace: space,
                             colors: [rgb(0x1A0B4A, 0), rgb(0x1A0B4A, 0.35)] as CFArray,
                             locations: [0.45, 1]) {
    let center = CGPoint(x: side / 2, y: side / 2)
    ctx.drawRadialGradient(vignette, startCenter: center, startRadius: 0,
                           endCenter: center, endRadius: side * 0.78, options: [])
}

// Маршрут. Пять остановок: левая ножка, подъём, середина, подъём, правая.
let stops = [
    CGPoint(x: side * 0.293, y: side * 0.293),
    CGPoint(x: side * 0.293, y: side * 0.707),
    CGPoint(x: side * 0.500, y: side * 0.459),
    CGPoint(x: side * 0.707, y: side * 0.707),
    CGPoint(x: side * 0.707, y: side * 0.293),
]

ctx.saveGState()
ctx.setLineJoin(.round)
ctx.setLineCap(.round)
ctx.setShadow(offset: CGSize(width: 0, height: -side * 0.012),
              blur: side * 0.05, color: rgb(0x1A0B4A, 0.45))
ctx.setStrokeColor(rgb(0xFFFFFF))
ctx.setLineWidth(side * 0.078)
ctx.addLines(between: stops)
ctx.strokePath()
ctx.restoreGState()

// Остановки: белый кружок с цветной серединой — ровно так они выглядят
// на самой карте.
for (index, stop) in stops.enumerated() {
    let outer = side * 0.058
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fillEllipse(in: CGRect(x: stop.x - outer, y: stop.y - outer,
                               width: outer * 2, height: outer * 2))
    let inner = side * 0.029
    ctx.setFillColor(rgb(stopColors[index % stopColors.count]))
    ctx.fillEllipse(in: CGRect(x: stop.x - inner, y: stop.y - inner,
                               width: inner * 2, height: inner * 2))
}

guard let image = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(
        outURL as CFURL, UTType.png.identifier as CFString, 1, nil)
else { exit(1) }
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { exit(1) }
print("иконка: \(outURL.path)")
