import Foundation

/// Всё, что показывает панель статистики.
///
/// Считается заново при каждой отметке. Это дёшево: 176 стран — один проход,
/// и зато нигде не нужно поддерживать инкрементальные счётчики в согласованном
/// состоянии, что обычно и становится источником расхождений.
struct TravelStatistics: Equatable {

    /// Доля суши, где пользователь был или живёт, в процентах.
    /// «Хочу» не считается: это желание, а не факт.
    let worldPercent: Double

    let visitedCount: Int
    let livingCount: Int
    let wishlistCount: Int

    /// Страны со статусом «был» или «живу».
    let exploredCount: Int
    let continentsTouched: Int
    let continents: [ContinentProgress]

    /// Мир, разрезанный на континенты по площади. Нужен полосе прогресса:
    /// сумма всех долей равна единице, а сумма закрашенного — ровно
    /// `worldPercent`. Поэтому Антарктида здесь есть, хотя в списке
    /// континентов её нет: без неё полоса не сходилась бы с числом над ней.
    let segments: [AreaSegment]

    struct AreaSegment: Identifiable, Equatable {
        let continent: Continent
        /// Доля континента в площади всей суши, 0…1.
        let share: Double
        /// Какая часть самого континента пройдена, 0…1.
        let filled: Double

        var id: String { continent.rawValue }
    }

    struct ContinentProgress: Identifiable, Equatable {
        let continent: Continent
        let explored: Int
        let total: Int

        var id: String { continent.rawValue }
        var fraction: Double { total > 0 ? Double(explored) / Double(total) : 0 }
    }

    static let empty = TravelStatistics(
        worldPercent: 0,
        visitedCount: 0,
        livingCount: 0,
        wishlistCount: 0,
        exploredCount: 0,
        continentsTouched: 0,
        continents: [],
        segments: []
    )

    var isEmpty: Bool { exploredCount == 0 && wishlistCount == 0 }

    static func make(log: TravelLog, geometry: WorldGeometry?) -> TravelStatistics {
        guard let geometry, geometry.totalAreaKm2 > 0 else { return .empty }

        var exploredArea: Double = 0
        var visited = 0
        var living = 0
        var wishlist = 0
        var exploredPerContinent: [Continent: Int] = [:]
        var exploredAreaPerContinent: [Continent: Double] = [:]
        var totalAreaPerContinent: [Continent: Double] = [:]

        for (countryID, status) in log.statuses {
            switch status {
            case .visited:  visited += 1
            case .living:   living += 1
            case .wishlist: wishlist += 1
            }

            guard status != .wishlist, let country = geometry.country(id: countryID) else { continue }

            exploredArea += country.areaKm2
            if let continent = country.continent {
                exploredPerContinent[continent, default: 0] += 1
                exploredAreaPerContinent[continent, default: 0] += country.areaKm2
            }
        }

        var totalPerContinent: [Continent: Int] = [:]
        for country in geometry.countries {
            guard let continent = country.continent else { continue }
            totalPerContinent[continent, default: 0] += 1
            totalAreaPerContinent[continent, default: 0] += country.areaKm2
        }

        let segments = Continent.allCases.compactMap { continent -> AreaSegment? in
            guard let total = totalAreaPerContinent[continent], total > 0 else { return nil }
            return AreaSegment(
                continent: continent,
                share: total / geometry.totalAreaKm2,
                filled: (exploredAreaPerContinent[continent] ?? 0) / total
            )
        }

        let continents = Continent.travelable.compactMap { continent -> ContinentProgress? in
            guard let total = totalPerContinent[continent], total > 0 else { return nil }
            return ContinentProgress(
                continent: continent,
                explored: exploredPerContinent[continent] ?? 0,
                total: total
            )
        }

        return TravelStatistics(
            worldPercent: exploredArea / geometry.totalAreaKm2 * 100,
            visitedCount: visited,
            livingCount: living,
            wishlistCount: wishlist,
            exploredCount: visited + living,
            continentsTouched: continents.filter { $0.explored > 0 }.count,
            continents: continents,
            segments: segments
        )
    }
}
