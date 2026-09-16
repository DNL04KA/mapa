import SwiftUI

/// Страна с уже готовой геометрией.
///
/// Ключевое решение: `path` хранится в единичном пространстве (0…1), а не в
/// экранных координатах. Поэтому при панорамировании и зуме мы не пересобираем
/// тысячи точек — меняется только матрица преобразования у `Canvas`.
public struct Country: Identifiable {

    /// Код ISO 3166-1 alpha-3. Для пяти территорий Natural Earth его не даёт —
    /// там подставлен ADM0_A3, он тоже уникален и стабилен.
    public let id: String
    public let name: String
    public let nameRU: String
    public let continent: Continent?
    public let areaKm2: Double

    /// Тон флага в круге оттенков, 0…1. Им страна заливается на карте:
    /// насыщенность и яркость приходят от статуса, а тон — от флага,
    /// поэтому карта получается разноцветной, но статус остаётся читаемым.
    public let flagHue: Double?

    /// Контур в единичном пространстве проекции.
    public let path: Path
    /// Габариты контура — быстрый предварительный отсев при попадании и зуме.
    public let bounds: CGRect
    /// Габариты крупнейшего куска суши.
    ///
    /// У России куски лежат по обе стороны 180-го меридиана, и общие габариты
    /// растягиваются на весь мир. Для силуэта в карточке нужен именно главный
    /// массив, иначе страна превращается в две полоски по краям.
    public let mainBounds: CGRect
    /// Точка, к которой имеет смысл центрировать камеру.
    public let anchor: CGPoint
    public let pointCount: Int

    public init(
        id: String,
        name: String,
        nameRU: String,
        continent: Continent?,
        areaKm2: Double,
        flagHue: Double?,
        path: Path,
        bounds: CGRect,
        mainBounds: CGRect,
        anchor: CGPoint,
        pointCount: Int
    ) {
        self.id = id
        self.name = name
        self.nameRU = nameRU
        self.continent = continent
        self.areaKm2 = areaKm2
        self.flagHue = flagHue
        self.path = path
        self.bounds = bounds
        self.mainBounds = mainBounds
        self.anchor = anchor
        self.pointCount = pointCount
    }
}

extension Country: Equatable {
    public static func == (lhs: Country, rhs: Country) -> Bool { lhs.id == rhs.id }
}

extension Country: Hashable {
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
