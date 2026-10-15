// Иконка приложения.
//
// Рисуется кодом, а не лежит картинкой: иконку придётся править — сдвинуть
// глобус, сменить оттенок, добавить отмеченную страну, — и каждый раз
// повторять это руками в редакторе значит однажды получить другую иконку.
// Здесь же видно, из чего она собрана, и пересобрать можно одной командой.
//
// Земля настоящая: те же границы, что и в приложении, в ортографической
// проекции с центром на Европе и Африке — то, что человек узнаёт глобусом.
// Четыре страны закрашены цветами приложения: иконка показывает ровно то,
// чем приложение занимается, — закрашенный мир.
//
//     swift Tools/make_icon.swift
//
// Результат: MAPA/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let side = 1024.0
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let bordersURL = root.appendingPathComponent("MAPA/Resources/world_110m.geojson")
let outURL = root.appendingPathComponent(
    "MAPA/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png")

// MARK: - Цвета приложения

func rgb(_ hex: UInt32, _ alpha: Double = 1) -> CGColor {
    CGColor(red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            alpha: alpha)
}

let void = rgb(0x06070C)
let abyss = rgb(0x0B0D15)
let ocean = rgb(0x0D1220)
let land = rgb(0x2B3250)
let indigo = rgb(0x6C5CFF)
let mint = rgb(0x5FE3B4)
let lagoon = rgb(0x22A7C9)
let magenta = rgb(0xE86FD1)

/// Закрашенные страны. Четыре и по разным материкам: иконка должна читаться
/// как «мир», а не как «Европа».
let marked: [String: CGColor] = [
    "ITA": indigo, "ESP": magenta, "EGY": mint, "ZAF": lagoon, "SAU": rgb(0x9B8CFF),
]

// MARK: - Проекция

/// Ортографическая проекция — глобус, как его рисуют на карте мира.
/// Центр смещён на восток и к северу: так в круг попадают Европа, Африка
/// и край Азии, а не пустая Атлантика.
let lat0 = 12.0 * .pi / 180
let lon0 = 18.0 * .pi / 180
let globeRadius = side * 0.40
let center = CGPoint(x: side / 2, y: side / 2)

func project(lon: Double, lat: Double) -> CGPoint? {
    let φ = lat * .pi / 180
    let λ = lon * .pi / 180 - lon0
    guard sin(lat0) * sin(φ) + cos(lat0) * cos(φ) * cos(λ) > 0 else { return nil }
    let x = cos(φ) * sin(λ)
    let y = cos(lat0) * sin(φ) - sin(lat0) * cos(φ) * cos(λ)
    return CGPoint(x: center.x + x * globeRadius, y: center.y + y * globeRadius)
}

// MARK: - Границы

struct Feature {
    let id: String
    let rings: [[CGPoint]]
}

func loadFeatures() -> [Feature] {
    guard let data = try? Data(contentsOf: bordersURL),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let features = root["features"] as? [[String: Any]] else {
        FileHandle.standardError.write(Data("нет файла границ\n".utf8))
        exit(1)
    }

    return features.compactMap { feature in
        guard let props = feature["properties"] as? [String: Any],
              let id = props["id"] as? String,
              let geometry = feature["geometry"] as? [String: Any],
              let type = geometry["type"] as? String else { return nil }

        // Полигон и мультиполигон приводим к одному виду: список колец.
        var raw: [[[Double]]] = []
        if type == "Polygon", let p = geometry["coordinates"] as? [[[Double]]] {
            raw = p
        } else if type == "MultiPolygon", let m = geometry["coordinates"] as? [[[[Double]]]] {
            raw = m.flatMap { $0 }
        }

        let rings = raw.compactMap { ring -> [CGPoint]? in
            // Кольцо, у которого часть точек за горизонтом, рвать нельзя:
            // получится клякса через весь глобус. Берём только целые.
            var points: [CGPoint] = []
            for pair in ring where pair.count >= 2 {
                guard let p = project(lon: pair[0], lat: pair[1]) else { return nil }
                points.append(p)
            }
            return points.count >= 3 ? points : nil
        }

        return rings.isEmpty ? nil : Feature(id: id, rings: rings)
    }
}

// MARK: - Рисование

let space = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: Int(side), height: Int(side),
                          bitsPerComponent: 8, bytesPerRow: 0, space: space,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    exit(1)
}

// Фон — ночное полотно приложения, от края к центру светлее.
ctx.setFillColor(void)
ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
if let gradient = CGGradient(colorsSpace: space,
                             colors: [abyss, void] as CFArray,
                             locations: [0, 1]) {
    ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                           endCenter: center, endRadius: side * 0.72,
                           options: [])
}

// Свечение под глобусом: без него шар лежит на фоне плоской наклейкой.
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: side * 0.11, color: indigo.copy(alpha: 0.5))
ctx.setFillColor(ocean)
ctx.fillEllipse(in: CGRect(x: center.x - globeRadius, y: center.y - globeRadius,
                           width: globeRadius * 2, height: globeRadius * 2))
ctx.restoreGState()

// Сетка меридианов и параллелей — она же говорит «карта».
ctx.saveGState()
ctx.addEllipse(in: CGRect(x: center.x - globeRadius, y: center.y - globeRadius,
                          width: globeRadius * 2, height: globeRadius * 2))
ctx.clip()
ctx.setStrokeColor(rgb(0xFFFFFF, 0.07))
ctx.setLineWidth(side * 0.004)
for lat in stride(from: -60.0, through: 60.0, by: 30.0) {
    var started = false
    for lon in stride(from: -180.0, through: 180.0, by: 2.0) {
        guard let p = project(lon: lon, lat: lat) else { started = false; continue }
        if started { ctx.addLine(to: p) } else { ctx.move(to: p); started = true }
    }
}
for lon in stride(from: -180.0, through: 180.0, by: 30.0) {
    var started = false
    for lat in stride(from: -90.0, through: 90.0, by: 2.0) {
        guard let p = project(lon: lon, lat: lat) else { started = false; continue }
        if started { ctx.addLine(to: p) } else { ctx.move(to: p); started = true }
    }
}
ctx.strokePath()

// Суша.
let features = loadFeatures()
for feature in features where marked[feature.id] == nil {
    ctx.setFillColor(land)
    for ring in feature.rings {
        ctx.addLines(between: ring)
        ctx.closePath()
    }
    ctx.fillPath()
}

// Отмеченные страны поверх — со своим свечением, как на карте.
for feature in features {
    guard let color = marked[feature.id] else { continue }
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: side * 0.02, color: color.copy(alpha: 0.9))
    ctx.setFillColor(color)
    for ring in feature.rings {
        ctx.addLines(between: ring)
        ctx.closePath()
    }
    ctx.fillPath()
    ctx.restoreGState()
}
ctx.restoreGState()

// Край шара: тонкий светлый ободок отделяет глобус от фона.
ctx.setStrokeColor(rgb(0xFFFFFF, 0.14))
ctx.setLineWidth(side * 0.006)
ctx.strokeEllipse(in: CGRect(x: center.x - globeRadius, y: center.y - globeRadius,
                             width: globeRadius * 2, height: globeRadius * 2))

// MARK: - Запись

guard let image = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil)
else { exit(1) }
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { exit(1) }
print("иконка: \(outURL.path), стран на глобусе: \(features.count)")
