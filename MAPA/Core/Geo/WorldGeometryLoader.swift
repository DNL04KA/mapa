import SwiftUI

/// Разбор границ из бандла.
///
/// Работает в фоне: парсинг и построение путей занимают заметные десятки
/// миллисекунд, а ронять первый кадр приложения нельзя.
public enum WorldGeometryLoader {

    public struct Result {
        public let geometry: WorldGeometry
        /// Сколько заняли чтение, парсинг и построение путей.
        public let duration: TimeInterval
    }

    public enum LoaderError: LocalizedError {
        case resourceMissing(String)
        case malformed(String)

        public var errorDescription: String? {
            switch self {
            case .resourceMissing(let name):
                return "В бандле нет файла \(name)"
            case .malformed(let reason):
                return "Файл границ повреждён: \(reason)"
            }
        }
    }

    private static let resourceName = "world_110m"

    public static func loadFromBundle() async throws -> Result {
        try await Task.detached(priority: .userInitiated) {
            let start = CFAbsoluteTimeGetCurrent()

            guard let url = Bundle.main.url(forResource: resourceName, withExtension: "geojson") else {
                throw LoaderError.resourceMissing("\(resourceName).geojson")
            }

            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let geometry = try parse(data)

            return Result(geometry: geometry, duration: CFAbsoluteTimeGetCurrent() - start)
        }.value
    }

    // MARK: - Парсинг

    /// `JSONSerialization`, а не `Codable`: у нас массивы массивов массивов чисел,
    /// и обход словарей вручную здесь заметно быстрее синтезированных декодеров.
    static func parse(_ data: Data) throws -> WorldGeometry {
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let features = root["features"] as? [[String: Any]]
        else {
            throw LoaderError.malformed("ожидалась FeatureCollection")
        }

        var countries: [Country] = []
        countries.reserveCapacity(features.count)

        for feature in features {
            guard
                let properties = feature["properties"] as? [String: Any],
                let id = properties["id"] as? String,
                let geometry = feature["geometry"] as? [String: Any],
                let polygons = geometry["coordinates"] as? [[[[Double]]]]
            else { continue }

            var path = Path()
            var pointCount = 0
            var bounds: CGRect?
            var anchor = CGPoint(x: 0.5, y: 0.5)
            var mainBounds: CGRect?
            var largestRingArea: CGFloat = 0

            for polygon in polygons {
                for ring in polygon {
                    guard ring.count >= 3 else { continue }

                    var ringBounds: CGRect?
                    var isFirstPoint = true

                    for pair in ring {
                        guard pair.count >= 2 else { continue }
                        let point = MapProjection.unitPoint(longitude: pair[0], latitude: pair[1])

                        if isFirstPoint {
                            path.move(to: point)
                            isFirstPoint = false
                        } else {
                            path.addLine(to: point)
                        }

                        ringBounds = ringBounds.map { $0.union(CGRect(origin: point, size: .zero)) }
                            ?? CGRect(origin: point, size: .zero)
                        pointCount += 1
                    }

                    path.closeSubpath()

                    guard let ringBounds else { continue }
                    bounds = bounds.map { $0.union(ringBounds) } ?? ringBounds

                    // Якорь берём у самого крупного кольца, а не у общих габаритов:
                    // у России и США куски лежат по разные стороны 180-го меридиана,
                    // и центр общего прямоугольника оказался бы посреди океана.
                    let area = ringBounds.width * ringBounds.height
                    if area > largestRingArea {
                        largestRingArea = area
                        anchor = CGPoint(x: ringBounds.midX, y: ringBounds.midY)
                        mainBounds = ringBounds
                    }
                }
            }

            guard let bounds, pointCount > 0 else { continue }

            countries.append(
                Country(
                    id: id,
                    name: properties["name"] as? String ?? id,
                    nameRU: properties["name_ru"] as? String ?? properties["name"] as? String ?? id,
                    continent: (properties["continent"] as? String).flatMap(Continent.init(rawValue:)),
                    areaKm2: (properties["area_km2"] as? Double) ?? 0,
                    flagHue: (properties["color"] as? String).flatMap(hue(fromHex:)),
                    path: path,
                    bounds: bounds,
                    mainBounds: mainBounds ?? bounds,
                    anchor: anchor,
                    pointCount: pointCount
                )
            )
        }

        guard !countries.isEmpty else {
            throw LoaderError.malformed("не разобрана ни одна страна")
        }

        return WorldGeometry(countries: countries)
    }

    /// Из «#RRGGBB» достаём только тон. Насыщенность и яркость флага не нужны:
    /// они пришли бы вразнобой, и карта распалась бы на яркие и тусклые пятна.
    private static func hue(fromHex hex: String) -> Double? {
        var value = hex
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let number = UInt32(value, radix: 16) else { return nil }

        let red = Double((number >> 16) & 0xFF) / 255
        let green = Double((number >> 8) & 0xFF) / 255
        let blue = Double(number & 0xFF) / 255

        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)
        let delta = maximum - minimum
        guard delta > 0.001 else { return nil }   // серый: тона нет

        let hue: Double
        if maximum == red {
            hue = (green - blue) / delta
        } else if maximum == green {
            hue = 2 + (blue - red) / delta
        } else {
            hue = 4 + (red - green) / delta
        }
        return (hue / 6).truncatingRemainder(dividingBy: 1) + (hue < 0 ? 1 : 0)
    }
}
