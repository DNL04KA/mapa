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
    /// Три прохода, и порядок важен.
    ///
    /// Первый — точное попадание в контур, и из попавших берём самую мелкую:
    /// Ватикан лежит внутри Италии, Лесото внутри ЮАР, и без этого правила
    /// большая страна всегда перекрывала бы вложенную.
    ///
    /// Второй — вложенная страна мельче пальца: ей добавляется немного
    /// свободы по краям, потому что в Монако шириной в семь точек экрана
    /// попасть иначе нельзя.
    ///
    /// Третий — ближайшая страна в пределах `tolerance`, если не попали
    /// никуда: тап у берега всё-таки выбирает страну, а не океан.
    public func country(at unit: CGPoint, tolerance: CGFloat = 0) -> Country? {
        var exact: Country?
        for offset in index.candidates(at: unit) {
            let country = countries[offset]
            guard country.bounds.contains(unit), country.path.contains(unit) else { continue }
            if exact.map({ country.areaKm2 < $0.areaKm2 }) ?? true { exact = country }
        }

        guard tolerance > 0 else { return exact }

        if let enclave = enclave(at: unit, tolerance: tolerance, inside: exact) { return enclave }
        if let exact { return exact }

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

    /// Страна внутри страны, которая на экране мельче пальца.
    ///
    /// Два ограничения не дают ей воровать нажатия у соседей. Она должна
    /// целиком помещаться в габариты той страны, по которой попали, —
    /// так отсеиваются просто мелкие соседи вроде Словении рядом с
    /// Австрией. И запас по краям не больше её собственного размера:
    /// иначе на карте мира, где восемь точек экрана это шестьсот
    /// километров, Монако забирало бы себе пол-Прованса.
    ///
    /// `tolerance` приходит в единичном пространстве и равен двадцати
    /// точкам экрана — из него получаем и остальные пороги, не зная
    /// ни зума, ни размера экрана.
    private func enclave(at unit: CGPoint, tolerance: CGFloat, inside host: Country?) -> Country? {
        let point = tolerance / 20
        let finger = 24 * point

        var best: Country?
        for offset in index.candidates(around: unit, radius: finger) {
            let country = countries[offset]
            // Главный массив, а не все габариты: у Франции в них входит
            // Гвиана, и «внутри Франции» оказывалась половина Европы.
            let box = country.mainBounds
            let size = max(box.width, box.height)
            guard size < finger else { continue }
            if let host, !host.mainBounds.contains(box) { continue }

            let grow = min(8 * point, size) / 2
            guard box.insetBy(dx: -grow, dy: -grow).contains(unit) else { continue }
            if best.map({ country.areaKm2 < $0.areaKm2 }) ?? true { best = country }
        }
        return best
    }

    private func distanceToBounds(_ point: CGPoint, box: CGRect) -> CGFloat {
        let dx = max(box.minX - point.x, 0, point.x - box.maxX)
        let dy = max(box.minY - point.y, 0, point.y - box.maxY)
        return sqrt(dx * dx + dy * dy)
    }
}
