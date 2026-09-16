import SwiftUI

/// Весь мир, разобранный и готовый к рисованию.
public struct WorldGeometry {

    public let countries: [Country]
    /// Все страны, слитые в один `Path`.
    /// Базовую сушу рисуем именно им: одна заливка и одна обводка вместо 176.
    /// Отмеченные страны ложатся поверх отдельными слоями.
    public let landPath: Path

    public let totalAreaKm2: Double
    public let pointCount: Int

    private let byID: [String: Country]
    private let index: CountryIndex

    public init(countries: [Country]) {
        self.countries = countries

        var merged = Path()
        for country in countries {
            merged.addPath(country.path)
        }
        self.landPath = merged

        self.totalAreaKm2 = countries.reduce(0) { $0 + $1.areaKm2 }
        self.pointCount = countries.reduce(0) { $0 + $1.pointCount }
        self.byID = Dictionary(countries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.index = CountryIndex(countries: countries)
    }

    public func country(id: String) -> Country? { byID[id] }

    /// Габариты набора стран — общий прямоугольник, в который они все влезают.
    public func bounds(of ids: some Sequence<String>) -> CGRect? {
        var result: CGRect?
        for id in ids {
            guard let country = byID[id] else { continue }
            // Берём главный массив: у России общие габариты растянуты
            // на весь мир из-за кусков по обе стороны 180-го меридиана.
            result = result.map { $0.union(country.mainBounds) } ?? country.mainBounds
        }
        return result
    }

    public func countries(on continent: Continent) -> [Country] {
        countries.filter { $0.continent == continent }
    }

    // MARK: - Попадание пальцем

    /// Страна под точкой.
    ///
    /// Сначала точное попадание в контур. Если мимо — ищем ближайшую страну
    /// в пределах `tolerance`: без этого в Монако, Люксембург или Сингапур
    /// пальцем не попасть в принципе.
    public func country(at unit: CGPoint, tolerance: CGFloat = 0) -> Country? {
        for offset in index.candidates(at: unit) {
            let country = countries[offset]
            if country.bounds.contains(unit), country.path.contains(unit) {
                return country
            }
        }

        guard tolerance > 0 else { return nil }

        var nearest: Country?
        var nearestDistance = CGFloat.greatestFiniteMagnitude

        for offset in index.candidates(around: unit, radius: tolerance) {
            let country = countries[offset]
            let distance = country.bounds.insetBy(dx: -tolerance, dy: -tolerance).contains(unit)
                ? distanceToBounds(unit, box: country.bounds)
                : .greatestFiniteMagnitude

            if distance < nearestDistance {
                nearestDistance = distance
                nearest = country
            }
        }

        return nearestDistance <= tolerance ? nearest : nil
    }

    private func distanceToBounds(_ point: CGPoint, box: CGRect) -> CGFloat {
        let dx = max(box.minX - point.x, 0, point.x - box.maxX)
        let dy = max(box.minY - point.y, 0, point.y - box.maxY)
        return sqrt(dx * dx + dy * dy)
    }
}
