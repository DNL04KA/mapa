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

    struct ContinentProgress: Identifiable, Equatable {
        let continent: Continent
        let explored: Int
        let total: Int
        let exploredArea: Double
        let totalArea: Double

        var id: String { continent.rawValue }

        /// Доля по числу стран — для подписи «3/44».
        var fraction: Double { total > 0 ? Double(explored) / Double(total) : 0 }

        /// Доля по площади — для полосы.
        ///
        /// Именно площадь, а не число стран: иначе строки в таблице мерили бы
        /// одно, а итог над ними — другое, и сумма не сходилась бы с процентом.
        var areaFraction: Double { totalArea > 0 ? exploredArea / totalArea : 0 }
    }

    static let empty = TravelStatistics(
        worldPercent: 0,
        visitedCount: 0,
        livingCount: 0,
        wishlistCount: 0,
        exploredCount: 0,
        continentsTouched: 0,
        continents: []
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

        // Антарктида участвует, только если там кто-то был.
        //
        // В процент открытого мира она входит всегда — это честно: материк
        // настоящий, и тот, кто туда добрался, заслужил свои восемь процентов.
        // А вот строка «Антарктида 0/1» в таблице у всех остальных — шум.
        // Пока её не отметили, строки нет; как отметили — появляется, и
        // таблица снова сходится с числом над ней.
        let listed = Continent.allCases.filter {
            $0 != .antarctica || (exploredPerContinent[$0] ?? 0) > 0
        }
        let continents = listed.compactMap { continent -> ContinentProgress? in
            guard let total = totalPerContinent[continent], total > 0 else { return nil }
            return ContinentProgress(
                continent: continent,
                explored: exploredPerContinent[continent] ?? 0,
                total: total,
                exploredArea: exploredAreaPerContinent[continent] ?? 0,
                totalArea: totalAreaPerContinent[continent] ?? 0
            )
        }

        return TravelStatistics(
            worldPercent: exploredArea / geometry.totalAreaKm2 * 100,
            visitedCount: visited,
            livingCount: living,
            wishlistCount: wishlist,
            exploredCount: visited + living,
            continentsTouched: continents.filter { $0.explored > 0 }.count,
            continents: continents
        )
    }
}
