import SwiftUI

/// Сеточный индекс по единичному пространству.
///
/// Без него каждый тап пришлось бы проверять на попадание во все 176 контуров.
/// Мир режется на сетку, в каждую клетку складываются страны, чьи габариты
/// её задевают, и тап проверяет только их — обычно одну-две.
struct CountryIndex {

    /// 64×64 клетки: одна клетка ≈ 5.6° по долготе. Мельче — растёт память
    /// на крупные страны, крупнее — падает точность отсева.
    private static let resolution = 64

    private let cells: [[Int]]

    init(countries: [Country]) {
        let resolution = Self.resolution
        var buckets = [[Int]](repeating: [], count: resolution * resolution)

        for (offset, country) in countries.enumerated() {
            let box = country.bounds
            let minColumn = Self.cellIndex(box.minX)
            let maxColumn = Self.cellIndex(box.maxX)
            let minRow = Self.cellIndex(box.minY)
            let maxRow = Self.cellIndex(box.maxY)

            for row in minRow...maxRow {
                for column in minColumn...maxColumn {
                    buckets[row * resolution + column].append(offset)
                }
            }
        }

        cells = buckets
    }

    private static func cellIndex(_ value: CGFloat) -> Int {
        min(max(Int(value * CGFloat(resolution)), 0), resolution - 1)
    }

    /// Индексы стран-кандидатов в точке.
    func candidates(at unit: CGPoint) -> [Int] {
        let column = Self.cellIndex(unit.x)
        let row = Self.cellIndex(unit.y)
        return cells[row * Self.resolution + column]
    }

    /// Кандидаты в квадрате вокруг точки — для «мягкого» попадания по мелким странам.
    func candidates(around unit: CGPoint, radius: CGFloat) -> [Int] {
        let minColumn = Self.cellIndex(unit.x - radius)
        let maxColumn = Self.cellIndex(unit.x + radius)
        let minRow = Self.cellIndex(unit.y - radius)
        let maxRow = Self.cellIndex(unit.y + radius)

        var result = Set<Int>()
        for row in minRow...maxRow {
            for column in minColumn...maxColumn {
                result.formUnion(cells[row * Self.resolution + column])
            }
        }
        return Array(result)
    }
}
